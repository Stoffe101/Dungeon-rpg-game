## Dev (`worldlab`, with region= and optionally showcol): every kind of thing a region's
## floor is made of, laid out in the start room, to look at with and without the
## collision overlay. Added to the floor's plan before anything is built.
class_name WorldLab
extends RefCounted

const ROWS := {
	"rootmire": {"solid": ["thicket:a", "thicket:b", "thicket:c", "glowcap", "dressing:mire_rock:a", "dressing:mire_rock:b"], "tall": "tree", "wide": "mire_log"},
	"ossuary": {"solid": ["dressing:statue", "brazier", "lore", "strut"], "tall": "", "wide": "sarcophagus"},
	"throne": {"solid": ["dressing:statue", "dressing:statue", "brazier", "strut"], "tall": "", "wide": "column_fallen"},
}


static func add(lay: DungeonGen.Layout) -> void:
	var r: Room = lay.rooms[0]
	var c := Vector2i(r.center())
	var set_of: Dictionary = ROWS.get(lay.region, ROWS.ossuary)
	r.props = r.props.filter(func(p): return p.kind in ["torch", "banner"])
	r.flora.clear()
	var g := lay.grid
	var clear := func(t: Vector2i) -> bool:
		return g.at(t.x, t.y) == TileGrid.FLOOR
	# back row: what stops you
	var x := -6
	for spec: String in set_of.solid:
		var t := c + Vector2i(x, -3)
		if clear.call(t):
			var bits := spec.split(":")
			var pd := {"kind": bits[0], "tile": t}
			if bits[0] == "dressing":
				pd["sheet"] = bits[1]
				if bits.size() > 2:
					pd["anim"] = bits[2]
			elif bits.size() > 1:
				pd["anim"] = bits[1]
			r.props.append(pd)
		x += 2
	if String(set_of.tall) != "":
		r.props.append({"kind": String(set_of.tall), "tile": c + Vector2i(7, -4), "anim": "a"})
	r.props.append({"kind": "dressing", "tile": c + Vector2i(-8, -1), "sheet": String(set_of.wide), "wide": true})
	# second row: what stops you until it is broken, and what you use
	for e in [["bramble", -5], ["bramble", -4], ["urn", -2], ["chest", 0], ["kindle_jar", 2], ["strut", 4], ["spring", 6]]:
		var t := c + Vector2i(int(e[1]), -1)
		if clear.call(t):
			var pd := {"kind": String(e[0]), "tile": t}
			if e[0] == "urn":
				pd["mat"] = "root"
			r.props.append(pd)
	# a line of spikes, staggered, and a vent
	for i in 5:
		r.props.append({"kind": "spikes", "tile": c + Vector2i(-7 + i, 2), "phase": i * 0.22})
	r.props.append({"kind": "rime_vent", "tile": c + Vector2i(1, 2)})
	# a walled gap one tile wide
	# what you walk through, one strip of each
	if lay.region == "rootmire":
		for row in 6:
			for k in 4:
				r.flora.append({"pos": Vector2(c + Vector2i(3 + row, 2 + (k % 2))) + Vector2(0.2 + 0.2 * k, 0.5), "row": row, "seed": k * 0.3, "flip": k % 2 == 0})
