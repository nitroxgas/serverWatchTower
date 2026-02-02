#!/usr/bin/env bash
set -euo pipefail

LOG_LEVEL="${LOG_LEVEL:-info}"

RUNS_DIR="${RUNS_DIR:-var/runs}"
STATE_DIR="${STATE_DIR:-var/state}"
LOCK_DIR="${LOCK_DIR:-var/state/locks}"

SSH_CONNECT_TIMEOUT_SECS="${SSH_CONNECT_TIMEOUT_SECS:-10}"
SSH_COMMAND_TIMEOUT_SECS="${SSH_COMMAND_TIMEOUT_SECS:-30}"
MAX_PARALLEL_HOSTS="${MAX_PARALLEL_HOSTS:-5}"

LOG_WINDOW="${LOG_WINDOW:-24h}"
COLLECT_AUTH_LOGS="${COLLECT_AUTH_LOGS:-false}"

AI_ENABLED="${AI_ENABLED:-false}"
AI_MODEL="${AI_MODEL:-}"
AI_MAX_INPUT_BYTES="${AI_MAX_INPUT_BYTES:-200000}"
AI_REDACT_PATTERNS="${AI_REDACT_PATTERNS:-}"

EMAIL_ENABLED="${EMAIL_ENABLED:-true}"
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_FROM="${EMAIL_FROM:-}"
EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX:-[watchtower]}"

RETENTION_DAYS_REPORTS="${RETENTION_DAYS_REPORTS:-30}"
RETENTION_DAYS_ARTIFACTS="${RETENTION_DAYS_ARTIFACTS:-7}"

log_info() {
  printf '%s\n' "INFO: $*" >&2
}

log_warn() {
  printf '%s\n' "WARN: $*" >&2
}

die() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

mktempdir() {
  local d
  d="$(mktemp -d 2>/dev/null || mktemp -d -t watchtower)"
  printf '%s' "$d"
}

acquire_lock() {
  local lock_file="$1"
  local lock_dir
  lock_dir="$(dirname "$lock_file")"
  mkdir -p "$lock_dir"

  if ( set -o noclobber; : >"$lock_file" ) 2>/dev/null; then
    printf '%s' "$$" >"$lock_file"
    return 0
  fi

  return 1
}

release_lock() {
  local lock_file="$1"
  rm -f "$lock_file" 2>/dev/null || true
}

