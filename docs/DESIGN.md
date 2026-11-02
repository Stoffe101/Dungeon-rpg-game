# Kindled Deep - Design

## Premise

The sun went out a generation ago. What is left of the world huddles around the
**Last Hearth**, a sanctuary built over the **Undervault** - a living dungeon that
swallowed the sun piece by piece. You are a **Kindled**, bound to the Hearth.
Each expedition you carry its fire down in a lantern and bring **Embers** (slivers
of the old sun) back up. The Hearth grows on what you return - and so do you.

The Undervault is aware. It **remembers** who hurts it.

## Pillars

1. **Hand-to-hand skill.** Readable telegraphs, responsive controls, rewards for
   precise timing (perfect dodges, Wards, staggers).
2. **Light as language.** Warm ember = you. Cold teal soul-light = the Undervault.
   Your lantern's reach grows with Kindle; the boss literally steals light.
3. **Builds, not numbers.** The skill tree and relics change *how* you fight.
4. **The world remembers.** Deaths, kills and victories leave marks that persist.

## Core loop

Sanctuary (spend, build, prepare) -> Descent (choose loadout) -> Depth 1 (rooms,
choices, relics) -> stairs or extract at the Hearthstone -> Depth 2 -> the Gloam
Warden -> settle rewards -> Sanctuary.

## Combat

| Input | Action |
|---|---|
| WASD / left stick | Move |
| Mouse / right stick | Aim |
| LMB / RT | Attack (tap = combo, hold = charged attack) |
| RMB / LT | **Ward** - 0.2s parry window. Negates a hit, staggers melee attackers, reflects projectiles, +15 Kindle |
| Space / Shift / A | Dodge (charges). Invulnerable start; dodging *into* a hit at the last moment is a **perfect dodge** (slow-mo, +Kindle) |
| Q / E | Abilities (cost Kindle) |
| R | Flask (limited healing) |
| F | Interact |
| Tab | Map |

**Kindle** (0-100+) is built by landing hits, perfect dodges and Wards; spent on
abilities. It also scales the lantern's light radius - a full lantern sees further.

**Weapons** are mechanically distinct:
- *Hearthblade* - fast 3-hit combo (slash, backslash, lunging thrust); charged whirl.
- *Cinderhammer* - slow 2-hit combo (sweep, slam + shockwave), unblockable,
  heavy poise damage; charged leap-slam. Breaks Guard shields.
- *Ashwood Staff* - tap for ember bolts, hold for a bursting fireball.
Forge levels add damage; level 3 adds each weapon's signature upgrade.

**Status effects:** Burn (stacking DoT), Chill -> Freeze (slow, then frozen and
vulnerable), Stagger (poise broken: interrupted, +25% damage taken), Exposed.
**Reactions:** Thermal Shock (fire on chilled / frost on burning -> steam burst),
Combustion (burning enemies explode), Shatter (frozen kills chill the area).
**Environment:** knockback can plunge enemies into pits; Grave Bloats damage
their allies; Guards stun themselves charging into walls.

## Enemies - The Hollow Ossuary

| Enemy | Role | Counterplay |
|---|---|---|
| Husk | Shambling melee, telegraphed claw | Bait the swing, punish recovery |
| Skitter | Fast pack leaper; circles then lunges in a straight line | Sidestep the line |
| Hollow Archer | Kites; aim line tracks you, then locks | Step aside late; Ward to reflect |
| Ossuary Guard | Tower shield blocks frontal damage; slow turn; shield charge | Flank, stagger, hammer; make it charge a wall |
| Bonecaller | Floating summoner (raises Husks), homing soul orbs | Kill it first |
| Grave Bloat | Walks up and bursts, hurting everything | Pop it among enemies |

**Elite affixes** (Hasted, Warded, Volatile, Vampiric, Phasing) twist behaviour
rather than only inflating health.

