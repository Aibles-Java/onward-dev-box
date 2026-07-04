# onward-dev-box — Local Infrastructure Plan

Local development environment ("dev-box") for the Aibles-Java platform.
First consumer: [`feature_flag`](https://github.com/Aibles-Java/feature_flag).

> Companion repo strategy (decided in feature_flag issue #14):
> - **onward-dev-box** → everything needed to run and verify services on a developer machine (DEV/local).
> - **onward-infras** (future) → SIT / PROD infrastructure (SonarQube server, deploy targets, etc.).

---

## 1. What `feature_flag` actually needs (analysis)

Source of truth: `../feature_flag` as of 2026-07-03.

| Aspect | Value | Evidence |
|---|---|---|
| Runtime | Java 21, Spring Boot 4.1.0, Maven (wrapper included) | `pom.xml` |
| App port | `8081` | `application.properties` |
| Database | PostgreSQL, db `feature_flag_db`, user `ff_user` / `ff_password`, port `5432` | `application.properties`, `docker-compose.yml` |
| Schema migration | Liquibase (`ddl-auto=validate`, changelog in classpath) — schema is created by the app itself on startup | `application.properties` |
| Auth | JWT (local secret in properties) + API keys — **no external identity provider needed** | `pom.xml`, `application.properties` |
| API docs | SpringDoc Swagger UI at `/swagger-ui.html` | `application.properties` |
| Quality gate | JaCoCo coverage (ratchet at 0.00 → target 80%) + **self-hosted SonarQube** (decision on issue #14) | `pom.xml`, issue #14 comments |
| API testing | Postman collection (62 KB) in `docs/postman/` | `feature_flag/docs/postman/` |
| Not needed | Redis, Kafka, mail, object storage, external APIs | nothing in `pom.xml` |

**Conclusion:** the mandatory local infra is small (PostgreSQL only). The value of the
dev-box is (a) one command to bring the whole environment up, (b) local parity with the
SIT quality tooling (SonarQube), and (c) shared conventions (ports, credentials, seed
data) as more services join the `aibles-java` workspace.

---

## 2. Target repo layout

```
onward-dev-box/
├── docker-compose.yml          # all services, gated by Compose profiles
├── .env.example                # every tunable (ports, credentials, versions)
├── Makefile                    # single entrypoint: make up / down / sonar / doctor ...
├── docs/
│   ├── INFRASTRUCTURE.md       # this document
│   └── RUNBOOK.md              # day-1 developer guide (to be written)
├── postgres/
│   └── init/
│       └── 01-init-databases.sql   # creates feature_flag_db + sonar db/users
├── sonarqube/
│   └── bootstrap.sh            # first-run: admin password, project, token, quality gate
├── scripts/
│   ├── doctor.sh               # preflight: docker, java 21, free ports, disk, vm.max_map_count
│   ├── wait-for.sh             # generic TCP/health wait helper
│   ├── seed-feature-flag.sh    # seed org/project/env/flags via the Admin API
│   └── smoke-test.sh           # newman run of the Postman collection
└── .github/workflows/
    └── validate.yml            # lint compose file + shellcheck scripts
```

---

## 3. Tools to create — detailed list

Organized in build order. Phases 1–2 are the deliverable; 3–4 are follow-ups.

### Phase 1 — Core runtime (must have)

#### 1.1 `docker-compose.yml` with profiles
The canonical compose file for local development. Replaces (supersedes) the minimal
`docker-compose.yml` inside `feature_flag` so infra lives in one place.

- **Profiles:**
  - `core` → `postgres`
  - `quality` → `sonarqube` (+ shares the same Postgres instance, separate database)
  - `tools` → `adminer` (DB browser)
- **Services:**
  - `postgres` — `postgres:16-alpine`, port `${POSTGRES_PORT:-5432}`, named volume,
    healthcheck `pg_isready`, mounts `postgres/init/` into `/docker-entrypoint-initdb.d/`.
  - `sonarqube` — `sonarqube:community` (LTS pin), port `${SONAR_PORT:-9000}`,
    `SONAR_JDBC_URL` pointing at the `sonar` database on the shared Postgres,
    volumes for `data`, `extensions`, `logs`.
  - `adminer` — `adminer:latest`, port `${ADMINER_PORT:-8090}` (optional, `tools` profile).
- One shared network `onward` so future services resolve each other by name.
- **Acceptance:** `docker compose --profile core up -d` yields a healthy Postgres;
  `--profile quality` adds a reachable SonarQube at `http://localhost:9000`.

#### 1.2 `postgres/init/01-init-databases.sql`
Idempotent first-boot SQL executed by the Postgres entrypoint:

```sql
CREATE USER ff_user WITH PASSWORD 'ff_password';
CREATE DATABASE feature_flag_db OWNER ff_user;
CREATE USER sonar WITH PASSWORD 'sonar_password';
CREATE DATABASE sonar OWNER sonar;
```

Keeps `feature_flag`'s existing credentials so `application.properties` works unchanged.
- **Acceptance:** `psql -U ff_user -d feature_flag_db -c 'select 1'` succeeds; app boots and Liquibase applies the changelog.

#### 1.3 `.env.example`
Every tunable in one documented file (ports, image tags, credentials). Copied to `.env`
by `make init`. Never commit `.env`.
- Include a warning that these credentials are **local-only** defaults.

#### 1.4 `Makefile` (single developer entrypoint)
```
make init      # copy .env.example → .env, run doctor
make up        # core profile up + wait until healthy
make up-all    # core + quality + tools
make down      # stop (keep volumes)
make nuke      # stop + delete volumes (fresh start; asks for confirmation)
make logs      # tail all service logs
make db        # psql shell into feature_flag_db
make run       # cd ../feature_flag && ./mvnw spring-boot:run
make sonar     # local sonar analysis of ../feature_flag (see 2.2)
make seed      # seed demo data via Admin API
make smoke     # newman smoke test against localhost:8081
make doctor    # environment preflight
```
- Assumes sibling checkout at `../feature_flag`; path overridable via `FF_DIR`.
- **Acceptance:** a new developer goes from clone to running app with `make init && make up && make run`.

#### 1.5 `scripts/doctor.sh`
Preflight check that fails fast with actionable messages:
- Docker daemon running, Compose v2 available.
- Java 21 present (`java -version`), warns if `JAVA_HOME` mismatched.
- Ports `5432`, `8081`, `9000`, `8090` free (or matching our own containers).
- For SonarQube on Linux: `vm.max_map_count >= 262144` (macOS/Docker Desktop: skip).
- ≥ 4 GB memory allocated to Docker when the `quality` profile is requested.

#### 1.6 `scripts/wait-for.sh`
Small helper polling a TCP port / HTTP health URL (optionally requiring a body
match, e.g. SonarQube's status = `UP`) with timeout. Container-side waits are
handled by compose healthchecks + `up --wait` (so `make up`/`make run` don't
need it); this covers waits compose can't see — host-run processes (the app on
`8081` for `make smoke`) and API-level readiness (`sonarqube/bootstrap.sh`, 2.1).

### Phase 2 — Quality stack (SonarQube local parity)

#### 2.1 `sonarqube/bootstrap.sh`
First-run automation against the SonarQube API:
1. Wait for `http://localhost:9000/api/system/status` = `UP`.
2. Change the default `admin/admin` password to `${SONAR_ADMIN_PASSWORD}`.
3. Create project `feature_flag` (key `aibles:feature_flag`).
4. Generate an analysis token and write it to `.env` (`SONAR_TOKEN=`).
5. Create/assign a quality gate mirroring the team gate (coverage ≥ current ratchet,
   0 new blocker issues) — keep the gate definition in a checked-in JSON so DEV and
   SIT (future `onward-infras`) configure identical gates.
- **Acceptance:** re-runnable without error (idempotent); token lands in `.env`.

#### 2.2 `make sonar` — local analysis command
Runs against the sibling repo:
```bash
cd ../feature_flag && ./mvnw verify sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=$SONAR_TOKEN \
  -Dsonar.projectKey=aibles:feature_flag \
  -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
```
Lets developers see the exact quality-gate verdict **before** pushing, matching what
SIT CI will enforce.
- Note: requires no `pom.xml` change (`sonar-maven-plugin` resolves on the fly), but we
  may later add plugin + properties to `feature_flag/pom.xml` for version pinning.

### Phase 3 — Developer convenience

#### 3.1 `adminer` service (`tools` profile)
Web DB browser at `http://localhost:8090` — inspect Liquibase-managed tables without a
local psql client. (Adminer over pgAdmin: single container, zero config.)

#### 3.2 `scripts/seed-feature-flag.sh`
Seeds a working dataset through the **Admin API** (not raw SQL, so it always respects
the current schema): register a user, create org → project → environments (dev/sit/prod)
→ a couple of flags, then print the SDK API key. Gives everyone the same demo state and
makes the Postman collection instantly usable.

#### 3.3 `scripts/smoke-test.sh` (newman)
Runs `feature_flag/docs/postman/Feature_Flag_Platform.postman_collection.json` against
`http://localhost:8081` via `newman` (Node) or the dockerized `postman/newman` image.
One command answers "is my local environment actually working end-to-end?".

#### 3.4 `docs/RUNBOOK.md`
Day-1 guide: prerequisites, `make init && make up && make run`, URLs table, common
failures (port conflict, stale volume after schema change → `make nuke`), how to run
Sonar locally.

#### 3.5 CI for this repo (`.github/workflows/validate.yml`)
Cheap guardrail: `docker compose config -q`, `shellcheck scripts/*.sh`, and a job that
boots the `core` profile and asserts Postgres becomes healthy.

### Phase 4 — Optional / future

| Tool | Trigger to add it |
|---|---|
| **Prometheus + Grafana** (`observability` profile) | once `feature_flag` adds `spring-boot-starter-actuator` + Micrometer; not before |
| **MailHog / mailpit** | if email verification / notifications land |
| **Redis** | if flag-evaluation caching is introduced |
| **LocalStack / MinIO** | if object storage is introduced |
| **mkcert + reverse proxy (Traefik/Caddy)** | if local HTTPS or multi-service routing is needed |
| **devcontainer.json** | if the team wants VS Code / Codespaces one-click envs |

---

## 4. Port allocation (workspace convention)

| Port | Service | Profile |
|---|---|---|
| 5432 | PostgreSQL (shared) | core |
| 8081 | feature_flag app (runs on host, not in compose) | — |
| 9000 | SonarQube | quality |
| 8090 | Adminer | tools |
| 3000 / 9090 | Grafana / Prometheus (reserved) | observability (future) |

New services in the workspace must claim ports here first to avoid collisions.

**Deliberate choice:** the app itself runs on the host via `./mvnw spring-boot:run`
(fast feedback, debugger, hot reload), while stateful dependencies run in Docker. The
existing `feature_flag/Dockerfile` remains for CI/image builds, not for the local loop.

---

## 5. Changes required in `feature_flag` (companion PR)

1. **Remove** (or reduce to a pointer) `feature_flag/docker-compose.yml` — dev-box becomes
   the single source of infra truth. Alternative: keep it as a minimal fallback with a
   README note; decide in review.
2. Update `feature_flag/CLAUDE.md` + README quick-start: "clone `onward-dev-box` next to
   this repo, run `make up`".
3. (Phase 2) Optionally pin `sonar-maven-plugin` and `sonar.*` properties in `pom.xml`.
4. No code or config changes needed otherwise — DB URL/credentials already match.

---

## 6. Definition of done (Phase 1 + 2)

- [x] `make init && make up && make run` boots the app from a clean machine (with Docker + JDK 21) with zero manual steps. (verified issue #9)
- [x] `make nuke && make up` recreates a pristine database; Liquibase re-applies cleanly. (verified issue #9)
- [ ] `make up-all` brings SonarQube to `UP`; `make sonar` publishes an analysis and prints the quality-gate result. (Phase 2)
- [ ] `make smoke` passes the Postman collection against a seeded local instance. (Phase 2)
- [x] `doctor.sh` catches the three most common failures: Docker down, port 5432 taken, wrong Java version. (verified issue #9)
- [x] No secrets committed; all credentials are documented local-only defaults in `.env.example`. (verified issue #9)
