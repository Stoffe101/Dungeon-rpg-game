## What a room is built as: once its walls are up, each larger room of a floor may be given
## a concept, a plan for its monuments and the patterns let into its floor, so that rooms
## are places rather than rectangles. Runs last over a finished floor on its own rng, so a
## seed's layout is otherwise what it was, and every machine builds the same thing.
##
## Everything that stands stops you (a `dressing` prop, as wide as its `span`, on floor
## that stays one piece); everything in the floor is walked over (`inlay`).
class_name RoomCraft
extends RefCounted

const OSSUARY := ["burial_aisle", "charnel", "mausoleum", "monuments"]
const THRONE := ["processional", "audience", "collapse", "foundry"]
## Each mood of the Hollow Below has its own standing things: [sheet, span].
const HOLLOW := {
	"whisper": {"stand": [["hollow_listener", 1], ["hollow_listener", 1], ["broken_obelisk", 1]], "floor": "inlay_ring"},
	"thin": {"stand": [["hollow_glass", 1], ["hollow_glass", 1], ["hollow_riftstone", 1]], "floor": ""},
	"crowded": {"stand": [["hollow_ribs", 2], ["bone_cairn", 2], ["charnel_bank", 2]], "floor": "inlay_tomb"},
	"roads": {"stand": [["hollow_milestone", 1], ["hollow_stair", 2], ["hollow_milestone", 1]], "floor": "inlay_road"},
	"teeth": {"stand": [["hollow_jaw", 2], ["hollow_jaw", 2], ["broken_obelisk", 1]], "floor": ""},
	"overgrown": {"stand": [["hollow_pale_cap", 1], ["hollow_pale_cap", 1], ["hollow_riftstone", 1]], "floor": ""},
}
## Dev: every room that can be is built as this.
static var force_concept := ""
## A door's lane is kept clear this far.
const DOOR_CLEAR := 4


static func compose(lay: DungeonGen.Layout, seed_v: int) -> void:
	var band := String(Delve.band(lay.depth).get("id", ""))
	for r: Room in lay.rooms:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, lay.depth, r.id, "craft"])
		_sills(lay, r, band)
		if not r.type in [Room.Type.COMBAT, Room.Type.ELITE, Room.Type.TREASURE, Room.Type.EVENT]:
			continue
		var forced := force_concept != ""
		if r.authored != "" or _floor_count(lay, r) < 60 or (rng.randf() > 0.8 and not forced):
			continue
		if forced and force_concept in OSSUARY + THRONE:
			r.concept = force_concept
			_build(lay, r, rng)
			continue
		if band != "" and (rng.randf() < 0.75 or forced):
			_hollow(lay, r, rng, band)
			r.concept = band
			continue
		match lay.region:
			"ossuary":
				r.concept = OSSUARY[rng.randi_range(0, OSSUARY.size() - 1)]
			"throne":
				r.concept = THRONE[rng.randi_range(0, THRONE.size() - 1)]
			_:
				continue
		_build(lay, r, rng)


static func _floor_count(lay: DungeonGen.Layout, r: Room) -> int:
	var n := 0
	for y in range(r.rect.position.y, r.rect.end.y):
		for x in range(r.rect.position.x, r.rect.end.x):
			if lay.grid.at(x, y) == TileGrid.FLOOR:
				n += 1
	return n


# --- laying things down ---------------------------------------------------------------

static func _near_door(r: Room, t: Vector2i, d := DOOR_CLEAR) -> bool:
	for door in r.doors:
		for dt: Vector2i in door.tiles:
			if absi(dt.x - t.x) < d and absi(dt.y - t.y) < d:
				return true
	return false


static func _taken(r: Room) -> Dictionary:
	var out := {}
	for p in r.props:
		if String(p.kind) in ["decal", "inlay", "torch", "banner"]:
			continue
		out[p.tile] = true
		for k in range(1, DungeonGen.span_of(p)):
			out[Vector2i(p.tile) + Vector2i(k, 0)] = true
	return out


## A monument on `t` (and the tiles east of it), if it fits and leaves the floor whole.
static func stand(lay: DungeonGen.Layout, r: Room, sheet: String, t: Vector2i, span := 1) -> bool:
	var want: Array[Vector2i] = []
	var taken := _taken(r)
	for k in span:
		var c := t + Vector2i(k, 0)
		if lay.grid.at(c.x, c.y) != TileGrid.FLOOR or taken.has(c) or _near_door(r, c) or not r.rect.has_point(c):
			return false
		want.append(c)
	if not DungeonGen._floor_whole(lay, r, want):
		return false
	var pd := {"kind": "dressing", "tile": t, "sheet": sheet}
	if span > 1:
		pd["span"] = span
	r.props.append(pd)
	return true


