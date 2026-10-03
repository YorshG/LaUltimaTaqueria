# RUN-01 — Loop jugable de M3

Fecha local: 2026-10-03. Base: `origin/uat` en `61dfce3`. Rama: `feature/run-01-m3-game-loop`. Entrega independiente para `uat`, sin merge ni promoción a `main`. El SHA/PR definitivos se registran en la entrega; los resultados de este documento corresponden al contenido verificado antes de publicar.

## Problema y alcance

El arranque anterior configuraba `Main`, pero no existía un caller de producción de `WaveDirector.start_wave()` ni de `UpgradeSelector.select_upgrade()`. Las pruebas de módulos iniciaban oleadas y elegían ofertas manualmente. El diagnóstico completo está en `M3_RUNTIME_AUDIT.md`.

`Main.tscn` ahora inicia `wave_01` por defecto, continúa las cinco oleadas en el orden del contenido y presenta una elección real después de cada cierre. La quinta elección aplica sus efectos antes de crear un único jefe. La orquestación de la partida sigue en `Main`; no se introduce `GameSession`, un event bus ni un singleton. El lifecycle del host y reinicio pertenecen a RST-01, con archivos independientes. Esta rama no modifica `project.godot` ni `App`.

## Contrato runtime

- `auto_start_run=true` es el valor de producción. Las pruebas anteriores que necesitan manejar las APIs de módulos fijan explícitamente `false` antes de añadir `Main` al árbol; sus assertions funcionales se conservan.
- `wave_countdown_sec=0.0` utiliza el parámetro existente de `WaveDirector`. La agenda existente produce el primer spawn a los 2 segundos. Se prueba también un countdown explícito de 0.5 segundos, sin cambiar los datos de balance.
- `UpgradeChoice` muestra exactamente tres botones con nombre y descripción obtenidos de la localización del contenido validado. Emite únicamente el ID de la intención; `UpgradeSelector` valida la selección y conserva las reglas de conflictos y elegibilidad.
- Mientras la oferta está visible, se detienen `BoardView`, `LaneField` y `WaveDirector`. La interfaz permanece interactiva. No se pausa globalmente `SceneTree`, por lo que un host externo puede presentar su confirmación.
- Los dos extremos de la intención UI rechazan callbacks durante una pausa del host. Un `pressed` tardío no deshabilita permanentemente las opciones al cancelar una confirmación.
- Cada selección cierra la oferta y avanza una sola vez. Las primeras cuatro inician la siguiente oleada; la quinta inicia el jefe. No existe una sexta oleada.
- `satisfied=true` produce victoria y congela gameplay. Un breach del jefe con reputación positiva produce `boss_escaped` y el texto «El jefe llegó al mostrador — partida terminada»; no se inventa reputación cero ni victoria. La derrota por reputación conserva el evento `run_ended` existente. La finalización del jefe conserva `boss_encounter_completed` y su payload.
- Se conservan D3–D8: frontera de encuentro antes del boss y en primer spawn, orden de satisfacción/splash, atomicidad de `second_chance`, orden del breach, derivación de efectos desde selecciones reales y geometría de `steady_hands`. `WaveDirector` no agrega `wave_started`.

## Observabilidad y reentrancia

`get_run_snapshot()` informa fase, outcome, terminal, número de oleada, seeds, `logical_elapsed_sec` y `wall_elapsed_sec`. El tiempo lógico suma los deltas de gameplay y excluye selección de mejoras y pausa del host. El tiempo real incluye esperas y se congela al terminar. Ninguno se usa como timeout ni se persiste.

`run_phase_changed` publica una transición ya instalada. La oferta se presenta y pausa antes de notificar; el director inicia antes de notificar la siguiente oleada; el boss existe antes de notificar su fase. Un listener que elige síncronamente al recibir `upgrade` no hace reaparecer una oferta vieja al retornar. La telemetría `ended` se publica después del evento terminal contractual, para que el host conozca primero el resultado.

## Archivos de implementación y pruebas

