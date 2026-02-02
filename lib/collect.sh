set -euo pipefail

collect_log_window_arg() {
  local w="${1:-24h}"
  case "$w" in
    *h|*m|*d)
      printf '%s' "-$w"
      ;;
    *)
      printf '%s' "-$w"
      ;;
  esac
}

collect_host_dirs() {
  local run_dir="$1"
  local host_id="$2"

  local host_dir="$run_dir/hosts/$host_id"
  local artifacts_dir="$host_dir/artifacts"

  mkdir -p "$artifacts_dir"
  printf '%s\n' "$host_dir"
}

collect_write_artifact() {
  local run_dir="$1"
  local host_id="$2"
  local artifact_name="$3"
  local content="$4"

  local host_dir
  host_dir="$(collect_host_dirs "$run_dir" "$host_id")"
  local out="$host_dir/artifacts/$artifact_name.txt"
  printf '%s\n' "$content" >"$out"
  printf '%s\n' "$out"
}

ssh_run() {
  local address="$1"
  local ssh_user="${2:-}"
  local ssh_port="${3:-}"
  local connect_timeout_secs="${4:-10}"
  local command_timeout_secs="${5:-30}"
  local remote_cmd="$6"

  require_cmd ssh

  local target="$address"
  if [[ -n "$ssh_user" ]]; then
    target="$ssh_user@$address"
  fi

  local -a ssh_args
  ssh_args=(
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o ConnectTimeout="$connect_timeout_secs"
    -o ServerAliveInterval=10
    -o ServerAliveCountMax=1
  )

  if [[ -n "$ssh_port" ]]; then
    ssh_args+=( -p "$ssh_port" )
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "$command_timeout_secs" ssh "${ssh_args[@]}" "$target" "$remote_cmd"
  else
    ssh "${ssh_args[@]}" "$target" "$remote_cmd"
  fi
}

collect_ssh_artifact() {
  local run_dir="$1"
  local host_id="$2"
  local address="$3"
  local ssh_user="${4:-}"
  local ssh_port="${5:-}"
  local artifact_name="$6"
  local remote_cmd="$7"
  local connect_timeout_secs="${8:-10}"
  local command_timeout_secs="${9:-30}"

  local host_dir
  host_dir="$(collect_host_dirs "$run_dir" "$host_id")"

  local out="$host_dir/artifacts/$artifact_name.txt"
  local err="$host_dir/artifacts/$artifact_name.err.txt"

  if ssh_run "$address" "$ssh_user" "$ssh_port" "$connect_timeout_secs" "$command_timeout_secs" "$remote_cmd" >"$out" 2>"$err"; then
    printf '%s\n' "$out"
    return 0
  fi

  return 1
}

collect_check_connectivity() {
  local run_dir="$1"
  local host_id="$2"
  local address="$3"
  local ssh_user="${4:-}"
  local ssh_port="${5:-}"
  local connect_timeout_secs="${6:-10}"
  local command_timeout_secs="${7:-15}"

  local host_dir
  host_dir="$(collect_host_dirs "$run_dir" "$host_id")"

  local out="$host_dir/artifacts/connectivity.txt"
  local err="$host_dir/artifacts/connectivity.err.txt"

  if ssh_run "$address" "$ssh_user" "$ssh_port" "$connect_timeout_secs" "$command_timeout_secs" "echo ok" >"$out" 2>"$err"; then
    return 0
  fi

  return 1
}

collect_us1_signals() {
  local run_dir="$1"
  local host_id="$2"
  local address="$3"
  local ssh_user="${4:-}"
  local ssh_port="${5:-}"
  local connect_timeout_secs="${6:-10}"
  local command_timeout_secs="${7:-30}"
  local log_window="${8:-24h}"

  local since_arg
  since_arg="$(collect_log_window_arg "$log_window")"

  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "uname" "uname -a" "$connect_timeout_secs" "$command_timeout_secs" || true
  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "uptime" "uptime" "$connect_timeout_secs" "$command_timeout_secs" || true

  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "df" "df -P -h" "$connect_timeout_secs" "$command_timeout_secs" || true
  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "free" "free -b" "$connect_timeout_secs" "$command_timeout_secs" || true

  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "dmesg" "dmesg -T 2>/dev/null | tail -n 200 || dmesg | tail -n 200" "$connect_timeout_secs" "$command_timeout_secs" || true

  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "journal-kernel" "journalctl -k --no-pager --since '$since_arg' 2>/dev/null | tail -n 300 || true" "$connect_timeout_secs" "$command_timeout_secs" || true

  collect_ssh_artifact "$run_dir" "$host_id" "$address" "$ssh_user" "$ssh_port" "syslog" "(test -f /var/log/syslog && tail -n 300 /var/log/syslog) || (test -f /var/log/messages && tail -n 300 /var/log/messages) || (journalctl --no-pager --since '$since_arg' 2>/dev/null | tail -n 300) || true" "$connect_timeout_secs" "$command_timeout_secs" || true
}
