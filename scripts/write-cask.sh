#!/usr/bin/env bash
# Écrit le cask Homebrew de Clawdio. Partagé par l'install locale (package.sh) et la release publique (release.sh).
# ./scripts/write-cask.sh <version> <sha256> <url> <homepage> <sortie.rb>
set -euo pipefail
VERSION="$1" SHA="$2" URL="$3" HOMEPAGE="$4" OUT="$5"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<RUBY
cask "clawdio" do
  version "$VERSION"
  sha256 "$SHA"

  url "$URL"
  name "Clawdio"
  desc "Claude Code quota and agent status in the notch, with a pixel art mascot"
  homepage "$HOMEPAGE"

  depends_on macos: :sonoma

  app "Clawdio.app"

  # Build signé ad-hoc, non notarisé : sans ça Gatekeeper refuse le lancement depuis Launchpad.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "/Applications/Clawdio.app"]
  end

  uninstall quit: "dev.clawdio.notch"

  zap trash: "~/Library/Preferences/dev.clawdio.notch.plist"
end
RUBY
