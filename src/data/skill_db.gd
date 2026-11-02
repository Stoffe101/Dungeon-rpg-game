## The Hearthtree: the permanent skill tree.
##
## Six branches radiate from the Hearth. Each has a spine of stat nodes,
## mechanic-changing notables, an active ability and a keystone with a real
## trade-off. Hybrid nodes sit between neighbouring branches so builds can
## cross over (fire + frost, dodge + parry, ...).
##
## Node fields:
##   id, name, branch, kind (root|minor|notable|ability|keystone|hybrid)
##   at: [ring, lateral] (polar placement around the branch axis) or pos override
##   links: neighbours (edges are undirected)
##   mods: [[stat, op, value]], flags: {flag: level}, ability: id, desc
class_name SkillDB
extends RefCounted

const RING := 60.0
const COSTS := {"root": 0, "minor": 1, "notable": 2, "ability": 2, "hybrid": 2, "keystone": 3}

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

	# ---------------- Hybrids (between branches) ----------------
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


## A node can be allocated when it is adjacent to an allocated node.
static func can_allocate(id: String, allocated: Array, points: int) -> bool:
	if allocated.has(id) or node(id).is_empty():
		return false
	if points < cost(id):
		return false
	for n in neighbours(id):
		if allocated.has(n):
			return true
	return false


## Refunding a node is allowed only if the remaining tree stays connected to the root.
static func can_refund(id: String, allocated: Array) -> bool:
	if id == "hearth" or not allocated.has(id):
		return false
	var rest := allocated.duplicate()
	rest.erase(id)
	return connected_set(rest).size() == rest.size()


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


static func branch_counts(allocated: Array) -> Dictionary:
	var out := {}
	for id in allocated:
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
		return Vector2(cos(a), sin(a)) * RING * 3.6
	if n.kind == "root":
		return Vector2.ZERO
	var ang := deg_to_rad(float(BRANCHES[n.branch].angle))
	var ring: float = float(n.at[0])
	var lat: float = float(n.at[1])
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	return dir * ring * RING + perp * lat * RING * 0.62
