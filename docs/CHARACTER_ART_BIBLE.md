# Biblia de arte de personajes

Documento de referencia para dirigir concept art de los monstruos y el jefe de La Última Taquería. Convierte en documentación oficial la dirección visual acordada en el canal `#laultimataqueria` (hilo de aprobación de dirección visual, 2026-09-21).

Este documento es de diseño de arte únicamente. No modifica `docs/ART_STYLE.md`, `docs/GAME_DESIGN.md`, `docs/CONTENT_MODEL.md`, datos en `data/content/`, balance, nombres, tags ni código. Es complementario a `docs/ART_STYLE.md`: donde este documento entra en detalle, `docs/ART_STYLE.md` sigue siendo la referencia de principios generales.

## Estado de las decisiones en este documento

Siguiendo la convención de `docs/DECISIONS.md`, cada sección marca su estado:

- **Aprobada**: ya validada por el Product Owner en el hilo de Slack del 2026-09-21.
- **Hipótesis de arte**: dirección de trabajo para el concept art, sujeta a ajuste una vez que exista arte real.
- **Guía inicial, no contractual**: valores de referencia (proporciones, colores) que orientan sin congelar producción final.

## 1. Dirección común (Aprobada)

- 2D plano estilizado. No se evalúa 2.5D en esta etapa del prototipo.
- Contorno grueso y oscuro, cel-shading simple de dos tonos (base + sombra) — sin gradientes suaves ni texturas de detalle fino que se pierdan a tamaño de ícono.
- Alta legibilidad móvil: cada personaje se construye desde una forma dominante reconocible a distancia, coherente con el pilar "comprensión en segundos" de `docs/GAME_DESIGN.md`.
- Proporción cabeza grande / cuerpo compacto para reforzar un tono simpático y no amenazante, alineado con `docs/ART_STYLE.md` ("monstruos simpáticos, expresivos y no aterradores").
- Nivel de detalle bajo-medio: máximo 3-4 lecturas de información por personaje (forma + rasgo facial + accesorio + color) para no competir por atención con ingredientes, platillos y HUD del tablero.
- Material base compartido entre los cuatro personajes (textura ligera tipo papel picado/servilleta) más un material distintivo por personaje, para que se lean como una misma familia visual.

## 2. Regla cultural (Aprobada)

Las referencias mexicanas se expresan a través de comida, taquería y props de cocina (delantales, salsas, charolas, vapor, ingredientes), nunca como vestimenta o rasgos étnicos puestos sobre el monstruo. Ningún personaje usa sombrero, bigote, sarape ni acento visual que funcione como estereotipo. El humor proviene de la situación — un monstruo entrañable devorando tacos — y de los props de cocina, no de la identidad del personaje. Esta regla tonal aplica a todo el juego (incluidos textos y recetas), pero este documento no rediseña recetas ni nombres: solo cubre el tratamiento visual de los cuatro personajes existentes.

## 3. Fichas de personaje

### 3.1 Nibbler — Mordisqueador (`nibbler`, básico)

- **Forma dominante**: gota/óvalo redondeado — silueta neutra de referencia contra la que se comparan los otros roles.
- **Rostro**: ojos grandes y redondos centrados; boca pequeña, siempre visible.
- **Personalidad**: curioso, entusiasta, torpe — "el recluta" de la invasión.
- **Postura**: erguido, brincos cortos al avanzar.
- **Detalles/accesorios**: ninguno o mínimo (una mancha de salsa en el mentón) — se mantiene limpio a propósito, ya que es la unidad base de comparación.
- **Rol visual**: es el punto de referencia; todo lo demás en la familia se lee "más grande", "más aplanado" o "más afilado" que Nibbler.
- **Rasgos invariantes**: proporción ovalada y tamaño de ojos consistentes en todos los estados; la boca mantiene una muesca o color interior fijo como ancla incluso abierta al morder.

### 3.2 Salsa Tank — Tanque salsero (`salsa_tank`, lento/tanque)

- **Forma dominante**: trapecio ancho y bajo, base pesada.
- **Rostro**: ojos entrecerrados/serios; boca ancha tipo mueca de esfuerzo.
- **Personalidad**: terco, imperturbable — "el que absorbe golpes".
- **Postura**: centro de gravedad bajo, pasos pesados y cortos, cuerpo ligeramente inclinado hacia adelante.
- **Detalles/accesorios**: caparazón o placas tipo concha en el lomo — prop de comida, no armadura militar, para no perder el tono no amenazante.
- **Rol visual**: ancho + bajo + caparazón comunican "esto aguanta mucho y no corre" desde la forma, antes de que se mueva.
- **Rasgos invariantes**: el caparazón está presente en todos los estados, incluidos stun y breach; el ancho de la silueta se mantiene notoriamente mayor que el de Nibbler en toda animación.

