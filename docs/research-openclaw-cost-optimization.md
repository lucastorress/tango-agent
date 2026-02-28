# Pesquisa: Otimização de Custos OpenClaw

> Compilado em 2026-02-28. Fontes: artigo Medium (@rentierdigital) + vídeo YouTube (FuturMinds).

---

## Fonte 1: Artigo Medium — "Anthropic Just Killed My $200/Month OpenClaw Setup"

**URL**: https://freedium-mirror.cfd/https://medium.com/@rentierdigital/anthropic-just-killed-my-200-month-openclaw-setup-so-i-rebuilt-it-for-15-9cab6814c556

### Contexto
- Autor usava OpenClaw com **Claude Max ($200/mês)** via OAuth por 6 semanas
- Consumia ~$1000+/mês em tokens pagando $200 flat-rate
- Anthropic **baniu a conta** (HTTP 403) por "violar ToS" — enforcement contra harness não autorizado do Claude Code
- Reconstruiu o setup inteiro por ~$15-20/mês

### Arquitetura reconstruída

| Componente | Custo/mês |
|------------|-----------|
| VPS Hostinger (primária, template OpenClaw) | $6.99 |
| VPS Hetzner (standby/redundância) | €4.50 |
| Kimi K2.5 via Moonshot API (modelo principal) | €3.20 |
| MiniMax M2.5 (batch tasks) | €1.87 |
| Gemini 3 Flash via OpenRouter (sub-agentes) | €0.94 |
| GLM-4.7-Flash (heartbeat/trivial) | grátis |
| **Total** | **~$15-20** |

### Destaques técnicos
- Rede privada entre VPS via **Tailscale** (monitoramento mútuo com failover)
- **Roteamento inteligente**: cada tipo de tarefa vai pro modelo mais custo-eficiente
- **Modelo gratuito** (GLM-4.7-Flash) para heartbeat/tarefas triviais
- Substituiu **20 workflows n8n** por instruções em linguagem natural nos agentes
- Deploy com Docker compose padrão do OpenClaw
- Redução total: **92%** ($200 → $15-20)

### Lições relevantes
1. **Claude Max OAuth é arriscado** — Anthropic está banindo heavy users
2. **API key direta (pay-per-use) é seguro** — não viola ToS
3. **Multi-provider com fallback chain** elimina vendor lock-in
4. **Modelo gratuito para heartbeat** é prático e funciona bem
5. **Hostinger oferece template OpenClaw** pré-instalado

---

## Fonte 2: Vídeo YouTube — "I Cut My OpenClaw Costs by 90%"

**Canal**: FuturMinds
**URL**: https://www.youtube.com/watch?v=YY1qFOlsGxo
**Duração**: ~6 min | **70 comentários analisados**

### As 3 otimizações

#### Otimização 1: Modelo primário Kimi K2.5 (Moonshot AI)
- 1 trilhão de parâmetros, open-source (lançado jan/2026)
- Custo: **$0.60 input / $3.00 output** por 1M tokens
- Claude Sonnet 4.5: $3 input / $15 output → Kimi é **5x mais barato**
- Na prática é ~2x mais verboso, ficando **~4x mais barato** no uso real
- Supera Claude Opus em benchmarks agentic (HLE-Full: 50.2% vs Opus 43.2%)
- Suporta até 100 subagentes paralelos, 256K context window
- API: `platform.moonshot.ai`
- **Reasoning mode (`reasoning: true`) causa bug no OpenClaw** — manter desativado por enquanto
- NVIDIA oferece Kimi K2.5 grátis mas é 5-10x mais lento (inviável em produção)

Config de provider:
```json
"models": {
  "moonshot": {
    "baseUrl": "https://api.moonshot.ai/v1",
    "apiKey": "<MOONSHOT_API_KEY>"
  }
}
```

Modelo primário:
```json
"agents": {
  "defaults": {
    "model": "moonshot/kimi-k2.5"
  }
}
```

#### Otimização 2: Heartbeat com Gemini Flash Lite
- Modelo: `google/gemini-2.0-flash-lite`
- Custo: **$0.075/1M tokens** — **60x mais barato** que Sonnet
- Heartbeat é apenas check "estou vivo", não precisa de inteligência
- Funciona perfeitamente com modelo ultra-barato

Config:
```json
"models": {
  "google": {
    "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
    "apiKey": "<GEMINI_API_KEY>"
  }
}
```

