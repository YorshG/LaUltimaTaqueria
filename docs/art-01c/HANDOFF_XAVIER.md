# Handoff ART-01C para Xavier

Estado de entrega: PR #63 **DRAFT**, base uat, sin merge. Jorge decide aceptación e integración. Inicio auditado `5e4bc11dd2c68a2b7563437e8cdeb98d39a97dc3`; SHA final exacto y CI de ese SHA se registran en el cuerpo de #63 y la entrega. Este documento no representa una reauditoría realizada por Xavier.

## Reauditoría propuesta

1. Verificar `headRefOid`, DRAFT, base uat y ocho checks del head actual. Confirmar uat `d46cc8cdebb363a7791da8417d78870da3e676d1`, main `a6d88f4c4715a64614ddf3e0a220e76d65304339`, #61 `9832846fe5837919d441273f496f31ef3430c0cf`, #62 `e894b438939e6260a4c8cc6c566373c351ddc2a7`, sin cambios por esta misión.
2. Revisar `git diff 5e4bc11..HEAD`: solo dos observadores de presentación, un texto del catálogo, pruebas/CI, backlog y documentación. Modelo, reglas, balance, input, targeting, guardado, sesiones y escenas no se modifican. [Inventario](FILES.md).
3. Abrir [comparativa agrupada 1620](evidence/comparison-crowded-1620.png) y las tres proporciones de [VALIDATION](VALIDATION.md). Antes/después usan **la misma fixture canónica** sobre B y C, no los antiguos 70/70. Todas están rotuladas como fixtures, no partidas.
4. Confirmar A: el listener de BoardVisual neutraliza la modulación heredada del Button; contorno/orden se dibujan aparte, sin línea sobre el ingrediente. `pixels.log` verifica igualdad byte a byte de cada región de icono, los tres ingredientes y tres alturas. Hoja de color/desaturación a escala móvil en `selection-mobile-pixels.png` (columnas: sin seleccionar, seleccionado, gris sin seleccionar, gris seleccionado; filas: T/M/V por 1620/1920/2400).
5. Confirmar B/C: `hunger_text()` solo formatea; una línea con ancho medido, máximo dos medidas de fuente por etiqueta; barra sigue el float. Ver 27.5/30 → 28/30, 67.625/70 → 68/70 y 17.666…/18 → 18/18; `0.49` sigue siendo un objetivo aunque dibuje 0/30. No aparece «provisional» ni debug en gameplay. El texto de reputación mantiene su contrato D1 original.
6. Confirmar D: Fixture lee el registro validado, hambre y velocidad de `monsters.json`, semilla fija y progresos publicados. Nueve clientes a progreso idéntico 0.46 prueban empate real (carril central, primer spawn elegible). `art_01c_audit_test.log` registra objetivo mostrado/servido y precisión tras satisfacción 1.375. Manifest incluye hashes del JSON y fixture.
7. Ejecutar los comandos de VALIDATION. Separar PASS de suites de la **incompatibilidad esperada de #62**: su prueba original produce errores y «PASS: 0 checks». No aceptar ese mensaje como éxito ni modificar #62 para ocultarlo.
8. Revisar [matriz](PR_MATRIX.md): #61 se conserva como delta compatible; #62 tiene escena en conflicto y contrato VBox incompatible. La sustitución de su composición, rescate documental y eventual cierre requieren decisión de Jorge. No se integró ni cerró nada.
9. Revisar [rendimiento](PERFORMANCE.md), incluidos todos los outliers y el intento tipográfico inicial conservado. 160 draw calls vs 59 uat; memoria y tiempos desktop no son garantía de móvil. [Protocolo físico](PHYSICAL_PROTOCOL.md) pendiente para ambos iPhone.

## Bloqueantes de aceptación que siguen abiertos

- Reauditoría independiente ART-01C por Xavier y revisión visual de Jorge.
- Evidencia física en iPhone 17 y 16 Pro Max: safe area real, Home Indicator, fila 5, ambas manos/pulgar, legibilidad y rendimiento sostenido.
- Decisión PO sobre #61/#62/#63; la recomendación no autoriza integración ni cierre.
- Las figuras siguen siendo proxies provisionales; no hay aprobación de arte final ni referencia Opción 1B añadida.
- Redondear puede mostrar entero máximo o cero mientras el float difiere; barra/target se conservan y debe comprobarse comprensión en dispositivo. Valores extremos fuera del catálogo se comprimen horizontalmente para no desbordar, sin prometer legibilidad física de números arbitrariamente largos.

Los tres frentes de proceso quedan documentados: backlog/trazabilidad, estrategia de PR y aceptación visual/física/PO. La entrega técnica para reauditoría puede quedar lista con CI verde; ART-01/01B/01C permanecen en revisión hasta cumplir sus criterios humanos.
