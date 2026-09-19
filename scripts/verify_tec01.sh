#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN=""
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot)"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "ERROR: Godot not found."
  exit 1
fi

echo "== TEC-01 verification =="
echo "Godot: $GODOT_BIN"
"$GODOT_BIN" --version

echo
echo "-- Importing project headlessly --"
"$GODOT_BIN" --headless --path . --editor --quit

echo
echo "-- Running bootstrap scene headlessly --"
"$GODOT_BIN" --headless --path . --scene res://scenes/Main.tscn --quit-after 3

echo
echo "TEC-01 PASS"
