<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Mac Cleaner icon">
</p>

# Mac Cleaner

A native SwiftUI app for freeing disk space on macOS. It finds caches, logs and developer junk, previews files with Quick Look, tells you whether a file is safe to delete, and runs common cleanup commands (Docker, Homebrew, npm, Xcode, …) with live output.

Runs on macOS 14 Sonoma or later, on both Apple Silicon and Intel (universal build).

## Features

- **Overview**: free and used disk space, the reclaimable size of each category, a "Scan Everything" button, and **Refresh** (⌘R).
- **Cleanup categories**: User Caches, Logs, Xcode DerivedData, Simulator Caches, Device Support, Xcode Archives, package manager caches (npm/pnpm/Yarn/Bun/Gradle/Maven/Cargo/CocoaPods), Downloads, and iPhone/iPad backups. Each category is tagged **Safe**, **Review** or **Caution**.
- **Quick Look preview** of the selected item, plus Open, Reveal in Finder and Copy Path. Double-click a row to open it, or right-click for more actions.
- **Large Files**: finds files above a size you pick (100 MB to 5 GB) in any folder. Selecting a file shows a **"safe to delete?" tip**:
  - 🟢 **Safe**: caches, logs, build output, `node_modules`, installers in Downloads.
  - 🟠 **Check first**: personal media and documents, device backups, Xcode or simulator data, unknown files.
  - 🔴 **Keep**: Docker and VM disks, Git internals, app data in `~/Library`, protected locations.
  - It also notes files not opened in 180+ days, and files opened in the last week.
- **Commands**: one-click `docker system prune`, `brew cleanup`, `brew autoremove`, `npm cache clean`, `pnpm store prune`, `pip cache purge`, `go clean -modcache`, `xcrun simctl delete unavailable`, Time Machine local-snapshot thinning, DNS flush, Empty Trash, and more. Output streams into a console you can stop, copy or clear. Tools that aren't installed are greyed out.
- **Custom command**: run any shell command (in a login `zsh`) in the same console.
- **Navigation**: Back and Forward buttons (⌘[ and ⌘]).

## Safety model

- Files are **moved to the Trash**, never deleted directly, so you can restore them until you empty the Trash.
- Every removal is checked by `SafetyGuard`. It allows only paths inside your home folder. It never allows:
  - top-level folders (`~/Documents`, `~/Library`, …) or a category's root folder;
  - anything under `.ssh`, `.gnupg`, Keychains, Mail, Messages, Calendars or iCloud Drive;
  - the insides of app bundles or Photos/Music libraries.
  - Checks are case-insensitive, matching APFS.
- Every command except **Safe** ones asks for confirmation, and so does every custom command.
- Admin commands (DNS flush, purge) use macOS's own password prompt. The app never handles your password.
- Some folders (e.g. iOS backups) need **Full Disk Access** (System Settings › Privacy & Security). The app offers a shortcut when it hits one.

## Install

### From a DMG

1. Open `MacCleaner-<version>.dmg` and drag **Mac Cleaner** into **Applications**.
2. The app is not notarized by Apple, so macOS blocks the first launch. Open it once, then go to **System Settings › Privacy & Security** and click **Open Anyway**. You only need to do this once.

### From source

Requires Xcode 16+ (Swift 6).

```bash
git clone <this-repo> mac-cleaner && cd mac-cleaner
./scripts/build-app.sh
open "build/Mac Cleaner.app"
```

Apps built on your own Mac open without the Gatekeeper warning. To install, run `cp -R "build/Mac Cleaner.app" /Applications/`.

## Scripts

| Script | What it does |
| --- | --- |
| `scripts/build-app.sh` | Release build: a universal, ad-hoc signed `build/Mac Cleaner.app`. Set `ARCHS=arm64` for a faster native-only build. |
| `scripts/make-dmg.sh` | Builds the app and packages `build/MacCleaner-<version>.dmg` with an Applications shortcut. Set `SKIP_BUILD=1` to reuse an existing build. |
| `scripts/make-icns.sh` | Re-renders the icon from `scripts/make-icon.swift` into `Resources/AppIcon.icns`. |

The version comes from `CFBundleShortVersionString` in `Resources/Info.plist`.

## Development

```bash
swift run MacCleaner   # debug build, launches the app
swift test             # unit tests (Swift Testing)
```

```
Sources/CleanerCore/    scanning, SafetyGuard, Trasher, SafetyAdvisor, shell runner, catalogs (unit-tested)
Sources/MacCleaner/     SwiftUI app: models (AppState, Console, LargeFiles) and views
Tests/CleanerCoreTests/ Swift Testing suite
Resources/              Info.plist and app icon
scripts/                build, DMG and icon scripts
```

- **Add a command**: add an entry to `CleanupCommand.catalog` in `Sources/CleanerCore/CleanupCommand.swift`.
- **Add a folder category**: add an entry to `CleanupCategory.catalog` in `Sources/CleanerCore/CleanupCategory.swift`.
- **Change the safety tips**: edit the rules in `Sources/CleanerCore/SafetyAdvisor.swift`.

Debug builds can render each screen to PNG without a display, for UI checks: `MACCLEANER_SNAPSHOT_DIR=/tmp/shots swift run MacCleaner`.

## Distributing without the Gatekeeper warning

To make the app open without the "can't be verified" prompt, sign and notarize it with an Apple Developer account ($99/year):

```bash
codesign --force --options runtime --sign "Developer ID Application: <Your Name> (<TEAMID>)" "build/Mac Cleaner.app"
SKIP_BUILD=1 ./scripts/make-dmg.sh
xcrun notarytool submit build/MacCleaner-1.0.0.dmg --keychain-profile <profile> --wait
xcrun stapler staple build/MacCleaner-1.0.0.dmg
```

`make-dmg.sh` currently signs the DMG ad-hoc. Re-sign it with the same Developer ID before you submit it for notarization.
