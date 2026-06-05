#!/usr/bin/env node
// Headless validator for docs/index.html — the web port has no build step, so this
// is its "compiler". It stubs the browser (document/canvas/Image/Audio/rAF/events),
// evaluates the real <script> in a vm sandbox, then:
//   1. calls genLevel() across many levels and asserts the jumpability invariants
//      (ground gaps ≤ 5 tiles, floating ledges ≥ 3-tile clearance) + feature presence,
//   2. boots a fresh sandbox per chosen level and drives the actual game loop for N
//      frames with synthetic key input, so any runtime error in update()/render()
//      (moving platforms, boss, leaderboard hooks) surfaces here, not in the browser.
//
// Only `function`-declared globals are reachable from outside the vm (genLevel,
// advance, startLevel, frame, …); const/let stay private. We pick the start level
// via location.search (?level=N), which the page reads into `urlLevel` at load.
//
// Usage:  node Tools/web_harness.mjs            # full suite
//         node Tools/web_harness.mjs 5 600      # drive only level 5 for 600 frames
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import vm from "node:vm";

const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "..", "docs", "index.html"), "utf8");
const script = html.split("<script>")[1].split("</script>")[0];

let failures = 0;
const fail = (m) => { failures++; console.error("  ✗ " + m); };
const ok = (m) => console.log("  ✓ " + m);

function makeCtx() {
  return new Proxy({}, {
    get(t, p) {
      if (p in t) return t[p];
      return (...a) => {
        if (p === "createLinearGradient" || p === "createRadialGradient") return { addColorStop() {} };
        if (p === "measureText") return { width: 10 };
        return undefined;
      };
    },
    set(t, p, v) { t[p] = v; return true; },
  });
}
const makeEl = (id) => ({ id, textContent: "", style: {}, addEventListener() {},
  getContext: () => makeCtx(), width: 960, height: 540 });
class ImageStub {
  constructor() { this.width = 16; this.height = 16; this.naturalWidth = 16; this.naturalHeight = 16;
    this.onload = null; this.onerror = null; this._src = ""; }
  set src(v) { this._src = v; queueMicrotask(() => { if (this.onload) this.onload(); }); }
  get src() { return this._src; }
}
class AudioStub {
  constructor() { this.preload = ""; this.volume = 1; this.loop = false; this.currentTime = 0; }
  play() { return Promise.resolve(); } pause() {} cloneNode() { return new AudioStub(); } addEventListener() {}
}

// Boot a fresh sandbox with the real script evaluated. Returns the live context +
// its event-handler registry. Resolves after Image onloads → loadAll → first build.
async function boot(search = "") {
  const handlers = {};
  const sandbox = {
    console, Math, Date, JSON, isNaN, parseInt, parseFloat, setTimeout, clearTimeout, queueMicrotask,
    URLSearchParams, Image: ImageStub, Audio: AudioStub,
    requestAnimationFrame: () => 0, cancelAnimationFrame: () => {},
    addEventListener: (t, h) => { (handlers[t] = handlers[t] || []).push(h); },
    removeEventListener: () => {},
    fetch: () => Promise.reject(new Error("offline (harness)")), // leaderboard must degrade gracefully
    localStorage: (() => { const m = new Map();
      return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)),
               removeItem: (k) => m.delete(k) }; })(),
    location: { search }, prompt: () => "ABC", alert: () => {},
  };
  sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox;
  const els = {};
  sandbox.document = { getElementById: (id) => (els[id] = els[id] || makeEl(id)),
    addEventListener: (t, h) => { (handlers[t] = handlers[t] || []).push(h); },
    createElement: (tag) => makeEl(tag) };
  const ctx = vm.createContext(sandbox);
  vm.runInContext(script, ctx, { filename: "docs/index.html#script", timeout: 5000 });
  await new Promise((r) => setTimeout(r, 50));
  return { ctx, handlers };
}

// ---- 1. Structural validation across levels ---------------------------------
console.log("[genLevel structure]");
{
  const { ctx } = await boot();
  let anyMoving = false, firstMoving = null;
  for (let n = 2; n <= 16; n++) {
    let def;
    try { def = ctx.genLevel(n); } catch (e) { fail(`genLevel(${n}) threw: ${e.message}`); continue; }
    const grounds = def.platforms.filter((p) => p[3] === 3).map((p) => ({ c: p[0], w: p[2] }))
      .sort((a, b) => a.c - b.c);
    for (let i = 1; i < grounds.length; i++) {
      const gap = grounds[i].c - (grounds[i - 1].c + grounds[i - 1].w);
      if (gap > 5) fail(`L${n}: ground gap ${gap} > 5 tiles (unjumpable)`);
    }
    for (const p of def.platforms) if (p[3] === 1 && p[1] < 6) fail(`L${n}: floating ledge row ${p[1]} < 6`);
    for (const p of def.platforms) { const mv = p[4]; if (mv) { anyMoving = true; firstMoving ??= n;
      if (!["h", "v"].includes(mv.axis)) fail(`L${n}: bad moving axis ${mv.axis}`);
      if (!(mv.range > 0) || !(mv.speed > 0)) fail(`L${n}: bad moving range/speed`); } }
    if (n >= 4 && !def.platforms.some((p) => p[4])) fail(`L${n}: expected ≥1 moving platform`);
  }
  anyMoving ? ok(`moving platforms present (first at level ${firstMoving})`) : fail("no moving platforms generated");
}

// ---- 2. Drive the live loop at selected levels ------------------------------
async function driveLevel(level, frames) {
  const { ctx, handlers } = await boot(level > 1 ? `?level=${level}` : "");
  try { ctx.advance(); } catch (e) { return fail(`level ${level}: advance() threw: ${e.message}`); }
  const press = (code) => (handlers.keydown || []).forEach((h) => h({ code, preventDefault() {} }));
  const release = (code) => (handlers.keyup || []).forEach((h) => h({ code, preventDefault() {} }));
  press("ArrowRight");
  let ts = 0;
  for (let f = 0; f < frames; f++) {
    ts += 16.7;
    if (f % 50 === 20) press("Space");
    if (f % 50 === 26) release("Space");
    try { ctx.frame(ts); } catch (e) { return fail(`level ${level}: frame ${f} threw: ${e.message}\n${e.stack}`); }
  }
  release("ArrowRight");
  ok(`level ${level}: ${frames} frames ran clean`);
}

console.log("\n[live loop]");
const argLevel = parseInt(process.argv[2]);
if (argLevel) {
  await driveLevel(argLevel, parseInt(process.argv[3]) || 400);
} else {
  await driveLevel(1, 200);   // hand-authored
  await driveLevel(6, 400);   // moving platforms present
  await driveLevel(5, 600);   // boss milestone
  await driveLevel(10, 600);  // second boss milestone
}

console.log(`\n${failures === 0 ? "PASS ✅" : "FAIL ❌ (" + failures + " failure(s))"}`);
process.exit(failures === 0 ? 0 : 1);
