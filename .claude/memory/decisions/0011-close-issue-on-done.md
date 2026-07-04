# 0011 — `issue-board.sh done` closes the issue, not just the board card

**Issue:** #28

## Problem

Feature PRs merge `feature/*` → `develop` (gitflow), but this repo's GitHub
default branch is `main`. Closing keywords (`Closes #N`/`Fixes #N`) only fire
on merge to the default branch, so they never auto-close an issue merged via
a feature PR — it silently stays open until someone runs `gh issue close` by
hand (happened with #9 / PR #27). They also don't fire retroactively when
`develop` eventually merges to `main`.

## Decision

`issue-board.sh done <issue#>` now runs `gh issue close` (with an explanatory
comment) immediately after moving the board card to **Done** — one command
handles both board + issue state. Feature PR bodies should still include
`Closes #N` for traceability/search, but it's documentation only, not a live
trigger.

## Alternatives considered

- Document manual `gh issue close` as a required step — rejected, still
  relies on someone remembering it every time (the exact failure mode being
  fixed).
- Only use closing keywords in the eventual `develop` → `main` release PR —
  rejected, closing keywords don't fire retroactively for issues already
  referenced in earlier merged PRs, so this wouldn't reliably close anything
  either.

## How to apply

Anyone calling `issue-board.sh done` should expect the linked issue to close
as a side effect. If a card should move to Done without closing the issue
(rare — e.g. reopened work), don't use `done`; call `set_status "Done"` logic
manually or edit the script call.
