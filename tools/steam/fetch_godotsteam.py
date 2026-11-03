"""Installs GodotSteam (GDExtension) into addons/godotsteam/ for Windows x86_64.

    python tools/steam/fetch_godotsteam.py [path/to/already-downloaded.zip]

The release is pinned (version and SHA-256) so every machine builds against the
same Steamworks library. Only what a Windows build needs is installed: the
extension manifest (trimmed to Windows x86_64), the debug and release libraries,
Valve's steam_api64.dll and the MIT licence. The editor "updater" plugin in the
zip is left out (it checks the internet for updates).

addons/godotsteam/ is gitignored: the game builds and runs without it (LAN and
direct IP only). See docs/STEAM.md.
"""
import hashlib
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile

VERSION = "4.23.2"
URL = "https://codeberg.org/godotsteam/godotsteam/releases/download/v4.23.2-gde/godotsteam-4.23.2-gdextension-plugin-4.4.zip"
SHA256 = "0c935ac86bdb881a71009a0352140a043812c438745979e1b246416a9282e414"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEST = os.path.join(ROOT, "addons", "godotsteam")
PREFIX = "godotsteam/addons/godotsteam/"
WANT = ["win64/libgodotsteam.windows.template_debug.x86_64.dll",
        "win64/libgodotsteam.windows.template_release.x86_64.dll",
        "win64/steam_api64.dll", "license.md", "readme.md"]
MANIFEST = """[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.4"

[libraries]
windows.debug.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"

[dependencies]
windows.x86_64 = { "res://addons/godotsteam/win64/steam_api64.dll": "" }
"""


def main():
    tmp = tempfile.mkdtemp(prefix="godotsteam_")
    try:
        if len(sys.argv) > 1:
            zpath = sys.argv[1]
        else:
            zpath = os.path.join(tmp, "godotsteam.zip")
            print("downloading", URL)
            urllib.request.urlretrieve(URL, zpath)
        h = hashlib.sha256(open(zpath, "rb").read()).hexdigest()
        if h != SHA256:
            print("SHA-256 mismatch: got %s, expected %s - not installing" % (h, SHA256))
            return 1
        print("verified GodotSteam %s (%s)" % (VERSION, h))
        with zipfile.ZipFile(zpath) as z:
            os.makedirs(os.path.join(DEST, "win64"), exist_ok=True)
            for rel in WANT:
                with z.open(PREFIX + rel) as src, open(os.path.join(DEST, rel), "wb") as out:
                    shutil.copyfileobj(src, out)
        with open(os.path.join(DEST, "godotsteam.gdextension"), "w", encoding="utf-8", newline="\n") as f:
            f.write(MANIFEST)
        print("installed into", DEST)
        print("now run Godot once with --import so the extension is registered")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
