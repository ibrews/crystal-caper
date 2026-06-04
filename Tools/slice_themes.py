#!/usr/bin/env python3
"""Slice the snow + desert tilesets (same Wang layout as forest) into
tile_surface_<theme>.png / tile_fill_<theme>.png for docs/assets and Resources,
and write a preview montage to /tmp/themes_preview.png."""
from PIL import Image, ImageOps
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.normpath(os.path.join(HERE, "..", "docs", "assets"))
RES = os.path.normpath(os.path.join(HERE, "..", "Resources"))
TS = 16
THEMES = {"snow": "tileset_snow.png", "desert": "tileset_desert.png"}

def slice_sheet(path):
    img = Image.open(path).convert("RGBA")
    cell = lambda cx, cy: img.crop((cx*TS, cy*TS, cx*TS+TS, cy*TS+TS))
    fill = cell(2, 1)
    surface = fill.copy()
    surface.alpha_composite(ImageOps.flip(cell(3, 0)))
    return surface, fill

cells = [("forest",
          Image.open(os.path.join(DOCS, "tile_surface.png")).convert("RGBA"),
          Image.open(os.path.join(DOCS, "tile_fill.png")).convert("RGBA"))]
for key, fn in THEMES.items():
    surf, fill = slice_sheet(os.path.join(HERE, fn))
    for d in (DOCS, RES):
        surf.save(os.path.join(d, f"tile_surface_{key}.png"))
        fill.save(os.path.join(d, f"tile_fill_{key}.png"))
    cells.append((key, surf, fill))
    print("sliced", key)

scale, pad = 7, 12
W = pad + (TS*scale + pad) * len(cells)
H = pad*2 + TS*scale*2
m = Image.new("RGBA", (W, H), (110, 160, 210, 255))
for i, (k, s, f) in enumerate(cells):
    x = pad + i*(TS*scale + pad)
    m.alpha_composite(s.resize((TS*scale, TS*scale), Image.NEAREST), (x, pad))
    m.alpha_composite(f.resize((TS*scale, TS*scale), Image.NEAREST), (x, pad + TS*scale))
m.convert("RGB").save("/tmp/themes_preview.png")
print("preview -> /tmp/themes_preview.png")
