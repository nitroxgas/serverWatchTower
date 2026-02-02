set -euo pipefail

report_init() {
  local run_dir="$1"
  local run_id="$2"

  local report_path="$run_dir/report.md"
  cat >"$report_path" <<EOF
# WatchTower Report

- Run ID: $run_id
- Generated at (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Fleet Summary

EOF

  printf '%s\n' "$report_path"
}

report_append_fleet_summary() {
  local report_path="$1"
  local total="$2"
  local healthy="$3"
  local warning="$4"
  local critical="$5"
  local failed="$6"

  cat >>"$report_path" <<EOF
- Total hosts: $total
- Healthy: $healthy
- Warning: $warning
- Critical: $critical
- Collection failures: $failed

EOF
}

report_append_host() {
  local report_path="$1"
  local run_dir="$2"
  local host_id="$3"

  local summary_path="$run_dir/hosts/$host_id/summary.json"
  local status="Unknown"

  if [[ -f "$summary_path" ]]; then
    status=$(grep -E '"status"' "$summary_path" | head -n1 | sed -E 's/.*"status"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || echo "Unknown")
  fi

  local captured_at=""
  if [[ -f "$summary_path" ]]; then
    captured_at=$(grep -E '"captured_at"' "$summary_path" | head -n1 | sed -E 's/.*"captured_at"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || echo "")
  fi

  cat >>"$report_path" <<EOF
## Host: $host_id

- Status: **$status**
- Captured at (UTC): ${captured_at:-unknown}
- Summary file: hosts/$host_id/summary.json
- Artifacts: hosts/$host_id/artifacts/

### Findings

EOF

  if [[ -f "$summary_path" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -r '.findings[]? | "- [" + .severity + "] " + .title + " (" + .evidence + ")"' "$summary_path" >>"$report_path" || true
    else
      grep -E '"severity"|"title"|"evidence"' "$summary_path" >>"$report_path" || true
    fi
  else
    echo "- No summary.json" >>"$report_path"
  fi

  echo >>"$report_path"
}

report_write_run_metadata() {
  local run_dir="$1"
  local run_id="$2"
  local inventory_path="$3"

  cat >"$run_dir/run.json" <<EOF
{"run_id":"$run_id","generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","inventory":"$inventory_path"}
EOF
}

report_append_ai_summary() {
  local report_path="$1"
  local ai_text="$2"

  {
    echo
    echo "## AI Summary"
    echo
    echo "**Note**: AI output should be treated as guidance. Validate against the cited evidence."
    echo
    printf '%s\n' "$ai_text"
    echo
  } >>"$report_path"
}
