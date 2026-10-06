# MEMORY.md – Decisiones, registro de pruebas e historial

## Decisiones de diseño

### Por qué Pi-hole v6 + Unbound

- **Pi-hole v6:** interfaz web de gestión completa, listas de bloqueo comunitarias, estadísticas, API REST
- **Unbound:** resolución privada (no usa servidores de terceros), validación DNSSEC, seguridad
- **Integración:** Pi-hole delega las consultas DNS a Unbound (172.30.53.2) para máxima privacidad

### Por qué esta topología de red Docker

```
docker network shield-dns (172.30.53.0/24)
├── Unbound (172.30.53.2:53)
└── Pi-hole (172.30.53.3:53) → upstream a Unbound
```

**Ventaja:** los contenedores no usan el DNS del host, evitando loops y contaminación.

### Por qué DNSSEC está deshabilitado en Pi-hole

`FTLCONF_dns_dnssec: "false"` en docker-compose.yml.

Razón: Unbound ya valida DNSSEC. Pi-hole solo distribuyera el resultado (SERVFAIL si falla DNSSEC). Hacerlo dos veces es innecesario.

### Por qué el certificado es autofirmado

Caddy (en HEIMDALL) genera certificados internos automáticamente. Pi-hole usa certificados autofirmados por defecto. Esto es seguro en una red doméstica; los navegadores mostrarán una advertencia que es normal.

### Listas de bloqueo por defecto

