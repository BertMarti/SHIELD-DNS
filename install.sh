#!/usr/bin/env bash
# SHIELD-DNS - instalador. Uso: ./install.sh [--comprobar | --sin-preguntas | --ayuda]
set -euo pipefail
cd "$(dirname "$0")"

info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✔\033[0m  %s\n' "$*"; }
aviso() { printf '\033[1;33m!\033[0m  %s\n' "$*"; }
mal()   { printf '\033[1;31m✘\033[0m  %s\n' "$*" >&2; }
fallo() { mal "$*"; exit 1; }

uso() {
  cat <<'EOF'
SHIELD-DNS: bloqueador de anuncios para toda la casa (Pi-hole + Unbound).

Uso:
  ./install.sh                  instala (o aplica la configuración) y arranca SHIELD-DNS
  ./install.sh --comprobar      solo comprueba los requisitos; no cambia nada
  ./install.sh --sin-preguntas  instala con los valores por defecto, sin preguntar nada
  ./install.sh --ayuda          muestra esta ayuda

La primera vez (sin .env) hace dos preguntas. Si .env ya existe no pregunta nada
(así lo usa ./update.sh).
EOF
}

MODO="instalar"; PREGUNTAR="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    --comprobar) MODO="comprobar" ;;
    --sin-preguntas|-y) PREGUNTAR="no" ;;
    -h|--ayuda|--help) uso; exit 0 ;;
    *) mal "Opción desconocida: $1"; uso >&2; exit 2 ;;
  esac
  shift
done

# --- Utilidades -----------------------------------------------------------------------------------
# Contraseña segura de 24 caracteres alfanuméricos (sin símbolos: no hay que escaparla en .env).
generar_clave() { head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-24; }

# Lee una variable de .env sin ejecutarlo (vacío si no existe).
leer_env() {
  [ -f .env ] || return 0
  { grep -E "^$1=" .env || true; } | tail -n1 | cut -d= -f2- | sed -E 's/^"(.*)"$/\1/'
}

# Escribe CLAVE=VALOR en .env (sustituye la línea o la añade). Con awk: el valor no se interpreta.
poner_env() {
  local tmp; tmp="$(mktemp .env.XXXXXX)"
  CLAVE="$1" VALOR="$2" awk 'BEGIN{c=ENVIRON["CLAVE"]; v=ENVIRON["VALOR"]; hecho=0}
    index($0, c "=")==1 {print c "=" v; hecho=1; next} {print}
    END{if(!hecho) print c "=" v}' .env > "$tmp"
  chmod 600 "$tmp"; mv "$tmp" .env
}

ip_lan()    { hostname -I 2>/dev/null | awk '{print $1}'; }
ip_router() { ip -4 route show default 2>/dev/null | awk '{print $3; exit}'; }
zona_horaria() {
  local tz
  tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  [ -n "$tz" ] || tz="$(cat /etc/timezone 2>/dev/null || true)"
  printf '%s' "${tz:-Europe/Madrid}"
}

# Puerto alternativo para sugerir (el siguiente, o el anterior si ya es el último).
otro_puerto() { if [ "$1" -lt 65535 ]; then echo $(($1 + 1)); else echo $(($1 - 1)); fi; }

# Sockets que escuchan en tcp|udp PUERTO (una línea de `ss` por socket).
escuchando() {
  local opc="-tlnH"; [ "$1" = udp ] && opc="-ulnH"
  { ss "$opc" 2>/dev/null || true; } | awk -v p="$2" '{n = split($4, a, ":"); if (a[n] == p) print}'
}

contenedor_activo() {
  local nombres; nombres="$($DOCKER ps --format '{{.Names}}' 2>/dev/null || true)"
  grep -qx "$1" <<<"$nombres"
}

# --- Comprobación de requisitos ---------------------------------------------------------------------
PROBLEMAS=0
problema() { mal "$1"; shift; local l; for l in "$@"; do printf '     %s\n' "$l" >&2; done; PROBLEMAS=$((PROBLEMAS + 1)); }

