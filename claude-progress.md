# Crystal Caper — Progress

## Status: ✅ COMPLETE & VERIFIED — playable game, win confirmed on device

A SpriteKit pixel-art platformer with 100% generated assets (PixelLab art +
synthesized audio). Builds clean, runs at 60fps on iPhone 17 (iOS 26.5),
autopilot beats the level end-to-end.

## Done
- Full game (17 Swift files): manual-gravity platformer controller, contacts,
  camera follow + clamp, parallax, particles, screen shake, jump assists
  (coyote time + jump buffer), win/game-over/respawn, tap-to-restart.
- Controls: on-screen ◀ ▶ JUMP + hardware keyboard (A/D/←/→, Space/W/↑).
- Generated assets integrated:
  - Hero "Pip" (fox) — idle/run/jump animations (east, mirrored for west).
  - Enemy "Grumpcap" (mushroom) — walk animation.
  - Forest tileset — sliced + composited grass-capped dirt from the Wang sheet.
  - 5 chiptune SFX (jump/gem/stomp/hurt/win), synthesized in pure Python.
- Procedural placeholder textures so the game runs at any asset stage.
- Attract/self-test bot (`CC_AUTOPLAY=1`) — runs the level autonomously; used
  for headless gameplay verification (caught the platform-clearance bug below).
- README + Tools/ pipeline docs + reproducible asset scripts.

## Verified on device (iPhone 17 / iOS 26.5)
- Run, jump pits, stomp enemies, collect gems, reach goal → WIN screen.
- Win run: Score 2500, 5/14 gems, +1500 life bonus, 60fps, 234 nodes / 78 draws.

## Tunables (GameConfig.swift)
gravityAccel 2600 · moveSpeed 360 · jumpVelocity 1080 · stompBounce 760
coyote 0.10 · buffer 0.12 · playerBody 52×104 @ (0,-22) · enemyBody 78×70 @ (0,-30)
Set `showDebugOverlays = true` for FPS/draw/physics overlays.

## Failed approaches / gotchas (keep — saves a future session)
- PixelLab tileset image URL returned a 0-byte file with plain curl — it 302
  redirects to a CDN; needs `curl -L`. (Character frame URLs are direct, no -L.)
- `create_*_object` PixelLab tools cost 20-40 generations each — unusable on a
  20-generation trial. Made the collectible/flag procedural instead; all
  characters cost 1 gen each.
- LEVEL BUG (found by autopilot): floating platforms only 2 tiles above the
  ground formed a low ceiling — the ~3-tile-tall fox body collided and the bot
  ran in place. Fix: floating platforms need ≥3-tile clearance (row 6+). A human
  would have hit the same wall. Lesson: in-lane ceilings must clear player body.
- iPhone sim boots portrait; landscape-locked app renders rotated → post-rotate
  screenshots with `sips -r 270`.

## Possible next steps (not required)
- Nudge player start / inset HUD off the Dynamic Island at far-left.
- More levels (LevelData is data-driven — add level2, scene transition).
- App icon from Pip's south rotation.
- Music loop.
