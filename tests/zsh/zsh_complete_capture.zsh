#!/usr/bin/env -S zsh -f
# Reports what Tab offers in the configured zsh; the line is cleared after each probe.
# stdin: one command name per line. stdout: "<cmd>\t<probe>\t<candidate>" per candidate
# ("<kept:N>" when zsh kept a match without naming it to us),
# and "<cmd>\t<probe>\t" once per probe, so probes with no candidates still appear.
# Probes are "<cmd> " and "<cmd> -". Run from an empty directory so file completion
# contributes nothing and only real completion definitions show up.
zmodload zsh/zpty zsh/datetime zsh/zselect
setopt extended_glob

root=${0:A:h:h:h}
setup=$(mktemp)
trap 'rm -f -- $setup; zpty -d z 2>/dev/null' EXIT

cat >| $setup <<'EOF'
ZSH_AUTOSUGGEST_STRATEGY=(history)
# Never pause to ask "do you wish to see all N possibilities?" or enter a menu.
LISTMAX=1000000
unsetopt auto_list auto_menu
zstyle ':completion:*' menu no
compadd() {
  # -O/-A/-D are matching queries made by completion functions; let them through.
  if [[ ${@[1,(i)(-|--)]} == *-(O|A|D)\ * ]]; then
    builtin compadd "$@"
    return
  fi
  # Record the names, then add for real so completers chain exactly as on a real Tab.
  local -a __zff_hits
  builtin compadd -A __zff_hits "$@"
  local h
  for h in $__zff_hits; do print -r -- "ZFFC:$h"; done
  builtin compadd "$@"
}
# Some completers add matches through builtins that bypass the compadd override above
# (_describe uses compdescribe), so also report zsh's own count of matches it kept.
zff-count() { print -r -- "ZFFN:$compstate[nmatches]"; }
zff-capture() {
  print -r -- ZFFBEGIN
  comppostfuncs=(zff-count)
  zle complete-word
  print -r -- ZFFEND
  BUFFER= CURSOR=0
}
zle -N zff-capture
bindkey '^I' zff-capture
print -r -- ZFFREADY
bindkey '^M' undefined
bindkey '^J' undefined
EOF

start() {
  zpty -d z 2>/dev/null
  zpty z "$root/zsh/try" -i
  zpty -w z "source ${(q)setup}"
  await ZFFREADY 30
}

# Reads pty lines until one contains $1; collects ZFFC candidates into $found.
await() {
  local want=$1 line
  local deadline=$(( EPOCHREALTIME + $2 ))
  found=() kept=0
  while (( EPOCHREALTIME < deadline )); do
    if zpty -rt z line 2>/dev/null; then
      line=${${line//$'\r'/}%$'\n'}
      [[ -n ${ZFF_DEBUG-} ]] && print -ru2 -- "PTY: ${(q+)line}"
      [[ $line == *ZFFC:* ]] && found+=("${${line##*ZFFC:}%%[[:space:]]#}")
      [[ $line == *ZFFN:<-> ]] && kept=${line##*ZFFN:}
      [[ $line == *$want* && $line != *source* ]] && return 0
    else
      zselect -t 2
    fi
  done
  return 1
}

typeset -a found
integer kept
start || { print -u2 "zsh capture session did not start"; exit 1; }
while IFS= read -r cmd; do
  for probe in "$cmd " "$cmd -"; do
    zpty -w -n z "$probe"$'\t'
    if ! await ZFFEND 10; then
      print -r -- "$cmd"$'\t'"$probe"$'\t'"<timeout>"
      start || exit 1
      continue
    fi
    print -r -- "$cmd"$'\t'"$probe"$'\t'
    for c in ${(u)found}; do print -r -- "$cmd"$'\t'"$probe"$'\t'"$c"; done
    # zsh kept more matches than the override saw; the extra ones are unnamed.
    for (( i = ${#${(u)found}} + 1; i <= kept; i++ )); do print -r -- "$cmd"$'\t'"$probe"$'\t'"<kept:$i>"; done
  done
done
