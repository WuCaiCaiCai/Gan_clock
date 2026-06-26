#!/usr/bin/env python3
"""
Generate a 128x128 pixel-art logo from icon.svg.
  1. Rasterize SVG at 1024x1024 via cairosvg
  2. Detect tomato region (exclude cream background)
  3. Crop + pad, scale to 128x128 with NEAREST
  4. Quantize: map every pixel to nearest of ~20-key-color palette
  5. Aggressive cleanup: merge rare colors, denoise edges
"""

import cairosvg
import io
from PIL import Image

SVG_PATH = "/mnt/Data/Program/Gan_clock/icon.svg"
OUTPUT_PATH = "/mnt/Data/Program/Gan_clock/ICONCREAT/pixel_logo_128.png"

CREAM = (237, 230, 217)  # #ede6d9

# =======================================================
# Compact palette: ~20 key colors, no duplicates
# =======================================================
PALETTE_RGB = [
    # --- Core tomato reds (3 tiers) ---
    (226, 79, 64),    # #e24f40  main bright red
    (209, 59, 48),    # #d13b30  mid red
    (202, 63, 48),    # #ca3f30  mid-warm red
    # --- Deep shadows ---
    (169, 43, 37),    # #a92b25  core shadow
    (170, 43, 38),    # #aa2b26  deep shadow
    (149, 53, 39),    # #953527  dark edge
    # --- Greens (leaf) ---
    (125, 171, 90),   # #7dab5a  main leaf green
    (86, 123, 61),    # #567b3d  dark leaf shadow
    # --- Stem / olive tones ---
    (146, 93, 55),    # #925d37  stem brown
    (110, 111, 57),   # #6e6f39  olive
    (126, 104, 57),   # #7e6839  olive-brown
    # --- Highlights ---
    (253, 251, 251),  # #fdfbfb  white highlight
    (242, 130, 116),  # #f28274  pink highlight
    (243, 126, 113),  # #f37e71  coral pink
    (251, 224, 215),  # #fbe0d7  soft pink
    # --- Dark structural edges ---
    (69, 64, 61),     # #45403d  dark charcoal
    (62, 59, 57),     # #3e3b39  dark gray
    (53, 48, 47),     # #35302f  very dark
    (50, 48, 45),     # #32302d  near-black
    # --- Muted transition ---
    (187, 99, 68),    # #bb6344  orange-brown
    (199, 96, 70),    # #c76046  orange-red
]

TRANSPARENT = (0, 0, 0, 0)


def closest(r, g, b, a):
    if a < 30:
        return TRANSPARENT
    if abs(r - CREAM[0]) < 20 and abs(g - CREAM[1]) < 20 and abs(b - CREAM[2]) < 20:
        return TRANSPARENT
    best = 1e9
    best_color = None
    for pr, pg, pb in PALETTE_RGB:
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if d < best:
            best = d
            best_color = (pr, pg, pb)
    return (*best_color, 255)


# =======================================================
# 1. Rasterize
# =======================================================
print("[1/5] Rasterizing SVG at 1024x1024...")
png_bytes = cairosvg.svg2png(
    url=SVG_PATH, output_width=1024, output_height=1024,
    background_color="transparent",
)
img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")

# =======================================================
# 2. Find tomato bounds (non-cream, non-transparent)
# =======================================================
print("[2/5] Detecting tomato region...")
px = img.load()
w, h = img.size
x1, y1, x2, y2 = w, h, 0, 0

for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a < 30:
            continue
        if abs(r - CREAM[0]) < 18 and abs(g - CREAM[1]) < 18 and abs(b - CREAM[2]) < 18:
            continue
        x1, y1 = min(x1, x), min(y1, y)
        x2, y2 = max(x2, x), max(y2, y)

pad = min(int((x2 - x1) * 0.03), int((y2 - y1) * 0.03), x1, y1, w - x2, h - y2)  # ~3% padding
x1, y1 = max(0, x1 - pad), max(0, y1 - pad)
x2, y2 = min(w - 1, x2 + pad), min(h - 1, y2 + pad)
print(f"    Crop: ({x1},{y1})-({x2},{y2}) size={x2-x1+1}x{y2-y1+1}")

img = img.crop((x1, y1, x2 + 1, y2 + 1))

# =======================================================
# 3. Scale to 128x128 NEAREST
# =======================================================
print("[3/5] Scaling to 128x128 NEAREST...")
img = img.resize((128, 128), Image.NEAREST).convert("RGBA")

# =======================================================
# 4. Quantize to palette
# =======================================================
print("[4/5] Quantizing...")
px = img.load()
for y in range(128):
    for x in range(128):
        r, g, b, a = px[x, y]
        px[x, y] = closest(r, g, b, a)

# =======================================================
# 5. Aggressive denoise + rare-color merge (3 passes)
# =======================================================
print("[5/5] Denoise + rare-color merge...")

for _pass in range(3):
    # --- Count frequencies ---
    freq = {}
    for y in range(128):
        for x in range(128):
            c = px[x, y]
            freq[c] = freq.get(c, 0) + 1

    # --- Merge rare colors (< 8 pixels) before final pass ---
    if _pass < 2:
        for y in range(128):
            for x in range(128):
                c = px[x, y]
                if c == TRANSPARENT:
                    continue
                if freq.get(c, 0) < 8:
                    # find most common neighbor color
                    nbr = {}
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if dx == 0 and dy == 0:
                                continue
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < 128 and 0 <= ny < 128:
                                nc = px[nx, ny]
                                if nc != TRANSPARENT:
                                    nbr[nc] = nbr.get(nc, 0) + 1
                    if nbr:
                        px[x, y] = max(nbr, key=nbr.get)

    # --- Standard neighbor-majority denoise ---
    for y in range(1, 127):
        for x in range(1, 127):
            nbr = {}
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nc = px[x + dx, y + dy]
                    nbr[nc] = nbr.get(nc, 0) + 1
            best = max(nbr, key=nbr.get)
            if nbr[best] >= 6:
                px[x, y] = best

# =======================================================
# Stats + Save
# =======================================================
colors = set()
nontrans = 0
for y in range(128):
    for x in range(128):
        c = px[x, y]
        colors.add(c)
        if c[3] > 0:
            nontrans += 1

img.save(OUTPUT_PATH, "PNG")
print(f"Unique colors: {len(colors)}")
print(f"Non-transparent: {nontrans}/{128*128} ({nontrans/163.84:.1f}%)")
print(f"Done -> {OUTPUT_PATH}")
