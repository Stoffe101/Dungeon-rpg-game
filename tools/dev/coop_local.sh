#!/usr/bin/env bash
# Co-op with real separate processes on this machine: one host and N-1 clients,
# all played by the bot, each with its own dev profile (never the real save).
# Each client may simulate its own link (netsim presets or rtt:loss:jitter).
#
#   GODOT=/path/to/godot tools/dev/coop_local.sh <players> [frames] [netsim per client ...]
#   e.g. tools/dev/coop_local.sh 4 3600 typical moderate stress
#
# Add WINDOWED=1 to watch real windows (otherwise headless). Logs and client
# netlogs go to captures/net/coop<N>_*. Localhost only: see docs/NETWORK.md.
set -u
cd "$(dirname "$0")/../.."
: "${GODOT:?set GODOT to the Godot 4.7 executable}"
N=${1:-2}
FRAMES=${2:-3600}
shift 2 || true
SIMS=("$@")
OUT=captures/net
mkdir -p "$OUT"
HEAD="--headless"
[ "${WINDOWED:-0}" = "1" ] && HEAD="--resolution 960x540"
LIMIT=$((FRAMES / 60 + 150))
timeout $LIMIT "$GODOT" $HEAD --max-fps 60 --path . -- scene=hub net=host coop="$N" seed=7 name=Host profile=coop_host.json \
	autopilot netdiag frames=$((FRAMES + 600)) quit > "$OUT/coop${N}_host.log" 2>&1 &
PIDS=($!)
sleep 1
for ((k = 1; k < N; k++)); do
	SIM=${SIMS[$((k - 1))]:-}
	EXTRA=""
	[ -n "$SIM" ] && EXTRA="netsim=$SIM netlog=$OUT/coop${N}_guest$k.json"
	timeout $LIMIT "$GODOT" $HEAD --max-fps 60 --path . -- scene=hub net=join:127.0.0.1 name=Guest$k profile=coop_guest$k.json \
		autopilot netdiag $EXTRA frames="$FRAMES" quit > "$OUT/coop${N}_guest$k.log" 2>&1 &
	PIDS+=($!)
	sleep 0.5
done
for p in "${PIDS[@]}"; do
	wait "$p"
done
echo "== script errors"
grep -H "SCRIPT ERROR" "$OUT"/coop"${N}"_*.log | head -20
echo "== floors entered"
grep -H "\[game\] entered" "$OUT"/coop"${N}"_*.log | head -20
for ((k = 1; k < N; k++)); do
	[ -f "$OUT/coop${N}_guest$k.json" ] && python -c "import json,sys; a=json.load(open(sys.argv[1]))['avg']; print(sys.argv[1], 'rtt %.0f ms, p50 %.3f p95 %.3f, drawn %.0f ms behind, down %.1f KB/s' % (a['rtt']*1000, a.get('err_p50',0), a.get('err_p95',0), a['delay'], a['in_kbs']))" "$OUT/coop${N}_guest$k.json"
done
