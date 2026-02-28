# Tango Agent

Agente pessoal de IA baseado no [OpenClaw](https://github.com/openclaw/openclaw), rodando exclusivamente em Docker.

## Pre-requisitos

- [Docker](https://docs.docker.com/get-docker/) e Docker Compose
- Git

## Quick Start

```bash
# Clonar com submodule
git clone --recurse-submodules https://github.com/lucastorress/tango-agent.git
cd tango-agent

# Setup (cria .env, openclaw.json, diretorios, builda imagem)
make setup

# Editar .env com suas API keys
# - ANTHROPIC_API_KEY
# - TELEGRAM_BOT_TOKEN
# - TELEGRAM_USER_ID

# Rodar setup novamente para injetar o Telegram User ID no config
make setup

# Subir o gateway
make up

# Ver logs
make logs
```

## Comandos (Makefile)

| Comando               | Descricao                                      |
|-----------------------|-------------------------------------------------|
| `make build`          | Builda a imagem Docker (2-step: base + gog)     |
| `make up`             | Sobe o gateway (acesso via SSH tunnel)          |
| `make up-proxy`       | Sobe gateway + Caddy com HTTPS (requer dominio) |
| `make down`           | Para todos os containers                        |
| `make logs`           | Acompanha logs do gateway                       |
| `make status`         | Verifica status dos canais                      |
| `make health`         | Verifica saude do gateway                       |
| `make cli`            | Abre o CLI do OpenClaw                          |
| `make setup`          | Executa setup inicial                           |
| `make deploy`         | Build + restart com validacao                   |
| `make update`         | Atualiza OpenClaw do upstream e rebuilda        |
| `make doctor`         | Roda diagnostico do OpenClaw                    |
| `make restart`        | Restart do gateway (mitiga memory leak)          |
| `make sync-bootstrap` | Sincroniza templates bootstrap → workspaces      |
| `make security-check` | Verifica seguranca do deploy                    |
| `make backup`         | Backup local do data/ (tar.gz)                  |
| `make snapshot`       | Backup local + snapshot Hetzner                 |

## Build e Deploy

### Como funciona o build (2-step)

O build usa duas etapas porque o `Dockerfile` da raiz estende a imagem base do OpenClaw:

```
Step 1: docker build ./tango-openclaw → tango-openclaw-base:latest  (OpenClaw + apt packages)
Step 2: docker compose build          → tango-openclaw:latest       (base + gog + socat)
```

`make build`, `make deploy`, `make setup` e `make update` executam os 2 steps automaticamente. **Nunca rode `docker compose build` direto** — a imagem base nao existira.

### Deploy local → VPS

```bash
# 1. Faz as mudancas localmente
# 2. Commita e push
git add . && git commit -m "feat: descricao" && git push

# 3. No VPS: pull + deploy
ssh deploy@<VPS_IP>
cd ~/tango-agent
git pull
git submodule update --init --recursive
make deploy
```

### Quando precisa de restart

| Mudanca | Comando | Motivo |
|---------|---------|--------|
| Editou `.env` (API keys, tokens) | `docker compose up -d tango-gateway --force-recreate` | `restart` nao recarrega env vars |
| Editou `data/config/openclaw.json` | `docker compose restart tango-gateway` | O gateway rele o config no boot |
| Mudou `Dockerfile` ou `docker-compose.yml` | `make build && docker compose up -d tango-gateway --force-recreate` | Precisa rebuildar a imagem |
| Atualizou bootstrap templates | `make sync-bootstrap && docker compose restart tango-gateway` | Copia templates para workspaces |
| Memory leak / gateway travado | `make restart` | Restart rapido |

**Regra geral**: mudou `.env` → `--force-recreate`. Mudou config JSON → `restart`. Mudou Dockerfile → `make build`.

### Atualizar OpenClaw do upstream

```bash
make update
# Depois commitar o submodule atualizado:
git add tango-openclaw && git commit -m "chore: update openclaw submodule"
```

## Configuracao

### Arquivos de configuracao

| Arquivo | Conteudo | Passado ao container? |
|---------|----------|-----------------------|
| `.env` | API keys, tokens, config do OpenClaw | Sim (via `env_file`) |
| `.env.infra` | Credenciais de infraestrutura (Hetzner) | **Nao** - apenas scripts |
| `data/config/openclaw.json` | Config do agente (modelo, canais, tools) | Sim (via volume) |

### Fluxo completo

```
1. make setup          # Gera .env, openclaw.json, diretorios, builda imagem
2. Editar .env         # Preencher API keys, token Telegram, User ID
3. make setup          # Re-rodar para injetar Telegram User ID no config
4. make up             # Sobe o gateway
5. make deploy         # (VPS) Valida .env + rebuild + restart
```

### Variaveis obrigatorias (.env)

| Variavel                  | O que e                          | Onde obter                                                  |
|---------------------------|----------------------------------|-------------------------------------------------------------|
| `OPENCLAW_GATEWAY_TOKEN`  | Token de autenticacao do gateway | Gerado automaticamente pelo `make setup`                    |
| `ANTHROPIC_API_KEY`       | Chave da API da Anthropic        | [console.anthropic.com](https://console.anthropic.com/)     |
| `TELEGRAM_BOT_TOKEN`      | Token do bot do Telegram         | [@BotFather](https://t.me/BotFather) no Telegram            |
| `TELEGRAM_USER_ID`        | Seu ID numerico do Telegram      | [@userinfobot](https://t.me/userinfobot) no Telegram        |

### Variaveis opcionais (.env)

| Variavel                  | Default                  | Descricao                          |
|---------------------------|--------------------------|------------------------------------|
| `OPENAI_API_KEY`          | _(vazio)_                | Chave da OpenAI (alternativa)      |
| `DOMAIN`                  | _(vazio)_                | Dominio para HTTPS (ex: tango.exemplo.com) |
| `OPENCLAW_CONFIG_DIR`     | `./data/config`          | Diretorio de config do OpenClaw    |
| `OPENCLAW_WORKSPACE_DIR`  | `./data/workspace`       | Diretorio de trabalho do agente    |
| `OPENCLAW_GATEWAY_BIND`   | `lan`                    | Modo de bind (`loopback` ou `lan`) |
| `OPENCLAW_IMAGE`          | `tango-openclaw:latest`  | Nome da imagem Docker              |
| `PROJECTS_DIR`            | `./projects`             | Diretorio de projetos git (montado no container) |
| `GIT_USER_NAME`           | `Tango Dev Agent`        | Nome para commits do agente                      |
| `GIT_USER_EMAIL`          | `dev@tango-agent.local`  | Email para commits do agente                     |
| `GIT_TOKEN`               | _(vazio)_                | GitHub PAT para push via HTTPS                   |

### Credenciais de infraestrutura (.env.infra)

Credenciais do servidor ficam **separadas** do `.env` do OpenClaw. O container nunca tem acesso a elas.

| Variavel             | Descricao                    |
|----------------------|------------------------------|
| `HETZNER_API_TOKEN`  | Token da API Hetzner Cloud   |
| `HETZNER_SERVER_ID`  | ID do servidor (para snapshots) |

```bash
# Criar a partir do template
cp .env.infra.example .env.infra
# Editar com suas credenciais
```

Os scripts de backup pedem o token em runtime se `.env.infra` nao existir.

### Seguranca dos arquivos de config

- `.env` e `.env.infra` **nunca sao commitados** (protegidos pelo `.gitignore`)
- Permissoes sao setadas automaticamente para `600` (apenas dono le/escreve)
- No VPS, o `.env` e criado pelo `make setup` e editado diretamente (sem transferencia via rede)
- O `.env.infra` nao precisa ir pro VPS — o script de backup pede o token Hetzner em runtime
- **Nunca** cole API keys em chats, issues ou repositorios publicos

## Agentes

O Tango Agent usa uma arquitetura **multi-agent** com cinco agentes especializados:

| Agente | Emoji | Papel | Perfil | Skills |
|--------|-------|-------|--------|--------|
| **tango** (principal) | 🥭 | Assistente pessoal, ponto de contato no Telegram | `messaging` | `weather`, `gog` |
| **atlas** | 📋 | Estrategista e pesquisador | `messaging` | `summarize`, `gog` |
| **pixel** | 💻 | Desenvolvedor e construtor | `coding` | `github`, `gh-issues` |
| **hawk** | 🔍 | Guardiao de qualidade e revisao | `coding` | `github`, `gh-issues`, `session-logs` |
| **sentinel** | 🛡️ | Seguranca e operacoes | `coding` | `healthcheck`, `session-logs` |

### Comunicacao entre agentes

Todos os agentes se comunicam via `agentToAgent` usando tags padronizadas:

- `[TASK]` — Delegar uma tarefa
- `[REPORT]` — Reportar resultado
- `[QUESTION]` — Tirar duvida
- `[INFO]` — Informar sem exigir acao

Apenas o **tango** pode spawnar subagents (`sessions_spawn`). Max 5 turnos de ping-pong por conversa agent-to-agent.

### Bootstrap files

Templates ficam em `config/bootstrap/{agente}/` e sao copiados para os workspaces:

| Arquivo | tango | atlas | pixel | hawk | sentinel | Descricao |
|---------|-------|-------|-------|------|----------|-----------|
| `IDENTITY.md` | x | x | x | x | x | Nome e emoji |
| `SOUL.md` | x | x | x | x | x | Base compartilhada + personalidade unica |
| `USER.md` | x | | | | | Info do usuario (Lucas) |
| `AGENTS.md` | x | x | x | x | x | Regras gerais + manual operacional |
| `HEARTBEAT.md` | x | | | | | Checklist do heartbeat + sugestoes de cron |
| `TOOLS.md` | | | x | x | x | Guidelines de ferramentas por papel |

- `make setup` copia templates somente se o arquivo nao existir no workspace
- `make sync-bootstrap` sobrescreve todos (exceto `memory/` e `MEMORY.md`)

### Memoria persistente

Cada agente tem um diretorio `memory/` no seu workspace para guardar informacoes entre sessoes. O OpenClaw faz flush automatico da memoria de compactacao para esses arquivos (`compaction.memoryFlush`).

### Cron

Cron habilitado globalmente para tarefas agendadas. O agente tango pode criar e gerenciar tarefas cron via Telegram. Sugestoes de cron (briefing matinal, resumo noturno) documentadas no `HEARTBEAT.md`.

## Config do OpenClaw (openclaw.json)

O arquivo `config/openclaw.example.json` e o template. O `make setup` copia automaticamente para `data/config/openclaw.json`.

### O que esta configurado no template

| Secao | Configuracao | Descricao |
|-------|-------------|-----------|
| `gateway` | `bind: loopback` + rate limit | Gateway localhost-only, bloqueia apos 5 falhas |
| `identity` | Nome, tema, emoji | Personalidade do Tango |
| `session` | `dmScope: per-channel-peer` | Sessoes separadas por contato |
| `channels.telegram` | `dmPolicy: allowlist` | So responde ao seu Telegram User ID |
| `agents` | Haiku 4.5 (default) + Sonnet 4.6 (coding) | `/model sonnet` ou `/model haiku` no Telegram |
| `agents.list` | 5 agentes: tango, atlas, pixel, hawk, sentinel | Multi-agent com agent-to-agent |
| `tools` | agentToAgent habilitado | Todos os agentes se comunicam entre si |
| `cron` | enabled | Tarefas agendadas |
| `logging` | `redactSensitive: tools` | Redacta dados sensiveis nos logs |

### Como encontrar seu Telegram User ID

1. Abra o Telegram e fale com o [@userinfobot](https://t.me/userinfobot)
2. Ele responde com seu ID numerico (ex: `123456789`)
3. Coloque no `.env`: `TELEGRAM_USER_ID=123456789`
4. Rode `make setup` para injetar no config

## Google Workspace (opcional)

O Tango Agent pode acessar Gmail, Calendar, Drive, Contacts, Sheets e Docs via a skill `gog`.

### Variaveis (.env)

| Variavel               | Descricao                                      |
|------------------------|-------------------------------------------------|
| `GOG_KEYRING_PASSWORD` | Senha para o keyring do gog (obrigatoria em Docker) |
| `GOG_ACCOUNT`          | Conta Google padrao (evita repetir `--account`) |

### Setup

1. Criar um projeto no [Google Cloud Console](https://console.cloud.google.com/) e baixar o `client_secret_*.json`
2. Copiar o JSON para `data/config/`:
   ```bash
   cp client_secret_*.json data/config/
   ```
3. Definir variaveis no `.env`:
   ```bash
   echo 'GOG_KEYRING_PASSWORD=senha-segura-aqui' >> .env
   echo 'GOG_ACCOUNT=sua-conta@gmail.com' >> .env
   ```
4. Restart para carregar as novas env vars:
   ```bash
   docker compose up -d tango-gateway
   ```
5. Autenticar dentro do container:
   ```bash
   docker compose exec tango-gateway bash
   gog auth credentials /home/node/.openclaw/client_secret_*.json
   gog auth add $GOG_ACCOUNT --services gmail,calendar,drive,contacts,docs,sheets
   # Mostra URL → abrir no browser → autorizar → copiar codigo de volta no terminal
   gog auth list  # verificar
   exit
   ```

Os tokens ficam persistidos em `data/config/gogcli/` via volume mount.

## HTTPS com Caddy (opcional)

Se voce tem um dominio apontando para o IP do VPS, o Caddy fornece HTTPS automatico:

```bash
# 1. Configurar dominio no .env
echo "DOMAIN=tango.seudominio.com" >> .env

# 2. Subir com proxy
make up-proxy
```

O Caddy obtem certificado Let's Encrypt automaticamente e faz reverse proxy para o gateway.

Sem dominio? Use SSH tunnel (ver abaixo).

## Deploy na Hetzner VPS

### Fluxo de deploy (via git)

Todo o codigo vai pelo repositorio. So os segredos vao por SCP.

```bash
# === Na sua maquina local ===

# 1. Hardening do VPS (primeira vez, como root)
ssh root@VPS_IP 'bash -s' < scripts/harden-vps.sh
# IMPORTANTE: teste o login ANTES de fechar a sessao root!
ssh deploy@VPS_IP

# 2. Instalar Docker no VPS
ssh deploy@VPS_IP 'curl -fsSL https://get.docker.com | sh'

# === No VPS (ssh deploy@VPS_IP) ===

# 3. Clonar repo (todo o codigo vem do git)
git clone --recurse-submodules https://github.com/lucastorress/tango-agent.git
cd tango-agent

# 4. Setup (gera .env com token automatico)
make setup

# 5. Editar .env no VPS com suas API keys
nano .env  # preencher ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_USER_ID

# 6. Deploy
make deploy
```

### Atualizar o deploy

```bash
# No VPS
cd ~/tango-agent
git pull
git submodule update --init --recursive
make deploy
```

### Hardening automatico

O script `scripts/harden-vps.sh` configura:
- **SSH**: key-only (sem senha), root login bloqueado, max 3 tentativas
- **Firewall (UFW)**: apenas SSH + HTTP/HTTPS, tudo mais bloqueado
- **Fail2ban**: ban de 1h apos 3 falhas SSH
- **Updates**: patches de seguranca automaticos, reboot as 4h se necessario
- **Usuario deploy**: usuario dedicado sem root

### Verificar seguranca

```bash
# No VPS, dentro do diretorio tango-agent
make security-check
```

## Backup

```bash
# Backup local (tar.gz, mantido em backups/, ultimos 7)
make backup

# Backup local + snapshot Hetzner (mantidos ultimos 5)
make snapshot
```

O script pede o token Hetzner em runtime se `.env.infra` nao existir.

## Acesso via SSH Tunnel (VPS)

```bash
ssh -L 18789:127.0.0.1:18789 deploy@seu-vps
# Em outro terminal:
openclaw gateway connect ws://127.0.0.1:18789 --token SEU_TOKEN
```

## Problemas conhecidos do OpenClaw e mitigacoes

O OpenClaw e um projeto ativo com vulnerabilidades documentadas. Abaixo as principais e como o Tango Agent mitiga cada uma.

### Vulnerabilidades corrigidas

| CVE | Severidade | Descricao | Status |
|-----|-----------|-----------|--------|
| CVE-2026-25253 | CVSS 8.8 | WebSocket hijacking → RCE via link malicioso | Corrigido (v2026.1.29+) |
| IPv6 multicast SSRF | Alta | Bypass do SSRF guard via IPv6 | Corrigido (v2026.2.26) |
| Sandbox path escape | Alta | Symlink/hardlink escape em workspace-only | Corrigido (v2026.2.26) |
| Device-auth spoofing | Alta | Spoofing de metadata de dispositivo | Corrigido (v2026.2.26) |

**Acao**: Manter o submodule atualizado (`make update`). Nosso commit esta em versao corrigida.

### Memory leak

O gateway pode crescer de 1.8GB para 4-6GB em dias de uso continuo.

**Mitigacoes no Tango Agent**:
- Memory limit: 4G (previne OOM do host)
- `make restart` para restart manual
- `make doctor` para diagnostico
- Deploy roda `openclaw doctor` automaticamente

### API keys em plain text

O `openclaw.json` armazena chaves sem criptografia. Nao ha secrets manager nativo.

**Mitigacoes no Tango Agent**:
- `chmod 600` automatico no setup (so dono le/escreve)
- `.env` e `openclaw.json` no `.gitignore`
- Credenciais de infra (Hetzner) separadas em `.env.infra` (nunca entram no container)

### ClawHub supply chain attacks

~20% dos skills no ClawHub sao maliciosos (malware, stealers, reverse shells).

**Mitigacoes no Tango Agent**:
- Messaging agents: `deny: ["gateway", "group:runtime"]` — bloqueia gateway e runtime
- Coding agents: perfil `coding` completo sem allow/deny extras
- `tools.elevated.enabled: false` — sem ferramentas privilegiadas
- `tools.loopDetection` habilitado — previne loops de ferramentas

### Modelo de confianca single-operator

O OpenClaw foi projetado para **um unico operador de confianca** por gateway. Nao e multi-tenant.

**Mitigacao no Tango Agent**:
- `dmPolicy: allowlist` — so responde ao seu Telegram User ID
- `groupPolicy: disabled` — sem acesso a grupos
- Gateway bound em `127.0.0.1` — nao exposto a internet

### Telegram Privacy Mode

Bots em grupos nao veem mensagens por padrao (precisa desabilitar via BotFather).

**Status**: Nao nos afeta — `groupPolicy: disabled` no config.

## Estrutura

```
tango-agent/
├── .env.example                # Template: variaveis do OpenClaw
├── .env.infra.example          # Template: credenciais de infra (Hetzner)
├── docker-compose.yml          # Gateway + Caddy + CLI
├── Makefile                    # Atalhos operacionais
├── scripts/
│   ├── setup.sh                # Setup inicial (local + VPS)
│   ├── deploy.sh               # Deploy com validacao
│   ├── sync-bootstrap.sh       # Sincroniza templates → workspaces
│   ├── backup.sh               # Backup local + snapshot Hetzner
│   ├── harden-vps.sh           # Hardening de seguranca do VPS
│   └── security-check.sh       # Auditoria de seguranca
├── config/
│   ├── openclaw.example.json   # Template de config OpenClaw
│   ├── Caddyfile               # Config do reverse proxy
│   ├── gitconfig               # Git config para o container (credential helper)
│   └── bootstrap/              # Templates de bootstrap dos agentes
│       ├── tango/              # IDENTITY, SOUL, USER, AGENTS, HEARTBEAT
│       ├── atlas/              # IDENTITY, SOUL, AGENTS
│       ├── pixel/              # IDENTITY, SOUL, AGENTS, TOOLS
│       ├── hawk/               # IDENTITY, SOUL, AGENTS, TOOLS
│       └── sentinel/           # IDENTITY, SOUL, AGENTS, TOOLS
├── data/                       # (gerado pelo setup, no .gitignore)
│   ├── config/                 # openclaw.json + identity/
│   ├── workspace/              # Workspace do Tango
│   ├── workspace-atlas/        # Workspace do Atlas
│   ├── workspace-pixel/        # Workspace do Pixel
│   ├── workspace-hawk/         # Workspace do Hawk
│   └── workspace-sentinel/     # Workspace do Sentinel
├── projects/               # (gitignored) Projetos git montados no container
└── tango-openclaw/             # [submodule] OpenClaw
```
