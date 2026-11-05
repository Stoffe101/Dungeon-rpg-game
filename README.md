# Kindled Deep

*Carry the last fire into the dark.*

A 2.5D action roguelite dungeon crawler with deep incremental RPG progression,
built in **Godot 4.7** (GDScript). The sun is dead; you are a Kindled, carrying
hearth-fire in a lantern down into the Undervault - a living dungeon that
remembers who hurts it.

![Combat](docs/screenshots/combat.png)

| | |
|---|---|
| ![The Gloam Warden](docs/screenshots/boss.png) | ![The Hearthtree](docs/screenshots/skilltree.png) |
| ![Main menu](docs/screenshots/menu.png) | ![Relic choice](docs/screenshots/relic_choice.png) |
| ![The Rootmire](docs/screenshots/rootmire.png) | ![Gloamfall](docs/screenshots/gloamfall.png) |
| ![Echo of a Fallen Kindled](docs/screenshots/echo.png) | ![Trial of the Undervault](docs/screenshots/trial.png) |
| ![The satchel](docs/screenshots/satchel.png) | ![The smithy](docs/screenshots/smithy.png) |
| ![The Ashen King's Eclipse](docs/screenshots/ashen_king.png) | ![The wardrobe](docs/screenshots/wardrobe.png) |
| ![Difficulty tiers and the three-spell loadout](docs/screenshots/descent.png) | ![The Sunken Throne](docs/screenshots/sunken_throne.png) |
| ![A guardian's floor](docs/screenshots/guardian_depth.png) | ![The smith's workshop, level 1 and 3](docs/screenshots/workshop.png) |
| ![Gloam Knives](docs/screenshots/spells_knives.png) | ![Weapon and gear icons](docs/screenshots/item_icons.png) |

## Features

- Skill-based combat: five distinct weapons (blade, hammer, staff, twin daggers,
  glaive) with combos and charged attacks, forged up to +10 with Masterwork and
  Ascended upgrades,
  dodge with perfect-dodge slow motion, Ward (parry and reflect), Kindle-fuelled
  abilities, status effects and elemental reactions.
- Procedural floors with branching routes, reward previews on doors, secret
  rooms, merchants, shrines of pacts, traps and extraction points.
- Room seals of woven soul-light, region by region.
- Twenty-two creatures with roles and readable telegraphs - burrowing
  Gravemoles, shield-binding Lampwights, Spore Mortars, wall-growing
  Bramblewrights, riposting Duelists, beam-sweeping Sunwatchers and more - built
  into fights by role pairings; elites with behaviour-changing affixes (Molten,
  Splitting, Gloom...).
- **Grudges**: the enemy that kills you returns by name, carrying your lost
  Embers - and left alone it grows, learning new traits.
- **Omens**: optional signs read at the Undervault Gate (Lightless, Restless
  Dead, Glass Kindled...) that make a descent harder and pay for it.
- Three regions of three depths: the Hollow Ossuary (the Gloam Warden snuffs the
  arena's light), the Rootmire (burnable brambles; the Hollow Bloom, a rooted
  corpse-flower whose roots you burn to wilt it) and the capstone, the Sunken
  Throne (the Ashen King puts out the sun - stand in the braziers' light).
- Difficulty tiers I-VIII (tougher foes, two-affix elites, richer loot);
  conquering the Sunken Throne opens the next tiers.
- Room events: Ember Wells, Trials of the Undervault, echoes of fallen Kindled,
  Sconce Vaults (light every sconce before one burns out) and lost camps.
- Loot beams by rarity, and the light of what you wear.
- **Co-op for up to four** over LAN or direct IP (Steam lobbies and invites when
  built with GodotSteam): your own Kindled answers at once (client prediction),
  everyone else is drawn smoothly; each Kindled keeps their own gear, tree,
  Grudges and rewards; currency is shared, gear drops for each of you; the
  party votes on the stairs and the Hearthstone; downed friends can be revived,
  and a friend whose link drops can come back to their seat.
- **Ember Runes**: set runes in your spells to make them split, arc, echo, turn
  to frost or shadow, burst, siphon or pull - each rune reads differently in each spell.
- Seven weapons, including the Hearthbow (timed Steady Shots) and the
  Emberwright's Tome (a spellcaster's book that hurries your spells).
- **Weapons as loot**: 31 weapon items - variants of each weapon with their own
  identity (the heavy Gravecleaver, the forked Splitbranch Staff, the frost Long
  Rimebow...), a build-defining unique per weapon and a legendary per guardian.
  The forge's levels for a weapon carry over to every variant.
- **Projectile builds**: more projectiles, piercing, chaining, splitting and
  returning shots for everything you loose, and new spells - Gloam Knives,
  Hearth Lantern, Ember Rush, Rekindle - in three spell slots.
- **Hearthtree build paths** with new keystones (Thousand Cuts, Ember Hail,
  Last Light, Spellblade) and co-op support (Hearthbond, Rekindle).
- **A party you can read**: cards for every friend (health, Kindle, level,
  downed and revive state), names that never pile up, your own Kindled marked;
  shared XP and personal loot tuned so no party size pays more than playing well.
- Depths with names and moods, a clear "Depth 2 of 3 / Guardian Depth", hand-made
  rooms among the generated ones, and a smith's workshop that grows with you.
- **Armour you can see**: every helm, chest, glove and boot is drawn on the
  Kindled; the wardrobe can show any piece you own, or hide it.
- **The Hollow Below**: an endless descent with an Echo of a guardian every
  third depth and one more Omen at every depth; past depth 9 the regions bleed together and
  the dark deepens.
- **Weapons that play differently**: every variant is a form of its weapon
  with its own mechanic - a riposting sabre, a heating forge-mallet, a
  line-holding partisan, a volley bow, glyph-writing and fire-breathing
  tomes - and the uniques have their own looks and signature moments.
- **Spells of every kind**: a beam you steer, an orb you burst, a wall of
  ice, a form of living fire - with Hearthtree synergies and loadouts.
- **Foes that tell their blows**: the one about to strike glows, and what
  its telegraph covers is what it hits.
- **Landmarks**: now and then a fight takes place around a region's great
  centrepiece - the Bone Colossus, the Heart-Root, the Fallen Sun-Disc - each
  with something to give.
- **Co-op that hunts the whole party**: foes share themselves out, flank a
  Kindled standing alone, and guardians call for help; rewards stay fair.
- **A fair party**: every Kindled earns the same from every shared fight and
  find; your own finds are yours alone (nobody else sees them), go straight
  into your Satchel and can be worn on the spot, below as at home.
- **A map that reads**: the full map and minimap drawn from the real floor
  plan, with every member of the party on them.
- **A world that says what things are**: names and actions over everything
  you can use, urns that shatter, loot that hangs in the air before it lands,
  music that swells with each fight.
- The Hearthtree: a 74-node constellation skill tree with keystones, hybrids and
  ranked masteries, route preview (click any node to kindle the path to it),
  search, a bonuses panel and three saved pages. Levels cap at 60 - about half
  the tree - so builds are choices; experience beyond becomes Renown, and 22
  Feats set long goals (a few grant a point past the cap);
  39 relics that steer builds; an evolving sanctuary whose survivors arrive,
  wander, and talk as the Hearth grows - and ask favours that earn permanent
  gifts - with trophies of fallen bosses, a rack of forged weapons, a lantern lit
  for every two feats and a camp cat.
- Hearthcall: stand still for three seconds and the Hearth pulls you home.
- A bestiary of every creature you have met, with their lore.
- Gear and crafting: six equipment slots, rarities, levels and item tiers,
  four colour-themed tier sets, twenty-four uniques forged from rare blueprints
  (some of them silly - the Squeaky Clogs make enemies trip), materials from
  enemies, chests and bosses, a smithy (craft, masterwork, temper, salvage), a
  peddler, a leather satchel that unbuckles to show the character, bag and
  stats, and a wardrobe to wear any look you have earned.
- Full gamepad support: menus, prompts, rebinding, aim assist.
- Real 3D lighting and shadows rendered as crisp pixel art; all art and audio
  generated by code (`tools/`). Optional creature voices from a licensed pack
  are imported locally (`tools/audio/import_licensed.py`) and never committed.

## Running

Requires Godot 4.7.x (standard build).

```
godot --path .                 # play
godot --path . -- scene=hub    # jump to the sanctuary
godot --path . -- scene=dungeon region=throne tier=4 kit=4 profile=dev.json   # try the capstone geared at Tier IV
```

Controls: WASD move, mouse aim, LMB attack (hold to charge), Space dodge,
RMB Ward, Q/E abilities, R flask, F interact, Tab map, Esc pause, F12 screenshot.
Gamepad is supported for movement, aiming and combat.

## Development

- Tests: `tools/dev/run_tests.sh` (or `godot --headless --path . res://tests/test_runner.tscn`)
- Rebuild art / audio: `godot --headless --path . -s res://tools/art/build_art.gd`,
  `godot --headless --path . -s res://tools/audio/build_audio.gd`
- Autopilot playtest: `godot --headless --path . -- autopilot scene=dungeon seed=7 frames=20000 quit profile=bot.json`

Docs: [Design](docs/DESIGN.md) - [Architecture](docs/ARCHITECTURE.md) - [Status](docs/STATUS.md) - [CLAUDE.md](CLAUDE.md)
