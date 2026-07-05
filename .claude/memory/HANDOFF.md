# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-05)

- Issue #10 (sonar bootstrap) and #28 are both closed/merged — no action
  needed there.
- Branch `feature/issue-11-quality-gate-json` (issue #11, Phase 2 item 2.1
  step 5 — the deliberately-deferred quality-gate follow-up from #10). Added
  `sonarqube/quality-gate.json` (checked-in gate definition: `new_coverage`
  ratcheted at 0 → target 80%, `new_blocker_violations` at 0) and wired
  `sonarqube/bootstrap.sh` step 5 to create/reconcile the named gate
  (`aibles-team-gate`) from that file and assign it to `aibles:feature_flag`
  (never as instance default — shared multi-tenant SonarQube). Verified
  end-to-end against a live `quality`-profile instance, including a clean
  idempotent re-run. Gotchas + rationale in
  `decisions/0013-quality-gate-json.md`. Not yet committed/pushed as of this
  handoff.
- Calibration `Actual`/`Δ` for #3–#11 still empty — needs human's actual hours.

## Context to Load

- `decisions/0013-quality-gate-json.md` — quality-gate JSON gotchas (SonarQube
  auto-adds "Clean as You Code" conditions to new gates; bootstrap.sh prunes
  them to match the checked-in file)
- `decisions/0012-sonar-bootstrap.md` — SonarQube bootstrap gotchas (password
  policy, `curl -G` requirement, token revoke-then-generate pattern)
- `docs/INFRASTRUCTURE.md` §3 — Phase 2: 2.1 (`sonarqube/bootstrap.sh`,
  including the quality gate) done; next is 2.2 `make sonar`

## Next steps

1. Push `feature/issue-11-quality-gate-json`, open PR (Closes #11, base
   `develop`), move card to Ready For Testing. When merged, use
   `issue-board.sh done 11` to close the issue.
2. Phase 2.2: `make sonar` target running
   `./mvnw verify sonar:sonar` against `../feature_flag` with `$SONAR_TOKEN`.
3. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432 permanently — ends the `ff_postgres`
   stop/start dance in every verification).
