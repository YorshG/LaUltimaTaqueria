#!/usr/bin/env bash
# TST-02: each Godot invocation is a separate process. Python's standard
# library provides portable finite timeouts on macOS and Linux (no GNU timeout).
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 - "$ROOT" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(sys.argv[1])
GODOT = os.environ.get("GODOT_BIN", "godot")
MAIN_CYCLES = 10
LOAD_CYCLES = 5
READY = "La Última Taquería — BOSS-01 temporary wiring ready."
DIAGNOSTIC = re.compile(
    r"^\s*(?:SCRIPT ERROR|ERROR):|\b(?:crashed|crash handler|"
    r"leaked at exit|still in use at exit)\b", re.IGNORECASE | re.MULTILINE
)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(label, *args, marker=None, timeout=30):
    # Engine logs also stay in the temporary directory, outside user://.
    command = [GODOT, "--headless", "--path", str(ROOT),
               "--log-file", str(work / "engine.log"), *args]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode("utf-8", errors="replace")
        raise RuntimeError(f"{label}: TIMEOUT after {timeout}s\n{output}") from error
    output = result.stdout.decode("utf-8", errors="replace")
    require(result.returncode == 0,
            f"{label}: exit {result.returncode}\n{output}")
    # Godot can report a script/initialization error and still exit with 0.
    require(not DIAGNOSTIC.search(output), f"{label}: engine diagnostic\n{output}")
    if marker is not None:
        require(output.splitlines().count(marker) == 1,
                f"{label}: missing or repeated completion marker\n{output}")


def probe(mode, path, status):
    run(f"{path.parent.name}/{mode}", "--script",
        "res://tests/restart_persistence_probe.gd", "--", mode, str(path),
        marker=f"TST-02 PROBE PASS: {mode} {status}")


def fixture(name):
    directory = work / name
    directory.mkdir()
    # The driver refuses unmarked directories and never uses Save's default path.
    (directory / ".tst-02-fixture").write_text("TST-02\n", encoding="utf-8")
    return directory / "save.json"


def snapshot(path):
    files = {}
    for entry in path.parent.iterdir():
        require(entry.is_file() and not entry.is_symlink(),
                f"Unexpected fixture entry: {entry.name}")
        files[entry.name] = entry.read_bytes()
    return files


def unchanged(path, expected, context):
    require(snapshot(path) == expected,
            f"{context}: fixture bytes or directory entries changed")


def check_document(path, record, coins, preferences):
    require(json.loads(path.read_text(encoding="utf-8")) == {
        "schema_version": 1, "record": record, "coins": coins,
        "preferences": preferences,
    }, f"{path.parent.name}: persisted document differs from the approved schema/values")


print("TST-02 restart suite\n", flush=True)
try:
    with tempfile.TemporaryDirectory(prefix="tst_02_") as temporary:
        work = Path(temporary).resolve()
        run("Project import", "--editor", "--quit", timeout=60)
        for cycle in range(1, MAIN_CYCLES + 1):
            run(f"Main cycle {cycle}/{MAIN_CYCLES}", "--scene",
                "res://scenes/Main.tscn", "--quit-after", "3", marker=READY)
        print(f"Main restart cycles: {MAIN_CYCLES}/{MAIN_CYCLES} PASS", flush=True)

        valid = fixture("valid")
        probe("write", valid, "SAVED")  # Process A exits before either reader.
        check_document(valid, 123, 456, {"test_option": True})
        expected_valid = {".tst-02-fixture": b"TST-02\n", "save.json": valid.read_bytes()}
        unchanged(valid, expected_valid, "Initial save")
        for _ in range(2):  # Processes B and C.
            probe("read", valid, "LOADED")
            unchanged(valid, expected_valid, "Cross-process roundtrip")
        print("Cross-process valid persistence: PASS", flush=True)

        recovery = fixture("recovery")
        corrupt = b'{"schema_version":1,"record":'
        recovery.write_bytes(corrupt)
        probe("recover", recovery, "RECOVERED")
        expected_recovery = {".tst-02-fixture": b"TST-02\n", "save.json.corrupt": corrupt}
        unchanged(recovery, expected_recovery, "Recovery without implicit save")
        probe("missing-save", recovery, "MISSING")  # Explicit save after missing load.
        check_document(recovery, 0, 0, {})
        expected_recovery["save.json"] = recovery.read_bytes()
        unchanged(recovery, expected_recovery, "Explicit defaults save preserves quarantine")
        probe("verify-defaults", recovery, "LOADED")
        unchanged(recovery, expected_recovery, "Next process loads defaults; quarantine intact")
        print("Cross-process recovery: PASS", flush=True)

        for _ in range(LOAD_CYCLES):
            probe("read", valid, "LOADED")
            unchanged(valid, expected_valid, "Repeated valid load")
        print("Repeated valid loads: PASS", flush=True)

        abandoned = fixture("abandoned")
        abandoned.write_bytes(expected_valid["save.json"])
        partial = b'{"schema_version":1,"record":999,"coins":'
        abandoned.with_name("save.json.tmp").write_bytes(partial)
        expected_abandoned = dict(expected_valid, **{"save.json.tmp": partial})
        for _ in range(LOAD_CYCLES):
            probe("read", abandoned, "LOADED")
            unchanged(abandoned, expected_abandoned, "Abandoned temporary preservation")
        print("Abandoned temporary preservation: PASS", flush=True)
        # Inspect all fixtures once more before TemporaryDirectory removes them.
        unchanged(valid, expected_valid, "Final valid fixture")
        unchanged(recovery, expected_recovery, "Final quarantine evidence")
        unchanged(abandoned, expected_abandoned, "Final abandoned temporary")
    print("\nTST-02 AUTOMATED PASS", flush=True)
except (OSError, RuntimeError, ValueError) as error:
    print(f"\nTST-02 AUTOMATED FAIL: {error}", file=sys.stderr, flush=True)
    sys.exit(1)
PY
