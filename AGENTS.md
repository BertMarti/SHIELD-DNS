# AGENTS.md – Guía de trabajo para IA

SHIELD-DNS es un bloqueador de anuncios, rastreadores y dominios maliciosos para toda la casa: Pi-hole v6 y Unbound con DNSSEC en Docker. Forma parte de ARIA, junto con ARIA (asistente y panel) y HEIMDALL (VPN WireGuard).

## Estructura

- `docker-compose.yml`: Pi-hole y Unbound, red Docker interna con IPs fijas (ver `docker-compose.yml`).
- `install.sh`, `update.sh`, `backup.sh`, `restore.sh`, `uninstall.sh`: operación.
- `README.md`: guía de usuario; `docs/DESARROLLO.md`: guía técnica.
- `site/`: web estática publicada en Pages.
- `SKILLS.md`, `MEMORY.md`, `PLAN.md`: operación, decisiones y hoja de ruta.
- `.env` y `data/`: locales, privados y nunca versionados.

## Comandos exactos

```bash
./install.sh
./install.sh --comprobar
./update.sh
./backup.sh
./restore.sh backups/shield-dns-AAAAMMDD-HHMM.tar.gz
./uninstall.sh
./uninstall.sh --purge
```

Validación local:

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
tests/instalador.sh
cp .env.example /tmp/shield.env
PIHOLE_PASSWORD=x docker compose --env-file /tmp/shield.env config -q
gitleaks git . --redact
site/construir.sh /tmp/shield-web/SHIELD-DNS
python3 -m http.server 8000 -d /tmp/shield-web
```

Pages publica solo `site/` y las imágenes necesarias, al subir a `main` o mediante `workflow_dispatch`. El despliegue es `git push origin main`.

## Convenciones

- Bash con `set -euo pipefail`, scripts idempotentes y español de España.
- Mantener la información útil: moverla, no borrarla.
- No inventar comportamiento. Comprobar primero scripts y Compose.
- No cambiar nombres de servicio o contenedor, puertos ni redes: los usa ARIA.
- No subir versiones mayores de las imágenes sin revisar antes la compatibilidad con ARIA.

## Seguridad y producción

Este repositorio es público: no subir IPs reales, dominios, nombres de personas, pueblo, MACs, contraseñas, tokens ni claves. `.env`, `data/` y copias nunca entran en el repositorio. SHIELD-DNS está EN PRODUCCIÓN: no ejecutar instalación, actualización, restauración, desinstalación ni Docker en la máquina real para probar; usar validación estática o un Pi-hole de pruebas.

El DHCP de Pi-hole no está soportado: la red Docker puente no recibe peticiones DHCP de la LAN. La alternativa es configurar el DNS en cada dispositivo o en un router compatible.

## Trabajo con varios modelos (vía OpenCode)

Claude (Opus, Claude Code) orquesta y revisa. `openai/gpt-5.6-luna` trabaja en código e interfaz; `google/gemini-3-flash-preview`, `google/gemini-3.5-flash` y `google/gemini-3.7-flash` en documentación. Para pruebas sin datos sensibles se pueden usar OpenCode Zen `big-pickle` y `mimo-v2.6-flash-free`. Las revisiones cruzadas usan `google/gemini-3.7-flash --agent plan`.

Los delegados trabajan en worktrees aparte y no reciben secretos; no hacen commit, push ni despliegues. No existe `opencode run --skill`.

```bash
opencode run --agent plan -m google/gemini-3.7-flash --dir <repo> "Revisa los cambios y lista los problemas"
git worktree add ../.wt/<tarea> -b feat/<tarea>
```
