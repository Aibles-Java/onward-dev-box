# 0001 — Claude Code harness setup (Tier 3, ported from feature_flag)

- **Date:** 2026-07-03
- **Trigger:** /shipwithai-starter:init after analyzing `../feature_flag/.claude`

## Decision

Install the full (Tier 3) harness, reusing feature_flag's battle-tested components
verbatim where they are project-agnostic and adapting the rest:

- **Verbatim:** `load-memory.sh`, `remind-save.sh`, `pre-push-memory-gate.sh`
  (its `origin/develop` fallback is correct — gitflow was chosen to match
  feature_flag), `observe.py`, `.githooks/pre-push`, memory `README.md`,
  `save-memory` skill.
- **Adapted:** `git-workflow` skill (release trains replaced with develop→main
  promotion; cross-repo breaking-change rule added), `drift-monitor` agent
  (rewritten around **cross-repo drift**: compose vs consumer application.properties,
  port registry vs compose), permissions allowlist (docker/make/shellcheck/psql/git
  instead of maven/java).
- **New:** `shellcheck-on-edit.sh` PostToolUse hook.
- **Skipped:** `.mcp.json` (no external services), board skills
  (issue-workflow/estimate-issue — add later if dev-box issues land on the
  Digital banking board), feature_flag's decision/convention history (starts fresh here).

## Convention honored

`settings.json` was **not** modified directly at first — hook wiring requires explicit
human confirmation (feature_flag convention: auto-mode blocks silently wiring hooks).
The config was staged at `.claude/settings.proposed.json`; the user explicitly approved
it the same day, so it was applied to `settings.json` and the staging file removed.

## Why

Same team, two repos — identical conventions (gitflow, conventional commits, memory
gate) mean zero context-switching cost, and the memory system's push gate is the only
mechanism that keeps session knowledge traveling with the work.
