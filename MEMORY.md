# MEMORY.md – Decisiones, pruebas e historial

## Decisiones de diseño

### Pi-hole v6 + Unbound

- Pi-hole ofrece panel, listas, estadísticas y API REST.
- Unbound resuelve de forma privada y valida DNSSEC.
- Pi-hole delega en Unbound mediante `172.30.53.2`.

### Red Docker

```text
docker network shield-dns (172.30.53.0/24)
├── Unbound (172.30.53.2:53)
└── Pi-hole (172.30.53.3:53) -> upstream a Unbound
```

La red privada evita que los contenedores usen el DNS del host y previene bucles. `FTLCONF_dns_dnssec` permanece en `false` porque Unbound ya valida DNSSEC.

### Seguridad y panel

- El instalador genera una contraseña aleatoria de 20 caracteres y la guarda en `.env` con permisos `600`.
- Pi-hole usa certificado autofirmado; el aviso del navegador es esperado en la red doméstica.
- La API de Pi-hole v6 usa `POST /api/auth` con JSON, no autenticación básica.
- El panel publica 8080 y 8443; ARIA usa hoy HTTP 8080 en la LAN.

### Listas

Pi-hole trae su lista por defecto. `EXTRA_ADLISTS` añade HaGeZi Multi y TIF mini. El instalador las registra y reconstruye gravity.

## Puertos del ecosistema

| Proyecto | Servicio | Puerto | Protocolo |
|---|---|---|---|
| ARIA | Web UI | 80, 443 | TCP |
| SHIELD-DNS | DNS | 53 | TCP/UDP |
| SHIELD-DNS | Panel | 8080, 8443 | TCP |
| HEIMDALL | WireGuard y panel | 51820, 51843 | UDP/TCP |

## Resultados de pruebas verificadas (2026-10-06)

### Test 1: bloqueo de anuncios

```bash
docker exec shield-pihole dig @127.0.0.1 doubleclick.net +short
```

Resultado en ambos casos: `0.0.0.0`. Conclusión: los dominios de anuncios se bloquean.

### Test 2: resolución normal

```bash
docker exec shield-pihole dig @127.0.0.1 tu-dominio.com +short
```

Resultado: devuelve una dirección válida. Conclusión: los dominios permitidos se resuelven.

### Test 3: DNSSEC

```bash
docker exec shield-pihole dig @127.0.0.1 dnssec-failed.org
```

Resultado esperado: `status: SERVFAIL`. Conclusión: Unbound rechaza dominios con DNSSEC inválido.

### Test 4: cantidad de listas

```bash
docker exec shield-pihole pihole-FTL sqlite3 /etc/pihole/gravity.db "SELECT COUNT(*) FROM gravity;"
```

Resultado verificado: `232079`. Conclusión: la combinación de listas estaba cargada.

### Test 5: API

Se verificó el inicio de sesión mediante `POST /api/auth` con JSON y respuesta de sesión válida. La prueba no usa autenticación básica.

### Test 6: idempotencia

```bash
./install.sh
./install.sh
```

Ambas ejecuciones terminaron correctamente; la segunda no cambió nada innecesariamente.

## Limitaciones conocidas

1. En algunas Raspberry Pi, `docker stats` muestra `0B` de memoria por la configuración de cgroups. No afecta al servicio.
2. Un DNS IPv6 anunciado por el router puede saltarse SHIELD-DNS. Configurar DNS IPv6 o desactivar IPv6 en la LAN.
3. El historial por dispositivo depende de cómo el router reenvía las consultas.
4. El DHCP de Pi-hole no está soportado en esta red Docker puente.

## Decisiones de seguridad

- `.env`, `data/` y copias no se versionan.
- El DNS no debe publicarse en Internet.
- El certificado autofirmado es local; el acceso externo debe pasar por ARIA/HEIMDALL.
- La lista de permitidos de gitleaks contiene solo un marcador histórico de contraseña de ejemplo y se mantiene por ser un falso positivo revisado del historial. No debe aparecer en documentación ni en ejemplos nuevos.

## 24/10/2026 – mejoras

- CI valida Bash, ShellCheck, Compose, puertos publicados, privacidad de la web e historial con gitleaks; usa permisos mínimos `contents: read`.
- Pages publica solo la web construida desde `site/` en `https://bertmarti.github.io/SHIELD-DNS/`.
- Dependabot agrupa semanalmente imágenes Docker y GitHub Actions.
- Se corrigió la documentación del DHCP: la red puente no recibe peticiones DHCP de la LAN.
- `pihole/pihole:latest` y `klutchell/unbound:latest` siguen pendientes de fijar. Antes hay que mirar la versión que corre en la Pi para no bajar la versión de la base de datos de Pi-hole.
- Queda pendiente valorar límites de memoria en una Pi de pruebas y pasar el panel de ARIA a HTTPS.

## Roadmap

Las ideas no son compromisos: estadísticas por dispositivo, sincronización entre Pis, copias automáticas, UI móvil nativa y alertas DNS.

## Referencias

- [Pi-hole](https://docs.pi-hole.net/)
- [Unbound](https://www.nlnetlabs.nl/projects/unbound/about/)
- [WireGuard](https://www.wireguard.com/)