- `scripts/main.gd`, `scenes/Main.tscn`: loop, fase visible, transiciones, guards y medición.
- `scripts/ui/upgrade_choice.gd`, su UID y `scenes/ui/UpgradeChoice.tscn`: presentación de ofertas e intención de selección.
- `tests/run_loop_test.gd` y su UID: 376 checks dedicados al loop y entrada de botones mediante `SubViewport.push_input`.
- `tests/run_core_suite.sh`: incorpora RUN-01 y rechaza errores del motor incluso cuando Godot retorna exit 0.
- Fixtures de Main con opt-out explícito: `board_input_test.gd`, `boss_encounter_test.gd`, `feedback_test.gd`, `lane_integration_test.gd`, `reputation_test.gd`, `upg_02b_satisfaction_test.gd`, `upg_02c_global_speed_test.gd`, `upg_02d_reputation_defense_test.gd`, `upg_02e_survival_test.gd`, `upg_02f_conditionals_test.gd`, `upg_02g_assist_serve_test.gd`, `upg_02h_steady_hands_test.gd`, `upgrade_selector_integration_test.gd` y `wave_director_test.gd`.
- `tests/m3_runtime_bot.gd` y su UID: harness de ejecución por el motor, fuera de core por su duración; no llama `WaveDirector.advance()` ni inicia oleadas manualmente.
- Documentación: este documento, `M3_RUNTIME_AUDIT.md`, `README.md` y fila RUN-01 en `planning/BACKLOG.md`.

## Verificación local

Godot `4.7.2.stable.official.ed1daf0bf`, macOS. Las ejecuciones verificadas se realizaron fuera del sandbox que bloquea la caché del editor y genera un error de certificados del sistema. La primera prueba sobre el worktree sin importar produjo errores de clases globales; después de importar se verificó el baseline y luego la implementación. Esos intentos iniciales no se cuentan como PASS.

| Prueba | Resultado |
|---|---|
| `bash scripts/verify_tec01.sh` | PASS: importación headless y arranque real de Main |
| `bash tests/run_core_suite.sh` | PASS: 23/23 archivos, incluidos RUN-01 y regresión UPG completa |
| `run_loop_test.gd` | PASS: 376 checks; escena configurada, cinco oleadas y selecciones, UI real, pausa, countdown, reentrancia, duplicados, dos victorias deterministas, breach sobrevivido y derrota |
| `board_input_test.gd` | PASS: 398 checks |
| UPG-02a/b/c/d | PASS: 963 / 607 / 406 / 526 checks |
| UPG-02e/f/g/h | PASS: 692 / 400 / 268 / 1263 checks |
| `boss_encounter_test.gd` | PASS: quinta selección, jefe único, fases, satisfacción, breach y ausencia de wave 6 |
| `reputation_test.gd` | PASS: reputación, daño por contenido, dedupe, veggie, derrota, HUD y resultados del jefe |
| `feedback_test.gd` | PASS: gestos, cues, umbral bajo, resultados del jefe, audio acotado y layout Unicode |
| `save_service_test.gd` | PASS: 10 casos, 193 assertions |
| `save_recovery_test.gd` | PASS: 29 casos, 1023 assertions, 0 platform skips; diagnósticos esperados de fixtures corruptos |
| `bash tests/run_restart_suite.sh` | PASS: 10/10 procesos Main y persistencia/recuperación entre procesos; no se presenta como aceptación de reinicio interno RST-01 |
| `git diff --check` | PASS |

Los logs completos de esta sesión están bajo `/tmp/run01-*.log`; `run01-core-final.log` contiene la regresión core final. No se detectaron errores de parser/runtime, conexiones duplicadas ni leaks en la ejecución positiva de RUN/core/TEC. Los warnings de recuperación de SAV-02 son fixtures negativos documentados, no fallos nuevos.

## Sensibilidad de las pruebas

Siete mutaciones aisladas en copias temporales, sin modificar la fuente positiva mientras se ejecutaban, fueron rechazadas con exit 1:

| Mutación | Assertion sensible |
|---|---|
| Desactivar autostart | `launch must start wave_01 without an external start_wave call` |
| Omitir pausa de upgrade | `upgrade overlay pauses board, runners and director` |
| Omitir cierre del overlay al avanzar | `returning from reentrant callback must not resurrect stale overlay` |
| Emitir fase upgrade antes de presentar | `reentrant observer sees fully presented and paused offer` |
| Tratar breach sobrevivido como victoria | `surviving boss breach is explicit non-victorious completion` |
| Permitir que botón tardío mute UI durante pausa del host | `stale pressed event during host pause must not lock the offer` |
| Emitir fase ended antes del evento terminal | `terminal phase telemetry follows the contractual boss completion` |

