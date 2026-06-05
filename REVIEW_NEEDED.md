# Review needed — Crystal Caper

Specific, actionable items for Alex. Everything else is done, verified, and pushed.

## 1. Deploy the leaderboard backend, then flip the URL on (≈3 min)

You chose **Cloudflare Worker + KV** and **"build first, decide deploy later."** All
the code ships disabled (URL empty), so the game already works with the personal
best; the shared online board lights up the moment you do this:

```bash
cd leaderboard
npx wrangler login                              # one-time browser OAuth
npx wrangler kv namespace create LEADERBOARD    # copy the printed id …
#   → paste it into leaderboard/wrangler.toml  (id = "…")
npx wrangler deploy                             # prints https://crystal-caper-leaderboard.<you>.workers.dev
```

Then set that URL in **both** clients and commit (Pages auto-redeploys the web one):

- `docs/index.html`  →  `const DEFAULT_LB = "https://…workers.dev";`
- `Sources/Leaderboard.swift`  →  `static let baseURL = "https://…workers.dev"`

**Verify after deploy:**
`curl -s https://…workers.dev/top` → `{"top":[]}`, then load
`https://ibrews.github.io/crystal-caper/` , finish a run, and the "— GLOBAL TOP —"
panel should list your score.

Already verified locally (no account needed): `node leaderboard/test-worker.mjs`
(in-process round-trip) **and** a live `npx wrangler dev --local` HTTP round-trip
(submit→read, validation, CORS, rate-limit all green).

> Abuse note: anyone can POST from a static page. The Worker does light validation
> (name ≤6 A–Z0–9, score 0–5M, level 1–9999) + a per-IP 2 s rate limit. It's a *fun*
> board, not ranked competition — don't trust it for anything that matters.

## 2. (Optional) Real PixelLab art for the boss

"King Grumpcap" currently uses a hand-drawn procedural placeholder
(`Assets.bossPlaceholder()` / the Canvas `drawBoss()`), deliberately, to conserve
the PixelLab trial budget (~9/40 used). If you want real art later, generate a
`create_character` on a larger canvas and drop `boss_walk_0.png`… into `Resources/`
— the loader adopts it with no code change (mirror the east frames; the game flips
for west). Update `Tools/README.md` with the new PixelLab ID if you do.
