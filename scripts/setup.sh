#!/usr/bin/env bash
set -euo pipefail

echo "=== Tango Agent - Setup ==="

# 1. Inicializar submodule se necessario
if [ ! -f tango-openclaw/package.json ]; then
    echo "Inicializando submodule..."
    git submodule update --init --recursive
fi

# 2. Criar diretorios de dados
mkdir -p data/config/identity data/workspace

# 3. Corrigir permissoes (uid 1000 = user 'node' no container)
if command -v chown &>/dev/null; then
    if [ "$(id -u)" -eq 0 ]; then
        chown -R 1000:1000 data/
        echo "Permissoes corrigidas (uid 1000)."
    else
        echo "AVISO: Rode como root no servidor para corrigir permissoes:"
        echo "  sudo chown -R 1000:1000 data/"
    fi
fi

# 4. Gerar .env se nao existir
if [ ! -f .env ]; then
    cp .env.example .env
    TOKEN=$(openssl rand -hex 32)
    # Compativel com macOS e Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/CHANGE_ME/$TOKEN/" .env
    else
        sed -i "s/CHANGE_ME/$TOKEN/" .env
    fi
    echo ""
    echo "Arquivo .env criado com token gerado automaticamente."
    echo "IMPORTANTE: Edite .env e preencha suas API keys:"
    echo "  - ANTHROPIC_API_KEY"
    echo "  - TELEGRAM_BOT_TOKEN"
    echo ""
else
    echo ".env ja existe, pulando."
fi

# 5. Build da imagem
echo "Building Docker image..."
docker compose build

echo ""
echo "=== Setup completo! ==="
echo "Proximos passos:"
echo "  1. Edite .env com suas API keys"
echo "  2. make up"
echo "  3. make logs"
