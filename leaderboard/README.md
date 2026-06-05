# Crystal Caper — shared leaderboard (Cloudflare Worker + KV)

A tiny serverless high-score board both the web port and the iOS app call. Free
tier, CORS-open, no third-party service that can vanish.

- `GET /top` → `{ "top": [ { "name", "score", "level", "ts" }, … ] }` (top 20)
- `POST /submit` `{ "name", "score", "level" }` → `{ "ok", "rank", "top" }`

It's a **fun board, not ranked competition.** Anyone can POST from a static page,
so the Worker only does light validation (name → ≤6 `A–Z0–9`, score `0–5,000,000`,
level `1–9999`) and a per-IP rate limit (one submit / 2 s). The whole board is one
KV key (read-modify-write) — fine at hobby scale, racy under heavy concurrent writes.

## Verify locally (no account needed)

```bash
node leaderboard/test-worker.mjs      # in-process submit→read round-trip + validation
npx wrangler dev --local              # optional: real HTTP on http://localhost:8787
# then:  curl -s localhost:8787/top
#        curl -s -XPOST localhost:8787/submit -d '{"name":"PIP","score":2500,"level":3}'
```

## Deploy (≈2 minutes — Alex)

```bash
cd leaderboard
npx wrangler login                                   # one-time browser OAuth
npx wrangler kv namespace create LEADERBOARD         # prints an id …
#   paste that id into wrangler.toml (the `id = "…"` line)
npx wrangler deploy                                  # prints https://crystal-caper-leaderboard.<you>.workers.dev
```

## Wire the clients

Set the deployed URL in both clients (then commit + let Pages redeploy):

- **Web** — `docs/index.html`: `const LEADERBOARD_URL = "https://…workers.dev";`
- **iOS** — `Sources/Leaderboard.swift`: `static let baseURL = "https://…workers.dev"`

While the URL is empty (the shipped default) the global board is simply hidden and
the game shows the existing **personal best** — nothing breaks pre-deploy.

## Custom domain (optional)

Add a route in the Cloudflare dashboard (Workers → your worker → Triggers) or via
`wrangler.toml` `routes` if you'd rather use `lb.yourdomain.com`.
