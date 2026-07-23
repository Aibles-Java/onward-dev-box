# 0018 — `docs/RUNBOOK.md` day-1 developer guide (issue #16)

**Date:** 2026-07-12

## What

Added `docs/RUNBOOK.md` (docs/INFRASTRUCTURE.md §3, item 3.4) — the day-1 guide a
developer who has never seen the repo can follow to get to a running app. Marked §3.4
done and updated the §2 tree comment ("to be written" → "done — issue #16").

## Design choices

- **Sourced every fact from the repo, not memory.** Prereqs/JDK-21 wording taken from
  `scripts/doctor.sh` fail hints; ports from `docs/INFRASTRUCTURE.md` §4 registry and
  `.env.example`; URLs from `docker-compose.yml` port mappings (app :8081, Sonar :9000,
  Adminer :8090, Postgres :5432); sonar flow from `sonarqube/bootstrap.sh` + `make sonar`.
- **`make run` is the daily driver, not `make init && make up && make run`.** The issue
  title lists all three, but `make run` already `up`s the core profile and waits — so the
  quick start is `make init` (once, for `.env` + doctor) then `make run`. `make up`
  documented separately as "DB only, no app".
- **Common-failures table mirrors `doctor.sh` fix lines** so the runbook and the preflight
  never drift: port 8081 conflict, dirty-DB→`make nuke` (init SQL runs only on first boot),
  SonarQube 4 GB / Linux `vm.max_map_count`, wrong JDK via `JAVA_HOME`.
- **`make smoke` self-resets the DB, so the runbook does NOT tell you to `make nuke`
  first.** After rebasing onto `develop` (which landed `make db-reset` + "smoke resets the
  DB first", see [[0017-smoke-test-script]]), §7 was corrected: the smoke loop is just
  `make run` (one terminal) + `make smoke` (another) — smoke truncates via `db-reset`
  in place, repeatable, `SMOKE_NO_RESET=1` to skip. `make nuke` is only for a full volume
  wipe (e.g. schema change), not a normal smoke run. The earlier draft's `make nuke`
  pre-step was stale.
- **Documented `make smoke` as known-red up front** (blocked on feature_flag#52, see
  [[0017-smoke-test-script]]) so a day-1 dev isn't alarmed when the smoke test fails
  through no fault of their setup.

## Status

Docs-only change on `feature/issue-16-runbook`. No DoD checkbox in §6 (that section is
Phase 1+2; RUNBOOK is Phase 3). Acceptance is qualitative ("a fresh dev can reach a
running app using only the runbook") — the guide is self-contained and every command in
it is a real, tested `make` target.
