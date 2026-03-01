# Lições Aprendidas — Sessão 2026-02-28

## O que funcionou

1. **Multi-provider via OpenRouter** — redução de ~92% nos custos (Sonnet $3/$15 → MiniMax $0.30/$1.20)
2. **Fallback chains** — MiniMax → Kimi → Gemini → Sonnet/Haiku evita travamento por rate limit
3. **Heartbeat com Gemini Flash Lite** — custo desprezível ($0.10/MTok), funciona bem
4. **Compaction safeguard** — auto-resume de sessões longas
5. **Claude CLI na VPS** — agentes coding podem usar `claude -p` com subscription Max Pro (custo zero)
6. **gog (Google Workspace)** — autenticado e funcional para Gmail, Calendar, Drive, Docs
7. **Playwright** — instalado e funcional para web scraping
8. **Execução direta via `claude -p`** — mais eficiente que delegar via Tango para tarefas de coding

## O que NÃO funcionou

### OpenClaw como orquestrador de coding
- **Tango (messaging) tentava spawnar subagentes para coding** — subagentes herdam perfil messaging (sem exec)
- **sessions_spawn vs sessions_send** — Tango confundia as duas ferramentas constantemente
- **Haiku como orquestrador** — modelo muito leve para orquestrar tarefas complexas, perdia contexto
- **Delegação em cadeia** — Tango → Pixel introduzia latência e perda de contexto significativa
- **Subagentes não persistiam memória** — cada sessão começava do zero
- **Paths de workspace** — subagentes rodavam no workspace do pai, não no próprio, causando arquivos não encontrados

### Problemas de sessões
- **Acúmulo de sessões** — crons + delegações criavam dezenas de sessões ativas
- **maxChildrenPerAgent** — não limitava efetivamente (Tango criava sessões diretas, não subagentes)
- **Sessões órfãs** — processos pendentes ficavam rodando indefinidamente
- **archiveAfterMinutes** — não limpava sessões na prática

### Problemas de tools/config
- `group:memory` e `cron` apareciam como "unknown entries" — build desatualizada no VPS
- `agentToAgent` não é uma tool — é uma seção de config, colocar no alsoAllow gerava warning
- **Kimi K2.5 reasoning mode** — causa crash no OpenClaw
- **contextPruning cache-ttl** — só funciona com modelos Anthropic
- **DeepSeek direto** — não funciona com OpenClaw (usar via OpenRouter)

### Pixel como agente de coding (via OpenClaw)
- **Analisava mas não implementava** — ficava planejando e perguntando em vez de executar
- **Não criava branches** — trabalhava em HEAD detached
- **Não commitava** — mudanças se perdiam entre sessões
- **Não salvava memória** — memory/ sempre vazio
- **Criava scripts próprios** — em vez de usar ferramentas existentes (web-scraper.py)
- **MiniMax M2.5 como coding model** — bom em benchmarks, mas fraco em seguir instruções complexas multi-step

### CBSchool scraping
- **Login funcionava** mas navegação pós-login falhava (redirecionamentos JS)
- **Pixel não usava o web-scraper.py** — criava scripts Playwright próprios
- **Credenciais não eram passadas** na delegação
- **URLs não eram encontradas** por problemas de path do workspace

## O que faria diferente

1. **Usar Claude CLI diretamente** em vez de OpenClaw para tarefas de coding — `claude -p` com `--dangerously-skip-permissions` é mais eficiente
2. **Não confiar em orquestração multi-agente** para coding — a cadeia Tango → Pixel introduz muita perda
3. **Manter OpenClaw apenas para messaging** — Tango respondendo no Telegram, lembretes, cron, web search
4. **Coding via Claude Code direto** — rodar `claude` interativo ou `claude -p` na VPS para implementar features
5. **Modelo mais forte para orquestração** — Haiku é insuficiente como orquestrador de tarefas complexas

## Configurações que funcionam (para referência futura)

### LLM Config
```json
{
  "tango": "anthropic/claude-haiku-4-5 → kimi → gemini-flash",
  "atlas": "kimi-k2.5 → gemini-flash → haiku",
  "pixel/hawk/sentinel": "minimax-m2.5 → kimi → gemini-flash → sonnet",
  "heartbeat": "gemini-flash-lite",
  "subagents": "gemini-flash",
  "contextTokens": 32000,
  "compaction": "safeguard",
  "timeout": 90
}
```

### Ferramentas instaladas na VPS
- Node 22 + pnpm
- Claude Code CLI (Max Pro)
- gog CLI (Google Workspace)
- gh CLI (GitHub)
- Playwright + Chromium
- Docker + Compose
- redis-cli, psql
- web-scraper.py

## TangoCash — Status

### PRs abertas
- [PR #4 — API](https://github.com/pinkecode/tangocash-v3-api/pull/4) — 4 commits (leaderboard, WebSocket, N+1, PIX validation)
- [PR #4 — Admin](https://github.com/pinkecode/tangocash-v3-admin/pull/4) — filtros URL, optimistic updates, error messages

### Fase 1 — 19/19 tarefas resolvidas
- 12 já estavam implementadas antes da sessão
- 7 implementadas nesta sessão (via claude -p direto, não via OpenClaw)

### Próximos passos
- Revisar e mergear as PRs
- Fase 2 (UI/UX) — 20 tarefas
- Fase 6 (pré-lançamento) — 25 tarefas (MVP blocker)
