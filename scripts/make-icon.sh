#!/usr/bin/env bash
# Génère Resources/AppIcon.icns : Clawd en pixel art (le vrai sprite, exporté depuis le code) sur un carré arrondi
# en dégradé beige → rose → lavande → violet (les couleurs du halo du notch). Écrit aussi les images du README
# (docs/icon.png, docs/avatar.png).
# À relancer seulement si le sprite de repos ou la palette changent (l'.icns est versionné). Nécessite Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d -t clawdio-icon)"
trap 'rm -rf "$WORK"' EXIT

swift build
"$(swift build --show-bin-path)/Clawdio" --export-sprites "$WORK/sprites.json" >/dev/null

mkdir -p docs
python3 - "$WORK" <<'PY'
import json, math, sys
from PIL import Image, ImageDraw, ImageFilter

work = sys.argv[1]
data = json.load(open(f"{work}/sprites.json"))

def pixels(image_id):
    return [[tuple(int(c[i:i + 2], 16) for i in (0, 2, 4, 6)) if c else None for c in row]
            for row in data["images"][image_id]["px"]]

body, shadow = pixels(data["rest"]["idle"]), pixels(data["shadow"])

# Dégradé du halo (Aurora dans PanelBackground.swift), en diagonale du coin haut-gauche au coin bas-droit.
stops = [(0.00, (217, 189, 184)), (0.35, (222, 191, 209)), (0.65, (209, 173, 222)), (1.00, (163, 120, 194))]

def gradient_at(t):
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))
    return stops[-1][1]

def render(size):
    """Icône complète à `size` px, sprite agrandi d'un facteur entier (pixels nets)."""
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Gabarit macOS : carré arrondi de 824/1024, centré, avec une ombre douce dessous.
    side = size * 824 / 1024
    origin = (size - side) / 2
    radius = side * 0.225
    box = [origin, origin, origin + side, origin + side]

    shade = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shade).rounded_rectangle([box[0], box[1] + size * 0.01, box[2], box[3] + size * 0.01],
                                            radius, fill=(0, 0, 0, 90))
    icon.alpha_composite(shade.filter(ImageFilter.GaussianBlur(size * 0.012)))

    tile = Image.new("RGBA", (size, size))
    tile.putdata([gradient_at(min(1, max(0, ((x - origin) + (y - origin)) / (2 * side)))) + (255,)
                  for y in range(size) for x in range(size)])
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius, fill=255)
    icon.paste(tile, (0, 0), mask)

    # Sprite 16 × 16 : lignes utiles 2…15 (le haut est vide, réservé aux sauts) → centrées sur ces lignes-là.
    scale = max(1, int(side * 0.70 // 16))
    left = round(size / 2 - 8 * scale)
    top = round(size / 2 - 9 * scale)
    for layer in (shadow, body):
        for y, row in enumerate(layer):
            for x, px in enumerate(row):
                if px is None:
                    continue
                r, g, b, a = px
                block = Image.new("RGBA", (scale, scale), (r, g, b, a))
                icon.alpha_composite(block, (left + x * scale, top + y * scale))
    return icon

iconset = f"{work}/AppIcon.iconset"
import os
os.makedirs(iconset)
renders = {s: render(s) for s in (32, 64, 128, 256, 512, 1024)}
# 16 px : trop petit pour un facteur entier ≥ 1 dans le carré arrondi → réduction du rendu 64 px.
renders[16] = renders[64].resize((16, 16), Image.LANCZOS)
for points in (16, 32, 128, 256, 512):
    renders[points].save(f"{iconset}/icon_{points}x{points}.png")
    renders[points * 2].save(f"{iconset}/icon_{points}x{points}@2x.png")
renders[1024].save(f"{work}/preview.png")
renders[256].save("docs/icon.png")  # image du README

# Galerie des poses pour le README (docs/avatar.png) : activités, besoins, joie, sommeil — fond transparent, ×8.
def clip_frame(name, index):
    return next(c for c in data["clips"] if c["name"] == name)["frames"][index]["image"]

poses = [data["rest"][k] for k in ("working.read", "working.write", "working.run", "working.web", "working.delegate",
                                     "attention")] + [clip_frame("cheer", 4), clip_frame("snore", 1)]
scale, gap = 8, 24
cell = 16 * scale
gallery = Image.new("RGBA", (len(poses) * cell + (len(poses) - 1) * gap, cell), (0, 0, 0, 0))
for i, pose in enumerate(poses):
    for layer in (shadow, pixels(pose)):
        for y, row in enumerate(layer):
            for x, px in enumerate(row):
                if px is not None:
                    gallery.alpha_composite(Image.new("RGBA", (scale, scale), px), (i * (cell + gap) + x * scale, y * scale))
gallery.save("docs/avatar.png")
PY

iconutil -c icns "$WORK/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$WORK/preview.png" "${ICON_PREVIEW:-/dev/null}" 2>/dev/null || true
echo "OK → Resources/AppIcon.icns"
