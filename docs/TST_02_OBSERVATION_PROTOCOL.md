# TST-02 — Reinicios y observación

Criterio: reinicios repetidos estables y registro que separa hechos de interpretaciones.
Complementa [TEST_PLAN.md](TEST_PLAN.md); no sustituye IOS-02 ni VAL-01.

## Alcance y gap conocido

La acción interna **«Reiniciar partida» aún no está implementada como contrato
ejecutable en el prototipo actual**. No hay reinicio de partida activa con
confirmación ni GameSession/Navigation definitivos. Los resets de componentes
y `SaveService.reset()` no equivalen a esa operación. Es un gap previo a TST-02,
no un fallo introducido por estas pruebas; no se marca como PASS.

Aquí un reinicio es cerrar el proceso completo y abrir otro que cargue Main.
La persistencia se comprueba por separado mediante un driver de SaveService:
Main todavía no integra el guardado. Solo se conservan récord, monedas y
preferencias; no se presupone persistencia de reputación, oleada, upgrades,
tablero, jefe, semilla, temporizadores ni feedback de una partida en curso.

## Automatización reproducible

Desde la raíz, con Godot 4.7.2, Bash y Python 3 (solo biblioteca estándar):

```bash
bash tests/run_restart_suite.sh
```

`GODOT_BIN` permite elegir el ejecutable. El runner resuelve la raíz desde su
ubicación, importa una vez (timeout de 60 s) y abre 10 procesos consecutivos con
`--scene res://scenes/Main.tscn --quit-after 3`. Ese 3 indica iteraciones del
bucle, no segundos. Cada proceso tiene un timeout de 30 s; exige exit 0, el
mensaje vigente al final de `_ready()` exactamente una vez y ausencia de errores
de script/motor o diagnósticos de crash/recursos pendientes al salir.

En otros procesos independientes comprueba:

- A guarda `record=123`, `coins=456`, `preferences={"test_option": true}`;
  B y C cargan exactamente esos valores.
- A recupera JSON corrupto: `RECOVERED`, defaults y original en cuarentena;
  B recibe `MISSING`, defaults sin escritura implícita y hace `save()` explícito;
  C recibe `LOADED` con defaults persistidos. La cuarentena conserva sus bytes.
- Cinco cargas adicionales del save válido conservan valores, bytes y entradas
  del directorio; no crean temporales ni cuarentenas.
- Cinco cargas con primary válido y `.tmp` parcial preservan ambos byte por byte,
  sin promover el temporal ni crear cuarentenas.

El probe acepta modo y ruta absoluta explícitos después de `--`; requiere el
marcador `.tst-02-fixture` que crea el runner. Todos los saves, cuarentenas y logs
de esta suite viven en un directorio temporal; no usa el `user://save.json` real.
Inspecciona las cuarentenas antes de limpiar los fixtures, también al finalizar.
Ante un fallo se detiene, imprime contexto y devuelve exit distinto de cero;
un timeout mata y espera al proceso antes de limpiar. CI ejecuta TST-02 como
paso independiente; TST-01 sigue teniendo exactamente 13 suites.

El PASS acredita esos arranques/cierres, cargas y archivos observados. No demuestra
ausencia total de memory leaks, acumulación gráfica, AudioStreamPlayers huérfanos,
temperatura estable ni rendimiento físico estable. No se miden FPS, memoria,
temperatura, carga física, consumo o batería: corresponden a IOS-02/M4.

## Sesión manual independiente

Estado: **validación física pendiente de IOS-01/IOS-02**. Preparar una copia del
registro siguiente por tester/dispositivo cuando exista build apropiado. No se
considera ejecutada por tener este protocolo ni bloquea la parte automatizada.

1. Jorge y su hermano prueban inicialmente por separado, sin compartir hallazgos
   hasta cerrar sus registros. Anotar build/commit, dispositivo y versión de iOS.
2. Probar sin coaching y sin explicar mecánicas salvo bloqueo técnico. Registrar
   cualquier intervención y su motivo. No sugerir qué debe resultar divertido.
3. Realizar **5 cierres completos y reaperturas consecutivas** por tester/dispositivo
   (quitar la app del selector, no solo enviarla al fondo). Tras cada apertura,
   observar si aparece la escena y responde, y si hay sonidos, avisos o conductas
   duplicadas. Registrar intentos fallidos, cierres inesperados y diferencias.
   No llamar a esto prueba del reinicio interno de partida ni medir rendimiento.
