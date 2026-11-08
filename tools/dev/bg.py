"""Background runs that never get in the owner's way.

Everything here runs from a copy of the project (so a run never reads half-edited
scripts, and an `override.cfg` that only background runs see), with its own user
folder (never the real save), at below-normal priority, with no sound. Rendered runs
start minimized and are moved off every screen and out of the taskbar before they
draw, so they never show up or take focus; they still render, and captures work.

    python tools/dev/bg.py test                         # headless unit tests
    python tools/dev/bg.py run NAME [--res WxH] [--timeout S] -- <game args>
    python tools/dev/bg.py e2e N SCENARIO [NETSIM ...]  # DEVNET, XARGS, LIMIT as for e2e.sh
    python tools/dev/bg.py batch FILE                   # co-op runs one after another (see cmd_batch)
    python tools/dev/bg.py perf [--secs S]              # frame times, 3440x1440 and 1920x1080
    python tools/dev/bg.py focuscheck                   # proof: a rendered run never had focus
    python tools/dev/bg.py clean                        # stop only processes this tool started (batches too)
    python tools/dev/bg.py sync                         # refresh the copy (every command does it)

BG_COPY=<name> in the environment uses its own frozen copy of the project, so a long bench
keeps running the code it started with while the work goes on. Only one co-op run at a time
holds the network port: a second waits for the first (BG_WAIT seconds, default 900).

Logs: captures/bg/<name>.log. Captures are copied back to captures/. Windows only for
rendered runs (on Linux use xvfb-run, see docs/DEVELOPMENT_HANDOFF.md).
"""
import ctypes
import json
import os
import shlex
import shutil
import subprocess
import sys
import threading
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.environ.get("GODOT", r"C:/Users/Skrra/Desktop/Godot_v4.7.2-stable_win64.exe")
if GODOT.startswith("/c/"):
    GODOT = "C:/" + GODOT[3:]
BASE = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "KindledDeepBG")
SNAP = os.path.join(BASE, "project" + ("_" + os.environ["BG_COPY"] if os.environ.get("BG_COPY") else ""))
E2E_LOCK = os.path.join(BASE, "e2e.lock")
STATE = os.path.join(BASE, "pids.json")
LOGS = os.path.join(ROOT, "captures", "bg")
USER_DIR = "KindledDeepBackgroundTests"
COPY = ["addons", "assets", "src", "tests", "tools", "project.godot", "export_presets.cfg", "icon.svg", "icon.svg.import"]
OVERRIDE = """[display]

window/size/mode=1
window/size/no_focus=true

[application]

config/use_custom_user_dir=true
config/custom_user_dir_name="%s"
""" % USER_DIR
BELOW_NORMAL = 0x00004000
NO_WINDOW = 0x08000000
WIN = os.name == "nt"


# --- the copy ----------------------------------------------------------------------

def _copy_tree(src, dst):
    """Copies what changed (size or time); removes what is gone (never the copy's own
    import cache)."""
    n = 0
    if os.path.isfile(src):
        if not os.path.exists(dst) or os.path.getmtime(src) > os.path.getmtime(dst) + 0.5 or os.path.getsize(src) != os.path.getsize(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            return 1
        return 0
    os.makedirs(dst, exist_ok=True)
    have = set(os.listdir(dst))
    for name in os.listdir(src):
        have.discard(name)
        n += _copy_tree(os.path.join(src, name), os.path.join(dst, name))
    for gone in have:
        if gone == ".godot" or gone.endswith(".import") or gone.endswith(".uid"):
            continue     # (made by the copy's own import)
        p = os.path.join(dst, gone)
        shutil.rmtree(p, ignore_errors=True) if os.path.isdir(p) else os.remove(p)
    return n


def sync(quiet=False):
    """The copy: sources and assets refreshed; its own import cache, brought up to date by
    a headless import whenever anything changed (new classes, new art), never the repo's
    .godot (which the owner's editor may be writing)."""
    os.makedirs(SNAP, exist_ok=True)
    first = not os.path.isdir(os.path.join(SNAP, ".godot"))
    if first and os.path.isdir(os.path.join(ROOT, ".godot")):
        _copy_tree(os.path.join(ROOT, ".godot"), os.path.join(SNAP, ".godot"))
    changed = 0
    for item in COPY:
        src = os.path.join(ROOT, item)
        if os.path.exists(src):
            changed += _copy_tree(src, os.path.join(SNAP, item))
    with open(os.path.join(SNAP, "override.cfg"), "w", encoding="utf-8") as f:
        f.write(OVERRIDE)
    os.makedirs(LOGS, exist_ok=True)
    if changed or first:
        log = os.path.join(LOGS, "import.log")
        p = launch("import", ["--headless", "--import"], log, False)
        finish(p, 600)
    if not quiet:
        print("[bg] copy up to date (%d files changed) at %s" % (changed, SNAP))
    return changed


def user_dir():
    return os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), USER_DIR)


