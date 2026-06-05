# Crystal Caper — Progress

## Base game: ✅ COMPLETE & VERIFIED (prior session)
SpriteKit pixel-art platformer + HTML5/Canvas web port, 100% generated assets.
Builds clean, 60fps on iPhone 17 (iOS 26.5), autopilot beats levels. Procedural
levels, 3 biomes, client-name crystal pops, all-crystal fireworks, looping music,
personal-best leaderboard.

---

## CURRENT TASK (2026-06-04): three new features, iOS + web parity

### Decisions
- **Leaderboard backend:** Cloudflare Worker + KV (Alex chose).
- **Deploy:** "Build first, decide deploy later" → clients are URL-flag-gated and degrade
  gracefully; Worker + Node test harness ship now; production `wrangler deploy` is Alex's step
  (REVIEW_NEEDED.md). Round-trip verified in-process via the Node harness (+ `wrangler dev --local` if available).
- **Boss art:** procedural `bossPlaceholder()` to conserve PixelLab trial budget (~9/40 used);
  loader auto-adopts real `boss_*.png` if dropped in later.

### Features
1. Moving platforms — carry the player; deterministic sinusoid; bonus floating ledges only
   (preserves gap≤5 / clearance≥3 invariants). Appear at level ≥ 4.
2. Boss — every 5th level; 3 stomps; telegraph (pause+flash) → charge + slow projectile;
   side contact costs a heart; on defeat: big bonus + all-crystals fireworks, then reveal goal.
3. Global leaderboard — shared Cloudflare Worker (name/score/level/ts, top 20), light validation +
   per-IP rate-limit; web + iOS clients; personal best retained.

### Status — ✅ DONE (commit 5fc7124, pushed to ibrews/crystal-caper main)
- [x] Moving platforms (iOS) / (web) — carry logic; deterministic sinusoid; L4+
- [x] Boss (iOS) / (web) — telegraph→charge/projectile, 3 stomps, defeat→fireworks→goal reveal
- [x] Leaderboard Worker + harness / web client / iOS client — URL-flag-gated, graceful
- [x] README + Things to Try + Tools/README + REVIEW_NEEDED + boss.png
- [x] iOS build SUCCEEDED; on-device shots: moving platform (L6), boss (L5), L1 regression WIN
- [x] Web vm-harness PASS (genLevel invariants + 1800+ loop frames); Worker round-trip PASS
      (in-process + live `wrangler dev` HTTP: submit→read, validation, CORS, rate-limit)
- [x] Browser smoke (preview agent) PASS all 3 — incl. full boss defeat loop + leaderboard
      POST/GET round-trip + board render; zero console errors
- [x] KB (projects/crystal-caper.md, 2 technique docs, daily, timing) committed + pushed
- [x] Committed + pushed; GitHub Pages live with new code (HTTP 200, markers present)
- [ ] Leaderboard PRODUCTION deploy = Alex's step (REVIEW_NEEDED.md); code verified, URL empty until then

### Env facts (verified this session)
- Swift 5.0 mode (project.yml), deployment iOS 17.0. Target sim UDID
  `974E8854-BFD9-4A36-A653-ED2142709C79` (iPhone 17, iOS 26.5) is Booted.
- `wrangler`/`supabase` CLIs NOT installed; no CF/Supabase creds in env. Node v26 present.

---

## Failed approaches / gotchas (KEEP — saves a future session)
- PixelLab tileset image URL returns a 0-byte file with plain curl — it 302 redirects to a CDN;
  needs `curl -L`. (Character frame URLs are direct, no -L.)
- `create_*_object` PixelLab tools cost 20-40 generations each — unusable on the trial. Make
  collectibles/flag/boss procedural instead; `create_character` costs ~1 gen each.
- PixelLab trial budget is small (~9/40 used as of this task) — do NOT spend generations casually.
- LEVEL BUG (found by autopilot): floating platforms only 2 tiles above ground formed a low
  ceiling — the ~3-tile fox body collided and the bot ran in place. Floating platforms need
  ≥3-tile clearance (row 6+). Keep this invariant when adding moving platforms.
- iPhone sim boots portrait; landscape-locked app renders rotated → post-rotate screenshots with
  `sips -r 270`.
- iOS LCG RNG and web mulberry32 RNG differ → same level number is NOT byte-identical across
  platforms (parallel, not mirrored). Verify each platform's level independently.
