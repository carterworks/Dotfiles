set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  sunshine-cosmic-randr client <output>
  sunshine-cosmic-randr mode <output> <width> <height> <fps>
  sunshine-cosmic-randr resolve <output> <width> <height> <fps>

Commands:
  client   Read width, height, and fps from SUNSHINE_CLIENT_* variables.
  mode     Apply an explicit mode.
  resolve  Print the closest supported refresh rate for a mode.
EOF
  exit 2
}

log() {
  printf 'sunshine-cosmic-randr: %s\n' "$*" >&2
}

die() {
  log "$*"
  exit 1
}

strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g'
}

cosmic_state() {
  cosmic-randr list | strip_ansi
}

output_modes() {
  local output=$1

  cosmic_state | awk -v output="$output" '
    $1 == output { in_output = 1; next }
    in_output && /^[^[:space:]]/ { exit }
    in_output && /Modes:/ { in_modes = 1; next }
    in_output && in_modes && /^[[:space:]]+[0-9]/ { print; next }
    in_output && in_modes && !/^[[:space:]]+[0-9]/ { exit }
  '
}

require_output() {
  local output=$1

  if ! cosmic_state | awk -v output="$output" '$1 == output { found = 1 } END { exit(found ? 0 : 1) }'; then
    die "unknown output '$output'"
  fi
}

resolve_refresh() {
  local output=$1
  local width=$2
  local height=$3
  local requested_fps=$4

  output_modes "$output" | awk -v width="$width" -v height="$height" -v fps="$requested_fps" '
    function abs(x) { return x < 0 ? -x : x }

    match($0, /([0-9]+)x([0-9]+)[[:space:]]+@[[:space:]]*([0-9.]+)[[:space:]]+Hz/, mode) {
      if (mode[1] != width || mode[2] != height) {
        next
      }

      diff = abs(mode[3] - fps)
      if (!found || diff < best_diff) {
        best = mode[3]
        best_diff = diff
        found = 1
      }
    }

    END {
      if (!found) {
        exit 1
      }

      print best
    }
  '
}

apply_mode() {
  local output=$1
  local width=$2
  local height=$3
  local requested_fps=$4
  local refresh

  require_output "$output"

  if ! refresh=$(resolve_refresh "$output" "$width" "$height" "$requested_fps"); then
    log "no supported mode for ${output} at ${width}x${height}"
    log "available modes for ${output}:"
    output_modes "$output" >&2
    exit 1
  fi

  log "applying ${output} -> ${width}x${height}@${refresh}Hz (requested ${requested_fps}Hz)"
  cosmic-randr mode "$output" "$width" "$height" --refresh "$refresh"
}

require_client_env() {
  : "${SUNSHINE_CLIENT_WIDTH:?missing SUNSHINE_CLIENT_WIDTH}"
  : "${SUNSHINE_CLIENT_HEIGHT:?missing SUNSHINE_CLIENT_HEIGHT}"
  : "${SUNSHINE_CLIENT_FPS:?missing SUNSHINE_CLIENT_FPS}"
}

command=${1:-}

case "$command" in
  client)
    [ "$#" -eq 2 ] || usage
    require_client_env
    apply_mode "$2" "$SUNSHINE_CLIENT_WIDTH" "$SUNSHINE_CLIENT_HEIGHT" "$SUNSHINE_CLIENT_FPS"
    ;;
  mode)
    [ "$#" -eq 5 ] || usage
    apply_mode "$2" "$3" "$4" "$5"
    ;;
  resolve)
    [ "$#" -eq 5 ] || usage
    require_output "$2"
    resolve_refresh "$2" "$3" "$4" "$5"
    ;;
  *)
    usage
    ;;
esac
