#!/usr/bin/env node
// In-process round-trip test for the leaderboard Worker. Exercises the real
// worker.js fetch handler against an in-memory KV stub + standard Request/Response
// (Node 18+ globals) — proves submit→read, sorting, validation, CORS, and rate
// limiting WITHOUT a Cloudflare account, so the round-trip is verified before deploy.
//
// Run:  node leaderboard/test-worker.mjs
import worker from "./worker.js";

// Minimal KV stub matching the get/put(+expirationTtl) surface the Worker uses.
function makeKV() {
  const m = new Map(), exp = new Map();
  return {
    async get(k) {
      if (exp.has(k) && exp.get(k) < Date.now()) { m.delete(k); exp.delete(k); }
      return m.has(k) ? m.get(k) : null;
    },
    async put(k, v, opts) { m.set(k, String(v)); if (opts?.expirationTtl) exp.set(k, Date.now() + opts.expirationTtl * 1000); },
  };
}

let fails = 0;
const ok = (cond, msg) => { if (!cond) { fails++; console.error("  ✗ " + msg); } else console.log("  ✓ " + msg); };

const env = { LEADERBOARD: makeKV() };
const BASE = "https://lb.example.workers.dev";
const call = (method, path, body, ip) =>
  worker.fetch(new Request(BASE + path, {
    method,
    headers: { "Content-Type": "application/json", ...(ip ? { "CF-Connecting-IP": ip } : {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  }), env);

console.log("[leaderboard worker]");

// Empty board + CORS.
let r = await call("GET", "/top"); let j = await r.json();
ok(r.status === 200 && Array.isArray(j.top) && j.top.length === 0, "GET /top returns empty board");
ok(r.headers.get("access-control-allow-origin") === "*", "CORS allow-origin header present");
r = await call("OPTIONS", "/submit");
ok(r.status === 200 && r.headers.get("access-control-allow-methods")?.includes("POST"), "OPTIONS preflight ok");

// Submit + read back (the round trip).
r = await call("POST", "/submit", { name: "pip", score: 2500, level: 3 }, "1.1.1.1"); j = await r.json();
ok(r.status === 200 && j.ok && j.rank === 1, "submit accepted, rank 1");
ok(j.top[0].name === "PIP" && j.top[0].score === 2500 && j.top[0].level === 3, "name sanitized + entry stored");
r = await call("GET", "/top"); j = await r.json();
ok(j.top.length === 1 && j.top[0].score === 2500, "round-trip: submitted score reads back from KV");

// Sorting (desc by score, then level).
await call("POST", "/submit", { name: "AAA", score: 9999, level: 7 }, "2.2.2.2");
await call("POST", "/submit", { name: "BBB", score: 100, level: 1 }, "3.3.3.3");
r = await call("GET", "/top"); j = await r.json();
ok(j.top[0].score === 9999 && j.top[j.top.length - 1].score === 100, "board sorted high→low");

// Validation.
ok((await call("POST", "/submit", { name: "X", score: -5, level: 1 }, "4.4.4.4")).status === 422, "rejects negative score");
ok((await call("POST", "/submit", { name: "X", score: 1e12, level: 1 }, "5.5.5.5")).status === 422, "rejects implausible score");
ok((await call("POST", "/submit", { name: "X", score: 50, level: 0 }, "6.6.6.6")).status === 422, "rejects level < 1");
r = await worker.fetch(new Request(BASE + "/submit", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{not json" }), env);
ok(r.status === 400, "rejects malformed JSON");

// Name sanitisation edge: emoji/long → clamped, never empty.
r = await call("POST", "/submit", { name: "💎abcdefgh", score: 5, level: 1 }, "8.8.8.8"); j = await r.json();
ok(/^[A-Z0-9]{1,6}$/.test(j.top.find(e => e.score === 5).name), "name clamped to ≤6 A–Z0–9");

// Rate limit (same IP twice fast → 429).
await call("POST", "/submit", { name: "RL", score: 11, level: 1 }, "9.9.9.9");
ok((await call("POST", "/submit", { name: "RL", score: 22, level: 1 }, "9.9.9.9")).status === 429, "per-IP rate limit blocks rapid resubmit");

// 404.
ok((await call("GET", "/nope")).status === 404, "unknown route → 404");

console.log(`\n${fails === 0 ? "PASS ✅" : "FAIL ❌ (" + fails + " failure(s))"}`);
process.exit(fails === 0 ? 0 : 1);
