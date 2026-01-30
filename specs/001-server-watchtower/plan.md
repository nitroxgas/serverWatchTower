# Implementation Plan: Server WatchTower
 
 **Branch**: `001-server-watchtower` | **Date**: 2026-01-30 | **Spec**: ./spec.md
 **Input**: Feature specification from `/specs/[###-feature-name]/spec.md`
 
 **Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.
 
 ## Summary
 
 Build an agentless (SSH-based) set of Bash scripts executed periodically via cron to collect key health signals and log excerpts from remote Linux servers, generate a per-run report, enrich it with AI analysis via ChatGPT, and send email alerts when critical issues or new warnings are detected. No database is used; all state is file-based.
 
 ## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Bash (POSIX-ish + common GNU userland)
**Primary Dependencies**: cron, ssh, scp (optional), awk/sed/grep, coreutils, gzip/tar, mailx (or sendmail-compatible), curl, jq (optional but recommended)
**Storage**: Filesystem (per-run artifacts + reports + a small state file for diffing “new warnings”)
**Testing**: Shell-based checks (e.g., bats or minimal test harness scripts)
**Target Platform**: Linux (runner machine) + Remote Linux servers accessed by SSH
**Project Type**: Single project (CLI scripts)
**Performance Goals**: Complete a run across configured hosts inside the cron window (configurable timeout per host)
**Constraints**: No database; only common Linux tools; safe for unattended cron; avoid collecting overly sensitive data by default
**Scale/Scope**: Dozens to hundreds of hosts (bounded by SSH concurrency limits and timeouts)
 
 ## Constitution Check
 
 *GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
 
 The project constitution file is currently a placeholder (no concrete gates defined). Proceeding with the following default gates:
 
 - Keep the solution simple (file-based, no DB).
 - Provide a CLI-first workflow suitable for automation (cron).
 - Keep secrets out of the repository.
 
 ## Project Structure

### Documentation (this feature)

 ```text
 specs/[###-feature]/
 ├── plan.md              # This file (/speckit.plan command output)
 ├── research.md          # Phase 0 output (/speckit.plan command)
 ├── data-model.md        # Phase 1 output (/speckit.plan command)
 ├── quickstart.md        # Phase 1 output (/speckit.plan command)
 ├── contracts/           # Phase 1 output (/speckit.plan command)
 └── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
 ```
 
 ### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

 ```text
 bin/
 ├── watchtower                # Main entrypoint (CLI)
 
 lib/
 ├── common.sh                 # logging, error handling, helpers
 ├── inventory.sh              # parse inventory file
 ├── collect.sh                # SSH collection per-host
 ├── analyze.sh                # local rule-based analysis
 ├── ai.sh                     # ChatGPT integration (optional)
 ├── report.sh                 # compose final report
 ├── alert.sh                  # email notifications
 └── retention.sh              # retention cleanup
 
 etc/
 ├── watchtower.conf           # configuration (paths, thresholds, timeouts)
 └── inventory.csv             # example inventory
 
 var/
 ├── runs/                     # per-run artifacts and reports (gitignored)
 └── state/                    # small state files for comparison (gitignored)
 
 cron/
 └── watchtower.cron           # sample cron entry
 
 tests/
 ├── smoke/                    # run locally against a test host
 └── unit/                     # shell tests for parsing/formatting
 ```
 
 **Structure Decision**: Single Bash-based CLI project with a small `lib/` of sourced modules, runnable unattended via cron.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
