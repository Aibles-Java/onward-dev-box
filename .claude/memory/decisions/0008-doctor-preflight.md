# 0008 — scripts/doctor.sh preflight design (issue #7)

**Date:** 2026-07-04

## Decisions

- **Run all checks, no early exit.** One pass surfaces every problem (counters +
  summary, exit 1 if any FAIL) instead of fail-fast-per-check — a new dev fixes
  everything in one round trip. Each FAIL prints a `fix:` line with a concrete
  command, not just an error.
- **Port "free or ours"** resolved via `docker ps --filter "publish=$port"
  --format '{{.Names}}'` matched against the fixed `container_name`s
  (`onward_postgres`/`onward_sonarqube`/`onward_adminer`). A foreign container
  gets a `docker stop <name>` fix (catches the real `ff_postgres` squatter);
  a host process falls back to `lsof` attribution; no `lsof` → bash `/dev/tcp`
  probe with "unknown process".
- **Port values mirror compose resolution:** `env_or_default` greps `.env` for
  `POSTGRES_PORT`/`SONAR_PORT`/`ADMINER_PORT` and falls back to the compose
  defaults, so doctor checks the ports that will actually bind. 8081 is fixed
  (host-run app contract, no container expected).
- **Quality checks are arg-gated** (`scripts/doctor.sh quality`, or
  `make doctor PROFILE=quality`) per the spec's "when the quality profile is
  requested": Linux-only `vm.max_map_count >= 262144` (macOS prints an explicit
  skip), Docker `MemTotal` with a **3.9 GB floor** — Docker Desktop reports the
  VM's MemTotal slightly below the configured allocation, so an exact "4 GB"
  setting must still pass.
- **Java policy:** major == 21 → ok; > 21 → warn (usually fine); < 21 or
  unparseable → FAIL/warn with Temurin 21 install fix. `JAVA_HOME` issues
  (missing binary, version ≠ PATH java) are warns, never FAILs — Maven uses
  JAVA_HOME, so the fix line gives `/usr/libexec/java_home -v 21`.

## Gotcha (macOS awk)

`$(awk "BEGIN {printf \"%.1f\", $var / ...}")` nested inside an outer
double-quoted string breaks macOS awk (program splits at the comma). Use
`awk -v bytes="$var" 'BEGIN {printf "%.1f", bytes/...}'` — single-quoted
program + `-v`, computed into a variable first.

## Verification (2026-07-04, macOS host)

All three DoD failure modes live-tested: Docker down (simulated via
`DOCKER_HOST=tcp://127.0.0.1:1` — no need to stop Docker Desktop), port 5432
taken (real `ff_postgres`, container-attributed fix), wrong Java (PATH shim
faking 17). Happy path via the usual swap: stop `ff_postgres` → `compose
--profile core up -d --wait` → all ok incl. "held by our own container" →
`down -v` + restart `ff_postgres`. `.env` override tested with a throwaway
`SONAR_PORT=9999`. **Untested:** the Linux `vm.max_map_count` branch
(shellcheck + logic review only — no Linux host available).
