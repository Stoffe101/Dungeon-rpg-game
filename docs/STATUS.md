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
| Autopilot playtests | Headless bot runs (seed 7): clears depth 1, descends, plays depth 2. Found and fixed: corridor targeting, partial pathing to solid goals, descend re-entry, freed-object timer callbacks. |
| Visual inspection (screenshots actually viewed) | Dungeon at 1080p and 720p, combat with HUD and gates, main menu, sanctuary + dialogue, skill tree. Sprite sheets for all characters, boss, icons. |
| Manual (human) play | **Not yet** - needs a human to judge feel, difficulty and controls. |
| Audio | Generated and level-checked by script; **not listened to** by the developer (no audio inspection available). |

## Known issues / limitations

- Tall pillars can hide the player behind them (no occlusion silhouette yet).
- Controller: inputs are mapped, but menus and the skill tree are mouse-first.
- Boss fight has only been exercised in code paths, not completed by the bot yet.
- Balance is first-pass (bot clears depth 1 comfortably; humans untested).
- UI layout verified at 1080p/720p via captures; 3440x1440 not yet captured.
- Hub is dark at low Hearth levels; lighting needs a pass.
- No death/hurt frames for enemies beyond flash + dissolve.

## Next priorities

1. Human playtest pass on combat feel (timings, hitstop, telegraph lengths).
2. Boss validation run (bot + screenshots), arena readability in Gloamfall.
3. Ultrawide capture/inspection; UI scale 2/3 checks.
4. Occlusion silhouette, hub lighting/decoration pass.
5. More rooms types/events, second region, more relic synergies.
