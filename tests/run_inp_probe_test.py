#!/usr/bin/env python3
"""Run the isolated probe regression, rejecting engine diagnostics even on exit 0."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

project = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="inp-probe-test-") as directory:
    result = subprocess.run(
        [os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(project),
         "--log-file", str(Path(directory) / "engine.log"),
         "--script", "res://tests/inp_touch_probe_test.gd", "--", "--no-file"],
        capture_output=True, text=True, timeout=90,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    diagnostics = re.search(
        r"SCRIPT ERROR|Parse Error|Invalid call|ObjectDB.*leak|resources still in use|"
        r"signal.*already connected|freed instance|^\s*ERROR:|leaked at exit", output, re.I | re.M,
    )
    passed = result.returncode == 0 and diagnostics is None and re.search(
        r"INP_PROBE_TEST \d+ checks 0 failures", output
    )
    raise SystemExit(0 if passed else 1)
