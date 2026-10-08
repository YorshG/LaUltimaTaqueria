# Handoff — auditoría independiente de Xavier

**No se ha realizado esta auditoría ni se ha enviado un mensaje externo.** Entrega: slice provisional, DRAFT a uat, **NO MERGE**. Revisar el diff completo y [VALIDATION](VALIDATION.md) antes de decidir; no marcar ART-01 concluido.

1. Comparar [antes](evidence/before-1920.png) / [después](evidence/after-1920.png) con el juego real: 25 casillas, tres ingredientes, tres carriles, cadena ortogonal, reputación y oleada. «Monedas —» es un pendiente aprobado por Jorge, no saldo ni recompensa.
2. Revisar que el aro de objetivo coincida con el runner servido, especialmente empates centro/izquierda/derecha, cruces, retiro por satisfacción, breach y ausencia de objetivo. La fuente es `select_nearest_target()`, nunca una regla de arte. El desplazamiento se observa desde `motion.progress`.
3. Obtener originales y condiciones de uso de Nibbler, Salsa Tank, Swift Hopper, Gran Glotón y Variante 1. No aceptar los polígonos como sustitutos de esos diseños ni congelar personajes por esta entrega. Solicitar hashes/procedencia/permiso antes de incorporar imágenes.
4. Evaluar los [18 rasters de 32 px y hoja](evidence/legibility-sheet.png), en gris y silueta exterior sólida, sin usar las letras como ayuda. Registrar por personaje reconocimiento y confusiones. Atención especial a Calma/Embate del jefe. Repetir con los sprites verdaderos al recibirlos.
5. En sheets futuros del jefe, exigir dientes cortos redondeados, panza ancha baja, un babero consistente, fase 2 con hambre ansiosa y sin enojo, fase 3 Embate. Eso está especificado pero **no representado ni validado** por un rostro final en esta slice.
6. Reproducir BOSS-01 o el bot: el boss solo comienza después de cinco oleadas resueltas y la quinta elección. Las imágenes de fase son fixtures, no prueba de ese timing.
7. Evaluar 1080×1620, 1920 y 2400; luego ambas manos, notch/Home, textos y densidad en iPhone real. Hay FAIL conocido del HUD ante la máscara sintética. Coordinar con propietario de #61/#62; el stack temporal pasó pruebas, pero no está integrado ni aprobado.
8. Revisar el coste 59→329 draw calls y +29 nodos. IOS-02 debe medir frame/memoria/temperatura física. No aprobar rendimiento móvil con la mediana desktop.

Registrar dictamen **aprobable / cambios solicitados / bloqueado por referencia ausente**, capturas anotadas, SHA completo y criterios pendientes. Jorge decide el orden de integración. Sin promoción a main ni merge de ningún PR en este handoff.
