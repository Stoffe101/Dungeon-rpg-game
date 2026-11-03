"""Prints the netsim matrix (captures/net/<preset>.json from NetDiag) as a markdown table.

    python tools/dev/netsim_table.py captures/net local excellent typical ...
"""
import json
import os
import sys

out = sys.argv[1]
presets = sys.argv[2:] or ["local", "excellent", "typical", "moderate", "difficult", "stress"]
print("| Condition (sim) | RTT measured | Drawn behind | Snapshot loss | Down KB/s | Up KB/s "
      "| Pred. error p50 / p95 (tiles) | avg untouched | Slides/s | Jumps/s |")
print("|---|---|---|---|---|---|---|---|---|---|")
for p in presets:
    path = os.path.join(out, p + ".json")
    if not os.path.exists(path):
        print("| %s | (no log) |||||||" % p)
        continue
    d = json.load(open(path, encoding="utf-8"))
    a = d["avg"]
    sim = d.get("netsim", [0, 0, 0])
    print("| %s (%d ms, %.1f%%) | %d ms | %d ms | %.1f%% | %.1f | %.1f | %.3f / %.3f | %.3f | %.1f | %.2f |" % (
        p, round(sim[0] * 1000), sim[1] * 100, round(a["rtt"] * 1000), round(a["delay"]), a["loss"] * 100,
        a["in_kbs"], a["out_kbs"], a.get("err_p50", 0.0), a.get("err_p95", 0.0), a.get("err_free", 0.0), a["fixes"], a["jumps"]))
