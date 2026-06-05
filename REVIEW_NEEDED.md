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

## 2. TestFlight — blocked on your ASC credentials (device install already done)

The app is **installed on your iPhone 15 Pro** (`com.ibrews.crystalcaper`, signed
Apple Development: Alex Coulombe, team C624J4S2F8) — tap it to play. TestFlight,
though, needs two things this never-shipped app lacks and that only you can supply:

1. **App Store Connect issuer ID** — not stored on this Mac (only the `.p8` keys are:
   `~/.private_keys/AuthKey_79HM47GZ7C.p8`, `AuthKey_AU4ZR3VHZN.p8`). Get it from
   App Store Connect → Users and Access → Integrations → App Store Connect API (the
   UUID at the top). Needed for every `altool`/ASC-API call.
2. **An app record** for bundle id `com.ibrews.crystalcaper` (register the bundle id,
   then create the app in ASC; confirm the Paid/Free agreements are active).

Shipping prep already done: `ITSAppUsesNonExemptEncryption=false` in Info.plist
(no export-compliance prompt), and distribution certs are present
(`Apple Distribution: Agile Lens LLC`).

**Once you paste the issuer ID + confirm the app record exists, the upload is:**
```bash
cd /Users/alex/dev/CrystalCaper
xcodegen generate
xcodebuild -project CrystalCaper.xcodeproj -scheme CrystalCaper -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/CrystalCaper.xcarchive \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=C624J4S2F8 CODE_SIGN_STYLE=Automatic archive
xcodebuild -exportArchive -archivePath build/CrystalCaper.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
xcrun altool --upload-app -f build/export/CrystalCaper.ipa -t ios \
  --apiKey 79HM47GZ7C --apiIssuer <ISSUER_ID>
```
(`ExportOptions.plist` = app-store-connect method, team C624J4S2F8, automatic signing.)
Tell me the issuer ID and I'll run this + watch it process. I held off because it
needs your account credential — same "surface before provisioning" rule as the
leaderboard backend.

## 3. (Optional) Real PixelLab art for the boss

"King Grumpcap" currently uses a hand-drawn procedural placeholder
(`Assets.bossPlaceholder()` / the Canvas `drawBoss()`), deliberately, to conserve
the PixelLab trial budget (~9/40 used). If you want real art later, generate a
`create_character` on a larger canvas and drop `boss_walk_0.png`… into `Resources/`
— the loader adopts it with no code change (mirror the east frames; the game flips
for west). Update `Tools/README.md` with the new PixelLab ID if you do.
