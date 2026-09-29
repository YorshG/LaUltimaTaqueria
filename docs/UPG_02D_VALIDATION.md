# UPG-02d — Máximo de reputación y escudo

## Baseline y alcance

Implementa exclusivamente `reputation_boost` (+15 al máximo, sin curar) y `safety_shield` (una carga que absorbe el siguiente breach de daño bruto positivo, incluido el jefe).

Se ejecutaron antes de editar `git fetch --prune origin`, `git switch uat`, `git pull --ff-only origin uat`, `git status` y `git rev-parse HEAD`. Árbol limpio y `uat = origin/uat = 759012227ac178168aa7ce9582c5a778593e3735`. Rama: `feature/upg-02d-reputation-defense`.

`origin/main` se verificó en `a6d88f4c4715a64614ddf3e0a220e76d65304339`. La referencia local `main` sigue en `f17fd38abc1aa18a430bebecf655833ac5d572f7`, como en UPG-02c; no se sincroniza ni se modifica. No se encontraron asignaciones activas a Claude sobre los archivos editados.

D6 queda registrada en `DECISIONS.md`: `dedupe → shield → damage multiplier → reputation change → second_chance`. La validación antecede al dedupe y el guard de derrota va entre dedupe y shield. Este bloque implementa únicamente dedupe, shield y cambio de reputación. Los comentarios de extensión reservan el orden de UPG-02e y la atomicidad ya aprobada de D5; no ejecutan mecánicas futuras.

## Estado, API y eventos

`ReputationState` mantiene `shield_charges` como entero y `_applied_selections` como diccionario privado por instancia, de `selection_number` a `upgrade_id`. El snapshot expone exactamente `current`, `maximum`, `defeated` y `shield_charges`; no expone el registro de selecciones.

`apply_selection_effect(selection_number: int, upgrade_id: String, effect) -> Dictionary` usa un Variant para `effect` para devolver un error explícito cuando no es Dictionary. Rechaza número de selección menor que 1, ID vacío, efecto mal formado, partida derrotada, stat/operación no soportados, valores no numéricos, no finitos o no positivos. Si se proporciona `type`, debe corresponder al stat. Los efectos continuos, condicionales y `extra_life_charges` se rechazan sin reservar selección. Todas las validaciones ocurren antes de marcar, y se marca antes de emitir señales. Una selección ya aplicada devuelve `DUPLICATE_SELECTION` sin mutaciones ni nuevas señales, incluso con reentrancia o un ID diferente.

- `reputation_max`: acepta incrementos float; rechaza desbordamientos y valores que no producen un cambio representable. `100/100 → 100/115`, `60/100 → 60/115`, `22/100 → 22/115`. No cambia `current`; una restauración posterior sí utiliza el nuevo máximo. Emite únicamente `maximum_changed`, con snapshot, `before_maximum`, `delta_maximum`, `selection_number` y `upgrade_id`.
- `reputation_shield_charges`: acepta `1` y `1.0`, exige entero exacto y conserva el rango int64 del contador. No emite señal de concesión ni añade HUD de cargas.
- `reputation_changed` conserva su significado: cambió `current`.

`apply_breach()` consulta daño del contenido validado. Conserva dedupe por `spawn_sequence` antes de señales y el guard terminal. Daño bruto 0 devuelve `ok: true` sin consumir escudo, sin llamar a `apply_damage(0)` y sin señales. Ante daño positivo y carga disponible, resta una carga antes de emitir `shield_consumed`, conserva `current` y no emite `reputation_changed` ni `run_ended`.

El payload de escudo incluye snapshot, `spawn_sequence`, `monster_id`, `prevented_damage` y `shield_charges_remaining`. Todo resultado de breach incluye `damage_requested`, `damage_applied`, `shield_consumed` y `prevented_damage`. El daño efectivo procede del resultado de la propia operación, conservado antes de callbacks; una restauración reentrante no lo altera.

