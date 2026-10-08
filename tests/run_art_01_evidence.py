#!/usr/bin/env python3
"""Reproduce fixed-baseline/after captures and 32px raster checks with real Godot."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BASE = "d46cc8cdebb363a7791da8417d78870da3e676d1"
OUT = ROOT / "docs/art-01/evidence"
GODOT = os.environ.get("GODOT_BIN", "godot")
DIAGNOSTIC = re.compile(r"SCRIPT ERROR|Parse Error|^\s*ERROR:|leaked at exit|still in use at exit", re.M | re.I)


def run(project, label, *args):
    command = [GODOT, "--path", str(project), "--log-file", str(OUT / (label + ".engine.log")), *args]
    result = subprocess.run(command, cwd=project, capture_output=True, text=True, timeout=90)
    output = result.stdout + result.stderr
    (OUT / (label + ".log")).write_text(output)
    if result.returncode or DIAGNOSTIC.search(output):
        raise RuntimeError(f"{label} FAILED\n{output}")
    print(label + " PASS", flush=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="art01-baseline-") as temporary:
        base = Path(temporary)
        archive = base / "base.zip"
        with archive.open("wb") as file:
            subprocess.run(["git", "archive", "--format=zip", BASE], cwd=ROOT, stdout=file, check=True)
        with zipfile.ZipFile(archive) as source:
            source.extractall(base)
        shutil.copyfile(ROOT / "tests/art_01_capture.gd", base / "tests/art_01_capture.gd")
        shutil.copyfile(ROOT / "tests/art_01_performance.gd", base / "tests/art_01_performance.gd")
        run(base, "baseline-import", "--headless", "--editor", "--quit")
        # Use the project's actual mobile renderer; log records the device/backend.
        run(base, "before-1920", "--script", "res://tests/art_01_capture.gd", "--", str(OUT / "before-1920.png"), "1920")
        run(base, "performance-before", "--script", "res://tests/art_01_performance.gd")
    run(ROOT, "import", "--headless", "--editor", "--quit")
    for height in [1620, 1920, 2400]:
        run(ROOT, f"after-{height}", "--script", "res://tests/art_01_capture.gd", "--", str(OUT / f"after-{height}.png"), str(height))
    for phase in ["boss1", "boss2", "boss3"]:
        run(ROOT, phase, "--script", "res://tests/art_01_capture.gd", "--", str(OUT / f"{phase}.png"), "1920", phase)
    run(ROOT, "legibility", "--script", "res://tests/art_01_legibility.gd", "--", str(OUT))
    run(ROOT, "performance-after", "--script", "res://tests/art_01_performance.gd")
    print("ART-01 EVIDENCE PASS", flush=True)


if __name__ == "__main__":
    main()
