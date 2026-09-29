# UPG-02c — Velocidad global

## Alcance y baseline

Implementación de `slow_salsa` (×0.9) y `slow_salsa_plus` (×0.75), para runners normales y jefe, existentes y futuros, incluidas todas sus fases.

Antes de editar se ejecutó `git fetch --prune origin`, `git switch uat`, `git pull --ff-only origin uat`, `git status` y `git rev-parse HEAD`. Árbol limpio, `uat` y `origin/uat` en `32cc723cb18ba4f43e90434504a9c8f334c13496`; `origin/main` en `a6d88f4c4715a64614ddf3e0a220e76d65304339`. Rama de trabajo: `feature/upg-02c-global-speed`.

La referencia local `main` permanece en `f17fd38abc1aa18a430bebecf655833ac5d572f7`, seis commits detrás de `origin/main`; no se cambió ni sincronizó. El SHA obligatorio de main corresponde a `origin/main`.

Se conserva el alcance congelado y la decisión aprobada de que la velocidad global también afecta al jefe. No cambia ninguna decisión aprobada; no se requiere modificar `DECISIONS.md`. No se encontraron asignaciones activas a Claude sobre los archivos editados.

## Contrato y criterios de aceptación

- `LaneField.global_speed_multiplier` inicia en `1.0` y pertenece a la instancia del campo.
- `set_global_speed_multiplier(value) -> bool` acepta únicamente int/float finito y mayor que cero. Devuelve `false` sin mutaciones ante valores inválidos.
- Cada asignación sustituye el valor absoluto y lo propaga a todos los runners que siguen siendo instancias válidas. Se omiten referencias liberadas; los retirados no se reactivan.
- `spawn_runner()` aplica el valor vigente después de `configure()` y antes de devolver el runner.
- `Main._on_upgrade_selected()` deriva desde `UpgradeSelector.get_active_effects()` y aplica `modifiers["monster_speed_global"]` antes de los guards existentes y del spawn del jefe. Una derivación fallida no produce cambios parciales.
- El payload de la señal no es la fuente del efecto. Repetir la señal deriva y asigna el mismo valor; no acumula ×0.9 ni ×0.75.
- Se preservan progreso, velocidad relativa, fase, stun, hambre, identidad y targeting. `LaneMotion` conserva toda la matemática de desplazamiento.

No se modifican JSON, `WaveDirector`, `LaneRunner`, `LaneMotion`, selección/ofertas ni otros efectos pendientes de UPG-02.

## Pruebas deterministas

`tests/upg_02c_global_speed_test.gd`: **406 comprobaciones**.

- Neutralidad y movimiento original; tres carriles activos, spawns futuros y cambio de velocidad únicamente para desplazamientos posteriores.
- Asignaciones repetidas 0.9/0.75 y retorno a 1; rechazo de NaN, ±Infinity, cero, negativos, null, booleanos, strings, arrays y diccionarios, conservando el último valor válido.
- Referencia liberada en la colección y runner retirado todavía válido.
- Estado de runners y targeting conservados; stun de 0.6 s sobrevive al refresh, sigue bloqueando a los 0.4 s y consume solo 0.2 s del siguiente avance de 0.4 s.
- Selección pública temprana de ambas salsas, runners ya activos y siete spawns posteriores a través del `WaveDirector` real.
- Cinco oleadas reales resueltas por `LaneField` para cada escenario de quinta selección. Una subclase solo de prueba observa el multiplicador al entrar a `spawn_runner()` y al salir: detectaría crear primero al jefe y corregirlo después, incluso antes de `boss_started`.
- Cambios del jefe por satisfacción real a fases ×1, ×1.25 y ×1.4; movimiento comprobado en cada fase. Se actualiza un jefe activo y se reproduce tres veces la selección en cada fase: recupera el estado derivado sin duplicar al jefe ni alterar su estado restante.
- Payloads deliberadamente inconsistentes no sustituyen el snapshot del selector. Derivación inválida inyectada no cambia campo, runner ni inicia jefe.

Todos los recorridos usan contenido vigente y semilla de Main **20260921**, con ofertas y selección por API pública, sin mutar variables privadas del selector:

| Escenario | Selecciones |
|---|---|
| Salsa en selección 2 | `last_stand`, `slow_salsa` |
| Salsa plus en selección 4 | `steady_hands`, `second_chance`, `taco_power_1`, `slow_salsa_plus` |
| Salsa en selección 5 | `steady_hands`, `second_chance`, `chain5_effect_boost`, `reputation_boost`, `slow_salsa` |
| Salsa plus en selección 5 | `steady_hands`, `second_chance`, `taco_power_1`, `last_stand`, `slow_salsa_plus` |

