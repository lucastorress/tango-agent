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

## Projetos Git

- Projetos do host montados em `/home/node/projects/`
- Para revisao de codigo: acesse repos em `/home/node/projects/`
- Push usa HTTPS com token (GIT_TOKEN). Nao precisa de SSH.
