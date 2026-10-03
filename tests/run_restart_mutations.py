#!/usr/bin/env python3
"""RST mutation checks run only in disposable copies; the checkout stays untouched."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT_BIN", "godot")
DIAGNOSTIC = re.compile(r"SCRIPT ERROR|^ERROR:|leaked at exit|still in use at exit", re.M)
MUTATIONS = (
    ("old-stays-in-tree", "\t\tsession_host.remove_child(_session)", "\t\t# deliberately kept old in tree", "RST-03:"),
    ("old-not-disabled", "\t\t_session.process_mode = Node.PROCESS_MODE_DISABLED", "\t\t# deliberately left old enabled", "RST-28:"),
    ("old-never-destroyed", "\t\t_session.queue_free()", "\t\t# deliberately omitted destruction", "RST-03:"),
    ("stale-generation-effective", "if generation != _generation:", "if false:", "RST-26:"),
    ("modal-keeps-simulating", "\t_suspend_subtree(_session)", "\t# deliberately omitted suspension", "RST-24:"),
    ("terminal-audio-latch", "\tsession_host.add_child(_session)",
     '\tsession_host.add_child(_session)\n\t_session.get_node("FeedbackAudio").set("_terminal", true)', "RST-17:"),
)


def run(project, *arguments):
    with tempfile.TemporaryDirectory(prefix="rst_01_engine_") as logs:
        return subprocess.run(
            [GODOT, "--headless", "--path", str(project), "--log-file", str(Path(logs) / "engine.log"), *arguments],
            cwd=project, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60,
        )


def isolated_metadata(temporary):
    key = "rst_01_isolated_" + uuid.uuid4().hex
    project = Path(temporary) / "metadata"
    shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(".git", ".godot", "graphify-out", "engine.log"))
    config = project / "project.godot"
    settings = re.sub(r"(?m)^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n", "", config.read_text())
    config.write_text(settings.replace("[application]", f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{key}"', 1))
    (project / ".rst-01-isolated").write_text(key)
    imported = run(project, "--editor", "--quit")
    if imported.returncode or DIAGNOSTIC.search(imported.stdout):
        raise RuntimeError("isolated metadata import failed:\n" + imported.stdout)
    located = run(project, "--script", "res://tests/restart_meta_probe.gd", "--", key, "locate")
    paths = [line.removeprefix("RST_META_DIR=") for line in located.stdout.splitlines() if line.startswith("RST_META_DIR=")]
    if located.returncode or len(paths) != 1 or Path(paths[0]).name != key:
        raise RuntimeError("isolated metadata directory was not verified:\n" + located.stdout)
    userdata = Path(paths[0]).resolve()
    marker = userdata / ".rst-01-userdata"
    marker.write_text(key)
    try:
        result = run(project, "--script", "res://tests/restart_meta_probe.gd", "--", key, "run")
        if result.returncode or DIAGNOSTIC.search(result.stdout) or "RST metadata PASS:" not in result.stdout:
            raise RuntimeError("isolated default metadata sentinel failed:\n" + result.stdout)
        print("RST metadata PASS: isolated default user:// sentinel unchanged; 40 restarts and 20 cancels.", flush=True)
    finally:
        # Delete only the unique directory with the exact marker we created.
        if userdata.name == key and marker.read_text() == key:
            shutil.rmtree(userdata)


def main():
    source = ROOT / "scripts/app.gd"
    original = source.read_bytes()
    boot = run(ROOT, "--quit-after", "3")
    if boot.returncode or DIAGNOSTIC.search(boot.stdout):
        raise RuntimeError("configured App bootstrap failed:\n" + boot.stdout)
    baseline = run(ROOT, "--script", "res://tests/restart_session_test.gd")
    if baseline.returncode or "RST-01 PASS: 30/30" not in baseline.stdout or DIAGNOSTIC.search(baseline.stdout):
        raise RuntimeError("clean baseline failed:\n" + baseline.stdout)
    try:
        with tempfile.TemporaryDirectory(prefix="rst_01_mutations_") as temporary:
            isolated_metadata(temporary)
            for name, before, after, expected_failure in MUTATIONS:
                project = Path(temporary) / name
                shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(".git", ".godot", "graphify-out", "engine.log"))
                candidate = project / "scripts/app.gd"
                text = candidate.read_text()
                if text.count(before) != 1:
                    raise RuntimeError(f"{name}: mutation anchor changed")
                candidate.write_text(text.replace(before, after, 1))
                imported = run(project, "--editor", "--quit")
                if imported.returncode or DIAGNOSTIC.search(imported.stdout):
                    raise RuntimeError(f"{name}: import failed:\n{imported.stdout}")
                result = run(project, "--script", "res://tests/restart_session_test.gd")
                if result.returncode == 0 or expected_failure not in result.stdout or "SCRIPT ERROR" in result.stdout:
                    raise RuntimeError(f"{name}: missing intended assertion {expected_failure}\n{result.stdout}")
                print(f"RST mutation killed: {name} -> {expected_failure}", flush=True)
    finally:
        if source.read_bytes() != original:
            raise RuntimeError("source checkout unexpectedly changed")
    print("RST mutation PASS: 6/6; disposable copies removed; checkout source unchanged.")


if __name__ == "__main__":
    main()
