# Guidelines de Ferramentas — Pixel 💻

## Exec seguro

- Sempre valide o comando antes de executar
- Nunca execute comandos destrutivos sem confirmacao (rm -rf, drop, etc.)
- Use `--dry-run` quando disponivel para validar antes de aplicar
- Limite o escopo: opere dentro do workspace designado

## Git workflow

- Commits atomicos: um commit por mudanca logica
- Mensagens no formato convencional: `feat:`, `fix:`, `chore:`, `docs:`
- Sempre verifique `git status` antes de commitar
- Nao force push sem justificativa

## Convencoes de codigo

- Siga o estilo existente do projeto (indentacao, naming, etc.)
- Codigo limpo > codigo clever
- Nomes descritivos para variaveis e funcoes
- Evite comentarios obvios — o codigo deve ser auto-explicativo
- Trate erros adequadamente, nao silencie exceptions

## Testes

- Escreva testes para funcionalidades novas
- Rode testes existentes antes de reportar conclusao
- Se um teste quebrar, corrija ou reporte com contexto

## Claude CLI (assistente de coding)

O `claude` CLI esta instalado e autenticado na VPS com plano Max Pro. Use-o para tarefas complexas de coding que se beneficiam de um modelo mais poderoso (Opus/Sonnet).

### SEMPRE use o Claude CLI para tarefas de coding

O Claude CLI roda com subscription Max Pro (custo zero extra), enquanto suas chamadas normais consomem API key paga. **Prefira sempre o Claude CLI** para qualquer tarefa que envolva:

- Escrever, editar ou refatorar codigo
- Analisar codebase ou arquitetura
- Gerar testes, documentacao, configs
- Revisar PRs ou diffs
- Pesquisar em projetos grandes
- Qualquer tarefa que voce faria sozinho mas o Claude CLI faz melhor

### Como usar

```bash
# Prompt simples (nao-interativo, retorna resposta)
claude -p "analise este arquivo e sugira melhorias"

# Com contexto de projeto (RECOMENDADO - entra no dir antes)
cd /home/deploy/projects/meu-projeto && claude -p "explique a arquitetura"

# Passando arquivo como input
cat arquivo.ts | claude -p "refatore para usar async/await"

# Modelo especifico (opus para tarefas complexas)
claude -p "revise a seguranca deste codigo" --model opus

# Output estruturado
claude -p "liste os endpoints da API" --output-format json

# Com ferramentas habilitadas (leitura de arquivos, etc)
cd /home/deploy/projects/meu-projeto && claude -p "leia o README e resuma" --allowedTools "Read Glob Grep"
```

### Regras

- **Sempre** use `claude -p` (modo print/nao-interativo) — nunca modo interativo
- Execute dentro do diretorio do projeto (`cd projeto && claude -p ...`)
- O CLI usa subscription Max Pro — **sem custo extra**. Prefira sobre suas proprias capacidades.
- Reporte o resultado pro Tango de forma resumida, nao copie output bruto.

## GitHub CLI (`gh`) e Git

O `gh` CLI esta instalado e autenticado na VPS como `limatango-code`. Credenciais ja configuradas — nao precisa de setup manual.

### Conta GitHub

- **Conta**: `limatango-code`
- **Organizacao**: `pinkecode` (repos privados do TangoCash)
- **Auth**: `gh auth` via token (GIT_TOKEN do .env)
- **Git user**: `Lima Tango <limatango.code@gmail.com>`
- **Credential helper**: `gh auth git-credential` (automatico para HTTPS)

### Comandos uteis

```bash
# Listar repos da org
gh repo list pinkecode

# Clonar repo privado (credenciais automaticas)
cd /home/deploy/projects && gh repo clone pinkecode/tangocash-v3-api

# Criar PR
cd /home/deploy/projects/meu-projeto && gh pr create --title "feat: description" --body "..."

# Ver PRs abertos
gh pr list --repo pinkecode/tangocash-v3-api

# Ver issues
gh issue list --repo pinkecode/tangocash-v3-api

# Push (credenciais automaticas via gh)
git push origin feature/minha-branch
```

### Repos conhecidos (TangoCash v3)

| Repo | Descricao |
|------|-----------|
| `pinkecode/tangocash-v3-bootstrap` | Docker Compose + orquestracao |
| `pinkecode/tangocash-v3-api` | NestJS API (Drizzle, Redis/Bull, Socket.IO) |
| `pinkecode/tangocash-v3-web` | Next.js frontend (Zustand, React Query) |
| `pinkecode/tangocash-v3-admin` | Next.js admin (Vitest, Recharts) |

### Regras

- Projetos ficam em `/home/deploy/projects/`, NAO no workspace
- Seu workspace (`workspace-pixel/`) e para arquivos proprios, notas, scripts temporarios
- Push usa HTTPS com credenciais automaticas (gh credential helper). Nao precisa de SSH.
- Sempre verifique `git status` antes de commitar
- Nao force push sem justificativa

## Google Workspace (`gog`)

O `gog` CLI esta autenticado com `limatango.code@gmail.com`. Use para Gmail, Calendar, Drive e Docs.

### Google Docs (relatorios, documentacao)

```bash
# Criar doc
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog docs create "Titulo do Documento" -a limatango.code@gmail.com

# Escrever conteudo (aceita markdown)
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog docs write <docId> "conteudo aqui" -a limatango.code@gmail.com

# Inserir conteudo adicional
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog docs insert <docId> "mais conteudo" -a limatango.code@gmail.com

# Ler doc
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog docs cat <docId> -a limatango.code@gmail.com

# Listar docs no Drive
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog drive ls -a limatango.code@gmail.com
```

### Gmail

```bash
# Buscar emails
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog gmail search "is:unread" -a limatango.code@gmail.com

# Ler email
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog gmail read <messageId> -a limatango.code@gmail.com
```

### Calendar

```bash
# Ver eventos de hoje
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog calendar list -a limatango.code@gmail.com

# Criar evento
GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD gog calendar create "Reuniao" --start "2026-03-01T10:00:00" --end "2026-03-01T11:00:00" -a limatango.code@gmail.com
```

### Regras do gog

- **Sempre** passe `GOG_KEYRING_PASSWORD=$GOG_KEYRING_PASSWORD` e `-a limatango.code@gmail.com`
- O link do Google Doc e `https://docs.google.com/document/d/<docId>/edit` — envie esse link ao Tango
- **NAO existe** `gog drive share` — docs criados ja ficam acessiveis pela conta
- Para relatorios grandes: crie Google Doc em vez de mandar texto longo no Telegram
