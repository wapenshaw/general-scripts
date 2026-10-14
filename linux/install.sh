#!/usr/bin/env bash
# linux/install.sh — first-run Linux bootstrap (Fedora dnf / Ubuntu apt-get)
#
# Installs the system prerequisites from the native package manager, then
# Homebrew (Linuxbrew) and the CLI tools in linux/Brewfile, the official
# uv/rustup/bun installers, and finally the zsh config. Safe to re-run. A
# failed step never aborts the rest. Keep it current afterwards with
# ./linux-update.zsh.
#
# Usage:
#   ./linux/install.sh              # Fedora/Ubuntu: tools + zsh (personal)
#   ./linux/install.sh --assurant   # same, with Assurant/Astra modules
#   ./linux/install.sh --base       # explicit personal profile
#   ./linux/install.sh --update     # also upgrade already-installed system packages
#   ./linux/install.sh --dry-run    # print mutating commands
#   ./linux/install.sh --skip-zsh   # tools only
#   ./linux/install.sh --skip-tools # zsh config only
#   ./linux/install.sh --bash-only  # only the Homebrew hook for bash (~/.profile, ~/.bashrc)
#
# Package ownership:
#   dnf / apt-get   system prerequisites (zsh, git, curl, compiler toolchain,
#                   direnv). direnv stays native: Homebrew's pulls in its own bash
#   Homebrew        CLI tools in linux/Brewfile (eza, bat, fd, ripgrep, fzf, gh,
#                   starship, zoxide, k9s, Azure kubelogin, …)
#   uv              Python installs and Python CLI tools (official installer;
#                   `uv self update`). Python is never installed through brew
#   nvm             Node.js. Node is never installed through brew
#   bash hook       bash never reads ~/.zsh, so linux/shell/brew.sh puts Homebrew on
#                   bash's PATH too (agent tools such as Copilot CLI run bash)
#   rustup          rustc / cargo (PATH is owned by the zsh config; only
#                   added when ~/.cargo/bin/cargo exists)
#   bun             official installer (`bun upgrade`)

set -u
set -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ASSURANT=0
UPDATE=0
DRY_RUN=0
SKIP_ZSH=0
SKIP_TOOLS=0
BASH_ONLY=0
STARSHIP_THEME="${ZSH_STARSHIP_THEME:-}"

OS_ID=""
OS_LIKE=""
OS_VERSION=""
PM=""          # dnf | apt
HAVE_SUDO=0
SUDO=()

WARNINGS=()
FAILURES=()

usage() {
  sed -n '2,32p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --assurant) ASSURANT=1 ;;
    --base) ASSURANT=0 ;;
    --update) UPDATE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-zsh) SKIP_ZSH=1 ;;
    --skip-tools) SKIP_TOOLS=1 ;;
    --bash-only) BASH_ONLY=1 ;;
    --theme=*) STARSHIP_THEME="${arg#--theme=}" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'This installer is for Linux. On macOS use ./macos/install.zsh\n' >&2
  exit 2
fi

#
# Output
#

green()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
yellow() { printf '\033[33m!\033[0m %s\n' "$1"; }
red()    { printf '\033[31m✗\033[0m %s\n' "$1" >&2; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }
info()   { printf '\033[36m==>\033[0m %s\n' "$1"; }

add_warning() { WARNINGS+=("$1"); }
add_failure() { FAILURES+=("$1"); }

print_command() {
  local arg
  printf '  '
  for arg in "$@"; do
    printf '%q ' "$arg"
  done
  printf '\n'
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#
# Distro + sudo
#

detect_os() {
  if [[ ! -r /etc/os-release ]]; then
    red "Cannot read /etc/os-release"
    exit 2
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_LIKE="${ID_LIKE:-}"
  OS_VERSION="${VERSION_ID:-}"

  case "$OS_ID" in
    fedora|rhel|centos|rocky|almalinux)
      PM=dnf
      ;;
    ubuntu|debian|pop|linuxmint|elementary)
      PM=apt
      ;;
    *)
      case " $OS_LIKE " in
        *" fedora "*|*" rhel "*|*" centos "*)
          PM=dnf
          ;;
        *" debian "*|*" ubuntu "*)
          PM=apt
          ;;
        *)
          red "Unsupported distro: ${OS_ID:-unknown} (ID_LIKE=${OS_LIKE:-none})"
          red "This installer supports Fedora (dnf) and Ubuntu/Debian (apt-get)."
          exit 2
          ;;
      esac
      ;;
  esac
}

