#!/usr/bin/env bash
set -euo pipefail

echo "IOS_READINESS_VERSION=1"

have() { command -v "$1" >/dev/null 2>&1; }

if have godot; then
  echo "GODOT_VERSION=$(godot --version | head -n1)"
else
  echo "GODOT_VERSION=missing"
fi

if have xcodebuild; then
  xcodebuild -version | awk 'NR==1{printf "XCODE_VERSION=%s",$0} NR==2{printf " %s\n",$0}'
else
  echo "XCODE_VERSION=missing"
fi

if have xcode-select; then
  echo "XCODE_DEVELOPER_DIR=$(xcode-select -p 2>/dev/null || echo unavailable)"
else
  echo "XCODE_DEVELOPER_DIR=missing"
fi

if have xcrun; then
  echo "IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || echo unavailable)"
else
  echo "IPHONEOS_SDK=missing"
fi

template_root="$HOME/Library/Application Support/Godot/export_templates"
template=""
if [[ -d "$template_root" ]]; then
  template="$(find "$template_root" -maxdepth 2 -type f -path '*/4.7.2.stable/ios.zip' -print -quit 2>/dev/null || true)"
fi
if [[ -n "$template" ]]; then
  echo "GODOT_IOS_TEMPLATE=present"
else
  echo "GODOT_IOS_TEMPLATE=missing"
fi

if have security; then
  valid_count="$(security find-identity -v -p codesigning 2>/dev/null | awk '/valid identities found/{print $1}' | tail -n1)"
  [[ -n "$valid_count" ]] || valid_count=0
  echo "VALID_CODESIGN_IDENTITIES=$valid_count"
else
  echo "VALID_CODESIGN_IDENTITIES=unknown"
fi

if have xcrun && xcrun xcdevice list --timeout 20 >/tmp/lut-xcdevice.json 2>/tmp/lut-xcdevice.err; then
  python3 - <<'PY'
import json
from pathlib import Path

path = Path("/tmp/lut-xcdevice.json")
try:
    data = json.loads(path.read_text())
except Exception:
    print("PHYSICAL_IOS_DEVICES=unknown")
    raise SystemExit(0)

devices = []
for item in data if isinstance(data, list) else []:
    if item.get("simulator") is True:
        continue
    platform = str(item.get("platform", "")).lower()
    if "iphoneos" not in platform and "ios" not in platform:
        continue
    devices.append(item)

print(f"PHYSICAL_IOS_DEVICES={len(devices)}")
for idx, item in enumerate(devices, 1):
    os_version = item.get("operatingSystemVersion") or item.get("osVersion") or "unknown"
    available = item.get("available")
    if available is None:
        available = not bool(item.get("error"))
    print(f"PHYSICAL_IOS_DEVICE_{idx}_AVAILABLE={str(bool(available)).lower()}")
    print(f"PHYSICAL_IOS_DEVICE_{idx}_OS={os_version}")
PY
else
  echo "PHYSICAL_IOS_DEVICES=unknown"
fi

rm -f /tmp/lut-xcdevice.json /tmp/lut-xcdevice.err

echo "IOS_READINESS_DONE=1"
