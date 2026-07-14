#!/usr/bin/env bash
# scripts/smoke-test.sh — end-to-end API smoke test (docs/INFRASTRUCTURE.md §3, item 3.3).
#
# Runs the feature_flag team's own Postman collection (they own the API, so they
# own the test) against a host-run app via `newman`. One command answers: "is my
# local environment actually working end-to-end?" — 72 chained requests with
# assertions walk auth → org → project → env → flags → SDK evaluation.
#
# This repo does NOT own the collection; it lives in the sibling feature_flag
# checkout and is only *run* here. We never edit it — the app's default baseUrl
# in the file is :8080, so we override it to :8081 (the cross-repo contract port)
# at run time instead.
#
# Runner selection (SMOKE_RUNNER=auto|node|docker, default auto):
#   node   — `newman` on PATH, else `npx --yes newman` (needs Node)
#   docker — dockerized `postman/newman` image (no local Node required)
# auto prefers node (no image pull) and falls back to docker.
#
# Needs a running app: `make run` foregrounds feature_flag and holds its terminal,
# so start it in one terminal and run the smoke test from a second:
#   terminal 1:  make run
#   terminal 2:  make smoke        # or: scripts/smoke-test.sh
#
# Usage:
#   scripts/smoke-test.sh                 # against http://localhost:8081
#   SMOKE_RUNNER=docker scripts/smoke-test.sh
#   FF_DIR=/path/to/feature_flag scripts/smoke-test.sh
#
# Overridable via env: FF_DIR, SMOKE_APP_URL, SMOKE_WAIT, SMOKE_RUNNER.
#
# Fresh-DB expectation: the collection registers fixed demo users and expects the
# first registration to return 201, so it needs a clean instance; a dirty DB fails
# at auth with 409. This script does NOT reset the DB — it only runs the collection.
# Prefer `make smoke`, which truncates first (via `make db-reset`) so every run is
# repeatable. Running this script directly assumes you've arranged a clean DB
# yourself (`make db-reset`, or a fresh `make nuke && make run`).
set -euo pipefail

FF_DIR="${FF_DIR:-../feature_flag}"
SMOKE_APP_URL="${SMOKE_APP_URL:-http://localhost:8081}"
SMOKE_WAIT="${SMOKE_WAIT:-60}"
SMOKE_RUNNER="${SMOKE_RUNNER:-auto}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COLLECTION="$FF_DIR/docs/postman/Feature_Flag_Platform.postman_collection.json"
APP_HOSTPORT="${SMOKE_APP_URL#*://}"          # strip scheme → host:port for the TCP wait

# The dockerized runner can't reach the host's 'localhost'; on Docker Desktop and
# (via --add-host below) Linux, host.docker.internal routes back to the host.
DOCKER_APP_URL="${SMOKE_APP_URL/localhost/host.docker.internal}"
DOCKER_APP_URL="${DOCKER_APP_URL/127.0.0.1/host.docker.internal}"

die() { echo "error: $1" >&2; [ $# -gt 1 ] && echo "       $2" >&2; exit 1; }

# ── Locate the collection (owned by the sibling feature_flag repo) ───────────

[ -f "$COLLECTION" ] || die \
  "Postman collection not found at '$COLLECTION'" \
  "clone feature_flag as a sibling, or point at it: FF_DIR=/path/to/feature_flag make smoke"

# ── Wait for the app (host-run on :8081; compose can't see it) ───────────────

echo "smoke: waiting for feature_flag on $APP_HOSTPORT (up to ${SMOKE_WAIT}s)…"
"$REPO_DIR/scripts/wait-for.sh" -t "$SMOKE_WAIT" -q "$APP_HOSTPORT" || die \
  "feature_flag is not answering on $APP_HOSTPORT" \
  "start it first:  make run   (or point SMOKE_APP_URL elsewhere)"

# ── Pick a runner ────────────────────────────────────────────────────────────

have() { command -v "$1" >/dev/null 2>&1; }

runner="$SMOKE_RUNNER"
if [ "$runner" = auto ]; then
  if have newman || have npx; then
    runner=node
  elif have docker; then
    runner=docker
  else
    die "no way to run newman: need 'newman'/'npx' (Node) or 'docker' on PATH" \
        "install Node (brew install node) or Docker, then re-run 'make smoke'"
  fi
fi

# ── Run the collection ───────────────────────────────────────────────────────

case "$runner" in
  node)
    if have newman; then
      echo "smoke: running via newman (baseUrl=$SMOKE_APP_URL)"
      newman run "$COLLECTION" --env-var "baseUrl=$SMOKE_APP_URL"
    elif have npx; then
      echo "smoke: running via 'npx newman' (baseUrl=$SMOKE_APP_URL)"
      npx --yes newman run "$COLLECTION" --env-var "baseUrl=$SMOKE_APP_URL"
    else
      die "SMOKE_RUNNER=node but neither 'newman' nor 'npx' is on PATH" \
          "install Node, or use SMOKE_RUNNER=docker"
    fi
    ;;
  docker)
    have docker || die "SMOKE_RUNNER=docker but 'docker' is not on PATH" "install Docker Desktop"
    echo "smoke: running via dockerized postman/newman (baseUrl=$DOCKER_APP_URL)"
    # Mount the collection read-only into the image's workdir (/etc/newman).
    # --add-host maps host.docker.internal on Linux (a no-op on Docker Desktop).
    docker run --rm \
      --add-host host.docker.internal:host-gateway \
      -v "$(cd "$(dirname "$COLLECTION")" && pwd)/$(basename "$COLLECTION")":/etc/newman/collection.json:ro \
      postman/newman run collection.json --env-var "baseUrl=$DOCKER_APP_URL"
    ;;
  *)
    die "unknown SMOKE_RUNNER='$SMOKE_RUNNER' (want: auto|node|docker)"
    ;;
esac

echo "smoke: collection passed — local environment is working end-to-end"
