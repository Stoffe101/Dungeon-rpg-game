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
- **Sconce Vault** - a sealed reliquary between cold sconces. A lit sconce burns
  for 9 s; light them all before the first goes out and the reliquary opens
  (tier-3 chest, a better gear roll, a Sunshard). A movement puzzle on the
  light theme, no combat.
- **A Kindled's Last Camp** - a dead Kindled's cold fire, bedroll and pack.
  Rekindling it rests you (40% health, a flask charge, full Kindle) and the
  pack is yours, with their last note.

## Enemy roles, squads and behavioural elites

Every creature has a **role** (brute, swarm, ranged, tank, summoner, exploder,
controller, charger, harrier, ambush, support, artillery, terrain, duelist,
beam). The Bestiary shows it with the answer to it ("Strengthens others. Break
the link, or kill it first.").

**Squads.** A fight is built around a role pairing before the rest of its
budget is spent: a *shield line* (tank/brute/duelist + ranged/artillery/beam),
a *pack* (swarms + a harrier or exploder), a *ward* (support + a frontliner), a
*court* (summoner + guards), a *snare* (controller/terrain + shooters) or an
*ambush*. Role caps keep puzzles from turning into walls (one support, one
summoner, one terrain-shaper, two artillery, two beams, two ambushers). All of it
is deterministic per seed.

**The second wave of creatures** (each needs an answer the first roster did not ask for):

| Creature | Region | Role | What it does | The answer |
|---|---|---|---|---|
| Gravemole | Ossuary | ambush | burrows (untargetable, a moving mound), erupts under you after a ground mark, lingers surfaced and swipes | keep moving; punish it while it is up |
| Lampwight | Ossuary | support | tethers an ally with a refilling soul shield; carries a real light | kill it first, or break line of sight |
| Spore Mortar | Rootmire | artillery | rooted; lobs arcing spore bombs onto marked ground that leave poison clouds | read the marks, close the distance |
| Bramblewright | Rootmire | terrain | grows a withering bramble wall across your path, thorn-whips up close | burn or hack the wall, or wait it out |
| Gilded Duelist | Throne | duelist | lunge strings, then a riposte stance (gold glint) that turns blades and cuts back | don't swing into the glint; spells still land |
| Sunwatcher | Throne | beam | tracking line, then a beam that sweeps 70 degrees and stops at walls | dash through it or get behind the eye |

**Behavioural elite affixes** (beside Hasted, Warded, Volatile, Vampiric, Phasing):
*Molten* leaves burning ground where it walks; *Splitting* climbs back out as two
lesser copies; *Gloom* wraps itself in a negative light - near it the lantern
dims and Kindle comes at half the rate, its violet eyes still showing where it
is. Affixes only roll where they work (no trail on a rooted Mortar, no phasing
on a burrower), Grudges included.

## Omens

Optional signs read at the Descent, unlocked by the first guardian kills (one
needs a death). Each makes the expedition harder in one specific way and pays a
stated share on what comes home (death included); they stack.

| Omen | Cost | Pays |
|---|---|---|
| Lightless | torches, candles, braziers and glowcaps are out | +30% Embers |
| Restless Dead | a third of the fallen rise once, weaker (rooms wait for them) | +30% XP |
| Glass Kindled | +35% damage dealt, +60% taken | +20% Embers, +20% XP |
| Tempered | one elite in every fight | +25% Embers, +10% XP |
| Dry Flask | one flask charge fewer | +25% Embers |
| Hunted | every unsettled Grudge waits on every depth, and pays double | +15% XP |

The Descent remembers the last region and Omens (save v8). The HUD lists the
run's Omens; the summary shows what they paid.

## The Undervault Gate and transitions

The hub's descent is the Undervault Gate: a rune arch between soul-fire
braziers, a turning veil over a stair. Its runes wake one after another; near
it they all burn, its light swells and soul motes rise; it hums. Descending, the
veil flares white and the Kindled comes apart into embers, then a title card on
black (region, depth, Omens) covers the load. Stairs and the road home use the
same card, so the world never pops.

## Loot presentation

Rare, epic, set and legendary drops (and blueprints) raise a pillar of their
rarity colour once they land, with a landing chime and ring by grade; epic-and-up
pickups burst in their colour, legendary and set finds get a banner. Worn
legendaries and uniques give the Kindled a faint drift of light in their colour
(sets keep their 4-piece aura). Everything follows the Effects slider live, and
beams stop pulsing with Reduce flashes.

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
- **Grudges grow.** Traits come with levels (Lv2 a second affix, Lv3 kin at its
  side, Lv4 fed on your Embers - harder hits per 50 carried; cap Lv5). Left
  unsettled, every third expedition it gains a level and its hoard 15%; the
  summary says so and the Shrine of Memory lists what it has become. Its room's
  fires burn red, and you are warned on arrival. A Lv2+ Grudge also drops what it
  hoarded. Pressure to settle it, and a better prize for doing so.
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

## Buildcrafting: runes, weapons, keystones

**Ember Runes** (src/data/runes.gd) are the spell-customisation layer. A rune
is set into an ability's socket (one; a second at level 20) and changes how that
spell behaves - and the same rune reads differently in each spell, so ten runes
across six spells give sixty behaviours without sixty items:

| Rune | What it does (examples) |
|---|---|
| Many | Flare erupts at three more points; Lance fans into three; a second Sigil; three shades on a Gloamstep; a shared Aegis; two Wisps |
| Arcing | every spell hit arcs to two more foes for half |
| Echoes | Flare/Lance happen again where cast; Sigil pulses twice more; Gloamstep recalls you; the Aegis re-forms once; a second Wisp |
| Rime / Gloam | the spell turns to frost (chills, +50% on frozen) or shadow (Exposed) - and recolours |
| Ruin | spell kills burst |
| Kindling | spell hits refund Kindle and heal |
| the Well | pulls instead of pushing; a breaking Aegis drags foes in |
| Haste / Might | cooldown vs damage vs cost |

Runes drop from elites (sometimes), every boss, the Trial and the Vault (one
per player in co-op) and can always be carved for a fixed price - a sure path
beside the lucky one.

**Weapons** now span seven playstyles. New this pass:
- *Hearthbow* - precision: pressing starts the draw; release early for a quick
  shot, on the peak for a Steady Shot (pierces three, always crits), late and the
  arm tires. Slow while drawing; positioning and timing are the skill.
- *Emberwright's Tome* - the caster's weapon: hold to read a stream of seeking
  motes; every hit shortens both spell cooldowns, and each spell cast inscribes
  its element (after runes) into the next pages. Its damage lives in the spells.

**Outer keystones** (ring 7, through each Mastery) change how a build plays:
Counterweight (a Ward unleashes the charged attack), Ashbringer (burning ground
and a damage mark), Stillness (stand still to hit harder - the turret
keystone), Shadowdancer (dodges leave shades), Bastion (your Ward protects
nearby allies and answers with a shockwave), Runebound (spells grow with every
rune set). Each has a real price.

## Visible armour

Every armour base has its own look on the Kindled (src/data/gear_looks.gd):
~20 drawn styles in their materials (hoods, helms with visors/horns/plumes,
crowns, masks; robes, mail, plate, coats, capes; gauntlets, gloves, wraps,
bracers; boots, greaves, sandals...). tools/art/gen_gear.gd draws one overlay
sheet per base on exactly the body's poses (GenPlayer.anim_table), clipped
against the body so capes show behind it and the lantern arm stays in front.
At run time up to four layers follow the body's frame, flip, squash, flash and
dissolve. The wardrobe can show any owned piece's look per slot, or hide it.

## Co-op (up to four)

Host-authoritative ENet play (see docs/NETWORK.md). Each player keeps their own
profile, gear, tree and rewards; the expedition is shared. Embers, memories,
materials and Sunshards are credited to everyone; gear, blueprints and runes
drop once per player; relic altars give each player their own pick. Foes target
the nearest Kindled (with aggro on heavy hitters); each extra Kindled adds about
30% more foes and a third more health (bosses half) - never four times anything.
Sealing a room draws everyone in - to just inside the door the fight began
from, never into the room's middle (a pillar, a pit, the fight). Downed players
can be revived; the fallen return when the room is won. Seat colours ring each
Kindled and name allies.

**The sanctuary is shared: the party gathers at the host's fire.** A guest
walks the host's camp (what the host has built, who lives there) in their own
gear; their progression stays their own - the Hearthtree, forge, smithy,
peddler, satchel, wardrobe and requests always open the guest's own profile.
Seeing the host's camp keeps the world consistent for everyone (one camp, one
set of residents in one place); a guest's own camp is theirs to show when they
host.

