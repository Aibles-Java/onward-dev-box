#!/usr/bin/env bash
# sonarqube/bootstrap.sh — first-run SonarQube API automation (docs/INFRASTRUCTURE.md §3, item 2.1).
#
# Against a running SonarQube (profile: quality — `make up-all`):
#   1. Wait for /api/system/status to report UP.
#   2. Change the default admin/admin password to ${SONAR_ADMIN_PASSWORD}.
#   3. Create project `feature_flag` (key aibles:feature_flag) if it doesn't exist.
#   4. (Re)generate an analysis token and write it to .env as SONAR_TOKEN=.
#
# The shared quality-gate definition (step 5 in issue #10) is out of scope here —
# tracked as a separate issue per the checked-in JSON gate plan.
#
# Idempotent: safe to re-run after the project/token/password already exist.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

command -v curl >/dev/null 2>&1 || { echo "bootstrap: curl is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "bootstrap: jq is required" >&2; exit 2; }

[ -f "$ENV_FILE" ] || { echo "bootstrap: $ENV_FILE not found — run 'make init' first" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

SONAR_PORT="${SONAR_PORT:-9000}"
BASE_URL="http://localhost:${SONAR_PORT}"
PROJECT_KEY="aibles:feature_flag"
PROJECT_NAME="feature_flag"
TOKEN_NAME="onward-dev-box"

: "${SONAR_ADMIN_PASSWORD:?bootstrap: SONAR_ADMIN_PASSWORD must be set in $ENV_FILE}"

say() { echo "bootstrap: $1"; }

# ── 1. Wait for SonarQube to report UP ──────────────────────────────────────

say "waiting for $BASE_URL to report UP"
"$ROOT_DIR/scripts/wait-for.sh" -t "${SONAR_WAIT_TIMEOUT:-180}" -e '"status":"UP"' "$BASE_URL/api/system/status"

# ── 2. Admin password: default admin/admin → SONAR_ADMIN_PASSWORD ──────────

if curl -fsS -u "admin:${SONAR_ADMIN_PASSWORD}" "$BASE_URL/api/authentication/validate" | jq -e '.valid == true' >/dev/null 2>&1; then
  say "admin password already set — skipping"
else
  say "changing admin password"
  curl -fsS -u admin:admin -X POST "$BASE_URL/api/users/change_password" \
    --data-urlencode "login=admin" \
    --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=${SONAR_ADMIN_PASSWORD}" \
    >/dev/null
fi

AUTH=(-u "admin:${SONAR_ADMIN_PASSWORD}")

# ── 3. Create project (idempotent) ──────────────────────────────────────────

EXISTING="$(curl -fsS -G "${AUTH[@]}" "$BASE_URL/api/projects/search" --data-urlencode "projects=${PROJECT_KEY}" | jq '.paging.total')"
if [ "$EXISTING" -gt 0 ]; then
  say "project '${PROJECT_KEY}' already exists — skipping"
else
  say "creating project '${PROJECT_KEY}'"
  curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/projects/create" \
    --data-urlencode "project=${PROJECT_KEY}" \
    --data-urlencode "name=${PROJECT_NAME}" \
    >/dev/null
fi

# ── 4. (Re)generate analysis token, write to .env ───────────────────────────

say "revoking any existing '${TOKEN_NAME}' token"
curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/user_tokens/revoke" \
  --data-urlencode "name=${TOKEN_NAME}" \
  >/dev/null || true

say "generating token '${TOKEN_NAME}'"
TOKEN="$(curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/user_tokens/generate" \
  --data-urlencode "name=${TOKEN_NAME}" | jq -r '.token')"

[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || { echo "bootstrap: failed to generate token" >&2; exit 1; }

if grep -q '^SONAR_TOKEN=' "$ENV_FILE"; then
  # BSD/GNU sed portability: write to a temp file rather than relying on -i suffix quirks.
  sed "s|^SONAR_TOKEN=.*|SONAR_TOKEN=${TOKEN}|" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
else
  { echo ""; echo "# Written by sonarqube/bootstrap.sh"; echo "SONAR_TOKEN=${TOKEN}"; } >> "$ENV_FILE"
fi

say "SONAR_TOKEN written to $ENV_FILE"
