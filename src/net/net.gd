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
## Each seat's colour: nameplates, map markers and the ring under each Kindled.
const COLORS := [Color(1.0, 0.72, 0.35), Color(0.45, 0.82, 1.0), Color(0.62, 1.0, 0.5), Color(1.0, 0.52, 0.78)]

static var i: Net
## True on the host while an expedition is being shared: effects, sounds and
## spawns are recorded for the clients. Clients and solo play leave it off.
static var recording := false
static var mute := 0           # >0 while something records its own richer event

var peer: ENetMultiplayerPeer
var roster := {}               # peer id -> {"name", "sheet", "slot"}
var run_sync: NetRun           # the expedition being shared (host or client)
var status := ""
var _left_run := false


func _ready() -> void:
	i = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


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
		i.run_sync.events.append(ev)


## A client asks the host to do something (interact, pick a relic...).
static func ask(kind: String, args: Array) -> void:
	if is_client():
		i.rpc_id(1, "_ask", kind, args)


static func color_of(peer_id: int) -> Color:
	if i == null or not i.roster.has(peer_id):
		return COLORS[0]
	return COLORS[int(i.roster[peer_id].get("slot", 0)) % COLORS.size()]


static func name_of(peer_id: int) -> String:
	if i == null or not i.roster.has(peer_id):
		return "Kindled"
	return String(i.roster[peer_id].get("name", "Kindled"))


# --- hosting and joining ------------------------------------------------------------

func host(port := PORT) -> bool:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		peer = null
		_status("Could not host on port %d (error %d). Is another game already hosting?" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	roster = {1: {"name": _my_name(), "sheet": Profile.character_sheet(), "slot": 0}}
	_status("Hosting on port %d. Friends join with your address." % port)
	roster_changed.emit()
	return true


func join(address: String, port := PORT) -> bool:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		peer = null
		_status("Could not reach %s:%d (error %d)." % [address, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	_status("Connecting to %s:%d..." % [address, port])
	return true


func leave() -> void:
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	roster.clear()
	recording = false
	roster_changed.emit()


func _my_name() -> String:
	return String(Settings.get_value("player_name", "Kindled")).substr(0, 16)


func _status(t: String) -> void:
	status = t
	print("[net] ", t)
	status_changed.emit(t)


func _on_connected() -> void:
	_status("Connected. Waiting for the host's word...")
	rpc_id(1, "_hello", _my_name(), Profile.character_sheet())


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


func _on_peer_connected(_id: int) -> void:
	pass


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
		rpc_id(1, "_sheet", Profile.character_sheet())
	elif is_host():
		roster[1].sheet = Profile.character_sheet()
		_broadcast_roster()


# --- RPC endpoints -------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(pname: String, sheet: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
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
	leave()
	_status(why)


@rpc("authority", "reliable")
func _roster(r: Dictionary) -> void:
	roster = r
	if status.begins_with("Connected") or status.begins_with("Connecting"):
		_status("In %s's party." % name_of(1))
	roster_changed.emit()


@rpc("any_peer", "reliable")
func _sheet(sheet: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and roster.has(id):
		roster[id].sheet = sheet
		_broadcast_roster()


## Host -> clients: the party goes down.
@rpc("authority", "reliable")
func _begin(params: Dictionary) -> void:
	Game.begin_coop_client(params)


@rpc("authority", "reliable")
func _descend(depth: int) -> void:
	Game.descend_client(depth)


@rpc("authority", "reliable")
func _run_end(outcome: String, killer: String, run_data: Dictionary) -> void:
	Game.end_coop_client(outcome, killer, run_data)


@rpc("any_peer", "unreliable_ordered")
func _n_input(d: Dictionary) -> void:
	if multiplayer.is_server() and run_sync:
		run_sync.on_input(multiplayer.get_remote_sender_id(), d)


@rpc("authority", "unreliable_ordered")
func _snapz(b: PackedByteArray, n: int) -> void:
	if run_sync:
		run_sync.apply_snapshot(bytes_to_var(b.decompress(n, FileAccess.COMPRESSION_ZSTD)))


@rpc("authority", "reliable")
func _events(evs: Array) -> void:
	if run_sync:
		run_sync.apply_events(evs)


@rpc("any_peer", "reliable")
func _ask(kind: String, args: Array) -> void:
	if multiplayer.is_server() and run_sync:
		run_sync.on_ask(multiplayer.get_remote_sender_id(), kind, args)


## Host -> one client: something only they get to answer (a relic choice).
@rpc("authority", "reliable")
func _offer(kind: String, args: Array) -> void:
	if run_sync:
		run_sync.on_offer(kind, args)


## Host -> one client: a line meant for them alone ("Found: ...").
@rpc("authority", "reliable")
func _tell(text: String, col: Color) -> void:
	Events.toast.emit(text, col)
