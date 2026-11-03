## Steam play through GodotSteam 4.23.2 (GDExtension; docs/STEAM.md): friends-only
## or private lobbies, invites (the overlay, or the friends list in the party
## screen), joining from an invite, a friend's "Join game" or the
## `+connect_lobby <id>` launch argument, and a SteamMultiplayerPeer (Steam
## Networking Sockets, relayed by Valve: no ports to open) under the same Net
## code as LAN play.
##
## GodotSteam is not part of the repository (tools/steam/fetch_godotsteam.py
## installs it). Everything here reaches it dynamically (Engine.get_singleton /
## ClassDB), so the game builds and runs without it and offers LAN / direct IP.
## The method, signal and constant names were read from the installed
## extension (ClassDB) on 2026-11-03, not taken from documentation.
class_name SteamLink
extends Node

signal changed

## Valve's public test app (Spacewar). Allowed in debug builds only, for local
## experiments: a release build must carry the game's own App ID.
const SPACEWAR := 480
# Steam constants (values read from the extension: Steam.LOBBY_TYPE_PRIVATE ...)
const LOBBY_PRIVATE := 0
const LOBBY_FRIENDS_ONLY := 1
const RESULT_OK := 1
const ENTER_SUCCESS := 1
const INIT_OK := 0
const INIT_NO_CLIENT := 2
const INIT_VERSION_MISMATCH := 3
const FRIEND_FLAG_IMMEDIATE := 4
const PERSONA_OFFLINE := 0
const CHAT_LEFT_MASK := 2 | 4 | 8 | 16     # left, disconnected, kicked, banned
const ENTER_TEXT := {
	2: "That lobby no longer exists.", 3: "You are not allowed in that lobby.", 4: "The party is full.",
	5: "Steam had a problem joining the lobby.", 6: "You are banned from that lobby.",
	7: "Your Steam account is limited and cannot join lobbies.", 10: "A member of that lobby has blocked you.",
	11: "You have blocked a member of that lobby.", 15: "Steam says to slow down; try again in a moment.",
}

var steam: Object                 # the Steam singleton, when GodotSteam is installed
var online := false               # initialised and logged in
var app_id := 0
var my_id := 0
var lobby_id := 0
var status := ""
var _pending_join := 0
var _testing := false
var _friends_only := true


## GodotSteam's classes are present in this build.
static func installed() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")


## The App ID this build runs as: the project setting kindled/steam/app_id, or
## (debug builds only) the steam_appid= dev argument. 0: none configured.
static func configured_app_id() -> int:
	var id := int(ProjectSettings.get_setting("kindled/steam/app_id", 0))
	for a in Dev.args():
		if a.begins_with("steam_appid="):
			id = int(a.substr(12))
	if id == SPACEWAR and not Dev.enabled():
		return 0     # never ship as Spacewar
	return id


## `+connect_lobby <id>` in a command line (Steam starts the game with it from
## an invite or a friend's "Join game"); 0 when absent.
static func lobby_in(args: PackedStringArray) -> int:
	for i in args.size():
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			return int(args[i + 1])
	return 0


