## Great things remember being used. A legendary or unique worn on expeditions
## gathers Resonance: first it Awakens (its own powers grow), and later it asks its
## bearer which way to grow, once. A path gives it the power of another great
## thing, so one item can do what two never could. Everything is on the item
## itself ("res", "ev", "path" in its dictionary), so it survives saves, trades and
## the co-op sheet; nothing is hidden: the tooltip counts it.
class_name Evolutions
extends RefCounted

const AWAKE := 150       # Resonance to Awaken
const ASCEND := 500      # Resonance to choose a path
const AWAKE_MULT := 1.15     # an Awakened item's own powers

## Two ways for each great weapon. `flags` are the same ones the uniques use.
const PATHS := {
	"thousandth_cut": [
		{"id": "echo", "name": "the Echoing Count", "col": Color(1.0, 0.88, 0.55), "flags": {"echo_strike": 1}, "desc": "Every fourth blow echoes a moment later."},
		{"id": "chain", "name": "the Kept Count", "col": Color(1.0, 0.62, 0.3), "flags": {"crit_chain": 1}, "desc": "Critical hits leap on to another foe."}],
	"quakeheart": [
		{"id": "frost", "name": "the Frozen Heart", "col": Color(0.6, 0.85, 1.0), "flags": {"hoarfrost": 1}, "desc": "Whatever strikes you is chilled to the bone."},
		{"id": "blood", "name": "the Beating Heart", "col": Color(1.0, 0.4, 0.4), "flags": {"lifesteal": 1}, "desc": "Melee blows give back a little of what they deal."}],
	"hundred_embers": [
		{"id": "wild", "name": "the Wildfire Wand", "col": Color(1.0, 0.55, 0.25), "flags": {"wildfire": 1}, "desc": "Fire leaps from the burning to their neighbours."},
		{"id": "steam", "name": "the Scalding Wand", "col": Color(0.85, 0.95, 1.0), "flags": {"thermal_shock": 1}, "desc": "Fire on a chilled foe, or frost on a burning one, erupts in steam."}],
	"gloamfang": [
		{"id": "shade", "name": "Fang of Shades", "col": Color(0.75, 0.55, 1.0), "flags": {"shadowdancer": 1}, "desc": "Every dodge leaves a shade where you stood, which bursts."},
		{"id": "storm", "name": "Fang of Storms", "col": Color(0.6, 0.9, 1.0), "flags": {"storm_crit": 1}, "desc": "Critical hits call lightning down on the foe."}],
	"searing_pike": [
		{"id": "pyre", "name": "the Pyre Pike", "col": Color(1.0, 0.45, 0.25), "flags": {"combustion": 1}, "desc": "The burning burst when they fall."},
		{"id": "knives", "name": "the Splintering Pike", "col": Color(0.8, 0.6, 1.0), "flags": {"crit_knives": 1}, "desc": "Critical hits fling a spectral knife at another foe."}],
	"windreturn": [
		{"id": "seek", "name": "the Homing Wind", "col": Color(0.85, 1.0, 0.55), "flags": {"seeking": 1}, "desc": "Everything you loose bends toward the nearest foe."},
		{"id": "wild", "name": "the Wildfire Wind", "col": Color(1.0, 0.55, 0.25), "flags": {"wildfire": 1}, "desc": "Fire leaps from the burning to their neighbours."}],
	"hollow_index": [
		{"id": "storm", "name": "the Index of Storms", "col": Color(0.6, 0.9, 1.0), "flags": {"storm_crit": 1}, "desc": "Critical hits call lightning down on the foe."},
		{"id": "steam", "name": "the Scalding Index", "col": Color(0.85, 0.95, 1.0), "flags": {"thermal_shock": 1}, "desc": "Fire on a chilled foe, or frost on a burning one, erupts in steam."}],
	"wardenfang": [
		{"id": "knives", "name": "the Thousand Fangs", "col": Color(0.8, 0.6, 1.0), "flags": {"crit_knives": 1}, "desc": "Critical hits fling a spectral knife at another foe."},
		{"id": "echo", "name": "the Twice-Bitten", "col": Color(1.0, 0.88, 0.55), "flags": {"echo_strike": 1}, "desc": "Every fourth blow echoes a moment later."}],
	"bloomstring": [
		{"id": "pyre", "name": "the Funeral String", "col": Color(1.0, 0.45, 0.25), "flags": {"combustion": 1}, "desc": "The burning burst when they fall."},
		{"id": "seek", "name": "the Hungry String", "col": Color(0.85, 1.0, 0.55), "flags": {"seeking": 1}, "desc": "Everything you loose bends toward the nearest foe."}],
	"sunfall_glaive": [
		{"id": "wild", "name": "the Spreading Dawn", "col": Color(1.0, 0.55, 0.25), "flags": {"wildfire": 1}, "desc": "Fire leaps from the burning to their neighbours."},
		{"id": "echo", "name": "the Second Sunset", "col": Color(1.0, 0.88, 0.55), "flags": {"echo_strike": 1}, "desc": "Every fourth blow echoes a moment later."}],
}
## Everything else great grows one of three ways.
const COMMON := [
	{"id": "hearth", "name": "Hearthbound", "col": Color(1.0, 0.8, 0.45), "mods": [["kindle_max", "add", 15.0], ["kindle_gain", "add", 0.08]], "desc": "+15 maximum Kindle, +8% Kindle gained."},
	{"id": "deep", "name": "Deepforged", "col": Color(0.7, 0.75, 0.9), "mods": [["elite_damage", "add", 0.12], ["max_hp", "add", 10.0]], "desc": "+12% damage to champions, +10 health."},
	{"id": "hollow", "name": "Hollowed", "col": Color(0.6, 1.0, 0.85), "mods": [["ember_gain", "add", 0.1], ["xp_gain", "add", 0.06]], "desc": "+10% Embers, +6% Memories."},
]


