#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Tango Agent - Security Check
# Verifica se o VPS e o deploy estao seguros
# Uso: ssh deploy@vps 'cd ~/tango-agent && bash scripts/security-check.sh'
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASS=$((PASS+1)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; WARN=$((WARN+1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAIL=$((FAIL+1)); }

echo "============================================"
echo "  Tango Agent - Security Check"
echo "============================================"
echo ""

# --- SSH ---
echo ">> SSH"
if grep -qr "PasswordAuthentication no" /etc/ssh/sshd_config.d/ 2>/dev/null || \
   grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    pass "Password authentication desabilitado"
else
    fail "Password authentication ainda habilitado"
fi

if grep -qr "PermitRootLogin no" /etc/ssh/sshd_config.d/ 2>/dev/null || \
   grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    pass "Root login desabilitado"
else
    fail "Root login ainda permitido"
fi

# --- Firewall ---
echo ""
echo ">> Firewall"
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    pass "UFW ativo"
    if ufw status | grep -q "18789"; then
        fail "Porta 18789 exposta no firewall (deveria ser localhost only)"
    else
        pass "Porta 18789 nao exposta externamente"
    fi
else
    fail "UFW nao esta ativo"
fi

# --- Fail2ban ---
echo ""
echo ">> Fail2ban"
if systemctl is-active fail2ban &>/dev/null; then
    pass "Fail2ban ativo"
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || echo "?")
    echo "       IPs banidos (sshd): $BANNED"
else
    fail "Fail2ban nao esta ativo"
fi

# --- Docker ---
echo ""
echo ">> Docker"
if command -v docker &>/dev/null; then
    pass "Docker instalado"
else
    fail "Docker nao encontrado"
fi

if docker compose ps --format json 2>/dev/null | grep -q "tango-gateway"; then
    pass "Container tango-gateway rodando"
else
    warn "Container tango-gateway nao esta rodando"
fi

# --- .env ---
echo ""
echo ">> Segredos"
if [ -f .env ]; then
    ENV_PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null)
    if [ "$ENV_PERMS" = "600" ] || [ "$ENV_PERMS" = "400" ]; then
        pass ".env com permissoes restritas ($ENV_PERMS)"
    else
        warn ".env com permissoes $ENV_PERMS (recomendado: chmod 600 .env)"
    fi

    if grep -q "CHANGE_ME\|sk-ant-\.\.\.\|123456:ABCDEF" .env 2>/dev/null; then
        fail ".env contem valores placeholder (nao preenchido)"
    else
        pass ".env preenchido (sem placeholders)"
    fi
else
    fail ".env nao encontrado"
fi

# --- Config OpenClaw ---
echo ""
echo ">> Config OpenClaw"
CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-./data/config}"
if [ -f "$CONFIG_DIR/openclaw.json" ]; then
    CONFIG_PERMS=$(stat -c "%a" "$CONFIG_DIR/openclaw.json" 2>/dev/null || stat -f "%Lp" "$CONFIG_DIR/openclaw.json" 2>/dev/null)
    if [ "$CONFIG_PERMS" = "600" ] || [ "$CONFIG_PERMS" = "400" ]; then
        pass "openclaw.json com permissoes restritas ($CONFIG_PERMS)"
    else
        warn "openclaw.json com permissoes $CONFIG_PERMS (recomendado: chmod 600)"
    fi
else
    warn "openclaw.json nao encontrado em $CONFIG_DIR (sera criado no primeiro boot)"
fi

# --- Projetos ---
echo ""
echo ">> Projetos"
PROJ_DIR="${PROJECTS_DIR:-./projects}"
if [ -d "$PROJ_DIR" ]; then
    PROJ_OWNER=$(stat -c "%u" "$PROJ_DIR" 2>/dev/null || stat -f "%u" "$PROJ_DIR" 2>/dev/null)
    if [ "$PROJ_OWNER" = "1000" ]; then
        pass "Diretorio de projetos com owner correto (uid 1000)"
    else
        warn "Diretorio de projetos com owner $PROJ_OWNER (esperado: 1000)"
    fi
else
    warn "Diretorio de projetos nao existe ($PROJ_DIR)"
fi

# --- Docker Security ---
echo ""
echo ">> Docker Security"
if docker inspect tango-gateway --format='{{.HostConfig.SecurityOpt}}' 2>/dev/null | grep -q "no-new-privileges"; then
    pass "Container com no-new-privileges"
else
    warn "Container sem no-new-privileges"
fi

if docker inspect tango-gateway --format='{{.HostConfig.CapDrop}}' 2>/dev/null | grep -q "ALL"; then
    pass "Container com cap_drop ALL"
else
    warn "Container sem cap_drop ALL"
fi

# --- Portas abertas ---
echo ""
echo ">> Rede"
if command -v ss &>/dev/null; then
    if ss -tlnp | grep -q "0.0.0.0:18789\|\*:18789"; then
        fail "Porta 18789 ouvindo em 0.0.0.0 (deveria ser 127.0.0.1)"
    elif ss -tlnp | grep -q "127.0.0.1:18789"; then
        pass "Porta 18789 ouvindo apenas em 127.0.0.1"
    else
        warn "Porta 18789 nao encontrada (gateway nao esta rodando?)"
    fi
fi

# --- Updates ---
echo ""
echo ">> Atualizacoes"
if systemctl is-enabled unattended-upgrades &>/dev/null; then
    pass "Atualizacoes automaticas ativas"
else
    warn "Atualizacoes automaticas nao configuradas"
fi

# --- Resumo ---
echo ""
echo "============================================"
echo -e "  ${GREEN}$PASS PASS${NC}  ${YELLOW}$WARN WARN${NC}  ${RED}$FAIL FAIL${NC}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
