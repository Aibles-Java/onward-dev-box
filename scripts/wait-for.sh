#!/usr/bin/env bash
# scripts/wait-for.sh — generic TCP/HTTP readiness wait (docs/INFRASTRUCTURE.md §3, item 1.6).
#
# Polls until a TCP port accepts connections or an HTTP URL answers with a
# success status (optionally requiring a body match), then exits 0. Exits 1
# once the timeout expires. Container-side waits are compose's job
# (healthchecks + 'up --wait'); this helper covers waits compose can't see —
# host-run processes (the app on 8081 for 'make smoke') and API-level
# readiness (SonarQube /api/system/status reporting UP).
#
# Usage:
#   scripts/wait-for.sh [-t seconds] [-q] <host:port>
#   scripts/wait-for.sh [-t seconds] [-q] [-e text] <http[s]://url>
#
#   -t seconds   overall timeout (default 60)
#   -e text      HTTP mode only: also require the response body to contain <text>
#   -q           quiet — no progress output, errors only
set -euo pipefail

TIMEOUT=60
EXPECT=""
QUIET=false

usage() {
  echo "usage: scripts/wait-for.sh [-t seconds] [-q] [-e text] <host:port | http[s]://url>" >&2
  exit 2
}

while getopts ':t:e:q' opt; do
  case "$opt" in
    t) TIMEOUT="$OPTARG" ;;
    e) EXPECT="$OPTARG" ;;
    q) QUIET=true ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
TARGET="$1"

case "$TIMEOUT" in
  ''|*[!0-9]*) echo "wait-for: timeout must be a whole number of seconds, got '$TIMEOUT'" >&2; exit 2 ;;
esac

say() { [ "$QUIET" = true ] || echo "$1"; }

# ── Mode detection + probe ───────────────────────────────────────────────────

MODE=""
HOST=""
PORT=""
case "$TARGET" in
  http://*|https://*)
    MODE=http
    command -v curl >/dev/null 2>&1 || { echo "wait-for: curl is required for HTTP mode" >&2; exit 2; }
    ;;
  *:*)
    MODE=tcp
    HOST="${TARGET%:*}"
    PORT="${TARGET##*:}"
    case "$PORT" in
      ''|*[!0-9]*) echo "wait-for: '$TARGET' — port must be numeric" >&2; exit 2 ;;
    esac
    [ -n "$HOST" ] || { echo "wait-for: '$TARGET' — host is empty" >&2; exit 2; }
    if [ -n "$EXPECT" ]; then
      echo "wait-for: -e only applies to HTTP mode" >&2
      exit 2
    fi
    ;;
  *) usage ;;
esac

probe() {
  if [ "$MODE" = tcp ]; then
    # Subshell so fd 3 closes on return; /dev/tcp is a bash builtin (no nc dep).
    (exec 3<>"/dev/tcp/$HOST/$PORT") 2>/dev/null
  else
    local body
    body="$(curl -fsS --max-time 5 "$TARGET" 2>/dev/null)" || return 1
    [ -z "$EXPECT" ] || [[ "$body" == *"$EXPECT"* ]]
  fi
}

# ── Poll loop ────────────────────────────────────────────────────────────────

DESC="$TARGET"
[ -z "$EXPECT" ] || DESC="$TARGET (body contains '$EXPECT')"

deadline=$((SECONDS + TIMEOUT))
while :; do
  if probe; then
    say "wait-for: $DESC is up (after ${SECONDS}s)"
    exit 0
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "wait-for: timed out after ${TIMEOUT}s waiting for $DESC" >&2
    exit 1
  fi
  sleep 1
done
