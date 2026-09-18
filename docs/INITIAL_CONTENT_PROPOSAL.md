# Propuesta inicial de contenido y balance

Estado del documento: **propuesta para revisión**, no integrada ni aprobada. Todos los valores numéricos son hipótesis ajustables (ver `docs/PROTOTYPE_SCOPE.md` y `prompts/CLAUDE_KICKOFF.md`). Este documento no modifica arquitectura, no agrega monetización, servidores, cuentas ni multijugador, y no contiene código de juego.

Convenciones usadas en todo el documento:

- **[Decisión aprobada]** — ya registrado en `docs/DECISIONS.md` o derivado directo de reglas vigentes.
- **[Hipótesis]** — propuesta nueva de este documento, sujeta a prueba y ajuste.
- **[Alternativa]** — camino distinto que no se eligió como propuesta principal, incluido para discusión.

Identificadores técnicos en inglés `snake_case`; texto visible al jugador en español. Ningún estado depende solo del color (se usan íconos, formas y texto de apoyo).

---

## 0. Resumen de supuestos heredados

- **[Decisión aprobada]** Tablero 5×5, tres carriles, cadenas ortogonales de 3+ ingredientes iguales, cadena de 4 = +50% satisfacción, cadena de 5+ = efecto especial por ingrediente (`docs/CORE_RULES.md`).
- **[Decisión aprobada]** Se alimenta, no se mata. Tono familiar, mexicano, respetuoso, exportable (`docs/GAME_DESIGN.md`).
- **[Hipótesis, ya marcada como tal en CORE_RULES]** Reputación inicial: 100.
- **[Decisión aprobada / objetivo]** Duración objetivo de partida: ~3 minutos (`docs/DECISIONS.md`), debe medirse.
- **[Decisión aprobada]** Recetas mixtas (con más de un ingrediente) quedan fuera del prototipo hasta validar la combinación básica. Por eso todas las recetas de esta propuesta usan un único ingrediente por cadena.

---

## 1. Monstruos iniciales

Tres monstruos con arquetipos claramente diferenciados: **básico/enseñanza**, **tanque lento** y **amenaza veloz**. Ninguno introduce mecánicas nuevas (sin cambio de carril, sin resistencias elementales): la diferenciación es puramente de parámetros, silueta, personalidad y señales.

### 1.1 Nibbler (mordisqueador)

- **Silueta:** criatura redonda, boca grande, orejas caídas; la más pequeña de las tres.
- **Personalidad:** glotón torpe y adorable, sin maldad; se emociona al oler comida.
- **Comportamiento:** avanza a ritmo constante por su carril; si su hambre baja de 30%, muerde el aire con ansiedad (animación de anticipación).
- **Rol estratégico:** enseña el gesto básico de cadena de 3 y el autoapuntado. Es el "metrónomo" de dificultad: su presencia constante da al jugador tiempo para practicar.
- **Señales de hambre/satisfacción:** ícono de plato vacío sobre la cabeza cuando tiene hambre alta; el ícono se llena progresivamente al recibir platillos; al quedar satisfecho, salta de alegría y sale de escena con un efecto de confeti. No depende solo de color: usa forma de ícono (plato vacío → medio lleno → lleno) y una pequeña barra numérica opcional.

```json
{"id":"nibbler","display_name_key":"monster.nibbler","tags":["basic"],"speed":55,"hunger":30,"reputation_damage":10,"initial_value_hypothesis":true}
```

### 1.2 Tanque salsero

- **Silueta:** criatura ancha, panzona, caparazón de tortilla dorada gruesa; la más grande.
- **Personalidad:** tranquilo, terco, no se distrae ni se apura; disfruta despacio.
- **Comportamiento:** avanza lento y de forma predecible; **no** cambia de velocidad por sí mismo. Requiere hambre alta acumulada, por lo que castiga a quien solo hace cadenas de 3.
- **Rol estratégico:** enseña que cadenas de 4–5 (bono de satisfacción / efecto especial) son más eficientes contra objetivos de hambre alta. Si llega al mostrador, el golpe de reputación es severo, así que también enseña priorización.
- **Señales de hambre/satisfacción:** panza translúcida tipo "medidor" que se va vaciando de un patrón de rayas (no solo color) conforme baja su hambre; sonido grave y lento de "satisfecho" al vaciarse del todo.

