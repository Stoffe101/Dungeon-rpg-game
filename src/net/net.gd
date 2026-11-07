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
## A party member's character sheet changed (gear, wardrobe, weapon, skills):
## every machine redraws that Kindled (and the host rebuilds its stats).
signal sheet_changed(peer_id: int)
## The open expedition proposal changed (Expedition): made, answered, counting, gone.
signal proposal_changed
## Guest: the host's camp arrived or changed (the sanctuary is rebuilt to match).
signal camp_changed

const PORT := 24565
const MAX_PLAYERS := 4
## Bumped whenever a message changes shape: peers that differ cannot play together.
const PROTOCOL := 14
## How long a seat waits for a Kindled that lost the link, and how long that
## Kindled keeps trying to reach the host again (seconds).
const SEAT_WAIT := 60.0
const RECONNECT_TRY := 30.0
## Each seat's colour: nameplates, map markers and the ring under each Kindled.
const COLORS := [Color(1.0, 0.72, 0.35), Color(0.45, 0.82, 1.0), Color(0.62, 1.0, 0.5), Color(1.0, 0.52, 0.78)]
## The order of the press counters in an input packet.
const PRESS_KEYS := ["attack", "dodge", "ward", "a1", "a2", "flask", "home", "interact", "a3"]
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

var peer: MultiplayerPeer       # ENet (LAN / direct IP) or SteamMultiplayerPeer: the same code above either
var steam: SteamLink           # Steam lobbies and invites (does nothing without GodotSteam)
var roster := {}               # peer id -> {"name", "sheet", "slot"}
var run_sync: NetRun           # the expedition being shared (host or client)
var status := ""
var ready_floor := {}          # host: peer -> the floor that peer has built (NetRun waits for all)
var away := {}                 # host: peer -> ms until its seat is given up (it lost the link mid-run)
var reconnecting_until := 0    # client: ms until it stops trying to reach the host again
var _last_join := ["", 0]      # client: the address it joined (to reach it again)
var _connect_until := 0        # client: ms until a connection attempt is given up
var _sheet_due := -1.0         # seconds until this machine's changed sheet goes out (changes come in bursts)
var _sheet_sent := {}          # the sheet the party last heard from this machine
var _retry_t := 0.0
var _early: Array = []         # client: [floor, events] sent before this machine had built that floor
## The party's expedition count (the host's): floor ids are expedition * 1000 +
## depth, so nothing from a floor left behind - or from the last expedition's
## floor of the same depth - is ever taken for the floor being played.
var expedition := 0
var proposal := {}             # the party's open expedition proposal (the host's; a copy elsewhere) - see Expedition
var camp := {}                 # guest: the host's camp (Hub.camp_of_profile), which this machine's sanctuary shows
var hub_sync: HubSync          # the shared sanctuary, while this machine is in it
var _camp_sent := {}           # host: the camp the party last heard of
var _where_me := "menu"        # where this machine's player is: menu, hub, below, summary
var _where_set := false

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
	for a in Dev.args():
		if a.begins_with("netsim="):
			set_netsim(a.substr(7))
	steam = SteamLink.new()
	add_child(steam)
	# the first scene is built before this node exists: start from it
	if not _where_set and Game.stage is Hub:
		_where_me = "menu" if (Game.stage as Hub).menu_mode else "hub"
	roster_changed.connect(func() -> void:
		if is_host():
			steam.update_lobby())
	# what this Kindled wears and wields is seen by the whole party, live
	Profile.changed.connect(func() -> void:
		if active():
			_sheet_due = 0.25)
	if Dev.args().has("autopilot") or Dev.args().has("autoaccept"):
		proposal_changed.connect(_dev_answer)
	roster_changed.connect(func() -> void:
		if is_host():
			Expedition.on_roster()
		elif not active() and not proposal.is_empty():
			proposal = {}
			proposal_changed.emit())


