## The Hearthtree: the permanent skill tree.
##
## Six branches radiate from the Hearth. Each has a spine of stat nodes,
## mechanic-changing notables, an active ability and a keystone with a real
## trade-off. Hybrid nodes sit between neighbouring branches so builds can
## cross over (fire + frost, dodge + parry, ...).
##
## Node fields:
##   id, name, branch, kind (root|minor|notable|ability|keystone|hybrid|mastery)
##   at: [ring, lateral] (polar placement around the branch axis) or pos override
##   links: neighbours (edges are undirected)
##   mods: [[stat, op, value]], flags: {flag: level}, ability: id, desc
##   ranks: masteries can be kindled several times; each rank is one more copy
##   of the id in the allocated list (so spending, applying and saving just work).
class_name SkillDB
extends RefCounted

const RING := 60.0
const COSTS := {"root": 0, "minor": 1, "notable": 2, "ability": 2, "hybrid": 2, "keystone": 3, "mastery": 1}

const BRANCHES := {
	"blade": {"name": "Blade", "angle": -90.0, "color": Color(0.93, 0.89, 0.8), "desc": "Melee mastery, combos and critical strikes."},
	"pyre": {"name": "Pyre", "angle": -30.0, "color": Color(1.0, 0.5, 0.2), "desc": "Fire, burning and explosions."},
	"rime": {"name": "Rime", "angle": 30.0, "color": Color(0.55, 0.8, 1.0), "desc": "Frost, chilling and shattering."},
	"gloam": {"name": "Gloam", "angle": 90.0, "color": Color(0.75, 0.5, 0.85), "desc": "Mobility, dodging and shadow."},
	"bulwark": {"name": "Bulwark", "angle": 150.0, "color": Color(0.75, 0.75, 0.68), "desc": "Defense, warding and survival."},
	"kindle": {"name": "Kindle", "angle": 210.0, "color": Color(1.0, 0.82, 0.4), "desc": "Kindle, abilities and wisps."},
}

