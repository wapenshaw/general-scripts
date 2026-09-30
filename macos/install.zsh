#!/bin/zsh
# macos/install.zsh — first-run Mac bootstrap
#
# Installs Homebrew if it is missing, then the curated CLI tools (via
# mac-update.zsh --bootstrap), then deploys the zsh config.
#
# Usage:
#   ./macos/install.zsh              # Homebrew + tools + zsh (personal profile)
#   ./macos/install.zsh --assurant   # same, with Assurant/Astra modules
#   ./macos/install.zsh --dry-run    # print mutating commands
#   ./macos/install.zsh --skip-zsh   # tools only
#   ./macos/install.zsh --skip-tools # zsh config only
#
# Safe to re-run. A missing or failed package never aborts the rest.

set -u
set -o pipefail

autoload -U colors && colors

SCRIPT_PATH="${0:A}"
REPO="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

ASSURANT=0
DRY_RUN=false
SKIP_ZSH=0
SKIP_TOOLS=0
STARSHIP_THEME="${ZSH_STARSHIP_THEME:-}"

usage() {
	sed -n '2,14p' "$SCRIPT_PATH"
}

for arg in "$@"; do
	case "$arg" in
	--assurant) ASSURANT=1 ;;
	--base) ASSURANT=0 ;;
	--dry-run) DRY_RUN=true ;;
	--skip-zsh) SKIP_ZSH=1 ;;
	--skip-tools) SKIP_TOOLS=1 ;;
	--theme)
		print -u2 "Pass the theme as --theme=NAME or ZSH_STARSHIP_THEME=NAME"
		exit 2
		;;
	--theme=*)
		STARSHIP_THEME="${arg#--theme=}"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		print -u2 "Unknown argument: $arg"
		usage
		exit 2
		;;
	esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
	print -u2 "This installer is for macOS. On Linux use ./linux/install.sh"
	exit 2
fi

info() {
	print -P "%F{cyan}==>%f $*"
}

success() {
	print -P "%F{green}✓%f $*"
}

warning() {
	print -P "%F{yellow}Warning:%f $*"
}

section() {
	print
	print -P "%B%F{blue}--- $* ---%f%b"
	print
}

verify_zsh_layout() {
	local target="$HOME/.zsh"
	local name path

	[[ -d "$target" ]] || {
		warning "Canonical zsh directory is missing: $target"
		return 1
	}

	for name in .zshenv .zprofile .zshrc; do
		path="$HOME/$name"
		if [[ ! -L "$path" || "$(readlink "$path")" != "$target/$name" ]]; then
			warning "$path is not linked to $target/$name"
			return 1
		fi
	done

	for name in zsh starship.toml; do
		path="$HOME/.config/$name"
		if [[ ! -L "$path" || "$(readlink "$path")" != "$target/$name" ]]; then
			warning "$path is not linked to $target/$name"
			return 1
		fi
	done
}

section "macOS first-run bootstrap"

info "Repo:     $REPO"
info "Machine:  $(scutil --get ComputerName 2>/dev/null || hostname)"
info "macOS:    $(sw_vers -productVersion)"
info "Arch:     $(uname -m)"
info "Profile:  $([[ "$ASSURANT" -eq 1 ]] && print assurant || print personal)"

if [[ "$DRY_RUN" == true ]]; then
	warning "Dry-run: mutating commands will only be printed"
fi

if [[ "$SKIP_TOOLS" -eq 0 ]]; then
	section "Homebrew + developer tools"

	typeset -a UPDATE_ARGS
	UPDATE_ARGS=(--bootstrap)
	[[ "$DRY_RUN" == true ]] && UPDATE_ARGS+=(--dry-run)

	if [[ -x "$REPO/mac-update.zsh" ]]; then
		if "$REPO/mac-update.zsh" "${UPDATE_ARGS[@]}"; then
			success "Tool bootstrap finished"
		else
			warning "mac-update.zsh exited nonzero; continuing with zsh config"
		fi
	else
		warning "mac-update.zsh is missing at $REPO/mac-update.zsh"
	fi
else
	info "Skipping Homebrew / tool bootstrap (--skip-tools)"
fi

if [[ "$SKIP_ZSH" -eq 0 ]]; then
	section "zsh config"

	typeset -a ZSH_ARGS
	if [[ "$ASSURANT" -eq 1 ]]; then
		ZSH_ARGS=(--assurant)
	else
		ZSH_ARGS=(--base)
	fi

	if [[ -n "$STARSHIP_THEME" ]]; then
		export ZSH_STARSHIP_THEME="$STARSHIP_THEME"
	elif [[ ! -t 0 || ! -t 1 ]]; then
		export ZSH_STARSHIP_THEME="${ZSH_STARSHIP_THEME:-nova}"
	fi

	if [[ "$DRY_RUN" == true ]]; then
		print -n "  "
		printf "%q " "$REPO/zsh/install.sh" "${ZSH_ARGS[@]}"
		print
	elif [[ -x "$REPO/zsh/install.sh" || -f "$REPO/zsh/install.sh" ]]; then
		if bash "$REPO/zsh/install.sh" "${ZSH_ARGS[@]}"; then
			if verify_zsh_layout; then
				success "zsh config deployed with ~/.zsh as the single source of truth"
			else
				warning "zsh config was copied, but the compatibility links are incomplete"
				exit 1
			fi
		else
			warning "zsh/install.sh exited nonzero"
			exit 1
		fi
	else
		warning "zsh/install.sh is missing"
		exit 1
	fi
else
	info "Skipping zsh config (--skip-zsh)"
fi

print
success "macOS bootstrap finished"
print "Open a new terminal or run:  exec zsh -l"
print "Later updates:  $REPO/mac-update.zsh"
print "Re-sync zsh:    $REPO/zsh/install.sh --base"
