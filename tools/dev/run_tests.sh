#!/usr/bin/env bash
# Runs the headless test suite. Fails on test failures AND on any script error
# (GDScript has no exceptions, so a crashing test would otherwise look green).
GODOT="${GODOT:-/c/Users/Skrra/Desktop/Godot_v4.7.2-stable_win64.exe}"
cd "$(dirname "$0")/../.."
out="$("$GODOT" --headless --path . res://tests/test_runner.tscn 2>&1)"
code=$?
echo "$out" | grep -E "FAIL|tests,|SCRIPT ERROR"
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "script errors detected"
	exit 1
fi
exit $code
