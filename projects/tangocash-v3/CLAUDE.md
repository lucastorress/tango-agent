# TangoCash v3 — Prompt de Desenvolvimento para Tango Agent

> Documento de transferencia de conhecimento para o sistema multi-agente Tango Agent (OpenClaw).
> Atualizado em: 2026-02-28

---

## CONTEXTO DE EXECUCAO — TANGO AGENT

### Ambiente

- **Projeto na VPS**: `/home/deploy/tango-agent/projects/tangocash-v3`
- **Claude CLI**: instalado e autenticado (Max Pro, custo zero)
- **GitHub CLI (`gh`)**: autenticado como `limatango-code` (org `pinkecode`)
- **Google Workspace (`gog`)**: autenticado (para relatorios em Google Docs)
- **Docker**: instalado (v29.2.1 + Compose v5.1.0)
- **PostgreSQL**: rodando via Docker (tangocash-db, porta 5432, user=tangocash, pass=tangocash_dev_123)
- **Redis**: rodando via Docker (tangocash-redis, porta 6379)
- **Node.js**: 22+, npm instalado
- **.env**: configurado nos 3 submodules (API, Web, Admin)
- **Dependencias**: `npm install` ja executado nos 3 submodules
- **redis-cli e psql**: instalados no host

### Agentes

| Agente | Papel | O que faz neste projeto |
|--------|-------|------------------------|
| **Tango** 🥭 | Orquestrador | Recebe tarefas do Lucas, delega, reporta resultados |
| **Pixel** 💻 | Desenvolvedor | Implementa codigo, roda CLI, faz commits |
| **Atlas** 📋 | Pesquisador | Pesquisa tecnica, analise, specs |
| **Hawk** 🔍 | Revisor | Code review, qualidade, testes |
| **Sentinel** 🛡️ | Seguranca | Auditoria, deploy, infra |

### Workflow

1. Lucas manda tarefa no Telegram
2. Tango delega para o agente certo via `sessions_send`
3. Agente executa na VPS usando `claude -p` para coding
4. Agente retorna `[REPORT]`
5. Tango resume resultado para o Lucas

### Regras de Execucao

1. Caminho do projeto: SEMPRE `/home/deploy/tango-agent/projects/tangocash-v3`
2. Use `claude -p` para tarefas de coding (custo zero via subscription)
3. Para tarefas complexas: `claude -p "..." --model opus`
4. Lotes de **3-5 tarefas** por vez (nao tudo de uma vez)
5. Relatorios grandes: criar Google Docs (`gog`)
6. Sempre salvar progresso em `memory/tangocash.md`
7. Fluxo: **Pixel implementa → Hawk revisa → Lucas aprova → proximo lote**
8. Para instalar deps: `cd <submodule> && npm install`
9. Docker + PostgreSQL + Redis estao rodando — pode executar migrations e seeds

### Repos Git (org pinkecode — privados)

| Repo | Descricao |
|------|-----------|
| `pinkecode/tangocash-v3-bootstrap` | Este monorepo (Docker Compose + orquestracao) |
| `pinkecode/tangocash-v3-api` | NestJS API (submodule) |
| `pinkecode/tangocash-v3-web` | Next.js frontend (submodule) |
| `pinkecode/tangocash-v3-admin` | Next.js admin (submodule) |
