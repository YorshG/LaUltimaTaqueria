# UPG-02g — assist_serve

Fecha de validación: 2026-09-30. Alcance exclusivo: UPG-02g.

## Baseline y aislamiento

Se sincronizaron refs con `git fetch origin` antes de modificar archivos:

- `origin/uat`: `ae14c90e72bf4d514bd55af0c84f78755926273d`, exactamente el baseline solicitado.
- `origin/main`: `a6d88f4c4715a64614ddf3e0a220e76d65304339`, exactamente el SHA solicitado.
- Rama creada desde ese `origin/uat`: `feature/upg-02g-assist-serve`.
- Checkout inicial limpio en `feature/upg-02e-reputation-survival`.
- Las refs locales previas se conservan: `uat` en `e4e15c43021cce8e43acd3a4f9fef93c20145aa4` y `main` en `f17fd38abc1aa18a430bebecf655833ac5d572f7`.

Se revisaron AGENTS, alcance congelado, colaboración y decisiones. No se encontraron asignaciones activas a Claude sobre los archivos autorizados. No se integró, rebasó ni promovió ninguna rama. La entrega es una rama feature y un PR exclusivamente contra `uat`, sin merge.

## Arquitectura y D7

`RecipeResolver` consume `chain4_splash_satisfaction` del snapshot derivado. Su validación existente rechaza valores no numéricos o no finitos. La resolución agrega `splash_satisfaction`: cero en cadena 3, cero con snapshot neutro y 10 en cadena 4+ con `assist_serve`. Este campo no recibe multiplicadores ni se suma a `satisfaction_final`.

`LaneField.resolve_dish()` conserva el targeting primario y el evento existente `dish_created`. Tras un servicio primario exitoso y su especial 5+, un helper privado busca el secundario usando el carril original y `_is_higher_priority()` sin modificar esa función ni `select_nearest_target()`. Excluye al primario, referencias liberadas y runners no targetable. Valida cadena 4+, cantidad positiva/finita y elegibilidad antes de aplicar únicamente `MonsterState.apply_satisfaction()`; si el secundario rechaza, devuelve splash vacío sin señal falsa.

D7 ordena las mutaciones de primario → especial primario → splash antes de las señales de servicio: un `dish_served` → `monster_satisfied` primario si corresponde → `monster_satisfied` secundario solo si transitó a satisfecho. Se capturan los datos antes de emitir señales de servicio síncronas. El contrato existente de `dish_created` y las señales internas de fase de MonsterState se conserva; D7 regula las señales de servicio/satisfacción de LaneField.

El retorno agrega `splash` en todas las salidas de LaneField. Es `{}` si no se aplicó; de lo contrario contiene `spawn_sequence`, `lane`, `monster_id`, `satisfaction_requested`, `satisfaction_applied`, `hunger_remaining_after` y `monster_became_satisfied`. El clamp se observa separando el valor solicitado del aplicado (10 solicitado / 7 aplicado en la prueba). Los payloads `dish_created` y `dish_served` no cambian. Main sigue procesando un solo platillo, un consumo de primer servicio y, cuando procede, una restauración veggie.

D7 y D7b quedan registrados en `DECISIONS.md`: no hay cue propio del splash. Solo una satisfacción completa reutiliza el feedback existente; una reducción parcial de hambre no produce feedback adicional.

## Archivos

- `scripts/recipes/recipe_resolver.gd`: campo plano separado.
- `scripts/lane/lane_field.gd`: búsqueda secundaria posterior a mutaciones primarias, aplicación plana, señales D7 y retorno aditivo.
- `tests/upg_02g_assist_serve_test.gd` y `.gd.uid`: suite determinista.
- `tests/run_core_suite.sh`: integra UPG-02g.
- `docs/DECISIONS.md`: D7/D7b.
- `docs/UPG_02G_VALIDATION.md`: evidencia y límites.

No se modifican Main, UpgradeModifiers, UpgradeSelector, ContentRegistry, ReputationState, WaveDirector, MonsterState, LaneRunner, JSON, localization, HUD ni feedback.

## Matriz de aceptación

Suite específica: **268 checks** en el código final sin mutaciones.

| Casos solicitados | Cobertura y resultado |
|---|---|
| 1–4 | Sin mejora en cadena 4 y con mejora en cadena 3: vacío; cadenas 4, 5 y 8: +10. PASS |
| 5–7 | Sin primario, solo un target, targets en carriles 0/2 y pareja en mismo carril. PASS |
| 8 | Tres candidatos válidos, prioridad por progreso y desempate por spawn; referencias liberadas, inactivos, satisfechos y llegada al mostrador excluidos. PASS |
| 9–10 | Primario satisfecho excluido; primario todavía activo nunca recibe su propio splash. PASS |
| 11 | Resolución fallida y rechazo real del primario tras `dish_created`: sin splash ni servicio. PASS |
| 12 | Candidato invalidado por fase del primario y fixture que rechaza en el límite de aplicación mediante MonsterState real: sin corrupción ni señal falsa. PASS |
| 13–15 | Secundario completo emite una satisfacción; incompleto ninguna; un servicio; D7 observado desde callbacks. PASS |
| 16 | Efectos del catálogo en cuatro combinaciones, incluidas ambas taco_power, chain4_boost, warm_welcome, last_stand y chain5_effect_boost: splash exacto 10. PASS |
| 17 | Tortilla/meat/veggie 5+ por Main: stun y burst solo al primario; una restauración veggie; condiciones se reevalúan en el siguiente platillo. PASS |
| 18 / R1 | Cinco oleadas reales y selección síncrona con jefe central, hambre completa al terminar el servicio final. PASS |
| R2 | WaveDirector real observa la satisfacción secundaria y cierra la oleada una sola vez. PASS |
| Selección posterior | Una señal de fase durante el burst primario cambia el candidato más cercano, sin invalidar al anterior. La selección debe observar el nuevo orden. PASS |
| Validación adicional | Resolver rechaza NaN/Inf/texto; LaneField ignora cantidad no positiva/no finita y cadena menor de 4 aunque se suministre splash. PASS |

