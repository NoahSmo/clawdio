#!/usr/bin/env bash
# Génère docs/screenshot.png pour le README : la pastille et le panneau ouvert, avec des DONNÉES D'EXEMPLE
# (DemoData) — aucun quota, coût ni titre de conversation réel. Nécessite Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d -t clawdio-shot)"
trap 'rm -rf "$WORK"' EXIT

swift build
CLAWDIO_DEMO=1 "$(swift build --show-bin-path)/Clawdio" --snapshot "$WORK" >/dev/null

mkdir -p docs
python3 - "$WORK" <<'PY'
import sys
from PIL import Image

work = sys.argv[1]
pill = Image.open(f"{work}/demo-collapsed.png").convert("RGBA")
panel = Image.open(f"{work}/demo-expanded.png").convert("RGBA")

# La pastille est rendue sur toute la largeur de l'écran : on garde sa partie utile, centrée sur l'encoche.
pill = pill.crop(pill.getbbox() or pill.size)
scale = panel.width / pill.width
pill = pill.resize((panel.width, max(1, round(pill.height * scale))), Image.LANCZOS)

gap = 40
shot = Image.new("RGBA", (panel.width, pill.height + gap + panel.height), (24, 24, 27, 255))
shot.alpha_composite(pill, (0, 0))
shot.alpha_composite(panel, (0, pill.height + gap))
shot.convert("RGB").resize((shot.width // 2, shot.height // 2), Image.LANCZOS).save("docs/screenshot.png")
PY

echo "OK → docs/screenshot.png"