comprobar_docker() {
  DOCKER=""
  if ! command -v docker >/dev/null 2>&1; then
    problema "Docker no está instalado." \
      "Instálalo con:  curl -fsSL https://get.docker.com | sh" \
      "y después:      sudo usermod -aG docker \$USER   (cierra sesión y vuelve a entrar)" \
      "(./install.sh sin --comprobar lo instala por ti)."
    return
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER="docker"
  elif sudo -n docker info >/dev/null 2>&1 || { [ "$MODO" = instalar ] && sudo docker info >/dev/null 2>&1; }; then
    DOCKER="sudo docker"
  else
    problema "Docker está instalado pero no responde (o tu usuario no tiene permiso)." \
      "Arráncalo:     sudo systemctl enable --now docker" \
      "Dale permiso:  sudo usermod -aG docker \$USER   (cierra sesión y vuelve a entrar)"
    return
  fi
  ok "Docker funciona"
  if $DOCKER compose version >/dev/null 2>&1; then
    ok "Docker Compose v2 disponible"
  else
    problema "Falta Docker Compose v2 (el comando 'docker compose')." \
      "Instálalo con:  sudo apt install -y docker-compose-plugin"
  fi
}

comprobar_arquitectura() {
  local arq
  arq="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "$arq" in
    arm64|aarch64|amd64|x86_64|armhf|armv7l|armel|armv6l) ok "Arquitectura compatible ($arq)" ;;
    *) problema "Arquitectura no compatible: $arq." \
         "Pi-hole y Unbound necesitan un equipo arm64 o amd64 (64 bits) o una Raspberry Pi de 32 bits (armhf)." ;;
  esac
}

comprobar_puertos() {
  if [ -n "${DOCKER:-}" ] && contenedor_activo shield-pihole; then
    ok "Puertos: SHIELD-DNS ya está en marcha y los usa"
    return
  fi
  if ! command -v ss >/dev/null 2>&1; then
    aviso "No puedo comprobar los puertos: falta 'ss' (instálalo con: sudo apt install -y iproute2)."
    return
  fi
  local lineas
  lineas="$( { escuchando udp 53; escuchando tcp 53; } | sort -u)"
  if [ -z "$lineas" ]; then
    ok "Puerto 53 (DNS) libre"
  elif grep -qE '127\.0\.0\.5[34]' <<<"$lineas"; then
    problema "El puerto 53 lo ocupa systemd-resolved (el DNS interno de Ubuntu y Debian)." \
      "Arreglo exacto (libera el 53 y la máquina sigue resolviendo nombres):" \
      "  sudo mkdir -p /etc/systemd/resolved.conf.d" \
      "  printf '[Resolve]\\nDNSStubListener=no\\n' | sudo tee /etc/systemd/resolved.conf.d/shield-dns.conf" \
      "  sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf" \
      "  sudo systemctl restart systemd-resolved" \
      "Después, vuelve a ejecutar: ./install.sh --comprobar"
  else
    problema "El puerto 53 (DNS) está ocupado por otro servicio:" \
      "$(head -n 3 <<<"$lineas")" \
      "Mira cuál es con:  sudo ss -tulpn | grep ':53 '" \
      "y detenlo antes de instalar. Los más habituales:" \
      "  dnsmasq:             sudo systemctl disable --now dnsmasq" \
      "  Pi-hole sin Docker:  sudo systemctl disable --now pihole-FTL" \
      "  BIND:                sudo systemctl disable --now named" \
      "  Otro contenedor:     docker ps   (y detén el que publique el 53)"
  fi
  local var def p
  for var in WEB_HTTP_PORT:8080 WEB_HTTPS_PORT:8443; do
    def="${var#*:}"; var="${var%%:*}"
    p="$(leer_env "$var")"; p="${p:-$def}"
    if [[ ! "$p" =~ ^[0-9]+$ ]] || [ "$p" -lt 1 ] || [ "$p" -gt 65535 ]; then
      problema "$var=$p no es un puerto válido." "Pon un número entre 1 y 65535 en .env (por defecto, $def)."
    elif [ -n "$(escuchando tcp "$p")" ]; then
      problema "El puerto $p/tcp (panel web) está ocupado." \
        "Elige otro en .env, p. ej. $var=$(otro_puerto "$p")  (si aún no tienes .env: cp .env.example .env)." \
        "Si usas ARIA, pon el mismo puerto en su SHIELD_URL."
    else
      ok "Puerto $p/tcp (panel web) libre"
    fi
  done
}

