#!/bin/zsh

set -u
set -o pipefail

autoload -U colors && colors

#
# Configuration
#

typeset -a FAILURES
typeset -a WARNINGS
typeset -a DEV_TOOLS
typeset -a OPTIONAL_TOOLS
typeset -a UV_TOOLS

typeset UV_PATH=""
typeset UV_DEFAULT_PYTHON=""
typeset UV_DEFAULT_VERSION=""
typeset PYTHON3_EXECUTABLE=""

typeset MISE_UV_ACTIVE=false
typeset MISE_UV_INSTALLED=false

FAILURES=()
WARNINGS=()

UPDATE_MACOS=false
BOOTSTRAP_TOOLS=false
PRUNE=false
DRY_RUN=false

# Python version exposed globally as:
#
#   ~/.local/bin/python
#   ~/.local/bin/python3
#   ~/.local/bin/python3.13
#
# Python 3.13 is used because some AI/transcription tools do not yet
# support Python 3.14.
UV_DEFAULT_PYTHON_VERSION="3.13"

# Native command-line tools managed by Homebrew.
#
# uv itself is installed and updated through Homebrew.
#
# Do not add Python applications such as pre-commit here.
DEV_TOOLS=(
	git
	gh
	jq
	yq
	ripgrep
	fd
	fzf
	bat
	eza
	zoxide
	direnv
	shellcheck
	shfmt
	git-delta
	just
	hyperfine
	uv
)

# Python command-line applications managed by uv.
UV_TOOLS=(
	pre-commit
	ruff
)

# Useful tools that are not installed automatically.
OPTIONAL_TOOLS=(
	tldr
	dust
	duf
	bottom
	gitleaks
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
uv_is_homebrew_managed() {
  local uv_path="$1"
  local brew_uv_link
  local brew_uv_opt

  command_exists brew || return 1
  brew list --formula uv >/dev/null 2>&1 || return 1

  brew_uv_link="$(brew --prefix)/bin/uv"
  brew_uv_opt="$(brew --prefix uv)/bin/uv"

  [[ "$uv_path" == "$brew_uv_link" ||
    "$uv_path" == "$brew_uv_opt" ]]
}

usage() {
	cat <<'HELP'
Usage:
  ~/mac-update.zsh [options]

Options:
  --macos       Install recommended macOS updates.
  --bootstrap   Install missing developer tools and the default Python.
  --prune       Remove unused mise tool versions.
  --dry-run     Print mutating commands without running them.
  --help, -h    Show this help.

Examples:
  ~/mac-update.zsh
  ~/mac-update.zsh --dry-run
  ~/mac-update.zsh --bootstrap
  ~/mac-update.zsh --macos
  ~/mac-update.zsh --macos --bootstrap --prune
  ~/mac-update.zsh --macos --bootstrap --prune --dry-run

Routine behavior:
  - Checks for available macOS updates.
  - Updates and upgrades Homebrew packages.
  - Updates tools managed by mise.
  - Verifies that uv is managed by Homebrew rather than mise.
  - Upgrades uv-managed Python installations.
  - Upgrades Python CLI applications managed by uv.
  - Runs Homebrew, mise, uv, Python, and environment health checks.

Bootstrap behavior:
  - Installs native developer tools through Homebrew.
  - Installs the uv executable through Homebrew.
  - Installs Python 3.13 through uv as the global/default Python.
  - Installs Python CLI tools such as pre-commit and ruff through uv.

Tool ownership:
  Homebrew  Native command-line utilities and the uv executable
  mise      Node.js, Go, Java, Terraform, and other non-Python runtimes
  uv        Python installations and Python CLI applications
  macOS     /usr/bin/python3; this is never modified
HELP
}

#
# Argument parsing
#

for arg in "$@"; do
	case "$arg" in
	--macos)
		UPDATE_MACOS=true
		;;
	--bootstrap)
		BOOTSTRAP_TOOLS=true
		;;
	--prune)
		PRUNE=true
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

#
# System information
#

print
info "Starting Mac maintenance"

print "Date:         $(date)"
print "Computer:     $(scutil --get ComputerName 2>/dev/null || hostname)"
print "macOS:        $(sw_vers -productVersion)"
print "Build:        $(sw_vers -buildVersion)"
print "Architecture: $(uname -m)"
print "Shell:        $SHELL"

if [[ "$DRY_RUN" == true ]]; then
	print
	warning "Dry-run mode is enabled"
	warning "Checks will run, but mutating commands will only be printed"
fi

#
# macOS updates
#

section "macOS updates"

info "Checking for available macOS updates"

# Listing updates does not modify the system.
if /usr/sbin/softwareupdate --list; then
	success "Finished checking for macOS updates"