**Expeditions are proposed, not readied.** Whoever is at the gate chooses the
region, tier and Omens and proposes; everyone is asked on a card that does not
interrupt them, answers with one key, and sees the others' answers arrive. A
short countdown follows agreement, so a slip can still be taken back. Votes
below (stairs, Hearthstone, Trial, Hearthcall) use the same card; standing at
the stairs with the asker counts as agreeing.

## Co-op interactions

Who decides what (src/net/party.gd), chosen so that nobody can spend a
friend's chance and nobody is dragged somewhere they did not agree to go:

| Kind | Interactions | Why |
|---|---|---|
| Personal | Cinder Merchant (own stock, own purse), shrine of pacts and the Echo (one bargain each), lore | a bargain is a choice about your own build |
| Shared | Ember Well (whoever draws pays the health; the Embers spill for all), lost camps, sconces, chests (with a relic pick for every Kindled) | the party found it together |
| Instanced | gear, blueprints, runes, relic altars | loot never becomes a race |
| Voted | the stairs, the Hearthstone, the Trial, a Hearthcall | they move or end everyone's expedition |

A vote needs everyone present within 30 s; one "not yet" ends it, and the
world does not pause meanwhile. A Hearthcall in a party is a proposal: the
ritual completes, then the party agrees to go home or stays.

Each Kindled owns its progression: guests bank the party's kills, guardians
felled and their own Grudges on their own profile, and a wipe names each
Kindled's own killer. Guests' Grudges hunt the whole party.

## Room seals

Combat rooms seal with woven soul-light: a diamond lattice with a rune column,
on a plate of the region's material (bone, root, gold). They form in stages,
shimmer, and come undone into rising motes. Anyone caught in a closing door is
stepped into the room; the grid, nav and picture always change together.

## The Hollow Below (endgame)

The endless descent after the Ashen King: the three regions in turn, an Echo of
the guardian every third depth (sturdier per meeting, with an affix; beating it
opens the way down), and one more Omen read in at every depth. The deepest depth
is remembered. It is the place builds are tested against rising pressure, and
where Omens, Grudges, runes and co-op meet.

## Evolution pass: builds, weapons, fair co-op, depths, the workshop

