#!/usr/bin/env python3
"""Generate a 1200x630 social card (docs/card.png) from the game's own art."""
from PIL import Image, ImageDraw, ImageFont
import os

A = os.path.expanduser("~/dev/CrystalCaper/docs/assets")
OUT = os.path.expanduser("~/dev/CrystalCaper/docs/card.png")
W, H = 1200, 630

img = Image.new("RGB", (W, H), (95, 176, 240))
d = ImageDraw.Draw(img)
for y in range(H):                                   # sky gradient
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(95+(191-95)*t), int(176+(227-176)*t), int(240+(251-240)*t)))

groundY = 472
d.rectangle([0, groundY, W, H], fill=(66, 42, 26))
surf = Image.open(os.path.join(A, "tile_surface.png")).convert("RGBA").resize((60, 60), Image.NEAREST)
fill = Image.open(os.path.join(A, "tile_fill.png")).convert("RGBA").resize((60, 60), Image.NEAREST)
for x in range(0, W, 60):
    img.paste(surf, (x, groundY - 12), surf)
    img.paste(fill, (x, groundY + 48), fill)

fox = Image.open(os.path.join(A, "pip_run_2.png")).convert("RGBA")
fox = fox.resize((fox.width * 5, fox.height * 5), Image.NEAREST)
img.paste(fox, (110, groundY - 12 - fox.height + 36), fox)

def gem(cx, cy, r=17):
    d.polygon([(cx, cy-r), (cx+r*0.8, cy), (cx, cy+r), (cx-r*0.8, cy)], fill=(63, 214, 239))
    d.polygon([(cx, cy-r), (cx+r*0.4, cy-2), (cx, cy+r*0.4), (cx-r*0.4, cy-2)], fill=(200, 247, 255))
for gx in (455, 530, 605):
    gem(gx, 300)

def font(sz):
    for p in ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "/Library/Fonts/Arial Bold.ttf",
              "/System/Library/Fonts/Helvetica.ttc"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, sz)
            except Exception: pass
    return ImageFont.load_default()

def text(x, y, s, sz, col, anchor="la", stroke=0, sc=(20, 40, 80)):
    d.text((x, y), s, font=font(sz), fill=col, anchor=anchor, stroke_width=stroke, stroke_fill=sc)

text(110, 70, "CRYSTAL CAPER", 96, (255, 255, 255), stroke=5)
text(114, 184, "a tiny Agile Lens adventure", 40, (224, 240, 255))
text(114, 246, "a pixel-art platformer · 100% AI-generated art", 30, (236, 246, 255))
text(114, 372, "▶  play free in your browser", 36, (255, 226, 122))
text(W - 28, H - 30, "ibrews.github.io/crystal-caper", 24, (255, 255, 255), anchor="rs")
img.save(OUT)
print("wrote", OUT)
