# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/issue-2-docker-compose` (issue #2, board card In progress →
  Ready For Testing once PR opens): `docker-compose.yml` with profiles
  core/quality/tools + `postgres/init/.gitkeep` (mount target; real init SQL is
  issue #3). All three acceptance criteria verified live: healthy Postgres,
  SonarQube `UP` and Healthy at :9000 (sonar db seeded manually into the scratch
  instance), `docker compose config -q` clean; adminer answered HTTP 200 on
  :8090. Environment torn down with `down -v` afterwards.
- feature_flag's old `ff_postgres` container still occupies host 5432 on this
  machine — verification used `POSTGRES_PORT=5433`. It goes away with the
  companion PR retiring feature_flag's compose (ADR-0001 decision 6).

## Context to Load

- `decisions/0003-compose-authoring-choices.md` — dual-profile postgres,
  fixed network name, superuser vs init-SQL users, curl-not-wget healthcheck
- `docs/INFRASTRUCTURE.md` §3 — remaining Phase 1 items

## Next steps

1. Open PR for `feature/issue-2-docker-compose` → `develop` (Closes #2), move
   board card to Ready For Testing.
2. Next Phase 1 issues (bundle with #2): `postgres/init/01-init-databases.sql`
   (issue #3-ish) and `.env.example` — the quality profile is only end-to-end
   verifiable once the init SQL lands.
3. Then Makefile, scripts/doctor.sh, scripts/wait-for.sh; after Phase 1, the
   companion PR to ../feature_flag retiring its docker-compose.yml.