Las pruebas de composición usan un selector fixture que devuelve efectos reales del catálogo; Main evalúa las condiciones y aplica los efectos posteriores reales. La combinación de siete mejoras prueba aislamiento aritmético aunque exceda los cinco slots de una partida. R1 usa el selector real con semilla 0 y ofertas/selecciones públicas; no usa ese fixture de composición.

## R1 y R2: sensibilidad comprobada

**R1:** las cinco oleadas reales se despachan y resuelven. Se conserva un monstruo central para el último servicio de cada oleada. `assist_serve` está seleccionado antes del último servicio de `wave_05`. Un listener de `wave_completed`, posterior al de Main, selecciona una oferta pública síncronamente. La quinta elección crea al jefe mientras `resolve_dish()` sigue en la pila. Se verifica que no existía antes, que se creó dentro de esa llamada y que al retornar mantiene **300/300** de hambre y `splash == {}`. Adelantar las señales del primario antes del splash hace fallar explícitamente la comprobación de hambre completa de R1.

**R2:** una fixture de oleada con dos monstruos centrales usa WaveDirector real. El secundario queda con hambre 7 antes del platillo. Al observar la señal primaria aún hay un pending y la oleada sigue `AWAITING_RESOLUTION`; tras la secundaria hay dos resueltos, cero pending, estado `COMPLETED` y una sola finalización con `satisfied_count == 2`. Omitir la señal secundaria hace fallar explícitamente R2 aunque el hambre ya sea cero.

Se ejecutaron siete mutaciones temporales independientes, restaurando los archivos después de cada corrida y al finalizar. Todas fallaron por assertions, sin errores de script en la corrida final de mutaciones:

| Mutación | Checks fallidos |
|---|---:|
| Multiplicar splash por satisfaction_multiplier | 27 |
| Preseleccionar secundario antes de aplicar primario, dejando aplicación posterior | 3 |
| Quitar restricción de carril | 7 |
| Aplicar stun y burst al secundario | 41 |
| Emitir dos dish_served | 22 |
| Mover señales primarias antes del splash | 5, incluido R1 |
| Omitir monster_satisfied secundario | 6, incluido R2 |

Los conteos de checks ejecutados pueden cambiar en mutantes que duplican/omiten callbacks. No se agrega framework de mutaciones ni se conservan cambios mutantes.

## Verificaciones

Godot local: `4.7.2.stable.official.ed1daf0bf`, macOS.

| Verificación | Resultado |
|---|---|
| Importación `godot --headless --path . --editor --quit` | PASS fuera del sandbox |
| Bootstrap Main `--scene res://scenes/Main.tscn --quit-after 3` | PASS |
| `upg_02g_assist_serve_test.gd` | PASS, 268 checks |
| `bash tests/run_core_suite.sh` | PASS, 20/20 archivos |
| `boss_encounter_test.gd` | PASS |
| `reputation_test.gd` | PASS |
| `feedback_test.gd` | PASS |
| `save_service_test.gd` | PASS, 10 casos / 193 assertions |
| `save_recovery_test.gd` | PASS, 29 casos / 1023 assertions / 0 platform skips; diagnósticos de fixtures indicados abajo |
| `bash tests/run_restart_suite.sh` | PASS; 10/10 ciclos Main y persistencia/recuperación entre procesos |
| Mutaciones temporales | 7/7 detectadas |
| `git diff --check` | PASS |

La importación inicial dentro del sandbox reportó restricciones de certificados y escritura de configuración del editor. Se repitió fuera del sandbox, sin esos errores. Godot también regeneró tres UID ausentes del baseline (`scripts/board/board_state.gd.uid`, `tests/board_playability_test.gd.uid`, `tests/board_refill_test.gd.uid`); se excluyen de esta entrega y se eliminan los generados por la validación al terminar.

SAV-02 emite cuatro `WARNING: Exponent too high` y un diagnóstico de UTF-8 inválido al cargar deliberadamente `1e999`, `-1e999` y bytes corruptos en sus fixtures existentes. La suite terminó con exit 0 y su marcador PASS. El recolector auxiliar marcó inicialmente esos avisos como fallo por su filtro estricto; se revisaron los backtraces y casos existentes, sin relajar assertions ni modificar la suite. No hubo errores de script, fugas ni recursos retenidos en las verificaciones finales.

CI remoto se reporta en el PR/entrega; no se presupone su éxito a partir de las pruebas locales.

## Límites y pendientes

No se implementa UPG-02h, RST-01, IOS-01 ni feedback dedicado. No cambia balance, targeting general ni decisiones previas; solo se registra el contrato D7/D7b aprobado. No se añaden dependencias ni secretos.

No se realizó validación visual/táctil en iPhone; queda como validación manual posterior del prototipo, no como evidencia de esta suite headless. Los UID ausentes del baseline son una observación preexistente fuera de alcance. El PR se deja sin merge y requiere revisión antes de integración.
