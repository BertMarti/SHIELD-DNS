# SKILLS.md – Procedimientos operacionales

## Tabla de procedimientos

| Procedimiento | Comando | Tiempo |
|---------------|---------|--------|
| Instalar SHIELD-DNS | `./install.sh` | 2-3 min |
| Desinstalar (mantener datos) | `./uninstall.sh` | <30 seg |
| Desinstalar (purgar todo) | `./uninstall.sh --purge` | <30 seg |
| Actualizar a última versión | `git pull && docker compose pull && docker compose up -d` | 1-2 min |
| Cambiar contraseña panel | Editar `.env` + `docker compose up -d` | 1 min |
| Permitir un dominio | `docker exec shield-pihole pihole allow DOMINIO` | <5 seg |
| Bloquear un dominio | `docker exec shield-pihole pihole deny DOMINIO` | <5 seg |
| Actualizar listas ahora | `docker exec shield-pihole pihole -g` | 1-2 min |
| Ver logs en tiempo real | `docker compose logs -f pihole` | — |
| Desactivar bloqueo temporalmente | Panel web → Sistema → Disable blocking | <5 seg |
| Verificar DNS funciona | `dig @IP example.com` | <5 seg |

---

## 1. Instalar SHIELD-DNS

### Requisitos previos
- Raspberry Pi con SSH habilitado
- Docker y Docker Compose (el script lo instala si falta)
- Puerto 53 (TCP/UDP) libre

### Pasos

```bash
ssh pi@raspberrypi.local
cd ~
git clone https://github.com/BertMarti/SHIELD-DNS.git
cd SHIELD-DNS
./install.sh
```

**Resultado esperado:**
```
✔ Docker disponible
✔ Creado .env
✔ Contraseña del panel generada en .env
✔ Pi-hole funcionando
✔ El DNS responde
```

### Si falla: puerto 53 ocupado
```bash
sudo ss -tulpn | grep 53
# Detén el servicio conflictivo:
sudo systemctl disable --now systemd-resolved
# O si es pihole-FTL nativo:
sudo apt-get remove pihole-ftl
# Vuelve a ejecutar:
./install.sh
```

---

## 2. Cambiar la contraseña del panel web

### Pasos

```bash
cd /ruta/a/SHIELD-DNS
# Edita .env con tu editor favorito
nano .env
# Busca PIHOLE_PASSWORD= y pon una contraseña nueva
# Guarda (Ctrl+X en nano)

# Aplica el cambio
docker compose up -d

# Verifica que funciona
curl -s https://localhost:8443/admin -k -u admin:NUEVA_PASSWORD | head -1
```

**Nota:** no commitees `.env`; está en `.gitignore`.

---

## 3. Permitir un dominio específico (sacarlo de la lista negra)

### Si sabes qué dominio lo necesita (ej. "ejemplo.com está bloqueado por error")

```bash
docker exec shield-pihole pihole allow ejemplo.com
```

**Resultado:**
```
✔ Allowlisting ejemplo.com
```

### Alternativa: desde el panel web
1. Accede a `https://<IP>:8443/admin`
2. "Allowlist" en la barra lateral → "Dominio"
3. Introduce `ejemplo.com`
4. Clic en "Añadir a allowlist"

---

## 4. Bloquear un dominio específico

### Comando

```bash
docker exec shield-pihole pihole deny ejemplo.com
```

**Resultado:**
```
✔ Denylisting ejemplo.com
```

### Desde el panel
1. Accede a `https://<IP>:8443/admin`
2. "Denylist" → "Dominio"
3. Introduce `ejemplo.com`
4. Clic en "Añadir a denylist"

---

## 5. Añadir una nueva lista de bloqueo

### Opción A: Permanente (recomendado)

1. Edita `.env.example`:
   ```bash
   EXTRA_ADLISTS="https://lista1.txt https://lista2.txt"
   ```

2. Ejecuta el instalador (es idempotente):
   ```bash
   ./install.sh
   ```

3. Commitea el cambio:
   ```bash
   git add .env.example
   git commit -m "Añadir nueva lista de bloqueo"
   git push
   ```

### Opción B: Temporal (una sola vez, sin persistencia)

