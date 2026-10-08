#!/usr/bin/env zsh
# macos/stages/02-runtimes.zsh — Stage 2: Developer Runtimes & Toolchains
#
# Bootstraps Node.js (via NVM), Python (via uv), Rust (via rustup), Bun, and Go.
set -euo pipefail

STAGE_DIR="${0:A:h}"
REPO="${STAGE_DIR:h:h}"

source "$REPO/macos/lib/common.zsh"
source "$REPO/macos/lib/nvm.zsh"

section "Stage 2: Developer Runtimes & Toolchains"

# 1. Node.js & pnpm via NVM
info "Configuring Node.js via NVM..."
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_VERSION="v0.40.8"
NODE_VERSION="26"

if [[ ! -d "$NVM_DIR" ]]; then
    run_cmd "Installing NVM ($NVM_VERSION)" \
        git clone --depth 1 --branch "$NVM_VERSION" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
else
    success "NVM is installed at $NVM_DIR"
fi

if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "source $NVM_DIR/nvm.sh --no-use"
    print_dry "nvm install $NODE_VERSION (if missing)"
    print_dry "nvm alias default $NODE_VERSION (if the default is missing or broken)"
    print_dry "nvm use default"
    print_dry "npm install -g pnpm (if missing from the selected NVM version)"
elif [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh" --no-use

    # Check if requested Node version is installed
    if ! nvm which "$NODE_VERSION" >/dev/null 2>&1; then
        run_cmd "Installing Node.js $NODE_VERSION via NVM" nvm install "$NODE_VERSION"
    else
        success "Node.js $NODE_VERSION is installed in NVM"
    fi
    # Repair a missing or broken default; keep a valid default the user chose.
    if nvm which default >/dev/null 2>&1; then
        success "NVM default resolves to $(nvm version default)"
    else
        run_cmd "Setting default Node.js alias to $NODE_VERSION" nvm alias default "$NODE_VERSION"
    fi
    # Install tools into the version new shells will actually select.
    nvm use default >/dev/null

    # A deliberate 'system' default is valid, but is not managed by NVM.
    if [[ "${NVM_BIN:-}" != "$NVM_DIR"/versions/node/*/bin ]]; then
        warning "The default Node is outside NVM; skipping global pnpm installation"
    elif [[ ! -x "$NVM_BIN/pnpm" ]]; then
        run_cmd "Installing global pnpm via npm" npm install -g pnpm
    else
        success "pnpm is installed ($(pnpm --version))"
    fi
else
    failure "NVM is incomplete: $NVM_DIR/nvm.sh is missing"
    exit 1
fi

# Shells inherit NVM's bin directory; version-pinned local links become stale.
remove_legacy_nvm_links

# 2. Python via uv
info "Configuring Python via uv..."
if ! command_exists uv; then
    run_cmd "Installing uv via Homebrew" brew install uv
else
    success "uv is installed ($(uv --version))"
fi

UV_PYTHON_VERSION="3.14"
run_cmd "Installing default Python $UV_PYTHON_VERSION via uv" \
    uv python install "$UV_PYTHON_VERSION" --default
run_cmd "Pinning global Python to $UV_PYTHON_VERSION" \
    uv python pin --global "$UV_PYTHON_VERSION"

# Python CLI applications managed by uv
UV_TOOLS=(
    awscli
    pre-commit
    ruff
)
typeset -a INSTALLED_UV_TOOLS
INSTALLED_UV_TOOLS=()
if command_exists uv; then
    INSTALLED_UV_TOOLS=(
        "${(@f)$(uv tool list 2>/dev/null | sed -n 's/^\([^[:space:]]*\) .*/\1/p')}"
    )
fi
for uv_tool in "${UV_TOOLS[@]}"; do
    if (( ${INSTALLED_UV_TOOLS[(Ie)$uv_tool]} )); then
        success "$uv_tool is installed through uv"
    else
        run_cmd "Installing uv tool $uv_tool" uv tool install "$uv_tool"
    fi
done

# 3. Rust toolchain via rustup
info "Configuring Rust toolchain via rustup..."
if command_exists rustup; then
    success "rustup is installed ($(rustup --version | head -n 1))"
else
    info "Installing rustup via official installer (without shell mutation)..."
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain stable"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
            sh -s -- -y --no-modify-path --default-toolchain stable
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        success "Rust toolchain installed"
    fi
fi

# 4. Bun and Go
info "Configuring Bun and Go..."
typeset v_out=""
for lang_tool in bun go; do
    if ! command_exists "$lang_tool"; then
        run_cmd "Installing $lang_tool via Homebrew" brew install "$lang_tool"
    else
        if [[ "$lang_tool" == "go" ]]; then
            v_out="$(go version 2>/dev/null | head -n 1)"
        else
            v_out="$($lang_tool --version 2>/dev/null | head -n 1)"
        fi
        success "$lang_tool is installed ($v_out)"
    fi
done

success "Stage 2: Developer Runtimes & Toolchains complete"
