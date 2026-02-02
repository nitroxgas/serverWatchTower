# Tasks: Server WatchTower

**Input**: Design documents from `/specs/001-server-watchtower/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested in the specification. Tasks below focus on implementation and smoke validation.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create runnable Bash project skeleton aligned with plan.md

- [ ] T001 Create directory structure `bin/ lib/ etc/ var/runs/ var/state/ cron/ tests/smoke/` at repository root
- [ ] T002 [P] Add `bin/watchtower` executable entrypoint (shebang, strict mode, help output) in `bin/watchtower`
- [ ] T003 [P] Add shared helpers (logging, temp files, exit codes, locking helpers) in `lib/common.sh`
- [ ] T004 [P] Add default configuration file template in `etc/watchtower.conf`
- [ ] T005 [P] Add example inventory in `etc/inventory.csv`
- [ ] T006 Add `.gitignore` entries for `var/` outputs and run artifacts in `.gitignore`
- [ ] T007 Add sample cron entry file in `cron/watchtower.cron`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core modules required by all user stories

- [ ] T008 Implement inventory parser (CSV parsing + validation + tag filtering) in `lib/inventory.sh`
- [ ] T009 Implement configuration loader (source config file + env overrides + defaults) in `lib/common.sh`
- [ ] T010 Implement run directory creation + run_id generation in `lib/common.sh`
- [ ] T011 Implement per-host SSH runner with connect/command timeouts in `lib/collect.sh`
- [ ] T012 Implement artifact writing conventions (per-host artifacts/summary paths) in `lib/collect.sh`
- [ ] T013 Implement baseline state read/write (last-run snapshot) in `lib/retention.sh`

**Checkpoint**: Foundation ready (CLI can parse inventory/config and create run directories)

---

## Phase 3: User Story 1 - Daily fleet report (Priority: P1) 🎯 MVP

**Goal**: Generate a fleet report with per-host status and evidence from collected signals

**Independent Test**: Run `bin/watchtower --inventory etc/inventory.csv --no-ai --no-email --dry-run` and `bin/watchtower --host <id> --no-ai --no-email` produces a run directory and a readable report.

- [ ] T014 [US1] Wire CLI flags and dispatch flow (`--inventory`, `--config`, `--out-dir`, `--host`, `--tags`, `--since`, `--json`, `--verbose`, `--dry-run`) in `bin/watchtower`
- [ ] T015 [P] [US1] Collect basic identity and uptime signals via SSH in `lib/collect.sh`
- [ ] T016 [P] [US1] Collect resource summaries (cpu/load/mem/swap/disk) via SSH in `lib/collect.sh`
- [ ] T017 [P] [US1] Collect kernel/system error indicators (dmesg/journal excerpts) via SSH in `lib/collect.sh`
- [ ] T018 [P] [US1] Collect selected log excerpts (syslog/messages) within configured window in `lib/collect.sh`
- [ ] T019 [US1] Implement rule-based analyzer producing `summary.json` (Healthy/Warning/Critical + findings + evidence refs) in `lib/analyze.sh`
- [ ] T020 [US1] Implement report composer to generate `report.md` (fleet + per-host sections) in `lib/report.sh`
- [ ] T021 [US1] Persist run metadata and report outputs under `var/runs/<run_id>/` in `lib/report.sh`
- [ ] T022 [US1] Write/print correct exit code mapping (0/1/2/3) based on results in `bin/watchtower`

**Checkpoint**: US1 complete (fleet report works without AI and without email)

---

## Phase 4: User Story 2 - Host unreachable handling (Priority: P2)

**Goal**: Unreachable hosts are clearly reported and do not block the run

**Independent Test**: Add a bogus host to inventory and run; report marks it `Unreachable` and exit code reflects partial failure.

- [ ] T023 [US2] Detect SSH connect/auth failures and record `collection_errors` in `lib/collect.sh`
- [ ] T024 [US2] Ensure analyzer maps collection failures to `Unreachable` host status with evidence in `lib/analyze.sh`
- [ ] T025 [US2] Ensure report includes unreachable reason and timestamps in `lib/report.sh`
- [ ] T026 [US2] Ensure exit code `3` is used for partial failures (some unreachable) without masking critical findings in `bin/watchtower`

---

## Phase 5: User Story 3 - Email alerts on critical/new warnings (Priority: P3)

**Goal**: Send email notifications when any host is Critical or when a Warning is new compared to previous run

**Independent Test**: Run twice with a controlled warning; second run does not re-alert unless warning fingerprint changes. Critical always alerts.

- [ ] T027 [US3] Implement warning fingerprinting + compare with `var/state/last-run.json` in `lib/retention.sh`
- [ ] T028 [US3] Implement email sender wrapper (mailx/sendmail) with clear error reporting in `lib/alert.sh`
- [ ] T029 [US3] Compose alert email subject/body (run_id, affected hosts, top findings, where to find artifacts) in `lib/alert.sh`
- [ ] T030 [US3] Trigger alerts for Critical and new Warnings; respect `--no-email` and `EMAIL_ENABLED` in `bin/watchtower`
- [ ] T031 [US3] Update last-run snapshot only after report is successfully generated in `lib/retention.sh`

---

## Phase 6: User Story 4 - AI report enrichment via ChatGPT (Priority: P4)

**Goal**: Enrich the report with an AI-generated summary citing evidence; must be disableable and redact sensitive patterns

**Independent Test**: With `--no-ai` report has no AI section; with AI enabled and missing API key, run fails with clear error.

- [ ] T032 [US4] Implement artifact selection and size capping for AI prompt payload in `lib/ai.sh`
- [ ] T033 [US4] Implement redaction (configurable patterns) before sending content to AI in `lib/ai.sh`
- [ ] T034 [US4] Implement ChatGPT call (via HTTPS API) and handle failures/timeouts in `lib/ai.sh`
- [ ] T035 [US4] Integrate AI summary into report output while keeping “observed vs hypothesis” separation in `lib/report.sh`
- [ ] T036 [US4] Wire `--no-ai` and `AI_ENABLED` behavior and missing-secret validation in `bin/watchtower`

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Retention, hardening, and operational readiness

- [ ] T037 [P] Add retention cleanup for old runs/artifacts based on config in `lib/retention.sh`
- [ ] T038 Add concurrency lock to prevent overlapping cron runs in `lib/common.sh` and `bin/watchtower`
- [ ] T039 [P] Add `--dry-run` output showing which hosts would run and where outputs go in `bin/watchtower`
- [ ] T040 [P] Add a smoke script that runs `bin/watchtower` with `--dry-run` and validates outputs/exit codes in `tests/smoke/smoke.sh`
- [ ] T041 Update `specs/001-server-watchtower/quickstart.md` with final command examples and notes about cron + secrets

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** blocks everything else.
- **Phase 2 (Foundational)** blocks all user stories.
- **US1** depends on Phase 2.
- **US2** depends on Phase 2 and integrates naturally with US1 flows.
- **US3** depends on Phase 2 and (for “new warning” diff) on state snapshot from US1.
- **US4** depends on Phase 2 and report composition from US1.

## Parallel Opportunities

- Tasks marked **[P]** can be done in parallel (different files / non-overlapping concerns).

## MVP Scope Recommendation

- Implement through **Phase 3 (US1)** first: daily report generation without AI/email.
