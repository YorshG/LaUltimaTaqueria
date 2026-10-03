# RST-01 — Reinicio de partida con host App

Fecha: 2026-10-03. Base inspeccionada: `61dfce343975eca377c778651234f940733a032a`
(`uat`). Rama: `feature/rst-01-restart-session`. D9 fue aprobada expresamente por
el Product Owner y revisada en misión III para distinguir retiro síncrono de
destrucción al final del frame; la revisión queda registrada en DECISIONS. Esta entrega no promueve `main` ni `uat`.

## Objetivo y frontera

Reiniciar una partida activa requiere confirmar. Cancelar conserva exactamente
su estado lógico. Confirmar deshabilita y retira inmediatamente el Main anterior,
encola su destrucción al final del frame e instala uno nuevo dentro de la misma
llamada, con las semillas deterministas existentes. No promete invalidez inmediata. Un resultado terminal permite
reinicio directo. La UI provisional permanece disponible aunque Main se
encuentre deshabilitado por derrota.

Se eligió RST-01 antes de RUN-01 porque App proporciona una frontera estable:
Main conserva todos los componentes y puede alojar el loop productivo sin que
App conozca oleadas, mejoras o reglas. RST-01 por sí solo no cierra M3. No se
implementa GameSession ni un framework de navegación.

## Reglas, propiedad e inventario auditados

Se leyeron AGENTS, PROTOTYPE_SCOPE, DECISIONS, CORE_RULES, ARCHITECTURE,
COLLABORATION, BACKLOG y el protocolo TST-02 antes de editar. No se encontró
propiedad activa de Claude sobre los archivos asignados. La propiedad de esta
rama fue explícitamente delimitada a App, configuración de arranque, pruebas y
workflow nuevos, y documentación D9/RST/arquitectura. Main, módulos de gameplay,
SaveService, contenido y pruebas existentes quedaron fuera de la edición.

| Propietario por partida | Estado que una reconstrucción descarta |
|---|---|
| Main | Boss y referencia a runner, mapas de oleadas/completadas y breach, `_encounter_token`, `_first_dish_pending`, modo terminal |
| ReputationState | Actual/máximo, derrota, escudos, vidas/ratio, multiplicador de daño y dedupe de breaches/selecciones |
| BoardView / BoardState / ChainPath | Tablero y RNG, semilla, cadena/drag, `input_forgiveness` |
| WaveDirector | Estado/pausa, countdown y elapsed, agenda/índices, runners y pendientes, contadores y emisión de cierre |
| UpgradeSelector | RNG, ofertas, selecciones, IDs bloqueados, defensa fuerte y oleadas consumidas |
| LaneField / runners | Spawn sequence, referencias a entidades, velocidad global; hambre, fases, avance, stun y flags one-shot |
| FeedbackCoordinator / FeedbackLayer | Dedupe, gesto, reputación baja, terminal e historial |
| FeedbackAudio / HUD | `_terminal`, cola/current cue/streams, reproducción y labels de resultado |

Los resets individuales eran insuficientes: BoardView conserva forgiveness y
cadena; LaneMotion conserva multiplicadores; WaveDirector.configure no limpia
todos sus contadores; UpgradeSelector no sustituye una run activa; el setter de
audio no rearma `_terminal`. No existían Timer/Tween/coroutines productivos de
gameplay en el baseline: los relojes son floats de WaveDirector y LaneMotion.
La suite agrega un Timer real `ALWAYS` debajo de Main para verificar ownership
futuro, suspensión y destrucción. Las señales son internas al subtree o conectan
RefCounted de la misma run; retener esos RefCounted desde una prueba no permite
modificar la nueva sesión: sus receptores pertenecen al subtree retirado y los
callbacks del host comprueban la generación, incluso antes de su destrucción.

## Implementación

- `scenes/App.tscn`, `scripts/app.gd`: host, CTA inferior y modal provisional.
- `project.godot`: `run/main_scene` apunta a App.
- `tests/restart_session_test.gd`: matriz determinista y stress configurable.
- `tests/restart_meta_probe.gd`, `tests/run_restart_mutations.py`: sentinel en
  `user://` exclusivamente aislado y mutaciones en copias descartables.
- `.github/workflows/restart-session.yml`: arranque configurado, matriz,
  sentinel y mutaciones en CI, con inspección de diagnostics además del exit code.
- `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`, este documento: contrato y evidencia.

