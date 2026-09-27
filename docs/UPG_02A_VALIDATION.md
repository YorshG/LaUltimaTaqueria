# UPG-02a — Agregación pura de modificadores

## Alcance y baseline

- Baseline de integración: `uat = 67b6ac33b7dda9c3c8f06e89d57d46a9a282663f`, confirmado después de fetch y pull fast-forward, con árbol limpio.
- Rama: `feature/upg-02a-modifiers`; destino del PR: exclusivamente `uat`, sin merge.
- `origin/main` se conserva en `a6d88f4c4715a64614ddf3e0a220e76d65304339`.
- No cambia decisiones aprobadas, contenido, selección/ofertas ni gameplay. UPG-02 sigue pendiente de sus siguientes bloques; no se inicia UPG-02b, RST-01 ni IOS-01.

## API

`UpgradeModifiers.derive(active_effects: Array) -> Dictionary` es estática sobre un helper `RefCounted`, sin estado runtime. Recibe el formato de `UpgradeSelector.get_active_effects()` (`upgrade_id`, `effect`). Solo consulta constantes del esquema de `ContentRegistry`; no instancia el registro ni carga archivos.

Éxito: `{"ok": true, "modifiers": {...}, "conditional_multipliers": [...]}`.

| Modificador continuo | Operación | Neutral |
|---|---|---|
| `satisfaction_flat_bonus` | add | 0.0 |
| `chain4_satisfaction_bonus` | add | 0.0 |
| `satisfaction_multiplier` | multiply | 1.0 |
| `special_effect_power_multiplier` | multiply | 1.0 |
| `chain4_splash_satisfaction` | add | 0.0 |
| `monster_speed_global` | multiply | 1.0 |
| `input_forgiveness` | add | 0.0 |
| `reputation_damage_taken` | multiply | 1.0 |

La reducción se ordena por `upgrade_id` antes de operar, sin redondeos. Los pares stat/operation y tipos se contrastan con el catálogo congelado. Los IDs duplicados son entradas estructuralmente inválidas; no se comprueban conflictos, elegibilidad ni cantidad de selecciones.

Cada condicional contiene `upgrade_id`, `stat`, `operation`, `value` y `params` con `condition` y, solo para `reputation_below_ratio`, `threshold`. La colección también se ordena por ID. Se conserva el umbral 0.20 de `last_stand` sin evaluarlo; su futuro consumidor debe respetar `< 20%`, distinto del `<= 20%` visual. `warm_welcome` conserva `first_dish_of_encounter`. Ninguno altera el multiplicador incondicional.

`reputation_max`, `reputation_shield_charges` y `extra_life_charges` se validan pero se omiten de la salida. Este helper no concede, consume ni registra efectos de una sola vez. Su aplicación futura corresponde al evento de selección y `selection_number`.

La salida usa objetos nuevos y no muta ni comparte contenedores con la entrada. Ante datos inválidos o desbordamiento devuelve `{"ok": false, "error": "INVALID_ACTIVE_EFFECTS", "message": ...}`, sin resultado parcial. No evalúa condiciones ni usa RNG, escenas, nodos, timers o estado global.

## Evidencia de aceptación — 2026-09-27

Entorno: macOS, `Godot 4.7.2.stable.official.ed1daf0bf`.

| Verificación | Resultado |
|---|---|
| `godot --headless --path . --editor --quit` | PASS, código 0, sin errores en la ejecución con permisos normales |
| `godot --headless --path . --script res://tests/upgrade_modifiers_test.gd` | PASS dos veces consecutivas; 963 comprobaciones por ejecución |
| `bash tests/run_core_suite.sh` | PASS, 14/14 archivos, incluida la nueva suite |
| `upgrade_selector_test.gd` | PASS dentro de la suite central |
| `upgrade_selector_integration_test.gd` | PASS dentro de la suite central |
| `git diff --check` | PASS |

La nueva suite cubre valores neutros; los diez efectos continuos reales por separado; los dos condicionales; omisión individual y repetida de los tres efectos de una sola vez; suma y multiplicación sin redondeos; 720 permutaciones de seis efectos sintéticos con IDs distintos; orden de inserción de diccionarios; repetición; aislamiento de entrada/salida; snapshots reales de cinco selecciones para tres semillas; errores estructurales, valores no finitos y desbordamiento.

No se exige seleccionar parejas prohibidas del catálogo para demostrar acumulación. No hay cambios en archivos de gameplay ni en `data/content/upgrades.json`.

## Hallazgos y límites

La primera ejecución bajo sandbox pasó las comprobaciones, pero Godot reportó acceso restringido a logs, certificados y ajustes de usuario. La importación y las ejecuciones de aceptación se repitieron fuera de esa restricción y finalizaron sin esos errores. Se excluyen del PR tres `.uid` preexistentes ausentes que el editor regeneró para archivos ajenos a UPG-02a.

No hay riesgos funcionales nuevos conocidos en este alcance puro. Queda pendiente conectar los modificadores y evaluar condiciones en los siguientes bloques autorizados de UPG-02. Esta entrega no valida esos efectos en gameplay ni en dispositivo físico.
