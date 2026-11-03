#!/usr/bin/env bash
# Session recovery with real processes (localhost ENet), both played by the bot:
#  1. a guest's game is killed mid-expedition and started again with the same
#     profile: it must take its seat back (same depth, its run, its gear drawn);
#  2. the host's game is killed: the guest must keep trying for 30 s, then bank
#     the checkpoint it carried into the depth - once.
#
#   GODOT=/path/to/godot tools/dev/e2e_recovery.sh
#
# Logs go to captures/e2e_recovery/. Localhost only (docs/NETWORK.md).
set -u
cd "$(dirname "$0")/../.."
: "${GODOT:?set GODOT to the Godot 4.7 executable}"
OUT=captures/e2e_recovery
mkdir -p "$OUT"
rm -f "$OUT"/*.log
UD="${APPDATA:-$HOME/AppData/Roaming}/Godot/app_userdata/Kindled Deep"
rm -f "$UD"/e2e_rh.json* "$UD"/e2e_rg.json*
RES=${RES:-800x450}
"$GODOT" --resolution "$RES" --position 0,0 --path . -- scene=hub net=host coop=2 seed=7 name=Host profile=e2e_rh.json \
	autopilot godmode netdiag wear=emberwrought > "$OUT/host.log" 2>&1 &
HOST=$!
sleep 2
"$GODOT" --resolution "$RES" --position 820,0 --path . -- scene=hub net=join:127.0.0.1 name=Guest1 profile=e2e_rg.json \
	autopilot godmode wear=rimeguard > "$OUT/guest_a.log" 2>&1 &
GUEST=$!
sleep 30
echo "== killing the guest mid-expedition"
kill -9 $GUEST 2>/dev/null || taskkill //F //PID $GUEST > /dev/null 2>&1
sleep 6
"$GODOT" --resolution "$RES" --position 820,0 --path . -- scene=hub net=join:127.0.0.1 name=Guest1 profile=e2e_rg.json \
	autopilot godmode wear=rimeguard capture=e2e_recovery/guest_back frames=900 > "$OUT/guest_b.log" 2>&1 &
GUEST=$!
sleep 30
echo "== killing the host"
kill -9 $HOST 2>/dev/null || taskkill //F //PID $HOST > /dev/null 2>&1
sleep 45
kill $GUEST 2>/dev/null || taskkill //F //PID $GUEST > /dev/null 2>&1
sleep 2
echo "== host"
grep -hE "found the party again|lost the link|entered depth|floor .* starts" "$OUT/host.log" | head
echo "== guest, first life"
grep -hE "entered depth" "$OUT/guest_a.log" | head -3
echo "== guest, after the restart"
grep -hE "rejoined|entered depth|Lost the host|host is gone|banking|run ended|already brought|SCRIPT ERROR" "$OUT/guest_b.log" | cut -c1-160 | head
echo "== script errors"
grep -H "SCRIPT ERROR" "$OUT"/*.log | sort | uniq -c | head
