# 0014 — `make sonar` target (issue #12), verified as issue #13 Phase 2 gate

**Date:** 2026-07-05

## What

Added `sonar:` to the Makefile (docs/INFRASTRUCTURE.md §3, item 2.2). Runs
`cd $(FF_DIR) && ./mvnw verify sonar:sonar` against the sibling `../feature_flag`
checkout, sourcing `.env` for `SONAR_TOKEN`/`SONAR_PORT`. Mirrors `make run`'s
FF_DIR-missing guard, plus a second guard for a missing `SONAR_TOKEN` (bootstrap
not yet run) — both fail with `exit 1` and an actionable fix command, matching
issue #12's acceptance criteria.

## Why `-Dsonar.qualitygate.wait=true`

The bare `mvnw verify sonar:sonar` call from the issue body only prints
`ANALYSIS SUCCESSFUL` — it does **not** print or block on the quality-gate
verdict (SonarQube's report processing is async). Issue #12 explicitly requires
`make sonar` to "print the quality-gate result", so `-Dsonar.qualitygate.wait=true`
was added on top of the issue's literal command. With it, Maven polls the
Compute Engine task and prints `QUALITY GATE STATUS: PASSED|FAILED` before
exiting — and exits non-zero on a failing gate, so it's usable as a pre-push
gate matching what SIT CI will enforce.

## Verification (issue #13)

Ran end-to-end against a live `quality`-profile stack:
- `make up-all` → all 3 services (postgres, sonarqube, adminer) reported healthy.
- `sonarqube/bootstrap.sh` re-run cleanly (idempotent — see [[0012-sonar-bootstrap]]).
- `make sonar` against `../feature_flag`: `ANALYSIS SUCCESSFUL`, then
  `QUALITY GATE STATUS: PASSED`, `BUILD SUCCESS`, exit 0.
- Both Makefile guards manually triggered (bad `FF_DIR`, stripped `SONAR_TOKEN`
  from `.env`) — both fail fast with exit 1/2 and the documented fix command.

Confirms the last unchecked Phase 2 acceptance line in
`docs/INFRASTRUCTURE.md` §6.

## Gotcha

Long-running `make sonar`/`mvnw` output can appear truncated mid-stream in an
interactive terminal capture (e.g. cut off during a Spring context test) even
though the process is still running and completes normally — the file on disk
is the source of truth, not what an interactive tail shows. Always redirect to
a log file and grep the file after the process exits rather than trusting
truncated interactive output.
