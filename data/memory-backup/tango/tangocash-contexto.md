# TangoCash — Contexto para Delegacao

## Onde esta o projeto
/home/deploy/tango-agent/projects/tangocash-v3

## CLAUDE.md
O arquivo CLAUDE.md neste diretorio contem TODA a documentacao do projeto:
- Arquitetura, stack, modelo de dados
- Plano de execucao (117 tarefas, 6 fases)
- Instrucoes detalhadas por tarefa
- Regras de codigo, testes, commits
- Endpoints da API

## Como delegar tarefas do TangoCash

Ao delegar para o Pixel, SEMPRE inclua:

[TASK] <descricao da tarefa>

Leia o CLAUDE.md em /home/deploy/tango-agent/projects/tangocash-v3/CLAUDE.md antes de comecar.
Projeto em: /home/deploy/tango-agent/projects/tangocash-v3
Use claude -p para implementar (custo zero).
Salve progresso em memory/tangocash.md.

## Ambiente disponivel
- Docker + PostgreSQL + Redis rodando
- npm install ja feito nos 3 submodules
- .env configurado
- Pode rodar: migrations, seeds, testes, builds

## Plano de execucao
Plano completo em memory/tangocash-plano-evolucao.md
MVP = Fase 1 (tech debt) + Fase 6 (pre-lancamento)
Executar em lotes de 3-5 tarefas: Pixel implementa → Hawk revisa → Lucas aprova
