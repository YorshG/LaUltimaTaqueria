# ART-01C — alcance y verificación inicial

Misión explícita de Jorge recibida el 7/oct/2026. Se corrigen cuatro defectos de presentación de #63: tinte de selección, hambre fraccionaria en dos filas, texto provisional visible y capturas con hambre inventada. Sin rediseño, integración, rebase, squash, force push, cierre de #62 ni modificación de main/uat.

Inicio de #63: `5e4bc11dd2c68a2b7563437e8cdeb98d39a97dc3`, OPEN DRAFT → uat. uat remoto `d46cc8cdebb363a7791da8417d78870da3e676d1`; main remoto `a6d88f4c4715a64614ddf3e0a220e76d65304339`. Checkout del usuario limpio, rama `codex/upg-02h-steady-hands`, 17 commits locales respecto a su upstream; preservado. Worktree ART-01B limpio. Se usa clon local aislado, rama `codex/art-01c-audit-corrections`, para avanzar #63 por fast-forward al entregar. No se actualizan las ramas de #61/#62.

Se leyeron AGENTS, alcance, colaboración, decisiones, backlog y todos los documentos de ART-01B. No se encontró informe autónomo de Xavier en el repositorio ni comentarios/reviews en #63 (API: listas vacías). Fuente de la auditoría del 7/oct a las 20:39: resumen incluido por Jorge en esta misión; reporta CI 8/8, regresiones locales 14/14 y autorización solo para revisión visual. ART-01C conserva esa atribución, no la presenta como reauditoría ya realizada.

Archivos permitidos: observadores `scripts/visuals/board_visual.gd` y `lane_visual.gd`, catálogo de textos visuales, pruebas/evidencia ART-01C, workflow de presentación, backlog y decisiones. Excluidos: modelo, balance, datos canónicos, scripts de gameplay/input/targeting/sesión/guardado y escenas de #61/#62. No se encontró propiedad activa de Claude sobre estos archivos; PRE-02 consta terminada.

Lotes y aceptación:
1. Presentación: identidad de los tres ingredientes intacta, contorno independiente, hambre entera en una línea y barra real; cero etiquetas de depuración.
2. Fixtures: datos validados 30/70/18, velocidad real, progreso y semilla fijos; fracciones y nueve runners; selector marcado coincide con servicio efectivo.
3. Regresión/evidencia: import Godot 4.7.2, suites completas y pruebas específicas; tres proporciones, safe area sintética, color/desaturación a escala móvil.
4. Proceso: backlog abierto, matriz de PR, mediciones equivalentes contra uat y protocolo físico, entrega DRAFT/CI para Xavier. La aceptación visual/física y la integración dependen de Jorge.
