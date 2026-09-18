# Propuesta inicial de contenido y balance

Estado del documento: **propuesta para revisión — v3, actualizada tras alinear contratos con `docs/preproduction` (segunda corrección de Codex/YorshG en el PR #2)**. No integrada ni aprobada como código. Todos los valores numéricos son hipótesis ajustables (ver `docs/PROTOTYPE_SCOPE.md` y `prompts/CLAUDE_KICKOFF.md`). Este documento no modifica arquitectura, no agrega monetización, servidores, cuentas ni multijugador, y no contiene código de juego.

Convenciones usadas en todo el documento:

- **[Decisión aprobada]** — ya registrado en `docs/DECISIONS.md` o derivado directo de reglas vigentes.
- **[Decisión de revisión PR #2]** — confirmado explícitamente por el dueño del repositorio en la revisión de esta propuesta; pendiente de que se registre formalmente en `docs/DECISIONS.md` si así lo deciden.
- **[Hipótesis]** — propuesta de este documento, sujeta a prueba y ajuste.
- **[Alternativa]** — camino distinto que no se eligió como propuesta principal, incluido para discusión.

Identificadores técnicos en **inglés** `snake_case` (corregido en esta revisión: la v1 usaba palabras en español como `tanque_salsero`, `chapulin_veloz`, `carne`, `verdura` — quedan renombrados abajo). Texto visible al jugador en español. Ningún estado depende solo del color.

---

## 0. Resumen de supuestos heredados y cambios de esta revisión

- **[Decisión aprobada]** Tablero 5×5, tres carriles, cadenas ortogonales de 3+ ingredientes iguales, cadena de 4 = +50% satisfacción, cadena de 5+ = efecto especial por ingrediente (`docs/CORE_RULES.md`).
- **[Decisión aprobada]** Se alimenta, no se mata. Tono familiar, mexicano, respetuoso, exportable (`docs/GAME_DESIGN.md`).
- **[Hipótesis, ya marcada como tal en CORE_RULES]** Reputación inicial: 100.
- **[Decisión de revisión PR #2]** Duración objetivo de partida actualizada del objetivo anterior más corto a **4–5 minutos**, tras revisar que la suma de oleadas + pausas + jefe de la v1 excedía ese objetivo anterior.
- **[Decisión de revisión PR #2]** Se confirma que la pausa de selección de mejora (una de tres) ocurre también después de la oleada 5, antes de iniciar el combate contra el jefe.
- **[Decisión aprobada]** Recetas mixtas quedan fuera del prototipo hasta validar la combinación básica; todas las recetas de esta propuesta usan un único ingrediente por cadena.

### Cambios respecto a la v1 (resumen de la revisión)

1. Todos los identificadores técnicos se corrigieron a inglés `snake_case` (monstruos, jefe, ingredientes, recetas, mejoras, efectos).
2. Se eliminó `chain_facil` (contradecía la regla de cadena mínima 3+) y se reemplazó por `chain4_boost`, que refuerza esa misma regla en vez de contradecirla.
3. Se eliminó `cadena_dorada` (introducía azar donde las cadenas 5+ son deterministas) y se reemplazó por `chain5_effect_boost`, determinista.
4. Se eliminaron cinco mejoras señaladas como de impacto táctico poco claro dentro de una sola partida: `propina_doble`, `propina_doble_plus`, `relleno_extra`, `resistencia_inicial`, `ojo_certero` (esta última además cambiaba la regla fija de objetivo "más cercano" de `docs/CORE_RULES.md`, lo cual no corresponde a una mejora de contenido). Se reemplazaron por cinco mejoras nuevas con efecto claro dentro de la partida: `extra_bite`, `patient_service`, `assist_serve`, `warm_welcome`, `last_stand`.
5. Se etiquetaron las defensas fuertes (`safety_shield`, `patient_service`, `second_chance`) con `"tags":["safety"]` y se limitó a una por partida mediante `conflicts` cruzados entre las tres.
6. Se aclaró explícitamente que `reputation_boost` no cura: solo aumenta el máximo de reputación en el momento de elegirla.
7. Se reescribió el comportamiento de "olfateo" del jefe para que sea puramente cosmético (animación + sonido de anticipación), sin afectar el objetivo automático fijo ("más cercano", con desempate central/izquierdo/derecho de `docs/CORE_RULES.md`).
8. Se movió el campo `"teaches"` dentro de los bloques JSON de las oleadas 3, 4 y 5 (en la v1 quedaba fuera del JSON, solo en el texto).
9. Se suavizó la afirmación de "oleada 1 sin superposición de monstruos" a hipótesis validable, ya que depende de la unidad de velocidad real que aún no está definida (ver pregunta abierta existente sobre `speed`).

### Cambios respecto a la v2 (segunda corrección del PR #2, alineación con contratos de `docs/preproduction`)

1. Se renombró la etiqueta de defensas fuertes de `safety` a `strong_defense`, alineada con el contrato ahora definido en `docs/CONTENT_MODEL.md` y `docs/CORE_RULES.md`.
2. El límite de una defensa fuerte por partida pasa a documentarse principalmente como regla del sistema de generación de ofertas (excluye el resto de mejoras `strong_defense` tras seleccionar una); los `conflicts` cruzados entre `safety_shield`, `patient_service` y `second_chance` se conservan como validación redundante, no como mecanismo principal.
3. Se eliminó por completo el gesto cosmético repetido de "olfateo" del jefe en fase 2. La transición al 60% de hambre restante ahora se comunica con una animación y sonido breves, únicos, en el momento del cambio de fase.
4. Se aclaró que las animaciones de transición de fases 2 y 3 son solo retroalimentación visual/sonora: no detienen la simulación ni el avance del jefe.
5. Se retiró la mención literal a "~3 minutos" como duración histórica; se describe ahora como "el objetivo anterior más corto".
6. Se eliminó la pregunta abierta sobre la claridad del olfateo cosmético (ya no aplica) y la pregunta sobre el mecanismo de límite de defensas fuertes, ya que esta revisión lo resuelve explícitamente.

---

## 1. Monstruos iniciales

Tres monstruos con arquetipos claramente diferenciados: **básico/enseñanza**, **tanque lento** y **amenaza veloz**. Ninguno introduce mecánicas nuevas de movimiento (sin cambio de carril, sin resistencias elementales, sin alterar el objetivo automático fijo).

### 1.1 Nibbler (mordisqueador)

- **Silueta:** criatura redonda, boca grande, orejas caídas; la más pequeña de las tres.
- **Personalidad:** glotón torpe y adorable, sin maldad; se emociona al oler comida.
- **Comportamiento:** avanza a ritmo constante por su carril; si su hambre baja de 30%, muerde el aire con ansiedad (animación de anticipación).
- **Rol estratégico:** enseña el gesto básico de cadena de 3 y el autoapuntado. Es el "metrónomo" de dificultad.
- **Señales de hambre/satisfacción:** ícono de plato vacío sobre la cabeza cuando tiene hambre alta; se llena progresivamente al recibir platillos; al quedar satisfecho, sale con confeti. No depende solo de color (forma de ícono + barra numérica opcional).

```json
{"id":"nibbler","display_name_key":"monster.nibbler","tags":["basic"],"speed":55,"hunger":30,"reputation_damage":10,"initial_value_hypothesis":true}
```

### 1.2 Salsa tank (antes "tanque salsero")

- **Silueta:** criatura ancha, panzona, caparazón de tortilla dorada gruesa; la más grande.
- **Personalidad:** tranquilo, terco, no se distrae ni se apura; disfruta despacio.
- **Comportamiento:** avanza lento y de forma predecible; no cambia de velocidad por sí mismo. Requiere hambre alta acumulada.
- **Rol estratégico:** enseña que cadenas de 4–5 son más eficientes contra objetivos de hambre alta. Si llega al mostrador, el golpe de reputación es severo.
- **Señales de hambre/satisfacción:** panza translúcida tipo "medidor" con patrón de rayas (no solo color) que se vacía conforme baja su hambre; sonido grave al vaciarse del todo.

```json
{"id":"salsa_tank","display_name_key":"monster.salsa_tank","tags":["tank","slow"],"speed":30,"hunger":70,"reputation_damage":25,"initial_value_hypothesis":true}
```

### 1.3 Swift hopper (antes "chapulín veloz")

- **Silueta:** criatura delgada, patas largas tipo resorte, siempre en movimiento.
- **Personalidad:** nervioso, juguetón, ríe y brinca; no es agresivo, solo muy inquieto.
- **Comportamiento:** avanza mucho más rápido que los otros dos; no cambia de carril (mecánica descartada, ver alternativa 1.3.a). Ventana de reacción corta.
- **Rol estratégico:** enseña reacción rápida y priorización cuando compite por atención con otro monstruo en pantalla.
- **Señales de hambre/satisfacción:** estela de movimiento que se acorta conforme se satisface; ícono de resorte con signo de exclamación como alerta temprana (no depende del color).

```json
{"id":"swift_hopper","display_name_key":"monster.swift_hopper","tags":["fast","priority"],"speed":90,"hunger":18,"reputation_damage":15,"initial_value_hypothesis":true}
```

> **[Alternativa 1.3.a]** Se consideró que `swift_hopper` cambiara de carril a mitad de recorrido. Se descarta por ser una mecánica nueva no descrita en `docs/CORE_RULES.md`. Queda como alternativa futura, no aprobada.

---

## 2. Jefe

### Big glutton (antes "El Gran Glotón", `boss_big_glutton`)

- **Identidad:** el monstruo más grande y viejo de la invasión; tono cómico-solemne, nunca amenazante de forma violenta.
- **Comportamiento general:** aparece solo, ocupa el carril central, hambre total 300 (como en `docs/CONTENT_MODEL.md`). Se alimenta igual que cualquier monstruo: el objetivo automático sigue siendo el fijo de `docs/CORE_RULES.md` (más cercano al mostrador, desempate central/izquierdo/derecho). El jefe no cambia esa regla.
- **Fases (por umbral de hambre restante):**
  1. **Fase 1 (100%–60%):** velocidad normal, come con calma.
  2. **Fase 2 (60%–30%):** velocidad 1.25×. Al cruzar el umbral del 60% de hambre restante, una animación y sonido breves comunican directamente el cambio de fase (la aceleración); es una señal única en el momento de la transición, no un gesto repetido de anticipación. Esta animación no detiene la simulación ni el avance del jefe.
  3. **Fase 3 (30%–0%):** velocidad 1.4×, con una breve animación de transición (sin penalización ni beneficio de juego, solo retroalimentación visual/sonora). Esta animación tampoco detiene la simulación ni el avance del jefe.
- **Contrajuego:** resistencia y ritmo, no "arma correcta" — no hay resistencias a ingredientes específicos.
- **Comunicación anticipada:** barra de hambre del jefe siempre visible; las señales de transición de fase 2 (60%) y fase 3 (30%) son animación y sonido breves, sin pausar la simulación ni el avance del jefe.

```json
{"id":"boss_big_glutton","display_name_key":"boss.big_glutton","hunger":300,"reputation_damage_on_breach":40,"lane":1,"phases":[{"threshold":1.0,"speed_multiplier":1.0,"behavior_tag":"calm"},{"threshold":0.6,"speed_multiplier":1.25,"behavior_tag":"phase2_transition_cue_cosmetic_only"},{"threshold":0.3,"speed_multiplier":1.4,"behavior_tag":"final_bite"}]}
```

> **[Hipótesis]** El jefe ocupa siempre el carril central y no genera monstruos adicionales durante su combate. **[Alternativa]** invocar refuerzos en fase 3 se descarta por ampliar el alcance de contenido y de IA de spawn.

---

## 3. Oleadas iniciales (5)

Numeración de carriles: `0` = izquierdo, `1` = central, `2` = derecho (consistente con el desempate de `docs/CORE_RULES.md`).

### Oleada 1 — Introducción

```json
{"id":"wave_01","duration_target_sec":25,"spawns":[{"at_sec":2,"monster_id":"nibbler","lane":1},{"at_sec":8,"monster_id":"nibbler","lane":0},{"at_sec":14,"monster_id":"nibbler","lane":2},{"at_sec":20,"monster_id":"nibbler","lane":1}],"teaches":"basic_match"}
```
Solo `nibbler`. **[Hipótesis, no garantía]** El espaciado de 6–8 s entre apariciones busca evitar que dos `nibbler` compartan pantalla a la vez; esto depende de la unidad real de `speed` que aún no está definida (ver pregunta abierta sobre escala de velocidad) y debe confirmarse con el prototipo, no se afirma como garantizado.

### Oleada 2 — Aparece el tanque

```json
{"id":"wave_02","duration_target_sec":30,"spawns":[{"at_sec":3,"monster_id":"nibbler","lane":0},{"at_sec":9,"monster_id":"nibbler","lane":2},{"at_sec":15,"monster_id":"salsa_tank","lane":1},{"at_sec":24,"monster_id":"nibbler","lane":1}],"teaches":"chain4_bonus_vs_high_hunger"}
```
Un solo `salsa_tank`. Objetivo pedagógico: cadenas de 4+ rinden mejor contra hambre alta.

### Oleada 3 — Prioridad entre dos amenazas

```json
{"id":"wave_03","duration_target_sec":35,"spawns":[{"at_sec":2,"monster_id":"salsa_tank","lane":0},{"at_sec":6,"monster_id":"nibbler","lane":1},{"at_sec":12,"monster_id":"nibbler","lane":2},{"at_sec":20,"monster_id":"salsa_tank","lane":2},{"at_sec":28,"monster_id":"nibbler","lane":0}],"teaches":"resource_prioritization"}
```
Dos `salsa_tank` en momentos distintos, obligando a decidir a quién atender primero.

### Oleada 4 — Aparece la amenaza veloz

```json
{"id":"wave_04","duration_target_sec":35,"spawns":[{"at_sec":3,"monster_id":"swift_hopper","lane":1},{"at_sec":8,"monster_id":"nibbler","lane":0},{"at_sec":14,"monster_id":"salsa_tank","lane":2},{"at_sec":22,"monster_id":"swift_hopper","lane":0},{"at_sec":30,"monster_id":"nibbler","lane":1}],"teaches":"fast_threat_response"}
```
Primer contacto con `swift_hopper`, en solitario y luego combinado.

### Oleada 5 — Mezcla final antes del jefe

```json
{"id":"wave_05","duration_target_sec":40,"spawns":[{"at_sec":2,"monster_id":"nibbler","lane":0},{"at_sec":6,"monster_id":"swift_hopper","lane":2},{"at_sec":10,"monster_id":"salsa_tank","lane":1},{"at_sec":16,"monster_id":"nibbler","lane":2},{"at_sec":22,"monster_id":"swift_hopper","lane":0},{"at_sec":28,"monster_id":"salsa_tank","lane":1},{"at_sec":34,"monster_id":"nibbler","lane":1}],"teaches":"full_mix_mastery"}
```
Los tres tipos combinados, mayor densidad. **[Decisión de revisión PR #2]** Al resolverse esta oleada, se ofrece la pausa de selección de mejora (una de tres) igual que tras cualquier otra oleada, y solo después comienza el combate contra `boss_big_glutton`.

---

## 4. Mejoras roguelite (15)

Rareza provisional: `common`, `rare`, `epic`. Las mejoras etiquetadas `"tags":["strong_defense"]` son defensas fuertes. El sistema de generación de ofertas excluye el resto de mejoras con esa etiqueta después de seleccionar una, garantizando máximo una por partida (contrato de `docs/CONTENT_MODEL.md`); los `conflicts` cruzados entre ellas (`safety_shield`, `patient_service`, `second_chance`) se conservan como validación redundante, no como mecanismo principal.

```json
[
  {"id":"taco_power_1","display_name_key":"upgrade.taco_power_1","rarity":"common","effect":{"stat":"satisfaction_multiplier","operation":"multiply","value":1.15},"conflicts":[]},
  {"id":"taco_power_2","display_name_key":"upgrade.taco_power_2","rarity":"epic","effect":{"stat":"satisfaction_multiplier","operation":"multiply","value":1.5},"conflicts":["taco_power_1"]},
  {"id":"chain4_boost","display_name_key":"upgrade.chain4_boost","rarity":"rare","effect":{"stat":"chain4_satisfaction_bonus","operation":"add","value":0.1},"conflicts":[],"notes":"Aumenta el bono existente de cadena 4 (de +50% a +60%); no reduce el mínimo de cadena de 3, refuerza la regla vigente."},
  {"id":"chain5_effect_boost","display_name_key":"upgrade.chain5_effect_boost","rarity":"epic","effect":{"stat":"special_effect_power_multiplier","operation":"multiply","value":1.3},"conflicts":[],"notes":"Hace más fuerte el efecto especial determinista de cadena 5 (ej. aturdimiento o restauración); no agrega azar."},
  {"id":"steady_hands","display_name_key":"upgrade.steady_hands","rarity":"common","effect":{"stat":"input_forgiveness","operation":"add","value":0.1},"conflicts":[]},
  {"id":"reputation_boost","display_name_key":"upgrade.reputation_boost","rarity":"common","effect":{"stat":"reputation_max","operation":"add","value":15},"conflicts":[],"notes":"Aumenta el máximo de reputación al elegirla; no cura ni restaura reputación perdida."},
  {"id":"safety_shield","display_name_key":"upgrade.safety_shield","rarity":"rare","effect":{"stat":"reputation_shield_charges","operation":"add","value":1},"conflicts":["patient_service","second_chance"],"tags":["strong_defense"]},
  {"id":"slow_salsa","display_name_key":"upgrade.slow_salsa","rarity":"common","effect":{"stat":"monster_speed_global","operation":"multiply","value":0.9},"conflicts":[]},
  {"id":"slow_salsa_plus","display_name_key":"upgrade.slow_salsa_plus","rarity":"epic","effect":{"stat":"monster_speed_global","operation":"multiply","value":0.75},"conflicts":["slow_salsa"]},
  {"id":"extra_bite","display_name_key":"upgrade.extra_bite","rarity":"common","effect":{"stat":"satisfaction_flat_bonus","operation":"add","value":5},"conflicts":[],"notes":"Suma satisfacción fija a cada platillo, útil incluso en cadenas de 3."},
  {"id":"patient_service","display_name_key":"upgrade.patient_service","rarity":"rare","effect":{"stat":"reputation_damage_taken","operation":"multiply","value":0.85},"conflicts":["safety_shield","second_chance"],"tags":["strong_defense"],"notes":"Reduce el daño de reputación recibido cuando un monstruo llega al mostrador."},
  {"id":"assist_serve","display_name_key":"upgrade.assist_serve","rarity":"rare","effect":{"stat":"chain4_splash_satisfaction","operation":"add","value":10},"conflicts":[],"notes":"Una cadena de 4+ también reduce un poco el hambre del segundo monstruo más cercano en el mismo carril; no cambia el objetivo principal fijo (más cercano)."},
  {"id":"warm_welcome","display_name_key":"upgrade.warm_welcome","rarity":"common","effect":{"stat":"first_dish_bonus_per_wave","operation":"set","value":1.0},"conflicts":[],"notes":"El primer platillo servido en cada oleada tiene el doble de satisfacción."},
  {"id":"last_stand","display_name_key":"upgrade.last_stand","rarity":"epic","effect":{"stat":"low_reputation_satisfaction_bonus","operation":"add","value":0.25},"conflicts":[],"notes":"Cuando la reputación cae por debajo de 20% del máximo, la satisfacción de los platillos aumenta 25%. Condición basada en estado, no en azar."},
  {"id":"second_chance","display_name_key":"upgrade.second_chance","rarity":"epic","effect":{"stat":"extra_life_charges","operation":"add","value":1},"conflicts":["safety_shield","patient_service"],"tags":["strong_defense"]}
]
```

---

## 5. Ingredientes (3) y recetas (5)

### 5.1 Ingredientes

```json
[
  {"id":"tortilla","display_name_key":"ingredient.tortilla","tier":1,"color_hint":"gold","base_satisfaction":10,"special_effect":"none"},
  {"id":"meat","display_name_key":"ingredient.meat","tier":1,"color_hint":"terracota","base_satisfaction":12,"special_effect":"none"},
  {"id":"veggie","display_name_key":"ingredient.veggie","tier":1,"color_hint":"verde","base_satisfaction":8,"special_effect":"none"}
]
```

- **Tortilla:** base versátil, satisfacción media; opción "segura" y abundante para cadenas tempranas.
- **Meat (carne):** mayor satisfacción por unidad; mejor para monstruos de hambre alta (`salsa_tank`).
- **Veggie (verdura):** menor satisfacción por unidad; su cadena de 5 da un efecto de apoyo defensivo.

### 5.2 Recetas

```json
[
  {"id":"taco_simple","display_name_key":"recipe.taco_simple","ingredients":{"tortilla":3},"satisfaction":30,"targeting":"nearest","effect":"none","feedback":"platillo básico, sonido corto y alegre"},
  {"id":"taco_meat_simple","display_name_key":"recipe.taco_meat_simple","ingredients":{"meat":3},"satisfaction":36,"targeting":"nearest","effect":"none","feedback":"sonido de sartén, golpe de satisfacción mayor"},
  {"id":"taco_veggie_simple","display_name_key":"recipe.taco_veggie_simple","ingredients":{"veggie":3},"satisfaction":24,"targeting":"nearest","effect":"none","feedback":"sonido fresco, salpicado verde breve"},
  {"id":"taco_golden","display_name_key":"recipe.taco_golden","ingredients":{"tortilla":5},"satisfaction":50,"targeting":"nearest","effect":"brief_stun","feedback":"destello dorado, el monstruo se detiene un instante a saborear"},
  {"id":"taco_veggie_refreshing","display_name_key":"recipe.taco_veggie_refreshing","ingredients":{"veggie":5},"satisfaction":40,"targeting":"nearest","effect":"reputation_small_restore","feedback":"brisa fresca, pequeño ícono de + reputación sobre el mostrador"}
]
```

- `taco_simple`, `taco_meat_simple`, `taco_veggie_simple`: platillos básicos de cadena 3, uno por ingrediente.
- `taco_golden` (cadena 5 de tortilla): efecto `brief_stun` — detiene un instante al monstruo objetivo.
- `taco_veggie_refreshing` (cadena 5 de veggie): efecto `reputation_small_restore` — pequeña recuperación de reputación (esta sí es una restauración real, a diferencia de la mejora `reputation_boost`, que solo sube el máximo).

> **[Alternativa]** Un efecto especial de cadena 5 también para `meat` queda para una segunda iteración, fuera del rango de 3–5 recetas pedido.

---

## 6. Tutorial mínimo

Cuatro líneas, todas disparadas por eventos de juego reales, dentro de la Oleada 1.

| Momento (evento disparador) | Texto visible (español) |
|---|---|
| Al iniciar `wave_01`, antes del primer spawn | "Desliza para conectar 3 tortillas iguales." |
| Cuando el primer `nibbler` entra en pantalla | "¡Tiene hambre! El platillo se sirve solo al más cercano." |
| Cuando el primer `nibbler` pasa la mitad de su carril sin ser atendido | "Si llega al mostrador, pierdes reputación." |
| Al abrirse la primera pantalla de mejora (fin de `wave_01`) | "Elige una mejora para la siguiente oleada." |

Si el jugador ya resolvió al primer `nibbler` antes del tercer texto, ese texto se omite.

---

## 7. Riesgos de balance, supuestos y preguntas abiertas

### 7.1 Riesgos de balance

- **Duración de partida:** con el nuevo objetivo de 4–5 minutos (decisión de esta revisión), la suma de oleadas (25+30+35+35+40 = 165 s ≈ 2:45) más 5 pausas de mejora y el combate contra el jefe encaja razonablemente; de todas formas debe medirse con el prototipo, no se da por hecho.
- **Mutua exclusión de defensas `strong_defense`:** con tres mejoras defensivas fuertes limitadas a una por partida por el sistema de ofertas (`safety_shield`, `patient_service`, `second_chance`), vigilar que ninguna se sienta claramente superior a las otras dos, o el límite por etiqueta no cumplirá su propósito de balance.
- **`salsa_tank` en oleada 3 (dos apariciones):** si el jugador no adoptó `taco_power` o `taco_golden`, dos tanques en 35 s podrían sentirse injustos. Tiempos de spawn son hipótesis.
- **Autoapuntado + `swift_hopper`:** relacionado con la pregunta abierta existente "¿Autoapuntar se siente justo?" (`docs/OPEN_QUESTIONS.md`).
- **`assist_serve` (splash a segundo monstruo):** vigilar que no vuelva trivial a `salsa_tank` cuando hay varios monstruos en el mismo carril.

### 7.2 Supuestos usados en esta propuesta

- Los valores de `speed`, `hunger` y `reputation_damage` de los tres monstruos son relativos entre sí; no hay unidad de referencia definida aún (ver pregunta abierta 7.4.3).
- Se asumió reputación inicial 100 (ya marcada como hipótesis en `docs/CORE_RULES.md`).
- Se asumió que las mejoras se ofrecen de a tres opciones por pausa (`docs/CORE_RULES.md`), por lo que 15 mejoras alcanzan para 5 pausas sin repetición si se desea.
- Se asumió que el jefe no genera monstruos adicionales ni tiene resistencias por ingrediente.

### 7.3 Validaciones realizadas

- Se re-validaron sintácticamente todos los bloques JSON del documento con un parser JSON tras la revisión (ver reporte de entrega).
- Se revisaron todos los identificadores para que sean inglés `snake_case`, manteniendo `display_name_key` y todo el texto visible en español.
- Se verificó que ninguna mejora contradiga reglas fijas de `docs/CORE_RULES.md` (objetivo automático "más cercano", cadena mínima de 3, cadena 5+ determinista).
- Se movió `"teaches"` al interior del JSON en las oleadas 3, 4 y 5.
- Se confirmó que solo se modificó `docs/INITIAL_CONTENT_PROPOSAL.md`.
- Se confirmó que la etiqueta de defensas fuertes usa el contrato oficial `strong_defense` y que el límite de una por partida se documenta desde el sistema de ofertas, no solo desde `conflicts`.
- Se confirmó que no quedan referencias al gesto cosmético de "olfateo" del jefe en el resumen, la sección de jefe, el JSON ni las preguntas abiertas.
- Se confirmó que la rama se actualizó (rebase) contra `docs/preproduction` antes de este commit.

### 7.4 Preguntas abiertas para Jorge y su hermano

1. ¿Se aprueba formalmente el nuevo objetivo de duración (4–5 min) en `docs/DECISIONS.md`, o prefieren que ese registro lo haga alguien del equipo directamente?
2. ¿La escala relativa de `speed`/`hunger`/`reputation_damage` propuesta es aceptable como punto de partida para que Codex defina las unidades reales de implementación, o prefieren fijar antes una unidad de referencia (por ejemplo, celdas por segundo)?
3. ¿Se desea, para una siguiente iteración, un efecto especial de cadena 5 también para `meat`, o se mantiene la asimetría (solo tortilla y veggie) como parte del diseño?

---

*Fin de la propuesta v3. Ningún archivo fuera de `docs/INITIAL_CONTENT_PROPOSAL.md` fue modificado.*
