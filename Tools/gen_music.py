#!/usr/bin/env python3
"""Synthesize a short, seamless chiptune loop (music.wav) for Crystal Caper.
Pure standard library. Writes to docs/assets/ and Resources/."""
import wave, struct, math, os

SR = 22050
OUTS = [os.path.expanduser("~/dev/CrystalCaper/docs/assets/music.wav"),
        os.path.expanduser("~/dev/CrystalCaper/Resources/music.wav")]

def midi(n): return 440.0 * 2 ** ((n - 69) / 12.0)

def osc(freq, t, kind):
    p = (freq * t) % 1.0
    if kind == "square": return 1.0 if p < 0.5 else -1.0
    if kind == "tri":    return 4 * abs(p - 0.5) - 1
    return math.sin(2 * math.pi * freq * t)

def env(i, n, a=0.01, r=0.06):
    t, dur = i / SR, n / SR
    return max(0.0, min(1.0, t / a if a else 1, (dur - t) / r if r else 1))

def tone(note, beats, beat_s, vol, kind):
    n = int(SR * beats * beat_s)
    if note is None: return [0.0] * n
    f = midi(note)
    return [osc(f, i / SR, kind) * vol * env(i, n) for i in range(n)]

def line(events, beat_s, vol, kind):
    out = []
    for note, beats in events:
        out += tone(note, beats, beat_s, vol, kind)
    return out

BPM = 132
BEAT = 60.0 / BPM

# I–V–vi–IV in C. Bass roots (quarters) + an eighth-note arpeggio lead.
bass = [(48, 1), (48, 1), (48, 1), (48, 1),
        (43, 1), (43, 1), (43, 1), (43, 1),
        (45, 1), (45, 1), (45, 1), (45, 1),
        (41, 1), (41, 1), (41, 1), (41, 1)]
chords = [[72, 76, 79, 84], [67, 71, 74, 79], [69, 72, 76, 81], [65, 69, 72, 77]]
pattern = [0, 1, 2, 3, 2, 1, 2, 3]
lead = []
for ch in chords:
    for idx in pattern:
        lead.append((ch[idx], 0.5))

b = line(bass, BEAT, 0.22, "tri")
l = line(lead, BEAT, 0.16, "square")
n = max(len(b), len(l))
mix = [0.0] * n
for i in range(len(b)): mix[i] += b[i]
for i in range(len(l)): mix[i] += l[i]
# soft limiter
mix = [max(-1, min(1, s * 0.9)) for s in mix]

frames = b"".join(struct.pack("<h", int(s * 32767)) for s in mix)
for path in OUTS:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    w = wave.open(path, "w"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(frames); w.close()
    print("wrote", path, f"({len(mix)/SR:.1f}s)")
