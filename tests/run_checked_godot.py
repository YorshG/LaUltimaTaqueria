#!/usr/bin/env python3
"""Fail closed on engine errors and missing/zero assertion summaries."""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ERROR = re.compile(r"SCRIPT ERROR|Parse Error|^\s*ERROR:|leaked at exit|still in use at exit", re.I | re.M)
SUMMARIES = {"ui_mobile_layout_test.gd": "UI_MOBILE_LAYOUT", "art_01b_layout_test.gd": "ART_01B_LAYOUT",
             "art_01c_audit_test.gd": "ART_01C_AUDIT", "art_01d_audit_test.gd": "ART_01D_AUDIT"}

def accepted(code, output, summary=None):
    if code or ERROR.search(output):
        return False
    if summary:
        rows = re.findall(r"^" + re.escape(summary) + r" ([0-9]+) checks ([0-9]+) failures$", output, re.M)
        return len(rows) == 1 and int(rows[0][0]) > 0 and int(rows[0][1]) == 0
    return True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--script", required=True)
    parser.add_argument("--summary")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="godot-checked-") as tmp:
        try:
            result = subprocess.run([os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", ".",
                "--log-file", str(Path(tmp) / "engine.log"), "--script", args.script],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        except subprocess.TimeoutExpired:
            print("FAIL: Godot timed out", file=sys.stderr)
            return 1
        print(result.stdout, end="")
        engine = Path(tmp, "engine.log").read_text() if Path(tmp, "engine.log").exists() else ""
        summary = args.summary or SUMMARIES.get(Path(args.script).name)
        ok = accepted(result.returncode, result.stdout, summary) and not ERROR.search(engine)
        if not ok:
            print("FAIL: exit status, engine diagnostic, or missing/zero checks", file=sys.stderr)
        return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