# --- processes ---------------------------------------------------------------------

def _record(pid, name):
    data = _load()
    data[str(pid)] = {"name": name, "started": time.time()}
    with open(STATE, "w") as f:
        json.dump(data, f)


def _forget(pid):
    data = _load()
    data.pop(str(pid), None)
    with open(STATE, "w") as f:
        json.dump(data, f)


def _load():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def launch(name, args, log_path, rendered):
    """Starts Godot on the copy, quietly. Returns the Popen."""
    cmd = [GODOT, "--path", SNAP, "--audio-driver", "Dummy"] + args
    log = open(log_path, "w", encoding="utf-8", errors="replace")
    kw = {}
    if WIN:
        si = subprocess.STARTUPINFO()
        si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        si.wShowWindow = 7  # SW_SHOWMINNOACTIVE: never shown on screen, never active
        kw = {"startupinfo": si, "creationflags": NO_WINDOW | BELOW_NORMAL}
    p = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, cwd=SNAP, **kw)
    _record(p.pid, name)
    if rendered and WIN:
        threading.Thread(target=_keep_away, args=(p,), daemon=True).start()
    return p


def finish(p, timeout):
    try:
        p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
    _forget(p.pid)
    return p.returncode


# --- keeping a window out of the way (Windows) ----------------------------------------

if WIN:
    import ctypes.wintypes as wt
    user32 = ctypes.windll.user32
    user32.GetWindowLongPtrW.restype = ctypes.c_ssize_t
    user32.SetWindowLongPtrW.argtypes = [wt.HWND, ctypes.c_int, ctypes.c_ssize_t]

    class WINDOWPLACEMENT(ctypes.Structure):
        _fields_ = [("length", wt.UINT), ("flags", wt.UINT), ("showCmd", wt.UINT), ("ptMinPosition", wt.POINT),
                    ("ptMaxPosition", wt.POINT), ("rcNormalPosition", wt.RECT)]

    def _windows_of(pid):
        out = []

        @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
        def cb(h, _):
            owner = wt.DWORD()
            user32.GetWindowThreadProcessId(h, ctypes.byref(owner))
            if owner.value == pid and not user32.GetWindow(h, 4):  # GW_OWNER: top-level only
                out.append(h)
            return True
        user32.EnumWindows(cb, 0)
        return out

    def _hide_away(h):
        """Off every screen, off the taskbar, restored so it still draws, never active."""
        r = wt.RECT()
        wp = WINDOWPLACEMENT()
        wp.length = ctypes.sizeof(WINDOWPLACEMENT)
        user32.GetWindowPlacement(h, ctypes.byref(wp))
        n = wp.rcNormalPosition
        w, ht = max(320, n.right - n.left), max(180, n.bottom - n.top)
        user32.ShowWindow(h, 0)  # SW_HIDE while the style changes
        ex = user32.GetWindowLongPtrW(h, -20)
        user32.SetWindowLongPtrW(h, -20, (ex | 0x00000080 | 0x08000000 | 0x00000020) & ~0x00040000)  # tool, no-activate, click-through
        wp.rcNormalPosition = wt.RECT(-20000, -20000, -20000 + w, -20000 + ht)
        wp.showCmd = 4  # SW_SHOWNOACTIVATE
        user32.SetWindowPlacement(h, ctypes.byref(wp))
        del r

    def _keep_away(p):
        done = set()
        t0 = time.time()
        while p.poll() is None and time.time() - t0 < 3600:
            for h in _windows_of(p.pid):
                if h not in done:
                    _hide_away(h)
                    done.add(h)
            time.sleep(0.002 if not done else 0.25)

    def foreground_pid():
        h = user32.GetForegroundWindow()
        pid = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(pid))
        return pid.value

    def window_rects(pid):
        out = []
        for h in _windows_of(pid):
            r = wt.RECT()
            user32.GetWindowRect(h, ctypes.byref(r))
            out.append((bool(user32.IsWindowVisible(h)), bool(user32.IsIconic(h)), (r.left, r.top, r.right, r.bottom)))
        return out


