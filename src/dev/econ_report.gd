## Dev (`econreport`): what everything in the game costs, added up, and which currencies
## are ever asked for. The income side comes from `econrun` expeditions (Game.end_run prints
## an [econ] line); tools/dev/econ_compare.py sets the two side by side.
class_name EconReport
extends RefCounted


static func _add(into: Dictionary, cost: Dictionary, times := 1) -> void:
	for k in cost:
		into[k] = int(into.get(k, 0)) + int(cost[k]) * times


static func run() -> void:
	var out := {}
	# the forge: one archetype to its top
	var forge := {}
	for lvl in GearDB.FORGE_MAX:
		var c := {"embers": GearDB.FORGE_COSTS[lvl]}
		c.merge(GearDB.FORGE_MATERIALS[lvl])
		if lvl == 2 or lvl == 6 or lvl == 9:
			c["sunshards"] = 1 if lvl == 2 else 2
		_add(forge, c)
	out["forge_one_weapon"] = forge
	# the sanctuary, whole
	var sanct := {}
	for id in Profile.SANCTUARY:
		for c: Dictionary in Profile.SANCTUARY[id].costs:
			_add(sanct, c)
	out["sanctuary_all"] = sanct
	# every recipe, once
	var craft := {}
	var uniques := 0
	for id in ItemDB.BASES:
		var b: Dictionary = ItemDB.BASES[id]
		if b.has("recipe"):
			_add(craft, b.recipe)
			if b.get("unique", false):
				uniques += 1
	out["craft_every_recipe"] = craft
	out["craftable_uniques"] = uniques
	# who asks for what
	var asked := {}
	for k in ItemDB.MATERIALS:
		asked[k] = int(forge.get(k, 0)) + int(sanct.get(k, 0)) + int(craft.get(k, 0))
	out["material_total_demand"] = asked
	print("[econ-costs] ", JSON.stringify(out))
