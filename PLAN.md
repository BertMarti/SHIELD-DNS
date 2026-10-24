# PLAN.md – Hoja de ruta

## Hecho hoy

- Documentación de usuario, técnica y para IA reorganizada sin perder las decisiones históricas.
- CI, Pages, Dependabot y gitleaks documentados.
- Corregida la indicación incorrecta sobre el DHCP de Pi-hole.
- Procedimiento de actualización centralizado en `./update.sh`.

## Siguiente

1. [x] Fijar `pihole/pihole` y `klutchell/unbound` a las versiones y digest desplegados.
2. Probar límites de memoria en una Pi de pruebas.
3. Revisar manualmente en enero la versión 2027 de Pi-hole y su compatibilidad con ARIA.
4. Valorar que el panel de ARIA entre solo por HTTPS 8443; hoy ARIA usa la API por HTTP 8080 en la LAN.

## Ideas

- Estadísticas por dispositivo.
- Sincronización de listas entre varias Pis.
- Copia automática de configuración.
- UI móvil nativa.
- Alertas automáticas si el DNS falla.