El modal guarda `process_mode` de cada nodo y `stream_paused` de reproductores;
suspende todo el subtree, incluso hijos `ALWAYS`. Cancelar restaura los valores
exactos. App no llama a helpers de tablero ni termina/cancela la cadena. Los
botones del modal permanecen fuera del subtree suspendido.

El reemplazo construye una instancia aún fuera del árbol, deshabilita y retira
la anterior, programa `queue_free`, conecta señales terminales de la nueva y
sólo entonces la añade. Al retornar, la nueva es la única sesión activa/oficial;
la anterior queda fuera del árbol, deshabilitada y pendiente de destrucción.
Después de un frame queda inválida. No se difiere el comando de reinicio. Un
guard cubre también observadores reentrantes de `session_replaced`. Confirmar
sin modal es un no-op. Solicitudes repetidas durante el modal no lo duplican. Una segunda activación
del CTA tras reinicio terminal encuentra una nueva run activa y abre una sola
confirmación; no ejecuta otro reinicio. No hay guards basados en frame count.

## Matriz de 30 casos

| Caso | Comprobación |
|---|---|
| 01 | Activa requiere modal visible y conserva identidad |
| 02 | Cancelación conserva snapshot fuerte: RNG, cadena, clocks, ofertas, efectos, reputación, entidades, feedback y HUD |
| 03 | Identidad nueva y generación +1; anterior fuera del árbol/deshabilitado/encolado inmediatamente e inválido después de un frame |
| 04 | Reputación/máximo y dedupe limpios |
| 05 | Estado, agenda, contadores y relojes de oleada limpios |
| 06 | Tablero, RNG y cadena iniciales |
| 07 | Selecciones, conflictos, ofertas, defensa fuerte y RNG iniciales |
| 08 | Efectos runtime ya aplicados de velocidad, mitigación y máximo neutralizados |
| 09 | Escudos realmente otorgados por selección no heredados |
| 10 | Vida/ratio de second_chance realmente otorgados no heredados |
| 11 | Forgiveness realmente aplicado por steady_hands vuelve a cero |
| 12 | Encounter token y primer platillo vuelven al estado inicial |
| 13 | Jefe real queda fuera de gameplay inmediatamente y destruido después de un frame |
| 14 | Runner anterior fuera del árbol/inactivo; sus señales no afectan new; inválido después de un frame |
| 15 | Timer anterior fuera del árbol/inactivo, inválido después de un frame y sin timeout posterior |
| 16 | Cardinalidad de conexiones de gameplay/feedback sin duplicados |
| 17 | Audio terminal real de derrota; nueva sesión acepta y reproduce selection |
| 18 | Derrota y ambos cierres terminales de jefe permiten reinicio directo |
| 19 | Confirmaciones dobles, CTA terminal duplicado y observador reentrante no duplican sesión |
| 20 | 20 reemplazos con número constante de nodos y un solo hijo de SessionHost |
| 21 | 20 reemplazos con número constante de listeners |
| 22 | Seeds por defecto reproducen snapshot lógico inicial |
| 23 | Meta aislada intacta; driver adicional verifica el DEFAULT_SAVE_PATH real de una copia aislada |
| 24 | Modal congela WaveDirector, avance/stun, Timer ALWAYS y cola/audio |
| 25 | Cancelación restaura procesamiento/reloj original y el modal deja de bloquear |
| 26 | Señales de nodos y ReputationState/FeedbackCoordinator anteriores no alteran la nueva run, antes de destrucción |
| 27 | `run_ended` real → listener → restart instala new síncronamente; old se destruye tras retornar al frame |
| 28 | `boss_encounter_completed` real, satisfecho y escape → listener → restart, sin liberar emisor locked |
| 29 | Listener terminal pide restart dos veces: generación +1 y solo confirmación para la nueva run |
| 30 | Callbacks de generación anterior y señales old no cambian snapshot, CTA ni terminal de new |

El input mouse/touch se envía por `SubViewport.push_input`: apertura desde el CTA,
release/drag contra tablero cubierto, cancelación y confirmación desde botones
reales. Una cadena válida pendiente sobrevive cancelar sin completarse por el
release del modal. La quinta selección usa ofertas reales y los efectos se
verifican antes de reiniciar. Fixtures de legacy controlan manualmente el reloj;
si Main ofrece `auto_start_run`, la factoría de pruebas lo desactiva antes de
`_ready`. La escena productiva se instancia además sin esa factoría.

## Metapersistencia y mutaciones

