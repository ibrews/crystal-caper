// Crystal Caper — shared high-score board (Cloudflare Worker + KV).
//
// Two routes, both CORS-open so the static GitHub Pages site and the iOS app can
// call them directly:
//   GET  /top              → { top: [ {name, score, level, ts}, … ] }   (top 20)
//   POST /submit  {name,score,level}  → { ok, rank, top }
//
// This is a *fun* board, not ranked competition: anyone can POST from a static
// page, so we only do light validation + a per-IP rate limit. Don't trust it for
// anything that matters. The whole board lives in one KV key (read-modify-write);
// fine at hobby scale, racy under heavy concurrent writes.
//
// Deploy: see ./README.md. Then set LEADERBOARD_URL in docs/index.html and
// Sources/Leaderboard.swift to this Worker's URL.

const KEY = "board";
const MAX_ENTRIES = 100;      // keep at most this many in KV
const TOP_N = 20;             // return at most this many
const MAX_NAME = 6;
const MAX_SCORE = 5_000_000;  // plausibility cap (a perfect long run is well under this)
const MAX_LEVEL = 9999;
const RATE_MS = 2000;         // min interval between submits from one IP

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

function sanitizeName(n) {
  return String(n ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, MAX_NAME) || "???";
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });

    if (request.method === "GET" && url.pathname === "/top") {
      const board = JSON.parse((await env.LEADERBOARD.get(KEY)) || "[]");
      return json({ top: board.slice(0, TOP_N) });
    }

    if (request.method === "POST" && url.pathname === "/submit") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "malformed json" }, 400); }

      const name = sanitizeName(body.name);
      const score = Math.floor(Number(body.score));
      const level = Math.floor(Number(body.level));
      if (!Number.isFinite(score) || score < 0 || score > MAX_SCORE) return json({ error: "bad score" }, 422);
      if (!Number.isFinite(level) || level < 1 || level > MAX_LEVEL) return json({ error: "bad level" }, 422);

      // Light per-IP rate limit: compare against the last submit timestamp.
      const ip = request.headers.get("CF-Connecting-IP") || "anon";
      const rlKey = "rl:" + ip;
      const last = Number((await env.LEADERBOARD.get(rlKey)) || 0);
      const now = Date.now();
      if (now - last < RATE_MS) return json({ error: "slow down" }, 429);
      await env.LEADERBOARD.put(rlKey, String(now), { expirationTtl: 600 });

      const board = JSON.parse((await env.LEADERBOARD.get(KEY)) || "[]");
      const entry = { name, score, level, ts: now };
      board.push(entry);
      board.sort((a, b) => b.score - a.score || b.level - a.level);
      const trimmed = board.slice(0, MAX_ENTRIES);
      await env.LEADERBOARD.put(KEY, JSON.stringify(trimmed));
      const rank = trimmed.indexOf(entry);
      return json({ ok: true, rank: rank >= 0 ? rank + 1 : null, top: trimmed.slice(0, TOP_N) });
    }

    return json({ error: "not found", routes: ["GET /top", "POST /submit"] }, 404);
  },
};
