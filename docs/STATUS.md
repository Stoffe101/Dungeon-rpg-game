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
- Hearthtree (55 nodes, 6 branches + hybrids + keystones), 39 relics,
  forge (temper/craft), sanctuary buildings, Grudge memorial, Undervault Memory.
- Sanctuary hub (walkable), main menu, HUD, minimap/full map, skill tree UI,
  relic choice, shop, shrine, forge, descent/loadout, settings (audio, display,
  UI scale, pixel size, gameplay accessibility, key rebinding), pause, summary.
- Versioned atomic saves with backup + migration.
- Generated content: all sprites, tiles, icons, UI frames, pixel font,
  73 sound effects, 4 music loops, 2 ambience beds.

## Validation

| Kind | What |
|---|---|
| Automated tests | 37 tests: combat math, stats, statuses, settlement, XP curve, skill tree rules/connectivity/layout, relic offers, profile currencies, forge, grudges, save round-trip + corrupt-file recovery + migration, dungeon connectivity/structure/determinism/overlap/wall heights, encounter budgets, headless combat simulations (AI hunts and hits, sword combo kills, dodge i-frames + perfect dodge, Ward reflect, burn kills, projectile/wall, bloat friendly fire). `tools/dev/run_tests.sh` |
| Autopilot playtests | Headless bot runs (seed 7): clears depth 1, descends, plays depth 2. Boss run with `godmode`: Gloamfall at 54%, skitter calls, Warden dies, Hearthstone victory settles (bonus, sunshards, staff unlock). Without godmode the naive bot dies to the Warden in ~25s. Found and fixed: corridor targeting, partial pathing to solid goals, descend re-entry, freed-object timer callbacks. |
| Visual inspection (screenshots actually viewed) | Dungeon at 1080p, 720p and 3440x1421 (ultrawide), combat with HUD/gates/traps/telegraphs, boss arena phase 1, main menu, sanctuary + dialogue, occlusion silhouette, skill tree, relic choice, forge, settings, run summary. Sprite sheets for all characters, boss, icons. See `docs/screenshots/`. |
| Manual (human) play | **Not yet** - needs a human to judge feel, difficulty and controls. |
| Audio | Generated and level-checked by script; **not listened to** by the developer (no audio inspection available). |

## Known issues / limitations

- Controller: inputs are mapped, but menus and the skill tree are mouse-first.
- Brazier relighting (boss phase 2) is covered by a sim test but not yet seen on screen.
- Balance is first-pass (bot clears depth 1 comfortably; humans untested).
- UI scale 2 at 1080p not yet captured (auto picks 3).
- Sanctuary is functional but sparse; needs more set dressing and NPC life.
- No death/hurt frames for enemies beyond flash + dissolve.

## Next priorities

1. Human playtest pass on combat feel (timings, hitstop, telegraph lengths).
2. Boss validation run (bot + screenshots), arena readability in Gloamfall.
3. UI scale 2 check; controller navigation for menus and the skill tree.
4. Sanctuary set dressing; enemy hurt/attack frames polish.
5. More rooms types/events, second region, more relic synergies.
