#!/usr/bin/env bash
set -euo pipefail

echo "=== Tango Agent - Setup ==="

# Funcao sed compativel com macOS e Linux
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# 1. Inicializar submodule se necessario
if [ ! -f tango-openclaw/package.json ]; then
    echo "Inicializando submodule..."
    git submodule update --init --recursive
fi

# 1b. Carregar .env se existir (para PROJECTS_DIR customizado)
if [ -f .env ]; then
    set -a; source .env; set +a
fi

# 2. Criar diretorios de dados
AGENTS="tango atlas pixel hawk sentinel"
for agent in $AGENTS; do
    ws="data/workspace"
    [ "$agent" != "tango" ] && ws="data/workspace-${agent}"
    mkdir -p "$ws/memory"
done
mkdir -p data/config/identity backups

# 2b. Criar diretorio de projetos
PROJ_DIR="${PROJECTS_DIR:-./projects}"
mkdir -p "$PROJ_DIR"

# 3. Corrigir permissoes (uid 1000 = user 'node' no container)
if command -v chown &>/dev/null; then
    if [ "$(id -u)" -eq 0 ]; then
        chown -R 1000:1000 data/ "$PROJ_DIR"
        echo "Permissoes corrigidas (uid 1000)."
    else
        echo "AVISO: Rode como root no servidor para corrigir permissoes:"
        echo "  sudo chown -R 1000:1000 data/ $PROJ_DIR"
    fi
fi

# 4. Gerar .env se nao existir
if [ ! -f .env ]; then
    cp .env.example .env
    TOKEN=$(openssl rand -hex 32)
    sed_inplace "s/CHANGE_ME/$TOKEN/" .env
    chmod 600 .env
    echo ""
    echo "Arquivo .env criado (permissoes 600, token auto-gerado)."
    echo ""
else
    echo ".env ja existe, pulando."
    # Garantir permissoes mesmo se ja existia
    chmod 600 .env
fi

# 5. Gerar openclaw.json se nao existir
if [ ! -f data/config/openclaw.json ]; then
    cp config/openclaw.example.json data/config/openclaw.json

    # Se TELEGRAM_USER_ID estiver no .env, injetar no config
    set -a
    source .env
    set +a

    if [ -n "${TELEGRAM_USER_ID:-}" ]; then
        sed_inplace "s/SEU_TELEGRAM_USER_ID/$TELEGRAM_USER_ID/" data/config/openclaw.json
        echo "openclaw.json criado com Telegram User ID: $TELEGRAM_USER_ID"
    else
        echo "openclaw.json criado."
        echo ""
        echo "IMPORTANTE: Configure seu Telegram User ID:"
        echo "  1. Fale com @userinfobot no Telegram para descobrir seu ID"
        echo "  2. Edite TELEGRAM_USER_ID no .env"
        echo "  3. Rode: make setup (para atualizar o config)"
        echo "  Ou edite diretamente: data/config/openclaw.json"
        echo ""
    fi

    chmod 600 data/config/openclaw.json
else
    echo "openclaw.json ja existe, pulando."

    # Atualizar Telegram User ID se estava faltando e agora esta no .env
    set -a
    source .env
    set +a

    if [ -n "${TELEGRAM_USER_ID:-}" ] && grep -q "SEU_TELEGRAM_USER_ID" data/config/openclaw.json 2>/dev/null; then
        sed_inplace "s/SEU_TELEGRAM_USER_ID/$TELEGRAM_USER_ID/" data/config/openclaw.json
        echo "Telegram User ID atualizado no openclaw.json: $TELEGRAM_USER_ID"
    fi
fi

# 6. Copiar bootstrap templates para workspaces (so cria se nao existir)
echo ""
echo "Verificando bootstrap files..."

for agent in $AGENTS; do
    ws="data/workspace"
    [ "$agent" != "tango" ] && ws="data/workspace-${agent}"

    if [ -d "config/bootstrap/$agent" ]; then
        for file in config/bootstrap/"$agent"/*.md; do
            [ ! -f "$file" ] && continue
            target="$ws/$(basename "$file")"
            if [ ! -f "$target" ]; then
                cp "$file" "$target"
                echo "Criado: $target"
            fi
        done
    fi
done

echo "Bootstrap files verificados."

# 7. Build da imagem
echo ""
echo "Building base OpenClaw image..."
docker build -t tango-openclaw-base:latest \
    --build-arg OPENCLAW_DOCKER_APT_PACKAGES="git openssh-client jq ripgrep" \
    ./tango-openclaw
echo "Building Tango image (with gog)..."
docker compose build tango-gateway

echo ""
echo "=== Setup completo! ==="
echo ""
echo "Proximos passos:"
if grep -q "sk-ant-\.\.\." .env 2>/dev/null; then
    echo "  1. Edite .env com suas API keys (ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN)"
fi
if grep -q "SEU_TELEGRAM_USER_ID" data/config/openclaw.json 2>/dev/null; then
    echo "  2. Descubra seu Telegram User ID (@userinfobot) e coloque no .env"
    echo "     Depois rode: make setup"
fi
echo "  - make up     (subir gateway)"
echo "  - make logs   (acompanhar logs)"
