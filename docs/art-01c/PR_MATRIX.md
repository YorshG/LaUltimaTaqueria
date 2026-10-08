# Comparación técnica y propuesta de integración (no ejecutada)

Referencias congeladas verificadas en GitHub: #61 `9832846fe5837919d441273f496f31ef3430c0cf` (base uat); #62 `e894b438939e6260a4c8cc6c566373c351ddc2a7` (base **rama #61**); #63 inicial `5e4bc11dd2c68a2b7563437e8cdeb98d39a97dc3` (base uat). Los tres OPEN DRAFT. #62 contiene #61 como ancestro; #63 parte directamente de uat y no contiene los commits de #61/#62.

CI remoto al inicio: todos los resultados SUCCESS. #61 tiene 8 registros / 7 nombres únicos (smoke duplicado), #62 6 registros / 5 nombres únicos (smoke duplicado), #63 8/8 nombres únicos. Se conservan snapshots en `evidence/pr-*-initial.json`. CI verde de una rama no prueba compatibilidad de su combinación.

## Inventario exacto

#61: `scripts/board/board_view.gd` (+font 42), `scenes/lane/LaneRunner.tscn` (+font 32, outline 4), `tests/board_input_test.gd` (+assert fuente tablero) y `tests/lane_integration_test.gd` (+assert fuente runner). Ningún cambio en geometría, hitboxes, modelos ni señales.

#62 respecto a #61: `scenes/App.tscn`, `scenes/Main.tscn`, `tests/ui_mobile_layout_test.gd`, una entrada en `tests/run_core_suite.sh`, `docs/UI_MOBILE_01_VALIDATION.md` y una fila en `planning/BACKLOG.md`. Su body aún menciona head anterior `1c102a8`; se audita el head real `e894b43` obtenido de API.

#63: presentación y assets provisionales, observadores Board/Lane, layout adaptativo Main/App, HUD/feedback/modales, pruebas/evidencias ART-01/B/C; ningún cambio en scripts de reglas, datos de balance o lifecycle. Inventario exacto contra uat en `evidence/pr63-files.txt`, delta ART-01C en `FILES.md`.

## Cobertura y riesgos

| Contrato/cambio | #61 | #62 | #63 ART-01B/C | Recomendación / riesgo |
|---|---|---|---|---|
| Fuente fallback tablero 42 | Implementa + assert | Hereda #61 | No implementa; IngredientVisual dibuja icono + nombre y oculta texto del Button | Conservar el delta de #61; su assert protege fallback, no certifica el nombre dibujado |
| Runner fallback 32 y outline 4 | Implementa; assert solo tamaño | Hereda #61 | No implementa; LaneVisual usa proxies superpuestos y sus propios tamaños | Conservar #61; no interpretar su assert como validación visual del proxy |
| Carriles antes del tablero; tablero inferior | — | Reordena VBox/AspectRatio | Sustituye con `gameplay_layout.gd`; mismas APIs/hijos únicos, rects adaptativos | No duplicar escenas de #62 |
| Reinicio superior | — | TopBar compacta fija (mínimo 64 unidades) | TopBar existente, posición segura; mínimo 44 pt a escala efectiva | Propósito cubierto; overlay #62 perdería adaptación de safe area y tamaño físico |
| Feedback por encima del tablero | — | Posición intermedia | Feedback compacto 2×2 en cabecera | Propósito cubierto, diferente posición dentro de la zona superior |
| Prueba móvil de tres proporciones | — | `ui_mobile_layout_test.gd` incorporado a core | `art_01b_layout_test.gd`, 2,005 checks, en CI presentation, no dentro de core | Único mecanismo de #62 no replicado: entrada core. Se propone portar assertions espaciales válidas al test actual/core en integración futura |
| Cast VBox y orden directo de hijos | — | Contratos del test de #62 | `Layout` y `Content` son Control con scripts adaptativos | Incompatibilidad de test/escena confirmada; sustituir casts por rects/contratos públicos |
| Registro UI-MOBILE-01 e historia física | — | Documento de observación iPhone 17 y fila propia | Backlog ART agregado; se referencia historia de #62, no se copia ni adjudica | Único contenido documental pendiente de portar si Jorge decide sustituir #62 |
| Safe area dinámica / transformación canvas | — | Pendiente de hardware | Proyección y tests sintéticos | Cobertura adicional de #63; validación real sigue pendiente |
| Ingredientes/hambre/fixtures | — | — | ART-01C conserva colores, entero en una línea, datos reales | Delta exclusivo #63, presentación únicamente |

## Compatibilidad demostrada y límites

`git merge-tree --write-tree #61 #63_inicial` produce árbol sin conflictos. `#62 + #63_inicial` produce conflicto de contenido en **App.tscn**; Main se combina textualmente, pero eso no garantiza geometría/contratos. Solo se escriben objetos en el clon desechable: no se mueve ninguna rama ni se ejecuta un merge de integración.

En copia desechable de ART-01C se superponen **los cuatro archivos exactos de #61**. Importación y board input, lane integration, ART-01, ART-01B, ART-01C y restart pasan. Por tanto los cambios de legibilidad fallback siguen siendo compatibles y útiles. Las ramas originales no se alteran.

El test original de #62 contra esta composición falla al convertir `Content` a VBox: tres `SCRIPT ERROR: Cannot call method 'get_children' on a null value.`. Además imprime engañosamente `PASS: 0 checks` y devuelve 0. Nuestro driver considera el diagnóstico una **incompatibilidad esperada**, no un PASS de layout. Se conserva el log íntegro. Es un riesgo concreto de integrar el test original sin adaptar; debe rechazarse cualquier error de motor y exigir conteo positivo en la futura adaptación.

Los 2,005 checks de ART-01B conservan intención espacial, tamaño físico, safe area, dispatch táctil a 25 celdas, selección ortogonal, modales y reinicio. ART-01C añade lectura entera y fidelidad del estado con fixtures canónicas. Esto no equivale a ejecutar sin cambios el test original de #62.

## Orden propuesto, pendiente de aprobación de Jorge

1. Revisar y aprobar #61 de forma independiente. Cuando Jorge autorice integración, conservar sus commits en uat; volver a ejecutar CI sobre la combinación exacta, incluida presentación de #63.
2. Mantener #62 abierto/DRAFT mientras Jorge decide si su propuesta de layout queda sustituida por #63. Su funcionalidad espacial está cubierta; rescatar únicamente documentación/fila UI-MOBILE-01 y assertions válidas que no dupliquen el layout. Adaptar la prueba para APIs públicas, rects y mínimos en puntos; no copiar sus escenas ni límite <=64.
3. Tras decisión explícita de sustitución y aceptación visual/física de #63, autorizar una integración normal que conserve historial de #61 y #63. No rebase/squash/force push. Las pruebas se repiten sobre el candidato concreto antes de promoverlo.
4. El cierre de #62, si procede, lo decide Jorge con referencia a la cobertura y preservación de su historia; no es automático ni fue realizado.

No hay funcionalidad de gameplay exclusiva de #62 que falte. Los únicos deltas no cubiertos son trazabilidad UI-MOBILE-01 y la pertenencia de la prueba a core; sus assertions ligadas a VBox/64 no deben conservarse literalmente. La decisión de producto pendiente es **aprobar #63 como sustituto de la composición #62**; esta misión prepara evidencia, no ejecuta esa decisión.