| Caso | Solicitado | Aplicado | Prevenido |
|---|---:|---:|---:|
| Nibbler con escudo | 10 | 0 | 10 |
| Siguiente nibbler sin escudo | 10 | 10 | 0 |
| Nibbler con current 5 | 10 | 5 | 0 |
| Monstruo de daño 0, con escudo | 0 | 0 | 0 |
| Jefe con escudo | 40 | 0 | 40 |
| Jefe sin escudo, current 100 | 40 | 40 | 0 |
| Jefe sin escudo, current 30 | 40 | 30 | 0 |

## Main, HUD y feedback

`Main` conserva el orden derive → velocidad global → one-shot soportado → guards → jefe. Resuelve la selección desde `get_selected_upgrades()[selection_number - 1]`, verifica rango e identidad y utiliza el efecto almacenado. `payload.effect` no interviene en gameplay. Devuelve errores explícitos de wiring para selección inválida o ID inconsistente; una quinta selección inconsistente no inicia al jefe. Solo los dos stats soportados llaman a la API one-shot; una quinta elección continua inicia al jefe normalmente.

Se guarda el primer resultado exitoso por `spawn_sequence`; errores duplicados no lo reemplazan. La finalización del jefe conserva `reputation_damage_on_breach = 40` y toma `reputation_damage` de `damage_applied`. Si una señal reentrante intenta completar antes de guardar el resultado exterior, espera al callback exterior, sin publicar daño inventado ni duplicar la finalización.

`maximum_changed` se conecta a `Hud.show_reputation` sin modificar `hud.gd`: etiqueta `Reputación 100 / 115`, barra con máximo 115 y valor 100. También se conecta a `FeedbackCoordinator.on_reputation_maximum_changed`, que solo evalúa el cruce UI `current / maximum <= 0.20`, sin `reputation_delta`: 22/100 → 22/115 avisa una vez; 19/100 → 19/115 no repite. `last_stand` conserva su contrato futuro `< 0.20` y no se implementa.

Se mantienen ambos cues en orden `breach → shield_consumed`. El coordinador deduplica escudos con un registro separado del de resoluciones. La única adición de copy es `feedback.shield_consumed`: **🛡 Escudo de la casa: daño bloqueado**. El tono corto y distinto se sintetiza como PCM mono en memoria. Se mantienen cola limitada, una sola voz, agrupación de repetidos y prioridad terminal; no se añaden archivos de audio.

## Pruebas deterministas

`tests/upg_02d_reputation_defense_test.gd`: **522 comprobaciones**. Cubre los contratos anteriores, validaciones, snapshots exactos, precisión float, límites del contador, dedupe por selección y breach, reentrancia del máximo, del escudo y de Main, derrota terminal con cargas remanentes, fixture validado de daño 0, HUD, low threshold y confianza en la selección almacenada.

Las pruebas de quinta selección completan las cinco oleadas con `WaveDirector` y `LaneField`, generan ofertas y eligen con la API pública real de `UpgradeSelector`. No mutan privados del selector. Una subclase de prueba inyecta únicamente la semilla 2 para el escudo; otra observa la reputación al entrar a `spawn_runner()`, antes de que exista el jefe. El contador de llamadas de una subclase de ReputationState comprueba que mejoras continuas y condicionales no pasan por la API one-shot.

| Caso | Semilla | Ruta pública |
|---|---:|---|
| Escudo quinto | 2 | `slow_salsa_plus`, `taco_power_1`, `warm_welcome`, `last_stand`, `safety_shield` |
| Boost quinto | 20260921 | `last_stand`, `slow_salsa`, `taco_power_1`, `patient_service`, `reputation_boost` |
| Continua quinta | 20260921 | `second_chance`, `chain5_effect_boost`, `extra_bite`, `slow_salsa`, `taco_power_2` |

`patient_service`, `second_chance` y las condicionales presentes en esas rutas permanecen inactivos. Las pruebas del jefe verifican daño bruto sin multiplicador y ausencia de resurrección.

