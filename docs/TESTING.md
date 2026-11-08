# Testing Kindled Deep

The first real two-PC playtest found five game-breaking co-op bugs that every
automated test had passed. Each had a different cause, and all of them showed
on someone's screen. Unit tests and bots checked the host's simulation. Nobody
looked at the guest's picture, pressed the real keys, or stayed on a floor
long enough for a race to show. These are the rules that came out of that, and
the tools that make them cheap.

## Rules

For any change that touches co-op (networking, scenes, UI, input, anything a
guest draws):

1. Test the logic automatically (`tests/`, headless).
2. Run separate host and guest processes over the real network
   (`tools/dev/e2e.sh`). A second Kindled simulated inside one process does not
   count.
3. Drive them with real input: the bound keys and the mouse, through Input
   (`src/dev/scenario.gd`). Calling `prop.interact()` or `Game.descend()`
   directly skips the very paths that broke.
4. Capture every machine's screen at the same moment (`Net.dev_shot`), and look
   at the captures - each side's. The host's picture proves nothing about the
   guest's.
5. Check transitions: floors, the sanctuary and back, joining, leaving.
6. Use more than two players where it matters (`e2e.sh 4`).
7. Play a whole expedition: sanctuary, proposal, depths 1-3, home, again.
8. Run solo too (`tests`, `uismoke`, an autopilot run, `scenario=talk`).
9. Repeat under simulated links (`e2e.sh 4 journey typical moderate stress`):
   races between floors only show with latency.
10. Report what was and was not checked: unit-tested, run as separate
    processes, captured and viewed, played by a human. Do not call co-op
    working from one machine's logs.

Localhost is not the internet, and simulated links are not routers, NAT or
Steam's relay. A human pair on two PCs is still needed (see below).

## Tools

| Tool | What it does |
|---|---|
| `tools/dev/run_tests.sh` | Unit and simulation tests (headless). Fails on any script error. |
| `-- uismoke profile=smoke.json` | Opens every screen and presses its buttons, including synthetic gamepad checks, and checks every visible piece of each screen lies inside the window. Run it with `--resolution 1920x1080` / `3440x1440` and `set=ui_scale:2..4`. |
| `-- scaling profile=scaling_eval.json [seeds= secs= tier= depth= comps=]` | Party-size scaling: 1-4 bot Kindled with real builds (no godmode) fight through real floors in one process; prints and writes `user://scaling_eval.md` (room time, damage taken, downs, wipes, XP and Embers per room, each against solo). Measures the host's rules, not the network. |
| `-- build=<preset>` | Makes the dev profile a whole build (level, Hearthtree, spells, weapon): starter, knives, lantern, rush, hail, bulwark, frost (`src/dev/build_presets.gd`). |
| `-- hitlab cast=1,3,2` | Foes beside the Kindled, full Kindle, the spell slots cast in turn at the nearest foe (aim held for captures). `forge=0..3` sets the workshop's level. |
| `tools/dev/e2e.sh [n] [scenario] [netsim...]` | n real windows (host + guests), fresh dev profiles, distinct outfits, the scenario played on each. Prints every check, every failure and every script error, then runs the comparison. |
| `tools/dev/e2e_compare.py logs...` | From the `[probe]` lines: how far each machine's picture of every other Kindled is from where its owner had it, per sanctuary and floor (p50 / p95 tiles), and any FROZEN stretch (the owner walked more than 2 tiles in 2 s, the picture stayed put, and they ended apart). Teleports such as being drawn into a room are not counted. |
| `tools/dev/e2e_recovery.sh` | A guest killed mid-expedition and restarted (it must take its seat back), then the host killed (the guest must bank its depth checkpoint once). |
| `tools/dev/coop_local.sh`, `netsim_matrix.sh` | Bot-only co-op runs and the measured network table in NETWORK.md. |
| `-- showcol` | Every tile a Kindled cannot walk onto drawn red on the floor (pits blue), each Kindled's box green: compare footprints with the art. |
| `-- capture=<name> frames=N quit` | One capture of the real rendered window. F12 in play. |

### Scenarios (`-- scenario=<name> role=host|guest`)

