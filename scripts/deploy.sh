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

# Validar diretorio de projetos
PROJ_DIR="${PROJECTS_DIR:-./projects}"
if [ ! -d "$PROJ_DIR" ]; then
    echo "Criando diretorio de projetos: $PROJ_DIR"
    mkdir -p "$PROJ_DIR"
fi

# Build (se falhar, nao derruba o gateway atual)
echo "Building OpenClaw..."
cd tango-openclaw
NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile
pnpm build
cd ..

# Reload service (caso o .service tenha mudado)
sudo cp scripts/tango-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload

# Restart
echo "Restarting gateway..."
sudo systemctl restart tango-gateway

# Aguardar healthy
echo "Aguardando gateway ficar healthy..."
for i in $(seq 1 20); do
    if cd tango-openclaw && node dist/index.js gateway health 2>/dev/null; then
        cd ..
        break
    fi
    cd ..
    sleep 3
done

# Rodar diagnostico
echo ""
echo "Rodando diagnostico..."
cd tango-openclaw && node dist/index.js doctor 2>&1 | tail -20 || true
cd ..

echo ""
echo "=== Deploy completo! ==="
systemctl status tango-gateway --no-pager
