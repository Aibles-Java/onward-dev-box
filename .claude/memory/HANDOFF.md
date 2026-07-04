# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-04)

- Branch `feature/issue-6-make-run` (issue #6, card In progress → Ready For
  Testing once PR opens): `run` target added to `Makefile` — `FF_DIR ?=
  ../feature_flag` override, `[ -x mvnw ]` checkout check with actionable
  error, idempotent `compose --profile core up -d --wait` before
  `./mvnw spring-boot:run`. CLAUDE.md Commands synced (run → implemented).
  Both acceptance criteria verified live: full `make init && make up && make
  run` boot (app on 8081, Liquibase applied all 9 tables to fresh
  `feature_flag_db`) and the missing-checkout error path (exit 1, clear
  message). Rationale in `decisions/0007-make-run-target.md`.
- Verification again required temporarily stopping the squatting `ff_postgres`
  (restored afterwards; test `.env` and volumes removed — repo clean apart
  from the intended diff).
- Estimate S / 3h written to board + `calibration.md` (human AFK → recommended
  value, adjustable — same precedent as #3/#4/#5).
- Calibration `Actual`/`Δ` for #3, #4, #5 still empty — needs human's actual
  hours (#5 merged as PR #23).

## Context to Load

- `decisions/0007-make-run-target.md` — make run choices + verify recipe
- `docs/INFRASTRUCTURE.md` §3 — remaining Phase 1 items (1.5 doctor, 1.6 wait-for)

## Next steps

1. PR for `feature/issue-6-make-run` → `develop` (Closes #6): open + card to
   Ready For Testing; when merged, `issue-board.sh done 6` + calibration
   Actual/Δ.
2. Remaining Phase 1 items: `scripts/doctor.sh` (1.5 — `make init` auto-picks
   it up once executable), `scripts/wait-for.sh` (1.6 — now scoped to
   host-side waits only, e.g. app on 8081 for `make smoke`; `make up`/`make
   run` no longer need it).
3. After Phase 1: companion PR to `../feature_flag` retiring its
   docker-compose.yml (frees host 5432 permanently — would end the
   `ff_postgres` stop/start dance in every verification).
