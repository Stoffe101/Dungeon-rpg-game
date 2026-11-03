#!/usr/bin/env bash
# Windows build: release check, export with the "Windows Desktop" preset, then
# check what came out.
#
#   GODOT=/path/to/godot tools/dev/build_windows.sh [release|debug]
#
# release -> builds/windows-release/, debug -> builds/windows-debug/ (gitignored).
# Needs Godot's 4.7.2 export templates (Editor > Manage Export Templates).
# A debug build keeps dev arguments and the testing stockpile (for testers);
# a release build drops them. With GodotSteam installed (tools/steam/
# fetch_godotsteam.py) its library and Valve's steam_api64.dll go beside the
# executable; a Steam release also needs the game's own App ID (docs/STEAM.md) -
# never Spacewar (480).
set -eu
cd "$(dirname "$0")/../.."
: "${GODOT:?set GODOT to the Godot 4.7 executable}"
MODE=${1:-release}
TEMPLATES="${APPDATA:-$HOME/AppData/Roaming}/Godot/export_templates/4.7.2.stable"
if [ ! -f "$TEMPLATES/windows_${MODE}_x86_64.exe" ]; then
	echo "No $MODE export template for 4.7.2 in $TEMPLATES."
	echo "Install them from the editor (Editor > Manage Export Templates) and run this again."
	exit 2
fi
OUT="builds/windows-$MODE"
python tools/dev/release_check.py "$OUT"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . "--export-$MODE" "Windows Desktop" "$OUT/KindledDeep.exe"
echo "== $OUT"
ls -la "$OUT"
FAIL=0
if [ -d addons/godotsteam ]; then
	for f in "libgodotsteam.windows.template_${MODE}.x86_64.dll" steam_api64.dll; do
		if [ ! -f "$OUT/$f" ]; then
			echo "MISSING beside the executable: $f"
			FAIL=1
		fi
	done
fi
if [ -f "$OUT/steam_appid.txt" ]; then
	echo "steam_appid.txt must not ship"
	FAIL=1
fi
# the embedded pack lists every packed file by path: none of the licensed sounds may be there
if grep -a -q -E "audio/licensed/[A-Za-z0-9_]+.(wav|ogg)" "$OUT/KindledDeep.exe"; then
	echo "licensed sounds were packed into the build"
	FAIL=1
fi
[ "$FAIL" = "0" ] && echo "build check passed" || { echo "BUILD CHECK FAILED"; exit 1; }
