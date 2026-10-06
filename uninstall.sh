#!/usr/bin/env bash
# SHIELD-DNS - desinstalador. Uso: ./uninstall.sh [--purge]
#   --purge  borra también la configuración y estadísticas de Pi-hole (carpeta data/) y el .env
set -euo pipefail
cd "$(dirname "$0")"
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

$DOCKER compose down
echo "Contenedores de SHIELD-DNS detenidos y eliminados."
echo "Recuerda volver a poner el DNS de tu router si apuntaba a esta Raspberry Pi."

if [ "${1:-}" = "--purge" ]; then
  sudo rm -rf data .env
  echo "Datos y .env eliminados."
fi
