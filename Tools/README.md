# Asset Pipeline

Every art and audio asset in Crystal Caper is generated, then committed into
`../Resources/` as flat PNG/WAV files. This folder documents how they were made
so the pipeline is reproducible.

## Generated art (PixelLab MCP)

Characters and the tileset were created with the [PixelLab](https://pixellab.ai)
MCP. The finished frames are already in `Resources/`; the IDs below let you
regenerate or extend them.

| Asset | PixelLab ID | Animations (east-facing) |
|-------|-------------|--------------------------|
| Pip the Fox (hero) | `de268521-eefb-466f-910f-ce85e29627de` | `breathing-idle` (4f), `running-6-frames` (6f), `jumping-1` (9f) |
| Grumpcap (enemy) | `bf901f6b-ec11-40e1-a944-015ae29fd2e6` | `walking` (6f) |
| Forest tileset | `33cdfbe0-e61d-4d2d-955d-f773f515a16a` | 16-tile Wang sheet, 16px |

Character frames are public on `backblaze.pixellab.ai`; the tileset image is at
`https://api.pixellab.ai/mcp/sidescroller-tilesets/<id>/image` (follow redirects
with `curl -L`).

Side-view characters only need the **east** rotation — the game mirrors it
(`xScale = -1`) for west, which keeps each animation to a single generation.

## Tiles — `slice_tileset.py`

The Wang sheet (`tileset_src.png`) isn't a simple surface/fill pair: grass edge
tiles store grass at the cell *bottom*. The slicer takes the solid-dirt cell
(2,1) and composites a vertically-flipped grass cell (3,0) over it to produce a
gapless grass-capped surface tile.

```bash
pip3 install pillow
python3 Tools/slice_tileset.py   # -> Resources/tile_surface.png + tile_fill.png
```

## Audio — `gen_sfx.py`

Five chiptune SFX (jump, gem, stomp, hurt, win) are synthesized as 16-bit mono
WAVs with the Python standard library — no samples, no dependencies.

```bash
python3 Tools/gen_sfx.py          # -> Resources/sfx_*.wav
```

## Procedural fallbacks

`Assets.swift` draws hand-coded placeholder textures (hero, enemy, **boss**, gem,
flag, tiles, sky, hills) whenever a real PNG is missing, so the game is always
buildable and playable even before assets are integrated. The boss, "King
Grumpcap" (`bossPlaceholder()`), is intentionally placeholder-only for now to
conserve the PixelLab trial budget; drop `boss_walk_0.png`… into `Resources/` and
the loader picks them up with no code change.

## Web port validation — `web_harness.mjs`

The web build (`docs/index.html`) has no compile step, so `Tools/web_harness.mjs`
is its "compiler": a headless Node `vm` harness that stubs the browser
(`document`/`canvas`/`Image`/`Audio`/`requestAnimationFrame`/events), evaluates the
real page script, asserts the level-generator invariants (ground gaps ≤ 5 tiles,
floating ledges ≥ 3-tile clearance, ≥1 moving platform from level 4), and drives
the actual game loop for hundreds of frames at several levels (incl. boss levels)
to catch runtime errors before they reach a browser.

```bash
node Tools/web_harness.mjs            # full suite
node Tools/web_harness.mjs 5 600      # drive only level 5 for 600 frames
```

The leaderboard backend has its own in-process round-trip test:
`node leaderboard/test-worker.mjs`.