# --- commands -----------------------------------------------------------------------

def cmd_test(_args):
    sync()
    log = os.path.join(LOGS, "tests.log")
    p = launch("tests", ["--headless", "res://tests/test_runner.tscn"], log, False)
    code = finish(p, 900)
    text = open(log, encoding="utf-8", errors="replace").read()
    lines = [ln for ln in text.splitlines() if "tests," in ln or ln.startswith("FAILURE") or "SCRIPT ERROR" in ln or "does not compile" in ln]
    for ln in sorted(set(lines))[:40]:
        print(ln)
    errors = text.count("SCRIPT ERROR")
    print("[bg] tests: exit %s, %d script errors, log %s" % (code, errors, log))
    return 1 if code != 0 or errors else 0


def _copy_captures():
    src = os.path.join(SNAP, "captures")
    if os.path.isdir(src):
        _copy_tree_add(src, os.path.join(ROOT, "captures"))


def _copy_tree_add(src, dst):
    os.makedirs(dst, exist_ok=True)
    for name in os.listdir(src):
        s, d = os.path.join(src, name), os.path.join(dst, name)
        if os.path.isdir(s):
            _copy_tree_add(s, d)
        elif not os.path.exists(d) or os.path.getmtime(s) > os.path.getmtime(d):
            shutil.copy2(s, d)


def cmd_run(args):
    if "--" not in args:
        print("usage: bg.py run NAME [--res WxH] [--timeout S] -- <game args>")
        return 2
    i = args.index("--")
    opts, game = args[:i], args[i + 1:]
    name = opts[0] if opts else "run"
    res = _opt(opts, "--res", "1920x1080")
    limit = float(_opt(opts, "--timeout", "120"))
    sync(quiet=True)
    log = os.path.join(LOGS, "%s.log" % name)
    p = launch(name, ["--resolution", res, "--"] + game + ["bg"], log, True)
    code = finish(p, limit)
    _copy_captures()
    text = open(log, encoding="utf-8", errors="replace").read()
    print("[bg] %s: exit %s, %d script errors, log %s" % (name, code, text.count("SCRIPT ERROR"), log))
    return code


def _opt(opts, key, default):
    return opts[opts.index(key) + 1] if key in opts and opts.index(key) + 1 < len(opts) else default


OUTFITS = ["emberwrought", "rimeguard", "gloamweave", "verdant"]


def _pid_alive(pid):
    if not WIN:
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False
    r = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"], capture_output=True, text=True)
    return ('"%d"' % pid) in r.stdout


def _take_e2e_lock():
    """One co-op run at a time: they all listen on the same port and share e2e_ profiles
    (two batches once ran over each other). A second run waits; a stale lock is taken over."""
    os.makedirs(BASE, exist_ok=True)
    deadline = time.time() + float(os.environ.get("BG_WAIT", "900"))
    told = False
    while True:
        try:
            fd = os.open(E2E_LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return True
        except FileExistsError:
            try:
                holder = int(open(E2E_LOCK).read().strip() or "0")
            except (OSError, ValueError):
                holder = 0
            if holder == os.getpid():
                return True
            if holder == 0 or not _pid_alive(holder):
                try:
                    os.remove(E2E_LOCK)
                except OSError:
                    pass
                continue
            if time.time() > deadline:
                print("[bg] another co-op run (pid %d) still holds the port; giving up" % holder)
                return False
            if not told:
                print("[bg] waiting for the co-op run in pid %d to finish" % holder)
                told = True
            time.sleep(2.0)


def _drop_e2e_lock():
    try:
        if int(open(E2E_LOCK).read().strip() or "0") == os.getpid():
            os.remove(E2E_LOCK)
    except (OSError, ValueError):
        pass


def cmd_e2e(args):
    if not _take_e2e_lock():
        return 3
    try:
        return _run_e2e(args)
    finally:
        _drop_e2e_lock()


def cmd_batch(args):
    """Co-op runs one after another, as one stoppable process. Each line of FILE:
        name | ENV=val ENV2=val | n scenario [netsim ...]
    Values may not hold a '|'; '#' starts a comment. Results: captures/bg/batch_<stem>/ (a
    summary and each run's logs and captures)."""
    stem = os.path.splitext(os.path.basename(args[0]))[0]
    out = os.path.join(LOGS, "batch_" + stem)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out, exist_ok=True)
    _record(os.getpid(), "batch " + stem)
    if not _take_e2e_lock():
        _forget(os.getpid())
        return 3
    summary = open(os.path.join(out, "summary.txt"), "w", encoding="utf-8")
    worst = 0
    try:
        for line in open(args[0], encoding="utf-8"):
            line = line.split("#")[0].strip()
            if not line:
                continue
            name, env_part, cmd_part = [x.strip() for x in line.split("|")]
            for k in ["DEVNET", "XARGS", "HXARGS", "GXARGS", "LIMIT", "RES"]:
                os.environ.pop(k, None)
            for pair in shlex.split(env_part):
                k, v = pair.split("=", 1)
                os.environ[k] = v
            log_path = os.path.join(out, name + ".out")
            real = sys.stdout
            with open(log_path, "w", encoding="utf-8") as f:
                sys.stdout = f
                try:
                    code = _run_e2e(shlex.split(cmd_part))
                finally:
                    sys.stdout = real
            shutil.rmtree(os.path.join(out, name), ignore_errors=True)
            shutil.copytree(os.path.join(LOGS, "e2e"), os.path.join(out, name))
            text = open(log_path, encoding="utf-8", errors="replace").read()
            picked = [ln for ln in text.splitlines() if "RESULT" in ln or "FAIL" in ln or "script errors" in ln]
            summary.write("=== %s: %s  (exit %d)\n%s\n" % (name, cmd_part, code, "\n".join(picked[:40])))
            summary.flush()
            worst = max(worst, code)
        summary.write("=== done\n")
    finally:
        summary.close()
        _drop_e2e_lock()
        _forget(os.getpid())
    print("[bg] batch finished, exit %d; %s" % (worst, os.path.join(out, "summary.txt")))
    return worst


