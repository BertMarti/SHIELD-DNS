# Guía técnica de SHIELD-DNS

Para quien quiera modificar o mantener SHIELD-DNS. La guía de uso está en el [README](../README.md).

## Propósito

SHIELD-DNS combina Pi-hole v6 y Unbound en Docker para filtrar DNS en una red doméstica. Pi-hole gestiona listas, consultas, grupos y API; Unbound resuelve localmente y valida DNSSEC.

## Estructura

`docker-compose.yml` define los servicios. `install.sh` instala y arranca; `update.sh` hace copia, ejecuta `git pull --ff-only`, descarga imágenes y reinstala; `backup.sh` exporta `.env` y Teleporter; `restore.sh` recupera ambos; `uninstall.sh` elimina contenedores y, con `--purge`, datos. `site/` contiene la web estática. `docs/img/` contiene banners, capturas y Ping.

## Servicios y red

La red Docker `shield-dns` es una subred /24 privada con IPs fijas para cada contenedor (los valores exactos están en `docker-compose.yml`). Pi-hole usa la IP fija de Unbound, puerto 53, como único upstream (`FTLCONF_dns_upstreams`). Solo Pi-hole publica DNS y panel; Unbound es interno.

| Servicio | Imagen actual | Uso |
|---|---|---|
| `shield-unbound` | `klutchell/unbound:1.26.1@sha256:9a3939ca33d6d3b42b81a70391bb8e43f0a08d2bd7a3fdffb43d427493345c36` | Resolución recursiva y DNSSEC. |
| `shield-pihole` | `pihole/pihole:2026.09.0@sha256:5b9c8cf51de7d6d3f2240dbe72baf5f06e1fd39cb4d77a99fab4fa13e23bd1be` | Filtrado, panel y API. |

| Puerto publicado | Uso |
|---|---|
| `53/tcp`, `53/udp` | DNS de la LAN. |
| `8080/tcp` | Panel HTTP; ARIA lo usa hoy en la LAN. |
| `8443/tcp` | Panel HTTPS autofirmado. |

`FTLCONF_dns_listeningMode` es `ALL` porque Pi-hole debe responder a clientes que llegan desde la LAN y desde la red Docker, no solo a localhost. `FTLCONF_dns_dnssec` es `false`: Unbound valida DNSSEC una sola vez y Pi-hole propaga `SERVFAIL` cuando corresponde.

<a id="configuracion"></a>

## Variables (`.env`)

Edita `.env` y vuelve a ejecutar `./install.sh` para aplicar los valores.

| Variable | Ejemplo | Función |
|---|---|---|
| `TZ` | `Europe/Madrid` | Zona horaria. |
| `PIHOLE_PASSWORD` | Vacía en la plantilla | Contraseña del panel y API; el instalador la genera. |
| `WEB_HTTP_PORT` | `8080` | Puerto HTTP del host. |
| `WEB_HTTPS_PORT` | `8443` | Puerto HTTPS del host. |
| `LOCAL_DNS_HOSTS` | `192.168.1.50 aria.lan` | Entradas locales separadas por `;`. |
| `EXTRA_ADLISTS` | URLs separadas por espacios | Listas adicionales. |

Para añadir otro nombre local:

```bash
LOCAL_DNS_HOSTS="192.168.1.50 aria.lan;192.168.1.50 nas.lan"
```

Pi-hole v6 usa `POST /api/auth` con JSON. No documentar autenticación básica. Para cambiar la contraseña: editar `PIHOLE_PASSWORD` en `.env` y ejecutar `docker compose up -d`; las variables `FTLCONF_` se aplican en cada arranque.

## Scripts

`install.sh` acepta `--comprobar` (solo comprueba requisitos y puertos), `--sin-preguntas` y `--ayuda`. Sin `.env`, en una terminal ofrece dos preguntas; con `.env` no pregunta. Crea `.env` con permisos `600`, genera una contraseña si hace falta, detecta la IP para `aria.lan`, crea `data/pihole`, arranca los contenedores, espera el estado saludable, registra `EXTRA_ADLISTS`, reconstruye gravity y prueba una consulta. `backup.sh` crea una copia Teleporter, incluye `.env`, usa permisos `600` y conserva siete copias. `restore.sh` pide confirmación, restaura `.env`, instala y carga Teleporter. `uninstall.sh` conserva datos por defecto y los purga solo con `--purge`.

## Versiones fijadas

Las imágenes están fijadas a exactamente lo desplegado el 24/10/2026:

| Imagen | Versión | Digest |
|---|---|---|
| `pihole/pihole` | `2026.09.0` | `sha256:5b9c8cf51de7d6d3f2240dbe72baf5f06e1fd39cb4d77a99fab4fa13e23bd1be` |
| `klutchell/unbound` | `1.26.1` | `sha256:9a3939ca33d6d3b42b81a70391bb8e43f0a08d2bd7a3fdffb43d427493345c36` |

Para comprobar la imagen local desplegada y consultar los manifiestos del registro:

