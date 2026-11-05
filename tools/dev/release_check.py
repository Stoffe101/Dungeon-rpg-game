"""Checks that a build about to be exported carries nothing meant only for development.

    python tools/dev/release_check.py [export_dir]

Fails (exit 1) when:
- the Windows export preset would pack the licensed sound pack (assets/audio/licensed,
  not redistributable) or a steam_appid.txt;
- the project's Steam App ID is Valve's Spacewar test app (480);
- the export folder holds a steam_appid.txt (a development-only file);
- the testing stockpile or the dev arguments are not gated to debug builds.
Prints what it checked. It does not prove a build is ready to ship (see docs/STEAM.md).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
problems = []
notes = []


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


preset = read("export_presets.cfg")
excl = re.search(r'^exclude_filter="([^"]*)"', preset, re.M)
excl = excl.group(1) if excl else ""
for must in ["assets/audio/licensed/*", "steam_appid.txt", "tests/*", "tools/*", "captures/*"]:
    if must not in excl:
        problems.append("export preset does not exclude %s" % must)
notes.append("export preset excludes: %s" % excl)

proj = read("project.godot")
m = re.search(r"^kindled/steam/app_id\s*=\s*(\d+)", proj, re.M)
app_id = int(m.group(1)) if m else 0
if app_id == 480:
    problems.append("project.godot sets kindled/steam/app_id=480 (Spacewar) - never ship as Spacewar")
notes.append("Steam App ID in project settings: %s" % (app_id if app_id else "none (Steam play off in release)"))

export_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "builds", "windows")
if os.path.isfile(os.path.join(export_dir, "steam_appid.txt")):
    problems.append("%s holds steam_appid.txt (development only)" % export_dir)

profile = read("src/autoload/profile.gd")
if 'return TEST_STOCKPILE and Dev.enabled() and OS.has_feature("editor")' not in profile:
    problems.append("the testing stockpile is not gated to debug builds (Profile.stockpile)")
dev = read("src/core/dev.gd")
if "OS.is_debug_build()" not in dev:
    problems.append("dev arguments are not gated to debug builds (Dev.enabled)")
for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
    for f in files:
        if f.endswith(".gd") and f != "dev.gd":
            if "get_cmdline_user_args" in open(os.path.join(dirpath, f), encoding="utf-8").read():
                problems.append("%s reads dev arguments directly (use Dev.args())" % f)
# exports leave tools/, tests/, docs/ and captures/ out: the game must not need them
for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
    for f in files:
        if f.endswith((".gd", ".tscn", ".tres")):
            text = open(os.path.join(dirpath, f), encoding="utf-8").read()
            for d in ("res://tools/", "res://tests/", "res://docs/", "res://captures/"):
                if d in text:
                    problems.append("%s uses %s (left out of exports)" % (f, d))
steam = read("src/net/steam_link.gd")
if "if id == SPACEWAR and not Dev.enabled()" not in steam:
    problems.append("SteamLink no longer refuses Spacewar in release builds")

for n in notes:
    print("  ", n)
if problems:
    print("RELEASE CHECK FAILED:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("release check passed")
