# Co-op networking

Up to four Kindled in one expedition. Each player keeps their own profile,
sanctuary, gear and Hearthtree; the expedition is shared. Steam setup and the
cross-machine test plan are in [STEAM.md](STEAM.md).

## Model: host-authoritative, predicted locally

- **One simulation**: the host runs the dungeon exactly as single-player does
  (AI, combat, damage, loot, rooms, bosses). Clients never decide an outcome.
- **Transports** (`Net.use_peer`, the same game code above either):
  - *ENet* (`ENetMultiplayerPeer`, UDP port 24565): LAN and direct IP. Over the
    internet the host forwards the port, or everyone joins one LAN-style VPN.
  - *Steam* (`SteamMultiplayerPeer` through GodotSteam 4.23.2, Steam
    Networking Sockets with Valve's relay: no ports to open). Optional: the
    game runs without GodotSteam, without Steam running and without an App ID
    (LAN / direct IP). Lobbies and a hosted session verified on one account;
    joining needs a second account. See [STEAM.md](STEAM.md).
  - *Solo* has no peer at all; every co-op path checks `Net.active()`.
- **Deterministic floors**: every peer builds the same floor from the run seed
  (`DungeonGen` uses only the passed RNG). Props built from the layout share an
  index (`Prop.net_idx`); props made later are announced (`prop+`).

## What crosses the wire

| Message | Direction | Rate / channel | Content |
|---|---|---|---|
| input (`_n_input`) | client -> host | every frame something changes, at least 60/s (and at once when the facing turns more than 0.3 rad); unreliable, ordered | the floor it belongs to, sequence id, move, aim, aim point, attack held, press counters (a lost packet never loses a press), measured round trip, attack hold time, where the client's prediction stood, and (protocol 7) the way its Kindled faces (`look`, indices 13-14: the host draws a guest's Kindled turned the way its owner sees it, instead of guessing from its movement) |
| snapshot (`_snapz`) | host -> each client | 30/s; unreliable, ordered; zstd chunks below one packet | floor id, host clock, chunk counter; actor rows that changed near that client (each refreshed every half second); every Kindled's HUD state; nearby shots and moving pickups; for the receiving client: the newest input the host has applied and for how long |
| events (`_events`) | host -> clients | every frame something happened; reliable | spawns and removals, prop changes (a landmark's answer travels as its prop state: anim, used, lit), seals, rooms, telegraphs, effects (urn debris included), positional sounds, banners and toasts, votes, `look` (the camera leaning toward an arriving guardian) |
| ask / offer / tell | both | reliable | a guest's requests (interact, buy, pact, vote...) and the host's answers |
| ping / pong | client <-> host | twice a second | round trip and jitter for the overlay and lag compensation |
| hello / roster / where / rejoin / checkpoint / run end | both | reliable | joining (protocol and game version checked), the party (and where each one is: menu, sanctuary, below, summary), returning after a drop, settlement |
| sheet (`_sheet`, roster) | both | reliable, on change | a player's character sheet: gear, wardrobe choices, look, weapon, skills (live: everyone redraws that Kindled) |
| proposal (`_propose` / `_answer` / `_withdraw` / `_proposal`) | both | reliable | the party's expedition proposal and each answer (see "Expeditions") |
| camp / hub poses (`_camp`, `_hub_pose`, `_hub_world`) | both | camp reliable; poses 20/s unreliable | the shared sanctuary (see "The sanctuary") |

Floats are rounded to 1/64 (exact in 32 bits). Each client gets its own
snapshot: actors farther than 26 tiles from its Kindled are left out (bosses
and the party never are), and an unchanged row is not sent again until its
half-second refresh.

## Responsiveness

- **Prediction** (`Player._predict`): a client's own Kindled moves, turns,
  dodges, wards, drinks, casts (the stance) and swings the moment it is asked,
  through the same movement code the host uses. Weapons run in a *predicting*
  mode: timing and picture only, no hits (the host deals every blow). Lunges
  and the spear, dagger and hammer moves are predicted as movement.
- **Reconciliation** (`NetRun._reconcile`): the host reports which input it last
  applied and for how long; the client compares its own record of that moment
  and moves by the difference. Small differences are smoothed out of the
  picture over ~100 ms (`Actor.draw_off`); a difference over 2.5 tiles (a pull
  into a sealed room, a teleport) is a jump.
- **Agreement**: packet timing makes host and client disagree by about a frame
  of walking per input. Each input carries where the client's prediction stood;
  the host moves the remote Kindled toward it by at most 0.12 tiles, only along
  a clear path and never while something is shoving it. This removes timing
  drift without letting a client move itself (anything larger stays the host's).
- **Interpolation**: everything else is drawn about 60-100 ms in the past,
  between the two snapshots around that moment, on a host clock estimated from
  the fastest packets (`_note_clock`). The delay adapts to the measured jitter.
- **Events every frame**: hits, sounds and effects go out the frame they
  happen (they used to wait for the next 20 Hz snapshot).
- **Shared clock**: in a party, one Kindled's hitstop or slow motion no longer
  freezes the world for everyone (it also kept clients' predictions honest).
- **Whose effect is it**: another Kindled's screen shake and camera kicks stay
  on their screen; their own sounds are heard from where they stand; their
  particles are drawn at the "Allies' effects" setting (60% by default); what
  your prediction already showed you is not sent back to you.

## Lag compensation

- **Dodge and Ward**: a remote Kindled's owner sees each blow a round trip late.
  A blow that would land on them waits `lag_grace` (their round trip + 50 ms,
  at most 250 ms) for a dodge or Ward already on its way; if one arrives the
  blow is turned (a perfect dodge when it comes in time, a Ward) as it was on
  the owner's screen. Counted per player ("late saves" on the host overlay).
- **Bow timing**: the host lines the draw up with how long the owner actually
  held the button (their clock), within 0.15 s.
- **Telegraphs** arrive as events the moment they start, with their remaining
  time, so a client sees the warning as early as the network allows.

## Diagnostics and simulated conditions

- `F3` (or the `netdiag` dev argument) shows the network overlay: round trip
  and jitter, traffic, snapshot rate and loss, how far behind the floor is
  drawn, and prediction error (average, untouched, worst) with corrections per
  second. The host sees each client's link (ENet round trip, loss, throttle)
  and how many blows lag compensation turned.
- `netsim=<preset>` or `netsim=<rtt_ms>:<loss_pct>[:<jitter_ms>]` makes this
  machine (a client) delay and drop its own traffic both ways, half the round
  trip each way. Presets: `local excellent typical moderate difficult stress`.
  `netlog=<file>` writes the per-second figures and averages as JSON.
- `tools/dev/netsim_matrix.sh [frames] [presets]`: a host and a client (bots,
  separate processes, seed 7) per condition, then a table
  (`tools/dev/netsim_table.py`). `tools/dev/coop_local.sh <n> [frames] [netsim per client]`:
  n real processes with per-client conditions.

## Measured (localhost, separate processes, simulated conditions)

| Condition (sim) | RTT measured | Drawn behind | Snapshot loss | Down KB/s | Up KB/s | Pred. error p50 / p95 (tiles) | avg untouched | Slides/s | Jumps/s |
|---|---|---|---|---|---|---|---|---|---|
| local (5 ms, 0.0%) | 21 ms | 64 ms | 0.0% | 28.0 | 9.5 | 0.014 / 0.058 | 0.114 | 3.0 | 0.07 |
| excellent (30 ms, 0.0%) | 44 ms | 64 ms | 0.0% | 28.8 | 9.6 | 0.011 / 0.477 | 0.102 | 2.8 | 0.09 |
| typical (60 ms, 0.5%) | 74 ms | 64 ms | 0.6% | 28.0 | 9.5 | 0.024 / 0.503 | 0.129 | 6.1 | 0.11 |
| moderate (100 ms, 1.0%) | 113 ms | 76 ms | 1.2% | 28.3 | 9.4 | 0.022 / 0.082 | 0.077 | 6.2 | 0.06 |
| difficult (150 ms, 2.0%) | 168 ms | 83 ms | 2.0% | 27.4 | 9.2 | 0.046 / 0.196 | 0.103 | 10.3 | 0.06 |
| stress (200 ms, 5.0%) | 223 ms | 104 ms | 4.9% | 28.3 | 9.0 | 0.053 / 0.240 | 0.163 | 11.5 | 0.07 |

Four players at once (host + 3 guests, one each on typical, moderate and stress
links, 7000 frames): every guest on the same floor, no script errors; guests
measured 73 / 116 / 218 ms round trips, drawn 68 / 79 / 101 ms behind, 37 KB/s
down each, prediction error p50 0.03-0.07 tiles. Two machines' worth of upload
for the host: about 3 x 37 KB/s.

Performance with four players (real windows, RTX 5070, 165 Hz monitor): the
host at 3440x1440 held 164-165 fps (up to 16 actors, 300 particles); a guest at
1920x1080 held 165 fps (up to 19 actors). The other three ran headless.

- *RTT measured* includes frame alignment: each hop waits for the next frame's
  network poll.
- *Prediction error* is the distance between where the client predicted its
  Kindled and where the host had it, for the same input and moment, before any
  correction (both bots fight, so shoves from foes and pulls into sealed rooms
  are included). p50 and p95 are per second, averaged over the run; p95 varies
  a lot from run to run (0.06-0.5 tiles over repeated runs) because it is the
  shoves. One tile is 16 pixels at the game's resolution.
- *Slides* are corrections smoothed out of the picture; *jumps* are snaps
  (pulls into sealed rooms).

What these numbers are **not**: a real internet route. The simulator delays
and drops packets on one machine; it does not reproduce routers, congestion,
NAT or Steam's relay. Lag-free play is not claimed from these numbers.

## Interactions and ownership

See `Party` (src/net/party.gd) and DESIGN.md, "Co-op interactions".

- Personal: the Cinder Merchant (own stock, own Embers), the shrine of pacts
  and the Echo (one bargain each), lore.
- Shared: the Ember Well (first come; the drawer pays the health), lost camps,
  sconces, chests (and each Kindled gets their own relic pick from a chest),
  Embers, memories, materials and Sunshards (credited to everyone's run).
- Instanced: gear, blueprints and runes drop once per player (only the owner
  sees and collects theirs); relic altars give each player their own pick.
- Voted (everyone present agrees within 30 s; one "not yet" ends it): the
  stairs, the Hearthstone, the Trial, a completed Hearthcall.

Every request is checked against that Kindled's own state (sold, spent, taken,
already voted, distance), so a repeated request changes nothing.

## Progression and settlement

- Each Kindled has a RunState on the host. At the end the host sends each
  guest its own settlement (`_run_end`): their loot and relics, the party's
  shared figures, the party's kills (bestiary and stats), guardians felled
  (world records such as the Ashen King), their own Grudges settled, and their
  own killer on a wipe. The guest banks it into its own profile.
- Every expedition has a run id; a profile remembers the runs it banked
  (`settled_runs`, save v10) and never banks one twice.
- Guests' Grudges come with their character sheets: the host picks a Grudge
  among the whole party's; a slain Grudge is settled for its owner.
- **Checkpoint**: as each floor begins the host sends each guest its run so far.

## The sanctuary (shared)

The party walks the **host's camp** together (`HubSync`, src/net/hub_sync.gd):

- A guest's sanctuary is built from the host's camp description
  (`Hub.camp_of_profile`: buildings, Hearth level, residents, garden, trophies,
  feat lanterns, the cat), sent when they join and whenever it changes. Joining
  or leaving a party rebuilds the guest's sanctuary in place (a short fade).
- Each machine moves its own Kindled itself (nothing here to predict) and sends
  where it stands, its animation, look and weapon pose 20 times a second; the
  host passes every pose on, with its residents' and the cat's positions (10/s).
  Everyone else is drawn 100 ms in the past between two poses.
- Personal things stay personal: the Hearthtree, forge, smithy, peddler,
  satchel, wardrobe and residents' requests open the local profile. A guest at
  the host's ruined forge uses (or rebuilds) their own; a resident a guest has
  not met at home greets them as the host's guest instead of offering a request.
- Other players' Kindled never block yours: they ease you aside while you stand
  in them, and you walk through them.

## Expeditions (proposals)

Anyone in the party proposes from the Undervault Gate (region, tier, Omens);
the host keeps the one proposal (`Expedition`, src/net/expedition.gd):

- Everyone else gets a request card at the side of the screen, wherever they
  are (walking the camp, in the satchel, at the Hearthtree). It shows who
  proposed what, and every Kindled's answer as it comes in (Ready / Not now /
  Deciding, and where they are). Y / N (pad: D-pad up / down) or the buttons
  answer it; it never pauses or takes focus.
- The proposer counts as ready. When every member present is ready, a 3 s
  countdown runs (anyone can still say Not now), then the host leads the party
  down. The proposer (or the host) withdraws it with N or Cancel; proposing
  again replaces it and asks everyone again. One proposal at a time; someone
  leaving drops out of it, the proposer leaving ends it; it lapses after 4 min.
- The same card carries the votes below (stairs, Hearthstone, Trial,
  Hearthcall). Anyone standing at the stairs or Hearthstone when a vote starts
  counts as agreeing.

## Joining, transitions, drops

- Protocol 6 (evolution pass): the input presses include the third spell
  (`a3`); every Kindled's row carries its Kindle maximum (27), third cooldown
  (28) and Momentum (29, so a guest's predicted swings keep the host's pace);
  shots carry their velocity (returning, chaining and forked shots turn); an
  actor that glows (the Hearth Lantern) sends its light with `actor+`; a
  Kindled's rare find is told to the rest of the party as a toast (`not`).
  Guests' XP is booked live on their own machine (`Profile.live_xp`) and only
  the rest is added at settlement (`xp_still_owed`), so nothing counts twice.
- `_hello` carries the protocol and game version; different builds are refused
  with a message naming both versions.
- **Floors start together**: every message names its floor; a guest keeps what
  arrives before it has built the floor and replays it; the host holds a new
  floor until every guest is ready (at most 10 s).
- **Floor ids are per expedition** (`expedition * 1000 + depth`), and input
  names its floor too. A client still on the floor the party just left keeps
  sending input (and counting its sequence numbers) until it has built the next
  one; before this, the host applied those numbers to the new floor's Kindled,
  which then dropped every real input as "old" - frozen on everyone else's
  screen for as long as the last floor had lasted, while it walked normally on
  its own (the playtest's "frozen after the stairs"). A client also reports an
  acknowledgement for input it never sent (`bad_ack` on the overlay).
- **A guest drops**: its seat waits 60 s; its Kindled waits where it stands,
  untouchable; votes and floor barriers go on without it. The same identity
  (profile identity, or Steam ID) joining again takes the seat back, with its
  run, gear on the ground, shop stock and bargains, and gets a dump of the
  floor as it is now. ENet notices a dead link within 3-8 s.
- **The host is lost**: the guest keeps the floor (frozen) and tries to reach
  the host again for 30 s ("Give up" stops early). If that fails it banks its
  checkpoint (what it carried into the current depth) as from a Hearthcall.
- **Pause in co-op**: menus never pause a shared world; each player's screens
  are their own.
- **Downed and wipe**: at 0 health a Kindled is downed for 25 s; standing beside
  them for 2.5 s revives at 40%. Bleeding out leaves them a spectator until the
  room is cleared or the party descends. Everyone down ends the run (each
  settles as a death, with their own killer).
- Host migration is **not** implemented: the host's machine runs the world.
  The checkpoint keeps a lost host from costing guests everything.

## Co-op rules

- **Targeting**: foes pick the nearest active Kindled, keep a target for a
  while, and turn on whoever hits them hard.
- **Scaling** (per extra player): foe health +35%, about 30% more foes per
  wave, boss health +50%. Never four times anything.
- **Sealing**: when a room seals, any player outside it is drawn in by the
  light - to just inside the door the fight began from (beside whoever started
  it), on floor reached from that door, a tile in from the room's edge, with
  open ground around, clear of props, pits, hazards, foes and each other
  (`Dungeon.regroup_spots`), briefly untouchable. They are told who drew them.
- **New floors** place the party on open floor in plain view (`party_spots`):
  never just north of a pillar or wall, where the camera would show only a
  silhouette.

## Code map

- `src/net/net.gd` (`Net`, added by Game at /root/Net): transport, roster,
  RPC endpoints, simulated conditions, link statistics, seats and rejoining.
- `src/net/net_run.gd` (`NetRun`, one per floor): host snapshots and events,
  remote input, votes, world dump; client interpolation, prediction record,
  reconciliation.
- `src/net/party.gd` (`Party`): interaction ownership, the host side of every
  guest interaction, guests' screens, votes on screen.
- `src/net/hub_sync.gd` (`HubSync`): the shared sanctuary.
- `src/net/expedition.gd` (`Expedition`): expedition proposals.
- `src/ui/request_card.gd` (`RequestCard`): the party's open question on screen.
- `src/ui/party_ui.gd` (`PartyUI`): hosting, joining, the party.
- `src/net/steam_link.gd` (`SteamLink`): Steam lobbies, invites, joining,
  link statistics; `tools/steam/fetch_godotsteam.py` installs GodotSteam.
- `src/ui/net_diag.gd` (`NetDiag`): the overlay and `netlog`.
- `Player.controller` is LOCAL, REMOTE (host side of a guest) or REPLICA
  (client side); `Player.predicting` marks a client's own Kindled.
- Dev: `net=host`, `net=join:<ip>`, `name=`, `coop=<n>` (the host proposes the
  expedition once n are in the sanctuary; bots and `autoaccept` answer it),
  `coopdive` (vote down a depth, then vote a Hearthcall),
  `netsim=`, `netlog=`, `netdiag`, `steam_appid=`, `steamtest`,
  `net=steamhost`, `net=steamjoin:<steam id>`, `localid` (debug builds only).

## Verified so far

**Playtest repair pass (2026-11-03): real windows, real input, every screen.**
Separate game processes on one PC over localhost ENet, each in its own window
with its own fresh dev profile and outfit, driven by `src/dev/scenario.gd` with
real key presses and clicks (docs/TESTING.md):

- **2 players, the whole journey**: 104 checks, 0 failures. Party screen host
  and join, the shared sanctuary, live gear changes, dialogue (F, mashing,
  Esc, click, a request accepted), proposal declined / withdrawn / accepted,
  depth 1 (foes drawn, a teammate drawn into a sealing room), depths 2 and 3
  with everyone walking on their own keys, a Hearthcall home, a second
  expedition. Pictures of each other: p50 0.00-0.05 tiles, nothing frozen.
- **4 players, the same journey**: 258 checks, 0 failures; every machine sees
  every other Kindled at p50 0.00-0.3 tiles on every floor, nothing frozen.
- **4 players with the guests on typical / moderate / stress links**: 256 of
  258 checks (the two failures were the scenario's own key-press budget on a
  longer Keeper conversation; fixed); nothing frozen.
- **Every foe on a guest's screen**: all 25 kinds, elites with all 8 affixes,
  a Grudge and the three guardians drawn whole (36 of 36), and gone when felled.
- **"Frozen after the stairs" reproduced, then fixed**: with the old input
  handling and a guest on a 100 ms link after 30 s on depth 1, the host saw the
  guest frozen 4-7 tiles from where it was (23 frozen windows; the guest logged
  "the host acknowledged input 1763, but only 4 were sent here"). With the fix,
  the same run: p50 0.01 tiles, nothing frozen.
- **Recovery**: a guest killed mid-floor and restarted took its seat back
  (same depth, its run); then the host killed: the guest banked the checkpoint
  it carried into the depth (this needed a fix: a guest who had rejoined had no
  checkpoint).

Earlier (bot-only), all on one Windows machine, separate processes, localhost:

- 2 players under every simulated condition from local to stress (table
  above), and 4 players (3 clients on typical, moderate and stress links at
  once): same floor everywhere, no script errors.
- Votes (stairs, Hearthcall) passed with a guest agreeing over a simulated
  60-100 ms link; both settled the same outcome and each banked its own share.
- A guest killed mid-run and restarted with the same profile took its seat
  back and kept playing with its run.
- The host quitting mid-floor: the guest banked its depth checkpoint.

- Steam on one account (Spacewar test App ID): initialisation, a private lobby
  (data, owner), a hosted session, clean quits, the LAN fallback without Steam
  or without an App ID - in the editor and in an exported debug build.
- The exported release and debug builds: GodotSteam and steam_api64.dll
  packaged and loading, no licensed sounds or steam_appid.txt, dev switches
  ignored in release; the bot playing depth 1 in the debug build.

Not verified: two machines, a real internet route, a second player joining
over Steam (needs a second Steam account on another PC), a human at the
controls. The human test plan is in docs/TESTING.md.

## Protocol 11 (living Undervault pass)

- **`_begin` carries `world`**: the host's Chronicle snapshot (`Chronicle.snapshot`:
  altars, whether a Grudge can keep a lair). Every machine's run holds it and
  every floor is generated from it (`DungeonGen.generate(..., world)`), so a
  guest's own altars never change what the party walks and a rejoin rebuilds
  the same floor. On a Fracture the floor's `fracture` region is added to it
  (deterministic from the depth).
- **`site:<event>:<choice>` votes**: a Hollow Altar's answers and a treasury's
  coffers are party votes; the card comes from `DeepEvents.ask`. Personal sites
  (the Pale Bowl) resolve for whoever used them, on the host.
- **`trial:procession`**: the Lost Procession's bier votes like a Trial.
- **`["wit", id]`** (host event): a guest marks in its own Chronicle that it
  witnessed something in the host's world; its world is untouched.
- **`["ping", peer, pos]`** (and `ask "ping"`): a mark on the floor and the map.
- A Grudge's dict (replicated in `_describe`) now carries `learned`, `slew`,
  `scars`; every machine draws its brand and name from it.
- `RunState` gained `world`, `pale`, `wounded`, `scars` (to/from_dict, so a
  rejoin and a settlement keep them).

## Protocol 10 (expedition evolution pass)

- **`_descend(depth, route)`**: the way down the party took (DungeonGen.ROUTES:
  `trial`, `vault`, `quiet`, or "" the plain way) rides with the descent;
  every machine builds the next floor for it (`DungeonGen.generate(..., route)`,
  seeded with the way's name). A rejoining guest gets it in `_rejoined`'s
  params (`route`) and in its run (`RunState.route` / `routes`).
- **The stairs vote names the way:** its kind is `stairs:<route>` (plain
  `stairs` still works); the card shows the way's name and line; the host
  descends by it when everyone agrees.
- **`["obj", text, k, colour]`** (host event): the room's task line on the
  HUD (seals left, the vault flame's strength); "" clears it. The seals are
  ordinary foes and the Vigil Lantern an ordinary prop on the wire.
- A sheet carries the Kindled's `tincture` ({id, rank}); the host pours a
  guest's draught (heal, barrier, haste, Kindle, cleansing) host-side.
- Reagents are finds of one's own (`kind` "reagent" through `_gift` /
  `bank_find`, banked once by drop id).

## Protocol 9 (playtest foundations pass)

- **Events for one peer:** an event recorded as `["own", peer, ev]` (a find
  of that guest's own: `pick+`, `pick-`) is sent to that peer alone - the
  host splits each frame's batch into the shared events (`rpc`) and one
  batch per guest (`rpc_id`). Other guests never receive another's find; a
  rejoining guest's `world_dump(peer)` holds only shared pickups and its own.
- **`_gift(floor, drop, kind, what, grade)`** (host -> one guest, reliable):
  a find the guest took, for its Satchel. The guest banks it once by drop id
  (`Profile.bank_find`, the save's `delivered` book), plays the find's moment
  and answers `Net.ask("gift_ok", [drop])`. The host keeps unacknowledged
  gifts per peer (`NetRun.gifts`), moves them with a rejoin and sends them
  again then and before `_run_end`.
- A guest's sheet now carries `known` and `scrolls` (blueprints are rolled
  against what that Kindled knows). A sheet that changes the weapon item
  re-arms that Kindled on the host below too (`Player.apply_sheet`).
- A guest at the title screen follows the host into camp when the roster
  says the host went in (`Net._follow_host`); nothing new on the wire.

## Protocol 8 (combat identity pass)

- Player rows gained index 30 (the weapon form's gauge, `form_meter`: heat,
  nocked arrows, glyphs, marks, a ready riposte) and index 31 (bits:
  Hearthfire Form 1, a Soulfire Beam pouring 2, Rekindle's haste 4). A
  guest keeps them alive a moment past each snapshot (`NetRun._spell_bits`);
  other Kindled's copies count them down themselves.
- The "tele" event carries the foe's net id as a ninth element, so a guest's
  copy of the foe glows through its wind-up.
- A guest predicts its own beam (slowed), Hearthfire (faster) and Cinder
  Orb recast (no cost); the host decides. Rimewall ice is a prop ("prop+")
  whose tiles become pillars on every machine; it melts as a prop removal.
