# 0010 — Phase 1 clean-machine verification (issue #9)

Ran the full Phase 1 acceptance checklist end-to-end on this machine (Docker
Desktop, JDK 21) and confirmed every item passes. No code changes were needed;
this was a pure verification pass.

## What was verified

- **Clean boot**: `.env` removed, all onward volumes/containers torn down,
  then `make init && make up && make run` — postgres came up healthy, Liquibase
  applied 8 changesets, Tomcat started on 8081, `GET /v3/api-docs` returned 200.
  Zero manual steps.
- **Nuke/up**: `make nuke` (confirmed via `yes y |`) removed the
  `onward-dev-box_postgres_data` volume + `onward` network; `make up` recreated
  both from scratch; a second `make run` re-applied all 8 Liquibase changesets
  cleanly against the empty DB (same 9 tables reappeared).
- **doctor.sh failure modes**: each of the three required detections was
  triggered non-destructively via a stub `docker`/`java` prepended to `PATH`
  (rather than actually stopping the real Docker daemon or reinstalling Java) —
  Docker daemon down, port 5432 held by a foreign process (`python3 -m
  http.server 5432`), and Java 17 on PATH. All three produced `FAIL` + an
  actionable `fix:` line; exit code 1 in each case.
- **No secrets / shellcheck**: `.env` is gitignored and not tracked;
  `.env.example` documents every credential as an explicit local-only default;
  `shellcheck scripts/*.sh .claude/hooks/*.sh` exits 0.

## Why stub PATH binaries instead of real failures

Stopping the real Docker daemon or swapping the real JDK would have been slow
and disruptive (this machine's Docker also runs unrelated containers). A
throwaway executable shadowing `docker`/`java` earlier in `PATH` reproduces the
exact failure `doctor.sh` checks for (`docker info` exit code, `java -version`
parse) without touching real system state — same technique is reusable for any
future doctor.sh check additions.

## Outcome

`docs/INFRASTRUCTURE.md` §6 — checked the four Phase 1 boxes verified here
(clean boot, nuke/up, doctor.sh, no-secrets); left the two Phase 2-only boxes
(`make sonar`, `make smoke`) unchecked since those land with their own issues
and are out of scope for #9.