func _ready() -> void:
	name = "SteamLink"
	if not installed():
		status = "Steam play is not part of this build (GodotSteam is not installed). LAN and direct IP work."
		return
	print("[steam] GodotSteam %s loaded" % Engine.get_singleton("Steam").call("get_godotsteam_version"))
	app_id = configured_app_id()
	if app_id <= 0:
		status = "No Steam App ID is configured for this build. LAN and direct IP work."
		print("[steam] ", status)
		return
	steam = Engine.get_singleton("Steam")
	var r: Dictionary = steam.call("steamInitEx", app_id, false)
	var code := int(r.get("status", -1))
	if code != INIT_OK:
		status = {INIT_NO_CLIENT: "Steam is not running. Start Steam and log in to play with friends there; LAN and direct IP work.",
			INIT_VERSION_MISMATCH: "This build's Steam library does not match the Steam client (update Steam)."}.get(code,
			"Steam did not start (%s). LAN and direct IP work." % String(r.get("verbal", "")))
		print("[steam] ", status, "  (", r, ")")
		steam = null
		return
	if not bool(steam.call("loggedOn")):
		status = "Steam is running but not logged in to its servers (offline mode?). LAN and direct IP work."
		print("[steam] ", status)
		steam.call("steamShutdown")
		steam = null
		return
	online = true
	my_id = int(steam.call("getSteamID"))
	status = "Steam: signed in as %s%s." % [persona(), "  (Spacewar test App ID - debug builds only)" if app_id == SPACEWAR else ""]
	print("[steam] ", status, "  id ", my_id, ", GodotSteam ", steam.call("get_godotsteam_version"))
	steam.connect("lobby_created", _on_lobby_created)
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.connect("join_requested", _on_join_requested)
	steam.connect("join_game_requested", _on_join_game_requested)
	steam.connect("lobby_kicked", _on_lobby_kicked)
	steam.connect("lobby_chat_update", _on_lobby_chat_update)
	steam.connect("steam_server_disconnected", _on_steam_lost)
	steam.connect("steam_server_connected", _on_steam_back)
	# relayed connections are set up ahead of time, so the first join is quick
	steam.call("initRelayNetworkAccess")
	# launched from an invite or a friend's "Join game": +connect_lobby <id>
	_pending_join = lobby_in(OS.get_cmdline_args())
	if _pending_join == 0:
		_pending_join = lobby_in(String(steam.call("getLaunchCommandLine")).split(" ", false))
	if _pending_join != 0:
		join_lobby.call_deferred(_pending_join)
	if "steamtest" in Dev.args():
		_self_test.call_deferred()


func _process(_dt: float) -> void:
	if online:
		steam.call("run_callbacks")


func _exit_tree() -> void:
	if online:
		# a Steam peer must be gone before Steam shuts down (it would touch
		# Steam's networking afterwards and crash the game on quit)
		if Net.i and Net.i.peer and Net.i.peer.get_class() == "SteamMultiplayerPeer":
			Net.i.peer.close()
			Net.i.multiplayer.multiplayer_peer = null
			Net.i.peer = null
		leave()
		steam.call("steamShutdown")
		online = false


func persona() -> String:
	return String(steam.call("getPersonaName")) if online else ""


## The name Steam shows for someone (for the party list).
func name_of(steam_id: int) -> String:
	return String(steam.call("getFriendPersonaName", steam_id)) if online else ""