**Projectile builds.** Every projectile the Kindled looses (bow arrows, staff
bolts, tome motes, the new Gloam Knives, wisp and lantern bolts, Thousand
Cuts' knives) goes through `Volley`: +projectiles fans more shots, pierce,
chain (leap to the next foe in sight), fork (split in two at half damage on the
first hit) and return (turn back at the end of the flight and strike again on
the way home). A volley strikes each foe once, so more projectiles widen the
reach of a shot rather than multiplying single-target damage. Whole-number
modifiers never scale with item level or tier.

**Spells and the third slot.** Four spells: Gloam Knives (a cheap, quick fan),
Hearth Lantern (a planted light that shoots, feeds Kindle and shelters - a
place for a party to hold), Ember Rush (a melee dash that cuts a line and stops
at walls) and Rekindle (wards everyone in the light, restores Kindle, raises the
fallen). Each has Rune of Many / Echoes / Well effects. A third spell slot opens
at level 5 (C; pad RB, which Attack gave up - RT attacks). The hotbar is one
framed plate: three spells, a hearth notch, the flask; keys in the corners,
costs inside, seconds over long cooldowns, a flash when a spell comes back.

**Hearthtree build paths.** Each branch gained a second layer beside its first
notable: Blade (Ember Rush, Momentum, keystone Thousand Cuts), Pyre
(Splintering Flame, keystone Ember Hail), Rime (Returning Frost), Gloam (Gloam
Knives, Fan of Shadows, Ricochet), Bulwark (Rekindle, Retribution, keystone
Last Light), Kindle (Hearth Lantern, Lanternwright, Hearthbond, keystone
Spellblade). Keystones ask a price (Thousand Cuts: 30% less per hit; Ember Hail:
25% less per shot; Last Light: 40% less health; Spellblade: 15% dearer spells).

**Weapons as loot.** Weapons are items in a seventh gear slot. Each base is a
variant of an archetype (the archetype is the moveset): a plain form, two
variants with an identity (the heavy Gravecleaver, the quick Duelist's Sabre,
the forked Splitbranch Staff, the frost Long Rimebow...), a unique per
archetype from blueprints (keystone-grade mechanics without the price: the
Thousandth Cut, Quakeheart, the Wand of a Hundred Embers, Gloamfang, the
Searing Pike, Windreturn, the Index of Hollow Words) and a legendary per boss
(Wardenfang, Bloomstring, the Sunfall Glaive). The forge's archetype levels
(+10, Temper, Masterwork, Ascend) apply to every variant; the item's own level
is tempered at the smithy like gear. About one find in six is a weapon, half of
them of the finder's archetype. Weapon damage multiplies the forge's scale, so
it and a weapon's identity grow gently with the tier (`kw` in
`ItemDB.mods_of`), and weapons carry no extra tier might.

**Fair co-op.** A party meets more foes (+30% per extra Kindled, each with +35%
health, bosses +50%) and each is worth less (`Party.reward_share`), so a
player's whole take grows by only +12% per friend: playing together is
rewarding, not a multiplier. Foes hit 10% harder per extra Kindled. The
scaling evaluation (`-- scaling`) measured both: see STATUS.

**Depths you can read.** Every depth has a name and a mood (the Upper Crypts,
the Charnel Galleries, the Warden's Deep...); the title card, floor banner, HUD
and map say "Depth 2 of 3", "Guardian Depth" (and who waits) or, in the Hollow
Below, how far the next Echo is. On a guardian's floor its lair is on the map
from the start, an ember at the screen's edge leans toward its door, and the
floor trembles when it stirs.

**Room variety.** Six new combat-room shapes (pillar ring, chasm with bridges,
hall of columns, broken dividing wall, L-shaped room, sinkholes) and six
hand-made rooms (two per region, mirrored at random) among the procedural ones.

**The workshop.** The forge grows in three levels: rebuilt (furnace, anvil,
smith); a quench trough and tool wall (tempering 15% cheaper, crafting a little
rarer); a master's workshop (bellows, banner, grindstone; tempering 30%
cheaper, crafted gear tempered once). The smith's hammer strikes are the
sparks; crafting flares the anvil and the quench barrel hisses.

## Development pass: feel, atmosphere, smart co-op, landmarks

**Facing.** Who the Kindled faces follows one priority, the same on every
screen: fighting (an attack, a charge, a held stick aim) faces the aim;
otherwise walking faces the walk (W/A/S/D and diagonals); standing still
keeps the last facing unless the mouse moves; a dodge faces where it goes.
The side frames switch with hysteresis (side when |x| > 1.15|y|, back only
when |x| < 0.7|y|), so a diagonal never flickers. The idle weapon follows the
facing, a charge the aim. A guest sends its facing with its input (the host no
longer guesses it from movement), so a turned Kindled looks turned to everyone.

**Bigger parties are hunted, not padded.** The bot evaluation showed why
parties were safer: every foe chased the nearest Kindled, so the rest fought
for free. Foes now share themselves out (a Kindled already pressed by others
is less inviting, one standing alone more, flankers most of all; ranged and
support foes barely care about distance, so the back line is pressed too) and
keep a target for a second or so unless another is clearly better. A party's
extra foes are picked for what they add - flankers and marksmen in turn,
inside the role caps, never pack summoners - and placed on the far side;
three or four Kindled meet one more short closing wave. Guardians gain less
health per friend (+40%), shorter rests between attacks (+7% per friend; wind-ups
and their warnings unchanged) and a call for help:
every 14 s (two Kindled), 12 s (three) or 10 s (four) foes of the region rise
(marked first) beside whoever stands
farthest from it. No role is required; every check is about position.
Rewards follow worth, not count (Party.wave_share): each wave pays a Kindled
what its own foes are worth, +12% per friend, whatever pricier extras came
with it; the closing wave pays a quarter.

**The world says what things are.** Interactables carry a name and, on the
one F would use, the action - in a colour per category (treasure gold, magic
soul-teal, bargains with a price rose, the way onward pale gold, trade amber)
- with a soft highlight pulse. Names fade with distance and never stack.
Players who prefer a clean screen choose "only the nearest" or "off" (then the
old prompt returns).

**Urns are worth breaking, not farming.** Each region has its own make (clay,
root-bound, gilded), its own break sound (three takes) and shards that stay on
the floor. Most hold a little or nothing; a glinting one (8% of urns at depth
1, rising to 18% by depth 6) always pays: Embers, a region material and
sometimes an Ember Core. Drops come from the floor's rng, and urns never return, so there is
nothing to farm. Every attack breaks them.

