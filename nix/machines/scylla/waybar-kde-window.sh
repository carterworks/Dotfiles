#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s render|activate|close INDEX\n' "$0" >&2
  exit 2
}

window_rows() {
  local id title class desktop

  while IFS= read -r id; do
    title=$(kdotool getwindowname "$id" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')
    class=$(kdotool getwindowclassname "$id" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')
    desktop=$(kdotool get_desktop_for_window "$id" 2>/dev/null | tr -d '\n')

    [ -n "$title" ] || continue
    [ "$desktop" != "null" ] || continue

    case "$class" in
      plasmashell|wbg|waybar|kded*|ksmserver|org.kde.kglobalaccel)
        continue
        ;;
    esac

    printf '%s\t%s\t%s\n' "$id" "$title" "$class"
  done < <(kdotool search --name '.*' 2>/dev/null)
}

index=${2:-}
case "${1:-}" in
  render)
    [[ "$index" =~ ^[1-9][0-9]*$ ]] || usage
    row=$(window_rows | sed -n "${index}p")
    if [ -z "$row" ]; then
      printf '{"text":"","tooltip":"","class":["empty"]}\n'
      exit 0
    fi

    IFS=$'\t' read -r id title class <<< "$row"
    icon="▣"
    case "$class" in
      brave*|chrom*|firefox*|zen*) icon="◉" ;;
      org.telegram*) icon="✉" ;;
      org.kde.dolphin*) icon="◆" ;;
      com.mitchellh.ghostty*) icon="⌁" ;;
    esac

    text=$(printf '%s  %s' "$icon" "$title" | jq -Rsa .)
    tooltip=$(printf '%s — %s' "$title" "$class" | jq -Rsa .)
    printf '{"text":%s,"tooltip":%s,"class":["window"]}\n' "$text" "$tooltip"
    ;;
  activate|close)
    [[ "$index" =~ ^[1-9][0-9]*$ ]] || usage
    row=$(window_rows | sed -n "${index}p")
    [ -n "$row" ] || exit 0
    IFS=$'\t' read -r id _ <<< "$row"
    if [ "$1" = activate ]; then
      kdotool windowactivate "$id"
    else
      kdotool windowclose "$id"
    fi
    ;;
  *)
    usage
    ;;
esac
