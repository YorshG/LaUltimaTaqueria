# UPG-02e — Mitigación, segunda oportunidad y veggie ×1.3

## Baseline y alcance

Implementa exclusivamente `patient_service`, `second_chance` y la restauración veggie escalada por `chain5_effect_boost`. Se preservan D1 (float), D5 (rescate atómico), D6 (orden del breach) y el alcance congelado. No hay nuevas decisiones de diseño ni cambios de balance.

Antes de modificar se ejecutaron `git fetch --prune origin`, `git switch uat`, `git pull --ff-only origin uat`, `git status` y `git rev-parse HEAD`. Árbol limpio; `uat = origin/uat = e4e15c43021cce8e43acd3a4f9fef93c20145aa4`. Rama: `feature/upg-02e-reputation-survival`.

`origin/main` se verificó en `a6d88f4c4715a64614ddf3e0a220e76d65304339`. La referencia local `main` conserva `f17fd38abc1aa18a430bebecf655833ac5d572f7`, como en los bloques anteriores; no se sincroniza ni modifica. No se encontraron asignaciones activas a Claude sobre los archivos editados.

## Runtime y contratos

`ReputationState.reputation_damage_multiplier` inicia en `1.0`. `set_reputation_damage_multiplier(value) -> bool` acepta únicamente int/float finito y positivo, asigna el valor absoluto y rechaza valores inválidos sin mutación. Refrescar tres veces `0.85` conserva `0.85`, sin acumular multiplicadores.

`Main._on_upgrade_selected()` conserva la derivación desde `get_active_effects()` y aplica: derive → velocidad global → multiplicador de daño → one-shot soportado → guards → jefe. Nunca obtiene gameplay de `payload.effect`. La lista de one-shots incorpora únicamente `extra_life_charges`, además de los dos stats de UPG-02d. Los continuos y condicionales siguen fuera de la API one-shot.

El snapshot incorpora `extra_life_charges` entero: `current`, `maximum`, `defeated`, `shield_charges`, `extra_life_charges`. No expone el ratio privado, el registro de selecciones ni el multiplicador.

`apply_selection_effect()` admite `extra_life_charges` solamente con `type = grant_charge`, `operation = add`, valor numérico finito positivo, entero exacto representable, y `params.restore_ratio` numérico finito en `(0, 1]`. Acepta `1` y `1.0`, protege el límite int64 y el desbordamiento de la suma. El contenido vigente concede una carga con ratio `0.25`. Todas las validaciones preceden al marcado; selección repetida devuelve `DUPLICATE_SELECTION` sin conceder otra carga ni sustituir el ratio. Se conserva el tracking por instancia y por `selection_number`, marcado antes de señales.

## D6 y D5

El breach sigue exactamente: validación → dedupe por `spawn_sequence` → guard terminal → no-op por daño bruto cero → shield → multiplicador → resolución atómica de reputación con second_chance.

El escudo absorbe el daño bruto antes de calcular el multiplicador y conserva cualquier carga de vida sintética. Sin escudo, se calcula `raw_damage × reputation_damage_multiplier`; un resultado no finito o negativo devuelve `INVALID_DAMAGE` sin pérdida de reputación ni consumo de vida. Se conserva el dedupe ya marcado. Un resultado cero no invoca `apply_damage(0)`.

Una pérdida letal con carga consume una vida y asigna directamente `maximum × restore_ratio`. No almacena cero intermedio, no aplica daño y restauración como dos operaciones y no emite `run_ended`. El máximo vigente se respeta: con 115, el rescate es 28.75.

**Orden de señales elegido: `extra_life_consumed → reputation_changed`.** Antes de la primera señal ya están actualizados current, defeated y las cargas. Ambos payloads son copias del mismo resultado final, calculado antes de ejecutar observadores. Se emite exactamente un `reputation_changed`, incluso si la restauración termina en el mismo current que había antes; ese caso informa delta 0 conforme a la señal única exigida por D5.

`extra_life_consumed` incluye snapshot final, `restore_ratio`, `restored_to`, daño bruto, daño mitigado, `spawn_sequence` y `monster_id`. No se añade cue, localización ni HUD de cargas. El HUD y el rearme del feedback low usan el único `reputation_changed` final. El umbral UI continúa siendo `<= 0.20`; `last_stand` no se activa ni implementa.

`apply_damage()` también comparte la resolución atómica de pérdidas, pero recibe un importe final: no vuelve a aplicar el multiplicador de breaches. En ese caso la identidad de breach es `spawn_sequence = -1`, `monster_id = ""`. `restore()` y `apply_served_dish()` conservan su comportamiento; restaurar no consume vidas.