**Music follows the fight.** Each region's loop has a combat layer of the same
length, started on the same frame; its volume follows how many awake foes are
near this machine's Kindled (up in about a second, down over a few). An elite
arriving strikes a sting; a real fight ending, a quiet chord. Region identities
(as written in tools/audio/build_audio.gd): the Ossuary cold D minor with a
sparse plucked motif; the Rootmire E dorian with woody marimba plucks; the
Throne a harmonic-minor processional with timpani, brass-like pads, a tolling
bell and a broken fanfare; the Hollow Below whole-tone bells over a beating
drone; the Bloom and the King have their own guardian music. The mix: a limiter on the master, a gentle
compressor on effects, warnings (wind-ups, guardians, parries) on voices of
their own so a crowd never steals them, music ducked a little under heavy
fighting.

**Depths look deeper.** The second and third depth of each region are drawn
from their own floor and wall textures, built from the first: the Ossuary
gains bones in the paving, then soul-light in its seams; the Rootmire spore
caps, then the Bloom's red veins; the Throne ash and scorch, then gold inlay
and a sun in the floor.

**Landmarks.** A floor sometimes holds its region's great centrepiece in the
middle of one fight (20% of floors at depth 1, 4% more each depth, at most 36%): the Bone Colossus, a
half-buried warden's skull whose eyes still hold soul-light; the Heart-Root,
the dead tree's heart held in an arch of roots; the Fallen Sun-Disc, the
sun-king's cracked emblem. Each tells something and does something once you
reach it: the Colossus remembers the depth (every room, hidden ones too, on
every Kindled's map) - information, which suits the Ossuary's secrets; the
Heart-Root takes 15% of a Kindled's health for a relic of their choosing (once
each - a bargain everyone in a party may make or refuse); the Sun-Disc warms
the party (Kindle, health, a flask) and leaves a Sunshard. A landmark is picked
with its own rng, so the rest of a seed's floor is unchanged. Seeing all three
earns "Wonders of the Deep".

**Loot is a moment.** A legendary, set or unique find rises from the fallen,
turns in the air for half a second with a rising hum, then strikes the floor
with its own sound, ring and flash. Rare and epic finds land with their own
chimes; every notable find says its name over where it lies (in co-op, only to
whoever it is for).

**Guardians arrive.** For 1.6 s the room trembles in growing pulses, light is
drawn into a widening sigil and the stone groans; then the guardian is there:
a shockwave in the region's light, a quarter-second of slow motion, the
camera leaning toward it (on every screen) and its name.

**The Hollow Below changes on each pass.** After the first nine depths the
regions bleed together (foes of the next region take places in some fights;
the title card says whose dead walk there) and every pass is darker (85%,
then 70%, then 55% of the light, no darker), so the lantern matters more the deeper it goes.

**The workshop sounds like one.** The smith's hammer rings on the anvil on
every blow (three takes of a hammer biting hot iron), every fourth blow lands
harder, and the bellows breathe with the fire flaring.

## Combat identity pass: weapon forms, new spells, readable foes

**A variant is a way to play, not a number.** Each archetype has its plain
form and two variants, and each variant is a *form* (ItemDB "form") the
archetype's script reads: different strikes, a different held move, a
mechanic of its own. Sword: the Gravecleaver's two wide cleaves Sunder
(every third blow on a foe Exposes it) and its Grave Drop executes the
wounded; the Duelist's Sabre thrusts four times and its held En Garde turns
the first blow into a riposte (a perfect dodge or Ward readies one too).
Hammer: the Tombmaul's slams echo as aftershocks and Tombfall plants it for
four rolling quakes; the Emberforge Mallet heats with every blow that lands,
throws molten sparks when hot and vents the heat as a nova. Staff: Rimewood
shards shatter into splinters, its Frost Lance freezes the chilled; the
Splitbranch's bolts fork and its fireball scatters bursting embers. Daggers:
the Gloam Kris marks foes (up to five) and tears the marks open with its
crossing cut or a Shadowstep to the most-marked foe; Ember Shivs throw
burning blades mid-combo and a fan of seven when held. Spear: the Rootspear
roots and drags in, and plants a ring of thorns; the Warden's Partisan holds
a line (frontal blows and shots stop on the shaft for 4 Kindle each) and
darts at what comes near - a tank's weapon. Bow: the Splitwood nocks an
arrow every quarter second (more arrows or a true shot, not both); the Long
Rimebow chills and its Steady Shot is an ice spear that freezes and leaves
frost. Tome: the Codex writes orbiting glyphs and echoes a spell cast with
all three; the Grimoire breathes fire in a cone. A HUD gauge shows heat,
nocked arrows, glyphs, marks or a ready riposte.

**Uniques are themselves.** Every unique and legendary weapon has its own
silhouette in the hand; three have a moment to build around - the
Thousandth Cut's thirtieth blow in a row is a flurry, the Wand of a Hundred
Embers' hundredth ember falls from above, the Sunfall Glaive's lunge brings
down a falling sun.

**Spells of different kinds.** Soulfire Beam is steered by the aim and burns
hotter the longer it holds (the caster walks); the Cinder Orb drifts and is
burst by a second cast (bigger the longer it drifted); Rimewall changes the
ground (its tiles are pillars while it stands - foes and shots stop); and
Hearthfire Form is a transformation (faster, hits burst in flame, ends in a
nova). The older ones gained what they lacked: Gloam Knives lodge and burst
on a melee blow (a caster-blade bridge), Ember Rush chains through the
burning, Rekindle cleanses and quickens, the Lantern's light exposes.

