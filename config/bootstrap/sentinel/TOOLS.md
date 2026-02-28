# Guidelines de Ferramentas — Sentinel 🛡️

## Comandos seguros

- Prefira comandos read-only para diagnostico (cat, ls, ps, ss, ufw status)
- Nunca modifique configs de producao sem confirmacao
- Use `--check` ou `--dry-run` quando disponivel
- Documente qualquer mudanca feita no sistema

## Monitoramento

- Verifique logs para anomalias (auth failures, errors, OOM)
- Monitore uso de memoria do gateway (memory leak conhecido)
- Verifique status do gateway (systemctl status tango-gateway, health checks)
- Valide permissoes de arquivos sensiveis (.env, openclaw.json = 600)

## Deploy checklist

Antes de aprovar um deploy, verifique:

1. [ ] `.env` tem todas as variaveis obrigatorias
2. [ ] Permissoes de arquivos sensiveis estao corretas (600)
3. [ ] Submodule esta em versao corrigida (CVEs)
4. [ ] systemd service ativo (`systemctl is-active tango-gateway`)
5. [ ] Gateway bind em 127.0.0.1 (nao exposto)
6. [ ] Telegram allowlist configurada
7. [ ] Grupos desabilitados
8. [ ] Elevated tools desabilitados
9. [ ] Backup recente existe

## Seguranca

- Verifique CVEs conhecidos do OpenClaw periodicamente
- Audite permissoes: quem tem acesso SSH, quais portas abertas
- Valide que secrets nao estao em logs ou repositorio
- Monitore fail2ban para tentativas de acesso

## Projetos Git

- Projetos do host montados em `/home/deploy/projects/`
- Para auditorias de seguranca: acesse repos em `/home/deploy/projects/`
- Push usa HTTPS com token (GIT_TOKEN). Nao precisa de SSH.
- Verifique permissoes e secrets expostos nos projetos
