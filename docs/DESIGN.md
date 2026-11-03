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
| Grave Spider | Keeps its distance, spits webs that snare (half speed); rears and lunges when close (depth 2+) | Step around the webs; punish the lunge |

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
| Bog Toad | Sits, then hops in heavy telegraphed arcs that splash on landing; its tongue lashes a long line and drags you in | Leave the landing circle; sidestep the tongue line |

**Boss - the Hollow Bloom.** A colossal rooted corpse-flower: it cannot move, so
it controls space. Lash (long line), spore volley (marked circles that leave
clouds), **Inhale** (drags you toward its maw; while inhaling it takes double
damage, then bites). At 55% - **Full Bloom**: radial root eruptions and
sporeling broods. Its four **root nodes** can be burned (or hacked apart): each
wilts it for a chunk of life, a stagger and an exposed window.

## Region 3 - The Sunken Throne (the capstone)

Opens once both the Warden and the Bloom have fallen. The drowned palace of the
last sun-king: polished obsidian mended with gold, gilded friezes, warm torches
and ash. Three depths, then the Ashen King. **Winning here at (or near) your
highest unlocked difficulty opens the next two tiers** - it is the gate of the
endgame climb.

| Enemy | Role | Counterplay |
|---|---|---|
| Gilded Sentinel | The Guard's discipline in heavier plate: frontal sun-shield, shield charge | Flank, stagger, make it charge a wall |
| Ash Hound | Packs of 2-3; circle, then leap in a straight line | Sidestep the line, cleave the pack |
| Eclipse Acolyte | Floats, calls hounds, sends homing black suns | Kill it before the pack grows |
| Ash Wraith | Kites and throws lances of dead sunlight after a tracking aim line | Step aside late; Ward to reflect |

**Boss - the Ashen King.** Greatsword sweeps, **Sunfall** (pillars of light
that land where you were standing, one after another), the **Corona** (a ring of
black suns with a three-wide gap) and a leaping slam with a shockwave to dodge
through. At 50% - **the Eclipse**: every ~13 s the sun goes out across the arena
and only the light of a lit brazier shelters you (it cannot be Warded, only
dodged or avoided). Each eclipse snuffs one brazier; strike dark braziers to
relight them, and relighting all four brings the **Dawn** - the King is seared,
staggered and exposed. His sweeps now cast lances, and ash hounds answer him.
Enrages at 20%. Drops the Sunfall Mantle (legendary) and Eclipse Shards.

## Difficulty tiers

Chosen on the Descent screen (I Kindling, II Smoulder, III Blaze, IV Inferno,
V Ashfall, VI Eclipse, VII Sunless, VIII Undying Night). Tiers I-II are open
from the start; each capstone win at your top tier opens two more.

| Per tier above I | Effect |
|---|---|
| Enemy health | x1.30 (compounding) |
| Enemy damage | x1.21 (compounding) |
| Enemy poise | +8% |
| Elites | +4% chance per encounter; from Tier IV they carry two affixes |
| Embers and Memories | +25% |
| Materials | +20% |
| Gear | drops at the run's tier: x(1 + 0.4 per tier) stats plus **tier might** (+4% damage per tier) |
| Loot quality | better rarity rolls; set pieces from Tier II; more blueprints |

The smithy forges at the highest tier you have won. The Descent screen shows a
single **power** number (tree, sanctuary and gear; 100 for a fresh Kindled) and
a suggested tier. Tuned with `tools/dev/power_report.tscn`: with a full epic
loadout of the matching item tier, kill times stay at 0.75-1.2x and survival at
1.5-2x of a fresh Kindled on Tier I; the Hearthtree, sanctuary, sets, uniques
and skill are what let you climb above your gear. (Before tier might, gear
defence outgrew offence and high tiers turned into sponges.)

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

## Gear, materials and the smithy

- **Slots**: Head, Chest, Hands, Feet, Ring, Charm (plus the weapon, which keeps
  its own forge). 37 craftable bases, 20 tier-set pieces, 13 uniques from
  blueprints and three boss legendaries (Gloamward Lantern from the Warden,
  Crown of the Hollow Bloom, Sunfall Mantle from the Ashen King).
- **Items** are instances: base + rarity (Common, Rare with one random affix,
  Epic with two, Legendary fixed) + level 1-5. Stats scale with level and rarity.
- **Materials**: Bone Dust, Grave Iron, Soul Glass (Ossuary); Rootwood, Spore
  Silk (Rootmire); Sun Gold (Sunken Throne); Ember Cores (chests); Warden
  Sigils, Bloom Hearts and Eclipse Shards (bosses, masterwork catalysts). Each enemy type has its own drop table; elites drop
  more and sometimes gear; chests drop materials and often gear; bosses drop
  catalysts, an extra piece and (always the first time) their legendary.
- **Keeping it**: loot is carried in the run; on extraction or victory all of it
  is banked, on a death half the materials (gear found is always kept).
