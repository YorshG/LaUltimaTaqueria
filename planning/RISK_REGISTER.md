# Registro de riesgos

| Riesgo | Prob. | Impacto | Señal temprana | Mitigación |
|---|---:|---:|---|---|
| Mecánica poco divertida | Alta | Alta | No repiten partida | Prototipo gris y pruebas tempranas |
| Tablero/carriles compiten | Alta | Alta | Ignoran una zona | Ritmo, señales y pausas ajustables |
| Gestos imprecisos | Media | Alta | Cadenas canceladas | Umbrales, feedback y pruebas físicas |
| Exceso de alcance | Alta | Alta | Nuevos sistemas antes de M3 | Alcance congelado |
| Identidad visual débil | Media | Media | Clips poco comprensibles | Siluetas y dirección consistente |
| Conflictos de colaboración | Media | Alta | Mismos archivos editados | Propiedad temporal y PR pequeños |
| Rendimiento Android | Media | Alta | Frames inestables | Pooling, límites y profiling temprano |
| Balance pobre | Alta | Media | Picos injustos o defensas acumuladas eliminan tensión | Datos externos, máximo una defensa fuerte y registros de prueba |
| Mucho contenido manual | Media | Media | M3 se retrasa | Reutilización y datos |
| Descubrimiento costoso | Alta | Alta | Poco interés orgánico | Validar clips antes de producción |
| Azar del tablero percibido como injusto | Media | Alta | Semillas sin cadenas útiles o resultados imposibles de reproducir | Semilla registrable, recuperación sin penalización y pruebas con semillas fijas |
| Guardado local corrupto | Baja | Media | Pérdida de marcador, récord o preferencias tras cierre | Esquema versionado, escritura atómica y recuperación de archivos inválidos |
| Contenido inválido llega a ejecución | Media | Alta | Referencias rotas o efectos desconocidos bloquean una partida | Validación previa de IDs, referencias, rangos, localización y catálogo cerrado |
