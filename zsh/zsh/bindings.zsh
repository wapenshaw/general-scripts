# Emacs key bindings (readline-style: Ctrl-A/E, Ctrl-R, etc.)
bindkey -e

# =========================================================
# Terminfo application mode (from zephyr/editor)
# Enables $terminfo[key] lookups — without this, Home/End/Del
# return wrong sequences depending on the terminal.
# =========================================================

zmodload zsh/terminfo

function zle-line-init {
  (( $+terminfo[smkx] )) && echoti smkx
  zle update-cursor-style
}
function zle-line-finish {
  (( $+terminfo[rmkx] )) && echoti rmkx
}
function update-cursor-style {
  case "$KEYMAP" in
    main|emacs|viins) printf '\e[6 q' ;;  # beam cursor
    *)                printf '\e[2 q' ;;  # block cursor
  esac
}
function zle-keymap-select { zle update-cursor-style; zle reset-prompt; zle -R; }

zle -N zle-line-init
zle -N zle-line-finish
zle -N update-cursor-style
zle -N zle-keymap-select

# =========================================================
# Portable key bindings via terminfo
# =========================================================

[[ -n "$terminfo[khome]" ]] && bindkey "$terminfo[khome]" beginning-of-line
[[ -n "$terminfo[kend]"  ]] && bindkey "$terminfo[kend]"  end-of-line
[[ -n "$terminfo[kich1]" ]] && bindkey "$terminfo[kich1]" overwrite-mode
[[ -n "$terminfo[kdch1]" ]] && bindkey "$terminfo[kdch1]" delete-char
[[ -n "$terminfo[kcbt]"  ]] && bindkey "$terminfo[kcbt]"  reverse-menu-complete

# =========================================================
# Word movement
# =========================================================

bindkey '^[[1;5C' forward-word   # Ctrl+Right
bindkey '^[[1;5D' backward-word  # Ctrl+Left
bindkey '\e[1;3C' forward-word   # Alt+Right (fallback escape sequence)
bindkey '\e[1;3D' backward-word  # Alt+Left

# =========================================================
# fzf widgets
# =========================================================

bindkey '^F' _fzf_file_no_hidden  # Ctrl+F — file picker, no hidden files

# =========================================================
# Autosuggestions
# =========================================================

bindkey '^\' autosuggest-toggle  # Ctrl+\ — toggle on/off

# =========================================================
# Extra widgets (cherry-picked from zephyr/editor)
# =========================================================

# Ctrl+Z — fg if line is empty, otherwise stash line and clear screen
function symmetric-ctrl-z {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER="fg"
    zle accept-line -w
  else
    zle push-input -w
    zle clear-screen -w
  fi
}
zle -N symmetric-ctrl-z
bindkey '^Z' symmetric-ctrl-z

# Ctrl+X Ctrl+S — prepend sudo to current line
function prepend-sudo {
  if [[ "$BUFFER" != su(do|)\ * ]]; then
    BUFFER="sudo $BUFFER"
    (( CURSOR += 5 ))
  fi
}
zle -N prepend-sudo
bindkey '^X^S' prepend-sudo

# Esc+; — toggle # comment at start of line (park a command without running it)
function pound-toggle {
  if [[ "$BUFFER" = '#'* ]]; then
    [[ $CURSOR != $#BUFFER ]] && (( CURSOR -= 1 ))
    BUFFER="${BUFFER:1}"
  else
    BUFFER="#$BUFFER"
    (( CURSOR += 1 ))
  fi
}
zle -N pound-toggle
bindkey '\e;' pound-toggle

# =========================================================
# Smarter paste (cherry-picked from zephyr/utility)
# bracketed-paste-url-magic: prevents paste injection attacks
# url-quote-magic: auto-quotes special chars as you type URLs
# =========================================================

autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic
