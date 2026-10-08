# Matriz #61 / #62 / #63 · ART-01D

Referencias iniciales: #61 `9832846fe5837919d441273f496f31ef3430c0cf` (base uat), #62 `e894b438939e6260a4c8cc6c566373c351ddc2a7` (base rama #61), #63 `c283b337dd5ccd7355ad554a58743ff972151d3b` (base uat). Todos OPEN/DRAFT. Integración selectiva de contenido dentro de #63 autorizada por esta misión; no es merge de ramas ni promoción.

| Delta | Procedencia | Acción ART-01D | Límite |
|---|---|---|---|
| Fuente fallback de celdas 42 | #61 | Conservada exactamente en BoardView; assertion original en board_input_test | IngredientVisual cubre el Button: valida fallback, no legibilidad del proxy |
| Fuente fallback de runners 32 + outline 4 | #61 | Conservada exactamente en LaneRunner.tscn; assertion original en lane_integration_test | LaneVisual dibuja el proxy; su lectura se comprueba aparte con evidencia/art tests |
| Layout inferior | #62 | Intención espacial conservada con rects del layout adaptativo de #63 | No copiar escenas, casts VBox, orden directo de hijos ni límite 64 |
| Assertions espaciales | #62 | ui_mobile_layout_test adaptado, 3 proporciones; incluye 5×5 | Sin dependencia de tipo Container |
| Tests de layout en core | #62 | ui_mobile + ART-01B + ART-01D dentro de core | Guard compartido rechaza errores, resumen ausente/duplicado/cero checks |
| Documento/origen físico | #62 | UI_MOBILE_01_VALIDATION preserva registro histórico y explica candidato actual | No adjudica aquella observación a la build actual |
| Cadena y hambre | #63 C → D | Contraste, conectores de margen, orden 26/20 px; ceil positivo solo de texto | Ingredientes, hitboxes, floats, targeting y reglas intactos |

Los cuatro archivos de #61 se preservan byte a byte respecto a su head. Sus pruebas siguen siendo útiles como contrato fallback y se ejecutan en core. Los proxies se verifican con tests C/D y píxeles reales; no se infiere su legibilidad de las dos assertions de fuente.

La integración directa de #62 continúa detenida por conflictos en App.tscn y planning/BACKLOG.md y contrato VBox incompatible. Se documenta ese conflicto en evidence/merge-tree-62.log; no se resuelve ni se cambia #62. Solo se rescata el subconjunto expresamente autorizado. La sustitución definitiva y eventual cierre de #62 requieren decisión de Jorge tras aceptación; tampoco se cierra #61 ni #63.

Próximo paso: reauditoría de Xavier, revisión visual de Jorge y validación física iPhone 17/16 Pro Max. Después, decisión explícita sobre orden de promoción. Ningún CI verde equivale a esa aprobación.
