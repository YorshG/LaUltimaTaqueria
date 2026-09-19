# Modelo de contenido

Contratos conceptuales congelados para el prototipo M0. Los valores de balance siguen siendo ajustables mediante datos, pero la forma de los datos y su semántica no deben cambiar durante implementación sin una decisión registrada.

## Escala de velocidad

`speed` es un coeficiente relativo. `100` equivale a `lane_reference_speed`, cuyo valor inicial de prototipo es **0.10 longitudes de carril por segundo**.

`effective_lane_speed = lane_reference_speed × speed / 100 × phase_multiplier × monster_speed_global`

`monster_speed_global` aplica también al jefe. Los valores exactos se medirán y podrán ajustarse como datos sin cambiar este contrato.

## Ingrediente

El ingrediente es la única fuente de verdad del efecto especial de una cadena de 5+.

```json
{"id":"tortilla","display_name_key":"ingredient.tortilla","tier":1,"color_hint":"gold","base_satisfaction":10,"special_effect":"brief_stun","special_effect_params":{"duration_sec":1.0}}
```

Catálogo cerrado inicial de `special_effect`:

- `brief_stun`: `duration_sec` > 0. Valor inicial: 1.0 s.
- `bonus_satisfaction_burst`: `amount` > 0. Valor inicial: 12 puntos de satisfacción.
- `reputation_small_restore`: `amount` > 0. Valor inicial: 5 puntos de reputación.

No se permite `none` en ingredientes jugables del prototipo porque `docs/CORE_RULES.md` exige un efecto especial para cadenas de 5+.

## Receta

```json
{"id":"taco_simple","display_name_key":"recipe.taco_simple","ingredients":{"tortilla":3},"satisfaction":30,"targeting":"nearest","effect":"brief_stun"}
```

Reglas:

- Cada receta del prototipo usa un solo ingrediente.
- `recipe.effect` debe ser idéntico a `ingredient.special_effect` del ingrediente referenciado.
- El campo `effect` solo se activa en cadenas de 5+; en cadenas de 3 y 4 no se ejecuta.
- Cadena 3: satisfacción base.
- Cadena 4: satisfacción base × 1.5.
- Cadena 5+: satisfacción de cadena 4 + un disparo del efecto especial del ingrediente.
- `targeting` cerrado a `nearest` durante el prototipo.

## Monstruo

```json
{"id":"nibbler","display_name_key":"monster.nibbler","speed":55,"hunger":30,"reputation_damage":10,"tags":["basic"]}
```

## Oleada

```json
{"id":"wave_01","duration_target_sec":25,"spawns":[{"at_sec":2,"monster_id":"nibbler","lane":1}],"teaches":"basic_match"}
```

## Mejora

```json
{"id":"taco_power_1","display_name_key":"upgrade.taco_power_1","description_key":"upgrade.taco_power_1.desc","rarity":"common","tags":["offense"],"effect":{"type":"modify_satisfaction","stat":"satisfaction_multiplier","operation":"multiply","value":1.15},"conflicts":["taco_power_2"],"synergies":["extra_bite"],"notes":"Opcional; solo documentación"}
```

Campos:

- `description_key`: obligatorio y localizable.
- `conflicts`: relación mecánica; debe ser simétrica.
- `synergies`: relación informativa de diseño; debe ser simétrica y no modifica ofertas ni lógica.
- `effect.params`: parámetros adicionales definidos por el tipo.
- `notes`: opcional; el cargador puede ignorarlo.
- Una pareja no puede estar simultáneamente en `conflicts` y `synergies`.
- La prohibición de ciclos aplica a dependencias/requisitos futuros, no a conflictos simétricos.

Catálogos cerrados:

- `operation`: `add`, `multiply`.
- `rarity`: `common`, `rare`, `epic`.
- `tags`: `offense`, `defense`, `utility`, `strong_defense`.
- `condition`: `first_dish_of_encounter`, `reputation_below_ratio`.

### Catálogo de `effect.type`

