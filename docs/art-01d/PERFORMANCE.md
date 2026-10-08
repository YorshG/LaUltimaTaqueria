# ART-01D · rendimiento observado en escritorio

Godot 4.7.2 / Metal Forward Mobile / Apple M2. Cinco corridas secuenciales e intercaladas por referencia y estado, 30 procesos: uat `d46cc8c`, ART-01C `c283b33` y ART-01D (SHA final en entrega). Misma fixture canónica de siete corredores, mismos scripts copiados a exports Git inmutables. Ventana 540×960, proyecto vertical; 60 frames de calentamiento + 180 observados. Se mide Main, no toda App. Estado adicional seleccionado: cinco Tortillas con tres cambios de dirección.

[Datos completos](evidence/performance.json), [resumen calculado](evidence/performance-summary.json), logs `perf-*` y `selected-perf-*`. No procesos Godot concurrentes durante las medidas. Capturas fuerzan un frame antes de leer imagen; **el benchmark no fuerza frames**.

| Referencia / estado | Nodos | Recursos | Huérfanos | Draw calls | Memoria estática MiB mediana (mín–máx) |
|---|---:|---:|---:|---:|---:|
| uat | 72 | 22 | 0 | 59 | 39.502 (39.502–39.502) |
| art01c | 103 | 39 | 0 | 160 | 44.821 (44.821–44.821) |
| art01d | 103 | 39 | 0 | 171 | 45.496 (45.496–45.496) |
| uat-selected | 72 | 23 | 0 | 63 | 43.867 (43.867–43.867) |
| art01c-selected | 103 | 40 | 0 | 184 | 45.198 (45.198–45.198) |
| art01d-selected | 103 | 40 | 0 | 196 | 46.112 (46.112–46.112) |

## Incrementos explícitos

- Sin selección, D frente a art01c: nodos +0, recursos +0, draw calls +11 (+6.9%), memoria estática mediana +0.675 MiB (+1.5%).
- Sin selección, D frente a uat: nodos +31, recursos +17, draw calls +112 (+189.8%), memoria estática mediana +5.994 MiB (+15.2%).
- Con cinco seleccionados, D frente a art01c: nodos +0, recursos +0, draw calls +12 (+6.5%), memoria estática mediana +0.914 MiB (+2.0%).
- Con cinco seleccionados, D frente a uat: nodos +31, recursos +17, draw calls +133 (+211.1%), memoria estática mediana +2.245 MiB (+5.1%).

El delta incluye el rescate de tipografía/outline fallback de #61 y el dibujo de D. No se atribuye cada coste a una causa aislada sin un benchmark adicional. Counts antes/después estables y cero huérfanos en las 30 muestras; esto es una observación acotada, no prueba de ausencia de fugas prolongadas. La memoria reportada es MEMORY_STATIC del motor, no RSS total ni memoria de GPU ni pico de dispositivo.

| Referencia / estado | Mediana de p95 TIME_PROCESS (ms) | Mediana intervalo de frame (ms) | Mediana de p95 intervalo (ms) | Mayor intervalo observado (ms) |
|---|---:|---:|---:|---:|
| uat | 22.646 | 16.688 | 17.922 | 33.724 |
| art01c | 32.908 | 16.702 | 17.786 | 33.254 |
| art01d | 23.879 | 16.691 | 17.685 | 33.324 |
| uat-selected | 23.419 | 16.687 | 17.565 | 33.734 |
| art01c-selected | 20.910 | 16.684 | 17.798 | 33.026 |
| art01d-selected | 32.587 | 16.691 | 17.890 | 32.849 |

TIME_PROCESS se actualiza a la frecuencia del monitor, no entrega un perfil independiente de CPU por frame. Los intervalos incluyen scheduling/ventana/compositor de macOS; los outliers se conservan. No se eliminan corridas ni se convierte esta muestra en una afirmación de 60 FPS, mejora/regresión causal de tiempos o aceptación móvil. Draw calls/memoria aumentan frente a C/uat y deben evaluarse en hardware modesto.

La primera versión del contorno tenía conectores parcialmente tapados; sus cinco corridas por estado/referencia permanecen en `evidence/initial-fit/`. La tabla principal usa solo la versión final después de la corrección de orden de dibujo/inset. Un timeout durante capturas no forma parte del benchmark y queda registrado por separado en VALIDATION.

Pendiente: iPhone 17 y 16 Pro Max, frame/GPU, memoria residente/picos, carga, temperatura, batería y sesiones sostenidas con build/commit registrados. Sin presupuesto físico aprobado, estas cifras no cierran IOS-02 ni ART-01D.

## Diferencias observadas de tiempos (sin atribución causal)

- Sin selección, D frente a art01c: mediana de p95 TIME_PROCESS -9.029 ms; mediana de intervalo -0.011 ms; mediana de p95 intervalo -0.101 ms; máximo observado +0.070 ms.
- Sin selección, D frente a uat: mediana de p95 TIME_PROCESS +1.233 ms; mediana de intervalo +0.003 ms; mediana de p95 intervalo -0.237 ms; máximo observado -0.400 ms.
- Con cinco seleccionados, D frente a art01c: mediana de p95 TIME_PROCESS +11.677 ms; mediana de intervalo +0.007 ms; mediana de p95 intervalo +0.092 ms; máximo observado -0.177 ms.
- Con cinco seleccionados, D frente a uat: mediana de p95 TIME_PROCESS +9.168 ms; mediana de intervalo +0.004 ms; mediana de p95 intervalo +0.325 ms; máximo observado -0.885 ms.

Se reportan también los incrementos de tiempos; la actualización gruesa del monitor y el entorno desktop impiden inferir causalidad o FPS sostenidos.
