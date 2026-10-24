#!/usr/bin/env bash
# Pruebas de install.sh SIN tocar nada real: cada caso copia el instalador a una carpeta temporal y
# lo ejecuta con un PATH aislado en el que docker, sudo, ss, curl, ip... son dobles de prueba.
# Nunca llega a Docker, a la red ni a los puertos de verdad. Uso: tests/instalador.sh
# Las comillas simples son a propósito (dobles de prueba y condiciones que se evalúan después) y
# CODIGO se usa dentro de esas condiciones con eval.
# shellcheck disable=SC2016,SC2034
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d)"; trap 'rm -rf "$BASE"' EXIT
SCRIPT_BIN="$(command -v script || true)"
FALLOS=0; TOTAL=0

# Herramientas reales permitidas. docker, sudo, ss, curl, ip, hostname... NO están: son dobles.
SYS="$BASE/sys"; mkdir -p "$SYS"
for h in bash sh env awk sed grep cat cut tr head tail base64 chmod cp mv mkdir mktemp rm seq sort \
         dirname wc uname stat ls tee; do
  r="$(command -v "$h")" && ln -s "$r" "$SYS/$h"
done

doble() { printf '#!/bin/sh\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }

preparar() {
  CASO="$BASE/caso$((TOTAL + 1))"; STUBS="$CASO/dobles"; LOG="$CASO/llamadas.log"
  mkdir -p "$CASO/repo" "$STUBS"; : > "$LOG"
  cp "$RAIZ/install.sh" "$RAIZ/.env.example" "$RAIZ/docker-compose.yml" "$CASO/repo/"
  doble docker 'echo "docker $*" >> "$LOG"
case "$1" in
  info) exit "${DOBLE_DOCKER_INFO:-0}" ;;
  compose) [ "$2" = version ] && echo "Docker Compose version v2.40.0"; exit 0 ;;
  ps) for c in ${DOBLE_CONTENEDORES:-}; do echo "$c"; done; exit 0 ;;
  inspect) echo healthy ;;
esac
exit 0'
  doble sudo 'echo "sudo $*" >> "$LOG"; [ "$1" = -n ] && shift; exec "$@"'
  doble ss 'case "$1" in -tlnH) cat "${DOBLE_SS_TCP:-/dev/null}" ;; -ulnH) cat "${DOBLE_SS_UDP:-/dev/null}" ;; esac'
  doble dpkg 'echo "${DOBLE_ARQ:-arm64}"'
  doble hostname '[ "$1" = -I ] && echo "192.168.1.50 172.17.0.1" || echo raspberrypi'
  doble ip 'echo "default via 192.168.1.1 dev eth0 proto dhcp"'
  doble timedatectl 'echo Europe/Madrid'
  doble curl 'echo "curl $*" >> "$LOG"; exit 1'
  doble sleep 'exit 0'
}

# ejecutar [VAR=valor ...] -- [argumentos de install.sh]   (sin terminal: stdin vacío)
ejecutar() {
  local vars=(); while [ "$1" != -- ]; do vars+=("$1"); shift; done; shift
  (cd "$CASO/repo" && env -i PATH="$STUBS:$SYS" HOME="$CASO" USER=prueba LOG="$LOG" "${vars[@]}" \
     bash ./install.sh "$@") > "$CASO/salida.txt" 2>&1 < /dev/null
  CODIGO=$?
}

# en_terminal "respuestas" [VAR=valor ...]: ejecuta con una terminal de verdad (script) y teclea las respuestas
en_terminal() {
  local respuestas="$1"; shift
  (cd "$CASO/repo" && printf '%b' "$respuestas" | env -i PATH="$STUBS:$SYS" HOME="$CASO" USER=prueba \
     LOG="$LOG" TERM=dumb "$@" "$SCRIPT_BIN" -qec "bash ./install.sh" /dev/null) > "$CASO/salida.txt" 2>&1
  CODIGO=$?
}

prueba() { # prueba "descripción" condición...
  local desc="$1"; shift; TOTAL=$((TOTAL + 1))
  if "$@"; then echo "ok $TOTAL - $desc"
  else echo "FALLO $TOTAL - $desc"; FALLOS=$((FALLOS + 1)); sed 's/^/    | /' "$CASO/salida.txt" | tail -n 25; fi
}
salida_tiene() { grep -qF -- "$1" "$CASO/salida.txt"; }
log_tiene()    { grep -qF -- "$1" "$LOG"; }
env_valor()    { grep -E "^$1=" "$CASO/repo/.env" | tail -n1 | cut -d= -f2-; }
veces()        { grep -oF -- "$1" "$CASO/salida.txt" | wc -l | tr -d ' '; }
# Solo el resumen final. (Con `script`, la terminal de prueba repite al principio todo lo tecleado
# antes de que `read -s` apague el eco; con una persona tecleando eso no ocurre.)
veces_resumen() { sed -n '/SHIELD-DNS instalado/,$p' "$CASO/salida.txt" | grep -oF -- "$1" | wc -l | tr -d ' '; }

