# Status

Last updated: 2026-11-05.

## Implemented

- **Playtest foundations pass (branch feature/playtest-foundations)** - the
  second two-PC playtest's findings; details in DESIGN, "Playtest
  foundations pass".
  - *Equal party income*: every shared award credits every Kindled the same
    (the room-clear XP went to the host alone; personal XP/Ember bonuses
    scaled shared orbs); gain bonuses are the party's best. XP ledger per
    machine and `tools/dev/ledger_compare.py`.
  - *Private finds*: never drawn, heard or sent to anyone but the owner.
  - *Live Satchel*: finds banked when taken (guests: acknowledged `_gift`,
    banked once by drop id), worn below (any weapon kind; not mid-fight).
  - *Rooms that open*: the arena (spawns, summons, splits, risers, adds and
    Grudges inside the reachable room) and a watchdog; the host-dead floor
    stop, the late Trial vote, leftover foes, flyers on gates, Rimewall in
    doorways and the bleed-out loop fixed.
  - *Map/minimap* from the real floor plan with every Kindled; no guardian
    arrow; *pointer steering*; readable floors (interior blocks, footprints,
    corner rounding, sprite depth lead, light); spell cards, picker and
    tooltips; host-led party start; guests at the host's forge.
  - *Combat*: the Thousandth Cut's buildup measured and redone
    (`-- legendlab`), attack turns, safe loadouts, drawn hurt/death frames
    for every regular foe, seven weapon masteries on the Hearthtree.
  - Save v13, protocol 9.
- **Combat identity pass (branch feature/combat-identity)** - details in
  DESIGN, "Combat identity pass".
  - *Weapon forms*: all 14 variants play differently (Gravecleaver sunders
    and executes, Duelist's Sabre ripostes from En Garde, Tombmaul's
    aftershocks and Tombfall, Emberforge Mallet's heat, Rimewood's shards and
    Frost Lance, Splitbranch's forks and cluster fireball, Gloam Kris marks,
    Ember Shivs thrown, Rootspear roots and thorns, Warden's Partisan holds
    the line, Splitwood's nocked volley, Long Rimebow's ice spear, Codex
    glyphs and spell echoes, Grimoire's fire breath), with a HUD gauge where
    a form has one.
  - *Uniques and legendaries* have their own held sprites; the Thousandth
    Cut, the Wand of a Hundred Embers and the Sunfall Glaive have signature
    moments.
  - *Spells*: Soulfire Beam (steered channel), Cinder Orb (recast to burst),
    Rimewall (ice wall terrain), Hearthfire Form (transformation); Gloam
    Knives lodge and burst on melee, Ember Rush chains through the burning,
    Rekindle cleanses and quickens, the Hearth Lantern exposes foes.
  - *Foes*: a blow lands on every Kindled its telegraph covers; the striker
    glows through its wind-up and the ground flashes as it lands; Frenzied
    and Shepherd elites; Urnlings in glinting urns.
  - *Builds*: five synergy notables (Shadow Cutlery, Detonator, Hearthforged,
    Frozen Bastion, Steady Pour), three saved loadouts (save v12), four build
    presets around the new mechanics.
  - *Feel*: each weapon class lands with its own impact sound; hammer kills
    hit hardest.
  - *Co-op rewards*: an exact economy audit (`-- economy`); a party's closing
    wave now pays no Embers or XP.

- **Development pass: feel, atmosphere, smart co-op (branch
  feature/feel-and-atmosphere)** - details in DESIGN, "Development pass".
  - *Facing (top priority)*: W/A/S/D and diagonals turn and animate the
    Kindled; it keeps its facing when it stops; a fight (attack, charge,
    stick aim) faces the aim, walking faces the walk, a moved mouse faces the
    pointer, a dodge faces where it goes. Hysteresis stops flicker on
    diagonals; the idle weapon follows the facing; armour layers mirror with
    the body. In co-op each Kindled sends its facing (protocol 7), so hosts
    and guests draw every Kindled turned the way its owner sees it.
  - *Smarter co-op*: foes share themselves out over a party (pressed Kindled
    are less inviting, a lone one is prey, ranged and support foes care
    little for distance); a party's extra foes are chosen by role (flankers
    and marksmen, within the role caps) and come from the far side; 3-4
    Kindled meet a closing wave; guardians gain less health per friend (+40%)
    but a quicker tempo and a call for help beside whoever stands farthest.
    Rewards are shared by worth, not by count.
  - *Interactables*: names over chests, shrines, wells, landmarks...
    in category colours (treasure gold, magic teal, bargains rose, the way
    onward pale gold), the action line on the one F would use, a soft
    highlight pulse; Settings > Accessibility > Object names (all / nearest /
    off).
  - *Urns*: three materials by region, crack-and-shatter with shards left on
    the floor, dust, three takes of a break sound per material; now and then a
    glinting urn that always pays; every attack type breaks them (blades,
    projectiles, spells, explosions, foes' blasts); rewards from the floor's
    own rng (no farming).
  - *Audio*: each region's walking music has a combat layer in step with it
    that swells with the fight; the Hollow Below and the two later guardians
    have their own music; stings for elites and a cleared fight; ambient
    one-shots per region; a master limiter, an SFX compressor, warnings on
    their own voices, music ducked under heavy fighting. All original
    (generated in tools/audio/build_audio.gd).
  - *Depths look deeper*: second and third depth floor/wall textures per
    region (bones, then soul-light seams; spore caps, then the Bloom's veins;
    ash, then gold inlay and a sun mosaic).
  - *Landmarks*: a rare fight around a region's great centrepiece (the Bone
    Colossus reveals the depth's map, hidden rooms too; the Heart-Root trades
    15% health for a relic, once per Kindled; the Fallen Sun-Disc restores the
    party and leaves a Sunshard), a banner on entry, minimap icons, the
    "Wonders of the Deep" feat.
  - *Loot*: legendary/set/unique finds hang turning in the air before they
    fall; each grade lands with its own sound; notable finds show their name
    on the floor (only to whoever they are for).
  - *Guardians arrive*: the room trembles, light gathers under a widening
    sigil, then a shockwave, a breath of slow motion, and the camera leans
    toward it on every screen.
  - *The Hollow Below* changes each pass through the regions: foes of the
    next region bleed in and it gets darker.
  - *The smith's anvil* rings on every blow (three takes), bellows breathe and
    the fire flares.