## Resultados de daño y jefe

Todos los resultados de breach mantienen `damage_requested`, `damage_applied`, `shield_consumed`, `prevented_damage` y añaden `damage_after_multiplier` y `extra_life_consumed`.

- `damage_requested`: bruto del contenido.
- `damage_after_multiplier`: cantidad mitigada que entra a la resolución; 0 cuando el flujo termina antes de esa etapa, por ejemplo con escudo, daño cero o error.
- `damage_applied`: `max(before_current - final_current, 0)`, calculado desde el snapshot de la propia operación. Nunca negativo.
- `prevented_damage`: conserva la semántica de UPG-02d, daño bruto absorbido por escudo; no se reutiliza para la mitigación de patient_service.

| Caso | Antes | Bruto | Mitigado | Final | Daño aplicado | Vida consumida |
|---|---:|---:|---:|---:|---:|---|
| Nibbler + patient | 100 | 10 | 8.5 | 91.5 | 8.5 | No |
| Tank + patient | 100 | 25 | 21.25 | 78.75 | 21.25 | No |
| Swift + patient | 100 | 15 | 12.75 | 87.25 | 12.75 | No |
| Jefe + patient | 100 | 40 | 34 | 66 | 34 | No |
| Jefe + patient, sin vida | 30 | 40 | 34 | 0 | 30 | No; derrota |
| Patient + vida, sintético | 35 | 40 | 34 | 1 | 34 | No |
| Patient + vida, sintético | 30 | 40 | 34 | 25 | 5 | Sí |
| Jefe + vida | 30 | 40 | 40 | 25 | 5 | Sí |
| Jefe + vida | 10 | 40 | 40 | 25 | 0 | Sí |
| Jefe + vida, current sin cambio | 25 | 40 | 40 | 25 | 0 | Sí |

Main conserva el primer resultado exitoso por spawn. La completion del jefe sigue usando ese `damage_applied` y mantiene `reputation_damage_on_breach = 40`. No se cambió ese wiring de UPG-02d.

Reentrancia cubierta: repetir el mismo breach desde `extra_life_consumed` devuelve `DUPLICATE_BREACH`; otro breach observa la vida ya consumida y aplica daño normal. Una restauración desde `reputation_changed` tampoco modifica el resultado exterior. Cada resultado conserva el estado final de su transacción, aunque una operación reentrante distinta avance después el estado vivo. También se repite la señal de carril del jefe durante el rescate, antes de que Main guarde el resultado exterior, sin duplicar completion ni sobrescribirlo con un error.

## Veggie ×1.3

`RecipeResolver` incorpora `reputation_small_restore` al mismo escalado de `amount` que utiliza burst. Solo aplica `special_effect_power_multiplier`: 5 × 1.3 = 6.5 en cadenas veggie 5+, incluyendo 6 y 25. Taco power, extra bite, chain4 bonus y las condicionales no multiplican esa restauración.

Casos verificados: sin boost +5; boost +6.5; 80 → 86.5 por servicio real; cadenas 3/4, no-target y servicio fallido +0; 112/115 +6.5 → 115/115. `apply_served_dish()` permanece intacto y lee la magnitud resuelta.

## Integración pública y regresiones ajustadas

La nueva suite `tests/upg_02e_survival_test.gd` tiene **692 comprobaciones**. Las rutas del jefe completan cinco oleadas reales con WaveDirector y LaneField, reciben ofertas y seleccionan mediante la API pública. Una subclase de prueba inyecta únicamente la semilla 2; otra observa estado y multiplicador al entrar a `spawn_runner()`. No se mutan privados del selector ni se cambia la exclusión strong_defense.

| Prueba | Semilla | Ruta pública |
|---|---:|---|
| Patient quinto | 2 | `slow_salsa_plus`, `taco_power_1`, `warm_welcome`, `last_stand`, `patient_service` |
| Vida quinta | 2 | `slow_salsa_plus`, `taco_power_1`, `warm_welcome`, `last_stand`, `second_chance` |
| Patient temprano | 20260921 | `last_stand`, `slow_salsa`, `taco_power_1`, `patient_service` |
| Vida temprana y veggie | 20260921 | `second_chance`, `chain5_effect_boost` |
| Regresión de jefe sin supervivencia | 20260921 | `last_stand`, `slow_salsa`, `chain4_boost`, `warm_welcome`, `taco_power_2` |

Los ajustes de pruebas previas conservan sus contratos:

- UPG-02b: solo se actualizan las expectativas temporales veggie +5 → +6.5 y current 85 → 86.5. Satisfacción, stun, burst y aislamiento conservan todas sus comprobaciones.
- Reputation y UPG-02d: snapshots exactos incorporan `extra_life_charges`.
- UPG-02d: `second_chance` ya no es un stat no soportado; su prueba de exclusión de efectos continuos utiliza `patient_service`. La ruta de quinta mejora continua se sustituye por la ruta pública sin supervivencia para mantener el overkill y la ausencia de llamadas one-shot. Sus checks aumentan de 522 a 526 al verificar el nuevo campo en payloads completos.
- Reputation y feedback: elegir siempre la primera oferta daba la ruta `steady_hands`, `second_chance`, `chain5_effect_boost`, `reputation_boost`, `slow_salsa`. Ahora concede una vida real y cambia la restauración veggie. Para conservar sus pruebas de derrota terminal, restauración básica y audio terminal se fija la ruta pública sin supervivencia; no se relaja ninguna expectativa de derrota, audio o cierre de jefe. Los rescates se verifican separadamente en UPG-02e.
- `boss_encounter_test.gd` permanece sin cambios y pasa, incluyendo unicidad, fases, satisfacción, breach y ausencia de wave 6.

## Validación local — 2026-09-29

macOS, `Godot 4.7.2.stable.official.ed1daf0bf`. La suite nueva pasó **dos ejecuciones dedicadas**, además de la ejecución central, con 692 comprobaciones en cada una.

| Verificación | Resultado |
|---|---|
| `godot --headless --path . --editor --quit` | PASS |
| Main/bootstrap `--scene res://scenes/Main.tscn --quit-after 3` | PASS |
| `bash tests/run_core_suite.sh` | PASS, 18/18 archivos |
| `reputation_test.gd`, explícita | PASS |
| `feedback_test.gd`, explícita | PASS |
| `boss_encounter_test.gd`, explícita | PASS |
| `upgrade_modifiers_test.gd`, explícita | PASS, 963 comprobaciones |
| `upg_02b_satisfaction_test.gd`, explícita | PASS, 607 comprobaciones |
| `upg_02c_global_speed_test.gd`, explícita | PASS, 406 comprobaciones |
| `upg_02d_reputation_defense_test.gd`, explícita | PASS, 526 comprobaciones |
| SAV-01 `save_service_test.gd` | PASS, 10 casos / 193 aserciones |
| SAV-02 `save_recovery_test.gd` | PASS, 29 casos / 1023 aserciones / 0 omisiones |
| TST-02 `bash tests/run_restart_suite.sh` | AUTOMATED PASS, 10/10 Main y persistencia entre procesos |
| `git diff --check` | PASS |

La primera carga de la suite nueva detectó una inferencia de tipo ambigua en una variable de prueba; se declaró bool y se repitió correctamente. El runner de regresión comprueba diagnósticos de Godot además del exit code, porque un error de parseo puede devolver 0. La regresión completa no tiene errores de script. SAV-02 conserva sus diagnósticos esperados por exponentes extremos y UTF-8 inválido. Logs locales fuera del repositorio: `/tmp/upg_02e_validation/`.

La importación regeneró tres UID ajenos de board conocidos de bloques anteriores; se excluyen de la entrega. Solo se incluye el UID de la nueva suite.

## Archivos y límites de entrega

Modificados: `scripts/session/reputation_state.gd`, `scripts/main.gd`, `scripts/recipes/recipe_resolver.gd`, `tests/run_core_suite.sh`, `tests/reputation_test.gd`, `tests/feedback_test.gd`, `tests/upg_02b_satisfaction_test.gd`, `tests/upg_02d_reputation_defense_test.gd`.

Creados: este documento, `tests/upg_02e_survival_test.gd` y su `.uid`. Total: **11 archivos**.

Permanecen intactos los JSON de contenido/localización, UpgradeModifiers, UpgradeSelector, lanes, waves, FeedbackCoordinator, FeedbackAudio y HUD. No se añaden dependencias, secretos, feedback de vida, HUD de cargas, balance ni sistemas de sesión.

No se conocen regresiones en el alcance automatizado. La ejecución fue headless; no acredita prueba manual o dispositivo iOS. CI, SHA final y URL del PR se reportan por separado al publicar. Entrega únicamente por commit/push de la rama de trabajo y PR contra `uat`, sin merge, sin push directo a `uat` ni cambios en `main`.

UPG-02f/g/h no se iniciaron. `warm_welcome`, `last_stand`, `assist_serve`, `steady_hands`, RST-01 e IOS-01 permanecen fuera del alcance.
