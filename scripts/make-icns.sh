#!/usr/bin/env bash
# Renders the icon and packs Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
swift scripts/make-icon.swift "$WORK/icon_1024.png"
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon_1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$WORK/icon_1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
cp "$WORK/icon_1024.png" Resources/AppIcon.png
echo "Wrote Resources/AppIcon.icns"
