"""Compares what each game process drew of the other Kindled with where those
Kindled really were (their owners' own [probe] lines), from tools/dev/e2e.sh logs.

    python tools/dev/e2e_compare.py captures/e2e/host.log captures/e2e/guest1.log ...

For every pair (viewer, other) and every stretch of the run (sanctuary, each
floor), prints how far behind/off the drawn Kindled was (median, 95th
percentile, in tiles) and any FROZEN stretch: the other walked more than two
tiles on their own screen while the viewer's picture of them barely moved.
Owners' positions are shifted by the expected draw delay before comparing.
"""
import json
import sys

DELAY_MS = 120      # others are drawn about this far in the past


def load(path):
    rows = []
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("[probe] "):
            try:
                rows.append(json.loads(line[8:]))
            except ValueError:
                pass
    return rows


def at(series, t):
    """The owner's own position at wall time t (linear between probes of the
    same scene: never blended across a change of floor)."""
    prev = None
    for r in series:
        if r["t"] >= t:
            if prev is None or prev["stage"] != r["stage"] or prev.get("fl", 0) != r.get("fl", 0):
                return r["me"], r
            k = (t - prev["t"]) / max(1, r["t"] - prev["t"])
            return [prev["me"][0] + (r["me"][0] - prev["me"][0]) * k, prev["me"][1] + (r["me"][1] - prev["me"][1]) * k], r
        prev = r
    return None, None


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(len(xs) * p))] if xs else 0.0


def main(paths):
    runs = {}
    for p in paths:
        rows = load(p)
        if rows:
            runs[rows[0]["who"]] = rows
    names = {who: who for who in runs}
    bad = 0
    for viewer, rows in runs.items():
        for other in runs:
            if other == viewer:
                continue
            label = other.capitalize() if other.startswith("guest") or other == "host" else other
            stretches = {}
            for r in rows:
                seen = None
                for k, v in r["others"].items():
                    if k.lower() == other:
                        seen = v
                if seen is None:
                    continue
                own, orow = at(runs[other], r["t"] - DELAY_MS)
                if own is None or orow["stage"] != r["stage"] or orow.get("fl", 0) != r.get("fl", 0):
                    continue
                key = "%s fl %s" % (r["stage"], r.get("fl", 0))
                err = ((seen[0] - own[0]) ** 2 + (seen[1] - own[1]) ** 2) ** 0.5
                stretches.setdefault(key, []).append((r["t"], err, seen, own))
            for key, pts in stretches.items():
                errs = [e for _, e, _, _ in pts]
                frozen = []
                # 2 s windows: the owner moved > 2 tiles, the picture < 0.2
                for i in range(len(pts)):
                    j = i
                    while j < len(pts) and pts[j][0] - pts[i][0] < 2000:
                        j += 1
                    if j >= len(pts):
                        break
                    own_moved = ((pts[j][3][0] - pts[i][3][0]) ** 2 + (pts[j][3][1] - pts[i][3][1]) ** 2) ** 0.5
                    seen_moved = ((pts[j][2][0] - pts[i][2][0]) ** 2 + (pts[j][2][1] - pts[i][2][1]) ** 2) ** 0.5
                    # a jump (drawn in by a sealing room, a teleport) is seen at once by
                    # the host and a moment later by its owner: not a frozen picture
                    jumped = any(((pts[k + 1][3][0] - pts[k][3][0]) ** 2 + (pts[k + 1][3][1] - pts[k][3][1]) ** 2) ** 0.5 > 3.0
                                 or ((pts[k + 1][2][0] - pts[k][2][0]) ** 2 + (pts[k + 1][2][1] - pts[k][2][1]) ** 2) ** 0.5 > 3.0
                                 for k in range(i, min(j + 3, len(pts) - 1)))   # (a slow link sees it later)
                    # frozen: the owner walked on, the picture stayed, and they ended apart
                    apart = ((pts[j][3][0] - pts[j][2][0]) ** 2 + (pts[j][3][1] - pts[j][2][1]) ** 2) ** 0.5 > 1.0
                    if own_moved > 2.0 and seen_moved < 0.2 and apart and not jumped:
                        frozen.append(pts[i][0])
                flag = ""
                if frozen:
                    flag = "  FROZEN for %d windows" % len(frozen)
                    bad += 1
                print("%-7s sees %-7s %-14s %4d samples  off by p50 %.2f  p95 %.2f tiles%s" % (
                    viewer, other, key, len(pts), pct(errs, 0.5), pct(errs, 0.95), flag))
    if bad:
        print("FROZEN pictures found: %d" % bad)
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
