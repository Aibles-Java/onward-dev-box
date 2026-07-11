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

## Status

Script is **done and verified** (runs clean in 2s, correct baseUrl override,
missing-collection guard, shellcheck clean, exit code propagates). `make smoke`
**cannot go green** until feature_flag fixes both defects — filed upstream as a
feature_flag issue. §6 DoD line "make smoke passes" left unchecked on purpose (it
does not pass yet, and the blocker is not in this repo). §3.3 documents the
known-red state.
