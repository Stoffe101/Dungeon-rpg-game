## The Hollow Below: the endless descent that opens once the Ashen King falls.
## It runs through the three regions in turn (three depths each), and every
## third depth holds an Echo of that region's guardian: stronger, carrying an
## affix, and beaten to go deeper rather than to go home. Each new depth reads
## one more Omen into the run, so the danger and the payout keep climbing.
## The deepest light is remembered.
class_name Delve
extends RefCounted

const NAME := "The Hollow Below"
const ORDER := ["ossuary", "rootmire", "throne"]
const BLURB := "An endless descent through all three regions. Every third depth an Echo of its guardian waits; every depth reads another Omen. How deep can your light go?"
const SEALED := "Sealed. Fell the Ashen King to find the way further down."
const MAX_OMENS := 5        # a descent reads no more than this: fair, and legible

## The first time this Kindled reaches a depth of the Hollow. Personal: each
## machine of a party keeps its own. Worth going for once; nothing to farm.
const MILESTONES := {
	5: {"title": "Past the Last Map", "line": "Nobody charted this. Two Sunshards were left here, by someone.", "sunshards": 2},
	10: {"title": "The Light Still Holds", "line": "A blueprint, pressed into the wall by a hand like yours.", "blueprint": true},
	15: {"title": "Where the Regions Forget", "line": "Three Sunshards, and an old road's colours to wear.", "sunshards": 3, "look": "wanderer"},
	20: {"title": "Deeper Than the Sun Fell", "line": "A legendary piece lay here, waiting for somebody to get this far.", "legendary": true},
	30: {"title": "The Bottom of the Light", "line": "Whatever is below this, it has heard you.", "sunshards": 5},
}


## Past the first regions the deep has moods, three depths at a time, in turn:
## something to name and to plan for rather than one more number.
const BANDS := [
	{"id": "whisper", "name": "The Whispering Halls", "line": "more fights keep rules of their own"},
	{"id": "thin", "name": "The Thin Light", "line": "lanterns reach less far"},
	{"id": "crowded", "name": "The Crowded Dark", "line": "every fight calls one more wave"},
	{"id": "roads", "name": "The Old Roads", "line": "the floors run in rings and wings"},
]


static func band(depth: int) -> Dictionary:
	return {} if depth < 4 else BANDS[int((depth - 4) / 3) % BANDS.size()]


static func unlocked() -> bool:
	return int(Profile.data.world.get("ashen_king_kills", 0)) >= 1


## Every sixth depth the Undervault fractures: two regions lie over each other,
## room by room, their stone and their dead alike, and a rift must be closed.
static func fractured(depth: int) -> bool:
	return depth % 6 == 4


## The region lying over this one on a fractured depth.
static func overlap_region(depth: int) -> String:
	return ORDER[(ORDER.find(region_for(depth)) + 1) % ORDER.size()]


## This save reached `depth` of the Hollow: the first time past a milestone
## pays and tells (returns it, or {}).
static func reach(depth: int, rng: RandomNumberGenerator) -> Dictionary:
	if not MILESTONES.has(depth) or Chronicle.marks("hollow_%d" % depth) > 0:
		return {}
	Chronicle.mark("hollow_%d" % depth)
	var m: Dictionary = MILESTONES[depth]
	Chronicle.note("Depth %d of the Hollow Below: %s." % [depth, m.title])
	if m.has("sunshards"):
		Profile.add_currency("sunshards", int(m.sunshards))
	if m.has("look"):
		Looks.unlock(String(m.look))
	if m.get("blueprint", false):
		var have: Array = Profile.known_blueprints() + Profile.scrolls()
		var b := ItemDB.roll_blueprint(rng, have)
		if b != "":
			Profile.scrolls().append(b)
	if m.get("legendary", false):
		Profile.add_item(ItemDB.make_item("sunfall_mantle", "legendary", 1, rng, 3))
	Profile.save_profile()
	return m


static func region_for(depth: int) -> String:
	return ORDER[int((depth - 1) / 3) % ORDER.size()]


static func is_boss_depth(depth: int) -> bool:
	return depth % 3 == 0


