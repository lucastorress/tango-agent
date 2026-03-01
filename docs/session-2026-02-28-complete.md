# Sessão Completa — 28 de Fevereiro de 2026

> Documentação de TUDO que foi feito, aprendido e decidido nesta sessão.

---

## 1. O QUE FOI FEITO

### 1.1 Correção do Config dos Agentes (Auditoria Completa)

**Problema**: Após migração Docker → bare metal, agentes estavam quebrados por nomes incorretos de tools, instruções erradas nos bootstrap files, e skills atribuídas a agentes sem as ferramentas necessárias.

**Correções aplicadas**:
- Removido `agentToAgent` do `alsoAllow` (não é tool, é seção de config)
- Atlas: removido `deny: group:runtime` e `exec.security` redundantes (messaging já não tem exec)
- Movido skill `gog` de Tango/Atlas para Pixel (gog precisa de exec)
- Reescrito `config/bootstrap/tango/AGENTS.md` com delegação automática via `sessions_send`
- Corrigido "container" → "VPS" nos bootstrap de Pixel
- Atualizado CLAUDE.md com tabela de agentes correta

**Commits**: `dce9124`, `b42b976`, `61ebd8e`

### 1.2 Multi-Provider LLM (OpenRouter)

**Antes**: Todos os agentes usavam Claude (Anthropic API key) — caro e rate limits constantes.

**Depois**:

| Agente | Antes | Depois | Economia |
|--------|-------|--------|----------|
| tango | Haiku $1/$5 | Haiku $1/$5 (mantido, dados pessoais) | — |
| atlas | Haiku $1/$5 | Kimi K2.5 $0.60/$3 | 40% |
| pixel/hawk/sentinel | Sonnet $3/$15 | MiniMax M2.5 $0.30/$1.20 | 92% |
| heartbeat | Haiku | Gemini Flash Lite $0.10/$0.40 | 90% |
| subagents | herdava pai | Gemini Flash $0.30/$2.50 | 90% |

**Configurações adicionais**:
- `contextTokens`: 100k → 32k
- `compaction`: mode `safeguard` (auto-resume)
- `timeoutSeconds`: 120 → 90
- `maxChildrenPerAgent`: 3
- `archiveAfterMinutes`: 30
- Fallback chains: MiniMax → Kimi → Gemini → Sonnet/Haiku
- Model params: Kimi contextWindow=256k, MiniMax contextWindow=200k, maxTokens=8192

**Commits**: `dce9124`, `70114af`

### 1.3 Ferramentas Instaladas na VPS

| Ferramenta | Versão | Auth | Propósito |
|-----------|--------|------|-----------|
| Claude Code CLI | v2.1.63 | OAuth (Max Pro, lucast0rr3s@gmail.com) | Coding via `claude -p` |
| gog CLI | v0.11.0 | OAuth (limatango.code@gmail.com) | Google Workspace |
| gh CLI | — | Token (limatango-code) | GitHub |
| Playwright | 1.58.0 | — | Web scraping |
| Docker | 29.2.1 | — | PostgreSQL + Redis |
| redis-cli | — | — | Diagnóstico Redis |
| psql | 16 | — | Diagnóstico PostgreSQL |
| expect | — | — | Automação de auth interativo |

**Processo de auth do gog** (complexo, documentado em `docs/vps-setup-guide.md`):
1. `gog auth credentials <json>` — registrar credenciais
2. `gog auth keyring file` — configurar keyring como file (headless)
3. `gog auth add <email>` — inicia OAuth, gera URL
4. Abrir URL no browser, autorizar no Google
5. Browser redireciona para localhost (falha)
6. Copiar URL de erro e fazer `curl` direto no VPS
7. `gog auth list` para confirmar

**Processo de auth do Claude CLI**:
1. `claude auth login` — precisa de terminal interativo (SSH direto)
2. Gera URL, abrir no browser, autorizar
3. Colar código no terminal

**Commits**: `9750e39`, `befc39e`, `362853b`

### 1.4 Bootstrap Files Reescritos

| Arquivo | Mudança principal |
|---------|-------------------|
| `tango/AGENTS.md` | Delegação automática, memória proativa, tabela de "quando delegar" |
| `pixel/AGENTS.md` | Memória obrigatória, container → VPS |
| `pixel/TOOLS.md` | Claude CLI, gh CLI, gog com exemplos completos |
| `hawk/TOOLS.md` | Claude CLI para reviews, gh CLI |
| `sentinel/TOOLS.md` | Claude CLI para auditorias, gh CLI |

**Commits**: `7bfa736`, `befc39e`, `362853b`

### 1.5 Web Scraper

Criado `scripts/web-scraper.py` com comandos:
- `login <url> <email> <senha>` — login e salva cookies
- `fetch <url>` — busca página (até 10k chars)
- `list-links <url>` — lista links únicos
- `screenshot <url> <output>` — screenshot full-page
- `crawl <url> [depth]` — crawl recursivo

