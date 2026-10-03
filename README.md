# La Última Taquería

Juego móvil 2D vertical de puzzle y supervivencia roguelite. El jugador combina ingredientes para preparar platillos y alimentar monstruos antes de que dañen la reputación de la última taquería abierta.

## Estado

Prototipo Godot 4.7.2 en integración `uat`: tablero, recetas, carriles, oleadas, jefe, reputación, feedback, guardado local y las 15 mejoras implementados. RUN-01 conecta el arranque, cinco oleadas, cinco elecciones visibles y el jefe dentro de `Main`; se entrega para revisión, sin declarar M3 cerrado. El host de reinicio RST-01 se revisa por separado. La [auditoría M3](docs/M3_RUNTIME_AUDIT.md) distingue el baseline integrado de los cambios propuestos.

La duración de 4–5 minutos, la exportación/instalación iOS y la interacción en iPhone siguen pendientes de medición. `main` conserva únicamente trabajo estable aprobado; los PRs funcionales se revisan contra `uat` antes de integrar.

## Objetivo del prototipo

Validar si trazar cadenas de ingredientes mientras se gestionan tres carriles produce partidas claras, divertidas y con deseo inmediato de repetir. Duración objetivo: 4–5 minutos.

## Equipo

- Jorge: Product Owner y aprobación.
- Hermano de Jorge: coevaluación y pruebas.
- Codex: arquitectura, implementación, integración y builds.
- Claude: sistemas, contenido, balance y módulos expresamente asignados.

## Lectura recomendada

1. [Alcance](docs/PROTOTYPE_SCOPE.md)
2. [Diseño](docs/GAME_DESIGN.md)
3. [Reglas](docs/CORE_RULES.md)
4. [Arquitectura](docs/ARCHITECTURE.md)
5. [Backlog](planning/BACKLOG.md)
6. [Colaboración](docs/COLLABORATION.md)

## Flujo Git

`main` contiene trabajo estable aprobado; `uat` es integración; cada cambio se realiza en `feature/*` o `docs/*` mediante Pull Request. Verificaciones locales: importar con `godot --headless --editor --path . --quit` y ejecutar `bash tests/run_core_suite.sh`. Las suites de guardado y reinicio tienen runners propios; consultar la documentación de validación de cada ticket.
