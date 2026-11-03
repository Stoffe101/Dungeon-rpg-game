## Co-op sessions: hosting, joining, the party roster and every message that
## crosses the wire. The host runs the expedition; clients send their input
## and draw what the host sends back. See docs/NETWORK.md.
##
## Game adds one Net node at /root/Net on every machine (same path everywhere,
## which RPCs need); the static helpers below are how the rest of the game asks
## about the session without caring whether there is one.
class_name Net
extends Node

signal roster_changed
signal status_changed(text: String)

const PORT := 24565
const MAX_PLAYERS := 4
## Bumped whenever a message changes shape: peers that differ cannot play together.
const PROTOCOL := 2
## Each seat's colour: nameplates, map markers and the ring under each Kindled.
const COLORS := [Color(1.0, 0.72, 0.35), Color(0.45, 0.82, 1.0), Color(0.62, 1.0, 0.5), Color(1.0, 0.52, 0.78)]
## The order of the press counters in an input packet.
const PRESS_KEYS := ["attack", "dodge", "ward", "a1", "a2", "flask", "home", "interact"]
## Named conditions for netsim= (round trip ms, loss %, jitter ms).
const SIM_PRESETS := {
	"local": [5.0, 0.0, 1.0], "excellent": [30.0, 0.0, 3.0], "typical": [60.0, 0.5, 6.0],
	"moderate": [100.0, 1.0, 10.0], "difficult": [150.0, 2.0, 15.0], "stress": [200.0, 5.0, 25.0],
}

static var i: Net
## True on the host while an expedition is being shared: effects, sounds and
## spawns are recorded for the clients. Clients and solo play leave it off.
static var recording := false
static var mute := 0           # >0 while something records its own richer event
## Whose action is running on the host (0: the world's). Sounds and screen shake
## from another player's Kindled are theirs, not this machine's.
static var actor_peer := 0
static var actor_pos := Vector2.ZERO
## While set, recorded events skip this peer: its owner already showed them (prediction).
static var skip_peer := 0

var peer: MultiplayerPeer
var roster := {}               # peer id -> {"name", "sheet", "slot"}
var run_sync: NetRun           # the expedition being shared (host or client)
var status := ""

# measured link (client: to the host)
var rtt := 0.0                 # seconds, smoothed
var jitter := 0.0              # seconds, smoothed variation of the round trip
var _ping_t := 0.0
# traffic counters (bytes and messages per second, updated each second)
var stats := {}
var _count := {}
var _count_t := 0.0

# simulated network conditions (dev: netsim=rtt_ms:loss_pct[:jitter_ms] or a preset
# name). Applied on this machine only, half the round trip each way.
var sim_rtt := 0.0
var sim_loss := 0.0
var sim_jitter := 0.0
var _simq: Array = []          # [due_ms, Callable], sorted by due
var _sim_last := {}            # lane -> latest due (keeps a lane in order)


func _ready() -> void:
	i = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("netsim="):
			set_netsim(a.substr(7))


func _process(delta: float) -> void:
	_deliver(Time.get_ticks_msec())
	_count_t += delta
	if _count_t >= 1.0:
		stats = _count.duplicate()
		for k in stats:
			stats[k] = float(stats[k]) / _count_t
		_count.clear()
		_count_t = 0.0
		if peer is ENetMultiplayerPeer and (peer as ENetMultiplayerPeer).host:
			var h := (peer as ENetMultiplayerPeer).host
			stats["wire_out"] = h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
			stats["wire_in"] = h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	if is_client():
		_ping_t += delta
		if _ping_t >= 0.5:
			_ping_t = 0.0
			to_host("_ping", [Time.get_ticks_msec()], "ping", false)


# --- static helpers ---------------------------------------------------------------

static func active() -> bool:
	return i != null and i.peer != null and i.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


static func is_host() -> bool:
	return active() and i.multiplayer.is_server()


static func is_client() -> bool:
	return active() and not i.multiplayer.is_server()


