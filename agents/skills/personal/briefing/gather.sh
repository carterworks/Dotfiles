#!/usr/bin/env bash
# Gather one day of local activity for the /briefing skill.
# Usage: gather.sh [YYYY-MM-DD]   (default: yesterday)
set -uo pipefail

usage() {
  printf 'Usage: %s [YYYY-MM-DD]\n' "${0##*/}" >&2
}

if [ "$#" -gt 1 ]; then
  usage
  exit 2
fi

DATE="${1:-$(date -v-1d +%Y-%m-%d)}"
if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
  || ! date -j -v+1d -f '%Y-%m-%d' "$DATE" +%Y-%m-%d >/dev/null 2>&1; then
  printf 'Invalid date: %s\n' "$DATE" >&2
  usage
  exit 2
fi

section() {
  printf '\n═══ %s ═══\n' "$1"
}

status() {
  printf 'STATUS: %s\n' "$1"
}

sanitize() {
  sed -E \
    -e 's#([[:alpha:]][[:alnum:]+.-]*://)[^/@[:space:]]+@#\1[REDACTED]@#g' \
    -e 's#([[:alpha:]][[:alnum:]+.-]*://[^?#[:space:]|]+)[?#][^[:space:]|]*#\1?[REDACTED]#g' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=:-]+/\1[REDACTED]/g' \
    -e 's/((--)?(token|password|passwd|secret|api[-_]?key|authorization)(=|[[:space:]]+))[^[:space:]|]+/\1[REDACTED]/g' \
    -e 's/((TOKEN|PASSWORD|PASSWD|SECRET|API_KEY|AUTHORIZATION)=)[^[:space:]|]+/\1[REDACTED]/g' \
    -e 's/(gh[pousr]_[A-Za-z0-9_]+)/[REDACTED]/g' \
    -e 's/(sk-[A-Za-z0-9_-]{16,})/[REDACTED]/g'
}

gather_atuin() {
  section 'ATUIN SHELL HISTORY'

  if ! command -v atuin >/dev/null 2>&1; then
    status 'unavailable (atuin is not installed)'
    return
  fi
  if ! command -v rg >/dev/null 2>&1; then
    status 'unavailable (rg is not installed)'
    return
  fi

  local output
  output=$(mktemp)

  # Atuin date filters have produced incomplete results on this machine.
  atuin history list --reverse --format '{time} | {directory} | {command}' 2>/dev/null \
    | rg "^$DATE " \
    | sanitize >"$output"
  local -a pipeline_status=("${PIPESTATUS[@]}")

  if [ "${pipeline_status[0]}" -ne 0 ]; then
    status 'failed (atuin could not read history)'
  elif [ "${pipeline_status[1]}" -gt 1 ] || [ "${pipeline_status[2]}" -ne 0 ]; then
    status 'failed (atuin history could not be filtered)'
  elif [ -s "$output" ]; then
    status 'complete'
    cat "$output"
  else
    status 'empty'
  fi

  rm -f "$output"
}

