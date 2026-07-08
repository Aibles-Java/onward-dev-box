# 0016 — `scripts/seed-feature-flag.sh` (issue #14)

## What

Added `scripts/seed-feature-flag.sh`, wired as `make seed`. Seeds a demo dataset
against a running `feature_flag` app (default `http://localhost:8081`, override
with `FF_APP_URL`) purely through its Admin API:

1. Register `demo@aibles.local` (fixed email/password) — or log in if it already
   exists.
2. Create org `aibles-demo` → project "Demo Web App" → three environments
   (Development/SIT/Production) → two flags (`new-dashboard` BOOLEAN,
   `welcome-message` STRING).
3. Print each environment's SDK API key plus a ready-to-copy `curl` example.

## Why these specific choices

- **Fixed demo credentials/org slug, not randomly generated ones** — makes
  re-runs detectable without needing a "seed marker" table. A `409` on org
  creation means the exact dataset already exists.
- **Idempotency handled as "fail with a clear message," not full skip-ahead** —
  the issue's acceptance criteria explicitly allow either behavior
  ("Re-running is either idempotent or fails with a clear message"). Detecting
  and resuming a partially-seeded org (e.g. org exists but envs don't) would
  need list/lookup calls for every resource type; not worth the complexity for
  a local dev convenience script. Re-running after `make nuke && make up &&
  make run` is the supported reset path.
- **`declare -A` (associative arrays) avoided** — macOS ships bash 3.2 by
  default (`/usr/bin/env bash` resolves to it unless the user has installed a
  newer bash via Homebrew and reordered `PATH`), which doesn't support them.
  Caught this by actually running the script, not just shellcheck — shellcheck
  doesn't flag bash-version incompatibilities. Used one plain variable per
  environment (`DEV_API_KEY`/`SIT_API_KEY`/`PROD_API_KEY`) instead.
- **`say()` prints to stderr, not stdout** — functions like `create_environment`
  return their value via `echo` + command substitution (`X="$(fn)"`); any
  stdout from `say()` inside that function would get captured into the return
  value instead of printed. This is a general pattern for this repo's other
  scripts too if we add more helper functions that both log and return a
  value via stdout.

## Gotcha found (not a script bug — an app behavior surprise)

`POST /api/v1/auth/register` in the **current** `feature_flag` app returns
`201` with an **empty body** — no token, unlike what
`docs/postman/Feature_Flag_Platform.postman_collection.json`'s test script
assumes (`pm.collectionVariables.set('ownerToken', body.token)` after
register). The script always calls `POST /api/v1/auth/login` afterward
(fresh registration or 409-exists) to obtain the JWT. Verified against a live
run (register → empty 201 body; login → 200 with `token`). Not something we
changed here — flagging in case the Postman collection itself needs a fix
later, or in case a future `feature_flag` release restores the old behavior.

## SDK auth header (verified, for anyone touching seed/smoke scripts later)

The SDK evaluation endpoints (`GET /api/v1/sdk/flags`, `/api/v1/sdk/flags/{key}`)
authenticate via header `X-Environment-Key: <64-char apiKey>` — **not**
`X-API-Key` as an early draft of this script assumed. Confirmed via the
Postman collection's `08-01 SDK: Get all flags` request headers.

## Verification performed

Full clean-machine loop: `make nuke` (confirmed) → `make up` → `make run`
(feature_flag on host, port 8081) → `make seed`. Fresh run printed all three
environment API keys; `curl -H "X-Environment-Key: <dev key>"
.../api/v1/sdk/flags` returned both seeded flags (200). Re-running `make seed`
against the same instance failed with the "already seeded" message and
non-zero exit, without creating duplicate orgs/projects/environments/flags.
`shellcheck scripts/seed-feature-flag.sh` clean.
