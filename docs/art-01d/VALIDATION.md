# ART-01D · validación para aceptación visual

Entrega técnica candidata del PR #63 **DRAFT**, sin merge. No representa aceptación de Xavier/Jorge ni de hardware. Head inicial auditado `c283b337dd5ccd7355ad554a58743ff972151d3b`. SHA final y checks remotos exactos en la entrega/descripción del PR; estos documentos no inventan resultados futuros de CI.

## Pruebas locales

Godot 4.7.2.stable.official.ed1daf0bf, macOS Apple M2, renderer gráfico Metal / Forward Mobile. Python estándar; sin dependencias nuevas.

| Verificación | Resultado verificable |
|---|---|
| Regresión completa | 17/17 etapas; [driver](evidence/regression-driver.log) |
| Core, incluido layout | 26/26 archivos; [core](evidence/core.log) |
| ART-01D | 4,094 checks, 0 fallos; 72 cadenas táctiles, 3 tamaños × 3 ingredientes × 2 bordes × longitudes 2–5; [log](evidence/art_01d_audit_test.log) |
| Rescate UI-MOBILE-01 | 18 checks, 0 fallos; [log](evidence/ui_mobile_layout_test.log) |
| Layout B / auditoría C / contrato ART | 2,005 / 693 / 276 checks, 0 fallos; [B](evidence/art_01b_layout_test.log), [C](evidence/art_01c_audit_test.log), [ART](evidence/art_01_visual_test.log) |
| Anti falso PASS | 6 checks; error de script + resumen positivo, cero checks y resumen ausente rechazados; [resumen](evidence/mobile-guard.log), [error real](evidence/guard-script-error-positive.log), [cero](evidence/guard-zero-checks.log) |
| Píxeles de cadena | 522 checks: 450 recortes de ingrediente idénticos + 72 conectores con contraste de luminancia >0.4 respecto al hueco vecino; [log](evidence/chain-pixels.log) |
| Píxeles a escala móvil sintética | 9/9 regiones de icono idénticas, tres ingredientes × tres alturas; color y gris; [log](evidence/pixels.log), [hoja](evidence/selection-mobile-pixels.png) |
| Reinicio y persistencia | Suite completa, recuperación, aislamiento y repetición PASS; [suite](evidence/restart-suite.log) |
| Mutaciones RST / VIS | 6/6 + 6/6 detectadas; [RST](evidence/restart-mutations.log), [VIS](evidence/vis-mutations.log) |
| VIS stress / lifetime | 189 checks, 100×12 corredores, lifetime válido; [log](evidence/vis_runner_retirement_test.log) |
| Bot de partida y variante restart | PASS, cinco oleadas, mejoras, jefe, victoria; [normal](evidence/m3_runtime_bot.log), [reinicios](evidence/runtime-restart.log) |
| Probe input | PASS sintético; [log](evidence/input-probe.log) |
| Alcance y #61 | Solo cuatro archivos runtime cambiados; cuatro archivos de #61 idénticos a su head; [auditoría](evidence/scope-audit.json) |

Los errores intencionales de las pruebas negativas se guardan en logs separados y **no se cuentan como suites aprobadas**: se comprueba el rechazo del proceso. La regresión permite únicamente el diagnóstico de JSON corrupto esperado por SAV-02. CI smoke/presentation ejecutan guards, conteos positivos y pruebas negativas; la evidencia de renderer gráfico es local.

Integridad final: **127 PNG**, 33 snapshots C/D idénticos y 123 logs positivos sin diagnósticos inesperados; [registro](evidence/integrity.json). Sintaxis Python y YAML válida; `git diff --check` limpio.

## Comparativas del mismo fixture

Cada PNG completo es 1080×H. Las hojas comparativas muestran C a la izquierda y D a la derecha a media escala. Las fixtures se congelan para capturar, no son partidas físicas. Toda selección usa el mismo BoardState preparado y los mismos datos en ambas referencias.

