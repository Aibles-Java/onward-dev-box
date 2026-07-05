#!/usr/bin/env bash
# sonarqube/bootstrap.sh — first-run SonarQube API automation (docs/INFRASTRUCTURE.md §3, item 2.1).
#
# Against a running SonarQube (profile: quality — `make up-all`):
#   1. Wait for /api/system/status to report UP.
#   2. Change the default admin/admin password to ${SONAR_ADMIN_PASSWORD}.
#   3. Create project `feature_flag` (key aibles:feature_flag) if it doesn't exist.
#   4. (Re)generate an analysis token and write it to .env as SONAR_TOKEN=.
#   5. Create/update the quality gate from the checked-in sonarqube/quality-gate.json
#      and assign it to aibles:feature_flag (issue #11) — DEV and SIT (future
#      onward-infras) both read this same file so the gates stay identical.
#
# Idempotent: safe to re-run after the project/token/password/gate already exist.
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
GATE_FILE="$ROOT_DIR/sonarqube/quality-gate.json"

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

# ── 5. Quality gate: create/update from checked-in JSON, assign to project ──

[ -f "$GATE_FILE" ] || { echo "bootstrap: $GATE_FILE not found" >&2; exit 1; }

GATE_NAME="$(jq -r '.name' "$GATE_FILE")"

EXISTING_GATE="$(curl -fsS -G "${AUTH[@]}" "$BASE_URL/api/qualitygates/list" | jq --arg name "$GATE_NAME" '[.qualitygates[] | select(.name == $name)] | length')"
if [ "$EXISTING_GATE" -gt 0 ]; then
  say "quality gate '${GATE_NAME}' already exists — reconciling conditions"
else
  say "creating quality gate '${GATE_NAME}'"
  curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/qualitygates/create" \
    --data-urlencode "name=${GATE_NAME}" \
    >/dev/null
fi

GATE_SHOW="$(curl -fsS -G "${AUTH[@]}" "$BASE_URL/api/qualitygates/show" --data-urlencode "name=${GATE_NAME}")"

while IFS= read -r cond; do
  METRIC="$(jq -r '.metric' <<<"$cond")"
  OP="$(jq -r '.op' <<<"$cond")"
  ERROR="$(jq -r '.error' <<<"$cond")"

  EXISTING_CONDITION_ID="$(jq -r --arg metric "$METRIC" '.conditions[]? | select(.metric == $metric) | .id' <<<"$GATE_SHOW")"

  if [ -n "$EXISTING_CONDITION_ID" ]; then
    say "updating condition '${METRIC}' on '${GATE_NAME}'"
    curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/qualitygates/update_condition" \
      --data-urlencode "id=${EXISTING_CONDITION_ID}" \
      --data-urlencode "metric=${METRIC}" \
      --data-urlencode "op=${OP}" \
      --data-urlencode "error=${ERROR}" \
      >/dev/null
  else
    say "adding condition '${METRIC}' to '${GATE_NAME}'"
    curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/qualitygates/create_condition" \
      --data-urlencode "gateName=${GATE_NAME}" \
      --data-urlencode "metric=${METRIC}" \
      --data-urlencode "op=${OP}" \
      --data-urlencode "error=${ERROR}" \
      >/dev/null
  fi
done < <(jq -c '.conditions[]' "$GATE_FILE")

# SonarQube auto-adds its "Clean as You Code" default conditions to any newly
# created custom gate (new_violations, new_duplicated_lines_density, ...).
# The checked-in JSON is authoritative, so strip anything it doesn't list.
GATE_SHOW="$(curl -fsS -G "${AUTH[@]}" "$BASE_URL/api/qualitygates/show" --data-urlencode "name=${GATE_NAME}")"
DESIRED_METRICS="$(jq -r '[.conditions[].metric] | join(",")' "$GATE_FILE")"

while IFS=$'\t' read -r id metric; do
  say "removing condition '${metric}' from '${GATE_NAME}' (not in ${GATE_FILE##*/})"
  curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/qualitygates/delete_condition" \
    --data-urlencode "id=${id}" \
    >/dev/null
done < <(jq -r --arg metrics "$DESIRED_METRICS" '
  ($metrics | split(",")) as $desired
  | .conditions[]? | select(([.metric] - $desired) | length > 0)
  | [.id, .metric] | @tsv
' <<<"$GATE_SHOW")

say "assigning quality gate '${GATE_NAME}' to project '${PROJECT_KEY}'"
curl -fsS "${AUTH[@]}" -X POST "$BASE_URL/api/qualitygates/select" \
  --data-urlencode "gateName=${GATE_NAME}" \
  --data-urlencode "projectKey=${PROJECT_KEY}" \
  >/dev/null

say "quality gate '${GATE_NAME}' assigned to '${PROJECT_KEY}'"
