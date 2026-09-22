#!/usr/bin/env bash
# Génère la page de visualisation des sprites de l'avatar (build/sprite-viewer.html) depuis le code Swift.
# ./scripts/sprite-viewer.sh [sortie.html]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build/sprite-viewer.html}"
JSON="$(mktemp -t clawdio-sprites)"
trap 'rm -f "$JSON"' EXIT

swift build
"$(swift build --show-bin-path)/Clawdio" --export-sprites "$JSON"

mkdir -p "$(dirname "$OUT")"
python3 -c '
import sys
json_text = open(sys.argv[1]).read()
page = open(sys.argv[2]).read().replace("/*SPRITES_JSON*/null", json_text)
open(sys.argv[3], "w").write(page)
' "$JSON" scripts/sprite-viewer.html "$OUT"

echo "OK → $OUT"
