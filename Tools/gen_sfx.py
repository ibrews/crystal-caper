#!/usr/bin/env python3
"""Synthesize tiny chiptune SFX (16-bit mono WAV) into Resources/.
No dependencies beyond the standard library."""
import wave, struct, math, os

SR = 44100
OUT = os.path.expanduser("~/dev/CrystalCaper/Resources")
os.makedirs(OUT, exist_ok=True)

def write_wav(name, samples):
    path = os.path.join(OUT, name)
    w = wave.open(path, "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    w.close()

def envelope(i, n, attack=0.005, release=0.05):
    t, dur = i / SR, n / SR
    a = min(1, t / attack) if attack > 0 else 1
    r = min(1, (dur - t) / release) if release > 0 else 1
    return max(0, min(a, r))

def osc(freq, t, kind):
    if kind == "square":
        return 1.0 if (freq * t) % 1 < 0.5 else -1.0
    if kind == "tri":
        p = (freq * t) % 1
        return 4 * abs(p - 0.5) - 1
    return math.sin(2 * math.pi * freq * t)

def tone(freq, dur, vol=0.45, kind="square", attack=0.005, release=0.05):
    n = int(SR * dur)
    return [osc(freq, i / SR, kind) * vol * envelope(i, n, attack, release) for i in range(n)]

def sweep(f0, f1, dur, vol=0.45, kind="square"):
    n = int(SR * dur); out = []
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        out.append(osc(f, t, kind) * vol * envelope(i, n, 0.004, 0.04))
    return out

def seq(*tracks):
    out = []
    for t in tracks:
        out += t
    return out

write_wav("sfx_jump.wav",  sweep(330, 760, 0.15, 0.40, "square"))
write_wav("sfx_gem.wav",   seq(tone(880, 0.05, 0.40, "tri"), tone(1320, 0.13, 0.40, "tri")))
write_wav("sfx_stomp.wav", sweep(240, 70, 0.16, 0.50, "square"))
write_wav("sfx_hurt.wav",  seq(tone(300, 0.07, 0.45, "square"), tone(190, 0.18, 0.40, "square")))
write_wav("sfx_win.wav",   seq(tone(523, 0.11, 0.40, "square"), tone(659, 0.11, 0.40, "square"),
                               tone(784, 0.11, 0.40, "square"), tone(1047, 0.30, 0.45, "square")))
print("wrote 5 sfx wavs to", OUT)
