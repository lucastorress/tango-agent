# Configuracao de Agentes

## Fallback Chains (anti-travamento)

| Agente | Primary | Fallback 1 | Fallback 2 | Fallback 3 |
|--------|---------|-----------|-----------|-----------|
| tango | Haiku | Kimi K2.5 | Gemini Flash | — |
| atlas | Kimi K2.5 | Gemini Flash | Haiku | — |
| pixel | MiniMax M2.5 | Kimi K2.5 | Gemini Flash | Sonnet |
| hawk | MiniMax M2.5 | Kimi K2.5 | Gemini Flash | Sonnet |
| sentinel | MiniMax M2.5 | Kimi K2.5 | Gemini Flash | Sonnet |

## Limites

- Max 2 subagentes simultaneos
- Max 3 filhos por agente
- Subagentes arquivados apos 30min ociosos
- Timeout: 90s por request
- contextTokens: 32k
- Compaction: safeguard (auto-resume)

## Claude CLI

Agentes coding (Pixel, Hawk, Sentinel) devem usar `claude -p` para tarefas pesadas.
Subscription Max Pro — custo zero extra.
