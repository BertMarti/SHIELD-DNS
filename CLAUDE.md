# CLAUDE.md – Claude Code en SHIELD-DNS

Lee `AGENTS.md` antes de trabajar. Es la guía principal del repositorio.

Claude Code orquesta el trabajo, usa los subagentes de `.claude/agents/` y aplica las skills de `.claude/skills/`. No ejecutes `install.sh`, `update.sh`, `restore.sh`, `uninstall.sh` ni Docker contra la máquina real: SHIELD-DNS está en producción y da DNS a toda la casa.

Antes de entregar cambios:

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
cp .env.example /tmp/shield.env
PIHOLE_PASSWORD=x docker compose --env-file /tmp/shield.env config -q
gitleaks git . --redact
```

Revisa además privacidad, enlaces y anclas. No incluyas `.env`, `data/`, IPs reales, dominios reales, MACs, claves ni nombres personales.

Los commits, cuando los solicite el orquestador, usan español, autor `BertMarti <107127310+BertMarti@users.noreply.github.com>` y una línea `Co-Authored-By: Claude`.

La arquitectura, los procedimientos y los gotchas están en `docs/DESARROLLO.md`; la memoria histórica en `MEMORY.md`; los procedimientos operativos en `SKILLS.md`.