```json
"agents": {
  "defaults": {
    "heartbeat": {
      "model": "google/gemini-2.0-flash-lite"
    }
  }
}
```

Requer `GEMINI_API_KEY` nas environment variables.

#### Otimização 3: Compaction mode "safeguard"
- **Problema**: sessões acumulam histórico, custo cresce exponencialmente
  - 10 mensagens → ~20k tokens → $0.06/query
  - 50 mensagens → ~100k tokens → $0.30/query
  - 100 mensagens → ~200k tokens → $0.60/query (10x mais caro para a mesma pergunta)
- **Safeguard** resume mensagens antigas automaticamente, mantém recentes intactas, preserva qualidade do contexto

Config:
```json
"agents": {
  "defaults": {
    "compaction": {
      "mode": "safeguard",
      "model": "moonshot/kimi-k2.5"
    }
  }
}
```

### Custo final do autor do vídeo
- Antes: ~$519/mês (Claude Sonnet 4.5)
- Depois: ~$15-20/mês (Kimi K2.5 + 3 otimizações)
- **Redução: ~90-97%**

---

## Insights dos comentários (70 comentários)

### Problemas técnicos reportados
- **DeepSeek não funciona direto** com OpenClaw — mangles o model name. Alternativa: OpenRouter (mas adiciona middleman). Um usuário migrou pro **Agent Zero** que tem suporte nativo
- **`contextPruning` mode "adaptive" quebrou** em versões recentes do OpenClaw → usar `cache-ttl` com ttl `120m`
- **Compaction bugada no Telegram** — não compacta conversas de Telegram em algumas versões
- **Kimi K2.5 `reasoning: true`** causa erro "Message ordering conflict" — manter false
- **Config reload** pode falhar com `contextPruning.mode: Invalid input` se usar mode depreciado

### Dicas da comunidade
- Um usuário usa **OpenAI embeddings para memory vector** + Gemini Flash heartbeat + Kimi K2.5 principal — combo eficiente
- Para **dados sensíveis**, não usar Moonshot (empresa chinesa) — ficar com Claude/OpenAI/Gemini
- **Mac M2 8GB RAM** roda OpenClaw (recomendado sandbox/Docker com acesso limitado)
- Um usuário pediu pro próprio OpenClaw se otimizar e ele sugeriu as mesmas otimizações automaticamente
- **Ollama local** funciona para heartbeat mas exige VPS mais potente (custo anula a economia)
- **Subagentes** são mini instâncias que o OpenClaw cria para tarefas paralelas — mais = mais rápido mas mais caro

### Alternativas mencionadas
- **Agent Zero**: suporte nativo a DeepSeek, mais fácil de configurar
- **Ollama**: modelos locais gratuitos, mas requer hardware mais potente
- **OpenRouter**: middleman para acessar qualquer modelo, mas adiciona custo e latência
- **MiniMax M2.1**: pode ser ainda mais barato que Kimi K2.5 (mencionado por um usuário)

---

## Aplicabilidade ao Tango Agent

### Aplicável imediatamente
1. **Heartbeat com Gemini Flash Lite** — Tango roda heartbeat a cada 30min com Sonnet/Haiku. Trocar por Gemini Flash Lite (~$0.075/1M tokens) economizaria significativamente
2. **Compaction safeguard** — verificar config atual e habilitar se não estiver ativo
3. **Budget limits por provider** — configurar limites mensais no Moonshot/Anthropic para prevenir surpresas

### Considerar no futuro
1. **Kimi K2.5 como modelo alternativo/fallback** — mais barato que Haiku, boa performance agentic
2. **Modelo mais barato para subagentes** — subagentes spawned pelo Tango poderiam usar modelo mais barato
3. **Multi-provider setup com fallback chain** — Anthropic → Moonshot → Google como fallback
4. **GLM-4.7-Flash (grátis) para heartbeat** — se quiser custo zero nessa função
5. **OpenAI embeddings para memory** — melhor qualidade de busca semântica

### Não aplicável / cuidado
- **Claude Max OAuth** — nosso setup já usa API key direta (seguro)
- **DeepSeek direto** — não funciona com OpenClaw (evitar)
- **Kimi K2.5 reasoning mode** — bugado no OpenClaw (manter false)
- **Dados sensíveis no Moonshot** — dados passam por servidores chineses
- **NVIDIA free tier** — lento demais para produção
