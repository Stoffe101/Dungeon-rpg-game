#!/usr/bin/env bash
# Windows build: release check, then a release export with the "Windows Desktop"
# preset into builds/windows/ (gitignored).
#
#   GODOT=/path/to/godot tools/dev/build_windows.sh [debug]
#
# Needs Godot's export templates for the same version (4.7.2): Editor > Manage
# Export Templates > Download and Install, or install the .tpz by hand.
# A debug export keeps dev arguments and the testing stockpile (for testers);
# a release export drops them. Steam builds also need GodotSteam's files in the
# project and the game's own App ID (docs/STEAM.md) - never Spacewar (480).
set -eu
cd "$(dirname "$0")/../.."
: "${GODOT:?set GODOT to the Godot 4.7 executable}"
MODE=${1:-release}
TEMPLATES="${APPDATA:-$HOME/AppData/Roaming}/Godot/export_templates/4.7.2.stable"
if [ ! -f "$TEMPLATES/windows_release_x86_64.exe" ]; then
	echo "No export templates for 4.7.2 in $TEMPLATES."
	echo "Install them from the editor (Editor > Manage Export Templates) and run this again."
	exit 2
fi
python tools/dev/release_check.py builds/windows
mkdir -p builds/windows
if [ "$MODE" = "debug" ]; then
	"$GODOT" --headless --path . --export-debug "Windows Desktop" builds/windows/KindledDeep.exe
else
	"$GODOT" --headless --path . --export-release "Windows Desktop" builds/windows/KindledDeep.exe
fi
ls -la builds/windows
