# UI-MOBILE-01 · consolidación en ART-01D

Rescate documental autorizado el 8 de octubre de 2026 desde #62, SHA `e894b438939e6260a4c8cc6c566373c351ddc2a7`. #62 permanece abierto/DRAFT e intacto. El texto histórico más abajo conserva la observación de Jorge registrada el 4 de octubre; **no es una prueba física nueva ni aceptación de ART-01D**.

La composición candidata actual es la de #63: `gameplay_layout.gd` y `safe_area_layout.gd`, controles adaptativos, feedback en cabecera, mostrador y tablero inferior. No se copian `App.tscn`, `Main.tscn`, los casts `VBoxContainer` ni el límite de reinicio ≤64 unidades de #62. Se recuperan assertions sobre rects reales: clientes arriba, tablero en mitad inferior y ≥300 unidades, reinicio y feedback sobre gameplay. Se añaden a core junto con la suite ART-01B de safe area/tamaño físico/modal/reinicio y ART-01D de gestos/selección/hambre.

`run_checked_godot.py` exige resumen único con checks > 0 y failures = 0 para estas suites, salida cero y ausencia de errores en stdout/stderr/log del motor. `run_mobile_guard_test.py` ejecuta un SCRIPT ERROR real seguido de un resumen positivo falso, cero checks, resumen ausente y control positivo; el runner debe rechazar los tres primeros. Los scripts recuperados tampoco devuelven cero si checks == 0.

Aceptación pendiente: Xavier/Jorge y repetir en iPhone 17 e iPhone 16 Pro Max. Véase [validación actual](art-01d/VALIDATION.md) y [matriz](art-01d/PR_MATRIX.md).

---

## Registro histórico de #62 (preservado)

# UI-MOBILE-01 — jerarquía móvil para iPhone

Fecha: 2026-10-04.

## Origen físico

Durante el primer smoke jugable real en iPhone 17, Jorge confirmó que el core loop es
usable en hardware: pudo enlazar cadenas, avanzar hasta wave 5, elegir mejoras y
modificar reputación. El problema principal observado fue visual/ergonómico:

- letras pequeñas en tablero y monstruos;
- el tablero queda demasiado arriba para juego continuo con una mano;
- clientes/monstruos compiten visualmente con la zona táctil;
- el botón de reinicio ocupa espacio permanente en el footer.

UI-MOBILE-01 responde a la preferencia física del jugador: **clientes arriba,
tablero abajo**.

## Alcance

Este cambio es de composición. No modifica:

- reglas de cadenas;
- hitboxes;
- selección de objetivos;
- velocidad de monstruos;
- oleadas;
- reputación;
- mejoras;
- balance;
- seeds;
- input touch/mouse.

La rama se apila sobre el PR #61 de legibilidad para no duplicar ese delta.

## Layout propuesto

Orden vertical dentro de Main:

1. HUD / estado de corrida;
2. clientes y monstruos (`LaneField`);
3. feedback;
4. tablero 5×5 (`BoardHost` / `BoardView`) en la mitad inferior.

En App:

- `RestartButton` deja de ser un footer de 88 px;
- pasa a una barra superior compacta, alineada a la derecha;
- `SessionHost` ocupa el resto de la pantalla.

## Validación automatizada

`tests/ui_mobile_layout_test.gd` instancia App a 1080×1620, 1080×1920 y
1080×2400 y verifica:

- TopBar antes de SessionHost;
- reinicio compacto;
- LaneField antes de BoardHost;
- clientes físicamente por encima del tablero;
- tablero con centro en la mitad inferior;
- tablero con tamaño mínimo jugable;
- feedback por encima del tablero.

La prueba se incorpora a `tests/run_core_suite.sh`.

## Validación física pendiente

La aceptación real depende de repetir la build en iPhone 17 y comparar con el
layout anterior.

Checklist:

- tablero alcanzable cómodamente con pulgar;
- clientes legibles sin que la mano tape el carril;
- tablero no queda comprimido;
- reinicio no estorba al gesto principal;
- mejora modal sigue legible;
- safe area superior/inferior no corta controles;
- al menos una partida hasta wave 5;
- idealmente boss/terminal/restart.

El safe area exacto **no se declara resuelto por desktop/headless**. Si la barra
superior invade notch/Dynamic Island o el tablero invade el Home Indicator, se
abrirá un ajuste específico basado en el rect físico observado.
