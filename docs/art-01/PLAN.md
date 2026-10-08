# ART-01 — auditoría y slice 1

Fecha local: 2026-10-07. Estado: **en preparación para revisión humana; NO MERGE**.

## Base y propiedad

- `origin/uat`: `d46cc8cdebb363a7791da8417d78870da3e676d1`.
- `origin/main`: `a6d88f4c4715a64614ddf3e0a220e76d65304339`.
- Checkout inicial limpio, rama `codex/upg-02h-steady-hands`, mismo SHA que uat.
- Worktree aislado, rama `codex/art-01-visual-slice`, creada desde ese SHA de uat.
- PR #60 IOS-02: memoria/CI/backlog; #61: BoardView.gd, LaneRunner.tscn y pruebas de input/integración; #62 apilado sobre #61: App.tscn, Main.tscn, core suite, backlog y prueba/layout móvil; #54: documentación M3/iOS/UPG-02h.
- No se editarán esos archivos ni contenido de Claude en `data/content/`. PRE-02 figura terminado; no se encontró asignación activa adicional. No se modifica ningún otro worktree.
- Permitidos: `scripts/visuals/`, `data/visuals/`, BoardView.tscn, LaneField.tscn, Hud.tscn, color de fondo en project.godot, documentación ART-01, DECISIONS.md, nuevas pruebas ART-01 y workflow propio. No se cambia el entry point de tests en uso por #62.

## Fuentes leídas

AGENTS.md, CLAUDE.md, PROTOTYPE_SCOPE, ART_STYLE, CHARACTER_ART_BIBLE completos, CORE_RULES, GAME_DESIGN, DECISIONS completo, ARCHITECTURE, COLLABORATION, UX_AND_ACCESSIBILITY, CONTENT_MODEL, ECONOMY, backlog/DoD; todas las escenas de producto, BoardView, LaneRunner, LaneField, Main, App, HUD, MonsterState y contratos de pruebas relevantes. Motor instalado: `4.7.2.stable.official.ed1daf0bf`.

## Inventario real y diferencias

`git ls-tree -r --name-only origin/uat` y búsqueda local: **cero** PNG/JPG/WebP/SVG/PSD/Aseprite de personajes. Solo existe la biblia textual. No están Nibbler, Salsa Tank, Swift Hopper, Gran Glotón ni Variante 1 como imágenes; no hay licencia, exportación, aprobación de sprite ni procedencia gráfica que verificar. El cierre de Art Sprint 0 y el rol de Xavier proceden del encargo; no se inventa evidencia del chat creativo.

El alcance excluye arte final y Android. La referencia de composición no puede copiarse ni compararse visualmente sin el archivo. El layout aprobado en uat tiene **tablero arriba y carriles abajo**; #62 propone invertirlos. ART-01 conserva uat y deja la composición móvil a ese PR. No se asigna un tipo de monstruo a cada carril: los tres tipos pueden aparecer donde indiquen los spawns.

Monedas: ECONOMY define propinas por progreso/victoria, pero no cantidades; SaveService es una API aislada de metadatos, sin fuente conectada al HUD. No se inventa una cifra ni fórmula. Jorge eligió **«Monedas —» pendiente** en esta misión.

## Geometría y riesgos actuales

- Canvas 1080×1920, `canvas_items`, aspect `expand`, portrait, ventana desktop 540×960; renderer mobile.
- Main tiene márgenes 24/48, VBox y tablero cuadrado AspectRatioContainer; grid 5×5, separación 8, mínimo de celda 52 unidades canvas.
- Tres hosts de carril, runner lógico 36×36; su avance normalizado es la fuente de targeting. Empates centro/izquierda/derecha, luego secuencia.
- BoardView recibe mouse/touch en coordenadas locales. D8 aplica tolerancia después del hit exacto. La presentación nueva ignora input.
- App tiene footer de reinicio de 88 unidades, sin consulta a safe area del sistema. Márgenes fijos **no acreditan** Dynamic Island/Home ni 44 pt físicos. #62 posee esa superficie; se mide la brecha sin modificarla.
- No atlas/sprites/import pipeline gráfico vigente. No autoloads declarados. SaveService no pertenece al lifecycle de App.

## Diseño incremental y aceptación

1. Capa visual de tablero: tres pictogramas propios provisionales (tortilla/carne/verdura), contorno oscuro y dos tonos; selección mediante borde y segmentos **solo para los puntos aceptados por ChainPath**. Mantiene texto/meta, 25 celdas, mínimos y APIs. La nueva fila de monedas consume espacio del VBox existente: sus containers recalculan tamaños; no se promete igualdad píxel a píxel del tablero. Se vuelven a probar coordenadas táctiles reales del viewport.
2. Capa visual de carriles: fondo azul-violeta, mostrador cálido, tres líneas separadas y proxies geométricos etiquetados. Sin rostros inventados ni reinterpretación de los conceptos ausentes. Estado del jefe leído de MonsterState; solo se dibuja un jefe existente, nunca anticipado. La posición visual se proyecta desde LaneMotion.progress sobre el tramo dibujable; los tres roles normales usan la misma proyección. No se usa la posición de Control que puede ser reordenada por PanelContainer. Se pinta el objetivo al final para preservar su cue en cruces.
3. Objetivo: marcador obtenido mediante `LaneField.select_nearest_target()`, sin duplicar prioridades ni mutar simulación. Se actualiza con avance/servicio; desaparece sin objetivo.
4. HUD: conservar oleada y reputación existentes; añadir «Monedas —» y estilo de reputación inequívoco. Sin vidas/corazones/puntuación/pedidos.
5. Verificación: importación, core, boss/HUD/feedback, restart/save, touch y regresión de retiro; capturas de fixture equivalente antes/después, aspectos y placeholders a 32 px/desaturados. Medir límites sin afirmar dispositivo ni 60 FPS.

Reversible: quitar los nodos de presentación y el renglón/estilo del HUD revierte la slice. Ninguna regla, señal, autoload o fuente de contenido jugable cambia.

## Pendientes artísticos y técnicos

- Incorporar conceptos y Variante 1 originales con procedencia, autor/derechos, hash, fecha y estado de revisión. Xavier revisa referencias, no las congela por este PR.
- Exportar sprites según PIPELINE.md; validar sus siluetas reales. Los placeholders no aprueban personajes finales.
- Orden de integración de #61/#62/ART-01 y safe areas físicas requiere coordinación humana; no hacer merge automático.
- Fórmula/fuente de monedas y localización posterior del HUD. Android fuera del prototipo; no se declara probado.
