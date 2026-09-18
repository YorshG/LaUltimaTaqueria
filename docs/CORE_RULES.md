# Reglas centrales — hipótesis iniciales

## Tablero

Cuadrícula 5 × 5. El jugador arrastra una cadena ortogonal de tres o más ingredientes iguales. No se permiten diagonales inicialmente. Al soltar, la cadena desaparece, crea un platillo y las celdas se rellenan desde arriba.

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

Comienzan tras cuenta regresiva breve y terminan cuando se generó y resolvió todo enemigo. Se pausa la acción para elegir una de tres mejoras. La quinta termina con jefe.

## Pausa y reinicio

Pausa manual y automática al perder foco. Reinicio requiere confirmación mientras una partida esté activa. Los valores exactos se ajustarán mediante datos.
