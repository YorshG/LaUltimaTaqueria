# Arquitectura propuesta

Godot 2D, versión estable a confirmar al iniciar implementación. Contenido dirigido por datos y simulación reproducible mediante una semilla registrable por partida.

## Árbol conceptual

```text
App
├── Navigation
├── GameSession
│   ├── LaneField
│   ├── Taqueria
│   ├── MatchBoard
│   ├── WaveDirector
│   ├── UpgradeSelector
│   └── HUD
├── ContentRegistry
├── SaveService
└── AudioService
```

## Responsabilidades

- `GameSession`: estado, semilla y transiciones de la partida.
- `MatchBoard`: entrada, cadenas, caída, relleno, detección de bloqueo y reorganización segura.
- `RecipeResolver`: convierte combinaciones en resultados.
- `LaneField`: movimiento, selección de objetivo y resolución.
- `WaveDirector`: agenda de spawns y finalización.
- `UpgradeSystem`: opciones y modificadores.
- `ContentRegistry`: valida y ofrece datos; rechaza IDs duplicados, referencias inexistentes, rangos inválidos, claves de localización ausentes y efectos fuera del catálogo cerrado.
- `SaveService`: récord, monedas y preferencias locales con esquema versionado, escritura atómica y recuperación segura.
- HUD: presentación; no contiene reglas.

## Eventos principales

`match_resolved`, `board_recovered`, `dish_created`, `dish_served`, `monster_satisfied`, `reputation_changed`, `wave_completed`, `upgrade_selected`, `run_ended`.

La lógica central debe probarse sin escenas visuales cuando sea posible. Las pruebas de tablero, ofertas y oleadas usarán semillas fijas; los reportes de errores incluirán semilla, build y commit cuando estén disponibles.

## Persistencia y recuperación

- El archivo local incluye versión de esquema y solo conserva récord, monedas como marcador y preferencias.
- La escritura se realiza de forma atómica para no reemplazar un estado válido con uno parcial.
- Un archivo ausente crea valores iniciales; uno parcial o corrupto se aparta o ignora de forma segura y no impide iniciar.
- No se persiste una partida en curso durante el prototipo.

## Rendimiento iOS

Objetivo provisional: 60 FPS, con modo aceptable a 30 FPS; sin asignaciones masivas por frame y con límites configurables de entidades y partículas. En M4 se medirán tiempo de frame, memoria, tiempo de carga y temperatura en el iPhone 17 con iOS 27.0, y se hará una prueba de humo adicional en el iPhone 16 Pro Max. Estos datos se registrarán junto con build, commit y versión de iOS; no se fijarán presupuestos adicionales sin medición.
