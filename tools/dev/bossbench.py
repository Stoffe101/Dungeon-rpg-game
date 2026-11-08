"""Guardian fights to the end, by real rules: no god mode, real builds, bots of three
skill levels that read the warnings on the floor with a reaction delay and miss some.
Headless and hidden (tools/dev/bg.py's copy and user folder), several at a time at most
two, at below-normal priority. Prints one line a fight and a table at the end.

    python tools/dev/bossbench.py [--seeds 3] [--builds cadence,vanguard,...] [--skills fair,sharp]
                                  [--regions ossuary,rootmire,throne] [--forms none,form] [--tier 1] [--kit N]

It measures whether a fight can be won and what kills people; it is not a verdict on
difficulty for humans (bots are not people)."""
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import bg  # noqa: E402

FORMS = {"ossuary": "lightless", "rootmire": "rootbound", "throne": "eclipsed"}


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    seeds = int(arg("--seeds", "3"))
    builds = arg("--builds", "cadence,vanguard,backstab,hail,lanternedge").split(",")
    skills = arg("--skills", "fair,sharp").split(",")
    regions = arg("--regions", "ossuary,rootmire,throne").split(",")
    forms = arg("--forms", "none,form").split(",")
    tier = arg("--tier", "1")
    kit = arg("--kit", "")
    bg.sync(quiet=True)
    jobs = []
    for region in regions:
        for form in forms:
            for build in builds:
                for skill in skills:
                    for s in range(seeds):
                        jobs.append((region, form, build, skill, 11 + s * 7))
    rows = []
    running = []
    out_dir = os.path.join(bg.LOGS, "bossbench")
    os.makedirs(out_dir, exist_ok=True)

    def start(job):
        region, form, build, skill, seed = job
        f = FORMS[region] if form == "form" else "none"
        name = "%s_%s_%s_%s_%d" % (region, form, build, skill, seed)
        log = os.path.join(out_dir, name + ".log")
        p = bg.launch("bossbench " + name, ["--headless", "--fixed-fps", "30", "--", "scene=dungeon", "depth=3", "region=" + region,
                                            "seed=%d" % seed, "warp=boss", "autopilot", "botskill=" + skill, "build=" + build, "tier=" + tier,
                                            "form=" + f, "bossquit"] + (["kit=" + kit] if kit else []) + [ "profile=bb_%s.json" % name[:40], "frames=60000", "quit", "bg"], log, False)
        return (p, job, log, time.time())

    while jobs or running:
        while jobs and len(running) < 2:
            running.append(start(jobs.pop(0)))
        time.sleep(0.5)
        for r in list(running):
            p, job, log, t0 = r
            if p.poll() is None and time.time() - t0 < 600:
                continue
            bg.finish(p, 1)
            running.remove(r)
            text = open(log, encoding="utf-8", errors="replace").read()
            won = re.search(r"guardian felled: (.*?), ([0-9.]+) left of the Kindled, ([0-9]+) s", text)
            lost = re.search(r"the Kindled fell after ([0-9]+) s on this floor, the guardian at (-?[0-9]+)%; last blows: (.*)", text)
            errs = text.count("SCRIPT ERROR")
            if won:
                res = ("won", int(won.group(3)), "%d%% health left" % round(float(won.group(2)) * 100), "")
            elif lost:
                res = ("died", int(lost.group(1)), "guardian at %s%%" % lost.group(2), lost.group(3).strip())
            else:
                res = ("unfinished", -1, "", "")
            rows.append((job, res, errs))
            print("[bench] %-9s %-5s %-12s %-6s seed %-3d %-10s %4s s  %-18s %s%s" % (job[0], job[1], job[2], job[3], job[4], res[0], res[1], res[2], res[3][:70],
                                                                                       ("  SCRIPT ERRORS %d" % errs) if errs else ""))
            sys.stdout.flush()
    print()
    print("| region | form | build | skill | won | died | unfinished | median time to win |")
    print("|---|---|---|---|---|---|---|---|")
    keys = sorted({(r[0][0], r[0][1], r[0][2], r[0][3]) for r in rows})
    for k in keys:
        rs = [r for r in rows if (r[0][0], r[0][1], r[0][2], r[0][3]) == k]
        won = [r[1][1] for r in rs if r[1][0] == "won"]
        died = sum(1 for r in rs if r[1][0] == "died")
        unf = sum(1 for r in rs if r[1][0] == "unfinished")
        med = sorted(won)[len(won) // 2] if won else "-"
        print("| %s | %s | %s | %s | %d | %d | %d | %s |" % (k[0], k[1], k[2], k[3], len(won), died, unf, med))


if __name__ == "__main__":
    main()
