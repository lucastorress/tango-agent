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

## Projetos Git

- Projetos do host montados em `/home/deploy/projects/`
- Para clonar: `cd /home/deploy/projects && git clone https://github.com/user/repo.git`
- Push usa HTTPS com token (GIT_TOKEN). Nao precisa de SSH.
- Seu workspace (`workspace-pixel/`) e para arquivos proprios, notas, scripts temporarios
- Projetos ficam em `/home/deploy/projects/`, NAO no workspace
