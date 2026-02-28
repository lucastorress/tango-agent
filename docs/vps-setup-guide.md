# Guia de Setup VPS — Tango Agent

> Documentacao de tudo que foi instalado manualmente na VPS e cenarios resolvidos.
> Atualizado em: 2026-02-28

---

## 1. Infraestrutura Base

### VPS
- **Provider**: Hetzner (CPX21 — 3 cores, 4GB RAM, 80GB SSD)
- **OS**: Ubuntu 24.04
- **IP**: configuravel
- **User**: `deploy` (criado por `scripts/harden-vps.sh`)

### Node.js + pnpm
```bash
# Node 22 via NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# pnpm
npm install -g pnpm
```

### OpenClaw Gateway (systemd)
```bash
cd ~/tango-agent
make setup    # Gera .env, openclaw.json, chmod 600, build
make deploy   # Valida, build, restart, health check
```

Service: `scripts/tango-gateway.service` → `/etc/systemd/system/tango-gateway.service`

---

## 2. Ferramentas Instaladas Manualmente

### Claude Code CLI
```bash
sudo npm install -g @anthropic-ai/claude-code

# Auth (interativo — requer browser)
claude auth login
# Gera URL → abrir no browser → colar codigo no terminal
```
- Autenticado como: `lucast0rr3s@gmail.com` (subscription Max Pro)
- Usado pelos agentes coding via `claude -p "prompt"`
- Custo: zero (usa subscription, nao API key)

### gog (Google Workspace CLI)
```bash
# Download e instalacao
wget https://github.com/steipete/gogcli/releases/download/v0.11.0/gog_linux_amd64.tar.gz
tar xzf gog_linux_amd64.tar.gz
sudo mv gog /usr/local/bin/
```

#### Auth do gog (requer browser)
```bash
# 1. Copiar credentials do Google Cloud Console
cp client_secret_*.json ~/.config/gogcli/credentials.json
gog auth credentials ~/.config/gogcli/credentials.json

# 2. Configurar keyring como file (headless)
GOG_KEYRING_PASSWORD=<senha> gog auth keyring file

# 3. Iniciar auth (roda em background)
GOG_KEYRING_PASSWORD=<senha> nohup gog auth add <email> > /tmp/gog-auth.log 2>&1 &

# 4. Pegar a URL do log
cat /tmp/gog-auth.log

# 5. Abrir URL no browser, autorizar no Google
# 6. Browser redireciona para localhost:<porta> — vai dar erro

# 7. Copiar URL de erro e fazer curl direto no VPS
curl -s "http://127.0.0.1:<porta>/oauth2/callback?state=...&code=..."

# 8. Verificar
GOG_KEYRING_PASSWORD=<senha> gog auth list
```

**Gotcha**: O `nohup` nao herda env vars. Sempre passar `GOG_KEYRING_PASSWORD=<senha>` explicitamente.

**Gotcha**: `gog drive share` NAO existe. Docs criados ja sao acessiveis pela conta.

### Playwright (browser automation)
```bash
# Instalar venv
sudo apt-get install -y python3.12-venv

# Criar ambiente
python3 -m venv ~/playwright-env
source ~/playwright-env/bin/activate

# Instalar Playwright + Chromium
pip install playwright
playwright install chromium
playwright install-deps chromium
```

Usado via script `scripts/web-scraper.py`:
```bash
source ~/playwright-env/bin/activate
python3 scripts/web-scraper.py login <url> <email> <senha>
python3 scripts/web-scraper.py fetch <url>
python3 scripts/web-scraper.py list-links <url>
python3 scripts/web-scraper.py screenshot <url> <output.png>
```

### GitHub CLI (`gh`)
```bash
# Ja vem no Ubuntu 24.04 ou:
sudo apt-get install -y gh

# Auth
gh auth login --with-token <<< "$GIT_TOKEN"
gh auth setup-git  # Configura credential helper
```

---

## 3. Configuracao Multi-Provider (OpenRouter)

### .env
```bash
ANTHROPIC_API_KEY=sk-ant-...     # Claude (Haiku para Tango)
OPENROUTER_API_KEY=sk-or-v1-...  # MiniMax, Kimi, Gemini (outros agentes)
GROQ_API_KEY=gsk_...             # Whisper (transcricao de audio gratis)
```

### Modelos por agente
| Agente | Primary | Via | Fallbacks |
|--------|---------|-----|-----------|
| tango | Haiku | Anthropic direto | Kimi → Gemini Flash |
| atlas | Kimi K2.5 | OpenRouter | Gemini Flash → Haiku |
| pixel/hawk/sentinel | MiniMax M2.5 | OpenRouter | Kimi → Gemini Flash → Sonnet |
| heartbeat | Gemini Flash Lite | OpenRouter | — |
| subagents | Gemini Flash | OpenRouter | — |

### Otimizacoes aplicadas
- `contextTokens`: 32k (reduzido de 100k)
- `compaction.mode`: `safeguard` (auto-resume sessoes longas)
- `maxChildrenPerAgent`: 3
- `archiveAfterMinutes`: 30
- `timeoutSeconds`: 90
- Fallback chains: 3-4 modelos por agente (anti-travamento)

---

## 4. Problemas Resolvidos e Gotchas

### OpenClaw Config
- `agentToAgent` NAO e uma tool — e uma secao de config. Colocar no `alsoAllow` gera warning.
- `sessions_send` e a tool real de delegacao (ja inclusa no perfil messaging).
- `deny` e `exec.security` sao redundantes para perfil `messaging`.
- `allowAgents` vai no config do agente, NAO em `agents.defaults.subagents`.
- Subagentes herdam perfil do pai — subagente de Tango (messaging) NAO tem exec.
- Skills CLI (gog, gh) precisam de `exec` — atribuir apenas a perfil `coding`.
- `compaction.enabled` nao existe mais no schema.
- `Kimi K2.5 reasoning: true` causa bug no OpenClaw — manter false.
- `DeepSeek direto` nao funciona com OpenClaw — usar via OpenRouter.
- `contextPruning cache-ttl` so funciona com modelos Anthropic.

### Rate Limits
- Sessoes acumuladas causam rate limit em cascata.
- Limpar sessoes: `rm -f ~/.openclaw/agents/*/sessions/*.jsonl ~/.openclaw/agents/*/sessions/sessions.json`
- Fallback chains previnem travamento: se MiniMax trava, cai pra Kimi, depois Gemini, depois Sonnet.

### OAuth em VPS headless
- Claude CLI: `claude auth login` usa TUI interativa — nao funciona com pipe/expect. Fazer via SSH interativo.
- gog: usar `nohup` + curl do callback (sem SSH tunnel necessario).
- Google OAuth app em modo teste: adicionar email como test user no Cloud Console.

---

## 5. Checklist de Setup para Nova VPS

1. [ ] `scripts/harden-vps.sh` — SSH key-only, UFW, fail2ban
2. [ ] Node 22 + pnpm
3. [ ] `git clone --recurse-submodules` do tango-agent
4. [ ] `make setup` — gera .env, openclaw.json
5. [ ] Editar `.env` com API keys
6. [ ] `make deploy` — build + start + health check
7. [ ] `sudo npm install -g @anthropic-ai/claude-code`
8. [ ] `claude auth login` (interativo via SSH)
9. [ ] gog: copiar credentials.json + `gog auth add` (ver secao 2)
10. [ ] Playwright: venv + install (ver secao 2)
11. [ ] `gh auth login` com GIT_TOKEN
12. [ ] Verificar: `make health`, `make logs`, `gog auth list`, `claude auth status`
