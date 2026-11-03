# Kindled Deep - project guide for Claude Code

A 2.5D action roguelite dungeon crawler with deep incremental RPG progression,
built in **Godot 4.7.2** (GDScript, Forward+). Windows PC first.

## The vision (keep this identity)

- **Mostly active combat.** The player moves, aims, attacks, dodges, wards and
  casts manually. Never turn it into an idle or auto-combat game.
- **Light is the theme.** The sun died; the Kindled carries hearth-fire in a
  lantern into the Undervault. Kindle (combat resource) also drives the lantern's
  light radius. Warm ember = player; cold teal soul-light = the Undervault.
- **The dungeon remembers.** Grudges (the enemy that killed you returns named,
  carrying your lost Embers), Undervault Memory (difficulty/reward rises after
  victories). Grow this into a signature system.
- **Deep permanent progression** (Hearthtree skill tree, forge, sanctuary) that
  expands build variety rather than trivialising combat.
- **Quality over scope.** Polish and playtest systems before adding more.

You have broad creative freedom: invent, replace, remove and redesign when it
makes the game better. Document significant decisions in `docs/DESIGN.md`.

## Paths and commands

Godot executable (the user's `godot.cmd` points to a missing 4.7.1 build; use this):

```
GODOT="/c/Users/Skrra/Desktop/Godot_v4.7.2-stable_win64.exe"
```

- Import / refresh class cache (needed after adding `class_name` scripts):
  `"$GODOT" --headless --path . --import`
- Run tests (exit code 0 = pass): `"$GODOT" --headless --path . res://tests/test_runner.tscn`
- Balance report (gear power vs difficulty tiers): `"$GODOT" --headless --path . res://tools/dev/power_report.tscn`
- After rebuilding art, run `--import` again or the game keeps showing the old textures.
- Licensed sounds: `python tools/audio/import_licensed.py <Minifantasy_Creatures_SFX_v3.0.zip>`
  writes the gitignored `assets/audio/licensed/` (never commit those: no redistribution, public repo).
  A name there overrides `assets/audio/sfx/`; `<name>_2`... are random takes. Creature voices are
  `v_<kind>_<event>` from `EnemyDB` `"voice"`.
- Rebuild art: `"$GODOT" --headless --path . -s res://tools/art/build_art.gd [-- only=player,enemies,...]`
- Rebuild audio: `"$GODOT" --headless --path . -s res://tools/audio/build_audio.gd [-- only=sfx|music|amb]`
- Preview a sprite sheet upscaled: `"$GODOT" --headless --path . -s res://tools/art/preview.gd -- res://assets/sprites/husk.png scale=5`
- Run the game: `"$GODOT" --path .`
- Dev args (after `--`): `scene=menu|hub|dungeon|boss`, `region=ossuary|rootmire|throne`, `seed=N`,
  `tier=N` (open and select a difficulty tier), `kit=N` (wear random epic gear of item tier N),
  `unlock=all` (open every region and tier), `wear=<set or base ids>`, `look=<look id>`,
  `hearthcall` (start a Hearthcall a second after the floor loads), `audiolog` (print every sound played),
  `open=skilltree|forge|descent|settings|controls|pause|relic|summary|inventory|smithy|peddler|wardrobe|feats` (with `open=skilltree`: `hover=<node id>`,
  `search=<text>`), `warp=boss|event`, `pad` (act as if a
  gamepad is in use), `capture=<name> frames=N quit` (saves `captures/<name>.png` of the real rendered window),
  `frames=N quit` (quit after N frames), `autopilot` (bot plays), `godmode`, `profile=<file>` (use a separate save),
  `uismoke` (menu smoke test incl. synthetic gamepad checks; grep the log for `FAILED` / `SCRIPT ERROR`),
  `hitlab` (enemies spawned beside the player) with `capture=hit frames=380 burst=36:4` to grab fast
  moments; tile them with `-s res://tools/dev/contact_sheet.gd -- out=captures/x.png crop=800x500 <files>`.
- Input: the bot and smoke test call `prop.interact()` directly, so they cannot catch a missing
  input path; `tests/test_sim.gd` presses the real `interact` action. Bindings are created with
  `device = -1` (all pads). Godot's `ui_accept`/`ui_cancel` get pad A/B added in `Settings.apply_bindings`.
- Sanctuary people (Keeper, smith, merchant, residents) share one rig in `tools/art/gen_npc.gd`:
  add a character by adding a spec there (outfit, hair, headwear, held/back items), not new drawing code.
- Always use `profile=dev_profile.json` (or similar) for dev runs so the real save is untouched.
- `-s` tool scripts cannot see autoloads; anything needing `Profile`/`Settings`
  must run as a scene (see `tests/test_runner.tscn`).
- A `-s` script that errors before `quit()` hangs: always use `timeout`.

## Architecture in one breath

`src/core` pure rules (Stats, Hit, Combat, StatusSet, RunState, Iso projection) ->
`src/data` data tables (SkillDB, RelicDB, GearDB, ItemDB, EnemyDB, Difficulty, Looks, Lore, Keeper) ->
`src/world` (TileGrid, DungeonGen, Room, Stage, Dungeon, Hub, LevelBuilder, Prop, Pickup) ->
`src/entities` (Actor, Player, Enemy + enemies/, Projectile, Hazard, Wisp) ->
`src/combat` (Weapon + weapons/, Abilities) -> `src/render` (PixelView, PixelSprite,
SpriteLib, Fx) -> `src/ui` (UIRoot, HUD, Minimap, SkillTreeUI, Screens, UIKit).
Autoloads: Events, Settings, Profile, Audio, Game. See `docs/ARCHITECTURE.md`.

Key conventions:
- Simulation is 2D (tiles, `Vector2` pos). Presentation maps through `Iso.to_world`.
  World z and y are stretched by sqrt(2) so the 45-degree ortho camera shows art 1:1.
- Sprite sheets are PNG + JSON sidecar (+ optional `_emit.png` emission mask)
  generated by `tools/art`. Origins must be horizontally centred (flip mirrors the quad).
- Stage runs its own clock (`simulate(dt)`), so hitstop/slow-mo never touch UI.
- All player-dealt damage goes through `Player.deal_hit`; all damage to the player
  through `Player.take_enemy_hit` (dodge/ward/aegis/barrier logic lives there).
- Generation must be deterministic per seed: never use `Array.shuffle()` or global
  `randf()` in `DungeonGen` (use the passed rng / `_shuffle`).
- Saves: `Profile` writes JSON atomically with `.bak`; bump `VERSION` and extend
  `Profile.migrate()` for any schema change. Never break old saves. (v4 added `requests`.)
- Hearthtree mastery ranks are repeated ids in `Profile.data.skills`: use `SkillDB.rank()` /
  `SkillDB.unique()` rather than assuming the list is a set.
- Gear: `src/data/item_db.gd` (bases, materials, affixes, drops), `Profile` inventory API
  (bag/equipped/materials, `pay` for mixed costs, equip/unequip/salvage), loot carried in
  `RunState.loot` and banked in `Game.end_run`. Screens: `InventoryUI`, `SmithyUI`, `PeddlerUI`
  (`src/ui/gear_ui.gd` has the shared widgets). Save v7 (v6: blueprints, looks, tiers; v7: level cap, Renown, skill pages, feats). `Profile.TEST_STOCKPILE` grants a
  testing stockpile once - switch it off before release. Dev: `open=inventory|smithy|peddler`, `rich`.
- Player code lives in the world SubViewport, which receives no input: read the mouse via
  `stage.view.get_global_mouse_position()` and device changes via `Settings.using_pad`.
- Resident requests count through `Dungeon.note_request(key)` (chest, ward, toy, sunshard,
  bramble, elite); gifts apply in `Profile.apply_sanctuary` via `Residents.apply_rewards`.

## Workflow

- Branch: `feature/initial-playable-foundation` (draft PR to `main`). Don't merge large work to main without review.
- Commit with descriptive messages; push when authenticated.
- After meaningful changes: run tests, run a capture, look at the screenshot,
  and (for gameplay) a headless autopilot run: `-- autopilot scene=dungeon seed=7 frames=20000 quit`.
- Be honest in reports: distinguish implemented / tested / visually inspected / manually played.
- Keep `docs/STATUS.md` current (known issues, validation results, next priorities).
