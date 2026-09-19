# Backlog del prototipo

Estados: pendiente, en curso, revisión, terminado.

| ID | Tarea | Responsable | Dep. | Aceptación | Pri. | Tamaño | Estado |
|---|---|---|---|---|---|---|---|
| PRE-01 | Aprobar documentación M0 | Jorge | — | Decisiones y bloqueantes resueltos | P0 | S | terminado |
| PRE-02 | Crear contenido inicial | Claude | PRE-01 | Entrega según prompt y JSON válido | P0 | M | terminado |
| PRE-03 | Confirmar entorno físico iOS | Jorge/Codex | PRE-01 | iPhone 17/iOS 27.0 y iPhone 16 Pro Max/versión iOS registrados | P0 | XS | en curso |
| TEC-01 | Crear proyecto Godot vertical | Codex | PRE-01 | Abre sin error y escena raíz corre | P0 | S | terminado |
| TEC-02 | Registrar y validar contenido | Codex | PRE-02,TEC-01 | Rechaza IDs/referencias/rangos/claves/efectos inválidos con errores claros | P0 | M | terminado |
| BRD-01 | Renderizar tablero 5 × 5 | Codex | TEC-01 | 25 celdas adaptables | P0 | S | terminado |
| BRD-02 | Capturar cadena ortogonal | Codex | BRD-01 | Acepta 3+, rechaza diagonal/repetida y no intercambia fichas | P0 | M | terminado |
| BRD-03 | Resolver caída y relleno determinista | Codex | BRD-02 | Misma semilla y gestos producen el mismo tablero sin huecos | P0 | M | pendiente |
| BRD-04 | Recuperar tablero sin cadenas | Codex | BRD-03 | Reorganiza sin penalización y garantiza una cadena válida | P0 | S | pendiente |
| REC-01 | Resolver platillo por datos | Codex | TEC-02,BRD-02 | Resultado determinista probado | P0 | M | pendiente |
| LANE-01 | Tres carriles y movimiento | Codex | TEC-01 | Movimiento independiente configurable | P0 | M | pendiente |
| LANE-02 | Hambre, objetivo y satisfacción | Codex | REC-01,LANE-01 | Autoobjetivo predecible | P0 | M | pendiente |
| WAV-01 | Director de oleadas | Codex | TEC-02,LANE-01 | Ejecuta agenda y finaliza | P0 | M | pendiente |
| UPG-01 | Elegir una de tres mejoras tras cada oleada | Codex | WAV-01 | Hay cinco elecciones y como máximo una defensa fuerte | P0 | M | pendiente |
| BOSS-01 | Integrar jefe posterior a la quinta | Codex | WAV-01,UPG-01,PRE-02 | Comienza tras la quinta elección; fases comunicadas y resolubles | P0 | M | pendiente |
| UI-01 | HUD y reputación | Codex | LANE-02 | Estado legible en móvil | P0 | S | pendiente |
| UI-02 | Feedback audiovisual provisional | Codex | REC-01 | Acciones clave distinguibles | P1 | M | pendiente |
| SAV-01 | Guardar récord, monedas y preferencias | Codex | TEC-01 | Esquema versionado y escritura atómica persisten tras reinicio | P1 | M | pendiente |
| SAV-02 | Recuperar guardado inválido | Codex | SAV-01 | Ausente, parcial o corrupto no impide iniciar ni destruye un estado válido | P0 | S | pendiente |
| TST-01 | Pruebas de reglas centrales | Codex | BRD-04,LANE-02 | Suite con semillas fijas y validación de contenido pasa | P0 | M | pendiente |
| TST-02 | Pruebas de reinicio y observación | Codex/Jorge | TST-01,SAV-02 | Reinicios repetidos estables y registro separa hechos de interpretaciones | P1 | S | pendiente |
| IOS-01 | Exportar build iOS | Codex | M3,PRE-03 | Compila en Xcode, instala y abre en iPhone 17 | P0 | M | pendiente |
| IOS-02 | Medir build iOS | Codex | IOS-01 | Registra frame, memoria, carga y temperatura en iPhone 17 y humo en iPhone 16 Pro Max con build/commit | P0 | S | pendiente |
| VAL-01 | Dos pruebas independientes | Jorge/hermano | IOS-02 | Formatos completos, sin coaching y con build/commit | P0 | S | pendiente |
| VAL-02 | Decisión continuar/iterar/pivotar | Equipo | VAL-01 | Decisión respaldada por hallazgos | P0 | S | pendiente |
