set -euo pipefail

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  s=${s//$'\t'/\\t}
  s=${s//$'\b'/\\b}
  s=${s//$'\f'/\\f}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

write_unreachable_summary() {
  local run_dir="$1"
  local host_id="$2"
  local error_msg="$3"

  local host_dir="$run_dir/hosts/$host_id"
  mkdir -p "$host_dir"

  local summary_path="$host_dir/summary.json"
  local jhost jerr
  jhost="$(json_escape "$host_id")"
  jerr="$(json_escape "$error_msg")"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat >"$summary_path" <<EOF
{"host_id":"$jhost","status":"Unreachable","captured_at":"$ts","findings":[{"severity":"Warning","title":"Host unreachable","evidence":"$jerr"}],"collection_errors":["$jerr"]}
EOF
}

analyze_host() {
  local run_dir="$1"
  local host_id="$2"

  local host_dir="$run_dir/hosts/$host_id"
  local artifacts_dir="$host_dir/artifacts"
  local summary_path="$host_dir/summary.json"

  local status="Healthy"
  local findings_json=""

  add_finding() {
    local severity="$1"
    local title="$2"
    local evidence="$3"

    local jsev jtitle jev
    jsev="$(json_escape "$severity")"
    jtitle="$(json_escape "$title")"
    jev="$(json_escape "$evidence")"

    local item
    item="{\"severity\":\"$jsev\",\"title\":\"$jtitle\",\"evidence\":\"$jev\"}"

    if [[ -z "$findings_json" ]]; then
      findings_json="$item"
    else
      findings_json+=" ,$item"
    fi

    case "$severity" in
      Critical)
        status="Critical"
        ;;
      Warning)
        if [[ "$status" != "Critical" ]]; then
          status="Warning"
        fi
        ;;
    esac
  }

  if [[ ! -d "$artifacts_dir" ]]; then
    add_finding "Warning" "No artifacts collected" "missing artifacts directory"
  fi

  local dmesg_file="$artifacts_dir/dmesg.txt"
  if [[ -f "$dmesg_file" ]] && grep -qiE '(hardware error|mce|i/o error|ext4-fs error|xfs.*corrupt|call trace|kernel panic|segfault)' "$dmesg_file"; then
    add_finding "Critical" "Kernel/hardware errors detected" "dmesg contains error patterns"
  fi

  local journal_kernel_file="$artifacts_dir/journal-kernel.txt"
  if [[ -f "$journal_kernel_file" ]] && grep -qiE '(hardware error|mce|i/o error|ext4-fs error|xfs.*corrupt|kernel panic)' "$journal_kernel_file"; then
    add_finding "Critical" "Kernel log shows errors" "journal kernel contains error patterns"
  fi

  local df_file="$artifacts_dir/df.txt"
  if [[ -f "$df_file" ]]; then
    local max_use
    max_use=$(awk 'NR>1 {gsub(/%/,"",$5); if($5+0>m)m=$5} END{print m+0}' "$df_file" 2>/dev/null || echo 0)
    if [[ "$max_use" -ge 95 ]]; then
      add_finding "Critical" "Disk usage critically high" "df max used=${max_use}%"
    elif [[ "$max_use" -ge 90 ]]; then
      add_finding "Warning" "Disk usage high" "df max used=${max_use}%"
    fi
  fi

  local free_file="$artifacts_dir/free.txt"
  if [[ -f "$free_file" ]]; then
    local mem_total mem_avail
    mem_total=$(awk '/^Mem:/ {print $2}' "$free_file" 2>/dev/null || echo "")
    mem_avail=$(awk '/^Mem:/ {print $7}' "$free_file" 2>/dev/null || echo "")
    if [[ -n "$mem_total" && -n "$mem_avail" && "$mem_total" -gt 0 ]]; then
      local pct
      pct=$(( (mem_avail * 100) / mem_total ))
      if [[ "$pct" -le 5 ]]; then
        add_finding "Critical" "Memory available very low" "MemAvailable ~${pct}%"
      elif [[ "$pct" -le 10 ]]; then
        add_finding "Warning" "Memory available low" "MemAvailable ~${pct}%"
      fi
    fi
  fi

  local uptime_file="$artifacts_dir/uptime.txt"
  if [[ ! -f "$uptime_file" ]]; then
    add_finding "Warning" "Missing uptime signal" "uptime not collected"
  fi

  if [[ -z "$findings_json" ]]; then
    findings_json=""
  fi

  local jstatus
  jstatus="$(json_escape "$status")"

  cat >"$summary_path" <<EOF
{"host_id":"$(json_escape "$host_id")","status":"$jstatus","findings":[${findings_json}]}
EOF

  printf '%s\n' "$status"
}
