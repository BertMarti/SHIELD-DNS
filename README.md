# SHIELD-DNS – Bloqueador de publicidad a nivel de DNS

SHIELD-DNS es un bloqueador de anuncios y rastreadores para toda tu red. Se ejecuta en tu Raspberry Pi usando Pi-hole v6 con Unbound como resolución privada.

## ¿Cómo funciona en tu casa?

**SHIELD-DNS** (este proyecto) + **HEIMDALL** (VPN) + **ARIA** (asistente IA):

- **SHIELD-DNS**: bloquea anuncios en el DNS (puerto 53). Todo dispositivo que lo use como DNS deja de cargar anuncios, sin instalar nada.
- **HEIMDALL**: VPN WireGuard para acceder a la red desde fuera de casa (y a través de ella, usar SHIELD-DNS incluso en el móvil en ruta).
- **ARIA**: asistente IA local con web UI en los puertos 80/443.

## Requisitos

- **Raspberry Pi** (4 o 5) con Raspberry Pi OS de 64 bits, u otra distribución Linux con Docker
- **Docker y Docker Compose** (el instalador lo pone si falta)
- **Puerto 53** (TCP/UDP) libre en la Raspberry Pi
- Si otro servicio usa el puerto 53 (por ej. `systemd-resolved` o `pihole-FTL` nativo), el instalador lo detecta y para

## Instalación en 3 comandos

```bash
git clone https://github.com/BertMarti/SHIELD-DNS.git
cd SHIELD-DNS
./install.sh
```

### Qué hace el instalador

1. Instala Docker si no lo tienes (mediante el script oficial de Docker)
2. Comprueba que el puerto 53 esté libre
3. Crea el archivo `.env` y genera automáticamente una contraseña fuerte para el panel
4. Descarga las imágenes Docker (Pi-hole y Unbound)
5. Arranca los contenedores y espera a que estén listos
6. Carga las listas de bloqueo (por defecto la lista HaGeZi, además de la lista por defecto de Pi-hole)
7. Comprueba que el DNS responda correctamente

El script es idempotente: puedes ejecutarlo varias veces sin problemas.

## Primero: acceso al panel web

Después de instalar, accede al panel:

```
https://<IP-de-la-Raspberry-Pi>:8443/admin
```

**Importante:** el certificado es autofirmado. Tu navegador te mostrará una advertencia. En:
- **Chrome/Edge/Firefox**: haz clic en "Avanzado" → "Continuar a la página"
- **Safari**: haz clic en "Mostrar detalles" → "Acceder a este sitio web"

No hay usuario: Pi-hole solo pide la contraseña.  
Contraseña: la que está en el archivo `.env` (variable `PIHOLE_PASSWORD`), generada durante la instalación.

## Uso día a día

### Pon SHIELD-DNS como DNS de tu red

Opción 1: en el router (recomendado)
- Entra en la configuración del router (suele ser `192.168.1.1`)
- Busca "DHCP" o "DNS"
- Pon la IP de la Raspberry Pi como servidor DNS primario
- Todos los dispositivos nuevos de tu red lo usarán automáticamente

Opción 2: en cada dispositivo
- Móvil: Ajustes > Wi-Fi > (red) > Configuración avanzada > DNS
- PC/Mac: Ajustes de red > DNS

**Nota sobre IPv6:** algunos routers también reparten servidores DNS IPv6. Si tu dispositivo recibe un servidor IPv6 del router/ISP, puede saltarse SHIELD-DNS. Si esto ocurre:
- Desactiva IPv6 en el router, o
- Configura DNS IPv6 manualmente en cada dispositivo

### Con HEIMDALL (VPN)

Si tienes HEIMDALL instalado, la VPN ya configura automáticamente SHIELD-DNS como DNS. Los clientes VPN recibirán bloqueo de anuncios incluso conectados desde fuera de casa.

## Actualizar

```bash
cd ~/homelab/SHIELD-DNS   # o donde lo clonaras
./update.sh
```

`update.sh` hace primero una copia de seguridad, descarga los cambios del repositorio y las imágenes nuevas, y vuelve a aplicar la instalación. Tus listas y ajustes se conservan.

## Copia de seguridad y restauración

```bash
./backup.sh
```

Crea `backups/shield-dns-AAAAMMDD-HHMM.tar.gz` con tu `.env` y una exportación de Pi-hole (listas, dominios permitidos/bloqueados, clientes y ajustes). Se conservan las 7 más recientes. **Copia ese archivo fuera de la Raspberry** (a tu PC o a un USB): si formateas, es lo único que necesitas.

Para restaurar (por ejemplo, en una Raspberry recién formateada):

```bash
git clone https://github.com/BertMarti/SHIELD-DNS.git && cd SHIELD-DNS
mkdir -p backups && cp /ruta/a/shield-dns-AAAAMMDD-HHMM.tar.gz backups/
./restore.sh backups/shield-dns-AAAAMMDD-HHMM.tar.gz
```

`restore.sh` pide confirmación, recupera la configuración y arranca todo con `install.sh`.

## Desinstalar

Sin borrar datos de Pi-hole (puedes reinstalar sin perder):
```bash
./uninstall.sh
```

Con purga completa (borra todo):
```bash
./uninstall.sh --purge
```

## Solución de problemas

### El DNS no responde
```bash
docker compose logs pihole
```

### Cambiar la contraseña del panel
1. Edita `.env` y cambia `PIHOLE_PASSWORD` a una nueva contraseña
2. Ejecuta `docker compose up -d`
3. Accede al panel con la nueva contraseña

### Ver los registros en tiempo real
```bash
docker compose logs -f pihole
```

### Permitir o bloquear un dominio específico

Bloquear un dominio (el panel también lo permite):
```bash
docker exec shield-pihole pihole deny ejemplo.com
```

Permitir un dominio (para sacarlo de la lista negra):
```bash
docker exec shield-pihole pihole allow ejemplo.com
```

### Actualizar las listas de bloqueo ahora mismo (sin esperar)
```bash
docker exec shield-pihole pihole -g
```

### Desactivar temporalmente el bloqueo
En el menú lateral del panel web, pulsa "Disable blocking" y elige por cuánto tiempo.

## Puertos

| Servicio | Puerto | Protocolo | Uso |
|----------|--------|-----------|-----|
| DNS | 53 | TCP/UDP | Resolución de DNS (obligatorio en la red) |
| Panel HTTP | 8080 | TCP | Panel web sin cifrar (mejor usa el 8443) |
| Panel HTTPS | 8443 | TCP | Panel web seguro (certificado autofirmado) |

## Características verificadas (2026-10-06)

- ✓ Bloquea anuncios: `doubleclick.net` y `googleads.g.doubleclick.net` → `0.0.0.0`
- ✓ Permite acceso normal: `github.com` resuelve correctamente
- ✓ DNSSEC funciona: `dnssec-failed.org` retorna SERVFAIL como se espera
- ✓ Listas: 232.079 dominios bloqueados
- ✓ Panel: login por API funciona
- ✓ Idempotencia: el instalador puede ejecutarse varias veces sin problemas

## Limitaciones conocidas

- **Estadísticas de Docker:** en Raspberry Pi, Docker muestra 0B de memoria incluso con contenedores activos. No es un problema; es una limitación del kernel (cgroup memory controller deshabilitado).
- **Clientes por la VPN:** las consultas que llegan a través de HEIMDALL aparecen en el panel con la IP interna de Docker, no con la del dispositivo concreto.

## Licencia

MIT – 2026, BertMarti