```json
{"id":"tanque_salsero","display_name_key":"monster.tanque_salsero","tags":["tank","slow"],"speed":30,"hunger":70,"reputation_damage":25,"initial_value_hypothesis":true}
```

### 1.3 Chapulín veloz

- **Silueta:** criatura delgada, patas largas tipo resorte, siempre en movimiento.
- **Personalidad:** nervioso, juguetón, ríe y brinca; no es agresivo, solo muy inquieto.
- **Comportamiento:** avanza mucho más rápido que los otros dos; **no cambia de carril** (se descarta esa variante para no introducir una mecánica nueva sin aprobación — ver alternativa 1.3.a). Su ventana de reacción es corta.
- **Rol estratégico:** enseña reacción rápida y decisión de "a quién atiendo primero" cuando compite por atención con otro monstruo en pantalla.
- **Señales de hambre/satisfacción:** estela de movimiento (líneas de velocidad) que se acorta conforme se satisface; ícono de resorte con signo de exclamación cuando está a punto de llegar al mostrador (alerta temprana, no depende del color).

```json
{"id":"chapulin_veloz","display_name_key":"monster.chapulin_veloz","tags":["fast","priority"],"speed":90,"hunger":18,"reputation_damage":15,"initial_value_hypothesis":true}
```

> **[Alternativa 1.3.a]** Diseño original consideró que `chapulin_veloz` cambiara de carril a mitad de recorrido para aumentar la presión. Se descarta como propuesta principal por ser una mecánica nueva no descrita en `docs/CORE_RULES.md` (que solo define desempates de objetivo, no cambio de carril de un monstruo). Se deja registrada como alternativa futura, no aprobada.

---

## 2. Jefe

### El Gran Glotón (`boss_gran_gloton`)

- **Identidad:** el monstruo más grande y viejo de la invasión; ya probó "todas las taquerías" y busca la última que sigue abierta. Tono cómico-solemne, nunca amenazante de forma violenta.
- **Comportamiento general:** aparece solo, ocupa el carril central, tiene hambre total mucho mayor que un monstruo normal (300, como en `docs/CONTENT_MODEL.md`).
- **Fases (por umbral de hambre restante):**
  1. **Fase 1 (100%–60% de hambre restante):** velocidad normal, come con calma.
  2. **Fase 2 (60%–30%):** se impacienta; velocidad 1.25×, y cada cierto intervalo hace un gesto de "olfateo" (telegrafiado, sin daño) que anticipa que buscará el carril con más platillos servidos recientemente — información para el jugador, no cambio de reglas de objetivo.
  3. **Fase 3 (30%–0%):** "última mordida": velocidad 1.4×, animación de transición con breve pausa de invulnerabilidad visual (sin penalización para el jugador, solo un respiro narrativo antes del tramo final).
- **Contrajuego:** el jefe se alimenta igual que cualquier monstruo (cadenas de 3/4/5 aplican normalmente); no introduce resistencias a ingredientes específicos para no ampliar el alcance del prototipo. El reto es de resistencia y ritmo, no de "arma correcta".
- **Comunicación anticipada:** barra de hambre del jefe siempre visible en pantalla (a diferencia de monstruos normales); el gesto de "olfateo" de fase 2 y la pausa de fase 3 son las señales de transición, ambas visuales y sonoras (no dependen de color).

```json
{"id":"boss_gran_gloton","display_name_key":"boss.gran_gloton","hunger":300,"reputation_damage_on_breach":40,"lane":1,"phases":[{"threshold":1.0,"speed_multiplier":1.0,"behavior_tag":"calm"},{"threshold":0.6,"speed_multiplier":1.25,"behavior_tag":"impatient_telegraph"},{"threshold":0.3,"speed_multiplier":1.4,"behavior_tag":"final_bite"}]}
```

> **[Hipótesis]** El jefe ocupa siempre el carril central y no genera monstruos adicionales durante su combate, para mantener el alcance simple en el prototipo. **[Alternativa]** que el jefe invoque 1–2 `nibbler` de apoyo en fase 3 se descarta por ahora: aumentaría el alcance de contenido y de IA de spawn más allá de lo pedido.

---

## 3. Oleadas iniciales (5)