## An inlay across `w` x `h` tiles whose top-left is `t`: only on whole floor.
static func inlay(lay: DungeonGen.Layout, r: Room, sheet: String, anim: String, t: Vector2i, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if lay.grid.at(t.x + x, t.y + y) != TileGrid.FLOOR:
				return false
	r.props.append({"kind": "inlay", "tile": t, "sheet": sheet, "anim": anim, "ox": (w - 1) * 0.5, "oy": (h - 1) * 0.5})
	return true


static func _along_x(r: Room) -> bool:
	var ew := 0
	var ns := 0
	for d in r.doors:
		if Vector2i(d.dir).x != 0:
			ew += 1
		else:
			ns += 1
	return ew >= ns


## The floor pattern down the room's axis, in lengths of `len_t` tiles.
static func _axis(lay: DungeonGen.Layout, r: Room, sheet: String, anims: Array, len_t: int, wid_t: int, rng: RandomNumberGenerator) -> void:
	var c := Vector2i(r.rect.get_center())
	# (one run: only its far end is worn through; a torn piece in the middle reads as a pattern)
	var whole := String(anims[0])
	var last := String(anims[anims.size() - 1])
	if _along_x(r):
		var y := c.y - wid_t / 2
		var x := r.rect.position.x
		while x + len_t <= r.rect.end.x:
			inlay(lay, r, sheet, last if x + len_t * 2 > r.rect.end.x and rng.randf() < 0.7 else whole, Vector2i(x, y), len_t, wid_t)
			x += len_t
	else:
		var x := c.x - wid_t / 2
		var y := r.rect.position.y
		while y + len_t <= r.rect.end.y:
			inlay(lay, r, sheet + "_v", last if y + len_t * 2 > r.rect.end.y and rng.randf() < 0.7 else whole, Vector2i(x, y), wid_t, len_t)
			y += len_t


## The room's back row, `n` evenly spaced columns of it.
static func _back_row(r: Room, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in n:
		out.append(Vector2i(r.rect.position.x + (r.rect.size.x * (k + 1)) / (n + 1) - 1, r.rect.position.y))
	return out


# --- the concepts ------------------------------------------------------------------------

static func _build(lay: DungeonGen.Layout, r: Room, rng: RandomNumberGenerator) -> void:
	var c := Vector2i(r.rect.get_center())
	var w := r.rect.size.x
	var h := r.rect.size.y
	match r.concept:
		"burial_aisle":
			_axis(lay, r, "inlay_aisle", ["whole", "broken"], 3, 1, rng)
			for k in range(-int(w / 4), int(w / 4) + 1):
				var x: int = c.x + k * 4
				for y: int in [c.y - 3, c.y + 2]:
					inlay(lay, r, "inlay_tomb", ["figure", "skull", "open"][rng.randi_range(0, 2)], Vector2i(x, y), 2, 1)
			stand(lay, r, "tomb_effigy", Vector2i(c.x - 1, r.rect.position.y), 2)
		"charnel":
			for t: Vector2i in _back_row(r, 3):
				stand(lay, r, "charnel_bank", t, 2)
			for k in 2:
				stand(lay, r, "bone_heap", c + Vector2i(rng.randi_range(-7, 7), rng.randi_range(0, 3)))
			inlay(lay, r, "inlay_tomb", "open", c + Vector2i(-3, 2), 2, 1)
			inlay(lay, r, "inlay_tomb", "figure", c + Vector2i(2, 2), 2, 1)
		"mausoleum":
			inlay(lay, r, "inlay_ring", "idle", c - Vector2i(1, 1), 3, 3)
			if stand(lay, r, "tomb_effigy", c - Vector2i(1, 0), 2):
				for d: Vector2i in [Vector2i(-3, -2), Vector2i(2, -2), Vector2i(-3, 2), Vector2i(2, 2)]:
					if lay.grid.at(c.x + d.x, c.y + d.y) == TileGrid.FLOOR:
						r.props.append({"kind": "candles", "tile": c + d})
			inlay(lay, r, "inlay_tomb", "skull", Vector2i(c.x - w / 3, c.y - 3), 2, 1)
			inlay(lay, r, "inlay_tomb", "figure", Vector2i(c.x + w / 3 - 1, c.y + 2), 2, 1)
		"monuments":
			for p: Vector2i in [Vector2i(r.rect.position.x + w / 4, r.rect.position.y + 2), Vector2i(r.rect.end.x - w / 4, r.rect.position.y + 2), Vector2i(r.rect.position.x + w / 4, r.rect.end.y - 3)]:
				stand(lay, r, "broken_obelisk", p)
			stand(lay, r, "bone_cairn", Vector2i(r.rect.end.x - w / 4 - 1, r.rect.end.y - 3), 2)
			for k in 3:
				inlay(lay, r, "inlay_tomb", ["figure", "skull"][k % 2], c + Vector2i(rng.randi_range(-6, 5), rng.randi_range(-2, 2)), 2, 1)
		"processional":
			_axis(lay, r, "inlay_carpet", ["whole", "whole", "torn"], 3, 2, rng)
			if h >= 8:
				inlay(lay, r, "inlay_sun", "idle", c - Vector2i(2, 2), 4, 4)
			for t: Vector2i in [c + Vector2i(-w / 4, -3), c + Vector2i(w / 4, -3), c + Vector2i(-w / 4, 3), c + Vector2i(w / 4, 3)]:
				if lay.grid.at(t.x, t.y) == TileGrid.FLOOR and not _near_door(r, t) and DungeonGen._floor_whole(lay, r, [t] as Array[Vector2i]):
					r.props.append({"kind": "brazier", "tile": t})
		"audience":
			var seat := Vector2i(c.x - 1, r.rect.position.y)
			if stand(lay, r, "broken_throne", seat, 3):
				var y := seat.y + 1
				while y + 3 <= r.rect.end.y and y < seat.y + 10:
					inlay(lay, r, "inlay_carpet_v", ["whole", "torn"][int(y > seat.y + 6)], Vector2i(c.x - 1, y), 2, 3)
					y += 3
				for x: int in [c.x - 5, c.x + 5]:
					var t := Vector2i(x, seat.y + 1)
					if lay.grid.at(t.x, t.y) == TileGrid.FLOOR and not _near_door(r, t) and DungeonGen._floor_whole(lay, r, [t] as Array[Vector2i]):
						r.props.append({"kind": "brazier", "tile": t})
		"collapse":
			stand(lay, r, "colossus_head", Vector2i(r.rect.position.x + 2, r.rect.position.y + 1), 3)
			stand(lay, r, "fallen_vault", Vector2i(r.rect.end.x - 5, r.rect.position.y + 1), 2)
			stand(lay, r, "colossus_foot", Vector2i(r.rect.end.x - 6, r.rect.end.y - 3), 2)
			if h >= 8:
				inlay(lay, r, "inlay_sun", "idle", c - Vector2i(2, 2), 4, 4)
		"foundry":
			for t: Vector2i in _back_row(r, 2):
				stand(lay, r, "chain_winch", t, 2)
			_axis(lay, r, "inlay_carpet", ["whole", "torn"], 3, 2, rng)


static func _hollow(lay: DungeonGen.Layout, r: Room, rng: RandomNumberGenerator, band: String) -> void:
	var spec: Dictionary = HOLLOW[band]
	var stands: Array = spec.stand
	var c := Vector2i(r.rect.get_center())
	var w := r.rect.size.x
	var spots: Array[Vector2i] = [
		Vector2i(r.rect.position.x + w / 4, r.rect.position.y + 1),
		Vector2i(r.rect.end.x - w / 4 - 1, r.rect.position.y + 1),
		Vector2i(r.rect.position.x + w / 4, r.rect.end.y - 3),
		Vector2i(r.rect.end.x - w / 4 - 1, r.rect.end.y - 3),
		c + Vector2i(0, -2),
	]
	for k in rng.randi_range(2, spots.size()):
		var s: Array = stands[rng.randi_range(0, stands.size() - 1)]
		stand(lay, r, String(s[0]), spots[k], int(s[1]))
	match String(spec.floor):
		"inlay_ring":
			inlay(lay, r, "inlay_ring", "idle", c - Vector2i(1, 1), 3, 3)
		"inlay_tomb":
			for k in 4:
				inlay(lay, r, "inlay_tomb", "open", c + Vector2i(rng.randi_range(-7, 6), rng.randi_range(-3, 3)), 2, 1)
		"inlay_road":
			_axis(lay, r, "inlay_road", ["whole", "marked"], 3, 1, rng)


# --- where a way begins and ends ----------------------------------------------------------

static func _sills(lay: DungeonGen.Layout, r: Room, band: String) -> void:
	var style: String = "hollow" if band != "" else lay.region
	for d in r.doors:
		if d.secret:
			continue
		var tiles: Array = d.tiles
		var lo: Vector2i = tiles[0]
		for t: Vector2i in tiles:
			lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		var dir: Vector2i = d.dir
		if dir.x != 0:
			r.props.append({"kind": "inlay", "tile": lo, "sheet": "inlay_sill_v", "anim": style, "ox": 0.0, "oy": (tiles.size() - 1) * 0.5})
		else:
			r.props.append({"kind": "inlay", "tile": lo, "sheet": "inlay_sill", "anim": style, "ox": (tiles.size() - 1) * 0.5, "oy": 0.0})
		if dir == Vector2i(0, -1):
			# a door in the back wall has a frame: posts either side of the gap
			var wall_y: int = r.rect.position.y - 1
			var hi: int = lo.x + tiles.size() - 1
			for x: int in [lo.x - 1, hi + 1]:
				if lay.grid.at(x, wall_y) == TileGrid.WALL:
					r.props.append({"kind": "jamb", "tile": Vector2i(x, wall_y), "anim": style})
