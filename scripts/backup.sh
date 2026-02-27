#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Tango Agent - Backup
# Faz backup do diretorio data/ e opcionalmente cria snapshot na Hetzner
#
# Credenciais de infra ficam em .env.infra (SEPARADO do .env do OpenClaw)
#
# Uso:
#   bash scripts/backup.sh              # Backup local (tar.gz)
#   bash scripts/backup.sh --snapshot   # Backup local + snapshot Hetzner
# =============================================================================

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/tango-backup-$TIMESTAMP.tar.gz"

echo "=== Tango Agent - Backup ==="

# --- 1. Backup local (tar.gz) ---
echo ""
echo ">>> Backup local do diretorio data/..."

if [ ! -d data ]; then
    echo "ERRO: Diretorio data/ nao encontrado."
    exit 1
fi

mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_FILE" data/
SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
echo "Backup criado: $BACKUP_FILE ($SIZE)"

# Limpar backups antigos (manter ultimos 7)
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/tango-backup-*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 7 ]; then
    ls -1t "$BACKUP_DIR"/tango-backup-*.tar.gz | tail -n +8 | xargs rm -f
    echo "Backups antigos removidos (mantidos ultimos 7)."
fi

# --- 2. Snapshot Hetzner (opcional) ---
if [ "${1:-}" = "--snapshot" ]; then
    echo ""
    echo ">>> Criando snapshot na Hetzner..."

    # Carregar credenciais de infra (separadas do .env do OpenClaw)
    if [ -f .env.infra ]; then
        set -a
        source .env.infra
        set +a
    fi

    # Token pode vir do .env.infra ou ser solicitado em runtime
    if [ -z "${HETZNER_API_TOKEN:-}" ]; then
        echo -n "Hetzner API Token: "
        read -rs HETZNER_API_TOKEN
        echo ""
    fi

    if [ -z "${HETZNER_SERVER_ID:-}" ]; then
        echo "Buscando servidores..."
        SERVERS=$(curl -sf \
            -H "Authorization: Bearer $HETZNER_API_TOKEN" \
            "https://api.hetzner.cloud/v1/servers" 2>/dev/null)

        if [ $? -ne 0 ] || [ -z "$SERVERS" ]; then
            echo "ERRO: Falha ao conectar na API Hetzner. Verifique o token."
            exit 1
        fi

        echo "$SERVERS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('servers', []):
    print(f\"  ID: {s['id']}  Nome: {s['name']}  IP: {s['public_net']['ipv4']['ip']}  Status: {s['status']}\")
" 2>/dev/null || echo "$SERVERS" | grep -o '"id":[0-9]*' | head -5

        echo -n "Server ID: "
        read -r HETZNER_SERVER_ID
    fi

    SNAPSHOT_DESC="tango-agent-$TIMESTAMP"
    echo "Criando snapshot '$SNAPSHOT_DESC'..."

    RESPONSE=$(curl -sf \
        -X POST \
        -H "Authorization: Bearer $HETZNER_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"description\": \"$SNAPSHOT_DESC\", \"type\": \"snapshot\"}" \
        "https://api.hetzner.cloud/v1/servers/$HETZNER_SERVER_ID/actions/create_image")

    if echo "$RESPONSE" | grep -q '"id"'; then
        echo "Snapshot criado com sucesso!"
        echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
img = data.get('image', {})
print(f\"  ID: {img.get('id')}  Descricao: {img.get('description')}  Status: {img.get('status')}\")
" 2>/dev/null || echo "  $RESPONSE"
    else
        echo "ERRO ao criar snapshot:"
        echo "  $RESPONSE"
        exit 1
    fi

    # Limpar snapshots antigos (manter ultimos 5)
    echo ""
    echo "Verificando snapshots antigos..."
    SNAPSHOTS=$(curl -sf \
        -H "Authorization: Bearer $HETZNER_API_TOKEN" \
        "https://api.hetzner.cloud/v1/images?type=snapshot&sort=created:desc" 2>/dev/null)

    TANGO_SNAPSHOTS=$(echo "$SNAPSHOTS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
snaps = [s for s in data.get('images', []) if 'tango-agent' in s.get('description', '')]
for s in snaps:
    print(f\"{s['id']} {s['description']}\")
" 2>/dev/null)

    SNAP_COUNT=$(echo "$TANGO_SNAPSHOTS" | grep -c "tango-agent" || true)
    if [ "$SNAP_COUNT" -gt 5 ]; then
        echo "$TANGO_SNAPSHOTS" | tail -n +6 | while read -r SNAP_ID SNAP_DESC; do
            echo "  Removendo snapshot antigo: $SNAP_DESC (ID: $SNAP_ID)"
            curl -sf -X DELETE \
                -H "Authorization: Bearer $HETZNER_API_TOKEN" \
                "https://api.hetzner.cloud/v1/images/$SNAP_ID" >/dev/null
        done
        echo "Snapshots antigos removidos (mantidos ultimos 5)."
    fi
fi

echo ""
echo "=== Backup completo! ==="
