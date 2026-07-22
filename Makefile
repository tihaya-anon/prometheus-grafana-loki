COMPOSE_PROJECT_NAME ?= pgl
export COMPOSE_PROJECT_NAME
OTEL_DATA_SERVICES := prometheus loki tempo
OTEL_DATA_VOLUMES := $(COMPOSE_PROJECT_NAME)_prometheus-data $(COMPOSE_PROJECT_NAME)_loki-data $(COMPOSE_PROJECT_NAME)_tempo-data

.PHONY: pull up down down-v clear-otel-data restart ps logs test validate smoke

pull:
	docker compose pull

up:
	docker compose up -d

down:
	docker compose down

down-v:
	docker compose down -v

clear-otel-data:
	docker compose rm --stop --force $(OTEL_DATA_SERVICES)
	@for volume in $(OTEL_DATA_VOLUMES); do \
		if docker volume inspect "$$volume" >/dev/null 2>&1; then \
			docker volume rm "$$volume"; \
		else \
			echo "Volume $$volume does not exist"; \
		fi; \
		docker volume create "$$volume"; \
	done
	docker compose up -d $(OTEL_DATA_SERVICES)

restart:
	docker compose restart

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=200

test:
	./scripts/github/test.sh

validate:
	./scripts/validate.sh

smoke:
	./scripts/smoke-test.sh
