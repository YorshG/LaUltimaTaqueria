# VIS-01 — Retirar runners resueltos

Auditoría y validación local del 2026-10-03, Godot `4.7.2.stable.official.ed1daf0bf` en Apple M2. Base independiente: `61dfce343975eca377c778651234f940733a032a` (`uat`). No cambia archivos de RST-01 / #55 ni archivos productivos de RUN-01 / #56.

## Causa y ownership

`MonsterState` marca al satisfecho como `active=false`; `LaneRunner.advance()` hace lo mismo al llegar al mostrador. Eso impide targeting/movimiento, pero no cambia `Control.visible`. `LaneField` conserva tanto el child bajo `Lane0/1/2` como su referencia en `_runners`. No existe pooling ni otro cleanup al finalizar wave o boss. `WaveDirector._spawned_runners` conserva referencias y usa sus claves como conteo histórico de spawns de la wave: borrar esas claves cambiaría D3 y los contadores.

La reproducción previa resolvió dos runners aislados (satisfacción y breach), cinco waves reales con sus cinco selecciones y el boss. Tras dos frames quedaron 28 runners: 0 activos, 28 visibles y 28 en `_runners`. Los totales acumulados después de cada wave fueron 6, 10, 15, 20 y 27; incluyen los dos probes iniciales. No se infirió el fallo únicamente de la imagen.

| Estado al retornar la resolución | Antes | Después |
| --- | --- | --- |
| Satisfecho / boss: active, hunger, satisfied | false, 0, true | false, 0, true |
| Breach: active, hunger, satisfied | false, 30, false | false, 30, false |
| visible / is_visible_in_tree | true / true | false / false |
| process_mode | INHERIT (0) | DISABLED (4) |
| parent / ownership inmediato | Lane correspondiente / true | Lane correspondiente / true |
| queued_for_deletion | false | true |
| Nodes / ownership tras dos frames | retenidos | 0 / 0 |

`resolved` continúa siendo el resultado lógico contabilizado por WaveDirector, no un estado visual adicional. En la prueba D7 de dos spawns se conservan exactamente 2 spawned, 2 resolved, 0 pending y una sola finalización después de eliminar los nodos.

## Cambio acotado

`LaneField` retira solo los targets de la resolución actual, después de `dish_served`, satisfacción primaria y satisfacción secundaria de D7; en breach, después de `monster_reached_counter`. Los listeners síncronos reciben los mismos payloads y pueden leer ambos runners vivos, visibles y sin eliminación encolada. Un servicio anidado no barre los targets pendientes de la resolución exterior.

Al terminar las señales, los runners inactivos se ocultan, deshabilitan y reciben `queue_free()`. `tree_exiting` elimina la referencia de `_runners`; no cambia el array durante las iteraciones síncronas existentes. El guard acepta también una referencia liberada por un observer. `WaveDirector.get_spawned_runner()` devuelve `null` cuando su nodo ya fue liberado, conservando la clave histórica para contar spawns.

Esta frontera de vida es deliberada: los consumidores conservan el payload o `MonsterState` si necesitan historia; no conservan un Control resuelto más allá del frame. La mutación directa del modelo, sin pasar por servicio/breach de LaneField, continúa siendo una API de prueba de bajo nivel y no inicia limpieza visual.

No se cambia selección de targets, contenido, satisfacción, splash, recompensas, velocidad, reputación, pausa ni terminales. No se modifica Main, App, la UI de mejoras ni ninguna suite congelada.

## Verificación reproducible

```sh
GODOT_BIN=/ruta/a/godot python3 tests/run_vis_retirement_checks.py
```

El runner crea copias temporales con identidad de proyecto única y logs fuera del checkout; no usa la ruta de metapersistencia del jugador. Importa de cero y rechaza diagnósticos de parser, GDScript, motor, referencias liberadas, conexiones duplicadas o recursos filtrados incluso con exit 0. Las aserciones negativas usan `VIS_ASSERT`, distintas de errores del motor. `VIS_CHECK_LOG_DIR=/ruta/temporal` conserva logs y `mutations.json`. El workflow `VIS-01 Runner Retirement` ejecuta ese comando en Ubuntu; su resultado remoto sigue pendiente hasta publicar la rama.

- Suite focal: **189 checks PASS**. Servicio parcial permanece visible; satisfacción y breach se retiran; D7 mantiene orden y clamp; resolución anidada; eliminación desde un observer; cinco waves y boss satisfecho/breach; Main deshabilitado al terminar.
- Stress: **100 ciclos × 12 runners = 1.200 runners**. Cada ciclo vuelve a exactamente **6 nodos base de LaneField**, 0 runners y 0 referencias propias.
- Lifetime: observer de breach ve el runner vivo, visible y no encolado. El probe directo del adaptador permite que la mutación `free` falle por una aserción de vida, no por la protección de Godot contra liberar un emisor bloqueado. La suite focal también dispara `advance()` real.
- Seis mutaciones rechazadas por sus aserciones y sin errores incidentales: no ocultar (`VIS_HIDDEN`), ocultar antes de listeners (`VIS_LISTENER_VISIBLE`), liberar antes de señal (`VIS_EVENT_LIFETIME FAIL`), doble resolución (`VIS_ONCE`), nodo residual (`VIS_FREED`) y boss residual (`VIS_BOSS`).
- Base: core **22/22**. Composición temporal de #55 y #56 congelados más VIS: core **23/23**, incluido RUN **376**. Ambas pasan boss, reputación, feedback, SAV-01 **10 casos / 193**, SAV-02 **29 / 1.023 / 0 skips**, TST-02 **10/10** y TEC-01. UPG-02h mantiene **1.263**.
- Composición: RST matrix y **3/3 mutaciones**, sentinel de metadatos por **40 reinicios / 20 cancelaciones**. Bot real de tablero: cinco waves, cinco selecciones, un boss, Victory y restart en wave/oferta/boss; ejecución headless y renderer Metal 4 Forward Mobile. La ejecución gráfica registró **142,09674 s lógicos**, **7,142 s reales** a 20× y **99 acciones**, sin errores ni leaks.

Las capturas antes/después con renderer real muestran los marcadores residuales al terminar y los tres carriles vacíos con VIS. El probe imprime además los estados de la tabla. Una primera salida gráfica inmediata del harness reportó dos ObjectDB pendientes; al dar dos frames de cleanup después de destruir Main, la ejecución verbose quedó limpia. Ese ajuste es del harness temporal, no del juego.

## Evidencia y límites

Artefactos de la sesión: `/private/tmp/m3-vis-audit/` (`baseline.log`, `after-probe.log`, `before.png`, `after.png`, logs de renderer, `regression-results.json`, `mutations-final/`). El informe de entrega está en `/private/tmp/m3-vis-audit-report.md`. Estos archivos temporales no son una dependencia del test ni del producto.

La revisión adversarial de RST detectó por separado A-LC01: restart síncrono desde un listener terminal puede intentar liberar el Main que todavía emite una señal y dejar App en reemplazo. VIS no modifica ese código congelado ni resuelve ese hallazgo preexistente; las pruebas de integración ordinarias aprobadas aquí no sustituyen su corrección. Tampoco constituyen evidencia de ejecución física en iOS.
