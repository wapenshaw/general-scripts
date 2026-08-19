#!/usr/bin/env bash
# linux/install.sh — first-run Linux bootstrap (Fedora dnf / Ubuntu apt-get)
#
# Installs the curated CLI tools from the native package manager, falls back
# to official user-level installers when a package is missing, then deploys
# the zsh config. Safe to re-run. A missing package never aborts the rest.
#
# Usage:
#   ./linux/install.sh              # Fedora/Ubuntu: tools + zsh (personal)
#   ./linux/install.sh --assurant   # same, with Assurant/Astra modules
#   ./linux/install.sh --base       # explicit personal profile
#   ./linux/install.sh --update     # also upgrade already-installed packages
#   ./linux/install.sh --dry-run    # print mutating commands
#   ./linux/install.sh --skip-zsh   # tools only
#   ./linux/install.sh --skip-tools # zsh config only
#
# Package ownership:
#   dnf / apt-get   native CLI tools (zsh, git, eza, bat, fd, ripgrep, …)
#   official scripts  mise, uv, starship, rustup, zoxide when the distro
#                     package is unavailable
#   rustup          rustc / cargo (PATH is owned by the zsh config; only
#                   added when ~/.cargo/bin/cargo exists)

set -u
set -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ASSURANT=0
UPDATE=0
DRY_RUN=0
SKIP_ZSH=0
SKIP_TOOLS=0
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
  sed -n '2,22p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --assurant) ASSURANT=1 ;;
    --base) ASSURANT=0 ;;
    --update) UPDATE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-zsh) SKIP_ZSH=1 ;;
    --skip-tools) SKIP_TOOLS=1 ;;
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

link_renamed_binary() {
  local src_cmd="$1"
  local dest_name="$2"
  local dest="$HOME/.local/bin/$dest_name"
  local src

  command_exists "$dest_name" && return 0
  command_exists "$src_cmd" || return 1

  src="$(command -v "$src_cmd")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command ln -sfn "$src" "$dest"
    return 0
  fi

  ln -sfn "$src" "$dest"
  green "Linked $src_cmd → ~/.local/bin/$dest_name"
}

#
# Official user-level fallbacks (no root required)
#

install_starship_official() {
  command_exists starship && { green "starship already on PATH"; return 0; }
  ensure_local_bin
  info "Installing starship via official installer"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"'
    return 0
  fi
  if curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
    green "Installed starship → ~/.local/bin"
  else
    yellow "Official starship installer failed"
    add_warning "starship official installer"
  fi
}

install_mise_official() {
  command_exists mise && { green "mise already on PATH"; return 0; }
  ensure_local_bin
  info "Installing mise via official installer"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command sh -c 'curl https://mise.run | sh'
    return 0
  fi
  if curl -fsSL https://mise.run | sh; then
    green "Installed mise → ~/.local/bin"
  else
    yellow "Official mise installer failed"
    add_warning "mise official installer"
  fi
}

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

install_zoxide_official() {
  command_exists zoxide && { green "zoxide already on PATH"; return 0; }
  ensure_local_bin
  info "Installing zoxide via official installer"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_command sh -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
    return 0
  fi
  if curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
    green "Installed zoxide → ~/.local/bin"
  else
    yellow "Official zoxide installer failed"
    add_warning "zoxide official installer"
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

  run_cmd "Install Python 3.13 as the uv default" \
    uv python install 3.13 --default

  if command_exists uv; then
    run_cmd "Install uv tool: pre-commit" uv tool install pre-commit
    run_cmd "Install uv tool: ruff" uv tool install ruff
  fi
}

#
# Catalog: package  binary  [fallback]
# fallback is one of: starship mise uv zoxide rustup (empty = no fallback)
#

fedora_catalog() {
  cat <<'EOF'
zsh zsh
git git
curl curl
ca-certificates ca-certificates
eza eza
bat bat
fd-find fd
ripgrep rg
fzf fzf
zoxide zoxide zoxide
direnv direnv
neovim nvim
ShellCheck shellcheck
shfmt shfmt
git-delta delta
just just
hyperfine hyperfine
jq jq
yq yq
gh gh
mise mise mise
starship starship starship
uv uv uv
rustup rustup-init rustup
EOF
}

ubuntu_catalog() {
  cat <<'EOF'
zsh zsh
git git
curl curl
ca-certificates ca-certificates
eza eza
bat bat
fd-find fdfind
ripgrep rg
fzf fzf
zoxide zoxide zoxide
direnv direnv
neovim nvim
shellcheck shellcheck
shfmt shfmt
git-delta delta
just just
hyperfine hyperfine
jq jq
yq yq
gh gh
mise mise mise
starship starship starship
uv uv uv
rustup rustup-init rustup
EOF
}

run_fallback() {
  local name="$1"
  case "$name" in
    starship) install_starship_official ;;
    mise)     install_mise_official ;;
    uv)       install_uv_official ;;
    zoxide)   install_zoxide_official ;;
    rustup)   install_rustup_official ;;
    *)        yellow "Unknown fallback: $name" ;;
  esac
}

install_catalog() {
  local line pkg binary fallback

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    pkg=""
    binary=""
    fallback=""
    read -r pkg binary fallback <<< "$line"

    if install_pkg "$pkg" "$binary"; then
      continue
    fi

    if [[ -n "$fallback" ]]; then
      info "Falling back to official installer for $fallback"
      run_fallback "$fallback"
    fi
  done
}

install_tools() {
  section_tools() {
    printf '\n\033[1m\033[34m--- %s ---\033[0m\n\n' "$1"
  }

  section_tools "Native packages ($PM)"

  refresh_packages
  ensure_local_bin

  case "$PM" in
    dnf) install_catalog < <(fedora_catalog) ;;
    apt) install_catalog < <(ubuntu_catalog) ;;
  esac

  if [[ "$PM" == apt ]]; then
    link_renamed_binary batcat bat
    link_renamed_binary fdfind fd
  fi

  section_tools "User-level fallbacks"

  # Always try these if the binary is still missing. Distros often lack them.
  command_exists starship || install_starship_official
  command_exists mise     || install_mise_official
  command_exists uv       || install_uv_official
  command_exists zoxide   || install_zoxide_official
  [[ -x "$HOME/.cargo/bin/cargo" ]] || install_rustup_official
  command_exists bun      || install_bun_official

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
    green "zsh config deployed to ~/.config/zsh"
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
