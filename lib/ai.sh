set -euo pipefail

ai_requirements_check() {
  require_cmd curl
  require_cmd jq

  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    die "AI enabled but OPENAI_API_KEY is not set"
  fi
}

ai_redact_stream() {
  local patterns="${1:-}"

  if [[ -z "$patterns" ]]; then
    cat
    return 0
  fi

  local tmp
  tmp="$(mktempdir)/ai_redact.sed"

  : >"$tmp"

  local p
  IFS=';' read -ra parts <<<"$patterns"
  for p in "${parts[@]}"; do
    p="${p//[$'\r\n\t ']/}"
    [[ -z "$p" ]] && continue
    printf 's/%s/[REDACTED]/g\n' "$p" >>"$tmp"
  done

  sed -E -f "$tmp"
}

ai_build_prompt_payload() {
  local run_dir="$1"
  local max_bytes="$2"

  local tmp
  tmp="$(mktempdir)/ai_payload.txt"

  {
    echo "WatchTower run directory: $run_dir"
    echo "Generated at (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "Instructions:"
    echo "- Summarize server health."
    echo "- Cite evidence from the provided artifacts."
    echo "- Separate 'Observed evidence' from 'Hypotheses'."
    echo "- Be concise and actionable."
    echo

    if [[ -f "$run_dir/report.md" ]]; then
      echo "=== Existing Report (non-AI) ==="
      cat "$run_dir/report.md"
      echo
    fi

    if [[ -d "$run_dir/hosts" ]]; then
      for host_dir in "$run_dir/hosts"/*; do
        [[ -d "$host_dir" ]] || continue
        host_id="$(basename "$host_dir")"
        echo "=== Host: $host_id ==="

        if [[ -f "$host_dir/summary.json" ]]; then
          echo "-- summary.json --"
          cat "$host_dir/summary.json"
          echo
        fi

        for f in uname uptime df free dmesg journal-kernel syslog connectivity; do
          p="$host_dir/artifacts/${f}.txt"
          [[ -f "$p" ]] || continue
          echo "-- artifact: $f.txt --"
          head -c 4000 "$p" || true
          echo
        done

        errp="$host_dir/artifacts/connectivity.err.txt"
        if [[ -f "$errp" ]]; then
          echo "-- artifact: connectivity.err.txt --"
          head -c 2000 "$errp" || true
          echo
        fi
      done
    fi
  } >"$tmp"

  if [[ -n "$max_bytes" && "$max_bytes" -gt 0 ]]; then
    head -c "$max_bytes" "$tmp" || true
  else
    cat "$tmp"
  fi
}

ai_chatgpt_summarize_run() {
  local run_dir="$1"

  ai_requirements_check

  local model
  model="${AI_MODEL:-gpt-4o-mini}"

  local max_bytes
  max_bytes="${AI_MAX_INPUT_BYTES:-200000}"

  local payload
  payload="$(ai_build_prompt_payload "$run_dir" "$max_bytes" | ai_redact_stream "${AI_REDACT_PATTERNS:-}")"

  local req
  req="$(jq -n --arg model "$model" --arg content "$payload" '{model:$model, messages:[{role:"system",content:"You are an ops assistant. Produce a health report based only on provided evidence."},{role:"user",content:$content}], temperature:0.2}')"

  local resp
  resp="$(curl -sS --fail --max-time 45 \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$req" \
    https://api.openai.com/v1/chat/completions)"

  jq -r '.choices[0].message.content // empty' <<<"$resp"
}