Velocidades del jefe comprobadas, en carriles/s:

| Global | Fase ×1 | Fase ×1.25 | Fase ×1.4 |
|---|---|---|---|
| 0.9 | 0.0225 | 0.028125 | 0.0315 |
| 0.75 | 0.01875 | 0.0234375 | 0.02625 |

## Validación local — 2026-09-29

macOS, `Godot 4.7.2.stable.official.ed1daf0bf`.

| Comando / verificación | Resultado |
|---|---|
| `godot --headless --path . --editor --quit` | PASS, exit 0 |
| `godot --headless --path . --script res://tests/upg_02c_global_speed_test.gd`, dos ejecuciones consecutivas | PASS, 406 comprobaciones en cada ejecución |
| `bash tests/run_core_suite.sh` | PASS, 16/16 archivos; incluye UPG-02a (963), UPG-02b (607) y UPG-02c (406 comprobaciones) |
| `godot --headless --path . --script res://tests/boss_encounter_test.gd` | PASS |
| `godot --headless --path . --script res://tests/reputation_test.gd` | PASS |
| `godot --headless --path . --script res://tests/feedback_test.gd` | PASS |
| `godot --headless --path . --scene res://scenes/Main.tscn --quit-after 3` | PASS, exit 0 |
| UPG-02a y UPG-02b, ejecuciones dedicadas adicionales | PASS, 963 y 607 comprobaciones |
| `godot --headless --path . --script res://tests/save_service_test.gd` | PASS, 10 casos / 193 aserciones |
| `godot --headless --path . --script res://tests/save_recovery_test.gd` | PASS, 29 casos / 1023 aserciones / 0 omisiones |
| `bash tests/run_restart_suite.sh` | AUTOMATED PASS, Main 10/10 y persistencia entre procesos |
| `git diff --check` | PASS |

Revisión final para publicación: se repitieron todos los comandos de la tabla con Godot 4.7.2. Los resultados coinciden con lo esperado. SAV-02 produjo únicamente sus diagnósticos conocidos para exponentes extremos y UTF-8 inválido. Tras `git fetch --prune origin`, `origin/uat` continúa en `32cc723cb18ba4f43e90434504a9c8f334c13496` y `origin/main` en `a6d88f4c4715a64614ddf3e0a220e76d65304339`; no fue necesario cambiar el baseline.

La ejecución dedicada inicial pasó las 406 comprobaciones con un diagnóstico de certificados de macOS causado por el sandbox. La suite de aceptación se ejecutó con acceso normal a la configuración del motor y pasó sin ese diagnóstico. La importación regeneró los tres UID ausentes de board ya observados en UPG-02a/b; se retiraron de la entrega.

Se actualizaron expectativas anteriores que quedaron obsoletas por el alcance autorizado: UPG-02b esperaba `slow_salsa` sin efecto runtime y BOSS-01 esperaba velocidad neutra pese a elegir una salsa en sus ofertas. BOSS-01 tuvo tres fallos iniciales por esas expectativas; ahora verifica la fórmula existente con el multiplicador derivado y pasó. No se relajaron los requisitos de fases, selección, unicidad del jefe, satisfacción ni breach.

## Archivos y pendientes

Modificados: `scripts/lane/lane_field.gd`, `scripts/main.gd`, `tests/run_core_suite.sh`, `tests/upg_02b_satisfaction_test.gd` y `tests/boss_encounter_test.gd`.

Creados: `tests/upg_02c_global_speed_test.gd`, su `.uid` y este documento.

La revisión estricta incluye los archivos nuevos, además del diff de archivos rastreados. Los ocho archivos corresponden a UPG-02c; las dos pruebas anteriores modificadas se justifican arriba. No se incluyen secretos, temporales, artefactos locales ni los UID regenerados ajenos al cambio. El UID de la nueva suite sí es parte intencional de la entrega.

No se conocen regresiones en el alcance verificado. Validación local headless; no acredita prueba manual ni dispositivo físico. La revisión e integración a `uat` siguen pendientes de aprobación; no se promovió a `uat` ni se modificó `main`. Los siguientes bloques de UPG-02 y el reinicio de sesión RST-01 continúan fuera de este cambio.

El commit y el PR se publican únicamente desde `feature/upg-02c-global-speed` hacia `uat`. El resultado remoto de CI se reporta en GitHub y en la entrega, separado de esta evidencia local. UPG-02d no se inició y no se autoriza el merge del PR.
