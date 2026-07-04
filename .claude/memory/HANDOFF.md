# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/issue-7-doctor-preflight` (issue #7, estimated M/4h): new
  `scripts/doctor.sh` (executable, shellcheck-clean) + `make doctor` target
  (`PROFILE=quality` for sonarqube host checks) + CLAUDE.md Commands sync
  (doctor → implemented). `make init` now actually runs the preflight (its
  auto-pickup branch existed since #5).
- All three DoD failure modes verified live on this macOS host: Docker down
  (via `DOCKER_HOST=tcp://127.0.0.1:1` — Docker Desktop never stopped), port
  5432 taken (real `ff_postgres`, fix names `docker stop ff_postgres`), wrong
  Java (PATH shim faking 17). Happy path + "held by our own container" via the
  usual ff_postgres swap; machine restored (ff_postgres back on 5432, test
  `.env` and volume removed). Linux `vm.max_map_count` branch untested — no
  Linux host. Rationale + gotchas in `decisions/0008-doctor-preflight.md`.
- Estimate M/4h written to board + `calibration.md` (human AFK → recommended
  value, adjustable — same precedent as #3–#6).
- Calibration `Actual`/`Δ` for #3–#7 still empty — needs human's actual hours.

## Context to Load

- `decisions/0008-doctor-preflight.md` — doctor.sh design + verify recipe
- `docs/INFRASTRUCTURE.md` §3 — remaining Phase 1 item (1.6 wait-for, host-side
  waits only) and Phase 2 (sonarqube bootstrap, `make sonar`)

## Next steps

1. PR for `feature/issue-7-doctor-preflight` → `develop` (Closes #7): open +
   card to Ready For Testing; when merged, `issue-board.sh done 7` +
   calibration Actual/Δ.
2. Issue #6 merged as PR #24 — if its card isn't Done yet, `issue-board.sh
   done 6` and chase calibration Actual/Δ with the human.
3. Remaining Phase 1: `scripts/wait-for.sh` (1.6 — host-side waits only, e.g.
   app on 8081 for `make smoke`). Then Phase 2 (sonarqube bootstrap).
4. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432 permanently — ends the `ff_postgres`
   stop/start dance in every verification).