### 3.3 Swift Hopper — Chapulín veloz (`swift_hopper`, rápido/prioritario)

- **Forma dominante**: óvalo alargado en diagonal, como si ya estuviera en movimiento incluso en reposo.
- **Rostro**: ojos rasgados/enfocados hacia adelante; boca pequeña en punta.
- **Personalidad**: nervioso, ágil, siempre a punto de saltar.
- **Postura**: agachado, tensión tipo resorte, listo para saltar.
- **Detalles/accesorios**: patas traseras notoriamente más largas (referencia a chapulín/saltamontes); estela cosmética sutil opcional al moverse.
- **Rol visual**: delgadez + diagonal + patas largas comunican "atiéndeme ya"; es, a propósito, la silueta más distinta a Nibbler, porque es el rol que exige prioridad de atención.
- **Rasgos invariantes**: el ángulo diagonal y las patas largas están presentes en todos los estados, incluidas las poses estáticas de reducción de movimiento.

### 3.4 El Gran Glotón — jefe (`boss_big_glutton`)

- **Forma dominante**: masa redonda enorme, centro de gravedad muy bajo — "panza" como forma principal, no un humanoide alto.
- **Rostro**: boca desproporcionadamente grande como rasgo central del personaje; ojos pequeños en comparación.
- **Personalidad**: glotón bonachón; la intensidad crece con las fases pero nunca cruza a terror — más "niño con mucha hambre" que villano.
- **Postura**: fase 1 (calma) relajada, panza al frente; fase 2 (60%, `phase2_transition_cue_cosmetic_only`) inclinado hacia adelante y más tenso; fase 3 (30%, `final_bite`) postura de embate, boca más abierta.
- **Detalles/accesorios**: un babero/servilleta visible desde el inicio de la partida.
- **Rol visual**: la escala (2-3x un monstruo básico) más la boca protagonista hacen del jefe un objetivo central obvio; los cambios de postura entre fases comunican la escalada de `data/content/boss.json` sin necesitar HUD.
- **Rasgos invariantes**: el babero es el mismo objeto en las tres fases — solo cambia su inclinación y tensión visual, nunca se reemplaza ni debe leerse como un accesorio o personaje distinto. La forma base de la boca se mantiene reconocible aun exagerada en la fase final.

## 4. Paletas conceptuales (Hipótesis de arte — colores no congelados)

Cada personaje tiene un color de familia cálido más un acento, pensados como punto de partida para concept art, no como valores finales de producción:

- **Nibbler**: base amarillo-maíz cálido, acento verde suave. Es el "neutro" de la paleta.
- **Salsa Tank**: base rojo-salsa saturado, acento café oscuro en el caparazón.
- **Swift Hopper**: base verde-chile intenso, acento amarillo brillante en las patas.
- **El Gran Glotón**: base café dorado horneado, babero en blanco hueso que cambia de tensión/textura entre fases, no de matiz.

**Regla explícita (Aprobada)**: ningún personaje puede distinguirse solo por matiz o saturación de color. La diferenciación se apoya en silueta, valor/contraste y detalle estructural (accesorio, proporción, postura); el color es siempre un refuerzo adicional, nunca la única señal. Esto debe poder verificarse desaturando el arte final y confirmando que los cuatro personajes siguen siendo distinguibles entre sí.

## 5. Familias de animación aprobadas

Estructura pensada para reutilizar loops y mantenerse dentro del presupuesto de "pocos frames, atlas pequeños" de `docs/ART_STYLE.md`.

### 5.1 Animaciones completas (compartidas en estructura entre `nibbler`, `salsa_tank` y `swift_hopper`)

1. **Locomoción base** (idle/avance) — timing relativo al `speed` de cada personaje en `data/content/monsters.json`.
2. **Hambre/expresión** — loop de espera mientras el monstruo no ha sido atendido.
3. **Recibir + bocado** — anticipación corta más mordida; es el equivalente visual a las señales sonoras "cadena válida", "receta creada" y "platillo servido" de `docs/AUDIO_STYLE.md`.
4. **Satisfacción + salida** — reacción de gusto y retirada combinadas en una sola pieza de animación.
5. **Breach (llegada al mostrador)** — pose de impacto propia, visualmente distinta a satisfacción, con su propia salida de "no atendido".

