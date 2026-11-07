## Guardians come back different. Once a region's guardian has fallen, the same
## arena sometimes holds a rarer form of it: not more health, a fight with
## another shape (Enemy.take_form + each guardian's own `begin_form`). Chosen from
## the expedition's seed and the world the run carries, so every machine agrees,
## and paid for with a richer hoard (Dungeon._guardian_hoard).
class_name Guardians
extends RefCounted

const FORMS := {
	"warden": {"id": "lightless", "name": "The Lightless Warden", "sub": "It has walked here without a lantern for a very long time",
		"hp": 1.1, "tint": Color(0.68, 0.6, 1.0), "col": Color(0.72, 0.5, 1.0)},
	"bloom": {"id": "rootbound", "name": "The Rootbound Bloom", "sub": "Every root is a way in. Burn them and it has nowhere to go",
		"hp": 1.0, "tint": Color(0.85, 1.0, 0.62), "col": Color(0.65, 1.0, 0.45)},
	"ashen_king": {"id": "eclipsed", "name": "The Eclipsed King", "sub": "His sun went out at the first blow",
		"hp": 0.95, "tint": Color(0.78, 0.66, 1.0), "col": Color(0.75, 0.5, 1.0)},
}
## Dev (`form=lightless`): this form whenever its guardian appears.
static var force := ""


static func def_of(form: String) -> Dictionary:
	for k in FORMS:
		if String(FORMS[k].id) == form:
			return FORMS[k]
	return {}


## The form this expedition's guardian takes ("" = as it always was). Never on the
## first meeting: a region's guardian is learned before it is changed.
static func form_of(boss_id: String, region: String, seed_v: int, depth: int, world: Dictionary) -> String:
	var f: Dictionary = FORMS.get(boss_id, {})
	if f.is_empty():
		return ""
	if force != "":
		return String(f.id) if force == String(f.id) else ""
	var felled := int((world.get("felled", {}) as Dictionary).get(region, 0))
	if felled <= 0:
		return ""
	var chance := mini(60, 30 + 5 * felled)
	return String(f.id) if posmod(hash([seed_v, depth, "form"]), 100) < chance else ""
