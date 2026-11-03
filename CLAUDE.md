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
  `spawn=x,y` (where the Kindled starts in the camp), `open=bestiary`,
  `open=skilltree|forge|descent|settings|controls|pause|relic|summary|inventory|smithy|peddler|wardrobe|feats` (with `open=skilltree`: `hover=<node id>`,
  `search=<text>`), `warp=boss|event`, `pad` (act as if a
  gamepad is in use), `capture=<name> frames=N quit` (saves `captures/<name>.png` of the real rendered window),
  `frames=N quit` (quit after N frames), `autopilot` (bot plays), `godmode`, `profile=<file>` (use a separate save),
  `uismoke` (menu smoke test incl. synthetic gamepad checks; grep the log for `FAILED` / `SCRIPT ERROR`),
  `hitlab` (enemies spawned beside the player; `lab=<id,id:affix>` picks them and makes elites) with
  `capture=hit frames=380 burst=36:4` to grab fast moments; tile them with
  `-s res://tools/dev/contact_sheet.gd -- out=captures/x.png crop=800x500 [at=x,y] [scale=k] [cols=n] <files>`.
  `lootlab` (one drop of each grade beside the player), `omens=<id,id>` (read these Omens next run),
  `descend` (hub: walk through the gate a second after loading), `net=host|join:<ip>`, `name=`, `coop=<n>`,
  `coopdive`, `region=delve`, `depth=N`, `open=coop|runes`, `weapon=bow|tome|...`, `netsim=`, `netlog=`,
  `netdiag`, `steam_appid=480` (local Steam experiments). Dev args and the testing stockpile work in debug
  builds only: read them through `Dev.args()`, never `OS.get_cmdline_user_args()`.
- Release safety: `python tools/dev/release_check.py` (no Spacewar App ID, no licensed audio or
  steam_appid.txt in exports, dev switches gated); `tools/dev/build_windows.sh` (needs export templates). `warp=event` + the seed list printed
  as `[dungeon] event room N: <kind>` finds a seed for a given event.
- Enemies: stats, `role`, voice and pools in `EnemyDB`; behaviour in `src/entities/enemies/<id>.gd`.
  Encounters are built from `EnemyDB.SQUADS` (role pairings) under `ROLE_CAP`; affixes are rolled
  with `EnemyDB.roll_affix` so they only land where they work (`affix_ok`, `"no_affix"`).
  Lobbed shots: `Projectile.lob(flight, peak)` (no collision in flight; `on_end_fn` acts on landing).
- Co-op (docs/NETWORK.md, docs/STEAM.md): `Net` (src/net/net.gd, added by Game at /root/Net - not an
  autoload), `NetRun` (per floor: host snapshots/events/votes, client interpolation/prediction/reconcile),
  `Party` (who owns each interaction, guests' screens), `SteamLink` (optional GodotSteam lobbies, reached
  dynamically). A client's own Kindled is `predicting` (weapons too: timing and picture, no hits); keep
  `Player._predict` in step with `Player._think` when movement rules change. Bump `Net.PROTOCOL` when a
  message changes shape. Measure with `tools/dev/netsim_matrix.sh` and `tools/dev/coop_local.sh <n> [frames]
  [netsim...]`; `netsim=typical` (or rtt:loss:jitter), `netdiag` / F3, `netlog=<file>`. `Stage.players` holds every Kindled, `Stage.player`
  is this machine's; use `nearest_player`/`players_near`/`active_players` instead of assuming one player.
  `Player.controller` is LOCAL/REMOTE/REPLICA; stats come from `Player.sheet` (another player's
  `Profile.character_sheet()`) when set. Host-side effects are recorded through `Net.rec` (Fx, Audio,
  spawns); wrap your own recorded events with `Net.mute` when clients do the same thing themselves.
  Test with real instances: host `-- scene=hub net=host coop=2 name=Host profile=a.json autopilot` and
  client `-- scene=hub net=join:127.0.0.1 name=Guest profile=b.json autopilot`; `coopdive` walks the
  party down a depth and home again.
- Visible armour: `GearLooks.VIS` (base -> style, material, accent, variant); `tools/art/gen_gear.gd`
  draws `gear_<base>` sheets on `GenPlayer.anim_table()` poses (job `gear`); preview outfits with
  `-s res://tools/art/preview_gear.gd -- outfits=a+b,c+d`. Player layers them (`refresh_paperdoll`).
- Ember Runes: `src/data/runes.gd`; generic runes act in `Player.deal_hit` via the hit's `"ab"` meta,
  Many/Echoes/Well inside `Abilities`. Weapons: bow (draw/steady shot), tome (motes, inscribe).
- The Hollow Below (endless): `src/data/delve.gd`; `region=delve depth=N` dev args.
- Omens live in `src/data/omens.gd` (costs applied in `Omens.apply` / Dungeon hooks, rewards banked
  in `Game.end_run`). Transitions: `UIRoot.title_card(title, sub, mid, extra)`; `Game.begin_descent`.
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
  (`src/ui/gear_ui.gd` has the shared widgets). Save v10 (v6: blueprints, looks, tiers; v7: level cap, Renown, skill pages, feats; v8: `descent` = last region + Omens; v9: `runes` and per-slot `inventory.shown`; v10: `settled_runs` (co-op settlements banked once) and `identity`). `Profile.TEST_STOCKPILE` grants a
  testing stockpile once - switch it off before release. Dev: `open=inventory|smithy|peddler`, `rich`.
- Player code lives in the world SubViewport, which receives no input: read the mouse via
  `stage.view.get_global_mouse_position()` and device changes via `Settings.using_pad`.
- Grudges: `Profile.record_grudge` / `age_grudges` (traits by level in `GRUDGE_TRAITS`); spawned by
  `Dungeon._spawn_grudge`, whose room is picked before props so its fires can burn red.
- Resident requests count through `Dungeon.note_request(key)` (chest, ward, toy, sunshard,
  bramble, elite); gifts apply in `Profile.apply_sanctuary` via `Residents.apply_rewards`.

## Workflow

- Branch: `feature/initial-playable-foundation` (draft PR to `main`). Don't merge large work to main without review.
- Commit with descriptive messages; push when authenticated.
- After meaningful changes: run tests, run a capture, look at the screenshot,
  and (for gameplay) a headless autopilot run: `-- autopilot scene=dungeon seed=7 frames=20000 quit`.
- Be honest in reports: distinguish implemented / tested / visually inspected / manually played.
- Keep `docs/STATUS.md` current (known issues, validation results, next priorities).