func _process(delta: float) -> void:
	_deliver(Time.get_ticks_msec())
	if _sheet_due >= 0.0:
		_sheet_due -= delta
		if _sheet_due < 0.0:
			refresh_sheet()
			if is_host():
				send_camp()
	if is_host():
		Expedition.tick()
	if _connect_until > 0 and Time.get_ticks_msec() > _connect_until and not active():
		# the host never answered (a Steam peer can wait forever): give up on this try
		_connect_until = 0
		if peer:
			peer.close()
		_on_failed()
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
		else:
			# Steam does not count bytes for us: the snapshots are most of it
			stats["wire_out"] = stats.get("snap_out", 0.0)
			stats["wire_in"] = stats.get("snap_bytes", 0.0)
	if is_client():
		_ping_t += delta
		if _ping_t >= 0.5:
			_ping_t = 0.0
			to_host("_ping", [Time.get_ticks_msec()], "ping", false)
	if reconnecting_until > 0 and not active():
		if Time.get_ticks_msec() > reconnecting_until:
			give_up()
		else:
			_retry_t += delta
			if _retry_t >= 3.0 and (peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED):
				_retry_t = 0.0
				_reach(_last_join[0], int(_last_join[1]))
	if multiplayer.multiplayer_peer and multiplayer.is_server() and not away.is_empty():
		for pid in away.keys():
			if Time.get_ticks_msec() > int(away[pid]):
				_drop_seat(int(pid))


## Dev: every machine in the party saves its screen now (`<name>_<player
## name>.png`), so what each player saw at one moment can be compared.
func dev_shot(shot: String) -> void:
	if not Dev.enabled():
		return
	if is_client():
		to_host("_dev_shot", [shot])
	else:
		_shot_here(shot)
		if is_host():
			rpc("_dev_shot_all", shot)


@rpc("any_peer", "reliable")
func _dev_shot(shot: String) -> void:
	if multiplayer.is_server():
		dev_shot(shot)


@rpc("authority", "reliable")
func _dev_shot_all(shot: String) -> void:
	_shot_here(shot)


func _shot_here(shot: String) -> void:
	if not Dev.enabled():
		return
	var tag := "p%d" % my_id()
	for a in Dev.args():
		if a.begins_with("name="):
			tag = a.substr(5).to_lower()
	Capture.save_now("%s_%s" % [shot, tag])


## Dev (bots, `autoaccept`): agree to the party's expedition after a moment.
func _dev_answer() -> void:
	if proposal.is_empty() or Expedition.my_answer() != "":
		return
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if not proposal.is_empty() and Expedition.my_answer() == "":
			Expedition.reply(true))


# --- static helpers ---------------------------------------------------------------

## In a session: hosting, or a client whose host is actually reachable (a
## Steam peer reports "connected" before the host has answered).
static func active() -> bool:
	if i == null or i.peer == null or i.peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return i.multiplayer.is_server() or i.multiplayer.get_peers().has(1)


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
		if actor_peer != 0 and String(ev[0]) == "fx" and String(ev[1]) in ["burst", "motes"]:
			ev = ["by", actor_peer, ev]    # each machine draws others' particles at its Allies' setting
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
	use_peer(enet, true)
	_status("Hosting on port %d. On your network, friends join with %s." % [port, lan_address()])
	return true


## Starts a session on a ready transport (ENet or Steam). Hosting seats this
## machine first; a client remembers how to reach the host again.
func use_peer(p: MultiplayerPeer, hosting: bool, reach := []) -> void:
	if peer and peer != p:
		peer.close()
	peer = p
	multiplayer.multiplayer_peer = p
	if not reach.is_empty():
		_last_join = reach
	if not hosting:
		_connect_until = Time.get_ticks_msec() + 20000
	if hosting:
		_sheet_sent = Profile.character_sheet()
		roster = {1: {"name": _my_name(), "sheet": _sheet_sent, "slot": 0, "id": identity(), "where": _where_me}}
		roster_changed.emit()


func join(address: String, port := PORT) -> bool:
	leave()
	reconnecting_until = 0
	_last_join = [address, port]
	return _reach(address, port)


func _reach(address: String, port: int) -> bool:
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	if address == "steam":
		return steam.connect_to(port)     # the host's Steam ID
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, port)
	if err != OK:
		_status("Could not reach %s:%d (error %d)." % [address, port, err])
		return false
	use_peer(enet, false)
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


