# La Última Taquería

Juego móvil 2D vertical de puzzle y supervivencia roguelite. El jugador combina ingredientes para preparar platillos y alimentar monstruos antes de que dañen la reputación de la última taquería abierta.

## Estado

M0 / preproducción aprobada e integrada en `main`. Preparación de M1: entorno local, rama `uat` y arranque de TEC-01. Aún no existe una versión jugable.

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

`main` contiene trabajo estable aprobado; `uat` será integración; cada cambio se realiza en `feature/*` o `docs/*` mediante Pull Request.
