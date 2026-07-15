# 0016 — `make seed` / `seed-feature-flag.sh` via Admin API (issue #14)

**Date:** 2026-07-11

## What

Added `scripts/seed-feature-flag.sh` (docs/INFRASTRUCTURE.md §3, item 3.2) and
wired it as `make seed`. It seeds a working demo dataset into a **host-run**
feature_flag by talking to its Admin API over HTTP (`localhost:8081`), never raw
SQL: register a user → log in for a JWT → create org → project →
environments (dev/sit/prod) → two flags (`dark-mode` BOOLEAN, `checkout-flow`
STRING), enable both on dev, then print the per-environment SDK API keys.
Also added a `curl`+`jq` preflight to `scripts/doctor.sh` (the script needs both).

## Why API, not raw SQL

The feature_flag schema is owned by the app's Liquibase migrations, not this
repo — see [[0004-idempotent-init-sql]] for the boundary (infra owns db/roles,
app owns schema). Raw `INSERT`s would duplicate the app's table structure,
password hashing (BCrypt), and the SDK-key SHA-256 hashing, and would drift the
moment feature_flag migrates. Seeding through the API respects the live schema
and fails loudly. This mirrors `sonarqube/bootstrap.sh`, which also configures
via API rather than writing SonarQube's tables directly.

## Gotchas hit while building it

- **Not idempotent by design.** The SDK API key is returned exactly once, at
  environment creation (only its hash is stored). A re-run can't reproduce it, so
  the script does *not* try to be idempotent: if the seed user already exists
  (register returns 409 Conflict — `DuplicateResourceException` →
  `GlobalExceptionHandler` in feature_flag) but login still works, it prints
  "already seeded" and exits 0. The guard checks any non-201 (not 409
  specifically) because the preceding `expect ... 200` on login catches genuine
  failures loudly first. Clean re-seed = `make nuke && make run && make seed`.
- **bash subshell drops globals.** `X="$(req ...)"` runs `req` in a
  command-substitution subshell, so its `HTTP_CODE`/`LAST_BODY` global writes
  don't reach the parent — the classic symptom was "login failed (HTTP 201)"
  (stale code from the prior register call). Fixed: every call is
  `req ... >/dev/null` followed by reading `$LAST_BODY`, never captured in `$(...)`.
- **macOS bash 3.2 has no associative arrays.** The env loop originally used
  `declare -A` → `invalid option`. Rewritten with plain vars
  (`DEV_ID`/`DEV_KEY`/`SIT_KEY`/`PROD_KEY`) + a `case` statement, matching how the
  other scripts avoid bash 4 features.
- **British vs American spelling drift** in feature_flag itself: the API field is
  `organisationId` while the DB column is `organization_id`. The script uses the
  API spelling; noted here because it bites anyone writing SQL against the DB.

## Contract touchpoints

App base URL `http://localhost:8081`, paths under `/api/v1/...`, no context-path.
SDK evaluation uses the `X-Environment-Key` header (not the JWT). Rate limit on
auth endpoints is 10/min. None of the cross-repo contract values (5432 /
`feature_flag_db` / `ff_user` / `ff_password`) changed.

## Verification

Ran live end-to-end against a host-run feature_flag: happy path created the full
dataset and printed 3 SDK keys; the SDK endpoint
(`/api/v1/sdk/flags` + `X-Environment-Key`) returned the 2 seeded flags; the
re-run path printed "already seeded" and exited 0. `shellcheck scripts/*.sh`
clean. See [[0007-make-run-target]] for the companion `make run` this pairs with.
