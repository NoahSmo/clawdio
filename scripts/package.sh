#!/usr/bin/env bash
# Construit dist/Clawdio-<version>.zip et un cask local (url file://) dans Casks/clawdio.rb, pour install-cask.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)"
export VERSION="$BASE_VERSION.$(date +%Y%m%d%H%M%S)"   # nouvelle version à chaque build → pas de cache Homebrew périmé

./scripts/build-app.sh >/dev/null
mkdir -p dist
ZIP="dist/Clawdio-$VERSION.zip"
rm -f dist/Clawdio-*.zip
ditto -c -k --keepParent build/Clawdio.app "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

./scripts/write-cask.sh "$VERSION" "$SHA" "file://$PWD/$ZIP" "file://$PWD" Casks/clawdio.rb

echo "OK → $ZIP"
echo "sha256 $SHA"