- `journey`: the whole evening.
  - **Party and sanctuary.** Host and join through the party screen (real
    clicks), meet in the sanctuary, check each Kindled is drawn in its
    owner's armour, and hide a helm live.
  - **Talking.** Talk to the Keeper with F, by mashing F, with Esc and with a
    click, and accept a resident's request.
  - **The expedition.** Propose it at the gate; a guest declines, the host
    withdraws, proposes again, and everyone accepts with Y.
  - **Below.** On depth 1 every foe must be drawn and a sealing room draws
    in a teammate safely. At depths 2 and 3 everyone walks on their own keys
    while the others check they move.
  - **Home and again.** A Hearthcall home, then a second expedition.
- `bestiary`: the host raises every kind of foe beside the party (all 25
  kinds, elites of every affix, a Grudge, the three guardians), and fells them.
  Each guest checks every one was drawn whole and is gone afterwards.
- `stairs`: just the stairs with the dev party. `stay=30` stays on depth 1
  first. It found the "frozen after the stairs" race: the old code fails it
  under `netsim=moderate`.
- `talk`: the dialogue checks alone (solo).
- `partyhud` (with `DEVNET=1`): the party cards in the sanctuary and below
  (names, levels, health with numbers, Kindle), a fight, a downed guest with
  the bleed-out and revive line, and a level-up seen by every guest.
- `partyesc`: the party screen opened, hosted from, closed with Esc.
- `facing` (solo, or a party with `DEVNET=1`): each of W/S/A/D and the
  diagonals turns and animates the Kindled, stopping keeps the facing,
  attacking faces the pointer even walking away, a dodge faces its way; in a
  party every machine walks its own way and checks the others are drawn
  turned correctly, in the sanctuary and below.
- `spells` (`DEVNET=1 XARGS=build=wall` or `XARGS="build=pyreblade hitlab lab=husk,husk"`):
  the first guest casts on its own keys; every machine checks a Rimewall's
  ice and pillar tiles appear and melt, Hearthfire's glow on that Kindled,
  and the host's Emberforge heat on the guest's gauge.
- `landmark` (`DEVNET=1 XARGS=landmark`): the host brings the party to the
  floor's landmark, the first guest walks up and presses F, every machine
  checks the name over it, that it answered, and (Colossus) that every room
  is on its own map.

A scenario prints `[scenario] ok/FAIL ...` lines, `[probe] {...}` lines four
times a second, and ends with `[scenario] RESULT <role>: n passed, m failed`
(exit code 1 on a failure). Captures go to `captures/e2e/`.

`XARGS="..."` gives every process of `tools/dev/e2e.sh` the same extra dev
switches (`XARGS=landmark`: every floor has its landmark - every machine must
generate the same floor).

### Looking and listening tools (development pass)

- `-- urnlab`: a row of urns of each make, plain and glinting, beside the
  Kindled, struck one after another from 1.5 s; `-- proplab`: six kinds of
  dungeon objects around it, to read the labels; `-- landmark warp=landmark`: start beside the floor's
  landmark with its fight won.
- `-- audiorec=SECONDS`: records the Master, Music, SFX and Ambience buses to
  `user://audio_rec/` while you play (or the bot plays).
- `python tools/audio/analyze.py <wav...>`: length, peak, RMS, loudest 50 ms,
  crest factor, spectral centroid, share of energy below 120 Hz and above
  8 kHz, decay time, clipped samples. **This is measurement, not listening**:
  it finds clipping, mud and imbalance, not whether something sounds good.

### Tools of the playtest foundations pass

