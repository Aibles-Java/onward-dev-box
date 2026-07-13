# onward-dev-box — single developer entrypoint (docs/INFRASTRUCTURE.md §3, item 1.4).
# Nothing in the daily loop should require raw docker commands.
#
# App-facing targets (seed, smoke) land with their own issues so this file
# carries no dead targets.

COMPOSE ?= docker compose
# Sibling checkout of the consumer app; the app runs on the host (debugger,
# hot reload), only its stateful dependencies run in compose.
FF_DIR  ?= ../feature_flag
# Every service is profile-gated, so lifecycle commands must enable profiles
# explicitly — a bare `docker compose down` would match no services.
CORE     = --profile core
ALL      = --profile core --profile quality --profile tools

.DEFAULT_GOAL := help

.PHONY: help init up up-all down nuke logs db run smoke doctor sonar

help: ## List available targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

init: ## Copy .env.example → .env (if missing) and run the doctor preflight
	@if [ -f .env ]; then \
		echo ".env already exists — leaving it untouched"; \
	else \
		cp .env.example .env && echo "created .env from .env.example (local-only defaults)"; \
	fi
	@if [ -x scripts/doctor.sh ]; then \
		scripts/doctor.sh; \
	else \
		echo "doctor: scripts/doctor.sh not present yet (issue 1.5) — skipping preflight"; \
	fi

doctor: ## Environment preflight (PROFILE=quality adds the sonarqube host checks)
	@scripts/doctor.sh $(PROFILE)

up: ## Start the core profile (postgres) and wait until healthy
	$(COMPOSE) $(CORE) up -d --wait

up-all: ## Start core + quality (sonarqube) + tools (adminer), wait until healthy
	$(COMPOSE) $(ALL) up -d --wait

down: ## Stop all services (volumes are kept)
	$(COMPOSE) $(ALL) down

nuke: ## Stop everything and DELETE volumes (fresh state; asks first)
	@printf 'This deletes ALL volumes (postgres data, sonarqube state). Continue? [y/N] '; \
	read -r answer; \
	case "$$answer" in \
		[yY]) ;; \
		*) echo "aborted — nothing touched"; exit 1 ;; \
	esac
	$(COMPOSE) $(ALL) down -v

logs: ## Tail logs of all running services
	$(COMPOSE) $(ALL) logs -f

db: ## psql shell into feature_flag_db (cross-repo contract credentials)
	$(COMPOSE) $(CORE) exec postgres psql -U ff_user -d feature_flag_db

run: ## Run feature_flag on the host (foreground — blocks this terminal; run `make smoke` in a second one)
	@if [ ! -x "$(FF_DIR)/mvnw" ]; then \
		echo "error: no feature_flag checkout at '$(FF_DIR)' (expected an executable mvnw there)"; \
		echo "  clone it as a sibling:  git clone https://github.com/Aibles-Java/feature_flag.git $(FF_DIR)"; \
		echo "  or point at an existing checkout:  make run FF_DIR=/path/to/feature_flag"; \
		exit 1; \
	fi
	$(COMPOSE) $(CORE) up -d --wait
	cd "$(FF_DIR)" && ./mvnw spring-boot:run

# `make run` foregrounds the app and holds its terminal, so smoke needs a second one:
#   terminal 1:  make run      # boots the DB + app, then blocks
#   terminal 2:  make smoke    # runs the collection against the running app
smoke: ## Run feature_flag's Postman collection via newman (needs `make run` live in another terminal)
	@scripts/smoke-test.sh

sonar: ## Run local SonarQube analysis of feature_flag and print the quality-gate verdict
	@if [ ! -x "$(FF_DIR)/mvnw" ]; then \
		echo "error: no feature_flag checkout at '$(FF_DIR)' (expected an executable mvnw there)"; \
		echo "  clone it as a sibling:  git clone https://github.com/Aibles-Java/feature_flag.git $(FF_DIR)"; \
		echo "  or point at an existing checkout:  make sonar FF_DIR=/path/to/feature_flag"; \
		exit 1; \
	fi
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	if [ -z "$${SONAR_TOKEN:-}" ]; then \
		echo "error: SONAR_TOKEN is not set (sonarqube/bootstrap.sh has not been run yet)"; \
		echo "  run:  make up-all && ./sonarqube/bootstrap.sh"; \
		exit 1; \
	fi; \
	cd "$(FF_DIR)" && ./mvnw verify sonar:sonar \
		-Dsonar.host.url=http://localhost:$${SONAR_PORT:-9000} \
		-Dsonar.token="$$SONAR_TOKEN" \
		-Dsonar.projectKey=aibles:feature_flag \
		-Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
		-Dsonar.qualitygate.wait=true
