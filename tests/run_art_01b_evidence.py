#!/usr/bin/env python3
"""Same fixture and renderer, three exact versions, three sequential perf runs."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
import run_art_01_evidence as evidence

ROOT = evidence.ROOT
OUT = ROOT / "docs/art-01b/evidence"
evidence.OUT = OUT
run = evidence.run
REFS = {"uat": "d46cc8cdebb363a7791da8417d78870da3e676d1",
        "art01": "04c3f3c7e3fb581aad55a538996d035e793413f3"}
PERF_FOLLOWUP = "--perf-followup" in sys.argv


def capture(project, prefix):
    for height in ([] if PERF_FOLLOWUP else [1620, 1920, 2400]):
        label = f"{prefix}-{height}"
        run(project, label, "--script", "res://tests/art_01b_capture.gd", "--", str(OUT / f"{label}.png"), str(height))
    for iteration in (range(4, 6) if PERF_FOLLOWUP else range(1, 4)):
        run(project, f"perf-{prefix}-{iteration}", "--script", "res://tests/art_01_performance.gd")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Reuse immutable baseline observations after presentation-only follow-ups.
    for prefix, sha in ({} if "--after-only" in sys.argv else REFS).items():
        with tempfile.TemporaryDirectory(prefix=f"art01b-{prefix}-") as temporary:
            project = Path(temporary)
            archive = project / "source.zip"
            with archive.open("wb") as stream:
                subprocess.run(["git", "archive", "--format=zip", sha], cwd=ROOT, stdout=stream, check=True)
            with zipfile.ZipFile(archive) as source:
                source.extractall(project)
            for name in ["art_01b_capture.gd", "art_01_performance.gd"]:
                shutil.copyfile(ROOT / "tests" / name, project / "tests" / name)
            run(project, prefix + "-import", "--headless", "--editor", "--quit")
            capture(project, prefix)
    run(ROOT, "import", "--headless", "--editor", "--quit")
    capture(ROOT, "art01b")
    for height in ([] if PERF_FOLLOWUP else [1620, 1920, 2400]):
        for mode in ["crowded", "bounds", "restart", "upgrades"]:
            label = f"{mode}-{height}"
            run(ROOT, label, "--script", "res://tests/art_01b_capture.gd", "--", str(OUT / f"{label}.png"), str(height), mode)
    for mode in ([] if PERF_FOLLOWUP else ["boss1", "boss2", "boss3"]):
        run(ROOT, mode, "--script", "res://tests/art_01b_capture.gd", "--", str(OUT / f"{mode}.png"), "1920", mode)
    if not PERF_FOLLOWUP:
        run(ROOT, "comparisons", "--script", "res://tests/art_01b_comparison.gd", "--", str(OUT))
    report = {}
    for prefix in [*REFS, "art01b"]:
        report[prefix] = [json.loads(line.removeprefix("ART_PERFORMANCE "))
                          for log in sorted(OUT.glob(f"perf-{prefix}-[0-9].log"))
                          for line in log.read_text().splitlines()
                          if line.startswith("ART_PERFORMANCE ")]
    (OUT / "performance.json").write_text(json.dumps(report, indent=2) + "\n")
    print("ART-01B EVIDENCE PASS", flush=True)


if __name__ == "__main__":
    main()