def _run_e2e(args):
    n = int(args[0]) if args else 2
    scen = args[1] if len(args) > 1 else "journey"
    sims = args[2:]
    limit = float(os.environ.get("LIMIT", "300"))
    xargs = os.environ.get("XARGS", "").split()
    host_x = os.environ.get("HXARGS", "").split()      # (switches for the host alone)
    guest_x = os.environ.get("GXARGS", "").split()     # (switches for every guest alone)
    devnet = os.environ.get("DEVNET", "0") == "1"
    res = os.environ.get("RES", "960x540")
    sync(quiet=True)
    out = os.path.join(LOGS, "e2e")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out, exist_ok=True)
    ud = user_dir()
    if os.path.isdir(ud):
        for f in os.listdir(ud):
            if f.startswith("e2e_"):
                os.remove(os.path.join(ud, f))
    host_net = ["net=host", "coop=%d" % n] if devnet else []
    guest_net = ["net=join:127.0.0.1", "autoaccept"] if devnet else []
    procs = []
    procs.append(launch("e2e host", ["--resolution", res, "--", "scene=hub", "scenario=" + scen, "role=host", "guests=%d" % (n - 1),
                                     "name=Host", "profile=e2e_host.json", "seed=7", "wear=" + OUTFITS[0], "bg"] + host_net + xargs + host_x,
                        os.path.join(out, "host.log"), True))
    time.sleep(2.0)
    for k in range(1, n):
        sim = ["netsim=" + sims[k - 1]] if k - 1 < len(sims) and sims[k - 1] else []
        procs.append(launch("e2e guest%d" % k, ["--resolution", res, "--", "scene=hub", "scenario=" + scen, "role=guest",
                                                 "name=Guest%d" % k, "profile=e2e_guest%d.json" % k, "wear=" + OUTFITS[k % 4], "bg"]
                            + sim + guest_net + xargs + guest_x, os.path.join(out, "guest%d.log" % k), True))
        time.sleep(1.0)
    code = 0
    t_end = time.time() + limit
    for p in procs:
        if finish(p, max(1.0, t_end - time.time())) != 0:
            code = 1
    # the captures each machine saved (Net.dev_shot) come home
    src = os.path.join(SNAP, "captures", "e2e")
    if os.path.isdir(src):
        _copy_tree_add(src, out)
    results, fails, errors = [], [], 0
    for f in sorted(os.listdir(out)):
        if f.endswith(".log"):
            text = open(os.path.join(out, f), encoding="utf-8", errors="replace").read()
            results += [ln for ln in text.splitlines() if "[scenario] RESULT" in ln]
            fails += ["%s: %s" % (f, ln) for ln in text.splitlines() if "[scenario] FAIL" in ln]
            errors += text.count("SCRIPT ERROR")
    print("== %d %s %s %s" % (n, scen, " ".join(sims), " ".join(xargs)))
    for ln in results:
        print(ln)
    for ln in fails[:30]:
        print(ln)
    print("[bg] e2e: %d script errors, logs in %s" % (errors, out))
    logs = [os.path.join(out, f) for f in sorted(os.listdir(out)) if f.endswith(".log")]
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "dev", "e2e_compare.py")] + logs)
    return 1 if code or fails or errors else 0


