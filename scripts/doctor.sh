#!/usr/bin/env bash
# scripts/doctor.sh — environment preflight (docs/INFRASTRUCTURE.md §3, item 1.5).
#
# Verifies the host can run the dev-box BEFORE anything boots: Docker daemon +
# Compose v2, Java 21 (the consumer app runs on the host), and the workspace
# ports (free, or held by our own containers). Pass `quality` to add the
# SonarQube host requirements (vm.max_map_count on Linux, ≥ 4 GB Docker memory).
#
# Usage:
#   scripts/doctor.sh            # core checks
#   scripts/doctor.sh quality    # core + quality-profile checks
#
# Runs every check (no early exit) so one pass shows all problems; each failure
# prints an actionable fix. Exit 1 if any check failed, 0 otherwise.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

QUALITY=false
for arg in "$@"; do
  case "$arg" in
    quality|--quality) QUALITY=true ;;
    *) echo "usage: scripts/doctor.sh [quality]" >&2; exit 2 ;;
  esac
done

FAILS=0
WARNS=0

ok()   { printf 'ok    %s\n' "$1"; }
warn() { printf 'warn  %s\n' "$1"; WARNS=$((WARNS + 1)); }
fail() { printf 'FAIL  %s\n      fix: %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

# Read a KEY=VALUE override from .env, falling back to the compose default —
# the same resolution docker-compose.yml applies, so we check the ports that
# will actually be bound.
env_or_default() {
  local value=""
  if [ -f "$ENV_FILE" ]; then
    value="$(grep -E "^${1}=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true)"
  fi
  printf '%s' "${value:-$2}"
}

# ── Docker daemon + Compose v2 ───────────────────────────────────────────────

DOCKER_UP=false
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI not found" \
       "install Docker Desktop (macOS) or Docker Engine (Linux): https://docs.docker.com/get-docker/"
else
  if docker info >/dev/null 2>&1; then
    DOCKER_UP=true
    ok "Docker daemon running"
  else
    fail "Docker daemon not running" \
         "start Docker Desktop (macOS) or 'sudo systemctl start docker' (Linux)"
  fi
  # The compose plugin is a CLI concern — checkable even with the daemon down.
  if compose_version="$(docker compose version --short 2>/dev/null)"; then
    ok "Compose v2 available (v$compose_version)"
  else
    fail "Compose v2 ('docker compose') not available" \
         "upgrade Docker Desktop, or install the plugin: https://docs.docker.com/compose/install/linux/"
  fi
fi

# ── Java 21 (feature_flag runs on the host, not in compose) ──────────────────

JAVA_VERSION_LINE=""
if ! command -v java >/dev/null 2>&1; then
  fail "java not found on PATH — the consumer app (feature_flag) runs on the host and needs Java 21" \
       "install Temurin 21: 'brew install --cask temurin@21' (macOS) or 'sdk install java 21-tem' (SDKMAN)"
else
  JAVA_VERSION_LINE="$(java -version 2>&1 | head -n1)"
  major="$(printf '%s' "$JAVA_VERSION_LINE" | sed -En 's/.*version "([0-9]+)[."].*/\1/p')"
  case "$major" in
    21)
      ok "Java 21 on PATH ($JAVA_VERSION_LINE)"
      ;;
    ''|*[!0-9]*)
      warn "could not parse the java version from: $JAVA_VERSION_LINE — expected Java 21"
      ;;
    *)
      if [ "$major" -gt 21 ]; then
        warn "Java $major on PATH — newer than the Java 21 feature_flag targets; usually fine, pin 21 if the build misbehaves"
      else
        fail "Java $major on PATH — feature_flag needs Java 21 ($JAVA_VERSION_LINE)" \
             "install Temurin 21: 'brew install --cask temurin@21' (macOS) or 'sdk install java 21-tem' (SDKMAN)"
      fi
      ;;
  esac
fi

if [ -n "${JAVA_HOME:-}" ] && [ -n "$JAVA_VERSION_LINE" ]; then
  if [ ! -x "$JAVA_HOME/bin/java" ]; then
    warn "JAVA_HOME points at '$JAVA_HOME' but there is no java binary there — Maven may pick a different JDK than your PATH"
  else
    java_home_line="$("$JAVA_HOME/bin/java" -version 2>&1 | head -n1)"
    if [ "$java_home_line" != "$JAVA_VERSION_LINE" ]; then
      warn "JAVA_HOME java ($java_home_line) differs from PATH java ($JAVA_VERSION_LINE) — Maven uses JAVA_HOME; on macOS: export JAVA_HOME=\$(/usr/libexec/java_home -v 21)"
    fi
  fi