load_config() {
  local config_path="${1:-}"
  if [[ -z "$config_path" ]]; then
    return 0
  fi

  if [[ ! -r "$config_path" ]]; then
    die "cannot read config: $config_path"
  fi

  local env_RUNS_DIR="${RUNS_DIR+x}"
  local env_STATE_DIR="${STATE_DIR+x}"
  local env_LOCK_DIR="${LOCK_DIR+x}"
  local env_SSH_CONNECT_TIMEOUT_SECS="${SSH_CONNECT_TIMEOUT_SECS+x}"
  local env_SSH_COMMAND_TIMEOUT_SECS="${SSH_COMMAND_TIMEOUT_SECS+x}"
  local env_MAX_PARALLEL_HOSTS="${MAX_PARALLEL_HOSTS+x}"
  local env_LOG_WINDOW="${LOG_WINDOW+x}"
  local env_COLLECT_AUTH_LOGS="${COLLECT_AUTH_LOGS+x}"
  local env_AI_ENABLED="${AI_ENABLED+x}"
  local env_AI_MODEL="${AI_MODEL+x}"
  local env_AI_MAX_INPUT_BYTES="${AI_MAX_INPUT_BYTES+x}"
  local env_AI_REDACT_PATTERNS="${AI_REDACT_PATTERNS+x}"
  local env_EMAIL_ENABLED="${EMAIL_ENABLED+x}"
  local env_EMAIL_TO="${EMAIL_TO+x}"
  local env_EMAIL_FROM="${EMAIL_FROM+x}"
  local env_EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX+x}"
  local env_RETENTION_DAYS_REPORTS="${RETENTION_DAYS_REPORTS+x}"
  local env_RETENTION_DAYS_ARTIFACTS="${RETENTION_DAYS_ARTIFACTS+x}"

  local v_RUNS_DIR="${RUNS_DIR:-}"
  local v_STATE_DIR="${STATE_DIR:-}"
  local v_LOCK_DIR="${LOCK_DIR:-}"
  local v_SSH_CONNECT_TIMEOUT_SECS="${SSH_CONNECT_TIMEOUT_SECS:-}"
  local v_SSH_COMMAND_TIMEOUT_SECS="${SSH_COMMAND_TIMEOUT_SECS:-}"
  local v_MAX_PARALLEL_HOSTS="${MAX_PARALLEL_HOSTS:-}"
  local v_LOG_WINDOW="${LOG_WINDOW:-}"
  local v_COLLECT_AUTH_LOGS="${COLLECT_AUTH_LOGS:-}"
  local v_AI_ENABLED="${AI_ENABLED:-}"
  local v_AI_MODEL="${AI_MODEL:-}"
  local v_AI_MAX_INPUT_BYTES="${AI_MAX_INPUT_BYTES:-}"
  local v_AI_REDACT_PATTERNS="${AI_REDACT_PATTERNS:-}"
  local v_EMAIL_ENABLED="${EMAIL_ENABLED:-}"
  local v_EMAIL_TO="${EMAIL_TO:-}"
  local v_EMAIL_FROM="${EMAIL_FROM:-}"
  local v_EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX:-}"
  local v_RETENTION_DAYS_REPORTS="${RETENTION_DAYS_REPORTS:-}"
  local v_RETENTION_DAYS_ARTIFACTS="${RETENTION_DAYS_ARTIFACTS:-}"

  # shellcheck source=/dev/null
  source "$config_path"

  if [[ -n "$env_RUNS_DIR" ]]; then RUNS_DIR="$v_RUNS_DIR"; fi
  if [[ -n "$env_STATE_DIR" ]]; then STATE_DIR="$v_STATE_DIR"; fi
  if [[ -n "$env_LOCK_DIR" ]]; then LOCK_DIR="$v_LOCK_DIR"; fi
  if [[ -n "$env_SSH_CONNECT_TIMEOUT_SECS" ]]; then SSH_CONNECT_TIMEOUT_SECS="$v_SSH_CONNECT_TIMEOUT_SECS"; fi
  if [[ -n "$env_SSH_COMMAND_TIMEOUT_SECS" ]]; then SSH_COMMAND_TIMEOUT_SECS="$v_SSH_COMMAND_TIMEOUT_SECS"; fi
  if [[ -n "$env_MAX_PARALLEL_HOSTS" ]]; then MAX_PARALLEL_HOSTS="$v_MAX_PARALLEL_HOSTS"; fi
  if [[ -n "$env_LOG_WINDOW" ]]; then LOG_WINDOW="$v_LOG_WINDOW"; fi
  if [[ -n "$env_COLLECT_AUTH_LOGS" ]]; then COLLECT_AUTH_LOGS="$v_COLLECT_AUTH_LOGS"; fi
  if [[ -n "$env_AI_ENABLED" ]]; then AI_ENABLED="$v_AI_ENABLED"; fi
  if [[ -n "$env_AI_MODEL" ]]; then AI_MODEL="$v_AI_MODEL"; fi
  if [[ -n "$env_AI_MAX_INPUT_BYTES" ]]; then AI_MAX_INPUT_BYTES="$v_AI_MAX_INPUT_BYTES"; fi
  if [[ -n "$env_AI_REDACT_PATTERNS" ]]; then AI_REDACT_PATTERNS="$v_AI_REDACT_PATTERNS"; fi
  if [[ -n "$env_EMAIL_ENABLED" ]]; then EMAIL_ENABLED="$v_EMAIL_ENABLED"; fi
  if [[ -n "$env_EMAIL_TO" ]]; then EMAIL_TO="$v_EMAIL_TO"; fi
  if [[ -n "$env_EMAIL_FROM" ]]; then EMAIL_FROM="$v_EMAIL_FROM"; fi
  if [[ -n "$env_EMAIL_SUBJECT_PREFIX" ]]; then EMAIL_SUBJECT_PREFIX="$v_EMAIL_SUBJECT_PREFIX"; fi
  if [[ -n "$env_RETENTION_DAYS_REPORTS" ]]; then RETENTION_DAYS_REPORTS="$v_RETENTION_DAYS_REPORTS"; fi
  if [[ -n "$env_RETENTION_DAYS_ARTIFACTS" ]]; then RETENTION_DAYS_ARTIFACTS="$v_RETENTION_DAYS_ARTIFACTS"; fi

  RUNS_DIR="${RUNS_DIR:-var/runs}"
  STATE_DIR="${STATE_DIR:-var/state}"
  LOCK_DIR="${LOCK_DIR:-var/state/locks}"

  SSH_CONNECT_TIMEOUT_SECS="${SSH_CONNECT_TIMEOUT_SECS:-10}"
  SSH_COMMAND_TIMEOUT_SECS="${SSH_COMMAND_TIMEOUT_SECS:-30}"
  MAX_PARALLEL_HOSTS="${MAX_PARALLEL_HOSTS:-5}"
}

generate_run_id() {
  date -u +%Y%m%dT%H%M%SZ
}

ensure_dir() {
  local d="$1"
  mkdir -p "$d"
}

create_run_dir() {
  local repo_root="$1"
  local out_dir_override="${2:-}"
  local run_id="$3"

  local base
  if [[ -n "$out_dir_override" ]]; then
    base="$out_dir_override"
  else
    base="$repo_root/$RUNS_DIR"
  fi

  ensure_dir "$base"
  local run_dir="$base/$run_id"
  ensure_dir "$run_dir"
  ensure_dir "$run_dir/hosts"
  printf '%s\n' "$run_dir"
}
