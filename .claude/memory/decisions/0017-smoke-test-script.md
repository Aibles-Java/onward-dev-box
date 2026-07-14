# 0017 — `make smoke` / `smoke-test.sh` via newman (issue #15)

**Date:** 2026-07-11

## What

Added `scripts/smoke-test.sh` (docs/INFRASTRUCTURE.md §3, item 3.3), wired as
`make smoke`. Runs the feature_flag team's own Postman collection
(`../feature_flag/docs/postman/Feature_Flag_Platform.postman_collection.json`)
end-to-end via newman against the host-run app. One command answers "does my local
env work end-to-end?". This repo does **not** own the collection — it only runs it.

## Design choices

- **Runner selection** `SMOKE_RUNNER=auto|node|docker` (default auto): prefer
  `newman`/`npx newman` (Node, no image pull), fall back to dockerized
  `postman/newman`. `node` is present on this machine; the docker path satisfies
  the "works without local Node" acceptance line.
- **baseUrl override, not edit.** The collection ships `baseUrl=http://localhost:8080`
  but the app runs on `:8081` (cross-repo contract). We pass
  `--env-var baseUrl=http://localhost:8081` at run time — never editing the
  collection (it belongs to feature_flag). See [[0016-seed-feature-flag-script]] for
  the same "run, don't own" boundary.
- **Docker fallback rewrites host** `localhost`→`host.docker.internal` (the
  container can't reach the host's localhost) and adds
  `--add-host host.docker.internal:host-gateway` so it also works on Linux.
- **Fresh-DB precondition.** The collection registers fixed demo users and expects
  `201` on first registration, so a dirty DB fails at auth (409). Documented; not
  auto-nuked (destructive).

## The important finding: `make smoke` is red, and it's NOT our bug

On a clean run (nuke → up → run → smoke, no auth probing first) the collection
reports **15/124 failing assertions in ~2s** (so not rate-limiting). All 15 trace
to **two feature_flag-owned defects** the smoke test correctly surfaced:

1. **Collection drift (feature_flag's collection is wrong).** `POST /auth/register`
   returns `HTTP 201, Content-Length: 0` (empty body — confirmed by direct curl),
   but the collection does `body = pm.response.json(); set('ownerToken', body.token)`
   and never logs admin/viewer in separately. → `JSONError` on all 3 registers;
   `adminUserId`/`viewerUserId` never captured → invite bodies malformed (`400`),
   delete hits `/members/` with an empty id (`500`). This matches the register
   contract found in issue #14: register returns 201 empty, login returns the token.
2. **App bug (feature_flag API).** `GET /organisations/{id}/members` returns `500`
   for the owner in the trivial 1-member case (independent of the drift — the owner
   token is valid, proven by org/project ops passing). Deeper: the org creator is
   not recorded in `organization_members` — `GET /organisations` → `[]` and
   `/members` → `403 "You are not a member of this organisation"` for the very user
   who created the org.

Caveat: some `[ERR]` negative tests "pass" falsely — e.g. `[ERR] Admin invites
OWNER → 403 ✓` is green only because `adminToken` is empty (403 = missing auth),
coincidentally matching the expected code.

## PR #39 review follow-up (2026-07-14)

- **Two-terminal documented (fixed).** Reviewer flagged that `make run` foregrounds
  `./mvnw spring-boot:run` and blocks, so `make smoke` needs a *second* terminal —
  nowhere spelled out. Added the explicit `terminal 1: make run` / `terminal 2: make
  smoke` sequence to the Makefile `run`/`smoke` help + comment block and the
  `smoke-test.sh` header. Docs-only.
- **Known-red "silent" claim (rejected, not fixed).** Reviewer called the red path
  "silent" (only the success line prints). It is not: newman prints a full failure
  report (124 assertions / 15 failed on a clean DB, 18 numbered failure entries).
  newman is a stateless action-executor+reporter — no DB access — so it *cannot*
  distinguish a known upstream bug from a real regression; a hardcoded
  `EXPECTED_FAILURES`/label would go stale the moment feature_flag#52 is fixed (run
  passes → hardcoded check falsely reports RED) and re-imports a cross-repo reference
  this repo doesn't own. Left as-is; rebutted on the PR.
- **Scoped db-reset (agreed problem, built across both repos).** Reviewer wanted a
  non-destructive `make db-reset` instead of `make nuke` between runs. Real gap, but
  a fast reset needs schema knowledge (which tables to TRUNCATE, which
  migration-history tables to spare) — that knowledge is feature_flag's. Split by
  ownership: **feature_flag PR #55** owns the truncation SQL/script
  (`scripts/db-reset.{sql,sh}` — TRUNCATE every `public` table except Liquibase
  history `databasechangelog`/`databasechangeloglock`, discovered from `pg_tables`);
  **dev-box** owns execution — `make db-reset` pipes that SQL into the compose
  Postgres container, and `make smoke` now runs it first (opt out: `SMOKE_NO_RESET=1`)
  so runs start known-clean. `smoke-test.sh` stays a pure runner (no reset).
  `make nuke` stays as the zero-maintenance full recovery.

- **Empirical finding: db-reset is necessary but NOT sufficient for a deterministic
  smoke.** Two back-to-back `make smoke` runs (both reset the DB) gave 15/124 then
  97/109 failures. Cause is NOT the DB (reset works) — it's feature_flag's **in-memory,
  time-windowed rate limiter** on `/auth/register` + `/auth/login`: run 1 had 0×
  `429`, run 2 had 6× `429` (quota exhausted across the two rapid runs). TRUNCATE
  can't reset app-side state. So there are two non-determinism sources and **both are
  feature_flag-owned**: DB seed collision (dev-box can reset via FF's SQL) and the
  rate limiter (dev-box cannot touch — needs an FF dev/test profile). Decision: leave
  the rate limiter to feature_flag; dev-box's reset still earns its keep by removing
  the DB-state variable.

## Status

Script is **done and verified** (runs clean in 2s, correct baseUrl override,
missing-collection guard, shellcheck clean, exit code propagates). `make smoke`
**cannot go green** until feature_flag fixes both defects — filed upstream as a
feature_flag issue. §6 DoD line "make smoke passes" left unchecked on purpose (it
does not pass yet, and the blocker is not in this repo). §3.3 documents the
known-red state.