gather_claude() {
  section 'CLAUDE CODE SESSIONS'

  local projects="$HOME/.claude/projects"
  if [ ! -d "$projects" ]; then
    status 'unavailable (Claude Code history was not found)'
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    status 'unavailable (jq is not installed)'
    return
  fi
  if ! command -v fd >/dev/null 2>&1; then
    status 'unavailable (fd is not installed)'
    return
  fi

  local files output
  files=$(mktemp)
  output=$(mktemp)
  if ! fd --hidden --no-ignore --type f --extension jsonl --exclude subagents --print0 . "$projects" >"$files" 2>/dev/null; then
    status 'failed (Claude Code history could not be listed)'
    rm -f "$files" "$output"
    return
  fi

  local file summary
  local found=0
  local failed=0
  while IFS= read -r -d '' file; do
    if ! summary=$(jq -sr --arg date "$DATE" '
      def epoch:
        .timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
      def text:
        .message.content
        | if type == "string" then .
          elif type == "array" then
            [.[] | select(.type == "text" and (.text | type == "string")) | .text]
            | join(" ")
          else ""
          end;
      [
        .[]
        | select(.timestamp? | type == "string")
        | (try epoch catch null) as $epoch
        | select($epoch != null)
        | select(($epoch | strflocaltime("%Y-%m-%d")) == $date)
        | {
            epoch: $epoch,
            time: ($epoch | strflocaltime("%H:%M")),
            cwd: (.cwd // "unknown directory"),
            branch: (.gitBranch // "no branch"),
            text: (if .type == "user" then text else "" end)
          }
        | .text |= (
            gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; " ")
            | gsub("[[:space:]]+"; " ")
            | sub("^[[:space:]]+"; "")
            | sub("[[:space:]]+$"; "")
          )
      ]
      | sort_by(.epoch)
      | . as $events
      | [
          $events[]
          | select(.text != "")
          | select((.text | startswith("Caveat")) | not)
          | select((.text | startswith("[Request")) | not)
          | select((.text | startswith("/")) | not)
        ] as $prompts
      | if ($events | length) == 0 then empty
        else [
            ($events[0].time + "-" + $events[-1].time),
            $events[0].cwd,
            $events[0].branch,
            (($prompts[0].text // "no user prompt found")[0:160])
          ] | @tsv
        end
    ' "$file" 2>/dev/null); then
      failed=1
      continue
    fi

    if [ -n "$summary" ]; then
      printf '%s\n' "$summary" | sanitize >>"$output"
      found=1
    fi
  done <"$files"
  rm -f "$files"

  if [ "$found" -eq 1 ] && [ "$failed" -eq 1 ]; then
    status 'partial (some Claude Code sessions could not be read)'
  elif [ "$failed" -eq 1 ]; then
    status 'failed (Claude Code sessions could not be read)'
  elif [ "$found" -eq 1 ]; then
    status 'complete'
  else
    status 'empty'
  fi

  if [ -s "$output" ]; then
    cat "$output"
  fi
  rm -f "$output"
}

gather_opencode() {
  section 'OPENCODE SESSIONS'

  local database="$HOME/.local/share/opencode/opencode.db"
  if [ ! -f "$database" ]; then
    status 'unavailable (OpenCode history was not found)'
    return
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    status 'unavailable (sqlite3 is not installed)'
    return
  fi

  local uri="file:$database?mode=ro"
  local tables
  if ! tables=$(sqlite3 -cmd '.timeout 3000' "$uri" \
    "SELECT ',' || group_concat(name, ',') || ',' FROM sqlite_master WHERE type='table';" 2>/dev/null); then
    status 'failed (OpenCode history could not be read)'
    return
  fi

  local message_table session_table
  if [[ "$tables" == *",session_message,"* && "$tables" == *",session_v2,"* ]]; then
    message_table='session_message'
    session_table='session_v2'
  elif [[ "$tables" == *",message,"* && "$tables" == *",session,"* ]]; then
    message_table='message'
    session_table='session'
  else
    status 'unavailable (OpenCode database schema is not supported)'
    return
  fi

  local query output
  query="
    WITH active AS (
      SELECT session_id, min(time_created) AS start_time, max(time_created) AS end_time
      FROM $message_table
      WHERE date(time_created/1000, 'unixepoch', 'localtime') = '$DATE'
      GROUP BY session_id
    )
    SELECT
      strftime('%H:%M', active.start_time/1000, 'unixepoch', 'localtime') || '-' ||
        strftime('%H:%M', active.end_time/1000, 'unixepoch', 'localtime'),
      replace(replace(s.directory, char(10), ' '), char(13), ' '),
      replace(replace(coalesce(s.title, ''), char(10), ' '), char(13), ' ')
    FROM active
    JOIN $session_table AS s ON s.id = active.session_id
    ORDER BY active.start_time;
  "

  if ! output=$(sqlite3 -cmd '.timeout 3000' -separator ' | ' "$uri" "$query" 2>/dev/null); then
    status 'failed (OpenCode activity could not be read)'
  elif [ -n "$output" ]; then
    status 'complete'
    printf '%s\n' "$output" | sanitize
  else
    status 'empty'
  fi
}

gather_chrome() {
  section 'CHROME BROWSER HISTORY'

  local chrome="$HOME/Library/Application Support/Google/Chrome"
  if [ ! -d "$chrome" ]; then
    status 'unavailable (Chrome history was not found)'
    return
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    status 'unavailable (sqlite3 is not installed)'
    return
  fi

  local all_rows
  all_rows=$(mktemp "${TMPDIR:-/tmp}/briefing-chrome-${DATE}.XXXXXX")
  local history profile snapshot rows count suffix
  local profiles=0
  local failed=0
  local total_rows=0

  for history in "$chrome"/*/History; do
    [ -f "$history" ] || continue
    profiles=$((profiles + 1))
    profile=$(basename "$(dirname "$history")")
    snapshot=$(mktemp -d "${TMPDIR:-/tmp}/briefing-chrome-db.XXXXXX")

    if ! cp "$history" "$snapshot/History" 2>/dev/null; then
      failed=1
      rmdir "$snapshot"
      continue
    fi

    # A copied WAL lets SQLite recover visits that Chrome has not checkpointed.
    for suffix in -wal -shm; do
      if [ -f "$history$suffix" ] && ! cp "$history$suffix" "$snapshot/History$suffix" 2>/dev/null; then
        failed=1
      fi
    done

    if ! rows=$(sqlite3 -separator ' | ' "$snapshot/History" "
      SELECT
        time(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime'),
        substr(replace(replace(u.title, char(10), ' '), char(13), ' '), 1, 75),
        substr(u.url, 1, 300)
      FROM visits AS v
      JOIN urls AS u ON u.id = v.url
      WHERE date(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime') = '$DATE'
        AND u.url NOT LIKE 'chrome-extension://%'
      ORDER BY v.visit_time;
    " 2>/dev/null); then
      failed=1
    elif [ -n "$rows" ]; then
      printf '%s\n' "--- $profile ---" >>"$all_rows"
      printf '%s\n' "$rows" | sanitize >>"$all_rows"
      count=$(printf '%s\n' "$rows" | awk 'NF { count++ } END { print count + 0 }')
      total_rows=$((total_rows + count))
    fi

    rm -f "$snapshot/History" "$snapshot/History-wal" "$snapshot/History-shm"
    rmdir "$snapshot"
  done

  if [ "$profiles" -eq 0 ]; then
    status 'unavailable (no Chrome profiles were found)'
    rm -f "$all_rows"
  elif [ "$total_rows" -eq 0 ] && [ "$failed" -eq 1 ]; then
    status 'failed (Chrome history could not be read)'
    rm -f "$all_rows"
  elif [ "$total_rows" -eq 0 ]; then
    status 'empty'
    rm -f "$all_rows"
  elif [ "$total_rows" -gt 500 ]; then
    if [ "$failed" -eq 1 ]; then
      status "partial ($total_rows visits saved to $all_rows)"
    else
      status "complete ($total_rows visits saved to $all_rows)"
    fi
  else
    if [ "$failed" -eq 1 ]; then
      status 'partial (some Chrome profiles could not be read)'
    else
      status 'complete'
    fi
    cat "$all_rows"
    rm -f "$all_rows"
  fi
}

printf 'BRIEFING SOURCE DUMP — %s\n' "$DATE"
gather_atuin
gather_claude
gather_opencode
gather_chrome
