# Research: Server WatchTower (Bash + cron)

## Decisions

### Decision: Scheduling via cron

- **Chosen**: Use cron on the runner host to execute WatchTower periodically.
- **Rationale**: Ubiquitous on Linux, minimal dependencies, fits “periodic batch” health checks.
- **Alternatives considered**:
  - systemd timers: good alternative but not universally configured/available.
  - Kubernetes CronJob: adds operational overhead and changes deployment model.

### Decision: Bash as implementation language

- **Chosen**: Bash scripts with small, modular sourced libraries.
- **Rationale**: Aligns with requirement to use common Linux tools; easy to deploy without runtime installation.
- **Alternatives considered**:
  - Python: stronger ergonomics/testing but violates “bash as programming language”.

### Decision: Agentless collection via SSH

- **Chosen**: SSH remote execution to collect signals, with timeouts and strict error handling.
- **Rationale**: Avoid installing agents on servers; widely supported.
- **Alternatives considered**:
  - Agent-based collectors: richer telemetry but higher operational cost.

### Decision: No database; file-based state

- **Chosen**: Store per-run artifacts and reports under a local directory and maintain small state files for comparison.
- **Rationale**: Matches “no database”; sufficient for daily comparisons.
- **Alternatives considered**:
  - SQLite/PostgreSQL: more queryability but against constraints.

### Decision: AI analysis via ChatGPT

- **Chosen**: Optional AI summarization step using ChatGPT; must be disableable.
- **Rationale**: Converts noisy logs into actionable summaries.
- **Alternatives considered**:
  - Fully rule-based only: simpler but less helpful narrative.

### Decision: Alerting via email

- **Chosen**: Email alerts for Critical and “new warnings”.
- **Rationale**: Minimal integration burden; universally available.
- **Alternatives considered**:
  - Chat/webhooks: faster but requires integrations.

## Best Practices / Notes

- Prefer collecting targeted excerpts rather than full logs to reduce sensitive data.
- Ensure SSH commands are bounded by timeouts; failures must not block the whole run.
- For ChatGPT, redact secrets and avoid collecting authentication logs unless explicitly enabled.
- Use lock files to prevent overlapping cron runs.
- Keep all secrets out of the repository (API keys, SMTP creds).
