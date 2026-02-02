# Server WatchTower

WatchTower is a lightweight, agentless health monitoring runner for a fleet of Linux servers.

It:

- Reads a static inventory (`etc/inventory.csv`)
- Connects over SSH (no agent installed on hosts)
- Collects a small set of health signals and log excerpts
- Produces per-host `summary.json` and a fleet `report.md`
- Optionally sends alert emails on Critical or new Warnings
- Optionally enriches the report with an AI summary (ChatGPT API)

This repository is designed to be safe for cron (idempotent, file-based state, explicit exit codes).

## Requirements

Runner machine (where you execute `bin/watchtower`):

- `bash`
- `ssh` client
- Common tools: `grep`, `awk`, `sed`, `date`, `head`, `tail`
- Recommended:
  - `jq` (improves JSON parsing)
- Optional:
  - `mailx` or a sendmail-compatible MTA (email alerts)
  - `curl` + `jq` (AI summary via ChatGPT API)

Remote hosts:

- Linux with SSH access from the runner

## Installation

1) Clone the repository.

2) Ensure scripts are executable:

```bash
chmod +x bin/watchtower lib/*.sh
```

3) Prepare inventory and config:

- Inventory: `etc/inventory.csv`
- Config: `etc/watchtower.conf`

## Configuration

### Inventory (`etc/inventory.csv`)

CSV header is required:

```csv
host_id,address,ssh_user,ssh_port,tags
```

Example:

```csv
host_id,address,ssh_user,ssh_port,tags
prod-1,10.0.0.10,ubuntu,22,env=prod;role=web
```

Notes:

- `ssh_user` and `ssh_port` are optional.
- `tags` is optional and supports simple filtering.

### Config (`etc/watchtower.conf`)

Key settings:

- Directories:
  - `RUNS_DIR` (default `var/runs`)
  - `STATE_DIR` (default `var/state`)
  - `LOCK_DIR` (default `var/state/locks`)
- SSH:
  - `SSH_CONNECT_TIMEOUT_SECS`
  - `SSH_COMMAND_TIMEOUT_SECS`
- Logs:
  - `LOG_WINDOW` (example: `24h`)
- AI:
  - `AI_ENABLED` (default `false`)
  - `AI_MODEL` (example: `gpt-4o-mini` or `gpt-4o`)
  - `AI_MAX_INPUT_BYTES` (payload cap)
  - `AI_REDACT_PATTERNS` (patterns separated by `;`)
- Email:
  - `EMAIL_ENABLED` (default `true`)
  - `EMAIL_TO`
  - `EMAIL_FROM`
  - `EMAIL_SUBJECT_PREFIX`

Important:

- Config values can be overridden by environment variables.

## Usage

### Dry-run

Validates config/inventory and creates a run directory without SSH:

```bash
bin/watchtower --dry-run --json
```

### Run all hosts

```bash
bin/watchtower --inventory etc/inventory.csv --config etc/watchtower.conf
```

### Filter by host

```bash
bin/watchtower --host prod-1
```

### Filter by tags

```bash
bin/watchtower --tags 'env=prod'
```

### JSON output

```bash
bin/watchtower --json
```

## Output layout

Outputs are written under `var/` (gitignored):

- `var/runs/<run_id>/report.md`
- `var/runs/<run_id>/run.json`
- `var/runs/<run_id>/hosts/<host_id>/summary.json`
- `var/runs/<run_id>/hosts/<host_id>/artifacts/*.txt`
- `var/state/last-run.json`

## Exit codes

- `0`: all Healthy
- `1`: at least one Warning
- `2`: at least one Critical (takes precedence)
- `3`: partial failure (some hosts unreachable/collection failed)
- `>3`: runner/internal error

## Email alerts

Email alerts are sent when:

- any host is `Critical`, or
- a `Warning` is new compared to the previous run

To disable email:

```bash
bin/watchtower --no-email
```

Or in config:

```bash
EMAIL_ENABLED=false
```

## AI report enrichment (ChatGPT API)

To enable AI enrichment you must set `OPENAI_API_KEY` in the environment.

Example test run using `gpt-4o-mini`:

```bash
OPENAI_API_KEY='YOUR_KEY' \
AI_ENABLED=true \
AI_MODEL='gpt-4o-mini' \
bin/watchtower --no-email --json
```

To disable AI for a single run:

```bash
bin/watchtower --no-ai
```

Notes:

- If `AI_ENABLED=true` and `OPENAI_API_KEY` is missing, the run fails with exit code `4`.
- Use `AI_REDACT_PATTERNS` to redact sensitive strings before sending artifacts to the API.

## Cron

A sample cron entry exists at:

- `cron/watchtower.cron`

Adjust paths and ensure the environment provides any secrets (like `OPENAI_API_KEY`).

## Documentation

Project docs and specs:

- `specs/001-server-watchtower/`

Key references:

- `specs/001-server-watchtower/contracts/cli.md`
- `specs/001-server-watchtower/contracts/config.md`
- `specs/001-server-watchtower/quickstart.md`
