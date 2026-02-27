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

# Build (se falhar, nao derruba o gateway atual)
echo "Building..."
docker compose build

# Restart com minimo downtime
echo "Restarting gateway..."
docker compose up -d tango-gateway

echo ""
echo "=== Deploy completo! ==="
docker compose ps