El jefe reutiliza esta misma estructura de 5 animaciones completas, adaptada a su escala y timing.

### 5.2 Overlays / poses cortas (no son animaciones completas independientes)

- **Stun**: overlay sobre la locomoción/idle — congela la pose y agrega ojos en espiral o parpadeo más pequeñas estrellas; pausa el loop base sin reemplazarlo. Aplica al efecto `brief_stun` descrito en `docs/CONTENT_MODEL.md`.
- **Cues de fase del jefe** (60% y 30%): overlay de postura sobre la locomoción base del jefe — cambia inclinación, tensión del babero y expresión. No genera una animación independiente nueva; los `behavior_tag` de `data/content/boss.json` ya documentan estos cues como cosméticos.

### 5.3 Variantes de reducción de movimiento (Aprobada, requisito de `docs/UX_AND_ACCESSIBILITY.md`)

Toda animación con trayectoria amplia (salto de Swift Hopper, embate del jefe, sacudida de stun) necesita una versión simplificada que sustituya el desplazamiento grande por un cambio de pose o expresión estático o de rango corto, sin perder la información que comunica. La reducción de movimiento sustituye sacudidas y trayectorias amplias; no elimina la señal, solo su amplitud de movimiento.

## 6. Feedback de breach — señal múltiple (Aprobada)

El breach (llegada al mostrador sin ser atendido) debe comunicarse con más de una señal, ninguna de ellas dependiente exclusivamente de color:

- **Cambio de pose/silueta** (impacto o mordida al mostrador) — señal primaria; funciona sin sonido y sin depender de color, cumpliendo el requisito de `docs/UX_AND_ACCESSIBILITY.md` de que el juego se entienda en silencio.
- **Icono o feedback visual** sobre el personaje (por ejemplo, un plato agrietado o un ícono de daño a reputación) — segunda señal, compatible con daltonismo.
- **Flash rojo de contorno** — únicamente un refuerzo cosmético opcional; nunca puede ser la única señal de breach.

## 7. Riesgos de legibilidad específicos por personaje

Prueba conceptual: verificar la silueta de cada personaje reducida a 32 px como test de legibilidad mínima. Esto es una prueba de diseño, no un tamaño obligatorio de render final.

- **Nibbler**: a 32 px se reduce a un círculo con dos puntos de ojos. Riesgo: sin accesorio, puede confundirse con un "blob" genérico de cualquier otro juego o asset provisional. Mitigación propuesta: mantener el tamaño de ojos grande como firma consistente incluso sin accesorio.
- **Salsa Tank**: a 32 px el trapecio y el caparazón se reducen a una mancha ancha con textura arriba. Riesgo: si el caparazón se aplana visualmente, puede leerse igual que Nibbler "solo más ancho". Mitigación propuesta: exagerar el ancho relativo de la silueta frente a Nibbler como guía inicial a validar, no como requisito contractual.
- **Swift Hopper**: a 32 px la diagonal y las patas largas deben sobrevivir como una forma inclinada con líneas delgadas debajo. Riesgo: las patas finas pueden desaparecer al escalar o comprimir la imagen. Mitigación propuesta: definir un grosor mínimo fijo en píxeles para las patas, sin escalarlas proporcionalmente por debajo de ese piso.
- **El Gran Glotón**: aunque su tamaño real en pantalla es mayor por tratarse del jefe, la boca grande debe seguir siendo el elemento más reconocible a distancia. Riesgo: si el babero se reduce demasiado en la prueba de 32 px, las fases 2 y 3 pueden verse casi idénticas. Mitigación propuesta: la inclinación de postura, no el babero, es la señal primaria de cambio de fase; el babero funciona como refuerzo, ya visible con claridad al tamaño real del jefe en pantalla.

## 8. Prompts maestros de generación visual

Prompts completos para producir concept art consistente. No se generan imágenes en este documento. Cada prompt incluye, además de su descripción específica, el bloque común de consistencia acordado para que las cuatro piezas compartan un mismo universo visual.

**Bloque común de consistencia** (aplicado a los cuatro prompts): mismo universo visual, mismo grosor de línea de contorno, misma filosofía de proporciones (cabeza grande / cuerpo compacto), mismo estilo de cel-shading de dos tonos, misma vista de tres cuartos de frente, misma iluminación cálida de referencia, y misma presentación de hoja conceptual (fondo neutro, personaje centrado, sin efectos de composición adicionales).