Numeración de carriles: `0` = izquierdo, `1` = central, `2` = derecho (consistente con el desempate de `docs/CORE_RULES.md`: central, izquierdo, derecho).

### Oleada 1 — Introducción

```json
{"id":"wave_01","duration_target_sec":25,"spawns":[{"at_sec":2,"monster_id":"nibbler","lane":1},{"at_sec":8,"monster_id":"nibbler","lane":0},{"at_sec":14,"monster_id":"nibbler","lane":2},{"at_sec":20,"monster_id":"nibbler","lane":1}],"teaches":"basic_match"}
```
Cierre: solo `nibbler`, sin superposición de dos monstruos a la vez. Objetivo pedagógico: cadena básica + autoapuntado.

### Oleada 2 — Aparece el tanque

```json
{"id":"wave_02","duration_target_sec":30,"spawns":[{"at_sec":3,"monster_id":"nibbler","lane":0},{"at_sec":9,"monster_id":"nibbler","lane":2},{"at_sec":15,"monster_id":"tanque_salsero","lane":1},{"at_sec":24,"monster_id":"nibbler","lane":1}],"teaches":"chain4_bonus_vs_high_hunger"}
```
Cierre: un solo `tanque_salsero`, con un `nibbler` de por medio para no saturar. Objetivo pedagógico: cadenas de 4+ rinden mejor contra hambre alta.

### Oleada 3 — Prioridad entre dos amenazas

```json
{"id":"wave_03","duration_target_sec":35,"spawns":[{"at_sec":2,"monster_id":"tanque_salsero","lane":0},{"at_sec":6,"monster_id":"nibbler","lane":1},{"at_sec":12,"monster_id":"nibbler","lane":2},{"at_sec":20,"monster_id":"tanque_salsero","lane":2},{"at_sec":28,"monster_id":"nibbler","lane":0}]}
```
`"teaches":"resource_prioritization"`. Cierre: dos `tanque_salsero` en pantalla en momentos distintos, obligando a decidir a quién atender primero.

### Oleada 4 — Aparece la amenaza veloz

```json
{"id":"wave_04","duration_target_sec":35,"spawns":[{"at_sec":3,"monster_id":"chapulin_veloz","lane":1},{"at_sec":8,"monster_id":"nibbler","lane":0},{"at_sec":14,"monster_id":"tanque_salsero","lane":2},{"at_sec":22,"monster_id":"chapulin_veloz","lane":0},{"at_sec":30,"monster_id":"nibbler","lane":1}]}
```
`"teaches":"fast_threat_response"`. Cierre: primer contacto con `chapulin_veloz`, en solitario y luego combinado.

### Oleada 5 — Mezcla final antes del jefe

```json
{"id":"wave_05","duration_target_sec":40,"spawns":[{"at_sec":2,"monster_id":"nibbler","lane":0},{"at_sec":6,"monster_id":"chapulin_veloz","lane":2},{"at_sec":10,"monster_id":"tanque_salsero","lane":1},{"at_sec":16,"monster_id":"nibbler","lane":2},{"at_sec":22,"monster_id":"chapulin_veloz","lane":0},{"at_sec":28,"monster_id":"tanque_salsero","lane":1},{"at_sec":34,"monster_id":"nibbler","lane":1}]}
```
`"teaches":"full_mix_mastery"`. Cierre: los tres tipos combinados, mayor densidad; al resolverse, se ofrece la mejora entre oleadas de siempre y comienza el combate contra `boss_gran_gloton` (ver pregunta abierta 7.4 sobre si corresponde una mejora adicional justo antes del jefe).

---

## 4. Mejoras roguelite (15)

Rareza provisional: `common`, `rare`, `epic`. Algunas mejoras son mutuamente excluyentes (`conflicts`) para simular decisiones de "camino" dentro de una partida.