```bash
# solo lectura: digest de la imagen con la que corre cada contenedor
docker image inspect --format '{{json .RepoDigests}}' "$(docker inspect -f '{{.Image}}' shield-pihole)"
docker image inspect --format '{{json .RepoDigests}}' "$(docker inspect -f '{{.Image}}' shield-unbound)"
docker buildx imagetools inspect pihole/pihole:2026.09.0
docker buildx imagetools inspect klutchell/unbound:1.26.1
```

Para actualizar, revisa primero la compatibilidad con ARIA y el cambio de API, actualiza la versión y el digest en `docker-compose.yml`, valida el Compose y ejecuta `./update.sh` en un momento tranquilo. Dependabot propone solo parches y menores; las versiones mayores se revisan a mano. En Pi-hole, `2027.x` es mayor porque usa el año como versión.

## Operación diaria desde la terminal

Desde la carpeta de SHIELD-DNS (en una máquina de pruebas o, en la de casa, solo cuando sepas lo que haces):

| Necesidad | Orden |
|---|---|
| Ver estado | `docker compose ps` |
| Permitir un dominio | `docker exec shield-pihole pihole allow ejemplo.com` |
| Bloquear un dominio | `docker exec shield-pihole pihole deny ejemplo.com` |
| Actualizar listas ahora | `docker exec shield-pihole pihole -g` |
| Ver registros | `docker compose logs -f pihole` (o `unbound`) |
| Probar el DNS dentro del contenedor | `docker exec shield-pihole dig @127.0.0.1 example.com` |

Comprobaciones desde otro equipo de la red:

```bash
dig @192.168.1.50 example.com          # status: NOERROR
dig @192.168.1.50 doubleclick.net +short  # 0.0.0.0 (bloqueado)
dig @192.168.1.50 dnssec-failed.org    # status: SERVFAIL (DNSSEC validado por Unbound)
```

Puerto 53 ocupado al instalar:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/shield-dns.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
./install.sh --comprobar
```

Si lo ocupa otro servicio, localizarlo con `sudo ss -tulpn | grep ':53 '`. Los habituales son `dnsmasq`, un Pi-hole nativo (`pihole-FTL`) y `named`; si ya lo usa SHIELD-DNS, no es un problema.

El panel permite consultar **Dashboard**, **Query Log**, listas, clientes, grupos y la pausa temporal del bloqueo.

## Listas y copias

Pi-hole incluye su lista por defecto. `EXTRA_ADLISTS` añade HaGeZi Multi y TIF mini. El instalador registra las URLs en gravity y ejecuta `pihole -g`. Las copias Teleporter incluyen listas, allowlist, denylist, clientes, grupos y ajustes.

## Integración

ARIA usa la API de Pi-hole para estadísticas, pausas, listas, avisos y control parental DNS. HEIMDALL puede usar `192.168.1.50` como DNS de la VPN si SHIELD-DNS está instalado antes, o configurándolo en su panel. El acceso público pasa por la configuración de ARIA/HEIMDALL; no se debe publicar el DNS.

## Validación, CI y Pages

Validación local (sin tocar producción):

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
tests/instalador.sh
cp .env.example /tmp/shield.env && sed -i 's/^PIHOLE_PASSWORD=.*/PIHOLE_PASSWORD=solo-para-pruebas/' /tmp/shield.env
docker compose --env-file /tmp/shield.env config -q
gitleaks git . --redact
site/construir.sh /tmp/shield-web/SHIELD-DNS && python3 -m http.server 8000 -d /tmp/shield-web   # http://localhost:8000/SHIELD-DNS/
```
`tests/instalador.sh` contiene 29 pruebas del instalador con dobles de Docker, sudo, ss, curl, ip y otros comandos; copia el instalador a una carpeta temporal y no toca Docker real, la red ni puertos. Usa `script` (util-linux) para probar la ejecución con terminal. CI ejecuta esas pruebas en el job «Scripts», junto a `bash -n` y ShellCheck de `tests/*.sh`; también verifica que solo se publican 53, 8080 y 8443, revisa la web y analiza el historial con gitleaks. `contents: read` limita permisos. Dependabot agrupa semanalmente actualizaciones de imágenes Docker y Actions.

Pages construye con `site/construir.sh _site`, copia `site/` y `docs/img` a `_site/img`, y publica `https://bertmarti.github.io/SHIELD-DNS/`. No publica la documentación como sitio independiente.

## Gotchas

- El puerto 53 debe estar libre; `systemd-resolved` o un Pi-hole nativo pueden ocuparlo.
- La primera carga de listas puede tardar varios minutos.
- IPv6 anunciado por el router puede saltarse el filtro.
- El certificado del panel es autofirmado y el navegador avisará.
- El DHCP de Pi-hole no funciona aquí: la red puente no recibe DHCP de la LAN; usar DNS manual o un router compatible.
- Pi-hole v6 no usa autenticación básica; la API inicia sesión con JSON en `POST /api/auth`.
- Las imágenes están fijadas a la versión y digest desplegados; no se deben cambiar sin revisar la compatibilidad con ARIA.

## Referencias

- [Pi-hole](https://docs.pi-hole.net/)
- [Unbound](https://www.nlnetlabs.nl/projects/unbound/about/)
- [DNSSEC](https://www.icann.org/dnssec/)
- [WireGuard](https://www.wireguard.com/)
