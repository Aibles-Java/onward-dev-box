# Architecture — onward-dev-box

Local development infrastructure for the Aibles-Java workspace. This document describes
the runtime topology; the phased build plan and rationale live in
[INFRASTRUCTURE.md](INFRASTRUCTURE.md), and decisions in [adr/](adr/).

## Topology

```
Developer host
├── feature_flag app        ← runs on HOST via ./mvnw spring-boot:run (port 8081)
│     │ jdbc:postgresql://localhost:5432/feature_flag_db
│     ▼
└── Docker (network: onward)
    ├── postgres:16-alpine          [profile: core]     port 5432
    │     ├── feature_flag_db (owner: ff_user)
    │     └── sonar          (owner: sonar)
    ├── sonarqube:community         [profile: quality]  port 9000
    │     └── JDBC → postgres/sonar
    └── adminer                     [profile: tools]    port 8090
```

## Design principles

1. **Apps on the host, state in Docker.** Services under active development run via
   their own build tool (debugger, hot reload); only stateful dependencies are
   containerized. The app-repo `Dockerfile` is for CI images, not the local loop.
2. **One shared instance, many tenants.** A single Postgres serves every workspace
   service with a database + owner user each (`postgres/init/`). A single SonarQube
   serves every service with a project each, sharing one quality-gate definition.
3. **Profiles keep the default footprint small.** `make up` starts only `core`;
   heavier services (`quality`) start on demand.
4. **The Makefile is the only interface.** Developers never need raw `docker` commands.
5. **Ports are a workspace-wide registry** — see INFRASTRUCTURE.md §4. New services
   claim a port there first.

## Cross-repo contract

The compose config is a dependency of sibling repos. For `feature_flag`:
`localhost:5432`, database `feature_flag_db`, user `ff_user` / `ff_password` — must
match `../feature_flag/src/main/resources/application.properties` exactly. The
`drift-monitor` agent verifies this.

## Repository layout

| Path | Responsibility |
|---|---|
| `docker-compose.yml` | All services, profile-gated (planned) |
| `postgres/init/` | First-boot SQL: databases + users per service (planned) |
| `sonarqube/bootstrap.sh` | Idempotent SonarQube first-run config (planned) |
| `scripts/` | doctor / wait-for / seed / smoke-test helpers (planned) |
| `Makefile` | Developer entrypoint (planned) |
| `docs/INFRASTRUCTURE.md` | Build plan + port registry (source of truth) |
| `docs/adr/` | Architecture decision records |
| `docs/CODEMAPS/` | Navigation guides |

## Adding a new service to the workspace

1. Claim ports in the INFRASTRUCTURE.md §4 registry.
2. Add `postgres/init/NN-init-<service>.sql` (database + owner user); apply to the
   live instance or `make nuke`.
3. Add the project key to the SonarQube bootstrap list.
4. Add any service-specific containers under a new compose profile if needed.
