#!/usr/bin/env bash
set -euo pipefail

echo "=== Tango Agent - Deploy ==="

# Validar .env existe
if [ ! -f .env ]; then
    echo "ERRO: .env nao encontrado. Rode 'make setup' primeiro."
    exit 1
fi

# Validar variaveis obrigatorias
source .env
for var in OPENCLAW_GATEWAY_TOKEN ANTHROPIC_API_KEY TELEGRAM_BOT_TOKEN; do
    if [ -z "${!var:-}" ] || [[ "${!var}" == *"..."* ]] || [[ "${!var}" == "CHANGE_ME" ]]; then
        echo "ERRO: $var nao configurado no .env"
        exit 1
    fi
done

# Validar openclaw.json
if [ ! -f "${OPENCLAW_CONFIG_DIR:-./data/config}/openclaw.json" ]; then
    echo "ERRO: openclaw.json nao encontrado. Rode 'make setup' primeiro."
    exit 1
fi

# Build (se falhar, nao derruba o gateway atual)
echo "Building..."
docker compose build

# Restart com minimo downtime
echo "Restarting gateway..."
docker compose up -d tango-gateway

# Aguardar container ficar healthy
echo "Aguardando gateway ficar healthy..."
for i in $(seq 1 20); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' tango-gateway 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        break
    fi
    sleep 3
done

# Rodar diagnostico
echo ""
echo "Rodando diagnostico..."
docker compose exec -T tango-gateway node dist/index.js doctor 2>&1 | tail -20 || true

echo ""
echo "=== Deploy completo! ==="
docker compose ps