setup_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    HAVE_SUDO=1
    SUDO=()
    return
  fi

  if ! command_exists sudo; then
    yellow "sudo is not installed; native package installs will be skipped"
    yellow "User-level installers (mise, uv, starship, rustup) can still run"
    HAVE_SUDO=0
    return
  fi

  if sudo -n true 2>/dev/null; then
    HAVE_SUDO=1
    SUDO=(sudo)
    return
  fi

  if [[ -t 0 && -t 1 ]]; then
    HAVE_SUDO=1
    SUDO=(sudo)
    return
  fi

  yellow "No passwordless sudo and no TTY; native package installs will be skipped"
  HAVE_SUDO=0
}

run_cmd() {
  local description="$1"
  shift

  info "$description"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command "$@"
    return 0
  fi

  if "$@"; then
    green "$description"
    return 0
  fi

  local rc=$?
  yellow "$description failed (exit $rc)"
  add_warning "$description"
  return 0
}

run_sudo() {
  local description="$1"
  shift

  if [[ "$HAVE_SUDO" -ne 1 ]]; then
    yellow "Skipping (no sudo): $description"
    print_command "$@"
    add_warning "Skipped without sudo: $description"
    return 0
  fi

  run_cmd "$description" "${SUDO[@]}" "$@"
}

#
# Package helpers
#

pkg_installed() {
  local pkg="$1"
  case "$PM" in
    dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
    apt) dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' ;;
    *) return 1 ;;
  esac
}

install_pkg() {
  local pkg="$1"
  local binary="${2:-}"

  if [[ -n "$binary" ]] && command_exists "$binary"; then
    green "$binary already on PATH ($pkg)"
    return 0
  fi

  if pkg_installed "$pkg"; then
    green "$pkg is already installed"
    return 0
  fi

  if [[ "$HAVE_SUDO" -ne 1 ]]; then
    yellow "Cannot install $pkg (no sudo)"
    add_warning "Need sudo to install $pkg"
    return 1
  fi

  info "Installing $pkg via $PM"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    case "$PM" in
      dnf) print_command "${SUDO[@]}" dnf install -y "$pkg" ;;
      apt) print_command "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" ;;
    esac
    return 0
  fi

  case "$PM" in
    dnf)
      if "${SUDO[@]}" dnf install -y "$pkg"; then
        green "Installed $pkg"
        return 0
      fi
      ;;
    apt)
      if "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends "$pkg"; then
        green "Installed $pkg"
        return 0
      fi
      ;;
  esac

  yellow "$pkg is not available from $PM (or install failed)"
  add_warning "Package $pkg"
  return 1
}

refresh_packages() {
  if [[ "$HAVE_SUDO" -ne 1 ]]; then
    yellow "Skipping package metadata refresh (no sudo)"
    return 0
  fi

  case "$PM" in
    dnf)
      run_sudo "Refresh dnf metadata" dnf makecache --refresh
      if [[ "$UPDATE" -eq 1 ]]; then
        run_sudo "Upgrade installed dnf packages" dnf upgrade -y
      fi
      ;;
    apt)
      run_sudo "Refresh apt metadata" env DEBIAN_FRONTEND=noninteractive apt-get update
      if [[ "$UPDATE" -eq 1 ]]; then
        run_sudo "Upgrade installed apt packages" \
          env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
      fi
      ;;
  esac
}

ensure_local_bin() {
  mkdir -p "$HOME/.local/bin"
  case ":${PATH}:" in
    *:"$HOME/.local/bin":*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
}

#
# Official user-level fallbacks (no root required)
#

install_uv_official() {
  command_exists uv && { green "uv already on PATH"; return 0; }
  ensure_local_bin
  info "Installing uv via official installer"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
    return 0
  fi
  if curl -fsSL https://astral.sh/uv/install.sh | sh; then
    green "Installed uv → ~/.local/bin"
  else
    yellow "Official uv installer failed"
    add_warning "uv official installer"
  fi
}

