# Definición de terminado

Una tarea está terminada cuando:

- Cumple todos sus criterios de aceptación.
- Respeta alcance, arquitectura y contratos vigentes.
- No deja errores críticos conocidos.
- Incluye pruebas o verificación apropiada.
- Funciona en el entorno objetivo cuando aplica.
- Actualiza documentación si cambió un contrato.
- Entrega reporte de archivos, decisiones, pruebas, riesgos y pendientes.
- No introduce dependencia o ampliación no aprobada.
- Está revisada e integrada en la rama correspondiente.

## Evidencia mínima por tipo de tarea

- **Documentación:** enlaces válidos, Markdown legible, búsqueda de términos obsoletos y revisión de contradicciones.
- **Contenido:** esquema validado, IDs y referencias consistentes, claves de localización presentes y parámetros marcados como hipótesis cuando corresponda.
- **Lógica:** pruebas de casos normales, bordes y errores; semilla o pasos suficientes para reproducir fallos.
- **Interfaz y accesibilidad:** prueba de ambas manos, expansión de texto/Unicode, silencio, reducción de movimiento y overlays sin temporizadores activos.
- **Persistencia:** pruebas de versión, escritura interrumpida y archivos ausentes, parciales o corruptos.
- **Build iOS:** dispositivo, versión iOS, build, commit, tiempo de frame, memoria, carga, temperatura y resultado de humo registrados; incluir al menos iPhone 17 principal y humo en iPhone 16 Pro Max.
