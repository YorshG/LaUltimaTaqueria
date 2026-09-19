# Propuesta inicial de contenido y balance

Estado del documento: **propuesta para revisión — v4, actualizada tras la revisión de contrato del PR #2 (catálogo `effect.type`, nombres, descripciones, sinergias y localización)**. No integrada ni aprobada como código. Todos los valores numéricos son hipótesis ajustables (ver `docs/PROTOTYPE_SCOPE.md` y `prompts/CLAUDE_KICKOFF.md`). Este documento no modifica arquitectura, no agrega monetización, servidores, cuentas ni multijugador, y no contiene código de juego.

Convenciones usadas en todo el documento:

- **[Decisión aprobada]** — ya registrado en `docs/DECISIONS.md` o derivado directo de reglas vigentes.
- **[Decisión de revisión PR #2]** — confirmado durante la revisión de esta propuesta. Cuando la decisión ya aparece en `docs/DECISIONS.md`, se trata como **[Decisión aprobada]** en el resto del documento.
- **[Hipótesis]** — propuesta de este documento, sujeta a prueba y ajuste.
- **[Alternativa]** — camino distinto que no se eligió como propuesta principal, incluido para discusión.

Identificadores técnicos en **inglés** `snake_case` (corregido en esta revisión: la v1 usaba palabras en español como `tanque_salsero`, `chapulin_veloz`, `carne`, `verdura` — quedan renombrados abajo). Texto visible al jugador en español. Ningún estado depende solo del color.

---

## 0. Resumen de supuestos heredados y cambios de esta revisión

- **[Decisión aprobada]** Tablero 5×5, tres carriles, cadenas ortogonales de 3+ ingredientes iguales, cadena de 4 = +50% satisfacción, cadena de 5+ = efecto especial por ingrediente (`docs/CORE_RULES.md`).
- **[Decisión aprobada]** Se alimenta, no se mata. Tono familiar, mexicano, respetuoso, exportable (`docs/GAME_DESIGN.md`).
- **[Hipótesis, ya marcada como tal en CORE_RULES]** Reputación inicial: 100.
- **[Decisión aprobada]** Duración objetivo de partida: **4–5 minutos**, incluyendo cinco oleadas, cinco elecciones de mejora y jefe; debe medirse con el prototipo.
- **[Decisión aprobada]** La pausa de selección de mejora (una de tres) ocurre también después de la oleada 5, antes de iniciar el combate contra el jefe.
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

### Cambios respecto a la v3 (revisión de contrato del PR #2)

1. **`effect.type` en las 15 mejoras.** Cada mejora incluye ahora `effect.type` tomado de un catálogo cerrado. Como `docs/CONTENT_MODEL.md` solo muestra un tipo de ejemplo, el catálogo completo se propone dentro de este documento (sección 4.1) como **[Hipótesis]**, con la marca explícita de que Codex debe adoptarlo o ajustarlo antes de implementar. No se modificó `docs/CONTENT_MODEL.md`.
2. **Nombres, descripciones y sinergias para las 15.** Cada mejora tiene `display_name_key`, `description_key` y `synergies` (además de `conflicts`); la sección 4.3 muestra nombre visible, descripción visible, rareza, conflictos y sinergias en una sola tabla, y 4.4 explica cada par de sinergia.
3. **Propuesta de localización en español.** La nueva sección 8 lista todas las claves visibles del documento (monstruos, jefe, ingredientes, recetas, rarezas, etiqueta de defensa fuerte, 15 nombres y 15 descripciones de mejoras y los 4 textos del tutorial) con su texto es-MX. La sección 6 añade la clave de cada línea del tutorial.
4. **Efectos ambiguos resueltos con datos estructurados.** `warm_welcome` (antes `operation: set`, `value: 1.0`, ambiguo) pasa a `multiply` × 2.0 con condición `first_dish_of_wave`; `last_stand` declara su umbral (`threshold: 0.2`) y `second_chance` su restauración (`restore_ratio: 0.25`) como `effect.params`, ya no solo en texto libre.
5. **Conflictos simétricos.** `taco_power_1` y `slow_salsa` no declaraban su conflicto con `taco_power_2` y `slow_salsa_plus`, aunque estas sí lo declaraban (la relación era unidireccional). Ahora ambos lados lo declaran; la validación redundante de las tres defensas fuertes ya era simétrica.
6. **Etiquetas en las 15 mejoras.** Se agregó `tags` a todas (`offense`, `defense`, `utility`, `strong_defense`); solo `strong_defense` proviene del contrato vigente, el resto es **[Hipótesis]**.
7. **Referencia corregida.** El supuesto sobre la unidad de `speed` citaba "pregunta abierta 7.4.3", que no existe; ahora cita 7.4.1.
8. **Sin cambios de valores** en monstruos, jefe, oleadas, ingredientes ni recetas, y se mantienen las decisiones aprobadas: partida de 4–5 minutos, quinta selección de mejora antes del jefe y máximo una defensa `strong_defense` por partida.

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
Los tres tipos combinados, mayor densidad. **[Decisión aprobada]** Al resolverse esta oleada, se ofrece la pausa de selección de mejora (una de tres) igual que tras cualquier otra oleada, y solo después comienza el combate contra `boss_big_glutton`.

---

## 4. Mejoras roguelite (15)

Rareza provisional: `common`, `rare`, `epic`. Las mejoras etiquetadas `"tags":["strong_defense"]` son defensas fuertes. El sistema de generación de ofertas excluye el resto de mejoras con esa etiqueta después de seleccionar una, garantizando máximo una por partida (contrato de `docs/CONTENT_MODEL.md`); los `conflicts` cruzados entre ellas (`safety_shield`, `patient_service`, `second_chance`) se conservan como validación redundante, no como mecanismo principal.

### 4.1 Catálogo cerrado de `effect.type` — **[Hipótesis]**

`docs/CONTENT_MODEL.md` exige que el tipo de efecto pertenezca a un catálogo cerrado, pero solo muestra un tipo de ejemplo (`modify_satisfaction`) y no formaliza la lista completa. Como el catálogo aún no existe, esta sección lo propone como **[Hipótesis]**. **Codex debe adoptar o ajustar este contrato antes de cualquier implementación**; este documento no modifica `docs/CONTENT_MODEL.md`, y mientras Codex no lo resuelva ninguna mejora de esta propuesta debe considerarse cargable por el `ContentRegistry`.

| `effect.type` | `stat` permitido (operación) | `params` | Semántica propuesta |
|---|---|---|---|
| `modify_satisfaction` | `satisfaction_multiplier` (`multiply`), `satisfaction_flat_bonus` (`add`) | — | Modifica la satisfacción de cada platillo servido. |
| `modify_chain_bonus` | `chain4_satisfaction_bonus` (`add`) | — | Ajusta el bono de cadena de 4 (base +0.5 según `docs/CORE_RULES.md`). |
| `modify_special_effect` | `special_effect_power_multiplier` (`multiply`) | — | Escala la potencia del efecto especial determinista de cadenas de 5+. |
| `add_splash_satisfaction` | `chain4_splash_satisfaction` (`add`) | — | Una cadena de 4+ quita hambre extra al segundo monstruo más cercano del mismo carril; el objetivo principal no cambia. |
| `conditional_satisfaction` | `satisfaction_multiplier` (`multiply`) | `condition` ∈ {`first_dish_of_wave`, `reputation_below_ratio`}; `threshold` (0–1) solo con `reputation_below_ratio` | Multiplicador de satisfacción que solo aplica si se cumple la condición. |
| `modify_reputation` | `reputation_max` (`add`), `reputation_damage_taken` (`multiply`) | — | Cambia el máximo de reputación o el daño que se recibe al llegar un monstruo al mostrador. |
| `grant_charge` | `reputation_shield_charges` (`add`), `extra_life_charges` (`add`) | `restore_ratio` (0–1) solo con `extra_life_charges` | Otorga cargas de un solo uso. Escudo: anula por completo el daño de reputación del siguiente monstruo que llegue al mostrador. Vida extra: si la reputación llega a 0, consume una carga y restaura reputación a `restore_ratio` × máximo. |
| `modify_monster_stat` | `monster_speed_global` (`multiply`) | — | Multiplica la velocidad de todos los monstruos. |
| `modify_input` | `input_forgiveness` (`add`) | — | Margen adicional de detección al tocar celdas durante el trazo (0.1 = +10%). |

Otros catálogos cerrados usados por las mejoras, también **[Hipótesis]** salvo donde se indica: `operation` ∈ {`add`, `multiply`} (no se usa `set`); `rarity` ∈ {`common`, `rare`, `epic`}; `tags` ∈ {`offense`, `defense`, `utility`, `strong_defense`} (`strong_defense` ya es contrato oficial).

Orden de aplicación propuesto para modificadores de satisfacción **[Hipótesis]**: (1) satisfacción base de la receta; (2) `+ satisfaction_flat_bonus`; (3) × (1 + bono de cadena: 0.5 en cadena de 4, más `chain4_satisfaction_bonus`); (4) × todos los multiplicadores acumulados (`taco_power_*`, `warm_welcome`, `last_stand`), que se combinan de forma multiplicativa. Debe confirmarse con Codex (ver 7.5).

Reglas de validación asociadas, coherentes con la sección "Validación obligatoria" de `docs/CONTENT_MODEL.md`: `type`, `stat`, `operation`, `rarity` y `tags` deben pertenecer a los catálogos anteriores; `stat` debe ser uno de los permitidos para su `type`; `params` solo con las claves indicadas; `conflicts` y `synergies` deben referenciar ids existentes, sin autorreferencias; ninguna mejora puede figurar a la vez en `conflicts` y `synergies` de otra. Ningún dato ejecuta scripts ni expresiones.

Campos que este documento añade al ejemplo de mejora de `docs/CONTENT_MODEL.md`, todos **[Hipótesis]** sujetos a la decisión de Codex: `description_key` (clave de localización de la descripción visible), `synergies` (lista informativa de ids, solo para diseño y balance: no cambia la generación de ofertas ni tiene efecto mecánico), `effect.params` (parámetros por tipo, ver tabla) y `notes` (solo documentación; el cargador puede ignorarlo o Codex puede retirarlo).

### 4.2 Datos

```json
[
  {"id":"taco_power_1","display_name_key":"upgrade.taco_power_1","description_key":"upgrade.taco_power_1.desc","rarity":"common","tags":["offense"],"effect":{"type":"modify_satisfaction","stat":"satisfaction_multiplier","operation":"multiply","value":1.15},"conflicts":["taco_power_2"],"synergies":["chain4_boost","extra_bite","warm_welcome"]},
  {"id":"taco_power_2","display_name_key":"upgrade.taco_power_2","description_key":"upgrade.taco_power_2.desc","rarity":"epic","tags":["offense"],"effect":{"type":"modify_satisfaction","stat":"satisfaction_multiplier","operation":"multiply","value":1.5},"conflicts":["taco_power_1"],"synergies":["chain4_boost","extra_bite","last_stand"]},
  {"id":"chain4_boost","display_name_key":"upgrade.chain4_boost","description_key":"upgrade.chain4_boost.desc","rarity":"rare","tags":["offense"],"effect":{"type":"modify_chain_bonus","stat":"chain4_satisfaction_bonus","operation":"add","value":0.1},"conflicts":[],"synergies":["taco_power_1","taco_power_2","steady_hands","assist_serve","warm_welcome"],"notes":"Sube el bono existente de cadena de 4 de +50% a +60%; no reduce el mínimo de cadena de 3, refuerza la regla vigente."},
  {"id":"chain5_effect_boost","display_name_key":"upgrade.chain5_effect_boost","description_key":"upgrade.chain5_effect_boost.desc","rarity":"epic","tags":["offense"],"effect":{"type":"modify_special_effect","stat":"special_effect_power_multiplier","operation":"multiply","value":1.3},"conflicts":[],"synergies":["steady_hands","reputation_boost"],"notes":"Refuerza el efecto especial determinista de las cadenas de 5+ (aturdimiento de taco_golden, restauración de taco_veggie_refreshing); no agrega azar."},
  {"id":"steady_hands","display_name_key":"upgrade.steady_hands","description_key":"upgrade.steady_hands.desc","rarity":"common","tags":["utility"],"effect":{"type":"modify_input","stat":"input_forgiveness","operation":"add","value":0.1},"conflicts":[],"synergies":["chain4_boost","chain5_effect_boost"],"notes":"[Hipótesis] +0.1 = +10% de margen de detección al tocar cada celda durante el trazo; la unidad real depende de Codex y de la prueba en dispositivo."},
  {"id":"reputation_boost","display_name_key":"upgrade.reputation_boost","description_key":"upgrade.reputation_boost.desc","rarity":"common","tags":["defense"],"effect":{"type":"modify_reputation","stat":"reputation_max","operation":"add","value":15},"conflicts":[],"synergies":["chain5_effect_boost","patient_service"],"notes":"Aumenta el máximo de reputación al elegirla; no cura ni restaura reputación perdida."},
  {"id":"safety_shield","display_name_key":"upgrade.safety_shield","description_key":"upgrade.safety_shield.desc","rarity":"rare","tags":["strong_defense"],"effect":{"type":"grant_charge","stat":"reputation_shield_charges","operation":"add","value":1},"conflicts":["patient_service","second_chance"],"synergies":["slow_salsa","slow_salsa_plus"],"notes":"Una carga: anula por completo el daño de reputación del siguiente monstruo que llegue al mostrador y se consume."},
  {"id":"slow_salsa","display_name_key":"upgrade.slow_salsa","description_key":"upgrade.slow_salsa.desc","rarity":"common","tags":["defense"],"effect":{"type":"modify_monster_stat","stat":"monster_speed_global","operation":"multiply","value":0.9},"conflicts":["slow_salsa_plus"],"synergies":["safety_shield","assist_serve"],"notes":"[Hipótesis] aplica a todos los monstruos, incluido el jefe (ver pendiente 7.5)."},
  {"id":"slow_salsa_plus","display_name_key":"upgrade.slow_salsa_plus","description_key":"upgrade.slow_salsa_plus.desc","rarity":"epic","tags":["defense"],"effect":{"type":"modify_monster_stat","stat":"monster_speed_global","operation":"multiply","value":0.75},"conflicts":["slow_salsa"],"synergies":["safety_shield","assist_serve"],"notes":"[Hipótesis] aplica a todos los monstruos, incluido el jefe (ver pendiente 7.5)."},
  {"id":"extra_bite","display_name_key":"upgrade.extra_bite","description_key":"upgrade.extra_bite.desc","rarity":"common","tags":["offense"],"effect":{"type":"modify_satisfaction","stat":"satisfaction_flat_bonus","operation":"add","value":5},"conflicts":[],"synergies":["taco_power_1","taco_power_2"],"notes":"Suma satisfacción fija a cada platillo, útil incluso en cadenas de 3."},
  {"id":"patient_service","display_name_key":"upgrade.patient_service","description_key":"upgrade.patient_service.desc","rarity":"rare","tags":["strong_defense"],"effect":{"type":"modify_reputation","stat":"reputation_damage_taken","operation":"multiply","value":0.85},"conflicts":["safety_shield","second_chance"],"synergies":["reputation_boost","last_stand"],"notes":"Reduce el daño de reputación recibido cuando un monstruo llega al mostrador."},
  {"id":"assist_serve","display_name_key":"upgrade.assist_serve","description_key":"upgrade.assist_serve.desc","rarity":"rare","tags":["offense"],"effect":{"type":"add_splash_satisfaction","stat":"chain4_splash_satisfaction","operation":"add","value":10},"conflicts":[],"synergies":["chain4_boost","slow_salsa","slow_salsa_plus"],"notes":"Una cadena de 4+ también quita hambre al segundo monstruo más cercano del mismo carril; el objetivo principal sigue siendo el fijo (más cercano). Si no hay segundo monstruo en el carril, no tiene efecto."},
  {"id":"warm_welcome","display_name_key":"upgrade.warm_welcome","description_key":"upgrade.warm_welcome.desc","rarity":"common","tags":["offense"],"effect":{"type":"conditional_satisfaction","stat":"satisfaction_multiplier","operation":"multiply","value":2.0,"params":{"condition":"first_dish_of_wave"}},"conflicts":[],"synergies":["taco_power_1","chain4_boost"],"notes":"El primer platillo servido en cada oleada normal tiene el doble de satisfacción. [Hipótesis] no aplica al combate contra el jefe, que no forma parte de ninguna oleada (docs/CORE_RULES.md)."},
  {"id":"last_stand","display_name_key":"upgrade.last_stand","description_key":"upgrade.last_stand.desc","rarity":"epic","tags":["offense"],"effect":{"type":"conditional_satisfaction","stat":"satisfaction_multiplier","operation":"multiply","value":1.25,"params":{"condition":"reputation_below_ratio","threshold":0.2}},"conflicts":[],"synergies":["taco_power_2","patient_service","second_chance"],"notes":"Cuando la reputación cae por debajo de 20% del máximo, la satisfacción de los platillos aumenta 25%. Condición basada en estado, no en azar."},
  {"id":"second_chance","display_name_key":"upgrade.second_chance","description_key":"upgrade.second_chance.desc","rarity":"epic","tags":["strong_defense"],"effect":{"type":"grant_charge","stat":"extra_life_charges","operation":"add","value":1,"params":{"restore_ratio":0.25}},"conflicts":["safety_shield","patient_service"],"synergies":["last_stand"],"notes":"Una carga: si la reputación llega a 0, se consume y la reputación se restaura a 25% del máximo [Hipótesis: 0.25]. Solo una vez por partida."}
]
```

### 4.3 Nombres, descripciones, conflictos y sinergias

Los textos son la propuesta de localización es-MX de la sección 8. La rareza se comunica también con texto (`rarity.*`) y las defensas fuertes con la etiqueta visible `tag.strong_defense`, de modo que ningún estado dependa solo del color.

| id | Nombre visible | Descripción visible | Rareza / etiqueta | Conflictos | Sinergias |
|---|---|---|---|---|---|
| `taco_power_1` | Sazón casera | Tus platillos satisfacen 15% más. | `common` | `taco_power_2` | `chain4_boost`, `extra_bite`, `warm_welcome` |
| `taco_power_2` | Sazón de la abuela | Tus platillos satisfacen 50% más. No se combina con Sazón casera. | `epic` | `taco_power_1` | `chain4_boost`, `extra_bite`, `last_stand` |
| `chain4_boost` | Ración generosa | Las cadenas de 4 dan +60% de satisfacción en vez de +50%. | `rare` | — | `taco_power_1`, `taco_power_2`, `steady_hands`, `assist_serve`, `warm_welcome` |
| `chain5_effect_boost` | Toque maestro | Los efectos especiales de las cadenas de 5 son 30% más fuertes. | `epic` | — | `steady_hands`, `reputation_boost` |
| `steady_hands` | Pulso firme | Trazar cadenas es más fácil: 10% más de margen al tocar cada ingrediente. | `common` | — | `chain4_boost`, `chain5_effect_boost` |
| `reputation_boost` | Clientela fiel | Tu reputación máxima sube 15 puntos. No recupera reputación perdida. | `common` | — | `chain5_effect_boost`, `patient_service` |
| `safety_shield` | Escudo de la casa | Anula por completo el daño de reputación del próximo monstruo que llegue al mostrador. | `rare`, `strong_defense` | `patient_service`, `second_chance` | `slow_salsa`, `slow_salsa_plus` |
| `slow_salsa` | Salsa espesa | Todos los monstruos avanzan 10% más lento. | `common` | `slow_salsa_plus` | `safety_shield`, `assist_serve` |
| `slow_salsa_plus` | Salsa extraespesa | Todos los monstruos avanzan 25% más lento. No se combina con Salsa espesa. | `epic` | `slow_salsa` | `safety_shield`, `assist_serve` |
| `extra_bite` | Bocado extra | Cada platillo satisface 5 puntos más, incluso con cadenas de 3. | `common` | — | `taco_power_1`, `taco_power_2` |
| `patient_service` | Servicio paciente | Los monstruos que llegan al mostrador te quitan 15% menos de reputación. | `rare`, `strong_defense` | `safety_shield`, `second_chance` | `reputation_boost`, `last_stand` |
| `assist_serve` | Ayudante de cocina | Las cadenas de 4 o más también quitan 10 de hambre al segundo monstruo más cercano de ese carril. | `rare` | — | `chain4_boost`, `slow_salsa`, `slow_salsa_plus` |
| `warm_welcome` | Bienvenida cálida | El primer platillo de cada oleada satisface el doble. | `common` | — | `taco_power_1`, `chain4_boost` |
| `last_stand` | Hasta el final | Con menos de 20% de reputación, tus platillos satisfacen 25% más. | `epic` | — | `taco_power_2`, `patient_service`, `second_chance` |
| `second_chance` | Otra ronda | Una vez, si tu reputación llega a 0, se restaura al 25% de tu máximo. | `epic`, `strong_defense` | `safety_shield`, `patient_service` | `last_stand` |

### 4.4 Motivo de cada sinergia

Las sinergias son simétricas y solo orientan el diseño y la prueba de combinaciones; no producen ningún bono adicional.

| Par | Motivo de diseño |
|---|---|
| `taco_power_1` + `extra_bite` | El bono fijo se combina con un multiplicador general. |
| `taco_power_1` + `chain4_boost` | El multiplicador escala también el bono reforzado de cadena de 4. |
| `taco_power_1` + `warm_welcome` | El primer platillo de la oleada se duplica y además se multiplica. |
| `taco_power_2` + `extra_bite` | El bono fijo se combina con un multiplicador grande. |
| `taco_power_2` + `chain4_boost` | El multiplicador escala también el bono reforzado de cadena de 4. |
| `taco_power_2` + `last_stand` | Multiplicadores acumulables en el tramo de reputación baja. |
| `chain4_boost` + `assist_serve` | Más cadenas de 4 activan más veces el efecto de contagio. |
| `chain4_boost` + `steady_hands` | Trazar cadenas largas resulta más fácil. |
| `chain4_boost` + `warm_welcome` | Abrir la oleada con una cadena de 4 duplicada. |
| `chain5_effect_boost` + `steady_hands` | Trazar cadenas de 5 resulta más fácil y su efecto es más fuerte. |
| `chain5_effect_boost` + `reputation_boost` | La restauración de taco_veggie_refreshing escala y hay más reputación que recuperar. |
| `reputation_boost` + `patient_service` | Más reserva de reputación y menos daño por golpe. |
| `safety_shield` + `slow_salsa` | Más tiempo para reaccionar; el escudo cubre el error que aún ocurra. |
| `safety_shield` + `slow_salsa_plus` | Más tiempo para reaccionar; el escudo cubre el error que aún ocurra. |
| `slow_salsa` + `assist_serve` | Monstruos lentos se acumulan más en un carril y el contagio conecta más. |
| `slow_salsa_plus` + `assist_serve` | Monstruos lentos se acumulan más en un carril y el contagio conecta más. |
| `patient_service` + `last_stand` | Menos daño por golpe alarga el tramo de reputación baja que premia la mejora. |
| `last_stand` + `second_chance` | Ambas premian jugar al límite de reputación. |

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

> **[Hipótesis]** Catálogo cerrado de `recipe.effect` usado aquí: `none`, `brief_stun`, `reputation_small_restore`; `targeting`: `nearest` (único valor, fijo por `docs/CORE_RULES.md`). Las magnitudes de `brief_stun` (duración) y `reputation_small_restore` (cantidad) no están definidas en esta propuesta y quedan para Codex/prototipo (ver 7.5). Codex debe adoptar/ajustar este catálogo junto con el de `effect.type` (sección 4.1).

---

## 6. Tutorial mínimo

Cuatro líneas, todas disparadas por eventos de juego reales, dentro de la Oleada 1.

| Momento (evento disparador) | Clave de localización | Texto visible (español) |
|---|---|---|
| Al iniciar `wave_01`, antes del primer spawn | `tutorial.trace_chain` | "Desliza para conectar 3 tortillas iguales." |
| Cuando el primer `nibbler` entra en pantalla | `tutorial.auto_target` | "¡Tiene hambre! El platillo se sirve solo al más cercano." |
| Cuando el primer `nibbler` pasa la mitad de su carril sin ser atendido | `tutorial.reputation_warning` | "Si llega al mostrador, pierdes reputación." |
| Al abrirse la primera pantalla de mejora (fin de `wave_01`) | `tutorial.pick_upgrade` | "Elige una mejora para la siguiente oleada." |

Si el jugador ya resolvió al primer `nibbler` antes del tercer texto, ese texto se omite.

---

## 7. Riesgos de balance, supuestos y preguntas abiertas

### 7.1 Riesgos de balance

- **Duración de partida:** con el objetivo aprobado de 4–5 minutos, la suma de oleadas (25+30+35+35+40 = 165 s ≈ 2:45) más 5 pausas de mejora y el combate contra el jefe encaja razonablemente; de todas formas debe medirse con el prototipo, no se da por hecho.
- **Mutua exclusión de defensas `strong_defense`:** con tres mejoras defensivas fuertes limitadas a una por partida por el sistema de ofertas (`safety_shield`, `patient_service`, `second_chance`), vigilar que ninguna se sienta claramente superior a las otras dos, o el límite por etiqueta no cumplirá su propósito de balance.
- **`salsa_tank` en oleada 3 (dos apariciones):** si el jugador no adoptó `taco_power` o `taco_golden`, dos tanques en 35 s podrían sentirse injustos. Tiempos de spawn son hipótesis.
- **Autoapuntado + `swift_hopper`:** relacionado con la pregunta abierta existente "¿Autoapuntar se siente justo?" (`docs/OPEN_QUESTIONS.md`).
- **`assist_serve` (splash a segundo monstruo):** vigilar que no vuelva trivial a `salsa_tank` cuando hay varios monstruos en el mismo carril. Además, extiende la regla de objetivo único de `docs/CORE_RULES.md` (el platillo afecta también a un segundo monstruo), lo que Codex debe aceptar explícitamente.
- **Multiplicadores apilables:** `taco_power_*`, `warm_welcome` y `last_stand` se combinan de forma multiplicativa según el orden propuesto en 4.1; una partida con `taco_power_2` + `last_stand` + cadenas de 4 puede escalar demasiado. Medir con el prototipo.
- **`slow_salsa_plus` sobre el jefe:** si `monster_speed_global` también afecta a `boss_big_glutton`, ×0.75 sobre sus fases 1.25× y 1.4× podría anular la presión del combate final. Depende de la pregunta 7.4.3.
- **`steady_hands` (`modify_input`):** su efecto depende de cómo se detecte el toque en cada celda; es la única mejora que actúa sobre la entrada y no sobre la simulación, y podría no ser perceptible en un tablero 5×5. Validar en el Galaxy S24 Ultra antes de conservarla.
- **`second_chance` y `reputation_boost`:** ambas dependen de una reputación máxima aún provisional (100); si esa base cambia, los valores 15 y 0.25 deben reescalarse.
- **Textos con cifras embebidas:** las descripciones de la sección 8 citan valores hipotéticos (15%, 50%, 25%…). Si el balance cambia un valor, el texto debe actualizarse a mano, con riesgo de desincronización.

### 7.2 Supuestos usados en esta propuesta

- Los valores de `speed`, `hunger` y `reputation_damage` de los tres monstruos son relativos entre sí; no hay unidad de referencia definida aún (ver pregunta abierta 7.4.1).
- Se asumió reputación inicial 100 (ya marcada como hipótesis en `docs/CORE_RULES.md`).
- Se asumió que las mejoras se ofrecen de a tres opciones por pausa (`docs/CORE_RULES.md`), por lo que 15 mejoras alcanzan para 5 pausas sin repetición si se desea.
- Se asumió que el jefe no genera monstruos adicionales ni tiene resistencias por ingrediente.
- Se asumió que las sinergias son solo informativas y que la generación de ofertas no las usa para ponderar.

### 7.3 Validaciones realizadas

- Se re-validaron sintácticamente los 13 bloques JSON del documento con un parser JSON estándar (3 monstruos, jefe, 5 oleadas, mejoras, ingredientes, recetas y localización).
- Cada una de las 15 mejoras tiene `effect.type`; `type`, `stat`, `operation`, `rarity`, `tags` y `params` pertenecen al catálogo cerrado de 4.1 (verificado con un script).
- `conflicts` y `synergies` no tienen referencias rotas, autorreferencias ni solapamientos entre sí; ambos son simétricos. Exactamente tres mejoras llevan `strong_defense` y se excluyen entre sí.
- Todas las claves `display_name_key` y `description_key` del documento existen en la sección 8, y no hay claves huérfanas; nombres ≤ 24 caracteres y descripciones ≤ 110 caracteres para dejar margen de expansión de texto.
- Las recetas referencian ingredientes existentes, las oleadas monstruos existentes, los carriles están entre 0 y 2 y los tiempos son finitos y no negativos.
- Las rutas de archivos citadas en el documento existen en el repositorio y, fuera del historial de cambios del inicio, no quedan referencias a la etiqueta anterior de defensas fuertes ni a la duración objetivo anterior.
- Se mantienen sin cambios los valores de monstruos, jefe, oleadas, ingredientes y recetas, y las decisiones aprobadas (4–5 minutos, quinta mejora antes del jefe, máximo una `strong_defense`).
- Se verificó que la rama contiene por completo `docs/preproduction` (ancestro directo, 0 commits pendientes) y que su diferencia con esa rama es solo `docs/INITIAL_CONTENT_PROPOSAL.md`.
- No se modificó `docs/CONTENT_MODEL.md` ni ningún otro archivo distinto de `docs/INITIAL_CONTENT_PROPOSAL.md`.

### 7.4 Preguntas abiertas para Jorge y su hermano

1. ¿La escala relativa de `speed`/`hunger`/`reputation_damage` propuesta es aceptable como punto de partida para que Codex defina las unidades reales de implementación, o prefieren fijar antes una unidad de referencia (por ejemplo, celdas por segundo)?
2. ¿Se desea, para una siguiente iteración, un efecto especial de cadena 5 también para `meat`, o se mantiene la asimetría (solo tortilla y veggie) como parte del diseño?
3. ¿Las mejoras `slow_salsa` y `slow_salsa_plus` deben afectar también al jefe, o solo a los monstruos de las oleadas normales?

### 7.5 Pendientes para Codex antes de implementar

1. **Adoptar o ajustar el catálogo `effect.type` de 4.1** (y el de `recipe.effect` de 5.2), decidir si pasa a `docs/CONTENT_MODEL.md` y, en ese caso, actualizar el contrato. Hasta entonces es solo **[Hipótesis]**.
2. **Decidir sobre las extensiones de contrato** `description_key`, `synergies`, `effect.params`, catálogo de `tags` y `notes` (4.1).
3. **Conflictos simétricos:** el documento los declara en ambos sentidos. Confirmar que la regla "sin ciclos inválidos" de `docs/CONTENT_MODEL.md` no rechaza un conflicto mutuo entre dos mejoras; si lo hiciera, indicar en qué sentido declararlos.
4. **Orden de aplicación de modificadores de satisfacción** propuesto en 4.1.
5. **Magnitudes aún sin definir:** duración de `brief_stun`, cantidad de `reputation_small_restore` y unidad real de `input_forgiveness`.
6. **Textos con cifras:** decidir si las descripciones se mantienen con cifras fijas o si se usa interpolación de valores desde los datos (por ejemplo, un marcador `{value}` reemplazado al mostrar el texto); esta propuesta no la introduce por ampliar el contrato.
7. **`monster_speed_global` sobre el jefe**, según la respuesta a la pregunta 7.4.3.

---

## 8. Propuesta de localización (es-MX)

**[Hipótesis]** Catálogo de localización base en español para todas las claves visibles que aparecen en este documento (monstruos, jefe, ingredientes, recetas, rarezas, etiqueta de defensa fuerte, mejoras y tutorial). Sigue el formato de `docs/CONTENT_MODEL.md` (objeto clave → texto) y las reglas de `docs/UX_AND_ACCESSIBILITY.md`: texto breve y localizable, sin depender del color. Los identificadores permanecen en inglés `snake_case`; el texto visible, en español.

```json
{
  "monster.nibbler": "Mordisqueador",
  "monster.salsa_tank": "Tanque salsero",
  "monster.swift_hopper": "Chapulín veloz",
  "boss.big_glutton": "El Gran Glotón",
  "ingredient.tortilla": "Tortilla",
  "ingredient.meat": "Carne",
  "ingredient.veggie": "Verdura",
  "recipe.taco_simple": "Taco sencillo",
  "recipe.taco_meat_simple": "Taco de carne",
  "recipe.taco_veggie_simple": "Taco de verdura",
  "recipe.taco_golden": "Taco dorado",
  "recipe.taco_veggie_refreshing": "Taco fresco",
  "rarity.common": "Común",
  "rarity.rare": "Rara",
  "rarity.epic": "Épica",
  "tag.strong_defense": "Defensa fuerte",
  "upgrade.taco_power_1": "Sazón casera",
  "upgrade.taco_power_1.desc": "Tus platillos satisfacen 15% más.",
  "upgrade.taco_power_2": "Sazón de la abuela",
  "upgrade.taco_power_2.desc": "Tus platillos satisfacen 50% más. No se combina con Sazón casera.",
  "upgrade.chain4_boost": "Ración generosa",
  "upgrade.chain4_boost.desc": "Las cadenas de 4 dan +60% de satisfacción en vez de +50%.",
  "upgrade.chain5_effect_boost": "Toque maestro",
  "upgrade.chain5_effect_boost.desc": "Los efectos especiales de las cadenas de 5 son 30% más fuertes.",
  "upgrade.steady_hands": "Pulso firme",
  "upgrade.steady_hands.desc": "Trazar cadenas es más fácil: 10% más de margen al tocar cada ingrediente.",
  "upgrade.reputation_boost": "Clientela fiel",
  "upgrade.reputation_boost.desc": "Tu reputación máxima sube 15 puntos. No recupera reputación perdida.",
  "upgrade.safety_shield": "Escudo de la casa",
  "upgrade.safety_shield.desc": "Anula por completo el daño de reputación del próximo monstruo que llegue al mostrador.",
  "upgrade.slow_salsa": "Salsa espesa",
  "upgrade.slow_salsa.desc": "Todos los monstruos avanzan 10% más lento.",
  "upgrade.slow_salsa_plus": "Salsa extraespesa",
  "upgrade.slow_salsa_plus.desc": "Todos los monstruos avanzan 25% más lento. No se combina con Salsa espesa.",
  "upgrade.extra_bite": "Bocado extra",
  "upgrade.extra_bite.desc": "Cada platillo satisface 5 puntos más, incluso con cadenas de 3.",
  "upgrade.patient_service": "Servicio paciente",
  "upgrade.patient_service.desc": "Los monstruos que llegan al mostrador te quitan 15% menos de reputación.",
  "upgrade.assist_serve": "Ayudante de cocina",
  "upgrade.assist_serve.desc": "Las cadenas de 4 o más también quitan 10 de hambre al segundo monstruo más cercano de ese carril.",
  "upgrade.warm_welcome": "Bienvenida cálida",
  "upgrade.warm_welcome.desc": "El primer platillo de cada oleada satisface el doble.",
  "upgrade.last_stand": "Hasta el final",
  "upgrade.last_stand.desc": "Con menos de 20% de reputación, tus platillos satisfacen 25% más.",
  "upgrade.second_chance": "Otra ronda",
  "upgrade.second_chance.desc": "Una vez, si tu reputación llega a 0, se restaura al 25% de tu máximo.",
  "tutorial.trace_chain": "Desliza para conectar 3 tortillas iguales.",
  "tutorial.auto_target": "¡Tiene hambre! El platillo se sirve solo al más cercano.",
  "tutorial.reputation_warning": "Si llega al mostrador, pierdes reputación.",
  "tutorial.pick_upgrade": "Elige una mejora para la siguiente oleada."
}
```

- Los textos de las descripciones incluyen cifras que reflejan los valores hipotéticos de la sección 4.2; si un valor cambia, la descripción debe actualizarse (ver riesgo en 7.1 y pendiente 7.5.6).
- Los nombres de monstruos, jefe, ingredientes y recetas conservan los nombres en español ya usados en la propuesta (por ejemplo "tanque salsero", "chapulín veloz", "El Gran Glotón").
- No se agregaron claves para efectos de receta (`brief_stun`, `reputation_small_restore`) porque en esta propuesta no se muestran como texto visible; si la interfaz los muestra, deberán agregarse.

---

*Fin de la propuesta v4. Ningún archivo fuera de `docs/INITIAL_CONTENT_PROPOSAL.md` fue modificado.*
