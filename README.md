<a name="readme-top"></a>

<p align="center">
  <sub>Parte del ecosistema ARIA&nbsp;&nbsp;·&nbsp;&nbsp;<a href="https://github.com/BertMarti/ARIA">🤖 ARIA</a>&nbsp;&nbsp;·&nbsp;&nbsp;<b>🛡️ SHIELD-DNS</b>&nbsp;&nbsp;·&nbsp;&nbsp;<a href="https://github.com/BertMarti/HEIMDALL">🔐 HEIMDALL</a></sub>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/banner-oscuro.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/img/banner-claro.svg">
    <img alt="SHIELD-DNS: bloqueador de anuncios y rastreadores para toda la casa" src="docs/img/banner-oscuro.svg" width="100%">
  </picture>
</p>

<p align="center">
  <a href="LICENSE"><img alt="Licencia MIT" src="https://img.shields.io/badge/licencia-MIT-34d399?style=flat-square"></a>
  <img alt="100 % autoalojado" src="https://img.shields.io/badge/100%20%25-autoalojado-34d399?style=flat-square">
  <img alt="Docker Compose" src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white">
  <img alt="Pi-hole v6" src="https://img.shields.io/badge/Pi--hole-v6-96060C?style=flat-square&logo=pihole&logoColor=white">
  <img alt="Unbound con DNSSEC" src="https://img.shields.io/badge/Unbound-DNSSEC-38d6ff?style=flat-square">
</p>

<p align="center">
  <b><a href="#instalacion">🚀 Instalar</a></b>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#apuntarlo-como-dns">📡 Apuntarlo como DNS</a>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#con-aria">🤖 Con ARIA</a>&nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="#problemas-frecuentes">🆘 Problemas</a>
</p>

**SHIELD-DNS atrapa anuncios antes de que lleguen a tu casa.** Es un bloqueador de anuncios, rastreadores y dominios maliciosos para toda la red: Pi-hole filtra las consultas y Unbound las resuelve de forma independiente con validación DNSSEC.

<p align="left"><img src="docs/img/ping/ping-hola.svg" alt="Ping: «¡Eh, mira! 1.284 anuncios atrapados hoy»"></p>

<a id="ping"></a>
## 🧚 Ping

Ping es el hada de luz de ARIA que aquí vigila la puerta y atrapa anuncios antes de que entren. Sus avisos aparecen junto a las partes importantes del manual, sin galería aparte.

Instálalo en una Raspberry Pi o en cualquier Linux con Docker. Después apunta el router a `192.168.1.50` y móviles, teles, consolas y ordenadores quedan protegidos sin instalar nada en cada dispositivo.

<p align="center">
  <img alt="Panel de Pi-hole de SHIELD-DNS con consultas, bloqueos y gráficas" src="docs/img/captura-panel-pihole.png" width="100%">
  <br><sub>Panel de Pi-hole con datos de demostración.</sub>
</p>

> [!NOTE]
> Todos los ejemplos usan una red ficticia `192.168.1.0/24`, una máquina SHIELD-DNS en `192.168.1.50`, Madrid como zona horaria y `tu-dominio.com` como dominio de ejemplo.

## 🧭 En 30 segundos

```mermaid
flowchart LR
    D["📱 Cualquier dispositivo"] --> P["🛡️ Pi-hole"]
    P -->|"anuncio o rastreador"| X["🚫 0.0.0.0<br/>atrapado"]
    P -->|"dominio permitido"| U["🔐 Unbound + DNSSEC"]
    U --> I["🌍 Internet"]
```

1. Instala los dos contenedores.
2. Configura `192.168.1.50` como DNS en el DHCP del router.
3. Comprueba una consulta bloqueada y una normal.
4. Gestiona listas, grupos y estadísticas desde Pi-hole o ARIA.

## 📑 Índice

