# Status

Last updated: 2026-11-03.

## Implemented

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
- Wardrobe (transmog): eight looks (sets and legendaries unlock them), applied
  as a palette swap in the sprite shader and in menu portraits. Save v6.
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
| Automated tests | 57 tests (incl. difficulty tiers and the capstone unlock, enemy tier scaling and double affixes, tier might, every region's creatures having scripts/sheets/tiles and rolling only their own pool, blueprints and learning, sets/uniques/looks, gear rolls/stats, equip/craft/salvage, run loot settlement, footsteps on contact frames, mastery ranks, resident requests and gifts, save migration v3->v4, Hearthtree route finding and stat totals, Warden brazier sear, Rootmire brambles never sealing doors, event room generation, Interact through the real input action, device-aware button labels, residents arriving and walking between spots), run locally and on GitHub Actions: combat math, stats, statuses, settlement, XP curve, skill tree rules/connectivity/layout, relic offers, profile currencies, forge, grudges, save round-trip + corrupt-file recovery + migration, dungeon connectivity/structure/determinism/overlap/wall heights, encounter budgets, headless combat simulations (AI hunts and hits, sword combo kills, dodge i-frames + perfect dodge, Ward reflect, burn kills, projectile/wall, bloat friendly fire). `tools/dev/run_tests.sh` |
| Autopilot playtests | Headless bot runs (seed 7): clears depth 1, descends, plays depth 2. Boss run with `godmode`: Gloamfall at 54%, skitter calls, Warden dies, Hearthstone victory settles (bonus, sunshards, staff unlock). Without godmode the naive bot dies to the Warden in ~25s. Rootmire (godmode): depth 1-2, Bloom wilted by all four burned roots, victory. Event rooms: bot completes a Trial (3 waves, reward), Ember Well and Echo offers without script errors. Loot: a god-mode run through depth 2 and the Warden banked materials, two epic pieces and the Gloamward Lantern into the save. Combat feel: burst captures (`hitlab burst=`) reviewed frame by frame for impacts and flash bloom; sword, hammer and staff autopilot runs clean after the change. Requests: a god-mode run with five active requests counted elite kills, a Sunshard, a chest and Wren's bird (the bot never Wards, so the Ward counter is only checked by code review). Found and fixed: corridor targeting, partial pathing to solid goals, descend re-entry, freed-object timer callbacks. |
| This round (tiers, Throne, gear) | Bots with tier-matched epic gear (`kit=N`), Ossuary seed 11: Tier I/kit I and Tier IV/kit IV reach depth 2 alive (98 and 84 kills); Tier IV with Tier I gear dies at depth 2; fresh, ungeared characters died early on Tiers IV and VI (measured before the final curve tune). Tier VI with Tier VI gear reaches depth 2 and dies there after 90 kills (the bot never uses the Hearthtree or sanctuary, so it is weaker than a real Kindled at that point); one earlier Tier VI bot got stuck beside a foe it could not reach (bot pathing; foe diagnostics added to the bot log). Sunken Throne on Tier IV with Tier IV gear: clears depths 1-2 and dies in the first room of depth 3 (115 kills). A second god-mode King kill (seed 3, Tier I) after the poise change: Eclipse at 49%, victory opens Tier III. God-mode bot kills the Ashen King: Eclipse at 49%, victory banks the Sunfall Mantle, a set piece and a blueprint, and Tier II opens Tiers III-IV. Throne floors and the Rootmire/Ossuary at depth 3 run without script errors. Balance numbers from `tools/dev/power_report.tscn` (see DESIGN). |
| Visual inspection (screenshots actually viewed) | This round: wardrobe portraits and all eight looks in-game, Descent tier picker, Throne floor (redone once: the first gold-flecked slabs read as rust), Ashen King fight (sweep, corona, stagger), Throne foes (Eclipse Acolyte with orbs, hounds), sprite sheets for the King, Sentinel, Hound, Acolyte, Wraith, Spider and Toad. Earlier: dungeon at 1080p, 720p and 3440x1421 (ultrawide), combat with HUD/gates/traps/telegraphs, boss arena phase 1 and Gloamfall, Rootmire rooms and the Hollow Bloom arena, event rooms (Echo, Trial), main menu, sanctuary + dialogue (early and progressed: residents, barks, garden), gamepad menus (focus ring, pad prompts, rebinding columns, skill tree hints), redrawn sanctuary NPCs (sprite sheets and in the hub), the new Hearthtree (empty, partly allocated, route preview affordable/unaffordable, search, masteries, branch focus, 1080p and ultrawide), request markers and the pause-menu journal, occlusion silhouette, relic choice, forge, settings, run summary. Sprite sheets for all characters, boss, icons. See `docs/screenshots/`. |
| UI smoke test | `-- uismoke`: opens every screen and presses its buttons (sanctuary building, forge craft/temper, weapon rack, skill allocate/refund/respec, memorial, settings tabs, merchant purchases, blood pact, chest, lore, Hearthstone confirm, extraction), kindles a distant Hearthtree node (checks exactly the previewed path is bought), moves the mouse around the player (aim, facing, swing direction), equips from the satchel, forges, masterworks, tempers, salvages, buys and sells, searches and focuses branches, ranks up a mastery and reads its tooltip, plays a resident's request conversation through to the gift, then drives menus with synthetic gamepad events (B interacts/backs out, A confirms, RB switches tabs, focus follows). Found and fixed the shop/forge refresh bug, a late-descend race, and (in the input audit) a missing Interact input path: until this fix a human could not open chests, trade or take the stairs - the bot and smoke test had been calling `interact()` directly. |
| Build coverage | Bot runs with hammer, staff, and the entire skill tree allocated (`skills=all`): no script errors after fixes (Wildfire implemented; freed-source guards). |
| Performance | Windowed 1080p autopilot: pinned at the 165 Hz vsync cap with ~200 particles and several enemies (RTX 5070). |
| Manual (human) play | **Not yet** - needs a human to judge feel, difficulty and controls. |
| Audio | Generated and level-checked by script; **not listened to** by the developer (no audio inspection available). |

## Known issues / limitations

- **TEST_STOCKPILE is on** (profile.gd): every save gets 60 of each material,
  6 catalysts, 1500 Embers and three starter pieces once (on upgrading to v5 or
  starting fresh), and on v6 three blueprint scrolls, five Tier II set pieces,
  40 Sun Gold and 6 of each catalyst. Turn it off before any real release.
- Difficulty and gear balance are tuned by formula and bots only; tiers V-VIII
  have not been played by anyone, and the Ashen King has only been beaten by a
  god-mode bot.
- The bot can get stuck beside a foe it cannot path to (seen once on Tier VI).
- New enemies and the King have no drawn hurt/death frames (procedural reactions only).
- Gear balance is a first pass; no drop-rate tuning against real play yet.
- Gamepad support is verified with synthetic events only; no physical controller has been tested.
- Balance is first-pass (bot clears depth 1 comfortably; humans untested).
- UI scale 2 at 1080p not yet captured (auto picks 3).
- Residents walk through each other and the player (no NPC collision).
- Enemy hurt reactions are procedural (recoil, squash, death slide); there are still no drawn hurt/death frames.
- Combat feel has been tuned from captured freeze frames and code review only - it needs hands on a controller.

## Next priorities

1. Human playtest pass on combat feel (timings, hitstop, telegraph lengths),
   the Ashen King's Eclipse, and how tiers II-IV feel with crafted gear.
2. Install Godot export templates and produce a Windows build (preset is ready).
3. Test with a physical controller (navigation, rebinding, aim assist feel).
4. Enemy hurt/attack frames polish; more resident stories (quests, gifts).
5. More events and relic synergies; a third region; enemy variety per depth.
