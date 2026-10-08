# Protocolo físico reproducible — pendiente, sin resultados inventados

No se conectó hardware en ART-01C. Responsables: Jorge (iPhone 17), segundo evaluador (iPhone 16 Pro Max), Xavier (auditoría). Registrar SHA/build, Godot 4.7.2/export templates, Xcode, modelo, iOS exacto, escala/pantalla/texto, brillo, batería, modo energía, temperatura ambiente y estado térmico inicial. iOS 27.0 es la referencia documental de iPhone 17; confirmar versión instalada. Versión de 16 Pro Max pendiente.

## Preparación y equivalencia

Instalar build identificada de uat `d46cc8c` y candidato ART-01C, con misma configuración de exportación, resolución, renderer y modo Release. Comparar cada referencia tras enfriamiento hasta estado térmico inicial equivalente. Usar la fixture canónica documentada (semilla 20260920, progresos 0.28/0.46/0.68; escenario de nueve clientes) en build de diagnóstico claramente marcada, más partidas reales con audio normal. No mezclar screenshots de fixture y partida. Registrar cualquier diferencia de OS o instrumentos.

Realizar tres sesiones de 15 minutos por referencia/dispositivo; alternar orden uat/candidato entre sesiones. Tras 2 minutos de warmup, muestrear 10 minutos continuos y conservar datos crudos. Añadir una sesión de 30 minutos por candidato para calentamiento/deriva y 10 reinicios consecutivos en oleada, mejora, jefe y terminal. Anotar tiempos de instalación/carga por separado.

## Safe area, controles y gesto

1. Capturar rect de pantalla, safe area real de DisplayServer, `screen_get_scale`, `get_screen_transform`, rect seguro proyectado y geometrías del HUD, Reiniciar, 25 celdas, modales y Home Indicator. Adjuntar screenshot y grabación identificados por dispositivo/build. Medir pt usando la transformación efectiva; no dividir ciegamente los píxeles del PNG.
2. En vertical, abrir/cancelar/confirmar Reiniciar 10 veces; repetir «Nueva partida» terminal y selector de mejoras. Ningún control debe quedar bajo Dynamic Island/notch/Home Indicator; sesión única y cancelación intacta. Registrar el menor tamaño táctil observado (objetivo >=44 pt).
3. Arrastrar por las cinco celdas de fila 5 y las cuatro esquinas: 20 gestos válidos por perfil, inicio/fin cerca del borde inferior. Alternar pulgar derecho, izquierdo y ambas manos. Registrar cadenas completadas/canceladas, duplicaciones touch/mouse, activaciones del sistema y reinicios accidentales. Incluir diagonales inválidas, levantar/reanudar y arrastre cerca de márgenes.
4. Repetir tras pausa/reanudación y mostrar/ocultar UI del sistema si cambia el rect. Registrar entradas reales de safe area y cualquier incumplimiento; no sustituir por la máscara sintética 177/102.

## Lectura y comprensión

Mostrar fixture regular y nueve clientes durante 5 segundos cada una, sin explicar símbolos. Pedir identificar Tortilla/Carne/Verdura seleccionadas, hambre restante y objetivo próximo. Repetir en escala de grises del dispositivo, luz ambiente normal y brillo fijado. Registrar aciertos/tiempo y comentarios textuales, no inferir comodidad de pruebas automáticas. Revisar el redondeo: 27.5 → 28/30, 67.625 → 68/70, 17.666… → 18/18; un remanente <0.5 muestra 0 y conserva barra/target real. Validar que no confunda con satisfacción terminada. Registrar si los números agrupados de al menos 8 pt se leen cómodamente.

## Rendimiento y temperatura

Con instrumentos disponibles de Xcode (Time Profiler, Allocations/Memory y Metal/frame capture) y monitores Godot, registrar memoria residente/peak, memoria estática como métrica separada, draw calls, nodos/recursos/huérfanos, CPU/GPU si disponibles, FPS y tiempos por frame. Reportar mediana/p95/p99/máximo, frames >16.67/33.33/50 ms y pérdidas/jank; conservar traza temporal, no solo promedios. Si la pantalla adapta frecuencia, registrar la efectiva y separar las condiciones.

Registrar estado térmico del sistema y temperatura superficial medida (instrumento/punto) al inicio y cada 5 minutos; si no hay termómetro, marcar temperatura superficial «no medida». Anotar batería al inicio/final, carga conectada y throttling observado. Interrumpir ante advertencia térmica del sistema, bloqueo o pérdida de datos; documentar el evento.

## Hoja de resultados (llenar por corrida)

| Campo | Resultado |
|---|---|
| Dispositivo / iOS / build SHA / operador / fecha | Pendiente |
| Baseline y candidato / orden / warmup / duración | Pendiente |
| Safe area real / escala / transformación / mínimo pt | Pendiente |
| Reinicios / sesiones activas / fugas | Pendiente |
| Gestos fila 5 por mano: correctos / fallos / duplicados | Pendiente |
| Lectura normal/gris: aciertos / tiempos / citas | Pendiente |
| FPS / frame ms mediana, p95, p99, máximo / frecuencia pantalla | Pendiente |
| Memoria residente / peak / estática / deriva / huérfanos | Pendiente |
| Temperatura / estado térmico / batería / jank | Pendiente |
| Archivos crudos / capturas / incidencias | Pendiente |
| Veredicto del evaluador / auditoría Xavier / decisión Jorge | Pendiente |

Criterios: rects seguros, gestos y lifecycle correctos, lectura comprendida en ambas manos, sin deriva no explicada y rendimiento evaluado contra uat con condiciones comparables. El objetivo de 60 FPS no se declara alcanzado con desktop ni con medias que oculten jank. Jorge decide aceptación visual y de rendimiento tras estos resultados.
