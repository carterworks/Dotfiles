set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  sunshine-kscreen-doctor push-client [output]
  sunshine-kscreen-doctor pop [output]
  sunshine-kscreen-doctor mode <output> <width> <height> <fps>
  sunshine-kscreen-doctor resolve <output> <width> <height> <fps>

Commands:
  push-client  Push the current mode, then apply SUNSHINE_CLIENT_*.
  pop          Restore the most recently pushed mode for the output.
  mode     Apply an explicit mode.
  resolve  Print the closest supported refresh rate for a mode.
EOF
  exit 2
}

log() {
  printf 'sunshine-kscreen-doctor: %s\n' "$*" >&2
}

die() {
  log "$*"
  exit 1
}

kscreen_state() {
  kscreen-doctor --json
}

state_dir() {
  if [ -n "${XDG_STATE_HOME:-}" ]; then
    printf '%s\n' "$XDG_STATE_HOME/sunshine-kscreen-doctor"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.local/state/sunshine-kscreen-doctor"
  else
    printf '%s\n' "/tmp/sunshine-kscreen-doctor-${UID:-unknown}"
  fi
}

stack_file() {
  local output=$1
  printf '%s/%s.stack\n' "$(state_dir)" "$output"
}

lock_file() {
  local output=$1
  printf '%s/%s.lock\n' "$(state_dir)" "$output"
}

init_state_dir() {
  mkdir -p "$(state_dir)"
}

output_modes() {
  local output=$1

  kscreen_state | jq -r --arg output "$output" '
    .outputs[]
    | select(.name == $output) as $o
    | $o.modes[]
    | "  \(.id): \(.size.width)x\(.size.height) @ \(.refreshRate) Hz\(if .id == $o.currentModeId then " (current)" else "" end)"
  '
}

detect_output() {
  kscreen_state | jq -r '
    [
      .outputs[]
      | select(.connected and .enabled)
    ]
    | sort_by(if .priority == 0 then 2147483647 else .priority end)
    | .[0].name // empty
  '
}

canonical_output() {
  local output=${1:-}

  kscreen_state | jq -er --arg output "$output" '
    .outputs[]
    | select(.connected and (.name == $output or (.id | tostring) == $output))
    | .name
  ' 2>/dev/null
}

resolve_output() {
  local output=${1:-}

  if [ -n "$output" ]; then
    if ! canonical_output "$output"; then
      return 1
    fi

    return
  fi

  output=$(detect_output)
  [ -n "$output" ] || return 1

  log "auto-detected output '$output'"
  printf '%s\n' "$output"
}

current_mode() {
  local output=$1

  kscreen_state | jq -er --arg output "$output" '
    .outputs[]
    | select(.name == $output and .connected and .enabled) as $o
    | $o.modes[]
    | select(.id == $o.currentModeId)
    | "\(.size.width) \(.size.height) \(.refreshRate)"
  ' 2>/dev/null
}

require_output() {
  local output

  if ! output=$(resolve_output "${1:-}"); then
    if [ -n "${1:-}" ]; then
      die "unknown output '${1}'"
    fi

    die "could not auto-detect an enabled output"
  fi

  if ! canonical_output "$output" >/dev/null; then
    die "unknown output '$output'"
  fi

  printf '%s\n' "$output"
}

resolve_refresh() {
  local mode

  mode=$(resolve_mode "$@") || return 1
  printf '%s\n' "${mode#* }"
}

resolve_mode() {
  local output
  local width=$2
  local height=$3
  local requested_fps=$4

  output=$(require_output "$1")

  kscreen_state | jq -er \
    --arg output "$output" \
    --argjson width "$width" \
    --argjson height "$height" \
    --argjson fps "$requested_fps" '
      def abs: if . < 0 then -. else . end;

      [
        .outputs[]
        | select(.name == $output and .connected)
        | .modes[]
        | select(.size.width == $width and .size.height == $height)
        | {
            id: .id,
            refreshRate: .refreshRate,
            diff: (.refreshRate - $fps | abs)
          }
      ]
      | sort_by(.diff)
      | .[0]
      | select(. != null)
      | "\(.id) \(.refreshRate)"
    ' 2>/dev/null
}

apply_mode() {
  local output
  local width=$2
  local height=$3
  local requested_fps=$4
  local mode
  local mode_id
  local refresh

  output=$(require_output "$1")

  if ! mode=$(resolve_mode "$output" "$width" "$height" "$requested_fps"); then
    log "no supported mode for ${output} at ${width}x${height}"
    log "available modes for ${output}:"
    output_modes "$output" >&2
    exit 1
  fi

  read -r mode_id refresh <<EOF
$mode
EOF

  log "applying ${output} -> ${width}x${height}@${refresh}Hz (requested ${requested_fps}Hz)"
  kscreen-doctor "output.${output}.mode.${mode_id}"
}

push_current_mode() {
  local output
  local mode

  output=$(require_output "$1")
  init_state_dir

  if ! mode=$(current_mode "$output") || [ -z "$mode" ]; then
    die "could not determine current mode for '$output'"
  fi

  printf '%s\n' "$mode" >>"$(stack_file "$output")"
  log "pushed ${output} state: $mode"
}

push_client_mode() {
  local output=$1
  push_current_mode "$output"
  apply_mode "$output" "$SUNSHINE_CLIENT_WIDTH" "$SUNSHINE_CLIENT_HEIGHT" "$SUNSHINE_CLIENT_FPS"
}

pop_mode() {
  local output
  local file
  local last
  local tmp
  local width
  local height
  local fps

  output=$(require_output "$1")
  init_state_dir
  file=$(stack_file "$output")

  if [ ! -s "$file" ]; then
    log "no saved state for '$output'"
    return 0
  fi

  last=$(tail -n 1 "$file")
  tmp=$(mktemp)
  sed '$d' "$file" >"$tmp"
  mv "$tmp" "$file"

  read -r width height fps <<EOF
$last
EOF

  log "popping ${output} state: ${width}x${height}@${fps}Hz"
  apply_mode "$output" "$width" "$height" "$fps"
}

with_lock() {
  local output

  output=$(require_output "${1:-}")

  init_state_dir
  exec 9>"$(lock_file "$output")"
  flock 9
  "${@:2}" "$output"
}

require_client_env() {
  : "${SUNSHINE_CLIENT_WIDTH:?missing SUNSHINE_CLIENT_WIDTH}"
  : "${SUNSHINE_CLIENT_HEIGHT:?missing SUNSHINE_CLIENT_HEIGHT}"
  : "${SUNSHINE_CLIENT_FPS:?missing SUNSHINE_CLIENT_FPS}"
}

command=${1:-}

case "$command" in
  push-client)
    [ "$#" -le 2 ] || usage
    require_client_env
    with_lock "${2:-}" push_client_mode
    ;;
  pop)
    [ "$#" -le 2 ] || usage
    with_lock "${2:-}" pop_mode
    ;;
  mode)
    [ "$#" -eq 5 ] || usage
    apply_mode "$2" "$3" "$4" "$5"
    ;;
  resolve)
    [ "$#" -eq 5 ] || usage
    require_output "$2" >/dev/null
    resolve_refresh "$2" "$3" "$4" "$5"
    ;;
  *)
    usage
    ;;
esac
