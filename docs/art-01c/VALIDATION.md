# ART-01C — evidencia para reauditoría

Entrega técnica de correcciones del PR #63, DRAFT → uat. No constituye aceptación visual/física ni aprobación de integración. Inicio `5e4bc11dd2c68a2b7563437e8cdeb98d39a97dc3`. La descripción del PR identifica el SHA final y sus checks remotos.

## Cuatro defectos corregidos

| Defecto | Cambio acotado | Evidencia |
|---|---|---|
| Ingredientes teñidos al seleccionar | BoardVisual neutraliza modulación del Button tras señal de cadena y dibuja doble contorno/orden independiente; retira línea sobre el sprite | 9 regiones de iconos idénticas byte a byte, tres ingredientes × tres alturas; [píxeles](evidence/pixels.log), [hoja móvil](evidence/selection-mobile-pixels.png) |
| Hambre fraccionaria en dos filas | Entero más cercano en una sola cadena `actual/máximo`, ajuste por ancho; barra conserva float exacto | 27.5/30 → 28/30, 67.625/70 → 68/70, 17.666…/18 → 18/18; stress 123456789.375 / 987654321.75. Test conserva precisión tras servicio de 1.375 |
| Texto técnico visible | `Carril n · Hambre`; estado provisional conservado en catálogo/código/docs | Capturas y assert de catálogo/Labels sin «provisional»/debug |
| Capturas con 70 de hambre para todo | Fixture compartida por capturas, pruebas y benchmark, desde ContentRegistry/monsters.json | Nibbler 30/speed55, Salsa Tank 70/speed30, Swift Hopper 18/speed90; [manifest](evidence/fixture-manifest.json), logs con snapshot |

El layout ART-01B y sus tamaños/hitboxes se conservan. Ningún script de modelo, balance, targeting, sesión, input, guardado o escenas se modifica. No se añade dependencia.

## Capturas

Todas son fixtures congeladas, no partidas jugadas. Las comparativas nuevas usan la **misma fixture canónica** sobre el SHA inmutable de ART-01B y ART-01C; no se comparan 70/70 contra valores distintos. PNG completos de 1080×1620, 1080×1920 y 1080×2400, más hojas comparativas a media escala para revisión.

| Proporción | Regular: datos reales y selección antes/después | Hambre fraccionaria | Nueve coincidentes | Safe area sintética |
|---|---|---|---|---|
| 1080×1620 | [comparativa](evidence/comparison-regular-1620.png) | [comparativa](evidence/comparison-fractional-1620.png) | [comparativa](evidence/comparison-crowded-1620.png) | [límites](evidence/art01c-bounds-1620.png) |
| 1080×1920 | [comparativa](evidence/comparison-regular-1920.png) | [comparativa](evidence/comparison-fractional-1920.png) | [comparativa](evidence/comparison-crowded-1920.png) | [límites](evidence/art01c-bounds-1920.png) |
| 1080×2400 | [comparativa](evidence/comparison-regular-2400.png) | [comparativa](evidence/comparison-fractional-2400.png) | [comparativa](evidence/comparison-crowded-2400.png) | [límites](evidence/art01c-bounds-2400.png) |

También se conservan `art01b/c-unselected-H.png` para comparar selección con el mismo frame sin seleccionar. En la hoja móvil: columnas color sin seleccionar/con selección, gris sin seleccionar/con selección; filas Tortilla/Carne/Verdura para cada altura. Se muestran a **45/56/64 px**, equivalentes sintéticos de escala 3 para el rect seguro de capturas. Los 44 pt de aceptación se verifican con transformación efectiva por la suite B; su safe area lateral más estrecha produce mínimos ligeramente distintos. El cambio en luminancia del borde sigue distinguible; no se afirma validación clínica de accesibilidad ni comodidad física.

Semilla de tablero 20260920; progresos regulares 0.28/0.46/0.68. Agrupada: tres de cada especie, tres por carril, todos en 0.46. Fracciones aplicadas por `apply_satisfaction`: 2.5, 2.375, 1/3. Cada captura imprime los floats originales y parámetros. En el empate agrupado gana el primer spawn elegible del centro; la prueba confronta el selector dibujado con el retorno del servicio real. Capturas realizadas con viewport gráfico real de Godot, sin reconstrucción de UI.