static func my_id() -> int:
	return i.multiplayer.get_unique_id() if active() else 1


static func party_size() -> int:
	return i.roster.size() if active() else 1


## Records an event for the clients (host, during a shared expedition).
static func rec(ev: Array) -> void:
	if recording and mute == 0 and i and i.run_sync:
		i.run_sync.events.append(ev if skip_peer == 0 else ["not", skip_peer, ev])


## A client asks the host to do something (interact, pick a relic...).
static func ask(kind: String, args: Array) -> void:
	if is_client():
		i.to_host("_ask", [kind, args])


static func color_of(peer_id: int) -> Color:
	if i == null or not i.roster.has(peer_id):
		return COLORS[0]
	return COLORS[int(i.roster[peer_id].get("slot", 0)) % COLORS.size()]


static func name_of(peer_id: int) -> String:
	if i == null or not i.roster.has(peer_id):
		return "Kindled"
	return String(i.roster[peer_id].get("name", "Kindled"))


## The running build's version (project setting), sent when joining.
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## Round trip to the host in seconds (0 when hosting or alone).
static func rtt_s() -> float:
	return i.rtt if i and is_client() else 0.0


func count(key: String, n := 1) -> void:
	_count[key] = int(_count.get(key, 0)) + n


# --- simulated conditions --------------------------------------------------------

## netsim=<rtt_ms>:<loss_pct>[:<jitter_ms>] or a preset (local, excellent, typical,
## moderate, difficult, stress). This machine delays (and drops) its own traffic
## both ways, so the whole round trip feels it.
func set_netsim(spec: String) -> void:
	var v: Array = SIM_PRESETS.get(spec, [])
	if v.is_empty():
		var parts := spec.split(":")
		v = [float(parts[0]), float(parts[1]) if parts.size() > 1 else 0.0, float(parts[2]) if parts.size() > 2 else 0.0]
	sim_rtt = float(v[0]) / 1000.0
	sim_loss = float(v[1]) / 100.0
	sim_jitter = float(v[2]) / 1000.0
	print("[net] simulating %d ms round trip, %.1f%% loss, %d ms jitter" % [int(sim_rtt * 1000.0), sim_loss * 100.0, int(sim_jitter * 1000.0)])


## Delivers `fn` now, or later (or never) under simulated conditions. Jitter
## varies the delay but keeps each lane in order (as a real route does); lost
## unreliable packets are gone, reliable ones arrive a round trip later (as a
## resend would) and hold up the ones behind them.
func _through(lane: String, reliable: bool, fn: Callable, now := -1.0) -> void:
	if sim_rtt <= 0.0 and sim_loss <= 0.0:
		fn.call()
		return
	var base := float(Time.get_ticks_msec()) if now < 0.0 else now
	var due := base + sim_rtt * 500.0 + randf_range(-1.0, 1.0) * sim_jitter * 1000.0
	if randf() < sim_loss:
		if not reliable:
			count("sim_lost")
			return
		due += sim_rtt * 1000.0 + 30.0
	due = maxf(due, float(_sim_last.get(lane, 0.0)))
	_sim_last[lane] = due
	# after anything due at the same moment (a burst keeps its order)
	var at := _simq.size()
	while at > 0 and float(_simq[at - 1][0]) > due:
		at -= 1
	_simq.insert(at, [due, fn])


## Hands over everything the simulated link has delivered by `now` (ms).
func _deliver(now: float) -> void:
	while not _simq.is_empty() and float(_simq[0][0]) <= now:
		var fn: Callable = _simq.pop_front()[1]
		fn.call()


## Client -> host, through the simulated link.
func to_host(method: StringName, args: Array, lane := "rel", reliable := true) -> void:
	_through("out_" + lane, reliable, func() -> void:
		if active():
			callv("rpc_id", [1, method] + args))


# --- hosting and joining ------------------------------------------------------------

