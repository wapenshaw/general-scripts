#!/bin/zsh

set -u
set -o pipefail

autoload -U colors && colors

#
# Configuration
#

typeset -a FAILURES
typeset -a WARNINGS
typeset -a BREW_BINARIES
typeset -a APT_DUPLICATES
typeset -a UV_TOOLS

typeset SCRIPT_DIR="${0:A:h}"
typeset BREWFILE="$SCRIPT_DIR/linux/Brewfile"
typeset AZURE_KUBELOGIN_TAP_URL="https://github.com/Azure/homebrew-kubelogin"
typeset UV_DEFAULT_PYTHON=""
typeset UV_DEFAULT_VERSION=""

FAILURES=()
WARNINGS=()

UPDATE_SYSTEM=false
BOOTSTRAP_TOOLS=false
CLEANUP=false
DEEP_CLEANUP=false
DRY_RUN=false

# Cleanup tuning (override from the environment, e.g. JOURNAL_MAX_AGE=3d ./linux-update.zsh --cleanup).
typeset JOURNAL_MAX_AGE="${JOURNAL_MAX_AGE:-7d}"
typeset TMP_MAX_AGE_DAYS="${TMP_MAX_AGE_DAYS:-1}"
typeset LOG_MAX_AGE_DAYS="${LOG_MAX_AGE_DAYS:-14}"
typeset SESSION_MAX_AGE_DAYS="${SESSION_MAX_AGE_DAYS:-14}"
# --deep wipes ~/.cache except these. uv's cache is kept: wiping it re-downloads
# every wheel through the proxy and breaks UV_LINK_MODE=clone sharing.
typeset -a CACHE_KEEP
CACHE_KEEP=(${=CACHE_KEEP_NAMES:-uv pre-commit ruff})

# Python version exposed globally as ~/.local/bin/python, python3 and python3.14
# (uv python install --default). Python is never installed through Homebrew.
UV_DEFAULT_PYTHON_VERSION="3.14"

# Commands that linux/Brewfile owns. Each must resolve into the Homebrew prefix;
# an older apt, /usr/local/bin or ~/.local/bin copy would shadow it and never be
# updated by `brew upgrade`. Keep in step with linux/Brewfile.
BREW_BINARIES=(
	bat
	delta
	eza
	fd
	fzf
	gh
	helm
	hyperfine
	jq
	just
	k9s
	kubelogin
	nvim
	rg
	shellcheck
	shfmt
	starship
	yq
	zoxide
)

# apt packages that Homebrew replaced; leftovers go stale and are shadowed.
APT_DUPLICATES=(
	bat
	eza
	fd-find
	fzf
	gh
	git-delta
	helm
	hyperfine
	jq
	just
	neovim
	ripgrep
	shellcheck
	shfmt
	zoxide
)

# Python command-line applications managed by uv.
UV_TOOLS=(
	pre-commit
	ruff
)

#
# Output helpers
#

info() {
	print -P "%F{cyan}==>%f $*"
}

success() {
	print -P "%F{green}✓%f $*"
}

warning() {
	print -P "%F{yellow}Warning:%f $*"
}

failure() {
	print -P "%F{red}Error:%f $*" >&2
}

section() {
	print
	print -P "%B%F{blue}--- $* ---%f%b"
	print
}

print_command() {
	local arg

	print -n "  "

	for arg in "$@"; do
		printf "%q " "$arg"
	done

	print
}

#
# General helpers
#

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

add_warning() {
	WARNINGS+=("$1")
}

add_failure() {
	FAILURES+=("$1")
}

run_step() {
	local description="$1"
	shift

	info "$description"

	if [[ "$DRY_RUN" == true ]]; then
		print_command "$@"
		return 0
	fi

	if "$@"; then
		success "$description"
		return 0
	else
		local exit_code=$?

		warning "$description failed with exit code $exit_code"
		add_failure "$description"

		return 0
	fi
}

# Puts Linuxbrew on PATH for this run. shellenv prepends, so ~/.local/bin (uv's
# python shims, uv) is moved back in front, as the zsh config does for real shells.
activate_homebrew() {
	local brew_bin

	if command_exists brew; then
		return 0
	fi

	for brew_bin in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
		if [[ -x "$brew_bin" ]]; then
			eval "$("$brew_bin" shellenv zsh)"
			path=("$HOME/.local/bin" $path)
			return 0
		fi
	done

	return 1
}

package_manager() {
	if command_exists apt-get; then
		print apt
	elif command_exists dnf; then
		print dnf
	fi
}

