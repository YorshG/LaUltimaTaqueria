# UPG-02h — steady_hands

Validación: 2026-10-01. Godot local `4.7.2.stable.official.ed1daf0bf`, macOS.
Alcance exclusivo UPG-02h; PR draft a `uat`, sin merge.

## Baseline y aislamiento

Se ejecutó `git fetch --all --prune` antes de editar:

- `origin/uat`: `e1d864bf95f658f19764e0d25ebd2d3f9f8f7c6e`, exactamente el baseline aprobado.
- `origin/main`: `a6d88f4c4715a64614ddf3e0a220e76d65304339`, intacto.
- `main` local previo: `f17fd38abc1aa18a430bebecf655833ac5d572f7`, conservado sin sincronizar ni editar.
- Working tree inicial limpio. No había PRs abiertos ni ramas UPG-02h duplicadas.
- Rama creada desde el baseline: `codex/upg-02h-steady-hands`.

Se revisaron AGENTS, alcance congelado, colaboración y decisiones. No se encontraron
asignaciones activas a Claude sobre los archivos autorizados. No se reescribe #50/#51
ni se implementan RST-01 o IOS-01. El SHA final y la URL del PR se reportan en la entrega.

## Fórmula y arquitectura D8

BoardView conserva la conversión única de #51:

```text
p = get_global_transform() * local_position
R_i = cell.get_global_rect()
m_i = f * min(R_i.size.x, R_i.size.y)
E_i = R_i.grow(m_i)
```

El margen completo se agrega a cada lado. Puntos, rects, centros, márgenes y
distancias se calculan en canvas; no se usan tamaños locales para expandir.

`BoardView.cell_index_at_canvas_position()` es estático y puro. Recibe punto,
rects en orden row-major y forgiveness; devuelve un índice o -1. Primero devuelve
el primer hit en un rect original. Si no hubo hit y `f <= 0`, termina inmediatamente,
sin fase expandida. Con `f > 0`, considera únicamente los rects expandidos que
contienen el punto, elige la distancia cuadrada estrictamente menor (`<`) y deja
los empates exactos al primer índice row-major. No usa epsilon ni `is_equal_approx`.
El helper no conoce ingredientes, ChainPath, viewport ni estado de partida.

BoardView posee `_input_forgiveness`, inicialmente 0. Su setter acepta exclusivamente
int/float finitos en [0,1], asigna absolutamente y rechaza sin mutar. El getter
permite consultar ese estado sin una segunda copia en Main. `reset_with_seed()`
lo conserva: pertenece a la corrida. DECISIONS registra que RST-01 deberá restaurarlo.

Main agrega únicamente el setter en el bloque de stats continuos, después de velocidad
y damage multiplier y antes de guards de selección, one-shots, derrota y boss.
Ante rechazo devuelve `INVALID_INPUT_FORGIVENESS`. La selección pública real de
`steady_hands` activa inmediatamente 0.10; repetir señal/setter no acumula.

## Archivos autorizados

1. `scripts/board/board_view.gd`: estado runtime, setter/getter, helper geométrico y hit-test.
2. `scripts/main.gd`: dos líneas de wiring continuo y error explícito.
3. `tests/upg_02h_steady_hands_test.gd`: suite determinista.
4. `tests/upg_02h_steady_hands_test.gd.uid`: UID del único script nuevo.
5. `tests/run_core_suite.sh`: añade UPG-02h sin retirar suites.
6. `docs/UPG_02H_VALIDATION.md`: evidencia y límites.
7. `docs/DECISIONS.md`: D8 y estado de corrida para futuro RST-01.
8. `data/content/upgrades.json`: únicamente `notes` de `steady_hands`.

No cambian ChainPath, BoardState, escena/layout, project/input emulation,
UpgradeModifiers, UpgradeSelector, registry, LaneField/Motion/Runner, RecipeResolver,
reputación, feedback, HUD, waves, boss, localization, balance ni el valor 0.10.

