## Omens: signs the Kindled may choose to read at the Descent. Each makes the
## expedition harder in one particular way and pays for it; they stack, and so
## do their rewards (banked at the end of the run, death included).
class_name Omens
extends RefCounted

const COLOR := Color(0.72, 0.55, 1.0)

const OMENS := {
	"lightless": {
		"name": "Lightless", "embers": 0.3, "xp": 0.0,
		"cost": "Every torch, candle and brazier is out. Your lantern is the only light.",
		"unlock": {"warden_kills": 1},
	},
	"restless": {
		"name": "Restless Dead", "embers": 0.0, "xp": 0.3,
		"cost": "A third of the fallen get up once more.",
		"unlock": {"warden_kills": 1},
	},
	"glass": {
		"name": "Glass Kindled", "embers": 0.2, "xp": 0.2,
		"cost": "You deal 35% more damage - and take 60% more.",
		"unlock": {"warden_kills": 1},
	},
	"tempered": {
		"name": "Tempered", "embers": 0.25, "xp": 0.1,
		"cost": "One foe in every fight is an elite.",
		"unlock": {"bloom_kills": 1},
	},
	"dry_flask": {
		"name": "Dry Flask", "embers": 0.25, "xp": 0.0,
		"cost": "Your flask holds one charge fewer.",
		"unlock": {"bloom_kills": 1},
	},
	"hunted": {
		"name": "Hunted", "embers": 0.0, "xp": 0.15,
		"cost": "Your Grudges hunt you: one waits on every depth. Settled, they pay double.",
		"unlock": {"warden_kills": 1, "deaths": 1},
	},
}


static func get_def(id: String) -> Dictionary:
	return OMENS.get(id, {})


static func unlocked(id: String) -> bool:
	var req: Dictionary = OMENS.get(id, {}).get("unlock", {})
	for k in req:
		var have := int(Profile.data.world.get(k, 0)) if k != "deaths" else int(Profile.data.stats.get("deaths", 0))
		if have < int(req[k]):
			return false
	return true


## The Descent is where Omens first appear: after the first guardian falls.
static func any_unlocked() -> bool:
	for id in OMENS:
		if unlocked(id):
			return true
	return false


static func what_unlocks(id: String) -> String:
	var req: Dictionary = OMENS.get(id, {}).get("unlock", {})
	if req.has("bloom_kills"):
		return "Fell the Hollow Bloom to read this sign."
	if req.has("deaths"):
		return "Only one who has died down there can read this sign."
	return "Fell the Gloam Warden to read this sign."


static func bonus(ids: Array, key: String) -> float:
	var b := 0.0
	for id in ids:
		b += float(OMENS.get(id, {}).get(key, 0.0))
	return b


## Player-side effects, applied when the Kindled's stats are built.
static func apply(ids: Array, stats: Stats) -> void:
	if ids.has("glass"):
		stats.add_mod("damage_more", "more", 0.35)
		stats.add_mod("damage_taken", "more", 0.6)
	if ids.has("dry_flask"):
		stats.add_mod("flask_charges", "add", -1.0)


static func names(ids: Array) -> String:
	return ", ".join(PackedStringArray(ids.map(func(i): return String(OMENS.get(i, {}).get("name", i)))))