**Boss - the Gloam Warden.** Halberd sweeps (210-degree), triple thrusts, a
leaping quake whose shockwave ring must be dodged *through*, fans of homing
soul-lanterns. At 55% - **Gloamfall**: it snuffs the arena braziers, calls
skitters and gains a gloamfire rush. Strike all four braziers to relight them:
the Warden is **Seared** (staggered and exposed). Enrages at 20%.

## Region 2 - The Rootmire

Unlocked by defeating the Gloam Warden. Fungal caverns among the roots of the
dead world-tree: green soil and moss, glowing cyan/pink caps, bio-lanterns.

**Region mechanic - brambles.** Solid thickets fill parts of rooms (never
sealing a door). *Any* fire hit ignites them; fire spreads to neighbouring
brambles and scorches enemies inside (the hearth-fire never burns its bearer).
Non-fire builds hack through (3 hits). Secret passages hide behind bramble walls.
Fire builds feel at home here; frost builds have to work for their shortcuts.

| Enemy | Role | Counterplay |
|---|---|---|
| Sporeling | Hopping pack biter; bursts into a spore cloud on death | Don't finish it point-blank |
| Thornback | Armoured beetle; telegraphed spiked roll that ricochets off walls, then dizzy (armour 0, exposed) | Sidestep, then punish |
| Lantern Moth | Flutters around your light, dives; a hit drains 15 Kindle (your lantern dims) | Ward or swat it early |
| Rootweaver | Kites; fans of erupting thorn lines and snaring root circles (heavy slow) | Close the gap between casts |

**Boss - the Hollow Bloom.** A colossal rooted corpse-flower: it cannot move, so
it controls space. Lash (long line), spore volley (marked circles that leave
clouds), **Inhale** (drags you toward its maw; while inhaling it takes double
damage, then bites). At 55% - **Full Bloom**: radial root eruptions and
sporeling broods. Its four **root nodes** can be burned (or hacked apart): each
wilts it for a chunk of life, a stagger and an exposed window.

## Room events

- **Ember Well** - trade 20% health for a pile of Embers.
- **Trial of the Undervault** - optional sealed gauntlet of three hard waves;
  prize: a rare-or-better relic choice and a Sunshard.
- **Echo of a Fallen Kindled** - a ghost of a previous bearer shares a memory
  and trades a relic for 30 Embers.

## Dungeon

Cell-grid floors with a main path, side branches ending in special rooms
(treasure, elite, shrine, merchant, rest), merged large halls, extra loops and a
hidden chamber behind a cracked wall. Room interiors are composed from authored
stamps (pillar patterns, pits, alcoves, cut corners, pit rings, octagon arenas)
and validated by flood fill. Doors show the reward of the room beyond (relic,
embers, vigor, memories, sunshard, elite, shrine, merchant...) so routing is a
choice. Combat rooms seal with soul-light gates until cleared.

## Progression

- **Embers** (common) - carried during a run (spendable at the merchant), banked
  on return. On death you keep 50%; the rest goes to your Grudge. Spent on the
  forge, sanctuary and respecs.
- **Sunshards** (rare) - elites, secrets, bosses, Grudges. Never lost. Gate big
  unlocks (weapons, tempering, sanctuary tiers).
- **Memories (XP)** -> levels -> skill points. Always kept.
- **The Hearthtree** - 55 nodes in six branches (Blade, Pyre, Rime, Gloam,
  Bulwark, Kindle) with hybrids between neighbours (Searing Edge, Thermal Shock,
  Frostwalk, Counterstep, Hearthguard, Ember Edge), four new abilities and six
  keystones with real trade-offs (Perfect Form, Living Pyre, Winter's Heart,
  Phantom, Unbreakable, Bonfire Soul). Respec at the Hearth (first free).
  **Masteries**: beside each keystone, fed by a late notable, a 5-rank node
  (1 point per rank) with a small two-stat bonus per rank - a long-term sink
  for points that doesn't force the keystone's trade-off. Ranks are stored as
  repeated ids in the skill list, so spending, applying and saving need no
  special cases.
  UX: every node shows an icon; hovering any node previews the cheapest route
  from your tree (gold if affordable, red if not) and clicking it kindles the
  whole route; a search box highlights matching nodes; clicking a branch name
  focuses it; tooltips show the tree-wide total of a stat before and after; a
  side panel sums up all bonuses, powers and abilities.
