# Steam play, builds, and cross-machine testing

Status (2026-11-03): GodotSteam 4.23.2 is installed and its real API was read
from the engine. On one machine with one Steam account, these work:

- Steam starts, a private lobby is opened and its data read back, and a Steam
  host peer runs (in the editor and in an exported debug build).
- The game quits cleanly with Steam running.
- Without Steam, or without an App ID, the game falls back to LAN / direct IP.

**Not verified:** a second player actually joining over Steam. Steam will not
connect an account to itself, so that needs a second Steam account on a second
PC (see "What is still blocked").

## What the game does with Steam

- **Lobbies**: "Host on Steam" opens a friends-only lobby for four (private:
  `SteamLink.host_lobby(false)`). Its lobby data carries the game's marker,
  protocol and version, the host's name, the region, tier and Omens, the party
  size, readiness and whether the party is below.
- **Invites**: "Invite friends" (while hosting) lists online Steam friends
  with an Invite button each (`inviteUserToLobby`) and, when the overlay is
  available, a button for the overlay's invite dialog.
- **Joining**: from an invite (`join_requested`), from "Join game" in the
  friends list while the game runs (`join_game_requested`) or when Steam starts
  it (`+connect_lobby <id>`, also read from `getLaunchCommandLine`), or from
  "Join a friend" in the party screen (friends in a Kindled Deep lobby).
  Rich presence advertises "Join game" for friends-only lobbies only; a private
  lobby is invite-only.
