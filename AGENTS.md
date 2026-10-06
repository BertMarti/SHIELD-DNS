# AGENTS.md – Distribución de trabajo para agentes

## Reparto recomendado

### Modelo económico (ej. Haiku)
**Tareas:** edición de documentación, cambios mecánicos, verificación de archivos

- Actualizar `.env.example` con nuevas variables
- Editar README.md y documentación
- Cambios triviales en docker-compose.yml (ej. cambiar puertos)
- Revisar que todos los archivos sean consistentes
- Formatear código bash

### Modelo de razonamiento profundo (ej. Opus)
**Tareas:** debugging de red, diseño, decisiones arquitectónicas

- Diseñar cambios en la topología de la red Docker
- Debuguear problemas con DNS o DNSSEC
- Decidir cómo integrar SHIELD-DNS con HEIMDALL
- Resolver conflictos de puertos o configuración
- Crear procedimientos operacionales complejos (ej. migración de datos)

## División por área

| Área | Modelo económico | Modelo fuerte | Notas |
|------|------------------|---------------|-------|
| Docs, README | ✓ | — | Edición directa, sin razonamiento profundo |
| .env.example, variables | ✓ | — | Cambios simples; lógica compleja → fuerte |
| docker-compose.yml | — | ✓ | Cambios de red requieren verificación de IPs/puertos |
| Scripts bash (install.sh, uninstall.sh) | — | ✓ | Lógica condicional, idempotencia, error handling |
| Debugging de problemas | — | ✓ | Requires understanding networking, Docker, Pi-hole |
| Integración con HEIMDALL | — | ✓ | Requiere coordinación entre proyectos |

## Flux de trabajo sugerido

1. **Tarea en modelo económico:** edita README o .env.example
   - Verifica cambios contra `git diff`
   - Commitea si es seguro

2. **Tarea en modelo fuerte:** debugging o arquitectura
   - Lee archivos relevantes (docker-compose.yml, install.sh)
   - Toma decisiones de diseño
   - Crea cambios y verifica con tests (si aplica)
   - Commitea con mensaje detallado en español

3. **Trabajo en paralelo:** si hay dos tareas independientes (ej. doc + script), pueden hacer ambas en paralelo (dos agentes)

## Limitaciones conocidas

- No hay un test suite automatizado (tests manuales via SSH en la Pi)
- Los cambios de red requieren verificación manual en hardware real
- DNSSEC es difícil de debuguear sin acceso directo a la Pi

## Reunión diaria

Si hay múltiples sprints:
- Modelo económico: repasa cambios de la mañana
- Modelo fuerte: planifica cambios de arquitectura y verifica tests

## Ejemplos de tareas

### Tarea A: "Añadir nueva lista de bloqueo a EXTRA_ADLISTS"
→ **Modelo económico** (edita .env.example, README)

### Tarea B: "Debuguear por qué DNSSEC falla en algunos dominios"
→ **Modelo fuerte** (lee docker-compose.yml, install.sh, SSH en Pi, ejecuta dig)

### Tarea C: "Hacer que HEIMDALL use automáticamente SHIELD-DNS como DNS de la VPN"
→ **Modelo fuerte** (requiere entender ambos proyectos, cambios en install.sh, tests)

### Tarea D: "Actualizar el README con nuevas instrucciones de troubleshooting"
→ **Modelo económico** (edita README.md, verifica sintaxis markdown)
