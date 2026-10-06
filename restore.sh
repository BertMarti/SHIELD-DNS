#!/usr/bin/env bash
# SHIELD-DNS - restaurar una copia. Uso: ./restore.sh backups/shield-dns-AAAAMMDD-HHMM.tar.gz
# Restaura .env y la configuración de Pi-hole (listas, permitidos/bloqueados, ajustes).
# Útil tras formatear: clona el repo, copia aquí el archivo de copia y ejecuta este script.
set -euo pipefail
cd "$(dirname "$0")"
COPIA="${1:-}"
[ -f "$COPIA" ] || { echo "Uso: ./restore.sh <archivo.tar.gz>" >&2; exit 1; }
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

read -r -p "Se reemplazará la configuración de SHIELD-DNS por la de $COPIA. ¿Continuar? [s/N] " r
[[ "$r" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
tar -xzf "$COPIA" -C "$TMP"
cp "$TMP/.env" .env; chmod 600 .env
./install.sh
$DOCKER cp "$TMP/teleporter.zip" shield-pihole:/tmp/restaurar.zip >/dev/null
$DOCKER exec shield-pihole pihole-FTL --teleporter /tmp/restaurar.zip >/dev/null
$DOCKER exec shield-pihole rm -f /tmp/restaurar.zip
$DOCKER exec shield-pihole pihole -g >/dev/null
echo "Configuración de Pi-hole restaurada."
