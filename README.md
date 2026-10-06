# 🛡️ SHIELD-DNS - Bloqueador de publicidad

**Estado:** En desarrollo (esqueleto inicial)
**Versión:** 0.1.0
**Licencia:** MIT

## ¿Qué es SHIELD-DNS?

SHIELD-DNS es un **bloqueador de publicidad a nivel de DNS** que se ejecuta en tu Raspberry Pi. Cualquier dispositivo que lo use como DNS (directamente o a través de la VPN HEIMDALL) deja de cargar anuncios y rastreadores, sin instalar nada en él.

### Funcionalidades previstas

- 🚫 Bloqueo de anuncios y rastreadores para toda la red y la VPN
- 📋 Listas de bloqueo actualizadas automáticamente
- 📊 Panel web con estadísticas
- 🔐 Resolución privada con Unbound

## Estado actual

El repositorio contiene un servidor FastAPI mínimo (`/health` y un endpoint de prueba), el `Dockerfile` y el `docker-compose.yml`. El servidor DNS con listas de bloqueo está pendiente.

## Requisitos

- Raspberry Pi 5 con Raspberry Pi OS de 64 bits, u otra distribución Linux
- Docker y Docker Compose
- Puerto 53 (UDP/TCP) libre en la Raspberry Pi

## Instalación

```bash
git clone https://github.com/BertMarti/SHIELD-DNS.git
cd SHIELD-DNS
cp .env.example .env
docker compose up -d
```

Después, pon la IP de la Raspberry Pi como DNS en el router o en cada dispositivo. Para saber la IP:

```bash
hostname -I
```

## Documentación para agentes

- [CLAUDE.md](CLAUDE.md) – instrucciones para Claude Code
- [AGENTS.md](AGENTS.md) – reparto de tareas entre agentes
- [SKILLS.md](SKILLS.md) – capacidades
- [MEMORY.md](MEMORY.md) – memoria y decisiones del proyecto

## Licencia

MIT
