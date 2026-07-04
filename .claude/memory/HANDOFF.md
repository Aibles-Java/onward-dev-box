# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/issue-4-env-example` (issue #4, board card In progress → Ready
  For Testing once PR opens): `.env.example` added covering all 11 compose
  variables with local-only warning; `docker-compose.yml` image tags
  parameterized (`POSTGRES_TAG:-16-alpine`, `ADMINER_TAG:-latest`). Both
  acceptance criteria verified: `cp .env.example .env && docker compose config -q`
  passes (all profiles), and the compose `${VAR}` set exactly matches the
  documented keys. Rendered images unchanged. Test `.env` removed after verify.
- **Estimate S / 1.5h drafted but NOT written to the board** — human was AFK at
  the confirmation prompt and estimate-issue forbids unconfirmed writes. Re-ask,
  then `.claude/scripts/issue-board.sh estimate 4 S 1.5` and log in
  `calibration.md`.
- Issues #2 (compose) and #3 (init SQL) are merged into develop.
- Old feature_flag `ff_postgres` container still squats on host 5432 (ADR-0001
  decision 6) — irrelevant to this issue (`config -q` only), matters again for
  `make up` work.

## Context to Load

- `decisions/0005-env-example-tunables.md` — env var conventions + verify recipe
- `docs/INFRASTRUCTURE.md` §3 — remaining Phase 1 items

## Next steps

1. Open PR for `feature/issue-4-env-example` → `develop` (Closes #4), move board
   card to Ready For Testing.
2. Confirm + write the issue #4 estimate (see WIP above).
3. Remaining Phase 1 items: Makefile (1.4), `scripts/doctor.sh`,
   `scripts/wait-for.sh`.
4. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432).
