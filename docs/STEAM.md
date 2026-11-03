# Steam play, builds, and cross-machine testing

Status (2026-11-03): the Steam layer (`src/net/steam_link.gd`) is written and
reaches GodotSteam dynamically, but **GodotSteam is not installed in this
project and none of the Steam path has run yet**. LAN / direct IP play is the
verified path (localhost, see NETWORK.md). Do not call Steam play working until
the checks at the end of this file have passed on real machines and accounts.

## What the game does with Steam

- **Lobbies**: "Host on Steam" opens a friends-only lobby (private is one flag
  away: `SteamLink.host_lobby(false)`) for four. Its lobby data carries the
  game's marker, protocol and version, the host's name, the region, tier and
  Omens, the party size and whether everyone is ready.
- **Invites**: "Invite friends" opens the Steam overlay's invite dialog. Friends
  join from the invite, from "Join game" in their friends list (rich presence
  `connect` = `+connect_lobby <id>`), or by launching with `+connect_lobby <id>`.
- **Transport**: `SteamMultiplayerPeer` (Steam Networking Sockets, relayed by
  Valve: no port forwarding, the IP addresses stay private) under the same
  `Net` code as ENet. The client connects to the lobby owner's Steam ID.
- **Identity**: the Steam ID is the player's identity (a dropped guest's seat
  waits for the same Steam ID). Names default to the Steam persona name.
- **Errors**: Steam not running or not logged in, no App ID configured, the
  lobby gone / full / not ours, different versions (checked from lobby data
  before connecting), and the host's own messages from `_hello`.

## Installing GodotSteam (needs your go-ahead: it is a download)

Researched 2026-11-03 (the GitHub repositories are archived; development moved
to Codeberg):

- Asset: `godotsteam-4.23.2-gdextension-plugin-4.4.zip`, 27 MiB, from
  https://codeberg.org/godotsteam/godotsteam/releases (tag v4.23.2-gde),
  "Godot 4.4+ - Steamworks 1.65", MIT licence. One zip for Windows, Linux,
  macOS and Android.
- The standalone MultiplayerPeer repository is retired: its code "has been
  merged into the main GodotSteam 4.x branch". Whether this GDExtension zip
  registers `SteamMultiplayerPeer` could not be confirmed from the web pages;
  check `ClassDB.class_exists("SteamMultiplayerPeer")` after installing. If it
  does not, the custom-editor builds on the same page (for Godot 4.7.2) do.

Steps once approved:

1. Unpack the zip into the project root (it adds `addons/godotsteam/` and a
   `.gdextension` file). Keep it out of git unless the licence and size are fine
   for the repository (MIT is fine; 27 MiB of binaries may not be).
2. For local experiments only: run with `-- steam_appid=480` (debug builds),
   or put the game's own App ID in the project setting `kindled/steam/app_id`.
   Steam must be running and logged in. Steam may also want a `steam_appid.txt`
   beside the executable when the game is not started by Steam; never ship it.
3. Run `--import`, then the game: the party screen shows "Steam: signed in as
   ..." and the Steam buttons. Without GodotSteam it says Steam play is not
   part of the build and offers LAN / direct IP only.
4. Check the method names against GodotSteam's docs for the installed version
   (steam_link.gd is the only file that calls them): `steamInitEx`,
   `run_callbacks`, `getSteamID`, `getPersonaName`, `getFriendPersonaName`,
   `createLobby`, `setLobbyJoinable`, `setLobbyData`, `getLobbyData`,
   `getLobbyOwner`, `joinLobby`, `leaveLobby`, `activateGameOverlayInviteDialog`,
   `setRichPresence`, `clearRichPresence`; signals `lobby_created`,
   `lobby_joined`, `join_requested`; `SteamMultiplayerPeer.create_host(port)`
   and `create_client(steam_id, port)`.

The overlay may not appear when running from the editor; test invites from an
exported build started through Steam.

## The App ID

- The project has **no** Steam App ID configured (`kindled/steam/app_id` unset).
- Valve's Spacewar (480) is for local experiments only. `SteamLink` refuses it
  in release builds, and `tools/dev/release_check.py` fails if it is set in the
  project. Never distribute a build configured as Spacewar.
- A real App ID needs a Steamworks partner account and the app fee. Nothing has
  been registered or purchased, and nothing will be without your explicit say.

## Windows builds

- `tools/dev/build_windows.sh [debug]` runs the release check, then exports the
  "Windows Desktop" preset into `builds/windows/` (gitignored).
- It needs the Godot 4.7.2 **export templates**, which are not installed on this
  machine (Editor > Manage Export Templates > Download and Install; about
  1 GB, so also your call). The script stops with that message until then.
- A **release** export ignores dev arguments (`Dev.args()`), grants no testing
  stockpile (`Profile.stockpile()`), refuses Spacewar, and leaves out the
  licensed sound pack and any `steam_appid.txt` (preset exclude filter). A
  **debug** export keeps the dev switches, for testers.
- The licensed creature sounds (`assets/audio/licensed/`) are excluded from
  exports by default. Include them only after checking that their licence
  allows shipping them inside a game build.
- A Steam build also needs GodotSteam's library files next to the executable
  (the GodotSteam extension DLL and `steam_api64.dll`; the exact file names
  depend on the release - check the zip).

## Testing across machines

What has been verified is listed in NETWORK.md ("Verified so far"): all on one
machine. This is the plan for the rest. Run each with the network overlay on
(F3) and keep the console logs (`[net]` lines).

### LAN (two PCs on one network)

1. PC A: party screen, "Host (LAN / IP)"; note the address it shows.
2. PC B: enter that address, "Join IP". Both: Descent; B "Ready"; A descends.
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

### Steam (after installing GodotSteam, two Steam accounts, two PCs)

1. A: "Host on Steam" (friends-only). B sees A "in game"; B joins from the
   friends list. Then: A invites B through the overlay; B accepts.
2. B quits; A invites again; B launches the game from the invite
   (`+connect_lobby`).
3. Private lobby: B can join only by invite.
4. Different builds (bump `application/config/version` on one side): B must
   be told both versions and not join.
5. Steam not running on B: the party screen says so; LAN still works.
6. The drop/rejoin and host-loss steps from the LAN list, over Steam.
7. Players on different networks / countries: Steam's relay should connect them
   without port forwarding; record the overlay's figures.

Only when these pass can Steam play be called working.
