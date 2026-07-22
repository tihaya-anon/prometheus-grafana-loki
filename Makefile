COMPOSE_PROJECT_NAME ?= pgl
export COMPOSE_PROJECT_NAME
OBSERVABILITY_NETWORK ?= observability
OTEL_DATA_SERVICES := prometheus loki tempo
OTEL_DATA_VOLUMES := $(COMPOSE_PROJECT_NAME)_prometheus-data $(COMPOSE_PROJECT_NAME)_loki-data $(COMPOSE_PROJECT_NAME)_tempo-data

.PHONY: pull up down down-v clear-otel-data ensure-network restart ps logs test validate smoke

pull:
	docker compose pull

up: ensure-network
	docker compose up -d

down:
	docker compose down

down-v:
	docker compose down -v

clear-otel-data: ensure-network
	docker compose rm --stop --force $(OTEL_DATA_SERVICES)
	@for volume in $(OTEL_DATA_VOLUMES); do \
		if docker volume inspect "$$volume" >/dev/null 2>&1; then \
			docker volume rm "$$volume"; \
		else \
			echo "Volume $$volume does not exist"; \
		fi; \
	done
	docker compose up -d $(OTEL_DATA_SERVICES)

ensure-network:
	@docker network inspect "$(OBSERVABILITY_NETWORK)" >/dev/null 2>&1 || docker network create "$(OBSERVABILITY_NETWORK)"

restart:
	docker compose restart

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=200

test:
	./scripts/github/test.sh

validate: ensure-network
	./scripts/validate.sh

smoke:
	./scripts/smoke-test.sh