`reputation_test.gd` solo actualiza la expectativa exacta de snapshot. `feedback_test.gd` añade la señal real de escudo, orden, dedupe independiente, copy exacto, PCM determinista y distinto y cobertura de cola limitada. `boss_encounter_test.gd` añade comparación del daño reportado con pérdida efectiva; conserva unicidad, fases, satisfacción, breach y ausencia de oleada 6.

## Validación local — 2026-09-29

macOS con `Godot 4.7.2.stable.official.ed1daf0bf`.

| Verificación | Resultado |
|---|---|
| Importación `godot --headless --path . --editor --quit` | PASS, exit 0 |
| Main/bootstrap `--scene res://scenes/Main.tscn --quit-after 3` | PASS, exit 0 |
| UPG-02d dedicada | PASS, 522 comprobaciones |
| `bash tests/run_core_suite.sh` | PASS, 17/17 archivos |
| `reputation_test.gd`, ejecución explícita | PASS |
| `feedback_test.gd`, ejecución explícita | PASS |
| `boss_encounter_test.gd`, ejecución explícita | PASS |
| `upgrade_modifiers_test.gd`, dedicada y central | PASS, 963 comprobaciones |
| `upg_02b_satisfaction_test.gd`, dedicada y central | PASS, 607 comprobaciones |
| `upg_02c_global_speed_test.gd`, dedicada y central | PASS, 406 comprobaciones |
| SAV-01 `save_service_test.gd` | PASS, 10 casos / 193 aserciones |
| SAV-02 `save_recovery_test.gd` | PASS, 29 casos / 1023 aserciones / 0 omisiones |
| TST-02 `bash tests/run_restart_suite.sh` | AUTOMATED PASS, 10/10 Main y persistencia entre procesos |
| `git diff --check` | PASS |

La suite central, importación, bootstrap y reputación/feedback/jefe se volvieron a ejecutar después del ajuste final de representabilidad int64. SAV/TST produjeron sus resultados sobre la misma funcionalidad; ese ajuste no modifica persistencia ni arranque. SAV-02 conserva sus diagnósticos esperados para exponentes extremos y UTF-8 inválido. Los logs locales están fuera del repositorio, en `/tmp/upg_02d_validation/`.

El primer ensayo de la nueva suite detectó un defecto de instrumentación: cambiar el script de ReputationState reinicializaba su índice de contenido vacío. Se corrigió construyendo la instancia observada con contenido validado y conservando las conexiones reales. La suite completa posterior pasa. La importación regeneró tres UID ajenos de board ya conocidos en UPG-02c; se excluyen de esta entrega.

## Archivos, riesgos y entrega

Modificados:

- `scripts/session/reputation_state.gd`
- `scripts/main.gd`
- `scripts/ui/feedback_coordinator.gd`
- `scripts/ui/feedback_audio.gd`
- `data/content/localization.es-MX.json`
- `docs/DECISIONS.md`
- `tests/reputation_test.gd`
- `tests/feedback_test.gd`
- `tests/boss_encounter_test.gd`
- `tests/run_core_suite.sh`

Creados: esta validación, `tests/upg_02d_reputation_defense_test.gd` y su `.uid`.

No se modifican `upgrades.json`, `UpgradeModifiers`, `UpgradeSelector`, `LaneField`, `LaneMotion`, `LaneRunner`, `RecipeResolver`, `WaveDirector` ni `hud.gd`. No se añaden dependencias, secretos, balance ni sistemas de sesión.

No se conocen regresiones en el alcance verificado. La evidencia es automatizada/headless: no acredita escucha manual ni validación física iOS. CI remoto, SHA final y URL del PR se reportan por separado en la entrega para no confundirlos con la evidencia local.

Entrega mediante commit y push de la rama de trabajo, PR exclusivamente contra `uat`, sin push directo a integración ni cambios en `main`, y sin merge. UPG-02e no se inicia: quedan pendientes `patient_service`, `second_chance` y veggie ×1.3, además de los otros bloques excluidos, RST-01 e IOS-01.
