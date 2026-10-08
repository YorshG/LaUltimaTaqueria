# Rendimiento desktop contra uat — observación limitada

Godot 4.7.2 (`ed1daf0bf`), macOS, Apple M2, Metal 4.0 / Forward Mobile. uat `d46cc8c`, ART-01B `5e4bc11` y candidato ART-01C. El benchmark se ejecuta con exactamente el mismo script `art_01c_performance.gd` y fixture desde datos validados en las tres referencias.

## Método

Cinco corridas por referencia (15 total), intercaladas uat → B → C durante cada ronda, procesos separados y secuenciales. Ventana solicitada 540×960, mismo proyecto/renderer/viewport base 1080×1920; Main standalone, auto_start=false, audio desactivado, siete clientes con hambre/velocidad canónica, sin avance automático, progreso 0.15 + índice×0.10. Sin cadena seleccionada. 60 frames de calentamiento + 180 observaciones por corrida (900 observaciones por referencia). No se ejecutan suites ni capturas durante las mediciones. Se conservaron todas las corridas y outliers. No se midió GPU/temperatura ni se aisló toda actividad del sistema.

`TIME_PROCESS` es un monitor periódico leído por frame; las 180 observaciones no son muestras independientes de latencia. Adicionalmente se toman intervalos monotónicos entre callbacks process_frame, afectados por sincronización/compositor; tampoco son tiempo GPU ni presentación efectiva. Memoria estática Godot se separa de RSS y no prueba ausencia de fugas. Counts antes/después cubren una ventana corta.

## Conteos y memoria

| Referencia | Draw calls (min–max) | Memoria estática MiB (min–max) | Nodos / recursos / huérfanos |
|---|---:|---:|---|
| uat | 59–59 | 39.501–39.501 | 72 / 22 / 0 |
| art01b | 160–160 | 44.554–44.554 | 103 / 39 / 0 |
| art01c | 160–160 | 44.820–44.820 | 103 / 39 / 0 |

ART-01C conserva **160 vs 59 draw calls**: +101, +171.2% frente a uat, sin mejora respecto a B en esta fixture. Memoria **+5.319 MiB vs uat**, +0.266 MiB vs B. Conteos idénticos entre warmup/final en todas las corridas; cero huérfanos observados. No se afirma ausencia de regresión.

## Todas las corridas

| Referencia / ronda | TIME_PROCESS mediana / p95 ms | Intervalo de frame mediana / p95 / máximo ms |
|---|---:|---:|
| uat / 1 | 25.871 / 25.871 | 8.146 / 10.212 / 25.335 |
| art01b / 1 | 11.975 / 11.975 | 8.254 / 9.417 / 10.819 |
| art01c / 1 | 9.799 / 9.799 | 8.345 / 9.289 / 10.237 |
| uat / 2 | 25.219 / 25.220 | 8.231 / 9.358 / 26.496 |
| art01b / 2 | 11.450 / 11.450 | 8.308 / 9.289 / 9.731 |
| art01c / 2 | 10.424 / 10.424 | 8.466 / 9.169 / 10.311 |
| uat / 3 | 9.142 / 25.158 | 8.245 / 9.366 / 25.306 |
| art01b / 3 | 12.383 / 12.383 | 8.389 / 9.328 / 10.494 |
| art01c / 3 | 19.054 / 19.054 | 8.387 / 9.467 / 10.538 |
| uat / 4 | 9.252 / 24.314 | 8.154 / 9.547 / 25.641 |
| art01b / 4 | 34.069 / 34.069 | 8.304 / 9.379 / 11.111 |
| art01c / 4 | 10.621 / 10.720 | 8.255 / 9.270 / 11.169 |
| uat / 5 | 9.433 / 9.433 | 8.099 / 9.262 / 9.584 |
| art01b / 5 | 11.564 / 11.564 | 8.404 / 9.177 / 9.873 |
| art01c / 5 | 11.961 / 11.961 | 8.256 / 9.437 / 9.799 |

## Variabilidad entre corridas

| Referencia | Mediana de las medianas TIME_PROCESS ms | Rango medianas / rango p95 ms | Rango p95 intervalos ms |
|---|---:|---:|---:|
| uat | 9.433 | 9.142–25.871 / 9.433–25.871 | 9.262–10.212 |
| art01b | 11.975 | 11.450–34.069 / 11.450–34.069 | 9.177–9.417 |
| art01c | 10.621 | 9.799–19.054 / 9.799–19.054 | 9.169–9.467 |

## Intento inicial y comparabilidad histórica

El primer ajuste probaba tamaños 32,31,…24 por etiqueta y creaba cachés tipográficos intermedios. Se conservan sus cinco corridas por referencia en [initial-fit/performance.json](evidence/initial-fit/performance.json): C 45.498 MiB, B 44.554, uat 39.502. La entrega calcula directamente el tamaño proporcional y mide solo el elegido, evitando ese recorrido. Las mediciones finales están en [performance.json](evidence/performance.json); el intento previo no se mezcla con la muestra final ni se ocultan sus outliers.

Los 59/160 draw calls reproducen la referencia histórica con el benchmark nuevo. La fixture histórica usaba hambre 70/speed55 para todas las especies y no fijaba explícitamente ventana; esta usa stats canónicos y agrega una dependencia de test, por eso cuenta un recurso adicional. Los tiempos históricos de B no son muestras equivalentes y no se mezclan ni se usan como prueba causal de mejora. Los PNG agrupados/cadena activa y App con safe area no se perfilan en esta fixture de Main; el protocolo físico debe incluirlos.

No se deduce 60 FPS físicos de intervalos desktop de unos 8.1–8.5 ms en la muestra final ni se afirma rendimiento mejorado por reducir cachés. Se requiere [protocolo físico](PHYSICAL_PROTOCOL.md): GPU, memoria residente, temperaturas, frame pacing y sesiones prolongadas en ambos iPhone. No hay resultados físicos en esta misión.

La primera serie mostró medianas de intervalo cercanas a 16.7 ms y la final ~8.3 ms, aun con idéntico comando/configuración. No se registró la frecuencia efectiva del compositor/monitor ni se aisló la causa de ese cambio; las series se mantienen separadas. No se atribuye causalmente esa diferencia de tiempo a la corrección tipográfica. La variabilidad publicada es entre agregados de cinco procesos; los logs guardan agregados por corrida, no una traza completa de cada frame.
