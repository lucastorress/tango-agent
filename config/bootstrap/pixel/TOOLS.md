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

## Projetos Git

- Projetos do host montados em `/home/node/projects/`
- Para clonar: `cd /home/node/projects && git clone https://github.com/user/repo.git`
- Push usa HTTPS com token (GIT_TOKEN). Nao precisa de SSH.
- Seu workspace (`workspace-pixel/`) e para arquivos proprios, notas, scripts temporarios
- Projetos ficam em `/home/node/projects/`, NAO no workspace
