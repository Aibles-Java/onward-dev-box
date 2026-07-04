# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-05)

- Branch `feature/issue-28-close-issue-on-done` (issue #28, closing-keyword
  gap for feature PRs). Implemented option 1 from the issue: `.claude/scripts/issue-board.sh done`
  now runs `gh issue close` (with an explanatory comment) right after moving
  the board card to Done. Updated `issue-workflow` SKILL.md with a "Closing
  issues" section explaining why `Closes #N` never auto-fires on `feature/*`
  → `develop` merges. Rationale in `decisions/0011-close-issue-on-done.md`.
- PR not yet opened for #28 as of this handoff; next session (or continuation)
  should push, open the PR (Closes #28, base `develop`), then
  `issue-board.sh ready 28`.
- Issue #9 (Phase 1 verification) merged as PR #27 — already reflects the
  *old* manual-close behavior this issue is fixing; no action needed there.
- Calibration `Actual`/`Δ` for #3–#9 still empty — needs human's actual hours.

## Context to Load

- `decisions/0011-close-issue-on-done.md` — why/how `issue-board.sh done`
  now closes issues (issue #28)
- `docs/INFRASTRUCTURE.md` §3 — Phase 1 complete and verified; next is
  Phase 2 (2.1 sonarqube/bootstrap.sh, 2.2 `make sonar`)

## Next steps

1. Push `feature/issue-28-close-issue-on-done`, open PR (Closes #28, base
   `develop`), move card to Ready For Testing. When merged, use the *new*
   `issue-board.sh done 28` behavior to confirm it actually closes the issue.
2. Phase 2: `sonarqube/bootstrap.sh` (2.1 — uses
   `wait-for.sh -e UP http://localhost:9000/api/system/status`), then
   `make sonar` (2.2).
3. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432 permanently — ends the `ff_postgres`
   stop/start dance in every verification).
