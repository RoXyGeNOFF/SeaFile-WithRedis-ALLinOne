SHELL := /bin/bash

.DEFAULT_GOAL := up

up:
	@if [ ! -f .env ]; then bash scripts/gen-env.sh; fi
	docker compose up -d
	@echo "\nSeafile должен быть доступен на http://localhost/ (после инициализации)"

down:
	docker compose down

logs:
	docker compose logs -f seafile

reset:
	docker compose down -v || true
	rm -rf data || true
	bash scripts/gen-env.sh -f


update:
	docker compose pull
	docker compose up -d
