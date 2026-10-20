#!/usr/bin/env bash
# Packages "Mac Cleaner.app" into a drag-to-Applications disk image: build/MacCleaner-<version>.dmg
# Set SKIP_BUILD=1 to package the existing build/Mac Cleaner.app without rebuilding.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Mac Cleaner.app"
[ "${SKIP_BUILD:-0}" = "1" ] || ./scripts/build-app.sh
[ -d "$APP" ] || { echo "Missing $APP. Run scripts/build-app.sh first." >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/MacCleaner-$VERSION.dmg"
VOLNAME="Mac Cleaner $VERSION"

STAGING="$(mktemp -d)/dmg"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Mac Cleaner.app"
ln -s /Applications "$STAGING/Applications"
cp Resources/AppIcon.icns "$STAGING/.VolumeIcon.icns"
SetFile -a C "$STAGING" 2>/dev/null || true   # use the custom volume icon when SetFile is available

[ -f "$DMG" ] && mv "$DMG" "$(mktemp -d)/"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
codesign --force --sign - "$DMG"
hdiutil verify "$DMG" >/dev/null

echo "Created: $DMG ($(du -h "$DMG" | cut -f1))"
echo "Recipients: open the DMG, drag Mac Cleaner into Applications, then allow it once in"
echo "System Settings › Privacy & Security › Open Anyway (the app is not notarized)."