| Tipo | Stats permitidos | Params |
|---|---|---|
| `modify_satisfaction` | `satisfaction_multiplier`/multiply, `satisfaction_flat_bonus`/add | — |
| `modify_chain_bonus` | `chain4_satisfaction_bonus`/add | — |
| `modify_special_effect` | `special_effect_power_multiplier`/multiply | — |
| `add_splash_satisfaction` | `chain4_splash_satisfaction`/add | — |
| `conditional_satisfaction` | `satisfaction_multiplier`/multiply | `condition`; `threshold` 0–1 solo con `reputation_below_ratio` |
| `modify_reputation` | `reputation_max`/add, `reputation_damage_taken`/multiply | — |
| `grant_charge` | `reputation_shield_charges`/add, `extra_life_charges`/add | `restore_ratio` 0–1 solo para `extra_life_charges` |
| `modify_monster_stat` | `monster_speed_global`/multiply | — |
| `modify_input` | `input_forgiveness`/add | — |

`input_forgiveness` usa una unidad normalizada al tamaño de celda: `0.10` añade un margen equivalente al 10% del menor lado de la celda al hit-test del trazo.

`modify_special_effect` multiplica el parámetro numérico principal del efecto 5+: duración para `brief_stun`, `amount` para `bonus_satisfaction_burst` y `reputation_small_restore`.

## Orden de satisfacción

Orden determinista para una resolución:

1. `recipe.satisfaction`.
2. Sumar `satisfaction_flat_bonus`.
3. Aplicar bono de cadena: cadena 3 = ×1.0; cadena 4 o 5+ = ×(1.5 + `chain4_satisfaction_bonus`).
4. Aplicar multiplicadores de satisfacción activos, todos de forma multiplicativa.
5. En cadena 5+, ejecutar una vez el efecto especial del ingrediente.

Los efectos secundarios de una mejora pueden afectar a un objetivo adicional si su tipo lo define, pero el objetivo primario continúa siendo el más cercano según `docs/CORE_RULES.md`.

## Jefe

```json
{"id":"boss_big_glutton","display_name_key":"boss.big_glutton","speed":25,"hunger":300,"reputation_damage_on_breach":40,"lane":1,"phases":[{"threshold":1.0,"speed_multiplier":1.0},{"threshold":0.6,"speed_multiplier":1.25},{"threshold":0.3,"speed_multiplier":1.4}]}
```

## Localización

```json
{"ingredient.tortilla":"Tortilla","recipe.taco_simple":"Taco sencillo","upgrade.taco_power_1.desc":"Tus platillos satisfacen 15% más."}
```

Para el prototipo, las descripciones pueden contener cifras fijas. Cualquier cambio de balance que altere una cifra visible debe actualizar su cadena localizada en el mismo commit. No se introduce interpolación dinámica en M0.

Identificadores técnicos en inglés, `snake_case`, estables y sin texto visible embebido en lógica.

## Validación obligatoria

Antes de iniciar una partida, el registro de contenido debe comprobar:

- IDs únicos dentro de cada tipo y referencias existentes.
- Números finitos y dentro de rangos definidos; tiempos no negativos y carriles 0–2.
- Todas las claves visibles presentes en el catálogo base de localización.
- Catálogos cerrados de rareza, targeting, operación, tags, condiciones, tipos de efecto y efectos especiales.
- Compatibilidad entre `effect.type`, `stat`, `operation` y `params`.
- `recipe.effect == ingredient.special_effect` para su ingrediente.
- Todo ingrediente jugable tiene un efecto especial válido de cadena 5+ y parámetros válidos.
- `conflicts` y `synergies` sin referencias rotas, autorreferencias ni solapamientos; ambas relaciones son simétricas.
- Ningún dato ejecuta scripts o expresiones arbitrarias.

Las mejoras defensivas fuertes usan `strong_defense`. Después de seleccionar una, el generador excluye las demás mejoras con esa etiqueta durante el resto de la partida.
