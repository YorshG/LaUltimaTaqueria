# UPG-02f — warm_welcome y last_stand

## Base, alcance y fuentes

Implementado sobre `uat` = `1d898ad748250b215e66117140430392a6c9eb9f` (PR #48), con Godot `4.7.2.stable.official.ed1daf0bf` en macOS. El checkout previo estaba limpio en `feature/upg-02e-reputation-survival` (`0e82e101506986989bb7831e9184fbe08a988282`), con un único worktree y sin rama local UPG-02f. Se trabajó en un clon aislado; el checkout y las ramas previas se conservaron. No se encontraron asignaciones activas de otros colaboradores para estos archivos.

Fuentes revisadas completas:

- [Contrato de Jorge/Codex](https://guintosbrothers.slack.com/archives/C0C3LLDUZ6C/p1790778070594179).
- [Auditoría previa de Xavier](https://guintosbrothers.slack.com/archives/C0C3LLDUZ6C/p1790781131206969), sin blockers.
- `docs/CONTENT_MODEL.md`, D1–D6 de `docs/DECISIONS.md` y contenido validado en `data/content/`.

Archivos de implementación: `scripts/main.gd`; pruebas: `tests/upg_02f_conditionals_test.gd` y su UID, `tests/upg_02b_satisfaction_test.gd`, `tests/run_core_suite.sh`; documentación: este documento y aclaración D3 en `docs/DECISIONS.md`.

No se modifican WaveDirector, UpgradeModifiers, RecipeResolver, LaneField, ReputationState, feedback ni JSON. UPG-02g/h, RST-01 e IOS-01 quedan fuera del alcance. `main` remoto se verificó en `a6d88f4c4715a64614ddf3e0a220e76d65304339`; no se promueve ni se hace merge. La entrega es un PR draft exclusivamente hacia `uat`.

## Comportamiento y auditoría incorporada

`Main._on_chain_completed` deriva los efectos activos y crea un snapshot efectivo nuevo por platillo. Evalúa `conditional_multipliers` con sus valores y parámetros validados, y multiplica solamente `satisfaction_multiplier` (paso 4 de D4). El derivador sigue siendo puro y el resolver sigue aislando los efectos especiales.

- `warm_welcome`: ×2 exclusivamente para el primer servicio exitoso de cada encuentro. El estado inicial está desarmado; spawns directos en LaneField y señales de selección no crean encuentros.
- Cada primer `monster_spawned` de una corrida (`get_spawned_count() == 1`) arma el encuentro, aunque se repita el `wave_id`. D3 registra esta frontera, sin añadir `wave_started`.
- El estado del primer servicio se consume aunque todavía no se posea la mejora. Una selección posterior no retroactiva un servicio ya realizado.
- El jefe se arma antes de su spawn y de `boss_started`; la quinta selección puede conceder la mejora y hacerla útil inmediatamente.
- Sólo `service.ok && target_found && served` no vacío consume. No-target, cadena inválida, error de resolución y rechazo real de LaneField lo conservan.
- Se captura un token antes de `resolve_dish` y se consume sólo si el encuentro sigue siendo el mismo. La cadena síncrona servicio → monstruo satisfecho → oleada completada → quinta selección → jefe no consume el bonus del jefe al regresar del servicio anterior.
- `last_stand`: ×1.25 si `maximum > 0` y `current / maximum < threshold` (`0.20` en contenido). No redondea ni usa comparación aproximada. Exactamente 20%, incluido 23/115, no aplica. El feedback UI conserva su `<= 20%`.
- La evaluación sucede antes de servir; el restore veggie del propio platillo sólo afecta la evaluación del siguiente. `second_chance` al 25% desactiva el bonus en el siguiente servicio.
- Ambos condicionales y `taco_power` se componen multiplicativamente. Stun, burst y restore veggie conservan únicamente su multiplicador especial; no se implementa splash.

## Pruebas deterministas

La nueva suite usa selección pública, contenido real y semillas fijas. La subclase de selector sólo fija la semilla de arranque, sin falsificar ofertas ni efectos. El avance automático se deshabilita en los fixtures para mover tiempos explícitamente. La prueba de rechazo invalida el target desde `dish_created` para recorrer el rechazo real de LaneField.

| Caso | Evidencia |
|---|---|
| Cinco oleadas y repetición de `wave_01` | Primer servicio 60, segundo 30; countdown sin target no consume. Oferta pública previa concede `warm_welcome` para ejercitar también la primera oleada |
| Fallos antes del primer servicio | Sin target, cadena de 2, ingrediente desconocido y target rechazado conservan 60 para el siguiente servicio real |
| Spawns posteriores | Tras consumir el primero, el siguiente spawn de esa misma corrida sirve 30 |
| Posesión tardía | Servicio sin mejora 30; obtenerla durante el encuentro sigue en 30; siguiente encuentro sirve 60 |
| Run real, selección temprana | Semilla 2: `warm_welcome`, `slow_salsa_plus`, `last_stand`, `chain4_boost`, `taco_power_1`; cinco oleadas completas por Main y selección síncrona, primer jefe 69 y segundo 34.5 |
| Run real, quinta selección | Semilla 5: `slow_salsa`, `safety_shield`, `steady_hands`, `reputation_boost`, `warm_welcome`; primer jefe 60 y segundo 30, sin oleada 6 |
| Umbral y patient_service | Semilla 20260921: `last_stand`, `slow_salsa`, `taco_power_1`, `patient_service`, `reputation_boost`; 23/115 → 34.5, 19.99% → 43.125; recuperación y breaches mitigados 8.5 reevaluados en vivo |
| Umbral y second_chance | Semilla 2: `slow_salsa_plus`, `taco_power_1`, `warm_welcome`, `last_stand`, `second_chance`; 20/100 → 34.5, 19.99/100 → 43.125; rescate al 25% → 34.5 |
| D4, tres ingredientes | Semilla 25: `patient_service`, `last_stand`, `warm_welcome`, `chain5_effect_boost`, `taco_power_2`; compara servicios reales con/sin condicionales y con/sin boost especial. Stun 1/1.3 s, burst 12/15.6 y veggie 5/6.5 no reciben ×2 ni ×1.25 ni taco_power |
| Snapshots | Efectos activos y derivación pura idénticos antes/después de los servicios |
| Regresión UPG-02b | Expectativas 30 → 37.5 y 48 → 60 al 19%; spawn directo sigue sin activar warm_welcome. No se relajan assertions |

## Resultado local

- Importación headless y escena Main: PASS.
- `godot --headless --path . --script res://tests/upg_02f_conditionals_test.gd`: **396 checks PASS**.
- `bash tests/run_core_suite.sh`: **19/19 archivos PASS**, incluida UPG-02f y regresión UPG-02a–e.
- `boss_encounter_test.gd`, `reputation_test.gd`, `feedback_test.gd`, `save_service_test.gd`, `save_recovery_test.gd`: **PASS**.
- `bash tests/run_restart_suite.sh`: **PASS**; 10/10 arranques de Main, persistencia entre procesos, recuperación y preservación de temporales abandonados.
- `git diff --check`: **PASS**.

La importación inicial dentro del sandbox informó restricciones de certificados/configuración del editor. La repetición autorizada fuera del sandbox y todas las pruebas anteriores terminaron sin `ERROR`, `SCRIPT ERROR`, fugas ni recursos retenidos. No se alteró código para eludir esos diagnósticos del entorno.

## Límites y pendientes manuales

No se ejecutó interacción táctil, evaluación audiovisual, balance ni build/dispositivo iOS. El wiring temporal de Main todavía no inicia automáticamente las oleadas; los tests usan la API pública existente de WaveDirector. No se implementa navegación ni reinicio activo RST-01. La repetición de una oleada aquí valida sólo el rearme de este estado, no la aceptación de selecciones duplicadas ni un reinicio completo de partida.

El estado terminal del CI del commit publicado se registra en el PR y en el reporte de entrega; los resultados locales no se presentan como validación CI independiente del merge base de PR #48.
