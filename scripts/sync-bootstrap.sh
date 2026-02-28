#!/usr/bin/env bash
set -euo pipefail

echo "=== Sync Bootstrap Templates ==="
echo ""
echo "Copia templates de config/bootstrap/ para os workspaces."
echo "Sobrescreve tudo EXCETO memory/ e MEMORY.md."
echo ""

AGENTS="tango atlas pixel hawk sentinel"

for agent in $AGENTS; do
    ws="data/workspace"
    [ "$agent" != "tango" ] && ws="data/workspace-${agent}"

    if [ ! -d "config/bootstrap/$agent" ]; then
        echo "AVISO: config/bootstrap/$agent nao existe, pulando."
        continue
    fi

    mkdir -p "$ws/memory"

    for file in config/bootstrap/"$agent"/*.md; do
        [ ! -f "$file" ] && continue
        basename_file="$(basename "$file")"

        # Nunca sobrescrever MEMORY.md
        if [ "$basename_file" = "MEMORY.md" ]; then
            continue
        fi

        cp "$file" "$ws/$basename_file"
        echo "Atualizado: $ws/$basename_file"
    done
done

echo ""
echo "Sync completo. Diretorios memory/ preservados."
