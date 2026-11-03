#!/usr/bin/env bash
# The co-op journey played by real game windows over the real network
# (localhost ENet): one host and N-1 guests, each its own process, own window,
# own fresh dev profile and own outfit, each driven by src/dev/scenario.gd with
# real key presses and clicks. Saves matched captures from every machine to
# captures/e2e/ and compares what each machine drew of the others with where
# they really were (tools/dev/e2e_compare.py).
#
#   GODOT=/path/to/godot tools/dev/e2e.sh [players=2] [scenario=journey] [netsim per guest ...]
#   e.g. tools/dev/e2e.sh 4 journey typical moderate stress
#
# RES=WxH sets the window size (default 960x540). Localhost only: it does not
# stand in for two machines, a real internet route or Steam (docs/NETWORK.md).
set -u
cd "$(dirname "$0")/../.."
: "${GODOT:?set GODOT to the Godot 4.7 executable}"
N=${1:-2}
SCEN=${2:-journey}
shift 2 || true
SIMS=("$@")
OUT=captures/e2e
mkdir -p "$OUT"
rm -f "$OUT"/*.log
UD="${APPDATA:-$HOME/AppData/Roaming}/Godot/app_userdata/Kindled Deep"
# fresh dev profiles every run (never the player's save)
rm -f "$UD"/e2e_*.json "$UD"/e2e_*.json.bak "$UD"/e2e_*.json.tmp
RES=${RES:-960x540}
W=${RES%x*}
H=${RES#*x}
OUTFITS=(emberwrought rimeguard gloamweave verdant)
LIMIT=${LIMIT:-600}
timeout "$LIMIT" "$GODOT" --resolution "$RES" --position 0,0 --path . -- scene=hub scenario="$SCEN" role=host guests=$((N - 1)) \
	name=Host profile=e2e_host.json seed=7 wear=${OUTFITS[0]} > "$OUT/host.log" 2>&1 &
PIDS=($!)
sleep 2
for ((k = 1; k < N; k++)); do
	SIM=${SIMS[$((k - 1))]:-}
	EXTRA=""
	[ -n "$SIM" ] && EXTRA="netsim=$SIM"
	X=$(((k % 2) * W))
	Y=$(((k / 2) * (H + 40)))
	timeout "$LIMIT" "$GODOT" --resolution "$RES" --position "$X,$Y" --path . -- scene=hub scenario="$SCEN" role=guest \
		name=Guest$k profile=e2e_guest$k.json wear=${OUTFITS[$k]} $EXTRA > "$OUT/guest$k.log" 2>&1 &
	PIDS+=($!)
	sleep 1
done
CODE=0
for p in "${PIDS[@]}"; do
	wait "$p" || CODE=1
done
echo "== results"
grep -h "\[scenario\] RESULT" "$OUT"/*.log
echo "== failures"
grep -H "\[scenario\] FAIL" "$OUT"/*.log | head -40
echo "== script errors"
grep -H "SCRIPT ERROR" "$OUT"/*.log | sort | uniq -c | head -20
python tools/dev/e2e_compare.py "$OUT"/*.log
exit $CODE
