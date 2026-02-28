# Heartbeat Checklist

Tarefas a verificar a cada heartbeat (30 min, 8h-24h):

- [ ] Verificar lembretes pendentes
- [ ] Checar status de tarefas delegadas aos agentes
- [ ] Revisar mensagens nao respondidas
- [ ] Verificar cron jobs agendados

## Sugestoes de Cron (criar via tool `cron`)

Estes sao cron jobs sugeridos. Crie-os em runtime usando a tool `cron` quando o Lucas aprovar:

- **Briefing matinal** (seg-sex 8h): verificar lembretes e tarefas pendentes do dia. Modelo: haiku (custo menor).
- **Resumo noturno** (22h): resumo do dia + lembretes para amanha. Modelo: haiku.
