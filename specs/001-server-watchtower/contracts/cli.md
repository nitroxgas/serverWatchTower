# Contract: CLI (watchtower)

This document defines the CLI surface for the WatchTower runner.

## Command

- `watchtower`

## Options

- `--inventory <path>`: path to inventory file (required)
- `--config <path>`: path to config file (optional; defaults to `etc/watchtower.conf` if present)
- `--out-dir <path>`: override output base directory (optional)
- `--since <duration>`: limit log collection window (optional)
- `--host <id>`: run only for a single host (optional)
- `--tags <k=v,...>`: filter hosts by tags (optional)
- `--no-ai`: disable AI enrichment (optional)
- `--no-email`: disable email alerts (optional)
- `--dry-run`: validate inventory/config and print planned actions, without connecting (optional)
- `--json`: machine-readable output summary on stdout (optional)
- `--verbose`: verbose logs on stderr (optional)

## Exit codes

- `0`: success, no warnings/criticals
- `1`: success with warnings (at least one host Warning)
- `2`: critical findings detected (at least one host Critical)
- `3`: partial failure (some hosts unreachable/collection failed)
- `>3`: runner/internal error

## Output

- Human-readable summary on stdout (unless `--json`).
- Logs and diagnostic messages on stderr.
- Detailed artifacts persisted to the run directory.
