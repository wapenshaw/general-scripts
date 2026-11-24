#!/usr/bin/env zsh
# shellcheck shell=bash

# uv-managed Python helpers shared by mac-update.zsh and linux-update.zsh.
# Callers provide info, success, warning and run_step (which honors DRY_RUN).

# Directories searched for virtual environments that still point at a specific
# patch install. uv's tool and cache environments are always searched.
typeset -g UV_PYTHON_VENV_SCAN_DIRS="${UV_PYTHON_VENV_SCAN_DIRS:-$HOME/Code}"

# Points one venv from a patch install (cpython-3.13.17-…) at a newer install of
# the same minor. Only pyvenv.cfg's home and the bin/ interpreter symlinks name
# the interpreter; patches of one minor share an ABI, so site-packages stay
# valid. Rolls back and fails when the venv's python no longer starts.
uv_python_repoint_venv() {
	local cfg="$1" old="/$2/" new="/$3/"
	local venv="${cfg:h}" content link target python
	local -A saved

	content="$(<"$cfg")" || return 1

	for link in "$venv"/bin/*(N@); do
		target="$(readlink "$link")" || return 1
		[[ "$target" == *"$old"* ]] && saved[$link]="$target"
	done

	print -r -- "${content//"$old"/$new}" >"$cfg" || return 1
	for link target in "${(@kv)saved}"; do
		ln -sfn "${target//"$old"/$new}" "$link" || break
	done

	for python in "$venv/bin/python" "$venv/bin/python3"; do
		[[ -x "$python" ]] || continue
		"$python" -c 'import sys' >/dev/null 2>&1 && return 0
		break
	done

	print -r -- "$content" >"$cfg"
	for link target in "${(@kv)saved}"; do
		ln -sfn "$target" "$link"
	done
	return 1
}

# Removes uv-managed Python patch installs superseded by a newer patch of the
# same minor, implementation, variant and platform. `uv python install
# --upgrade` and `uv python upgrade` keep the old patch directories. Venvs made
# through the minor link (cpython-3.14-…, uv's default) already follow
# upgrades; a venv pinned to an exact patch is first repointed at the minor link
# (or the newest patch when uv made no link), and the patch is kept if that fails.
uv_python_prune_patches() {
	local python_dir tool_dir cache_dir dir name group patch root found target cfg
	local -A newest stale_group
	local -a installs stale roots venv_configs users

	python_dir="$(uv python dir 2>/dev/null)" || return 0
	[[ -d "$python_dir" ]] || return 0

	# Real patch directories only; the minor links (cpython-3.14-…) are symlinks
	# and pre-releases (3.15.0a1) are left alone. The group is the minor link's name.
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
		if (( patch < newest[$group] )); then
			stale+=("$name")
			stale_group[$name]="$group"
		fi
	done

	if (( ${#stale[@]} == 0 )); then
		success "No superseded uv Python patch installs"
		return 0
	fi

	# Fail closed: a venv the scan could not see must not lose its interpreter,
	# so any error here keeps every superseded patch.
	# uv's cache also holds venvs (uvx, uv run --with).
	if ! tool_dir="$(uv tool dir 2>/dev/null)" || [[ -z "$tool_dir" ]] ||
		! cache_dir="$(uv cache dir 2>/dev/null)" || [[ -z "$cache_dir" ]]; then
		warning "Could not resolve uv's tool or cache directory; keeping superseded patches"
		return 0
	fi
	roots=("$tool_dir" "$cache_dir" ${=UV_PYTHON_VENV_SCAN_DIRS})

	for root in "${roots[@]}"; do
		[[ -d "$root" ]] || continue
		if ! found="$(find "$root" \
			\( -name node_modules -o -name .git \) -prune -o \
			-name pyvenv.cfg -type f -print 2>/dev/null)"; then
			warning "Could not scan all of $root for venvs; keeping superseded patches"
			print "  Check with: find ${(q)root} -name pyvenv.cfg >/dev/null"
			return 0
		fi
		venv_configs+=(${(f)found})
	done

	for name in "${stale[@]}"; do
		group="${stale_group[$name]}"
		if [[ -d "$python_dir/$group" ]]; then
			target="$group"
		else
			target="$(print -r -- "$name" |
				sed -E "s/^([a-z]+-[0-9]+\.[0-9]+\.)[0-9]+/\1${newest[$group]}/")"
		fi

		users=()
		if (( ${#venv_configs[@]} > 0 )); then
			found="$(grep -lF -- "/$name/" "${venv_configs[@]}" 2>/dev/null)"
			case $? in
			0) users=(${(f)found}) ;;
			1) ;;
			*)
				warning "Could not read every pyvenv.cfg; keeping $name"
				continue
				;;
			esac
		fi

		for cfg in "${users[@]}"; do
			run_step "Point venv ${cfg:h} at $target" \
				uv_python_repoint_venv "$cfg" "$name" "$target"
		done

		# A repoint that failed (and was rolled back) still names the patch; an
		# unreadable pyvenv.cfg is treated the same way.
		if (( ${#users[@]} > 0 )) && [[ "${DRY_RUN:-false}" != true ]]; then
			found="$(grep -lF -- "/$name/" "${users[@]}" 2>/dev/null)"
			if (( $? != 1 )); then
				warning "Keeping superseded Python $name; these venvs could not be repointed:"
				print -l -- "  ${^users[@]:h}"
				continue
			fi
		fi

		run_step "Remove superseded Python $name" uv python uninstall "$name"
	done
}