- **Evolution pass (branch feature/evolution-builds)**: builds, weapons, fair
  co-op, readable depths and a real workshop (details in DESIGN, "Evolution
  pass").
  - *Co-op party HUD*: a card per friend (portrait, seat colour, name, level,
    health with numbers, barrier, Kindle; downed with bleed-out and revive
    progress, fallen, link lost, at the menu / in camp / below). Names over
    Kindled never pile up; your own Kindled wears a brighter, breathing ring.
  - *Shared XP, personal loot*: XP is booked live for guests and never counted
    twice; gear rolls per Kindled (weapons lean to each finder's archetype);
    a bigger party meets more foes worth less each (+12% take per friend), and
    foes hit 10% harder per extra Kindled. Measured by the new scaling
    evaluation (below).
  - *Projectile builds*: +projectiles, pierce, chain, fork, return for every
    projectile; four spells (Gloam Knives, Hearth Lantern, Ember Rush,
    Rekindle) with rune effects, sprites and sounds; a third spell slot at
    level 5 (C / pad RB); a framed hotbar.
  - *Hearthtree*: 16 new nodes in build paths per branch, 15 new icons.
  - *Weapons as loot*: 31 weapon items (plain, variants, uniques from
    blueprints, a legendary per guardian), forge levels per archetype carried
    over, weapon tints in the world, 31 item icons, tooltips naming the
    archetype; save v11.
  - *Depths*: names and moods per depth, "Depth 2 of 3" / "Guardian Depth" /
    Hollow Below wording everywhere, the guardian's lair on the map, an edge
    pointer to it and a tremor as it stirs. Six new room shapes and six
    hand-made rooms.
  - *The workshop*: new furnace, anvil, quench barrel, tool rack, grindstone;
    the forge grows in three levels with smithing perks; sparks on the
    smith's strike; crafting flares the anvil.
  - *Fixed on the way*: Momentum / Last Light / Hearthbond / shelter only
    ticked in client prediction; a returning shot double-hit the foe it turned
    on; the one-strike-per-volley rule never recorded strikes; a seal stepped
    people onto the room's centre and parties spawned on one fallback spot
    (both walked map cells as tiles); positive cost/cooldown text read
    "-15% less"; two smoke-test timing bugs (see Validation).

- **Co-op playtest repair pass (branch feature/coop-playtest-repair)**, after the
  first real two-PC playtest. Each reported problem was reproduced with
  separate game windows first; the cause, then the fix:
  - *Guests saw only shadows for foes*: foes spawn fully dissolved and fade in
    during the host's simulation step, which a guest's copies never run. They now
    rise on every screen, with their health bars, nameplates and phasing fade
    (and those overlays go with them when they fall - they used to linger).
  - *A teammate frozen on other screens after the stairs*: the old floor's input
    reached the host after it had built the next floor, so the new Kindled took
    old sequence numbers and dropped every real input (as long as the last floor
    had lasted). Input names its floor; floor ids are per expedition.
  - *Black screen in conversations*: in co-op nothing pauses, and the Kindled
    kept reading F under an open conversation, starting it again with another
    55% dim per press. Any open screen now holds the player's input; one
    conversation at a time; conversations are framed (letterbox bars, a shadow
    under the text) with the world in view; their callback runs exactly once;
    requests end in Accept / Not now; Esc closes at once.
  - *Teleported into pillars*: a teammate drawn into a sealing room now arrives
    just inside the door the fight began from, on open, reachable floor clear of
    props, pits, hazards, foes and each other. New floors place the party in
    plain view (it once started behind a pillar, a silhouette on every screen).
  - *Separate sanctuaries*: the party walks the host's camp together
    (`HubSync`): each Kindled in its owner's gear, residents and the cat moving
    the same everywhere; personal facilities open your own profile.
  - *Armour not seen by teammates*: sheets were sent once, at joining; gear,
    wardrobe and weapon changes now reach the party live.
  - *Campfire collision*: the south row (empty ground) no longer blocks.
  - *Party readiness*: expeditions are proposed and answered on a request card
    (Y / N), with a countdown; the same card carries the in-run votes.
  - Redesigned: the party screen (Play Together: host / join a friend / join by
    address; the party as portrait seats) and Settings (category rail, pad-ready
    rows, a line explaining each). In co-op, losing window focus no longer pops
    a "Paused" menu (nothing pauses there).
  - Found by the new tests: the new dialogue panel had slid off-screen (fixed
    before shipping), a rejoined guest had no checkpoint if the host then left,
    and a crowd of other players could wall a Kindled in at the sanctuary.
  - Testing: `src/dev/scenario.gd`, `tools/dev/e2e.sh`, `e2e_compare.py`,
    `e2e_recovery.sh`, `showcol`; method in docs/TESTING.md.
- **Steam & responsive co-op pass (branch feature/steam-coop):**
  - *Netcode*: client prediction of the local Kindled (movement, dodge, Ward,
    flask, cast stance, weapon timing and lunges), reconciliation with input
    sequence ids, a bounded host lean that removes packet-timing drift,
    interpolation of everything else on an estimated host clock, 30 Hz
    per-client snapshots (deltas, interest, packet-sized chunks), events every
    frame, ENet throttle pinned, a shared clock (no hitstop/slow-mo in co-op).
  - *Lag compensation*: blows on a remote Kindled wait its round trip for a
    dodge or Ward on the way; the bow uses the owner's hold time.
  - *Diagnostics*: F3 overlay, `netsim=` link simulation with six presets,
    `netlog=`, `tools/dev/netsim_matrix.sh`, `tools/dev/coop_local.sh`.
  - *Every interaction for guests* with ownership rules (personal, shared,
    instanced, voted), host-checked and idempotent; party votes.
  - *Progression per player*: kills, bestiary, guardians felled and Grudges
    bank on each guest's profile; guests' Grudges hunt the party; each Kindled's
    own killer; settlements bank once (save v10); a host loss banks the guest's
    depth checkpoint.
  - *Sessions*: protocol/version check, ready states, floors that start
    together (early events kept and replayed), seats that wait 60 s for the same
    identity (rejoin with a floor dump), guests that try to reach a lost host.
  - *Steam* (GodotSteam 4.23.2, installed by `tools/steam/fetch_godotsteam.py`,
    API read from the extension): lobbies, invites from an in-game friends
    list or the overlay, joining from invites / "Join game" / `+connect_lobby`
    / "Join a friend", Steam identity, connection timeouts. Verified on one
    account; joining needs a second account.
  - *Windows builds*: official 4.7.2 templates installed; release and debug
    exports with GodotSteam packaged and checked (`tools/dev/build_windows.sh`).
  - *Release safety*: dev args and the testing stockpile only in debug builds;
    exports leave out the licensed sounds and steam_appid.txt; release check
    and build scripts.
  - *Fixed*: from depth 2 on, guests got none of the host's events (wave
    spawns, effects, sounds) because the old floor switched recording off.
- **Buildcraft & co-op pass (branch feature/buildcraft-coop):**
  - *Co-op for up to four* (host-authoritative ENet, LAN/direct IP): party
    screen, character sheets, replicated floors (snapshots + events), shared
    currency and instanced gear/blueprints/runes, per-player relic picks, foes
    choosing among players, co-op scaling, downed/revive, party-wide descend,
    Hearthcall and settlement into each player's own profile, seat colours and
    a HUD party panel. See docs/NETWORK.md.
  - *Room seals* redesigned (woven soul-light, region plates, staged forming
    and release, new sounds); anyone in a closing door is stepped inside.
  - *Visible armour*: 57 armour bases drawn on the Kindled from the body's own
    poses; satchel figure; per-slot appearance in the wardrobe; replicated in co-op.
  - *Ember Runes*: ten runes, one/two sockets per spell, drops and carving, a
    rune screen; each rune behaves differently per spell. Save v9.
  - *Weapons*: Hearthbow (draw and Steady Shot) and Emberwright's Tome (seeking
    motes that hurry spells, inscriptions).
  - *Hearthtree outer ring*: six transformative keystones.
  - *The Hollow Below*: endless descent with guardian Echoes and an Omen per depth.