Además, un ejecutable temporal que imprime `SCRIPT ERROR` y retorna exit 0 fue rechazado por el runner en las 23 entradas. Evidencia: `/tmp/run01-mutation-results.json`, `/tmp/run01-mut-*.log` y `/tmp/run01-runner-mutation.log`. El harness temporal está en `/tmp/run01_mutations.py`.

## Partida con motor y composición RST

Comandos reproducibles del harness durable, ejecutados desde la raíz del proyecto:

```sh
godot --headless --path . --script res://tests/m3_runtime_bot.gd -- 20
godot --headless --path . --script res://tests/m3_runtime_bot.gd -- 1
# Después de integrar/componer App de RST-01:
godot --headless --path . --script res://tests/m3_runtime_bot.gd -- 20 restart
```

Una composición temporal de RUN + RST, anterior al cierre final de revisión, completó una partida a velocidad 1× usando cadenas válidas de `BoardView` y botones UI: 52 cadenas, cinco elecciones, cinco oleadas, un jefe y victoria. Registró 142.0591 segundos lógicos y 141.930 segundos reales; oleadas de 20.0066, 24.5111, 28.0021, 30.0045 y 34.5076 segundos. Es diagnóstico de un bot que intenta una cadena de tres cada 0.5 segundos y elige inmediatamente; no acredita la duración de una partida humana ni el objetivo de 4–5 minutos.

La suma de los últimos tiempos de spawn es 136 segundos; la suma de `duration_target_sec` es 165 segundos y sigue siendo metadata. No se ajustó balance para forzar el objetivo. La misma composición verificó reinicio durante oleada, oferta y boss, y cancelación sin cambio lógico. El informe final de composición y su manifest corresponden al host de RST y complementan estos resultados, sin afirmar que las ramas independientes ya estén integradas en `uat`.

Las capturas desktop de la composición (`/private/tmp/m3-start.png`, `m3-upgrade.png`, `m3-victory.png`) muestran opciones legibles y el control del host accesible. No equivalen a validación táctil física en iPhone.

## Riesgos y pendientes

### Composición final verificada

La copia final `/private/tmp/m3-combined-final-nmsa2y76/project` combina las dos
ramas sin mergear refs. Un manifest SHA256 registra las fuentes funcionales.
Pasó core 23/23 (RUN 376), boss/reputation/feedback, SAV-01 193, SAV-02 1023,
TST-02 10/10 y persistencia, TEC-01, arranque App y RST 26/26 (166 checks),
sentinel de metapersistencia y 3/3 mutaciones RST. Sus logs/results/manifest
están en el directorio padre. No se atribuye este resultado a `uat` integrado.

El harness durable final pasó también por separado desde Main y compuesto con
App. La composición se renderizó con **Metal 4.0 / Forward Mobile en Apple M2**:
reinicios y cancelaciones durante wave, upgrade y boss; callback de botón tardío
bajo modal rechazado sin bloquear las opciones; partida final con cinco oleadas,
cinco elecciones, un boss, victoria y reinicio terminal. Ejecución acelerada 20×:
142.3212 s lógicos y 7.171 s de pared en la última run. Sin errores de script,
fugas ni recursos retenidos. La evidencia 1× anterior sigue siendo diagnóstico
automático, no duración humana validada.

Logs finales del bot: `/private/tmp/m3-final-render-bot.log` y
`/private/tmp/m3-final-standalone-bot.log`. Las capturas del modal sobre la oferta
se inspeccionaron visualmente; la UI permanece legible y las acciones accesibles.
El harness imprime las rutas exactas en TMPDIR al usar `capture` sin headless.

### Trabajo posterior

- Revisión independiente y CI del head publicado; no se autoriza merge funcional automáticamente.
- Integración de App/RST-01 antes de declarar reinicio interno completo de M3; verificar otra vez el head compuesto.
- Los runners resueltos permanecen dibujados en los carriles en el baseline, aunque ya no reciben targeting ni progresan. El loop hace visible esa acumulación; requiere seguimiento de presentación separado y no cambia los contratos de esta entrega.
- La elección de mejoras usa UI provisional. Audio/touch físico, usabilidad, balance y duración humana requieren dispositivos y sesiones reales.
- IOS-01/INP-01 no se consideran terminados por estas pruebas.
