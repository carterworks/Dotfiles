set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  sunshine-cosmic-randr push-client [output]
  sunshine-cosmic-randr pop [output]
  sunshine-cosmic-randr mode <output> <width> <height> <fps>
  sunshine-cosmic-randr resolve <output> <width> <height> <fps>

Commands:
  push-client  Push the current mode, then apply SUNSHINE_CLIENT_*.
  pop          Restore the most recently pushed mode for the output.
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

state_dir() {
  if [ -n "${XDG_STATE_HOME:-}" ]; then
    printf '%s\n' "$XDG_STATE_HOME/sunshine-cosmic-randr"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.local/state/sunshine-cosmic-randr"
  else
    printf '%s\n' "/tmp/sunshine-cosmic-randr-${UID:-unknown}"
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

  cosmic_state | awk -v output="$output" '
    $1 == output { in_output = 1; next }
    in_output && /^[^[:space:]]/ { exit }
    in_output && /Modes:/ { in_modes = 1; next }
    in_output && in_modes && /^[[:space:]]+[0-9]/ { print; next }
    in_output && in_modes && !/^[[:space:]]+[0-9]/ { exit }
  '
}

detect_output() {
  cosmic_state | awk '
    /^[^[:space:]]/ {
      output = $1
      enabled = index($0, "(enabled)") > 0
      next
    }

    output != "" && /Xwayland primary:[[:space:]]+true/ {
      found = 1
      print output
      exit
    }

    output != "" && enabled && first_enabled == "" {
      first_enabled = output
    }

    END {
      if (!found && first_enabled != "") {
        print first_enabled
      }
    }
  '
}

resolve_output() {
  local output=${1:-}

  if [ -n "$output" ]; then
    printf '%s\n' "$output"
    return
  fi

  output=$(detect_output)
  if [ -z "$output" ]; then
    die "could not auto-detect an enabled output"
  fi

  log "auto-detected output '$output'"
  printf '%s\n' "$output"
}

current_mode() {
  local output=$1

  cosmic_state | awk -v output="$output" '
    $1 == output { in_output = 1; next }
    in_output && /^[^[:space:]]/ { exit }
    in_output && /Modes:/ { in_modes = 1; next }
    in_output && in_modes && /\(current\)/ {
      match($0, /([0-9]+)x([0-9]+)[[:space:]]+@[[:space:]]*([0-9.]+)[[:space:]]+Hz/, mode)
      if (mode[1] != "") {
        printf "%s %s %s\n", mode[1], mode[2], mode[3]
        exit
      }
    }
  '
}

require_output() {
  local output

  output=$(resolve_output "${1:-}")

  if ! cosmic_state | awk -v output="$output" '$1 == output { found = 1 } END { exit(found ? 0 : 1) }'; then
    die "unknown output '$output'"
  fi

  printf '%s\n' "$output"
}

resolve_refresh() {
  local output
  local width=$2
  local height=$3
  local requested_fps=$4

  output=$(require_output "$1")

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
  local output
  local width=$2
  local height=$3
  local requested_fps=$4
  local refresh

  output=$(require_output "$1")

  if ! refresh=$(resolve_refresh "$output" "$width" "$height" "$requested_fps"); then
    log "no supported mode for ${output} at ${width}x${height}"
    log "available modes for ${output}:"
    output_modes "$output" >&2
    exit 1
  fi

  log "applying ${output} -> ${width}x${height}@${refresh}Hz (requested ${requested_fps}Hz)"
  cosmic-randr mode "$output" "$width" "$height" --refresh "$refresh"
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

  output=$(resolve_output "${1:-}")

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
    require_output "$2"
    resolve_refresh "$2" "$3" "$4" "$5"
    ;;
  *)
    usage
    ;;
esac
