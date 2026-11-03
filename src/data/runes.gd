## Ember Runes: stones set into an ability's sockets that change how it
## behaves. One rune reads differently in each spell (a Splitting Lance fans
## out, a Splitting Flare erupts in three places), so the same few runes make
## many builds. Abilities get one socket, a second at level 20.
class_name Runes
extends RefCounted

const SECOND_SOCKET_LEVEL := 20

## id -> name, colour, short, and the line for each ability where it differs
const RUNES := {
	"split": {"name": "Rune of Many", "color": Color(1.0, 0.82, 0.4), "icon": "rune_split",
		"desc": "The spell divides into several weaker ones.",
		"per": {"flare": "Also erupts at three points around you (half strength).", "cinder_lance": "Three lances in a fan (70% each).",
			"frost_sigil": "A second sigil, mirrored around you (smaller).", "gloamstep": "Leaves three shades along your path.",
			"aegis": "Shares half its ward with allies near you; alone, it holds 30% more.", "wisp": "Two wisps (60% damage each).",
			"knives": "Three more knives in the fan.", "lantern": "Two lanterns side by side (60% each).",
			"rush": "Three afterimages rush beside you, cutting their own paths.", "rekindle": "A second, smaller pulse where you will stand in a moment."}},
	"chain": {"name": "Rune of Arcing", "color": Color(0.55, 0.85, 1.0), "icon": "rune_chain",
		"desc": "Each hit arcs to up to two more foes nearby for half its damage."},
	"echo": {"name": "Rune of Echoes", "color": Color(0.45, 1.0, 0.85), "icon": "rune_echo",
		"desc": "The spell happens again a moment later, weaker.",
		"per": {"flare": "A second flare where you cast it (60%).", "cinder_lance": "The lance flies again from where you threw it (60%).",
			"frost_sigil": "Two more pulses.", "gloamstep": "After 2 s you snap back to where you left - and the shade there bursts.",
			"aegis": "When the ward breaks it forms once more, at half strength.", "wisp": "A second wisp follows six seconds later.",
			"knives": "A second volley a moment later (60%).", "lantern": "When it gutters out it flares once more (a burst of embers).",
			"rush": "The trail you leave bursts into flame a moment later.", "rekindle": "Pulses again after 3 s (half the ward)."}},
	"rime": {"name": "Rune of Rime", "color": Color(0.7, 0.9, 1.0), "icon": "rune_rime",
		"desc": "The spell turns to frost: it chills instead of burning, and hits frozen foes 50% harder."},
	"gloam": {"name": "Rune of Gloam", "color": Color(0.75, 0.5, 1.0), "icon": "rune_gloam",
		"desc": "The spell turns to shadow: it leaves foes Exposed (taking more damage) instead of burning."},
	"volatile": {"name": "Rune of Ruin", "color": Color(1.0, 0.5, 0.25), "icon": "rune_volatile",
		"desc": "Foes it kills burst, hurting those near them."},
	"siphon": {"name": "Rune of Kindling", "color": Color(1.0, 0.45, 0.45), "icon": "rune_siphon",
		"desc": "Each foe it hits gives back 4 Kindle and a little health."},
	"gravity": {"name": "Rune of the Well", "color": Color(0.5, 0.95, 0.9), "icon": "rune_gravity",
		"desc": "The spell draws foes in instead of throwing them back.",
		"per": {"cinder_lance": "Foes it pierces are dragged toward you.", "aegis": "When the ward breaks it pulls foes in and staggers them.",
			"wisp": "Its bolts tug foes toward it.", "knives": "The knives turn back at the end of their flight and cut again on the way home.",
			"lantern": "Its light slowly draws foes toward it.", "rush": "Foes you pass are dragged along the trail with you.",
			"rekindle": "Foes near you are pulled into the light and staggered."}},
	"haste": {"name": "Rune of Haste", "color": Color(1.0, 0.9, 0.5), "icon": "rune_haste",
		"desc": "40% shorter cooldown, 20% less damage."},
	"might": {"name": "Rune of Might", "color": Color(1.0, 0.4, 0.35), "icon": "rune_might",
		"desc": "50% more damage and 25% more area, at 40% more Kindle."},
}

## What carving a rune at the smithy costs (a sure path, beside lucky drops).
const CARVE := {"embers": 120, "soul_glass": 3, "ember_core": 1}


static func get_def(id: String) -> Dictionary:
	return RUNES.get(id, {})


static func describe(id: String, ability: String) -> String:
	var d := get_def(id)
	return String(d.get("per", {}).get(ability, d.get("desc", "")))


static func sockets(level: int) -> int:
	return 2 if level >= SECOND_SOCKET_LEVEL else 1


## The runes set in `ability` for this Kindled (their own profile or their sheet).
static func of(pl: Player, ability: String) -> Array:
	if pl == null:
		return []
	var socketed: Dictionary = pl.sheet.get("runes", {}) if not pl.sheet.is_empty() else Profile.runes().get("socketed", {})
	return socketed.get(ability, [])


## How many runes are set across all of this Kindled's spells.
static func total(pl: Player) -> int:
	var socketed: Dictionary = pl.sheet.get("runes", {}) if not pl.sheet.is_empty() else Profile.runes().get("socketed", {})
	var n := 0
	for ab in socketed:
		for r in socketed[ab]:
			if String(r) != "":
				n += 1
	return n


static func has(pl: Player, ability: String, rune: String) -> bool:
	return of(pl, ability).has(rune)


static func damage_mult(pl: Player, ability: String) -> float:
	var r := of(pl, ability)
	return (1.5 if r.has("might") else 1.0) * (0.8 if r.has("haste") else 1.0)


static func area_mult(pl: Player, ability: String) -> float:
	return 1.25 if has(pl, ability, "might") else 1.0


static func cost_mult(pl: Player, ability: String) -> float:
	return 1.4 if has(pl, ability, "might") else 1.0


static func cooldown_mult(pl: Player, ability: String) -> float:
	return 0.6 if has(pl, ability, "haste") else 1.0


## The colour a spell is drawn in, once an element rune has turned it.
static func tint(pl: Player, ability: String, base: Color) -> Color:
	var r := of(pl, ability)
	if r.has("rime"):
		return Color(0.65, 0.88, 1.0)
	if r.has("gloam"):
		return Color(0.7, 0.45, 0.95)
	return base