# --- Ayuda y opciones ---
preparar; ejecutar -- --ayuda
prueba "--ayuda explica --comprobar y sale con 0" eval '[ $CODIGO -eq 0 ] && salida_tiene "--comprobar"'
preparar; ejecutar -- --inventada
prueba "una opción desconocida sale con 2 y lo dice" eval '[ $CODIGO -eq 2 ] && salida_tiene "Opción desconocida"'

# --- --comprobar ---
preparar; ejecutar -- --comprobar
prueba "--comprobar con todo bien: sale con 0 y dice cómo instalar" eval '[ $CODIGO -eq 0 ] && salida_tiene "Todo listo"'
prueba "--comprobar no crea .env ni arranca nada" eval '[ ! -e "$CASO/repo/.env" ] && ! log_tiene "compose up" && ! log_tiene "curl"'

preparar; printf 'UNCONN 0 0 127.0.0.53%%lo:53 0.0.0.0:*\nUNCONN 0 0 127.0.0.54:53 0.0.0.0:*\n' > "$CASO/udp"
ejecutar DOBLE_SS_UDP="$CASO/udp" -- --comprobar
prueba "puerto 53 de systemd-resolved: falla y da el arreglo exacto" \
  eval '[ $CODIGO -eq 1 ] && salida_tiene "systemd-resolved" && salida_tiene "DNSStubListener=no" && salida_tiene "sudo systemctl restart systemd-resolved"'

preparar; printf 'LISTEN 0 32 0.0.0.0:53 0.0.0.0:*\n' > "$CASO/tcp"
ejecutar DOBLE_SS_TCP="$CASO/tcp" -- --comprobar
prueba "puerto 53 ocupado por otro servicio: falla y dice cómo averiguar cuál" \
  eval '[ $CODIGO -eq 1 ] && salida_tiene "ocupado por otro servicio" && salida_tiene "sudo ss -tulpn"'

preparar; printf 'LISTEN 0 32 0.0.0.0:53 0.0.0.0:*\n' > "$CASO/tcp"
ejecutar DOBLE_SS_TCP="$CASO/tcp" DOBLE_CONTENEDORES="shield-unbound shield-pihole" -- --comprobar
prueba "si SHIELD-DNS ya está en marcha, sus propios puertos no son un problema" eval '[ $CODIGO -eq 0 ]'

preparar; printf 'LISTEN 0 32 *:8080 *:*\n' > "$CASO/tcp"
ejecutar DOBLE_SS_TCP="$CASO/tcp" -- --comprobar
prueba "puerto 8080 ocupado: falla y propone WEB_HTTP_PORT=8081" eval '[ $CODIGO -eq 1 ] && salida_tiene "WEB_HTTP_PORT=8081"'

preparar; printf 'LISTEN 0 32 *:5353 *:*\nLISTEN 0 32 *:18080 *:*\n' > "$CASO/tcp"
ejecutar DOBLE_SS_TCP="$CASO/tcp" -- --comprobar
prueba "puertos parecidos (5353, 18080) no cuentan como ocupados" eval '[ $CODIGO -eq 0 ]'

preparar; rm "$STUBS/docker"; ejecutar -- --comprobar
prueba "sin Docker: falla, explica cómo instalarlo y NO lo instala" \
  eval '[ $CODIGO -eq 1 ] && salida_tiene "Docker no está instalado" && salida_tiene "get.docker.com" && ! log_tiene "curl"'

preparar; ejecutar DOBLE_DOCKER_INFO=1 -- --comprobar
prueba "Docker sin permiso o parado: falla y da los dos arreglos" \
  eval '[ $CODIGO -eq 1 ] && salida_tiene "systemctl enable --now docker" && salida_tiene "usermod -aG docker"'

preparar; ejecutar DOBLE_ARQ=i386 -- --comprobar
prueba "arquitectura no compatible: falla y lo explica" eval '[ $CODIGO -eq 1 ] && salida_tiene "Arquitectura no compatible"'

preparar; ejecutar DOBLE_ARQ=armhf -- --comprobar
prueba "Raspberry Pi de 32 bits (armhf) es compatible" eval '[ $CODIGO -eq 0 ]'

# --- Instalación sin terminal (como desde ARIA: curl | bash) ---
preparar; ejecutar -- --sin-preguntas
CLAVE="$(env_valor PIHOLE_PASSWORD)"
prueba "instalación sin preguntas: termina bien y arranca los contenedores" eval '[ $CODIGO -eq 0 ] && log_tiene "compose up -d"'
prueba ".env queda con permisos 600" eval '[ "$(stat -c %a "$CASO/repo/.env")" = 600 ]'
prueba "contraseña generada de 24 caracteres alfanuméricos" eval '[[ "$CLAVE" =~ ^[A-Za-z0-9]{24}$ ]]'
prueba "sin terminal la contraseña NO se imprime (no acaba en registros)" eval '[ "$(veces "$CLAVE")" -eq 0 ] && salida_tiene "grep PIHOLE_PASSWORD .env"'
prueba "resumen con los pasos del router y la IP del router detectada" \
  eval 'salida_tiene "http://192.168.1.1" && salida_tiene "DNS primario: 192.168.1.50" && salida_tiene "nslookup doubleclick.net 192.168.1.50"'
