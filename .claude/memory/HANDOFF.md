# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/issue-3-postgres-init-sql` (issue #3, board card In progress →
  Ready For Testing once PR opens): `postgres/init/01-init-databases.sql`
  (idempotent — see decision 0004), `.gitkeep` removed, estimate S/3h logged in
  `calibration.md`. Both acceptance criteria verified live: `select 1` as
  `ff_user`/`sonar` over TCP+password, feature_flag booted on the host with
  8 Liquibase changesets applied. Environment torn down with `down -v`.
- Issue #2 (compose) is merged into develop (PR #20).
- Old feature_flag `ff_postgres` container still squats on host 5432 —
  verification keeps using `POSTGRES_PORT=5433` until the companion PR retires
  feature_flag's compose (ADR-0001 decision 6).

## Context to Load

- `decisions/0004-idempotent-init-sql.md` — init SQL patterns + cross-repo
  verification recipe
- `decisions/0003-compose-authoring-choices.md` — superuser vs init-SQL users
- `docs/INFRASTRUCTURE.md` §3 — remaining Phase 1 items

## Next steps

1. Open PR for `feature/issue-3-postgres-init-sql` → `develop` (Closes #3),
   move board card to Ready For Testing.
2. Remaining Phase 1 items: `.env.example` (item 1.3), then Makefile,
   `scripts/doctor.sh`, `scripts/wait-for.sh`.
3. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432).
