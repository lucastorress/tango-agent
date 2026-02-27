.PHONY: build up down logs status cli setup deploy update health

build:
	docker compose build

up:
	docker compose up -d tango-gateway

down:
	docker compose down

logs:
	docker compose logs -f tango-gateway

status:
	docker compose exec tango-gateway node dist/index.js channels status --probe

health:
	docker compose exec tango-gateway node dist/index.js gateway health

cli:
	docker compose --profile cli run --rm tango-cli $(CMD)

setup:
	bash scripts/setup.sh

deploy:
	bash scripts/deploy.sh

update:
	@echo "Atualizando OpenClaw do upstream..."
	cd tango-openclaw && git fetch upstream && git merge upstream/main --no-edit
	@echo "Rebuilding..."
	docker compose build
	docker compose up -d tango-gateway
	@echo "Commitar submodule atualizado:"
	@echo "  git add tango-openclaw && git commit -m 'chore: update openclaw submodule'"
