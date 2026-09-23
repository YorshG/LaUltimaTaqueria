# UI-02 — feedback audiovisual provisional para revisión

## Base y alcance

- `origin/uat` inicial: `26798b7be2e05df60bf735ed075d706ae1c4fde8`.
- Rama: `feature/ui-02-provisional-feedback`.
- `origin/main` observado antes de implementar: `a6d88f4c4715a64614ddf3e0a220e76d65304339`; no se modifica ni promueve.
- UI-02 queda pendiente en el backlog para revisión y cierre separado. No se implementa UPG-02 ni otra feature.

## Arquitectura y archivos

`señales de gameplay → FeedbackCoordinator → FeedbackLayer + FeedbackAudio`

- `scripts/ui/feedback_coordinator.gd`: `RefCounted` sin nodos de audio o presentación; traduce señales a payloads semánticos con `cue_id`, `text_key`, `values`, `sound_id` y `terminal`. No llama métodos de gameplay ni modifica los payloads originales.
- `scripts/ui/feedback_layer.gd` y `scenes/ui/FeedbackLayer.tscn`: franja dentro del VBox y los márgenes existentes, bajo el HUD. Mantiene cuatro mensajes recientes, sin overlays, flashes, movimiento, color semántico ni timers. Texto de 40 unidades, multilínea y Unicode; filas mínimas reservadas para reducir cambios de distribución. Los eventos síncronos de receta/servicio/satisfacción quedan visibles juntos. Repeticiones consecutivas idénticas se agrupan.
- `scripts/ui/feedback_audio.gd`: un único `AudioStreamPlayer`, síntesis PCM nativa en memoria y cola acotada. Su procesamiento continúa después de la derrota exclusivamente para reproducir el cue final; gameplay conserva el bloqueo de UI-01.
- `scripts/main.gd` y `scenes/Main.tscn`: wiring temporal. Los observadores se conectan antes de los callbacks de gameplay que emiten eventos síncronos para que breach preceda al delta y derrota; satisfacción precede a victoria. No cambian los contratos existentes.
- `data/content/localization.es-MX.json`: añade 13 claves `feedback.*`; conserva todos los textos anteriores.
- `tests/feedback_test.gd` y `.github/workflows/godot-smoke.yml`: nueva suite y un solo paso de CI, sin reestructurar TST-01.
- `docs/DECISIONS.md`: registra el umbral exclusivamente de presentación. Este documento registra implementación y verificaciones. Se incluyen los `.uid` de los cuatro scripts nuevos.

No cambian BoardView, ChainPath, RecipeResolver, LaneField, MonsterState, ReputationState, WaveDirector, UpgradeSelector ni el HUD de UI-01.

## Cues completos

| ID sonoro | Clave visual | Texto es-MX | Sonido provisional |
|---|---|---|---|
| `selection` | `feedback.selection` | → Selección iniciada | Pulso 440 Hz |
| `chain_valid` | `feedback.chain_valid` | ✓ Cadena lista | Dos tonos 660→880 Hz |
| `dish_created` | `feedback.dish_created` | + Platillo listo | Dos tonos 520→650 Hz |
| `dish_served` | `feedback.dish_served` | → Servido | Pulso 1000 Hz |
| `satisfied` | `feedback.monster_satisfied` | ✓ Satisfecho | Tres tonos 660→830→990 Hz |
| `breach` | `feedback.breach` | ! Llegó al mostrador | Dos tonos graves 220→140 Hz |
| `low_reputation` | `feedback.low_reputation` | ! Reputación baja | Dos pulsos 330 Hz |
| `upgrade` | `feedback.upgrade_selected` | ↑ Mejora elegida | Dos tonos 740→1110 Hz |
| `boss_phase_2` | `feedback.boss_phase_2` | ! El Gran Glotón acelera | Dos tonos 260→390 Hz |
| `boss_phase_3` | `feedback.boss_phase_3` | !! El Gran Glotón: máxima velocidad | Tres tonos 260→390→520 Hz |
| `victory` | `feedback.victory` | ✓ Victoria | Tres tonos 523→659→784 Hz |
| `defeat` | `feedback.defeat` | ! Derrota | Tres tonos 294→220→147 Hz |
| Sin sonido adicional | `feedback.reputation_delta` | Reputación {delta} | Sólo visual: usa el delta de UI-01, sin recalcular daño |

La selección suena una vez al empezar, sin sonido por movimiento. `chain_valid` se emite la primera vez que alcanza 3; extender a 4/5/6 no repite. Completar/cancelar rearma el próximo gesto. Breaches/satisfacciones repetidos se agrupan por `spawn_sequence`. Las fases usan los tags existentes; `calm` no es cambio de fase y no genera aviso. No se añade ninguna mecánica de fase.