## Resultados locales

Godot **4.7.2.stable.official.ed1daf0bf**, macOS/Apple M2. Driver de regresión: **15/15 etapas PASS**, incluyendo core de **23/23 archivos**. Se rechazan errores de motor/fugas aunque exit code sea 0; SAV-02 permite únicamente el error de JSON corrupto intencional de sus fixtures.

| Verificación | Resultado |
|---|---|
| Importación | PASS sin diagnóstico inesperado fuera del sandbox |
| ART-01C específica | **693 checks, 0 fallos**, tres alturas × regular/fraccional/coincidente |
| ART-01B layout/safe area/input/modal/reinicio | **2,005 checks, 0 fallos** |
| ART-01 contrato de presentación | **276 checks, 0 fallos** |
| Core: 5×5, ortogonales, mouse/touch, targeting, carriles, recetas, oleadas, mejoras | **23/23 PASS** |
| Jefe, reputación/HUD, feedback, guardado/recuperación | PASS |
| Reinicio y persistencia entre procesos | PASS; suite repetida y metadata aislada |
| RST mutations | **6/6 mutantes detectados**; 40 reinicios/20 cancelaciones, sentinel sin cambios |
| VIS / lifetime / stress | **189 checks**; 100×12 stress; **6/6 mutantes detectados** |
| Runtime bot, variante reinicio | PASS; time_scale 20 y variante de reinicios |
| INP probe sintético | PASS; no equivale a touch físico |
| #61 exacto sobre ART-01C | Import + seis scripts PASS, incluidas assertions originales |
| #62 test original | **INCOMPATIBLE esperado**: cast VBox nulo, tres errores; «PASS: 0 checks» no se acepta |
| Color/desaturación móvil | **9/9 iconos idénticos**, contorno distinguible, cero errores de renderer |
| Capturas | **30 PNG completos + 9 comparativas + 1 hoja móvil**; tres proporciones |
| Rendimiento | Cinco corridas por referencia uat/B/C, secuenciales; [datos y límites](PERFORMANCE.md) |

El primer import restringido produjo errores de certificados/ajustes del editor del sandbox; se conserva como `import-sandbox-diagnostic.log`, no se cuenta como PASS. Se repitió con acceso normal al entorno y las verificaciones finales quedan en `import.log`. La primera generación de hoja móvil encontró formatos RGB/RGBA distintos: se corrigió conversión explícita y se regeneró; el driver final rechaza los errores de renderer.

## Reproducción

Desde checkout de #63, con los SHA de #61/#62/uat/B disponibles como objetos Git, Godot 4.7.2 y Python 3.9+:

```sh
godot --headless --path . --editor --quit
GODOT_BIN=godot python3 tests/run_art_01c_regression.py
GODOT_BIN=godot python3 tests/run_art_01c_compatibility.py
GODOT_BIN=godot python3 tests/run_restart_mutations.py
GODOT_BIN=godot python3 tests/run_vis_retirement_checks.py
godot --headless --path . --script res://tests/m3_runtime_bot.gd -- 20 restart
GODOT_BIN=godot python3 tests/run_art_01c_evidence.py
```

Evidencia requiere renderer gráfico. El driver usa `git archive` y copias temporales, no checkout/merge de ramas; soporta `--captures-only` y `--performance-only`. Todas las salidas nuevas se guardan en ART-01C; no reescribe evidencia histórica ART-01/B. CI presentation ejecuta el nuevo test con guard de errores y conteo positivo, junto con A/B. El test de píxeles es local gráfico; no se presenta como check headless de CI.

## Pendientes

[Reauditoría Xavier](HANDOFF_XAVIER.md), aceptación visual de Jorge, [protocolo físico](PHYSICAL_PROTOCOL.md) y decisión sobre [orden de integración](PR_MATRIX.md). No se conectó iPhone; no se afirma 60 FPS ni ausencia de regresión. Runners y arte siguen siendo proxies. Números fuera del catálogo se ajustan horizontalmente para evitar desbordes; no se promete legibilidad de longitudes arbitrarias. Redondeo puede mostrar 0 o máximo mientras el float difiere: la barra y elegibilidad siguen siendo reales y su comprensión requiere revisión física.
