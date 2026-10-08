# Handoff ART-01B para Xavier

El PR #63 sigue DRAFT y no autoriza merge. Jorge revisa distribución y arte; Xavier realiza auditoría independiente. Este documento entrega evidencia, no afirma aceptación visual ni prueba en dispositivo.

## Revisar primero

1. Abrir `evidence/comparison-1620.png`, `comparison-1920.png` y `comparison-2400.png`: cada una muestra uat → ART-01 → ART-01B con la misma fixture de tres clientes y cadena ortogonal.
2. Abrir `bounds-*.png`: máscaras rojas sintéticas de notch/Home Indicator, contornos de HUD/carriles/mostrador/tablero/reinicio. Contrastar con valores de `art_01b_layout_test.log`.
3. Revisar `crowded-*.png` (nueve clientes, hambre fraccional), `boss1/2/3.png`, `restart-*.png`, `upgrades-*.png`. Los monstruos y sus expresiones son proxies.
4. Leer [VALIDATION.md](VALIDATION.md), [PLAN.md](PLAN.md), [FILES.md](FILES.md), `evidence/performance.json` y los logs de composición.

## Contratos que requieren atención

- `App` conserva su script/lifecycle original y posee exactamente una sesión. `safe_area_layout.gd` solo coloca controles y pasa métricas de vista a Main. No usar safe area directamente como unidades de canvas.
- `gameplay_layout.gd` conserva los hijos únicos y contratos; sus rects reales deben ordenar HUD → carriles → mostrador → tablero. El tablero es 5×5 con celdas cuadradas. La cadena observa cambios de tamaño de celdas.
- Los slots horizontales evitan que clientes cercanos se tapen. La coordenada vertical sigue `LaneMotion.progress`; no altera movimiento, hambre ni prioridad. La indicación de objetivo usa `select_nearest_target()`; se prueba que recibe el platillo real.
- `Monedas —` sigue pendiente, sin conectar SaveService ni crear recompensas. Reputación no es vida y no se agrega una barra global de jefe en oleadas normales.
- #61 fue superpuesto en copia desechable con sus fuentes y assertions exactos. #62 pasó la auditoría previa exacta; sus App/Main se adaptan aquí con cambios explícitos. No sobreescribir estos App/Main con los originales de #62. El test original de #62 exige VBox y botón <=64 unidades, incompatible con 44 pt a escala 3; no se afirma que pase sin adaptar. Ver `composition-vs-62.diff`.

## Pendientes humanos y físicos

- Jorge: confirmar distribución, tamaño percibido, fidelidad a Opción 1B y expresión de Hambre. No se contó con una imagen aprobada de Opción 1B; se aplicaron los requisitos escritos y guías del repositorio.
- Xavier: ejecutar regresiones y revisar el mínimo delta entre #61/#62/#63. Sus ramas no se fusionaron ni modificaron.
- iPhone 17 e iPhone 16 Pro Max: validar valores reales de safe area/escala, arrastre con pulgar, esquinas, Home Indicator, foco/reinicio/modal y cambio de tamaño. No se conectó dispositivo iOS ni Android en esta misión.
- Medir GPU, memoria, batería y frame pacing en dispositivo. TIME_PROCESS de escritorio no demuestra 60 FPS; monitor periódico, no contador GPU.
- Revisar lectura de hambre en tres clientes por carril: números en dos filas de 32 unidades (~10.7 pt en escala 3), complementados con barra segmentada y token. La geometría no se superpone en la fixture, pero comodidad y lectura física siguen pendientes. Fuera de las proporciones/escala ensayadas no se promete automáticamente mínimo de 44 pt.
- No declarar estas formas arte final ni promover el PR por CI verde. No se envió este handoff a terceros.

## Revisiones entregadas

- Inicial ART-01: `04c3f3c7e3fb581aad55a538996d035e793413f3`.
- Implementación ART-01B: `1659e80416c0b7d6082cd2819a7d75a120d1a63e`.
- Pruebas/CI ART-01B: `027804920c078643003d945133f382eb8fccbb8f`.
- El commit posterior agrega este informe y la evidencia; su SHA final figura en el PR #63 y en la entrega a Jorge.
