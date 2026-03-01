# TangoCash V3 — Plano de Evolução para Lançamento
> Branch: `feat/igaming-evolution`
> Criado em: 2026-02-28
> Baseado em: análise completa do código-fonte, DOCUMENTACAO_TANGOCASH.md, PROGRESSO.md, TECH_DEBT.md, CLAUDE.md, docs/evolution/*

---

## 📌 Contexto

O projeto está estruturalmente completo (Fases 1–5 do PROGRESSO.md concluídas), incluindo:
- API NestJS com 15+ módulos
- Frontend Web (Next.js) com todas as telas de usuário
- Frontend Admin (Next.js) com RBAC, configurações, auditoria
- Integração Fire Banking (Avista) com PIX Cash-In/Out
- Módulo de Email (Mailersend + BullMQ)
- Módulo de Referrals (bônus + comissões)
- WebSockets para usuários
- CI/CD com GitHub Actions
- Docker + Nginx (produção)

**O que falta para lançar:** corrigir gaps críticos de implementação, fechar tech debt, adicionar mecânicas iGaming, testes e preparação de ambiente.

---

## FASE 1 — Tech Debt Crítico (Bloqueadores de Lançamento)

### 1.1 Gaps de Implementação

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 1.1.1 | Implementar validação de `maxNumbersPerUser` no `GamesService.purchaseNumbers()` | Fácil |
| 1.1.2 | Corrigir leaderboard sem nomes — adicionar JOIN com tabela `users` no `getLeaderboard()` | Fácil |
| 1.1.3 | Emitir WebSocket events para usuários finais: `wallet.updated`, `game.number_sold`, `game.completed` | Médio |
| 1.1.4 | Implementar reembolso em jogos cancelados (TODO em games.service.ts:577) | Médio |
| 1.1.5 | Rodar migration pendente do RBAC (migration 0003) | Fácil |
| 1.1.6 | Rodar seed de admin para criar usuário admin@tangocash.dev | Fácil |

### 1.2 Tech Debt (TECH_DEBT.md)

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 1.2.1 | [API-001] Corrigir N+1 query em `getPendingWithdrawals` — usar JOIN ou batch | Médio |
| 1.2.2 | [API-003] Validação de formato de chave PIX no DTO de saque | Médio |
| 1.2.3 | [API-004] Usar BullMQ para retry de emails críticos (verificação, reset senha) | Médio |
| 1.2.4 | [API-005] Corrigir erros de tipagem no AdminController (lines 460,480,494,548) | Fácil |
| 1.2.5 | [API-006] Remover imports não utilizados em game-automation, scratch-cards, withdrawal-rules | Fácil |
| 1.2.6 | [ADMIN-001] Adicionar validação server-side dos limites de configuração | Médio |
| 1.2.7 | [API-002] Implementar parsing X.509 para alertas de expiração de certificado Fire Banking | Difícil |
| 1.2.8 | [ADMIN-002] Persistir filtros na URL com nuqs/searchParams | Fácil |
| 1.2.9 | [ADMIN-003] Updates otimistas após mutations (setQueryData) | Médio |
| 1.2.10 | [ADMIN-004] Mensagens de erro específicas por código HTTP (403, 404, 422) | Fácil |

### 1.3 Segurança e Estabilidade

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 1.3.1 | Verificar segredos em produção — não commitar .env, usar secrets manager | Médio |
| 1.3.2 | Testar webhook Fire Banking com simulação de CashIn/CashOut/Reversal | Médio |
| 1.3.3 | Configurar Sentry ou similar para capturar exceções em produção | Médio |

---

## FASE 2 — UI/UX (Melhorias nas Telas Web + Admin)

### 2.1 Frontend Web

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 2.1.1 | Feedback em tempo real no depósito via WebSocket (sem polling manual) | Médio |
| 2.1.2 | Skeleton screens em telas com fetch (jogos, carteira, perfil) | Médio |
| 2.1.3 | Toast notifications para eventos de WebSocket | Fácil |
| 2.1.4 | Tela de resultado do sorteio com animação (número vencedor + prêmio) | Difícil |
| 2.1.5 | Validação de CPF em tempo real no formulário de cadastro | Fácil |
| 2.1.6 | NumberGrid melhorado — destacar números comprados pelo usuário vs disponíveis | Médio |
| 2.1.7 | Progressbar do jogo com % de números vendidos em tempo real | Fácil |
| 2.1.8 | Tela de jogo encerrado com resultado, vencedor, seed de auditoria | Médio |
| 2.1.9 | Dark/Light theme toggle | Médio |
| 2.1.10 | Revisão de responsividade mobile (375px/390px) | Médio |
| 2.1.11 | Empty states com ilustrações | Fácil |
| 2.1.12 | Modal de confirmação de saque com taxa R$1,90 | Fácil |

### 2.2 Frontend Admin

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 2.2.1 | Dashboard com métricas em tempo real via WebSocket | Médio |
| 2.2.2 | Filtros avançados na tabela de usuários (status, data, range de saldo) | Médio |
| 2.2.3 | Busca global por email, CPF, nome | Médio |
| 2.2.4 | Exportação de dados em CSV | Difícil |
| 2.2.5 | Preview de lucratividade antes de ativar jogo | Médio |
| 2.2.6 | Notificações de admin em tempo real (badge de saques pendentes) | Médio |
| 2.2.7 | Tela de detalhes do sorteio com trail de auditoria | Médio |
| 2.2.8 | Responsive admin para tablet (768px) | Fácil |

---

## FASE 3 — Mecânicas de Jogo (100% das Mecânicas Previstas)

### 3.1 Scratch Cards (Raspadinha)

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 3.1.1 | Completar ScratchCardsService — integração com schema e fluxo compra/revelação | Difícil |
| 3.1.2 | Frontend Web: tela de scratch cards | Difícil |
| 3.1.3 | Animação de raspagem (canvas/WebGL) | Difícil |
| 3.1.4 | Admin: criar/gerenciar scratch card games | Médio |
| 3.1.5 | Validação de RTP e distribuição de prêmios (max 50% RTP) | Médio |

### 3.2 Game Templates e Automação

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 3.2.1 | Admin: verificar CRUD completo de Templates (/templates) | Médio |
| 3.2.2 | Admin: verificar controles start/stop de Automação (/automation) | Médio |
| 3.2.3 | Revisar BullMQ processors (GAME_CREATION, DRAW_EXECUTION, GAME_MONITORING) | Difícil |
| 3.2.4 | Garantir criação e sorteio automático conforme template/scheduler | Difícil |
| 3.2.5 | Frontend: exibir jogos automáticos na home com countdown para sorteio | Médio |

### 3.3 Sorteio Ponderado (Weighted Draw)

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 3.3.1 | Implementar sorteio com pesos usando campo `weight` de game_numbers | Médio |
| 3.3.2 | Admin: configurar pesos ao criar jogo | Médio |
| 3.3.3 | Frontend: indicar visualmente números com probabilidade diferente | Médio |

### 3.4 Torneios e Competições

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 3.4.1 | Schema de torneios (tournaments, tournament_entries, tournament_prizes) | Difícil |
| 3.4.2 | Lógica de torneio com múltiplos vencedores e distribuição escalonada | Difícil |
| 3.4.3 | Frontend: tela de torneios com leaderboard ao vivo | Difícil |
| 3.4.4 | Admin: criar e gerenciar torneios | Médio |

### 3.5 Gamification Core

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 3.5.1 | Sistema de XP e Levels (schema, cálculo, exibição no perfil) | Difícil |
| 3.5.2 | Badges e Conquistas (schema, triggers, exibição) | Difícil |
| 3.5.3 | Leaderboards globais diário/semanal/mensal | Médio |
| 3.5.4 | Missões diárias (schema, tracking de progresso, recompensas) | Difícil |
| 3.5.5 | Streaks de login com bonificação | Médio |
| 3.5.6 | VIP Tiers (Bronze, Prata, Ouro, Diamante) com benefícios progressivos | Difícil |

---

## FASE 4 — Configurabilidade Admin

### 4.1 Configurações Gerais

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 4.1.1 | Validação server-side de configs (min/max) | Médio |
| 4.1.2 | Histórico de alterações de config (audit trail) | Fácil |
| 4.1.3 | Configuração Fire Banking (/config → Pagamentos) — verificar e testar | Médio |

### 4.2 Configurações de Scratch Cards

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 4.2.1 | Tela de configuração global (RTP máximo, preço por cartão) | Médio |
| 4.2.2 | Editor visual de distribuição de prêmios (tiers + probabilidades) | Difícil |

### 4.3 Configurações de Templates

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 4.3.1 | Editor avançado de template com validação de RTP e config de automação | Difícil |
| 4.3.2 | Preview de lucratividade esperada (calculadora de receita) | Médio |
| 4.3.3 | Clonar template existente | Fácil |

### 4.4 Configurações de Gamification

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 4.4.1 | Config de XP (pontos por ação, multiplicadores) | Médio |
| 4.4.2 | Gerenciar Badges (criar, editar, condições de desbloqueio) | Médio |
| 4.4.3 | Config de VIP Tiers (thresholds, benefícios, taxas) | Médio |
| 4.4.4 | Config de Missões (criar missões com recompensas) | Médio |

### 4.5 Configurações de Referral e Saques

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 4.5.1 | Verificar funcionamento da config de referral no /config | Fácil |
| 4.5.2 | Dashboard de performance de referrals (top referrers, conversão) | Médio |
| 4.6.1 | Verificar CRUD completo de regras de saque (/withdrawal-rules) | Médio |
| 4.6.2 | Aprovação manual de saques em lote | Médio |

---

## FASE 5 — Testes

### 5.1 Testes Unitários (API)

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 5.1.1 | GamesService: purchaseNumbers, executeDraw, cancelGame+refund | Médio |
| 5.1.2 | WalletService: initiateDeposit, confirmDeposit, initiateWithdraw + validação PIX | Médio |
| 5.1.3 | ReferralsService: criação, ativação, bônus, comissão | Fácil |
| 5.1.4 | AuthService: registro com duplicatas, verificação de email | Médio |
| 5.1.5 | ScratchCardsService: compra, revelação, distribuição de prêmios | Difícil |
| 5.1.6 | GameAutomationService: criação de jobs, draw automático | Difícil |

### 5.2 Testes de Integração

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 5.2.1 | Fluxo depósito PIX → webhook → crédito carteira | Difícil |
| 5.2.2 | Fluxo saque → Fire Banking → webhook de confirmação/falha | Difícil |
| 5.2.3 | Fluxo criar jogo → comprar → sortear → creditar prêmio | Difícil |
| 5.2.4 | Webhook Fire Banking: CashIn, CashOut, Reversals | Médio |

### 5.3 Testes E2E (Playwright)

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 5.3.1 | Setup Playwright no tangocash-web e tangocash-admin | Médio |
| 5.3.2 | E2E: cadastro e login completo | Médio |
| 5.3.3 | E2E: depósito PIX (QR code → webhook → saldo atualizado) | Difícil |
| 5.3.4 | E2E: compra de números em jogo | Médio |
| 5.3.5 | E2E: admin flow (criar jogo → ativar → sortear) | Médio |
| 5.3.6 | E2E: fluxo de referral completo | Difícil |

### 5.4 Testes Admin (Vitest — já existem)

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 5.4.1 | Expandir testes existentes (auth-flow, api, withdrawal-api) | Fácil |
| 5.4.2 | Testes de componentes (GameTable, UserTable, PermissionsEditor) | Médio |

---

## FASE 6 — Pré-Lançamento

### 6.1 Banco de Dados

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 6.1.1 | Executar todas as migrations em produção (`npm run db:migrate`) | Fácil |
| 6.1.2 | Executar seed inicial (`npm run db:seed`) | Fácil |
| 6.1.3 | Verificar índices do schema no banco de produção | Fácil |
| 6.1.4 | Configurar backup automático diário com retenção 30 dias | Médio |
| 6.1.5 | Criar dados de seed para homologação (jogos demo, usuários de teste) | Fácil |

### 6.2 Variáveis de Ambiente

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 6.2.1 | Cheklist completo do .env de produção (todas as vars do .env.example) | Fácil |
| 6.2.2 | JWT_SECRET com mínimo 64 chars | Fácil |
| 6.2.3 | CORS_ORIGINS com domínios de produção | Fácil |
| 6.2.4 | NODE_ENV=production em todos os containers | Fácil |
| 6.2.5 | Redis com senha configurada | Fácil |

### 6.3 Infraestrutura

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 6.3.1 | SSL/TLS via Certbot (api, web, admin) | Médio |
| 6.3.2 | DNS apontando para produção | Fácil |
| 6.3.3 | Nginx no perfil de produção ativo | Fácil |
| 6.3.4 | Verificar stack de monitoramento (Uptime Kuma) | Médio |
| 6.3.5 | Firewall: apenas portas 80, 443, SSH abertas | Fácil |
| 6.3.6 | Testar rate limiting em produção | Fácil |

### 6.4 Fire Banking

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 6.4.1 | Configurar credenciais de produção no admin | Fácil |
| 6.4.2 | Registrar URL de webhook no painel Fire Banking | Fácil |
| 6.4.3 | Testar transação real de R$5 (depósito + saque) | Médio |
| 6.4.4 | Validar certificado mTLS e autenticação OAuth | Médio |

### 6.5 Segurança

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 6.5.1 | Remover/proteger rota Swagger em produção | Fácil |
| 6.5.2 | Bloquear acesso direto às portas 3000, 3001, 3002 | Fácil |
| 6.5.3 | Testar validação HMAC do webhook em produção | Médio |
| 6.5.4 | Confirmar CORS sem wildcard * | Fácil |
| 6.5.5 | Configurar Sentry ou BugSnag | Médio |

### 6.6 Smoke Tests Pós-Deploy

| # | Tarefa | Dificuldade |
|---|--------|-------------|
| 6.6.1 | Registrar usuário via formulário web | Fácil |
| 6.6.2 | Login e verificar saldo | Fácil |
| 6.6.3 | Depósito de R$5 real via PIX | Fácil |
| 6.6.4 | Comprar número em jogo ativo | Fácil |
| 6.6.5 | Executar sorteio de teste via admin | Fácil |
| 6.6.6 | Fazer saque e confirmar crédito | Fácil |
| 6.6.7 | Verificar logs de auditoria no admin | Fácil |
| 6.6.8 | Verificar recebimento de emails (depósito, prêmio) | Fácil |

---

## 📊 Resumo

| Fase | Tarefas | Estimativa |
|------|---------|------------|
| FASE 1 — Tech Debt Crítico | 19 | 2–3 semanas |
| FASE 2 — UI/UX | 20 | 2–3 semanas |
| FASE 3 — Mecânicas de Jogo | 22 | 4–6 semanas |
| FASE 4 — Configurabilidade Admin | 14 | 2–3 semanas |
| FASE 5 — Testes | 17 | 2–3 semanas |
| FASE 6 — Pré-Lançamento | 25 | 1 semana |
| **TOTAL** | **117** | **~3 meses** |

## 🎯 Para Lançamento MVP (mínimo viável):

```
IMEDIATO — Corrigir gaps críticos:
  1.1.1 maxNumbersPerUser
  1.1.2 leaderboard com nomes
  1.1.3 WebSocket para usuários
  1.1.4 reembolso em cancelamento
  1.1.5 rodar migration RBAC
  1.1.6 rodar seed de admin

ANTES DO LAUNCH:
  Toda a Fase 6 (infra + env + Fire Banking + segurança + smoke tests)

PÓS-LAUNCH:
  Fase 2 (UI/UX), Fase 3.1-3.3, Fase 5 (testes)

EVOLUÇÃO FUTURA:
  Fase 3.4-3.5 (torneios + gamification), Fase 4 (configs avançadas)
```

**Estimativa MVP: 2–3 semanas**

---

*Documento gerado em 2026-02-28 | Projeto: tangocash-v3 | Branch: feat/igaming-evolution*
