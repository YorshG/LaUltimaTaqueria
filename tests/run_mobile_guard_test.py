#!/usr/bin/env python3
"""Execute real failing GDScript; a forged positive PASS must still exit nonzero."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from run_checked_godot import accepted
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/art-01d/evidence"

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bodies = {
        "script-error-positive": 'func broken():\n\tvar missing: Variant = null\n\tmissing.get_children()\nfunc _initialize():\n\tbroken()\n\tprint("UI_MOBILE_LAYOUT 1 checks 0 failures")\n\tquit(0)\n',
        "zero-checks": 'func _initialize():\n\tprint("UI_MOBILE_LAYOUT 0 checks 0 failures")\n\tquit(0)\n',
        "missing-summary": 'func _initialize():\n\tprint("PASS")\n\tquit(0)\n',
        "positive-control": 'var checks := 0\nfunc _initialize():\n\tchecks += 1\n\tassert(2 + 2 == 4)\n\tprint("UI_MOBILE_LAYOUT %d checks 0 failures" % checks)\n\tquit(0)\n',
    }
    with tempfile.TemporaryDirectory(prefix="mobile-guard-") as tmp:
        for name, body in bodies.items():
            script = Path(tmp, name + ".gd")
            script.write_text("extends SceneTree\n" + body)
            command = [sys.executable, "tests/run_checked_godot.py", "--script", str(script), "--summary", "UI_MOBILE_LAYOUT"]
            result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
            (OUT / ("guard-" + name + ".log")).write_text(result.stdout + f"\nWRAPPER_EXIT={result.returncode}\n")
            assert (result.returncode == 0) == (name == "positive-control"), result.stdout
            if name == "script-error-positive":
                assert "SCRIPT ERROR" in result.stdout and "UI_MOBILE_LAYOUT 1 checks 0 failures" in result.stdout
            print(name + " correctly " + ("accepted" if result.returncode == 0 else "rejected"))
    assert not accepted(1, "UI_MOBILE_LAYOUT 1 checks 0 failures", "UI_MOBILE_LAYOUT")
    assert not accepted(0, "UI_MOBILE_LAYOUT 1 checks 1 failures", "UI_MOBILE_LAYOUT")
    print("MOBILE_GUARD 6 checks 0 failures")
if __name__ == "__main__":
    main()
