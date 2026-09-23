#!/usr/bin/env bash
# Génère docs/social-preview.png (1280 × 640) : l'image montrée quand le lien du dépôt est partagé (Discord,
# Slack, X…). À téléverser une fois dans Settings → General → Social preview du dépôt GitHub. Nécessite Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d -t clawdio-social)"
trap 'rm -rf "$WORK"' EXIT

swift build
"$(swift build --show-bin-path)/Clawdio" --export-sprites "$WORK/sprites.json" >/dev/null

mkdir -p docs
python3 - "$WORK" <<'PY'
import json, sys
from PIL import Image, ImageDraw, ImageFont

work = sys.argv[1]
data = json.load(open(f"{work}/sprites.json"))
W, H = 1280, 640

def pixels(image_id):
    return [[tuple(int(c[i:i + 2], 16) for i in (0, 2, 4, 6)) if c else None for c in row]
            for row in data["images"][image_id]["px"]]

# Même dégradé que l'icône (palette du halo), en diagonale.
stops = [(0.00, (217, 189, 184)), (0.35, (222, 191, 209)), (0.65, (209, 173, 222)), (1.00, (163, 120, 194))]

def gradient_at(t):
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))
    return stops[-1][1]

card = Image.new("RGB", (W, H))
card.putdata([gradient_at((x / W + y / H) / 2) for y in range(H) for x in range(W)])
draw = ImageDraw.Draw(card)

def blit(layer, scale, left, top):
    for y, row in enumerate(layer):
        for x, px in enumerate(row):
            if px is not None:
                card.paste(Image.new("RGBA", (scale, scale), px), (left + x * scale, top + y * scale),
                           Image.new("L", (scale, scale), px[3]))

# Clawd en grand à gauche, avec son ombre au sol.
scale = 22
left, top = 96, (H - 16 * scale) // 2
for layer in (pixels(data["shadow"]), pixels(data["rest"]["idle"])):
    blit(layer, scale, left, top)

# La rangée d'activités en bas à droite, plus petite.
poses = [data["rest"][k] for k in ("working.read", "working.write", "working.run", "working.web", "working.delegate")]
for i, pose in enumerate(poses):
    blit(pixels(pose), 6, 560 + i * 120, 470)

ink, soft = (42, 29, 51), (74, 56, 86)
title = ImageFont.truetype("Resources/Fonts/Monocraft.ttc", 96)
body = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 34)
mono = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 21)

draw.text((560, 150), "Clawdio", font=title, fill=ink)
draw.text((560, 268), "Claude Code quota and agent status", font=body, fill=soft)
draw.text((560, 312), "in the Mac notch.", font=body, fill=soft)

chip = [560, 378, 560 + int(draw.textlength("brew install --cask NoahSmo/clawdio/clawdio", font=mono)) + 48, 438]
draw.rounded_rectangle(chip, 14, fill=(28, 20, 34))
draw.text((chip[0] + 24, 398), "brew install --cask NoahSmo/clawdio/clawdio", font=mono, fill=(235, 226, 240))

card.save("docs/social-preview.png")
PY

echo "OK → docs/social-preview.png (1280 × 640)"
echo "À téléverser : https://github.com/NoahSmo/clawdio/settings → General → Social preview"