- [🔍 Qué incluye](#que-incluye)
- [🧚 Ping](#ping)
- [📋 Requisitos](#requisitos)
- [🚀 Instalación](#instalacion)
- [⚙️ Configuración](#configuracion)
- [📡 Apuntarlo como DNS](#apuntarlo-como-dns)
- [🧭 Operación diaria](#operacion-diaria)
- [🤖 Con ARIA](#con-aria)
- [🔐 Con HEIMDALL](#con-heimdall)
- [💾 Copias y actualizaciones](#copias-y-actualizaciones)
- [🆘 Problemas frecuentes](#problemas-frecuentes)
- [🔌 Puertos](#puertos)
- [🌐 Ecosistema ARIA](#ecosistema-aria)
- [📄 Licencia](#licencia)

<a id="que-incluye"></a>
## 🔍 Qué incluye

| Pieza | Función |
|---|---|
| **Pi-hole v6** | Bloqueo DNS, listas, allowlist, denylist, grupos, clientes, estadísticas y API REST. |
| **Unbound** | Resolvedor local que consulta la jerarquía DNS y valida DNSSEC. Pi-hole le envía las consultas por la red privada Docker. |
| **Listas** | Lista de Pi-hole más HaGeZi Multi y TIF mini, configuradas en `EXTRA_ADLISTS`. |
| **`aria.lan`** | Nombre local que el instalador apunta a la máquina para entrar en ARIA desde casa o la VPN. |

<a id="requisitos"></a>
## 📋 Requisitos

- Raspberry Pi 4/5 con Raspberry Pi OS de 64 bits, o PC/mini-PC con Debian, Ubuntu u otra distribución Linux.
- Docker y el plugin `docker compose v2`. `install.sh` instala Docker si falta.
- Puerto 53 TCP y UDP libre.
- IP fija o reserva DHCP para la máquina. En los ejemplos: `192.168.1.50`.

> [!WARNING]
> Windows, WSL2 y Docker Desktop no son recomendables para exponer DNS a toda la LAN: el puerto 53 y el acceso desde otros dispositivos suelen dar problemas.

<a id="instalacion"></a>
## 🚀 Instalación

<p align="right"><img src="docs/img/ping/ping-instala.svg" alt="Ping: «¿Instalado? Desde ya, ni un anuncio se me escapa»"></p>

```bash
sudo apt update && sudo apt install -y git openssl
mkdir -p ~/homelab && cd ~/homelab
git clone https://github.com/BertMarti/SHIELD-DNS.git
cd SHIELD-DNS
./install.sh
```

El instalador es idempotente y hace lo siguiente:

1. Comprueba Docker, Compose y el puerto 53.
2. Crea `.env` desde [`.env.example`](.env.example), genera la contraseña del panel y establece `aria.lan` con la IP detectada.
3. Arranca `shield-unbound` y `shield-pihole`, y espera el estado saludable de Pi-hole.
4. Registra y descarga las listas de `EXTRA_ADLISTS`.
5. Comprueba que el DNS responde.

Panel: `https://192.168.1.50:8443/admin`. El certificado es autofirmado. La contraseña está en `.env`:

```bash
grep PIHOLE_PASSWORD .env
```

<a id="configuracion"></a>
## ⚙️ Configuración

Edita `.env` y vuelve a ejecutar `./install.sh` para aplicar los valores:

| Variable | Valor inicial | Uso |
|---|---|---|
| `TZ` | `Europe/Madrid` | Zona horaria de los contenedores. |
| `PIHOLE_PASSWORD` | Aleatoria | Contraseña del panel y de la API. |
| `WEB_HTTP_PORT` | `8080` | Panel HTTP. |
| `WEB_HTTPS_PORT` | `8443` | Panel HTTPS. |
| `LOCAL_DNS_HOSTS` | `"<IP> aria.lan"` | Nombres locales con formato `IP nombre;IP nombre`. |
| `EXTRA_ADLISTS` | HaGeZi Multi y TIF mini | URLs separadas por espacios. |

Para añadir otro nombre local:

```bash
LOCAL_DNS_HOSTS="192.168.1.50 aria.lan;192.168.1.50 nas.lan"
```

Las listas, dominios permitidos/bloqueados, clientes y grupos también se administran desde el panel de Pi-hole.

<a id="apuntarlo-como-dns"></a>
## 📡 Apuntarlo como DNS

### Router, opción recomendada

1. Abre el router, normalmente `http://192.168.1.1`.
2. Busca **LAN**, **DHCP** o **DNS**.
3. Pon `192.168.1.50` como DNS primario.
4. Deja vacío el secundario o repite `192.168.1.50`. Un DNS externo permite saltarse el bloqueo.
5. Guarda y renueva el Wi-Fi o el DHCP de los dispositivos.

Si el router no deja cambiar el DNS, puedes desactivar su DHCP y activar el DHCP de Pi-hole desde *Settings → DHCP*. Hazlo solo cuando tengas acceso al panel.

### Un dispositivo concreto

| Dispositivo | Ajuste |
|---|---|
| Android | Wi-Fi → tu red → IP estática → DNS 1: `192.168.1.50`. Desactiva **DNS privado**. |
| iPhone/iPad | Wi-Fi → (i) → Configurar DNS → Manual → `192.168.1.50`. |
| Windows, macOS o Linux | Configuración de red → DNS manual: `192.168.1.50`. |

> [!IMPORTANT]
> Si el router anuncia un DNS IPv6 del operador, algunos equipos lo usarán y evitarán SHIELD-DNS. Configura el DNS IPv6 o desactívalo en la LAN.

Comprueba desde un equipo de la red `192.168.1.0/24`:

```bash
nslookup doubleclick.net 192.168.1.50  # debe devolver 0.0.0.0
nslookup example.com 192.168.1.50      # debe devolver una IP normal
```

<a id="operacion-diaria"></a>
## 🧭 Operación diaria

| Necesidad | Acción |
|---|---|
| Ver consultas y bloqueos | Panel → **Dashboard** o **Query Log**. |
| Permitir un dominio | `docker exec shield-pihole pihole allow ejemplo.com` |
| Bloquear un dominio | `docker exec shield-pihole pihole deny ejemplo.com` |
| Actualizar listas ahora | `docker exec shield-pihole pihole -g` |
| Pausar el bloqueo | Panel → **Disable blocking**; Pi-hole ofrece 10 s, 5 min, 30 min o hasta reactivar. |
| Ver logs | `docker compose logs -f pihole` |
| Ver estado | `docker compose ps` |

El bloqueo DNS no puede distinguir un anuncio que comparte dominio con el contenido, como algunos anuncios de vídeo. Si una app se rompe, busca el dominio en **Query Log** y añádelo a la allowlist solo si confías en él.

<a id="con-aria"></a>
## 🤖 Con ARIA

<p align="left"><img src="docs/img/ping/ping-aria.svg" alt="Ping: «ARIA ya sabe quién llamó al DNS»"></p>

ARIA se conecta a la API de Pi-hole y convierte SHIELD-DNS en una pieza operable desde el panel y el chat. Si ambos proyectos están en `~/homelab/SHIELD-DNS` y `~/homelab/ARIA`, su instalador detecta la contraseña de Pi-hole. Si no, configura en el `.env` de ARIA:

```bash
SHIELD_URL=http://192.168.1.50:8080
SHIELD_PASSWORD=la-contraseña-de-pihole
```

ARIA ofrece:

- Estadísticas de consultas y bloqueos en el Centro de control.
- Pausar el bloqueo 5, 30 o 60 minutos, y reanudarlo.
- Preguntas en el chat como «¿cuántos anuncios has bloqueado hoy?» y `/bloqueo` en Telegram.
- Resumen diario con bloqueos y aviso si SHIELD-DNS deja de responder.
- Informe semanal por Telegram.
- Listas: ver el número de dominios y lanzar una actualización de gravity.
- Control parental por dispositivo: por ejemplo, pausar el dispositivo de Ana, bloquear servicios y aplicar horarios.
- Grupos propios de Pi-hole como `ARIA-pausa` y `ARIA-svc-...`, sin tocar grupos ajenos.
- Control opcional de nombres conocidos de DNS cifrado por dispositivo para evitar saltos sencillos al filtro.

El control parental es bloqueo DNS: no puede impedir DNS fijado manualmente, todo DNS cifrado ni una VPN. Para una dirección pública usa, por ejemplo, `https://shield.tu-dominio.com` a través de la configuración de ARIA/HEIMDALL.

<p align="center">
  <img alt="Tarjeta de SHIELD-DNS en el Centro de control de ARIA" src="docs/img/captura-aria-shield.png" width="72%">
  <br><sub>Tarjeta de SHIELD-DNS en ARIA con datos de demostración.</sub>
</p>

<a id="con-heimdall"></a>
## 🔐 Con HEIMDALL

Si instalas SHIELD-DNS antes que HEIMDALL, la VPN lo usa como DNS automáticamente. Así el móvil sigue filtrando anuncios fuera de casa. Si instalaste HEIMDALL primero, configura `192.168.1.50` como DNS en su panel de administración.

```mermaid
flowchart LR
    M["📱 Móvil fuera de casa"] --> H["🔐 HEIMDALL / WireGuard"]
    H --> S["🛡️ SHIELD-DNS"]
    S --> M
```

<a id="copias-y-actualizaciones"></a>
## 💾 Copias y actualizaciones

### Copia

```bash
./backup.sh
```

Crea `backups/shield-dns-AAAAMMDD-HHMM.tar.gz` con `.env` y una exportación Teleporter de Pi-hole: listas, allowlist, denylist, clientes, grupos y ajustes. Conserva las siete más recientes y protege el archivo con permisos `600`. Contiene la contraseña: guárdalo fuera de la máquina.

### Restauración

```bash
mkdir -p backups
cp /ruta/a/shield-dns-AAAAMMDD-HHMM.tar.gz backups/
./restore.sh backups/shield-dns-AAAAMMDD-HHMM.tar.gz
```

El script pide confirmación, restaura `.env`, instala y carga de nuevo la configuración de Pi-hole.

### Actualización

```bash
./update.sh
```

Hace una copia, ejecuta `git pull --ff-only`, descarga imágenes nuevas y vuelve a instalar. Los datos de `data/pihole/` se conservan.

<a id="problemas-frecuentes"></a>
## 🆘 Problemas frecuentes

<p align="right"><img src="docs/img/ping/ping-problemas.svg" alt="Ping: «¡Alerta! Ese anuncio intentó colarse»"></p>

<details>
<summary><b>El puerto 53 está ocupado</b></summary>

```bash
sudo ss -tulpn | grep 53
sudo systemctl disable --now systemd-resolved
# o, si existía un Pi-hole nativo:
sudo systemctl disable --now pihole-FTL
./install.sh
```
</details>

<details>
<summary><b>La casa se queda sin internet</b></summary>

Comprueba `docker compose ps` y `docker compose logs pihole`. Mientras lo solucionas, devuelve temporalmente al router el DNS anterior. Tras desinstalar, ejecuta también `./uninstall.sh` y recuerda cambiar el DNS del router.
</details>

<details>
<summary><b>No se bloquean anuncios</b></summary>

Comprueba que el dispositivo recibe `192.168.1.50`, desactiva **DNS privado**, revisa IPv6 y confirma en **Query Log** que llegan consultas. YouTube y otros servicios pueden mezclar anuncio y contenido en el mismo dominio.
</details>

<details>
<summary><b>Una web o aplicación deja de funcionar</b></summary>

Busca la consulta bloqueada en **Query Log** y permítela desde el panel o con `docker exec shield-pihole pihole allow dominio.com`.
</details>

<details>
<summary><b>El panel no carga u olvidé la contraseña</b></summary>

Usa `https://192.168.1.50:8443/admin`, con `/admin`, y revisa `docker compose logs pihole`. La contraseña está en `.env`: `grep PIHOLE_PASSWORD .env`.
</details>

<details>
<summary><b>DNSSEC falla</b></summary>

Unbound es quien valida DNSSEC; Pi-hole lo deja desactivado para no validarlo dos veces. Comprueba el resolvedor con `docker compose logs unbound` y el estado con `docker compose ps`.
</details>

<a id="puertos"></a>
## 🔌 Puertos

| Contenedor | Puerto | Uso |
|---|---|---|
| `shield-pihole` | `53/tcp` y `53/udp` | DNS de la red. |
| `shield-pihole` | `8080/tcp` | Panel HTTP. |
| `shield-pihole` | `8443/tcp` | Panel HTTPS autofirmado. |
| `shield-unbound` | Interno | Resolvedor en la red Docker `172.30.53.0/24`. |

> [!WARNING]
> No abras estos puertos en el router. El DNS solo debe responder desde la LAN y, si procede, desde la VPN.

<a id="ecosistema-aria"></a>
## 🌐 Ecosistema ARIA

| Proyecto | Función | Puertos |
|---|---|---|
| [ARIA](https://github.com/BertMarti/ARIA) | Asistente y panel central de la casa. | 80, 443 |
| **SHIELD-DNS** | Bloqueador DNS con Pi-hole y Unbound. | 53, 8080, 8443 |
| [HEIMDALL](https://github.com/BertMarti/HEIMDALL) | VPN WireGuard para entrar en casa desde fuera. | 51820/udp, 51843 |

<a id="licencia"></a>
## 📄 Licencia

MIT. Consulta [LICENSE](LICENSE).

<p align="right"><img src="docs/img/ping/ping-despedida.svg" alt="Ping: «Menos anuncios, más paz en casa»"><br><a href="#readme-top">⬆️ Volver arriba</a></p>
