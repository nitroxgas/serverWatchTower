set -euo pipefail

send_email() {
  local to="$1"
  local subject="$2"
  local body="$3"
  local from="${4:-}"

  if [[ -z "$to" ]]; then
    die "EMAIL_TO is empty"
  fi

  if command -v mailx >/dev/null 2>&1; then
    if [[ -n "$from" ]]; then
      printf '%s\n' "$body" | mailx -r "$from" -s "$subject" "$to"
    else
      printf '%s\n' "$body" | mailx -s "$subject" "$to"
    fi
    return 0
  fi

  if command -v sendmail >/dev/null 2>&1; then
    {
      echo "To: $to"
      if [[ -n "$from" ]]; then
        echo "From: $from"
      fi
      echo "Subject: $subject"
      echo
      printf '%s\n' "$body"
    } | sendmail -t
    return 0
  fi

  die "no mail sender available (need mailx or sendmail)"
}

build_alert_subject() {
  local prefix="$1"
  local run_id="$2"
  local critical_count="$3"
  local new_warning_count="$4"

  local sev=""
  if [[ "$critical_count" -gt 0 ]]; then
    sev="CRITICAL"
  elif [[ "$new_warning_count" -gt 0 ]]; then
    sev="WARNING"
  else
    sev="INFO"
  fi

  printf '%s %s run=%s critical=%s new_warnings=%s' "$prefix" "$sev" "$run_id" "$critical_count" "$new_warning_count"
}

build_alert_body() {
  local run_id="$1"
  local run_dir="$2"
  local report_path="$3"
  local critical_hosts="$4"
  local new_warning_hosts="$5"

  cat <<EOF
WatchTower alert

Run ID: $run_id
Run dir: $run_dir
Report: $report_path

Critical hosts:
$critical_hosts

New warning hosts:
$new_warning_hosts

Notes:
- This alert is sent when any host is Critical or when new Warnings appear compared to the previous run.
EOF
}