```json
[
  {"id":"taco_power_1","display_name_key":"upgrade.taco_power_1","rarity":"common","effect":{"stat":"satisfaction_multiplier","operation":"multiply","value":1.15},"conflicts":[]},
  {"id":"taco_power_2","display_name_key":"upgrade.taco_power_2","rarity":"epic","effect":{"stat":"satisfaction_multiplier","operation":"multiply","value":1.5},"conflicts":["taco_power_1"]},
  {"id":"chain_facil","display_name_key":"upgrade.chain_facil","rarity":"rare","effect":{"stat":"chain_min_length","operation":"set","value":2},"conflicts":[]},
  {"id":"mano_firme","display_name_key":"upgrade.mano_firme","rarity":"common","effect":{"stat":"input_forgiveness","operation":"add","value":0.1},"conflicts":[]},
  {"id":"reputacion_extra","display_name_key":"upgrade.reputacion_extra","rarity":"common","effect":{"stat":"reputation_max","operation":"add","value":15},"conflicts":[]},
  {"id":"escudo_taquero","display_name_key":"upgrade.escudo_taquero","rarity":"rare","effect":{"stat":"reputation_shield_charges","operation":"add","value":1},"conflicts":[]},
  {"id":"salsa_lenta","display_name_key":"upgrade.salsa_lenta","rarity":"common","effect":{"stat":"monster_speed_global","operation":"multiply","value":0.9},"conflicts":[]},
  {"id":"salsa_lenta_plus","display_name_key":"upgrade.salsa_lenta_plus","rarity":"epic","effect":{"stat":"monster_speed_global","operation":"multiply","value":0.75},"conflicts":["salsa_lenta"]},
  {"id":"propina_doble","display_name_key":"upgrade.propina_doble","rarity":"common","effect":{"stat":"coin_reward_multiplier","operation":"multiply","value":1.2},"conflicts":[]},
  {"id":"propina_doble_plus","display_name_key":"upgrade.propina_doble_plus","rarity":"rare","effect":{"stat":"coin_reward_multiplier","operation":"multiply","value":1.5},"conflicts":["propina_doble"]},
  {"id":"relleno_extra","display_name_key":"upgrade.relleno_extra","rarity":"common","effect":{"stat":"board_refill_speed","operation":"multiply","value":1.15},"conflicts":[]},
  {"id":"ojo_certero","display_name_key":"upgrade.ojo_certero","rarity":"rare","effect":{"stat":"auto_target_priority","operation":"set","value":"lowest_hunger_remaining"},"conflicts":[]},
  {"id":"cadena_dorada","display_name_key":"upgrade.cadena_dorada","rarity":"epic","effect":{"stat":"special_effect_chance_on_chain4","operation":"add","value":0.15},"conflicts":[]},
  {"id":"resistencia_inicial","display_name_key":"upgrade.resistencia_inicial","rarity":"common","effect":{"stat":"starting_reputation","operation":"add","value":10},"conflicts":[]},
  {"id":"segunda_oportunidad","display_name_key":"upgrade.segunda_oportunidad","rarity":"epic","effect":{"stat":"extra_life_charges","operation":"add","value":1},"conflicts":[]}
]
```

Notas de sinergia y riesgo (no forman parte del contrato JSON, son guía de diseño):

- `taco_power_1`/`taco_power_2` y `salsa_lenta`/`salsa_lenta_plus` son pares "básico vs. potenciado" del mismo concepto; se listan como `conflicts` para que el jugador elija un camino, no acumule ambos.
- `cadena_dorada` sinergiza con `chain_facil` (cadenas más fáciles de lograr con más probabilidad de efecto especial); **[riesgo de balance]**, ver sección 7.
- `escudo_taquero` y `segunda_oportunidad` son ambas redes de seguridad; ofrecerlas juntas en una misma partida podría reducir demasiado la tensión — **[riesgo de balance]**, ver sección 7.

---

## 5. Ingredientes (3) y recetas (5)

Todas las recetas usan un único ingrediente por cadena, conforme a `docs/CORE_RULES.md` (recetas mixtas quedan para después).

### 5.1 Ingredientes

```json
[
  {"id":"tortilla","display_name_key":"ingredient.tortilla","tier":1,"color_hint":"gold","base_satisfaction":10,"special_effect":"none"},
  {"id":"carne","display_name_key":"ingredient.carne","tier":1,"color_hint":"terracota","base_satisfaction":12,"special_effect":"none"},
  {"id":"verdura","display_name_key":"ingredient.verdura","tier":1,"color_hint":"verde","base_satisfaction":8,"special_effect":"none"}
]
```

