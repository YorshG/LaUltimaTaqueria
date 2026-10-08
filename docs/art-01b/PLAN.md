# ART-01B — corrección de distribución

Misión de Jorge, 2026-10-07. Continuación del PR #63, `codex/art-01-visual-slice` → `uat`, siempre DRAFT. Sin merge, main ni force push. Los archivos y evidencias históricos de ART-01 se conservan.

## Auditoría previa

| Referencia | SHA auditado | Estado |
|---|---|---|
| #63 inicial / ART-01 | `04c3f3c7e3fb581aad55a538996d035e793413f3` | OPEN DRAFT |
| uat / baseline | `d46cc8cdebb363a7791da8417d78870da3e676d1` | Base de #63 |
| main | `a6d88f4c4715a64614ddf3e0a220e76d65304339` | No modificar |
| #61 | `9832846fe5837919d441273f496f31ef3430c0cf` | OPEN DRAFT, base uat |
| #62 | `e894b438939e6260a4c8cc6c566373c351ddc2a7` | OPEN DRAFT, base fix/ios-runner-legibility |

Se leyeron alcance, reglas, arte, biblia de personajes, arquitectura, decisiones, colaboración y handoff ART-01. No se dispone de imagen de referencia Opción 1B ni sprites canónicos finales: se conserva la interpretación provisional de los requisitos escritos. No se reemplaza toda la UI con una imagen.

#61 amplía fuentes del tablero/runner. #62 propone carriles antes del tablero y reinicio en TopBar; no resuelve safe area dinámica. Antes de editar se ensayó en copia desechable el overlay exacto de App/Main/LaneRunner/board_view y sus tests de #61/#62 sobre ART-01: importación, board input, ui_mobile_layout y ART-01 visual pasaron. El log completo se conserva en evidence/stack-audit-before.log.

La composición final retiene el propósito de #62 (orden y reinicio superior) y sus nombres/API; sustituye su VBox fijo por dos componentes de layout. El límite de botón <=64 unidades de su test contradice el nuevo mínimo táctil a escala 3; se reemplaza por aceptación de tamaño en pt. No se deben superponer sus App/Main originales sobre ART-01B. Sus fuentes se prueban en copia desechable, no se adjudican ni editan los archivos de gameplay de #61 en esta rama.

## Criterios y lotes

1. Layout: rect seguro de App, HUD compacto y feedback 2×2, carriles/mostrador/tablero cuadrado inferior. Exactamente 25 celdas. Conservar sesiones, señales, guardado e input.
2. Proyección: avance vertical real, slots horizontales dentro de cada carril para evitar solapamiento, hambre numérica y barra, objetivo del selector real. Tres poses de jefe con dientes redondos y Hambre ansiosa. Todos son proxies.
3. Verificación: pruebas de orden espacial/safe area/touch/modal/resize más regresiones anteriores y composición #61/#62. Capturas comparables en 1080×1620, 1920 y 2400, anotaciones y estados adicionales.
4. Costo: fixture histórica de siete clientes, 60 frames warmup +180 muestras, tres ejecuciones consecutivas por referencia, renderer desktop idéntico. Registrar draw calls, memoria, nodos, recursos, huérfanos, mediana/p95. Sin inferir FPS físicos.
5. Entrega: commits auditables, PR63 actualizado DRAFT, evidencias y handoff. Aprobación visual de Jorge y auditoría de Xavier pendientes.

## Coordenadas

El proyecto usa viewport base 1080×1920, stretch canvas_items y expand. Las pruebas fijan un SubViewport de canvas 1080×H. El adaptador invierte `Viewport.get_screen_transform() * App.get_global_transform_with_canvas()` antes de intersectar el rect seguro con App. `screen_get_scale / longitud_del_eje_transformado` da unidades canvas por punto; no se interpreta un píxel canvas como un punto. Los SubViewport de prueba inyectan explícitamente transformación y densidad. Escritorio o un rect inválido usan el viewport disponible como fallback.

Fuentes de API: [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) y [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html). La exactitud de métricas recibidas en iOS y la comodidad real quedan pendientes de hardware.
