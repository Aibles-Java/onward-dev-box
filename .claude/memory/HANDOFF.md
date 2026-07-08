# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-08)

- Issues #9, #10, #11, #12, #13, #28 are closed/merged — no action needed there.
- Issue #14 (`scripts/seed-feature-flag.sh` via Admin API) implemented on
  branch `feature/issue-14-seed-feature-flag`:
  - New `scripts/seed-feature-flag.sh`, wired as `make seed`. Registers a
    fixed demo user, creates org `aibles-demo` → project → three environments
    (Development/SIT/Production) → two flags (`new-dashboard` BOOLEAN,
    `welcome-message` STRING), prints each environment's SDK API key.
  - `docs/INFRASTRUCTURE.md` §3.2 updated: marked done, documented the
    register-returns-empty-body gotcha and the re-run "already seeded"
    failure behavior.
  - Verified end-to-end on a clean machine: `make nuke` (confirmed) →
    `make up` → `make run` (feature_flag on host) → `make seed` (fresh run
    succeeded, printed working SDK keys, confirmed via
    `curl -H "X-Environment-Key: ..." .../api/v1/sdk/flags` → 200 with both
    flags) → re-ran `make seed` → failed with the "already seeded" message,
    non-zero exit, no duplicates created. `shellcheck` clean.
  - Full rationale + gotchas (register empty-body, `X-Environment-Key` header
    name, avoided `declare -A` for macOS bash 3.2 compat) in
    `decisions/0016-seed-feature-flag.md`.
  - Not yet pushed / PR not yet opened as of this handoff.
- Calibration `Actual`/`Δ` for #3–#14 still empty — needs human's actual hours.

## Context to Load

- `decisions/0016-seed-feature-flag.md` — issue #14 rationale + the
  register-empty-body and SDK-header gotchas; read before touching
  `scripts/seed-feature-flag.sh` or `scripts/smoke-test.sh` (issue #15, same
  API surface)
- `decisions/0015-issue-13-phase2-verification.md` — issue #13 close-out
  rationale
- `decisions/0014-make-sonar-target.md` — `make sonar` gotchas

## Next steps

1. Push `feature/issue-14-seed-feature-flag`, open PR (Closes #14, base
   `develop`), move card to Ready For Testing. When merged, use
   `issue-board.sh done 14` to close the issue.
2. Remaining open Phase 3 issues: #15 (smoke-test.sh — can reuse the
   register/login/SDK-header findings from #14), #16 (RUNBOOK.md), #17
   (validate.yml CI), #18 (companion PR to feature_flag retiring its
   docker-compose.yml).
