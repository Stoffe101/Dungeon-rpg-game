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
  - *Steam* (`SteamMultiplayerPeer` through GodotSteam, Steam Networking
    Sockets with Valve's relay: no ports to open). Optional: the game runs
    without GodotSteam. See [STEAM.md](STEAM.md).
  - *Solo* has no peer at all; every co-op path checks `Net.active()`.
- **Deterministic floors**: every peer builds the same floor from the run seed
  (`DungeonGen` uses only the passed RNG). Props built from the layout share an
  index (`Prop.net_idx`); props made later are announced (`prop+`).

## What crosses the wire

| Message | Direction | Rate / channel | Content |
|---|---|---|---|
| input (`_n_input`) | client -> host | every frame something changes, at least 60/s; unreliable, ordered | sequence id, move, aim, aim point, attack held, press counters (a lost packet never loses a press), measured round trip, attack hold time, where the client's prediction stood |
| snapshot (`_snapz`) | host -> each client | 30/s; unreliable, ordered; zstd chunks below one packet | floor id, host clock, chunk counter; actor rows that changed near that client (each refreshed every half second); every Kindled's HUD state; nearby shots and moving pickups; for the receiving client: the newest input the host has applied and for how long |
| events (`_events`) | host -> clients | every frame something happened; reliable | spawns and removals, prop changes, seals, rooms, telegraphs, effects, positional sounds, banners and toasts, votes |
| ask / offer / tell | both | reliable | a guest's requests (interact, buy, pact, vote...) and the host's answers |
| ping / pong | client <-> host | twice a second | round trip and jitter for the overlay and lag compensation |
| hello / roster / ready / rejoin / checkpoint / run end | both | reliable | joining (protocol and game version checked), the party, readiness, returning after a drop, settlement |

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

## Joining, readiness, transitions, drops

- `_hello` carries the protocol and game version; different builds are refused
  with a message naming both versions.
- Guests mark themselves ready in the Descent; the host leads the way once
  everyone is.
- **Floors start together**: every message names its floor; a guest keeps what
  arrives before it has built the floor and replays it; the host holds a new
  floor until every guest is ready (at most 10 s).
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
- **Sealing**: when a room seals, any player outside it is drawn in.

## Code map

- `src/net/net.gd` (`Net`, added by Game at /root/Net): transport, roster,
  RPC endpoints, simulated conditions, link statistics, seats and rejoining.
- `src/net/net_run.gd` (`NetRun`, one per floor): host snapshots and events,
  remote input, votes, world dump; client interpolation, prediction record,
  reconciliation.
- `src/net/party.gd` (`Party`): interaction ownership, the host side of every
  guest interaction, guests' screens, votes on screen.
- `src/net/steam_link.gd` (`SteamLink`): Steam lobbies and invites.
- `src/ui/net_diag.gd` (`NetDiag`): the overlay and `netlog`.
- `Player.controller` is LOCAL, REMOTE (host side of a guest) or REPLICA
  (client side); `Player.predicting` marks a client's own Kindled.
- Dev: `net=host`, `net=join:<ip>`, `name=`, `coop=<n>` (the host starts when n
  are in and ready), `coopdive` (vote down a depth, then vote a Hearthcall),
  `netsim=`, `netlog=`, `netdiag`, `steam_appid=` (debug builds only).

## Verified so far

All on one Windows machine, separate processes, localhost:

- 2 players under every simulated condition from local to stress (table
  above), and 4 players (3 clients on typical, moderate and stress links at
  once): same floor everywhere, no script errors.
- Votes (stairs, Hearthcall) passed with a guest agreeing over a simulated
  60-100 ms link; both settled the same outcome and each banked its own share.
- A guest killed mid-run and restarted with the same profile took its seat
  back and kept playing with its run.
- The host quitting mid-floor: the guest banked its depth checkpoint.

Not verified: two machines, a real internet route, Steam (GodotSteam is not
installed here), a human at the controls.
