#!/usr/bin/env zsh
# shellcheck shell=bash

# uv-managed Python helpers shared by mac-update.zsh and linux-update.zsh.
# Callers provide info, success, warning and run_step (which honors DRY_RUN).

# Directories searched for virtual environments that still point at a specific
# patch install. uv's tool and cache environments are always searched.
typeset -g UV_PYTHON_VENV_SCAN_DIRS="${UV_PYTHON_VENV_SCAN_DIRS:-$HOME/Code}"

# Succeeds (0) when a venv still names a patch install in pyvenv.cfg or in any
# bin/ symlink (resolved, so python3 -> python -> … counts), 1 when it does
# not, 2 when pyvenv.cfg cannot be read.
uv_python_venv_names() {
	local venv="$1" needle="/$2/" link

	grep -qF -- "$needle" "$venv/pyvenv.cfg" 2>/dev/null
	case $? in
	0) return 0 ;;
	1) ;;
	*) return 2 ;;
	esac

	for link in "$venv"/bin/*(N@); do
		[[ "${link:A}/" == *"$needle"* ]] && return 0
	done
	return 1
}

# Points one venv from a patch install (cpython-3.13.17-…) at a newer install of
# the same minor. Only pyvenv.cfg's home and the bin/ interpreter symlinks name
# the interpreter; patches of one minor share an ABI, so site-packages stay
# valid. Any write or relink failure, a link left on the old patch, a python
# that does not resolve into the new install, or one that does not start rolls
# everything back and fails.
uv_python_repoint_venv() {
	local cfg="$1" old_name="$2" old="/$2/" new="/$3/" new_dir="$4"
	local venv="${cfg:h}" content link target python ok=1
	local -A saved

	content="$(<"$cfg")" || return 1

	for link in "$venv"/bin/*(N@); do
		target="$(readlink "$link")" || return 1
		[[ "$target" == *"$old"* ]] && saved[$link]="$target"
	done

	print -r -- "${content//"$old"/$new}" >"$cfg" || ok=0
	if (( ok )); then
		for link target in "${(@kv)saved}"; do
			ln -sfn "${target//"$old"/$new}" "$link" || { ok=0; break; }
		done
	fi

	if (( ok )); then
		uv_python_venv_names "$venv" "$old_name"
		(( $? == 1 )) || ok=0
	fi

	if (( ok )); then
		python="$venv/bin/python"
		[[ -e "$python" ]] || python="$venv/bin/python3"
		# -I -S: start the bare interpreter only; the venv's .pth files and
		# sitecustomize are project code and must not run here.
		[[ -e "$python" && "${python:A}" == "${new_dir:A}/"* ]] &&
			"$python" -I -S -c '' >/dev/null 2>&1 && return 0
	fi

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
		for cfg in "${venv_configs[@]}"; do
			uv_python_venv_names "${cfg:h}" "$name"
			case $? in
			0) users+=("$cfg") ;;
			1) ;;
			*)
				warning "Could not read $cfg; keeping $name"
				continue 2
				;;
			esac
		done

		for cfg in "${users[@]}"; do
			run_step "Point venv ${cfg:h} at $target" \
				uv_python_repoint_venv "$cfg" "$name" "$target" "$python_dir/$target"
		done

		# Re-check every venv, cfg and bin/ links alike: a failed (rolled back)
		# repoint or an unreadable pyvenv.cfg keeps the patch.
		if (( ${#users[@]} > 0 )) && [[ "${DRY_RUN:-false}" != true ]]; then
			found=""
			for cfg in "${users[@]}"; do
				uv_python_venv_names "${cfg:h}" "$name"
				(( $? == 1 )) || found+="  ${cfg:h}"$'\n'
			done
			if [[ -n "$found" ]]; then
				warning "Keeping superseded Python $name; these venvs could not be repointed:"
				print -rn -- "$found"
				continue
			fi
		fi

		run_step "Remove superseded Python $name" uv python uninstall "$name"
	done
}
