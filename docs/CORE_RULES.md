# Reglas centrales — hipótesis iniciales

## Tablero

Cuadrícula 5 × 5. El jugador arrastra una cadena ortogonal de tres o más ingredientes iguales. No se permiten diagonales ni se usa intercambio tradicional match-3. Una celda no puede repetirse dentro de la misma cadena. Al soltar una cadena válida, esta desaparece, crea un platillo y las celdas se rellenan desde arriba.

La generación inicial y los rellenos usan una semilla registrable por partida. La misma semilla y los mismos gestos deben reproducir el mismo resultado lógico para facilitar diagnóstico y pruebas.

Después de cada relleno se comprueba que exista al menos una cadena ortogonal válida de tres o más. Si no existe, el tablero se reorganiza automáticamente, sin penalización, conservando la semilla y garantizando una cadena válida antes de devolver el control.

## Platillos

- Cadena de 3: platillo básico.
- Cadena de 4: +50% de satisfacción.
- Cadena de 5 o más: efecto especial definido por ingrediente.
- Las recetas mixtas se habilitarán después de validar la combinación básica.

## Objetivos

El platillo selecciona automáticamente al monstruo más cercano al mostrador que pueda recibir su efecto. Empates: carril central, izquierdo, derecho. La interfaz debe anticipar el objetivo.

## Monstruos y reputación

Cada monstruo tiene velocidad y satisfacción requerida. Los platillos reducen su hambre; al llegar a cero sale satisfecho. Si llega al mostrador, consume reputación y se retira. Reputación inicial provisional: 100.

## Oleadas

Comienzan tras cuenta regresiva breve y terminan cuando se generaron y resolvieron todos los monstruos programados. Hay cinco oleadas normales. Después de cada oleada se detienen la simulación y sus temporizadores para elegir una de tres mejoras; la quinta elección ocurre antes del jefe. El jefe comienza después de esa elección y no forma parte de la quinta oleada.

Solo puede seleccionarse una mejora etiquetada como defensa fuerte por partida. Una vez elegida, las demás mejoras con esa etiqueta dejan de ser elegibles. La partida completa tiene una duración objetivo de 4–5 minutos.

## Pausa y reinicio

Pausa manual y automática al perder foco. Los temporizadores de juego se detienen también durante selección de mejoras, pausa, tutorial bloqueante y otros overlays modales. Reinicio requiere confirmación mientras una partida esté activa. Los valores exactos se ajustarán mediante datos.
