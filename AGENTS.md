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

## Trabajo con varios modelos (opcional, vía OpenCode)

Un agente orquestador (por ejemplo Claude en Claude Code) puede repartir tareas entre los modelos que tengas conectados en [OpenCode](https://opencode.ai): GitHub Copilot, ChatGPT, Gemini, modelos gratuitos de OpenCode Zen, etc. Así se ahorra cuota del modelo principal sin perder el control.

**Papeles**
- **Orquestador:** entiende la petición, planifica, divide en tareas pequeñas con rutas y objetivo concretos, revisa todo lo que vuelve, pasa las pruebas, hace commit y despliega. Es el único que hace commit, push o despliega.
- **Delegados:** reciben una tarea cerrada (escribir una función, redactar documentación, revisar un diff) y devuelven el resultado.

**Cómo delegar**
```bash
opencode models                    # modelos disponibles (proveedor/modelo)
opencode auth list                 # cuentas conectadas
# Revisión o consulta, sin tocar archivos:
opencode run --agent plan -m <proveedor/modelo> --dir <repo> "Revisa ... y lista los problemas"
# Cambios: siempre en un worktree aparte, nunca en la copia desplegada
git worktree add ../.wt/<tarea> -b feat/<tarea>
opencode run -m <proveedor/modelo> --dir ../.wt/<tarea> "Implementa ... siguiendo AGENTS.md"
```

**Reparto orientativo**
| Tarea | Modelo |
|---|---|
| Diseño, seguridad, depuración difícil, revisión final | El más capaz (orquestador) |
| Implementar funciones siguiendo un patrón existente | Modelo de código (Copilot / GPT) |
| Documentación, traducciones, textos | Modelo rápido (Gemini / Copilot) |
| Búsquedas, resúmenes, borradores sin datos sensibles | Modelos gratuitos (Zen) |

**Reglas**
- Nunca pases a un delegado secretos, `.env`, contraseñas ni datos personales. Con los modelos **gratuitos**, todavía menos: algunos usan lo que reciben para entrenar.
- Los delegados no hacen commit, push ni despliegues, ni tocan servicios en marcha. Las revisiones se hacen con `--agent plan` (solo lectura).
- Todo lo que devuelva un delegado lo revisa el orquestador y pasa la suite completa de pruebas antes de integrarse.
- Dale a cada delegado el contexto que necesita (rutas, este `AGENTS.md`, criterios de aceptación): no comparte la memoria del orquestador.
