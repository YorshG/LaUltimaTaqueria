#!/usr/bin/env bash
set -euo pipefail

echo "== La Última Taquería :: macOS/iOS doctor =="

echo
echo "-- macOS --"
sw_vers

echo
echo "-- Architecture --"
uname -m

echo
echo "-- Disk --"
df -h /

echo
echo "-- Xcode app --"
if [ -d "/Applications/Xcode.app" ]; then
  echo "FOUND: /Applications/Xcode.app"
else
  echo "MISSING: /Applications/Xcode.app"
fi

echo
echo "-- xcode-select --"
if command -v xcode-select >/dev/null 2>&1; then
  xcode-select -p || true
else
  echo "xcode-select not found"
fi

echo
echo "-- xcodebuild --"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version || true
else
  echo "xcodebuild not found"
fi

echo
echo "-- Godot --"
if command -v godot >/dev/null 2>&1; then
  godot --version || true
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  /Applications/Godot.app/Contents/MacOS/Godot --version || true
else
  echo "Godot not found in PATH or /Applications/Godot.app"
fi

echo
echo "-- Godot project --"
if [ -f "project.godot" ]; then
  echo "FOUND: $(pwd)/project.godot"
else
  echo "MISSING: project.godot (run this script from repo root)"
fi

echo
echo "-- iPhone detection (optional) --"
if command -v xcrun >/dev/null 2>&1; then
  xcrun xctrace list devices 2>/dev/null | sed -n '1,80p' || true
else
  echo "xcrun not available"
fi

echo
echo "== Doctor finished =="
