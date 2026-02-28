# Mission Control Insights — Aprendizados para o Tango Agent

> Documento de referencia baseado no sistema "Mission Control" do Bhanu Teja P (@pbteja1998),
> que coordena 10 agentes AI autonomos usando OpenClaw. Este arquivo serve como guia de
> implementacao futura para evoluir a arquitetura multi-agente do Tango Agent.
>
> **Fontes originais:**
> - [Tweet viral (3.5M views)](https://x.com/pbteja1998/status/2017662163540971756)
> - [Artigo detalhado — Dan Malone](https://www.dan-malone.com/blog/mission-control-ai-agent-squads)
> - [Thread sobre o squad de 10 agentes](https://x.com/pbteja1998/status/2017495026230775832)

---

## 1. O que e o Mission Control

Um sistema onde **10 agentes AI autonomos** trabalham como um time real, cada um com
papel definido, comunicacao entre si, e ciclo de vida controlado por crons.

### Composicao do squad

| Agente   | Papel                | Responsabilidades                                        |
|----------|----------------------|----------------------------------------------------------|
| Jarvis   | Squad Lead           | Coordena, delega tarefas, monitora progresso             |
| Shuri    | Product Analyst      | Testa edge cases, analisa UX, questiona decisoes         |
| Fury     | Customer Researcher  | Pesquisa reviews (G2, etc.), toda claim precisa de prova |
| Vision   | SEO Analyst          | Analise de SEO, keywords, posicionamento                 |
| Loki     | Content Writer       | Redacao de conteudo (blog, docs)                         |
| Quill    | Social Media Manager | Posts, engajamento, calendario de conteudo               |
| Wanda    | Designer             | Criacao visual, mockups, assets                          |
| Hawkeye  | (spawned por Jarvis) | Agente emergente, criado sob demanda                     |

### Principios de design

1. **Cada agente tem uma unica responsabilidade** — nao faz tudo, faz uma coisa bem
2. **Comunicacao via banco compartilhado** — agentes se @mencionam, discutem, refutam
3. **Sessoes efemeras** — cada cron cria sessao isolada que roda e termina (custo controlado)
4. **AGENTS.md como manual operacional** — cada agente sabe suas regras, ferramentas, limites
5. **Heartbeats escalonados** — agentes acordam em horarios diferentes para nao sobrecarregar

---

## 2. Arquitetura tecnica do Mission Control

### Heartbeat system (cron escalonado)

Cada agente tem um intervalo de heartbeat diferente para distribuir carga:

```
content-lead:        */2 * * * *     (a cada 2 min)
content-writer:      1-59/3 * * * *  (a cada 3 min, offset 1)
content-social:      2-59/4 * * * *  (a cada 4 min, offset 2)
content-researcher:  3-59/5 * * * *  (a cada 5 min, offset 3)
```

**Por que escalonar?** Se todos acordam no mesmo minuto, sobrecarrega a API e gera
competicao por recursos. O offset garante que no maximo 1 agente esta ativo por vez.

### Comunicacao entre agentes

O Mission Control original usa **Convex** (banco de dados real-time). A versao SaaS
(Dan Malone) migrou para **Supabase** com Row-Level Security.

Mecanismo de comunicacao:
- Agentes escrevem em um "feed de atividade" compartilhado
- Usam @mencoes para direcionar mensagens
- Task board (kanban) com estados: Backlog → In Progress → In Review → Done
- Agentes podem criar, reclamar e completar tarefas autonomamente

### Estrutura de arquivos por agente

```
workspace-{agente}/
  IDENTITY.md      # Nome, papel, personalidade
  SOUL.md          # Instrucoes profundas de comportamento
  AGENTS.md        # Manual operacional: ferramentas, memoria, comunicacao
  memory/          # Memoria persistente do agente
```

O **AGENTS.md** e o diferencial — ele define:
- Onde arquivos sao armazenados
- Como a memoria funciona
- Quais ferramentas estao disponiveis
- Quando falar vs ficar quieto
- Como usar o Mission Control (task board, mencoes)
- Protocolos de comunicacao com outros agentes

### Controle de custo

- Sessoes efemeras: heartbeat acorda, faz o trabalho, sessao termina
- Modelo mais barato para tarefas de rotina (heartbeat check-in)
- Modelo mais capaz apenas para tarefas complexas delegadas
- Context window reduzido para heartbeats (nao precisa de historico longo)

---

## 3. Comparacao: Tango Agent atual vs Mission Control

### O que ja temos

| Aspecto                     | Tango Agent             | Mission Control         | Status    |
|-----------------------------|-------------------------|-------------------------|-----------|
| Multi-agente                | 2 (tango + dev)         | 10 agentes              | Parcial   |
| Agent-to-agent              | Habilitado              | Habilitado              | OK        |
| Heartbeat (tango)           | 4min, 8h-24h            | 2-5min escalonados      | OK        |
| Heartbeat (dev)             | Desabilitado            | Habilitado              | A fazer   |
| IDENTITY.md / SOUL.md       | Sim                     | Sim                     | OK        |
| AGENTS.md                   | Nao tem                 | Sim                     | A fazer   |
| Task board compartilhado    | Nao tem                 | Convex/Supabase         | A fazer   |
| Cron para tarefas           | Habilitado, nao usado   | Usado ativamente        | A fazer   |
| Subagents (dev)             | Desabilitado            | Habilitado              | A avaliar |
| Workspace isolado por agente| Sim                     | Sim                     | OK        |
| Memoria persistente         | Sim                     | Sim                     | OK        |
| Comunicacao estruturada     | Agent-to-agent direto   | Feed + @mencoes + tasks | A fazer   |

### O que nos diferencia (e devemos manter)

- **Seguranca**: nosso setup e mais restritivo (allowlist, deny de exec no tango, loopback)
- **Simplicidade**: 2 agentes com papeis claros vs 10 agentes que podem gerar overhead
- **Custo**: Haiku como primary no tango e uma decisao acertada para o dia-a-dia
- **Operador unico**: nao precisamos de multi-tenancy nem RLS

---

## 4. Plano de implementacao — Por fase

### Fase 1: Fundamentos (esforco baixo, impacto alto)

#### 1.1 Criar AGENTS.md nos workspaces

Criar `data/workspace/AGENTS.md` (tango) e `data/workspace-dev/AGENTS.md` (dev) com:

**Para o tango (`data/workspace/AGENTS.md`):**
```markdown
# Manual Operacional — Tango

## Seu papel
Voce e o assistente pessoal do Lucas via Telegram. Voce coordena, responde,
pesquisa e delega tarefas tecnicas para o agente `dev`.

## Ferramentas disponiveis
- Messaging (Telegram)
- Memory (leitura e escrita)
- Web (busca e fetch)
- Agent-to-agent (comunicacao com `dev`)

## Ferramentas NEGADAS
- Execucao de comandos (exec)
- Automacao (group:automation)
- Runtime (group:runtime)

## Quando delegar para `dev`
- Qualquer tarefa que envolva codigo, git, ou manipulacao de arquivos
- Debug de erros tecnicos
- Atualizacoes de dependencias ou submodulos

## Quando agir sozinho
- Conversas, perguntas, pesquisas
- Lembretes e acompanhamentos
- Resumos e analises de conteudo

## Memoria
- Diretorio: memory/
- Use memoria para guardar contexto entre sessoes
- Nao armazene dados sensiveis (tokens, senhas)

## Comunicacao
- Responda sempre em portugues brasileiro
- Seja direto, util, sem enrolacao
- Nao envie mensagens sem contexto relevante
```

**Para o dev (`data/workspace-dev/AGENTS.md`):**
```markdown
# Manual Operacional — Dev

## Seu papel
Voce e o agente de desenvolvimento. Executa tarefas tecnicas delegadas pelo
tango ou pelo operador. Nunca fala diretamente no Telegram.

## Ferramentas disponiveis
- Coding (leitura/escrita de codigo)
- File system (group:fs)
- Runtime (group:runtime)
- Exec (execucao de comandos)
- Agent-to-agent (comunicacao com `tango`)

## Quando responder
- Somente quando receber uma tarefa via agent-to-agent
- Sempre reporte o resultado de volta ao tango

## Quando ficar quieto
- Nao inicie conversas por conta propria
- Nao envie mensagens no Telegram

## Workspace
- Diretorio de trabalho: workspace-dev/
- Memoria: workspace-dev/memory/
- Todo o trabalho deve ficar dentro do seu workspace
```

#### 1.2 Configurar crons uteis

Adicionar ao `openclaw.json`, na configuracao de cada agente:

**Tango — resumo diario e check de lembretes:**
```json
{
  "cron": [
    {
      "id": "daily-summary",
      "schedule": "0 22 * * *",
      "prompt": "Faca um resumo do que aconteceu hoje. Verifique lembretes pendentes para amanha. Envie no Telegram.",
      "model": "haiku"
    },
    {
      "id": "morning-briefing",
      "schedule": "0 8 * * 1-5",
      "prompt": "Bom dia! Verifique lembretes para hoje e tarefas pendentes. Envie um briefing matinal no Telegram.",
      "model": "haiku"
    }
  ]
}
```

**Dev — health check periodico:**
```json
{
  "cron": [
    {
      "id": "health-check",
      "schedule": "0 */6 * * *",
      "prompt": "Verifique a saude do sistema: uso de memoria do container, espaco em disco, status dos servicos. Registre na memoria se houver algo anormal.",
      "model": "haiku"
    }
  ]
}
```

> **Nota:** Verificar a sintaxe exata de cron no OpenClaw antes de implementar.
> A documentacao pode usar formato diferente do crontab padrao.

---

### Fase 2: Comunicacao estruturada (esforco medio)

#### 2.1 Task board simples via arquivo compartilhado

Criar `data/shared/tasks.md` (volume montado em ambos os workspaces) com formato:

```markdown
# Task Board

## Backlog
- [ ] #001 Atualizar submodule do OpenClaw para ultima versao
- [ ] #002 Revisar configuracao de rate limiting

## Em Progresso
- [~] #003 Investigar uso de memoria do gateway @dev

## Concluido
- [x] #000 Setup inicial do Tango Agent @tango 2026-02-27
```

Convencoes:
- `- [ ]` = backlog, `- [~]` = em progresso, `- [x]` = concluido
- `@agente` = quem esta responsavel
- `#NNN` = ID sequencial da task
- Qualquer agente pode criar, reclamar ou completar tasks

#### 2.2 Protocolo de comunicacao entre agentes

Definir no AGENTS.md de ambos um protocolo padrao:

```markdown
## Protocolo de comunicacao agent-to-agent

Ao enviar mensagem para outro agente, use o formato:
- **[TASK]** Para delegar uma tarefa com ID do task board
- **[REPORT]** Para reportar resultado de uma tarefa
- **[QUESTION]** Para tirar uma duvida
- **[INFO]** Para compartilhar informacao sem exigir acao

Exemplo: "[TASK] #003 — Investigar por que o gateway esta usando 3.5GB de RAM"
Exemplo: "[REPORT] #003 — Memoria alta causada por acumulo de sessoes. Reiniciei o container."
```

---

### Fase 3: Evolucao do squad (esforco alto, longo prazo)

#### 3.1 Habilitar heartbeat no dev

Quando tivermos tarefas automaticas para o dev, habilitar heartbeat com intervalo longo:

```json
{
  "id": "dev",
  "heartbeat": {
    "enabled": true,
    "intervalMinutes": 30,
    "activeHours": { "start": 6, "end": 23 }
  }
}
```

O heartbeat do dev deve:
1. Checar o task board por tarefas atribuidas a ele
2. Executar tarefas pendentes
3. Reportar resultados de volta ao tango
4. Verificar saude do sistema

#### 3.2 Habilitar subagents no dev

Para tarefas complexas, permitir que dev crie sub-agentes:

```json
{
  "id": "dev",
  "subagents": {
    "enabled": true,
    "maxSpawnDepth": 1,
    "maxConcurrent": 1
  }
}
```

Caso de uso: dev recebe tarefa de refatorar codigo — spawna um sub-agente para
pesquisar best practices enquanto ele implementa.

#### 3.3 Adicionar novos agentes especializados

Quando o volume de tarefas justificar, considerar:

| Agente    | Papel                  | Modelo    | Heartbeat | Caso de uso                        |
|-----------|------------------------|-----------|-----------|------------------------------------|
| `writer`  | Criacao de conteudo    | Sonnet    | 15min     | Blog posts, documentacao           |
| `research`| Pesquisa aprofundada   | Sonnet    | 30min     | Analise de mercado, concorrencia   |
| `monitor` | Monitoramento/alertas  | Haiku     | 5min      | Uptime, custos, anomalias          |

**Importante:** Cada novo agente precisa de:
- Entrada no `agents.list[]` do `openclaw.json`
- Workspace isolado (`data/workspace-{agente}/`)
- Arquivos de bootstrap (`IDENTITY.md`, `SOUL.md`, `AGENTS.md`)
- Definicao de ferramentas permitidas/negadas
- Heartbeat configurado com offset (escalonado)
- Entrada no `agentToAgent.allow[]`

---

## 5. Licoes-chave do Mission Control

### O que deu certo
1. **Separacao de responsabilidades** funciona — agentes focados sao mais eficazes
2. **Heartbeats escalonados** evitam sobrecarga e reduzem custo
3. **AGENTS.md como manual** reduz "alucinacao de papel" — o agente sabe seus limites
4. **Task board compartilhado** elimina a necessidade do humano fazer micro-management
5. **Sessoes efemeras** controlam custo — heartbeat nao precisa de historico longo

### O que deu errado / cuidados
1. **Agentes geram muitas tarefas** — Bhanu comentou que os agentes geram mais trabalho
   do que conseguem executar. Pode precisar de limites.
2. **Prompt do heartbeat precisa de cuidado** — OpenClaw tende a responder rapido sem
   executar as acoes follow-up. O prompt do heartbeat precisa ser assertivo.
3. **Custo escala rapido** — 10 agentes com heartbeat de 2-5min consome bastante API.
   Para nosso caso (operador unico), 2-3 agentes e suficiente.
4. **Complexidade operacional** — mais agentes = mais pontos de falha. Comecar pequeno e
   evoluir conforme a necessidade real.

### Regra de ouro
> "Nao adicione agentes porque pode. Adicione porque a tarefa exige."
>
> Comece com o minimo (tango + dev), valide o fluxo de comunicacao e tasks,
> e so entao considere expandir o squad.

---

## 6. Checklist de implementacao

- [ ] **Fase 1.1** — Criar `AGENTS.md` no workspace do tango
- [ ] **Fase 1.1** — Criar `AGENTS.md` no workspace do dev
- [ ] **Fase 1.2** — Configurar cron de resumo diario (tango)
- [ ] **Fase 1.2** — Configurar cron de briefing matinal (tango)
- [ ] **Fase 1.2** — Configurar cron de health check (dev)
- [ ] **Fase 2.1** — Criar `data/shared/tasks.md` e montar volume
- [ ] **Fase 2.2** — Documentar protocolo de comunicacao nos AGENTS.md
- [ ] **Fase 3.1** — Habilitar heartbeat no dev
- [ ] **Fase 3.2** — Habilitar subagents no dev
- [ ] **Fase 3.3** — Avaliar necessidade de novos agentes

---

*Documento criado em 2026-02-27. Baseado na analise do Mission Control (Bhanu Teja P)
e adaptado para o contexto do Tango Agent (operador unico, Hetzner VPS, 2 agentes).*
