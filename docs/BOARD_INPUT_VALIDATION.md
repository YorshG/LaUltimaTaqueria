# BoardView — conversión de coordenadas GUI

Baseline: `origin/uat = ae14c90e72bf4d514bd55af0c84f78755926273d`.
Rama: `fix/board-gui-local-coordinates`, PR draft exclusivamente a `uat`.
`origin/main = a6d88f4c4715a64614ddf3e0a220e76d65304339` permanece intacto.
PR50/head `fac8132427e94c8817fa2b20a4df2c0399dde3b3` no recibe commits.

## Problema reproducido

`_gui_input()` recibe la posición relativa a BoardView. `_coord_at_position()`
la comparaba directamente con `get_global_rect()` de cada celda. En Main, una
pulsación real enviada por `Viewport.push_input()` a la primera celda llegó a
BoardView en `(81, 81)` mientras su centro global era `(685, 504)` y el origen del
tablero `(604, 423)`: el hit-test devolvió `(-1, -1)`. Se reprodujo con mouse y touch.
La prueba nueva falló contra el código original: 280/316 checks. En su versión
final, que añade resize vivo y verifica cero upgrades, quitar la conversión
produce 350/398 fallos de assertions y exit 1, sin errores de script.

El contrato de posiciones locales está documentado en [Control._gui_input](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-private-method-gui-input) y fue confirmado en el motor local con ambos tipos de evento.

## Corrección y alcance

Se transforma una vez el punto de BoardView al espacio de canvas mediante
`get_global_transform() * position` antes de contrastarlo con los mismos
rectángulos de celdas. Conserva rectángulos, exclusión de gaps, orden de
recorrido, reglas ortogonales y relleno determinista. No añade margen,
`input_forgiveness`, desempate, selección alternativa, balance ni UPG-02h.
No cambia workflows. La prueba se agrega al entry point central existente.

Antes de editar se verificaron status/branch/SHAs y remotos. El único PR abierto
era PR50, cuyo diff no toca BoardView. El historial remoto de BoardView desde
2026-09-28 no tenía commits. Los commits divergentes antiguos de BRD son trabajo
histórico, no un PR activo ni una asignación vigente encontrada.

## Verificación local

Godot `4.7.2.stable.official.ed1daf0bf`, macOS `27.0.1`.

| Comando | Resultado |
|---|---|
| `godot --headless --path . --editor --quit` | exit 0, sin diagnósticos |
| `godot --headless --path . --script res://tests/board_input_test.gd` | 3 corridas finales, 398 checks por corrida, exit 0 |
| `bash tests/run_core_suite.sh` | 20/20, exit 0; baseline uat tiene 19 y se añade una prueba |
| `bash tests/run_restart_suite.sh` | exit 0, 10/10 ciclos Main y persistencia entre procesos |
| `boss_encounter_test.gd`, `reputation_test.gd`, `feedback_test.gd` | exit 0 cada una |
| `save_service_test.gd` | exit 0, 10 casos / 193 assertions |
| `save_recovery_test.gd` | exit 0, 29 casos / 1023 assertions / 0 skips |
| Compatibilidad en worktree desechable del head exacto de PR50 | suite central 21/21, incluidos 398 checks input y 268 UPG-02g; exit 0; ensayo restaurado |
| `git diff --check` | exit 0 |

La prueba usa el dispatch real de un SubViewport, no llama `_gui_input()` ni el
helper de hit-test directamente. Verifica las 25 celdas con ambos tipos de
entrada, 4 bordes y 4 esquinas, gaps, ventanas 1080×1620/1920/2400, resize vivo,
traslación y escala no uniforme. Traza una cadena real, rechaza diagonal y
repetición, y compara caída/relleno con BoardState usando la misma semilla.

Los únicos avisos de aceptación provienen de SAV-02: cuatro `Exponent too high`
y un diagnóstico UTF-8 para fixtures deliberadamente corruptas existentes.
No se modifican esas fixtures ni assertions. Se retiraron los tres UID de board
preexistentes ausentes del baseline que Godot regeneró; se entrega sólo el UID
correspondiente al nuevo test.

Logs, comandos completos, exits y duraciones se conservan fuera del checkout
habitual en el directorio de auditoría de esta sesión. CI remoto y SHA final se
reportan en el PR; una ejecución headless no acredita validación táctil física
en iPhone ni exportación iOS. El PR queda draft y no se fusiona.
