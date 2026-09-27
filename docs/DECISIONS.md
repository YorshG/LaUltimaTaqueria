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
| UPG-02 D1: la reputación mantiene precisión `float` interna, sin `ceil`, `floor` ni redondeo por operación; la presentación oculta decimales si el valor es entero y muestra hasta 2 decimales si existen (p. ej. 91.5, 21.25, 28.75, 6.5) | Aprobada para implementación | Multiplicadores como `patient_service` ×0.85, la restauración de `second_chance` y la restauración ×1.3 producen fracciones; no se altera el gameplay para ocultarlas |
| UPG-02 D2: se registra UPG-02 — Aplicar efectos de mejoras, dependiente de UPG-01, UI-01 y los módulos integrados que consume | Aprobada | Las mejoras hoy solo se ofrecen, seleccionan y almacenan; aceptación: las 15 mejoras vigentes modifican la partida según `docs/CONTENT_MODEL.md`, con pruebas deterministas y sin romper selección/ofertas |
| UPG-02 D3: no se añade `wave_started` a `WaveDirector` por ahora; la capa de sesión/wiring temporal en `Main` marca el inicio de cada encuentro al iniciar cada oleada normal y en `boss_started`, y ahí se rearma `warm_welcome` | Aprobada para implementación | Evita un evento nuevo en `WaveDirector` y define una frontera de encuentro única para oleadas y jefe |
| UPG-02 D4: orden contractual de una resolución: 1) `recipe.satisfaction`; 2) `satisfaction_flat_bonus`; 3) bono de cadena; 4) multiplicadores de satisfacción; 5) efecto especial 5+; 6) splash de `assist_serve`; 7) efectos globales posteriores al servicio, como restauración de reputación. El efecto 5+ y el splash son adicionales y no reciben los multiplicadores de los pasos 1–4 | Aprobada para implementación | Confirma la lectura literal del orden de `docs/CONTENT_MODEL.md` y lo extiende a splash y efectos posteriores sin ambigüedad |
| UPG-02 D5: `second_chance` es atómico: si una pérdida llevaría la reputación a 0 o menos y hay carga, consume una carga, no expone el 0 intermedio, restaura directamente al 25% del máximo, emite un único `reputation_changed` con el valor final y `extra_life_consumed`, y no emite `run_ended` | Aprobada para implementación | Evita derrotas transitorias, feedback de derrota espurio y dobles eventos observables por HUD/feedback |
| Umbral de reputación baja: el feedback de UI-02 usa `current / maximum <= 0.20` (presentación) y `last_stand` se activa solo con `< 0.20` (mecánica) | Aprobada; diferencia intencional | En exactamente 20% se avisa “Reputación baja” pero `last_stand` aún no aplica; no se debe unificar ni tratar como defecto |
| RST-01 se registra como requisito para la salida de M3 y depende de UPG-02; secuencia: UPG-02 → RST-01 → cierre/validación M3 → IOS-01 | Aprobada | TST-02 confirmó que no existe reinicio de partida activa con confirmación; “no arrastra upgrades” debe validarse sobre efectos runtime ya aplicados, no solo sobre IDs almacenados |
