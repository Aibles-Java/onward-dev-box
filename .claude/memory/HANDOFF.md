# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-05)

- Issues #10, #11, #28 are closed/merged (PR #31 merged issue #11) — no action
  needed there.
- Branch `feature/issue-12-make-sonar-target` (issue #12, Phase 2 item 2.2).
  Added `sonar:` target to the Makefile — runs `./mvnw verify sonar:sonar`
  against `../feature_flag` (`FF_DIR`-overridable), sourcing `.env` for
  `SONAR_TOKEN`/`SONAR_PORT`, with `-Dsonar.qualitygate.wait=true` added on top
  of the issue's literal command so the quality-gate verdict actually prints
  and gates the exit code (bare `sonar:sonar` doesn't wait for/print it).
  Guards: missing `../feature_flag` checkout, missing `SONAR_TOKEN` — both
  exit 1 with an actionable fix command. Verified end-to-end (see below).
  Rationale + gotchas in `decisions/0014-make-sonar-target.md`. Not yet
  committed/pushed as of this handoff.
- Issue #13 (Phase 2 acceptance verification) was picked up in the same
  session — its acceptance criteria required `make sonar` (#12) to exist
  first, so #12 was implemented before verifying #13. Verification run:
  `make up-all` → all 3 services healthy; `sonarqube/bootstrap.sh` re-run
  cleanly (idempotent); `make sonar` against `../feature_flag` printed
  `QUALITY GATE STATUS: PASSED`, `BUILD SUCCESS`, exit 0. Both Makefile error
  guards manually triggered and confirmed. This closes the last unchecked
  line in `docs/INFRASTRUCTURE.md` §6 (Phase 2 quality-stack acceptance).
  SonarQube Community's one-branch-per-project / no-local-PR-analysis
  limitation is already documented in `docs/INFRASTRUCTURE.md` (§1, Quality
  gate row referencing issue #14 comments) — no new doc needed for that
  acceptance line.
- Calibration `Actual`/`Δ` for #3–#12 still empty — needs human's actual hours.

## Context to Load

- `decisions/0014-make-sonar-target.md` — why `qualitygate.wait=true` was
  added beyond the issue's literal command, plus the interactive-terminal-
  truncation gotcha when verifying long `mvnw` runs
- `decisions/0013-quality-gate-json.md` — quality-gate JSON gotchas
- `decisions/0012-sonar-bootstrap.md` — SonarQube bootstrap gotchas

## Next steps

1. Push `feature/issue-12-make-sonar-target`, open PR (Closes #12, base
   `develop`), move card to Ready For Testing. When merged, use
   `issue-board.sh done 12` to close the issue.
2. Close out issue #13 (verification gate) once #12's PR lands — either as
   its own PR/comment recording the verification run above, or folded into
   the same PR if the human prefers one bundled change. Ask if unclear.
3. Remaining open Phase 3 issues: #14 (seed-feature-flag.sh), #15
   (smoke-test.sh), #16 (RUNBOOK.md), #17 (validate.yml CI), #18 (companion
   PR to feature_flag retiring its docker-compose.yml).
