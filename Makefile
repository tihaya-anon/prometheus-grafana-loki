.PHONY: pull up down restart ps logs validate smoke

pull:
	docker compose pull

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=200

validate:
	./scripts/validate.sh

smoke:
	./scripts/smoke-test.sh
