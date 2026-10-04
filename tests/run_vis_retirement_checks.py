#!/usr/bin/env python3
"""VIS-01 checks and six mutations in disposable copies; source remains unchanged."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT_BIN", "godot")
DIAGNOSTIC = re.compile(
    r"SCRIPT ERROR|Parse Error|Invalid call|^\s*ERROR:|leaked at exit|"
    r"still in use at exit|already connected|freed instance", re.M | re.I
)
FIELD = "scripts/lane/lane_field.gd"
TEST = "res://tests/vis_runner_retirement_test.gd"
LIFETIME = "res://tests/vis_runner_event_lifetime_test.gd"
MUTATIONS = (
    ("no-hide", "\trunner.hide()", "\tpass # no hide", TEST, "VIS_HIDDEN"),
    ("hide-before-listeners", "\tdish_served.emit(served_payload)",
     "\ttarget.hide()\n\tdish_served.emit(served_payload)", TEST, "VIS_LISTENER_VISIBLE"),
    ("free-before-signal",
     "\tmonster_reached_counter.emit(payload)\n\t_retire_runner(runner)",
     "\trunner.free()\n\tmonster_reached_counter.emit(payload)", LIFETIME, "VIS_EVENT_LIFETIME FAIL"),
    ("double-resolve", "\t\tmonster_satisfied.emit(primary_satisfied_payload)",
     "\t\tmonster_satisfied.emit(primary_satisfied_payload)\n\t\tmonster_satisfied.emit(primary_satisfied_payload)", TEST, "VIS_ONCE"),
    ("runner-residual", "\trunner.queue_free()", "\tpass # retain hidden node", TEST, "VIS_FREED"),
    ("boss-residual", "\trunner.hide()",
     '\tif runner.monster_state.monster_id == "boss_big_glutton":\n\t\treturn\n\trunner.hide()', TEST, "VIS_BOSS"),
)


def run(project, log, *args):
    result = subprocess.run(
        [GODOT, "--headless", "--path", str(project), "--log-file", str(log.with_suffix(".engine.log")), *args],
        cwd=project, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, timeout=60,
    )
    log.write_text(result.stdout)
    return result


def copy_project(destination, key):
    shutil.copytree(ROOT, destination, ignore=shutil.ignore_patterns(
        ".git", ".godot", "graphify-out", "engine.log", "build", "builds", "exports", "__pycache__"
    ))
    # All runs use disposable project identity, never the player's metadata path.
    (destination / "override.cfg").write_text('[application]\nconfig/name="' + key + '"\n')


def main():
    source = ROOT / FIELD
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    results = []
    with tempfile.TemporaryDirectory(prefix="vis_01_checks_") as temporary:
        work = Path(temporary)
        project = work / "baseline"
        copy_project(project, work.name)
        imported = run(project, work / "baseline-import.log", "--editor", "--quit")
        if imported.returncode or DIAGNOSTIC.search(imported.stdout):
            raise RuntimeError("VIS baseline import failed:\n" + imported.stdout)
        for script in [TEST, LIFETIME]:
            tested = run(project, work / (Path(script).stem + ".log"), "--script", script)
            if tested.returncode or DIAGNOSTIC.search(tested.stdout) or "PASS" not in tested.stdout:
                raise RuntimeError("VIS baseline failed:\n" + tested.stdout)
            print(tested.stdout, end="", flush=True)
        for name, before, after, script, marker in MUTATIONS:
            candidate = work / name
            shutil.copytree(project, candidate, ignore=shutil.ignore_patterns(".godot"))
            path = candidate / FIELD
            text = path.read_text()
            if text.count(before) != 1:
                raise RuntimeError(name + ": mutation anchor changed")
            path.write_text(text.replace(before, after, 1))
            imported = run(candidate, work / (name + "-import.log"), "--editor", "--quit")
            if imported.returncode or DIAGNOSTIC.search(imported.stdout):
                raise RuntimeError(name + ": invalid mutant import:\n" + imported.stdout)
            tested = run(candidate, work / (name + ".log"), "--script", script)
            # Every mutation must fail its named behavioral assertion, not an
            # incidental engine error, stale instance, leak or parser diagnostic.
            if tested.returncode == 0 or marker not in tested.stdout or DIAGNOSTIC.search(tested.stdout):
                raise RuntimeError(name + ": intended assertion not isolated:\n" + tested.stdout)
            results.append({"mutation": name, "assertion": marker, "exit": tested.returncode})
            print("VIS mutation killed: " + name + " -> " + marker, flush=True)
        output = os.environ.get("VIS_CHECK_LOG_DIR")
        if output:
            output_path = Path(output)
            output_path.mkdir(parents=True, exist_ok=True)
            for log in work.glob("*.log"):
                shutil.copy2(log, output_path / log.name)
            (output_path / "mutations.json").write_text(json.dumps(results, indent=2))
    if hashlib.sha256(source.read_bytes()).hexdigest() != original:
        raise RuntimeError("VIS source changed during checks")
    print("VIS mutation PASS: 6/6; source unchanged; disposable copies removed.")


if __name__ == "__main__":
    main()
