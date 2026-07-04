# 0007 — `make run`: host-run feature_flag against dev-box infra (issue #6)

**Date:** 2026-07-04 · **Branch:** `feature/issue-6-make-run`

## What was decided

1. **DB health wait via idempotent `$(COMPOSE) $(CORE) up -d --wait`, not
   `scripts/wait-for.sh`.** The issue text named wait-for.sh (item 1.6), but that
   script doesn't exist yet and compose covers this case strictly better: it
   *starts* postgres if it isn't running and blocks on the real healthcheck,
   whereas wait-for.sh would only poll (and time out on a never-started DB).
   Side effect: `make run` alone works from a cold clone — `make up` first is
   no longer strictly required. This narrows 1.6's remaining scope to waits
   compose can't see (e.g. host app on 8081 for the future `make smoke`).
2. **Checkout detection is `[ -x "$(FF_DIR)/mvnw" ]`, not `[ -d ]`.** An
   existing-but-wrong directory fails the same clear way as a missing one. The
   error prints two actionable fixes: clone as sibling, or `make run
   FF_DIR=/path`. `FF_DIR ?= ../feature_flag` sits next to `COMPOSE` at the top.
3. **CLAUDE.md Commands sync:** `make run` moved from "planned" to implemented
   list, per the standing instruction to keep that section in sync.

## Verification (both acceptance criteria, live)

Same squat recipe as 0006: `docker stop ff_postgres` → `make init && make up &&
make run` from a clean state (fresh volume). Proof of boot: app answered on 8081
(swagger-ui 302, root 403/secured) and `feature_flag_db` contained
`databasechangelog` + all 9 app tables owned by `ff_user` → Liquibase applied
the changelog through the `make run` boot. Error path: `make run
FF_DIR=/nonexistent/path` → clear message, exit 1. Teardown restored everything
(`down -v`, `rm .env`, `docker start ff_postgres`).
