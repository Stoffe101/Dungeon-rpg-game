"""Compare the XP ledgers of two (or more) Kindled who played the same run.

Each machine writes user://ledger/<run id>_<name>.jsonl (src/net/ledger.gd): where its
Kindled started, every change to its experience (source and amount), what the
host awarded the party, each floor and the settlement. Copy each player's file
(Windows: %APPDATA%/Godot/app_userdata/Kindled Deep/ledger/) and run:

    python tools/dev/ledger_compare.py host.jsonl guest.jsonl

It prints, per file, the start, the gains by source, the end, and then the
first place their gains part ways - so a gap is explained by where it began,
not by guessing at levels.
"""
import json
import sys
from collections import OrderedDict


def load(path):
    lines = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                try:
                    lines.append(json.loads(ln))
                except json.JSONDecodeError:
                    pass
    return lines


def summary(lines):
    start = next((l for l in lines if l.get("ev") == "start"), {})
    end = next((l for l in reversed(lines) if l.get("ev") == "end"), {})
    by_src = OrderedDict()
    by_depth = OrderedDict()
    for l in lines:
        if l.get("ev") == "xp":
            by_src[l.get("src", "?")] = by_src.get(l.get("src", "?"), 0) + int(l.get("n", 0))
            d = l.get("depth", 0)
            by_depth[d] = by_depth.get(d, 0) + int(l.get("n", 0))
    awards = [l for l in lines if l.get("ev") == "award"]
    return start, end, by_src, by_depth, awards


def main(paths):
    if not paths:
        print(__doc__)
        return 1
    sums = []
    for p in paths:
        lines = load(p)
        start, end, by_src, by_depth, awards = summary(lines)
        sums.append((p, start, end, by_src, by_depth))
        print("== %s" % p)
        print("  start: level %s, total XP %s, xp_gain x%s" % (start.get("level", "?"), start.get("total", "?"), start.get("xp_gain", "?")))
        for s, n in by_src.items():
            print("  %-12s %6d" % (s, n))
        gained = sum(by_src.values())
        print("  gained       %6d" % gained)
        if end:
            print("  end:   level %s, total XP %s (%s)" % (end.get("level", "?"), end.get("total", "?"), end.get("outcome", "?")))
            if "total" in start and "total" in end:
                print("  total changed by %d" % (int(end["total"]) - int(start["total"])))
        if awards:
            kinds = {}
            for a in awards:
                k = (a.get("kind"), a.get("src"))
                kinds[k] = kinds.get(k, 0) + int(a.get("n", 0))
            print("  awarded to the party (host's view): %s" % ", ".join("%s/%s %d" % (k[0], k[1], n) for k, n in kinds.items()))
            short = [a for a in awards if len(a.get("to", [])) < max(len(b.get("to", [])) for b in awards)]
            if short:
                print("  !! %d awards reached fewer Kindled than others (first: %s)" % (len(short), json.dumps(short[0])))
    if len(sums) >= 2:
        a, b = sums[0], sums[1]
        print("== where %s and %s differ" % (a[0], b[0]))
        # (a guest's experience arrives as "live" - the host's awards as they
        # came - so sources are named differently on each side; depths and
        # totals are compared)
        same = sum(a[3].values()) == sum(b[3].values())
        print("  gained in all: %d vs %d" % (sum(a[3].values()), sum(b[3].values())))
        for d in sorted(set(a[4]) | set(b[4]), key=lambda x: int(x)):
            if a[4].get(d, 0) != b[4].get(d, 0):
                same = False
                print("  depth %-3s %6d vs %6d   <- they part ways here" % (d, a[4].get(d, 0), b[4].get(d, 0)))
        if same:
            print("  their gains match floor by floor")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
