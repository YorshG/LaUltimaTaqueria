# UPG-02b — Satisfacción y efectos 5+ de stun/burst

## Baseline y alcance

- Baseline confirmado tras `git fetch --prune origin`, `git switch uat` y `git pull --ff-only origin uat`: `cfba503739aae6dcc67393a1213f69d30e85e880`, con árbol limpio y sin avance remoto adicional.
- Rama: `feature/upg-02b-satisfaction`. PR exclusivamente contra `uat`; sin push directo a `uat` ni merge.
- `origin/main` permanece en `a6d88f4c4715a64614ddf3e0a220e76d65304339`. La referencia local `main` ya apuntaba a `f17fd38abc1aa18a430bebecf655833ac5d572f7`; se conserva sin cambios.
- Implementa `taco_power_1`, `taco_power_2`, `extra_bite`, `chain4_boost` y `chain5_effect_boost` únicamente para stun/burst.
- Conserva decisiones aprobadas, contenido y balance. No inicia UPG-02c, otros bloques UPG-02, RST-01, IOS-01, HUD ni feedback nuevos.

## Cambios y contrato

`RecipeResolver.resolve(ingredient_id, chain_length, modifiers = {})` conserva todos los campos previos. Las llamadas de dos argumentos y los snapshots vacíos/neutros producen el mismo resultado REC-01 completo.

La fórmula D4, con precisión `float` y sin redondeo, es:

```text
(recipe.satisfaction + satisfaction_flat_bonus)
  × (1.0 si cadena 3; 1.5 + chain4_satisfaction_bonus si cadena 4/5+)
  × satisfaction_multiplier
```

El efecto 5+ se calcula después e independientemente: `duration_sec × special_effect_power_multiplier` para stun y `amount × special_effect_power_multiplier` para burst. Nunca recibe flat, bono de cadena ni multiplicadores de satisfacción.

El resolver valida que el snapshot sea un diccionario con claves de texto y valores numéricos finitos; consume solo los cuatro stats de este bloque. Las demás entradas numéricas no activan mecánicas. Rechaza estructuras incorrectas, booleanos, NaN, infinito y desbordamiento aritmético con `INVALID_MODIFIERS`, mensaje y sin resultado parcial. No introduce límites de balance. Copia los parámetros del efecto antes de modificarlos; preserva contenido y snapshot.

En `Main`, un preload y la derivación bajo demanda conectan `UpgradeSelector.get_active_effects()` → `UpgradeModifiers.derive()` → `RecipeResolver` → `LaneField`. No hay caché ni segundo estado mutable. Una derivación o resolución fallida se devuelve antes de crear/servir un platillo o aplicar reputación. `conditional_multipliers` no se evalúa.

`LaneField`, `ReputationState`, `UpgradeSelector`, `UpgradeModifiers` y `data/content/upgrades.json` no cambian. LaneField ya consume la satisfacción y los parámetros resueltos.

**Límite temporal explícito:** `chain5_effect_boost` todavía no escala `reputation_small_restore`. Veggie conserva `amount = 5.0`, incluido el servicio real que restaura reputación de 80 a 85. El contrato final de +6.5 sigue pendiente de UPG-02e; esta prueba no redefine ese contrato.

## Evidencia numérica

| Caso | Resultado comprobado |
|---|---|
| Tortilla sin mejoras, cadenas 3/4/5+ | 30 / 45 / 45 |
| `extra_bite`, tortilla 3/4 | 35 / 52.5 |
| `chain4_boost`, tortilla 3/4/5+ | 30 / 48 / 48 |
| `taco_power_1`, tortilla 3 | 34.5 |
| `taco_power_2`, tortilla 3 | 45 |
| `extra_bite + chain4_boost + taco_power_2`, tortilla 5 | (30 + 5) × 1.6 × 1.5 = 84 |
| `chain5_effect_boost`, tortilla 5 | stun 1.3 s; movimiento bloqueado aún tras 1.1 s y reanudado tras 1.4 s |
| `chain5_effect_boost`, meat 5 | normal 54 + burst 15.6 = 69.6 servidos |
| `taco_power_2 + chain5_effect_boost`, meat 5 | normal 81; burst sigue en 15.6 |
| Los cuatro modificadores, meat 5 | normal 98.4; burst sigue en 15.6 |
| Selección real de extra_bite, taco_power_2 y chain5_effect_boost, meat 5 | normal 92.25 + burst 15.6 = 107.85 servidos |