### 8.1 Nibbler

"2D stylized mobile game monster character, round teardrop silhouette, big round friendly eyes, small mouth, warm corn-yellow base color with soft green accent, thick dark outline, flat cel-shading with two-tone shading, no realistic anatomy, cute non-threatening creature, simple food-inspired texture, single dominant rounded shape, clean readable silhouette at small icon size, front-facing three-quarter view, plain neutral background, warm reference lighting, concept sheet presentation, same visual universe and line weight and proportion philosophy and shading style and camera angle and lighting as the rest of this monster family."

### 8.2 Salsa Tank

"2D stylized mobile game monster character, wide low trapezoid silhouette, heavy low center of gravity, squinting determined eyes, wide mouth, deep saturated salsa-red base color with dark brown shell-like plating on the back, thick dark outline, flat cel-shading, sturdy tank archetype but friendly and non-threatening, food-inspired shell texture, clean readable silhouette at small icon size, front-facing three-quarter view, plain neutral background, warm reference lighting, concept sheet presentation, same visual universe and line weight and proportion philosophy and shading style and camera angle and lighting as the rest of this monster family."

### 8.3 Swift Hopper

"2D stylized mobile game monster character, slim elongated diagonal-leaning silhouette, long grasshopper-like hind legs, sharp focused eyes, small pointed mouth, intense chile-green base color with bright yellow accent on legs, thick dark outline, flat cel-shading, coiled ready-to-jump posture, fast and agile but cute non-threatening creature, clean readable silhouette at small icon size, front-facing three-quarter view, plain neutral background, warm reference lighting, concept sheet presentation, same visual universe and line weight and proportion philosophy and shading style and camera angle and lighting as the rest of this monster family."

### 8.4 El Gran Glotón (jefe)

"2D stylized mobile game boss monster character, huge round low-slung belly silhouette, oversized mouth as central feature, small eyes, earthy golden-brown baked-crust base color, visible bib/napkin accessory in bone-white that stays the same object across all phases with only tilt and tension changing, thick dark outline, flat cel-shading, calm friendly glutton personality despite large scale, non-threatening and charming not scary, food-inspired texture, clean readable silhouette even at small size, front-facing three-quarter view, plain neutral background, warm reference lighting, concept sheet presentation, same visual universe and line weight and proportion philosophy and shading style and camera angle and lighting as the rest of this monster family."

## 9. Tabla resumen

| Personaje | Forma dominante | Color base (hipótesis) | Accesorio clave | Postura | Rol visual | Rasgo invariante |
|---|---|---|---|---|---|---|
| Nibbler | Gota redonda | Amarillo-maíz | Ninguno (neutro) | Erguido, brinco corto | Básico / referencia | Proporción ovalada + tamaño de ojos |
| Salsa Tank | Trapecio ancho | Rojo-salsa | Caparazón dorsal | Bajo, pesado | Tanque / lento | Caparazón siempre visible + ancho notorio |
| Swift Hopper | Gota alargada diagonal | Verde-chile | Patas traseras largas | Agachado, en tensión | Veloz / prioridad | Ángulo diagonal + patas largas |
| El Gran Glotón | Masa redonda enorme | Café dorado horneado | Babero (mismo objeto en 3 fases) | Calma → inclinado → embate | Jefe / escalada | Babero reconocible + forma base de boca |

## 10. Pipeline recomendado

1. Biblia de arte de personajes (este documento).
2. Concept art por personaje, a partir de los prompts maestros de la sección 8.
3. Prueba de legibilidad a 32 px (sección 7) sobre el concept art resultante.
4. Selección de la dirección final por personaje.
5. Character sheets (vistas múltiples, expresiones, proporciones finales).
6. Producción de sprites y animación, siguiendo las familias de animación de la sección 5.

## 11. Fuera de alcance de este documento

- Cualquier cambio a nombres, stats, tags o comportamiento de oleada/jefe en `data/content/`.
- Colores exactos, anchos exactos, número de frames por animación y dimensiones finales de sprites — quedan como guías iniciales a validar en el pipeline, no como valores contractuales.
- Diseño de HUD o indicadores de progreso de hambre/reputación.
- Nuevos monstruos o variantes de los cuatro personajes existentes.
- Rediseño de recetas, ingredientes o textos, más allá del tono cultural ya descrito en la sección 2.
