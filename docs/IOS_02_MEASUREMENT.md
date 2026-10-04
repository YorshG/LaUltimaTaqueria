# IOS-02 — medición de rendimiento y memoria

Fecha de apertura: 2026-10-03. Baseline de integración al iniciar este frente:
`uat = d46cc8cdebb363a7791da8417d78870da3e676d1`.
`main = a6d88f4c4715a64614ddf3e0a220e76d65304339` permanece fuera de alcance.

IOS-02 **no queda cerrado** con este documento ni con el preflight desktop.
Su aceptación sigue requiriendo medición sobre iPhone físico después de IOS-01:
frame, memoria, carga y estado térmico en iPhone 17, más smoke en iPhone 16 Pro Max,
siempre registrando build/commit.

## Por qué existe un preflight antes del iPhone

La investigación privada previa aisló un comportamiento que no debe confundirse con
una regresión de RST-01:

- Memory Lab: 12 clases, 39 configuraciones, 51 ejecuciones y 420.000 ciclos.
- En headless, `Control` y cinco derivadas crecieron +488.016 B de
  `Performance.MEMORY_STATIC` entre 100 y 10.000 ciclos.
- `Node`, `Node2D` y audio cambiaron ~+16 B; un `SubViewport` idle ~+28 B.
- En 20.000 ciclos, el patrón headless mostró una meseta intermedia y luego
  +979.296 B respecto del ciclo 100.
- Los conteos de nodos/objetos/recursos permanecieron estables y no aparecieron
  nodos huérfanos en los escenarios relevantes.
- El mismo experimento de `Control` a 10.000 ciclos dio 0 B de delta con
  Metal/Mobile en macOS y +16 B con Compatibility, mientras headless mostró
  +488.016 B.
- Renderer, display y cadencia no se aislaron en un factorial completo; por eso
  **no se atribuye causalidad exclusiva** al renderer ni se etiqueta el patrón
  como leak confirmado del motor.
- Geometría, texto/theme/font, accesibilidad, focus/mouse y variantes de
  `free`/`queue_free`/delay por frame no eliminaron el crecimiento headless.

Conclusión conservadora: el riesgo físico iOS sigue abierto. No se justifica
pooling ni un cambio de producto sin evidencia en dispositivo.

## Preflight durable en el repositorio

`tests/ios_02_memory_probe.gd` reemplaza una sesión App/Main completa repetidamente
con gameplay automático desactivado. Por defecto registra 1.000 reinicios, con
100 ciclos de calentamiento y una muestra cada 100 ciclos.

