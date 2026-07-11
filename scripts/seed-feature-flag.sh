#!/usr/bin/env bash
# scripts/seed-feature-flag.sh — demo-data seeder (docs/INFRASTRUCTURE.md §3, item 3.2).
#
# Seeds a working dataset through the feature_flag Admin API (never raw SQL, so
# it always respects the current schema): register a user, log in for a JWT,
# then create org → project → environments (dev/sit/prod) → a couple of flags,
# and print the per-environment SDK API keys. Gives everyone the same demo
# state and makes the Postman collection instantly usable.
#
# The app runs on the HOST (see 'make run'); this script only talks to its
# HTTP API. Wire-up: 'make seed'.
#
# Usage:
#   scripts/seed-feature-flag.sh              # seed against http://localhost:8081
#   SEED_APP_URL=http://localhost:8081 scripts/seed-feature-flag.sh
#
# Overridable via env: SEED_APP_URL, SEED_EMAIL, SEED_PASSWORD, SEED_WAIT.
#
# Idempotency: the SDK API key is returned by the API exactly once, at
# environment creation — only its hash is stored, so a re-run cannot reproduce
# it. This script therefore does NOT try to be idempotent: if the seed user
# already exists it stops with a clear "already seeded" message. Reset with
# 'make nuke && make up && make run' for a clean slate.
set -euo pipefail

APP_URL="${SEED_APP_URL:-http://localhost:8081}"
SEED_EMAIL="${SEED_EMAIL:-seed@example.com}"
SEED_PASSWORD="${SEED_PASSWORD:-password123}"
SEED_WAIT="${SEED_WAIT:-60}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_HOSTPORT="${APP_URL#*://}"   # strip scheme → host:port for the TCP wait

TOKEN=""       # set after login; sent as Bearer on every admin call
HTTP_CODE=""   # set by req() to the last response status
LAST_BODY=""   # set by req() to the last response body

# ── HTTP helper ──────────────────────────────────────────────────────────────

# req METHOD PATH [JSON_BODY] — echoes the response body, sets HTTP_CODE.
# Attaches the Bearer token once we have one. Never aborts on a non-2xx status
# (curl's --fail is deliberately omitted so callers can inspect HTTP_CODE); a
# transport error leaves HTTP_CODE empty.
req() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" "$APP_URL$path" -H 'Content-Type: application/json')
  [ -n "$TOKEN" ] && args+=(-H "Authorization: Bearer $TOKEN")
  [ -n "$body" ] && args+=(-d "$body")

  local resp
  resp="$(curl "${args[@]}" -w $'\n%{http_code}' 2>/dev/null || true)"
  HTTP_CODE="${resp##*$'\n'}"
  LAST_BODY="${resp%$'\n'*}"
  [ "$HTTP_CODE" = "$LAST_BODY" ] && LAST_BODY=""   # empty-body responses
  printf '%s' "$LAST_BODY"
}

# expect WHAT EXPECTED_CODE — abort with the response body if the last status
# is not the expected one.
expect() {
  if [ "$HTTP_CODE" != "$2" ]; then
    echo "error: $1 failed (HTTP ${HTTP_CODE:-no response from $APP_URL})" >&2
    [ -n "$LAST_BODY" ] && echo "       $LAST_BODY" >&2
    exit 1
  fi
}

# jq_field JSON FILTER — extract a field, aborting if it is missing/null.
jq_field() {
  local out
  out="$(printf '%s' "$1" | jq -r "$2")"
  if [ -z "$out" ] || [ "$out" = "null" ]; then
    echo "error: expected field '$2' missing from response:" >&2
    echo "       $1" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# ── Preflight: tooling + a reachable app ─────────────────────────────────────

for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: '$tool' is required but not on PATH (run 'make doctor')" >&2
    exit 1
  }
done

echo "seed: waiting for feature_flag on $APP_HOSTPORT (up to ${SEED_WAIT}s)…"
if ! "$REPO_DIR/scripts/wait-for.sh" -t "$SEED_WAIT" -q "$APP_HOSTPORT"; then
  echo "error: feature_flag is not answering on $APP_HOSTPORT" >&2
  echo "       start it first:  make run   (or point SEED_APP_URL elsewhere)" >&2
  exit 1
fi

# ── 1–2. Register + log in (register never returns a token) ──────────────────

req POST /api/v1/auth/register \
  "$(printf '{"email":"%s","password":"%s","firstName":"Seed","lastName":"User"}' \
     "$SEED_EMAIL" "$SEED_PASSWORD")" >/dev/null
REGISTER_CODE="$HTTP_CODE"

req POST /api/v1/auth/login \
  "$(printf '{"email":"%s","password":"%s"}' "$SEED_EMAIL" "$SEED_PASSWORD")" >/dev/null
expect "login as $SEED_EMAIL" 200
TOKEN="$(jq_field "$LAST_BODY" '.token')"

