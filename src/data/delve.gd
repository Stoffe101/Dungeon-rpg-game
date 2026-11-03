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


static func best() -> int:
	return int(Profile.data.world.get("delve_best", 0))
