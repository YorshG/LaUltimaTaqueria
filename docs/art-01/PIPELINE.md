# Pipeline propuesto — personajes provisionales

**Propuesta técnica de ART-01, no congelación de arte.** No existen conceptos o sprites finales en este repositorio. Los polígonos de `data/visuals/art_01.json` son proxies geométricos propios, identificados como provisionales en runtime. No se extrajeron imágenes de un concepto ni se generaron personajes alternativos.

## Recepción de las cuatro referencias

1. Incorporar originales en `art/references/<character_id>/` solo después de recibirlos. Registrar autor/origen, licencia o autorización para uso en el juego, fecha, SHA-256, estado de aprobación y restricciones de redistribución. No subir una imagen sin condiciones conocidas.
2. IDs existentes: `nibbler`, `salsa_tank`, `swift_hopper`, `boss_big_glutton`. Registrar Variante 1 aparte como referencia de composición, con anotaciones de errores mecánicos, nunca como pantalla ejecutable aprobada.
3. Xavier compara original/biblia/sheet de producción: no rediseñar arbitrariamente los tres monstruos. El Gran Glotón conserva panza ancha baja, dientes cortos redondeados y un solo babero; calma → inclinación y ansiedad de hambre (sin enojo) → embate. La etiqueta es **Embate**, nunca Ataque.
4. Faltan rostros, dientes, animación y poses expresivas en los proxies. El babero geométrico no acredita consistencia de un sprite definitivo. No usar estas pruebas para aprobar conceptos ausentes.

## Especificación inicial de exportación (sujeta a revisión)

| Elemento | Canvas por frame | Pivote normalizado | Escala inicial en canvas Godot |
|---|---:|---|---:|
| Nibbler / Salsa Tank / Swift Hopper | 128×128 RGBA | (0.5, 0.85), contacto común | 0.65625 → 84 unidades |
| Gran Glotón, cada fase | 256×256 RGBA | (0.5, 0.85), mismo babero | 0.65625 → 168 unidades |
| Tortilla / carne / verdura | 96×96 RGBA | (0.5, 0.5) | proporcional a celda |

Los tamaños son de producción inicial, **no** hitboxes ni puntos físicos. El renderer provisional coloca proxies desde `LaneMotion.progress`; el futuro Sprite2D/TextureRect debe conservar esa única fuente lógica y ajustar su pivote al mismo anclaje. No cambiar LaneRunner.size, velocidades, rutas ni prioridad para hacer caber el arte.

- Nombre: `<character_id>__<state>__p<1-3>__f<00-03>.png`; ingredientes por ID de contenido (`tortilla`, `meat`, `veggie`). Índice de atlas versionado con rect, pivot, duration y `status: provisional`.
- Estados: idle/move, hunger, receive/bite, satisfied/exit y breach; hasta 4 frames por estado como presupuesto de prueba. Stun y cambios de fase son overlays/poses, no mecánicas nuevas. Versión estática para reducción de movimiento; no borrar el cue.
- PNG transparente, sRGB, RGBA8, sin fondo decorativo, sin texto quemado. Base y sombra plana, contorno oscuro y margen para no cortar extremidades. Mantener un grosor legible tras reducción.
- Empaquetar sin rotación, 2 px de extrusión y 2 px de separación. AtlasTexture/SpriteFrames en Godot; filtro lineal para arte plano, comprobar bleed a escalas fraccionarias. Sin mipmaps para la prueba móvil 2D inicial; comparar si hay minificación intensa. Lossless para validación de alfa/contorno; compresión de GPU solo tras medir calidad y soporte.
- Normales: **una página 2048×2048**, capacidad suficiente para 3×20 frames de 128 con padding. Jefe: hasta **dos páginas 2048×2048** para 3×20 frames de 256 con padding. Ingredientes/UI: una página 512×512.
- Presupuesto máximo inicial residente sin compresión ni mipmaps: 16 + 32 + 1 = **49 MiB de texels**. Con mipmaps completos, aproximadamente 65.3 MiB. No incluye buffers, font atlas, duplicados de importación ni overhead de driver. Es un techo de planificación para reducir después de medir, no gasto actual ni presupuesto iOS aprobado. Cargar/desalojar las páginas del boss al cambiar encuentro es una propuesta posterior, no implementación ART-01.
- La slice actual añade **0 bytes de atlas de personajes**, 25 Controls de ingrediente, dos capas de dibujo y recursos de estilo pequeños. Redibuja carriles activos; las celdas se invalidan al redibujar sus Buttons. Sin partículas, shaders, tween, audio adicional o descargas.

## Puerta de calidad

Cada exportación debe repetir la prueba **a 32×32 px reales**, no una miniatura visual aproximada: render normal, luminancia desaturada y silueta exterior negra opaca sin ojos/boca/babero interiores. Guardar cada PNG y una hoja ampliada con vecino más cercano; incluir las tres fases del jefe. Verificar extremidades, conectividad, margen, contraste y distinguir entre máscaras distintas y reconocimiento humano.

Ejecutado sobre los proxies: `tests/art_01_legibility.gd`. Se exportan 18 PNG de 32 px y una hoja 960×480 (ampliación 4×, columnas N/S/H/B1/B2/B3; filas color/gris/silueta). El test exige relleno negro, área razonable y máscaras distintas. **No mide reconocimiento**. Xavier debe revisar las tres fases, cuya diferenciación es más débil que la de los tres roles; las expresiones solo podrán auditarse cuando llegue el arte real.

## Incorporación posterior sin invadir reglas

Reemplazar únicamente el render de `draw_proxy` por regiones de atlas, conservando IDs, lectura de fase desde `MonsterState.get_current_phase()` y objetivo desde `LaneField.select_nearest_target()`. Validar primero una pose quieta por personaje, luego las cinco familias de animación. La quinta elección sigue perteneciendo a Main; ningún sprite crea o anticipa el boss. La integración del layout #62/safe areas y la aprobación de Xavier se revisan por separado antes de promover.