# Fresh run → register returned 201. Anything else, but login still works, means
# the user already exists → already seeded (and the one-time keys are gone).
if [ "$REGISTER_CODE" != "201" ]; then
  echo
  echo "already seeded: user '$SEED_EMAIL' already exists (register returned ${REGISTER_CODE:-error})."
  echo "The SDK keys are shown only once at creation and cannot be re-printed."
  echo "To re-seed from a clean slate:  make nuke && make up && make run && make seed"
  exit 0
fi
echo "seed: registered and logged in as $SEED_EMAIL"

# ── 3. Organization (creator becomes OWNER) ──────────────────────────────────

req POST /api/v1/organisations '{"name":"Demo Org","slug":"demo-org"}' >/dev/null
expect "create organization" 201
ORG_ID="$(jq_field "$LAST_BODY" '.id')"
echo "seed: org        Demo Org ($ORG_ID)"

# ── 4. Project ───────────────────────────────────────────────────────────────

req POST /api/v1/projects \
  "$(printf '{"organisationId":"%s","name":"Demo Project","description":"Seeded demo project"}' "$ORG_ID")" >/dev/null
expect "create project" 201
PROJECT_ID="$(jq_field "$LAST_BODY" '.id')"
echo "seed: project    Demo Project ($PROJECT_ID)"

# ── 5. Environments dev/sit/prod (apiKey returned once, here) ─────────────────

# Fixed set of environments. Kept as plain variables (not an associative array)
# so the script runs on the stock macOS bash 3.2 — matching the other scripts.
# Only dev's id is needed later (to enable flags there); every env's apiKey is
# reported. DEV_ID/*_KEY are plain variables (no associative array) so the
# script runs on the stock macOS bash 3.2, matching the other scripts.
DEV_ID=""; DEV_KEY=""; SIT_KEY=""; PROD_KEY=""
for name in dev sit prod; do
  req POST /api/v1/environments \
    "$(printf '{"projectId":"%s","name":"%s","description":"%s environment"}' \
       "$PROJECT_ID" "$name" "$name")" >/dev/null
  expect "create environment '$name'" 201
  env_id="$(jq_field "$LAST_BODY" '.id')"
  env_key="$(jq_field "$LAST_BODY" '.apiKey')"
  case "$name" in
    dev)  DEV_ID="$env_id"; DEV_KEY="$env_key" ;;
    sit)  SIT_KEY="$env_key" ;;
    prod) PROD_KEY="$env_key" ;;
  esac
  echo "seed: env        $name ($env_id)"
done

# ── 6. Feature flags (project-scoped) + enable a couple on dev ───────────────

req POST /api/v1/flags \
  "$(printf '{"projectId":"%s","name":"Dark Mode","key":"dark-mode","description":"Enable dark mode UI","valueType":"BOOLEAN"}' "$PROJECT_ID")" >/dev/null
expect "create flag 'dark-mode'" 201
FLAG1_ID="$(jq_field "$LAST_BODY" '.id')"
echo "seed: flag       dark-mode ($FLAG1_ID)"

req POST /api/v1/flags \
  "$(printf '{"projectId":"%s","name":"Checkout Flow","key":"checkout-flow","description":"Which checkout flow to serve","valueType":"STRING"}' "$PROJECT_ID")" >/dev/null
expect "create flag 'checkout-flow'" 201
FLAG2_ID="$(jq_field "$LAST_BODY" '.id')"
echo "seed: flag       checkout-flow ($FLAG2_ID)"

# Turn them on in dev so 'make smoke' / the SDK endpoint return something useful.
req PUT "/api/v1/flags/$FLAG1_ID/environments/$DEV_ID" \
  '{"enabled":true,"value":null,"rolloutPercent":100}' >/dev/null
expect "enable dark-mode on dev" 200
req PUT "/api/v1/flags/$FLAG2_ID/environments/$DEV_ID" \
  '{"enabled":true,"value":"v2","rolloutPercent":100}' >/dev/null
expect "set checkout-flow on dev" 200
echo "seed: enabled dark-mode + checkout-flow on dev"

# ── Summary (the SDK keys are the payload — printed once, capture them) ───────

cat <<SUMMARY

============================================================
 Seed complete — demo dataset created via the Admin API
============================================================
 Login     $SEED_EMAIL / $SEED_PASSWORD
 Org       Demo Org      ($ORG_ID)
 Project   Demo Project  ($PROJECT_ID)
 Flags     dark-mode (BOOLEAN, on in dev)
           checkout-flow (STRING="v2", on in dev)

 SDK API keys  (header: X-Environment-Key — shown only once):
   dev    $DEV_KEY
   sit    $SIT_KEY
   prod   $PROD_KEY

 Try it:
   curl -s $APP_URL/api/v1/sdk/flags \\
     -H "X-Environment-Key: $DEV_KEY" | jq .
============================================================
SUMMARY