- `-- scenario=loot` (DEVNET=1, 2-4 players): the host drops one epic find
  beside each Kindled; every machine checks it draws only its own find (a
  guest is not even sent another's), walks to it, has it in the Satchel at
  once below, wears it with a real click, and that its save got exactly its
  run's XP; the host checks every run got the same XP and Embers and sees
  each guest wear their find.
- `-- legendlab profile=legend.json [secs=90 forms=thousandth_cut,...]`:
  how often signature weapon moments come in small fights, long fights and
  against one tough foe (report in `user://legend_lab.md`).
- `-- open=map explored` / `open=minimap explored`: the full map / minimap
  with every room walked; `open=spellpick`: the spell picker;
  `open=inventory saveload`: the Satchel with a saved loadout.
- The XP ledger: every machine writes `user://ledger/<run id>_<name>.jsonl`;
  `python tools/dev/ledger_compare.py host.jsonl guest.jsonl` shows where
  two players' gains part ways (Windows: %APPDATA%/Godot/app_userdata/
  Kindled Deep/ledger/, or the profile's folder).
- `tests/test_playtest.gd`: every finding of the second playtest pinned down
  (equal XP and Embers, private finds, the live Satchel, a foe beyond a gate
  brought back, a room won while the host lies dead, 18 floors with every
  room fought to its end, steering, corners, footprints, attack turns,
  loadouts, the guest at the host's forge, every foe script compiling).

### Tools of the expedition evolution pass

- `-- walllab [behind]`: one of each building element by the start (a
  waist-high wall, a pillar, a pit, a solid set piece, a walk-through one);
  `behind` stands the Kindled behind the pillar (its silhouette). Compare
  with `showcol` (the collision overlay).
- `-- route=trial|vault|quiet` (a floor reached that way, depth 2) and
  `warp=stairs|objective` (at the fork, or in the way's own room).
- `-- open=apothecary`; the UI smoke now also steeps a tincture, presses the
  Hearthtree key twice, raises and improves the Apothecary checking the
  Kindled never moves, and scrolls the Smithy 60 pieces deep checking a pick
  keeps its place.
- `tests/test_evolution.gd`: the gear path (another kind, another form, a
  tempered blade, armour on and off, a talent point), no steering left, the
  Hearthtree key, the silhouette's instance slots, 90 floors walked for
  reachability (doors, rooms, usable props) and every route's floors, the
  v13->v14 migration, reagents teaching and distilling, each tincture's
  effect, the fork's offer, and each way's shape.
- The journey scenario's stairs vote now names a way (`stairs:<route>`) and
  every machine checks it arrived on that way's floor.

### Tools of the living Undervault pass

- `-- walllab` still shows every building element; `warp=altar` stands at the
  floor's Hollow Altar (`seed=11` has one at depth 1), `warp=stairs` at the fork.
- `-- region=delve depth=4`: a Fracture; `route=breach|lair` the rare ways.
- `-- scaling routes=,trial,vault,quiet sizes=1,4 comps=mixed seeds=3 secs=170
  tier=2 depth=2`: bots compare the ways (room time, health lost, deaths,
  Embers per floor, finds), solo and in a party.
- `-- sitefind region=ossuary depth=2`: a seed for each form of each way and
  each event, to walk into with `route=<way> seed=N warp=objective` (or
  `warp=event`) and look at. `-- scene=hub open=chronicle sample` fills the
  Chronicle screen.
- `tools/dev/e2e.sh 4 sites` (DEVNET=1): every Kindled pings with their own key
  and sees everyone's mark on the map, then the party answers a Hollow Altar by
  vote; the host's Chronicle changes, a guest's own altar does not, and every
  screen shows the answered altar.
- `tests/test_evolution.gd` also pins: the altar due once an expedition,
  each answer's effect on later floors, Grudge history and lessons, the v14->v15
  migration, Fractures, milestones paying once, Omen caps and exclusions.
- `tests/test_living.gd` plays the content rather than generating it: each
  way's room begun and won on a real floor (the HUD's task gone after), a room
  held while a seal stands, the Vigil fed and choked, ash in a Gauntlet, coffers
  paying and sealing, altars, the Pale Bowl once a floor, a Grudge warding,
  lunging, fleeing once and leaving its trophy, shatter between two Kindled, the
  new uniques and deep hybrids, an Echo's pattern, a ping fading.
- Rendered captures found what none of that could (see STATUS): after adding
  anything visible, walk into it and look at the capture.

### Tools of the foes and guardians pass

- `-- scene=dungeon region=<r> rosterlab [anim=windup] [lab=<id,id>]`: a region's
  foes in rows on its real floor and light, held in one pose (they do not act).
- `-- region=<r> depth=3 warp=boss autopilot bossat=0.5` starts a guardian at that
  health; `bossdie=<seconds>` fells it that long after it arrives and prints the
  frame, so `capture=<name> frames=<n> burst=8:50` can be aimed at the fall.
- `tools/dev/e2e.sh <n> guardian` (DEVNET=1): a party down to depth 3 and through
  a guardian's arrival, turn and fall; nothing may land on the blow, and its hoard
  and the way home must reach every screen.
- A check on a lagged guest must use that machine's own clock: the first
  `guardian` scenario sampled once at a fixed step and failed for no game reason.
- `tests/test_foes.gd`: rims and `self_light` on every foe, a rim gone from a
  corpse, a fall for every guardian, wind-ups that change the silhouette, spoils
  and titles, the three new foes' behaviour.

### Tools of the great evolution pass

- `scenario=ways` (run with `XARGS=plan=wing`, DEVNET=1): the floor's plan and bars match
  on every machine; a guest is refused at the plate without the key, takes the key and opens
  the vault with real key presses; every map shows the vault, every grid opens; a felled column
  lies down on every screen; a Snuffer dims the guest's own lantern and its death restores it;
  a Gravehook's chain drags the guest's own Kindled.
- `warp=boss bossquit autopilot botskill=sharp form=<id>|none`: a guardian fought to its end by
  the bot's real hits, timed (`[dungeon] guardian felled: ...`). Run it from a copy of the project
  (`cp -r .godot addons assets src tests tools project.godot ...` to a scratch folder) so long
  runs never read half-edited scripts.
- `plan=`, `warp=lock|key|rule`, `sitefind` (rule rooms too), `open=noticeboard`, `maren`.
- `stallog`: every slow frame taken apart (process, draw, present, what changed, what the game was
  doing). Never measure with stdout piped: a print through a pipe costs tens of milliseconds.
- `tools/dev/run_tests.sh` fails on any `SCRIPT ERROR` as well as on failures: a test that crashes
  half way otherwise reads as passed (the runner counts checks, not crashes).

### Tools of the deepening pass

Everything below runs through `tools/dev/bg.py`, so nothing appears on screen or takes focus
(see CLAUDE.md, "Background runs only").

- `python tools/dev/bg.py focuscheck`: a rendered capture while the foreground window is sampled
  every 10 ms; passes only if Godot never had focus and was never on a screen.
- `python tools/dev/bossbench.py`: guardians to the end without god mode (builds x skills x
  forms x seeds, two at a time, headless at `--fixed-fps 30`); a lost fight names its last blows.
- `-- weaponlab [secs=40] [bases=...]`: every weapon in the same fights (an unshielded brute, a
  shielded Guard, packs of Husks, a Skitter swarm); `user://weapon_lab.md`.
- `-- scaling ... comps=<preset>,...`: any build preset as a team; a downed bot prints its last
  blows and what the room held (`[scaling] DOWN ...`).
- `scenario=deep` with `HXARGS=hunt=ossuary GXARGS="wear=gloamfang evolve=storm"` (DEVNET=1):
  the host's hunt on every machine's floor, a guest reading a sign with a real key press, a
  guest's grown weapon applied on the host. `HXARGS`/`GXARGS` add switches to the host or the
  guests alone.
- Dev switches: `hunt=<region>`, `evolve=<path id>`, `botskill=`, `bossquit` (also on a death).

## Human playtest: the deepening pass

1. **Your weapon's technique.** Sword: press again just as a swing settles (a glint shows the
   moment). Hammer: break one foe in a crowd. Daggers: get behind. Spear: strike with the tip.
   Staff: hold a charge long past full. Bow: let go at the peak of the draw and do not get hit.
   Is each one noticeable, learnable and worth it? Does any feel like a chore?
2. **The tree.** Try one technique notable on another weapon, and one keystone (Perfect Cadence,
   The Lantern's Edge, Vanguard's Weight, Unblinking). Does the price feel fair?
3. **A hunt.** Fell a guardian, take its hunt from the noticeboard, go back: read the signs,
   find the harbinger, fight the quarry. Did it feel different from a normal visit?
4. **Altar consequences.** Kindled: take a lamp's flame. Broken: dig rubble; are fights too
   crowded? Is the extra foe noticeable?
5. **A great thing that grows.** Does the weapon look different once awake and once it has
   chosen? Was the choice clear before you made it?
6. **The map.** Is it cleaner without the facing line? Can you still tell yourself apart?
7. **Listening** (nobody has heard any sound in this game; only measured). New this pass: `cadence`
   (a short bright glint, 0.35 s), `evolve` (1.6 s, the path choice), and from the last pass `snuff`,
   `chain_throw`, `chain_haul`. Ask of each: can you tell it apart in a crowded fight; is it too
   loud or too quiet beside the swings; does it ever grate after an hour?
   **On laptop speakers or small headphones**: these older sounds put most of their energy below
   120 Hz (measured with `tools/audio/analyze.py`) and may vanish or turn to mud there: heartbeat,
   crumble, slam, seal_close, satchel_close, the moss steps, explode, player_death, aftershock,
   swing_heavy, seal_open, deny, bow_draw, sweep, lantern. Listen to a guardian's slam and a
   death on small speakers. None of the 178 effects clip.
8. **Floor spikes and the King's sun-pillars** now say who hurt you ("Floor spikes") in the
   death summary; the pillars also show as off-screen arrows on the other players' screens.

## Human playtest: the great evolution pass

Two PCs, one expedition or two each, about an hour. Nothing here has been played by a person yet.

1. **The Keeper** (both): click the Keeper from a few steps away. Your Kindled should walk over and
   talk, never swing. Press a movement key on the way: the walk stops.
2. **Floor shapes**: on a floor with bars near the start (a wing), follow the toast to the key,
   carry it back, open the vault. Does the guest see the bars lift at the same moment? Does the map
   show the vault once the key is taken? On a floor with a lever, pull it and use the short way back.
3. **Rooms to use**: strike a column, a jar and a vent with foes near them. Did the warning come
   early enough? Did it ever hurt you in a way that felt unfair?
4. **Rule rooms**: if a fight is named on entry (One Pulse, the Unlit Room, the Hungry Floor), was it
   clear what it asked and did the chest feel worth it?
5. **New foes**: let a Snuffer take your flame, then chase it. Let a Gravehook catch you once, then
   dodge its chain. Were the warnings readable in a crowd and on the guest's screen?
6. **Guardians**: a second visit to a guardian may bring its rarer form. Is the Lightless Warden's
   dark readable? Does the Rootbound Bloom's warning show where it will rise?
7. **The noticeboard** (beside the gate): take two notices each, play, and see if they pay on the way home
   on both machines.
8. **Great things**: wear a legendary or unique; its tooltip should count Resonance. After a few runs it
   Awakens; later the Satchel offers a choice of two paths.
9. **A death**: does "How it ended" tell you something you did not know? Is "The whole run" useful or noise?
10. **Wide screen** (3440x1440 and 1920x1080): is the HUD close enough to the fight? Try Settings, HUD width,
    and Accessibility, Strong warnings.
11. **Grudges**: when one flees, note what you hit it with last. Next time it should be marked against that.

Please note anything that felt slow, unclear, unfair or broken, with the time and what was on screen.

## Human playtest on two PCs

Two people, each on their own PC. For a LAN game, both on the same network:

1. **Host.** A: main menu > Play Together > Host. B: Play Together > Join by
   Address, then type the address A's party screen shows. Over Steam: A
   chooses Host on Steam; B uses Join a Friend, or accepts A's invite.
2. **The sanctuary.** You both stand in A's camp and see each other, each
   in your own armour. Check:
   - B changes gear or wardrobe (hide a helm): A sees it within a second.
   - Each talks to the Keeper and to a resident with a "!". F, a click and
     Esc each work once; the world stays visible behind the words; nothing
     stays dark.
   - Walk into each other and through a crowd at the gate: nobody gets
     stuck.
3. **The expedition.** A walks to the gate and proposes. B gets the card
   wherever they are, even in the satchel. B presses N: A's card shows "Not
   now". A presses N to withdraw, proposes again, B presses Y: a 3 s
   countdown, then you both go down together.
4. **Depth 1.** B stays back while A enters a fight room. Check:
   - B is drawn in just inside the door A used, on open floor, and can
     move at once.
   - Both of you see every foe as a sprite, with nameplates and bars on
     elites.
5. **The stairs.** After a few minutes on depth 1, take the stairs (both
   press Y). On depth 2, each walks somewhere different: each must see the
   other move. Repeat at depth 3.
6. **Home.** Hearthcall home, then propose a second expedition.
7. **Drops.**
   - B quits mid-floor and starts again: B must take its seat back.
   - A quits mid-floor: B tries for 30 s, then brings home what it carried
     into that depth.

Note anything odd with the F3 overlay on: its round trip, loss and
corrections help diagnose it. Keep both machines' `[net]` and `[steam]` log
lines (in the `--verbose` console, or run from a terminal).

## Human playtest: the evolution pass

What bots and scripts cannot judge. Use a fresh dev profile
(`-- profile=play_evo.json`), or `build=<preset>` to start with a build.

1. **Spells and the hotbar.** At level 5 the third slot opens (C; pad RB).
   Set three spells at the Descent loadout. In a fight: are the keys, costs and
   cooldown seconds readable at a glance? Is the "ready" flash noticeable but
   not distracting? On a pad, does RT attack and RB cast without fumbling?
2. **Build feel** (`build=knives`, `rush`, `hail`, `lantern`, `bulwark`):
   - Gloam Knives with Fan of Shadows and Ricochet: does the fan feel worth a
     slot? Are the knives easy to see?
   - Ember Rush + Momentum + Thousand Cuts: does the speed-up feel earned?
   - Ember Hail: more shots, each weaker - does it feel stronger or weaker?
   - Hearth Lantern: is standing in its light rewarding? Is it readable which
     lantern is yours in co-op?
   - Last Light: does losing Kindle instead of health read clearly?
3. **Weapons.** Find and wield a variant (Gravecleaver, Splitwood Bow...):
   is the difference noticeable? Is the tooltip clear that the forge's
   levels still count? Is the variant's tint visible in the world?
4. **Depths.** Do the title cards and the HUD make it obvious how far the
   guardian is? On the guardian's floor: is the edge pointer helpful or
   intrusive? Does the tremor land as anticipation?
5. **The workshop** (`forge=1`, `2`, `3`): does it look like a smithy? Are
   the sparks in time with the hammer? Is the forge screen's expand option
   easy to find?
6. **Co-op with 2-4 people.** Are the party cards readable at a glance in a
   fight? Can everyone find their own Kindled in a crowd (the brighter double
   ring)? Do names stay readable when everyone stands at the fire? Does a
   party fight feel as tense as playing alone (foes hit 10% harder per extra
   Kindled)? Do rare-find toasts from friends feel nice or noisy?

## Human playtest: the development pass

Facing (keyboard + mouse, then a pad):
- Walk W, A, S, D and each diagonal: the Kindled turns and runs that way,
  no flicker on diagonals. Stop: it keeps facing that way.
- Walk away from the pointer and attack: it turns to swing at the pointer.
  Dodge: it faces where it goes. Armour and weapon stay on the body.
- In a party, watch a friend walk around you and turn: they face where they
  go on your screen too, after the stairs and after rejoining.

Listening (headphones, then laptop or TV speakers - nothing has been heard
by a person yet):
- Walk a region, then fight: does the combat layer rise in time with the
  music and fall away after? Is any region's music tiring after 20 minutes?
- Break urns of each region: satisfying, varied, not too loud or shrill?
- Drops: rare / epic / legendary chimes distinct? The legendary hum and impact.
- A guardian's arrival (rumble, then the arrival), the Colossus waking, the
  smith's anvil and bellows in the sanctuary.
- A four-player brawl: are wind-ups and parries still heard? Does anything
  clip or pump?

Co-op difficulty (2, 3 and 4 players, Tier I-III):
- Do foes come for everyone, not just whoever is in front? Does anyone get
  picked off for standing alone - and does that feel fair or unfair?
- Guardians in a party: are the helpers it calls readable (marked first) and
  survivable? Is the fight longer or just harder?
- Do rewards feel fair per player compared to solo?

The world:
- Can you tell at a glance what every object is and what F will do? Try
  Settings > Accessibility > Object names: only the nearest / off.
- Landmarks (`-- landmark` to see one every floor): do they feel like places?
  Is the Heart-Root's price worth it?
- Depths 2 and 3 of each region and the Hollow Below past depth 9: do they
  feel deeper?

### Tools of the combat identity pass

- `-- botcharge`: the autopilot holds every third attack (charged moves and
  stances, to see and test the forms).
- `-- build=beam|wall|pyreblade|shadow`: whole builds around the new spells,
  each with a weapon form; with `hitlab cast=1,2` they cast at lab foes.
- `-- wear=<variant>`: any form (e.g. `wear=wardens_partisan`).
- `-- economy profile=economy.json [seeds= region= depth= tier=]`: the exact
  economy audit (parties 1-4, every foe felled, every drop taken; report in
  `user://economy_audit.md`).

## Human playtest: the combat identity pass

Weapons (keyboard + mouse, then a pad) - for each variant (`-- wear=...`):
- Does it play differently from the plain weapon? Is its held move clear
  (charge, stance, guard)? Is its gauge readable?
- Duelist's Sabre: does En Garde feel fair (1s, one blow)? Partisan: is
  Hold the Line strong but not safe (4 Kindle a block)?
- Uniques: are the Thousandth Cut's flurry, the Hundredth Ember and the
  falling sun exciting?

Spells (`-- build=beam|wall|pyreblade|shadow`):
- Soulfire Beam: is steering it satisfying? Cinder Orb: is the recast clear?
  Rimewall: does it change fights (and never trap you)? Hearthfire: does the
  form feel powerful?
- Knives with a melee weapon, Rush chains, Rekindle's cleanse.

Foes:
- In a crowd, can you tell which foe is about to strike from its glow? Do
  strikes land where the telegraph showed, for everyone in it?
- Frenzied and Shepherd elites: readable? Urnlings: a fun surprise or a
  cheap shot?

Listening (nothing in this pass has been heard by a person):
- each weapon's impact; the new spells; forms' sounds (riposte, block,
  aftershock, vent, breath...); Frenzy and Shepherd.

Co-op: whole expeditions with 2-4 players - do rewards feel fair per player?


## Human playtest: the playtest foundations pass

Bring the XP ledgers home (see Tools): if levels part ways, the files say
where. Two (or more) PCs, a whole expedition, then:

- **Equal progress:** start equal (or note both levels and XP), play to the
  end; compare levels and the ledgers. Take turns finishing foes and picking
  up memories - nothing should change who gets what.
- **Private finds:** each sees only their own drops (beam, name, chime);
  neither can take the other's. A legendary of yours: does the friend's
  "found" line feel right, or is it noise?
- **The live Satchel:** open it below after a find (marked with an ember),
  compare, wear it, feel the weapon change; try mid-fight (held until the
  seals fall). Die once: finds stay, half the materials go.
- **Rooms:** any room that will not open, any foe you cannot reach - note
  the room and look for "arena watchdog" in the log.
- **Map and minimap:** Tab - readable at a glance? Can you find your friend
  on both? Zoom with the wheel. Is the guardian's lair easy enough to find
  without the arrow?
- **Steering:** hold W and move the mouse; does it feel natural or twitchy?
  Settings > Gameplay > Pointer steering (W follows the mouse / Always / Off).
- **Floors:** anything that looks walkable but blocks (or the reverse)?
  Sprites cutting each other? Brightness (Settings > Display) at default -
  still the Undervault, but readable?
- **Party start:** host presses Begin together at the title; does everyone
  arrive without touching anything? A guest at the host's forge: craft and
  temper with your own materials.
- **Combat:** crowds - do foes taking turns feel fair but still dangerous?
  The Thousandth Cut and the Wand of a Hundred Embers - often enough to look
  forward to, rare enough to stay special? Foes' flinches and falls.
- **The Hearthtree:** the seven weapon masteries - do they change how your
  weapon plays?

## Human playtest: the foes and guardians pass

- **Reading a crowd:** in a busy room in each region, can you tell what is about
  to hit you at a glance? Is the rim helping, or is it too loud, or too neon?
- **The foes seen most:** Husk, Guard, Archer, Skitter. Does the wind-up give you
  time to react from the shape alone, before the red marker?
- **Guardians:** does each arrival feel like that guardian? Does the turn make you
  look up? Does the fall feel like an ending, and do you enjoy the short wait for
  the spoils or want to skip it?
- **Tollkeeper:** can you dodge through the ring on purpose? Is it too bright?
- **Lurecap:** did one fool you? Could you have spotted the eye? Was it fair?
- **Ash Herald:** did you see the mark? In a party, did someone go for the Herald?
- **A friend's screen:** guardians and new foes should look the same on a guest's
  machine.

## Human playtest: the living Undervault pass

- **The stone:** do the walls read as solid rock now, and do floors stay quiet
  enough that foes and drops stand out? Any cap, pit or doorway that looks wrong?
  Look at the third depth of a region (the bright grid is gone: too plain now?).
- **The Forked Descent:** is the choice still a choice when it does not come
  every floor? Each way, several times: the Trial's three forms (seals, a
  Champion, the falling ash), the Vault's three (keep the flame, choose one
  coffer, a workshop), the Silent Passage. Does the Trial feel worth its danger?
  Bots suggest it pays about 1.6x the plain way for about 3x the health lost.
