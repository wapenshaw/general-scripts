#!/usr/bin/env zsh
# macos/stages/02-runtimes.zsh — Stage 2: Developer Runtimes & Toolchains
#
# Bootstraps Node.js (via NVM), Python (via uv), Rust (via rustup), Bun, and Go.
set -euo pipefail

STAGE_DIR="${0:A:h}"
REPO="${STAGE_DIR:h:h}"

source "$REPO/macos/lib/common.zsh"

section "Stage 2: Developer Runtimes & Toolchains"

# 1. Node.js & pnpm via NVM
info "Configuring Node.js via NVM..."
export NVM_DIR="$HOME/.nvm"
NVM_VERSION="v0.40.8"
NODE_VERSION="26"

if [[ ! -d "$NVM_DIR" ]]; then
    run_cmd "Installing NVM ($NVM_VERSION)" \
        git clone --depth 1 --branch "$NVM_VERSION" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
else
    success "NVM is installed at $NVM_DIR"
fi

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    
    # Check if requested Node version is installed
    if ! nvm which "$NODE_VERSION" >/dev/null 2>&1; then
        run_cmd "Installing Node.js $NODE_VERSION via NVM" nvm install "$NODE_VERSION"
        run_cmd "Setting default Node.js alias to $NODE_VERSION" nvm alias default "$NODE_VERSION"
    else
        success "Node.js $NODE_VERSION is installed in NVM"
    fi
    nvm use "$NODE_VERSION" >/dev/null 2>&1 || true

    # Install pnpm if missing
    if ! command_exists pnpm; then
        run_cmd "Installing global pnpm via npm" npm install -g pnpm
    else
        success "pnpm is installed ($(pnpm --version))"
    fi

    # Expose Node binaries to ~/.local/bin for POSIX shell compatibility
    info "Exposing Node binaries to ~/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    local node_bin_dir
    node_bin_dir="$(dirname "$(command -v node)")"
    if [[ -d "$node_bin_dir" && "$node_bin_dir" == "$HOME/.nvm/"* ]]; then
        for tool in node npm npx pnpm; do
            if [[ -x "$node_bin_dir/$tool" ]]; then
                if [[ "${DRY_RUN:-false}" == true ]]; then
                    print_dry "ln -sf $node_bin_dir/$tool $HOME/.local/bin/$tool"
                else
                    ln -sf "$node_bin_dir/$tool" "$HOME/.local/bin/$tool"
                fi
            fi
        done
        success "Node, npm, npx, and pnpm linked into ~/.local/bin"
    fi
fi

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
INSTALLED_UV_TOOLS=(
    "${(@f)$(uv tool list 2>/dev/null | sed -n 's/^\([^[:space:]]*\) .*/\1/p')}"
)
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
    fi
    success "Rust toolchain installed"
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
