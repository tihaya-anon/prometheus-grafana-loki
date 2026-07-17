.PHONY: pull up down down-v restart ps logs test validate smoke

pull:
	docker compose pull

up:
	docker compose up -d

down:
	docker compose down

down-v:
	docker compose down -v

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
