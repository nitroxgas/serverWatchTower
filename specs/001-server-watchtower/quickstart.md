# Quickstart: Server WatchTower

## Prerequisites (runner machine)

- Linux host with:
  - `cron`
  - `bash`
  - `ssh` client
  - common tools: `grep`, `awk`, `sed`, `tar`, `gzip`, `date`
  - email sender: `mailx` (or a sendmail-compatible MTA)
  - `curl`
  - `jq` (recommended; optional if outputs are purely text)

## Repository layout

This feature’s docs live in:

- `specs/001-server-watchtower/`

## Configure inventory

Create an inventory file (example):

- `etc/inventory.csv`

Each line should identify a host and address, plus optional ssh user/port/tags.

## Configure secrets (ChatGPT)

If AI analysis is enabled, provide the API key **via environment**, not in the repo:

- `OPENAI_API_KEY` (required when AI is enabled)

## Configure email

Ensure the runner can send mail (via local MTA or configured `mailx`).

## Schedule with cron

Create a cron entry on the runner that calls the WatchTower CLI on a fixed interval.

- Example file: `cron/watchtower.cron`

## Run manually

Run once manually to validate connectivity and outputs:

- `bin/watchtower --inventory etc/inventory.csv --config etc/watchtower.conf`

## Outputs

Reports and artifacts are written under `var/` (should be gitignored):

- `var/runs/<run_id>/...`
- `var/state/...`
