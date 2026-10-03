# INP-01 — instrumento de diagnóstico aislado

Estado: preparado para iPhone; **INP-01 sigue pendiente**. Este PR no cambia `Main`, `BoardView`, `ChainPath`, `project.godot` ni settings persistentes. La escena sólo corre al abrirla explícitamente. No aplica deduplicación.

## Reproducción

Base: `uat` `61dfce343975eca377c778651234f940733a032a`. Validado con Godot `4.7.2.stable.official.ed1daf0bf`, macOS 27.0.1, headless para regresión. Seed de tablero `20260920`; no hay sesión de gameplay en el probe.

Desde la raíz de esta rama:

```sh
godot --headless --editor --import
GODOT_BIN=godot python3 tests/run_inp_probe_test.py
godot --path . res://tests/INPTouchProbe.tscn
```

El runner exige salida 0, marcador de éxito y ausencia de errores de script, parseo, llamadas, instancias liberadas, conexiones duplicadas o leaks. La prueba usa `--no-file`; no lee ni modifica SaveService.

La escena registra JSONL en `user://inp_probe/probe-<timestamp>-<ticks>.jsonl` y en consola con prefijo `INP_PROBE`. No guarda datos personales. `device` es el índice del evento de Godot, no un identificador físico. El decorator registra cada llamada real a `ChainPath.try_add`, delega al método original y devuelve su resultado intacto. Sólo sustituye `_chain` dentro de esta escena de prueba; esa dependencia privada queda cubierta por regresión.

Cada fila contiene tiempo monotónico en microsegundos, tipo, posición, pressed cuando corresponde, device, touch_index/button_mask, `gesture_probe_seq` y contadores. Los eventos de dominio añaden ingrediente y puntos; `try_add` añade aceptación/rechazo. Raw motions no tienen un booleano pressed propio: se conserva button_mask o su tipo ScreenDrag.

`gesture_probe_seq` agrupa presses de familias distintas cercanos (80 ms / 16 unidades de viewport). Es una **heurística de observabilidad**, no identifica un gesto físico. Puede agrupar dos dedos o gestos alternos rápidos. Conservar los eventos crudos y anotar manualmente el número de gesto observado; nunca deducir duplicación sólo del ID. No usar este logger para medir latencia/performance: imprimir, escribir y actualizar el texto añaden trabajo.

## Escenarios A/B

A usa el valor original de `Input.is_emulating_mouse_from_touch()` (observado `true`; touch desde mouse `false`). B desactiva mouse desde touch sólo en memoria mediante la casilla. Volver a A o salir de la escena restaura el valor original. No se modifica `ProjectSettings` ni la build principal.

Restablecer limpia cadena/tablero/contadores; preserva el escenario y forgiveness seleccionado. La casilla de fixture coloca dos filas de tortillas para repetir cadenas 3/4/5 y zig-zag sin depender del refill. Es contenido exclusivamente diagnóstico, etiquetado en el log; desactivarla vuelve al tablero productivo. La otra casilla permite probar margen 0.1, sin adquirir upgrades ni cambiar contenido productivo.

Pruebas automáticas: **62 checks**. Touch solo y mouse solo: 1 inicio / 1 final / 3 intentos; par forzado: 2 inicios / 1 final / 6 intentos (incluye intentos duplicados rechazados). El tablero final y señales son iguales con y sin decorator. También tap, cadenas 4/5, zig-zag, correlación negativa por distancia, A/B y geometría con contadores 10000. El par forzado no demuestra que iOS genere ambos eventos en producción.

## Build física aislada

1. Copiar el checkout a una carpeta experimental; registrar SHA, Godot, dispositivo e iOS exactos. No exportar esta escena como producto ni alterar ramas auditadas.
2. Sólo en la copia, fijar `application/run/main_scene` a `res://tests/INPTouchProbe.tscn`.
3. Usar un preset de diagnóstico con Team ID real local y bundle diagnóstico aprobado. Para esta build, no excluir `tests/INPTouchProbe.tscn`, `tests/inp_touch_probe.gd` ni `tests/inp_probe_chain.gd`. Es posible usar export de recursos seleccionados con la escena como raíz y sus dependencias.
4. Exportar con templates oficiales de la misma versión, compilar/instalar desde Xcode y guardar la consola filtrada por `INP_PROBE`. Alternativa: descargar el contenedor de la aplicación de prueba desde Xcode y recuperar únicamente `inp_probe/*.jsonl`.
5. Comparar A/B en el mismo dispositivo y fixture, repitiendo cada gesto 5 veces. Restaurar tablero entre intentos. Anotar cualquier pérdida de release, doble inicio o diferencia lógica.

Matriz física: tap; drag de 3, 4 y 5; borde con forgiveness 0/0.1; zig-zag ortogonal; salir/reentrar tablero; toque rápido/largo; drag lento/rápido. Por intento registrar manual gesture number, escenario, ScreenTouch press/release, ScreenDrag, MouseButton press/release, MouseMotion, chain_started, try_add, chain_completed, ingrediente/puntos y observación. Para tap inválido se espera 1 inicio / 0 finales válidos / cancelación; para cadena válida, 1 inicio / 1 final. Una ausencia de eventos en el probe requiere revisar también si el gesto entró en el tablero.

No cerrar INP-01 ni elegir una política de dedupe hasta obtener esa evidencia en iPhone físico. No confundir el probe aislado con aceptación integral del input dentro de App/pausas/upgrades.