- **Tortilla:** base versátil, satisfacción media. Papel estratégico: opción "segura" y más abundante en el tablero (facilita cadenas tempranas).
- **Carne:** mayor satisfacción por unidad; papel estratégico: mejor para monstruos de hambre alta (`tanque_salsero`) cuando se hacen cadenas de 3–4.
- **Verdura:** menor satisfacción por unidad pero más barata de generar visualmente como "extra"; papel estratégico: su cadena de 5 da un efecto de apoyo (ver receta `taco_verde_refrescante`), pensado para momentos defensivos.

### 5.2 Recetas

```json
[
  {"id":"taco_simple","display_name_key":"recipe.taco_simple","ingredients":{"tortilla":3},"satisfaction":30,"targeting":"nearest","effect":"none","feedback":"platillo básico, sonido corto y alegre"},
  {"id":"taco_carne_simple","display_name_key":"recipe.taco_carne_simple","ingredients":{"carne":3},"satisfaction":36,"targeting":"nearest","effect":"none","feedback":"sonido de sartén, golpe de satisfacción mayor"},
  {"id":"taco_verde_simple","display_name_key":"recipe.taco_verde_simple","ingredients":{"verdura":3},"satisfaction":24,"targeting":"nearest","effect":"none","feedback":"sonido fresco, salpicado verde breve"},
  {"id":"taco_dorado","display_name_key":"recipe.taco_dorado","ingredients":{"tortilla":5},"satisfaction":50,"targeting":"nearest","effect":"aturdimiento_breve","feedback":"destello dorado, el monstruo se detiene un instante a saborear"},
  {"id":"taco_verde_refrescante","display_name_key":"recipe.taco_verde_refrescante","ingredients":{"verdura":5},"satisfaction":40,"targeting":"nearest","effect":"reputacion_leve_mas","feedback":"brisa fresca, pequeño ícono de + reputación sobre el mostrador"}
]
```

- `taco_simple`, `taco_carne_simple`, `taco_verde_simple`: platillos básicos de cadena 3, uno por ingrediente, siguiendo el contrato canónico de `docs/CONTENT_MODEL.md`.
- `taco_dorado` (cadena 5 de tortilla): efecto especial "aturdimiento breve" — detiene un instante al monstruo objetivo, dando margen para atender otra amenaza. Piensa el jugador: "tortilla grande = respiro táctico".
- `taco_verde_refrescante` (cadena 5 de verdura): efecto especial "reputación leve +" — pequeña recuperación de reputación. Piensa el jugador: "verdura grande = red de seguridad defensiva".

> **[Alternativa]** Se consideró un efecto especial de cadena 5 también para `carne` (por ejemplo, daño extra sostenido contra `tanque_salsero`). Se deja fuera de esta propuesta para no superar el rango de 3–5 recetas pedido; queda como candidato natural para una segunda iteración de contenido.

---

## 6. Tutorial mínimo

Extremadamente corto: cuatro líneas de texto, todas disparadas por eventos de juego reales (no hay pantallas ni paneles separados). Se enseña jugando, dentro de la Oleada 1.

| Momento (evento disparador) | Texto visible (español) |
|---|---|
| Al iniciar `wave_01`, antes del primer spawn | "Desliza para conectar 3 tortillas iguales." |
| Cuando el primer `nibbler` entra en pantalla | "¡Tiene hambre! El platillo se sirve solo al más cercano." |
| Cuando el primer `nibbler` pasa la mitad de su carril sin ser atendido | "Si llega al mostrador, pierdes reputación." |
| Al abrirse la primera pantalla de mejora (fin de `wave_01`) | "Elige una mejora para la siguiente oleada." |

No hay quinto texto: si el jugador ya resolvió al primer `nibbler` antes de que aparezca el tercer texto, ese texto se omite (la advertencia de reputación solo tiene sentido si hay riesgo real).

---

## 7. Riesgos de balance, supuestos y preguntas abiertas

### 7.1 Riesgos de balance

