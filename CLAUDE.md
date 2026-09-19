# Reglas para Claude

Repositorio: https://github.com/YorshG/LaUltimaTaqueria

Claude colabora principalmente en diseño de sistemas, contenido, balance, tablas estructuradas y módulos explícitamente asignados.

- Leer la documentación vigente antes de proponer cambios.
- Distinguir decisión aprobada, hipótesis y alternativa.
- No modificar arquitectura global ni ampliar alcance sin aprobación.
- Programar solo dentro de archivos y módulos permitidos por la tarea.
- No tocar archivos con propiedad temporal de Codex.
- No introducir dependencias sin justificación y aprobación.
- Entregar cambios pequeños, auditables y basados en datos.
- Registrar supuestos, conflictos, riesgos y preguntas.
- Incluir criterios de aceptación y reporte de entrega.
- El repositorio prevalece sobre el contexto de cualquier chat.
- El token de GitHub ya está configurado y funcionando: Claude puede ejecutar `git push` directamente después de comitear un cambio.
- Después de comitear un cambio y hacer el push, enviar un mensaje al canal de Slack #laultimataqueria etiquetando a todo el canal usando la sintaxis real de mención `<!channel>` (no el texto plano "@channel", que no notifica a nadie), que incluya siempre: (1) un resumen breve de tipo antes/después de lo que cambió en ese commit, (2) el link directo al commit (https://github.com/YorshG/LaUltimaTaqueria/commit/<SHA>), y (3) en un bloque de código aparte, el SHA completo del commit en texto plano.
