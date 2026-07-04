# 0004 — postgres/init SQL written idempotently (issue #3)

**Date:** 2026-07-04 · **Context:** Phase 1 item 1.2, `feature/issue-3-postgres-init-sql`

## Decisions

1. **`01-init-databases.sql` uses idempotent patterns, not the issue's literal
   `CREATE USER`/`CREATE DATABASE`.** Roles via `DO $$ … IF NOT EXISTS (pg_roles)`,
   databases via the psql `SELECT 'CREATE DATABASE …' WHERE NOT EXISTS (…)\gexec`
   trick (Postgres has no `CREATE DATABASE IF NOT EXISTS`). INFRASTRUCTURE.md §1.2
   explicitly asks for "idempotent" SQL, and the CLAUDE.md gotcha ("adding a
   database later means nuke **or applying the SQL to the live instance**") needs
   re-applicability. Verified: re-running the file against the live instance is a
   clean no-op. `\gexec` works because the entrypoint runs `.sql` files through psql.

2. **Credentials are verbatim from the cross-repo contract** —
   `ff_user`/`ff_password`/`feature_flag_db` and `sonar`/`sonar_password`/`sonar`.
   Databases are owned by their service user (PG16: owner owns `public` schema via
   `pg_database_owner`, so Liquibase DDL works with no extra GRANTs).

## Verification recipe (cross-repo, repeatable)

- Old `ff_postgres` still holds host 5432 → verify on `POSTGRES_PORT=5433`.
- Boot the consumer app against the scratch instance without touching its config:
  `SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5433/feature_flag_db ./mvnw spring-boot:run`
  (Spring relaxed binding overrides `spring.datasource.url`).
- Confirmed: TCP+password login for both users, 8 Liquibase changesets ran, 9
  tables owned by `ff_user`, Tomcat up on 8081. Ended with `down -v` (first-boot
  semantics — never leave a volume created without the final init SQL).