- **Duración total probablemente excede los ~3 minutos objetivo.** Sumando solo la duración de las 5 oleadas (25+30+35+35+40 = 165 s ≈ 2 min 45 s) más las pausas de selección de mejora (4, posiblemente 5) y el combate contra el jefe, la partida completa probablemente ronda 3:45–4:30. **Esto es una alerta, no una corrección silenciosa**: se necesita decidir si se acortan oleadas, se reduce el número de pausas, o se ajusta el objetivo de duración.
- **Redes de seguridad acumuladas:** `escudo_taquero` + `segunda_oportunidad` + `reputacion_extra` en una misma partida podrían eliminar casi toda la tensión de perder. Sugerido (no implementado aquí): limitar cuántas mejoras de "seguridad" pueden ofrecerse por partida.
- **`cadena_dorada` + `chain_facil`:** combinar "cadenas de 2 cuentan" con "más probabilidad de efecto especial en cadena 4" podría trivializar el reto de formar cadenas grandes. Vigilar en pruebas.
- **`tanque_salsero` en oleada 3 (dos apariciones):** si el jugador no adoptó `taco_power` o el `taco_dorado`, dos tanques en una oleada de 35 s podrían sentirse injustos. Los tiempos de spawn son hipótesis y deben ajustarse con datos de prueba.
- **Autoapuntado + `chapulin_veloz`:** al ser tan rápido, si aparece a la vez que otro monstruo en el carril contrario, el autoapuntado podría "elegir mal" desde la perspectiva del jugador. Relacionado con la pregunta abierta existente "¿Autoapuntar se siente justo?" (`docs/OPEN_QUESTIONS.md`).

### 7.2 Supuestos usados en esta propuesta

- Los valores de `speed`, `hunger` y `reputation_damage` de los tres monstruos son relativos entre sí (no hay unidad de referencia definida aún); se asumió una escala donde `nibbler` es el punto medio.
- Se asumió que la reputación inicial es 100 (ya marcada como hipótesis en `docs/CORE_RULES.md`) para poder calibrar `reputation_damage` y las mejoras que la modifican.
- Se asumió que las mejoras se ofrecen de a tres opciones por pausa (regla ya descrita en `docs/CORE_RULES.md`: "elegir una de tres mejoras"), por lo que las 15 propuestas alcanzan para 5 pausas sin repetición si se desea.
- Se asumió que el jefe no genera monstruos adicionales ni tiene resistencias por ingrediente, para no ampliar el alcance del prototipo.

### 7.3 Validaciones realizadas

- Los 6 bloques/arreglos JSON de este documento fueron validados sintácticamente con un parser JSON (ver reporte de entrega).
- Se revisó cada monstruo, oleada, mejora y receta contra `docs/CORE_RULES.md` y `docs/CONTENT_MODEL.md` para mantener compatibilidad de campos (ids en `snake_case`, claves de texto en `display_name_key`, sin texto embebido en la lógica).
- Se revisó que ninguna propuesta contradiga `docs/DECISIONS.md` ni amplíe lo excluido en `docs/PROTOTYPE_SCOPE.md` (sin iOS, sin monetización, sin servidores, sin cuentas).
- Se contrastó cada mecanismo nuevo candidato (cambio de carril del `chapulin_veloz`, invocación de refuerzos del jefe, resistencias por ingrediente) contra el alcance aprobado; los tres se descartaron como propuesta principal y se dejaron como alternativas explícitas para no expandir el alcance sin aprobación.

### 7.4 Preguntas abiertas para Jorge y su hermano

1. ¿Se ajusta el objetivo de duración de partida (~3 min) o se recortan oleadas/pausas para cumplirlo? (ver riesgo 7.1)
2. ¿Debe ofrecerse una pausa de mejora justo antes del combate contra el jefe (después de la oleada 5), o el jefe inicia inmediatamente tras la oleada 5 sin mejora adicional?
3. ¿Se aprueba limitar cuántas mejoras de "red de seguridad" (`escudo_taquero`, `segunda_oportunidad`, `reputacion_extra`) pueden aparecer en una misma partida, o se deja sin límite para el prototipo inicial?
4. ¿Se desea, para una siguiente iteración, un efecto especial de cadena 5 también para `carne` (ver alternativa en sección 5.2), o se prefiere mantener la asimetría (solo tortilla y verdura tienen efecto de cadena grande) como parte del diseño?
5. ¿La escala relativa de `speed`/`hunger`/`reputation_damage` propuesta aquí es aceptable como punto de partida para que Codex la use al definir las unidades reales de implementación, o prefieren fijar primero una unidad de referencia (por ejemplo, celdas por segundo)?

---

*Fin de la propuesta. Ningún archivo fuera de este documento fue modificado.*