**Commits**: `9750e39`, `1ac4a65`

### 1.6 Transcrição de Áudio (Groq Whisper)

Configurado `tools.media.audio` com Groq Whisper (grátis):
- Voice notes no Telegram são transcritos automaticamente
- Modelo: `whisper-large-v3-turbo`
- Provider: Groq (GROQ_API_KEY)

### 1.7 TangoCash — Fase 1 Concluída

**Auditoria**: 12 de 19 tarefas já estavam implementadas. 7 foram implementadas nesta sessão.

**PRs abertas**:
- [PR #4 — API](https://github.com/pinkecode/tangocash-v3-api/pull/4): 4 commits
  - `fix(games): fix leaderboard JOIN to return userName correctly`
  - `fix(realtime): wire WebSocket events into purchase, draw, deposit and withdraw flows`
  - `fix(wallet): resolve N+1 query in getPendingWithdrawals with JOIN`
  - `fix(wallet): add PIX key format validation to withdraw DTO`
- [PR #4 — Admin](https://github.com/pinkecode/tangocash-v3-admin/pull/4): 1 commit
  - `fix(admin): URL-persisted filters, optimistic updates, HTTP error messages`

**Migrations e seeds executados** no PostgreSQL da VPS (container Docker).

---

## 2. O QUE APRENDEMOS

### 2.1 OpenClaw — Funciona para

- Messaging no Telegram (responder, lembrar, pesquisar)
- Heartbeat e cron jobs simples
- Web search e fetch
- Transcrição de áudio
- Delegação simples (uma tarefa por vez)

### 2.2 OpenClaw — NÃO funciona para

- **Orquestração de coding multi-agente** — cadeia Tango → Pixel perde contexto
- **Tarefas complexas multi-step** — Haiku é insuficiente como orquestrador
- **Coding real** — agentes analisam mas não implementam (ficam perguntando)
- **Persistência de memória** — subagentes não salvam progresso entre sessões
- **Gestão de sessões** — acumulam, travam, processos órfãos

### 2.3 Melhor abordagem para coding

`claude -p` diretamente na VPS com `--dangerously-skip-permissions`:
- Sem cadeia de delegação (sem perda de contexto)
- Implementa de fato (não fica perguntando)
- Usa subscription Max Pro (custo zero)
- Pode ser chamado via SSH remoto

### 2.4 Problemas técnicos específicos

| Problema | Causa | Solução |
|----------|-------|---------|
| "unknown entries (group:memory)" | Build desatualizada | `pnpm build` no tango-openclaw |
| "No session found with label: pixel" | Tango usando sessions.resolve em vez de sessions_send | Reinstruir via AGENTS.md |
| Sessões acumulando | Cron de 15min + delegações | Desabilitar cron de monitoria |
| Subagente sem exec | sessions_spawn herda perfil do pai | Usar sessions_send para agentes nomeados |
| gog auth falha | GOG_KEYRING_PASSWORD não passado para nohup | Passar env var explicitamente |
| Claude CLI auth | TUI interativa não funciona com pipe/expect | SSH interativo direto |
| Pixel em HEAD detached | Não criava branch antes de commitar | claude -p direto com instruções prescritivas |
| message too long no Telegram | Relatórios grandes truncados | Google Docs via gog |

---

## 3. INVENTÁRIO COMPLETO DO REPOSITÓRIO

### Código e Config

| Caminho | Propósito |
|---------|-----------|
| `config/openclaw.example.json` | Template de config multi-provider |
| `config/bootstrap/tango/AGENTS.md` | Instruções do Tango (delegação automática) |
| `config/bootstrap/pixel/AGENTS.md` | Instruções do Pixel (memória obrigatória) |
| `config/bootstrap/pixel/TOOLS.md` | Claude CLI, gh, gog para Pixel |
| `config/bootstrap/hawk/TOOLS.md` | Claude CLI, gh para Hawk |
| `config/bootstrap/sentinel/TOOLS.md` | Claude CLI, gh para Sentinel |
| `scripts/web-scraper.py` | Scraper Playwright (login, fetch, crawl) |
| `scripts/tango-gateway.service` | Systemd unit do gateway |

### Documentação

| Caminho | Propósito |
|---------|-----------|
| `docs/vps-setup-guide.md` | Guia completo de setup da VPS |
| `docs/lessons-learned-2026-02-28.md` | Lições aprendidas |
| `docs/research-openclaw-cost-optimization.md` | Pesquisa de otimização de custos |
| `docs/session-2026-02-28-complete.md` | Este documento |

### Memórias dos Agentes (backup)

| Caminho | Conteúdo |
|---------|----------|
| `data/memory-backup/tango/tangocash-plano-evolucao.md` | Plano completo (117 tarefas, 6 fases) |
| `data/memory-backup/tango/sessao-2026-02-28.md` | Diário de progresso do Tango |
| `data/memory-backup/tango/cbschool.md` | URLs e status do CBSchool |
| `data/memory-backup/tango/agentes-config.md` | Config dos agentes (fallback chains) |
| `data/memory-backup/tango/tangocash-contexto.md` | Contexto de delegação |
| `data/memory-backup/pixel/cbschool.md` | URLs dos módulos CBSchool |
| `data/memory-backup/openclaw-config-live.json` | Config completo como estava rodando |
| `data/memory-backup/cron-jobs.json` | Cron jobs ativos |

### Projetos

| Caminho | Conteúdo |
|---------|----------|
| `projects/tangocash-v3/CLAUDE.md` | Contexto completo do TangoCash para agentes |
| `projects/tangocash-v3/PLANO_EVOLUCAO.md` | Plano na VPS (copiado da memória do Tango) |

---

## 4. COMO RECRIAR DO ZERO

### 4.1 VPS Nova

```bash
# 1. Criar VPS Hetzner (CPX21, Ubuntu 24.04)
# 2. Hardening
ssh root@<IP>
git clone https://github.com/lucastorress/tango-agent.git
cd tango-agent && bash scripts/harden-vps.sh
# Logout e reconectar como deploy

# 3. Clonar repo como deploy
ssh deploy@<IP>
git clone --recurse-submodules https://github.com/lucastorress/tango-agent.git
cd tango-agent

# 4. Setup inicial
make setup  # Gera .env, openclaw.json, chmod 600, build

# 5. Editar .env com as chaves
nano .env
# ANTHROPIC_API_KEY=sk-ant-...
# OPENROUTER_API_KEY=sk-or-v1-...
# GROQ_API_KEY=gsk_...
# TELEGRAM_BOT_TOKEN=8796842658:AAF...
# TELEGRAM_USER_ID=86295506
# GOG_KEYRING_PASSWORD=...
# GOG_ACCOUNT=limatango.code@gmail.com

# 6. Instalar ferramentas extras
sudo npm install -g @anthropic-ai/claude-code
claude auth login  # Interativo — seguir instruções
# gog: ver docs/vps-setup-guide.md seção 2
# Playwright:
python3 -m venv ~/playwright-env
source ~/playwright-env/bin/activate
pip install playwright && playwright install chromium && playwright install-deps chromium

# 7. Deploy
make deploy
```

### 4.2 Config Multi-Provider

O template `config/openclaw.example.json` já tem tudo configurado:
- Modelos por agente (Haiku, Kimi, MiniMax, Gemini)
- Fallback chains (3-4 níveis)
- contextTokens: 32k
- Compaction safeguard
- Heartbeat Flash Lite
- Subagents Gemini Flash

`make setup` copia o template e injeta o TELEGRAM_USER_ID.

### 4.3 Se for usar para CODING

**NÃO use o OpenClaw como orquestrador de coding.** Use:

```bash
# Opção 1: Claude CLI direto na VPS
ssh deploy@<IP>
cd ~/tango-agent/projects/<projeto>
claude -p "<tarefa>" --allowedTools "Read Glob Grep Edit Write Bash" --dangerously-skip-permissions

# Opção 2: Claude Code local + SSH
cd ~/Git/tango-agent/projects/<projeto>
claude  # Interativo, lê CLAUDE.md do projeto

# Opção 3: Claude CLI remoto via SSH
ssh deploy@<IP> 'cd ~/tango-agent/projects/<projeto> && claude -p "<tarefa>" --dangerously-skip-permissions'
```

### 4.4 Se for usar para MESSAGING (o que funciona)

O OpenClaw funciona bem como assistente pessoal no Telegram:
- Responder perguntas
- Pesquisar na web
- Lembretes e cron jobs
- Transcrever áudios
- Consultar Gmail/Calendar via delegação simples para Pixel

Para isso, `make deploy` é suficiente.

---

## 5. PENDÊNCIAS

| Item | Status | Próximo passo |
|------|--------|---------------|
| TangoCash PR API #4 | Aberta | Revisar e mergear |
| TangoCash PR Admin #4 | Aberta | Revisar e mergear |
| TangoCash Fase 2 (UI/UX) | Planejada | 20 tarefas, pós-MVP |
| TangoCash Fase 6 (pré-lançamento) | Planejada | 25 tarefas, MVP blocker |
| CBSchool scraping | Parcial | Login funciona, extração pendente |
| Vídeo (Gemini/Kimi) | Config pronta, falta GEMINI_API_KEY | Criar em aistudio.google.com |
| gog auth no Google Cloud | App em modo teste | Publicar ou manter como teste |

---

*Documento gerado em 2026-03-01 | Sessão de ~12 horas | 10 commits | 2 PRs abertas*
