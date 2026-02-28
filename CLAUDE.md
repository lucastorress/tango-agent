# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this project

Tango Agent is Lucas Torres's (@lucastorress) personal AI assistant built on OpenClaw, running **bare metal via systemd** on a Hetzner VPS with Telegram as the initial messaging channel.

**Respond in Brazilian Portuguese** unless the user switches to English.

## Architecture

This is a **bootstrap/infrastructure repo**, not an application codebase. It wraps OpenClaw (a TypeScript/Node.js AI gateway) with systemd, operational scripts, and security hardening.

- `tango-openclaw/` is a **git submodule** → `lucastorress/tango-openclaw` (fork) with `upstream` remote → `openclaw/openclaw`
- All configuration flows through two layers: `.env` (read by systemd `EnvironmentFile`) and `data/config/openclaw.json` (OpenClaw runtime config)
- Deploy is **git-based**: VPS clones the repo, secrets are created locally via `make setup` + manual edit. No scp needed.

### Credential separation

| File | Read by | Purpose |
|------|---------|---------|
| `~/.openclaw` | symlink → `data/config/` | OpenClaw always reads `$HOME/.openclaw`; symlink created by `make setup` |
| `.env` | systemd `EnvironmentFile` | API keys, tokens, OpenClaw env vars |
| `.env.infra` | Scripts only | Hetzner API token — never enters gateway process |
| `data/config/openclaw.json` | OpenClaw (`XDG_CONFIG_HOME`) | Runtime config (generated from `config/openclaw.example.json`) |
| `GIT_TOKEN` | `.env` → systemd | GitHub PAT para git push via HTTPS (agentes coding) |
| `GOG_KEYRING_PASSWORD` | `.env` → systemd | Senha do keyring do gog |
| `GOG_ACCOUNT` | `.env` → systemd | Conta Google padrão para o gog |
| `OPENROUTER_API_KEY` | `.env` → systemd | OpenRouter API key (multi-provider LLM gateway) |

### Build

Build direto com pnpm (sem Docker):

```bash
cd tango-openclaw && pnpm install --frozen-lockfile && pnpm build
```

O resultado fica em `tango-openclaw/dist/`. `make build`, `make deploy`, `make setup` e `make update` executam o build automaticamente.

### Services (systemd)

| Service | Type | Description |
|---------|------|-------------|
| `tango-gateway` | systemd unit | OpenClaw gateway, port 18789 on loopback, MemoryMax 4G |
| `tango-bot` | Docker container | Telegram bot via Claude Agent SDK (profile: bot) |

O gateway roda como user `deploy` via systemd. O bot ainda usa Docker (separado).

### Multi-agent architecture

Five agents with distinct roles, personalities, and permissions:

| Agent (id) | Name | Emoji | Profile | Extras (alsoAllow) | Skills | Heartbeat | Workspace |
|------------|------|-------|---------|-------------------|--------|-----------|-----------|
| `tango` (default) | Tango | 🥭 | `messaging` | `memory`, `web`, `sessions_spawn`, `cron`, `agents_list`, `image` | `weather` | 30min (8h-24h) | `data/workspace/` |
| `atlas` | Atlas | 📋 | `messaging` | `memory`, `web`, `image` | `summarize` | — | `data/workspace-atlas/` |
| `pixel` | Pixel | 💻 | `coding` | _(profile completo, sem extras)_ | `github`, `gh-issues`, `gog` | — | `data/workspace-pixel/` |
| `hawk` | Hawk | 🔍 | `coding` | _(profile completo, sem extras)_ | `github`, `gh-issues`, `session-logs` | — | `data/workspace-hawk/` |
| `sentinel` | Sentinel | 🛡️ | `coding` | _(profile completo, sem extras)_ | `healthcheck`, `session-logs` | — | `data/workspace-sentinel/` |

- **Tango** 🥭: Right-hand assistant. Talks to Lucas via Telegram. Delegates to others. Only agent with heartbeat and `sessions_spawn`.
- **Atlas** 📋: Strategic thinker. Research, specs, analysis. Data before opinions.
- **Pixel** 💻: Builder. Code, implement, ship. No chit-chat.
- **Hawk** 🔍: Quality guardian. Code review, testing, architecture validation. Always suggests fixes.
- **Sentinel** 🛡️: Security watchdog. Audits, checklists, deploy validation. Prevents before fixing.

All agents can communicate with each other via `agentToAgent`. Only Tango can spawn subagents. Max 5 ping-pong turns per agent-to-agent conversation.

Agent-to-agent communication uses standardized tags: `[TASK]`, `[REPORT]`, `[QUESTION]`, `[INFO]`.

### Projects directory (agentes coding)

| Localização | Caminho |
|-------------|---------|
| VPS | `/home/deploy/tango-agent/projects/` ou `PROJECTS_DIR` do `.env` |
| macOS (dev) | `./projects/` (default) |

- Acessível por `pixel`, `hawk` e `sentinel` (perfil `coding` com `exec`)
- Git push usa HTTPS com `GIT_TOKEN` (GitHub PAT no `.env`)
- SSH agent forwarding desabilitado no VPS (segurança)