install_rustup_official() {
  if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    green "cargo already installed at ~/.cargo/bin/cargo"
    return 0
  fi

  info "Installing rustup (official installer, no PATH mutation)"
  info "zsh config adds ~/.cargo/bin only when cargo exists"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if command_exists rustup-init; then
      print_command rustup-init -y --no-modify-path --default-toolchain stable --profile default
    else
      print_command sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
    fi
    return 0
  fi

  local ok=1
  if command_exists rustup-init; then
    rustup-init -y --no-modify-path --default-toolchain stable --profile default || ok=0
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
      sh -s -- -y --no-modify-path --default-toolchain stable --profile default || ok=0
  fi

  if [[ "$ok" -ne 1 ]]; then
    yellow "rustup installer failed"
    add_warning "rustup installer"
    return 0
  fi

  if [[ -x "$HOME/.cargo/bin/cargo" && -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
  elif [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  fi

  if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    green "cargo installed at ~/.cargo/bin/cargo"
  else
    yellow "rustup finished but cargo is not at ~/.cargo/bin/cargo"
    add_warning "cargo missing after rustup"
  fi
}

install_bun_official() {
  command_exists bun && { green "bun already on PATH"; return 0; }
  info "Installing bun via official installer"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command sh -c 'curl -fsSL https://bun.sh/install | bash'
    return 0
  fi
  if curl -fsSL https://bun.sh/install | bash; then
    green "Installed bun"
  else
    yellow "Official bun installer failed (optional)"
    add_warning "bun official installer"
  fi
}

bootstrap_uv_python() {
  command_exists uv || return 0

  run_cmd "Install Python 3.14 as the uv default" \
    uv python install 3.14 --default
  run_cmd "Pin the global uv Python to 3.14" \
    uv python pin --global 3.14

  run_cmd "Install uv tool: pre-commit" uv tool install pre-commit
  run_cmd "Install uv tool: ruff" uv tool install ruff
}

#
# Homebrew (Linuxbrew)
#

BREW_BIN=""
BREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
AZURE_KUBELOGIN_TAP_URL="https://github.com/Azure/homebrew-kubelogin"

find_brew() {
  local candidate
  for candidate in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [[ -x "$candidate" ]]; then
      BREW_BIN="$candidate"
      return 0
    fi
  done
  if command_exists brew; then
    BREW_BIN="$(command -v brew)"
    return 0
  fi
  return 1
}

# Puts brew on PATH for this run. shellenv prepends, so ~/.local/bin (uv's python
# shims, uv) is moved back in front, as the zsh config does for real shells.
activate_homebrew() {
  find_brew || return 1
  eval "$("$BREW_BIN" shellenv bash)"
  export PATH="$HOME/.local/bin:$PATH"
  export HOMEBREW_NO_ENV_HINTS=1
}

install_homebrew() {
  if activate_homebrew; then
    green "Homebrew already installed: $BREW_BIN"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Installing Homebrew"
    print_command env NONINTERACTIVE=1 /bin/bash -c "curl -fsSL $BREW_INSTALLER_URL | bash"
    return 0
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    yellow "Homebrew will not install as root; re-run as your normal user"
    add_warning "Homebrew (run as a non-root user)"
    return 1
  fi

  # The installer creates /home/linuxbrew with sudo. NONINTERACTIVE=1 needs
  # passwordless sudo; with only a TTY let it prompt for the password.
  local noninteractive=""
  if sudo -n true 2>/dev/null; then
    noninteractive=1
  elif [[ ! -t 0 || ! -t 1 ]]; then
    yellow "Homebrew needs sudo; no passwordless sudo and no TTY, skipping"
    add_warning "Homebrew (needs sudo and a TTY: re-run this script from a terminal)"
    return 1
  fi

  local installer
  installer="$(mktemp)"
  info "Installing Homebrew"
  if curl -fsSL "$BREW_INSTALLER_URL" -o "$installer" &&
    env ${noninteractive:+NONINTERACTIVE=1} /bin/bash "$installer"; then
    rm -f "$installer"
    if activate_homebrew; then
      green "Homebrew installed: $BREW_BIN"
      return 0
    fi
    yellow "Homebrew installer finished but brew was not found"
    add_warning "Homebrew PATH after install"
    return 1
  fi

  rm -f "$installer"
  yellow "Homebrew installer failed"
  add_warning "Install Homebrew"
  return 1
}

# The Azure kubelogin tap carries ~460 MB of git history. Clone it shallow before
# `brew bundle` taps it (brew would do a full clone), or re-clone an existing full one.
ensure_azure_kubelogin_tap() {
  local tap_dir
  tap_dir="$("$BREW_BIN" --repository)/Library/Taps/azure/homebrew-kubelogin"

  if [[ -d "$tap_dir/.git" &&
    "$(git -C "$tap_dir" rev-parse --is-shallow-repository 2>/dev/null)" == true ]]; then
    green "Azure kubelogin tap is already a shallow clone"
    return 0
  fi

  info "Cloning the Azure kubelogin tap shallow (a full clone is ~460 MB)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command git clone --depth 1 "$AZURE_KUBELOGIN_TAP_URL" "$tap_dir"
    return 0
  fi

  mkdir -p "$(dirname "$tap_dir")"
  if ! git clone --depth 1 -q "$AZURE_KUBELOGIN_TAP_URL" "$tap_dir.shallow"; then
    rm -rf "$tap_dir.shallow"
    yellow "Could not clone the Azure kubelogin tap"
    add_warning "Azure kubelogin tap clone"
    return 0
  fi
  if [[ "$tap_dir" == */Library/Taps/azure/homebrew-kubelogin ]]; then
    rm -rf "$tap_dir"
    mv "$tap_dir.shallow" "$tap_dir"
    green "Azure kubelogin tap cloned shallow"
  fi
}

brew_bundle() {
  local brewfile="$REPO/linux/Brewfile"

  if [[ ! -f "$brewfile" ]]; then
    red "Missing $brewfile"
    add_failure "linux/Brewfile missing"
    return 1
  fi

  if [[ -z "$BREW_BIN" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      info "Dry-run: Homebrew is not installed yet; the bundle step would run:"
      print_command brew bundle --file "$brewfile"
    else
      yellow "Homebrew is unavailable; skipping $brewfile"
    fi
    return 0
  fi

  ensure_azure_kubelogin_tap
  run_cmd "Install the Homebrew tools in linux/Brewfile" \
    "$BREW_BIN" bundle --file "$brewfile"
}

BASH_BREW_BEGIN="# >>> linux/install.sh Homebrew block >>>"
BASH_BREW_END="# <<< linux/install.sh Homebrew block <<<"

# bash never reads ~/.zsh, so give it Homebrew too: deploy linux/shell/brew.sh and
# source it from ~/.profile (login shells) and ~/.bashrc (interactive shells).
# Already-running processes keep the PATH they started with and must be restarted.
install_bash_brew() {
  local src="$REPO/linux/shell/brew.sh"
  local dest="$HOME/.config/shell/brew.sh"
  local rc ts

  if [[ ! -f "$src" ]]; then
    red "Missing $src"
    add_failure "linux/shell/brew.sh missing"
    return 1
  fi

  info "Installing the Homebrew hook for bash"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command mkdir -p "$(dirname "$dest")"
    print_command cp "$src" "$dest"
    for rc in "$HOME/.profile" "$HOME/.bashrc"; do
      printf '  append the Homebrew block to %s\n' "$rc"
    done
    return 0
  fi

  ts="$(date +%Y%m%d%H%M%S)"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  green "Installed ~/.config/shell/brew.sh"

  for rc in "$HOME/.profile" "$HOME/.bashrc"; do
    if [[ -f "$rc" ]] && grep -qF "$BASH_BREW_BEGIN" "$rc"; then
      green "$rc already sources it"
      continue
    fi

    [[ -f "$rc" ]] && cp -p "$rc" "$rc.bak-brew-$ts"
    # shellcheck disable=SC2016
    {
      printf '\n%s\n' "$BASH_BREW_BEGIN"
      printf '# Homebrew on PATH for bash (zsh gets it from ~/.zsh/.zshenv).\n'
      printf '[ -r "$HOME/.config/shell/brew.sh" ] && . "$HOME/.config/shell/brew.sh"\n'
      printf '%s\n' "$BASH_BREW_END"
    } >> "$rc"
    green "Added the Homebrew block to $rc (backup: $rc.bak-brew-$ts)"
  done
}

#
# System prerequisites (native package manager). Everything else is Homebrew.
# Format: package  binary-to-look-for (empty = rely on the package database)
#

fedora_catalog() {
  cat <<'EOF2'
zsh zsh
git git
curl curl
ca-certificates
gcc gcc
gcc-c++ g++
make make
procps-ng
file file
direnv direnv
EOF2
}

ubuntu_catalog() {
  cat <<'EOF2'
zsh zsh
git git
curl curl
ca-certificates
build-essential
procps
file file
direnv direnv
EOF2
}

install_catalog() {
  local line pkg binary

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    pkg=""
    binary=""
    read -r pkg binary <<< "$line"
    install_pkg "$pkg" "$binary" || true
  done
}

install_tools() {
  section_tools() {
    printf '\n\033[1m\033[34m--- %s ---\033[0m\n\n' "$1"
  }

  section_tools "System packages ($PM)"

  refresh_packages
  ensure_local_bin

  case "$PM" in
    dnf) install_catalog < <(fedora_catalog) ;;
    apt) install_catalog < <(ubuntu_catalog) ;;
  esac

  section_tools "Homebrew"
  if install_homebrew; then
    brew_bundle
  else
    add_warning "Skipped linux/Brewfile (Homebrew unavailable)"
  fi
  install_bash_brew

  section_tools "User-level installers"

  command_exists uv || install_uv_official
  [[ -x "$HOME/.cargo/bin/cargo" ]] || install_rustup_official
  command_exists bun || install_bun_official

  section_tools "uv Python"
  bootstrap_uv_python
}

deploy_zsh() {
  printf '\n\033[1m\033[34m--- %s ---\033[0m\n\n' "zsh config"

  local -a zsh_args
  if [[ "$ASSURANT" -eq 1 ]]; then
    zsh_args=(--assurant)
  else
    zsh_args=(--base)
  fi

  if [[ -n "$STARSHIP_THEME" ]]; then
    export ZSH_STARSHIP_THEME="$STARSHIP_THEME"
  elif [[ ! -t 0 || ! -t 1 ]]; then
    export ZSH_STARSHIP_THEME="${ZSH_STARSHIP_THEME:-nova}"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command bash "$REPO/zsh/install.sh" "${zsh_args[@]}"
    return 0
  fi

  if [[ ! -f "$REPO/zsh/install.sh" ]]; then
    red "zsh/install.sh is missing at $REPO/zsh/install.sh"
    add_failure "zsh/install.sh missing"
    return 1
  fi

  if bash "$REPO/zsh/install.sh" "${zsh_args[@]}"; then
    green "zsh config deployed to ~/.zsh"
  else
    yellow "zsh/install.sh exited nonzero"
    add_failure "zsh/install.sh"
    return 1
  fi
}

#
# Main
#

detect_os
setup_sudo
ensure_local_bin

printf '\n'
bold "==> Linux first-run bootstrap"
info "Repo:     $REPO"
info "Distro:   ${OS_ID} ${OS_VERSION} (${PM})"
info "Profile:  $([[ "$ASSURANT" -eq 1 ]] && printf assurant || printf personal)"
info "sudo:     $([[ "$HAVE_SUDO" -eq 1 ]] && printf yes || printf no)"
[[ "$DRY_RUN" -eq 1 ]] && yellow "Dry-run: mutating commands will only be printed"
printf '\n'

if [[ "$BASH_ONLY" -eq 1 ]]; then
  SKIP_TOOLS=1
  SKIP_ZSH=1
  install_bash_brew
fi

if [[ "$SKIP_TOOLS" -eq 0 ]]; then
  install_tools
else
  info "Skipping package bootstrap (--skip-tools)"
fi

if [[ "$SKIP_ZSH" -eq 0 ]]; then
  deploy_zsh
else
  info "Skipping zsh config (--skip-zsh)"
fi

if command_exists zsh && [[ "${SHELL:-}" != *zsh ]]; then
  printf '\n'
  info "zsh is installed but is not your login shell"
  printf '  chsh -s %s\n' "$(command -v zsh)"
fi

printf '\n'
if ((${#FAILURES[@]} > 0)); then
  red "Finished with ${#FAILURES[@]} failure(s):"
  for item in "${FAILURES[@]}"; do
    printf '  - %s\n' "$item"
  done
fi

if ((${#WARNINGS[@]} > 0)); then
  yellow "Finished with ${#WARNINGS[@]} warning(s):"
  for item in "${WARNINGS[@]}"; do
    printf '  - %s\n' "$item"
  done
fi

if ((${#FAILURES[@]} == 0)); then
  green "Linux bootstrap finished"
else
  yellow "Linux bootstrap finished with failures — review above"
fi

printf '\n'
printf 'Open a new terminal or run:  exec zsh -l\n'
printf 'Re-run any time:             %s/linux/install.sh\n' "$REPO"
printf 'Re-sync zsh only:            %s/zsh/install.sh %s\n' \
  "$REPO" "$([[ "$ASSURANT" -eq 1 ]] && printf -- --assurant || printf -- --base)"

if ((${#FAILURES[@]} > 0)); then
  exit 1
fi