Comando reproducible:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/ios_02_memory_probe.gd -- 1000 100 100
```

Cada muestra imprime `IOS02_SAMPLE=<json>` con:

- `MEMORY_STATIC` y tamaño máximo del message buffer;
- conteo de objetos, recursos, nodos y nodos huérfanos;
- tiempo de proceso de frame;
- delta de memoria frente a la muestra post-warmup.

El probe **falla** si después del warmup deriva cualquiera de estos conteos
estructurales: objetos, recursos, nodos u huérfanos. El delta de
`MEMORY_STATIC` se registra pero **no decide PASS/FAIL**.

Razón: Godot documenta que `MEMORY_STATIC` no está disponible en builds release
y que algunos monitores no actualizan en tiempo real. Es útil como evidencia
debug comparable, no como sustituto del footprint físico de iOS.

Referencia:
https://docs.godotengine.org/en/4.7/classes/class_performance.html

El workflow `.github/workflows/ios-02-memory-preflight.yml` conserva el log como
artifact y también rechaza parser/runtime errors y mensajes de leak del motor.


### Resultado CI inicial del preflight

PR run `37175345547` sobre el primer head del PR #60: **SUCCESS**.

Muestras relevantes del probe de 1.000 reinicios:

| Ciclo | MEMORY_STATIC | Delta vs ciclo 100 | Objetos | Recursos | Nodos | Huérfanos |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 30.287.497 B | 0 B | 1.713 | 29 | 74 | 0 |
| 400 | 31.026.565 B | +739.068 B | 1.713 | 29 | 74 | 0 |
| 700 | 32.009.765 B | +1.722.268 B | 1.713 | 29 | 74 | 0 |
| 1.000 | 32.009.769 B | +1.722.272 B | 1.713 | 29 | 74 | 0 |

El crecimiento ocurrió por escalones mientras los cuatro conteos estructurales
permanecieron exactamente estables. Este resultado **no prueba leak de producto** y
tampoco invalida el riesgo: reproduce en otro host headless el patrón que motivó
IOS-02. La decisión queda deliberadamente pendiente de Instruments en dispositivo.

## Fuente de verdad para memoria iOS

La aceptación física usará herramientas de Apple:

1. Xcode Memory Report para memoria actual y máximo observado.
2. Instruments **Game Memory** / **Allocations** para heap, VM y generaciones.
3. VM Tracker para footprint/resident/dirty memory.
4. Metal Resource Events cuando sea necesario separar recursos de GPU.

Apple recomienda Allocations y generaciones para aislar las asignaciones creadas
durante una interacción concreta, y advierte que simulator/macOS no sustituye
los límites reales de memoria de iOS.

Referencias:
- https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use
- https://developer.apple.com/documentation/xcode/analyzing-the-memory-usage-of-your-metal-app

## Fuente de verdad para frame/carga/térmica

Usar Instruments **Game Performance** sobre el dispositivo. El template incluye
Display/vsync, GPU, CPU/system load y Thermal State.

Referencia:
https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/

Para “temperatura” no se inventarán grados Celsius: la API pública de Apple
expone estado térmico del sistema (`nominal`, `fair`, `serious`, `critical`).
IOS-02 registrará ese estado/track térmico.

Referencia:
https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum

## Dispositivo principal disponible

Jorge confirmó que su **iPhone 17** está disponible como dispositivo principal para
IOS-01/IOS-02. Por tanto, no es necesario esperar al iPhone 16 Pro Max de Xavier
para iniciar la validación física; ese segundo dispositivo queda como smoke
secundario.

Antes de exportar, ejecutar en la Mac de Jorge:

```sh
bash scripts/ios_readiness_check.sh
```

El script está diseñado para imprimir solo versiones, presencia de template,
conteo de identidades válidas y disponibilidad/versiones iOS de dispositivos
físicos. No imprime UDID, Team ID, certificados ni perfiles.

Godot 4.7 requiere macOS + Xcode, templates de exportación y un preset iOS con
App Store Team ID y Bundle Identifier no vacíos para generar el proyecto Xcode.
El preset debe crearse/configurarse localmente con valores reales; no se
inventarán ni se publicarán credenciales.

Referencia oficial:
https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html

## Protocolo físico — iPhone 17 (principal)

### A. Identidad de build

Registrar antes de medir:

- commit exacto de `uat`;
- identificador/version de build exportada;
- Godot y Xcode;
- modelo del dispositivo y versión iOS;
- renderer efectivo;
- fecha/hora local;
- Low Power Mode on/off;
- batería aproximada y si está conectado a energía.

No mezclar mediciones de commits distintos en una misma tabla.

### B. Arranque/carga

Hacer 5 cold launches independientes desde app terminada.

Registrar por intento:

- tiempo hasta primera UI interactiva;
- crash/diagnóstico si existe;
- memoria al quedar interactiva;
- estado térmico inicial.

Reportar mediana, mínimo y máximo. No usar un único arranque como conclusión.

### C. Gameplay sostenido

Capturar una sesión con Instruments Game Performance durante al menos una partida
completa de M3 y un reinicio.

Registrar:

- frame/display time y FPS observado;
- hitches/vsync perdidos relevantes;
- CPU/system load;
- GPU cuando esté disponible;
- estado térmico inicial, pico y final;
- memoria inicial, pico y final.

No ajustar balance para “mejorar” la medición.

### D. Experimento de memoria de reinicio

Con build debug/profilable y Instruments:

1. lanzar y dejar estabilizar;
2. marcar generación G0;
3. ejecutar 20 reinicios completos;
4. marcar G1;
5. ejecutar otros 20 reinicios completos;
6. marcar G2;
7. dejar la app idle 60 s sin cambiar pantalla;
8. marcar G3.

Para G0–G3 registrar:

- Memory Report / footprint;
- All Heap & Anonymous VM;
- resident/dirty memory en VM Tracker;
- allocations persistentes por generación;
- recursos Metal relevantes;
- warnings de memoria, termination o diagnóstico;
- estado térmico.

Interpretación:

- una subida aislada no prueba leak;
- crecimiento retenido que continúa por lote y no se estabiliza tras idle requiere
  atribución antes de aprobar IOS-02;
- warning/termination por memoria es bloqueante;
- objetos/nodos/listeners residuales atribuibles al juego son bloqueantes;
- caches o asignaciones del engine solo se clasifican después de evidencia de
  stack/categoría en Instruments.

### E. Smoke de funcionalidad

En la misma build verificar como mínimo:

- arranque;
- una partida completa;
- una elección de mejora;
- jefe;
- terminal;
- reinicio;
- contenido JSON cargado correctamente;
- ausencia de crash y errores visibles.

## Smoke — iPhone 16 Pro Max

Usar exactamente el mismo commit/build cuando sea posible.

Mínimo:

- cold launch;
- una partida completa;
- reinicio;
- captura corta de Game Performance;
- memoria inicial/pico/final;
- thermal state inicial/final.

Este smoke no sustituye la medición principal del iPhone 17.

## INP-01 se mantiene separado

IOS-02 puede compartir la misma build física con INP-01, pero no mezclar
conclusiones. El probe INP ya integrado solo demuestra sensibilidad sintética;
la decisión touch+mouse requiere hardware.

En el dispositivo registrar tap, cadena válida, cancelación y gesto tras restart,
con un solo `chain_started` por gesto aceptado y una sola finalización por cadena
válida. Solo con evidencia física se decidirá entre desactivar
`emulate_mouse_from_touch` o deduplicar runtime.

## Formato de resultados

Conservar una tabla por dispositivo:

| Campo | Resultado |
|---|---|
| Commit/build | |
| Dispositivo / iOS | |
| Godot / Xcode | |
| Renderer | |
| Cold launch mediana/min/max | |
| FPS / frame time | |
| CPU/system load | |
| Memoria inicial/pico/final | |
| Reinicios G0/G1/G2/G3 | |
| Thermal inicial/pico/final | |
| Warnings/crash | |
| Resultado smoke | |
| INP-01 relacionado | separado |

Nombrar trazas con fecha, commit, dispositivo y herramienta, por ejemplo:

`20261003-d46cc8c-iPhone17-GameMemory-restarts.trace`

## Criterio para avanzar a main

No promover M3 a `main` por resultados desktop únicamente.

Antes de promoción deben existir:

- IOS-01: build firmada que instala y abre;
- IOS-02: mediciones físicas completas y atribuibles;
- INP-01: evidencia touch/mouse en hardware y decisión explícita;
- cualquier bloqueante físico corregido y reauditado.
