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
| Godot y Android primero | Sustituida | Reemplazada por iOS-first al dejar de estar disponible el Galaxy S24 Ultra |
| Offline y sin monetización | Aprobada para prototipo | Validar diversión primero |
| Galaxy S24 Ultra como dispositivo físico principal | Sustituida | El equipo ya no está disponible |
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
| Toolchain Android de Godot 4.7: JDK 17, Platform 35, Build-Tools 35.0.1, NDK r28b, CMake 3.10.2.4988404 | Sustituida | Android queda diferido después del prototipo iOS |
| Android Studio estable para administrar SDK | Sustituida | Android queda diferido después del prototipo iOS |
| iOS como primera plataforma del prototipo; Android diferido | Aprobada | El equipo dispone de dos iPhone físicos y ya no dispone del Galaxy S24 Ultra |
| iPhone 17 con iOS 27.0 como dispositivo físico principal | Aprobada | Dispositivo del Product Owner disponible para iteración frecuente |
| iPhone 16 Pro Max como segundo dispositivo físico | Aprobada | Permite validación independiente con el hermano del Product Owner; versión de iOS pendiente |
| Xcode 27 para compilar y desplegar en iOS 27 | Aprobada para implementación | Xcode 27 incluye SDK iOS 27 y soporte de dispositivo iOS 17–27 |
| Godot 4.7.2 stable + export templates iOS | Aprobada para implementación | Godot requiere macOS + Xcode y sus export templates para exportar a iOS |
| Apple Account / Personal Team suficiente para pruebas en dispositivos propios | Aprobada para prototipo | Apple permite pruebas personales sin membresía paga; los perfiles deben renovarse periódicamente |
| En LANE-02, `LaneMotion.progress >= 1.0` vuelve al monstruo inelegible sin procesar reputación | Aprobada para implementación | La llegada al mostrador será responsabilidad de un sistema posterior; LANE-02 no implementa breach ni `reputation_changed` |
| Un platillo sin objetivo se representa con `target_found: false` y sin evento adicional | Aprobada para implementación | Evita inventar `dish_wasted`/`dish_missed`; tampoco emite `dish_served` ni aplica satisfacción |
| `Main` aloja temporalmente el puente `BoardView` → `RecipeResolver` → `LaneField` | Aprobada como wiring temporal | Integra LANE-02 sin adelantar `GameSession`; WAV-01 o la futura sesión podrán reemplazarlo |
| `LaneMotion.progress` es la única fuente de verdad de avance del monstruo | Aprobada para implementación | `MonsterState` no duplica ni cachea posición, preservando el targeting determinista |
| En WAV-01, `duration_target_sec` es metadata de ritmo y no un timeout | Aprobada para implementación | Una oleada termina sólo tras despachar y resolver todos sus monstruos, aunque exceda la duración objetivo |
| WAV-01 considera resuelto a un monstruo satisfecho o que llega al mostrador | Aprobada para implementación | La llegada emite un evento one-shot y retira lógicamente la entidad sin aplicar todavía reputación |
| El countdown de WAV-01 es un parámetro explícito de `start_wave` | Aprobada para implementación | Evita congelar un valor de balance prematuro y mantiene `wave_elapsed_sec` separado del countdown |
| UPG-01 genera ofertas con semilla explícita sobre IDs ordenados; las elegidas no se repiten | Aprobada para implementación | Hace reproducibles las cinco elecciones sin depender del orden de diccionarios ni del RNG global |
| En UPG-01, rareza y sinergias son metadata; `strong_defense` es la exclusión primaria de defensas fuertes | Aprobada para implementación | Evita inventar pesos o mecánicas y garantiza como máximo una defensa fuerte incluso si los conflictos fueran redundantes |
| UI-02 avisa al cruzar desde arriba hacia `current / maximum <= 0.20` | Presentación provisional autorizada | Sólo feedback visual/sonoro; no cambia balance, reglas ni activa mejoras. No repite mientras siga bajo el umbral; recuperarse por encima permite un nuevo aviso al volver a cruzar |