- **Major evolution pass (this round):** six new enemies filling missing roles
  (Gravemole, Lampwight, Spore Mortar, Bramblewright, Gilded Duelist,
  Sunwatcher) with art, voices and sim tests; lobbed projectiles; every enemy
  has a role (shown in the Bestiary); role-based encounter squads with caps;
  behavioural elite affixes Molten, Splitting and Gloom; six Omens chosen at
  the Descent (save v8, the Descent remembers region and Omens); the Undervault
  Gate with wake/flare animations, hum and a title-card descent transition;
  loot beams, landing chimes, rare-find flourishes and gear auras; live Effects
  setting; Grudges that grow traits and level while unsettled, foreshadowed by
  red fires, with a hoard when settled; Sconce Vault and Lost Camp events.
- 2.5D pixel renderer (integer-scaled low-res viewport, sqrt(2) projection,
  quantised/dithered lighting, emissive masks, bloom, texel-snapped camera).
- Player: movement, aim (mouse or right stick), 3 weapons with combos and charged
  attacks, dodge charges + perfect dodge, Ward (parry/reflect), Kindle, flask,
  6 abilities (Flare, Cinder Lance, Frost Sigil, Gloamstep, Aegis, Wisp Familiar).
- 16 enemy types across three regions + elite affixes (two per elite from
  Tier IV) + Grudges; three bosses: the Gloam Warden, the Hollow Bloom and the
  Ashen King (Sunfall, Corona, the Eclipse: shelter in brazier light).
- Status effects (Burn, Chill/Freeze, Stagger, Exposed) and reactions
  (Thermal Shock, Combustion, Shatter, pit plunges, bloat blasts).
- Procedural floors (main path, branches, merged halls, loops, secret room),
  stamp-composed rooms, reward previews on doors, gates, waves, merchant,
  shrine of pacts, rest springs, treasure, stairs + Hearthstone extraction.
- Second region, the Rootmire (unlocked by the Warden): new tileset, burnable
  brambles, 5 enemies, the Hollow Bloom boss, music/ambience, lore.
- Capstone region, the Sunken Throne (unlocked by both bosses): obsidian and
  gold tileset, 4 enemies (Gilded Sentinel, Ash Hound, Eclipse Acolyte, Ash
  Wraith), the Ashen King, its own music and lore. Every region has 3 depths;
  new Grave Spider (Ossuary, webs snare) and Bog Toad (Rootmire, hops, tongue pull).
- Difficulty tiers I-VIII: enemy health/damage/poise, more and double-affix
  elites, richer rewards, item tiers with tier might; tier picker with power
  and a suggestion on the Descent screen; tier on the HUD, map and summary;
  the capstone opens the next two tiers.