func leave(keep_lobby := false) -> void:
	if not keep_lobby and steam:
		steam.leave()
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	roster.clear()
	_host_where = ""
	proposal = {}
	camp = {}
	_camp_sent = {}
	proposal_changed.emit()
	recording = false
	rtt = 0.0
	jitter = 0.0
	ready_floor.clear()
	away.clear()
	_early.clear()
	_simq.clear()
	_sim_last.clear()
	roster_changed.emit()


func _my_name() -> String:
	var n := String(Settings.get_value("player_name", "Kindled"))
	if n == "Kindled" and steam and steam.online:
		n = steam.persona()
	return n.substr(0, 16)


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
			# notice a dead link in seconds, not half a minute (a seat waits for it)
			p.set_timeout(32, 3000, 8000)


func _on_connected() -> void:
	_connect_until = 0
	_steady(1)
	_status("Connected. Waiting for the host's word..." if reconnecting_until == 0 else "Found the host. Asking for our seat back...")
	var info := {"proto": PROTOCOL, "ver": game_version(), "id": identity(), "where": _where_me}
	if reconnecting_until > 0 and Game.run:
		info["rejoin"] = Game.run.run_id
	_sheet_sent = Profile.character_sheet()
	to_host("_hello", [_my_name(), _sheet_sent, info])


## Who this player is to the host: the profile's identity (Steam: the Steam ID).
static func identity() -> String:
	# dev (debug builds): a second process on the same Steam account is its own Kindled
	if i and i.steam and i.steam.online and not Dev.args().has("localid"):
		return "steam:%d" % i.steam.my_id
	return Profile.identity()


func _on_failed() -> void:
	if reconnecting_until > 0:
		return     # still trying (_process reaches out again)
	if String(_last_join[0]) == "steam":
		_status("Could not reach the host over Steam. Check that they are still hosting.")
	else:
		_status("Could not connect. Check the address, that the host is hosting, and their firewall.")
	leave()


func _on_server_gone() -> void:
	var in_run := Game.run != null and Game.run.result == "" and Game.stage is Dungeon
	var addr: Array = _last_join.duplicate()
	leave(true)
	if in_run and String(addr[0]) != "":
		# the link may only have dropped: keep the floor and reach for the host
		_last_join = addr
		reconnecting_until = Time.get_ticks_msec() + int(RECONNECT_TRY * 1000.0)
		_retry_t = 2.0
		_status("Lost the host. Reaching for them again...")
		Game.coop_link_lost()
		return
	_status("The host left the session.")
	if in_run:
		Game.abandon_coop_run()


