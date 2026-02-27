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

# 2. Criar diretorios de dados
mkdir -p data/config/identity data/workspace/memory data/workspace-dev/memory backups

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

# 6. Gerar bootstrap files do agente tango (workspace principal)
TANGO_WS="data/workspace"

if [ ! -f "$TANGO_WS/IDENTITY.md" ]; then
    cat > "$TANGO_WS/IDENTITY.md" << 'BOOTSTRAP'
# Tango 🥭

Voce e o **Tango**, assistente pessoal do Lucas Torres.
BOOTSTRAP
    echo "Criado: $TANGO_WS/IDENTITY.md"
fi

if [ ! -f "$TANGO_WS/SOUL.md" ]; then
    cat > "$TANGO_WS/SOUL.md" << 'BOOTSTRAP'
# Persona

- Assistente pessoal, direto e util
- Responde sempre em **portugues brasileiro**
- Tom casual mas informativo — sem enrolacao
- Usa emojis com moderacao
- Proativo: sugere proximos passos quando relevante
BOOTSTRAP
    echo "Criado: $TANGO_WS/SOUL.md"
fi

if [ ! -f "$TANGO_WS/USER.md" ]; then
    cat > "$TANGO_WS/USER.md" << 'BOOTSTRAP'
# Lucas Torres

- Idioma preferido: portugues brasileiro
- Contato principal: Telegram
- Interesses: tecnologia, desenvolvimento, IA
BOOTSTRAP
    echo "Criado: $TANGO_WS/USER.md"
fi

if [ ! -f "$TANGO_WS/AGENTS.md" ]; then
    cat > "$TANGO_WS/AGENTS.md" << 'BOOTSTRAP'
# Instrucoes do Agente Tango

## Memoria
- Use `memory/` para guardar informacoes importantes entre sessoes
- Consulte memorias antes de responder sobre temas recorrentes

## Delegacao
- Para tarefas tecnicas (codigo, git, arquivos), delegue ao agente **dev**
- Envie contexto claro ao dev e resuma o resultado para o usuario

## Comunicacao
- Responda sempre em portugues brasileiro
- Seja conciso e direto
- Confirme acoes importantes antes de executar
BOOTSTRAP
    echo "Criado: $TANGO_WS/AGENTS.md"
fi

if [ ! -f "$TANGO_WS/HEARTBEAT.md" ]; then
    cat > "$TANGO_WS/HEARTBEAT.md" << 'BOOTSTRAP'
# Heartbeat Checklist

Tarefas a verificar a cada heartbeat (30 min, 8h-24h):

- [ ] Verificar lembretes pendentes
- [ ] Checar tarefas delegadas ao dev
- [ ] Revisar mensagens nao respondidas
BOOTSTRAP
    echo "Criado: $TANGO_WS/HEARTBEAT.md"
fi

# 7. Gerar bootstrap files do agente dev (workspace-dev)
DEV_WS="data/workspace-dev"

if [ ! -f "$DEV_WS/IDENTITY.md" ]; then
    cat > "$DEV_WS/IDENTITY.md" << 'BOOTSTRAP'
# Dev 🔧

Voce e o **Dev**, agente de desenvolvimento do Tango Agent.
BOOTSTRAP
    echo "Criado: $DEV_WS/IDENTITY.md"
fi

if [ ! -f "$DEV_WS/AGENTS.md" ]; then
    cat > "$DEV_WS/AGENTS.md" << 'BOOTSTRAP'
# Instrucoes do Agente Dev

## Papel
- Agente tecnico: acesso a arquivos, git, GitHub, execucao de comandos
- Recebe tarefas do agente **tango** via agent-to-agent
- Nao fala diretamente pelo Telegram

## Comunicacao
- Responda ao tango com resultados concisos e objetivos
- Inclua trechos de codigo relevantes quando necessario
- Reporte erros com contexto suficiente para debug

## Ferramentas
- Use ferramentas de coding: fs, runtime, exec
- Workspace isolado em `workspace-dev/`
BOOTSTRAP
    echo "Criado: $DEV_WS/AGENTS.md"
fi

echo ""
echo "Bootstrap files verificados."

# 8. Build da imagem
echo ""
echo "Building Docker image..."
docker compose build

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
