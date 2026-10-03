# M3 — baseline ejecutable y deuda de validación

Fecha: 2026-10-03. Esta evidencia corresponde exclusivamente a
`61dfce343975eca377c778651234f940733a032a` (`uat`, cierre UPG-02, PR #53), antes de
implementar RUN-01/RST-01. No demuestra que el loop completo o el reinicio de una
partida activa estén implementados. Tampoco cierra M3 ni acredita dispositivo físico.

## Aislamiento y reproducción

Se exportó ese commit con `git archive` a `/private/tmp/m3-audit-baseline/project`.
La copia temporal usó un `override.cfg` con `config/name="M3AuditBaseline61dfce3"`.
Un probe confirmó que `OS.get_user_data_dir()` era
`~/Library/Application Support/Godot/app_userdata/M3AuditBaseline61dfce3`, distinto
del proyecto real. Los logs se dirigieron a `/private/tmp/m3-audit-baseline`.
Las suites Save conservan además sus fixtures temporales explícitas.

Godot local: `4.7.2.stable.official.ed1daf0bf`. Se ejecutaron, desde la copia:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --scene res://scenes/Main.tscn --quit-after 3
bash tests/run_core_suite.sh
godot --headless --path . --script res://tests/boss_encounter_test.gd
godot --headless --path . --script res://tests/reputation_test.gd
godot --headless --path . --script res://tests/feedback_test.gd
godot --headless --path . --script res://tests/save_service_test.gd
godot --headless --path . --script res://tests/save_recovery_test.gd
bash tests/run_restart_suite.sh
bash scripts/verify_tec01.sh
```

`GODOT_BIN` y `PATH` apuntaron a un wrapper temporal del binario instalado que
añadía `--log-file /private/tmp/m3-audit-baseline/engine.log`. No se modificaron
scripts, escenas, contenido ni persistencia del checkout para ejecutar el baseline.

## Resultados

| Verificación | Resultado |
|---|---|
| Importación y escena Main | PASS, exit 0; marcador de wiring presente |
| Core | **22/22 archivos PASS** |
| Board input, incluido en core | **398 checks PASS** |
| UPG-02a/b/c/d/e/f/g/h, incluidas en core | **963 / 607 / 406 / 526 / 692 / 400 / 268 / 1263 checks PASS** |
| BOSS-01 | PASS: quinta selección, unicidad, fases, satisfacción, breach y ausencia de wave 6 |
| UI-01 reputation/HUD | PASS |
| UI-02 feedback | PASS |
| SAV-01 | **10 casos / 193 assertions PASS** |
| SAV-02 | **29 casos / 1023 assertions PASS / 0 omisiones de plataforma** |
| TST-02 | **10/10 arranques Main PASS**, persistencia/recuperación entre procesos, cargas repetidas y temporal abandonado preservado |
| TEC-01 | PASS: versión, importación y escena Main |
| BoardView Smoke y LaneField Smoke | Sus scripts de pruebas y escena están cubiertos por las ejecuciones anteriores |

No se encontró `SCRIPT ERROR`, crash, fuga al salir, recurso retenido ni señal ya
conectada. SAV-02 emitió los cuatro avisos `Exponent too high` y el diagnóstico de
UTF-8 inválido esperados por sus fixtures corruptas; no son regresiones nuevas.
Los tests que ejercitan Main están dentro de las suites anteriores: no existe una
suite independiente denominada `main_test.gd` en este baseline.

Logs por runner, resultados estructurados y probes locales:
`/private/tmp/m3-audit-baseline/results.json` y archivos `*.log` vecinos. Son
evidencia temporal local, no artefactos duraderos de CI ni archivos para commitear.

## Seis observaciones heredadas de UPG-02

| Observación | Evidencia y clasificación |
|---|---|
| 1201 frente a 1263 | La entrega original UPG-02h tuvo 1201; los follow-ups de #53 agregaron 62. La suite actual pasa 1263. Se añade un apéndice a [UPG_02H_VALIDATION](UPG_02H_VALIDATION.md), preservando las cifras históricas de mutación. Documental, no bloqueante. |
| D8 e INP-01 | D8 conserva la referencia genérica a hardening IOS; el ticket concreto es [INP-01](../planning/BACKLOG.md). Este cambio documental no modifica DECISIONS, propiedad de RST-01 durante la sesión. |
| Helpers de BoardView | `_sync_cells()` asume propiedades de celda; `_refresh_selection()` asume `modulate`. El hit-test ya filtra hijos no Control, pero esos otros helpers no. La escena real construye solo Buttons: riesgo latente si se agregan otros hijos, sin fallo de gameplay observado. Refactor diferido. |
| Fixture N2 | El caso de gap expandido hereda `f=0.1` del último elemento del bucle `[0.0, 0.1]`. Pasa, pero depende del orden del fixture. Mejora test-only: fijar y comprobar 0.1 antes del caso. No se modifica aquí. |
| Historia D3 | La redacción original está en `26d352c`; la aclaración del primer spawn por corrida y del jefe antes del spawn está en `6f98c80` y se conserva en el baseline. La semántica vigente no necesita reversión. |
| Nombre de CI | El archivo vigente `.github/workflows/godot-smoke.yml` declara **Godot CI**. `Godot TEC-01 Smoke` es una referencia histórica que debe contrastarse con cada run remoto; no es el nombre del YAML auditado. |

## CI y límites

`Godot CI` usa Godot 4.7.2, Ubuntu y timeout de 10 minutos. Ejecuta importación,
Main, core, boss, reputation, feedback, SAV-01, SAV-02 y TST-02. Sus pushes
automáticos solo cubren `feature/**`; el evento `pull_request` depende de cambios
en project/scenes/scripts/tests/content o el propio workflow. Un PR solo documental
puede no dispararlo. `BoardView Smoke` y `LaneField Smoke` tienen filtros propios.
Esta auditoría acredita ejecución local, no un nuevo run remoto.

Al preparar RUN-01/RST-01 se debe repetir la regresión sobre sus SHAs y comprobar
la escena de arranque vigente. TST-02 acredita procesos nuevos; no sustituye los
tests de reemplazo de sesión dentro de la misma App. Los requisitos iOS pendientes
y el protocolo INP-01 están en [IOS_01_PREPARATION](IOS_01_PREPARATION.md).
