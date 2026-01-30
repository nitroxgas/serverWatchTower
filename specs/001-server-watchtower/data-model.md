# Data Model: Server WatchTower (file-based)

This feature uses file-based “entities” rather than a database.

## Entities

### Entity: InventoryEntry

- **Represents**: A remote server target.
- **Fields**:
  - `id`: stable identifier/name.
  - `address`: hostname or IP.
  - `ssh_user` (optional)
  - `ssh_port` (optional)
  - `tags` (optional): environment/role/region.

### Entity: Run

- **Represents**: One execution of WatchTower over the whole inventory.
- **Fields**:
  - `run_id`: timestamp-based identifier.
  - `started_at`, `finished_at`
  - `runner_host`
  - `config_snapshot` (optional reference)

### Entity: HostResult

- **Represents**: Output for one host in a run.
- **Fields**:
  - `host_id`
  - `status`: Healthy / Warning / Critical / Unreachable.
  - `findings`: list of finding summaries (severity, title).
  - `evidence_refs`: pointers to collected artifact snippets.
  - `collection_errors` (optional)

### Entity: CollectedArtifact

- **Represents**: A single collected item (command output, log excerpt, metadata).
- **Fields**:
  - `host_id`
  - `source`: e.g. “command:uptime”, “log:syslog”, “journal:kernel”.
  - `captured_at`
  - `content_path` (path on runner)

### Entity: FleetReport

- **Represents**: Human-readable report for the run.
- **Fields**:
  - `run_id`
  - `fleet_status_summary`
  - `per_host_sections`
  - `ai_summary` (optional)

### Entity: StateSnapshot

- **Represents**: Minimal “previous run” info needed to detect “new warnings”.
- **Fields**:
  - `last_run_id`
  - `per_host_last_status`
  - `per_host_warning_fingerprints` (for change detection)

## Storage Layout (proposed)

- `var/runs/<run_id>/`
  - `inventory.normalized.json` (optional)
  - `hosts/<host_id>/`
    - `artifacts/` (raw outputs)
    - `summary.json` (machine-readable findings)
  - `report.md` / `report.txt`
  - `report.json` (optional)
- `var/state/`
  - `last-run.json`
  - `locks/`

## Validation Rules

- Inventory entries must have unique `id` and valid `address`.
- A run must produce a host result for every inventory entry (even if Unreachable).
- State snapshot updates only after a run completes successfully (or with a clear partial-failure mode).