```bash
docker exec shield-pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES \
  ('https://nueva-lista.txt', 1, 'Manual');"

# Actualiza las listas
docker exec shield-pihole pihole -g
```

---

## 6. Actualizar las listas de bloqueo ahora mismo

Por defecto, Pi-hole las actualiza cada lunes a las 02:00 UTC. Para hacerlo ya:

```bash
docker exec shield-pihole pihole -g
```

**Resultado esperado:**
```
✔ Retrieving blocklist 1 of 3 (StevenBlack)
✔ Retrieving blocklist 2 of 3 (HaGeZi Multi)
✔ Gravity rebuild done
```

Esto puede tardar 1-2 minutos. Ver progreso:
```bash
docker compose logs -f pihole
```

---

## 7. Ver los logs en tiempo real

```bash
cd /ruta/a/SHIELD-DNS
docker compose logs -f pihole
```

**Ctrl+C para salir**

### Logs útiles

- `Blocking doubleclick.net` → funciona el bloqueo
- `dnssec-failed.org: SERVFAIL` → DNSSEC funciona
- `Client 192.168.1.100 (dispositivo): example.com (A)` → consulta DNS

---

## 8. Desactivar el bloqueo temporalmente

Si necesitas que ciertos dominios pasen temporalmente (ej. depurando):

1. Accede a `https://<IP>:8443/admin`
2. Botón "Disable blocking" (esquina superior derecha)
3. Elige duración: 10s, 5m, 30m, o "until re-enabled"
4. El botón se volverá rojo mientras está desactivado

**Resultado:** todas las consultas DNS pasan sin bloqueo durante el tiempo elegido.

---

## 9. Verificar que el DNS responde

### Desde la Raspberry Pi misma

```bash
docker exec shield-pihole dig @127.0.0.1 example.com +short
```

**Resultado:** la dirección IP de `example.com`

### Desde otro dispositivo en la red

```bash
dig @IP-de-la-Raspberry example.com +short
# ej: dig @192.168.1.10 example.com +short
```

### Verificar bloqueo de anuncios

```bash
dig @IP-de-la-Raspberry doubleclick.net +short
```

**Resultado:** `0.0.0.0` (bloqueado)

### Verificar DNSSEC

```bash
dig @127.0.0.1 dnssec-failed.org
```

Busca en la respuesta:
```
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: xxxxx
```

---

## 10. Desinstalar sin perder datos

```bash
./uninstall.sh
```

**Resultado:**
```
Contenedores de SHIELD-DNS detenidos y eliminados.
Recuerda volver a poner el DNS de tu router si apuntaba a esta Raspberry Pi.
```

Los datos de Pi-hole se conservan en `data/pihole/`. Puedes reinstalar con `./install.sh` y recuperarás toda la configuración.

---

## 11. Desinstalar y borrar todo

```bash
./uninstall.sh --purge
```

**Resultado:**
```
Contenedores de SHIELD-DNS detenidos y eliminados.
Datos y .env eliminados.
```

Esto borra `data/` y `.env`. La próxima instalación empezará desde cero.

---

## 12. Actualizar a la última versión

```bash
cd /ruta/a/SHIELD-DNS
git pull
docker compose pull
docker compose up -d
```

**Resultado:**
- `git pull` trae cambios del repositorio
- `docker compose pull` descarga nuevas imágenes (si las hay)
- `docker compose up -d` reinicia los contenedores

Esto es seguro: tus datos en `data/pihole/` se preservan.

---

## Troubleshooting rápido

| Problema | Solución |
|----------|----------|
| DNS no responde | `docker compose logs pihole` → busca `ERROR` |
| Panel devuelve 502 | Reinicia: `docker compose restart pihole` |
| Puerto 53 sigue ocupado después de desinstalar | `sudo ss -tulpn \| grep 53` + detén el servicio |
| Contraseña olvidada | Edita `.env`, vuelve a generar, ejecuta `docker compose up -d` |
| Listas no se actualizan | `docker exec shield-pihole pihole -g` manual |
| Un dominio se bloquea por error | `docker exec shield-pihole pihole allow dominio.com` |
