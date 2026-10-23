---
name: comprobar-cambios
description: Úsala antes de integrar o publicar cambios para ejecutar las comprobaciones estáticas, de Compose, secretos y privacidad de SHIELD-DNS.
---

# Comprobar cambios

Ejecuta:

```bash
bash -n *.sh site/*.sh
shellcheck *.sh site/*.sh
cp .env.example /tmp/shield.env
PIHOLE_PASSWORD=x docker compose --env-file /tmp/shield.env config -q
gitleaks git . --redact
```

Después revisa manualmente `git diff`, los enlaces relativos, las anclas, los puertos publicados, los secretos y la privacidad. No ejecutes `install.sh`, `update.sh`, `restore.sh`, `uninstall.sh` ni Docker contra producción. No hagas commit.
