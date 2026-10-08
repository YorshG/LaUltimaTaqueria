# Archivos de ART-01B

Delta respecto al HEAD inicial ART-01 `04c3f3c7e3fb581aad55a538996d035e793413f3`. El histórico `docs/art-01/` y sus pruebas permanecen intactos.

## Código, escenas, activos y CI

- [.github/workflows/art-01-visual.yml](../../.github/workflows/art-01-visual.yml)
- [assets/provisional/README.md](../../assets/provisional/README.md)
- [assets/provisional/art_01b_atlas.png](../../assets/provisional/art_01b_atlas.png)
- [assets/provisional/art_01b_atlas.png.import](../../assets/provisional/art_01b_atlas.png.import)
- [assets/provisional/controls.tres](../../assets/provisional/controls.tres)
- [docs/DECISIONS.md](../../docs/DECISIONS.md)
- [scenes/App.tscn](../../scenes/App.tscn)
- [scenes/Main.tscn](../../scenes/Main.tscn)
- [scenes/lane/LaneField.tscn](../../scenes/lane/LaneField.tscn)
- [scenes/ui/FeedbackLayer.tscn](../../scenes/ui/FeedbackLayer.tscn)
- [scenes/ui/Hud.tscn](../../scenes/ui/Hud.tscn)
- [scenes/ui/UpgradeChoice.tscn](../../scenes/ui/UpgradeChoice.tscn)
- [scripts/ui/feedback_layer.gd](../../scripts/ui/feedback_layer.gd)
- [scripts/visuals/art_01_style.gd](../../scripts/visuals/art_01_style.gd)
- [scripts/visuals/board_visual.gd](../../scripts/visuals/board_visual.gd)
- [scripts/visuals/counter_visual.gd](../../scripts/visuals/counter_visual.gd)
- [scripts/visuals/counter_visual.gd.uid](../../scripts/visuals/counter_visual.gd.uid)
- [scripts/visuals/gameplay_layout.gd](../../scripts/visuals/gameplay_layout.gd)
- [scripts/visuals/gameplay_layout.gd.uid](../../scripts/visuals/gameplay_layout.gd.uid)
- [scripts/visuals/ingredient_visual.gd](../../scripts/visuals/ingredient_visual.gd)
- [scripts/visuals/lane_visual.gd](../../scripts/visuals/lane_visual.gd)
- [scripts/visuals/proxy_atlas.gd](../../scripts/visuals/proxy_atlas.gd)
- [scripts/visuals/proxy_atlas.gd.uid](../../scripts/visuals/proxy_atlas.gd.uid)
- [scripts/visuals/safe_area_layout.gd](../../scripts/visuals/safe_area_layout.gd)
- [scripts/visuals/safe_area_layout.gd.uid](../../scripts/visuals/safe_area_layout.gd.uid)
- [tests/art_01b_build_atlas.gd](../../tests/art_01b_build_atlas.gd)
- [tests/art_01b_build_atlas.gd.uid](../../tests/art_01b_build_atlas.gd.uid)
- [tests/art_01b_capture.gd](../../tests/art_01b_capture.gd)
- [tests/art_01b_capture.gd.uid](../../tests/art_01b_capture.gd.uid)
- [tests/art_01b_comparison.gd](../../tests/art_01b_comparison.gd)
- [tests/art_01b_comparison.gd.uid](../../tests/art_01b_comparison.gd.uid)
- [tests/art_01b_layout_test.gd](../../tests/art_01b_layout_test.gd)
- [tests/art_01b_layout_test.gd.uid](../../tests/art_01b_layout_test.gd.uid)
- [tests/run_art_01b_compatibility.py](../../tests/run_art_01b_compatibility.py)
- [tests/run_art_01b_evidence.py](../../tests/run_art_01b_evidence.py)
- [tests/run_art_01b_regression.py](../../tests/run_art_01b_regression.py)

## Documentación y evidencia

- [PLAN.md](PLAN.md): alcance, heads auditados, decisiones y coordenadas.
- [VALIDATION.md](VALIDATION.md): resultados, capturas, rendimiento y límites.
- [HANDOFF_XAVIER.md](HANDOFF_XAVIER.md): auditoría independiente y hardware pendiente.
- Este inventario y [evidence](evidence/): 27 PNG (9 versiones/resoluciones, 3 comparativas, 12 estados por resolución y 3 fases de jefe); logs de regresiones, composición e importación, 15 corridas de rendimiento y performance.json. `.gdignore` evita importar capturas como activos del juego; `.gitignore` excluye logs duplicados del engine e imports de evidencia.

## Separación de responsabilidades

App/Main cambian composición de escenas; sus scripts de sesión permanecen intactos. SafeAreaLayout y GameplayLayout solo distribuyen controles. LaneVisual/CounterVisual observan el estado de juego. El atlas comparte figuras y el Theme comparte controles. Solo FeedbackLayer cambia visibilidad/ubicación de sus cuatro mensajes; conserva payloads e historial. No se editan reglas, contenido de balance, SaveService, targeting ni los archivos de #61.
