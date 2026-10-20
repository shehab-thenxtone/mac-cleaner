#!/usr/bin/env bash
# Builds a release "Mac Cleaner.app" into ./build (ad-hoc signed).
# Universal (Apple Silicon + Intel) by default; set ARCHS="arm64" for a faster native-only build.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS="${ARCHS:-arm64 x86_64}"
ARCH_FLAGS=()
for arch in $ARCHS; do ARCH_FLAGS+=(--arch "$arch"); done

swift build -c release --product MacCleaner "${ARCH_FLAGS[@]}"
BIN="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)/MacCleaner"

APP="build/Mac Cleaner.app"
mkdir -p build
[ -d "$APP" ] && mv "$APP" "$(mktemp -d)/"   # move the old bundle aside instead of deleting in place
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacCleaner"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] || ./scripts/make-icns.sh
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built: $APP ($(lipo -archs "$APP/Contents/MacOS/MacCleaner"))"