| H | Normal/sin selección | Giros | Gris | Hambre real <1 | Fracciones | Corredores/target | Safe area |
|---|---|---|---|---|---|---|---|
| 1620 | [sin](evidence/comparison-unselected-1620.png) / [cadena](evidence/comparison-regular-1620.png) | [5 ingredientes](evidence/comparison-turns-1620.png) | [C/D](evidence/comparison-turns-gray-1620.png) | [0.2](evidence/comparison-subunit-1620.png) | [30/70/18](evidence/comparison-fractional-1620.png) | [nueve](evidence/comparison-crowded-1620.png) | [límites](evidence/art01d-bounds-1620.png) |
| 1920 | [sin](evidence/comparison-unselected-1920.png) / [cadena](evidence/comparison-regular-1920.png) | [5 ingredientes](evidence/comparison-turns-1920.png) | [C/D](evidence/comparison-turns-gray-1920.png) | [0.2](evidence/comparison-subunit-1920.png) | [30/70/18](evidence/comparison-fractional-1920.png) | [nueve](evidence/comparison-crowded-1920.png) | [límites](evidence/art01d-bounds-1920.png) |
| 2400 | [sin](evidence/comparison-unselected-2400.png) / [cadena](evidence/comparison-regular-2400.png) | [5 ingredientes](evidence/comparison-turns-2400.png) | [C/D](evidence/comparison-turns-gray-2400.png) | [0.2](evidence/comparison-subunit-2400.png) | [30/70/18](evidence/comparison-fractional-2400.png) | [nueve](evidence/comparison-crowded-2400.png) | [límites](evidence/art01d-bounds-2400.png) |

Secuencias individuales: `art01c/d-chain-{2,3,4,5}-{1620,1920,2400}.png` y sus versiones `-gray.png`. Incluyen el tablero entero 5×5. TURNS = (0,0)→(1,0)→(1,1)→(2,1)→(2,2); los tests además recorren desde (4,4) hacia arriba/izquierda. No hay diagonal. La captura de cadena 2 es un gesto aún activo; al soltar se cancela según la regla existente.

Datos reales: Nibbler 30/speed55, Salsa Tank 70/speed30, Swift Hopper 18/speed90. Fraccional = 27.5, 67.625, 17.666… por `apply_satisfaction`; subunit = aproximadamente 0.2, 67.625, 17.5 por el mismo método. La primera muestra C `0/30`, D `1/30`. El valor exacto queda en cada log; barra conserva float. La suite C confronta target dibujado con servicio real de 1.375; fixture crowded tiene nueve corredores en progreso 0.46 y verifica empate real. [Manifest](evidence/fixture-manifest.json).

## Reproducción

Desde #63 con Python 3.9+, Godot 4.7.2 y objetos Git de C/uat disponibles:

```sh
godot --headless --path . --editor --quit
python3 tests/run_art_01d_regression.py
python3 tests/run_mobile_guard_test.py
python3 tests/run_restart_mutations.py
python3 tests/run_vis_retirement_checks.py
godot --headless --path . --script res://tests/m3_runtime_bot.gd -- 20 restart
python3 tests/run_art_01d_evidence.py
```

La última orden requiere renderer gráfico; soporta `--captures-only` / `--performance-only`. Capturas y métricas se ejecutan secuencialmente; `git archive` usa copias temporales, sin mover ramas. Las salidas nuevas van a ART-01D. Un intento sufrió timeout esperando frame del renderer, sin diagnóstico de script; se conserva en [capture-timeout.log](evidence/capture-timeout.log), no se cuenta como PASS. Los scripts de captura/comparativa/píxeles ahora llaman `RenderingServer.force_draw(false)` antes de leer la imagen para no depender de la exposición de la ventana nativa. El benchmark conserva el renderer normal, sin forzar sus frames. [Métricas y límites](PERFORMANCE.md), [cambios](CHANGES.md), [matriz](PR_MATRIX.md).

## Riesgos y pendientes

Bloqueantes de **aceptación/promoción**, no ocultados por CI: reauditoría de Xavier, revisión visual de Jorge, prueba física iPhone 17/iOS 27.0 y iPhone 16 Pro Max (registrar versión de iOS), y decisión de integración. Protocolo físico sigue [pendiente](../art-01c/PHYSICAL_PROTOCOL.md): pulgar, fila 5, safe area real, Home Indicator, touch+mouse, lectura y temperatura/rendimiento sostenido.

La integración completa de #62 está detenida por conflicto; el rescate selectivo está documentado y no resuelve/cierra su PR. Los assets siguen siendo proxies provisionales.

No bloqueantes técnicos observados: ceil puede mostrar el máximo antes de alcanzarlo internamente; es intencional y la barra conserva precisión. Números extremos fuera del catálogo siguen ajustándose horizontalmente. Incrementos de draw calls/memoria se reportan en PERFORMANCE, sin prometer presupuesto móvil. Doble touch/mouse real continúa pendiente de INP-01. Las medidas de escritorio no prueban 60 FPS, comodidad física ni accesibilidad clínica.
