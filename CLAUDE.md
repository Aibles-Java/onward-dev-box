# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Local development environment ("dev-box") for the Aibles-Java workspace. Provides the
shared infrastructure — PostgreSQL, SonarQube, dev tooling — that sibling service repos
(first consumer: `../feature_flag`) need to run on a developer machine. SIT/PROD
infrastructure lives in a separate repo (`onward-infras`, future); this repo is
local-only by design.

**Status: greenfield.** The target design lives in `docs/INFRASTRUCTURE.md` (the build
plan and the workspace port registry). The compose file, Makefile, and scripts are being
built out per that plan — keep this file's Commands section in sync as targets land.

## Commands

```bash
# Makefile lifecycle targets (implemented — `make help` lists them)
make init      # copy .env.example → .env; runs the doctor preflight
make doctor    # environment preflight (PROFILE=quality adds sonarqube host checks)
make up        # start core profile (postgres) and wait until healthy
make up-all    # core + quality (sonarqube) + tools (adminer)
make down      # stop, keep volumes
make nuke      # stop + delete volumes (fresh state; confirms first)
make logs      # tail all service logs
make db        # psql shell into feature_flag_db (contract credentials)
make run       # run ../feature_flag on the host (FF_DIR to override); waits for DB health
make seed      # seed demo data (org/project/env/flags) into feature_flag via its Admin API
make sonar     # local SonarQube analysis of ../feature_flag checks

# Planned targets, landing with their own issues (see docs/INFRASTRUCTURE.md §3)
make smoke     # end-to-end smoke test of the running stack (issue #15)

# Lint all shell scripts
shellcheck scripts/*.sh .claude/hooks/*.sh
```

## Architecture

- `docker-compose.yml` — all services, gated by Compose **profiles**: `core` (postgres),
  `quality` (sonarqube), `tools` (adminer). One shared `onward` network.
- `postgres/init/` — first-boot SQL; **one database + owner user per consumer service**
  (multi-tenant shared instance).
- `sonarqube/` — idempotent bootstrap (admin password, one project per service, shared
  quality-gate definition).
- `scripts/` — `doctor.sh`, `wait-for.sh`, seed and smoke-test helpers.
- `Makefile` — the single developer entrypoint; nothing should require raw docker
  commands.
- Consumer apps run **on the host** (debugger, hot reload); only stateful dependencies
  run in Docker.

See `docs/architecture.md` for the service topology and `docs/adr/` for decisions.

## Cross-repo contract (critical)

This repo's compose config must satisfy what `../feature_flag` expects in
`src/main/resources/application.properties`:

| Contract | Value |
|---|---|
| Postgres port | `5432` |
| Database / user / password | `feature_flag_db` / `ff_user` / `ff_password` |
| App port (host-run, not ours) | `8081` |

Changing any of these here without a matching change in feature_flag breaks the app.
The `drift-monitor` agent checks this contract — run it via "check drift".

## Gotchas

- `postgres/init/*.sql` executes **only on first boot** (empty volume). Adding a
  database later means `make nuke` or applying the SQL to the live instance.
- The port table in `docs/INFRASTRUCTURE.md` §4 is the workspace-wide **port registry**.
  Claim ports there before adding any service.
- SonarQube Community analyzes **one branch per project** — no local PR analysis.
- Local-only credentials live in `.env` / compose defaults on purpose; never reuse them
  outside localhost, and never commit `.env`.

## Conventions

- **Branching:** gitflow — `feature/<slug>` → `develop`; never commit directly to `main`.
- **Commits:** conventional — `type(scope): subject` (see `.claude/skills/git-workflow/`).
- **Shell:** all scripts pass `shellcheck`; `set -euo pipefail` unless a hook must
  never block (then `set -uo pipefail` + explicit exit 0).
- **Memory:** durable decisions/conventions go in `.claude/memory/` via `/save-memory`;
  the pre-push gate blocks work pushes that don't update memory
  (`SKIP_MEMORY_CHECK=1` to override intentionally).
- Enable the git backstop once after cloning: `git config core.hooksPath .githooks`.

## Sensitive areas

- `postgres/init/` — credential definitions that sibling repos depend on
- `docker-compose.yml` port mappings — collisions break other workspace services
- `.claude/hooks/` — harness enforcement; changes require explicit human confirmation
