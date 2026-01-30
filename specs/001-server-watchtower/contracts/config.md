# Contract: Configuration (watchtower.conf)

This document defines the configuration knobs for WatchTower. The format is an implementation choice, but the configuration must support the following keys.

## Required/Recommended keys

- `RUNS_DIR`: base directory for run outputs (default: `var/runs`)
- `STATE_DIR`: base directory for state (default: `var/state`)
- `LOCK_DIR`: directory for lock files (default: `var/state/locks`)

- `SSH_CONNECT_TIMEOUT_SECS`: per-host SSH connect timeout
- `SSH_COMMAND_TIMEOUT_SECS`: per-command timeout
- `MAX_PARALLEL_HOSTS`: max concurrent hosts per run

- `LOG_WINDOW`: time window for log excerpt collection (e.g., “24h”)
- `COLLECT_AUTH_LOGS`: boolean, default false

- `AI_ENABLED`: boolean, default false
- `AI_MODEL`: string identifier
- `AI_MAX_INPUT_BYTES`: cap for prompt payload
- `AI_REDACT_PATTERNS`: list/patterns to redact

- `EMAIL_ENABLED`: boolean, default true
- `EMAIL_TO`: comma-separated recipients
- `EMAIL_FROM`: sender
- `EMAIL_SUBJECT_PREFIX`

- `RETENTION_DAYS_REPORTS`
- `RETENTION_DAYS_ARTIFACTS`

## Behavioral requirements

- If `AI_ENABLED=true`, WatchTower must error clearly when the required environment secret is missing.
- If `EMAIL_ENABLED=true`, WatchTower must emit a clear error when email sending fails.
- All defaults must be safe and privacy-preserving (no full log dumps unless enabled).
