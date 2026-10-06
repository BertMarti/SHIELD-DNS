#!/usr/bin/env bash
# SHIELD-DNS - instalador. Uso: ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✔\033[0m  %s\n' "$*"; }
fallo() { printf '\033[1;31m✘\033[0m  %s\n' "$*" >&2; exit 1; }

# 1. Docker
if ! command -v docker >/dev/null 2>&1; then
  info "Docker no está instalado. Instalando con el script oficial (get.docker.com)..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi
DOCKER="docker"
docker info >/dev/null 2>&1 || DOCKER="sudo docker"
$DOCKER compose version >/dev/null 2>&1 || fallo "Falta el plugin 'docker compose'."
ok "Docker disponible"

# 2. Puerto 53 libre (salvo que ya sea nuestro contenedor)
if ! $DOCKER ps --format '{{.Names}}' | grep -qx shield-pihole; then
  if sudo ss -tulpn 2>/dev/null | grep -qE '[:.]53\s'; then
    sudo ss -tulpn | grep -E '[:.]53\s' >&2
    fallo "El puerto 53 está ocupado por otro servicio (arriba). Detenlo antes de instalar (p. ej. 'sudo systemctl disable --now pihole-FTL' o systemd-resolved)."
  fi
fi

# 3. .env
if [ ! -f .env ]; then
  cp .env.example .env
  ok "Creado .env"
fi
if ! grep -qE '^PIHOLE_PASSWORD=.+' .env; then
  PASS="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)"
  sed -i "s|^PIHOLE_PASSWORD=.*|PIHOLE_PASSWORD=${PASS}|" .env
  ok "Contraseña del panel generada en .env"
fi
chmod 600 .env
set -a; . ./.env; set +a
mkdir -p data/pihole

# 4. Arranque
info "Arrancando contenedores..."
$DOCKER compose up -d

info "Esperando a que Pi-hole esté listo..."
for i in $(seq 1 60); do
  estado="$($DOCKER inspect -f '{{.State.Health.Status}}' shield-pihole 2>/dev/null || echo starting)"
  [ "$estado" = "healthy" ] && break
  sleep 3
done
[ "$estado" = "healthy" ] || fallo "Pi-hole no arrancó correctamente. Revisa: docker compose logs pihole"
ok "Pi-hole funcionando"

# 5. Listas de bloqueo extra
if [ -n "${EXTRA_ADLISTS:-}" ]; then
  for url in $EXTRA_ADLISTS; do
    $DOCKER exec shield-pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
      "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('${url//\'/}', 1, 'SHIELD-DNS');"
  done
  info "Actualizando listas de bloqueo (puede tardar un par de minutos)..."
  $DOCKER exec shield-pihole pihole -g >/dev/null
  ok "Listas actualizadas"
fi

# 6. Comprobación
IP="$(hostname -I | awk '{print $1}')"
if $DOCKER exec shield-pihole dig +short +time=5 @127.0.0.1 example.com >/dev/null 2>&1; then
  ok "El DNS responde"
else
  fallo "El DNS no responde. Revisa: docker compose logs"
fi

cat <<EOF

────────────────────────────────────────────────────────
 SHIELD-DNS instalado
   Panel web:   https://${IP}:${WEB_HTTPS_PORT:-8443}/admin
                (certificado autofirmado: acepta el aviso del navegador)
   Contraseña:  la variable PIHOLE_PASSWORD de $(pwd)/.env
   Servidor DNS: ${IP}

 Siguiente paso: pon ${IP} como DNS en tu router (o en cada
 dispositivo). Si usas HEIMDALL, la VPN ya lo usa automáticamente.
────────────────────────────────────────────────────────
EOF
