# UI-01 — entrega para revisión

## Base y alcance

- Base inicial de `origin/uat`: `6d8d625ca092bf4338806118321fa907f77604a3` (TST-01 integrado).
- Rama: `feature/ui-01-hud-reputation`.
- Exclusivamente reputación, breach, restauración veggie, HUD provisional y derrota lógica.
- UI-01 permanece pendiente en el backlog hasta revisión y cierre documental separado.

## Implementación y criterios

- `scripts/session/reputation_state.gd`: estado `RefCounted` por partida, sin nodos visuales, RNG ni timers. Inicia con `current = maximum = 100`; devuelve snapshots y resultados con valor previo, delta efectivo y transición a derrota. Rechaza magnitudes no positivas/no finitas y limita el resultado a `0..maximum`.
- El estado indexa daños de contenido validado: normales por `reputation_damage`, jefe por `reputation_damage_on_breach`. Identifica cada breach con `spawn_sequence`, único durante la vida de `LaneField`, y lo registra antes de emitir señales para impedir duplicados incluso reentrantes.
- `scripts/main.gd` mantiene el puente temporal reemplazable por GameSession. Procesa reputación antes de que WaveDirector pueda ofrecer una mejora por el último breach de la oleada. No modifica las reglas ni los payloads de LaneField, RecipeResolver o BOSS-01.
- La restauración requiere resolución válida con `special_effect_triggered` y `reputation_small_restore`, además de servicio exitoso con objetivo y payload `served`. Usa `amount` del resolver; aplica incluso si ese platillo satisface al jefe.
- `scenes/ui/Hud.tscn` y `scripts/ui/hud.gd`: texto numérico, barra y resultado provisional, sin lógica de juego. Fuente de 48 unidades, texto multilínea, cifras enteras sin decimales innecesarios y soporte de texto Unicode ampliado.
- `scenes/Main.tscn`: HUD en lugar del encabezado, dentro de los márgenes existentes (24 horizontales, 48 verticales). El contenedor del tablero pasa de COVER a FIT para mantenerlo en su espacio cuando crece el HUD; no cambia el tablero lógico.
- Llegar a cero fija derrota terminal, emite `run_ended` una sola vez (`outcome: defeat`, `reason: reputation_depleted`) y desactiva el procesamiento/entrada de Main y sus hijos. Eventos tardíos no restauran reputación ni inician jefe/ofertas. No se implementa pausa/reinicio.
- Satisfacer al jefe muestra `Victoria`. Un breach no letal del jefe conserva el cierre de BOSS-01 y descuenta reputación, sin inventar victoria ni derrota. Un breach letal cierra BOSS-01 y emite derrota, ambos una sola vez.

No se cambian decisiones aprobadas, datos de balance ni mejoras. No se implementa GameSession completo ni ninguna otra feature.

## Pruebas y resultados

Godot `4.7.2.stable.official.ed1daf0bf`, macOS, 2026-09-23:

| Verificación | Resultado |
|---|---|
| `godot --headless --path . --editor --quit` | PASS |
| `godot --headless --path . --scene res://scenes/Main.tscn --quit-after 3` | PASS |
| `bash tests/run_core_suite.sh` | PASS, 13/13 archivos |
| `godot --headless --path . --script res://tests/boss_encounter_test.gd` | PASS |
| `godot --headless --path . --script res://tests/reputation_test.gd` | PASS |
| `git diff --check` | PASS |
| Capturas con render Metal, ventana 540 × 960 | Inicio, daño y derrota legibles; sin solapamiento |

La nueva suite comprueba los 15 criterios pedidos: inicialización, daños 10/25/15/40, contenido alternativo validado sin hardcodes, clamp inferior/superior, duplicados, restauración 5+, cadenas 3/4, falta de objetivo, derrota única, HUD reactivo y cierres del jefe. Además cubre rechazo de NaN/infinito, resultados reproducibles, reentrada, servicio fallido, objetivos retirados, cadena 6+, derrota en último breach de oleada y platillo veggie que satisface al jefe.

Layout probado en lienzos verticales 1080 × 1620, 1080 × 1920 y 1080 × 2400, con texto español ampliado/Unicode y fuente aumentada a 64 unidades. Se verifican márgenes y ausencia de intersección con tablero/carriles.

CI añade sólo un paso UI-01 al workflow existente, después de BOSS-01. La suite central TST-01 no cambia.

## Límites y pendientes

- Falta validación física en iPhone; se respetan los márgenes del prototipo, sin añadir un sistema nuevo de insets nativos.
- Victoria es sólo presentación del cierre existente; no hay navegación ni pantalla final.
- `ReputationState` corresponde a una partida y un `LaneField`; una futura sesión creará otra instancia para otra partida.
- Las ejecuciones iniciales dentro del sandbox mostraron errores de permisos para logs/configuración de Godot. Las verificaciones finales se ejecutaron con los permisos adecuados y terminaron sin errores ni advertencias.
- No se detectaron regresiones. No se cambió `main`, no se aplicaron upgrades y no se inició UI-02 ni otra feature.