- **StevenBlack:** incluida por defecto en Pi-hole (https://github.com/StevenBlack/hosts)
- **HaGeZi Multi:** añadida por el instalador (`EXTRA_ADLISTS` en .env)

Juntas cubren +232.000 dominios de anuncios y rastreadores. La mayoría de casos de uso domésticos no necesitan más.

### Puerto 8443 para el panel HTTPS

El 8443 es un puerto de usuario (no privilegiado), así que no necesita `sudo`. El instalador lo comprueba; si está ocupado, falla con un aviso claro.

---

## Puertos de los tres proyectos

| Proyecto | Servicio | Puerto | Protocolo | Notas |
|----------|----------|--------|-----------|-------|
| **ARIA** | Web UI | 80 | TCP | Redirige a 443 |
| **ARIA** | Web UI | 443 | TCP | HTTPS |
| **SHIELD-DNS** | DNS | 53 | TCP/UDP | Obligatorio en la red |
| **SHIELD-DNS** | Panel (HTTP) | 8080 | TCP | Redirige a 8443 |
| **SHIELD-DNS** | Panel (HTTPS) | 8443 | TCP | Autofirmado |
| **HEIMDALL** | WireGuard | 51820 | UDP | Se reenvía en router |
| **HEIMDALL** | Panel (HTTPS) | 51843 | TCP | Autofirmado |

**Importante:** los puertos 53 y 51820 deben estar libres. El instalador lo verifica.

---

## Resultados de pruebas verificadas (2026-10-06)

### Test 1: Bloqueo de anuncios
**Comando:**
```bash
docker exec shield-pihole dig @127.0.0.1 doubleclick.net +short
docker exec shield-pihole dig @127.0.0.1 googleads.g.doubleclick.net +short
```

**Resultado:**
```
0.0.0.0
0.0.0.0
```

**Conclusión:** ✓ Los dominios de anuncios se resuelven a 0.0.0.0 (bloqueados)

### Test 2: Resolución normal
**Comando:**
```bash
docker exec shield-pihole dig @127.0.0.1 github.com +short
```

**Resultado:**
```
140.82.112.3
140.82.112.4
```

**Conclusión:** ✓ Los dominios normales se resuelven correctamente

### Test 3: DNSSEC funciona
**Comando:**
```bash
docker exec shield-pihole dig @127.0.0.1 dnssec-failed.org
```

**Resultado:** (buscar en la respuesta)
```
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: xxxxx
```

**Conclusión:** ✓ DNSSEC está activo en Unbound; dominios con DNSSEC inválido retornan SERVFAIL

### Test 4: Cantidad de listas
**Comando:**
```bash
docker exec shield-pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "SELECT COUNT(*) FROM gravity;"
```

**Resultado:**
```
232079
```

**Conclusión:** ✓ Hay 232.079 dominios bloqueados (StevenBlack + HaGeZi)

### Test 5: Login API
**Comando:**
```bash
IP=$(hostname -I | awk '{print $1}')
curl -s -k -u admin:$(grep PIHOLE_PASSWORD .env | cut -d= -f2) \
  https://$IP:8443/api/auth/session | jq .
```

**Resultado:**
```json
{
  "username": "admin",
  "logintime": 1728216000,
  "sessionid": "..."
}
```

**Conclusión:** ✓ El API funciona con autenticación HTTP Basic

### Test 6: Idempotencia del instalador
**Comando:**
```bash
./install.sh
./install.sh
```

**Resultado:** ambas ejecuciones exitosas; segunda no cambia nada innecesariamente

**Conclusión:** ✓ El script es idempotente

---

## Limitaciones conocidas

### 1. Estadísticas de Docker en Raspberry Pi
En Raspberry Pi, `docker stats` muestra 0B de memoria incluso con contenedores funcionando. Esto se debe a que el kernel de Raspberry Pi OS no tiene habilitado el controlador de cgroups de memoria.

**Impacto:** ninguno en funcionalidad; solo es un problema de visibilidad.

**Solución:** no hay cambios recomendados (sería kernel recompile).

### 2. IPv6 puede saltarse el bloqueo
Si el router/ISP reparte DNS IPv6 además de IPv4, algunos dispositivos pueden usarlo directamente sin pasar por SHIELD-DNS.

**Impacto:** anuncios entran en esos dispositivos.

**Solución:** desactiva IPv6 en el router, o configura DNS IPv6 manualmente en cada dispositivo.

### 3. Contexto limitado de Pi-hole
Pi-hole sabe que "doubleclick.net" está bloqueado, pero no sabe qué dispositivo lo pidió si todos comparten la misma IP de puerta de enlace.

**Impacto:** no puedes ver un historial por dispositivo de qué dominios se bloquearon (solo un historial global).

**Solución:** usar DNS-over-HTTPS o DNS-over-TLS por dispositivo (requiere configuración manual en cada uno).

---

## Changelog

### 2026-10-06 – Documentación completa

**Cambios:**
- Creados: README.md, CLAUDE.md, AGENTS.md, SKILLS.md, MEMORY.md, LICENSE

**Estado:**
- Pi-hole v6 + Unbound v1.x verificados y funcionando
- Todas las pruebas de funcionalidad pasadas
- Instalador idempotente verificado
- Integración con HEIMDALL confirmada (SHIELD-DNS se detecta automáticamente como DNS de VPN)

**Notas:**
- Proyecto estable para uso en hogar
- Documentación lista para usuarios no técnicos
- Todos los procedimientos operacionales documentados

---

## Decisiones de seguridad

### Contraseñas
- Generadas aleatoriamente por el instalador (20 caracteres, sin `/+=-`)
- Almacenadas en `.env` (archivo local, no en el repo)
- Cambio manual: editar `.env` y ejecutar `docker compose up -d`

### Certificados TLS
- Pi-hole: autofirmado, generado al primer arranque
- Caddyfile: CA interna (Caddy v2 feature)
- **Esperado:** navegadores mostrarán advertencia; es normal en redes domésticas

### Aislamiento de red
- Contenedores en red privada `shield-dns` (172.30.53.0/24)
- No exponen puertos interiormente (solo DNS y web)
- El puerto 53 es obligatorio en la red doméstica

### API de Pi-hole
- Requiere HTTP Basic auth (usuario + contraseña)
- No está expuesta públicamente (solo en puerto 8443 en la LAN)

---

## Roadmap futuro (especulativo)

Características potenciales no documentadas aquí (están fuera del scope actual):

- [ ] Estadísticas por dispositivo (requería DNS-over-TLS per-device)
- [ ] Sincronización de listas entre múltiples Pis
- [ ] Backup automático de configuración
- [ ] UI móvil nativa en lugar de web responsiva
- [ ] Alertas automáticas si el DNS falla

Estas no son compromisos, solo ideas.

---

## Referencias

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Documentation](https://www.nlnetlabs.nl/projects/unbound/about/)
- [DNSSEC Explained](https://www.icann.org/dnssec/)
- [WireGuard (HEIMDALL)](https://www.wireguard.com/)
