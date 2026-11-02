# Status

Last updated: 2026-11-02 (first development session).

## Implemented

- 2.5D pixel renderer (integer-scaled low-res viewport, sqrt(2) projection,
  quantised/dithered lighting, emissive masks, bloom, texel-snapped camera).
- Player: movement, aim (mouse or right stick), 3 weapons with combos and charged
  attacks, dodge charges + perfect dodge, Ward (parry/reflect), Kindle, flask,
  6 abilities (Flare, Cinder Lance, Frost Sigil, Gloamstep, Aegis, Wisp Familiar).
- 6 enemy types + elite affixes + Grudges; the Gloam Warden boss (2 phases,
  brazier arena mechanic, enrage).
- Status effects (Burn, Chill/Freeze, Stagger, Exposed) and reactions
  (Thermal Shock, Combustion, Shatter, pit plunges, bloat blasts).
- Procedural floors (main path, branches, merged halls, loops, secret room),
  stamp-composed rooms, reward previews on doors, gates, waves, merchant,
  shrine of pacts, rest springs, treasure, stairs + Hearthstone extraction.
- Second region, the Rootmire (unlocked by the Warden): new tileset, burnable
  brambles, 4 enemies, the Hollow Bloom boss, music/ambience, lore.
- Room events: Ember Well, Trial of the Undervault, Echo of a Fallen Kindled.
- Gamepad: aim assist; every menu navigable (auto-focus with a gold focus ring,
  A confirm, B back, LB/RB switch tabs); skill tree cursor; prompts and the
  controls card show pad buttons when a pad is in use; separate keyboard and
  gamepad rebinding. CI on GitHub Actions.
- Hearthtree (55 nodes, 6 branches + hybrids + keystones), 39 relics,
  forge (temper/craft), sanctuary buildings, Grudge memorial, Undervault Memory.
- Sanctuary camp: residents who arrive with progress, wander, sit, bark and talk;
  benches, cookpot, tent, crates, banners, planters that bloom over time.
- Sanctuary hub (walkable), main menu, HUD, minimap/full map, skill tree UI,
  relic choice, shop, shrine, forge, descent/loadout, settings (audio, display,
  UI scale, pixel size, gameplay accessibility, key rebinding), pause, summary.
- Versioned atomic saves with backup + migration.
- Generated content: all sprites, tiles, icons, UI frames, pixel font,
  73 sound effects, 4 music loops, 2 ambience beds.

## Validation

| Kind | What |
|---|---|
| Automated tests | 44 tests (incl. Warden brazier sear, Rootmire brambles never sealing doors, event room generation, Interact through the real input action, device-aware button labels, residents arriving and walking between spots), run locally and on GitHub Actions: combat math, stats, statuses, settlement, XP curve, skill tree rules/connectivity/layout, relic offers, profile currencies, forge, grudges, save round-trip + corrupt-file recovery + migration, dungeon connectivity/structure/determinism/overlap/wall heights, encounter budgets, headless combat simulations (AI hunts and hits, sword combo kills, dodge i-frames + perfect dodge, Ward reflect, burn kills, projectile/wall, bloat friendly fire). `tools/dev/run_tests.sh` |
| Autopilot playtests | Headless bot runs (seed 7): clears depth 1, descends, plays depth 2. Boss run with `godmode`: Gloamfall at 54%, skitter calls, Warden dies, Hearthstone victory settles (bonus, sunshards, staff unlock). Without godmode the naive bot dies to the Warden in ~25s. Rootmire (godmode): depth 1-2, Bloom wilted by all four burned roots, victory. Event rooms: bot completes a Trial (3 waves, reward), Ember Well and Echo offers without script errors. Found and fixed: corridor targeting, partial pathing to solid goals, descend re-entry, freed-object timer callbacks. |
| Visual inspection (screenshots actually viewed) | Dungeon at 1080p, 720p and 3440x1421 (ultrawide), combat with HUD/gates/traps/telegraphs, boss arena phase 1 and Gloamfall, Rootmire rooms and the Hollow Bloom arena, event rooms (Echo, Trial), main menu, sanctuary + dialogue (early and progressed: residents, barks, garden), gamepad menus (focus ring, pad prompts, rebinding columns, skill tree hints), occlusion silhouette, skill tree, relic choice, forge, settings, run summary. Sprite sheets for all characters, boss, icons. See `docs/screenshots/`. |
| UI smoke test | `-- uismoke`: opens every screen and presses its buttons (sanctuary building, forge craft/temper, weapon rack, skill allocate/refund/respec, memorial, settings tabs, merchant purchases, blood pact, chest, lore, Hearthstone confirm, extraction), then drives menus with synthetic gamepad events (B interacts/backs out, A confirms, RB switches tabs, focus follows). Found and fixed the shop/forge refresh bug, a late-descend race, and (in the input audit) a missing Interact input path: until this fix a human could not open chests, trade or take the stairs - the bot and smoke test had been calling `interact()` directly. |
| Build coverage | Bot runs with hammer, staff, and the entire skill tree allocated (`skills=all`): no script errors after fixes (Wildfire implemented; freed-source guards). |
| Performance | Windowed 1080p autopilot: pinned at the 165 Hz vsync cap with ~200 particles and several enemies (RTX 5070). |
| Manual (human) play | **Not yet** - needs a human to judge feel, difficulty and controls. |
| Audio | Generated and level-checked by script; **not listened to** by the developer (no audio inspection available). |

## Known issues / limitations

- Gamepad support is verified with synthetic events only; no physical controller has been tested.
- Balance is first-pass (bot clears depth 1 comfortably; humans untested).
- UI scale 2 at 1080p not yet captured (auto picks 3).
- Residents walk through each other and the player (no NPC collision).
- No death/hurt frames for enemies beyond flash + dissolve.

## Next priorities

1. Human playtest pass on combat feel (timings, hitstop, telegraph lengths).
2. Install Godot export templates and produce a Windows build (preset is ready).
3. Test with a physical controller (navigation, rebinding, aim assist feel).
4. Enemy hurt/attack frames polish; more resident stories (quests, gifts).
5. More events and relic synergies; a third region; enemy variety per depth.