prueba "aria.lan apunta a la IP de la máquina" eval '[ "$(env_valor LOCAL_DNS_HOSTS)" = "\"192.168.1.50 aria.lan\"" ]'

preparar; printf 'UNCONN 0 0 127.0.0.53%%lo:53 0.0.0.0:*\n' > "$CASO/udp"
ejecutar DOBLE_SS_UDP="$CASO/udp" -- --sin-preguntas
prueba "instalación con el 53 ocupado: se detiene antes de crear .env" eval '[ $CODIGO -eq 1 ] && [ ! -e "$CASO/repo/.env" ] && ! log_tiene "compose up"'

# --- Ruta de ./update.sh: .env ya existe ---
preparar; cp "$CASO/repo/.env.example" "$CASO/repo/.env"
sed -i -e 's/^PIHOLE_PASSWORD=.*/PIHOLE_PASSWORD=ya-existente-solo-pruebas/' -e 's/^LOCAL_DNS_HOSTS=.*/LOCAL_DNS_HOSTS="192.168.1.50 aria.lan"/' "$CASO/repo/.env"
cp "$CASO/repo/.env" "$CASO/env-antes"
printf 'LISTEN 0 32 0.0.0.0:53 0.0.0.0:*\nLISTEN 0 4096 0.0.0.0:8080 0.0.0.0:*\nLISTEN 0 4096 0.0.0.0:8443 0.0.0.0:*\n' > "$CASO/tcp"
printf 'UNCONN 0 0 0.0.0.0:53 0.0.0.0:*\n' > "$CASO/udp"
if [ -n "$SCRIPT_BIN" ]; then
  en_terminal "" DOBLE_CONTENEDORES="shield-unbound shield-pihole" DOBLE_SS_TCP="$CASO/tcp" DOBLE_SS_UDP="$CASO/udp"
else
  ejecutar DOBLE_CONTENEDORES="shield-unbound shield-pihole" DOBLE_SS_TCP="$CASO/tcp" DOBLE_SS_UDP="$CASO/udp" --
fi
prueba "con .env existente (update.sh) y sus puertos 53/8080/8443 en uso por SHIELD-DNS: no pregunta y termina bien" eval '[ $CODIGO -eq 0 ] && ! salida_tiene "Configuración rápida"'
prueba "con .env existente no cambia .env ni muestra la contraseña" \
  eval 'cmp -s "$CASO/env-antes" "$CASO/repo/.env" && [ "$(veces ya-existente-solo-pruebas)" -eq 0 ]'

# --- Asistente en una terminal de verdad ---
if [ -n "$SCRIPT_BIN" ]; then
  preparar; en_terminal '\n\n'
  CLAVE="$(env_valor PIHOLE_PASSWORD)"
  prueba "asistente: Enter genera la contraseña y la muestra UNA sola vez" \
    eval '[ $CODIGO -eq 0 ] && salida_tiene "Configuración rápida" && [[ "$CLAVE" =~ ^[A-Za-z0-9]{24}$ ]] && [ "$(veces "$CLAVE")" -eq 1 ] && salida_tiene "no se volverá a mostrar"'
  prueba "asistente: por defecto añade las listas recomendadas" eval 'log_tiene "pihole -g"'

  preparar; en_terminal 'corta\nMiClaveSegura2026\nMiClaveSegura2026\nn\n'
  prueba "asistente: rechaza una contraseña corta y guarda la elegida" \
    eval '[ $CODIGO -eq 0 ] && salida_tiene "al menos 12" && [ "$(env_valor PIHOLE_PASSWORD)" = MiClaveSegura2026 ]'
  prueba "asistente: con la contraseña elegida, el resumen no la repite" \
    eval 'salida_tiene "grep PIHOLE_PASSWORD .env" && [ "$(veces_resumen MiClaveSegura2026)" -eq 0 ]'
  prueba "asistente: «n» deja solo la lista por defecto" eval '[ "$(env_valor EXTRA_ADLISTS)" = "\"\"" ] && ! log_tiene "pihole -g"'

  preparar; en_terminal 'Clave.Segura_2026!@%+=,:*^-\nClave.Segura_2026!@%+=,:*^-\n\n'
  prueba "asistente: una contraseña con todos los símbolos permitidos se guarda literal y .env se carga bien" \
    eval '[ $CODIGO -eq 0 ] && [ "$(env_valor PIHOLE_PASSWORD)" = "Clave.Segura_2026!@%+=,:*^-" ]'

  preparar; en_terminal 'con espacios y $raros\n\nn\n'
  prueba "asistente: rechaza símbolos peligrosos y acaba generando una" \
    eval '[ $CODIGO -eq 0 ] && salida_tiene "Usa solo letras" && [[ "$(env_valor PIHOLE_PASSWORD)" =~ ^[A-Za-z0-9]{24}$ ]]'
else
  echo "# aviso: falta 'script' (util-linux); se omiten las pruebas con terminal"
fi

echo "---"
echo "$((TOTAL - FALLOS))/$TOTAL pruebas correctas"
[ "$FALLOS" -eq 0 ]