## Audio y saturación

Se usa `AudioStreamWAV` como contenedor nativo equivalente al generador: admite PCM generado dinámicamente en memoria ([documentación de Godot](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html)). No se cargan ni escriben archivos WAV/MP3/OGG.

Síntesis determinista de senos, mono, 16 bits, 22050 Hz, con ataque/liberación breves y 10 ms de separación entre notas; volumen de reproducción −14 dB. Cada cue dura menos de 0.5 s y su PCM se cachea al primer uso. No hay RNG, dependencias, assets externos ni generación continua por frame.

Un solo reproductor con polifonía 1. Conserva como máximo cuatro cues pendientes; repeticiones del cue actual o ya pendiente se agrupan. Cuando se llena, descarta el pendiente más antiguo para admitir el más reciente. Victoria/derrota interrumpen, vacían la cola y excluyen eventos posteriores. La franja visual no depende de que el cue entre en la cola sonora.

En headless se desactiva la salida por defecto. La propiedad interna `playback_enabled` permite probar silencio sin añadir settings. Las pruebas de reproducción activan explícitamente el reproductor usando el driver Dummy; no requieren altavoces. La partida no espera respuestas ni finalización del audio.

## Reputación baja

Umbral provisional de UI: `current / maximum <= 0.20`. No cambia balance, activa upgrades ni afecta daño o satisfacción. Se inicializa desde el snapshot y sólo avisa al pasar de encima al rango bajo; permanecer debajo no repite. Recuperarse por encima rearma el siguiente cruce. Llegar directamente a cero también cruza el rango; derrota tiene prioridad sonora y queda como último mensaje. No se crea bucle de alarma.

## Validación — 2026-09-23

Godot `4.7.2.stable.official.ed1daf0bf`, macOS:

| Verificación | Resultado |
|---|---|
| `godot --headless --path . --editor --quit` | PASS |
| `godot --headless --path . --scene res://scenes/Main.tscn --quit-after 3` | PASS |
| `bash tests/run_core_suite.sh` | PASS, 13/13 |
| BOSS-01: `tests/boss_encounter_test.gd` | PASS |
| UI-01: `tests/reputation_test.gd` | PASS |
| UI-02: `tests/feedback_test.gd` | PASS |
| `git diff --check` | PASS |
| Ejecución gráfica con Metal y reproductor nativo | PASS, sin errores |

La suite UI-02 cubre los 18 criterios solicitados: selección/gesto, cadena válida única, nuevo gesto, receta, servicio, satisfacción, breach distinto, cruce de reputación baja, supresión mientras permanece baja, mejora sin aplicar efectos, fases 2/3, victoria/derrota, correspondencia visual de todos los sonidos, invariancia del gameplay y funcionamiento sin dispositivo de audio. Adicionalmente verifica duplicados, recuperación y nuevo cruce, ratio con máximo distinto, PCM determinista/distinto/acotado, silencio en sus extremos, cola limitada, prioridad terminal y reproducción tras desactivar Main.

La comparación de gameplay repite el mismo escenario con observadores desconectados, feedback silencioso y audio Dummy: snapshots idénticos de tablero, reputación, hambre, avance, velocidad, oleada y mejoras almacenadas.

Layout automatizado en 1080×1620, 1080×1920 y 1080×2400, fuente aumentada a 56 y texto Unicode expandido: feedback dentro de márgenes, sin intersección con HUD/tablero/carriles, etiquetas contenidas y contenido dentro del borde inferior. Capturas revisadas con ventana 540×960: servicio, breach/reputación baja, fases, victoria y derrota. Captura adicional 540×810 con cuatro mensajes largos/fuente ampliada: sin recorte ni solapamiento, pero se reduce el área del tablero. Los mensajes se distinguen mediante palabras y símbolos sin depender del color o el audio.

## Límites y pendientes

- Validación física en iPhone y evaluación perceptual de volumen/distinción de tonos en sus altavoces pendientes; no bloquean abrir este PR.
- La franja guarda cuatro eventos recientes; ráfagas descartan mensajes/cues antiguos de forma acotada. No es un registro completo de la partida.
- Mucha expansión de texto reduce espacio disponible del tablero; falta comprobar comodidad táctil en dispositivo. No se añade una pantalla de accesibilidad ni settings.
- La importación inicial regeneró tres `.uid` ajenos a UI-02; se retiran de la entrega. Las verificaciones finales terminaron sin errores ni advertencias.
- No se detectaron regresiones. Sin aplicación de mejoras, producción audiovisual final, música, persistencia, iOS export ni GameSession completo.
