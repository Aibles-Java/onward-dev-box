# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-07-03)

- Repo is **planned but not implemented**: `docs/INFRASTRUCTURE.md` holds the full
  build plan (phases 1–4 + port registry §4); no docker-compose.yml, Makefile, or
  scripts exist yet.
- Tier 3 harness fully installed AND active: `settings.json` hook wiring was
  explicitly approved and applied (memory hooks, observe.py, shellcheck-on-edit,
  push gate). Hooks live from the next session onward.
- Git state: **zero commits**, unborn HEAD renamed `master` → `main` (matches GitHub
  default). Remote `origin` is empty. Everything is untracked, awaiting first commit.

## Context to Load

- `decisions/0001-claude-code-harness-setup.md` — what was ported vs adapted vs skipped
- `docs/adr/ADR-0001-dev-box-architecture.md` — shared Postgres/SonarQube design
- `docs/INFRASTRUCTURE.md` §3 — the Phase 1 tool list to implement next

## Next steps

1. First commit + gitflow bootstrap (user has the commands, not yet run):
   `git add -A && git commit -m "chore: bootstrap claude code harness and dev-box docs"`,
   push `main`, then create/push `develop`. The initial push passes the memory gate
   because `.claude/memory/` is in the commit.
2. `git config core.hooksPath .githooks` — arm the git-side memory-gate backstop.
3. Implement Phase 1 of INFRASTRUCTURE.md: docker-compose.yml (profiles
   core/quality/tools), postgres/init/01-init-databases.sql, .env.example, Makefile,
   scripts/doctor.sh, scripts/wait-for.sh.
4. After Phase 1: companion PR to ../feature_flag retiring its local
   docker-compose.yml (ADR-0001 decision 6).
