# Interactive zsh that behaves like Fish: inline suggestions from Atuin history,
# a Fish-styled completion picker, Fish's theme, and Fish as a completion source
# for programs zsh can't complete. Home Manager sources this from the checkout
# (nix/modules/home/shell.nix) and sets the ZSH_PLUGIN_* paths first; zsh/try
# does the same for trying it out. Tests: tests/zsh/.
typeset -U path cdpath fpath manpath

_zff_root="${${(%):-%x}:A:h}"
_zff_cache="${ZSH_FISH_FEEL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}"
[[ -d "$_zff_cache" ]] || mkdir -p -- "$_zff_cache"

if [[ -n "${ZSH_CARAPACE_BIN:-}" && -x "$ZSH_CARAPACE_BIN" ]]; then
  path=("${ZSH_CARAPACE_BIN:h}" $path)
fi

[[ -n "${REX_BIN_DIR:-}" ]] && path=("$REX_BIN_DIR" $path)

for profile in ${(z)NIX_PROFILES}; do
  fpath+=("$profile/share/zsh/site-functions" "$profile/share/zsh/$ZSH_VERSION/functions" "$profile/share/zsh/vendor-completions")
done

[[ -n "${ZSH_PLUGIN_COMPLETIONS:-}" && -d "$ZSH_PLUGIN_COMPLETIONS" ]] && fpath=("$ZSH_PLUGIN_COMPLETIONS" $fpath)

# Nix store binaries have normalized epoch mtimes, so key cached init scripts by
# resolved realpath + exact arguments rather than file mtime. Publish atomically
# only on generator success so partial/failed output is never cached.
_zff_cache_source() {
  local name="$1"
  local bin_path="$2"
  shift 2
  local cache_file="$_zff_cache/${name}.zsh"
  local meta_file="$_zff_cache/${name}.meta"
  local stamp="${bin_path:A}|$*"
  local current_stamp=""
  [[ -r "$meta_file" ]] && current_stamp="$(<"$meta_file")"
  if [[ ! -s "$cache_file" || "$current_stamp" != "$stamp" ]]; then
    local tmp_file="${cache_file}.tmp.$$"
    if "$@" </dev/null >| "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
      mv -f -- "$tmp_file" "$cache_file"
      print -r -- "$stamp" >| "$meta_file"
      zcompile "$cache_file" 2>/dev/null || true
    else
      rm -f -- "$tmp_file"
      return 1
    fi
  fi
  source "$cache_file"
}

# Use an owned history file for Zsh's own writes, and import Atuin history from a
# separate file via `fc -R` so background sync never races Zsh's HIST_FCNTL_LOCK.
HISTFILE="${ZSH_FISH_FEEL_HISTFILE:-${HISTFILE:-$HOME/.zsh_history}}"
_zff_atuin_hist="${ZSH_FISH_FEEL_ATUIN_HIST:-$_zff_cache/atuin-history.zsh}"
HISTSIZE=20000
SAVEHIST=20000
[[ -d "${HISTFILE:h}" ]] || mkdir -p -- "${HISTFILE:h}"

setopt \
  AUTO_CD \
  INTERACTIVE_COMMENTS \
  PROMPT_SP \
  HIST_FCNTL_LOCK \
  HIST_IGNORE_DUPS \
  HIST_IGNORE_ALL_DUPS \
  HIST_IGNORE_SPACE \
  HIST_SAVE_NO_DUPS \
  SHARE_HISTORY \
  NO_BEEP \
  COMPLETE_IN_WORD \
  ALWAYS_TO_END

# Match Fish word boundaries so Alt+Left/Right and Alt+Backspace stop at /, -, ., _
WORDCHARS=''
# Snappy Escape handling (50ms instead of Zsh's 400ms default)
KEYTIMEOUT=5

zmodload zsh/complist
autoload -Uz compinit

