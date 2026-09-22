#!/usr/bin/env bash
# Installe le build local de Clawdio dans /Applications via un tap Homebrew local (local/clawdio).
# Pour installer la version publiée : brew install --cask <compte>/clawdio/clawdio (voir README).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/package.sh

TAP="${CLAWDIO_TAP:-local/clawdio}"

# Migration : l'app s'appelait Claudio (cask "claudio", tap local/claudio). Ses préférences sont reprises au
# premier lancement de Clawdio (PreferencesMigration) ; on désinstalle l'ancienne app pour éviter deux notchs.
pkill -x Claudio 2>/dev/null || true
if brew list --cask claudio >/dev/null 2>&1; then brew uninstall --cask claudio; fi
for old in $(brew tap | grep "/claudio$" || true); do brew untap "$old" >/dev/null; done

brew tap | grep -qx "$TAP" || brew tap-new --no-git "$TAP" >/dev/null
TAP_DIR="$(brew --repository "$TAP")"
mkdir -p "$TAP_DIR/Casks"
cp Casks/clawdio.rb "$TAP_DIR/Casks/clawdio.rb"

pkill -x Clawdio 2>/dev/null || true
if brew list --cask clawdio >/dev/null 2>&1; then
  brew upgrade --cask "$TAP/clawdio" || brew reinstall --cask "$TAP/clawdio"
else
  brew install --cask "$TAP/clawdio"
fi

open -a Clawdio
echo "Installé : /Applications/Clawdio.app"
