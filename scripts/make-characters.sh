#!/usr/bin/env bash
# Génère docs/characters.png, la galerie des personnages du README : Rocky, Rocky EVA, Rocky bulle, puis le duo
# Rocky & Grace (check et « Amaze ! »). Vrais sprites exportés depuis le code, fond transparent. Nécessite Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d -t clawdio-characters)"
trap 'rm -rf "$WORK"' EXIT

swift build
BIN="$(swift build --show-bin-path)/Clawdio"
for character in rocky rockySuit rockyBubble rockyGrace; do
    "$BIN" --export-sprites "$WORK/$character.json" "$character" >/dev/null
done

mkdir -p docs
python3 - "$WORK" <<'PY'
import json, sys
from PIL import Image

work = sys.argv[1]
SCALE, GAP = 6, 36  # ×6 par pixel de Rocky ; la bulle, aux pixels ⅔ plus petits, passe à ×4 (même taille à l'écran)

def load(character):
    return json.load(open(f"{work}/{character}.json"))

def frame(data, clip, index):
    return next(c for c in data["clips"] if c["name"] == clip)["frames"][index]["image"]

def render(data, image_id, scale):
    """Ombre, pose, puis la bulle éventuelle, agrandies au plus proche voisin."""
    w, h = data["width"], data["height"]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layers = [data["shadow"], image_id] + ([data["overlay"]] if data.get("overlay") else [])
    for layer in layers:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        img.putdata([tuple(int(c[i:i + 2], 16) for i in (0, 2, 4, 6)) if c else (0, 0, 0, 0)
                     for row in data["images"][layer]["px"] for c in row])
        out.alpha_composite(img)
    return out.resize((w * scale, h * scale), Image.NEAREST)

rocky, suit, bubble, duo = (load(c) for c in ("rocky", "rockySuit", "rockyBubble", "rockyGrace"))
cells = [
    render(rocky, rocky["rest"]["idle"], SCALE),
    render(suit, suit["rest"]["attention"], SCALE),
    render(bubble, bubble["rest"]["idle"], SCALE * 2 // 3),
    render(duo, frame(duo, "duo.fistBump", 3), SCALE),  # pince contre le poing, étincelles
    render(duo, frame(duo, "rocky.cheer", 4), SCALE),   # « Amaze ! Amaze ! Amaze ! »
]
height = max(c.height for c in cells)
gallery = Image.new("RGBA", (sum(c.width for c in cells) + GAP * (len(cells) - 1), height), (0, 0, 0, 0))
x = 0
for cell in cells:
    gallery.alpha_composite(cell, (x, height - cell.height))  # alignés sur le sol
    x += cell.width + GAP
gallery.save("docs/characters.png")
PY

echo "OK → docs/characters.png"
