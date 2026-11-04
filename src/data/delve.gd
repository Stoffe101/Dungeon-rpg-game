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


static func unlocked() -> bool:
	return int(Profile.data.world.get("ashen_king_kills", 0)) >= 1


static func region_for(depth: int) -> String:
	return ORDER[int((depth - 1) / 3) % ORDER.size()]


static func is_boss_depth(depth: int) -> bool:
	return depth % 3 == 0


## How many Echoes of a guardian the Kindled has met by this depth (1 at depth 3).
static func echo_n(depth: int) -> int:
	return maxi(1, depth / 3)


## One more Omen, read when the party goes deeper (none left: none).
static func next_omen(rng: RandomNumberGenerator, active: Array) -> String:
	var pool: Array = Omens.OMENS.keys().filter(func(o): return not active.has(o) and Omens.unlocked(String(o)))
	if pool.is_empty():
		return ""
	return String(pool[rng.randi_range(0, pool.size() - 1)])


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
		if is_boss_depth(depth):
			return [pre + "Depth %d" % depth, "An Echo of %s waits here. The Hollow Below has no floor." % boss_name]
		return [pre + "Depth %d" % depth, "No floor below. An Echo waits in %d." % (3 - depth % 3)]
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
