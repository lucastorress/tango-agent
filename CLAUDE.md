# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this project

Tango Agent is Lucas Torres's (@lucastorress) personal AI assistant built on OpenClaw, running **exclusively in Docker** (never locally — this protects host files). Deployed on a Hetzner VPS with Telegram as the initial messaging channel.

**Respond in Brazilian Portuguese** unless the user switches to English.

## Architecture

This is a **bootstrap/infrastructure repo**, not an application codebase. It wraps OpenClaw (a TypeScript/Node.js AI gateway) with Docker Compose, operational scripts, and security hardening.

- `tango-openclaw/` is a **git submodule** → `lucastorress/tango-openclaw` (fork) with `upstream` remote → `openclaw/openclaw`
- All configuration flows through two layers: `.env` (env vars to container) and `data/config/openclaw.json` (OpenClaw config, mounted as volume)
- Deploy is **git-based**: VPS clones the repo, secrets are created locally via `make setup` + manual edit. No scp needed.

### Credential separation

| File | Enters container? | Purpose |
|------|-------------------|---------|
| `.env` | Yes (`env_file`) | API keys, tokens, OpenClaw env vars |
| `.env.infra` | **Never** | Hetzner API token — host-side scripts only |
| `data/config/openclaw.json` | Yes (volume) | OpenClaw runtime config (generated from `config/openclaw.example.json`) |

### Docker services (tango-net bridge network)

| Service | Profile | Description |
|---------|---------|-------------|
| `tango-gateway` | _(always)_ | OpenClaw gateway, port 18789 on 127.0.0.1, memory limit 4G |
| `tango-caddy` | `proxy` | Caddy reverse proxy with auto-HTTPS (requires `DOMAIN` in .env) |
| `tango-cli` | `cli` | Interactive OpenClaw CLI, on-demand |

### Multi-agent architecture

Two pre-configured agents with distinct roles and permissions:

| Agent | Role | Tools | Heartbeat | Workspace |
|-------|------|-------|-----------|-----------|
| `tango` (default) | Personal assistant via Telegram | `messaging` + `memory` + `web` | 30min (8h-24h) | `data/workspace/` |
| `dev` | Coding/development agent | `coding` + `fs` + `runtime` + `exec` | disabled | `data/workspace-dev/` |

- **tango** handles conversations, reminders, research. Delegates technical tasks to **dev** via agent-to-agent.
- **dev** has file/git/exec access but never speaks directly on Telegram. Only responds to tango.
- Agent-to-agent communication enabled between both agents.
- Bootstrap files (IDENTITY.md, SOUL.md, etc.) in each workspace define agent persona and instructions.
- Memory persistence: each agent has a `memory/` directory in its workspace.
- Cron enabled globally for scheduled tasks.

### LLM configuration

- **Primary**: Claude Sonnet 4.6 (`anthropic/claude-sonnet-4-6`, alias `sonnet`)
- **Fallback**: Claude Haiku 4.5 (`anthropic/claude-haiku-4-5`, alias `haiku`)
- User can switch via `/model sonnet` or `/model haiku` in Telegram
- Single `ANTHROPIC_API_KEY` serves both models

## Common commands

```bash
make setup          # First-time: generates .env (auto-token), openclaw.json, chmod 600, builds image
make up             # Start gateway
make down           # Stop all containers
make deploy         # Validate .env + build + restart + wait healthy + openclaw doctor
make restart        # Quick restart (mitigates known memory leak)
make logs           # Tail gateway logs
make doctor         # Run OpenClaw built-in diagnostics
make status         # Probe channel status
make health         # Gateway health check
make cli CMD="..."  # Run OpenClaw CLI command
make update         # Fetch upstream OpenClaw, merge, rebuild
make backup         # Local tar.gz backup of data/ (keeps last 7)
make snapshot       # Local backup + Hetzner API snapshot (keeps last 5)
make security-check # Audit VPS security posture
make up-proxy       # Start gateway + Caddy (requires DOMAIN in .env)
```

## Key files

| File | Purpose |
|------|---------|
| `config/openclaw.example.json` | OpenClaw config template. `setup.sh` copies to `data/config/openclaw.json` and injects `TELEGRAM_USER_ID` from `.env` |
| `config/Caddyfile` | Caddy reverse proxy config (uses `$DOMAIN` env var) |
| `scripts/setup.sh` | Idempotent setup: generates .env, copies config, sets chmod 600, builds image. Safe to re-run. |
| `scripts/deploy.sh` | Validates required env vars, builds, restarts, waits for healthy container, runs `openclaw doctor` |
| `scripts/harden-vps.sh` | One-shot VPS hardening: SSH key-only, no root login, UFW (SSH+80+443), fail2ban, unattended-upgrades, creates `deploy` user |
| `scripts/security-check.sh` | Audits SSH, firewall, fail2ban, .env permissions, exposed ports, Docker state |
| `scripts/backup.sh` | Local tar.gz + optional Hetzner snapshot via API (reads `.env.infra` or prompts at runtime) |

## Working with the submodule

```bash
# Update from upstream OpenClaw
cd tango-openclaw && git fetch upstream && git merge upstream/main --no-edit && cd ..
docker compose build && docker compose up -d tango-gateway
git add tango-openclaw && git commit -m "chore: update openclaw submodule"
```

The submodule has two remotes: `origin` (Lucas's fork) and `upstream` (openclaw/openclaw).

## Security constraints

- Gateway binds to `127.0.0.1` only — access via SSH tunnel or Caddy reverse proxy
- Telegram allowlist (`dmPolicy: allowlist`) — only responds to the configured `TELEGRAM_USER_ID`
- Groups disabled (`groupPolicy: disabled`)
- Agent `tango`: `messaging` profile + `memory` + `web`; `exec` denied; `elevated` disabled
- Agent `dev`: `coding` profile + `fs` + `runtime` + `exec`; isolated workspace; no direct Telegram access
- Container runs as non-root user `node` (uid 1000); `data/` must be owned by 1000:1000 on VPS
- `.env` and `openclaw.json` are chmod 600 (set by setup.sh)

## Known OpenClaw issues to be aware of

- **Memory leak**: Gateway grows from 1.8GB to 4-6GB over days. Memory limit is 4G in compose. Use `make restart` periodically.
- **CVE-2026-25253** (CVSS 8.8): WebSocket hijacking → RCE. Fixed in v2026.1.29+. Our submodule is on a patched version.
- **ClawHub supply chain**: ~20% of ClawHub skills are malicious. Never install external skills without auditing. Our config denies automation/runtime tool groups.
- **API keys in plain text**: OpenClaw stores keys unencrypted in `openclaw.json`. Mitigated with chmod 600.
- **Bun is experimental**: Not production-ready for gateway (WhatsApp/Telegram bugs). Always use Node.
- **CPU spike on startup**: OpenClaw loads all channel SDKs regardless of config. Expected behavior, not a bug in our setup.
- **Single-operator trust model**: One trusted operator per gateway. Not designed for multi-tenant.

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
