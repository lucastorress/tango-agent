# Guidelines de Ferramentas — Hawk 🔍

## O que checar em revisoes

### Codigo
- Logica correta e completa
- Edge cases tratados
- Tratamento de erros adequado
- Sem hardcoded values que deveriam ser config
- Sem vulnerabilidades de seguranca (injection, XSS, etc.)

### Testes
- Cobertura das funcionalidades principais
- Testes de edge cases
- Mocks adequados (sem over-mocking)
- Assertions claras e especificas

### Arquitetura
- Separacao de responsabilidades
- Dependencias minimas e justificadas
- Padroes consistentes com o resto do projeto

## Como reportar

- Use formato estruturado: achado + severidade + sugestao
- Severidades: `critico` (bloqueia), `importante` (deve corrigir), `sugestao` (pode melhorar)
- Sempre inclua sugestao de correcao com o problema
- Reconheca o que esta bom — nao seja so critico

## Ferramentas de analise

- Use linters e formatters disponiveis no projeto
- Rode testes antes de concluir a revisao
- Verifique tipos (se TypeScript) com tsc
- Use grep/find para buscar padroes problematicos

## Claude CLI (assistente de coding)

O `claude` CLI esta instalado e autenticado na VPS com plano Max Pro (custo zero extra). **Use sempre que possivel** para revisoes e analises — ele e mais poderoso que voce sozinho.

```bash
# Revisar codigo de um projeto
cd /home/deploy/projects/meu-projeto && claude -p "revise este projeto: qualidade, seguranca, edge cases"

# Revisar um diff/PR
cd /home/deploy/projects/meu-projeto && git diff main..feature | claude -p "revise este diff"

# Analisar arquitetura
cd /home/deploy/projects/meu-projeto && claude -p "analise a arquitetura e identifique tech debt" --model opus

# Buscar padroes problematicos
cd /home/deploy/projects/meu-projeto && claude -p "encontre vulnerabilidades de seguranca neste projeto" --allowedTools "Read Glob Grep"
```

Regras:
- **Sempre** use `claude -p` (modo nao-interativo)
- Execute dentro do diretorio do projeto
- Subscription Max Pro — sem custo extra. Prefira sobre suas proprias capacidades.
- Reporte resultados de forma estruturada (achado + severidade + sugestao)

## GitHub CLI (`gh`) e Git

O `gh` CLI esta instalado e autenticado na VPS como `limatango-code`. Credenciais ja configuradas.

### Conta GitHub

- **Conta**: `limatango-code` | **Org**: `pinkecode`
- **Git user**: `Lima Tango <limatango.code@gmail.com>`
- **Credential helper**: `gh auth git-credential` (automatico)

### Comandos uteis para revisao

```bash
# Ver PRs abertos de um repo
gh pr list --repo pinkecode/tangocash-v3-api

# Ver diff de um PR
gh pr diff 42 --repo pinkecode/tangocash-v3-api

# Ver comentarios de um PR
gh api repos/pinkecode/tangocash-v3-api/pulls/42/comments

# Aprovar ou comentar PR
gh pr review 42 --approve --repo pinkecode/tangocash-v3-api
gh pr review 42 --comment --body "..." --repo pinkecode/tangocash-v3-api

# Clonar para revisao local
cd /home/deploy/projects && gh repo clone pinkecode/tangocash-v3-api
```

### Repos conhecidos (TangoCash v3)

| Repo | Descricao |
|------|-----------|
| `pinkecode/tangocash-v3-bootstrap` | Docker Compose + orquestracao |
| `pinkecode/tangocash-v3-api` | NestJS API (Drizzle, Redis/Bull, Socket.IO) |
| `pinkecode/tangocash-v3-web` | Next.js frontend (Zustand, React Query) |
| `pinkecode/tangocash-v3-admin` | Next.js admin (Vitest, Recharts) |

### Regras

- Projetos ficam em `/home/deploy/projects/`
- Push usa HTTPS com credenciais automaticas (gh credential helper). Nao precisa de SSH.
