# 0002 — Port issue/PR workflow skills from feature_flag

**Date:** 2026-07-04
**Status:** accepted

## Decision

Ported the second wave of feature_flag's harness into this repo, adapted for an
infra repo: `create-pr`, `estimate-issue` (+ empty `calibration.md`),
`issue-workflow`, `.claude/scripts/issue-board.sh`, and
`.github/PULL_REQUEST_TEMPLATE.md`.

## What was adapted (not copied verbatim)

- **issue-board.sh** — `REPO` changed to `Aibles-Java/onward-dev-box`, and made
  overridable via `ISSUE_BOARD_REPO` env var so the script stays portable across
  workspace repos. Board stays the shared org-wide "Digital banking" project #3;
  the repo filter on every card lookup is load-bearing (feature_flag issue #12
  regression).
- **create-pr / PR template** — Test plan and Reviewer checklist rewritten for
  infra: shellcheck clean, `make nuke && make up` for compose/init changes,
  `make doctor`, cross-repo contract callout (Postgres 5432,
  `feature_flag_db`/`ff_user`/`ff_password`), port-registry claim
  (INFRASTRUCTURE.md §4), first-boot-only awareness for `postgres/init/`,
  hook-change confirmation.
- **estimate-issue** — rubric (hours → XS–XL, round up) kept verbatim for
  cross-repo comparability; evidence-gathering step rewritten for infra scoping
  (nuke cycles, first-boot SQL, consumer-repo companion changes). Calibration
  log starts empty — feature_flag's history is app-specific, don't import it.
- **issue-workflow** — sensitive-areas step points at this repo's CLAUDE.md list;
  decision-comment repo changed.

## What was deliberately NOT ported

- feature_flag's git-workflow v2.5.0 release/hotfix flow — this repo's v1.0.0
  intentionally has no release trains (`develop` → `main` promotion *is* the
  release). Do not "upgrade" it to match feature_flag.

## Verification

- `shellcheck` clean on issue-board.sh; arg-validation paths exercised.
- Read-only end-to-end: `issue-board.sh status 18` resolved the correct
  onward-dev-box card on board #3 (returned "Todo"). Board holds cards from 3
  repos (17 from this one), confirming both the board's relevance and the need
  for the repo filter.
