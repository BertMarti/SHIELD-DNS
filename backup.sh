#!/usr/bin/env bash
# SHIELD-DNS - copia de seguridad. Uso: ./backup.sh
# Guarda .env y una exportación "Teleporter" de Pi-hole (listas, permitidos/bloqueados,
# clientes y ajustes) en backups/shield-dns-AAAAMMDD-HHMM.tar.gz. Conserva las 7 más recientes.
set -euo pipefail
cd "$(dirname "$0")"
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"
[ -f .env ] || { echo "No hay .env: ¿está instalado SHIELD-DNS?" >&2; exit 1; }
$DOCKER ps --format '{{.Names}}' | grep -qx shield-pihole || { echo "Pi-hole no está en marcha." >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p backups
ZIP="$($DOCKER exec -w /tmp shield-pihole pihole-FTL --teleporter 2>/dev/null | grep -E '\.zip$' | tail -1)"
[ -n "$ZIP" ] || { echo "No se pudo exportar la configuración de Pi-hole." >&2; exit 1; }
$DOCKER cp "shield-pihole:/tmp/$ZIP" "$TMP/teleporter.zip" >/dev/null
$DOCKER exec shield-pihole rm -f "/tmp/$ZIP"
cp .env "$TMP/.env"

ARCHIVO="backups/shield-dns-$(date +%Y%m%d-%H%M).tar.gz"
tar -czf "$ARCHIVO" -C "$TMP" .env teleporter.zip
chmod 600 "$ARCHIVO"
ls -1t backups/shield-dns-*.tar.gz | tail -n +8 | xargs -r rm -f
echo "Copia creada: $(pwd)/$ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))"
