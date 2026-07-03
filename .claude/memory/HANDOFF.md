# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Where things stand (2026-07-03)

- `docs/INFRASTRUCTURE.md` — full build plan written (phases 1–4, port registry §4);
  **nothing implemented yet**: no docker-compose.yml, Makefile, or scripts.
- Tier 3 Claude Code harness installed via /shipwithai-starter:init, ported from
  `../feature_flag/.claude`: memory system + hooks, shellcheck hook, git-workflow +
  save-memory skills, cross-repo drift-monitor agent, ADR-0001, CODEMAPS.

## Blocked on the human

1. ~~settings.json hook wiring~~ — DONE 2026-07-03: user explicitly approved,
   full config applied (hooks active from the next session).
2. `git config core.hooksPath .githooks` — enable the pre-push memory-gate backstop.
3. Branch cleanup: local branch is `master`, default is `main`, and gitflow was
   chosen — create/push `develop`, align local branch.

## Next work

- Phase 1 of INFRASTRUCTURE.md §3: docker-compose.yml (profiles core/quality/tools),
  postgres/init/01-init-databases.sql, .env.example, Makefile, doctor.sh, wait-for.sh.
- Companion PR to feature_flag afterwards: retire its local docker-compose.yml,
  update its CLAUDE.md quick-start (ADR-0001 decision 6).
