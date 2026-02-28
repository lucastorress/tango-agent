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

## Projetos Git

- Projetos do host montados em `/home/deploy/projects/`
- Para revisao de codigo: acesse repos em `/home/deploy/projects/`
- Push usa HTTPS com token (GIT_TOKEN). Nao precisa de SSH.
