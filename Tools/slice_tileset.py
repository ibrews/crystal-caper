#!/usr/bin/env python3
"""Slice Crystal Caper's ground tiles from the PixelLab sidescroller tileset.

Produces Resources/tile_surface.png (grass-capped) and tile_fill.png (dirt).

The source sheet is 64x64 = 16 Wang tiles of 16px. Cell (2,1) is solid dirt.
The grass edge tiles store grass at the cell BOTTOM, so we flip cell (3,0) and
composite its grass over the dirt fill to get a gapless grass-capped surface.

Usage:  python3 Tools/slice_tileset.py        (needs Pillow)
"""
from PIL import Image, ImageOps
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "tileset_src.png")
OUT = os.path.normpath(os.path.join(HERE, "..", "Resources"))
TS = 16

img = Image.open(SRC).convert("RGBA")

def cell(cx, cy):
    return img.crop((cx * TS, cy * TS, cx * TS + TS, cy * TS + TS))

fill = cell(2, 1)
surface = fill.copy()
surface.alpha_composite(ImageOps.flip(cell(3, 0)))   # grass cap over dirt, no gap

fill.save(os.path.join(OUT, "tile_fill.png"))
surface.save(os.path.join(OUT, "tile_surface.png"))
print("wrote tile_surface.png + tile_fill.png to", OUT)
