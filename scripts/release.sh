#!/usr/bin/env bash
# Publie une version de Clawdio : build, zip en GitHub Release, puis cask à jour dans le tap Homebrew.
#   ./scripts/release.sh 0.2.0
# Ensuite, pour tout le monde : brew install --cask <compte>/clawdio/clawdio
# Prérequis : gh connecté (gh auth login), dépôts <compte>/clawdio et <compte>/homebrew-clawdio (créés au besoin).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage : ./scripts/release.sh <version>, ex. 0.2.0}"
export VERSION
OWNER="${CLAWDIO_OWNER:-$(gh api user --jq .login)}"
REPO="$OWNER/clawdio"
TAP_REPO="$OWNER/homebrew-clawdio"
TAG="v$VERSION"

git diff --quiet && git diff --cached --quiet || { echo "Commits d'abord : l'arbre de travail n'est pas propre." >&2; exit 1; }
gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 && { echo "$TAG existe déjà sur $REPO." >&2; exit 1; }

# Version inscrite dans le dépôt : Info.plist de référence, commitée avec le tag.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
git commit -qam "Release $VERSION" || true
git tag "$TAG"
git push -q origin HEAD "$TAG"

./scripts/build-app.sh >/dev/null
mkdir -p dist
ZIP="dist/Clawdio-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Clawdio.app "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

gh release create "$TAG" "$ZIP" --repo "$REPO" --title "Clawdio $VERSION" \
  --notes "Installer / mettre à jour : \`brew install --cask $OWNER/clawdio/clawdio\` (ou \`brew upgrade --cask clawdio\`)."

# Tap : dépôt homebrew-clawdio, un seul fichier Casks/clawdio.rb.
gh repo view "$TAP_REPO" >/dev/null 2>&1 || gh repo create "$TAP_REPO" --public \
  --description "Homebrew tap for Clawdio" >/dev/null
TAP_DIR="$(mktemp -d -t clawdio-tap)"
trap 'rm -rf "$TAP_DIR"' EXIT
gh repo clone "$TAP_REPO" "$TAP_DIR" -- -q 2>/dev/null || git -C "$TAP_DIR" init -q
./scripts/write-cask.sh "$VERSION" "$SHA" \
  "https://github.com/$REPO/releases/download/v#{version}/Clawdio-#{version}.zip" \
  "https://github.com/$REPO" "$TAP_DIR/Casks/clawdio.rb"
git -C "$TAP_DIR" add Casks/clawdio.rb
git -C "$TAP_DIR" commit -qm "clawdio $VERSION"
git -C "$TAP_DIR" branch -M main
git -C "$TAP_DIR" remote get-url origin >/dev/null 2>&1 || git -C "$TAP_DIR" remote add origin "https://github.com/$TAP_REPO.git"
git -C "$TAP_DIR" push -q -u origin main

echo "Publié : $TAG · sha256 $SHA"
echo "Installer : brew install --cask $OWNER/clawdio/clawdio"