### Bootstrap structure

Templates live in `config/bootstrap/{agent}/` and are copied to workspaces by `make setup` (only if missing) or `make sync-bootstrap` (overwrites, preserves `memory/`).

| File | tango | atlas | pixel | hawk | sentinel | Purpose |
|------|-------|-------|-------|------|----------|---------|
| `IDENTITY.md` | x | x | x | x | x | Name + emoji (2-3 lines) |
| `SOUL.md` | x | x | x | x | x | Shared base + unique personality |
| `USER.md` | x | | | | | Info about Lucas |
| `AGENTS.md` | x | x | x | x | x | General rules + operational manual |
| `HEARTBEAT.md` | x | | | | | Heartbeat checklist + cron suggestions |
| `TOOLS.md` | | | x | x | x | Tool guidelines specific to role |

Memory persistence: each agent has a `memory/` directory in its workspace. Cron enabled globally.

### LLM configuration (multi-provider via OpenRouter)

| Agente | Primary | Fallback | Custo (input/output MTok) |
|--------|---------|----------|---------------------------|
| tango | Claude Haiku 4.5 | Kimi K2.5 | $1.00/$5.00 |
| atlas | Kimi K2.5 (OpenRouter) | Claude Haiku 4.5 | $0.60/$3.00 |
| pixel, hawk, sentinel | MiniMax M2.5 (OpenRouter) | Claude Sonnet 4.6 | $0.30/$1.20 |
| heartbeat | Gemini 2.5 Flash Lite (OpenRouter) | — | $0.10/$0.40 |
| subagents | Gemini 2.5 Flash (OpenRouter) | — | $0.30/$2.50 |

- User can switch via `/model sonnet`, `/model haiku`, `/model m25`, `/model kimi`, `/model flash-lite` in Telegram
- `ANTHROPIC_API_KEY` for Claude models, `OPENROUTER_API_KEY` for all others
- Compaction mode `safeguard` (auto-resume sessions longas)
- `contextTokens`: 32k (reduzido de 100k para economia)

### Tango Bot (Agent SDK)

Alternative to OpenClaw gateway — a standalone Telegram bot using `@anthropic-ai/claude-agent-sdk` (the Claude Code engine as a library). Lives in `bot/`.

- Grammy long polling (no webhook needed)
- Same auth: `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`
- Same workspaces, bootstrap files, and projects mount as OpenClaw
- Tango (main, Haiku) delegates to subagents via `Task` tool: atlas (Haiku), pixel (Sonnet), hawk (Sonnet), sentinel (Sonnet)
- Session persistence: `data/bot/sessions.json`
- **Cannot run simultaneously with OpenClaw gateway** if they share the same `TELEGRAM_BOT_TOKEN`

Source: `bot/src/` (6 files: config, bot, agent, session, streamer, index)

## Common commands

```bash
make setup          # First-time: generates .env (auto-token), openclaw.json, chmod 600, builds OpenClaw
make up             # Start gateway (systemctl start)
make down           # Stop gateway (systemctl stop)
make deploy         # Validate .env + build + restart + wait healthy + openclaw doctor
make restart        # Quick restart (mitigates known memory leak)
make logs           # Tail gateway logs (journalctl -f)
make logs-error     # Tail only errors (journalctl -p err)
make logs-today     # Logs since today
make doctor         # Run OpenClaw built-in diagnostics
make status         # systemctl status (PID, uptime, memory, last logs)
make health         # Gateway health check
make mem            # Memory usage
make cli CMD="..."  # Run OpenClaw CLI command
make update         # Fetch upstream OpenClaw, merge, rebuild
make install-service # Install/update systemd unit
make backup         # Local tar.gz backup of data/ (keeps last 7)
make snapshot       # Local backup + Hetzner API snapshot (keeps last 5)
make security-check # Audit VPS security posture
make sync-bootstrap # Sync bootstrap templates → workspaces (overwrites, preserves memory/)

# Tango Bot (Agent SDK)
make bot-dev        # Run bot locally with tsx (dev)
make bot-build      # Compile TypeScript
make bot-up         # Start bot container (profile: bot)
make bot-down       # Stop bot container
make bot-logs       # Tail bot logs
make bot-restart    # Restart bot container
```

## Key files

