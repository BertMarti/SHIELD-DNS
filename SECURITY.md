# Seguridad

SHIELD-DNS responde a todas las consultas DNS de una casa: un fallo puede afectar a todos sus dispositivos.
Gracias por avisar con discreción.

## Cómo avisar de un fallo

- **No abras una issue pública.** Usa el aviso privado de GitHub:
  [Security → Report a vulnerability](https://github.com/BertMarti/SHIELD-DNS/security/advisories/new).
- Cuenta qué has visto, cómo reproducirlo y qué versión usas (`git log -1 --oneline`).
- **Nunca** incluyas tu `.env`, la contraseña de Pi-hole, registros de consultas, IPs públicas ni nombres de tus dispositivos.

Respondo en cuanto pueda (es un proyecto personal, sin plazos garantizados). Si el fallo se confirma, se arregla en `main`
y se explica en el [CHANGELOG](CHANGELOG.md).

## Versiones con soporte

Solo la última versión de la rama `main`. Actualiza con `./update.sh`.

## Buenas prácticas para quien lo instala

- **No abras el puerto 53 ni el panel (8080/8443) en el router.** Un DNS abierto a internet se usa para ataques.
- Entra al panel por `https://…:8443/admin` mejor que por HTTP.
- Guarda las copias de `./backup.sh` fuera de la máquina: contienen la contraseña del panel.
- Mantén la máquina y las imágenes al día (`sudo apt upgrade` y `./update.sh`).
