set -euo pipefail

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

state_last_run_path() {
  local state_dir="$1"
  mkdir -p "$state_dir"
  printf '%s\n' "$state_dir/last-run.json"
}

state_read_last_run_id() {
  local state_dir="$1"
  local p
  p="$(state_last_run_path "$state_dir")"

  [[ -f "$p" ]] || return 1

  local line
  line="$(grep -E '"last_run_id"' "$p" 2>/dev/null | head -n1 || true)"
  [[ -n "$line" ]] || return 1

  printf '%s\n' "$line" | sed -E 's/.*"last_run_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

state_read_warning_fingerprint() {
  local state_dir="$1"
  local host_id="$2"

  local p
  p="$(state_last_run_path "$state_dir")"
  [[ -f "$p" ]] || return 1

  local key
  key="\"$(json_escape "$host_id")\""

  local line
  line="$(grep -E "${key}[[:space:]]*:[[:space:]]*\"" "$p" 2>/dev/null | head -n1 || true)"
  [[ -n "$line" ]] || return 1

  printf '%s\n' "$line" | sed -E 's/.*:[[:space:]]*"([^"]+)".*/\1/'
}

state_write_last_run() {
  local state_dir="$1"
  local run_id="$2"

  local p
  p="$(state_last_run_path "$state_dir")"

  cat >"$p" <<EOF
{"last_run_id":"$run_id"}
EOF
}

warning_fingerprint_from_summary() {
  local summary_path="$1"
  [[ -f "$summary_path" ]] || return 1

  local payload
  if command -v jq >/dev/null 2>&1; then
    payload="$(jq -r '[.status, (.findings[]? | select(.severity=="Warning") | .title + ":" + .evidence)] | join("|")' "$summary_path" 2>/dev/null || true)"
  else
    payload="$(grep -E '"status"|"severity"|"title"|"evidence"' "$summary_path" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' || true)"
  fi

  payload="${payload:-}"

  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$payload" | sha1sum | awk '{print $1}'
    return 0
  fi

  if command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$payload" | md5sum | awk '{print $1}'
    return 0
  fi

  printf '%s' "$payload"
}

state_write_last_run_with_warnings() {
  local state_dir="$1"
  local run_id="$2"
  local warnings_kv="$3"

  local p
  p="$(state_last_run_path "$state_dir")"

  cat >"$p" <<EOF
{"last_run_id":"$(json_escape "$run_id")","warnings":{${warnings_kv}}}
EOF
}