const NODES := [
	{"id": "hearth", "name": "Hearthbound", "branch": "", "kind": "root", "at": [0, 0], "links": ["b1", "p1", "r1", "g1", "w1", "k1"],
		"desc": "Your bond to the Last Hearth. Grants the Flare ability."},

	# ---------------- Blade ----------------
	{"id": "b1", "name": "Honed Edge", "branch": "blade", "kind": "minor", "at": [1, 0], "links": ["b2", "b2l", "b2r"], "mods": [["melee_damage", "add", 0.08]]},
	{"id": "b2", "name": "Measured Strikes", "branch": "blade", "kind": "minor", "at": [2, 0], "links": ["b3"], "mods": [["attack_speed", "add", 0.06]]},
	{"id": "b2l", "name": "Keen Eye", "branch": "blade", "kind": "minor", "at": [2, -1], "links": ["b3l"], "mods": [["crit_chance", "add", 0.03]]},
	{"id": "b2r", "name": "Heavy Hand", "branch": "blade", "kind": "minor", "at": [2, 1], "links": ["b3"], "mods": [["poise_damage", "add", 0.25]]},
	{"id": "b3", "name": "Riposte", "branch": "blade", "kind": "notable", "at": [3, 0.4], "links": ["b4", "x_bp"], "flags": {"riposte": 1},
		"desc": "After a successful Ward, your next attack within 2s is a critical hit that deals +60% damage."},
	{"id": "b3l", "name": "Flurry Finisher", "branch": "blade", "kind": "notable", "at": [3, -1.2], "links": ["b4l", "x_kb"], "flags": {"combo_wave": 1},
		"desc": "The final strike of a melee combo releases a cutting wave of embers."},
	{"id": "b4", "name": "Whetted", "branch": "blade", "kind": "minor", "at": [4, 0.3], "links": ["b5", "b5r"], "mods": [["melee_damage", "add", 0.10]]},
	{"id": "b4l", "name": "Bloodletter", "branch": "blade", "kind": "minor", "at": [4, -1], "links": ["b5"], "mods": [["crit_mult", "add", 0.25]]},
	{"id": "b5", "name": "Executioner", "branch": "blade", "kind": "notable", "at": [5, -0.3], "links": ["b6"], "flags": {"executioner": 1},
		"desc": "Deal +60% damage to enemies below 30% health."},
	{"id": "b5r", "name": "Arc of Cinders", "branch": "blade", "kind": "notable", "at": [5, 1.1], "links": ["b6"], "flags": {"crit_chain": 1},
		"desc": "Critical hits leap to a nearby enemy for 50% of the damage."},
	{"id": "b6", "name": "Perfect Form", "branch": "blade", "kind": "keystone", "at": [6, 0.3], "links": [], "flags": {"perfect_form": 1}, "mods": [["crit_chance", "more", -0.5]],
		"desc": "The final strike of every melee combo is always critical. Your crit chance from all other sources is halved."},

	# ---------------- Pyre ----------------
	{"id": "p1", "name": "Smolder", "branch": "pyre", "kind": "minor", "at": [1, 0], "links": ["p2", "p2r"], "mods": [["fire_damage", "add", 0.10]]},
	{"id": "p2", "name": "Kindling", "branch": "pyre", "kind": "minor", "at": [2, -0.5], "links": ["p3", "p3l"], "mods": [["burn_chance", "add", 0.10]]},
	{"id": "p2r", "name": "Hotter Coals", "branch": "pyre", "kind": "minor", "at": [2, 0.8], "links": ["p3"], "mods": [["burn_damage", "add", 0.25]]},
	{"id": "p3", "name": "Combustion", "branch": "pyre", "kind": "notable", "at": [3, 0.3], "links": ["p4", "p4r", "x_pr"], "flags": {"combustion": 1},
		"desc": "Burning enemies explode when they die, dealing fire damage around them and spreading Burn."},
	{"id": "p3l", "name": "Cinder Lance", "branch": "pyre", "kind": "ability", "at": [3, -1.3], "links": ["p4", "x_bp"], "ability": "cinder_lance",
		"desc": "Unlocks Cinder Lance: a piercing spear of fire that ignites everything in a line."},
	{"id": "p4", "name": "Fanned Flames", "branch": "pyre", "kind": "minor", "at": [4, -0.4], "links": ["p5l"], "mods": [["burn_stacks", "add", 2.0]]},
	{"id": "p4r", "name": "Blaze", "branch": "pyre", "kind": "minor", "at": [4, 1.0], "links": ["p5"], "mods": [["fire_damage", "add", 0.15]]},
	{"id": "p5", "name": "Heat Bloom", "branch": "pyre", "kind": "notable", "at": [5, 0.7], "links": ["p6"], "flags": {"flare_ground": 1},
		"desc": "Flare scorches the ground, leaving flames that burn enemies for 3s."},
	{"id": "p5l", "name": "Wildfire", "branch": "pyre", "kind": "notable", "at": [5, -0.8], "links": ["p6"], "flags": {"wildfire": 1},
		"desc": "Every 1.5s, Burn spreads from each burning enemy to one nearby enemy."},
	{"id": "p6", "name": "Living Pyre", "branch": "pyre", "kind": "keystone", "at": [6, 0], "links": [], "flags": {"living_pyre": 1}, "mods": [["burn_damage", "more", 1.0]],
		"desc": "Every hit you deal is Fire and Burn deals double damage. You can no longer Chill enemies."},

	# ---------------- Rime ----------------
	{"id": "r1", "name": "Cold Touch", "branch": "rime", "kind": "minor", "at": [1, 0], "links": ["r2", "r2l"], "mods": [["frost_damage", "add", 0.10]]},
	{"id": "r2", "name": "Biting Frost", "branch": "rime", "kind": "minor", "at": [2, 0.5], "links": ["r3", "r3r"], "mods": [["chill_chance", "add", 0.15]]},
	{"id": "r2l", "name": "Deep Cold", "branch": "rime", "kind": "minor", "at": [2, -0.8], "links": ["r3"], "mods": [["chill_power", "add", 0.12]]},
	{"id": "r3", "name": "Shatter", "branch": "rime", "kind": "notable", "at": [3, -0.3], "links": ["r4", "r4l", "x_pr"], "flags": {"shatter": 1},
		"desc": "Frozen enemies take double bonus damage. Killing a frozen enemy shatters it, chilling everything nearby."},
	{"id": "r3r", "name": "Frost Sigil", "branch": "rime", "kind": "ability", "at": [3, 1.3], "links": ["r4", "x_rg"], "ability": "frost_sigil",
		"desc": "Unlocks Frost Sigil: a rune that pulses freezing cold at a target location."},
	{"id": "r4", "name": "Permafrost", "branch": "rime", "kind": "minor", "at": [4, 0.4], "links": ["r5r"], "mods": [["status_duration", "add", 0.25]]},
	{"id": "r4l", "name": "Rimeblood", "branch": "rime", "kind": "minor", "at": [4, -1.0], "links": ["r5"], "mods": [["frost_damage", "add", 0.15]]},
	{"id": "r5", "name": "Glacial Ward", "branch": "rime", "kind": "notable", "at": [5, -0.7], "links": ["r6"], "flags": {"glacial_ward": 1},
		"desc": "A successful Ward freezes nearby attackers. Reflected projectiles Chill."},
	{"id": "r5r", "name": "Hoarfrost Mantle", "branch": "rime", "kind": "notable", "at": [5, 0.8], "links": ["r6"], "flags": {"hoarfrost": 1}, "mods": [["armor", "add", 0.08]],
		"desc": "Enemies that strike you are Chilled. +8% armor."},
	{"id": "r6", "name": "Winter's Heart", "branch": "rime", "kind": "keystone", "at": [6, 0], "links": [], "flags": {"winters_heart": 1},
		"desc": "All your hits Chill. You deal 25% less damage to enemies that are neither chilled nor frozen."},

	# ---------------- Gloam ----------------
	{"id": "g1", "name": "Light Step", "branch": "gloam", "kind": "minor", "at": [1, 0], "links": ["g2", "g2r"], "mods": [["move_speed", "inc", 0.06]]},
	{"id": "g2", "name": "Quick Recovery", "branch": "gloam", "kind": "minor", "at": [2, -0.6], "links": ["g3l", "g3"], "mods": [["dodge_recharge", "more", -0.15]]},
	{"id": "g2r", "name": "Long Shadow", "branch": "gloam", "kind": "minor", "at": [2, 0.8], "links": ["g3"], "mods": [["dodge_distance", "inc", 0.2]]},
	{"id": "g3", "name": "Afterimage", "branch": "gloam", "kind": "notable", "at": [3, 0.3], "links": ["g4", "g4r", "x_rg"], "flags": {"dodge_afterimage": 1},
		"desc": "Dodging leaves a shade behind that detonates after a moment for shadow damage."},
	{"id": "g3l", "name": "Fleetfoot", "branch": "gloam", "kind": "notable", "at": [3, -1.3], "links": ["g4", "x_gw"], "mods": [["dodge_charges", "add", 1.0]],
		"desc": "+1 Dodge charge."},
	{"id": "g4", "name": "Slippery", "branch": "gloam", "kind": "minor", "at": [4, -0.4], "links": ["g5", "g5l"], "mods": [["dodge_iframes", "add", 0.06]]},
	{"id": "g4r", "name": "Gloamstep", "branch": "gloam", "kind": "ability", "at": [4, 1.2], "links": ["g5"], "ability": "gloamstep",
		"desc": "Unlocks Gloamstep: vanish and reappear at the cursor, leaving an exploding shade."},
	{"id": "g5", "name": "Ambush", "branch": "gloam", "kind": "notable", "at": [5, 0.5], "links": ["g6"], "flags": {"ambush": 1},
		"desc": "Attacks made within 1.2s after a dodge are critical hits."},
	{"id": "g5l", "name": "Perfect Shadow", "branch": "gloam", "kind": "notable", "at": [5, -1.0], "links": ["g6"], "flags": {"perfect_refund": 1},
		"desc": "Perfect dodges refund the dodge charge and grant 25 Kindle."},
	{"id": "g6", "name": "Phantom", "branch": "gloam", "kind": "keystone", "at": [6, 0], "links": [], "flags": {"phantom": 1},
		"mods": [["dodge_distance", "more", 0.5], ["dodge_iframes", "more", 1.0], ["dodge_charges", "add", -1.0], ["max_hp", "more", -0.25]],
		"desc": "Dodge distance +50% and dodge invulnerability doubled. -1 Dodge charge and 25% less maximum health."},

	# ---------------- Bulwark ----------------
	{"id": "w1", "name": "Sturdy", "branch": "bulwark", "kind": "minor", "at": [1, 0], "links": ["w2", "w2l"], "mods": [["max_hp", "add", 15.0]]},
	{"id": "w2", "name": "Iron Skin", "branch": "bulwark", "kind": "minor", "at": [2, 0.6], "links": ["w3r", "w3"], "mods": [["armor", "add", 0.06]]},
	{"id": "w2l", "name": "Steady Grip", "branch": "bulwark", "kind": "minor", "at": [2, -0.8], "links": ["w3"], "mods": [["parry_window", "add", 0.06]]},
	{"id": "w3", "name": "Mirror Ward", "branch": "bulwark", "kind": "notable", "at": [3, -0.4], "links": ["w4", "w4l", "x_gw"], "flags": {"mirror_ward": 1},
		"desc": "Projectiles you reflect deal triple damage and pierce."},
	{"id": "w3r", "name": "Bastion", "branch": "bulwark", "kind": "notable", "at": [3, 1.2], "links": ["w4", "x_wk"], "flags": {"ward_barrier": 1},
		"desc": "A successful Ward grants a barrier that absorbs 20 damage for 4s."},
	{"id": "w4", "name": "Stalwart", "branch": "bulwark", "kind": "minor", "at": [4, 0.4], "links": ["w5", "w5r"], "mods": [["max_hp", "add", 20.0]]},
	{"id": "w4l", "name": "Spiked Guard", "branch": "bulwark", "kind": "minor", "at": [4, -1.0], "links": ["w5"], "mods": [["thorns", "add", 10.0]]},
	{"id": "w5", "name": "Second Wind", "branch": "bulwark", "kind": "notable", "at": [5, -0.5], "links": ["w6"], "flags": {"second_wind": 1},
		"desc": "Once per expedition, a lethal blow leaves you at 1 health and invulnerable for 2s."},
	{"id": "w5r", "name": "Aegis", "branch": "bulwark", "kind": "ability", "at": [5, 1.0], "links": ["w6"], "ability": "aegis",
		"desc": "Unlocks Aegis: a ward of hearth-light that absorbs damage and turns projectiles back."},
	{"id": "w6", "name": "Unbreakable", "branch": "bulwark", "kind": "keystone", "at": [6, 0.2], "links": [], "flags": {"unbreakable": 1},
		"mods": [["max_hp", "more", 0.4], ["armor", "add", 0.15], ["move_speed", "more", -0.18]],
		"desc": "+40% maximum health and +15% armor. You cannot be knocked back. 18% less movement speed."},

	# ---------------- Kindle ----------------
	{"id": "k1", "name": "Deeper Wick", "branch": "kindle", "kind": "minor", "at": [1, 0], "links": ["k2", "k2r"], "mods": [["kindle_max", "add", 20.0]]},
	{"id": "k2", "name": "Ember Hunger", "branch": "kindle", "kind": "minor", "at": [2, -0.6], "links": ["k3l", "k3"], "mods": [["kindle_gain", "inc", 0.15]]},
	{"id": "k2r", "name": "Efficient Flame", "branch": "kindle", "kind": "minor", "at": [2, 0.8], "links": ["k3"], "mods": [["ability_cost", "more", -0.1]]},
	{"id": "k3", "name": "Wisp Familiar", "branch": "kindle", "kind": "ability", "at": [3, 0.3], "links": ["k4", "k4r", "x_wk"], "ability": "wisp",
		"desc": "Unlocks Wisp Familiar: summon a loyal hearth-wisp that hunts your foes."},
	{"id": "k3l", "name": "Soul Harvest", "branch": "kindle", "kind": "notable", "at": [3, -1.3], "links": ["k4", "x_kb"], "mods": [["kindle_on_kill", "add", 8.0]],
		"desc": "Killing an enemy grants 8 Kindle."},
	{"id": "k4", "name": "Brighter Flame", "branch": "kindle", "kind": "minor", "at": [4, -0.4], "links": ["k5", "k5l"], "mods": [["ability_damage", "add", 0.15]]},
	{"id": "k4r", "name": "Swift Rites", "branch": "kindle", "kind": "minor", "at": [4, 1.0], "links": ["k5l"], "mods": [["cooldown", "more", -0.12]]},
	{"id": "k5", "name": "Overflow", "branch": "kindle", "kind": "notable", "at": [5, -0.8], "links": ["k6"], "flags": {"overflow": 1},
		"desc": "While at maximum Kindle, your attacks also launch seeking ember bolts."},
	{"id": "k5l", "name": "Twin Wisps", "branch": "kindle", "kind": "notable", "at": [5, 0.7], "links": ["k6"], "flags": {"twin_wisps": 1},
		"desc": "Wisp Familiar summons an additional wisp. Wisps deal +30% damage."},
	{"id": "k6", "name": "Bonfire Soul", "branch": "kindle", "kind": "keystone", "at": [6, 0], "links": [], "flags": {"bonfire_soul": 1}, "mods": [["ability_damage", "more", 0.4]],
		"desc": "Abilities deal 40% more damage. Without enough Kindle, abilities consume health instead."},

	# ---------------- Masteries (ranked, beside each keystone) ----------------
	{"id": "b_m", "name": "Blade Mastery", "branch": "blade", "kind": "mastery", "ranks": 5, "at": [6, -1.4], "links": ["b5"],
		"mods": [["melee_damage", "add", 0.04], ["crit_chance", "add", 0.01]]},
	{"id": "p_m", "name": "Pyre Mastery", "branch": "pyre", "kind": "mastery", "ranks": 5, "at": [6, 1.5], "links": ["p5"],
		"mods": [["fire_damage", "add", 0.05], ["burn_damage", "add", 0.06]]},
	{"id": "r_m", "name": "Rime Mastery", "branch": "rime", "kind": "mastery", "ranks": 5, "at": [6, -1.5], "links": ["r5"],
		"mods": [["frost_damage", "add", 0.05], ["chill_power", "add", 0.03]]},
	{"id": "g_m", "name": "Gloam Mastery", "branch": "gloam", "kind": "mastery", "ranks": 5, "at": [6, 1.4], "links": ["g5"],
		"mods": [["move_speed", "inc", 0.03], ["dodge_recharge", "more", -0.04]]},
	{"id": "w_m", "name": "Bulwark Mastery", "branch": "bulwark", "kind": "mastery", "ranks": 5, "at": [6, -1.4], "links": ["w5"],
		"mods": [["max_hp", "add", 8.0], ["armor", "add", 0.015]]},
	{"id": "k_m", "name": "Kindle Mastery", "branch": "kindle", "kind": "mastery", "ranks": 5, "at": [6, 1.5], "links": ["k5l"],
		"mods": [["kindle_max", "add", 5.0], ["ability_damage", "add", 0.04]]},

	# ---------------- the outer ring: keystones that change how you fight ----------------
	# reached through each branch's Mastery; each turns a mechanic and asks a price
	{"id": "b7", "name": "Counterweight", "branch": "blade", "kind": "keystone", "at": [7, -1.4], "links": ["b_m"], "flags": {"counterweight": 1},
		"mods": [["parry_window", "more", -0.3]],
		"desc": "A successful Ward unleashes your weapon's charged attack at once (the Tome reads a burst of five words). Your Ward window is 30% shorter."},
	{"id": "p7", "name": "Ashbringer", "branch": "pyre", "kind": "keystone", "at": [7, 1.5], "links": ["p_m"], "flags": {"ashbringer": 1},
		"mods": [["ability_cost", "more", 0.25]],
		"desc": "Fire from your spells leaves burning ground under what it hits; foes standing in it take 25% more damage from you. Spells cost 25% more Kindle."},
	{"id": "r7", "name": "Stillness", "branch": "rime", "kind": "keystone", "at": [7, -1.5], "links": ["r_m"], "flags": {"stillness": 1},
		"mods": [["move_speed", "more", -0.1]],
		"desc": "Stand still for a breath and you are Still: your hits deal 40% more damage and always chill, until you move. You move 10% slower."},
	{"id": "g7", "name": "Shadowdancer", "branch": "gloam", "kind": "keystone", "at": [7, 1.4], "links": ["g_m"], "flags": {"shadowdancer": 1},
		"mods": [["max_hp", "more", -0.15]],
		"desc": "Every dodge leaves a shade where you stood that detonates a moment later. 15% less maximum health."},
	{"id": "w7", "name": "Bastion", "branch": "bulwark", "kind": "keystone", "at": [7, -1.4], "links": ["w_m"], "flags": {"bastion": 1},
		"desc": "Your Ward also turns blows aimed at allies near you, and every Ward answers with a shockwave. After a Ward you wait 50% longer to raise it again."},
	{"id": "k7", "name": "Runebound", "branch": "kindle", "kind": "keystone", "at": [7, 1.5], "links": ["k_m"], "flags": {"runebound": 1},
		"mods": [["cooldown", "more", 0.25]],
		"desc": "Your spells deal 8% more damage for every Ember Rune set in your spells. Spell cooldowns are 25% longer."},

	# ---------------- Build paths (the second layer of each branch) ----------------
	# each branch gains a spell or a mechanic that changes how a build plays,
	# reached beside its first notable and ending in a keystone with a price
	{"id": "b_rush", "name": "Ember Rush", "branch": "blade", "kind": "ability", "at": [3, 1.6], "links": ["b2r", "b_mo"], "ability": "rush",
		"desc": "Unlocks Ember Rush: burst toward the cursor as a streak of fire, cutting and burning everything in your path."},
	{"id": "b_mo", "name": "Momentum", "branch": "blade", "kind": "notable", "at": [4, 1.8], "links": ["b8"], "flags": {"momentum": 1},
		"desc": "Each weapon hit builds Momentum (up to 8; it fades 1.5s after your last hit): +4% attack speed per stack. At 8, your combo finisher also looses a cutting wave."},
	{"id": "b8", "name": "Thousand Cuts", "branch": "blade", "kind": "keystone", "at": [5.6, 2.3], "links": [], "flags": {"thousand_cuts": 1},
		"mods": [["attack_speed", "more", 0.5]],
		"desc": "You attack 50% faster, but your weapon hits deal 30% less damage. Every third hit in a row flings a spectral knife at another foe."},
	{"id": "p_fork", "name": "Splintering Flame", "branch": "pyre", "kind": "notable", "at": [4, -1.8], "links": ["p3l", "p8"], "mods": [["fork", "add", 1.0]],
		"desc": "Your projectiles split in two when they first strike a foe; the halves fly on at 50% damage."},
	{"id": "p8", "name": "Ember Hail", "branch": "pyre", "kind": "keystone", "at": [5.4, -2.0], "links": [], "flags": {"ember_hail": 1},
		"mods": [["projectiles", "add", 2.0]],
		"desc": "Everything you fire looses 2 more projectiles, but each deals 25% less damage."},
	{"id": "r_ret", "name": "Returning Frost", "branch": "rime", "kind": "notable", "at": [4, 1.9], "links": ["r3r"], "flags": {"proj_return": 1},
		"mods": [["chill_chance", "add", 0.1]],
		"desc": "Your projectiles turn back at the end of their flight and strike again on the way home. +10% chill chance."},
	{"id": "gk", "name": "Gloam Knives", "branch": "gloam", "kind": "ability", "at": [4, -1.9], "links": ["g3l", "g_fan"], "ability": "knives",
		"desc": "Unlocks Gloam Knives: fling a fan of five shadow knives. Cheap and quick, and shaped by every projectile modifier you carry."},
	{"id": "g_fan", "name": "Fan of Shadows", "branch": "gloam", "kind": "notable", "at": [5, -2.1], "links": ["g_ric"], "mods": [["projectiles", "add", 1.0]],
		"desc": "Everything you fire looses 1 more projectile."},
	{"id": "g_ric", "name": "Ricochet", "branch": "gloam", "kind": "notable", "at": [6, -2.0], "links": [], "mods": [["chain", "add", 2.0]],
		"desc": "Your projectiles leap from a struck foe to the next one nearby, up to 2 times."},
	{"id": "w_rk", "name": "Rekindle", "branch": "bulwark", "kind": "ability", "at": [4, 1.9], "links": ["w3r", "w_ret"], "ability": "rekindle",
		"desc": "Unlocks Rekindle: hearth-light floods out around you, warding you and every ally in it, restoring Kindle and raising the fallen."},
	{"id": "w_ret", "name": "Retribution", "branch": "bulwark", "kind": "notable", "at": [5, 2.1], "links": ["w8"], "flags": {"retribution": 1},
		"desc": "Damage you take is stored (up to your maximum health). Your next successful Ward releases it, doubled, as a shockwave around you."},
	{"id": "w8", "name": "Last Light", "branch": "bulwark", "kind": "keystone", "at": [6, 2.2], "links": [], "flags": {"last_light": 1},
		"mods": [["max_hp", "more", -0.4]],
		"desc": "Your Kindle takes blows before your health does, and after 2s unhurt it refills quickly. 40% less maximum health."},
	{"id": "k_orb", "name": "Cinder Orb", "branch": "kindle", "kind": "ability", "at": [4.4, 2.0], "links": ["k4r"], "ability": "orb",
		"desc": "Unlocks Cinder Orb: a slow orb of embers you burst with a second cast - the longer it drifted, the bigger the burst."},
	{"id": "p_beam", "name": "Soulfire Beam", "branch": "pyre", "kind": "ability", "at": [3.9, 2.2], "links": ["p4r"], "ability": "beam",
		"desc": "Unlocks Soulfire Beam: pour the lantern's fire out in a beam you steer, burning hotter the longer it holds."},
	{"id": "r_wall", "name": "Rimewall", "branch": "rime", "kind": "ability", "at": [3.9, 3.1], "links": ["r_ret"], "ability": "rimewall",
		"desc": "Unlocks Rimewall: raise a wall of ice that stops foes and their shots, and shatters when it melts."},
	{"id": "b_form", "name": "Hearthfire Form", "branch": "blade", "kind": "ability", "at": [2.4, 2.4], "links": ["b_rush"], "ability": "hearthfire",
		"desc": "Unlocks Hearthfire Form: become hearth-fire for 7s - faster, your weapon's hits burst in flame, and it ends in a nova."},
	# synergies of the new spells and weapon forms (combat-identity pass)
	{"id": "g_cut", "name": "Shadow Cutlery", "branch": "gloam", "kind": "notable", "at": [4.4, -2.9], "links": ["gk"], "flags": {"shadow_cutlery": 1},
		"desc": "Each lodged Gloam Knife also leaves a gloam mark; when lodged knives burst they tear the marks open too (6 shadow damage each)."},
	{"id": "k_det", "name": "Detonator", "branch": "kindle", "kind": "notable", "at": [4.8, 3.0], "links": ["k_orb"], "flags": {"detonator": 1},
		"desc": "A Cinder Orb's burst also bursts the knives lodged in what it strikes, tears their gloam marks open and shatters any Rimewall it touches."},
	{"id": "b_forged", "name": "Hearthforged", "branch": "blade", "kind": "notable", "at": [3.8, 3.3], "links": ["b_form", "b_rush"], "flags": {"hearthforged": 1},
		"desc": "In Hearthfire Form your weapon's gauge fills twice as fast (heat, marks, cuts, embers), and every foe you fell in it adds a second to the form (up to 5)."},
	{"id": "r_bast", "name": "Frozen Bastion", "branch": "rime", "kind": "notable", "at": [4.6, 2.7], "links": ["r_wall"], "flags": {"frozen_bastion": 1},
		"desc": "Your Rimewall chills what stands beside it every second, and when it shatters it freezes the already chilled."},
	{"id": "p_pour", "name": "Steady Pour", "branch": "pyre", "kind": "notable", "at": [4.3, 3.2], "links": ["p_beam"], "flags": {"steady_pour": 1},
		"desc": "You walk at full pace while pouring a Soulfire Beam, and it grows hot half again as fast."},
	# techniques: each kind of weapon's own skill, lent by the tree to any weapon
	{"id": "t_cadence", "name": "Cadence", "branch": "blade", "kind": "notable", "at": [3.6, -2.4], "links": ["b3l"], "flags": {"tech_cadence": 1},
		"desc": "Any weapon learns the sword's rhythm: press again just as a swing settles and the next comes quicker and 25% harder; the third in time lands like a finisher."},
	{"id": "t_breaker", "name": "Breaking Blow", "branch": "bulwark", "kind": "notable", "at": [3.6, -2.2], "links": ["w4l"], "flags": {"tech_breaker": 1},
		"desc": "Any weapon hits like a hammer: a blow that breaks a foe's poise sends the shock into those beside it (30% of the blow, most of its stagger)."},
	{"id": "t_behind", "name": "Knife in the Dark", "branch": "gloam", "kind": "notable", "at": [6.4, -1.0], "links": ["g5l"], "flags": {"tech_behind": 1},
		"desc": "Any weapon finds the gap: a blow from behind a foe is always critical (guardians watch their backs)."},
	{"id": "t_point", "name": "The Point", "branch": "rime", "kind": "notable", "at": [6.2, 1.6], "links": ["r5r"], "flags": {"tech_point": 1},
		"desc": "Any thrust has a sweet spot: struck with the far end of its reach, a foe takes 35% more and is driven back."},
	{"id": "t_overcharge", "name": "Overcharge", "branch": "kindle", "kind": "notable", "at": [3.4, 2.0], "links": ["k4r"], "flags": {"tech_overcharge": 1},
		"desc": "Any charged attack can be held past full: after a breath more it is Overcharged, and its release costs 15 Kindle and hits 45% harder."},
	{"id": "t_focus", "name": "Steady Eye", "branch": "pyre", "kind": "notable", "at": [2.8, 1.9], "links": ["p2r"], "flags": {"tech_focus": 1},
		"desc": "Any weapon builds Focus: a charged blow that lands adds one (up to three, +12% damage each); any blow that lands on you loses it all."},
	# specialisation keystones that turn a technique into a way of fighting, with a price
	{"id": "s_cadence", "name": "Perfect Cadence", "branch": "blade", "kind": "keystone", "at": [5.4, -2.4], "links": ["t_cadence"], "flags": {"perfect_cadence": 1},
		"desc": "Every strike in time is critical. Strikes out of time deal 20% less. (Cadence: press again just as a swing settles.)"},
	{"id": "s_lantern", "name": "The Lantern's Edge", "branch": "kindle", "kind": "keystone", "at": [5.6, -3.4], "links": ["k_lw"], "flags": {"lantern_edge": 1},
		"desc": "Your light is a weapon: it reaches 30% further, and foes inside it take up to 25% more from you, the fuller your Kindle. Weapon hits no longer give Kindle."},
	{"id": "s_vanguard", "name": "Vanguard's Weight", "branch": "bulwark", "kind": "keystone", "at": [5.2, -2.4], "links": ["t_breaker"], "flags": {"vanguard": 1},
		"mods": [["attack_speed", "more", -0.1]],
		"desc": "Staggered foes take 35% more from you, and a Breaking Blow's shock carries twice as far and hits twice as hard. You attack 10% slower."},
	{"id": "s_unblinking", "name": "Unblinking", "branch": "pyre", "kind": "keystone", "at": [6.4, 2.6], "links": ["p_pour", "t_focus"], "flags": {"unblinking": 1},
		"desc": "Focus gathers up to five, and a blow that lands on you costs one instead of all. Without Focus your blows deal 10% less. (Focus: Steady Eye, or a bow's true shots.)"},
	# weapon masteries: one notable per kind of weapon, each changing how its
	# forms fight (read by the weapon scripts), on the branch whose spirit it shares
	{"id": "m_sword", "name": "Sunder and Answer", "branch": "blade", "kind": "notable", "at": [4.8, -3.1], "links": ["b4l"], "flags": {"mastery_sword": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Swords. Gravecleaver: two blows Sunder a foe (not three), and Grave Drop executes below 35% health. Duelist's Sabre: every riposte gives back a dodge. +5% weapon damage."},
	{"id": "m_hammer", "name": "Earthshaker", "branch": "bulwark", "kind": "notable", "at": [4.8, -3.4], "links": ["w4l"], "flags": {"mastery_hammer": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Hammers. Tombmaul: every slam echoes a third time. Emberforge Mallet: heat builds half again as fast. +5% weapon damage."},
	{"id": "m_daggers", "name": "Night's Tally", "branch": "gloam", "kind": "notable", "at": [4.9, 3.0], "links": ["g4r"], "flags": {"mastery_daggers": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Daggers. Gloam Kris: a foe holds up to seven marks. Ember Shivs: the fan throws nine. +5% weapon damage."},
	{"id": "m_spear", "name": "Rooted Ground", "branch": "rime", "kind": "notable", "at": [5.2, -3.4], "links": ["r_m"], "flags": {"mastery_spear": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Spears. Rootspear: roots hold half again as long. Sunfall Glaive: its falling sun is a quarter wider. +5% weapon damage."},
	{"id": "m_bow", "name": "Quiver Lore", "branch": "rime", "kind": "notable", "at": [5.8, 3.4], "links": ["r_bast"], "flags": {"mastery_bow": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Bows. Splitwood Bow: the draw nocks up to seven arrows. +5% weapon damage."},
	{"id": "m_staff", "name": "Branching Flame", "branch": "pyre", "kind": "notable", "at": [5.6, 3.4], "links": ["p_m"], "flags": {"mastery_staff": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Staves. Splitbranch: every bolt forks twice. +5% weapon damage."},
	{"id": "m_tome", "name": "Inkbound", "branch": "kindle", "kind": "notable", "at": [3.6, 3.4], "links": ["k_orb"], "flags": {"mastery_tome": 1},
		"mods": [["weapon_damage", "add", 0.05]],
		"desc": "Tomes. Codex of Echoes: echoed spells strike at 65% (from 45%). Grimoire of Ash: it breathes a third further. +5% weapon damage."},
	{"id": "k_lan", "name": "Hearth Lantern", "branch": "kindle", "kind": "ability", "at": [4, -1.8], "links": ["k3l", "k_hb", "k_lw"], "ability": "lantern",
		"desc": "Unlocks Hearth Lantern: plant a lantern that looses ember bolts at foes; every Kindled in its light regains Kindle and takes less damage."},
	{"id": "k_lw", "name": "Lanternwright", "branch": "kindle", "kind": "notable", "at": [4.4, -2.9], "links": [], "flags": {"lanternwright": 1},
		"desc": "Your Hearth Lanterns burn 50% longer and fire twice as fast, and two of them can stand at once."},
	{"id": "k_hb", "name": "Hearthbond", "branch": "kindle", "kind": "notable", "at": [5, -2.0], "links": ["k8"], "flags": {"hearthbond": 1},
		"desc": "You and every Kindled within 5 paces of you gain 2 Kindle a second. When an ally near you is struck, you gain 4 Kindle."},
	{"id": "k8", "name": "Spellblade", "branch": "kindle", "kind": "keystone", "at": [6, -1.9], "links": [], "flags": {"spellblade": 1},
		"mods": [["ability_cost", "more", 0.15]],
		"desc": "Each spell you cast charges your next 3 weapon hits with its element: +40% damage, and they Burn, Chill or Expose. Spells cost 15% more Kindle."},

	# ---------------- Hybrids (between branches) ----------------
	# the deep hybrids: a second step between two branches, each a way of fighting
	# where one way of fighting meets another: each joins a technique to something else
	{"id": "w_kb", "name": "The Wide Wick", "branch": "kindle|blade", "kind": "hybrid", "ring": 7.0, "links": ["z_kb"], "flags": {"wide_wick": 1},
		"desc": "A spell cast with your lantern at four-fifths full or more lands a fifth harder. Fill it before you spend it."},
	{"id": "w_gw", "name": "Slipstream", "branch": "gloam|bulwark", "kind": "hybrid", "ring": 7.0, "links": ["z_gw"], "flags": {"slipstream": 1},
		"desc": "A perfect dodge makes your next spell free."},
	{"id": "w_wk", "name": "Overflowing Light", "branch": "bulwark|kindle", "kind": "hybrid", "ring": 7.0, "links": ["z_wk"], "flags": {"overflow": 1},
		"desc": "Kindle gained past full becomes health, a quarter as much."},
	{"id": "w_rg", "name": "Shatterpoint", "branch": "rime|gloam", "kind": "hybrid", "ring": 7.0, "links": ["z_rg"], "flags": {"shatterpoint": 1},
		"desc": "Break the guard of something cold and it freezes where it stands."},
	{"id": "z_kb", "name": "Banked Strikes", "branch": "kindle|blade", "kind": "hybrid", "ring": 6.4, "links": ["y_kb"], "flags": {"banked_strikes": 1},
		"desc": "Strikes in Cadence give back Kindle. A run of three lights your lantern for a moment."},
	{"id": "z_bp", "name": "Searing Time", "branch": "blade|pyre", "kind": "hybrid", "ring": 5.3, "links": ["x_bp"], "flags": {"searing_time": 1},
		"desc": "Strikes in Cadence set foes alight. Struck in time while burning, a foe takes half again as much."},
	{"id": "z_pr", "name": "Cold Aim", "branch": "pyre|rime", "kind": "hybrid", "ring": 5.3, "links": ["x_pr"], "flags": {"cold_aim": 1},
		"desc": "True shots chill. At full Focus they freeze what is already chilled."},
	{"id": "z_rg", "name": "Rime Knife", "branch": "rime|gloam", "kind": "hybrid", "ring": 6.4, "links": ["y_rg"], "flags": {"rime_knife": 1},
		"desc": "A blow from behind on a chilled foe spends the chill and deals half again as much."},
	{"id": "z_gw", "name": "Turned Aside", "branch": "gloam|bulwark", "kind": "hybrid", "ring": 6.4, "links": ["y_gw"], "flags": {"turned_aside": 1},
		"desc": "After a perfect dodge or a clean Ward, your next blow lands as if from behind: it is critical, guardians included."},
	{"id": "z_wk", "name": "Breaker's Coal", "branch": "bulwark|kindle", "kind": "hybrid", "ring": 6.4, "links": ["y_wk"], "flags": {"breakers_coal": 1},
		"desc": "Breaking a foe's guard pours Kindle back into you, and it burns those shaken by it."},
	{"id": "y_kb", "name": "Furnace Heart", "branch": "kindle|blade", "kind": "hybrid", "ring": 5.1, "links": ["x_kb"], "flags": {"furnace_heart": 1},
		"desc": "Every point of Kindle you spend banks in your weapon: your next blow is 1% stronger for each, up to 60%. Cast, then strike."},
	{"id": "y_gw", "name": "Perfect Answer", "branch": "gloam|bulwark", "kind": "hybrid", "ring": 5.1, "links": ["x_gw"], "flags": {"perfect_answer": 1},
		"desc": "After a Ward or a perfect dodge, your next blow is a sure critical and staggers: a defence that is an attack."},
	{"id": "y_rg", "name": "Shadowfrost", "branch": "rime|gloam", "kind": "hybrid", "ring": 5.1, "links": ["x_rg"], "flags": {"shadowfrost": 1},
		"desc": "A shade strikes with you at anything chilled: your blows land 30% harder on chilled foes."},
	{"id": "y_wk", "name": "Hearth Anchor", "branch": "bulwark|kindle", "kind": "hybrid", "ring": 5.1, "links": ["x_wk"], "flags": {"hearth_anchor": 1},
		"desc": "While you Ward, Kindle flows back: 8 a second. Standing your ground fuels the spells that end the fight."},
	{"id": "x_bp", "name": "Searing Edge", "branch": "blade|pyre", "kind": "hybrid", "links": [], "mods": [["fire_damage", "add", 0.1]], "flags": {"searing_edge": 1},
		"desc": "Melee hits have a 20% chance to Burn. +10% fire damage."},
	{"id": "x_pr", "name": "Thermal Shock", "branch": "pyre|rime", "kind": "hybrid", "links": [], "flags": {"thermal_shock": 1},
		"desc": "Fire damage against a chilled enemy (or frost against a burning one) erupts in a burst of steam that damages everything nearby."},
	{"id": "x_rg", "name": "Frostwalk", "branch": "rime|gloam", "kind": "hybrid", "links": [], "flags": {"frost_trail": 1},
		"desc": "Dodging leaves a trail of rime that Chills enemies who cross it."},
	{"id": "x_gw", "name": "Counterstep", "branch": "gloam|bulwark", "kind": "hybrid", "links": [], "flags": {"counterstep": 1},
		"desc": "After a perfect dodge or a successful Ward, your next hit breaks the enemy's poise."},
	{"id": "x_wk", "name": "Hearthguard", "branch": "bulwark|kindle", "kind": "hybrid", "links": [], "flags": {"hearthguard": 1},
		"desc": "Gain 10 Kindle when struck. While at maximum Kindle you take 15% less damage."},
	{"id": "x_kb", "name": "Ember Edge", "branch": "kindle|blade", "kind": "hybrid", "links": [], "flags": {"ember_edge": 1},
		"desc": "Melee hits generate 50% more Kindle."},
]

## Icons for the nodes that change how you play; minors use their stat's icon.
const ICONS := {
	"hearth": "hearth", "b3": "mirror", "b3l": "sword", "b5": "skull", "b5r": "flare", "b6": "crown",
	"p3": "coal", "p3l": "lance", "p5": "flame", "p5l": "brand", "p6": "phoenix",
	"r3": "prism", "r3r": "sigil", "r5": "mirror", "r5r": "gem_blue", "r6": "snow",
	"g3": "gloamstep", "g3l": "boot", "g4r": "gloamstep", "g5": "eye", "g5l": "mask", "g6": "mask",
	"w3": "mirror", "w3r": "aegis", "w5": "bandage", "w5r": "aegis", "w6": "shield",
	"k3": "wisp", "k3l": "skull", "k5": "sun", "k5l": "wisp", "k6": "sun",
	"x_bp": "flame", "x_pr": "prism", "x_rg": "snow", "x_gw": "dodge", "x_wk": "kindle", "x_kb": "sword",
	"y_kb": "flame", "y_gw": "dodge", "y_rg": "snow", "y_wk": "kindle",
	"b_m": "sword", "p_m": "flame", "r_m": "snow", "g_m": "feather", "w_m": "shield", "k_m": "wick",
	"b7": "hammer", "p7": "coal", "r7": "hourglass", "g7": "gloamstep", "w7": "shield", "k7": "sigil",
	"b_rush": "rush", "b_mo": "momentum", "b8": "cuts", "p_fork": "splinter", "p8": "hail", "r_ret": "return",
	"gk": "knives", "g_fan": "fan", "g_ric": "ricochet", "w_rk": "rekindle", "w_ret": "retribution", "w8": "lastlight",
	"k_lan": "lantern", "k_lw": "lanterns", "k_hb": "bond", "k8": "spellblade",
}
const STAT_ICONS := {
	"melee_damage": "sword", "attack_speed": "hourglass", "crit_chance": "eye", "crit_mult": "gem_red", "poise_damage": "hammer",
	"fire_damage": "flame", "burn_chance": "coal", "burn_damage": "coal", "burn_stacks": "brand",
	"frost_damage": "snow", "chill_chance": "snow", "chill_power": "gem_blue", "status_duration": "hourglass",
	"move_speed": "boot", "dodge_recharge": "dodge", "dodge_distance": "feather", "dodge_iframes": "mask", "dodge_charges": "dodge",
	"max_hp": "heart", "armor": "shield", "parry_window": "mirror", "thorns": "fork",
	"kindle_max": "wick", "kindle_gain": "kindle", "ability_cost": "candle", "ability_damage": "prism", "cooldown": "hourglass",
	"kindle_on_kill": "skull", "projectiles": "fan", "pierce": "lance", "chain": "ricochet", "fork": "splinter",
	"projectile_damage": "bow",
}

static var _by_id: Dictionary = {}
static var _adj: Dictionary = {}


static func _ensure() -> void:
	if not _by_id.is_empty():
		return
	for n in NODES:
		_by_id[n.id] = n
		_adj[n.id] = []
	for n in NODES:
		for l in n.get("links", []):
			if not _adj[n.id].has(l):
				_adj[n.id].append(l)
			if _adj.has(l) and not _adj[l].has(n.id):
				_adj[l].append(n.id)


static func node(id: String) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func all_ids() -> Array:
	_ensure()
	return _by_id.keys()


static func neighbours(id: String) -> Array:
	_ensure()
	return _adj.get(id, [])


static func cost(id: String) -> int:
	return int(COSTS.get(node(id).get("kind", "minor"), 1))


static func max_rank(id: String) -> int:
	return int(node(id).get("ranks", 1))


static func rank(id: String, allocated: Array) -> int:
	return allocated.count(id)


## A node can be allocated when it is adjacent to an allocated node; a mastery
## that is already kindled can take further ranks up to its maximum.
static func can_allocate(id: String, allocated: Array, points: int) -> bool:
	if node(id).is_empty() or points < cost(id):
		return false
	if allocated.has(id):
		return rank(id, allocated) < max_rank(id)
	for n in neighbours(id):
		if allocated.has(n):
			return true
	return false


## Refunding a node is allowed only if the remaining tree stays connected to the root.
static func can_refund(id: String, allocated: Array) -> bool:
	if id == "hearth" or not allocated.has(id):
		return false
	if rank(id, allocated) > 1:
		return true   # dropping one rank keeps the node in the tree
	var rest := allocated.duplicate()
	rest.erase(id)
	return connected_set(rest).size() == unique(rest).size()


static func unique(allocated: Array) -> Array:
	var seen := {}
	for id in allocated:
		seen[id] = true
	return seen.keys()


static func connected_set(allocated: Array) -> Array:
	var seen := {}
	if not allocated.has("hearth"):
		return []
	var stack := ["hearth"]
	while not stack.is_empty():
		var c: String = stack.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		for n in neighbours(c):
			if allocated.has(n) and not seen.has(n):
				stack.append(n)
	return seen.keys()


static func spent(allocated: Array) -> int:
	var s := 0
	for id in allocated:
		s += cost(id)
	return s


## Abilities granted by allocated nodes (Flare is innate).
static func abilities(allocated: Array) -> Array:
	var out := ["flare"]
	for id in allocated:
		var a: String = node(id).get("ability", "")
		if a != "" and not out.has(a):
			out.append(a)
	return out


## Applies every allocated node's modifiers and flags to `stats`.
static func apply(allocated: Array, stats: Stats) -> void:
	for id in allocated:
		var n := node(id)
		if n.is_empty():
			continue
		stats.apply_mods(n.get("mods", []))
		stats.apply_flags(n.get("flags", {}))


static func icon_of(id: String) -> String:
	if ICONS.has(id):
		return ICONS[id]
	var n := node(id)
	if n.has("ability"):
		return String(GearDB.ability(n.ability).get("icon", "star"))
	var mods: Array = n.get("mods", [])
	if not mods.is_empty():
		return STAT_ICONS.get(String(mods[0][0]), "star")
	return "star"


## Cheapest route of unallocated nodes from the allocated tree to `id` (inclusive,
## in the order they must be kindled) and the allocated node it grows from.
## Returns {} when `id` is already allocated or cannot be reached.
static func path_to(id: String, allocated: Array) -> Dictionary:
	_ensure()
	if allocated.has(id) or not _by_id.has(id) or allocated.is_empty():
		return {}
	var dist := {}
	var prev := {}
	var open: Array = []
	for a in allocated:
		dist[a] = 0
		open.append(a)
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in range(1, open.size()):
			if int(dist[open[i]]) < int(dist[open[best]]):
				best = i
		var cur: String = open.pop_at(best)
		if done.has(cur):
			continue
		done[cur] = true
		if cur == id:
			break
		for nb in neighbours(cur):
			if allocated.has(nb):
				continue
			var d := int(dist[cur]) + cost(nb)
			if not dist.has(nb) or d < int(dist[nb]):
				dist[nb] = d
				prev[nb] = cur
				open.append(nb)
	if not prev.has(id):
		return {}
	var nodes: Array = []
	var c := id
	while not allocated.has(c):
		nodes.push_front(c)
		c = prev[c]
	return {"nodes": nodes, "from": c, "cost": int(dist[id])}


## Every stat bonus the allocated nodes grant, merged per stat and operation.
## Returns [[stat, op, value], ...] in a stable order.
static func totals(allocated: Array) -> Array:
	var sums := {}
	var order: Array = []
	for id in allocated:
		for m in node(id).get("mods", []):
			var key := "%s|%s" % [m[0], m[1]]
			if not sums.has(key):
				order.append(key)
				sums[key] = 0.0 if m[1] != "more" else 1.0
			if m[1] == "more":
				sums[key] = float(sums[key]) * (1.0 + float(m[2]))
			else:
				sums[key] = float(sums[key]) + float(m[2])
	var out: Array = []
	for key in order:
		var parts: PackedStringArray = String(key).split("|")
		var v := float(sums[key])
		out.append([parts[0], parts[1], v - 1.0 if parts[1] == "more" else v])
	return out


## Kindled nodes per branch (a ranked mastery counts once).
static func branch_counts(allocated: Array) -> Dictionary:
	var out := {}
	for id in unique(allocated):
		for b in String(node(id).get("branch", "")).split("|", false):
			out[b] = int(out.get(b, 0)) + 1
	return out


## Tree-space position of a node (for the UI).
static func position_of(id: String) -> Vector2:
	var n := node(id)
	if n.is_empty():
		return Vector2.ZERO
	if n.kind == "hybrid":
		var bs: PackedStringArray = String(n.branch).split("|")
		var a1: float = BRANCHES[bs[0]].angle
		var a2: float = BRANCHES[bs[1]].angle
		if absf(a2 - a1) > 180.0:
			a2 -= 360.0 * signf(a2 - a1)
		var a := deg_to_rad((a1 + a2) * 0.5)
		return Vector2(cos(a), sin(a)) * RING * float(n.get("ring", 3.6))
	if n.kind == "root":
		return Vector2.ZERO
	var ang := deg_to_rad(float(BRANCHES[n.branch].angle))
	var ring: float = float(n.at[0])
	var lat: float = float(n.at[1])
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	return dir * ring * RING + perp * lat * RING * 0.62
