#!/usr/bin/env python3
"""Audit immutable PR heads in disposable exports; never integrate branch refs."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import run_art_01_evidence as evidence

ROOT = evidence.ROOT
OUT = ROOT / 'docs/art-01c/evidence'
evidence.OUT = OUT
HEAD61 = '9832846fe5837919d441273f496f31ef3430c0cf'
HEAD62 = 'e894b438939e6260a4c8cc6c566373c351ddc2a7'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='art01c-compat-') as temporary:
        project = Path(temporary) / 'project'
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('.git', '.godot', 'evidence', '__pycache__', '*.import'))
        for name in ['scenes/lane/LaneRunner.tscn', 'scripts/board/board_view.gd', 'tests/board_input_test.gd', 'tests/lane_integration_test.gd']:
            (project / name).write_bytes(subprocess.check_output(['git', 'show', f'{HEAD61}:{name}'], cwd=ROOT))
        evidence.run(project, 'compat61-import', '--headless', '--editor', '--quit')
        for script in ['board_input_test', 'lane_integration_test', 'art_01_visual_test', 'art_01b_layout_test', 'art_01c_audit_test', 'restart_session_test']:
            evidence.run(project, 'compat61-' + script, '--headless', '--script', f'res://tests/{script}.gd')
        # Reproduce #62's exact test against #63; this is an expected incompatible
        # contract, not a passing claim nor an edit to the source test/PR.
        name = 'tests/ui_mobile_layout_test.gd'
        (project / name).write_bytes(subprocess.check_output(['git', 'show', f'{HEAD62}:{name}'], cwd=ROOT))
        result = subprocess.run([evidence.GODOT, '--headless', '--path', str(project), '--log-file', str(OUT / 'compat62-contract.engine.log'), '--script', 'res://' + name], capture_output=True, text=True, timeout=30)
        log = result.stdout + result.stderr
        (OUT / 'compat62-original-contract.log').write_text(log)
        if log.count("SCRIPT ERROR: Cannot call method 'get_children' on a null value.") != 3 or 'PASS: 0 checks' not in log:
            raise RuntimeError('Expected VBox get_child incompatibility was not reproduced: ' + log)
        print('compat62 original VBox contract INCOMPATIBLE (expected, preserved log)', flush=True)
    for ref, label in [(HEAD61, '61'), (HEAD62, '62')]:
        result = subprocess.run(['git', 'merge-tree', '--write-tree', ref, '5e4bc11'], cwd=ROOT, capture_output=True, text=True)
        (OUT / f'merge-tree-{label}.log').write_text(result.stdout + result.stderr)
        if result.returncode != (0 if label == '61' else 1):
            raise RuntimeError('Unexpected merge-tree compatibility result')
    print('ART-01C COMPATIBILITY AUDIT PASS; #62 remains incompatible, no integration', flush=True)


if __name__ == '__main__':
    main()
