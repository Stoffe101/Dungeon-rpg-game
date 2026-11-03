# Co-op networking

Up to four Kindled in one expedition. Each player keeps their own profile,
sanctuary, gear and Hearthtree; the expedition is shared.

## Model: host-authoritative, replicated presentation

- **Transport**: Godot ENet (`ENetMultiplayerPeer`), default port 24565.
  LAN and direct IP. Internet play needs the host's port forwarded (UDP) or a
  VPN-style LAN (ZeroTier, Tailscale, Radmin); there is no relay or NAT
  punching yet. Do not claim internet play works from LAN tests.
- **One simulation**: the host runs the dungeon exactly as single-player does
  (AI, combat, damage, loot, rooms, bosses). Clients do not simulate gameplay.
- **Clients send input** (30 Hz, unreliable-ordered): movement, aim, aim
  point, attack held, and *press counters* for attack/dodge/ward/abilities/
  flask/hearthcall/interact, so a lost packet never loses a press.
- **Host sends**
  - *snapshots* (20 Hz, unreliable-ordered): every actor's position, height,
    facing, animation and frame, health, shield, flags; each player's HUD state
    (Kindle, flask, cooldowns, dodge charges, run Embers) and weapon pose;
    moving pickups; projectiles' positions.
  - *events* (reliable, batched per tick): actor/projectile/pickup spawns and
    removals, prop state changes, seals, rooms visited, telegraphs, effects
    (bursts, rings, shapes, numbers, splats...), positional sounds, banners and
    toasts, descend, run end.
- **Deterministic floors**: every peer generates the same floor from the run
  seed (`DungeonGen` uses only the passed RNG). Props built from the layout have
  the same index everywhere; props made later are announced with their index.
- **Clients render**: replicas are smoothed toward the latest snapshot. Each
  client's camera and HUD follow its own Kindled.

## Ownership and rewards

- **Players**: the host builds each remote Kindled from the client's
  *character sheet* (skills, equipped gear, sanctuary, resident gifts, look,
  weapon, abilities) - the same function builds the local Kindled, so stats
  match single-player exactly.
- **RunState per player**, owned by the host. At the end the host sends each
  client its own settlement, and the client banks it into its own profile
  through the normal `Game.end_run` path.
- **Shared**: Embers, memories (XP), materials and Sunshards - a pickup collected
  by anyone is credited to every player's run.
- **Instanced**: gear and blueprints - one roll per player, visible to and
  collectable by its owner only. Relic altars give each player their own pick.
- **Host-only interactions (for now)**: merchant, shrine of pacts, Ember Well,
  Trial altar, Echo, Hearthstone. Clients are told so.

## Co-op rules

- **Targeting**: foes pick the nearest living player, keep a target for a
  while, and turn on whoever hits them hard.
- **Scaling** (per extra player): foe health +35%, about 30% more foes per wave,
  boss health +50%. Never four times anything.
- **Sealing**: when a room seals, any player outside it is drawn in through the
  light, so nobody is shut out of a fight.
- **Downed**: at 0 health a Kindled is downed for 25 s; standing beside them
  for 2.5 s revives at 40%. Bleeding out leaves them a spectator until the room
  is cleared or the party descends (back at 30%). Everyone down ends the run.
- **Descending and Hearthcall** move the whole party.

## Code map

- `src/net/net.gd` - transport, roster, lobby, RPC endpoints (Game adds it at /root/Net).
- `src/net/net_run.gd` - per floor: host snapshot/event capture, client apply.
- `Stage.players` (every Kindled), `Stage.player` (this machine's);
  `Actor.net_id`; `Player.controller` (LOCAL, REMOTE, REPLICA).
- Dev: `net=host`, `net=join:<ip>`, `name=`, `coop=<n>` (host starts when n players are in), `coopdive`.

## Verified so far (real separate instances on one machine, localhost)

- 2 players: host and client enter the same seeded floor, fight the same scaled
  encounters, shared Embers credited to both, no script errors; descending to
  depth 2 together; a Hearthcall ends the run for both and the client banks its
  own share into its own profile; a client leaving mid-fight leaves the host
  running; the host leaving returns the client to its own sanctuary.
- 4 players (host + 3 clients): all join, enter the same floor, 16 actors on
  every machine, no script errors.

## Not verified / limitations

- LAN across two machines, the internet, slow or lossy networks, rejoining a
  run in progress (late joiners wait in the sanctuary).
- No client-side prediction: a client's own Kindled moves after a round trip
  (fine on a LAN; noticeable at internet latencies).
- Shapes whose size changes over time on the host (expanding boss rings) appear
  at their starting size on clients; telegraphs are replicated properly.
- Merchant, shrine of pacts, Ember Well, Trial, Echo and the Hearthstone are
  host-only for now. Clients see the host's toasts.
- Kills, Grudges and world records (boss kills, Memory) are recorded on the
  host's profile; clients bank their own run (Embers, XP, loot, runes, relics).
