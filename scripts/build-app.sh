#!/usr/bin/env bash
# Build Clawdio.app (bundle sans Dock icon, signé ad-hoc par défaut).
# SIGN_IDENTITY="Apple Development: ..." ./scripts/build-app.sh  → signature stable
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Clawdio"

APP="build/Clawdio.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Clawdio"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then   # version de release (scripts/release.sh, scripts/package.sh)
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi
mkdir -p "$APP/Contents/Resources"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"   # Monocraft (SIL OFL) + sa licence
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # généré par scripts/make-icon.sh
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

echo "OK → $APP"
echo "Lancer : open $APP"