4. Registrar primero la observación o el comentario literal con momento/ciclo.
   No inferir fugas o causas técnicas de una conducta visual o sonora.
5. Al terminar, completar duración, partidas realmente completadas y si quiso
   repetir (espontáneamente o tras pregunta neutral). Interpretar después de la
   sesión y vincular cada hipótesis con sus observaciones. No puntuar testers.

## Tres categorías de evidencia

- **Hecho observado:** directamente visible, con momento y contexto.
  Ejemplo: «En la segunda apertura la aplicación se cerró antes de mostrar el tablero».
- **Comentario literal del tester:** entre comillas y atribuido al tester.
  Ejemplo: “No entendí qué hacía esa mejora”. No tratar la opinión como un hecho
  sobre la mecánica. Si se parafrasea, indicarlo y no usar comillas de cita literal.
- **Interpretación / hipótesis:** conclusión del observador, escrita después.
  Ejemplo: «Hipótesis: la jerarquía visual de la mejora podría ser insuficiente».
  Nunca convertir una interpretación en hecho ni atribuirla al tester.

## Plantilla de sesión (copiar, no completar con supuestos)

Usar «no disponible», «no observado» o «pendiente» cuando corresponda.

| Campo | Valor |
|---|---|
| Tester/dispositivo | |
| Versión de iOS | |
| Build/commit | |
| Semilla de partida | Registrar si es accesible; si no, «no disponible» |
| Duración | |
| Partidas completadas | |
| Mano y ajustes de accesibilidad | |
| Momento de confusión | Momento y hecho/cita que lo respalda |
| Momento de diversión | Momento y hecho/cita que lo respalda |
| ¿Quiso repetir? | Registrar si fue espontáneo o respuesta a pregunta |
| Errores | Ciclo, pasos y resultado observado |
| Observaciones factuales | |
| Interpretaciones/hipótesis | Completar después; referenciar hechos |
| Comentarios del tester | Citas literales entre comillas |

| Ciclo | Hecho observado al cerrar/abrir y responder | Comentario literal | Incidencia/intervención |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

Hipótesis posteriores (referir ciclo/momento): ____________________

Gap: reinicio interno de partida activa con confirmación **no implementado / no probado**.

## Evidencia de implementación

Base auditada: `uat=257fbb58e9128b966f003b9f67c728ec683ed583`;
`origin/main=a6d88f4c4715a64614ddf3e0a220e76d65304339`.
Rama: `test/tst-02-restart-observation`. Sin cambios de decisiones aprobadas,
gameplay, SaveService, TST-01 ni archivos reservados a UPG-02.

Verificación local, 2026-09-26, macOS y Godot
`4.7.2.stable.official.ed1daf0bf`, sobre esta rama y el baseline anterior:

| Verificación | Resultado |
|---|---|
| `bash tests/run_restart_suite.sh` | AUTOMATED PASS; Main 10/10 y los cuatro casos de persistencia PASS |
| `bash tests/run_core_suite.sh` | 13/13 PASS |
| `save_service_test.gd` | 10 casos / 193 aserciones PASS |
| `save_recovery_test.gd` | 29 casos / 1023 aserciones / 0 omisiones PASS |
| Importación `--editor --quit` y smoke Main `--quit-after 3` | exit 0, sin errores |
| `bash -n tests/run_restart_suite.sh` y revisión de diff | PASS |
| Fallos inyectados al runner mediante ejecutables temporales | Rechaza exit 7, ERROR con exit 0, ausencia de señal de ready y SCRIPT ERROR en ciclo 4 |
| Proceso simulado colgado | Falla a los 30 s; proceso terminado y recogido; fixtures eliminados |

Las pruebas negativas se lanzaron desde fuera del repositorio y ninguna emitió
AUTOMATED PASS. SAV-02 conserva sus avisos esperados por exponentes extremos y
UTF-8 inválido. La primera importación bajo sandbox falló por acceso a certificados
y ajustes del editor de macOS; la ejecución autorizada fuera del sandbox pasó.
No se modificó código productivo para resolver esa restricción del entorno.

Pendientes: ejecución de CI remoto, revisión/integración en `uat` y validación
física IOS-01/IOS-02. No se promovió a `uat` ni a `main`.