- **Smithy** (talk to the smith): craft (rarity rolls 55/33/12; a catalyst makes
  a guaranteed Epic masterwork), temper (+1 level for half the recipe's
  materials plus Embers), salvage (half the recipe back; legendaries return
  their catalyst).
- **Peddler** stall in the sanctuary: six pieces that change after every
  expedition, bought with Embers; sells gear back for half its price.
- **Satchel** (I / right-stick click / pause menu): the Kindled with their
  equipment, the bag, materials, and a stats panel that opens and closes.

## Blueprints, uniques and tier sets

- **Blueprints** are rare finds (elites, chests, always one from the Ashen
  King) that you learn from the satchel; each unlocks one **unique** at the
  smithy. Twenty-four uniques, deliberately not all about damage. The newest
  eleven: Crown of Embers (damage grows with the Embers you carry), Mothwing
  Cloak (ember moths seek and ignite foes), Thornmail of the Rootmire (thorns
  burst out when struck), Firebrand Gauntlets (fire spreads), Mirrorguard
  Bracers (a Ward throws the blow back x3), Sandals of Still Time (perfect
  dodges still time longer and refund the dodge), Executioner's Band (crits
  under a quarter health), Four-Leaf Ring (extra chest treasure, rarer finds),
  Grudgebearer's Locket (power from the Grudges hunting you), The Bottomless
  Flask (cleared rooms refill a flask) and the Glass Lantern (close-range damage
  for less health). The first thirteen: Gambler's Coin
  (crits sometimes spill Embers - "KA-CHING!"), Seven-League Boots, Squeaky
  Clogs (every step squeaks; enemies sometimes trip over the noise), Heart of
  the Mountain, Spellweaver Circlet, Echoing Gauntlets (every fourth hit
  repeats), Ring of the Last Ember (once per expedition, a killing blow rekindles
  you), Lantern of Avarice (more materials, tougher foes), Stormcaller Signet
  (crits call lightning), Vampire's Kiss, Featherfall Hood (float over spikes),
  Berserker's Mantle (stronger the more you bleed), Kindle Battery.
- **Tier sets** (green, one affix, from Tier II): Emberwrought (fire: always
  burns, +25% vs burning), Rimeguard (frost: a Ward freezes the area and grants
  a barrier, chilled foes hit softer), Gloamweave (shadow: dodging makes your
  next blows certain crits; a perfect dodge resets cooldowns), Verdant Warden
  (thorns, spores and healing on kills). Bonuses at 2 and 4 pieces.
- **Wardrobe (transmogrification)**: two set pieces or a legendary unlock that
  look - a palette swap of the Kindled's cloak and scarf, applied in the sprite
  shader so every frame changes. Wear any unlocked look, or let it follow your gear.

## Weapons and the forge

Five weapons, each a different way to fight: the **Hearthblade** (balanced
three-strike combo, whirling cut), **Cinderhammer** (slow, guard-breaking,
leaping quake), **Ashwood Staff** (ember bolts, fireball), **Twin Fangs** (four
quick cuts, +15% crit, Shadowstep dash through foes) and **Sunpiercer** (reach
thrusts that skewer a line, a wide sweep, Comet Lunge). The Ashen Forge tempers
them to +10 (+12% damage a level) for Embers and materials from every region:
**+3 Tempered** adds a signature, **+7 Masterwork** a second one (ember ring,
burning cracks, fireball shrapnel, a second Shadowstep, a sunfire lance), **+10
Ascended** makes the blade blaze.

## Long-term progression (the 100-hour plan)

- **Level cap 60.** The Hearthtree costs 140 points; a Kindled has 59 from
  levels plus up to 9 from feats, so about half the tree. Builds are choices.
- **Three Hearthtree pages**: save builds and switch in the sanctuary.
- **Renown**: experience past the cap. Each rank pays 60 Embers, every fifth a
  Sunshard. It never adds power, so it can run forever.
- **Feats** (22): boss kills, the Throne on Tiers IV and VIII, kill and elite
  milestones, settled Grudges, Masterwork / Ascended / all weapons, blueprints,
  set pieces, looks, a restored sanctuary, the cap and Renown. Rewards are
  Embers, Sunshards, two wardrobe looks and, for the great ones, a skill point
  past the cap. Granted the moment they are reached.
- Alongside: difficulty tiers I-VIII, gear tiers and sets, 24 blueprints for
  uniques, ten looks, the bestiary, Grudges and Memory.

## The sanctuary keeps your story

Residents arrive as you progress, the garden blooms, lanterns light with the
Hearth. Now also: a trophy for each fallen boss (with lore), a weapon rack that
shows what you have forged, a lantern lit along the south wall for every two
feats, a stand wearing your chosen look (it opens the wardrobe), a Hearth that
burns brighter with your level, forge sparks, moths around the lanterns, and,
after your first expedition, a cat that naps by the fire and can be petted.

