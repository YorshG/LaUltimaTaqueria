#!/usr/bin/env python3
"""Disposable #61 typography overlay on controlled #62/ART-01B composition."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import run_art_01_evidence as evidence

ROOT = evidence.ROOT
OUT = ROOT / "docs/art-01b/evidence"
evidence.OUT = OUT
HEAD61 = "9832846fe5837919d441273f496f31ef3430c0cf"
HEAD62 = "e894b438939e6260a4c8cc6c566373c351ddc2a7"


def main():
    with tempfile.TemporaryDirectory(prefix="art01b-compatibility-") as temporary:
        project = Path(temporary) / "project"
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(".git", ".godot", "evidence", "__pycache__", "*.import"))
        for name in ["scenes/lane/LaneRunner.tscn", "scripts/board/board_view.gd",
                     "tests/board_input_test.gd", "tests/lane_integration_test.gd"]:
            content = subprocess.check_output(["git", "show", f"{HEAD61}:{name}"], cwd=ROOT)
            (project / name).write_bytes(content)
        evidence.run(project, "compatibility-import", "--headless", "--editor", "--quit")
        for script in ["board_input_test", "lane_integration_test", "art_01_visual_test", "art_01b_layout_test", "restart_session_test"]:
            evidence.run(project, "compatibility-" + script, "--headless", "--script", f"res://tests/{script}.gd")
        # Exact overlap is visible to the independent auditor, including the
        # different presentation already present in ART-01 (not all new B work).
        delta = subprocess.check_output(["git", "diff", "--unified=0", HEAD62, "--", "scenes/App.tscn", "scenes/Main.tscn"], cwd=ROOT, text=True)
        (OUT / "composition-vs-62.diff").write_text(delta)
        (OUT / "compatibility-summary.txt").write_text(
            f"#61 {HEAD61}\n#62 {HEAD62}\n"
            "PASS #61 exact typography and its board/lane assertions over ART-01B.\n"
            "PASS ART-01 observers, ART-01B spatial/safe/touch checks and restart.\n"
            "#62 exact scenes passed initial disposable audit (stack-audit-before.log).\n"
            "Final App/Main implement its hierarchy intent with adaptive Controllers.\n"
            "Original #62 test's VBox/order/min<=64 assertions are superseded, not claimed to pass here.\n"
            "No merge performed. Final composition is not a blind overlay of #62 scenes.\n")
    print("ART-01B CONTROLLED COMPOSITION PASS", flush=True)


if __name__ == "__main__":
    main()
