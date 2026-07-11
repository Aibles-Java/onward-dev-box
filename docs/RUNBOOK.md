# RUNBOOK — day-1 developer guide

Get from a fresh clone to a running `feature_flag` app against local infra. If you
have never seen this repo, follow it top to bottom.

The model: **stateful dependencies run in Docker** (Postgres, SonarQube, Adminer);
the **app runs on the host** via `./mvnw spring-boot:run` (debugger, hot reload). The
Makefile is the only interface — nothing here needs raw `docker` commands.

---

## 1. Prerequisites

| Need | Why | Install |
|---|---|---|
| **Docker Desktop / Engine** + Compose v2 | runs Postgres/SonarQube/Adminer | https://docs.docker.com/get-docker/ |
| **JDK 21** (Temurin) | the `feature_flag` app runs on the host and needs Java 21 | `brew install --cask temurin@21` (macOS) or `sdk install java 21-tem` (SDKMAN) |
| **`../feature_flag` checkout** | this repo runs the app but does not contain it | see §2 |
| Docker memory ≥ 4 GB | only if you use the `quality` profile (SonarQube) | Docker Desktop → Settings → Resources |

`make doctor` verifies all of this before anything boots — run it any time (`make init`
runs it for you).

---

## 2. Sibling checkout layout

The app lives in a **sibling** repo next to this one:

```
01_Projects/Project_java/
├── onward-dev-box/     ← you are here (infra)
└── feature_flag/       ← the consumer app (clone this)
```

```bash
git clone https://github.com/Aibles-Java/feature_flag.git ../feature_flag
```

Point elsewhere with `FF_DIR=/path/to/feature_flag make run` if your layout differs.

---

## 3. Quick start

```bash
make init      # copy .env.example → .env, then run the doctor preflight
make run       # start Postgres (waits until healthy) + run the app on the host
```

`make run` boots the `core` profile and blocks on `./mvnw spring-boot:run`, so leave it
in its own terminal. The app is up when Spring logs `Started ... on port 8081`.

That is the whole daily loop. `make up` (Postgres only, no app) exists if you want the
DB up without the app.

---

## 4. URLs & ports

| URL | Service | Profile | Up via |
|---|---|---|---|
| `localhost:5432` | PostgreSQL (shared) | core | `make up` / `make run` |
| `http://localhost:8081` | feature_flag app (host, not Docker) | — | `make run` |
| `http://localhost:9000` | SonarQube web UI | quality | `make up-all` |
| `http://localhost:8090` | Adminer (DB web UI) | tools | `make up-all` |

Ports are the workspace registry (`docs/INFRASTRUCTURE.md` §4). `5432` / `8081` are the
cross-repo contract with `feature_flag` — do not change them here alone.

---

## 5. Everyday commands

```bash
make help      # list every target
make up        # start core (postgres) and wait until healthy
make up-all    # core + quality (sonarqube) + tools (adminer)
make run       # up core + run the app on the host (this is the daily driver)
make db        # psql shell into feature_flag_db (contract credentials)
make logs      # tail all running service logs
make down      # stop services, keep volumes (data survives)
make nuke      # stop + DELETE volumes — fresh DB state (asks first)
make doctor    # re-run the environment preflight
```

---

## 6. Running SonarQube locally

One-time setup, then analysis is a single command:

```bash
make up-all                    # brings SonarQube up on :9000 (needs ≥ 4 GB Docker mem)
./sonarqube/bootstrap.sh       # first-run: sets admin password, creates the project,
                               # quality gate, and writes SONAR_TOKEN into your .env
make sonar                     # analyze ../feature_flag and print the gate verdict
```

`make sonar` prints `QUALITY GATE STATUS: PASSED/FAILED` and exits non-zero on a failed
gate. SonarQube Community analyzes one branch per project — there is no local PR
analysis.

---

## 7. Running the end-to-end smoke test

`make smoke` runs `feature_flag`'s own Postman collection (72 chained requests) against
the running app:

```bash
make nuke      # the collection needs a FRESH DB (it registers fixed demo users)
make run       # (other terminal) fresh app on a clean DB
make smoke     # runs the collection via newman
```

> **Known red today.** `make smoke` currently reports failures that trace to two
> `feature_flag`-owned defects (filed as `Aibles-Java/feature_flag#52`), not to this
> repo. The script itself is correct; it will go green once those are fixed.

---

## 8. Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `make run` fails, port 8081 in use | an old app instance is still running | `lsof -ti tcp:8081 \| xargs kill` then re-run |
| App starts but auth/data is stale, or `make smoke` gets 409 on register | dirty DB from a previous run | `make nuke` (deletes volumes) then `make run` |
| Schema change in `feature_flag` not picked up | `postgres/init/*.sql` runs **only on first boot** (empty volume) | `make nuke` to re-init from scratch |
| SonarQube container exits / never healthy | Docker memory < 4 GB, or Linux `vm.max_map_count` too low | raise Docker memory to ≥ 4 GB; Linux: `sudo sysctl -w vm.max_map_count=262144` |
| `make run` says no `mvnw` at `../feature_flag` | sibling checkout missing or wrong path | clone it (§2) or pass `FF_DIR=/path make run` |
| Maven picks the wrong JDK | `JAVA_HOME` differs from PATH java | macOS: `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` |

When in doubt, `make doctor` prints a `fix:` line for each failed check.

---

## 9. Credentials

The DB/user/password in `.env` and compose defaults are **intentionally weak,
local-only** values. Never reuse them outside localhost, and never commit your `.env`
(it is gitignored). SIT/PROD configuration lives in a separate repo.
