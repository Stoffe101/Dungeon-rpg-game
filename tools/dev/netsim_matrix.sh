#!/usr/bin/env bash
# Co-op under simulated network conditions: for each preset a host and a client
# (separate processes, both played by the bot) share a floor; the client
# simulates the link (Net.set_netsim) and logs what it measured (NetDiag netlog=).
#
#   GODOT=/path/to/godot tools/dev/netsim_matrix.sh [frames] [preset ...]
#
# Presets: local excellent typical moderate difficult stress (docs/NETWORK.md).
# Results: captures/net/<preset>.json and a markdown table on stdout.
# Localhost only: this measures the netcode under made-up conditions, not a real
# internet route (see docs/NETWORK.md, "What these numbers are not").
set -u
cd "$(dirname "$0")/../.."
: "${GODOT:?set GODOT to the Godot 4.7 executable}"
FRAMES=${1:-3600}
shift || true
PRESETS=${*:-local excellent typical moderate difficult stress}
OUT=captures/net
mkdir -p "$OUT"
for p in $PRESETS; do
	echo "== $p"
	timeout $((FRAMES / 60 + 120)) "$GODOT" --headless --max-fps 60 --path . -- scene=hub net=host coop=2 seed=7 name=Host \
		profile=net_host.json autopilot frames=$((FRAMES + 600)) quit > "$OUT/host_$p.log" 2>&1 &
	H=$!
	sleep 1
	timeout $((FRAMES / 60 + 90)) "$GODOT" --headless --max-fps 60 --path . -- scene=hub net=join:127.0.0.1 name=Guest \
		profile=net_guest.json autopilot netsim="$p" netlog="$OUT/$p.json" frames="$FRAMES" quit > "$OUT/client_$p.log" 2>&1
	wait $H
	grep -h "SCRIPT ERROR" "$OUT/host_$p.log" "$OUT/client_$p.log" | head -5
done
python tools/dev/netsim_table.py "$OUT" $PRESETS