## Things that can evolve: anything legendary or unique, trophies aside.
static func can_evolve(item: Dictionary) -> bool:
	var b := ItemDB.base(String(item.get("base", "")))
	return (b.get("legendary", false) or b.get("unique", false)) and not b.get("trophy", false)


static func paths_of(item: Dictionary) -> Array:
	return PATHS.get(String(item.get("base", "")), COMMON)


## 0 sleeping, 1 Awakened, 2 on its path.
static func stage(item: Dictionary) -> int:
	return 2 if String(item.get("path", "")) != "" else (1 if int(item.get("res", 0)) >= AWAKE else 0)


## It has gathered enough, and is asking.
static func ready(item: Dictionary) -> bool:
	return can_evolve(item) and String(item.get("path", "")) == "" and int(item.get("res", 0)) >= ASCEND


static func path_def(item: Dictionary) -> Dictionary:
	var id := String(item.get("path", ""))
	if id == "":
		return {}
	for p in paths_of(item):
		if String(p.id) == id:
			return p
	return {}


static func choose(item: Dictionary, id: String) -> bool:
	if not ready(item):
		return false
	for p in paths_of(item):
		if String(p.id) == id:
			item["path"] = id
			return true
	return false


## What its path adds to the item's powers.
## The colour its powers take once it has chosen (its glow, its tint).
static func path_color(item: Dictionary) -> Color:
	return path_def(item).get("col", Color(1, 1, 1))


static func path_mods(item: Dictionary) -> Array:
	return path_def(item).get("mods", [])


static func path_flags(item: Dictionary) -> Dictionary:
	return path_def(item).get("flags", {})


## Its name as it has grown.
static func named(item: Dictionary, n: String) -> String:
	if not can_evolve(item):
		return n
	match stage(item):
		1:
			return "Awakened %s" % n
		2:
			return "%s, %s" % [n, String(path_def(item).get("name", ""))]
	return n


## The line a tooltip shows ("" = nothing to say).
static func progress(item: Dictionary) -> String:
	if not can_evolve(item):
		return ""
	var r := int(item.get("res", 0))
	match stage(item):
		0:
			return "Resonance %d/%d: use wakes it." % [r, AWAKE]
		1:
			if r >= ASCEND:
				return "Resonance %d: it is ready to choose a path." % r
			return "Awakened: its powers +%d%%. Resonance %d/%d to a path." % [int(round((AWAKE_MULT - 1.0) * 100.0)), r, ASCEND]
	return "%s" % String(path_def(item).get("desc", ""))


## An expedition's worth of Resonance. Every Kindled's own count of what they took
## part in; a death pays half, because it was still used.
static func gain_of(run: RunState, outcome: String) -> int:
	var n: int = run.kills + 30 * (run.bosses as Array).size() + 15 * (run.grudges_won as Array).size() + run.resonance_bonus
	return n if outcome != "died" else n / 2


## Feeds everything great that is worn. Returns lines worth saying on the way home.
static func feed(equipped: Dictionary, amount: int) -> Array:
	var said: Array = []
	if amount <= 0:
		return said
	for slot in equipped:
		var it: Variant = equipped[slot]
		if not it is Dictionary or (it as Dictionary).is_empty() or not can_evolve(it):
			continue
		var was := int(it.get("res", 0))
		it["res"] = was + amount
		var n := ItemDB.item_name(it)
		if was < AWAKE and int(it.res) >= AWAKE:
			said.append("%s stirs." % n)
		if was < ASCEND and int(it.res) >= ASCEND and String(it.get("path", "")) == "":
			said.append("%s is ready to choose a path (Satchel)." % n)
	return said
