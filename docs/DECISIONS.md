# Registro de decisiones

Fecha inicial: 2026-09-18.

| Decisión | Estado | Justificación |
|---|---|---|
| Nombre provisional: La Última Taquería | Aprobada | Identidad memorable; puede cambiar tras validación |
| Móvil vertical y una mano | Aprobada | Acceso rápido y sesiones cortas |
| Tablero inicial 5 × 5 y tres carriles | Aprobada para prototipo | Equilibrio inicial entre legibilidad y decisiones |
| Trazar cadenas ortogonales de 3+ ingredientes; sin intercambio match-3 | Aprobada | Interacción táctil directa y adecuada para una mano |
| Monstruos simpáticos hambrientos | Aprobada | Humor y público amplio |
| Alimentar, no matar | Aprobada | Diferenciación y tono familiar |
| Partidas de 4–5 minutos | Objetivo aprobado | Incluye cinco oleadas, cinco mejoras y jefe; debe medirse |
| Cinco oleadas normales y jefe después de la quinta | Aprobada | Separa con claridad el examen final de las oleadas pedagógicas |
| Una mejora después de cada oleada, incluida una quinta antes del jefe | Aprobada | Mantiene una elección por cierre de oleada |
| Máximo una mejora defensiva fuerte por partida | Aprobada | Evita acumular redes de seguridad que eliminen la tensión |
| Godot y Android primero | Aprobada | Alcance y costo |
| Offline y sin monetización | Aprobada para prototipo | Validar diversión primero |
| Galaxy S24 Ultra como dispositivo físico principal | Aprobada | Dispositivo disponible para las primeras pruebas; Android por confirmar |
| Monedas solo como marcador local, sin tienda ni desbloqueos | Aprobada para prototipo | Evita diseñar economía antes de validar el núcleo |
| Contenido basado en datos | Aprobada | Facilita balance y paralelo |
| Codex integra; Claude diseña contenido/módulos aislados | Aprobada | Reduce conflictos |
| Cadena 5+ conserva bono de cadena 4 y añade un efecto especial por ingrediente | Aprobada para prototipo | Evita penalizar cadenas largas y fija una sola interpretación de resolución |
| Ingrediente como fuente de verdad del efecto 5+; receta solo lo refleja | Aprobada para prototipo | Evita duplicidad y contradicciones de contenido |
| Catálogos y extensiones de mejoras de `CONTENT_MODEL.md` | Aprobados para prototipo | Permiten validación determinista antes de implementar |
| Conflictos de mejoras son simétricos; sinergias son informativas | Aprobada para prototipo | Simplifica validación y mantiene balance separado de lógica |
| Orden de modificadores de satisfacción definido en `CONTENT_MODEL.md` | Aprobado para prototipo | Garantiza resultados reproducibles |
| `monster_speed_global` también afecta al jefe | Aprobada para prototipo | Mantiene coherencia del modificador durante toda la partida |
| Textos de balance con cifras fijas, actualizados junto con los datos | Aprobada para prototipo | Evita introducir interpolación antes de validar el núcleo |
| Magnitudes iniciales 5+: stun 1.0 s, burst +12, restauración +5 | Hipótesis de prototipo | Valores iniciales medibles y ajustables sin cambiar contrato |
| Escala de velocidad relativa: 100 = 0.10 carriles/s; jefe base 25 | Hipótesis de prototipo | Permite implementar y medir sin congelar balance final |
| M0 / preproducción aprobada e integrada en main | Aprobada | PR #1 fusionado por el Product Owner |
| Rama `uat` como integración a partir de M1 | Aprobada | Mantiene `main` estable mientras se implementa y prueba |
| Godot 4.7.2 stable + GDScript para el prototipo | Aprobada para implementación | Versión estable vigente; alcance 2D y lógica de prototipo no requieren C# |
| Toolchain Android de Godot 4.7: JDK 17, Platform 35, Build-Tools 35.0.1, NDK r28b, CMake 3.10.2.4988404 | Aprobada para implementación | Alineado con la documentación oficial de exportación Android de Godot 4.7 |
| Android Studio estable para administrar SDK | Aprobada para implementación | Simplifica instalación y mantenimiento del toolchain Android en macOS |