- **Hollow Altars:** read the three answers. Did you know what you were
  choosing, and did the next expedition feel different? Let one rest at the
  Shrine (the Chronicle) and check it changes back.
- **The Breach:** break an altar, then take the third way. Fair, or a wall?
- **Grudges:** die, come back. Does yours feel like it knows you (a red ward if
  you stood and swung, a marked lunge if you kept away)? Hurt a level 2+ one
  until it runs: do you want to chase it? Is the red trail on the floor visible?
- **Events:** the Last Stand and the Lost Procession: does a room like that tell
  you anything without words? The Pale Bowl: is the price clear?
- **The Hollow Below:** a Fracture (two regions in one floor), an Echo's pattern
  (is the mark readable before the blow?), the milestones, Omens that exclude
  each other.
- **Builds:** Furnace Heart, Perfect Answer, Shadowfrost, Hearth Anchor, the
  three new uniques: does each change what you do, or only a number?
- **In a party:** ping (G / D-pad right): do people use it? An altar vote: does
  everyone understand it binds the host's world, and only theirs? Shatter a
  friend's frozen foe.
- **Words on screen:** do banners read over everything now? Do toasts stay out
  of the way of the controls card?

## Human playtest: the expedition evolution pass

- **Gear in the sanctuary:** take up a weapon of another kind at the rack
  and in the Satchel; swing at a dummy at once. Change armour and watch
  health and the outfit change. Temper what you hold.
