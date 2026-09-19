# Encargo inicial para Claude — contenido del prototipo

Actúa como diseñador de sistemas y balance de **La Última Taquería**. Lee primero `README.md`, `CLAUDE.md`, `docs/PROTOTYPE_SCOPE.md`, `docs/GAME_DESIGN.md`, `docs/CORE_RULES.md` y `docs/CONTENT_MODEL.md`.

## Contexto

Juego móvil vertical para una mano. En un tablero 5 × 5 se arrastran cadenas ortogonales de 3+ ingredientes iguales; no se intercambian fichas como en un match-3 tradicional. Los platillos alimentan automáticamente monstruos que avanzan por tres carriles. Hay cinco oleadas normales, una mejora después de cada una y un jefe posterior. Partida objetivo: 4–5 minutos. Tono familiar, colorido y mexicano respetuoso. Alimentar, no matar.

## Entrega

Produce un único documento Markdown con JSON válido donde aplique:

1. **Tres monstruos iniciales:** id, nombre, silueta, personalidad, comportamiento, velocidad relativa y valor inicial propuesto, hambre, daño de reputación, señales de hambre/satisfacción y diferencia estratégica.
2. **Un jefe:** identidad, fases, comportamiento, contrajuego y comunicación anticipada.
3. **Cinco oleadas:** duración, composición, tiempos de aparición, carriles, objetivo pedagógico, aumento de dificultad y cierre.
4. **Quince mejoras:** id, nombre, descripción, efecto estructurado, parámetros, rareza provisional, conflictos y sinergias.
5. **Tres ingredientes y 3–5 recetas:** ids, reglas, efecto, potencia inicial, feedback y papel estratégico.
6. **Tutorial mínimo:** textos y momento de aparición; debe enseñar jugando.
7. **Riesgos de balance y preguntas abiertas.**

## Reglas

- No escribas código ni cambies arquitectura.
- No agregues monetización, servidores, cuentas o metaprogresión compleja.
- Mantén todos los valores numéricos como hipótesis ajustables.
- Usa ids técnicos en inglés `snake_case` y texto visible en español.
- No dependas únicamente del color.
- Distingue: decisión aprobada, hipótesis y alternativa.
- Comprueba que los JSON sean sintácticamente válidos.
- Señala cualquier contradicción en vez de resolverla silenciosamente.

Finaliza usando `prompts/CLAUDE_DELIVERY_TEMPLATE.md`.