def cmd_perf(args):
    secs = float(_opt(args, "--secs", "60"))
    sync(quiet=True)
    rows = []
    for res in ["3440x1440", "1920x1080"]:
        for region in ["throne", "ossuary"]:
            name = "perf_%s_%s" % (res, region)
            log = os.path.join(LOGS, name + ".log")
            p = launch(name, ["--resolution", res, "--", "scene=dungeon", "region=" + region, "depth=2", "seed=7", "autopilot", "godmode",
                              "kit=4", "profile=bg_perf.json", "stallog=20", "perflog", "set=vsync:0", "frames=%d" % int(secs * 140),
                              "quit", "bg"], log, True)
            finish(p, secs * 3 + 60)
            text = open(log, encoding="utf-8", errors="replace").read().splitlines()
            perf = [ln for ln in text if ln.startswith("[perf]")]
            stall = [ln for ln in text if ln.startswith("[stall]") and "frames," in ln]
            rows.append("%s %s: %s | %s" % (res, region, stall[-1] if stall else "-", perf[-1][:120] if perf else "-"))
            print(rows[-1])
    return 0


def cmd_focuscheck(_args):
    """Runs a rendered capture and samples the foreground window all the while."""
    if not WIN:
        print("[bg] focuscheck is for Windows")
        return 0
    sync(quiet=True)
    before = foreground_pid()
    log = os.path.join(LOGS, "focuscheck.log")
    p = launch("focuscheck", ["--resolution", "1280x720", "--", "scene=dungeon", "region=ossuary", "seed=3", "godmode",
                              "profile=bg_focus.json", "capture=bg_focuscheck", "frames=240", "quit", "bg"], log, True)
    samples = stolen = 0
    on_screen = []
    t0 = time.time()
    while p.poll() is None and time.time() - t0 < 120:
        samples += 1
        if foreground_pid() == p.pid:
            stolen += 1
        for vis, icon, r in window_rects(p.pid):
            if vis and not icon and r[2] > -10000 and r[3] > -10000 and (r[2] - r[0]) > 200:
                on_screen.append(r)
        time.sleep(0.01)
    finish(p, 5)
    _copy_captures()
    ok = os.path.exists(os.path.join(ROOT, "captures", "bg_focuscheck.png"))
    print("[bg] focuscheck: %d samples, Godot had the foreground in %d, on-screen window sightings %d, capture saved: %s, "
          "foreground before %d after %d" % (samples, stolen, len(on_screen), ok, before, foreground_pid()))
    return 0 if stolen == 0 and not on_screen and ok else 1


def cmd_clean(_args):
    data = _load()
    # (a batch first, or it would start the next run as the last one is stopped)
    for pid, info in sorted(data.items(), key=lambda kv: 0 if str(kv[1].get("name", "")).startswith("batch ") else 1):
        alive = False
        if WIN:
            r = subprocess.run(["tasklist", "/FI", "PID eq %s" % pid, "/FO", "CSV", "/NH"], capture_output=True, text=True)
            is_batch = str(info.get("name", "")).startswith("batch ")
            alive = ("python" in r.stdout.lower()) if is_batch else ("Godot" in r.stdout)
        if alive:
            subprocess.run(["taskkill", "/PID", pid, "/T", "/F"], capture_output=True)
            print("[bg] stopped %s (%s)" % (pid, info.get("name")))
        _forget(int(pid))
    if os.path.exists(E2E_LOCK):
        try:
            if not _pid_alive(int(open(E2E_LOCK).read().strip() or "0")):
                os.remove(E2E_LOCK)
        except (OSError, ValueError):
            pass
    print("[bg] nothing else is touched: only processes this tool started")
    return 0


def cmd_sync(_args):
    sync()
    return 0


if __name__ == "__main__":
    commands = {"test": cmd_test, "run": cmd_run, "e2e": cmd_e2e, "perf": cmd_perf, "focuscheck": cmd_focuscheck,
                "clean": cmd_clean, "sync": cmd_sync, "batch": cmd_batch}
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        print(__doc__)
        sys.exit(2)
    sys.exit(commands[sys.argv[1]](sys.argv[2:]))
