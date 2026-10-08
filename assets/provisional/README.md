# Activos provisionales ART-01B

`art_01b_atlas.png` es un bake local de las geometrías propias de ART-01, no arte canónico aprobado ni una imagen conceptual reutilizada. Procedencia: `scripts/visuals/art_01_style.gd` y `data/visuals/art_01.json`; Godot dibuja y exporta mediante `tests/art_01b_build_atlas.gd`. No hay proveedor, descarga, IA generativa ni dependencia nueva.

- PNG RGBA transparente 512×512, una textura compartida. Importación lossless, sin mipmaps; aproximadamente 1 MiB RGBA sin comprimir, 44 KiB de archivo.
- Tres columnas con paso de 168 px. Cada figura ocupa 152×152 con margen inicial de 8 px. El runtime muestrea regiones de 160×160 incluyendo cuatro píxeles alrededor del dibujo para conservar contornos.
- Fila 0: Nibbler / Salsa Tank / Swift Hopper. Fila 1: Calma / Hambre / Embate. Fila 2: tortilla / carne / verdura. Sin sprites, rigs o animaciones finales.
- El jefe conserva siluetas y babero provisionales; agrega ojos, cejas elevadas en Hambre y dientes circulares. La evaluación de simpatía/ansiedad y fidelidad artística corresponde a Jorge.
- `controls.tres` es un Theme reutilizable de paneles opacos, botones y foco. No altera handlers ni estados de sesión.

Para regenerar desde el worktree, con renderer gráfico disponible:

```sh
godot --path . --script res://tests/art_01b_build_atlas.gd
godot --headless --path . --editor --quit
```

Los textos, barras, cadena y controles se dibujan por separado. Nunca se usa una captura completa como UI.