comprobar_todo() { comprobar_docker; comprobar_arquitectura; comprobar_puertos; }

# --- Modo --comprobar: solo informa, no cambia nada -------------------------------------------------
if [ "$MODO" = comprobar ]; then
  info "Comprobando los requisitos de SHIELD-DNS (no se cambia nada)..."
  comprobar_todo
  if [ "$PROBLEMAS" -eq 0 ]; then
    ok "Todo listo. Instala con: ./install.sh"
    exit 0
  fi
  mal "Hay $PROBLEMAS problema(s). Arréglalos con las instrucciones de arriba y repite: ./install.sh --comprobar"
  exit 1
fi

# --- 1. Requisitos ----------------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  info "Docker no está instalado. Instalando con el script oficial (get.docker.com)..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi
info "Comprobando requisitos..."
comprobar_todo
[ "$PROBLEMAS" -eq 0 ] || fallo "Todavía no se puede instalar: arregla lo de arriba y repite ./install.sh"

# --- 2. Configuración (.env) --------------------------------------------------------------------------
CLAVE_GENERADA=""
ASISTENTE="no"
if [ ! -f .env ]; then
  (umask 077; cp .env.example .env)
  poner_env TZ "$(zona_horaria)"
  ok "Creado .env (solo lo puede leer tu usuario)"
  if [ "$PREGUNTAR" = auto ] && [ -t 0 ] && [ -t 1 ]; then ASISTENTE="si"; fi
fi
chmod 600 .env

if [ "$ASISTENTE" = si ]; then
  printf '\n\033[1mConfiguración rápida\033[0m (Enter acepta lo que va entre corchetes)\n\n'
  clave=""; otra=""; resp=""
  for _ in 1 2 3; do
    read -rsp "1/2 Contraseña para el panel de Pi-hole [Enter = generar una segura]: " clave || true; echo
    [ -z "$clave" ] && break
    if [ "${#clave}" -lt 12 ]; then aviso "Debe tener al menos 12 caracteres."; clave=""; continue; fi
    if [[ ! "$clave" =~ ^[A-Za-z0-9._@%+=,:!*^-]+$ ]]; then
      aviso "Usa solo letras, números y estos símbolos: . _ - @ % + = , : ! * ^"; clave=""; continue
    fi
    read -rsp "    Repítela: " otra || true; echo
    [ "$clave" = "$otra" ] && break
    aviso "No coinciden."; clave=""
  done
  if [ -n "$clave" ]; then poner_env PIHOLE_PASSWORD "$clave"; ok "Contraseña guardada en .env"; fi
  read -rp "2/2 ¿Añadir las listas de bloqueo recomendadas (anuncios, rastreo y amenazas)? [S/n]: " resp || true
  case "${resp:-s}" in
    [nN]*) poner_env EXTRA_ADLISTS '""'; ok "Solo se usará la lista por defecto de Pi-hole" ;;
    *) ok "Se añadirán las listas recomendadas" ;;
  esac
  unset clave otra
fi

if [ -z "$(leer_env PIHOLE_PASSWORD)" ]; then
  CLAVE_GENERADA="$(generar_clave)"
  poner_env PIHOLE_PASSWORD "$CLAVE_GENERADA"
  ok "Contraseña del panel generada"
fi
if [ -z "$(leer_env LOCAL_DNS_HOSTS)" ]; then
  IP_PI="$(ip_lan)"
  if [ -n "$IP_PI" ]; then
    poner_env LOCAL_DNS_HOSTS "\"${IP_PI} aria.lan\""
    ok "aria.lan → ${IP_PI} (para entrar en ARIA con https://aria.lan)"
  else
    aviso "No sé la IP de esta máquina: aria.lan no se configura. Si lo quieres, pon en .env LOCAL_DNS_HOSTS=\"192.168.1.50 aria.lan\" con tu IP."
  fi
