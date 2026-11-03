## Steam play through GodotSteam (docs/STEAM.md): friends-only or private
## lobbies, invites through the overlay, joining from a friend's invite or the
## `+connect_lobby <id>` launch argument, and a SteamMultiplayerPeer (Steam
## Networking Sockets, relayed by Valve: no ports to open) under the same Net
## code as LAN play.
##
## GodotSteam is a GDExtension that is not part of the repository. Everything
## here reaches it dynamically (Engine.get_singleton / ClassDB), so the game
## builds and runs without it and simply offers LAN / direct IP play.
##
## NOT YET VERIFIED: the GodotSteam method and signal names below follow its
## 4.x documentation as best known; they have not been run against the real
## extension in this project. See docs/STEAM.md, "Verification".
class_name SteamLink
extends Node

signal changed

## Valve's public test app (Spacewar). Allowed in debug builds only, for local
## experiments: a release build must carry the game's own App ID.
const SPACEWAR := 480
const LOBBY_PRIVATE := 0          # Steam.LOBBY_TYPE_PRIVATE
const LOBBY_FRIENDS_ONLY := 1     # Steam.LOBBY_TYPE_FRIENDS_ONLY
const RESULT_OK := 1              # k_EResultOK
const ENTER_SUCCESS := 1          # k_EChatRoomEnterResponseSuccess

var steam: Object                 # the Steam singleton, when GodotSteam is installed
var online := false               # initialised and logged in
var app_id := 0
var my_id := 0
var lobby_id := 0
var status := ""
var _pending_join := 0


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


func _ready() -> void:
	name = "SteamLink"
	if not installed():
		status = "Steam play is not part of this build (GodotSteam is not installed). LAN and direct IP work."
		return
	app_id = configured_app_id()
	if app_id <= 0:
		status = "No Steam App ID is configured for this build. LAN and direct IP work."
		return
	steam = Engine.get_singleton("Steam")
	var r: Variant = steam.call("steamInitEx", app_id, false)
	var code := int((r as Dictionary).get("status", -1)) if r is Dictionary else (0 if bool(r) else -1)
	if code != 0:
		status = "Steam did not start (%s). Is Steam running and are you logged in?" % (String((r as Dictionary).get("verbal", "")) if r is Dictionary else str(r))
		steam = null
		return
	online = true
	my_id = int(steam.call("getSteamID"))
	status = "Steam: signed in as %s%s." % [persona(), "  (Spacewar test App ID - debug only)" if app_id == SPACEWAR else ""]
	steam.connect("lobby_created", _on_lobby_created)
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.connect("join_requested", _on_join_requested)
	# launched from a friend's invite: steam://... +connect_lobby <id>
	var raw := OS.get_cmdline_args()
	for i in raw.size():
		if raw[i] == "+connect_lobby" and i + 1 < raw.size():
			_pending_join = int(raw[i + 1])
	if _pending_join != 0:
		join_lobby.call_deferred(_pending_join)


func _process(_dt: float) -> void:
	if online:
		steam.call("run_callbacks")


func persona() -> String:
	return String(steam.call("getPersonaName")) if online else ""


## The name Steam shows for someone (for the party list).
func name_of(steam_id: int) -> String:
	return String(steam.call("getFriendPersonaName", steam_id)) if online else ""


# --- hosting --------------------------------------------------------------------------

## Opens a lobby (friends can see and join it, or only the invited) and hosts on it.
func host_lobby(friends_only := true) -> void:
	if not online:
		_say(status)
		return
	_say("Opening a lobby on Steam...")
	steam.call("createLobby", LOBBY_FRIENDS_ONLY if friends_only else LOBBY_PRIVATE, Net.MAX_PLAYERS)


func _on_lobby_created(result: int, id: int) -> void:
	if result != RESULT_OK:
		_say("Steam could not open a lobby (result %d)." % result)
		return
	lobby_id = id
	var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = p.call("create_host", 0)
	if err != OK:
		_say("Could not host over Steam (error %d)." % err)
		steam.call("leaveLobby", id)
		lobby_id = 0
		return
	steam.call("setLobbyJoinable", id, true)
	update_lobby()
	# friends can "Join game" from their friends list
	steam.call("setRichPresence", "connect", "+connect_lobby %d" % id)
	Net.i.use_peer(p, true)
	_say("Hosting on Steam. Invite friends from the party screen (or the Steam overlay).")


## Host: what a friend sees about the lobby before joining.
func update_lobby() -> void:
	if not online or lobby_id == 0:
		return
	var d := {
		"kd": "1", "proto": str(Net.PROTOCOL), "ver": Net.game_version(), "host": persona(),
		"region": String(Profile.data.descent.get("region", "ossuary")), "tier": str(Difficulty.selected()),
		"omens": ",".join(Profile.data.descent.get("omens", [])), "players": "%d/%d" % [Net.party_size(), Net.MAX_PLAYERS],
		"ready": str(Net.i.all_ready()) if Net.is_host() else "false",
	}
	for k in d:
		steam.call("setLobbyData", lobby_id, k, String(d[k]))


func invite() -> void:
	if online and lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)


# --- joining --------------------------------------------------------------------------

func _on_join_requested(id: int, _friend: int) -> void:
	join_lobby(id)


func join_lobby(id: int) -> void:
	if not online:
		_say(status)
		return
	_say("Joining the lobby on Steam...")
	steam.call("joinLobby", id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		_say({2: "That lobby no longer exists.", 3: "You are not allowed in that lobby.", 4: "The party is full.",
			5: "Steam had a problem joining the lobby."}.get(response, "Could not join the lobby (%d)." % response))
		return
	lobby_id = id
	var owner := int(steam.call("getLobbyOwner", id))
	if owner == my_id:
		return    # our own lobby (we are hosting)
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
	connect_to(owner)


## Opens the link to a host (also used to reach it again after a drop).
func connect_to(owner: int) -> bool:
	var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = p.call("create_client", owner, 0)
	if err != OK:
		_say("Could not reach the host over Steam (error %d)." % err)
		return false
	Net.i.use_peer(p, false, ["steam", owner])
	_say("Connecting to %s over Steam..." % name_of(owner))
	return true


func leave() -> void:
	if online and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
		steam.call("clearRichPresence")
	lobby_id = 0
	changed.emit()


func _say(t: String) -> void:
	status = t
	if Net.i:
		Net.i._status(t)
	changed.emit()