## Hearthcall and the satchel

- **Hearthcall** (H / left-stick click): stand still for 3 s and the Hearth
  pulls you home, keeping everything (an extraction). A sigil and a closing ring
  of hearth-light, embers drawn in, the lantern swelling; any hit, step, swing,
  ward, ability or flask breaks it, and it can't be heard over a living boss.
- **The satchel**: a messenger satchel (shoulder strap on brass rings, rounded
  flap with the pressed hearth emblem, two straps into buckles, a front pocket)
  pops up shut, its straps slip their buckles, the flap swings up, and it
  unfolds into the open bag (character and materials in one pocket, gear on the
  plum lining, stats in another); closing folds it back and buckles it.

## Looks of the places

- **Dungeon floors** carry large, dithered patches of grime and wear (world
  shader) so slabs never read as one tile repeated. Each region has its own
  ten pieces of floor clutter, twice as dense as before and gathering at the
  walls: bones, cobwebs, soul-light seeping through cracks and guttered candles
  in the Ossuary; moss, roots, glowing caps and spore rings in the Rootmire;
  gold coins, ash, live cinders and gold-veined cracks in the Throne.
- **Light**: bigger rooms get candles / glowcaps / braziers along the walls; the
  air moves (soul motes rise, spores drift, ash and embers fall). The Throne's
  braziers burn hearth-gold (the Ashen King's Eclipse is about their light).
- **Set dressing** against the walls gives each region a silhouette:
  sarcophagi (one seeping soul-light) and bone heaps in the Ossuary, hollow
  glowing stumps in the Rootmire, broken statues of the court holding up a gilt
  sun and fallen columns in the Throne.
- **The camp** has its own clutter (straw, wood chips, petals, paw prints),
  woven rugs by the Hearth and the tent, and a sign over each ruin saying what
  rebuilding it costs (it fades in as you approach); the prompt says what it
  brings back (the forge: the smith).
- **Bestiary** (pause menu): silhouettes until met, then portrait, region,
  slain count and lore.

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

**Hit feedback stack** (every landed player hit, in order of arrival): white
glint on the target (kept below bloom so big sprites don't flare), a recoil
along the blow plus a short squash (scaled down by mass, so bosses barely
give), an additive starburst at the contact point tinted by damage type (gold
for crits, orange fire, ice frost; doubled for crits and combo finishers; it
animates in real time so it plays during the freeze), directional particles,
a camera kick in the blow's direction (melee only), hitstop (sword 0.05 s,
finisher 0.08 s, crit 0.06 s, killing blow 0.05 s / elite 0.075 s), a glint on
the blade, and controller rumble (every screen shake rumbles in proportion;
hits and crits add light pulses; setting "Rumble (pad)"). Kills slide the body
along the killing blow as it dissolves; elites go out with a soul-light flash.

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
- **Gear in its own slots beside the weapon forge** rather than replacing it:
  weapons already carry combos and tempering; gear is where builds get numbers
  and where materials from the dungeon pay off.
- **Death keeps half the materials but all gear found**: losing a rare drop to a
  death feels worse than losing a pile of dust, and gear is the exciting part.
- **Data in GDScript tables** (not .tres): diffable, compile-checked, easy to
  extend; migrate to Resources if an in-editor content workflow is needed.
- **Looks as palette swaps, not new sprite sheets**: eight looks for the price
  of eight colour lists, and every animation (and future one) recolours for
  free. Sources are matched in sRGB in the shader (dark linear tones are too
  close together to match reliably).
- **Difficulty tiers gate on the capstone** rather than on a power number:
  unlocking harder tiers is a feat (beat the Ashen King at your top tier), and
  the power number only advises.
- **Tier might on gear** instead of steeper item stats: one transparent line in
  the tooltip keeps damage in step with enemy health at every tier without
  inflating defence too.
- **The Kindled faces the way they walk**, and turns to the aim while
  fighting (or when the mouse moves while standing). Facing only the mouse made
  walking away look like moonwalking (playtest report).
- **Licensed sound packs stay out of git.** The Minifantasy creature pack may be
  used in the game but not redistributed, and the repository is public, so
  `tools/audio/import_licensed.py` converts it into the gitignored
  `assets/audio/licensed/`; those sounds override generated ones of the same
  name, and a fresh clone falls back to the generated set.
- **A level cap instead of an endless tree**: with the whole tree reachable,
  progression ended in sameness. The cap keeps the build a choice; Renown, feats,
  tiers, gear and the forge carry the long tail without breaking it.
- **New enemies reuse proven behaviours** where they fit (Sentinel = Guard,
  Hound = Skitter, Acolyte = Bonecaller, Wraith = Archer) with new art, stats
  and projectiles from data; only the Spider, Toad and the Ashen King needed
  new code. Variety for the player, little new risk.
