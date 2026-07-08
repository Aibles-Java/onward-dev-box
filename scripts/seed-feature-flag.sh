#!/usr/bin/env bash
# scripts/seed-feature-flag.sh — demo dataset via the Admin API (docs/INFRASTRUCTURE.md §3, item 3.2).
#
# Against a running feature_flag app (`make up && make run`, port 8081 by
# default — override with FF_APP_URL), seeds through the Admin API (never raw
# SQL, so it always respects the current schema):
#   1. Register a demo user (or log in if it already exists).
#   2. Create an org → a project → environments (dev/sit/prod) → two flags.
#   3. Print each environment's SDK API key.
#
# Fixed demo credentials/slug so re-running is detectable: if the org already
# exists, the script fails fast with an "already seeded" message instead of
# creating duplicates. Wired as `make seed`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${FF_APP_URL:-http://localhost:8081}"

command -v curl >/dev/null 2>&1 || { echo "seed: curl is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "seed: jq is required" >&2; exit 2; }

OWNER_EMAIL="demo@aibles.local"
OWNER_PASSWORD="Demo_password123"
ORG_NAME="Aibles Demo"
ORG_SLUG="aibles-demo"
PROJECT_NAME="Demo Web App"

say() { echo "seed: $1" >&2; }
fail() { echo "seed: $1" >&2; exit 1; }

TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

# api_call METHOD PATH [JSON_BODY] [BEARER_TOKEN] — prints the HTTP status
# code to stdout; the response body lands in $TMP_BODY.
api_call() {
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local args=(-sS -o "$TMP_BODY" -w '%{http_code}' -X "$method" "$BASE_URL$path" -H 'Content-Type: application/json')
  [ -z "$token" ] || args+=(-H "Authorization: Bearer $token")
  [ -z "$data" ] || args+=(-d "$data")
  curl "${args[@]}"
}

# ── 0. Wait for the app to answer ───────────────────────────────────────────

say "waiting for $BASE_URL to answer"
"$ROOT_DIR/scripts/wait-for.sh" -t "${FF_WAIT_TIMEOUT:-30}" "$BASE_URL/api-docs" \
  || fail "app not reachable at $BASE_URL — run 'make up && make run' first (override the URL with FF_APP_URL)"

# ── 1. Register demo user (or log in if this is a re-run) ──────────────────

say "registering demo user '$OWNER_EMAIL'"
STATUS="$(api_call POST /api/v1/auth/register "$(jq -n \
  --arg email "$OWNER_EMAIL" --arg password "$OWNER_PASSWORD" \
  --arg firstName "Demo" --arg lastName "Seed" \
  '{email:$email,password:$password,firstName:$firstName,lastName:$lastName}')")"

case "$STATUS" in
  201) ;;
  409) say "user already exists — logging in instead" ;;
  *) fail "register failed (HTTP $STATUS): $(cat "$TMP_BODY")" ;;
esac

# Register responds 201 with an empty body — the token only comes back from
# /login, so always log in afterwards regardless of which branch ran above.
STATUS="$(api_call POST /api/v1/auth/login "$(jq -n \
  --arg email "$OWNER_EMAIL" --arg password "$OWNER_PASSWORD" \
  '{email:$email,password:$password}')")"
[ "$STATUS" = 200 ] || fail "login failed (HTTP $STATUS): $(cat "$TMP_BODY")"
TOKEN="$(jq -r '.token' "$TMP_BODY")"
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || fail "no token returned by login endpoint"

# ── 2. Create organisation (fails clearly if this is a re-run) ─────────────

say "creating organisation '$ORG_SLUG'"
STATUS="$(api_call POST /api/v1/organisations "$(jq -n \
  --arg name "$ORG_NAME" --arg slug "$ORG_SLUG" '{name:$name,slug:$slug}')" "$TOKEN")"

if [ "$STATUS" = 409 ]; then
  fail "already seeded — organisation '$ORG_SLUG' already exists for '$OWNER_EMAIL'. Run 'make nuke && make up && make run' for a fresh instance before reseeding."
fi
[ "$STATUS" = 201 ] || fail "create organisation failed (HTTP $STATUS): $(cat "$TMP_BODY")"
ORG_ID="$(jq -r '.id' "$TMP_BODY")"

# ── 3. Create project ────────────────────────────────────────────────────────

say "creating project '$PROJECT_NAME'"
STATUS="$(api_call POST /api/v1/projects "$(jq -n \
  --arg orgId "$ORG_ID" --arg name "$PROJECT_NAME" --arg description "Seeded demo project" \
  '{organisationId:$orgId,name:$name,description:$description}')" "$TOKEN")"
[ "$STATUS" = 201 ] || fail "create project failed (HTTP $STATUS): $(cat "$TMP_BODY")"
PROJECT_ID="$(jq -r '.id' "$TMP_BODY")"

# ── 4. Create environments (dev/sit/prod) ───────────────────────────────────
# Plain variables rather than an associative array — macOS ships bash 3.2,
# which doesn't support `declare -A`.

create_environment() {
  local env_name="$1"
  say "creating environment '$env_name'"
  STATUS="$(api_call POST /api/v1/environments "$(jq -n \
    --arg projectId "$PROJECT_ID" --arg name "$env_name" --arg description "Seeded $env_name environment" \
    '{projectId:$projectId,name:$name,description:$description}')" "$TOKEN")"
  [ "$STATUS" = 201 ] || fail "create environment '$env_name' failed (HTTP $STATUS): $(cat "$TMP_BODY")"
  jq -r '.apiKey' "$TMP_BODY"
}

DEV_API_KEY="$(create_environment "Development")"
SIT_API_KEY="$(create_environment "SIT")"
PROD_API_KEY="$(create_environment "Production")"

# ── 5. Create a couple of flags ──────────────────────────────────────────────

say "creating flag 'new-dashboard' (BOOLEAN)"
STATUS="$(api_call POST /api/v1/flags "$(jq -n \
  --arg projectId "$PROJECT_ID" \
  '{projectId:$projectId,name:"New Dashboard",key:"new-dashboard",description:"Enable the redesigned dashboard",valueType:"BOOLEAN"}')" "$TOKEN")"
[ "$STATUS" = 201 ] || fail "create flag 'new-dashboard' failed (HTTP $STATUS): $(cat "$TMP_BODY")"

say "creating flag 'welcome-message' (STRING)"
STATUS="$(api_call POST /api/v1/flags "$(jq -n \
  --arg projectId "$PROJECT_ID" \
  '{projectId:$projectId,name:"Welcome Message",key:"welcome-message",description:"Copy shown on first login",valueType:"STRING"}')" "$TOKEN")"
[ "$STATUS" = 201 ] || fail "create flag 'welcome-message' failed (HTTP $STATUS): $(cat "$TMP_BODY")"

# ── 6. Print the SDK API keys ────────────────────────────────────────────────

say "demo dataset seeded:"
echo "  organisation : $ORG_NAME ($ORG_SLUG)"
echo "  project      : $PROJECT_NAME"
echo "  flags        : new-dashboard (BOOLEAN), welcome-message (STRING)"
echo "  SDK API keys:"
echo "    dev  : $DEV_API_KEY"
echo "    sit  : $SIT_API_KEY"
echo "    prod : $PROD_API_KEY"
echo
echo "  try it: curl -H \"X-Environment-Key: $DEV_API_KEY\" $BASE_URL/api/v1/sdk/flags"
