# 0003 — docker-compose.yml authoring choices (issue #2)

**Date:** 2026-07-04 · **Context:** Phase 1 item 1.1, `feature/issue-2-docker-compose`

## Decisions

1. **`postgres` carries profiles `["core", "quality"]`**, not just `core`.
   Compose refuses to start a service whose `depends_on` target's profile is not
   activated, so `sonarqube` (quality) needs postgres enabled in that profile too.
   `core → postgres` still holds conceptually; this only makes
   `docker compose --profile quality up` self-sufficient (SonarQube shares the
   instance anyway, per INFRASTRUCTURE.md §1.1).

2. **Network has a fixed name `onward`** (`name: onward`, not the project-prefixed
   default) so sibling repos' compose files can attach with `external: true` and
   resolve services by name.

3. **Container superuser is `postgres`/`postgres` (local-only), NOT `ff_user`.**
   Deliberate divergence from feature_flag's old compose (which made `ff_user` the
   superuser via `POSTGRES_USER`). Per-service users/databases
   (`ff_user`/`feature_flag_db`, `sonar`/`sonar`) are created by first-boot SQL in
   `postgres/init/` (issue #3) — that's what makes the instance multi-tenant.
   The cross-repo contract (`ff_user`/`ff_password`/`feature_flag_db`) is
   unchanged from the app's point of view.

4. **SonarQube healthcheck uses `curl`, not `wget`.** Gotcha found during
   verification: the current `sonarqube:community` image (26.6.0) ships `curl`
   and `bash` but **no `wget`** — a wget-based healthcheck fails with
   `wget: not found` while the service is actually UP.

5. **Image tag `sonarqube:${SONARQUBE_TAG:-community}`** — follows the issue
   text verbatim; pinning to a specific LTA tag can happen via `.env` later.

## Verification notes (repeatable)

- Verified with `POSTGRES_PORT=5433` because feature_flag's old `ff_postgres`
  container holds host 5432 — the env-var port overrides exist for exactly this.
- `quality` was verified end-to-end by manually creating the `sonar` role/db in
  the scratch instance (init SQL wasn't merged yet); both containers reached
  `Healthy` under `up -d --wait`.
- Always ended verification with `down -v`: a postgres volume created **without**
  the init SQL would permanently skip it on later boots (first-boot-only
  semantics, see CLAUDE.md gotchas).