## Matriz de pruebas

Suite nueva final: **1201 checks PASS**, tanto directa como dentro de core.

| Contrato | Cobertura |
|---|---|
| Setter | Inicial 0; int/float; extremos 0/1; 0.1 repetido; rechazo de NaN, Inf, -Inf, -0.1, 1.5, texto, null, bool, array y dictionary sin mutar |
| Geometría pura | 25 rects sintéticos; centros originales; límites semiabiertos; grid vacío; f=0; margen completo; m-0.1/m+0.1 |
| Hit exacto prioritario | A 100×100; B 81×81 empieza en x=108; x=99.95 pertenece a A pero B expandida tiene centro más cercano: gana A |
| Solapamiento | Horizontal, vertical, esquina; gana centro más cercano |
| Empates | Horizontal izquierda, vertical arriba, cuatro equidistantes menor índice row-major |
| Casi empate | Delta de distancia cuadrada aproximadamente 1.6e-3; gana la distancia realmente menor |
| Tamaños diferentes | 100×200, 99×100 y 81×100; margen propio por celda y lado menor |
| Input real | Mouse y touch por `SubViewport.push_input()`, sin llamar `_gui_input()` directamente |
| Layouts | 1080×1620, 1080×1920, 1080×2400, 720×1280; resize vivo de 1080×1920 a 720×1280 |
| Traslación/escala | Host en (140,200), escala (1.25,0.8); margen canvas 7.040 frente a local 7.800; punto entre ambos los distingue en geometría y dispatch real |
| Neutralidad | 25 centros por mouse/touch, bordes/esquinas/gaps y suite #51 intacta, 398 checks |
| Selección pública | WaveDirector → oferta real de UpgradeSelector → `select_upgrade("steady_hands")` → señal → Main → setter; hit antes falla y después funciona |
| Idempotencia | Reemisión de señal y setter repetido; punto exterior a 15% distingue 0.10 de 0.20 |
| Wiring | Refresh antes de guards de selección inválida, boss iniciado y derrota; fixture con valor derivado 1.5 comprueba error y preservación del valor efectivo |
| Corrida | `reset_with_seed()` conserva 0.10 |
| ChainPath | Mismo ingrediente, adyacencia ortogonal, diagonal/repetición/ingrediente distinto rechazados; mínimo 3; corta cancelada; válida completa una sola vez |
| Refill | Cadena mediante input real con forgiveness; snapshot idéntico a BoardState con seed 20260920 y mismos puntos |

Las assertions geométricas usan resultados esperados explícitos; la neutralidad #51
no se modifica. Las consultas directas al hit-test runtime complementan el dispatch
para distinguir límites geométricos de los límites de enrutamiento del Control.

## Mutation-style

Nueve mutaciones independientes temporales de BoardView; restauración byte por byte
después de cada ejecución y al terminar. Main y la suite permanecieron intactos.
Las ocho mutaciones con cambio de comportamiento fallaron por assertions (exit 1),
sin `SCRIPT ERROR`, crash ni fugas. El código restaurado pasó nuevamente 1201 checks.

| Mutación | Checks fallidos / 1201 | Assertions representativas |
|---|---:|---|
| Repartir margen a la mitad | 60 | Margen completo por lado; m-0.1; celdas de tamaños distintos |
| Lado mayor en lugar del menor | 10 | 99×100; 100×200; escala; m+0.1 |
| Margen calculado con tamaños locales | 7 | Punto que distingue canvas/local, incluido mouse y touch transformados |
| Primera coincidencia expandida | 66 | Nearest-center; cadenas reales; refill |
| Empate con `is_equal_approx` | 1 | Casi empate: debe ganar la distancia estrictamente menor |
| Invertir row-major usando `<=` | 3 | Empates horizontal, vertical y cuatro celdas |
| Quitar prioridad exacta para f>0 | 1 | Fixture desigual donde vecino expandido tiene centro más cercano |
| Setter incremental | 72 | Asignación absoluta, neutralidad, reemisión y banda 0.10 vs 0.20 |
| Ejecutar fase expandida con f=0 | 0 | Mutante equivalente en resultados: `grow(0)` conserva R y los hits exactos ya retornaron |

