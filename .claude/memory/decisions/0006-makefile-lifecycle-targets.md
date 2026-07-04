# 0006 — Makefile lifecycle targets: authoring choices (issue #5)

**Date:** 2026-07-04 · **Branch:** `feature/issue-5-makefile`

## What was decided

1. **Health waiting uses Compose v2 `--wait`, not `wait-for.sh`.** `make up` /
   `make up-all` run `docker compose … up -d --wait`, which blocks on the
   healthchecks already defined in `docker-compose.yml`. Issue 1.6
   (`scripts/wait-for.sh`) stays scoped to cases compose can't cover (e.g.
   `make run` racing a cold DB from the host side) — the Makefile needs no
   dependency on it.
2. **`make init` degrades gracefully while `scripts/doctor.sh` doesn't exist**
   (issue 1.5): `[ -x scripts/doctor.sh ]` → run it, else print a skip notice.
   No dead targets: `doctor`, `run`, `sonar`, `seed`, `smoke` deliberately NOT
   added (their issues will add them).
3. **Every lifecycle command passes profiles explicitly** (`--profile core
   --profile quality --profile tools` for `down`/`nuke`/`logs`). All services in
   this compose file are profile-gated, so a bare `docker compose down` matches
   **no services** and silently does nothing. Constant `ALL` in the Makefile
   carries the full list — extend it when a new profile is added.
4. **`make db` uses contract credentials over the container-local socket:**
   `compose exec postgres psql -U ff_user -d feature_flag_db`. Works
   password-less because the official postgres image ships `local all all trust`
   in pg_hba.conf; TCP from the host would prompt for `ff_password`.
5. **`make nuke` confirmation** is a `read -r` + `case` guard answering only
   `y`/`Y`; anything else aborts with exit 1 before `down -v` runs. Verified
   both paths (n → volumes intact, y → volumes deleted).
6. **`.DEFAULT_GOAL := help`** with self-documenting `##` comments — bare `make`
   lists targets instead of running the first one.

## Verification recipe (repeatable)

Old `ff_postgres` still squats host 5432 → `docker stop ff_postgres`, run
`make init && make up` (fresh volume boots init SQL; verified
`ff_user@feature_flag_db` via `compose exec -T … psql`), exercise both nuke
paths, then `rm .env && docker start ff_postgres` to restore. Acceptance on the
default port beats a `POSTGRES_PORT` override here because the issue's criterion
is literally "works from a clean clone".