## How many Echoes of a guardian the Kindled has met by this depth (1 at depth 3).
static func echo_n(depth: int) -> int:
	return maxi(1, depth / 3)


## One more Omen, read when the party goes deeper (none left: none).
static func next_omen(rng: RandomNumberGenerator, active: Array) -> String:
	if active.size() >= MAX_OMENS:
		return ""
	var pool: Array = Omens.OMENS.keys().filter(func(o): return not active.has(o) and Omens.unlocked(String(o)) and Omens.compatible(String(o), active))
	if pool.is_empty():
		return ""
	return String(pool[rng.randi_range(0, pool.size() - 1)])


## How many times the descent has already passed through all three regions
## (0 on depths 1-9). Each pass the Hollow is darker, and the regions bleed
## into each other: foes of the next region walk this one's halls.
static func cycle(depth: int) -> int:
	return maxi(0, (depth - 1) / 9)


## The region whose foes bleed into this depth ("" on the first pass).
static func bleed_region(depth: int) -> String:
	if cycle(depth) < 1:
		return ""
	return ORDER[(ORDER.find(region_for(depth)) + 1) % ORDER.size()]


## How much darker the Hollow is on this pass (ambient light multiplier).
static func gloom(depth: int) -> float:
	return maxf(0.55, 1.0 - 0.15 * cycle(depth))


## Which of its region's three floors a depth is (0..2).
static func floor_index(depth: int, delve: bool) -> int:
	return (depth - 1) % 3 if delve else clampi(depth - 1, 0, 2)


## A depth's own name and mood: [name, ambient tint].
static func floor_def(region: String, depth: int, delve: bool) -> Array:
	var fl: Array = EnemyDB.REGIONS.get(region, {}).get("floors", [])
	if fl.is_empty():
		return ["", Color(0, 0, 0, 0)]
	return fl[clampi(floor_index(depth, delve), 0, fl.size() - 1)]


## The words under a depth's title card - [line, extra line]: where the
## expedition stands ("Depth 2 of 3"), the guardian's floor, or the endless
## Hollow Below. Every machine of a party says the same.
static func depth_title(region: String, depth: int, delve: bool) -> Array:
	var nm := String(floor_def(region, depth, delve)[0])
	var pre := (nm + "  -  ") if nm != "" else ""
	var boss_name := String(EnemyDB.get_def(String(EnemyDB.REGIONS.get(region, {}).get("boss", ""))).get("name", "the guardian"))
	if delve:
		var bleed := bleed_region(depth)
		var also := ("  The %s's dead walk here too." % String(EnemyDB.REGIONS[bleed].name).trim_prefix("The ")) if bleed != "" else ""
		if fractured(depth):
			return ["The Fracture  -  Depth %d" % depth, "%s lies over this place. Close the rift." % String(EnemyDB.REGIONS[overlap_region(depth)].name)]
		if is_boss_depth(depth):
			return [pre + "Depth %d" % depth, "An Echo of %s waits here. The Hollow Below has no floor.%s" % [boss_name, also]]
		return [pre + "Depth %d" % depth, "No floor below. An Echo waits in %d.%s" % [3 - depth % 3, also]]
	var total := int(EnemyDB.REGIONS.get(region, {}).get("depths", 3))
	if depth >= total:
		return [pre + "Depth %d of %d  -  Guardian Depth" % [depth, total], "%s waits." % boss_name]
	return [pre + "Depth %d of %d" % [depth, total], ""]


## The HUD's short form: "Depth 1/3", "Guardian 3/3", "Hollow 7 (Echo in 2)".
static func depth_short(region: String, depth: int, delve: bool) -> String:
	if delve:
		return ("Hollow %d  Echo" % depth) if is_boss_depth(depth) else ("Hollow %d (Echo in %d)" % [depth, 3 - depth % 3])
	var total := int(EnemyDB.REGIONS.get(region, {}).get("depths", 3))
	return ("Guardian %d/%d" if depth >= total else "Depth %d/%d") % [depth, total]


static func best() -> int:
	return int(Profile.data.world.get("delve_best", 0))