- **Relics** - 39 run-only powers (common/rare/epic/cursed). Offers are weighted
  toward your tree branches and held relics; ability augments only appear when
  you have the ability.
- **Sanctuary** - Hearth (max HP, lights the sanctuary), Ashen Forge (temper and
  craft weapons), Ember Apothecary (flasks), Shrine of Memory (Grudge rewards).
  Survivors come to the light as the Hearth grows and expeditions return (six
  residents: a gardener, an old guard, a child, a lamplighter, a woodcutter, a
  singer). They wander between favourite spots, sit at the fire, remark on what
  you've done (Grudges, deaths, the Warden's fall) and talk when spoken to; their
  lines change after the Warden falls. Planters by the south wall grow from bare
  soil to glowing sunblooms with your progress.
- **Resident requests** - each resident asks a favour only the Kindled can do
  below ("!" over their head), tracked across expeditions; when it's done they
  show "?" and hand over a permanent gift. Ama: open 4 chests (flasks heal more).
  Teodric: Ward 15 attacks (longer Ward window). Wren: find her wooden bird (it
  turns up in the next chest; +10% Embers). Bram: bring 3 Sunshards (+15 max
  Kindle). Hollis: clear 25 brambles (+8% fire damage). Sefa: defeat 4 elites
  (+10% Memories). The pause menu lists them.
- **Undervault Memory** - each Warden kill raises Memory: stronger foes, richer
  rewards. Foundation for an endless difficulty climb.

## Signature: the dungeon remembers

- **Grudges.** The enemy type that kills you becomes a named nemesis
  ("Morrow the Patient") with an elite affix and a level. It carries the Embers
  you lost and hunts you on later expeditions; dying to it again levels it up.
  Settling it returns the Embers (doubled with the Shrine of Memory) and a Sunshard.
- **Memory** escalates the region after victories.
- Planned: rooms reshaped by past events, factions reacting to your build,
  bosses returning as "echoes" with new mechanics.

## Presentation

Orthographic 45-degree camera over real 3D geometry, rendered at ~480x270
(integer-scaled), with the world's depth/height stretched by sqrt(2) so floor,
wall and sprite pixels map 1:1 to screen pixels. Real omni lights with shadows,
quantised and dithered lighting bands, emissive sprite masks (eyes, flames,
lanterns), bloom, pixel particles, floor-painted telegraphs and slash arcs.
All art and audio are generated by code in `tools/` from a single 60-colour palette.

## Decisions log

- **3D + sprites over pure 2D**: real lighting/shadows are central to the light
  theme. The sqrt(2) stretch keeps pixel art crisp. (Cost: tall pillars can hide
  the player - mitigate with an occlusion silhouette later.)
- **Generated art/audio**: no external tools installed; code-generated assets are
  reproducible, versionable and consistent. Replaceable by hand-made assets later.
- **One currency for shop and bank (Embers)**: spending at the merchant is a real
  trade-off against permanent progress.
- **Grudges instead of a plain "lose X%" death penalty**: loss becomes a goal.
- **One rig for all sanctuary people** (`tools/art/gen_npc.gd`): characters are
  specs (outfit, hair, headwear, items) drawn on the Kindled's proportions, so
  new residents cost a dictionary, and the cast stays visually consistent.
- **Click-to-route in the Hearthtree** instead of node-by-node clicking: refunds
  are free for leaf nodes, so buying a route is low-risk and saves a lot of clicks.
- **Data in GDScript tables** (not .tres): diffable, compile-checked, easy to
  extend; migrate to Resources if an in-editor content workflow is needed.
