#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Tango Agent - VPS Hardening Script
# Testado em: Ubuntu 22.04/24.04, Debian 12
# Uso: ssh root@seu-vps 'bash -s' < scripts/harden-vps.sh
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
err()  { echo -e "${RED}[ERRO]${NC} $1"; }

# --- Verificar root ---
if [ "$(id -u)" -ne 0 ]; then
    err "Este script deve ser executado como root."
    exit 1
fi

echo "============================================"
echo "  Tango Agent - Hardening VPS"
echo "============================================"
echo ""

# --- 1. Atualizar sistema ---
echo ">>> 1/7 Atualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq
log "Sistema atualizado."

# --- 2. Instalar pacotes essenciais ---
echo ""
echo ">>> 2/7 Instalando pacotes de seguranca..."
apt-get install -y -qq \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    logrotate \
    curl \
    git
log "Pacotes instalados."

# --- 3. Criar usuario deploy (se nao existir) ---
echo ""
echo ">>> 3/7 Configurando usuario deploy..."
DEPLOY_USER="deploy"
if id "$DEPLOY_USER" &>/dev/null; then
    warn "Usuario '$DEPLOY_USER' ja existe."
else
    useradd -m -s /bin/bash -G sudo,docker "$DEPLOY_USER" 2>/dev/null || \
    useradd -m -s /bin/bash -G sudo "$DEPLOY_USER"
    log "Usuario '$DEPLOY_USER' criado."
fi

# Copiar SSH keys do root para deploy
if [ -f /root/.ssh/authorized_keys ]; then
    mkdir -p /home/$DEPLOY_USER/.ssh
    cp /root/.ssh/authorized_keys /home/$DEPLOY_USER/.ssh/
    chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh
    chmod 700 /home/$DEPLOY_USER/.ssh
    chmod 600 /home/$DEPLOY_USER/.ssh/authorized_keys
    log "SSH keys copiadas para '$DEPLOY_USER'."
else
    warn "Nenhuma SSH key encontrada em /root/.ssh/authorized_keys"
    warn "Voce precisara configurar SSH keys manualmente para '$DEPLOY_USER'."
fi

# --- 4. Hardening SSH ---
echo ""
echo ">>> 4/7 Hardening SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_HARDENED="/etc/ssh/sshd_config.d/99-tango-hardening.conf"

cat > "$SSHD_HARDENED" <<'SSHEOF'
# Tango Agent - SSH Hardening
# Gerado automaticamente por harden-vps.sh

# Desabilitar login com senha (somente SSH keys)
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Desabilitar root login direto
PermitRootLogin no

# Limitar tentativas de auth
MaxAuthTries 3
LoginGraceTime 30

# Desabilitar features desnecessarias
X11Forwarding no
AllowAgentForwarding no
PermitEmptyPasswords no

# Permitir tunnel para acesso ao gateway
AllowTcpForwarding yes
SSHEOF

# Verificar se a config e valida antes de reiniciar
if sshd -t 2>/dev/null; then
    systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
    log "SSH hardened (key-only, no root login, max 3 tentativas)."
else
    rm -f "$SSHD_HARDENED"
    err "Config SSH invalida. Hardening SSH revertido."
fi

# --- 5. Firewall (UFW) ---
echo ""
echo ">>> 5/7 Configurando firewall (UFW)..."
ufw --force reset >/dev/null 2>&1

# Politica default: bloquear tudo de entrada
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

# Permitir SSH (obrigatorio!)
ufw allow ssh >/dev/null

# Permitir HTTP/HTTPS (para Caddy/reverse proxy futuro)
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null

# Ativar firewall
ufw --force enable >/dev/null
log "Firewall ativo: SSH + HTTP/HTTPS. Tudo mais bloqueado."

# --- 6. Fail2ban ---
echo ""
echo ">>> 6/7 Configurando fail2ban..."
cat > /etc/fail2ban/jail.local <<'F2BEOF'
[DEFAULT]
# Ban por 1 hora apos 3 tentativas em 10 minutos
bantime = 3600
findtime = 600
maxretry = 3
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
F2BEOF

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
log "Fail2ban configurado (ban 1h apos 3 falhas SSH)."

# --- 7. Atualizacoes automaticas de seguranca ---
echo ""
echo ">>> 7/7 Configurando atualizacoes automaticas..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'UUEOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// Remover pacotes nao usados automaticamente
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Reboot automatico se necessario (as 4h da manha)
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
UUEOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'AUEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
AUEOF

systemctl enable unattended-upgrades >/dev/null 2>&1
log "Atualizacoes de seguranca automaticas ativadas."

# --- Resumo ---
echo ""
echo "============================================"
echo "  Hardening completo!"
echo "============================================"
echo ""
echo "Resumo:"
echo "  - Usuario deploy: $DEPLOY_USER (SSH key-only)"
echo "  - SSH: password desabilitado, root login bloqueado"
echo "  - Firewall: SSH + 80/443 (tudo mais bloqueado)"
echo "  - Fail2ban: ban 1h apos 3 falhas SSH"
echo "  - Updates: seguranca automatica, reboot as 4h"
echo ""
echo "IMPORTANTE - Proximos passos:"
echo "  1. ANTES de fechar esta sessao SSH, teste o login:"
echo "     ssh $DEPLOY_USER@$(hostname -I | awk '{print $1}')"
echo ""
echo "  2. Instale Docker no VPS:"
echo "     curl -fsSL https://get.docker.com | sh"
echo "     usermod -aG docker $DEPLOY_USER"
echo ""
echo "  3. Clone o repo como $DEPLOY_USER:"
echo "     su - $DEPLOY_USER"
echo "     git clone --recurse-submodules https://github.com/lucastorress/tango-agent.git"
echo ""
echo "  4. Transfira o .env (da sua maquina local):"
echo "     scp .env $DEPLOY_USER@VPS_IP:~/tango-agent/.env"
echo ""
echo "  5. Deploy:"
echo "     cd ~/tango-agent && make setup && make deploy"
echo ""