else
	warning "The macOS update check returned a nonzero status"
	add_warning "Check for macOS updates returned a nonzero status"
fi

if [[ "$UPDATE_MACOS" == true ]]; then
	print
	warning "Installing recommended macOS updates"
	warning "Your password may be requested"
	warning "A restart may be required"

	run_step \
		"Install recommended macOS updates" \
		sudo /usr/sbin/softwareupdate --install --recommended
else
	print
	info "macOS updates were checked but not installed"
	print "Use --macos to install recommended updates."
fi

#
# Homebrew
#

section "Homebrew"

if command_exists brew; then
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
		"Upgrade Homebrew packages and applications" \
		brew upgrade

	run_step \
		"Remove unused Homebrew dependencies" \
		brew autoremove

	run_step \
		"Clean old Homebrew packages and cached downloads" \
		brew cleanup

	print
	info "Checking Homebrew ownership of uv"

	if brew list --formula uv >/dev/null 2>&1; then
		success "uv is installed through Homebrew"

		if [[ -x "$(brew --prefix uv)/bin/uv" ]]; then
			info "Homebrew uv executable: $(brew --prefix uv)/bin/uv"
		fi
	else
		warning "uv is not currently installed through Homebrew"
		print "Install it with:"
		print "  brew install uv"
		add_warning "uv is not installed through Homebrew"
	fi

	print
	info "Checking for Python applications installed through Homebrew"

	if brew list --formula pre-commit >/dev/null 2>&1; then
		warning "Homebrew pre-commit is installed"
		warning "This can cause Homebrew Python to be installed as a dependency"
		warning "Recommended migration:"
		print "  brew uninstall pre-commit"
		print "  uv tool install pre-commit"
		add_warning "Homebrew pre-commit should be migrated to uv"
	else
		success "pre-commit is not managed by Homebrew"
	fi

	print
	info "Checking for Homebrew-managed Python installations"

	typeset -a BREW_PYTHONS

	BREW_PYTHONS=(
		${(@f)"$(brew list --formula 2>/dev/null |
			grep -E '^python(@|$)' || true)"}
	)

	if ((${#BREW_PYTHONS[@]} > 0)); then
		warning "Homebrew-managed Python formulae were found:"

		for python_formula in "${BREW_PYTHONS[@]}"; do
			[[ -z "$python_formula" ]] && continue

			print "  - $python_formula"

			typeset -a PYTHON_DEPENDENTS

			PYTHON_DEPENDENTS=(
				${(@f)"$(brew uses --installed "$python_formula" 2>/dev/null ||
					true)"}
			)

			if ((${#PYTHON_DEPENDENTS[@]} > 0)); then
				print "    Required by: ${PYTHON_DEPENDENTS[*]}"
			else
				print "    Required by: no installed Homebrew formulae"
			fi
		done

		warning "These Python formulae were not removed automatically"
		warning "Some Homebrew packages may require them as dependencies"
		add_warning "Homebrew-managed Python formulae were found"
	else
		success "No Homebrew-managed Python formulae were found"
	fi

	print
	info "Running Homebrew health check"

	if brew doctor; then
		success "Homebrew reports no significant problems"
	else
		warning "Homebrew reported issues; review the messages above"
		add_warning "Homebrew health check reported issues"
	fi
else
	failure "Homebrew is not installed or is unavailable in PATH"
	add_failure "Homebrew unavailable"
fi

#
# mise
#

section "mise"

if command_exists mise; then
	info "mise: $(mise --version)"

	print
	info "Checking for mise-managed uv"

	MISE_UV_ACTIVE=false
	MISE_UV_INSTALLED=false

	if mise current 2>/dev/null | grep -Eq '^uv[[:space:]]'; then
		MISE_UV_ACTIVE=true
	fi

	if [[ -d "$HOME/.local/share/mise/installs/uv" ]]; then
		MISE_UV_INSTALLED=true
	fi

	if [[ "$MISE_UV_ACTIVE" == true ]]; then
		warning "uv is currently active through mise"
		add_warning "uv is active through mise"
	fi

	if [[ "$MISE_UV_INSTALLED" == true ]]; then
		warning "A mise-managed uv installation exists"
		print "  $HOME/.local/share/mise/installs/uv"
		add_warning "A mise-managed uv installation remains installed"
	fi

	if [[ "$MISE_UV_ACTIVE" == true ||
		"$MISE_UV_INSTALLED" == true ]]; then
		print
		warning "Recommended migration commands:"
		print "  mise use -g --remove uv"
		print "  mise uninstall uv --all"
		print "  brew install uv"
	else
		success "uv is neither configured nor installed through mise"
	fi

	print
	info "Showing outdated mise-managed tools"

	if mise outdated; then
		success "Finished checking mise-managed tools"
	else
		warning "mise could not determine outdated tools"
		add_warning "Check mise-managed tools"
	fi

	print

	run_step \
		"Upgrade mise-managed tools" \
		mise upgrade

	if [[ "$PRUNE" == true ]]; then
		run_step \
			"Prune unused mise tool versions" \
			mise prune --yes
	else
		info "Skipping mise pruning"
		print "Use --prune to remove unused mise tool versions."
	fi

	print
	info "Verifying mise configuration"

	if mise doctor; then
		success "mise configuration check completed"
	else
		warning "mise reported configuration issues"
		add_warning "mise health check reported issues"
	fi
else
	warning "mise is unavailable in PATH; skipping mise maintenance"
	add_warning "mise unavailable"
fi

#
# uv and Python
#

section "uv and Python"

if command_exists uv; then
	UV_PATH="$(command -v uv)"

	info "uv: $(uv --version)"
	info "uv executable: $UV_PATH"

	print
	info "Verifying uv ownership"

	BREW_UV_LINK="$(brew --prefix)/bin/uv"
	BREW_UV_OPT="$(brew --prefix uv)/bin/uv"

	if command_exists brew &&
		brew list --formula uv >/dev/null 2>&1 &&
		[[ "$UV_PATH" == "$BREW_UV_LINK" ||
			"$UV_PATH" == "$BREW_UV_OPT" ]]; then
		success "uv is installed and managed by Homebrew"
	elif [[ "$UV_PATH" == "$HOME/.local/share/mise/"* ]]; then
		warning "uv resolves to a mise-managed installation"
		print "  $UV_PATH"
		add_warning "uv resolves to mise"
	elif [[ "$UV_PATH" == "$HOME/.local/bin/uv" ]]; then
		warning "uv resolves to a standalone user installation"
		print "  $UV_PATH"

		if command_exists brew; then
			print "Expected Homebrew executable:"
			print "  $(brew --prefix)/bin/uv"
		fi

		add_warning "uv does not resolve to Homebrew"
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
		3.14)
			warning "uv discovers Python 3.14 from \$HOME"
			warning "Some tools such as WhisperX may not support Python 3.14"
			print "Install the recommended default with:"
			print "  uv python install $UV_DEFAULT_PYTHON_VERSION --default"
			add_warning "uv discovers Python 3.14 from the home directory"
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
	print "Install uv with:"
	print "  brew install uv"
	add_failure "uv unavailable"
fi

#
# Developer-tool bootstrap
#

section "Developer-tool bootstrap"

if [[ "$BOOTSTRAP_TOOLS" == true ]]; then
	#
	# Homebrew-managed native tools and uv
	#

	if command_exists brew; then
		typeset -a MISSING_BREW_TOOLS

		MISSING_BREW_TOOLS=()

		info "Checking developer tools managed by Homebrew"

		for local_tool in "${DEV_TOOLS[@]}"; do
			if brew list --formula "$local_tool" >/dev/null 2>&1; then
				success "$local_tool is installed through Homebrew"
			else
				MISSING_BREW_TOOLS+=("$local_tool")
			fi
		done

		if ((${#MISSING_BREW_TOOLS[@]} > 0)); then
			print
			info "Missing Homebrew tools: ${MISSING_BREW_TOOLS[*]}"

			run_step \
				"Install missing Homebrew developer tools" \
				brew install "${MISSING_BREW_TOOLS[@]}"
		else
			print
			success "All curated Homebrew developer tools are installed"
		fi
	else
		warning "Cannot bootstrap native tools because Homebrew is unavailable"
		add_failure "Homebrew developer-tool bootstrap"
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
		warning "Run the script again after Homebrew installs uv"
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

				run_step \
					"Upgrade uv tool: $uv_tool" \
					uv tool upgrade "$uv_tool"
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

	print
	info "Optional tools not installed automatically:"
	print "  ${OPTIONAL_TOOLS[*]}"
else
	info "Developer-tool bootstrap was not requested"
	print "Use --bootstrap to install the curated tool collection."

	print
	info "Homebrew bootstrap tools:"
	print "  ${DEV_TOOLS[*]}"

	print
	info "uv default Python:"
	print "  Python $UV_DEFAULT_PYTHON_VERSION"

	print
	info "uv bootstrap tools:"
	print "  ${UV_TOOLS[*]}"

	print
	info "Optional tools:"
	print "  ${OPTIONAL_TOOLS[*]}"
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

typeset -i PATH_POSITION=0
typeset -i LOCAL_BIN_POSITION=0
typeset -i USR_BIN_POSITION=0

for path_entry in "${path[@]}"; do
	((PATH_POSITION++))

	if [[ "$path_entry" == "$HOME/.local/bin" &&
		"$LOCAL_BIN_POSITION" -eq 0 ]]; then
		LOCAL_BIN_POSITION=$PATH_POSITION
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
else
	warning "~/.local/bin is missing from PATH"
	print 'Add the following to ~/.zshrc:'
	print '  export PATH="$HOME/.local/bin:$PATH"'
	add_warning "~/.local/bin missing from PATH"
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

if command_exists mise; then
	print
	info "Active mise tools:"

	if ! mise current; then
		warning "Could not display active mise tools"
		add_warning "Display active mise tools"
	fi
fi

if command_exists uv; then
	print

	UV_PATH="$(command -v uv)"

	info "uv executable: $UV_PATH"

	BREW_UV_LINK="$(brew --prefix)/bin/uv"
	BREW_UV_OPT="$(brew --prefix uv)/bin/uv"

	if command_exists brew &&
		brew list --formula uv >/dev/null 2>&1 &&
		[[ "$UV_PATH" == "$BREW_UV_LINK" ||
			"$UV_PATH" == "$BREW_UV_OPT" ]]; then
		success "uv is installed and managed by Homebrew"
	elif [[ "$UV_PATH" == "$HOME/.local/share/mise/"* ]]; then
		warning "uv resolves to a mise-managed installation"
		add_warning "uv resolves to mise"
	else
		warning "uv does not resolve to the expected Homebrew executable"
		print "  $UV_PATH"
		add_warning "uv executable ownership"
	fi

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

		PYTHON3_EXECUTABLE="$(
			python3 -c 'import sys; print(sys.executable)' 2>/dev/null ||
				true
		)"

		if [[ -n "$PYTHON3_EXECUTABLE" ]]; then
			info "python3 executable: $PYTHON3_EXECUTABLE"
		fi

		case "$(command -v python3)" in
		"$HOME/.local/bin/"*)
			success "python3 resolves through ~/.local/bin"
			;;
		/opt/homebrew/*)
			warning "python3 currently resolves to a Homebrew installation"
			warning "Ensure ~/.local/bin appears before /opt/homebrew/bin"
			add_warning "python3 resolves to Homebrew"
			;;
		/usr/bin/python3)
			warning "python3 currently resolves to the macOS system Python"
			warning "Install a uv default Python or fix PATH ordering"
			print "  uv python install $UV_DEFAULT_PYTHON_VERSION --default"
			print '  export PATH="$HOME/.local/bin:$PATH"'
			add_warning "python3 resolves to macOS system Python"
			;;
		*)
			warning "python3 resolves to an unexpected location"
			print "  $(command -v python3)"
			add_warning "python3 resolves to an unexpected location"
			;;
		esac

		PYTHON3_VERSION="$(
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

	print

	if command_exists pre-commit; then
		success "pre-commit: $(pre-commit --version)"
		info "pre-commit executable: $(command -v pre-commit)"

		case "$(command -v pre-commit)" in
		"$HOME/.local/bin/"*)
			success "pre-commit is exposed through ~/.local/bin"
			;;
		/opt/homebrew/*)
			warning "pre-commit is still resolving to Homebrew"
			add_warning "pre-commit resolves to Homebrew"
			;;
		*)
			warning "pre-commit resolves from an unexpected location"
			print "  $(command -v pre-commit)"
			add_warning "pre-commit executable location"
			;;
		esac
	else
		warning "pre-commit is unavailable"
		print "Install it with:"
		print "  uv tool install pre-commit"
		add_warning "pre-commit unavailable"
	fi

	print

	if command_exists ruff; then
		success "ruff: $(ruff --version)"
		info "ruff executable: $(command -v ruff)"

		case "$(command -v ruff)" in
		"$HOME/.local/bin/"*)
			success "ruff is exposed through ~/.local/bin"
			;;
		/opt/homebrew/*)
			warning "ruff is resolving to Homebrew"
			add_warning "ruff resolves to Homebrew"
			;;
		*)
			warning "ruff resolves from an unexpected location"
			print "  $(command -v ruff)"
			add_warning "ruff executable location"
			;;
		esac
	else
		warning "ruff is unavailable"
		print "Install it with:"
		print "  uv tool install ruff"
		add_warning "ruff unavailable"
	fi
fi

if command_exists brew; then
	print
	info "Homebrew prefix: $(brew --prefix)"
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
	success "Mac maintenance finished without command failures"

	if ((${#WARNINGS[@]} > 0)); then
		warning "Review the warnings above when convenient"
	else
		success "No warnings were detected"
	fi
else
	failure "Mac maintenance finished with ${#FAILURES[@]} failure(s):"

	for item in "${FAILURES[@]}"; do
		print "  - $item"
	done

	print
	failure "Review the failures above for details"

	exit 1
fi

print