func host(port := PORT) -> bool:
	leave()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_status("Could not host on port %d (error %d). Is another game already hosting?" % [port, err])
		return false
	peer = enet
	multiplayer.multiplayer_peer = peer
	roster = {1: {"name": _my_name(), "sheet": Profile.character_sheet(), "slot": 0}}
	_status("Hosting on port %d. On your network, friends join with %s." % [port, lan_address()])
	roster_changed.emit()
	return true


func join(address: String, port := PORT) -> bool:
	leave()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, port)
	if err != OK:
		_status("Could not reach %s:%d (error %d)." % [address, port, err])
		return false
	peer = enet
	multiplayer.multiplayer_peer = peer
	_status("Connecting to %s:%d..." % [address, port])
	return true


## This machine's address on the local network (what LAN friends type).
static func lan_address() -> String:
	# home networks first; 172.16-31 last (often a virtual adapter: WSL, Hyper-V, Docker)
	var addrs := IP.get_local_addresses()
	for prefix in ["192.168.", "10."]:
		for a in addrs:
			if a.begins_with(prefix):
				return a
	for a in addrs:
		if a.begins_with("172.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31:
			return a + " (check: this may be a virtual adapter)"
	return "your address"


func leave() -> void:
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	roster.clear()
	recording = false
	rtt = 0.0
	jitter = 0.0
	_simq.clear()
	_sim_last.clear()
	roster_changed.emit()


func _my_name() -> String:
	return String(Settings.get_value("player_name", "Kindled")).substr(0, 16)


func _status(t: String) -> void:
	status = t
	print("[net] ", t)
	status_changed.emit(t)


## ENet slows unreliable traffic when round trips vary, by dropping packets on
## purpose. Our traffic is small and steady, and on a LAN (or localhost, where
## acks wait for the next frame) that "congestion" is only frame timing: keep
## every snapshot and input.
func _steady(id: int) -> void:
	if peer is ENetMultiplayerPeer:
		var p := (peer as ENetMultiplayerPeer).get_peer(id)
		if p:
			p.throttle_configure(5000, ENetPacketPeer.PACKET_THROTTLE_SCALE, 0)


func _on_connected() -> void:
	_steady(1)
	_status("Connected. Waiting for the host's word...")
	to_host("_hello", [_my_name(), Profile.character_sheet(), {"proto": PROTOCOL, "ver": game_version()}])


func _on_failed() -> void:
	_status("Could not connect. Check the address, that the host is hosting, and their firewall.")
	leave()


func _on_server_gone() -> void:
	var in_run := Game.run != null and Game.stage is Dungeon
	leave()
	_status("The host left the session.")
	if in_run:
		Events.toast.emit("The host's fire went out - you are back at your own Hearth.", Color(1.0, 0.6, 0.5))
		Game.abandon_coop_run()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_steady(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var who := name_of(id)
	roster.erase(id)
	_broadcast_roster()
	_status("%s left." % who)
	if run_sync:
		run_sync.on_peer_left(id)


func _broadcast_roster() -> void:
	rpc("_roster", roster)
	roster_changed.emit()


## The client's Kindled changed (gear, skills) while waiting in the sanctuary.
func refresh_sheet() -> void:
	if is_client():
		to_host("_sheet", [Profile.character_sheet()])
	elif is_host():
		roster[1].sheet = Profile.character_sheet()
		_broadcast_roster()


## Host: the measured link to one client (ENet's own figures).
func link_of(id: int) -> Dictionary:
	if not (peer is ENetMultiplayerPeer):
		return {}
	var p := (peer as ENetMultiplayerPeer).get_peer(id)
	if p == null:
		return {}
	return {"rtt": p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),
		"loss": p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE),
		"throttle": p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)}


# --- RPC endpoints -------------------------------------------------------------------
# Client-side endpoints pass through _through() so simulated conditions apply to
# everything a client receives; the host never simulates (it would double up).

