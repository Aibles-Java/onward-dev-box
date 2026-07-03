# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/port-harness-skills`: second harness wave ported from
  feature_flag — `create-pr`, `estimate-issue` (+ empty calibration log),
  `issue-workflow`, `.claude/scripts/issue-board.sh` (repo filter →
  onward-dev-box, overridable via `ISSUE_BOARD_REPO`), and
  `.github/PULL_REQUEST_TEMPLATE.md`. Shellcheck clean; read-only board test
  passed (issue #18 → "Todo"). PR to `develop` being opened this session.
- Repo itself is still **planned but not implemented**: `docs/INFRASTRUCTURE.md`
  holds the build plan; no docker-compose.yml, Makefile, or scripts/ yet — the
  PR-template test-plan items reference `make` targets that don't exist until
  Phase 1 lands.

## Context to Load

- `decisions/0002-port-issue-and-pr-skills.md` — what was adapted vs copied vs
  deliberately not ported (git-workflow release flow stays out)
- `docs/INFRASTRUCTURE.md` §3 — the Phase 1 tool list to implement next

## Next steps

1. Merge the `feature/port-harness-skills` PR into `develop`.
2. Implement Phase 1 of INFRASTRUCTURE.md: docker-compose.yml (profiles
   core/quality/tools), postgres/init/01-init-databases.sql, .env.example,
   Makefile, scripts/doctor.sh, scripts/wait-for.sh — the board has open
   onward-dev-box issues (e.g. #18 in Todo); use the new `issue-workflow` skill
   to work them.
3. After Phase 1: companion PR to ../feature_flag retiring its local
   docker-compose.yml (ADR-0001 decision 6).
