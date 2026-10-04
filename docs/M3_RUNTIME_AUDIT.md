# Auditoría del loop M3 — 2026-10-03

## Baseline y procedencia

Después de `git fetch --all --prune`, `origin/uat` permanece en
`61dfce343975eca377c778651234f940733a032a` (PR #53) y `origin/main` en
`a6d88f4c4715a64614ddf3e0a220e76d65304339`. No hubo avance respecto de la misión.
Los PRs recientes #48–53 están fusionados; no se encontró asignación activa de
Claude en los archivos de este trabajo. El checkout previo sigue en
`codex/upg-02h-steady-hands`; sus nueve archivos sin seguimiento con sufijo ` 2`
son byte por byte idénticos a sus originales y se preservaron. Se trabaja en
worktrees nuevos desde `origin/uat`, sin alterar ese checkout.

Se revisaron README, backlog, decisiones, arquitectura, alcance, diseño, reglas,
modelo de contenido, colaboración, validaciones UPG-02a–h, escenas y suites.
El README aún describía preproducción; no representaba el código integrado.

## Flujo existente antes de RUN-01

Las rutas y números de línea de esta tabla corresponden exclusivamente al SHA
del baseline, no al código posterior del PR.

| Evento | Emisor | Receptor | Efecto | ¿Ruta productiva completa? |
|---|---|---|---|---|
| Arranque | `project.godot:10` | `scenes/Main.tscn`, `Main._ready` | Carga contenido, configura WaveDirector y arranca selector con seed fija | Parcial: director queda IDLE |
| Inicio wave_01 | Ninguno | `WaveDirector.start_wave` | Iniciaría agenda | No: sólo callers de pruebas |
| Cadena válida | `BoardView.chain_completed` | `Main._on_chain_completed` | Resolver → LaneField → reputación | Sí |
| Despacho de monstruo | `WaveDirector.advance` | `LaneField.spawn_runner` | Runner, secuencia, encuentro D3 | Sí, si alguien inicia la wave |
| Satisfacción / breach | LaneField | Main, WaveDirector | Daño primero; dedupe/resolución; cerrar agenda al resolver todos | Sí |
| Fin de oleada | `WaveDirector.wave_completed` | `Main._on_wave_completed` | Registrar cierre y pedir tres ofertas al selector | Sí, sin UI |
| Elegir mejora | Interacción de usuario inexistente | `UpgradeSelector.select_upgrade` | Valida ID ofrecido y emite selección | No: sólo callers de pruebas |
| Aplicar selección | `upgrade_selected` | `Main._on_upgrade_selected` | Derivar efectos y aplicar one-shots desde datos canónicos | Sí |
| Siguiente oleada | Ninguno | `WaveDirector.start_wave` | Continuaría orden | No |
| Quinta selección | Main + selector + cinco cierres reales | LaneField | Armar encuentro antes de crear jefe y emitir boss_started | Sí, alimentado manualmente por pruebas |
| Cambio de fase | MonsterState | Main | Velocidad de fase y feedback | Sí |
| Jefe satisfecho | LaneField | Main | HUD Victoria; `boss_encounter_completed(satisfied=true)` | Parcial: gameplay no se congelaba |
| Jefe en mostrador | LaneField | Main / reputación | Breach y `boss_encounter_completed(satisfied=false)` | Sí; puede quedar reputación positiva, no es victoria |
| Reputación cero | ReputationState | Main | `PROCESS_MODE_DISABLED`, `run_ended`, feedback terminal | Sí |
| Reiniciar | UI / host inexistentes | Nueva instancia de Main | Destruir runtime e iniciar limpio | No |

La búsqueda en `scripts/` y `scenes/` encontró sólo las definiciones de
`start_wave()` y `select_upgrade()`, sin llamadas productivas. En
`tests/upgrade_selector_integration_test.gd:72`, el baseline incluso exige
“Main must not auto-start a wave”. Los helpers BOSS/UPG inician waves y eligen
por API explícitamente. Esas pruebas son válidas para módulos, pero no prueban
una partida iniciada desde la aplicación. El hallazgo de Xavier es correcto.

## Orden y fronteras de implementación

Se elige **B: RST-01 → RUN-01**. App puede ser una frontera estable y pequeña:
instancia Main, escucha `run_ended` y `boss_encounter_completed`, administra su
modal y reemplaza toda la sesión. No necesita conocer oleadas, ofertas,
modificadores ni el futuro estado del loop. Todo ese estado permanece bajo Main.
El análisis de ownership y D9 se documentan en la entrega RST-01.

Ambos PRs parten del mismo `uat` confirmado. RST-01 posee App, configuración de
arranque, documentación D9/arquitectura, suite y workflow propios. RUN-01 posee
Main, UI de selección, fixtures/suite de loop, backlog y este informe. No hay
archivos compartidos editados entre ramas. RUN puede ejecutarse desde Main sin
App; App puede reemplazar el Main actual sin RUN. Por eso el desarrollo puede
proseguir sin fingir una dependencia ya integrada ni hacer ramas conflictivas.
La validación combinada se realiza en una copia temporal y se identifica como
tal; no es evidencia de que `uat` ya contenga ambos PRs.

La producción inicia el loop por defecto. Las pruebas históricas que controlan
manualmente el director usan una opción explícita antes de instanciar el árbol;
se conserva su cobertura de los contratos de módulos. Las nuevas pruebas
ejercitan el comportamiento productivo predeterminado y las intenciones de UI.

`boss_encounter_completed` conserva el significado del payload: satisfacción
es victoria; breach con reputación positiva es encuentro finalizado sin victoria.
No se fuerza reputación cero ni se crea otra wave. El reinicio terminal permite
una partida nueva en ambos casos. No se modifica balance ni el objetivo temporal.

## Verificación y límites

El baseline se importó antes de ejecutar scripts: una caché ausente puede
provocar `SCRIPT ERROR` y aun así Godot devolver exit 0. La aceptación exige
marcador de éxito y ausencia de errores de script, no sólo código de salida.
Baseline: core 22/22; board_input 398; UPG-02a–h
963/607/406/526/692/400/268/1263; boss, reputation, feedback, SAV-01 (10/193),
SAV-02 (29/1023/0 skips), TST-02 (10/10 Main y persistencia), TEC-01 y Main PASS.
SAV-02 conserva diagnósticos esperados de fixtures corruptos. Las pruebas usan
datos de usuario aislados y no modifican la metapersistencia personal.

La evidencia de la implementación, mutaciones y duración diagnosticada se
registra en `RUN_01_VALIDATION.md`; RST-01 se entrega en su PR propio. M3 sigue
pendiente de revisión independiente, integración de ambos, medición de partida
real y validación física. Esta auditoría no atribuye PASS a un iPhone ni autoriza
merge o promoción a `main`.

## Hallazgo visual preexistente

Una partida automática renderizada con Godot/OpenGL en macOS confirmó que los
runners satisfechos/inactivos permanecen dibujados: LaneRunner/LaneField los
retiran lógicamente, pero no ocultan sus controles. Al final se superponen varias
letras M/B. No causa targets elegibles, spawns extra ni selección repetida, pero
reduce legibilidad y merece un seguimiento de presentación antes de pruebas con
usuarios. No se mezcla un refactor de carriles con los contratos RUN/RST.
Las capturas también verificaron tres opciones localizadas legibles y el CTA de
App accesible bajo la oferta. Esto acredita render desktop, no ergonomía iPhone.
