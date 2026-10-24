---
name: publicar-web
description: Úsala para validar y publicar la web estática de SHIELD-DNS en GitHub Pages sin incluir documentación ni secretos.
---

# Publicar web

1. Ejecuta `site/construir.sh /tmp/shield-web/SHIELD-DNS`.
2. Sirve la salida con `python3 -m http.server 8000 -d /tmp/shield-web` si necesitas una comprobación visual.
3. Confirma que Pages copia `site/` y `docs/img` y no publica el resto de `docs/`.
4. Revisa privacidad y enlaces, sube la rama y abre una PR hacia `main`; al fusionarla, el workflow **Pages** publica la web (también se puede lanzar a mano con *Run workflow*).

No uses Docker ni la máquina de producción para probar.
