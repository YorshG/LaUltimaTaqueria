# Backlog del prototipo

Estados: pendiente, en curso, revisión, terminado.

| ID | Tarea | Responsable | Dep. | Aceptación | Pri. | Tamaño | Estado |
|---|---|---|---|---|---|---|---|
| PRE-01 | Aprobar documentación M0 | Jorge | — | Decisiones y bloqueantes resueltos | P0 | S | pendiente |
| PRE-02 | Crear contenido inicial | Claude | PRE-01 | Entrega según prompt y JSON válido | P0 | M | pendiente |
| TEC-01 | Crear proyecto Godot vertical | Codex | PRE-01 | Abre sin error y escena raíz corre | P0 | S | pendiente |
| TEC-02 | Registrar contenido validado | Codex | PRE-02,TEC-01 | Errores claros ante datos inválidos | P0 | M | pendiente |
| BRD-01 | Renderizar tablero 5 × 5 | Codex | TEC-01 | 25 celdas adaptables | P0 | S | pendiente |
| BRD-02 | Capturar cadena ortogonal | Codex | BRD-01 | Acepta 3+, rechaza diagonal/repetida | P0 | M | pendiente |
| BRD-03 | Resolver caída y relleno | Codex | BRD-02 | Sin huecos ni estados imposibles | P0 | M | pendiente |
| REC-01 | Resolver platillo por datos | Codex | TEC-02,BRD-02 | Resultado determinista probado | P0 | M | pendiente |
| LANE-01 | Tres carriles y movimiento | Codex | TEC-01 | Movimiento independiente configurable | P0 | M | pendiente |
| LANE-02 | Hambre, objetivo y satisfacción | Codex | REC-01,LANE-01 | Autoobjetivo predecible | P0 | M | pendiente |
| WAV-01 | Director de oleadas | Codex | TEC-02,LANE-01 | Ejecuta agenda y finaliza | P0 | M | pendiente |
| UPG-01 | Elegir una de tres mejoras | Codex | WAV-01 | Modificador aplica solo a run actual | P1 | M | pendiente |
| BOSS-01 | Integrar jefe provisional | Codex | WAV-01,PRE-02 | Fases comunicadas y resolubles | P1 | M | pendiente |
| UI-01 | HUD y reputación | Codex | LANE-02 | Estado legible en móvil | P0 | S | pendiente |
| UI-02 | Feedback audiovisual provisional | Codex | REC-01 | Acciones clave distinguibles | P1 | M | pendiente |
| SAV-01 | Guardar récord, monedas y preferencias | Codex | TEC-01 | Persiste tras reinicio de app | P1 | S | pendiente |
| TST-01 | Pruebas de reglas centrales | Codex | BRD-03,LANE-02 | Suite repetible pasa | P0 | M | pendiente |
| AND-01 | Exportar APK | Codex | M3 | Instala y abre en Android | P0 | M | pendiente |
| VAL-01 | Dos pruebas independientes | Jorge/hermano | AND-01 | Formatos completos, sin coaching | P0 | S | pendiente |
| VAL-02 | Decisión continuar/iterar/pivotar | Equipo | VAL-01 | Decisión respaldada por hallazgos | P0 | S | pendiente |