## Pruebas nuevas

`tests/upg_02b_satisfaction_test.gd` y su UID, incorporados a `tests/run_core_suite.sh`: **607 comprobaciones**, PASS en ejecución dedicada y nuevamente dentro de la suite central.

- Igualdad completa de las salidas neutras para los tres ingredientes y cadenas 3/4/5/6/25; regresiones REC-01 originales intactas.
- Valores del catálogo real, orden D4, ausencia de doble multiplicación y tipos float; diez repeticiones por combinación de ingrediente/tier con snapshot combinado.
- Aislamiento de entrada, contenido, salida y resoluciones sucesivas.
- Errores estructurales, NaN/±Infinity en los ocho stats derivados, desbordamiento normal y del burst, e intermedio infinito multiplicado por cero.
- Main con inyección explícita de fallos por subclases de prueba: derivación fallida y cada snapshot inválido no emiten `dish_created`, `dish_served`, `monster_satisfied` ni `reputation_changed`, ni alteran hambre, stun, reputación o selección. No se modifica código productivo para inyectarlos.
- Integración real con semilla **20260921**, la misma de Main, sin editar variables privadas de UpgradeSelector. La señal de cierre de oleada crea las ofertas y `select_upgrade` registra cada selección. Secuencia fijada mediante búsqueda previa por API pública: `second_chance`, `chain5_effect_boost`, `extra_bite`, `slow_salsa`, `taco_power_2`.
- El flujo `BoardView → Main → Resolver → LaneField` sirve 30 sin mejoras, 35 después de elegir extra_bite y 52.5 después de taco_power_2. Main resuelve además cadenas 5+ y LaneField aplica stun, burst y el servicio de veggie.
- Otra secuencia pública con la misma semilla (`last_stand`, `slow_salsa`, `chain4_boost`, `warm_welcome`) verifica que las condiciones siguen diferidas incluso en el primer platillo y con reputación al 19%; chain4_boost sí sirve 48. No se añade RNG al resolver ni al derivador.

## Validación local — 2026-09-29

Entorno: macOS, `Godot 4.7.2.stable.official.ed1daf0bf`. Ejecuciones con permisos del usuario para permitir acceso normal a la configuración del motor.

| Verificación | Resultado |
|---|---|
| Import headless `--editor --quit` | PASS, exit 0 |
| Bootstrap/Main `--scene res://scenes/Main.tscn --quit-after 3` | PASS, exit 0 |
| `recipe_resolver_test.gd` | PASS, REC-01 sin cambios en sus pruebas |
| `upgrade_modifiers_test.gd` | PASS, 963 comprobaciones |
| `lane_integration_test.gd` | PASS, regresión original intacta |
| `upg_02b_satisfaction_test.gd` | PASS, 607 comprobaciones |
| `bash tests/run_core_suite.sh` | PASS, 15/15 archivos |
| BOSS-01 / UI-01 / UI-02 | PASS |
| SAV-01 | PASS, 10 casos / 193 aserciones |
| SAV-02 | PASS, 29 casos / 1023 aserciones / 0 omisiones |
| `bash tests/run_restart_suite.sh` | AUTOMATED PASS, Main 10/10 y persistencia entre procesos |
| `git diff --check` | PASS |

La importación regeneró tres UID preexistentes ausentes de board, ya observados en UPG-02a; se excluyen de este PR. SAV-02 conserva los diagnósticos esperados de sus fixtures de exponentes extremos y UTF-8 inválido. No se observaron errores de script/motor en la validación funcional.

## Archivos, riesgos y pendientes

Modificados: `scripts/recipes/recipe_resolver.gd`, `scripts/main.gd`, `tests/run_core_suite.sh`. Creados: `tests/upg_02b_satisfaction_test.gd`, su `.uid` y este documento.

No se conocen regresiones funcionales en el alcance validado. La integración de pruebas emite cierres de oleada deterministas; no reemplaza validación física ni una partida manual completa. TST-02 comprueba reapertura de procesos, no el reinicio interno RST-01 todavía pendiente. El boost de veggie y las demás mejoras runtime siguen pendientes de sus bloques autorizados.

El estado final de CI y el enlace del PR se reportan en la entrega y en GitHub. Este documento acredita la ejecución local; abrir el PR no autoriza fusionarlo.