**Builds that combine.** Five notables tie spells and forms together
(Shadow Cutlery: knives leave Kris marks; Detonator: the orb bursts knives,
marks and ice; Hearthforged: Hearthfire doubles form gauges and grows on
kills; Frozen Bastion: the wall chills and its shatter freezes; Steady
Pour: walk at full pace while beaming). Three saved loadouts in the Satchel
(page, spells, gear, weapon) make trying builds cheap.

**Foes say what they are about to do.** Every telegraphed blow lands on
every Kindled the shape covers (it used to hit only the chosen target - a
slam drawn over two players hurt one), its shape flashes as it lands, and
the striker's body glows redder through the wind-up and flashes at the
blow, so in a crowd the one about to strike stands out. Frenzied elites
erupt at half health; Shepherds shield their kin behind a warning ring (kill
them first). Some glinting urns are Urnlings.

**Every weapon sounds like itself.** Blades slice, hammers crunch, points
punch in, arrows thunk, spells pop; a crit rings over the impact.

**Co-op rewards are measured, not guessed.** `-- economy` clears whole
floors exactly (every foe felled, every drop taken) for parties of 1-4. It
showed a big party's closing wave lifting XP to 1.4-1.8x solo; that wave now
pays nothing, and every party size sits near +12% per friend from kills.

## Playtest foundations pass: fair parties, rooms that open, a readable floor

The second two-PC playtest (2026-11-04) found unequal progression, finds that
were not private, loot that could not be worn until home, a room that never
opened, foes behind a closed gate, a poor map, confusing collision, sprites
cutting each other and an awkward spell picker. Each was reproduced in code
before it was fixed; the tests that pin them down are in
`tests/test_playtest.gd`, and `scenario=loot` checks the party ones on real
machines.

### Shared income (Party.award_xp / award_embers)
- **Cause of the Lv 12 vs Lv 10 gap:** the room-clear experience
  (6 + 3 x depth per room) went to the host's run and save only, and every
  shared orb was scaled by each Kindled's *own* XP and Ember bonuses.