| File | Purpose |
|------|---------|
| `config/openclaw.example.json` | OpenClaw config template. `setup.sh` copies to `data/config/openclaw.json` and injects `TELEGRAM_USER_ID` from `.env` |
| `config/Caddyfile` | Caddy reverse proxy config (uses `$DOMAIN` env var) |
| `scripts/tango-gateway.service` | systemd unit file for the gateway |
| `scripts/setup.sh` | Idempotent setup: generates .env, copies config, sets chmod 600, builds OpenClaw. Safe to re-run. |
| `scripts/deploy.sh` | Validates required env vars, builds, restarts, waits for healthy, runs `openclaw doctor` |
| `scripts/harden-vps.sh` | One-shot VPS hardening: SSH key-only, no root login, UFW (SSH+80+443), fail2ban, unattended-upgrades, creates `deploy` user |
| `scripts/security-check.sh` | Audits SSH, firewall, fail2ban, .env permissions, exposed ports, systemd state |
| `scripts/backup.sh` | Local tar.gz + optional Hetzner snapshot via API (reads `.env.infra` or prompts at runtime) |
| `scripts/sync-bootstrap.sh` | Copies bootstrap templates to workspaces (overwrites). Never touches `memory/` or `MEMORY.md` |
| `config/bootstrap/` | Bootstrap templates for all 5 agents (IDENTITY.md, SOUL.md, AGENTS.md, etc.) |
| `config/gitconfig` | Git config (credential helper, safe.directory) — copied to `~/.gitconfig` by setup |
| `bot/src/` | Tango Bot source (6 TypeScript files: config, bot, agent, session, streamer, index) |
| `bot/Dockerfile` | Bot container image (node:22-bookworm-slim + git, curl, jq, ripgrep) |
| `docker/` | Archived Docker files (docker-compose.yml, Dockerfile) — reference only |

## Working with the submodule

```bash
# Update from upstream OpenClaw
cd tango-openclaw && git fetch upstream && git merge upstream/main --no-edit && cd ..
make build && sudo systemctl restart tango-gateway
git add tango-openclaw && git commit -m "chore: update openclaw submodule"
```

The submodule has two remotes: `origin` (Lucas's fork) and `upstream` (openclaw/openclaw).

## Security constraints

- Gateway binds to `127.0.0.1` only — access via SSH tunnel or Caddy reverse proxy
- Telegram allowlist (`dmPolicy: allowlist`) — only responds to the configured `TELEGRAM_USER_ID`
- Groups disabled (`groupPolicy: disabled`)
- Agent `tango`: `messaging` profile + `alsoAllow` (memory, web, sessions_spawn, cron, agents_list, image); `exec` denied; `elevated` disabled
- Agent `atlas`: `messaging` profile + `alsoAllow` (memory, web, image); `exec` denied; no heartbeat
- Agents `pixel`, `hawk`, `sentinel`: `coding` profile (full — all 16 tools included); isolated workspaces; no direct Telegram access
- Gateway runs as user `deploy` via systemd; `data/` owned by `deploy`
- `.env` and `openclaw.json` are chmod 600 (set by setup.sh)
- systemd hardening: `NoNewPrivileges=true`, `ProtectSystem=strict`, `ReadWritePaths` limited to `/home/deploy` and `/tmp`
- `MemoryMax=4G` no systemd (equivalente ao memory limit do Docker)

## Known OpenClaw issues to be aware of

- **Memory leak**: Gateway grows from 1.8GB to 4-6GB over days. `MemoryMax=4G` in systemd unit. Use `make restart` periodically.
- **CVE-2026-25253** (CVSS 8.8): WebSocket hijacking → RCE. Fixed in v2026.1.29+. Our submodule is on a patched version.
- **ClawHub supply chain**: ~20% of ClawHub skills are malicious. Never install external skills without auditing. Messaging agents deny `gateway`; coding agents use full profile without extra allow/deny. `elevated` disabled globally.
- **API keys in plain text**: OpenClaw stores keys unencrypted in `openclaw.json`. Mitigated with chmod 600.
- **Bun is experimental**: Not production-ready for gateway (WhatsApp/Telegram bugs). Always use Node.
- **CPU spike on startup**: OpenClaw loads all channel SDKs regardless of config. Expected behavior, not a bug in our setup.
- **Single-operator trust model**: One trusted operator per gateway. Not designed for multi-tenant.
- **Bot token conflict**: OpenClaw gateway and tango-bot cannot share the same `TELEGRAM_BOT_TOKEN` simultaneously (Telegram only allows one connection per token). Use one or the other, or create a separate bot token.

## Script compatibility

Scripts use `sed_inplace()` helper or `$OSTYPE` checks to be compatible with both **macOS** (local dev) and **Linux** (Hetzner VPS).

## Commit conventions

```
feat: description     # New feature or capability
fix: description      # Bug fix
chore: description    # Maintenance (submodule update, deps, etc)
docs: description     # Documentation only
```

## Deploy flow

```
VPS: git clone --recurse-submodules → make setup → edit .env → make deploy
Updates: git pull → git submodule update --init --recursive → make deploy
```

### Restart rules

| Mudança | Comando | Motivo |
|---------|---------|--------|
| `.env` editado | `make restart` | systemd relê `EnvironmentFile` no restart |
| `openclaw.json` editado | `make restart` | Gateway relê o config no boot |
| Código do OpenClaw | `make build && make restart` | Precisa rebuildar |
| systemd unit mudou | `make install-service && make restart` | Recarrega o daemon |
| Bootstrap templates | `make sync-bootstrap && make restart` | Copia templates para workspaces |
| Memory leak | `make restart` | Restart rápido |