fi
chmod 600 .env
set -a
# shellcheck source=/dev/null
. ./.env
set +a
mkdir -p data/pihole

# --- 3. Arranque --------------------------------------------------------------------------------------
info "Arrancando contenedores..."
$DOCKER compose up -d

info "Esperando a que Pi-hole esté listo..."
estado="starting"
for _ in $(seq 1 60); do
  estado="$($DOCKER inspect -f '{{.State.Health.Status}}' shield-pihole 2>/dev/null || echo starting)"
  [ "$estado" = "healthy" ] && break
  sleep 3
done
[ "$estado" = "healthy" ] || fallo "Pi-hole no arrancó bien. Mira qué pasa con: docker compose logs pihole"
ok "Pi-hole funcionando"

# --- 4. Listas de bloqueo extra -------------------------------------------------------------------------
if [ -n "${EXTRA_ADLISTS:-}" ]; then
  for url in $EXTRA_ADLISTS; do
    $DOCKER exec shield-pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
      "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('${url//\'/}', 1, 'SHIELD-DNS');"
  done
  info "Actualizando listas de bloqueo (puede tardar un par de minutos)..."
  $DOCKER exec shield-pihole pihole -g >/dev/null
  ok "Listas actualizadas"
fi

# --- 5. Comprobación -------------------------------------------------------------------------------------
IP="$(ip_lan)"
if $DOCKER exec shield-pihole dig +short +time=5 @127.0.0.1 example.com >/dev/null 2>&1; then
  ok "El DNS responde"
else
  fallo "El DNS no responde. Mira qué pasa con: docker compose logs"
fi

# --- 6. Resumen y siguientes pasos -------------------------------------------------------------------------
ROUTER="$(ip_router)"; ROUTER="${ROUTER:-192.168.1.1}"
# La contraseña generada se muestra UNA sola vez y solo en una terminal (nunca en un registro).
if [ -n "$CLAVE_GENERADA" ] && [ -t 1 ]; then
  LINEA_CLAVE="${CLAVE_GENERADA}
                 ⚠ Guárdala ahora en tu gestor de contraseñas: no se volverá a mostrar.
                   (Queda en $(pwd)/.env, que solo puede leer tu usuario.)"
else
  LINEA_CLAVE="la de PIHOLE_PASSWORD en $(pwd)/.env   (grep PIHOLE_PASSWORD .env)"
fi
cat <<EOF

────────────────────────────────────────────────────────────────────
 ✔ SHIELD-DNS instalado
   Panel web:    https://${IP}:${WEB_HTTPS_PORT:-8443}/admin
                 (certificado propio: acepta el aviso del navegador)
   Contraseña:   ${LINEA_CLAVE}
   Servidor DNS: ${IP}

 SIGUIENTES PASOS
 1. Que toda la casa use SHIELD-DNS (en el router):
    a) Entra en el router: http://${ROUTER}  (usuario y clave suelen ir en su pegatina).
    b) Busca «DHCP», «LAN» o «Servidor DNS».
    c) DNS primario: ${IP}. DNS secundario: vacío o también ${IP}
       (si pones 8.8.8.8 u otro, muchos anuncios se colarán por ahí).
    d) Guarda, y desconecta y vuelve a conectar el Wi-Fi de tus dispositivos.
    ¿Tu router no deja cambiar el DNS? Ponlo en cada dispositivo:
    Ajustes → Wi-Fi → tu red → DNS manual → ${IP}
 2. Comprueba que bloquea, desde otro equipo:  nslookup doubleclick.net ${IP}
    Debe responder 0.0.0.0. En el panel verás las consultas en «Query Log».
 3. Importante: la Raspberry necesita IP fija (reserva DHCP en el router) y
    NUNCA abras los puertos 53, ${WEB_HTTP_PORT:-8080} ni ${WEB_HTTPS_PORT:-8443} en el router.
 ¿Usas HEIMDALL (VPN)? Instálalo después: usará este DNS automáticamente.
────────────────────────────────────────────────────────────────────
EOF