- Blueprints (rare drops, learned in the satchel) for 13 uniques, many of them
  utility or silly (Squeaky Clogs, Gambler's Coin, Featherfall Hood...); four
  tier sets with 2/4-piece bonuses that change play; 37 plain bases.
- Wardrobe (transmog): ten looks (sets, legendaries and feats unlock them),
  applied as a palette swap in the sprite shader and in menu portraits.
- Facing follows WASD movement; the aim takes over while fighting (playtest fix).
- Hearthcall: a 3 s interruptible channel home from anywhere below.
- The satchel: a real messenger satchel when shut (strap, rounded flap, buckles,
  pocket) that unfolds into the open bag; animated both ways, new art/sounds.
- 24 uniques (11 new this round, each with tests where they have logic).
- Visual pass: floor grime shader, three region decal sets + a camp set,
  room lights in bigger rooms, ambient air per region, rugs and ruin signs in
  the camp, Throne ambience; the Bestiary.
- Five weapons (new: Twin Fangs, Sunpiercer); forge to +10 with Tempered,
  Masterwork and Ascended tiers and material costs; new forge screen.
- Level cap 60, Renown, three Hearthtree pages, 22 Feats. (Save now v8.)
- Living sanctuary: boss trophies, a weapon rack that fills, feat lanterns, a
  wardrobe stand, forge sparks, moths, a camp cat.
- Audio: creature voices (attack, hurt, death, idle, jump/land, boss steps) from
  the licensed Minifantasy pack when imported locally; new bow (no more plucked
  string), bow draw, sun lance, Hearthcall and satchel sounds; distance falloff
  for world sounds; `audiolog` dev arg.
- Room events: Ember Well, Trial of the Undervault, Echo of a Fallen Kindled.
- Gamepad: aim assist; every menu navigable (auto-focus with a gold focus ring,
  A confirm, B back, LB/RB switch tabs); skill tree cursor; prompts and the
  controls card show pad buttons when a pad is in use; separate keyboard and
  gamepad rebinding. CI on GitHub Actions.
- Hearthtree (55 nodes, 6 branches + hybrids + keystones) with icons on every
  node, route preview (click a distant node to kindle the cheapest path to it),
  search, branch focus, "tree total" tooltips and a bonuses panel; 39 relics,
  forge (temper/craft), sanctuary buildings, Grudge memorial, Undervault Memory.
- Playtest fixes: mouse aim/facing (was broken: the world SubViewport never saw
  the mouse), a flask slot on the HUD, footsteps synced to the run cycle.
- Gear: 6 slots, 21 bases (2 legendary), rarities, levels, affixes; 8 materials;
  drops from enemies, elites, chests and bosses; banking at run end; satchel
  (inventory + stats panel), smithy (craft / masterwork / temper / salvage),
  peddler stall (rotating stock, buy/sell). Save v5.
- More combat effects: floor splats and scorch, dust, crit lights, hit counter,
  low-health heartbeat. Hearthtree visual overhaul (nebula, trunks, living
  branches, bevelled nodes, the Hearth at the root).
- Combat feel layer: impact starbursts, enemy recoil/squash, directional camera
  kick, killing-blow hitstop, death slide, elite death flash, blade glint,
  controller rumble (with a setting), calmer hit-flash bloom.
- Hearthtree masteries (6 ranked nodes, 5 ranks each).
- Resident requests with permanent gifts; journal in the pause menu; "!"/"?" markers.
- Sanctuary camp: residents who arrive with progress, wander, sit, bark and talk;
  benches, cookpot, tent, crates, banners, planters that bloom over time.
- Sanctuary hub (walkable), main menu, HUD, minimap/full map, skill tree UI,
  relic choice, shop, shrine, forge, descent/loadout, settings (audio, display,
  UI scale, pixel size, gameplay accessibility, key rebinding), pause, summary.
- Versioned atomic saves with backup + migration.
- Generated content: all sprites, tiles, icons, UI frames, pixel font,
  83 sound effects, 6 music loops, 3 ambience beds.

## Validation

| Kind | What |
|---|---|
| Playtest foundations pass (2026-11-05) | **Unit tests**: 163 pass, 0 script errors in the run (new in tests/test_playtest.gd: steering, equal XP and Embers with personal bonuses, a friend's find invisible here, finds banked once and kept out of the settlement, a foe beyond a gate brought back, a room won while the host lies dead, bleeding out is death, a late Trial vote, 18 floors x every combat room fought to its end with parties of 1 and 4 - no foe outside its arena, every room opened -, corner rounding, interior walls, dressing footprints, attack turns, loadout checks, the guest at the host's forge, every foe script compiling, the v12->v13 migration; test_forms: the weapon masteries and the Thousandth Cut's buildup). **Separate processes, real input, one PC**: `scenario=loot` 2 players 11+10, 4 players 14+11+11+11, 2 players under `netsim=typical` 11+10 (only one's own find drawn, a guest is not sent another's, the find in the Satchel at once below, worn with a click, each save got exactly its run's XP, every run the same XP and Embers, the host sees guests wear their finds, every machine's map shows all four); `scenario=partystart` 4+4 (the guest follows the host from the title into camp without a click); regressions under protocol 9: 2-player journey 53+51, 4-player journey 71+63+62+62, stairs under `netsim=typical` 7+9 - all passed. **UI smoke**: 43 checks, 0 failures (its aim checks now use the scripted pointer; with the real cursor they failed at random while the PC was in use). **Solo autopilot** (seed 7): depths 1 and 2, no script errors. **Viewed in captures**: the full map (1080p, 3440x1440, a floor's start), the minimap, the Descent's spell cards and the picker (1080p and 960x540), the Satchel's loadout strip, the Hearthtree with a mastery hovered, the Ossuary before/after the light change, every foe sheet's new rows (husk, guard, skitter, bloat, duelist...), host and guest screens of private finds and of the 4-player map. **Measured**: `-- legendlab` (Thousandth Cut 2.5/min small fights, 4.5/min crowds; Hundred Embers ~7/min firing constantly; Sunfall every charged lunge). **Frame times** (1080p, bot fighting a crowd): this PC now runs at 60 Hz, so with V-Sync the old and new code both sit at p50 ~17 ms; with V-Sync off, old p50 5.2-5.4 ms, new 4.6-6.9 ms across runs on a PC in use - no reliable difference; the minimap costs ~0.1 ms a frame and bakes only when the map changes. **Not done**: no human played; no two PCs or Steam; the arena watchdog not seen in a real fight; no listening. |
| Combat identity pass (2026-11-04) | **Unit tests**: 145 pass (every form's mechanic, the uniques' moments, each new spell and rework, foes striking all covered Kindled and their wind-up glow, Frenzied and Shepherd, synergy notables, loadouts and the v11->v12 migration, Urnlings). **UI smoke**: 43 checks at 1080p and 3440x1440 (the Satchel's loadout strip fits). **Rendered, bot fighting (`hitlab botcharge`)**: all 14 forms with no script errors; spells cast with `cast=` and build presets; uniques held; foes' wind-up glow and strike flash. **Separate processes, real input, one PC**: `scenario=spells` with `build=wall` (a guest's Rimewall rises and melts on both screens) and `build=pyreblade` (Hearthfire glow on both; the host's heat on the guest's gauge) - 6+6 checks each; regressions under protocol 8: 4-player journey 71+63+62+62, 2-player journey 53+51, facing 14+14, stairs under `netsim=typical` 7+9, 3-player bestiary - all passed. **Frame times** (`perflog`, 1080p, V-Sync 165 Hz, bot fighting a crowd with `build=beam|pyreblade|wall|shadow`): p50 6.1 ms, p95 6.2 ms, p99 at most 7.4 ms; single worst frames 12-62 ms, except ~230 ms stalls in the bot's own stuck-diagnostic dump (full path searches in src/dev/bot.gd, not game code - confirmed by timing the bot's frame and a run without the bot). **Audio events**: each weapon class plays its own impact (audio log). **Measured, not heard**: every new sound peaks at -1 dBFS without clipping; the hammer's crunch rebalanced to carry on small speakers. **Economy audit**: 12 seeds x 5 floors, exact (see Known issues). **Not done**: no human played or listened; no two-PC or Steam test. |
| Development pass (2026-11-04) | **Unit tests**: 122 pass (party targeting and extras, rewards by worth, landmarks: generation leaves the rest of a seed's floor unchanged, its room stays walkable, each of the three answers, the Wonders feat; Hollow cycles; facing with every key). **UI smoke**: 43 checks pass at 1080p (three runs after a harness fix; a feat card opening late made the resident checks flaky). **Separate processes, real input, localhost (one PC)**: 2-player journey 53+51 checks; 4-player journey 71+63+62+62 (after making two talk checks wait on results: with four windows on one PC a dialogue opened up to 0.65 s after F); facing 14+14; stairs under `netsim=typical` 7+9; bestiary with 3 players; `landmark` (a guest presses F at the Colossus; every machine sees it wake and the whole map) 6+7; solo `talk` 13. **Viewed in captures**: facing on host and guest, labels, urns breaking (all makes), depth textures (9 region/depth pairs), the three landmarks idle and answered (solo and host+guest), loot hang and floor names, a guardian's arrival frame by frame, the Hollow at depth 10. **Frame times** (`perflog`, 1080p, V-Sync at 165 Hz, RTX 5070, bot playing): p50 and p95 6.1 ms, p99 at most 8.3 ms in the Ossuary, a Rootmire landmark floor, the Throne guardian fight and the sanctuary; single worst frames 6-34 ms after the first loading window. **Audio, measured not heard**: every new sound peak-normalised to -1 dBFS without clipping, low end checked per file; a 41 s guardian-floor recording of all buses: master peak -4.5 dBFS, no sample over -1 dBFS, bus loudness steady within ~3 dB; 41% of the master's energy below 120 Hz (mostly the guardian music). **Bot co-op evaluation**: Tier III, 3 seeds x 240 s per party (see Known issues). **Not done**: no human played or listened; no two-PC or Steam test. |
| Automated tests | 76 tests (incl. the six new enemies in sims, squads, behavioural affixes, Omens, Grudge growth, vault/camp generation, Thornmail, Mirrorguard, Executioner's Band, every blueprint has an icon, walking turns the Kindled, Hearthcall break/complete, every weapon's combo and charge, forge costs, the level cap and Renown, pages, feats, the v7 migration, difficulty tiers and the capstone unlock, enemy tier scaling and double affixes, tier might, every region's creatures having scripts/sheets/tiles and rolling only their own pool, blueprints and learning, sets/uniques/looks, gear rolls/stats, equip/craft/salvage, run loot settlement, footsteps on contact frames, mastery ranks, resident requests and gifts, save migration v3->v4, Hearthtree route finding and stat totals, Warden brazier sear, Rootmire brambles never sealing doors, event room generation, Interact through the real input action, device-aware button labels, residents arriving and walking between spots), run locally and on GitHub Actions: combat math, stats, statuses, settlement, XP curve, skill tree rules/connectivity/layout, relic offers, profile currencies, forge, grudges, save round-trip + corrupt-file recovery + migration, dungeon connectivity/structure/determinism/overlap/wall heights, encounter budgets, headless combat simulations (AI hunts and hits, sword combo kills, dodge i-frames + perfect dodge, Ward reflect, burn kills, projectile/wall, bloat friendly fire). `tools/dev/run_tests.sh` |
| Autopilot playtests | Headless bot runs (seed 7): clears depth 1, descends, plays depth 2. Boss run with `godmode`: Gloamfall at 54%, skitter calls, Warden dies, Hearthstone victory settles (bonus, sunshards, staff unlock). Without godmode the naive bot dies to the Warden in ~25s. Rootmire (godmode): depth 1-2, Bloom wilted by all four burned roots, victory. Event rooms: bot completes a Trial (3 waves, reward), Ember Well and Echo offers without script errors. Loot: a god-mode run through depth 2 and the Warden banked materials, two epic pieces and the Gloamward Lantern into the save. Combat feel: burst captures (`hitlab burst=`) reviewed frame by frame for impacts and flash bloom; sword, hammer and staff autopilot runs clean after the change. Requests: a god-mode run with five active requests counted elite kills, a Sunshard, a chest and Wren's bird (the bot never Wards, so the Ward counter is only checked by code review). Found and fixed: corridor targeting, partial pathing to solid goals, descend re-entry, freed-object timer callbacks. |
| Latest round (satchel exterior, uniques, dungeon/camp visuals, bestiary) | Captured and viewed: the satchel opening (shut satchel, flap up, unfolding), every region before/after the visual pass (grime, decals, room lights), decal rows per region (a bug passed the Ossuary row to every region - fixed and re-checked), the camp centre with trophies, rugs and camp clutter, the forge-ruin sign near and far, the title screen, the Bestiary empty and after a Warden kill, the new item icons. The smoke test caught the cat stealing a resident's conversation (moved). |
| Earlier round (playtest fixes, satchel, forge, progression, camp, audio) | Captured and viewed: the satchel opening sequence and the open bag, the new forge, Hearthcall from start to departure, the Feats screen and pause menu, the sanctuary with feat lanterns, wardrobe stand and the cat. Audio checked with `audiolog` bot runs: every played name resolves, voices fire on telegraphs/hits/deaths, spike traps only within earshot (was 176 plays across the map per run). UI smoke 34/34, seed-7 autopilot run clean. Not checked: the sounds themselves by ear. |
| Tiers, Throne, gear | Bots with tier-matched epic gear (`kit=N`), Ossuary seed 11: Tier I/kit I and Tier IV/kit IV reach depth 2 alive (98 and 84 kills); Tier IV with Tier I gear dies at depth 2; fresh, ungeared characters died early on Tiers IV and VI (measured before the final curve tune). Tier VI with Tier VI gear reaches depth 2 and dies there after 90 kills (the bot never uses the Hearthtree or sanctuary, so it is weaker than a real Kindled at that point); one earlier Tier VI bot got stuck beside a foe it could not reach (bot pathing; foe diagnostics added to the bot log). Sunken Throne on Tier IV with Tier IV gear: clears depths 1-2 and dies in the first room of depth 3 (115 kills). A second god-mode King kill (seed 3, Tier I) after the poise change: Eclipse at 49%, victory opens Tier III. God-mode bot kills the Ashen King: Eclipse at 49%, victory banks the Sunfall Mantle, a set piece and a blueprint, and Tier II opens Tiers III-IV. Throne floors and the Rootmire/Ossuary at depth 3 run without script errors. Balance numbers from `tools/dev/power_report.tscn` (see DESIGN). |
| Evolution pass | **Automated**: 117 tests (new: volleys, chain/fork/return, the four spells, Rekindle raising a downed friend, the build keystones, the third slot and its lock, tree layout/icons/reachability, the reward share, weapon items (bases, equipping, forge x item might, whole-number stats, drop shares), the v10->v11 migration, room variety and hand-made rooms, party spawn spots and seal step-out). UI smoke 44/44 at 1920x1080 (UI scale 2, 3) and 3440x1440 (3, 4), now also checking every screen it opens fits the window. Solo autopilot (seed 7): depth 1 cleared, depth 2 reached, no script errors, no stuck bot. **Party-size scaling evaluation** (bots with real builds, no godmode, Tier III depth 2, 3 seeds x 240 s): each Kindled earns 0.84-1.30x solo XP per room and 0.99-1.60x Embers per room; room time is noisy (bots stall); with the +10%/friend damage a 2-party takes about what solo does (27% of health per room), 3-4 parties less (15-26%); the table is written to `user://scaling_eval.md` (the dev user folder) on each run. **Separate processes, one PC, real windows**: 4 players `partyhud` (host 5/5, guests 6/6: cards, downed, level-up, names unstacked); 2 players `journey` locally (53/51) and under a typical simulated link (53/51, nothing frozen, p95 under 0.7 tiles). **Captured and viewed**: the hotbar (empty, locked, cooldowns, three spells), Gloam Knives and the Hearth Lantern in the hit lab, the Hearthtree with the new nodes, the satchel with a weapon item, the weapon icon atlas, the Descent loadout with three slots, a guardian floor (HUD, map, pointer), a hand-made room, the workshop at levels 1 and 3 with collision, the party menu and dialogue at 1080p, the 4-player sanctuary and fights on every machine, ultrawide 3440x1421. **Performance**: Ember Hail bow build pinned at 165 fps (vsync) at 1920x1080 and 3440x1440 (up to 307 particles). **Not verified**: two PCs, a real internet route, Steam joining, a physical gamepad, human play of any of it, audio by ear. |
| Co-op playtest repair pass | 101 tests (new: proposals asked / answered / counted down / withdrawn / dropped, a stale acknowledgement ignored), UI smoke 34/34 (updated for the new settings), a solo autopilot run (seed 7: depth 1 cleared, depth 2 reached, no script errors), solo dialogue scenario 13/13. **Separate processes, one PC, real windows and real key presses / clicks** (docs/TESTING.md): 2-player journey 104/104 checks; 4-player journey 258/258; 4 players with guests on typical / moderate / stress links 256/258 (the 2 were the scenario's key-press budget, fixed); every foe kind, elite affix, a Grudge and the three guardians drawn whole on a guest's screen (36/36) and gone when felled; the stairs freeze reproduced with the old code under a 100 ms link (23 frozen windows) and gone with the fix; a guest crashing and taking its seat back, then the host crashing and the guest banking its checkpoint. **Captured and viewed** (both sides of each moment): the shared sanctuary with 2 and 4 players in their own outfits, a live helm hidden, conversations open and closed on host and guest, the request card (received, declined, counting down), fights with foes on both screens, depth 2 with four players, home again; the party screen (start, hosting, full), Settings at 1920x1080 and 3440x1440 and UI scales 2 and 3, the campfire with the collision overlay before and after. Not verified: two PCs, a real internet route, Steam joining, a human at the controls, a physical gamepad. |
| Steam & responsive co-op pass | 100 tests (new: prediction tracks the host's movement through a swing and a dodge within 0.02 tiles, reconciliation slides and jumps, a late dodge turns a waiting blow (perfect, counted), the bow lines up the owner's hold, the network simulator keeps order and loses packets, the personal merchant, one bargain each and one relic pick per offer, party votes, recording across floors, settlement once with the party's deeds, guests' Grudges for their owner, the v9->v10 migration, a returning guest's seat, readiness, LAN play without GodotSteam, allies' particle scaling). UI smoke 34/34. **Real separate processes, one machine, simulated links** (table in docs/NETWORK.md): 2 players under all six conditions (local to stress: measured round trip = simulated + 15-24 ms, others drawn 64-104 ms behind, snapshot loss = simulated loss, ~28 KB/s down and ~9 KB/s up per guest, prediction error p50 0.01-0.05 tiles); 4 players with three guests on typical/moderate/stress links at once; stairs and Hearthcall votes passing with a guest's agreement over 60-100 ms links, both settling the same outcome; a guest killed mid-run and restarted with the same profile taking its seat back with its run; the host quitting mid-floor and the guest banking its depth checkpoint. Found and fixed by these runs: guests got no host events from depth 2 on (recording switched off by the old floor), events sent before a guest built a floor were lost (now kept and replayed), the simulator reordering a burst, ENet's throttle dropping snapshots on localhost, an unsaved identity (a restarted guest was a stranger), a Hearthcall broken by the previous frame's walk, the network overlay drawn off-screen. **Steam (GodotSteam 4.23.2, one PC, one account, Spacewar)**: initialisation, a private lobby (data round trip, owner), a hosted session and the LAN fallback (Steam closed, no App ID) - in the editor and in an exported debug build; the friends list read (nobody invited). Found and fixed: the game crashed on quit while hosting over Steam (Steam shut down under a live peer), a Steam client messaging a host it had not reached, private lobbies advertising "Join game", and the exported game failing to start (game code preloaded the palette from `tools/`, which exports leave out). **Windows builds** exported with the official templates: release (runs headless with isolated user data, GodotSteam loads, dev switches ignored) and debug (the bot played depth 1 at 165 fps, capture viewed); no licensed sounds or steam_appid.txt inside. Performance with four players: host window 3440x1440 164-165 fps, guest window 1920x1080 165 fps. Captured and viewed: a guest's 1080p view with both Kindled, name tags, sealed room and the overlay (`docs/screenshots/coop_netdiag.png`). Not verified: two machines, a real internet route, a second player joining over Steam (needs a second Steam account on another PC), the Steam overlay and launch-from-invite (need the game started by Steam), human play. |
| Buildcraft & co-op pass | 84 tests (new: seals blocking/nudging/release on a real headless Dungeon, co-op downed/revive/wipe and shared vs instanced pickups, every armour base has a sheet following every body animation and the wardrobe override, all runes in a headless fight and the v8->v9 migration, Bow steady shot and Tome cooldowns/inscription, outer keystones, the Hollow Below). UI smoke 34/34. **Co-op with real separate instances on one machine (localhost)**: 2 players (descend together, Hearthcall ends the run for both, the client banks its own share, a client leaving mid-fight, the host leaving, Tome host + Bow guest fighting together, remote armour and weapon visible) and 4 players (host + 3 clients on the same floor, 16 actors everywhere, no script errors). Found and fixed by these runs: snapshots above the MTU (now compressed chunks), freed replicas assigned to typed variables, a co-op spawn inside a pillar, a virtual adapter shown as the LAN address. Captured and viewed: seals in all three regions, armour outfits across poses and in play (found and fixed dithered/see-through layers and the silhouette pass mistaking armour for a wall), the co-op party screen, the rune screen, Bow and Tome fights, the outer keystones in the tree, an Echo of the Gloam Warden in the Hollow Below. Bots: Bow (Rootmire Tier II) and Tome (Throne Tier II) runs without script errors. 3440x1440 (real `--resolution`): 165 fps throughout. Not verified: co-op across two machines or the internet; human play of any of it. |
| Evolution pass (enemies, squads, Omens, gate, loot, Grudges, events) | 76 tests (new: each of the six enemies in a headless sim, squad role caps and determinism, Molten/Splitting/Gloom, Omens unlock/bonus/apply/migration/end-of-run payout, Grudge traits/aging/cap, vault and camp generation on open floor). UI smoke 34/34. Captured and viewed: the six enemies in their regions (`hitlab lab=`), Lampwight before/after its light, Gloom before/after the toned-down darkness, Molten trail, the Bestiary, the Descent with Omens, Lightless vs lit, the HUD corner (run clock was being clipped - fixed), the new gate sprite sheet and the full flare-to-title-card sequence (found the sword floating after the Kindled dissolved - fixed), loot beams per grade, the vault opening and the camp. Autopilot: all three regions on fresh profiles (no script errors; the bot killed Mortars and Duelists, including through the riposte stance), the vault solved and the camp rekindled by the bot. Validation runs with tier-matched gear, all without script errors and alive at depth 2 at the frame limit: Ossuary Tier I with Restless Dead + Tempered (an elite in every fight, risers counted in 65 kills), Rootmire Tier II with Glass Kindled, Throne Tier III with Lightless + Dry Flask. Restless rising sigils captured. Ultrawide 3440x1421: Descent screen and a Throne fight captured (layout and HUD corner fine); no ultrawide performance run yet. Not verified visually: a Grudge room's red fires. |
| Visual inspection (screenshots actually viewed) | This round: wardrobe portraits and all eight looks in-game, Descent tier picker, Throne floor (redone once: the first gold-flecked slabs read as rust), Ashen King fight (sweep, corona, stagger), Throne foes (Eclipse Acolyte with orbs, hounds), sprite sheets for the King, Sentinel, Hound, Acolyte, Wraith, Spider and Toad. Earlier: dungeon at 1080p, 720p and 3440x1421 (ultrawide), combat with HUD/gates/traps/telegraphs, boss arena phase 1 and Gloamfall, Rootmire rooms and the Hollow Bloom arena, event rooms (Echo, Trial), main menu, sanctuary + dialogue (early and progressed: residents, barks, garden), gamepad menus (focus ring, pad prompts, rebinding columns, skill tree hints), redrawn sanctuary NPCs (sprite sheets and in the hub), the new Hearthtree (empty, partly allocated, route preview affordable/unaffordable, search, masteries, branch focus, 1080p and ultrawide), request markers and the pause-menu journal, occlusion silhouette, relic choice, forge, settings, run summary. Sprite sheets for all characters, boss, icons. See `docs/screenshots/`. |
| UI smoke test | `-- uismoke`: opens every screen and presses its buttons (sanctuary building, forge craft/temper, weapon rack, skill allocate/refund/respec, memorial, settings tabs, merchant purchases, blood pact, chest, lore, Hearthstone confirm, extraction), kindles a distant Hearthtree node (checks exactly the previewed path is bought), moves the mouse around the player (aim, facing, swing direction), equips from the satchel, forges, masterworks, tempers, salvages, buys and sells, searches and focuses branches, ranks up a mastery and reads its tooltip, plays a resident's request conversation through to the gift, then drives menus with synthetic gamepad events (B interacts/backs out, A confirms, RB switches tabs, focus follows). Found and fixed the shop/forge refresh bug, a late-descend race, and (in the input audit) a missing Interact input path: until this fix a human could not open chests, trade or take the stairs - the bot and smoke test had been calling `interact()` directly. |
| Build coverage | Bot runs with hammer, staff, and the entire skill tree allocated (`skills=all`): no script errors after fixes (Wildfire implemented; freed-source guards). |
| Performance | Windowed 1080p autopilot: pinned at the 165 Hz vsync cap with ~200 particles and several enemies (RTX 5070). This round's bot runs: 154-165 fps in fights with up to 10 actors and ~570 particles; single dips to 126-131 at encounter starts and one 97 at a floor load (2 actors), i.e. hitches, not load. |
| Manual (human) play | **Not yet** - needs a human to judge feel, difficulty and controls. |
| Audio | Generated and level-checked by script; **not listened to** by the developer (no audio inspection available). |

## Known issues / limitations

- Playtest foundations pass: every fix is unit-tested and the party ones
  run on separate processes on one PC; nobody has played it. To watch in
  play: whether pointer steering feels natural (it latches while W is held),
  the new brightness (ambient 1.08/1.0/0.92 by depth, a lifted light
  falloff), the arena watchdog (never seen to trigger in a real fight: look
  for "arena watchdog" in the log), attack turns (two wind-ups per Kindled),
  the Thousandth Cut's new rate. The minimap is 4 screen pixels a tile at
  the usual interface size. Generated foe falls are inspected in sheets and
  captures only.

- Combat identity pass: every form, spell and synergy is tuned by tests,
  captures and bot runs only - nobody has fought with them. Numbers to watch
  in play: Hold the Line's 4 Kindle per block, En Garde's 1s guard, the
  beam's ramp, the Cinder Orb's growth, Hearthfire's 50 Kindle / 22s, the
  Urnling's surprise. Its new sounds are generated and measured, not heard.
  The orange dither on held weapons is the existing lantern look.
- Co-op rewards (exact, `-- economy`, 12 seeds each, Ossuary 1-3, Rootmire
  and Throne 2, Tier III): XP from kills per Kindled is 1.10-1.16x solo
  (2 players), 1.23-1.28x (3), 1.34-1.44x (4) against +12% per friend;
  Embers per Kindled over a whole floor 1.04-1.10x, 1.12-1.17x, 1.19-1.26x
  (chests, urns and room rewards are not divided by design). Gear and
  material drops are not in the audit; whether these feel fair is for play.

- Development pass: nothing in its audio has been listened to by a person -
  levels, balance and the low end are set by measurement
  (tools/audio/analyze.py, bus recordings with `audiorec`), which is not the
  same as hearing it. Co-op difficulty is measured with bots on one PC
  (3 seeds x 240 s per party, Tier III): damage taken per Kindled per room is
  now in the solo band (parties 11-28%, solo 16-32%), XP per Kindled is
  1.03-1.59x solo; Embers per Kindled read 1.4-2.2x but that number divides
  by rooms cleared, which varies 1.3-7.3 between runs (too noisy to tune
  from). A 4-player melee bot party once took 89 s per room. Landmarks,
  urns, loot hang and the guardian entrance are seen in captures, not played
  by a person. All multiplayer checks ran as separate local processes, not on
  two PCs or over Steam.

- Evolution pass: the new spells, keystones, weapon variants and the co-op
  damage scaling are tuned by tests, bots and formulas only. With weapons as a
  seventh gear slot a full epic L5 kit has ~16% more offense at Tier I and
  ~30% at Tier VIII than before (power report); the tier suggestion counts it.
  Co-op parties of 3-4 are still somewhat safer per Kindled than solo in the
  bot evaluation. Equipping a different kind of weapon is refused below (only
  variants of the expedition's weapon can be taken up). Another Kindled's
  weapon tint changes only on the next floor if they swap variants mid-floor.
  The smoke test's request check needed paced presses (fixed); its pad check
  failed on the pre-session commit too in this environment (fixed in the
  test, not the game).

- Co-op: the fixes for the first two-PC playtest are verified with separate
  windows on one PC (localhost and simulated links), not yet by the two of you
  on two PCs (plan: docs/TESTING.md). Not across two machines or a real
  internet route. Steam play works on one
  account up to a hosted lobby; nobody has joined over Steam yet (needs a
  second account on another PC), and the overlay / launch-from-invite need
  the game started by Steam. No real App ID: release builds have Steam off. No host migration (a lost host ends the expedition; guests keep
  their depth checkpoint). Growing boss shapes show at their start size on
  clients. Allies' effects are not dimmed separately from your own yet.
  See docs/NETWORK.md and docs/STEAM.md.
- The licensed creature sounds are left out of exported builds (licence not
  checked for bundling); exported builds use the generated sounds.
- Armour overlays are drawn per style at 32x32; tiny pieces (gloves, boots) read
  as colour more than shape. Death frames show the Kindled without armour.
- The Tome and Bow, runes and outer keystones are tuned by tests and bots only.

- **TEST_STOCKPILE is on** (profile.gd): every save gets 60 of each material,
  6 catalysts, 1500 Embers and three starter pieces once (on upgrading to v5 or
  starting fresh), and on v6 three blueprint scrolls, five Tier II set pieces,
  40 Sun Gold and 6 of each catalyst. Turn it off before any real release.
- Difficulty and gear balance are tuned by formula and bots only; tiers V-VIII
  have not been played by anyone, and the Ashen King has only been beaten by a
  god-mode bot.
- The bot can get stuck beside a foe it cannot path to (seen once on Tier VI).
- The licensed creature sounds live only in the local, gitignored
  `assets/audio/licensed/` (licence: no redistribution, public repo). A fresh
  clone has no creature voices until `tools/audio/import_licensed.py` is run
  with the pack. An exported build includes whatever is present locally.
- Nothing in the audio has been listened to by the developer: levels are set by
  measurement (peak-normalised, distance falloff), not by ear.
- Hearthcall lets a player escape most non-boss fights if they can avoid being
  hit for 3 s; watch whether that removes too much tension.
- The Warden's and the Ashen King's trophies have been seen on screen; the
  Bloom's has not.
- The six new enemies have only been fought by the bot: telegraph lengths,
  the Gravemole's eruption, the Sunwatcher's sweep speed and the Duelist's
  stance odds need a human hand. Omen rewards are first-pass numbers.
- Restless Dead risers and red Grudge-room fires have not been captured yet.
- New enemies and the King have no drawn hurt/death frames (procedural reactions only).
- Gear balance is a first pass; no drop-rate tuning against real play yet.
- Gamepad support is verified with synthetic events only; no physical controller has been tested.
- Balance is first-pass (bot clears depth 1 comfortably; humans untested).
- In the shared sanctuary each machine hits its own training dummies (others'
  swings show, their numbers do not), and a guest's own camp (buildings,
  residents) is only seen when they host.
- Residents walk through each other and the player (no NPC collision).
- Enemy hurt reactions are procedural (recoil, squash, death slide); there are still no drawn hurt/death frames.
- Combat feel has been tuned from captured freeze frames and code review only - it needs hands on a controller.

## Next priorities

0. This pass with people: docs/TESTING.md "Human playtest: the playtest
   foundations pass" - equal levels over a whole expedition (bring the XP
   ledgers), private finds, wearing finds below, every room opening, the
   map, steering, readability, the party start and the guest at the forge.

0. The combat identity pass with people: docs/TESTING.md "Human playtest:
   the combat identity pass" - every weapon form on keyboard and pad, the
   new spells and their combinations, whether foes' wind-ups read in a
   crowd, loadouts, and party rewards over a whole expedition.

0. This pass with people: docs/TESTING.md "Human playtest: the development
   pass" - facing on keyboard, mouse and pad (and on a friend's screen), a
   listening pass on headphones and speakers (music layers, urns, drops,
   guardian arrival, anvil), 2-4 player difficulty and whether parties feel
   hunted rather than swarmed, landmarks and urn rewards.

0. The evolution pass with people: docs/TESTING.md "Human playtest: the
   evolution pass" (spells and hotbar on keyboard and pad, build feel, weapon
   variants, guardian clarity, the workshop, 2-4 player readability and
   difficulty). Then tune co-op damage for 3-4 players from real play.

1. The two-PC human playtest in docs/TESTING.md (sanctuary, conversations,
   proposal, foes, regrouping, stairs, drops) - then the LAN / internet / Steam
   checklists in docs/STEAM.md.
2. A second Steam account on a second PC: run the Steam checklist in
   docs/STEAM.md (joining, invites, Join game, relay latency, drops).
3. Co-op polish still open: dimmer allies' effects, portraits in the party
   panel, co-op-only build synergies, and making the Hollow Below more than
   numbers (depth rules, not only health).
4. Playtest the Bow, the Tome, runes and the outer keystones; tune numbers.
3. Human playtest pass on combat feel (timings, hitstop, telegraph lengths),
   the Ashen King's Eclipse, and how tiers II-IV feel with crafted gear.
2. Install Godot export templates and produce a Windows build (preset is ready).
3. Test with a physical controller (navigation, rebinding, aim assist feel).
4. Enemy hurt/attack frames polish; more resident stories (quests, gifts).
5. Playtest the new creatures and Omens; tune telegraphs and Omen payouts.
6. More events, relic synergies with the new roles (e.g. answers to supports
   and beams), boss variants, and depth-specific encounter rules.