@rpc("any_peer", "reliable")
func _hello(pname: String, sheet: Dictionary, info := {}) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if int(info.get("proto", 0)) != PROTOCOL or String(info.get("ver", "")) != game_version():
		rpc_id(id, "_rejected", "Different versions: the host runs %s (protocol %d), you run %s (protocol %d). Update both to the same build." % [
			game_version(), PROTOCOL, String(info.get("ver", "?")), int(info.get("proto", 0))])
		return
	if roster.size() >= MAX_PLAYERS:
		rpc_id(id, "_rejected", "The party is full (four Kindled).")
		return
	if run_sync != null:
		rpc_id(id, "_rejected", "The party is already below. Join when they are back at the Hearth.")
		return
	var used: Array = roster.values().map(func(r): return int(r.slot))
	var slot := 0
	while used.has(slot):
		slot += 1
	roster[id] = {"name": pname.substr(0, 16), "sheet": sheet, "slot": slot}
	_broadcast_roster()
	_status("%s joined the party." % pname)


@rpc("authority", "reliable")
func _rejected(why: String) -> void:
	_through("rel", true, func() -> void:
		leave()
		_status(why))


@rpc("authority", "reliable")
func _roster(r: Dictionary) -> void:
	_through("rel", true, func() -> void:
		roster = r
		if status.begins_with("Connected") or status.begins_with("Connecting"):
			_status("In %s's party." % name_of(1))
		roster_changed.emit())


@rpc("any_peer", "reliable")
func _sheet(sheet: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and roster.has(id):
		roster[id].sheet = sheet
		_broadcast_roster()


## Host -> clients: the party goes down.
@rpc("authority", "reliable")
func _begin(params: Dictionary) -> void:
	_through("rel", true, func() -> void: Game.begin_coop_client(params))


@rpc("authority", "reliable")
func _descend(depth: int) -> void:
	_through("rel", true, func() -> void: Game.descend_client(depth))


@rpc("authority", "reliable")
func _run_end(outcome: String, killer: String, run_data: Dictionary) -> void:
	_through("rel", true, func() -> void: Game.end_coop_client(outcome, killer, run_data))


## Client -> host, every frame (up to 60 a second): see NetRun.pack_input.
@rpc("any_peer", "unreliable_ordered")
func _n_input(d: Array) -> void:
	if multiplayer.is_server() and run_sync:
		count("in_msgs")
		run_sync.on_input(multiplayer.get_remote_sender_id(), d)


@rpc("authority", "unreliable_ordered")
func _snapz(b: PackedByteArray, n: int) -> void:
	count("snap_bytes", b.size())
	_through("snap", false, func() -> void:
		count("snaps")
		if run_sync:
			run_sync.apply_snapshot(bytes_to_var(b.decompress(n, FileAccess.COMPRESSION_ZSTD))))


@rpc("authority", "reliable")
func _events(evs: Array) -> void:
	_through("rel", true, func() -> void:
		if run_sync:
			run_sync.apply_events(evs))


@rpc("any_peer", "reliable")
func _ask(kind: String, args: Array) -> void:
	if multiplayer.is_server() and run_sync:
		run_sync.on_ask(multiplayer.get_remote_sender_id(), kind, args)


## Host -> one client: something only they get to answer (a relic choice).
@rpc("authority", "reliable")
func _offer(kind: String, args: Array) -> void:
	_through("rel", true, func() -> void:
		if run_sync:
			run_sync.on_offer(kind, args))


## Host -> one client: a line meant for them alone ("Found: ...").
@rpc("authority", "reliable")
func _tell(text: String, col: Color) -> void:
	_through("rel", true, func() -> void: Events.toast.emit(text, col))


@rpc("any_peer", "unreliable_ordered")
func _ping(t: int) -> void:
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "_pong", t)


@rpc("authority", "unreliable_ordered")
func _pong(t: int) -> void:
	_through("pong", false, func() -> void:
		var r := (Time.get_ticks_msec() - t) / 1000.0
		jitter = lerpf(jitter, absf(r - rtt), 0.2) if rtt > 0.0 else 0.0
		rtt = r if rtt <= 0.0 else lerpf(rtt, r, 0.2))
