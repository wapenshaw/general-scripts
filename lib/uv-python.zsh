#!/usr/bin/env zsh
# shellcheck shell=bash

# uv-managed Python helpers shared by mac-update.zsh and linux-update.zsh.
# Callers provide info, success, warning and run_step (which honors DRY_RUN).

# Directories searched for virtual environments that still point at a specific
# patch install. uv's tool environments are always searched.
typeset -g UV_PYTHON_VENV_SCAN_DIRS="${UV_PYTHON_VENV_SCAN_DIRS:-$HOME/Code}"

# Removes uv-managed Python patch installs superseded by a newer patch of the
# same minor, implementation, variant and platform. `uv python install
# --upgrade` and `uv python upgrade` keep the old patch directories. Venvs made
# through the minor link (cpython-3.14-…, uv's default) follow upgrades; a venv
# pinned to an exact patch records that patch's directory in pyvenv.cfg and
# breaks if it is removed, so such patches are kept and reported.
uv_python_prune_patches() {
	local python_dir tool_dir dir name group patch root
	local -A newest
	local -a installs stale roots venv_configs users

	python_dir="$(uv python dir 2>/dev/null)" || return 0
	[[ -d "$python_dir" ]] || return 0

	# Real patch directories only; the minor links (cpython-3.14-…) are symlinks
	# and pre-releases (3.15.0a1) are left alone.
	for dir in "$python_dir"/*(N/); do
		name="${dir:t}"
		[[ "$name" =~ '^([a-z]+)-([0-9]+)\.([0-9]+)\.([0-9]+)((\+[a-z]+)*-.+)$' ]] || continue

		group="$match[1]-$match[2].$match[3]$match[5]"
		installs+=("$name" "$group" "$match[4]")

		if (( match[4] > ${newest[$group]:--1} )); then
			newest[$group]="$match[4]"
		fi
	done

	for name group patch in "${installs[@]}"; do
		(( patch < newest[$group] )) && stale+=("$name")
	done

	if (( ${#stale[@]} == 0 )); then
		success "No superseded uv Python patch installs"
		return 0
	fi

	tool_dir="$(uv tool dir 2>/dev/null || true)"
	roots=(${tool_dir:+$tool_dir} ${=UV_PYTHON_VENV_SCAN_DIRS})

	for root in "${roots[@]}"; do
		[[ -d "$root" ]] || continue
		venv_configs+=(${(f)"$(find "$root" -maxdepth 6 \
			\( -name node_modules -o -name .git \) -prune -o \
			-name pyvenv.cfg -type f -print 2>/dev/null)"})
	done

	for name in "${stale[@]}"; do
		users=()
		if (( ${#venv_configs[@]} > 0 )); then
			users=(${(f)"$(grep -lF -- "/$name/" "${venv_configs[@]}" 2>/dev/null)"})
		fi

		if (( ${#users[@]} > 0 )); then
			warning "Keeping superseded Python $name; these venvs still use it:"
			print -l -- "  ${^users[@]:h}"
			continue
		fi

		run_step "Remove superseded Python $name" uv python uninstall "$name"
	done
}
