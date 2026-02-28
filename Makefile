.PHONY: build up down logs status cli setup deploy update health harden security-check backup snapshot doctor restart sync-bootstrap install-service logs-error logs-today mem bot-dev bot-build bot-up bot-down bot-logs bot-restart

# === Build ===
build:
	cd tango-openclaw && NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile && pnpm build

# === Gateway (systemd) ===
up:
	sudo systemctl start tango-gateway

down:
	sudo systemctl stop tango-gateway

restart:
	sudo systemctl restart tango-gateway

logs:
	journalctl -u tango-gateway -f

status:
	systemctl status tango-gateway

health:
	cd tango-openclaw && node dist/index.js gateway health

doctor:
	cd tango-openclaw && node dist/index.js doctor

cli:
	cd tango-openclaw && node dist/index.js $(CMD)

# === Setup/Deploy ===
setup:
	bash scripts/setup.sh

deploy:
	bash scripts/deploy.sh

install-service:
	sudo cp scripts/tango-gateway.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable tango-gateway

update:
	@echo "Atualizando OpenClaw do upstream..."
	cd tango-openclaw && git fetch upstream && git merge upstream/main --no-edit
	@echo "Rebuilding..."
	cd tango-openclaw && NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile && pnpm build
	sudo systemctl restart tango-gateway
	@echo "Commitar submodule atualizado:"
	@echo "  git add tango-openclaw && git commit -m 'chore: update openclaw submodule'"

# === Observabilidade ===
logs-error:
	journalctl -u tango-gateway -p err -f

logs-today:
	journalctl -u tango-gateway --since today

mem:
	systemctl status tango-gateway | grep Memory

# === Seguranca/Backup ===
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
