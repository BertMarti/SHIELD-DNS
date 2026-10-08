# CLAUDE.md – Guía para Claude Code en SHIELD-DNS

## Estructura del proyecto

```
SHIELD-DNS/
├── docker-compose.yml      Definición de los contenedores (Unbound + Pi-hole)
├── install.sh              Script de instalación (idempotente)
├── uninstall.sh            Script de desinstalación
├── .env.example            Plantilla de variables de configuración
├── .env                    Configuración local (NUNCA commitear)
├── data/pihole/            Volumen persistente de Pi-hole (NUNCA commitear)
├── README.md               Documentación para usuarios
├── CLAUDE.md               Esta guía
├── AGENTS.md               Distribución de trabajo entre agentes
├── SKILLS.md               Procedimientos operacionales
├── MEMORY.md               Decisiones, puerto, historial
└── LICENSE                 MIT license
```

## Convenciones

### Idioma
- **Usuarios:** español de España (Castilla) en todos los mensajes, comentarios y documentos públicos
- **Código (scripts, comentarios internos):** español de España

### Secretos y configuración
- **NUNCA commitear `.env`** (está en `.gitignore`)
- **Secretos solo en `.env`:** contraseñas generadas, tokens, claves privadas
- **Datos persistentes:** carpeta `data/` (en `.gitignore`)

### Scripts bash
Todos los scripts usan:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
```

Esto asegura:
- Fallo si hay errores
- Fallo si se usan variables vacías
- Fallo si hay pipes que fallan
- El script funciona desde cualquier directorio

### Idempotencia
- `install.sh` puede ejecutarse múltiples veces sin consecuencias
- No crea directorios ni archivos si ya existen
- Actualiza valores solo si están vacíos o cambian

## Cómo probar cambios en la Raspberry Pi

### Opción 1: SSH en la Pi y test directo
```bash
ssh pi@raspberrypi.local
cd /ruta/a/SHIELD-DNS
git pull origin main
./install.sh
docker compose logs -f pihole
# Testear el DNS: dig @127.0.0.1 example.com
```

### Opción 2: Cambiar y commitear localmente
1. Edita los archivos (`.env.example`, `docker-compose.yml`, scripts)
2. Haz `git commit` localmente
3. Ejecuta `git push` cuando esté verificado

### Cómo testear DNS sin Docker
```bash
# En la Pi, si tienes dig instalado
dig @<IP-de-la-Raspberry> example.com
dig @<IP-de-la-Raspberry> doubleclick.net  # Debe retornar 0.0.0.0
```

## Cambios comunes y dónde hacerlos

| Cambio | Archivo | Nota |
|--------|---------|------|
| Añadir nueva lista de bloqueo | `.env.example` → variable `EXTRA_ADLISTS` | Espacio-separadas |
| Cambiar puertos del panel | `.env.example` → `WEB_HTTP_PORT`, `WEB_HTTPS_PORT` | Requiere que el puerto esté libre |
| Cambiar zona horaria | `.env.example` → `TZ` | Solo en primer arranque |
| Cambiar contraseña Pi-hole | `.env` → `PIHOLE_PASSWORD`, luego `docker compose up -d` | No commitear .env |
| Cambiar IP de Unbound | `docker-compose.yml` → `networks.shield.ipv4_address` | Impacta a Pi-hole |
| Cambiar dirección del subdominio de Pi-hole | `install.sh` → línea 79 | Varía según configuración |

## Lo que NO hacer

- **No commitear `.env`** – es privado de la instalación
- **No tocar `data/`** – son los datos de Pi-hole (persistencia)
- **No usar `sudo` innecesariamente en scripts** – Docker ya maneja permisos
- **No hardcodear IPs o puertos** en código; usar variables de `.env`
- **No cambiar la estructura de la red Docker** sin verificar que sigue funcionando
- **No modificar archivos que recrea Docker** (ej. la configuración de Unbound) sin saber que se sobrescribirá

## Gotchas

### El puerto 53 está ocupado
Si `install.sh` falla diciendo que el puerto 53 está en uso:
- Comprueba: `sudo ss -tulpn | grep 53`
- Si es `systemd-resolved`, desactívalo: `sudo systemctl disable --now systemd-resolved`
- Si es `pihole-FTL` nativo, desinstálalo o usa contenedores
- Luego vuelve a ejecutar `./install.sh`

### PIHOLE_PASSWORD está vacía
Si olvidaste generarla, el instalador lo hace automáticamente. Solo edita `.env` si quieres cambiarla manualmente.

### Las listas tardan en actualizar
La primera carga de listas puede tardar 1-2 minutos. Puedes ver el progreso con:
```bash
docker compose logs -f pihole
```

### DNSSEC y Pi-hole
En `docker-compose.yml`, `FTLCONF_dns_dnssec: "false"` porque Unbound ya valida DNSSEC. No lo cambies.

## Testing

### Verificar que el DNS responde
```bash
# Desde la Pi o desde otra máquina de la red
dig @<IP-Raspberry> example.com
```

Debe retornar algo como:
```
; <<>> DiG 9.x <<>> @192.168.1.10 example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
```

### Verificar que Pi-hole bloquea
```bash
dig @<IP-Raspberry> doubleclick.net +short
```

Debe retornar `0.0.0.0`

### Verificar que DNSSEC funciona
```bash
dig @127.0.0.1 dnssec-failed.org
```

Debe retornar `status: SERVFAIL`

## Herramientas útiles

- `docker compose ps` – estado de los contenedores
- `docker compose logs pihole` – últimos logs
- `docker compose logs -f pihole` – logs en tiempo real
- `docker inspect shield-pihole` – detalles del contenedor
- `docker exec shield-pihole dig @127.0.0.1 example.com` – testear DNS dentro del contenedor

## Referencias

- Pi-hole: https://pi-hole.net/
- Unbound: https://www.nlnetlabs.nl/projects/unbound/about/
- Docker: https://docs.docker.com/

## Otros modelos
Para repartir tareas con otros modelos (Copilot, GPT, Gemini, gratuitos de OpenCode Zen) sigue `AGENTS.md` → «Trabajo con varios modelos»: Claude orquesta y revisa; los delegados trabajan en un worktree aparte y nunca reciben secretos ni datos personales.
