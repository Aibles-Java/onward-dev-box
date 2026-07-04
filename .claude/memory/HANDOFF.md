# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/issue-8-wait-for` (issue #8, estimated S/2h): new
  `scripts/wait-for.sh` (executable, shellcheck-clean) — auto-detected TCP
  (`host:port` via `/dev/tcp`) and HTTP (`http[s]://` via curl) modes, `-t`
  timeout (default 60s), `-e` body-match for HTTP (SonarQube `status=UP`),
  `-q` quiet. INFRASTRUCTURE.md §1.6 reworded (was stale: claimed "used by
  `make up`"; 0007 gave that to compose `--wait`). No Makefile change — first
  real callers are the future `make smoke` (8081) and `sonarqube/bootstrap.sh`.
- Verified live against throwaway python http.server listeners: prompt success
  (0s when up, 4s for a 3s-late listener), exit 1 on timeout for closed
  port/404/body-mismatch, exit 2 on all bad-args paths, `-q` silent. Rationale
  in `decisions/0009-wait-for-helper.md`.
- Estimate S/2h written to board + `calibration.md` (human AFK → recommended
  value, adjustable — same precedent as #3–#7).
- Calibration `Actual`/`Δ` for #3–#8 still empty — needs human's actual hours.
- Issue #7 (doctor.sh) merged as PR #25; if its card isn't Done yet:
  `issue-board.sh done 7` + calibration Actual/Δ.

## Context to Load

- `decisions/0009-wait-for-helper.md` — wait-for.sh design + verify recipe
- `docs/INFRASTRUCTURE.md` §3 — Phase 1 now complete; next is Phase 2
  (2.1 sonarqube/bootstrap.sh, 2.2 `make sonar`)

## Next steps

1. PR for `feature/issue-8-wait-for` → `develop` (Closes #8): open + card to
   Ready For Testing; when merged, `issue-board.sh done 8` + calibration
   Actual/Δ.
2. Phase 2: `sonarqube/bootstrap.sh` (2.1 — uses
   `wait-for.sh -e UP http://localhost:9000/api/system/status`), then
   `make sonar` (2.2).
3. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432 permanently — ends the `ff_postgres`
   stop/start dance in every verification).