fi

# ── CLI tooling ('make seed' drives the Admin API with curl + jq) ────────────

for tool in curl jq; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool on PATH"
  else
    fail "$tool not found on PATH — 'make seed' needs it to call the feature_flag Admin API" \
         "install it: 'brew install $tool' (macOS) or your distro's package manager (Linux)"
  fi
done

# ── Ports (free, or held by our own containers) ──────────────────────────────

port_listener() {
  # Best-effort "who listens on this port" for the fix message.
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1 " (pid " $2 ")"}'
  fi
}

port_busy() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
  fi
}

# check_port <port> <expected-container|-> <what> <fix-if-taken>
check_port() {
  local port="$1" expected="$2" what="$3" fix="$4"
  local owner listener
  if ! port_busy "$port"; then
    ok "port $port free ($what)"
    return
  fi
  if [ "$DOCKER_UP" = true ]; then
    owner="$(docker ps --filter "publish=$port" --format '{{.Names}}' | head -n1 || true)"
    if [ -n "$owner" ]; then
      if [ "$owner" = "$expected" ]; then
        ok "port $port held by our own container '$owner' ($what)"
      else
        fail "port $port taken by container '$owner' ($what)" \
             "stop it: 'docker stop $owner' — $fix"
      fi
      return
    fi
  fi
  listener="$(port_listener "$port")"
  fail "port $port taken by ${listener:-an unknown process} ($what)" "$fix"
}

POSTGRES_PORT="$(env_or_default POSTGRES_PORT 5432)"
SONAR_PORT="$(env_or_default SONAR_PORT 9000)"
ADMINER_PORT="$(env_or_default ADMINER_PORT 8090)"

check_port "$POSTGRES_PORT" onward_postgres "postgres" \
  "stop the conflicting service (a local 'brew services stop postgresql'?) — do NOT move POSTGRES_PORT casually, 5432 is the cross-repo contract with ../feature_flag"
check_port 8081 - "feature_flag app, host-run" \
  "is feature_flag already running? stop it before 'make run' starts another instance"
check_port "$SONAR_PORT" onward_sonarqube "sonarqube" \
  "stop the conflicting service, or override SONAR_PORT in .env (claim ports in docs/INFRASTRUCTURE.md §4)"
check_port "$ADMINER_PORT" onward_adminer "adminer" \
  "stop the conflicting service, or override ADMINER_PORT in .env (claim ports in docs/INFRASTRUCTURE.md §4)"

# ── Quality profile extras (SonarQube's embedded Elasticsearch) ──────────────

if [ "$QUALITY" = true ]; then
  if [ "$(uname -s)" = "Linux" ]; then
    max_map_count="$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)"
    if [ "$max_map_count" -ge 262144 ]; then
      ok "vm.max_map_count=$max_map_count (>= 262144, SonarQube/Elasticsearch)"
    else
      fail "vm.max_map_count=$max_map_count < 262144 — SonarQube's embedded Elasticsearch will not start" \
           "sudo sysctl -w vm.max_map_count=262144, persist via /etc/sysctl.d/99-sonarqube.conf"
    fi
  else
    ok "vm.max_map_count check skipped (not Linux — the Docker Desktop VM preconfigures it)"
  fi

  if [ "$DOCKER_UP" = true ]; then
    docker_mem="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
    docker_mem_gib="$(awk -v bytes="$docker_mem" 'BEGIN {printf "%.1f", bytes / 1073741824}')"
    # Docker Desktop reports the VM's MemTotal, slightly below the configured
    # allocation — a ~3.7 GiB floor lets an exact "4 GB" setting pass.
    if [ "$docker_mem" -ge 3900000000 ]; then
      ok "Docker memory ${docker_mem_gib} GiB (>= 4 GB for the quality profile)"
    else
      fail "Docker memory ${docker_mem_gib} GiB < 4 GB — SonarQube needs headroom" \
           "Docker Desktop → Settings → Resources → Memory ≥ 4 GB (native Linux: free up host memory)"
    fi
  else
    warn "Docker memory check skipped — daemon not running"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo
if [ "$FAILS" -gt 0 ]; then
  echo "doctor: $FAILS check(s) FAILED, $WARNS warning(s) — fix the above before 'make up'"
  exit 1
fi
echo "doctor: all checks passed ($WARNS warning(s))"