- **Upgrades:** raise or improve the Forge (Expand the workshop), the
  Apothecary and the Shrine while standing beside them: you should stay put
  and watch them change. A guest: watch the host's camp change too.
- **The Smithy:** scroll a long list, pick something near the bottom, temper
  it: does the list stay where it was? The slot chips, rarity and "ready"
  filters - useful?
- **Movement:** walk with WASD while sweeping the mouse; the Kindled should
  walk where the keys say and look where you aim, then look ahead again.
  On a pad: left stick walks, right stick aims.
- **K:** open the Hearthtree in camp and below; kindle a point between
  fights (not while sealed in). Does the TALENT POINT reminder help?
- **The orange blob:** any warm pixel cloud over the Kindled? Stand behind
  a pillar or wall: is the outline readable, not distracting?
- **Readable floors:** can you tell walls, waist-high walls, pillars, pits
  and floor apart at a glance, in light and in the dark? Anything that
  looks solid but is not, or the reverse?
- **The Apothecary:** steep a tincture; try Kindleroot, Wardmilk and
  Sunwater in a fight. Did you find a reagent? Did the screen tell you what
  to look for next?
- **The Forked Descent:** at the stairs, is the choice clear (names,
  colours, the hint)? In a party, does the vote card make sense? Try each
  way: does the Trial of Ash feel harder and worth it, the Lost Vault worth
  the flame, the Silent Passage a real breather? The seals (can every build
  break them?) and the flame (standing in it while fighting).