La suite directa usa un archivo temporal explícito y comprueba ausencia de I/O
en App; eso solo no demostraría ausencia de acceso indirecto al save por defecto.
Por eso el driver crea una copia del proyecto y un directorio de usuario cuyo
nombre es un UUID `rst_01_isolated_*`. El probe exige configuración custom,
marcador de copia, nombre exacto de directorio y marcador de usuario antes de
usar `Save.new()` sin ruta alternativa. Récord 987, monedas 654 y preferencia de
audio se conservan byte a byte tras 40 reinicios y 20 cancelaciones. El driver
elimina exclusivamente su directorio UUID marcado al terminar. Nunca usa el
`user://` del proyecto real.

Seis mutaciones aisladas prueban sensibilidad, sin editar/restaurar el checkout:

| Defecto inyectado | Fallo exigido |
|---|---|
| Omitir `remove_child` | RST-03, old debe estar fuera del árbol y new ser el único hijo |
| Omitir deshabilitar old | RST-28, emisor boss retirado debe estar deshabilitado |
| Omitir `queue_free` | RST-03, old debe ser inválido después de un frame |
| Ignorar generación en callback terminal | RST-26, señales old no deben cambiar terminal de new |
| Omitir suspensión del subtree | RST-24, reloj/Timer avanzan bajo modal |
| Instanciar audio con latch terminal activo | RST-17, cue nuevo rechazado |

El driver exige baseline limpio, fallo no cero, assertion específica y ausencia
de errores de sintaxis en cada mutante. Los logs de engine van a temporales;
las copias se retiran automáticamente y el source checkout queda sin cambios.

## Evidencia histórica previa a A-LC-01

Los resultados de esta sección corresponden al head auditado `d4f0dcd` con
D9 original y no acreditan la corrección nueva. La revalidación de misión III
se registra separadamente al final.

Todos los comandos terminaron con exit 0 y se inspeccionaron diagnostics del
engine; no hubo `SCRIPT ERROR`, `ERROR`, objetos filtrados ni recursos en uso al
salir. La regresión completa pasó y, después de retirar un guard de frame en
favor de estado explícito, se repitieron App, matriz RST, sentinel/mutaciones y
stress sobre el árbol final.

| Comando / comprobación | Resultado local |
|---|---|
| `bash scripts/verify_tec01.sh` | PASS; Godot 4.7.2, import y bootstrap legacy Main |
| `godot --headless --path . --quit-after 3` | PASS; escena configurada App |
| `bash tests/run_core_suite.sh` | PASS; 22/22 archivos, incluyendo board_input 398, UPG-02h 1263 y UPG-02g 268 checks |
| Boss / reputation / feedback | PASS; suites independientes existentes |
| Save service / save recovery | PASS; 193 / 1023 assertions, 0 platform skips |
| `bash tests/run_restart_suite.sh` | PASS; Main 10/10 y persistencia/recuperación entre procesos |
| `godot --headless --path . --script res://tests/restart_session_test.gd` | PASS; 26/26 casos, 166 checks, 20 reemplazos |
| `python3 tests/run_restart_mutations.py` | PASS; baseline, bootstrap real, sentinel default aislado, 3/3 mutantes detectados por assertions previstas |
| `godot --headless --path . --script res://tests/restart_session_test.gd -- --cycles=200` | PASS; 706 checks, 200 reemplazos, nodos/listeners constantes |
| Revisión de diff, whitespace y sintaxis Python | PASS |

CI remoto, SHA del commit entregado y URL del PR se completan en la publicación.
No se presentan estas ejecuciones locales como validación de un head futuro.

## Límites y pendientes

La composición final con RUN-01 se verificó en
`/private/tmp/m3-combined-final-nmsa2y76/project`, con manifest SHA256 de fuentes,
metapersistencia aislada y sin modificar refs de integración. Pasaron core23,
RUN376, boss/reputación/feedback, SAV193/1023, TST-02, TEC-01, App y matriz RST166,
incluidos sentinel y mutaciones. Un cambio posterior del texto que reporta el
número de ciclos se sincronizó y verificó de nuevo con el checker RST.

El bot de RUN ejecutó el motor real con renderer Metal 4.0 / Forward Mobile en M2:
confirmar/cancelar durante oleada, oferta y boss; bloqueo de callback UI bajo el
modal sin dejar opciones deshabilitadas; vuelta a wave_01 sin mejoras ni boss;
partida completa posterior, victoria y reinicio directo. Log:
`/private/tmp/m3-final-render-bot.log`. Las capturas del modal sobre la oferta se
inspeccionaron visualmente. Esta evidencia acredita composición desktop, no un
merge ya realizado ni prueba de iPhone.

