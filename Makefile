# onward-dev-box — single developer entrypoint (docs/INFRASTRUCTURE.md §3, item 1.4).
# Nothing in the daily loop should require raw docker commands.
#
# App-facing targets (run, sonar, seed, smoke) land with their own issues so this
# file carries no dead targets. `make init` runs the doctor preflight once
# scripts/doctor.sh exists (issue 1.5); until then it skips with a notice.

COMPOSE ?= docker compose
# Every service is profile-gated, so lifecycle commands must enable profiles
# explicitly — a bare `docker compose down` would match no services.
CORE     = --profile core
ALL      = --profile core --profile quality --profile tools

.DEFAULT_GOAL := help

.PHONY: help init up up-all down nuke logs db

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
