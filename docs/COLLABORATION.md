# Colaboración

## Ramas

- `main`: estable y aprobada.
- `uat`: integración y prueba.
- `feature/<id>-<slug>`: una tarea.
- `docs/<slug>`: documentación.

## Reglas

Pull Requests pequeños, una finalidad por PR y propietario temporal por archivo. Antes de comenzar se declaran archivos permitidos y prohibidos. Un colaborador no edita archivos propiedad activa de otro.

Los contratos compartidos —esquemas de datos, eventos e interfaces consumidas por varios módulos— se congelan temporalmente mientras haya trabajo paralelo dependiente. Cambiarlos requiere avisar a los propietarios afectados y coordinar el orden de integración.

La propiedad de un archivo solo cambia mediante transferencia explícita registrada en la tarea o Pull Request. La transferencia indica estado actual, cambios pendientes y nuevo propietario; hasta entonces conserva la propiedad anterior.

El repositorio es la fuente oficial. Cada entrega incluye objetivo, archivos, decisiones, supuestos, verificaciones, riesgos y pendientes. Si dos propuestas chocan, se detiene la integración, se documentan alternativas y el Product Owner decide.

Codex revisa compatibilidad e integra. Claude entrega contenido o módulos delimitados. Ninguno promueve a `main` sin aprobación. Si hay conflicto, se detiene la edición del archivo afectado; no se sobrescribe trabajo ajeno y el propietario designado realiza la integración final.
