# Server WatchTower: Remote Linux Health Reports

## Summary

Create a set of scripts that periodically assess the health of remote Linux servers, collect key system logs and diagnostics, generate an AI-analyzed health report, and notify operators by email when issues are detected (hardware errors, usage spikes, and other evidence of system failure).

## Problem Statement

Operators need a reliable, repeatable way to:

- Detect early signals of hardware failure and system instability.
- Identify resource pressure (CPU, memory, disk, IO) and abnormal spikes.
- Centralize key logs for investigation and auditing.
- Receive actionable summaries instead of raw log dumps.

## Goals

- Periodically collect health indicators and relevant logs from remote Linux hosts.
- Produce a per-host and fleet-level report with:
  - Current status.
  - Detected anomalies and their evidence.
  - Suggested next actions.
- Use AI analysis (ChatGPT) to turn raw signals into a concise, actionable narrative.
- Send email notifications when high-severity issues are detected.
- Work across common Linux distributions with minimal prerequisites.

## Non-Goals

- Continuous streaming observability (metrics/log pipelines) as a replacement for a monitoring stack.
- Automated remediation actions on hosts.
- Agent installation on every host as a strict requirement (agentless is the default assumption).

## Users

- **Sysadmin / SRE**: Wants daily summaries and immediate alerts for severe issues.
- **On-call operator**: Needs evidence and links/attachments sufficient to triage quickly.

## Assumptions

- Hosts are reachable via network and allow non-interactive remote access.
- Authentication is done via SSH keys (recommended) or an equivalent secure method.
- Operators can provide an inventory file listing the target servers.
- AI usage is allowed for operational data and follows the organization’s security policy.

## Scope & Boundaries

### In scope

- Remote collection of:
  - System identity and uptime.
  - Resource usage summaries.
  - Disk usage and inode usage.
  - Kernel/system error indicators.
  - Hardware error indicators when available.
  - Selected log excerpts.
- Local packaging of collected artifacts per run.
- AI analysis of collected artifacts to generate a report.
- Email delivery of:
  - A summary (human-readable).
  - Attachments or references to raw collected artifacts.

### Out of scope

- Managing SSH key distribution.
- Editing host configuration.
- Making privileged changes to enable additional telemetry.

## Inventory

The system must accept a **static inventory file** that defines which hosts are checked.

### Inventory requirements

- Each host entry must include:
  - Unique host name/identifier.
  - Network address (hostname or IP).
- Each host entry may include:
  - SSH port.
  - Remote username.
  - Tags (environment, role, region) used in reporting and filtering.

## Health Signals to Collect

The system must collect enough evidence to support diagnosis and AI summarization.

### Hardware and kernel error evidence

- Evidence of disk/IO errors.
- Evidence of filesystem corruption warnings.
- Evidence of memory errors (when available).
- Evidence of kernel panics/oops.
- Evidence of hardware event logs (when available).

### Resource utilization and spike evidence

- CPU utilization summary and recent load.
- Memory usage summary and swap activity.
- Disk usage summary (including high-water marks if available).
- IO pressure indicators when available.

### Core operational logs (high-value)

- System log excerpts that commonly contain failures (boot, kernel, service failures).
- Authentication and security-related logs (for anomaly context).

## AI Report Requirements (ChatGPT)

The system must generate an AI-analyzed report per run.

### Report structure

- **Executive summary**: Overall fleet status.
- **Per-host status**:
  - Status: Healthy / Warning / Critical.
  - Findings: bullet list with severity.
  - Evidence: short quotes/snippets, timestamps, and which source produced it.
  - Suggested actions: operator-oriented next steps.
- **Trends** (if previous runs exist): identify regressions/improvements.

### AI input constraints

- The AI prompt must include:
  - The time window of data.
  - The host tags/context.
  - Clear instructions to cite evidence from the provided artifacts.
- The AI output must:
  - Be concise.
  - Avoid speculation when evidence is missing.
  - Clearly distinguish “observed evidence” vs “hypothesis”.

## Alerting Requirements (Email)

- The system must send an email when:
  - Any host is **Critical**, or
  - A new **Warning** appears compared to the previous run.
- The email must include:
  - Run timestamp.
  - Affected hosts.
  - Top findings and recommended next actions.
  - A way to access or attach raw artifacts.

## Data Retention

- The system must retain:
  - Reports for a configurable retention period.
  - Raw artifacts (logs/diagnostics) for a configurable retention period.
- The system must support deleting old runs according to retention settings.

## Security & Privacy

- Credentials and secrets must not be stored in plaintext inside the repository.
- The solution must minimize collection of sensitive data:
  - Prefer summaries and targeted excerpts.
  - Avoid collecting full logs unless explicitly configured.
- When sending data to ChatGPT, the system must support:
  - Redacting known sensitive patterns (tokens, passwords) before upload.
  - A configuration switch to disable AI analysis (fallback to non-AI report).

## Reliability & Operability

- Each run must produce a clear success/failure status per host.
- Failures to reach a host must be reported as such (not silently ignored).
- The system must be able to run periodically without manual intervention.
- The system must be safe to run concurrently or prevent overlapping runs.

## User Scenarios & Testing

### Scenario 1: Daily fleet report

- Given an inventory file with multiple hosts
- When the scheduled run completes
- Then a fleet report is generated with per-host status and evidence
- And raw artifacts are stored for later investigation

### Scenario 2: Critical hardware error

- Given a host with disk I/O errors reported in system logs
- When the run completes
- Then the host is marked **Critical**
- And an email alert is sent listing the host, the error evidence, and recommended next actions

### Scenario 3: Usage spike warning

- Given a host exhibiting abnormal load or memory pressure compared to recent baselines
- When the run completes
- Then the host is marked **Warning**
- And the report includes the evidence and timestamps supporting the finding

### Scenario 4: Host unreachable

- Given a host that is unreachable or authentication fails
- When the run completes
- Then the report marks the host as **Unreachable** (or equivalent)
- And the report includes the reason and timing

## Functional Requirements

- **FR1**: The system must load a static inventory file defining target hosts.
- **FR2**: The system must connect to each host and collect the defined health signals.
- **FR3**: The system must store collected artifacts per host and per run.
- **FR4**: The system must produce a report containing fleet summary and per-host findings.
- **FR5**: The system must analyze collected artifacts using ChatGPT to generate human-readable findings.
- **FR6**: The system must support running in a defined time window and record run metadata.
- **FR7**: The system must send email alerts for critical findings and newly detected warnings.
- **FR8**: The system must support configurable retention for reports and artifacts.
- **FR9**: The system must produce deterministic exit codes/status suitable for automation (success with warnings, partial failure, full failure).

## Non-Functional Requirements

- **NFR1**: Must complete a run across N hosts within an acceptable operational window (configurable).
- **NFR2**: Must not significantly impact host performance (low overhead collection).
- **NFR3**: Must log its own actions and errors for auditing and troubleshooting.
- **NFR4**: Must handle partial failures and continue collecting from other hosts.

## Success Criteria

- A daily run produces a report that operators can use to identify:
  - At least the top 3 actionable risks across the fleet (when present).
  - Clear evidence references for each finding.
- Email alerts are delivered within an acceptable time after run completion for critical events.
- Operators can answer “what changed since yesterday?” using the generated reports.

## Open Questions

None.
