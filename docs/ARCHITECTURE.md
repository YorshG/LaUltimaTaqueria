# Arquitectura del prototipo

Godot 4.7.2 stable, 2D y GDScript. Contenido dirigido por datos y simulación reproducible mediante una semilla registrable por partida.

## Árbol conceptual histórico

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

UPG-02 añade `extra_life_consumed` para `second_chance` (D5 en `docs/DECISIONS.md`).

La lógica central debe probarse sin escenas visuales cuando sea posible. Las pruebas de tablero, ofertas y oleadas usarán semillas fijas; los reportes de errores incluirán semilla, build y commit cuando estén disponibles.

## Persistencia y recuperación

- El archivo local incluye versión de esquema y solo conserva récord, monedas como marcador y preferencias.
- La escritura se realiza de forma atómica para no reemplazar un estado válido con uno parcial.
- Un archivo ausente crea valores iniciales; uno parcial o corrupto se aparta o ignora de forma segura y no impide iniciar.
- No se persiste una partida en curso durante el prototipo.

## Rendimiento iOS

Objetivo provisional: 60 FPS, con modo aceptable a 30 FPS; sin asignaciones masivas por frame y con límites configurables de entidades y partículas. En M4 se medirán tiempo de frame, memoria, tiempo de carga y temperatura en el iPhone 17 con iOS 27.0, y se hará una prueba de humo adicional en el iPhone 16 Pro Max. Estos datos se registrarán junto con build, commit y versión de iOS; no se fijarán presupuestos adicionales sin medición.

## Frontera de lifecycle implementada — RST-01 / D9

El árbol conceptual anterior sigue siendo una distribución de responsabilidades,
no una afirmación de que Navigation o GameSession ya existan como módulos.
El runtime del prototipo ahora arranca en `scenes/App.tscn`:

```text
App (lifecycle y confirmación)
├── Layout
│   ├── SessionHost
│   │   └── Main (una instancia por partida)
│   │       ├── BoardView / BoardState / ChainPath
│   │       ├── LaneField / LaneRunner / MonsterState / LaneMotion
│   │       ├── WaveDirector
│   │       ├── UpgradeSelector
│   │       ├── HUD / FeedbackLayer / FeedbackAudio
│   │       └── RecipeResolver / ReputationState / FeedbackCoordinator
│   └── Reiniciar / Nueva partida
└── Confirmación de reinicio
```

`Main` conserva el wiring temporal de la partida. App no inicia oleadas, selecciona
mejoras, deriva efectos ni determina resultados. Observa `run_ended` y
`boss_encounter_completed` para distinguir partida activa de terminal. Las
conexiones se crean antes de añadir Main al árbol; un inicio productivo desde
`Main._ready()` queda dentro del mismo contrato.

El host suspende el subtree completo durante la confirmación, incluidos nodos
con modo `ALWAYS` y streams de audio. Conserva y restaura los valores anteriores
al cancelar; no limpia una cadena pendiente ni reescribe RNG, clocks u ofertas.
El modal queda fuera de ese subtree. Confirmar retira y libera la instancia
anterior antes de activar la nueva, sin espera ni `queue_free`. La reconstrucción
restaura las semillas por defecto y todos los estados runtime, también los de
futuros hijos de Main.

SaveService mantiene su responsabilidad de metapersistencia fuera de esta
operación. App no lo carga ni escribe; no se guarda/restaura una partida activa.
La implementación de reinicio no acredita por sí sola el loop jugable M3: su
orquestación continúa siendo responsabilidad de Main y del ticket RUN-01.