- **Rule now:** every shared award - foes' memories and Embers, a room won,
  a boss, a spring of memories - credits every Kindled of the party the same
  amount, whoever felled the foe or walked over the find, standing, downed
  or waiting to be rekindled. A gain bonus (Four-Leaf Ring, Lantern of
  Avarice, an affix, a relic, a resident's gift) is the party's: the best in
  the party lifts everyone. Two Kindled who start equal finish equal.
- Personal spending (the merchant, pacts, the Echo) still parts balances; a
  shrine pact's Embers are its taker's.
- **The XP ledger** (`src/net/ledger.gd`): every machine writes each change
  to its own experience (source, amount, level, total) and the host what it
  awarded (base, multiplier, recipients) to `user://ledger/<run>_<name>.jsonl`;
  `tools/dev/ledger_compare.py a.jsonl b.jsonl` shows where two players'
  gains part ways, floor by floor.

### Finds of one's own
- A drop's owner is set before it exists. On every other machine it is not
  drawn, lit, beamed, named or heard, and on guests' machines it does not
  even arrive: events marked "own" go to that peer alone (NetRun flushes
  them per peer; a rejoining guest's world dump holds only its own).
- **The Satchel is live:** gear, runes and blueprints go into the finder's
  Satchel the moment they are taken (they were always kept on a death, so
  nothing is risked). The host banks its own; a guest's arrive as a
  `_gift`, acknowledged, sent again after a rejoin and before the end, and
  banked once by its drop id (`Profile.bank_find`, the save's `delivered`
  book). The settlement no longer carries gear. Materials still ride with
  the run (half lost on a death).
- **Wearing finds below:** any find can be worn on the spot, a weapon of
  another kind included (its form and moves at once; the host swings a
  guest's new weapon from their sheet). While a room is sealed around you
  the Satchel holds your gear as it is (no swapping mid-fight).
- Blueprints are rolled per Kindled against what *they* know (their sheet).

### Rooms that always open
- **Cause of the sealed room:** a Bonecaller backed against a door raised
  its husks up to ~3.5 tiles away with no room check - into the passage
  between two closed gates, unreachable and counted. Also: the floor
  stopped advancing while the host lay dead (no waves, no clearing), a late
  Trial vote could seal another room over a fight, foes left from one fight
  were counted in the next, flyers stayed on gate tiles, Rimewall could ice
  a doorway, and bleeding out looped back to downed.
- **The arena:** when a room seals, its reachable floor (flood-filled from
  the party inside the room's own tiles) is the arena. Waves, summons,
  splits, risers, adds and Grudges are placed inside it (`foe_spot`,
  `arena_spot`). A watchdog brings a counted foe that stays outside it for
  1.5 s back in (a sigil marks it) - the fight stays the fight; nothing is
  opened or won on a timer.

### Steering, the map, the guardian
- **Pointer steering** (Settings > Gameplay, on by default): hold W and
  move the mouse - a sweep, not a twitch - and W walks toward the pointer
  (S backs away, A/D sidestep) until W is let go; keys alone walk the
  screen's way. "Always" makes every walk relative to the pointer; pads
  are untouched. The steered walk is what is predicted and sent to the host.
- **The map** is drawn from the real floor plan (one pixel a tile, baked
  when what is known changes): true room shapes, passages, pillars, closed
  gates. The full map dims the world, fits everything known into most of
  the screen in whole screen pixels, zooms with the wheel, and has its own
  header (region / floor and depth / Tier) and key. Both maps show every
  Kindled in their party colour (names on the full map); one off the
  minimap shows as a pip on its edge.
- The guardian's edge arrow is gone: its lair is on the map from the start.

### A floor you can read
- Walls inside a room are waist-high blocks (they were 8-px ledges that
  read as steps). Wide dressing blocks the two tiles it covers; bone heaps
  are walked through; burnt brambles lie low. Walking into the very edge of
  a block rounds the corner.
- Sprites lead slightly toward the camera in depth (never on screen), so a
  body beside a pillar is no longer cut; actors differ by a hair so two in
  one row do not flicker. Coincident actors are parted; spawns no longer
  stack on tile centres.
- Light: the banded falloff is lifted before quantising, ambient raised,
  the vignette softened, and a Brightness setting.

### Spells, the party screen, the forge
- Spell cards and a picker replace the default dropdowns; one tooltip
  (`SpellUI`) everywhere, with the cast's own numbers (build and runes).
- The host's "Begin together" takes the party into the host's sanctuary;
  guests follow automatically. "New Kindled" resets only that player's save.
- A guest at the host's camp works at the host's forge (`Profile.facility`):
  its workshop level, the guest's own purse, no building gained.

### Combat priorities
- **Signature moments** are measured with `-- legendlab`. The Thousandth Cut
  now gathers per swing that lands and per foe felled (double on elites and
  guardians), keeps its charge between fights and brightens the blade:
  about 2.5 a minute in small fights, 4.5 in a crowd (it was 48 s to the
  first in small fights, 18 a minute in crowds).
- **Attack turns:** two foes at most wind up a melee blow on one Kindled at
  once, two shots likewise; elites take a turn but count; guardians do not.
- **Loadouts** are checked before they are worn and never half-change
  without saying so; selling or salvaging a piece used by a loadout warns.
- **Drawn falls:** every regular foe has hurt and death frames drawn from
  its own body (crumble, topple, curl or melt).
- **Weapon masteries:** seven Hearthtree notables, one per kind of weapon,
  that change how its forms fight.

## Expedition evolution pass: everyday fixes, a readable dungeon, the Apothecary, the Forked Descent

### Everyday fixes (each had a cause found in code first)
- **Weapon not in hand after a change in the sanctuary.** `InventoryUI._equip`
  only re-made the weapon below; in the sanctuary a weapon of another kind
  never reached the Kindled until the camp was rebuilt. Now every change to
  the save reaches the live Kindled through one path, `Player.sync_gear`
  (watching `Profile.changed`, a frame later; at once from the Satchel and
  the weapon rack): stats, weapon kind and form (a tempered blade too),
  armour layers, spells. Armour, loadouts, tempering, the Hearthtree, runes,
  buildings and residents' gifts all go through it (tests).
- **Upgrades moved the Kindled to the fire.** `Game.goto_hub()` rebuilt the
  whole camp. Facilities are now built in tagged groups and
  `Hub.refresh_camp` rebuilds only the group that changed, in place: the new
  pieces dissolve in out of sparks; whoever stands where a new piece sits is
  eased a step aside. Guests' camps follow the host's the same way.
- **The Smithy jumped to the top on every click.** It was rebuilt from
  scratch. It is now built once in persistent sections (tabs, slot / rarity
  / "ready" filters, list, detail, materials on hand); a pick restyles two
  rows and redraws the detail; a save change redraws the list keeping its
  scroll and focus (smoke test with 60 extra pieces).
- **Mouse steering removed.** The keys always walk the screen's way. A
  deliberate sweep of the mouse (18 px of hand travel, capped so it fades)
  turns the Kindled's face toward the aim for 0.7 s while it walks on.
- **K opens the Hearthtree** anywhere (D-pad left on a pad). Below, new
  points can be kindled between fights only; refunds, respec, pages and
  feeding the Hearth stay at the sanctuary (no free respec between rooms).
  Unspent points show beside the level until spent.
- **The yellow-orange blob on the Kindled.** Two causes, both in the
  silhouette pass that draws the Kindled behind stone: (1) it declared its
  instance uniforms in a different order from the body's shader, so Godot
  gave `lead` two indices ("Only the first one will display correctly") and
  the silhouette read the wrong depth lead, judged its own body to be in
  front of it and dithered orange over the whole Kindled for some actor ids;
  slots are now pinned (`instance_index`) in both and tested. (2) Even when
  correct it was a half-dense orange checkerboard in screen pixels; it is
  now a one-texel outline of the body's own texels with a sparse dim inside.

### The dungeon's visual grammar (LevelBuilder + world.gdshader)
The second playtest's complaint - walls that look like floor, floor that
looks like walls - was measured with `-- showcol`: the solid mass between
rooms was drawn with the same flagstones as a floor, a level up, and the
waist-high walls inside rooms used a stretched 8-px trim strip that vanished
into the floor. The rules now:
- **Floor**: quieter than anything on it (contrast eased toward its own
  average, x0.74); a stepped, dithered contact shadow where it meets a wall
  (strongest at a wall's foot), a pillar or a solid set piece; a lit lip at
  a pit.
- **Wall cap**: a rim of the region's dressed stone on every open edge
  (crypt blue-grey, root green, throne gold, hearth warm), with a faint
  light of its own so outlines survive the dark; darkening toward the
  middle of thick rock. "If it has a rim, it is the top of something solid."
- **Wall face**: masonry at the texture's own scale, bottom-anchored, dark
  at its foot, a lip under its cap.
- **Pit**: falls into the dark at once below its lip.
- **Set pieces**: solid ones get the floor's contact shadow (the level mesh
  is built after the props); walk-through ones (bone heaps) do not.
- **A Kindled behind stone**: an outline, not a blob.
- Generation never lets a set piece close off a nook (`_floor_whole`); a
  test walks 90 floors and every route floor checking every door, room
  floor, usable prop and stairway is reachable.

### The Ember Apothecary: tinctures
Three upgrades of +flask left nothing to come back for. Now the flask is
*steeped* with one tincture, chosen at the Apothecary and kept between
expeditions (deliberately no brewing chore). Each changes what a drink does:
Hearthbalm (heals more), Kindleroot (less health, a full Kindle), Wardmilk
(a barrier after the drink: drink before the blow), Sunwater (haste and the
dodges back), Grave-salt (washes afflictions off, wards against them), Last
Ember (double on the edge, half otherwise), Gloamwater (blows chill). Each is
learned from a reagent found below - each region's elites carry their own,
vault chests Wardmoth Milk, guardians Ashen Marrow, the Lost Vault Gloamcap -
and more reagents distil it to rank II (III once the Apothecary is fully
restored). Reagents are personal finds (banked when taken, like runes). The
host pours a guest's draught from their sheet; effects resolve host-side.
The Apothecary is drawn at three levels with a cauldron and a drying rack.
Considered and not chosen: consumable brews made before each run (a chore,
and duplication risk in co-op), several flasks at once (HUD and input
clutter), stat-only upgrades (not a decision).

### Replayability research (what comparable games do, and what fits)
From existing knowledge of these games' documented mechanics - not new
research, and not proof that any mechanic retains players.

| Game | Mechanic observed | Lesson | Fit here |
|---|---|---|---|
| Hades / Hades II | Doors show the next chamber's reward; Chaos gates trade a curse for a later boon; harder optional chambers | Show the consequence at the choice point | The forked stairs name the way and what it means |
| Dead Cells | Several exits per biome lead to different biomes (difficulty, loot); permanent runes open new paths; cursed chests | Branching at the scale of whole levels; new paths as long-term goals | Forks at floor scale; a hidden fourth way later |
| Curse of the Dead Gods | A path choice every room; darkness and torches change danger | Light as a tactical resource in the level | Keep the Flame; braziers that matter later |
| Risk of Rain 2 | Teleporter event as each stage's goal; shrines (Mountain: harder boss for more) | Opt-in difficulty with a visible trade | Trial of Ash; the existing Trial altar and pacts |
| Ravenswatch | Open map, a day timer, side objectives before the boss | Time-boxed exploration | Not adopted: a timer fights co-op regrouping |
| Ember Knights | Door choices in 4-player co-op | The party needs one shared, legible choice | The stairs vote names the way |
| Path of Exile | Map modifiers; optional in-map encounters; atlas | Optional encounter types inside ordinary floors | Omens are our modifiers; objectives our encounters |
| Diablo III / IV | Rifts with a progress goal; cursed chests and shrines (timed waves) | Short, clear event goals inside a floor | Seals and Flame |

**Chosen for the vertical slice:** physical forked stairways (no new route
screen; a party vote it already understands), three ways that trade danger,
discovery and safety instead of being strictly better, two objectives that
belong to their ways, and the Apothecary's reagents as a reason to take the
riskier ways. **Rejected for now:** a node map screen (more UI than this
needs), timers (co-op regrouping), escort/rescue (AI pathing and softlock
risk), environmental puzzles (stale on repeat, co-op sync), a collapsing
chamber (navigation and softlock risk), shrines with consequences across
expeditions (needs a world-state save design first: next priorities).

### The Forked Descent
- Every stairs room below a guardian's floor (the Hollow Below too) offers
  two of three stairways, by the seed - the same two for the whole party.
  Each is named over its steps in its colour, with a brazier lit in it.
- **Trial of Ash**: +1 room, two elites, foes x1.25, Embers x1.4, elites
  drop gear more often, and its largest hall is warded by three Ash Seals:
  stationary foes that any blow, spell or shot breaks; while one stands the
  hall's foes take a third of every blow (and shed ash so you can see it).
  Won: a relic, a rune, Embers.
- **The Lost Vault**: -1 room, +2 side branches (treasure, events), and a
  vault held through three waves while its Vigil Lantern is kept lit by
  standing in its light (it drains when nobody is there). Kept: an ancient
  chest, a Gloamcap for each Kindled, a chance of a blueprint. Guttered: a
  plain chest. The room opens either way.
- **Silent Passage**: foes x0.7, no elite, a spring; Embers x0.7.
- Floors on the plain way are unchanged per seed; a way's floor is seeded
  with its name (deterministic per seed and way).
- Neither objective can hold a room shut: seals are ordinary foes to the
  arena and watchdog, and the flame only decides the vault's spoils.
- Co-op: the way rides in the vote ("stairs:trial"), the descent message,
  the run and the rejoin parameters; the HUD's task line reaches guests as
  an "obj" event. Shared income rules are unchanged (route multipliers
  apply to the foes' Embers, which are shared).

## Decisions log
- 2026-11-05 Expedition evolution: one gear path (`Player.sync_gear`) instead of per-screen refreshes; facilities rebuilt in place by group; mouse steering removed (facing only); silhouette instance slots pinned; a dungeon grammar of rims, contact shadows and quiet floors; tinctures over flask stats; physical forked stairs over a route screen; objectives that cannot hold a room shut.

- **Shared income is equal; gain bonuses are the party's.** The best XP / Ember
  bonus in a party applies to every Kindled's share (not each their own), so
  equal starts end equal and a friend's lucky ring helps everyone (second
  playtest: Lv 12 vs Lv 10).
- **Finds are banked when taken.** Gear, runes and blueprints were never lost
  on a death, so the Satchel holds them at once and they can be worn below;
  only materials ride with the run. Guests' finds are acknowledged messages
  banked once by drop id.
- **Sealed fights have an arena and a watchdog, never a timer.** Placement
  keeps foes inside the reachable room; a counted foe found outside is
  brought back. Nothing opens because time passed.
- **Foes take turns** (two wind-ups, two shots per Kindled) instead of
  dealing less damage: crowds stay dangerous but readable.

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
- **One strike per foe per volley.** Without it, +projectiles would multiply
  single-target damage (every arrow of a fan into one boss); with it, more
  projectiles mean reach and crowd control, and keystones that add shots ask a
  per-shot price.
- **Weapons as archetype variants, forge levels per archetype.** The forge's
  years of work on "the sword" should not vanish when a better sword drops: the
  archetype's level stays, the item adds identity. Found weapons can always be
  wielded (they teach their archetype).
- **Co-op rewards per Kindled, not per party.** Each Kindled's take is its own
  roll and its own share; a bigger party sees more foes, each worth less, so no
  party size pays more than playing well does. Measured, not assumed.
- **The third spell slot at level 5, on RB.** A new player learns two spells
  first; the pad's attack moved to RT alone (one-time fix for players who had
  rebound Attack before).
- **A level cap instead of an endless tree**: with the whole tree reachable,
  progression ended in sameness. The cap keeps the build a choice; Renown, feats,
  tiers, gear and the forge carry the long tail without breaking it.
- **Roles before numbers.** The second wave of six creatures was chosen to fill
  missing roles (ambush, support, artillery, terrain, duelist, beam) rather than
  to add stat variants; encounters are composed from role pairings with caps,
  because a fight's shape matters more than its size.
- **Omens pay on what comes home**, not on pickups, so the reward is visible in
  one place (the summary) and death still pays a share - risk is never a trap.
- **Grudges grow over time** instead of waiting forever: an old nemesis should
  feel like a decision you keep putting off.
- **New enemies reuse proven behaviours** where they fit (Sentinel = Guard,
  Hound = Skitter, Acolyte = Bonecaller, Wraith = Archer) with new art, stats
  and projectiles from data; only the Spider, Toad and the Ashen King needed
  new code. Variety for the player, little new risk.

- **Runes before more skills.** Ten runes that read differently in each of six
  spells give the build space of sixty variants for ten items, and they work in
  any build. The Tome and Runebound make a caster's identity out of them.
- **Visible armour as overlays on shared poses**, not a sheet per combination:
  57 small sheets drawn from the body's own pose table can never drift from the
  body, and adding a piece is one table row.
- **Co-op is host-authoritative with replicated presentation.** The simulation
  uses global randomness in many places; lockstep would desync. One simulation
  and clients that draw it keeps every rule in one place, and single-player runs
  through exactly the same code.
- **No autoload for networking**: Game adds /root/Net at start-up, so
  project.godot (which the editor rewrites) does not have to change.
- **One endgame, connected**: the Hollow Below reuses regions, bosses, Omens and
  Grudges rather than adding a parallel activity.

- **Co-op stays host-authoritative, with prediction on top.** Each client
  predicts its own Kindled with the host's movement code and reconciles; the
  host leans toward the client's predicted spot only by a frame's walk (packet
  timing), never through walls or against a shove. Fully client-authoritative
  movement would remove the last corrections but would let a client place its
  Kindled anywhere and fight the host's knockback; the bounded lean got the
  error to about a pixel at the median on every simulated link.
- **A shared world keeps one clock.** Hitstop and slow motion freeze nothing in
  co-op: four players' hits would keep everyone's world stuttering, and each
  client predicts against a steady clock.
- **Lag compensation by waiting, not rewinding.** Blows on a remote Kindled wait
  its round trip for a dodge or Ward already on the way. It is cheap, fair to
  what the owner saw, and cannot be used to dodge after seeing the damage.
- **Votes for what moves the party**, personal bargains for what shapes a build
  (see "Co-op interactions").
- **Seats wait for the same identity; no host migration.** A dropped guest
  gets 60 s to come back as itself (profile identity or Steam ID). The host's
  machine runs the world, so a lost host ends the expedition; each guest banks
  the checkpoint from the start of the depth instead of losing everything.
- **Shared sanctuary, personal progression.** The party walks the host's camp
  (host-owned environment), each Kindled in its own gear (per-player state),
  each machine moving its own Kindled (nothing to fight there, so no
  prediction), personal facilities on the local profile. Alternatives rejected:
  everyone in their own camp with visitors (two players at "the forge" would see
  different forges and residents in different places), or merging camps (whose
  upgrades count?).
- **A screen has the player's hands.** In co-op the world never pauses, so an
  open menu or conversation must stop that player's Kindled taking input - the
  missing rule behind the playtest's black screens. Questions for the whole
  party (proposals, votes) are the exception: a card at the side, answered
  with Y / N, that never takes focus or the hands.
- **Test what each player sees.** The playtest's bugs were all invisible to
  host-side tests; co-op changes are now checked with separate windows, real
  input and captures from every machine (docs/TESTING.md).
- **Steam is optional and reached dynamically.** The game builds and runs
  without GodotSteam (LAN / direct IP); with it, lobbies and Valve's relay
  carry the same messages. Development switches only work in debug builds.
- **Make parties harder by how foes choose, not by health.** Health sponges
  make fights longer, not more interesting; the measured gap came from foes
  ignoring all but the nearest Kindled.
- **Share rewards by worth.** Counting foes let pricier extras inflate a
  party's pay; valuing them keeps "a little more for company" honest.
- **Landmarks on their own rng.** A rare centrepiece must not reshuffle every
  seed's floors (dev seed lists, tests, players' shared seeds).
- **Measure audio, never claim to have heard it.** Generated sounds are
  checked for peaks, clipping, spectrum and loudness and set by those numbers;
  whether they sound good is for a person with ears.
- **Variants are forms, not stat sticks.** A weapon worth finding changes
  how a fight is played; numbers alone do not make a build.
- **Spells differ in behaviour, not colour.** A steered beam, a recast
  burst, terrain and a transformation each ask something different of the
  player; a recoloured projectile does not.
- **A telegraph is a promise.** What its shape covers is what gets hit - for
  every Kindled in it - and the one about to strike shows it.
- **Measure rewards with an exact audit, not bots in a time window.** The
  bots' Embers-per-room swung with how many rooms they cleared; the audit
  counts what the rules pay.
