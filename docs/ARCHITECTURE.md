# Architecture

## Layers

```
src/core      pure rules, no scene tree: Iso (projection), Stats, Hit, Combat,
              StatusSet, RunState
src/data      content tables: SkillDB (Hearthtree), RelicDB, GearDB (weapons,
              abilities), ItemDB (gear, sets, uniques, blueprints, materials),
              EnemyDB (enemies, affixes, regions), Difficulty (tiers and
              their unlocks), Looks (wardrobe palette swaps), Lore, Keeper
src/world     TileGrid (collision/LOS), DungeonGen + Room (generation),
              Stage (simulation host), Dungeon / Hub (concrete stages),
              LevelBuilder (meshes), Prop, Pickup
src/entities  Actor (base), Player, Enemy (+ enemies/*), Projectile, Hazard, Wisp,
              LanternTotem (the Hearth Lantern spell)
src/combat    Weapon (+ weapons/*), Abilities, Volley (projectile modifiers:
              count, pierce, chain, fork, return; one strike per foe per volley)
src/render    PixelView (low-res viewport + camera), PixelSprite, SpriteLib, Fx
src/ui        UIRoot (layers/modals), HUD (hotbar), PartyFrames (co-op cards),
              Minimap, SkillTreeUI, Screens, UIKit
src/autoload  Events (signal bus), Settings, Profile (saves), Audio, Game (flow)
src/dev       Capture (screenshots), Bot (autopilot playtests), Scenario (e2e),
              BuildPresets (build=<preset>), ScalingEval (-- scaling)
tools/        art/ and audio/ generators, dev/ helpers (all run headless)
tests/        headless test runner + suites
```

## Rendering

- `PixelView` owns a `SubViewport` sized `window / pixel_scale` (+2px margin),
  where `pixel_scale = round(window_h / 270)` (1080p -> 4x, 1440p -> 5x).
  Its texture is shown by a `TextureRect` with nearest filtering.
- Orthographic `Camera3D`, pitch -45 degrees, `size = internal_h / 16`.
  World mapping: `Iso.to_world(plane, h) = (x, h*sqrt2, y*sqrt2)`; this makes floor,
  wall-face and upright-sprite texels exactly one screen pixel.
- The camera position is snapped to the texel grid in camera space; the
  remaining fraction offsets the displayed texture, so motion is smooth without
  shimmering. Actors also snap their positions to the texel grid.
- `world.gdshader` (floors/walls) and `sprite.gdshader` (actors/props) use a
  custom `light()` that quantises light into bands with Bayer dithering.
  Sprites ignore N.L so they're lit from any side.
- `ground_fx.gdshader` paints telegraphs, slash arcs, rings and sigils onto the
  floor with UVs snapped to the 16px grid. `Fx` also runs a MultiMesh pixel
  particle system, flash lights, afterimages, damage numbers and screen shake.
- UI is a normal 2D canvas scaled by an integer `content_scale_factor`
  (auto = floor(h/360)), using the generated bitmap font for crisp pixels.

## Simulation

- `Stage._process` computes `dt` (clamped), applies hitstop/slow-motion and calls
  `simulate(dt)`: timers, actors, projectiles, hazards, pickups, props, actor
  separation, then `_stage_tick`. Effects step on real time.
- Collision is tile-based (`TileGrid.move_box`), pathing uses `AStarGrid2D`
  (`Stage.path_step`, partial paths allowed). Pits block walking but not shots;
  knockback can push enemies into pits.
- Hit queries: `Stage.in_circle / in_arc / in_line / nearest_hostile`.
- Damage: `Combat.resolve(hit, status, armor, damage_taken, roll, shatter, block)`
  is pure and tested. `Player.deal_hit` layers skill/relic interactions on top;
  `Player.take_enemy_hit` handles dodge/perfect-dodge/Ward/Aegis/barrier.
- Delayed effects: `Stage.after(seconds, callable)` on simulation time. A callable
  bound to an object that may be freed first must come from a **static** function
  (see `Bloat._blast_later`), otherwise Godot drops or misroutes it.

## Content pipeline

- `tools/art/*.gd` draw sprites with `px.gd` (masks + ramp shading + outlines)
  from `pal.gd`. `sheet.gd` writes `name.png`, `name.json` (frame, origin, anims)
  and `name_emit.png` (emission mask). `SpriteLib` loads these and caches one
  `ShaderMaterial` + quad per sheet; per-instance shader params carry frame/flip/flash.
- `tools/audio/synth.gd` renders SFX (44.1 kHz) and loops (22.05 kHz) to WAV.
- Project-wide import defaults disable texture compression and mipmaps.

## Persistence

- `Profile` (autoload) holds the save dict. `save_profile()` writes JSON to a
  temp file, verifies it parses, rotates the old save to `.bak`, renames.
  `load_profile()` falls back to `.bak` when the main file is unreadable.
  `migrate()` upgrades old versions and fills new keys; `VERSION` = 10.
- `Settings` persists to `user://settings.cfg` (options + rebinds). Input actions
  are created in code from `DEFAULT_BINDINGS`.

## Networking (co-op)

See NETWORK.md. In one breath: `Net` (transport: ENet or Steam through
`use_peer`; roster, seats, RPCs, simulated conditions) -> `NetRun` per floor
(host: snapshots per client at 30 Hz with deltas and interest, events every
frame, remote input, votes, floor barrier; client: interpolation buffer,
prediction record and reconciliation) -> `Party` (interaction ownership and
guests' screens). The host's world is the only simulation; a client's own
Kindled is predicted (`Player._predict`, weapons in predicting mode) and every
other actor is a replica drawn in the past.

## Flow

`Game.goto_menu()` (hub in menu mode behind the title) -> `goto_hub()` ->
`start_run()` -> `_enter_depth(n)` builds a `Dungeon` from `DungeonGen.generate`
-> `descend()` -> ... -> `end_run(outcome)` settles currencies, Grudges and stats,
saves, shows the summary -> `goto_hub()`.

## Builds, weapons and rewards (evolution pass)

- **Projectiles**: anything a Kindled looses is made with `Volley.fire` (or
  shaped with `Volley.shape` after a weapon builds it). The player's stats
  `projectiles`, `pierce`, `chain`, `fork` and the flags `proj_return`,
  `ember_hail`, `seeking` decide the shot; `Projectile.group` (shared by a
  volley) keeps one strike per foe. Chain/fork/return live in `Projectile`.
- **Spells**: `Abilities.cast` (one function per spell). Three slots
  (`Player.ability_slots`, `ability_cd`, `slot_open` for the level-5 lock);
  the network presses are `a1..a3`, the third cooldown rides in the player
  snapshot row (index 28) with Momentum (29).
- **Weapon items**: `inventory.equipped.weapon` holds an item whose base names
  its archetype (`ItemDB.arch_of`); `Profile.equipped_weapon()` prefers it,
  `Profile.choose_weapon()` changes archetype at the forge. The stat
  `weapon_damage` multiplies `Weapon.damage_scale()` (forge level x item).
  Another Kindled's weapon item comes from their sheet (`Player.weapon_item`),
  so tints and stats match on every machine.
- **Co-op rewards**: `Dungeon._spawn_wave` scales foe count, `_coop_scale`
  health and damage, `Party.reward_share` each foe's XP / Embers / loot odds;
  gear rolls are per Kindled (`_gear_drop`, weapons leaning to each finder's
  archetype through `_favour`).
- **Depths**: `Delve.depth_title` / `depth_short` / `floor_def` describe any
  depth (regions and the Hollow Below) for cards, banners, HUD and map.