- **Transport**: `SteamMultiplayerPeer` (Steam Networking Sockets with Valve's
  relay: no port forwarding, addresses stay private) under the same `Net` code
  as ENet. The client connects to the lobby owner's Steam ID. `no_nagle` is on
  (each frame's input goes out at once).
- **Identity**: the Steam ID (a dropped guest's seat waits for the same Steam
  ID). The party name defaults to the Steam persona name.
- **Errors**: Steam not running, not logged in, library/client mismatch, no App
  ID, every lobby-entry failure Steam reports (gone, full, not allowed, banned,
  limited account, blocked, rate limit), not a Kindled Deep lobby, different
  versions (from lobby data, before connecting), a host that never answers
  (given up after 20 s), connecting to your own account.

## The API we use (read from the installed extension)

`Steam` (engine singleton, 736 methods): `steamInitEx(app_id, embed_callbacks)
-> {status, verbal}` (0 ok, 2 no Steam client, 3 version mismatch),
`loggedOn`, `run_callbacks`, `steamShutdown`, `getSteamID`, `getPersonaName`,
`getFriendPersonaName`, `getAppID`, `getLaunchCommandLine`, `createLobby(type,
max_members=2)`, `joinLobby`, `leaveLobby`, `setLobbyData`, `getLobbyData`,
`setLobbyJoinable`, `getLobbyOwner`, `getNumLobbyMembers`, `inviteUserToLobby`,
`activateGameOverlayInviteDialog`, `isOverlayEnabled`, `setRichPresence`,
`clearRichPresence`, `initRelayNetworkAccess`, `getRelayNetworkStatus`,
`getFriendCount(flags)`, `getFriendByIndex`, `getFriendPersonaState`,
`getFriendGamePlayed -> {id, ip, game_port, query_port, lobby}`,
`getConnectionRealTimeStatus(handle, lanes, get_status)`.
Signals: `lobby_created(connect, lobby_id)`, `lobby_joined(lobby, permissions,
locked, response)`, `join_requested(lobby_id, steam_id)`,
`join_game_requested(user, connect)`, `lobby_chat_update`, `lobby_kicked`,
`steam_server_connected`, `steam_server_disconnected`.
Constants: `LOBBY_TYPE_PRIVATE = 0`, `LOBBY_TYPE_FRIENDS_ONLY = 1`,
`RESULT_OK = 1`, `CHAT_ROOM_ENTER_RESPONSE_SUCCESS = 1`.

`SteamMultiplayerPeer` (extends MultiplayerPeerExtension): `create_host(port=0)`,
`create_client(steam_id, port=0)`, `host_with_lobby`, `connect_to_lobby`,
`add_peer`, `get_peer(id) -> SteamPacketPeer` (`get_connection_handle`,
`get_steam_id`, `get_state`), properties `no_nagle`, `no_delay`,
`server_relay`, `debug_level`.

GodotSteam's own project settings (`steam/initialization/...`) stay at their
defaults (no auto-initialisation): the game initialises Steam itself.

## Installing GodotSteam

```bash
python tools/steam/fetch_godotsteam.py
```

It downloads `godotsteam-4.23.2-gdextension-plugin-4.4.zip` (28,292,972 bytes)
from https://codeberg.org/godotsteam/godotsteam/releases (tag v4.23.2-gde),
checks its SHA-256 (`0c935ac8...e414`, pinned in the script), and installs only
the Windows x86_64 pieces into `addons/godotsteam/`: a trimmed
`godotsteam.gdextension`, the debug and release libraries,
`steam_api64.dll` and the MIT licence. Then run Godot once with `--import`.

- The licence is MIT. Valve's `steam_api64.dll` carries a valid Valve Corp.
  signature; the GodotSteam libraries are unsigned (open-source builds).
- The manifest requires Godot 4.4 or later. It loads in 4.7.2 without
  warnings.
- The zip's editor "updater" plugin is left out (it checks the internet).
- `addons/godotsteam/` is gitignored (27 MiB of binaries). The game builds and
  runs without it.

## The App ID

- The project has **no** Steam App ID configured (`kindled/steam/app_id` unset),
  so a release build offers LAN / direct IP only.
- Valve's Spacewar (480) works in debug builds through `-- steam_appid=480`, for
  local experiments only. Release builds refuse it, and
  `tools/dev/release_check.py` fails if it is set in the project. Never
  distribute a build configured as Spacewar. No `steam_appid.txt` is needed or
  shipped: the App ID is passed to `steamInitEx`.
- A real App ID needs a Steamworks partner account and the app fee. Nothing has
  been registered or purchased.

## Windows builds

```bash
GODOT=... tools/dev/build_windows.sh release
GODOT=... tools/dev/build_windows.sh debug
```

The two builds go to `builds/windows-release/` and `builds/windows-debug/`
(gitignored). The script:

1. runs the release check;
2. exports with the official 4.7.2 templates (installed, SHA-512 checked
   against the release's `SHA512-SUMS.txt`);
3. checks the result.

The checks:

- the GodotSteam library (`libgodotsteam.windows.template_<mode>.x86_64.dll`)
  and `steam_api64.dll` sit beside `KindledDeep.exe`;
- no `steam_appid.txt` is there;
- no licensed sound file is listed in the embedded pack.

Checked on 2026-11-03:

- **Release build** (114 MB exe plus the two DLLs): run headless, with
  `APPDATA` pointed at a scratch folder so the real save could not be touched.
  It starts without script errors, GodotSteam loads, and with no App ID it
  offers LAN. The dev args `godmode rich profile=x.json` were ignored.
- **Debug build**: the bot played depth 1 at 165 fps. The capture was
  viewed. With `steam_appid=480` and Steam closed it reported "Steam is not
  running" and fell back to LAN. With Steam running, the Steam self-test passed
  inside the exported build.
- **Found by the first build:** `src/data/looks.gd` preloaded the palette from
  `tools/art/`, which exports leave out, so the exported game could not start.
  The palette moved to `src/render/pal.gd`, and the release check now fails if
  game code uses `tools/`, `tests/`, `docs/` or `captures/`.
- The licensed creature sounds are left out of exports by default. Include them
  only after checking that their licence allows shipping them inside a game.

## Dev arguments for Steam (debug builds only)

- `steam_appid=480`: run as Spacewar.
- `steamtest`: the self-test. It opens a private lobby without rich presence,
  checks its data and owner, starts a host peer, leaves, and quits with
  PASSED / FAILED.
- `net=steamhost`: host a private lobby.
- `net=steamjoin:<steam id>`: connect straight to a host's Steam ID.
- `localid`: use the profile identity instead of the Steam ID (two processes on
  one account).

## What was tested with Steam (one PC, one account, Spacewar)

| Check | Result |
|---|---|
| `steamInitEx(480)` with Steam closed | status 2, "Steam is probably not running" - the game says so and offers LAN |
| `steamInitEx(480)` with Steam running | ok; persona, Steam ID, App ID 480, relay access requested |
| Private lobby: create, set/get data, owner, member count, leave | passed (`steamtest`, editor and exported debug build) |
| `SteamMultiplayerPeer.create_host` in a session | connected, unique id 1; ran a hosted session in the hub |
| Friends list (online friends, game played, lobby) | read; nobody was invited (an invite messages a real friend) |
| Overlay | not available when the game is not started by Steam (`isOverlayEnabled` false); the in-game friends list is the fallback |
| A second process joining | not possible on one account: Steam does not connect an account to itself (the attempt never completes; the game now refuses it with a message) |
| Quit with Steam running | **crashed** at first (Steam shut down under a live Steam peer); fixed: the peer is closed first |
| A Steam client before the host answers | sent messages to an unknown host; fixed: `Net.active()` waits for the host; a host that never answers is given up after 20 s |

## What is still blocked

- **A second Steam account on a second PC.** Joining, invites end to end,
  "Join game", `+connect_lobby`, latency over Valve's relay, drops and
  rejoining over Steam all need it.
- **Starting the game through Steam.** The overlay and launch-from-invite
  need the game started by Steam: either a real App ID with the build uploaded
  to Steam, or the exe added as a non-Steam game. The latter changes your
  Steam library, so it was not done here.
- **A real App ID.** It needs a Steamworks partner account. A release build
  has Steam play off until one is set.

## Testing across machines

Run each step with the network overlay on (F3) and keep the console logs (the
`[net]` and `[steam]` lines).

### LAN (two PCs on one network)

1. PC A: Play Together, "Host"; the party screen shows the address
   ("Show connection details").
2. PC B: Play Together, "Join by Address", that address, "Join". A proposes an
   expedition at the gate; B answers Ready (Y); the party goes down. (The full
   two-PC pass, sanctuary to stairs, is in docs/TESTING.md.)
3. Play a floor together: watch B's own Kindled (should feel immediate),
   A's Kindled on B's screen and foes (smooth, ~60-100 ms behind), hits and
   sounds on both, the overlay's prediction error and loss.
4. Shop, pact, Echo, Well, chest relic picks from B; votes for the stairs and
   the Hearthstone from both sides; a Trial vote turned down by one player.
5. Pull B's network cable for 10 s mid-fight, plug it back: B should take its
   seat back. Pull it for 70 s: the seat should be given up and B should bank
   its checkpoint after its 30 s of trying.
6. Close A mid-floor: B should try for 30 s, then bank its depth checkpoint.
7. Finish a run (victory or wipe): both settle, each into its own profile.

### Internet without Steam

Same as LAN, with the host's UDP port 24565 forwarded (or a LAN-style VPN).
Record the overlay's round trip, jitter and loss; compare with the simulated
table in NETWORK.md.

### Steam (two Steam accounts on two PCs; debug builds with `steam_appid=480`)

1. A: Play Together, "Host" (with Steam running it hosts on Steam). B: "Join a
   Friend" and pick A, or accept A's invite (party screen > "Invite friends" >
   Invite).
2. B joins from A's "Join game" in the Steam friends list (rich presence).
3. Private lobby (`net=steamhost` on A): B can join only by invite.
4. Different builds (bump `application/config/version` on one side): B must be
   told both versions and not join.
5. The drop/rejoin and host-loss steps from the LAN list, over Steam.
6. Players on different networks: Steam's relay should connect them without port
   forwarding; record the overlay's figures (the host overlay shows Steam's ping).

Only when these pass can Steam play be called working.
