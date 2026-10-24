# SKILLS.md – Procedimientos operacionales

## Tabla de procedimientos

| Procedimiento | Comando | Tiempo |
|---|---|---|
| Instalar | `./install.sh` | 2-3 min |
| Desinstalar manteniendo datos | `./uninstall.sh` | <30 s |
| Desinstalar y purgar | `./uninstall.sh --purge` | <30 s |
| Actualizar correctamente | `./update.sh` | 1-2 min |
| Cambiar contraseña | Editar `.env` + `docker compose up -d` | 1 min |
| Permitir un dominio | `docker exec shield-pihole pihole allow DOMINIO` | <5 s |
| Bloquear un dominio | `docker exec shield-pihole pihole deny DOMINIO` | <5 s |
| Actualizar listas | `docker exec shield-pihole pihole -g` | 1-2 min |
| Ver logs | `docker compose logs -f pihole` | — |
| Pausar bloqueo | Panel → Disable blocking | <5 s |
| Comprobar DNS | `dig @192.168.1.50 tu-dominio.com` | <5 s |

## 1. Instalar

```bash
./install.sh
```

El script comprueba Docker, Compose y el puerto 53, crea `.env`, genera la contraseña, arranca los contenedores, carga `EXTRA_ADLISTS` y prueba el DNS. Si el puerto está ocupado, revisar el servicio y repetir. No activar el DHCP de Pi-hole: esta instalación usa una red Docker puente que no recibe DHCP de la LAN.

## 2. Cambiar la contraseña en Pi-hole v6

Edita `.env`, cambia `PIHOLE_PASSWORD` y aplica:

```bash
docker compose up -d
```

La API de v6 usa `POST /api/auth` con JSON. No uses autenticación básica ni guardes la contraseña en el repositorio.

## 3. Permitir un dominio

```bash
docker exec shield-pihole pihole allow tu-dominio.com
```

También puede hacerse desde **Allowlist** en el panel.

## 4. Bloquear un dominio

```bash
docker exec shield-pihole pihole deny tu-dominio.com
```

## 5. Añadir una lista permanente

Edita `.env.example`, ajusta `EXTRA_ADLISTS` con URLs separadas por espacios y ejecuta `./install.sh`. Los cambios de documentación o plantilla se revisan antes de hacer commit.

## 6. Actualizar listas

```bash
docker exec shield-pihole pihole -g
```

## 7. Ver logs

```bash
docker compose logs -f pihole
```

Pulsa `Ctrl+C` para salir. `SERVFAIL` en un dominio con DNSSEC inválido es el resultado esperado.

## 8. Pausar el bloqueo

En el panel, abre **Disable blocking** y elige indefinidamente, 10 segundos, 30 segundos, 5 minutos o un tiempo personalizado.

## 9. Verificar DNS

```bash
docker exec shield-pihole dig @127.0.0.1 tu-dominio.com +short
```

La consulta bloqueada devuelve `0.0.0.0`; la prueba DNSSEC devuelve `SERVFAIL`.

## 10. Desinstalar sin perder datos

```bash
./uninstall.sh
```

Los datos de `data/pihole/` y `.env` se conservan. Devuelve el DNS anterior al router si era necesario.

## 11. Desinstalar y borrar todo

```bash
./uninstall.sh --purge
```

Borra `data/` y `.env`. Es irreversible sin una copia.

## 12. Actualizar

```bash
./update.sh
```

Es el procedimiento correcto: hace una copia, ejecuta `git pull --ff-only`, descarga imágenes, reinstala y elimina imágenes sin usar. No sustituirlo por una secuencia manual.

## Troubleshooting rápido

| Problema | Acción |
|---|---|
| DNS no responde | `docker compose logs pihole` y `docker compose ps`. |
| Puerto 53 ocupado | `sudo ss -tulpn` y detener el servicio conflictivo. |
| Panel no carga | Revisar `https://192.168.1.50:8443/admin` y los logs. |
| Contraseña olvidada | Editar `.env` y ejecutar `docker compose up -d`. |
| Lista no actualiza | Ejecutar `docker exec shield-pihole pihole -g`. |
| Dominio bloqueado por error | Usar `pihole allow DOMINIO`. |
| DHCP no funciona | No es compatible con esta red puente; configurar DNS manualmente. |

## Playbook

1. Copia: `./backup.sh`; guarda `backups/*.tar.gz` fuera de la máquina.
2. Restauración: clona el repositorio, copia el archivo a `backups/` y ejecuta `./restore.sh backups/<archivo>`.
3. Actualización: `./update.sh`, que hace la copia antes del cambio.