_zff_compdump="$_zff_cache/.zcompdump"
if [[ -s "$_zff_compdump" && -z "$_zff_compdump"(#qN.mh+24) ]]; then
  compinit -C -d "$_zff_compdump"
else
  compinit -d "$_zff_compdump"
  zcompile "$_zff_compdump" 2>/dev/null || true
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
# Fish never asks "do you wish to see all N possibilities?"; LISTMAX=0 would still ask
# whenever the list is taller than the screen.
LISTMAX=1000000

# Fish knows hundreds of programs that zsh and carapace don't, many from completions it
# generates from man pages. When zsh has nothing to offer, ask a config-free Fish
# (~0.15s) using the interactive Fish completion path captured by fish-env-to-zsh.
_zff_fish_complete() {
  (( $+commands[fish] && $#_zff_fish_complete_path )) || return 1
  local line="${(j: :)words[1,CURRENT-1]} $PREFIX" row value desc
  local -a spaced spaced_desc joined joined_desc
  for row in "${(@f)$(command fish --no-config -c \
      'set -g fish_complete_path $argv[2..] $fish_complete_path; complete -C -- $argv[1]' \
      "$line" $_zff_fish_complete_path 2>/dev/null)}"; do
    [[ -n $row ]] || continue
    value=${row%%$'\t'*}
    [[ $row == *$'\t'* ]] && desc=${row#*$'\t'} || desc=
    # Directories and "--opt=" continue the same word, so no space after them.
    if [[ $value == */ || $value == *= ]]; then
      joined+=("$value") joined_desc+=("${value//:/\\:}${desc:+:$desc}")
    else
      spaced+=("$value") spaced_desc+=("${value//:/\\:}${desc:+:$desc}")
    fi
  done
  (( $#spaced + $#joined )) || return 1
  # Fish already matched (fuzzily) and escaped these, so zsh shouldn't refilter (-U)
  # or requote (-Q) them.
  (( $#spaced )) && _describe -t fish-completions 'completions' spaced_desc spaced -U -Q
  (( $#joined )) && _describe -t fish-completions 'completions' joined_desc joined -U -Q -S ''
  return 0
}

if [[ ${ZSH_FISH_FEEL_NO_FISH_BRIDGE:-0} != 1 ]]; then
  # Programs with no zsh completion at all: Fish first, then plain files.
  _zff_default() { _zff_fish_complete || _default }
  compdef _zff_default -default-

  # Programs whose zsh completion offered nothing here: Fish as the last completer.
  _zff_fish_fallback() { _zff_fish_complete }
  zstyle ':completion:*' completer _complete _ignored _zff_fish_fallback
fi

: "${ZSH_USE_FZF_TAB:=1}"
if [[ "$ZSH_USE_FZF_TAB" == "1" && -n "${ZSH_PLUGIN_FZF_TAB:-}" && -r "$ZSH_PLUGIN_FZF_TAB" ]]; then
  zstyle ':completion:*' menu no
  # fzf-tab parses plain [%d] group headers; raw ANSI escapes break its width/group parsing.
  zstyle ':completion:*:descriptions' format '[%d]'
else
  zstyle ':completion:*' menu select
  zstyle ':completion:*:descriptions' format '%F{8}-- %d --%f'
  zstyle ':completion:*:warnings' format '%F{1}-- no matches --%f'
fi

_zff_picker_marker="${TMPDIR:-/tmp}/zff-picker.$$"

# fzf-tab rows are "prefix\0candidate  -- description\0suffix". Fish's pager shows
# "candidate  (description)" in fish_pager_color_description. fzf-tab maps the chosen
# row back to its completion by exact text, so _zff_fzf_inline restores the original
# rows from _zff_pager_original after fzf returns.
typeset -gA _zff_pager_original
_zff_fish_pager_rows() {
  setopt localoptions extendedglob
  local row head rest candidate tail shown
  _zff_pager_original=()
  _zff_pager_rows=()
  while IFS= read -r row; do
    head=${row%%$'\0'*} rest=${row#*$'\0'}
    candidate=${rest%%$'\0'*} tail=${rest#*$'\0'}
    if [[ $row == *$'\0'*$'\0'* && $candidate == (#b)(*[^[:space:]])([[:space:]]##)--\ (*) ]]; then
      shown="$head"$'\0'"$match[1]$match[2]${_zff_desc_sgr-}($match[3])"$'\e[0m\0'"$tail"
      # fzf --ansi prints the chosen row without escape codes.
      _zff_pager_original[${shown//$'\e'\[[0-9;]#m/}]=$row
      row=$shown
    fi
    _zff_pager_rows+=("$row")
  done
}

# Draws fzf over the command line itself so the query reads as part of what you're
# typing: fzf's prompt is the rendered shell prompt plus the buffer before the word
# being completed, and fzf's query is that word.
_zff_fzf_inline() {
  # print -P honors PROMPT_SUBST like the real prompt; ${(e)} would eat a bare "$".
  # Split into a real array: a one-line prompt would otherwise be a scalar, and [-1]
  # would take its last character instead of its last line.
  local -a prompt_lines=("${(@f)$(print -nP -- "$PROMPT")}")
  local prompt_line="$prompt_lines[-1]"
  # fzf's query may be the candidates' shared prefix rather than what was typed, so
  # strip the word being completed, not the query.
  local typed="${LBUFFER%"$IPREFIX$PREFIX"}"
  : >| "$_zff_picker_marker"
  # fzf always begins on the row below the cursor; start one row up so it draws over
  # the command line instead of under it.
  { print -n $'\r'; echoti cuu1 } >/dev/tty
  local -a _zff_pager_rows chosen
  _zff_fish_pager_rows
  chosen=("${(@f)$(print -rl -- "${_zff_pager_rows[@]}" | command fzf "$@" --prompt="$prompt_line$typed" \
    --pointer=' ' --marker=' ' --gutter=' ' --no-scrollbar ${_zff_fzf_colors:+--color=$_zff_fzf_colors})}")
  local ret=$? line
  for line in "${chosen[@]}"; do
    print -r -- "${_zff_pager_original[$line]:-$line}"
  done
  # fzf-tab moves up one row after fzf to undo the usual next-row start; cancel that.
  echoti cud1 >/dev/tty
  return $ret
}

_zff_tab_complete() {
  zle fzf-tab-complete
  if [[ -e "$_zff_picker_marker" ]]; then
    rm -f -- "$_zff_picker_marker"
    zle .reset-prompt
  fi
}

_zff_load_fzf_tab() {
  if [[ "$ZSH_USE_FZF_TAB" == "1" && -n "${ZSH_PLUGIN_FZF_TAB:-}" && -r "$ZSH_PLUGIN_FZF_TAB" ]]; then
    source "$ZSH_PLUGIN_FZF_TAB"
    # When candidates share a longer prefix than what's typed (git add --pa -> --pat),
    # fzf-tab hands the insert back to zsh and re-runs, and that second fzf never draws.
    # Staying in menu mode opens the picker on the shared prefix, which is what Fish shows.
    functions -c _ftb__main_complete _zff_ftb_main_complete
    _ftb__main_complete() {
      _zff_ftb_main_complete "$@"
      local ret=$?
      [[ $compstate[insert] == *unambiguous ]] && compstate[insert]=menu
      return ret
    }
    zle -N _zff_tab_complete
    bindkey '^I' _zff_tab_complete
    zstyle ':fzf-tab:*' fzf-command _zff_fzf_inline
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    # Adaptive height capped at half the pane keeps the command line on screen; a fixed
    # min-height larger than the pane makes fzf scroll the prompt away.
    zstyle ':fzf-tab:*' fzf-flags --height=~50% --min-height=6 --no-border \
      --info=hidden --no-separator
    # One look for every completion kind: no group header row, no · markers, one color.
    zstyle ':fzf-tab:*' show-group quiet
    zstyle ':fzf-tab:*' prefix ''
    zstyle ':fzf-tab:*' group-colors ''
    zstyle ':fzf-tab:*' switch-group '<' '>'
    zstyle ':fzf-tab:*' continuous-trigger '/'
  fi
}

_zff_deferred=()
_zff_defer() {
  _zff_deferred+=("$1")
}

_zff_run_deferred() {
  local fd="$1"
  zle -F "$fd"
  exec {fd}<&-
  local fn
  for fn in "${_zff_deferred[@]}"; do
    "$fn"
  done
  _zff_deferred=()
}

_zff_load_carapace() {
  if command -v carapace >/dev/null 2>&1; then
    export CARAPACE_BRIDGES='zsh,fish,bash'
    export CARAPACE_MATCH=1
    # Carapace is the explicit provider for git, npm, pnpm, uv (including pyproject.toml scripts), rg, gh, etc.
    _zff_cache_source carapace "$(command -v carapace)" carapace _carapace zsh
    functions -c _carapace_completer _zff_carapace_completer
    _carapace_completer() {
      _zff_carapace_completer "$@"
      (( compstate[nmatches] )) && return 0
      [[ $PREFIX == -* ]] && return 1
      # Carapace filters file names by prefix itself, so Fish-style substring matches
      # ("EADME" -> README.md) never reach zsh's matchers. When the argument is a file,
      # ask zsh's own file completion, which honors the matcher-list.
      local probe
      probe="$(carapace "${words[1]:t}" zsh "${(@)words[1,CURRENT-1]}" '' 2>/dev/null)"
      case $probe in
        *files$'\003'*) _files ;;
        *directories$'\003'*) _files -/ ;;
        *) return 1 ;;
      esac
    }
  fi
}

# Programs you use that neither zsh, carapace nor Fish can complete, but that print
# their own zsh completion script. Cached per resolved binary, so upgrades regenerate.
typeset -gA _zff_self_completions=(
  opencode2 '--completions zsh'
  t3 '--completions zsh'
  t3pair '--completions zsh'
  hunk 'completion zsh'
  fnox 'completion zsh'
)
_zff_load_self_completions() {
  local name bin first declared
  for name in ${(k)_zff_self_completions}; do
    bin=${commands[$name]-}
    [[ -n $bin ]] || continue
    _zff_cache_source "complete-$name" "$bin" "$bin" ${=_zff_self_completions[$name]} || continue
    (( $+_comps[$name] )) && continue
    # Some scripts register the upstream name instead (opencode2's says "opencode").
    read -r first < "$_zff_cache/complete-$name.zsh"
    declared=${${first#\#compdef }%% *}
    [[ -n ${_comps[$declared]-} ]] && compdef "$_comps[$declared]" "$name"
  done
}

# Completes a command as if another command line had been typed in its place, the way
# Fish's `function --wraps` does: `gap --pa<Tab>` completes like `git add --all --patch --pa`.
_zff_complete_as() {
  local -a replacement=(${(z)1})
  words=($replacement "${(@)words[2,-1]}")
  (( CURRENT += $#replacement - 1 ))
  _normal
}
typeset -gA _zff_completes_as=(pnpx 'pnpm dlx' npx 'npm exec')
_zff_load_completes_as() {
  setopt localoptions extendedglob
  local file name line target
  # Fish only honors --wraps on functions, so wrapper scripts on PATH (a fish script
  # holding `function gap --wraps='git add --all --patch'`) complete in neither shell.
  for file in ~/.local/bin/*(N-*); do
    name=${file:t}
    (( $+_comps[$name] || $+_zff_completes_as[$name] )) && continue
    { IFS= read -r line && [[ $line == '#!'*fish* ]] } < $file || continue
    while IFS= read -r line; do
      if [[ $line == (#b)*--wraps=\'([^\']##)\'* ]]; then
        _zff_completes_as[$name]=$match[1]
        break
      fi
    done < $file
  done
  for name target in "${(@kv)_zff_completes_as}"; do
    (( ($+commands[$name] || $+functions[$name]) && ! $+_comps[$name] )) || continue
    functions[_zff_as_$name]="_zff_complete_as ${(q)target}"
    compdef "_zff_as_$name" "$name"
  done
}

# Fish environment -> zsh: theme colors and the completion path used by the Fish bridge.
# Keyed on the resolved Fish config so a Home Manager rebuild regenerates it.
_zff_load_fish_env() {
  [[ -n ${_zff_fish_theme:-} ]] && { source "$_zff_fish_theme"; return; }
  command -v fish >/dev/null 2>&1 || return 0
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
  [[ -e $config ]] || return 0
  local gen="$_zff_root/fish-env-to-zsh" gen_mtime
  zmodload -F zsh/stat b:zstat
  zstat -A gen_mtime +mtime -- "$gen" || return 0
  # The generator ignores arguments; its mtime rides along so edits to it bust the cache.
  _zff_cache_source fish-env "$config" "$gen" "$gen_mtime" \
    && _zff_fish_theme="$_zff_cache/fish-env.zsh"
}

_zff_load_fast_syntax() {
  if [[ -n "${ZSH_PLUGIN_FAST_SYNTAX:-}" && -r "$ZSH_PLUGIN_FAST_SYNTAX" ]]; then
    source "$ZSH_PLUGIN_FAST_SYNTAX"
    # Reapply after the plugin so a saved fast-theme can't override the Fish colors.
    _zff_load_fish_env
    (( $+functions[_zsh_autosuggest_bind_widgets] )) && _zsh_autosuggest_bind_widgets
  fi
}

_zff_load_atuin() {
  if command -v atuin >/dev/null 2>&1; then
    export ATUIN_NOBIND="true"
    _zff_cache_source atuin "$(command -v atuin)" atuin init zsh
    # Atuin's generated init prepends its own subprocess strategy; restore in-memory history first
    # so history hits fork zero processes while completion remains a fallback on misses.
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    bindkey '^r' atuin-search
    bindkey '^[[A' atuin-up-search
    bindkey '^[OA' atuin-up-search
  fi
}

bindkey -e

bindkey '^[[C' forward-char
bindkey '^[OC' forward-char
bindkey '^[[D' backward-char
bindkey '^[OD' backward-char
bindkey '^[[1;3C' forward-word
bindkey '^[[1;9C' forward-word
bindkey '^[f' forward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;9D' backward-word
bindkey '^[b' backward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[Z' reverse-menu-complete
bindkey '^[[3~' delete-char

bindkey -M menuselect '^[[A' up-line-or-history
bindkey -M menuselect '^[OA' up-line-or-history
bindkey -M menuselect '^[[B' down-line-or-history
bindkey -M menuselect '^[OB' down-line-or-history
bindkey -M menuselect '^[[C' forward-char
bindkey -M menuselect '^[OC' forward-char
bindkey -M menuselect '^[[D' backward-char
bindkey -M menuselect '^[OD' backward-char
bindkey -M menuselect '^I' menu-complete
bindkey -M menuselect '^[[Z' reverse-menu-complete
bindkey -M menuselect '^[' send-break

# Fish 4 renders hex colors as 24-bit unless told otherwise; zsh only does so when
# COLORTERM says the terminal can. Kept unexported so child programs see the real value.
[[ -z ${COLORTERM-} ]] && typeset -g COLORTERM=truecolor
_zff_load_fish_env

if [[ -n "${ZSH_PLUGIN_AUTOSUGGESTIONS:-}" && -r "$ZSH_PLUGIN_AUTOSUGGESTIONS" ]]; then
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=40
  : "${ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE:=fg=8}"
  ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(forward-char end-of-line vi-forward-char vi-end-of-line vi-add-eol)
  ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(forward-word emacs-forward-word vi-forward-word vi-forward-word-end vi-forward-blank-word vi-forward-blank-word-end)
  source "$ZSH_PLUGIN_AUTOSUGGESTIONS"
  # Must unset AFTER sourcing because zsh-autosuggestions defines it on Zsh >= 5.0.8.
  unset ZSH_AUTOSUGGEST_USE_ASYNC
fi

_zff_load_atuin_history() {
  [[ -r "$_zff_atuin_hist" ]] && fc -R "$_zff_atuin_hist" 2>/dev/null || true
}

if [[ $options[zle] = on && "${ZSH_FISH_FEEL_NO_DEFER:-0}" != "1" ]]; then
  _zff_defer _zff_load_atuin_history
  _zff_defer _zff_load_carapace
  _zff_defer _zff_load_self_completions
  _zff_defer _zff_load_completes_as
  _zff_defer _zff_load_fzf_tab
  _zff_defer _zff_load_fast_syntax
  _zff_defer _zff_load_atuin
  local _zff_fd
  exec {_zff_fd}</dev/null
  zle -F "$_zff_fd" _zff_run_deferred
else
  _zff_load_atuin_history
  _zff_load_carapace
  _zff_load_self_completions
  _zff_load_completes_as
  _zff_load_fzf_tab
  _zff_load_fast_syntax
  [[ $options[zle] = on ]] && _zff_load_atuin
fi

if command -v zoxide >/dev/null 2>&1; then
  _zff_cache_source zoxide "$(command -v zoxide)" zoxide init zsh --cmd cd
fi

if [[ "$TERM" != "dumb" && "${ZSH_FISH_FEEL_SIMPLE_PROMPT:-0}" != "1" ]] && command -v starship >/dev/null 2>&1; then
  _zff_starship_bin="$(command -v starship)"
  _zff_starship_cache="$_zff_cache/starship.zsh"
  _zff_starship_meta="$_zff_cache/starship.meta"
  _zff_starship_stamp="${_zff_starship_bin:A}|init zsh"
  _zff_starship_cur=""
  [[ -r "$_zff_starship_meta" ]] && _zff_starship_cur="$(<"$_zff_starship_meta")"
  if [[ ! -s "$_zff_starship_cache" || "$_zff_starship_cur" != "$_zff_starship_stamp" ]]; then
    _zff_starship_tmp="${_zff_starship_cache}.tmp.$$"
    _zff_starship_out="${_zff_starship_cache}.out.$$"
    _zff_p2="$("$_zff_starship_bin" prompt --continuation 2>/dev/null || print -r -- '> ')"
    if "$_zff_starship_bin" init zsh >| "$_zff_starship_tmp" 2>/dev/null \
      && [[ -s "$_zff_starship_tmp" ]] \
      && awk -v repl="PROMPT2=${(qq)_zff_p2}" '/^PROMPT2=/{print repl; next} {print}' "$_zff_starship_tmp" >| "$_zff_starship_out" \
      && [[ -s "$_zff_starship_out" ]]; then
      mv -f -- "$_zff_starship_out" "$_zff_starship_cache"
      print -r -- "$_zff_starship_stamp" >| "$_zff_starship_meta"
      zcompile "$_zff_starship_cache" 2>/dev/null || true
    fi
    rm -f -- "$_zff_starship_tmp" "$_zff_starship_out"
    unset _zff_p2 _zff_starship_tmp _zff_starship_out
  fi
  [[ -r "$_zff_starship_cache" ]] && source "$_zff_starship_cache"
  unset _zff_starship_bin _zff_starship_cache _zff_starship_meta _zff_starship_stamp _zff_starship_cur
else
  PROMPT='$ '
fi

if [[ "${ZSH_FISH_FEEL_NO_DIRENV:-0}" != "1" ]] && command -v direnv >/dev/null 2>&1; then
  _zff_cache_source direnv "$(command -v direnv)" direnv hook zsh
fi


sync-atuin-history() {
  local script="$_zff_root/sync-atuin-history"
  [[ -x "$script" ]] && "$script" "$_zff_atuin_hist"
  [[ -r "$_zff_atuin_hist" ]] && fc -R "$_zff_atuin_hist"
}

_zff_sync_bg() {
  local script="$_zff_root/sync-atuin-history"
  if [[ -x "$script" && "${ZSH_FISH_FEEL_SKIP_EXIT_SYNC:-0}" != "1" ]]; then
    ("$script" "$_zff_atuin_hist" >/dev/null 2>&1 &)
  fi
}

_zff_on_bg_sync_done() {
  local fd="$1"
  zle -F "$fd"
  exec {fd}<&-
  [[ -r "$_zff_atuin_hist" ]] && fc -R "$_zff_atuin_hist" 2>/dev/null || true
}

autoload -Uz add-zsh-hook
add-zsh-hook zshexit _zff_sync_bg

# Always refresh the separate Atuin export asynchronously on interactive launch so fresh
# Fish commands become available to the first prompt via `fc -R` at 0ms startup cost.
if [[ "${ZSH_FISH_FEEL_SKIP_EXIT_SYNC:-0}" != "1" && $options[zle] = on ]]; then
  local _zff_sync_script="$_zff_root/sync-atuin-history"
  if [[ -x "$_zff_sync_script" ]]; then
    local _zff_hist_fd
    exec {_zff_hist_fd}< <("$_zff_sync_script" "$_zff_atuin_hist" >/dev/null 2>&1; print ok)
    zle -F "$_zff_hist_fd" _zff_on_bg_sync_done
  fi
fi

unset _zff_compdump
