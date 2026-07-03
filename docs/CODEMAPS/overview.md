# Overview — onward-dev-box

Shared local infrastructure for Aibles-Java services. Greenfield: the plan in
`docs/INFRASTRUCTURE.md` is the source of truth; runtime files land per its phases.

## Where things are (or will be)

| Path | What | State |
|---|---|---|
| `docs/INFRASTRUCTURE.md` | Build plan, tool list, **port registry (§4)** | exists |
| `docs/architecture.md` | Service topology + design principles | exists |
| `docs/adr/` | Decision records (0001: dev-box architecture) | exists |
| `docker-compose.yml` | Services gated by profiles core/quality/tools | planned (Phase 1) |
| `postgres/init/` | First-boot SQL — one db + user per service | planned (Phase 1) |
| `Makefile` | Developer entrypoint (`make up/run/sonar/...`) | planned (Phase 1) |
| `scripts/` | doctor / wait-for / seed / smoke helpers | planned (Phase 1–3) |
| `sonarqube/bootstrap.sh` | Idempotent SonarQube setup | planned (Phase 2) |
| `.claude/` | Harness: memory system, hooks, skills, drift-monitor agent | exists |
| `.githooks/pre-push` | Memory-gate backstop (`git config core.hooksPath .githooks`) | exists |

## Key flows

- **Boot flow:** `make up` → compose starts postgres (core profile) → init SQL on
  first boot → wait-for health → developer runs the app on the host.
- **Quality flow:** `make up-all` → sonarqube (quality profile) → `make sonar` runs
  analysis of `../feature_flag` against `localhost:9000`.
- **Memory flow:** work session → `/save-memory` → pre-push gate verifies memory
  travels with pushed work.

## Gotchas

See `CLAUDE.md` — most importantly: init SQL only runs on an empty volume, and the
compose config is a cross-repo contract with `../feature_flag`'s
`application.properties`.