No se realizó prueba táctil física, medición iOS, audio percibido ni validación
de rendimiento. Los tiempos cortos de la prueba son esperas del test, no timers
nuevos del producto. Los snapshots comparan tiempo lógico; elapsed de pared y
timestamps absolutos de RUN-01 son medición externa y no se comparan entre runs.
La pausa por pérdida de foco y el hardening de touch/mouse emulado siguen sus
tickets propios. La revisión de integración con RUN-01 debe ejecutar el loop
productivo completo con App, además de las fixtures de componentes.

## Misión III — corrección A-LC-01 y D9 revisada

El PO aprobó `remove_child + queue_free` el 2026-10-03 17:01 CST
(Slack `1791068509.283679`), después de la confirmación independiente de Xavier.
La promesa corregida es retiro inmediato del gameplay, no invalidez inmediata
del objeto. El comando de reinicio completo sigue siendo síncrono.

Se añadieron seis recorridos reales: derrota, boss satisfecho y boss escapado,
cada uno con uno o dos requests dentro del listener terminal. Verifican estado
inmediato, una generación, callbacks viejos inefectivos y destrucción posterior.
Las fixtures de #55 controlan sus oleadas; la composición con #56/#58 debe
verificar además el loop productivo, y su bot se adapta solo en copia privada.

Resultado del repro mínimo, con el mismo harness y Godot 4.7.2:

| Observación | Head auditado `d4f0dcd` | Corrección actual |
|---|---|---|
| Exit code | 0, con `Object is locked` / `Attempted to free a locked object` | 0, sin diagnostics |
| Al retornar del listener | Host 0, generación 1, `_replacing=true`, sin new oficial | Host 1, generación 2, new oficial/listo, `_replacing=false` |
| Old inmediatamente | Válido/fuera del árbol, sin destrucción programada | Válido/fuera del árbol/deshabilitado/encolado |
| Tras un frame | Old todavía válido; host vacío | Old inválido; new sigue oficial |

Revalidación de #55 sobre copia privada con `user://` aislado; se verificaron
códigos de salida, markers y ausencia de diagnostics incluso cuando exit es 0:

| Comprobación | Resultado |
|---|---|
| Import desde copia sin `.godot` y bootstrap configurado App | PASS |
| RST completo | PASS, 30/30 casos, 257 checks |
| Stress RST `--cycles=200` | PASS, 977 checks; old inválido al frame siguiente en cada ciclo; nodos/listeners constantes |
| Sentinel default aislado | PASS, bytes intactos tras 40 reinicios y 20 cancelaciones |
| Mutaciones revisadas | PASS, 6/6 rechazadas por las assertions previstas, sin script/parse errors |
| Core | PASS, 22/22 archivos; incluye Board input 398 y UPG-02a–h |
| Boss, reputación y feedback | PASS |
| SAV-01 / SAV-02 | PASS, 193 / 1023 assertions, cero platform skips |
| TST-02 | PASS, Main 10/10 y persistencia/recuperación entre procesos |
| TEC-01 | PASS |

Evidencia durable local bajo
`/Users/jorgeguinto/.codex/visualizations/2026/10/03/01a102b2-6978-7bf2-9486-9c7a39741eb2/M3_MISSION_III/lifecycle/`:
`manifest.json` (hashes de archivos probados), `results.json`,
`alc01-before-after.json`, logs por suite y por paso de mutación. Un rechazo
inicial del wrapper por buscar «Reputation tests passed» en lugar del marker
real «UI-01 tests passed» se conserva en `results-initial-reputation-marker.json`;
se corrigió contra el log exitoso existente, sin cambiar producto ni suite.

El coordinador verificó la composición privada `uat + #55 corregida + #56 + #58`
en `/private/tmp/m3-mission3-rc`: 25 jobs PASS, core23, RUN376, RST30, VIS189,
seis mutantes VIS, Board398, UPG-02a–h, boss/reputación/feedback, SAV193/1023,
TST, TEC, App y bot completo. Repitió además los seis mutantes RST y el sentinel
con el driver final. Evidencia: `M3_MISSION_III/composition/rc/summary.json`.
Las dos expectativas del bot sobre invalidez inmediata se adaptaron solo en
esa copia privada al contrato completo D9; no se editó el head #56. Los resultados
de burn-in y CI remoto se reportan con sus manifests finales por el coordinador.
Esta composición no es un merge ni autoriza promoción de ramas.
