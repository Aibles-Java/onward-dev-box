# 0015 — Issue #13 Phase 2 acceptance verification closed out

**What:** Re-ran and confirmed all four acceptance criteria on issue #13 on a
live checkout (not just the earlier same-day exploratory run):
`make up-all` → all 3 services (`postgres`, `sonarqube`, `adminer`) reported
`Healthy`; `sonarqube/bootstrap.sh` re-run cleanly (idempotent — password/project
skip, token revoke-then-regenerate, gate conditions reconciled); `make sonar`
against `../feature_flag` printed `QUALITY GATE STATUS: PASSED` and
`BUILD SUCCESS`, exit 0.

**Why:** Issue #13's 4th acceptance line ("SonarQube Community limitation
documented: one branch per project, no local PR analysis") was **not** actually
satisfied — earlier HANDOFF notes claimed this was covered by
`docs/INFRASTRUCTURE.md` §1's quality-gate row, but that row only references
issue #14 for the *choice* of self-hosted SonarQube, not the Community edition's
one-branch/no-PR-decoration limitation. Added an explicit note under §3.2 (`make
sonar`) instead, and flipped `docs/INFRASTRUCTURE.md` §6 Definition-of-done line
4 from unchecked to `[x]` (Phase 2 line, `make up-all`/`make sonar` acceptance).

**How to apply:** Don't trust a HANDOFF claim that something is "already
documented" at face value — grep for the actual text before closing an
acceptance checkbox off of it. See [[0014-make-sonar-target]] for the sonar
target itself.

**Gotcha:** `make sonar`'s Maven output is long (~15 min) and gets silently
truncated by the terminal capture when run in the foreground — redirect to a
log file with `run_in_background` / `nohup ... &` and poll for the child
process (`pgrep -f "mvnw verify sonar"`) to exit, then grep the log file, or
the `QUALITY GATE STATUS` / `BUILD SUCCESS` lines near the end get cut off.