apt_installed() {
	dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

azure_kubelogin_tap_dir() {
	print -r -- "$(brew --repository)/Library/Taps/azure/homebrew-kubelogin"
}

tap_is_shallow() {
	[[ "$(git -C "$1" rev-parse --is-shallow-repository 2>/dev/null)" == true ]]
}

# The Azure kubelogin tap carries ~460 MB of git history; keep it at one commit.
make_tap_shallow() {
	local tap_dir="$1"
	local tmp_dir="$1.shallow"

	[[ "$tap_dir" == */Library/Taps/azure/homebrew-kubelogin ]] || return 1

	command rm -rf "$tmp_dir"
	if ! git clone --depth 1 -q "$AZURE_KUBELOGIN_TAP_URL" "$tmp_dir"; then
		command rm -rf "$tmp_dir"
		return 1
	fi

	command rm -rf "$tap_dir" && command mv "$tmp_dir" "$tap_dir"
}

typeset SUDO_PRIMED=false

# Asks for the sudo password once up front so later steps do not stop and prompt.
prime_sudo() {
	[[ "$SUDO_PRIMED" == true || "$DRY_RUN" == true ]] && return 0
	SUDO_PRIMED=true

	run_step "Authenticate sudo" sudo -v
}

rm_rf() {
	command rm -rf -- "$@"
}

fs_used_kb() {
	df -k --output=used / | sed -n '2s/[^0-9]//gp'
}

human_kb() {
	numfmt --from-unit=1024 --to=iec --format=%.1f "$1" 2>/dev/null || print "${1}K"
}

path_size() {
	if [[ -e "$1" ]]; then
		du -sh "$1" 2>/dev/null | cut -f1
	else
		print "-"
	fi
}

report_size() {
	printf "  %-26s %s\n" "$1" "$2"
}

# Deletes entries older than N days under a directory, never sockets or pipes
# (a running tmux, ssh-agent or herdr keeps its socket there) and never across
# mounts (WSLg's /tmp/.X11-unix). Entries that are busy or non-empty are skipped.
sweep_old() {
	local dir="$1" days="$2"

	sudo find "$dir" -mindepth 1 -xdev ! -type s ! -type p -mtime "+$days" -delete 2>/dev/null
	return 0
}

sweep_old_logs() {
	sudo find /var/log -xdev -type f \
		\( -name '*.gz' -o -name '*.xz' -o -name '*.old' -o -name '*.[0-9]' \) \
		-mtime "+$LOG_MAX_AGE_DAYS" -delete 2>/dev/null
	return 0
}

purge_residual_configs() {
	local -a residual
	residual=(${(f)"$(dpkg -l | awk '/^rc/ {print $2}')"})

	((${#residual[@]} > 0)) || return 0
	info "Residual configs: ${residual[*]}"
	sudo apt-get purge -y "${residual[@]}"
}

trim_free_space() {
	sudo fstrim -av
	local rc=$?

	sync
	return $rc
}

# --deep: ~/.cache except CACHE_KEEP.
sweep_user_cache() {
	local entry name

	for entry in "$HOME"/.cache/*(N); do
		name="${entry:t}"

		if ((${CACHE_KEEP[(Ie)$name]})); then
			info "Keeping ~/.cache/$name"
			continue
		fi

		run_step "Remove ~/.cache/$name" rm_rf "$entry"
	done
}

# --deep: npx package dirs, except those a running process uses.
sweep_npx_cache() {
	local dir hash in_use

	in_use="$(ps -eo args | grep -oE '[.]npm/_npx/[0-9a-f]+' | sed 's#.*/##' | sort -u || true)"

	for dir in "$HOME"/.npm/_npx/*(N/); do
		hash="${dir:t}"

		if print -r -- "$in_use" | grep -qx "$hash"; then
			info "Keeping npx cache $hash (in use)"
		else
			run_step "Remove npx cache $hash" rm_rf "$dir"
		fi
	done
}

# --deep: Azure MCP extracts a copy per launch; skip while the server runs.
sweep_azmcp() {
	local dir

	if pgrep -f '[.]net/azmcp' >/dev/null 2>&1; then
		info "azmcp is running, skipped"
		return 0
	fi

	for dir in "$HOME"/.net/azmcp/*(N); do
		run_step "Remove Azure MCP extraction ${dir:t}" rm_rf "$dir"
	done
}

# --deep: Claude Code keeps every downloaded version; keep the two newest.
sweep_claude_versions() {
	local versions_dir="$HOME/.local/share/claude/versions"
	local -a versions

	[[ -d "$versions_dir" ]] || return 0

	versions=(${(f)"$(ls -1 "$versions_dir" | sort -V)"})
	((${#versions[@]} > 2)) || return 0

	for version in "${versions[@]:0:$((${#versions[@]} - 2))}"; do
		if pgrep -f "claude/versions/$version" >/dev/null 2>&1; then
			info "Keeping Claude Code $version (running)"
			continue
		fi

		run_step "Remove old Claude Code $version" rm_rf "$versions_dir/$version"
	done
}

# --deep: Copilot sessions idle for SESSION_MAX_AGE_DAYS. Sessions that a live
# process holds, or that contain a git repo/worktree (possibly unpushed work), are kept.
sweep_copilot_sessions() {
	local sessions_dir="$HOME/.copilot/session-state"
	local dir id lock pid live
	typeset -i removed=0

	[[ -d "$sessions_dir" ]] || return 0

	for dir in "$sessions_dir"/*(N/); do
		id="${dir:t}"

		[[ "$id" =~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' ]] || continue
		[[ -L "$dir" ]] && continue

		if find "$dir" -maxdepth 1 -type f -mtime "-$SESSION_MAX_AGE_DAYS" 2>/dev/null | grep -q .; then
			continue
		fi

		live=0
		for lock in "$dir"/inuse.*.lock(N); do
			pid="${${lock:t}//[^0-9]/}"
			kill -0 "$pid" 2>/dev/null && live=1
		done

		if ((live)); then
			info "Keeping Copilot session $id (in use)"
			continue
		fi

		if [[ -n "$(find "$dir" -maxdepth 4 -name .git -print -quit 2>/dev/null)" ]]; then
			info "Keeping Copilot session $id (contains a git repo/worktree: review by hand)"
			continue
		fi

		run_step "Remove Copilot session $id" rm_rf "$dir"
		removed+=1
	done

	info "$removed Copilot session(s) idle for ${SESSION_MAX_AGE_DAYS}+ days"
}

usage() {
	cat <<'HELP'
Usage:
  ./linux-update.zsh [options]
  ./linux/install.sh           First-run Linux bootstrap (system packages + Homebrew + tools + zsh)

Options:
  --system      Install system package updates (apt or dnf). Uses sudo.
  --cleanup     Free disk space (apt/dnf caches, unused packages, old logs and /tmp,
                brew/uv/npm/pip caches) and finish with `sudo fstrim -av` so the
                WSL virtual disk can shrink. Uses sudo.
  --deep        With --cleanup, also sweep ~/.cache (except uv, pre-commit, ruff),
                the npx cache, Azure MCP extractions, old Claude Code versions and
                idle Copilot sessions. Implies --cleanup.
  --bootstrap   Install Homebrew if missing, then apply linux/Brewfile, rustup,
                the uv default Python and the uv tools.
  --dry-run     Print mutating commands without running them.
  --help, -h    Show this help.

Examples:
  ./linux-update.zsh
  ./linux-update.zsh --dry-run
  ./linux-update.zsh --system
  ./linux-update.zsh --cleanup
  ./linux-update.zsh --cleanup --deep --dry-run
  ./linux-update.zsh --bootstrap
  ./linux-update.zsh --system --bootstrap --dry-run

Routine behavior:
  - Lists available system package updates (installs them only with --system).
  - Updates and upgrades Homebrew packages, then removes unused dependencies.
  - Keeps the Azure kubelogin tap a shallow clone.
  - Updates rustup and the installed Rust toolchain when rustup is present.
  - Updates uv, upgrades uv-managed Python installations and uv tools.
  - Runs Homebrew, rustup, uv, Python, PATH-order and WSL health checks.

Cleanup (only with --cleanup; a normal run just reports what is reclaimable):
  - apt: clean, autoclean, autoremove --purge, purge residual configs (dnf: clean all).
  - Vacuums the systemd journal (JOURNAL_MAX_AGE, default 7d).
  - Deletes rotated logs older than LOG_MAX_AGE_DAYS (14), and /tmp entries older than
    TMP_MAX_AGE_DAYS (1) and /var/tmp older than 30 days, never sockets or other mounts.
  - brew cleanup --prune=all, uv cache prune (never a full wipe), npm and pip caches.
  - --deep adds: ~/.cache (CACHE_KEEP_NAMES, default "uv pre-commit ruff"), npx cache
    (skips dirs in use), Azure MCP extractions, Claude Code versions (keeps 2), Copilot
    sessions idle SESSION_MAX_AGE_DAYS (14, skips live and git-containing ones).
  - Last step: sudo fstrim -av, then prints the filesystem usage before and after.
    Shrinking the VHDX itself happens on Windows (see the WSL section).

Bootstrap behavior:
  - Runs linux/install.sh --skip-zsh when Homebrew is missing.
  - Applies linux/Brewfile (Homebrew tools, Azure kubelogin tap).
  - Installs rustup via the official installer without mutating shell rc files.
  - Installs Python 3.14 through uv as the global/default Python.
  - Installs Python CLI tools such as pre-commit and ruff through uv.

Tool ownership:
  apt / dnf  System packages and prerequisites (zsh, git, curl, build tools, direnv)
  Homebrew   Native CLI utilities in linux/Brewfile; never Python or Node
  NVM        Node.js and global Node packages
  rustup     Rust toolchain (rustc, cargo, rustfmt, clippy)
  uv         uv itself (uv self update), Python installations, Python CLI tools
HELP
}

#
# Argument parsing
#

for arg in "$@"; do
	case "$arg" in
	--system)
		UPDATE_SYSTEM=true
		;;
	--bootstrap)
		BOOTSTRAP_TOOLS=true
		;;
	--cleanup)
		CLEANUP=true
		;;
	--deep)
		CLEANUP=true
		DEEP_CLEANUP=true
		;;
	--dry-run)
		DRY_RUN=true
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		failure "Unknown option: $arg"
		print
		usage
		exit 2
		;;
	esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
	failure "This script is for Linux/WSL. On macOS use ./mac-update.zsh"
	exit 2
fi

#
# System information
#

print
info "Starting Linux maintenance"

typeset DISTRO_NAME="$(. /etc/os-release 2>/dev/null && print -r -- "${PRETTY_NAME:-unknown}")"

print "Date:         $(date)"
print "Computer:     $(hostname)"
print "Distro:       $DISTRO_NAME"
print "Kernel:       $(uname -r)"
print "Architecture: $(uname -m)"
print "Shell:        ${SHELL:-unknown}"

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
	print "WSL distro:   $WSL_DISTRO_NAME"
fi

if [[ "$DRY_RUN" == true ]]; then
	print
	warning "Dry-run mode is enabled"
	warning "Checks will run, but mutating commands will only be printed"
fi

#
# System package updates
#

section "System packages"

typeset PM="$(package_manager)"

case "$PM" in
apt)
	info "Checking for available apt updates"

	if [[ "$UPDATE_SYSTEM" == true ]]; then
		warning "Installing system updates"
		warning "Your password may be requested"

		prime_sudo
		run_step "Refresh apt metadata" sudo apt-get update
		run_step "Upgrade apt packages" sudo apt-get full-upgrade -y
		run_step "Remove unused apt packages" sudo apt-get autoremove -y
	else
		# Lists what the last `apt update` saw; refreshing needs sudo.
		if apt list --upgradable 2>/dev/null | sed '1d'; then
			success "Finished checking for apt updates (from cached metadata)"
		else
			warning "The apt update check returned a nonzero status"
			add_warning "Check for apt updates returned a nonzero status"
		fi

		print
		info "System updates were checked but not installed"
		print "Use --system to refresh apt metadata and install them."
	fi

	if [[ -e /var/run/reboot-required ]]; then
		warning "A restart is required to finish a system update"
		if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
			print "  From Windows: wsl --shutdown"
		fi
		add_warning "System restart required"
	fi
	;;
dnf)
	info "Checking for available dnf updates"

	if [[ "$UPDATE_SYSTEM" == true ]]; then
		warning "Installing system updates"
		warning "Your password may be requested"

		prime_sudo
		run_step "Upgrade dnf packages" sudo dnf upgrade -y
		run_step "Remove unused dnf packages" sudo dnf autoremove -y
	else
		# dnf check-update exits 100 when updates are available.
		dnf check-update >/dev/null 2>&1
		case $? in
		0) success "No dnf updates are available" ;;
		100)
			dnf check-update 2>/dev/null
			info "System updates were checked but not installed"
			print "Use --system to install them."
			;;
		*)
			warning "The dnf update check returned an error"
			add_warning "Check for dnf updates failed"
			;;
		esac
	fi
	;;
*)
	warning "No supported system package manager found (apt or dnf)"
	add_warning "No supported system package manager"
	;;
esac

#
# Homebrew
#

section "Homebrew"

if ! activate_homebrew; then
	if [[ "$BOOTSTRAP_TOOLS" == true ]]; then
		info "Homebrew is missing; running the first-run bootstrap"
		typeset -a INSTALL_ARGS
		INSTALL_ARGS=(--skip-zsh)
		[[ "$DRY_RUN" == true ]] && INSTALL_ARGS+=(--dry-run)

		run_step \
			"Install Homebrew and linux/Brewfile (linux/install.sh)" \
			"$SCRIPT_DIR/linux/install.sh" "${INSTALL_ARGS[@]}"

		activate_homebrew || true
	else
		warning "Homebrew is not installed"
		print "Install it with:"
		print "  ./linux/install.sh"
		print "  ./linux-update.zsh --bootstrap"
	fi
fi

if command_exists brew; then
	export HOMEBREW_NO_ENV_HINTS=1

	info "Homebrew: $(brew --version | head -n 1)"
	info "Prefix: $(brew --prefix)"

	run_step \
		"Update Homebrew metadata" \
		brew update

	print
	info "Checking for outdated Homebrew packages"

	if brew outdated; then
		success "Finished checking outdated Homebrew packages"
	else
		warning "Could not list outdated Homebrew packages"
		add_warning "Check outdated Homebrew packages"
	fi

	run_step \
		"Upgrade Homebrew packages" \
		brew upgrade

	run_step \
		"Remove unused Homebrew dependencies" \
		brew autoremove

	run_step \
		"Clean old Homebrew packages and cached downloads" \
		brew cleanup

	print
	info "Checking the Azure kubelogin tap"

	typeset TAP_DIR="$(azure_kubelogin_tap_dir)"

	if [[ -d "$TAP_DIR/.git" ]]; then
		if tap_is_shallow "$TAP_DIR"; then
			success "Azure kubelogin tap is a shallow clone"
		else
			warning "Azure kubelogin tap has full git history (~460 MB)"

			run_step \
				"Re-clone the Azure kubelogin tap shallow" \
				make_tap_shallow "$TAP_DIR"
		fi
	else
		info "Azure kubelogin tap is not installed"
	fi

	print
	info "Checking linux/Brewfile"

	if [[ -f "$BREWFILE" ]]; then
		if brew bundle check --file "$BREWFILE" >/dev/null 2>&1; then
			success "Everything in linux/Brewfile is installed"
		elif [[ "$BOOTSTRAP_TOOLS" == true ]]; then
			# Shallow first: brew bundle would otherwise tap the full 460 MB history.
			if [[ ! -d "$TAP_DIR/.git" ]]; then
				run_step \
					"Clone the Azure kubelogin tap shallow" \
					git clone --depth 1 -q "$AZURE_KUBELOGIN_TAP_URL" "$TAP_DIR"
			fi

			run_step \
				"Install missing Homebrew tools from linux/Brewfile" \
				brew bundle --file "$BREWFILE"
		else
			warning "linux/Brewfile has missing tools"
			print "Install them with:"
			print "  ./linux-update.zsh --bootstrap"
			add_warning "linux/Brewfile has missing tools"
		fi
	else
		warning "Missing $BREWFILE"
		add_warning "linux/Brewfile missing"
	fi

	print
	info "Checking for Homebrew formulae that should not be installed"

	typeset -a BREW_FORMULAE
	BREW_FORMULAE=(${(f)"$(brew list --formula --full-name 2>/dev/null)"})

	typeset -a BREW_FORBIDDEN
	BREW_FORBIDDEN=(
		${(M)BREW_FORMULAE:#(python|python@*|node|node@*|nvm|bash|pre-commit|rustup|rust)}
	)

	if ((${#BREW_FORBIDDEN[@]} > 0)); then
		for forbidden in "${BREW_FORBIDDEN[@]}"; do
			warning "Homebrew formula $forbidden is installed"

			typeset -a DEPENDENTS
			DEPENDENTS=(${(f)"$(brew uses --installed "$forbidden" 2>/dev/null || true)"})

			if ((${#DEPENDENTS[@]} > 0)); then
				print "  Required by: ${DEPENDENTS[*]}"
			else
				print "  Required by: no installed Homebrew formulae"
			fi
			add_warning "Homebrew formula $forbidden is installed"
		done

		print "Python is owned by uv, Node by nvm, Rust by rustup, bash by the system."
		print "Remove one that nothing needs with: brew uninstall <formula>"
	else
		success "No Homebrew python, node, nvm, bash or rust formulae"
	fi

	if ((${BREW_FORMULAE[(Ie)kubelogin]})); then
		warning "homebrew-core's kubelogin is installed (int128's OIDC plugin)"
		print "  Your kubeconfig needs Azure's: brew uninstall kubelogin"
		print "  then: brew install azure/kubelogin/kubelogin"
		add_warning "Wrong kubelogin formula installed"
	fi

	print
	info "Checking for apt packages that Homebrew replaced"

	typeset -a APT_LEFTOVERS
	APT_LEFTOVERS=()

	if [[ "$PM" == apt ]]; then
		for apt_package in "${APT_DUPLICATES[@]}"; do
			if apt_installed "$apt_package"; then
				APT_LEFTOVERS+=("$apt_package")
			fi
		done
	fi

	if ((${#APT_LEFTOVERS[@]} > 0)); then
		warning "apt still has copies of Homebrew-managed tools: ${APT_LEFTOVERS[*]}"
		print "They are shadowed on PATH and will go stale. Remove with:"
		print "  sudo apt remove ${APT_LEFTOVERS[*]}"
		add_warning "Duplicate apt packages: ${APT_LEFTOVERS[*]}"
	else
		success "No duplicate apt copies of Homebrew-managed tools"
	fi

	print
	info "Running Homebrew health check"

	if brew doctor; then
		success "Homebrew reports no significant problems"
	else
		warning "Homebrew reported issues; review the messages above"
		add_warning "Homebrew health check reported issues"
	fi
elif [[ "$DRY_RUN" == true && "$BOOTSTRAP_TOOLS" == true ]]; then
	info "Dry-run: remaining Homebrew steps skipped until brew exists"
else
	failure "Homebrew is not installed or is unavailable in PATH"
	add_failure "Homebrew unavailable"
fi

#
# Node / NVM
#

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -d "$NVM_DIR" ]]; then
	section "Node / NVM"

	# Share the shell's version selection and PATH rule without loading nvm.sh.
	if [[ -f "$SCRIPT_DIR/zsh/zsh/nvm-path.zsh" ]]; then
		source "$SCRIPT_DIR/zsh/zsh/nvm-path.zsh"
	fi

	if command_exists node; then
		typeset NODE_EXECUTABLE="$(node -p 'process.execPath')"
		if [[ "$NODE_EXECUTABLE" == "$NVM_DIR"/versions/node/*/bin/node ]]; then
			success "node: $(node --version) ($NODE_EXECUTABLE)"
		else
			warning "Node does not resolve to NVM: $NODE_EXECUTABLE"
			warning "Select an installed version with nvm alias default <version>"
			add_warning "Node does not resolve to NVM"
		fi
	else
		info "Node is not yet installed in NVM"
	fi

	if command_exists pnpm; then
		success "pnpm: $(pnpm --version)"
	fi
fi

#
# rustup / Cargo
#

section "rustup / Cargo"

if command_exists rustup; then
	info "rustup: $(rustup --version 2>/dev/null | head -n 1)"
	info "rustup executable: $(command -v rustup)"

	if [[ "$(command -v rustup)" == "$HOME/.cargo/bin/"* ]]; then
		success "rustup is the official rustup-init installation"
	elif [[ "$(command -v rustup)" == /home/linuxbrew/* ||
		"$(command -v rustup)" == /usr/* ]]; then
		warning "rustup resolves to a Homebrew or system installation"
		warning "This script expects the official rustup-init toolchain in ~/.cargo"
		add_warning "rustup resolves to Homebrew or the system"
	else
		warning "rustup resolves from an unexpected location"
		print "  $(command -v rustup)"
		add_warning "rustup executable location"
	fi

	print
	info "Active Rust toolchain"

	if rustup show; then
		success "Finished showing rustup toolchain"
	else
		warning "rustup could not show the active toolchain"
		add_warning "Show rustup toolchain"
	fi

	print

	run_step \
		"Update rustup and installed toolchains" \
		rustup update
else
	warning "rustup is unavailable in PATH; skipping Rust maintenance"
	print "Install it with --bootstrap, or manually:"
	print "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
	add_warning "rustup unavailable"
fi

#
# uv and Python
#

section "uv and Python"

if command_exists uv; then
	typeset UV_PATH="$(command -v uv)"

	info "uv: $(uv --version)"
	info "uv executable: $UV_PATH"

	print
	info "Verifying uv ownership"

	if [[ "$UV_PATH" == "$HOME/.local/bin/uv" ]]; then
		success "uv is the standalone installation in ~/.local/bin"

		run_step \
			"Update uv" \
			uv self update
	elif [[ "$UV_PATH" == /home/linuxbrew/* ]]; then
		success "uv is managed by Homebrew (updated by brew upgrade)"
	else
		warning "uv resolves from an unexpected location"
		print "  $UV_PATH"
		add_warning "uv ownership is unexpected"
	fi

	print
	info "Installed and discovered Python versions"

	if uv python list --only-installed; then
		success "Finished listing installed Python versions"
	else
		warning "uv could not list installed Python versions"
		add_warning "List uv Python installations"
	fi

	print

	run_step \
		"Upgrade uv-managed Python installations" \
		uv python upgrade

	run_step \
		"Install or update Python $UV_DEFAULT_PYTHON_VERSION" \
		uv python install "$UV_DEFAULT_PYTHON_VERSION" --default

	print
	info "Checking Python discovered by uv from the home directory"

	UV_DEFAULT_PYTHON="$(
		cd "$HOME" &&
			VIRTUAL_ENV= \
				UV_PROJECT_ENVIRONMENT= \
				uv python find 2>/dev/null
	)" || UV_DEFAULT_PYTHON=""

	if [[ -n "$UV_DEFAULT_PYTHON" ]]; then
		info "Python discovered by uv from \$HOME:"
		print "  $UV_DEFAULT_PYTHON"

		UV_DEFAULT_VERSION="$(
			"$UV_DEFAULT_PYTHON" \
				-c 'import sys; print(".".join(map(str, sys.version_info[:2])))' \
				2>/dev/null || true
		)"

		case "$UV_DEFAULT_VERSION" in
		"$UV_DEFAULT_PYTHON_VERSION")
			success \
				"uv discovers Python $UV_DEFAULT_PYTHON_VERSION from \$HOME"
			;;
		"")
			warning "Could not determine the discovered Python version"
			add_warning "Could not determine uv Python version"
			;;
		*)
			info "uv discovers Python $UV_DEFAULT_VERSION from \$HOME"
			warning \
				"Configured default version is $UV_DEFAULT_PYTHON_VERSION"
			print "Install it with:"
			print "  uv python install $UV_DEFAULT_PYTHON_VERSION --default"
			add_warning \
				"uv discovered Python $UV_DEFAULT_VERSION instead of $UV_DEFAULT_PYTHON_VERSION"
			;;
		esac
	else
		warning "uv could not find a Python interpreter from \$HOME"
		print "Install the desired default with:"
		print "  uv python install $UV_DEFAULT_PYTHON_VERSION --default"
		add_warning "uv Python unavailable"
	fi

	print
	info "Installed uv-managed command-line tools"

	if uv tool list; then
		success "Finished listing uv-managed tools"
	else
		warning "uv could not list installed tools"
		add_warning "List uv-managed tools"
	fi

	print

	run_step \
		"Upgrade uv-managed command-line tools" \
		uv tool upgrade --all
else
	warning "uv is unavailable in PATH"
	warning "Skipping uv-managed Python and Python tool maintenance"
	if [[ "$BOOTSTRAP_TOOLS" == true ]]; then
		warning "uv will be installed during the requested bootstrap"
	else
		print "Install uv with:"
		print "  ./linux/install.sh"
		add_failure "uv unavailable"
	fi
fi

#
# Developer-tool bootstrap
#

section "Developer-tool bootstrap"

if [[ "$BOOTSTRAP_TOOLS" == true ]]; then
	#
	# rustup-managed Rust toolchain
	#

	if command_exists rustup; then
		success "rustup is already installed"
	else
		info "Installing rustup via the official installer"
		info "Shell rc files are not modified; PATH is owned by the zsh config"

		install_official_rustup() {
			curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
				sh -s -- -y --no-modify-path \
					--default-toolchain stable \
					--profile default
		}

		run_step \
			"Install rustup (official installer, no PATH mutation)" \
			install_official_rustup

		if [[ -x "$HOME/.cargo/bin/cargo" && -f "$HOME/.cargo/env" ]]; then
			. "$HOME/.cargo/env"
		elif [[ -x "$HOME/.cargo/bin/cargo" ]]; then
			path=("$HOME/.cargo/bin" $path)
		fi

		if command_exists rustup; then
			success "rustup is now on PATH: $(command -v rustup)"
		else
			warning "rustup installed but is not yet on PATH in this session"
			warning "Open a new shell after bootstrap finishes"
			add_warning "rustup not on PATH after install"
		fi
	fi

	#
	# uv-managed default Python
	#

	print

	if command_exists uv; then
		run_step \
			"Install Python $UV_DEFAULT_PYTHON_VERSION as the uv default" \
			uv python install "$UV_DEFAULT_PYTHON_VERSION" --default

		run_step \
			"Set global uv Python to $UV_DEFAULT_PYTHON_VERSION" \
			uv python pin --global "$UV_DEFAULT_PYTHON_VERSION"
	else
		warning "Cannot install the default Python because uv is unavailable"
		warning "Run ./linux/install.sh, then run this script again"
		add_failure "uv Python bootstrap"
	fi

	#
	# uv-managed Python CLI tools
	#

	print

	if command_exists uv; then
		info "Checking Python command-line tools managed by uv"

		typeset -a INSTALLED_UV_TOOLS

		INSTALLED_UV_TOOLS=(
			"${(@f)$(uv tool list 2>/dev/null |
				sed -n 's/^\([^[:space:]]*\) .*/\1/p')}"
		)

		for uv_tool in "${UV_TOOLS[@]}"; do
			if ((${INSTALLED_UV_TOOLS[(Ie)$uv_tool]})); then
				success "$uv_tool is installed through uv"
			else
				run_step \
					"Install uv tool: $uv_tool" \
					uv tool install "$uv_tool"
			fi
		done
	else
		warning "Cannot bootstrap Python tools because uv is unavailable"
		add_failure "uv developer-tool bootstrap"
	fi
else
	info "Developer-tool bootstrap was not requested"
	print "Use --bootstrap to install Homebrew tools, rustup, Python and uv tools."

	print
	info "Homebrew tools (linux/Brewfile):"
	print "  ${BREW_BINARIES[*]}"

	print
	info "Rust toolchain:"
	print "  rustup (official installer → ~/.cargo)"

	print
	info "uv default Python:"
	print "  Python $UV_DEFAULT_PYTHON_VERSION"

	print
	info "uv bootstrap tools:"
	print "  ${UV_TOOLS[*]}"
fi

#
# Cleanup
#

section "Cleanup"

if [[ "$CLEANUP" == true ]]; then
	typeset USED_BEFORE_KB="$(fs_used_kb)"

	warning "Cleaning up"
	warning "Your password may be requested"
	prime_sudo

	print
	info "System packages"

	case "$PM" in
	apt)
		run_step "Clean the apt package cache" sudo apt-get clean
		run_step "Remove obsolete apt package files" sudo apt-get autoclean
		run_step "Remove unused apt packages and their configs" sudo apt-get autoremove --purge -y
		run_step "Purge residual package configs" purge_residual_configs
		;;
	dnf)
		run_step "Clean dnf caches" sudo dnf clean all
		run_step "Remove unused dnf packages" sudo dnf autoremove -y
		;;
	esac

	print
	info "Logs and temporary files"

	if command_exists journalctl && [[ -d /run/systemd/system ]]; then
		run_step "Vacuum the systemd journal (older than $JOURNAL_MAX_AGE)" \
			sudo journalctl --vacuum-time="$JOURNAL_MAX_AGE"
	fi

	run_step "Delete rotated logs older than $LOG_MAX_AGE_DAYS days" sweep_old_logs
	run_step "Delete /tmp entries older than $TMP_MAX_AGE_DAYS day(s)" sweep_old /tmp "$TMP_MAX_AGE_DAYS"
	run_step "Delete /var/tmp entries older than 30 days" sweep_old /var/tmp 30

	print
	info "Package-manager caches"

	if command_exists brew; then
		run_step "Prune the Homebrew cache" brew cleanup --prune=all
	fi

	if command_exists uv; then
		# prune drops unused entries; the cache itself stays (see CACHE_KEEP).
		run_step "Prune the uv cache" uv cache prune
	fi

	if command_exists npm; then
		run_step "Clean the npm cache" npm cache clean --force
	fi

	if command_exists pip; then
		run_step "Purge the pip cache" pip cache purge
	fi

	if [[ "$DEEP_CLEANUP" == true ]]; then
		print
		info "Deep cleanup (~/.cache keeps: ${CACHE_KEEP[*]})"

		sweep_user_cache
		sweep_npx_cache
		sweep_azmcp
		sweep_claude_versions
		sweep_copilot_sessions
	fi

	print
	info "Trimming free space"

	run_step "Trim unused filesystem blocks" trim_free_space

	if [[ "$DRY_RUN" != true ]]; then
		typeset USED_AFTER_KB="$(fs_used_kb)"

		print
		info "Root filesystem used: $(human_kb "$USED_BEFORE_KB") → $(human_kb "$USED_AFTER_KB")"
		df -h / | sed 's/^/  /'
	fi

	if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
		print
		info "The virtual disk shrinks on the Windows side:"
		print "  A sparse VHD (wsl --manage $WSL_DISTRO_NAME --set-sparse true) reclaims the trimmed blocks"
		print "  automatically. Otherwise: wsl --shutdown, then diskpart: compact vdisk."
	fi
else
	info "Reclaimable space (nothing was removed):"

	if [[ "$PM" == apt ]]; then
		report_size "apt package cache" "$(path_size /var/cache/apt/archives)"
	elif [[ "$PM" == dnf ]]; then
		report_size "dnf cache" "$(path_size /var/cache/dnf)"
	fi

	if command_exists journalctl && [[ -d /run/systemd/system ]]; then
		report_size "systemd journal" "$(journalctl --disk-usage 2>/dev/null | sed -n 's/.*take up \([^ ]*\) .*/\1/p')"
	fi

	report_size "/tmp (older than $TMP_MAX_AGE_DAYS day)" \
		"$(find /tmp -mindepth 1 -xdev -mtime "+$TMP_MAX_AGE_DAYS" 2>/dev/null | wc -l) entries"

	if command_exists brew; then
		report_size "Homebrew cache" "$(path_size "$(brew --cache)")"
	fi

	if command_exists uv; then
		report_size "uv cache (kept, pruned)" "$(path_size "$(uv cache dir 2>/dev/null)")"
	fi

	report_size "npm cache (~/.npm)" "$(path_size "$HOME/.npm")"
	report_size "user cache (~/.cache)" "$(path_size "$HOME/.cache")"
	report_size "Copilot sessions" "$(path_size "$HOME/.copilot/session-state")"
	report_size "Claude Code versions" "$(path_size "$HOME/.local/share/claude/versions")"

	print
	info "Cleanup was not requested"
	print "Use --cleanup to free this space and trim the disk (sudo), --deep to also"
	print "sweep ~/.cache, the npx cache, old Claude versions and idle Copilot sessions."
fi

#
# Environment diagnostics
#

section "Environment diagnostics"

info "PATH order:"

for path_entry in $path; do
	print "  $path_entry"
done

print

typeset BREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
typeset -i PATH_POSITION=0
typeset -i LOCAL_BIN_POSITION=0
typeset -i CARGO_BIN_POSITION=0
typeset -i USR_BIN_POSITION=0
typeset -i BREW_BIN_POSITION=0
typeset -i NVM_BIN_POSITION=0

for path_entry in "${path[@]}"; do
	((PATH_POSITION++))

	if [[ "$path_entry" == "$HOME/.local/bin" &&
		"$LOCAL_BIN_POSITION" -eq 0 ]]; then
		LOCAL_BIN_POSITION=$PATH_POSITION
	fi

	if [[ "$path_entry" == "$HOME/.cargo/bin" &&
		"$CARGO_BIN_POSITION" -eq 0 ]]; then
		CARGO_BIN_POSITION=$PATH_POSITION
	fi

	if [[ "$path_entry" == "$BREW_PREFIX/bin" &&
		"$BREW_BIN_POSITION" -eq 0 ]]; then
		BREW_BIN_POSITION=$PATH_POSITION
	fi

	if [[ "$path_entry" == "$NVM_DIR"/versions/node/*/bin &&
		"$NVM_BIN_POSITION" -eq 0 ]]; then
		NVM_BIN_POSITION=$PATH_POSITION
	fi

	if [[ "$path_entry" == "/usr/bin" &&
		"$USR_BIN_POSITION" -eq 0 ]]; then
		USR_BIN_POSITION=$PATH_POSITION
	fi
done

if ((LOCAL_BIN_POSITION > 0)); then
	success "~/.local/bin is present in PATH"

	if ((USR_BIN_POSITION == 0)); then
		warning "/usr/bin was not found in PATH"
		add_warning "/usr/bin missing from PATH"
	elif ((LOCAL_BIN_POSITION < USR_BIN_POSITION)); then
		success "~/.local/bin appears before /usr/bin"
	else
		warning "~/.local/bin should appear before /usr/bin"
		add_warning "~/.local/bin PATH ordering"
	fi

	if ((BREW_BIN_POSITION > 0 && LOCAL_BIN_POSITION > BREW_BIN_POSITION)); then
		warning "~/.local/bin should appear before Homebrew so uv's python wins"
		add_warning "~/.local/bin PATH ordering relative to Homebrew"
	fi
else
	warning "~/.local/bin is missing from PATH"
	print 'Add the following to ~/.zsh/.zshenv:'
	print '  path=("$HOME/.local/bin" $path)'
	add_warning "~/.local/bin missing from PATH"
fi

if ((BREW_BIN_POSITION > 0)); then
	if ((USR_BIN_POSITION > 0 && BREW_BIN_POSITION < USR_BIN_POSITION)); then
		success "Homebrew appears before /usr/bin"
	else
		warning "Homebrew should appear before /usr/bin so brew tools win"
		add_warning "Homebrew PATH ordering"
	fi

	if ((NVM_BIN_POSITION > 0 && NVM_BIN_POSITION > BREW_BIN_POSITION)); then
		warning "NVM's node should appear before Homebrew"
		add_warning "NVM PATH ordering relative to Homebrew"
	fi
fi

print

if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
	success "cargo is installed at ~/.cargo/bin/cargo"

	if ((CARGO_BIN_POSITION > 0)); then
		success "~/.cargo/bin is present in PATH"

		if ((BREW_BIN_POSITION > 0 && CARGO_BIN_POSITION > BREW_BIN_POSITION)); then
			warning "~/.cargo/bin should appear before Homebrew so rustup wins"
			add_warning "~/.cargo/bin PATH ordering"
		fi
	else
		warning "~/.cargo/bin is missing from PATH even though cargo is installed"
		print "The zsh config only adds it when ~/.cargo/bin/cargo is executable."
		add_warning "~/.cargo/bin missing from PATH"
	fi

	if command_exists cargo; then
		success "cargo: $(cargo --version 2>&1)"
		info "cargo executable: $(command -v cargo)"
	else
		warning "cargo is installed but is not resolving on PATH"
		add_warning "cargo not resolving on PATH"
	fi

	if command_exists rustc; then
		success "rustc: $(rustc --version 2>&1)"
		info "rustc executable: $(command -v rustc)"
	else
		warning "rustc is unavailable"
		add_warning "rustc unavailable"
	fi
else
	if ((CARGO_BIN_POSITION > 0)); then
		warning "~/.cargo/bin is on PATH but cargo is not installed"
		warning "PATH should only include ~/.cargo/bin when cargo exists"
		add_warning "~/.cargo/bin on PATH without cargo"
	else
		success "~/.cargo/bin is not on PATH (cargo is not installed)"
	fi
fi

print
info "Homebrew-managed tools resolve into $BREW_PREFIX:"

for brew_binary in "${BREW_BINARIES[@]}"; do
	typeset resolved="$(command -v "$brew_binary" 2>/dev/null || true)"

	if [[ -z "$resolved" ]]; then
		warning "$brew_binary is not installed"
		add_warning "$brew_binary missing"
	elif [[ "$resolved" == "$BREW_PREFIX"/* ]]; then
		success "$brew_binary → $resolved"
	else
		warning "$brew_binary resolves to $resolved, not Homebrew"
		print "  Remove the old copy so brew upgrade updates what you run."
		add_warning "$brew_binary resolves outside Homebrew ($resolved)"
	fi
done

if command_exists kubelogin; then
	if kubelogin --help 2>&1 | grep -q convert-kubeconfig; then
		success "kubelogin is Azure's (supports convert-kubeconfig)"
	else
		warning "kubelogin is not Azure's; AKS kubeconfigs will not authenticate"
		add_warning "kubelogin is not the Azure kubelogin"
	fi
fi

if command_exists brew; then
	print
	info "Checking that bash shells also see Homebrew (agent tools such as Copilot CLI run bash):"

	typeset BASH_BREW="$(env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc 'command -v brew' 2>/dev/null || true)"

	if [[ -n "$BASH_BREW" ]]; then
		success "bash -l finds brew ($BASH_BREW)"
	else
		warning "bash login shells do not see Homebrew"
		print "  Fix with: ./linux/install.sh --bash-only"
		print "  Processes that were already running keep their old PATH; restart them."
		add_warning "bash does not see Homebrew"
	fi
fi

print

if command_exists git; then
	success "git: $(git --version)"
else
	warning "git is unavailable"
	add_failure "git unavailable"
fi

if command_exists gh; then
	success "GitHub CLI: $(gh --version | head -n 1)"
else
	warning "GitHub CLI is unavailable"
	add_warning "GitHub CLI unavailable"
fi

if [[ -d "$NVM_DIR" ]]; then
	print
	if command_exists node; then
		success "node: $(node --version) ($(command -v node))"
	fi
	if command_exists pnpm; then
		success "pnpm: $(pnpm --version)"
	fi
fi

if command_exists uv; then
	print

	info "uv executable: $(command -v uv)"

	print

	if command_exists python; then
		success "python: $(command -v python)"
		success "python version: $(python --version 2>&1)"
	else
		warning "The generic python command is unavailable"
		warning "Install a uv-managed default Python with:"
		print "  uv python install $UV_DEFAULT_PYTHON_VERSION --default"
		add_warning "Generic python command unavailable"
	fi

	print

	if command_exists python3; then
		success "python3: $(command -v python3)"
		success "python3 version: $(python3 --version 2>&1)"

		case "$(command -v python3)" in
		"$HOME/.local/bin/"*)
			success "python3 resolves through ~/.local/bin"
			;;
		/home/linuxbrew/*)
			warning "python3 currently resolves to a Homebrew installation"
			warning "Ensure ~/.local/bin appears before $BREW_PREFIX/bin"
			add_warning "python3 resolves to Homebrew"
			;;
		/usr/bin/python3)
			warning "python3 currently resolves to the system Python"
			warning "Install a uv default Python or fix PATH ordering"
			print "  uv python install $UV_DEFAULT_PYTHON_VERSION --default"
			add_warning "python3 resolves to the system Python"
			;;
		*)
			warning "python3 resolves to an unexpected location"
			print "  $(command -v python3)"
			add_warning "python3 resolves to an unexpected location"
			;;
		esac

		typeset PYTHON3_VERSION="$(
			python3 \
				-c 'import sys; print(".".join(map(str, sys.version_info[:2])))' \
				2>/dev/null || true
		)"

		if [[ "$PYTHON3_VERSION" == "$UV_DEFAULT_PYTHON_VERSION" ]]; then
			success \
				"python3 matches configured Python $UV_DEFAULT_PYTHON_VERSION"
		elif [[ -n "$PYTHON3_VERSION" ]]; then
			warning \
				"python3 is $PYTHON3_VERSION; configured default is $UV_DEFAULT_PYTHON_VERSION"
			add_warning "python3 version differs from configured default"
		fi
	else
		warning "python3 is unavailable"
		add_failure "python3 unavailable"
	fi

	for uv_tool in "${UV_TOOLS[@]}"; do
		print

		if command_exists "$uv_tool"; then
			success "$uv_tool: $("$uv_tool" --version 2>&1 | head -n 1)"
			info "$uv_tool executable: $(command -v "$uv_tool")"

			case "$(command -v "$uv_tool")" in
			"$HOME/.local/bin/"*)
				success "$uv_tool is exposed through ~/.local/bin"
				;;
			/home/linuxbrew/*)
				warning "$uv_tool is resolving to Homebrew"
				add_warning "$uv_tool resolves to Homebrew"
				;;
			*)
				warning "$uv_tool resolves from an unexpected location"
				print "  $(command -v "$uv_tool")"
				add_warning "$uv_tool executable location"
				;;
			esac
		else
			warning "$uv_tool is unavailable"
			print "Install it with:"
			print "  uv tool install $uv_tool"
			add_warning "$uv_tool unavailable"
		fi
	done
fi

if command_exists brew; then
	print
	info "Homebrew prefix: $(brew --prefix)"
fi

#
# WSL
#

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
	section "WSL"

	info "Root filesystem:"
	df -h / | sed 's/^/  /'

	typeset -i ROOT_USED_PERCENT="$(df --output=pcent / | sed -n '2s/[^0-9]//gp')"

	if ((ROOT_USED_PERCENT >= 85)); then
		warning "The root filesystem is ${ROOT_USED_PERCENT} percent full"
		add_warning "WSL root filesystem is ${ROOT_USED_PERCENT} percent full"
	else
		success "The root filesystem is ${ROOT_USED_PERCENT} percent full"
	fi

	print
	info "The WSL virtual disk only shrinks on the Windows side:"
	print "  Linux:   sudo fstrim -av   (./linux-update.zsh --cleanup does this)"
	print "  Windows: wsl --manage $WSL_DISTRO_NAME --set-sparse true   (one-time; then it reclaims automatically)"

	print

	# Zscaler's DNS tunnel black-holes AAAA queries, so every lookup stalls ~20 s
	# unless glibc skips them. The zsh config sets this in ~/.zsh/.zshenv.
	if [[ " ${RES_OPTIONS:-} " == *" no-aaaa "* ]]; then
		success "RES_OPTIONS includes no-aaaa (WSL DNS workaround)"
	else
		warning "RES_OPTIONS does not include no-aaaa"
		print "  Lookups may stall ~20 s behind Zscaler; re-deploy the zsh config."
		add_warning "RES_OPTIONS missing no-aaaa"
	fi

	if [[ -n "${SSL_CERT_FILE:-}" ]]; then
		success "SSL_CERT_FILE is set ($SSL_CERT_FILE)"
	else
		warning "SSL_CERT_FILE is not set; downloads may fail behind Zscaler"
		add_warning "SSL_CERT_FILE not set"
	fi
fi

#
# Summary
#

section "Summary"

if ((${#WARNINGS[@]} > 0)); then
	warning "Maintenance completed with ${#WARNINGS[@]} warning(s):"

	for item in "${WARNINGS[@]}"; do
		print "  - $item"
	done

	print
fi

if ((${#FAILURES[@]} == 0)); then
	success "Linux maintenance finished without command failures"

	if ((${#WARNINGS[@]} > 0)); then
		warning "Review the warnings above when convenient"
	else
		success "No warnings were detected"
	fi
else
	failure "Linux maintenance finished with ${#FAILURES[@]} failure(s):"

	for item in "${FAILURES[@]}"; do
		print "  - $item"
	done

	print
	failure "Review the failures above for details"

	exit 1
fi

print
