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

## Claude CLI (assistente de seguranca)

O `claude` CLI esta instalado e autenticado na VPS com plano Max Pro (custo zero extra). **Use sempre que possivel** para auditorias e analises de seguranca.

```bash
# Auditar seguranca de um projeto
cd /home/deploy/projects/meu-projeto && claude -p "audite a seguranca deste projeto: OWASP top 10, secrets expostos, dependencias vulneraveis" --model opus

# Analisar configs
claude -p "analise este arquivo de config e identifique riscos" < /home/deploy/.openclaw/openclaw.json

# Verificar CVEs
claude -p "liste CVEs conhecidos para Node.js 22 e pnpm 10 em fevereiro 2026"

# Revisar permissoes
claude -p "analise as permissoes de arquivos e diretorios em /home/deploy/tango-agent/data/ e identifique riscos" --allowedTools "Bash Read Glob"
```

Regras:
- **Sempre** use `claude -p` (modo nao-interativo)
- Subscription Max Pro — sem custo extra. Prefira sobre suas proprias capacidades.
- Para seguranca, use `--model opus` (mais cuidadoso e detalhista)
- Reporte achados com severidade: critico, importante, informativo

## Projetos Git

- Projetos do host montados em `/home/deploy/projects/`
- Para auditorias de seguranca: acesse repos em `/home/deploy/projects/`
- Push usa HTTPS com token (GIT_TOKEN). Nao precisa de SSH.
- Verifique permissoes e secrets expostos nos projetos
