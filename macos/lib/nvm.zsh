# Remove only the version-pinned NVM links created by older Mac scripts.
# Keep unrelated executables and links, including standalone pnpm installs.
remove_legacy_nvm_links() {
    local bin_dir="${1:-$HOME/.local/bin}"
    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    local tool link target

    for tool in node npm npx pnpm; do
        link="$bin_dir/$tool"
        [[ -L "$link" ]] || continue
        target="$(readlink "$link")" || return 1
        [[ "$target" == "${nvm_dir%/}"/versions/node/*/bin/"$tool" ]] || continue

        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "Dry-run: remove legacy NVM symlink $link"
        else
            rm -- "$link" || return 1
            success "Removed legacy NVM symlink $link"
        fi
    done
    return 0
}
