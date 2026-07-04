# 0009 — `wait-for.sh`: host-side TCP/HTTP readiness helper (issue #8)

**Date:** 2026-07-04 · **Branch:** `feature/issue-8-wait-for`

## What was decided

1. **Auto-detected modes, one positional target.** `http://`/`https://` prefix →
   HTTP mode (curl, `-fsS`, 5s per-attempt cap); anything with a colon → TCP
   mode via bash's `/dev/tcp` in a subshell (fd closes on return, no `nc`
   dependency — same probe pattern as doctor.sh's `port_busy`). No `tcp|http`
   subcommand to remember.
2. **`-e <text>` body-match flag (HTTP only), beyond the issue's letter.** A
   bare 200-wait can't serve the known Phase 2 consumer: SonarQube's
   `/api/system/status` answers 200 while `"status":"STARTING"`. `-e UP` makes
   `sonarqube/bootstrap.sh` (2.1) a one-liner. Rejected keeping it minimal —
   the flag is ~4 lines and directly serves the only planned HTTP caller.
   `-e` on a TCP target is a usage error (exit 2), keeping mode semantics
   honest.
3. **Exit codes: 0 up, 1 timeout, 2 usage** — timeout distinguishable from
   caller mistakes. Timing uses bash's `SECONDS` builtin (no `date` math,
   bash-3.2-safe for macOS).
4. **No Makefile wiring in this issue.** 0007 already narrowed 1.6: compose
   `up -d --wait` owns container-side waits; this helper is for waits compose
   can't see (host app on 8081 for the future `make smoke`, SonarQube API
   readiness). INFRASTRUCTURE.md §1.6 text updated to match — it still claimed
   "used by `make up`".

## Verification (live, both acceptance criteria)

Against throwaway `python3 -m http.server` listeners: TCP + HTTP + `-e` match
succeed in 0s when up; a listener started ~3s late succeeds at 4s (prompt, no
full-timeout wait); closed port / 404 / body mismatch all exit 1 at the `-t`
deadline; bad args (no target, non-numeric timeout/port, `-e` with TCP, bare
hostname) all exit 2 with usage/errors; `-q` suppresses the success line.
shellcheck clean.
