"""Measures sound files (standard library only - no numpy needed).

    python tools/audio/analyze.py assets/audio/sfx/urn*.wav
    python tools/audio/analyze.py --stems captures/audio/   (a folder of recorded bus stems)

Per file: length, peak and RMS (dBFS), the loudest 50 ms window, crest factor,
spectral centroid and the share of energy below 120 Hz / above 8 kHz (of the
loudest window), the time to fall 40 dB from the peak, and clipped samples.

These are measurements, not listening: they catch clipping, mud, harshness,
levels that do not match and tails that ring on, but whether a sound *works*
still needs a person's ears.
"""
import cmath
import math
import os
import struct
import sys
import wave


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        vals = struct.unpack("<%dh" % (len(raw) // 2), raw)
        scale = 32768.0
    elif sw == 4:
        vals = struct.unpack("<%di" % (len(raw) // 4), raw)
        scale = 2147483648.0
    elif sw == 1:
        vals = [b - 128 for b in raw]
        scale = 128.0
    else:
        raise ValueError("unsupported sample width %d" % sw)
    mono = []
    for i in range(0, len(vals), ch):
        mono.append(sum(vals[i:i + ch]) / (ch * scale))
    return mono, rate


def db(x):
    return 20.0 * math.log10(max(x, 1e-9))


def fft(x):
    n = len(x)
    if n <= 1:
        return x
    even = fft(x[0::2])
    odd = fft(x[1::2])
    out = [0j] * n
    for k in range(n // 2):
        t = cmath.exp(-2j * math.pi * k / n) * odd[k]
        out[k] = even[k] + t
        out[k + n // 2] = even[k] - t
    return out


def spectrum_stats(seg, rate):
    n = 1
    while n < len(seg):
        n *= 2
    n = min(n, 8192)
    seg = seg[:n] + [0.0] * (n - len(seg[:n]))
    win = [seg[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1))) for i in range(n)]
    sp = fft([complex(v, 0) for v in win])
    mags = [abs(c) ** 2 for c in sp[: n // 2]]
    total = sum(mags) or 1e-12
    freqs = [i * rate / n for i in range(n // 2)]
    centroid = sum(f * m for f, m in zip(freqs, mags)) / total
    low = sum(m for f, m in zip(freqs, mags) if f < 120.0) / total
    high = sum(m for f, m in zip(freqs, mags) if f > 8000.0) / total
    return centroid, low, high


def analyze(path):
    x, rate = read_wav(path)
    if not x:
        return None
    peak = max(abs(v) for v in x)
    rms = math.sqrt(sum(v * v for v in x) / len(x))
    win = max(1, int(rate * 0.05))
    best, best_i = 0.0, 0
    for i in range(0, max(1, len(x) - win), max(1, win // 4)):
        e = math.sqrt(sum(v * v for v in x[i:i + win]) / win)
        if e > best:
            best, best_i = e, i
    if len(x) / rate > 3.0:
        # a long track: average over windows spread through it (not just its loudest hit)
        cs, ls, hs = [], [], []
        step = max(1, len(x) // 24)
        for i in range(0, len(x) - 4096, step):
            c, l, h = spectrum_stats(x[i:i + 4096], rate)
            cs.append(c); ls.append(l); hs.append(h)
        centroid, low, high = sum(cs) / len(cs), sum(ls) / len(ls), sum(hs) / len(hs)
    else:
        centroid, low, high = spectrum_stats(x[best_i:best_i + 4096], rate)
    # time from the peak until the level stays 40 dB under it
    pk_i = max(range(len(x)), key=lambda i: abs(x[i]))
    thr = peak * 0.01
    t40 = None
    hop = max(1, int(rate * 0.005))
    for i in range(pk_i, len(x), hop):
        if max(abs(v) for v in x[i:i + hop]) < thr and all(abs(v) < thr for v in x[i:min(len(x), i + int(rate * 0.05))]):
            t40 = (i - pk_i) / rate
            break
    clipped = sum(1 for v in x if abs(v) >= 0.999)
    return {
        "len": len(x) / rate, "peak": db(peak), "rms": db(rms), "loud50": db(best), "crest": db(peak) - db(rms),
        "centroid": centroid, "low": low, "high": high, "t40": t40, "clip": clipped,
    }


def main(args):
    files = []
    for a in args:
        if os.path.isdir(a):
            files += sorted(os.path.join(a, f) for f in os.listdir(a) if f.lower().endswith(".wav"))
        else:
            files.append(a)
    print("%-28s %5s %6s %6s %7s %5s %7s %5s %5s %6s %4s" % ("file", "len", "peak", "rms", "loud50", "crest", "cent", "<120", ">8k", "t40", "clip"))
    for f in files:
        r = analyze(f)
        if r is None:
            continue
        print("%-28s %5.2f %6.1f %6.1f %7.1f %5.1f %7.0f %5.2f %5.2f %6s %4d" % (os.path.basename(f)[:28], r["len"], r["peak"], r["rms"], r["loud50"], r["crest"],
            r["centroid"], r["low"], r["high"], ("%.2f" % r["t40"]) if r["t40"] is not None else "-", r["clip"]))


if __name__ == "__main__":
    main([a for a in sys.argv[1:] if a != "--stems"])
