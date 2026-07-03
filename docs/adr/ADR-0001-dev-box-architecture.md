# ADR-0001: Dev-box architecture — shared local infrastructure for the workspace

- **Status:** Accepted
- **Date:** 2026-07-03
- **Context:** feature_flag issue #14 (quality tooling) and its decision comment

## Context

The Aibles-Java workspace needs local infrastructure for its services (first:
`feature_flag`, which requires PostgreSQL and — per the issue #14 decision — a
self-hosted SonarQube quality gate). Embedding infra in each service repo duplicates
config and drifts; the team chose a split:

- **onward-dev-box** (this repo) — everything needed to run and verify services locally.
- **onward-infras** (future) — SIT/PROD infrastructure.

## Decisions

1. **Apps on the host, state in Docker.** Services under development run via their own
   build tool (`./mvnw spring-boot:run`) for debugger/hot-reload; only stateful
   dependencies (Postgres, SonarQube) are containerized here.
2. **One shared Postgres, one database + owner user per service.** Multi-tenant
   isolation by ownership, not by container. A service needing a different Postgres
   major version or special image gets its own container at that point.
3. **One shared SonarQube, one project per service**, with a single checked-in
   quality-gate definition so DEV and (future) SIT gates stay identical. Community
   Edition accepted — one-branch-per-project limitation is fine locally.
4. **Compose profiles** (`core` / `quality` / `tools`) keep the default footprint to
   Postgres only; a `Makefile` is the sole developer interface.
5. **Port allocation is a workspace registry** maintained in
   `docs/INFRASTRUCTURE.md` §4: 5432 postgres, 8081 feature_flag (host), 9000
   sonarqube, 8090 adminer.
6. **The service repo's own docker-compose.yml is superseded** — a companion PR to
   feature_flag will remove or stub it so infra truth lives here only.

## Consequences

- Compose credentials/ports become a **cross-repo contract** with each consumer's
  application config; the `drift-monitor` agent checks it stays in sync.
- Postgres init SQL runs only on first boot — adding services later requires a live-SQL
  helper or a volume reset (`make nuke`).
- Local credentials are deliberately weak/committed (`.env.example`); they must never
  be reused beyond localhost.
