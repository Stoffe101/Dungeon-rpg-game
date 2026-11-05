## The Ember Apothecary's tinctures: what the flask is steeped with. One at a
## time, chosen at the Apothecary and kept between expeditions (no brewing
## chore before every descent). Each changes what a drink *does*, not just how
## much it heals - a decision about the build and the fights ahead.
##
## A tincture is learned from its reagent, found below (each region's elites
## carry its own; guardians, chests and the Undervault's stranger rooms the
## rest). Every further reagent of the kind distils it a rank higher (up to 2,
## or 3 once the Apothecary is fully restored). Hearthbalm needs no reagent.
class_name Tinctures
extends RefCounted

const MAX_RANK := 3

const REAGENTS := {
	"grave_salt": {"name": "Grave Salt", "teaches": "salt", "color": Color(0.82, 0.86, 0.95), "icon": "bone_dust",
		"where": "Ossuary elites", "desc": "Salt from the Ossuary's burial niches. It keeps rot, fire and frost from taking hold."},
	"kindleroot": {"name": "Kindleroot", "teaches": "kindleroot", "color": Color(1.0, 0.62, 0.3), "icon": "rootwood",
		"where": "Rootmire elites", "desc": "A root that drinks lantern-light. Steeped, it gives it back."},
	"sunwater": {"name": "Sunwater", "teaches": "sunwater", "color": Color(1.0, 0.86, 0.45), "icon": "sun_gold",
		"where": "Sunken Throne elites", "desc": "Water from the drowned halls, still warm from a sun that died."},
	"wardmoth_milk": {"name": "Wardmoth Milk", "teaches": "wardmilk", "color": Color(0.85, 0.9, 1.0), "icon": "soul_glass",
		"where": "chests and vaults", "desc": "What the pale moths leave on old wards. It hardens on the skin."},
	"ashen_marrow": {"name": "Ashen Marrow", "teaches": "last_ember", "color": Color(1.0, 0.45, 0.35), "icon": "ember_core",
		"where": "guardians", "desc": "From the bones of something that would not die. It burns brightest at the end."},
	"gloamcap": {"name": "Gloamcap", "teaches": "gloamwater", "color": Color(0.7, 0.5, 1.0), "icon": "spore_silk",
		"where": "hidden and forgotten rooms", "desc": "A cold violet cap that grows only where nobody has walked in a long time."},
}

## heal: multiplier on the flask's healing at ranks 1..3. The rest is read by
## Player._drink (host side).
const TINCTURES := {
	"hearthbalm": {"name": "Hearthbalm", "reagent": "", "color": Color(1.0, 0.78, 0.45), "heal": [1.1, 1.2, 1.3],
		"desc": "The plain draught, made well: heals {heal} as much."},
	"kindleroot": {"name": "Kindleroot Draught", "reagent": "kindleroot", "color": Color(1.0, 0.62, 0.3), "heal": [0.55, 0.65, 0.75],
		"desc": "Heals {heal} as much, but fills your Kindle to the brim - for spell builds that live on their spells."},
	"wardmilk": {"name": "Wardmilk", "reagent": "wardmoth_milk", "color": Color(0.85, 0.9, 1.0), "heal": [0.8, 0.85, 0.9], "barrier": [0.2, 0.28, 0.36],
		"desc": "Heals {heal} as much, then a barrier of {barrier} of your health for 5s: drink before the blow, not after."},
	"sunwater": {"name": "Sunwater Tonic", "reagent": "sunwater", "color": Color(1.0, 0.86, 0.45), "heal": [0.7, 0.75, 0.8], "haste": [4.0, 5.0, 6.0],
		"desc": "Heals {heal} as much; you run faster for {haste} and your dodges are back at once - to get out, or get in."},
	"salt": {"name": "Grave-salt Tincture", "reagent": "grave_salt", "color": Color(0.82, 0.86, 0.95), "heal": [0.9, 1.0, 1.0], "ward": [3.0, 4.0, 5.0],
		"desc": "Heals {heal} as much and washes off burning, chill and every other affliction; none takes hold for {ward}."},
	"last_ember": {"name": "Last Ember", "reagent": "ashen_marrow", "color": Color(1.0, 0.45, 0.35), "heal": [0.5, 0.5, 0.5], "low": [2.0, 2.3, 2.6],
		"desc": "Below a third of your health it heals {low} as much; above, only {heal}. A gamble on the edge."},
	"gloamwater": {"name": "Gloamwater", "reagent": "gloamcap", "color": Color(0.7, 0.5, 1.0), "heal": [0.85, 0.9, 0.95], "chill": [6.0, 7.0, 8.0],
		"desc": "Heals {heal} as much; for {chill} every blow you land chills (enough of them freeze)."},
}


static func get_def(id: String) -> Dictionary:
	return TINCTURES.get(id, TINCTURES.hearthbalm)


static func reagent(id: String) -> Dictionary:
	return REAGENTS.get(id, {})


## The tincture a reagent teaches.
static func taught_by(reagent_id: String) -> String:
	return String(REAGENTS.get(reagent_id, {}).get("teaches", ""))


## A rank's value of a ranked field (1-based rank, clamped).
static func at(id: String, field: String, rank: int) -> float:
	var a: Array = get_def(id).get(field, [1.0])
	return float(a[clampi(rank, 1, a.size()) - 1])


## The tincture's line with this rank's numbers.
static func describe(id: String, rank: int) -> String:
	var d := get_def(id)
	var s := String(d.desc)
	for f in ["heal", "low", "barrier"]:
		if d.has(f):
			s = s.replace("{%s}" % f, "%d%%" % int(round(at(id, f, rank) * 100.0)))
	for f in ["haste", "ward", "chill"]:
		if d.has(f):
			s = s.replace("{%s}" % f, "%ds" % int(at(id, f, rank)))
	return s


## The reagent each region's elites carry.
static func region_reagent(region: String) -> String:
	return {"rootmire": "kindleroot", "throne": "sunwater"}.get(region, "grave_salt")