## Client: stop reaching for the host; what was carried into this depth comes home.
func give_up() -> void:
	var was := reconnecting_until > 0
	reconnecting_until = 0
	leave()
	_status("The host left the session.")
	if was and Game.run:
		Game.abandon_coop_run()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_steady(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not roster.has(id) or away.has(id):
		return
	var who := name_of(id)
	if run_sync and roster.has(id):
		# mid-expedition: the seat waits a while for the same Kindled to return
		roster[id]["away"] = true
		away[id] = Time.get_ticks_msec() + int(SEAT_WAIT * 1000.0)
		_broadcast_roster()
		_status("%s lost the link. Their seat waits." % who)
		run_sync.on_peer_away(id)
		return
	roster.erase(id)
	_broadcast_roster()
	_status("%s left." % who)


## Host: a seat that waited long enough is given up.
func _drop_seat(id: int) -> void:
	away.erase(id)
	var who := name_of(id)
	roster.erase(id)
	_broadcast_roster()
	_status("%s left." % who)
	if run_sync:
		run_sync.on_peer_left(id)


## Peers that are here (away seats are in the roster but not connected).
func present() -> Array:
	return roster.keys().filter(func(pid): return not bool(roster[pid].get("away", false)))


func _broadcast_roster() -> void:
	rpc("_roster", roster)
	roster_changed.emit()


## This machine's Kindled changed (gear, wardrobe, weapon, skills): the party
## hears of it (only when something they would see or feel changed).
func refresh_sheet() -> void:
	var sh := Profile.character_sheet()
	if sh == _sheet_sent or not active():
		return
	_sheet_sent = sh
	if is_client():
		to_host("_sheet", [sh])
	elif is_host() and roster.has(1):
		roster[1].sheet = sh
		_broadcast_roster()
		sheet_changed.emit(1)


## Host: the measured link to one client (ENet's figures, or Steam's).
func link_of(id: int) -> Dictionary:
	if not (peer is ENetMultiplayerPeer):
		var s: Dictionary = steam.link_stats(peer, id) if steam else {}
		return {"rtt": int(s.get("ping", 0)), "loss": 0.0, "throttle": 0, "steam": s}
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
	if run_sync != null:
		# the same Kindled (by identity) takes its seat back, even after a restart
		var seat := _seat_of(String(info.get("id", "")))
		if seat != 0 and Game.run:
			if not away.has(seat):
				# the old link is not known to be dead yet: it is now
				_on_peer_disconnected(seat)
				if peer is ENetMultiplayerPeer:
					(peer as ENetMultiplayerPeer).get_peer(seat).peer_disconnect_now()
			_rejoin(seat, id)
			return
		rpc_id(id, "_rejected", "The party is already below. Join when they are back at the Hearth.")
		return
	if roster.size() >= MAX_PLAYERS:
		rpc_id(id, "_rejected", "The party is full (four Kindled).")
		return
	for pid in roster:
		if String(roster[pid].get("id", "")) == String(info.get("id", "x")) and String(info.get("id", "")) != "":
			rpc_id(id, "_rejected", "That Kindled is already in the party.")
			return
	var used: Array = roster.values().map(func(r): return int(r.slot))
	var slot := 0
	while used.has(slot):
		slot += 1
	roster[id] = {"name": pname.substr(0, 16), "sheet": sheet, "slot": slot, "id": String(info.get("id", "")), "where": String(info.get("where", "menu"))}
	# the sanctuary they walk into is this one, and they hear of any open proposal
	rpc_id(id, "_camp", Hub.camp_of_profile())
	rpc_id(id, "_proposal", proposal)
	_broadcast_roster()
	_status("%s joined the party." % pname)
	Events.toast.emit("%s joined the party." % pname, color_of(id))


## Host: the guest seat held by this identity (its peer id), or 0.
func _seat_of(ident: String) -> int:
	if ident == "":
		return 0
	for pid in roster:
		if int(pid) != 1 and String(roster[pid].get("id", "")) == ident:
			return int(pid)
	return 0


## Host: a Kindled that lost the link is back. Its seat (slot, run, Kindled on
## the floor) moves to its new peer id, and it gets the floor as it is now.
func _rejoin(old: int, new: int) -> void:
	var entry: Dictionary = roster[old]
	roster.erase(old)
	away.erase(old)
	entry.erase("away")
	roster[new] = entry
	if run_sync:
		run_sync.on_rejoin(old, new)
	_steady(new)
	_broadcast_roster()
	var r := Game.run_of(new)
	var params := {"seed": Game.run.seed, "region": "delve" if Game.run.delve else Game.run.region, "tier": Game.run.tier,
		"omens": Game.run.omens.duplicate(), "run_id": Game.run.run_id, "depth": Game.run.depth, "exp": expedition, "route": Game.run.route}
	rpc_id(new, "_rejoined", params, r.to_dict())
	# what it carried into this depth, in case this host's fire goes out next
	var cp: Dictionary = Game.checkpoints.get(String(entry.get("id", "")), {})
	if not cp.is_empty():
		rpc_id(new, "_checkpoint", cp)
	if run_sync:
		rpc_id(new, "_events", run_sync.floor_id, run_sync.world_dump(new))
	_status("%s found the party again." % String(entry.name))
	Events.toast.emit("%s found the party again." % String(entry.name), Color(0.75, 0.95, 0.9))


## Host -> a returning client: its run, and the depth to build again.
@rpc("authority", "reliable")
func _rejoined(params: Dictionary, run_data: Dictionary) -> void:
	_through("rel", true, func() -> void:
		reconnecting_until = 0
		if (Profile.data.get("settled_runs", []) as Array).has(String(params.get("run_id", ""))):
			# this Kindled already brought its share of that expedition home
			leave()
			_status("You already brought your share of that expedition home.")
			return
		Game.rejoin_coop_client(params, run_data))


# --- where everyone is, and the expedition they agree on --------------------------------

## This machine's player moved on: the sanctuary, the menu, below, the summary.
## The party screen and proposals show it ("at the main menu").
func set_where(w: String) -> void:
	_where_me = w
	_where_set = true
	_following = false
	if is_host() and roster.has(1):
		roster[1]["where"] = w
		_broadcast_roster()
	elif is_client():
		to_host("_where", [w])


@rpc("any_peer", "reliable")
func _where(w: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and roster.has(id) and w in ["menu", "hub", "below", "summary"]:
		roster[id]["where"] = w
		_broadcast_roster()


## Where a party member is, in words ("in the sanctuary").
static func where_text(peer_id: int) -> String:
	if i == null or not i.roster.has(peer_id):
		return ""
	if bool(i.roster[peer_id].get("away", false)):
		return "lost the link"
	return {"menu": "at the main menu", "hub": "in the sanctuary", "below": "below", "summary": "reading the summary"}.get(
		String(i.roster[peer_id].get("where", "")), "")


## Host: the camp everyone in the party walks, sent when it changes (a forge
## rebuilt, a resident arrived...).
func send_camp() -> void:
	if not is_host():
		return
	var c := Hub.camp_of_profile()
	if c != _camp_sent:
		_camp_sent = c
		rpc("_camp", c)


@rpc("authority", "reliable")
func _camp(c: Dictionary) -> void:
	_through("rel", true, func() -> void:
		if c != camp:
			camp = c
			camp_changed.emit())


@rpc("any_peer", "reliable")
func _propose(region: String, tier: int, omens: Array) -> void:
	if multiplayer.is_server():
		Expedition.propose(multiplayer.get_remote_sender_id(), region, tier, omens)


@rpc("any_peer", "reliable")
func _answer(id: int, yes: bool) -> void:
	if multiplayer.is_server():
		Expedition.answer(multiplayer.get_remote_sender_id(), id, yes)


@rpc("any_peer", "reliable")
func _withdraw(id: int) -> void:
	if multiplayer.is_server():
		Expedition.cancel(multiplayer.get_remote_sender_id(), id)


@rpc("authority", "reliable")
func _proposal(p: Dictionary) -> void:
	_through("rel", true, func() -> void:
		proposal = p
		proposal_changed.emit())


## Client -> host, 20 a second in the sanctuary: where its Kindled stands (HubSync).
@rpc("any_peer", "unreliable_ordered")
func _hub_pose(pose: Array) -> void:
	if multiplayer.is_server() and hub_sync:
		hub_sync.on_pose(multiplayer.get_remote_sender_id(), pose)


## Host -> clients, 20 a second: the party in the sanctuary, and the camp's movers.
@rpc("authority", "unreliable_ordered")
func _hub_world(poses: Dictionary, movers: Array) -> void:
	_through("hub", false, func() -> void:
		if hub_sync:
			hub_sync.on_world(poses, movers))


@rpc("authority", "reliable")
func _rejected(why: String) -> void:
	_through("rel", true, func() -> void:
		leave()
		_status(why))


@rpc("authority", "reliable")
func _roster(r: Dictionary) -> void:
	_through("rel", true, func() -> void:
		var old := roster
		roster = r
		if status.begins_with("Connected") or status.begins_with("Connecting"):
			_status("In %s's party." % name_of(1))
		roster_changed.emit()
		for pid in roster:
			if old.has(pid) and old[pid].get("sheet") != roster[pid].get("sheet"):
				sheet_changed.emit(int(pid))
		_follow_host())


var _following := false
var _host_where := ""          # where the host was at the last roster (a guest follows a change)


## A guest still at the title screen follows the host into the shared
## sanctuary as soon as the host is there (the host's "Begin together", or a
## host already in camp when the guest joins): nobody has to close the party
## screen and press Continue on their own. Their own Kindled, as ever.
func _follow_host() -> void:
	if not is_client() or not roster.has(1):
		return
	var hw := String(roster[1].get("where", "menu"))
	var was := _host_where
	_host_where = hw
	# only when the host *goes* in (or is in when we join): a guest who walks
	# back to the title screen on purpose is not pulled into camp again
	if _where_me != "menu" or _following or hw == "menu" or hw == was:
		return
	_following = true
	if Game.ui:
		Game.ui.toast("%s's sanctuary - you follow with your own Kindled." % name_of(1), Color(0.75, 0.95, 0.9))
		Game.ui.leave_main_menu()
		Game.ui.fade(Game.goto_hub)


@rpc("any_peer", "reliable")
func _sheet(sheet: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and roster.has(id):
		roster[id].sheet = sheet
		_broadcast_roster()
		sheet_changed.emit(id)


## Host -> clients: the party goes down.
@rpc("authority", "reliable")
func _begin(params: Dictionary) -> void:
	_through("rel", true, func() -> void: Game.begin_coop_client(params))


@rpc("authority", "reliable")
func _descend(depth: int, route: String) -> void:
	_through("rel", true, func() -> void: Game.descend_client(depth, route))


@rpc("authority", "reliable")
func _run_end(outcome: String, killer: String, run_data: Dictionary) -> void:
	_through("rel", true, func() -> void: Game.end_coop_client(outcome, killer, run_data))


## Host -> one client as each floor begins: its run so far (kept in case the host is lost).
@rpc("authority", "reliable")
func _checkpoint(run_data: Dictionary) -> void:
	_through("rel", true, func() -> void: Game.coop_checkpoint = run_data)


## Client -> host, every frame (up to 60 a second): see NetRun._send_input.
## Each packet names its floor: a client still on the floor the party just
## left keeps sending input (and counting its sequence) until it has built the
## next one, and the host must not take those numbers for the new floor - its
## fresh Kindled would then drop every real input as old, and stand frozen
## while its owner walked on (the "frozen after the stairs" bug).
@rpc("any_peer", "unreliable_ordered")
func _n_input(fl: int, d: Array) -> void:
	if multiplayer.is_server() and run_sync:
		count("in_msgs")
		if fl != run_sync.floor_id:
			count("in_stale")
			return
		run_sync.on_input(multiplayer.get_remote_sender_id(), d)


@rpc("authority", "unreliable_ordered")
func _snapz(fl: int, b: PackedByteArray, n: int) -> void:
	count("snap_bytes", b.size())
	_through("snap", false, func() -> void:
		count("snaps")
		if run_sync and run_sync.floor_id == fl:
			run_sync.apply_snapshot(bytes_to_var(b.decompress(n, FileAccess.COMPRESSION_ZSTD))))


## Host -> clients, every frame something happened on floor `fl`. A client that
## has not built that floor yet keeps them until it has (Game is still showing
## the depth's title card): nothing that happens there first is lost.
@rpc("authority", "reliable")
func _events(fl: int, evs: Array) -> void:
	_through("rel", true, func() -> void:
		if run_sync and run_sync.floor_id == fl:
			run_sync.apply_events(evs)
		elif run_sync == null or fl > run_sync.floor_id:
			_early.append([fl, evs]))


## Client: what was sent for floor `fl` before it was built here (and forget older floors).
func take_early(fl: int) -> Array:
	var out: Array = []
	for e in _early:
		if int(e[0]) == fl:
			out.append_array(e[1])
	_early = _early.filter(func(e): return int(e[0]) > fl)
	return out


## Client -> host: this machine has built floor `fl` and is ready to play it.
@rpc("any_peer", "reliable")
func _floor_ready(fl: int) -> void:
	if multiplayer.is_server():
		ready_floor[multiplayer.get_remote_sender_id()] = fl


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


## Host -> one guest: a find of their own (gear, a rune, a blueprint), for
## their Satchel. Banked once by its drop id, then acknowledged; its moment
## (the name rising, the chime) plays only here.
@rpc("authority", "reliable")
func _gift(fl: int, drop: String, kind: String, what: Variant, grade: int) -> void:
	_through("rel", true, func() -> void:
		var fresh := Profile.bank_find(kind, what, drop)
		if fresh and run_sync and run_sync.floor_id == fl and Game.stage and Game.stage.player:
			Pickup.found_fx(Game.stage, Game.stage.player, kind, what, grade)
		if Game.run:
			var seen := false
			for f in Game.run.found:
				if String(f.get("drop", "")) == drop:
					seen = true
			if not seen:
				Game.run.found.append({"kind": kind, "what": what, "drop": drop})
		Net.ask("gift_ok", [drop]))


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
