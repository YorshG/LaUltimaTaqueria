# Modelo de contenido

Contratos conceptuales; no son implementación definitiva.

## Ingrediente

```json
{"id":"tortilla","display_name_key":"ingredient.tortilla","tier":1,"color_hint":"gold","base_satisfaction":10,"special_effect":"none"}
```

## Receta

```json
{"id":"taco_simple","display_name_key":"recipe.taco_simple","ingredients":{"tortilla":3},"satisfaction":30,"targeting":"nearest","effect":"none"}
```

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
{"id":"taco_power_1","display_name_key":"upgrade.taco_power_1","rarity":"common","tags":["offense"],"effect":{"type":"modify_satisfaction","stat":"satisfaction_multiplier","operation":"multiply","value":1.2},"conflicts":[]}
```

## Jefe

```json
{"id":"boss_gloton","phases":[{"threshold":1.0,"speed_multiplier":1.0},{"threshold":0.5,"speed_multiplier":1.25}],"hunger":300}
```

## Localización

```json
{"ingredient.tortilla":"Tortilla","recipe.taco_simple":"Taco sencillo"}
```

Identificadores en inglés, `snake_case`, estables y sin texto visible embebido en lógica.

## Validación obligatoria

Antes de iniciar una partida, el registro de contenido debe comprobar:

- IDs únicos dentro de cada tipo y referencias existentes entre recetas, monstruos, oleadas y mejoras.
- Números finitos y dentro de rangos definidos; tiempos no negativos y carriles limitados a 0–2.
- Todas las claves visibles presentes en el catálogo de localización base.
- Valores de rareza, targeting, operación y tipo de efecto pertenecientes a catálogos cerrados.
- Ningún dato ejecuta scripts o expresiones arbitrarias.
- Conflictos y requisitos sin referencias rotas ni ciclos inválidos.

Las mejoras defensivas fuertes usan la etiqueta `strong_defense`. El generador de ofertas excluye el resto de esa etiqueta después de seleccionar una, garantizando el máximo de una por partida.
