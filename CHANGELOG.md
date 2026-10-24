# Changelog

Formato basado en Keep a Changelog. El proyecto no usa números de versión.

## [2026-10-24] Fase 2

- **Añadido:** comprobación previa `./install.sh --comprobar`, opciones `--sin-preguntas` y `--ayuda`, asistente de primera instalación, pruebas del instalador y sección «Empieza en 5 minutos» en la web.
- **Cambiado:** imágenes fijadas a Pi-hole `2026.09.0` y Unbound `1.26.1` con sus digest desplegados; documentación del resumen de instalación, Dependabot y pendientes de memoria.
- **Corregido:** creación de `.env` con permisos `600` desde el primer momento y guía exacta para liberar el puerto 53 ocupado por `systemd-resolved`.
- **Seguridad:** `no-new-privileges:true` en Unbound, no en Pi-hole por sus capacidades requeridas; se documentan los límites de exposición del DNS y panel.

## [2026-10-24]

- Añadida documentación técnica separada y guía para IA.
- Documentados CI, Pages, Dependabot y gitleaks.
- Corregida la recomendación del DHCP de Pi-hole en red Docker puente.
- Actualizados los procedimientos para Pi-hole v6, `./update.sh` y API JSON.
- Añadida la web de GitHub Pages (`site/`) y su workflow.
- CI: `bash -n`, ShellCheck, `docker compose config`, puertos publicados (53, 8080, 8443), gitleaks y comprobación de la web.
- Dependabot semanal agrupado, `.gitleaks.toml` con lista de permitidos concreta y `SECURITY.md`.
- Arreglos de ShellCheck en los scripts sin cambiar su comportamiento.
- README con enlace a la web e insignias de CI; lo técnico (variables, órdenes de terminal, puertos) pasa a `docs/DESARROLLO.md`.

## [2026-10-07]

- Documentados `backup.sh`, `restore.sh` y `update.sh`.
- Confirmada la copia antes de actualizar y la restauración de configuración.

## [2026-10-06]

- Documentación inicial de usuario, operación, decisiones, pruebas e integración con ARIA y HEIMDALL.