## Friends who are online now: [{id, name, playing, lobby}] - `lobby` is the
## Steam lobby they are in when they play this game (joinable from the list).
func friends_online() -> Array:
	var out: Array = []
	if not online:
		return out
	var n := int(steam.call("getFriendCount", FRIEND_FLAG_IMMEDIATE))
	for i in n:
		var fid := int(steam.call("getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE))
		if int(steam.call("getFriendPersonaState", fid)) == PERSONA_OFFLINE:
			continue
		var game: Dictionary = steam.call("getFriendGamePlayed", fid)
		var here := int(game.get("id", 0)) == app_id
		out.append({"id": fid, "name": name_of(fid), "playing": here, "lobby": int(game.get("lobby", 0)) if here else 0})
	out.sort_custom(func(a, b): return (a.playing and not b.playing) or (a.playing == b.playing and String(a.name) < String(b.name)))
	return out


# --- hosting --------------------------------------------------------------------------

## Opens a lobby (friends can see and join it, or only the invited) and hosts on it.
func host_lobby(friends_only := true) -> void:
	if not online:
		_say(status)
		return
	if lobby_id != 0:
		leave()
	_friends_only = friends_only
	_say("Opening a lobby on Steam...")
	steam.call("createLobby", LOBBY_FRIENDS_ONLY if friends_only else LOBBY_PRIVATE, Net.MAX_PLAYERS)


func _on_lobby_created(result: int, id: int) -> void:
	if result != RESULT_OK:
		_say("Steam could not open a lobby (result %d)." % result)
		return
	lobby_id = id
	var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	p.set("no_nagle", true)     # send at once: a frame's input should not wait
	var err: int = p.call("create_host", 0)
	if err != OK:
		_say("Could not host over Steam (error %d)." % err)
		steam.call("leaveLobby", id)
		lobby_id = 0
		return
	steam.call("setLobbyJoinable", id, true)
	update_lobby()
	if not _testing:
		if _friends_only:
			# friends can "Join game" from their friends list (a private lobby is invite-only)
			steam.call("setRichPresence", "connect", "+connect_lobby %d" % id)
			steam.call("setRichPresence", "status", "Gathering a party")
		Net.i.use_peer(p, true)
		_say("Hosting on Steam. Invite friends from the party screen.")
	else:
		_test_hosted(p)
	print("[steam] lobby %d open, hosting" % id)


## Host: what a friend sees about the lobby before joining.
func update_lobby() -> void:
	if not online or lobby_id == 0:
		return
	var d := {
		"kd": "1", "proto": str(Net.PROTOCOL), "ver": Net.game_version(), "host": persona(),
		"region": String(Profile.data.descent.get("region", "ossuary")), "tier": str(Difficulty.selected()),
		"omens": ",".join(Profile.data.descent.get("omens", [])), "players": "%d/%d" % [Net.party_size(), Net.MAX_PLAYERS],
		"ready": str(Net.i.all_ready()) if Net.is_host() else "false",
		"below": "1" if Game.run != null and Game.stage is Dungeon else "0",
	}
	for k in d:
		steam.call("setLobbyData", lobby_id, k, String(d[k]))


## The Steam overlay's invite dialog (falls back to the party screen's list).
func invite() -> bool:
	if not online or lobby_id == 0:
		return false
	if not bool(steam.call("isOverlayEnabled")):
		_say("The Steam overlay is not available here: invite from the friends list below.")
		return false
	steam.call("activateGameOverlayInviteDialog", lobby_id)
	return true


func invite_friend(friend: int) -> void:
	if online and lobby_id != 0 and bool(steam.call("inviteUserToLobby", lobby_id, friend)):
		_say("Invited %s." % name_of(friend))


# --- joining --------------------------------------------------------------------------

func _on_join_requested(id: int, _friend: int) -> void:
	join_lobby(id)


## A friend's "Join game" (rich presence) while this game is already running.
func _on_join_game_requested(_user: int, connect: String) -> void:
	var id := lobby_in(connect.split(" ", false))
	if id != 0:
		join_lobby(id)


func join_lobby(id: int) -> void:
	if not online:
		_say(status)
		return
	if Net.is_host() and Game.run != null:
		_say("Finish this expedition before joining another party.")
		return
	_say("Joining the lobby on Steam...")
	steam.call("joinLobby", id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		_say(String(ENTER_TEXT.get(response, "Could not join the lobby (%d)." % response)))
		return
	var owner := int(steam.call("getLobbyOwner", id))
	if owner == my_id:
		return    # our own lobby (we are hosting)
	if lobby_id != 0 and lobby_id != id:
		steam.call("leaveLobby", lobby_id)
	lobby_id = id
	if String(steam.call("getLobbyData", id, "kd")) != "1":
		_say("That lobby is not a Kindled Deep party.")
		leave()
		return
	var proto := int(String(steam.call("getLobbyData", id, "proto")))
	var ver := String(steam.call("getLobbyData", id, "ver"))
	if proto != Net.PROTOCOL or ver != Net.game_version():
		_say("Different versions: the host runs %s, you run %s. Update both to the same build." % [ver, Net.game_version()])
		leave()
		return
	if String(steam.call("getLobbyData", id, "below")) == "1":
		_say("%s's party is already below. You will join them at the Hearth." % name_of(owner))
	connect_to(owner)


## Opens the link to a host (also used to reach it again after a drop).
func connect_to(owner: int) -> bool:
	if not online:
		return false
	if owner == my_id:
		# Steam does not connect an account to itself: a second account is needed
		_say("That is your own Steam account. Joining needs a friend's (a second account).")
		return false
	var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	p.set("no_nagle", true)
	var err: int = p.call("create_client", owner, 0)
	if err != OK:
		_say("Could not reach the host over Steam (error %d)." % err)
		return false
	Net.i.use_peer(p, false, ["steam", owner])
	_say("Connecting to %s over Steam..." % name_of(owner))
	return true


func _on_lobby_kicked(id: int, _admin: int, _due_to_disconnect: int) -> void:
	if id == lobby_id:
		lobby_id = 0
		_say("You left the Steam lobby.")


## Someone left the lobby. The game's own link notices first; this only keeps
## the lobby's player count honest for friends looking at it.
func _on_lobby_chat_update(id: int, _changed: int, _making_change: int, state: int) -> void:
	if id == lobby_id and Net.is_host() and state & CHAT_LEFT_MASK != 0:
		update_lobby()


func _on_steam_lost(_result: int) -> void:
	_say("Lost the connection to Steam's servers. Steam play will resume when it is back.")


func _on_steam_back() -> void:
	_say("Back in touch with Steam.")


func leave() -> void:
	if online and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
		steam.call("clearRichPresence")
	lobby_id = 0
	changed.emit()


## The link to one peer as Steam sees it (ping, quality), for the overlay.
func link_stats(p: MultiplayerPeer, peer_id: int) -> Dictionary:
	if not online or p == null or not p.has_method("get_peer"):
		return {}
	var pp: Object = p.call("get_peer", peer_id)
	if pp == null:
		return {}
	var d: Variant = steam.call("getConnectionRealTimeStatus", int(pp.call("get_connection_handle")), 0, true)
	return d if d is Dictionary else {}


func _say(t: String) -> void:
	status = t
	if Net.i:
		Net.i._status(t)
	changed.emit()


# --- dev: steamtest --------------------------------------------------------------------

## Debug builds, `-- steamtest steam_appid=480`: opens a *private* lobby (no rich
## presence: friends see nothing to join), checks its data round trip and
## ownership, starts a SteamMultiplayerPeer host on it, then leaves and quits.
## Proves initialisation, lobbies and the transport on one account; joining
## needs a second account (docs/STEAM.md).
func _self_test() -> void:
	_testing = true
	print("[steamtest] persona=%s id=%d app=%d overlay=%s relay=%d" % [persona(), my_id, int(steam.call("getAppID")),
		str(steam.call("isOverlayEnabled")), int(steam.call("getRelayNetworkStatus"))])
	print("[steamtest] friends online: %d" % friends_online().size())
	steam.call("createLobby", LOBBY_PRIVATE, Net.MAX_PLAYERS)
	get_tree().create_timer(15.0).timeout.connect(func() -> void:
		if lobby_id == 0:
			print("[steamtest] FAILED: no lobby after 15 s")
			get_tree().quit(1))


func _test_hosted(p: MultiplayerPeer) -> void:
	var ok := true
	var back := String(steam.call("getLobbyData", lobby_id, "proto"))
	print("[steamtest] lobby data proto=%s ver=%s host=%s" % [back, String(steam.call("getLobbyData", lobby_id, "ver")), String(steam.call("getLobbyData", lobby_id, "host"))])
	ok = ok and back == str(Net.PROTOCOL)
	var owner := int(steam.call("getLobbyOwner", lobby_id))
	print("[steamtest] owner=%d (me=%d) members=%d" % [owner, my_id, int(steam.call("getNumLobbyMembers", lobby_id))])
	ok = ok and owner == my_id
	print("[steamtest] host peer status=%d unique_id=%d" % [p.get_connection_status(), p.get_unique_id()])
	ok = ok and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and p.get_unique_id() == 1
	p.close()
	leave()
	print("[steamtest] %s" % ("PASSED" if ok else "FAILED"))
	get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(0 if ok else 1))
