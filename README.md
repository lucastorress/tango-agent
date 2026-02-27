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

# Setup (cria .env, diretorios, builda imagem)
make setup

# Editar .env com suas API keys
# - ANTHROPIC_API_KEY
# - TELEGRAM_BOT_TOKEN

# Subir o gateway
make up

# Ver logs
make logs
```

## Comandos (Makefile)

| Comando        | Descricao                                      |
|----------------|-------------------------------------------------|
| `make build`   | Builda a imagem Docker                          |
| `make up`      | Sobe o gateway em background                    |
| `make down`    | Para todos os containers                        |
| `make logs`    | Acompanha logs do gateway                       |
| `make status`  | Verifica status dos canais                      |
| `make health`  | Verifica saude do gateway                       |
| `make cli`     | Abre o CLI do OpenClaw (ex: `make cli CMD=...`) |
| `make setup`   | Executa setup inicial                           |
| `make deploy`  | Build + restart com validacao                   |
| `make update`  | Atualiza OpenClaw do upstream e rebuilda        |

## Atualizar OpenClaw

```bash
make update
# Depois commitar o submodule atualizado:
git add tango-openclaw && git commit -m "chore: update openclaw submodule"
```

## Acesso via SSH Tunnel (VPS)

```bash
ssh -L 18789:127.0.0.1:18789 user@seu-vps
# Em outro terminal:
openclaw gateway connect ws://127.0.0.1:18789 --token SEU_TOKEN
```

## Estrutura

```
tango-agent/
├── .env.example                # Template de configuracao
├── docker-compose.yml          # Compose principal
├── Makefile                    # Atalhos operacionais
├── scripts/
│   ├── setup.sh                # Setup inicial
│   └── deploy.sh               # Deploy com validacao
├── config/
│   └── openclaw.example.json   # Template de config OpenClaw
└── tango-openclaw/             # [submodule] OpenClaw
```
