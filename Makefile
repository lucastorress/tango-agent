.PHONY: build up up-proxy down logs status cli setup deploy update health harden security-check backup snapshot doctor restart sync-bootstrap bot-dev bot-build bot-up bot-down bot-logs bot-restart

build:
	@echo "Building base OpenClaw image..."
	docker build -t tango-openclaw-base:latest \
		--build-arg OPENCLAW_DOCKER_APT_PACKAGES="git openssh-client jq ripgrep" \
		./tango-openclaw
	@echo "Building Tango image (with gog)..."
	docker compose build tango-gateway

up:
	docker compose up -d tango-gateway

up-proxy:
	docker compose --profile proxy up -d

down:
	docker compose --profile proxy down

restart:
	docker compose restart tango-gateway

logs:
	docker compose logs -f tango-gateway

status:
	docker compose exec tango-gateway node dist/index.js channels status --probe

health:
	docker compose exec tango-gateway node dist/index.js gateway health

doctor:
	docker compose exec tango-gateway node dist/index.js doctor

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
	docker build -t tango-openclaw-base:latest \
		--build-arg OPENCLAW_DOCKER_APT_PACKAGES="git openssh-client jq ripgrep" \
		./tango-openclaw
	docker compose build tango-gateway
	docker compose up -d tango-gateway
	@echo "Commitar submodule atualizado:"
	@echo "  git add tango-openclaw && git commit -m 'chore: update openclaw submodule'"

harden:
	@echo "Uso: ssh root@VPS_IP 'bash -s' < scripts/harden-vps.sh"

security-check:
	bash scripts/security-check.sh

backup:
	bash scripts/backup.sh

snapshot:
	bash scripts/backup.sh --snapshot

sync-bootstrap:
	@bash scripts/sync-bootstrap.sh

# === Tango Bot (Agent SDK) ===

bot-dev:
	cd bot && npx tsx src/index.ts

bot-build:
	cd bot && pnpm build

bot-up:
	docker compose --profile bot up -d tango-bot

bot-down:
	docker compose stop tango-bot

bot-logs:
	docker compose logs -f tango-bot

bot-restart:
	docker compose restart tango-bot
