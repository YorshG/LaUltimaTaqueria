# Arquitectura propuesta

Godot 2D, versión estable a confirmar al iniciar implementación. Contenido dirigido por datos.

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

- `GameSession`: estado y transiciones de la partida.
- `MatchBoard`: entrada, cadenas, caída y relleno.
- `RecipeResolver`: convierte combinaciones en resultados.
- `LaneField`: movimiento, selección de objetivo y resolución.
- `WaveDirector`: agenda de spawns y finalización.
- `UpgradeSystem`: opciones y modificadores.
- `ContentRegistry`: valida y ofrece datos.
- `SaveService`: récord, monedas y preferencias locales.
- HUD: presentación; no contiene reglas.

## Eventos principales

`match_resolved`, `dish_created`, `dish_served`, `monster_satisfied`, `reputation_changed`, `wave_completed`, `upgrade_selected`, `run_ended`.

La lógica central debe probarse sin escenas visuales cuando sea posible. Objetivo provisional: 60 FPS, con modo aceptable a 30 FPS; sin asignaciones masivas por frame y con límites configurables de entidades/partículas.