La última mutación terminó exit 0. El contrato de no hacer trabajo expandido a f=0
se verificó por inspección del guard restaurado, no se atribuye falsamente a una
assertion de comportamiento. El helper puro no expone contadores de trabajo ni
efectos observables; no se añadió instrumentación productiva para detectar esta
optimización. Se informa como límite de la cobertura de mutaciones. No se conservan
mutantes ni framework/logs de mutación dentro del repositorio.

## Regresión final

| Runner / suite | Resultado |
|---|---|
| `bash scripts/verify_tec01.sh` | PASS, importación Godot y bootstrap Main |
| `bash tests/run_core_suite.sh` | **22/22 PASS** |
| `board_input_test.gd` directo, intacto | **398 checks PASS** |
| `upg_02h_steady_hands_test.gd` directo | **1201 checks PASS** |
| `upg_02g_assist_serve_test.gd` directo | **268 checks PASS** |
| UPG-02a/b/c/d/e/f en core | 963 / 607 / 406 / 526 / 692 / 400 checks PASS |
| `boss_encounter_test.gd` | PASS |
| `reputation_test.gd` | PASS |
| `feedback_test.gd` | PASS |
| `save_service_test.gd` | 10 casos / 193 assertions PASS |
| `save_recovery_test.gd` | 29 casos / 1023 assertions PASS, 0 platform skips |
| `bash tests/run_restart_suite.sh` | PASS; 10/10 reinicios Main, persistencia y recuperación entre procesos |
| Smoke Board existente | BoardView, ChainPath, refill y playability incluidos en core: PASS |
| `git diff --check` | PASS |

R1 conserva boss creado síncronamente en **300/300** y splash vacío. R2 conserva
**2 resueltos, 0 pendientes y una finalización**. No se cambian esas suites ni la
implementación de #50; #51 conserva su única conversión de coordenadas y su neutralidad.

## Warnings y pendientes

Bloqueantes encontrados: ninguno.

La primera importación recreó los tres UID ausentes preexistentes de BoardState,
board_playability_test y board_refill_test. Se retiran al finalizar; solo se entrega
el UID nuevo de UPG-02h. SAV-02 emite cuatro `Exponent too high` y un diagnóstico
UTF-8 al leer fixtures deliberadamente corruptas. No hubo errores de script,
fugas ni recursos retenidos en las suites finales.

La banda exterior a 1080×2400 mide **1.800 canvas px**: la geometría acepta el
punto dentro de E pero el press inicial queda fuera de BoardView y no se despacha.
D8 acepta este límite; no se cambia escena/layout ni la semántica del drag iniciado.

Con 0.10 casi desaparecen zonas muertas internas. Un trazo diagonal cercano a una
esquina puede capturar un vecino ortogonal del mismo ingrediente; es consecuencia
válida del forgiveness. ChainPath conserva sus reglas. Queda pendiente evaluación
perceptual/comfort en dispositivo, no se trata como blocker automático.

Touch + mouse emulado con `emulate_mouse_from_touch` podría duplicar `chain_started`.
No se cambia emulación ni deduplicación. Ambos eventos resuelven la misma coordenada
en las pruebas separadas. Se registra para hardening de dispositivo / IOS y prueba
física en iPhone, todavía pendiente. No se realizó exportación iOS ni validación táctil
física. Canvas transform distinto de identidad, rotación y escala negativa mantienen
los límites previos; D8 no amplía ese alcance.

Logs completos, exits y detalle de assertions mutantes quedan fuera del checkout en
`/private/tmp/upg02h-validation.qJoWBF`. La entrega final registra SHA/PR, scope,
higiene y estado remoto. CI remoto se reporta por separado, sin inferirlo del éxito local.
