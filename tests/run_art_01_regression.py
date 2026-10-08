#!/usr/bin/env python3
"""Existing module regressions plus presentation contract, preserving complete logs."""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/art-01/evidence"
GODOT = os.environ.get("GODOT_BIN", "godot")
SCRIPTS = ["art_01_visual_test", "boss_encounter_test", "reputation_test", "feedback_test",
           "restart_session_test", "save_service_test", "save_recovery_test",
           "vis_runner_retirement_test", "vis_runner_event_lifetime_test", "m3_runtime_bot"]
DIAGNOSTIC = re.compile(r"SCRIPT ERROR|Parse Error|leaked at exit|still in use at exit", re.I)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    commands = [("core", ["bash", "tests/run_core_suite.sh"])]
    commands += [(name, [GODOT, "--headless", "--path", str(ROOT), "--log-file", str(OUT / (name + ".engine.log")),
                         "--script", "res://tests/" + name + ".gd"]) for name in SCRIPTS]
    commands += [("restart-suite", ["bash", "tests/run_restart_suite.sh"]),
                 ("input-probe", ["python3", "tests/run_inp_probe_test.py"])]
    for label, command in commands:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=150)
        (OUT / (label + ".log")).write_text(result.stdout)
        errors = re.findall(r"^\s*ERROR: (.*)$", result.stdout, re.M)
        # SAV-02 intentionally diagnoses corrupt fixtures; its own assertions verify recovery.
        if label == "save_recovery_test":
            errors = [line for line in errors if not line.startswith("Parse JSON failed.")]
        if result.returncode or DIAGNOSTIC.search(result.stdout) or errors:
            raise RuntimeError(f"{label} FAILED\n{result.stdout}")
        print(label + " PASS", flush=True)


if __name__ == "__main__":
    main()
