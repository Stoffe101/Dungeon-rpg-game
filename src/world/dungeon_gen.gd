## Procedural dungeon floor generator (pure, deterministic for a given seed).
##
## Rooms live on a coarse cell grid. A main path runs from the start to the exit
## (stairs or the boss); side branches end in special rooms; some combat rooms
## merge into larger halls; extra doors create loops; a hidden chamber may sit
## behind a cracked wall. Room interiors are composed from authored "stamps"
## (pillars, pits, alcoves, cut corners, ...) and validated with a flood fill so
## every door is always reachable.
class_name DungeonGen
extends RefCounted

const CELL_W := 24
const CELL_H := 16
const FX0 := 1
const FW := 22
const FY0 := 2
const FH := 12
const MARGIN := 3
const DOOR_COLS := [9, 12]
const DOOR_ROWS := [4, 7]
## Set dressing drawn about two tiles wide (centred between two tiles, both solid).
const WIDE_DRESSING := ["sarcophagus", "stump", "column_fallen"]
## ...and dressing low enough to walk through (bones underfoot).
const WALKABLE_DRESSING := ["bone_heap"]
const GW := 7
const GH := 6
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Hand-made rooms (22x12, a single cell), mixed into the procedural ones:
## . floor, # wall, o pillar, ~ pit, space void. Doors are kept clear after.
const AUTHORED := {
	"ossuary_chapel": [
		"......................",
		".o..o..o......o..o..o.",
		"......................",
		"......####..####......",
		"......#........#......",
		".........~~~~.........",
		".........~~~~.........",
		"......#........#......",
		"......####..####......",
		"......................",
		".o..o..o......o..o..o.",
		"......................",
	],
	"ossuary_ossuary": [
		"......................",
		"..##....##....##....##",
		"......................",
		"..o................o..",
		"......~~~....~~~......",
		"......~~~....~~~......",
		"......................",
		"..o................o..",
		"......................",
		"##....##....##....##..",
		"......................",
		"......................",
	],
	"root_hollow": [
		"  ..................  ",
		" .....##......##..... ",
		".....##..~~~~..##.....",
		"....##..~~~~~~..##....",
		"......................",
		"..o......~~.......o...",
		"......................",
		"....##..~~~~~~..##....",
		".....##..~~~~..##.....",
		" .....##......##..... ",
		"  ..................  ",
		"......................",
	],
	"root_tangle": [
		"......................",
		"...##.......##........",
		"....##.....##...o.....",
		".....##...##..........",
		"......................",
		".o.......~~~......o...",
		".........~~~..........",
		"......................",
		"..........##...##.....",
		"....o....##.....##....",
		".........#.......#....",
		"......................",
	],
	"throne_colonnade": [
		"......................",
		"..o...o...o...o...o...",
		"......................",
		"......................",
		"..~~~~..........~~~~..",
		"..~~~~...####...~~~~..",
		"..~~~~...####...~~~~..",
		"......................",
		"......................",
		"..o...o...o...o...o...",
		"......................",
		"......................",
	],
	"throne_court": [
		"......................",
		".~~..............~~...",
		".~~...o......o...~~...",
		"......................",
		".......########.......",
		"......................",
		"......................",
		".......########.......",
		"......................",
		".~~...o......o...~~...",
		".~~..............~~...",
		"......................",
	],
}
const AUTHORED_BY_REGION := {"ossuary": ["ossuary_chapel", "ossuary_ossuary"], "rootmire": ["root_hollow", "root_tangle"],
	"throne": ["throne_colonnade", "throne_court"]}



## The Forked Descent: every stairs room below a guardian's floor offers two
## of three ways down, each shaping the next floor. None is simply better:
## harder for more, more to find for less fighting, safer for less.
##   path / branches: rooms added to the main path / side branches
##   foes: the encounter budget; embers: room-clear and enemy Embers
const ROUTES := {
	"trial": {"name": "Trial of Ash", "short": "Ash", "act": "harder fights, richer spoils", "color": Color(1.0, 0.42, 0.25), "path": 1, "branches": 0, "foes": 1.25, "embers": 1.4,
		"line": "Harder fights and two elites; a hall warded by seals. Richer spoils."},
	"vault": {"name": "The Lost Vault", "short": "Vault", "act": "fewer fights, more to find", "color": Color(1.0, 0.8, 0.4), "path": -1, "branches": 2, "foes": 1.0, "embers": 1.0,
		"line": "Fewer fights, more side rooms - and a vault whose flame you must keep lit."},
	"quiet": {"name": "Silent Passage", "short": "Silent", "act": "safer, leaner", "color": Color(0.45, 0.9, 0.85), "path": 0, "branches": 0, "foes": 0.7, "embers": 0.7,
		"line": "Fewer, weaker foes, no elite, a spring of vigor. Lean spoils."},
}
static var _route := ""          # (set by generate while a floor is built)
static var _offer: Array = []


## The two ways down this floor's stairs offer (by the seed: everyone in a
## party sees the same two, and a floor offers the same two again).
static func route_offer(seed_v: int, depth: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, depth, "fork"])
	var ids: Array = ROUTES.keys()
	_shuffle(ids, rng)
	return ids.slice(0, 2)


static func route_def(id: String) -> Dictionary:
	return ROUTES.get(id, {})


class Layout:
	var seed := 0
	var depth := 1
	var region := "ossuary"
	var boss_depth := false
	var route := ""               # the way this floor was reached (ROUTES), "" the plain way
	var offer: Array = []         # the ways down its stairs offer
	var grid: TileGrid
	var rooms: Array[Room] = []
	var start_id := 0
	var exit_id := 0
	var cell_owner := {}

	func room(i: int) -> Room:
		return rooms[i] if i >= 0 and i < rooms.size() else null

	func room_at_tile(t: Vector2i) -> Room:
		var rid := grid.room_at(t.x, t.y)
		return room(rid)

	func room_at_point(p: Vector2) -> Room:
		return room_at_tile(Vector2i(floori(p.x), floori(p.y)))


static func generate(seed_v: int, depth: int, region: String, boss_depth: bool, route := "") -> Layout:
	_route = route if ROUTES.has(route) else ""
	# a guardian's floor has one way on; every other offers two
	_offer = [] if boss_depth else route_offer(seed_v, depth)
	for attempt in 60:
		var rng := RandomNumberGenerator.new()
		# (the plain way keeps every seed's floor as it always was)
		rng.seed = hash([seed_v, depth, attempt]) if _route == "" else hash([seed_v, depth, attempt, _route])
		var lay := _try_generate(rng, depth, region, boss_depth)
		if lay != null:
			lay.seed = seed_v
			_landmark(lay, seed_v)
			_route = ""
			return lay
	push_error("DungeonGen: failed to generate a layout")
	return null


## Each region's landmark: one great centrepiece that tells something of the
## place and does something once you reach it (Dungeon.request "landmark").
const LANDMARKS := {
	"ossuary": {"id": "colossus", "name": "The Bone Colossus", "line": "It was a warden once. It still remembers every hall.",
		"prompt": "Listen to the Colossus", "light": Color(0.55, 0.9, 0.85), "energy": 0.45},
	"rootmire": {"id": "heartroot", "name": "The Heart-Root", "line": "The dead tree's heart still beats. It is thirsty.",
		"prompt": "Bleed for the Heart (-15% health)", "light": Color(1.0, 0.35, 0.35), "energy": 0.8},
	"throne": {"id": "sundisc", "name": "The Fallen Sun-Disc", "line": "The sun-king's emblem. A little warmth is still caught in it.",
		"prompt": "Touch the last warmth", "light": Color(1.0, 0.72, 0.38), "energy": 0.7},
}
## Dev (`landmark`): every floor has one.
static var force_landmark := false


static func landmark_def(id: String) -> Dictionary:
	for k in LANDMARKS:
		if String(LANDMARKS[k].id) == id:
			return LANDMARKS[k]
	return {}


## Now and then a floor holds its region's landmark, in the middle of one
## fight (more often deeper down). Chosen with an rng of its own, so the rest
## of a seed's floor is the same with or without it.
static func _landmark(lay: Layout, seed_v: int) -> void:
	if not LANDMARKS.has(lay.region):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, lay.depth, "landmark"])
	if rng.randf() > minf(0.16 + 0.04 * lay.depth, 0.36) and not force_landmark:
		return
	var cands: Array = []
	for r in lay.rooms:
		if r.type == Room.Type.COMBAT and r.id >= 2 and r.authored == "" and r.cells.size() == 1 and r.rect.size.x >= 20:
			cands.append(r)
	if cands.is_empty():
		return
	var r: Room = cands[rng.randi_range(0, cands.size() - 1)]
	var c := Vector2i(r.center())
	# open floor around it, whatever the room's own shape put there
	var g := lay.grid
	var area := Rect2i(c.x - 4, c.y - 3, 9, 6).intersection(r.rect.grow(-1))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			g.put(x, y, TileGrid.FLOOR)
			g.room_of[y * g.width + x] = r.id
	# a pit cut in half keeps its edge
	var ring := area.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			if g.at(x, y) == TileGrid.VOID:
				g.put(x, y, TileGrid.WALL)
	r.props = r.props.filter(func(pd): return pd.kind == "decal" or not area.has_point(pd.tile))
	r.landmark = String(LANDMARKS[lay.region].id)
	r.props.append({"kind": "landmark", "tile": c, "id": r.landmark})
	# the place it stands is kept: lights at its feet
	var lamp: String = {"rootmire": "glowcap", "throne": "brazier"}.get(lay.region, "candles")
	for o in [Vector2i(-3, 1), Vector2i(3, 1)]:
		r.props.append({"kind": lamp, "tile": c + o})


static func _try_generate(rng: RandomNumberGenerator, depth: int, region: String, boss_depth: bool) -> Layout:
	var lay := Layout.new()
	lay.depth = depth
	lay.region = region
	lay.boss_depth = boss_depth
	lay.route = _route
	lay.offer = _offer.duplicate()
	var rt: Dictionary = ROUTES.get(_route, {})
	var owner := {}            # Vector2i cell -> room index
	var room_cells: Array = [] # room index -> Array[Vector2i]
	var types: Array = []
	var links := {}            # "a:b" -> [cell_a, cell_b, secret]

	# 1. main path
	var start := Vector2i(rng.randi_range(2, 4), GH - 1)
	var path_len := 6 + mini(depth, 3) + int(rt.get("path", 0))
	var path := _walk(rng, start, path_len, owner)
	if path.size() < path_len:
		return null
	for i in path.size():
		owner[path[i]] = i
		room_cells.append([path[i]])
		types.append(Room.Type.COMBAT)
		if i > 0:
			_link(links, i - 1, i, path[i - 1], path[i])
	types[0] = Room.Type.START
	var last := path.size() - 1

	# 2. boss arena (2x2) or stairs
	if boss_depth:
		types[last] = Room.Type.REST
		var placed := false
		var corners := []
		for d in DIRS:
			var c := path[last] + d
			# candidate 2x2 blocks that contain c
			for ox in [0, -1]:
				for oy in [0, -1]:
					corners.append([c + Vector2i(ox, oy), c])
		_shuffle(corners, rng)
		for pair in corners:
			var tl: Vector2i = pair[0]
			var blk: Array[Vector2i] = [tl, tl + Vector2i(1, 0), tl + Vector2i(0, 1), tl + Vector2i(1, 1)]
			var ok := true
			for b in blk:
				if b.x < 0 or b.y < 0 or b.x >= GW or b.y >= GH or owner.has(b):
					ok = false
					break
			if not ok:
				continue
			var bi := room_cells.size()
			for b in blk:
				owner[b] = bi
			room_cells.append(blk)
			types.append(Room.Type.BOSS)
			_link(links, last, bi, path[last], pair[1])
			lay.exit_id = bi
			placed = true
			break
		if not placed:
			return null
	else:
		types[last] = Room.Type.STAIRS
		lay.exit_id = last

	# 3. branches ending in special rooms
	var specials: Array = [Room.Type.TREASURE, Room.Type.ELITE, Room.Type.SHRINE, Room.Type.MERCHANT, Room.Type.EVENT]
	if not boss_depth:
		specials.append(Room.Type.REST)
	match _route:
		"trial":
			specials.append(Room.Type.ELITE)        # two elites
		"vault":
			specials.append_array([Room.Type.TREASURE, Room.Type.EVENT])
		"quiet":
			specials.erase(Room.Type.ELITE)
			if not specials.has(Room.Type.REST):
				specials.append(Room.Type.REST)
	_shuffle(specials, rng)
	var branch_count := 3 + (1 if rng.randf() < 0.5 else 0) + int(rt.get("branches", 0))
	if _route == "vault":
		# its treasure is down a side branch: make sure one is taken
		specials.erase(Room.Type.TREASURE)
		specials.append(Room.Type.TREASURE)
	elif _route == "quiet":
		# ...and the quiet way's spring
		specials.erase(Room.Type.REST)
		specials.append(Room.Type.REST)
	var origins := range(1, last)
	_shuffle(origins, rng)
	var made := 0
	for o in origins:
		if made >= branch_count or specials.is_empty():
			break
		var blen := 1 if rng.randf() < 0.6 else 2
		var br := _walk(rng, path[o], blen + 1, owner)
		if br.size() < 2:
			continue
		var prev_i: int = o
		var prev_c: Vector2i = path[o]
		for k in range(1, br.size()):
			var ni := room_cells.size()
			owner[br[k]] = ni
			room_cells.append([br[k]])
			types.append(Room.Type.COMBAT if k < br.size() - 1 else specials.pop_back())
			_link(links, prev_i, ni, prev_c, br[k])
			prev_i = ni
			prev_c = br[k]
		made += 1
	if made < 2:
		return null
	if not types.has(Room.Type.ELITE) and _route != "quiet":
		types[rng.randi_range(2, maxi(2, last - 1))] = Room.Type.ELITE
	if _route == "trial" and types.count(Room.Type.ELITE) < 2:
		for i in range(last - 1, 1, -1):
			if types[i] == Room.Type.COMBAT:
				types[i] = Room.Type.ELITE
				break

	# 4. merge some combat rooms into bigger halls
	for i in room_cells.size():
		if types[i] != Room.Type.COMBAT or room_cells[i].size() != 1 or rng.randf() > 0.38:
			continue
		var c: Vector2i = room_cells[i][0]
		var opts: Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < GW and n.y < GH and not owner.has(n):
				opts.append(n)
		if opts.is_empty():
			continue
		var n: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
		owner[n] = i
		room_cells[i].append(n)

	# 5. loops between adjacent rooms
	for c: Vector2i in owner.keys():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if not owner.has(n):
				continue
			var a: int = owner[c]
			var b: int = owner[n]
			if a == b or links.has(_key(a, b)):
				continue
			if types[a] == Room.Type.BOSS or types[b] == Room.Type.BOSS:
				continue
			if types[a] == Room.Type.START or types[b] == Room.Type.START:
				continue
			if rng.randf() < 0.22:
				_link(links, a, b, c, n)

	# 6. secret chamber behind a cracked wall
	if rng.randf() < 0.75:
		var cands: Array = []
		for y in GH:
			for x in GW:
				var c := Vector2i(x, y)
				if owner.has(c):
					continue
				var nb: Array = []
				for d in DIRS:
					if owner.has(c + d) and types[owner[c + d]] != Room.Type.BOSS:
						nb.append(c + d)
				if nb.size() >= 1:
					cands.append([c, nb])
		if not cands.is_empty():
			var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
			var si := room_cells.size()
			owner[pick[0]] = si
			room_cells.append([pick[0]])
			types.append(Room.Type.SECRET)
			var nbc: Vector2i = pick[1][rng.randi_range(0, pick[1].size() - 1)]
			_link(links, owner[nbc], si, nbc, pick[0], true)

	# 7. carve
	var gw_t := GW * CELL_W + MARGIN * 2
	var gh_t := GH * CELL_H + MARGIN * 2
	var grid := TileGrid.new(gw_t, gh_t)
	lay.grid = grid
	lay.cell_owner = owner
	for i in room_cells.size():
		var r := Room.new()
		r.id = i
		r.type = types[i]
		for c in room_cells[i]:
			r.cells.append(c)
		var mn := Vector2i(999, 999)
		var mx := Vector2i(-1, -1)
		for c: Vector2i in r.cells:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
		var x0 := mn.x * CELL_W + FX0 + MARGIN
		var y0 := mn.y * CELL_H + FY0 + MARGIN
		var x1 := mx.x * CELL_W + FX0 + FW - 1 + MARGIN
		var y1 := mx.y * CELL_H + FY0 + FH - 1 + MARGIN
		r.rect = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
		lay.rooms.append(r)
	# doors (corridor gaps) first, so stamps know which tiles must stay open
	for k in links:
		var L: Array = links[k]
		_carve_door(lay, L[0], L[1], L[2], L[3], L[4])
	for r in lay.rooms:
		_shape_room(lay, r, rng)
	grid.finalize_walls()
	# secret doors start sealed (cracked wall)
	for r in lay.rooms:
		for d in r.doors:
			if d.secret:
				for t: Vector2i in d.gap:
					grid.put(t.x, t.y, TileGrid.WALL)
	lay.start_id = 0

	# 8. contents: rewards, encounters, props
	_populate(lay, rng)
	return lay


## Seeded Fisher-Yates shuffle (Array.shuffle() uses the global RNG and would
## break seed reproducibility).
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func _link(links: Dictionary, a: int, b: int, ca: Vector2i, cb: Vector2i, secret := false) -> void:
	links[_key(a, b)] = [a, b, ca, cb, secret]


## Random self-avoiding walk of `n` cells starting at `from` (inclusive),
## preferring to head north and sideways.
static func _walk(rng: RandomNumberGenerator, from: Vector2i, n: int, owner: Dictionary) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for attempt in 30:
		var p: Array[Vector2i] = [from]
		var used := {from: true}
		while p.size() < n:
			var cur: Vector2i = p[p.size() - 1]
			var opts: Array = []
			for d in DIRS:
				var c: Vector2i = cur + d
				if c.x < 0 or c.y < 0 or c.x >= GW or c.y >= GH:
					continue
				if used.has(c) or owner.has(c):
					continue
				var w := 1.0
				if d == Vector2i(0, -1):
					w = 2.2
				elif d == Vector2i(0, 1):
					w = 0.5
				opts.append([c, w])
			if opts.is_empty():
				break
			var tot := 0.0
			for o in opts:
				tot += o[1]
			var x := rng.randf() * tot
			var pick: Vector2i = opts[0][0]
			for o in opts:
				x -= o[1]
				if x <= 0.0:
					pick = o[0]
					break
			p.append(pick)
			used[pick] = true
		if p.size() > best.size():
			best = p
		if best.size() >= n:
			break
	return best


static func _carve_door(lay: Layout, a: int, b: int, ca: Vector2i, cb: Vector2i, secret: bool) -> void:
	var g := lay.grid
	var tiles_a: Array[Vector2i] = []
	var tiles_b: Array[Vector2i] = []
	var gap: Array[Vector2i] = []
	var d := cb - ca
	var lo := ca if (d.x > 0 or d.y > 0) else cb
	var hi := cb if lo == ca else ca
	if d.y == 0:
		var gx0 := lo.x * CELL_W + FX0 + FW + MARGIN
		for r in range(DOOR_ROWS[0], DOOR_ROWS[1] + 1):
			var y := lo.y * CELL_H + FY0 + r + MARGIN
			for gx in [gx0, gx0 + 1]:
				g.put(gx, y, TileGrid.FLOOR)
				gap.append(Vector2i(gx, y))
			if lo == ca:
				tiles_a.append(Vector2i(gx0, y))
				tiles_b.append(Vector2i(gx0 + 1, y))
			else:
				tiles_b.append(Vector2i(gx0, y))
				tiles_a.append(Vector2i(gx0 + 1, y))
	else:
		var gy0 := lo.y * CELL_H + FY0 + FH + MARGIN
		for c in range(DOOR_COLS[0], DOOR_COLS[1] + 1):
			var x := lo.x * CELL_W + FX0 + c + MARGIN
			for k in 4:
				g.put(x, gy0 + k, TileGrid.FLOOR)
				gap.append(Vector2i(x, gy0 + k))
			if lo == ca:
				tiles_a.append(Vector2i(x, gy0))
				tiles_b.append(Vector2i(x, gy0 + 3))
			else:
				tiles_b.append(Vector2i(x, gy0))
				tiles_a.append(Vector2i(x, gy0 + 3))
	var ra := lay.rooms[a]
	var rb := lay.rooms[b]
	ra.doors.append({"to": b, "dir": d, "tiles": tiles_a, "gap": gap, "secret": secret})
	rb.doors.append({"to": a, "dir": -d, "tiles": tiles_b, "gap": gap, "secret": secret})


# ---------------------------------------------------------------------------
# Room interiors

static func _shape_room(lay: Layout, r: Room, rng: RandomNumberGenerator) -> void:
	var g := lay.grid
	var w := r.rect.size.x
	var h := r.rect.size.y
	# door keep-out zones in local coordinates (must stay floor)
	var keep: Array[Rect2i] = []
	for d in r.doors:
		for t: Vector2i in d.tiles:
			var lt := t - r.rect.position
			var dir: Vector2i = d.dir
			# step from the threshold into the room and reserve a 3-deep lane
			for k in range(1, 4):
				var p := lt - dir * k
				keep.append(Rect2i(p.x - 1, p.y - 1, 3, 3))
	var layout := PackedByteArray()
	var best := PackedByteArray()
	var stamps_for := _stamp_pool(r)
	# now and then a single-cell fight takes place in a hand-made room
	var authored := ""
	var made: Array = AUTHORED_BY_REGION.get(lay.region, [])
	if w == 22 and h == 12 and (r.type == Room.Type.COMBAT or r.type == Room.Type.ELITE) and not made.is_empty() and rng.randf() < 0.22:
		authored = String(made[rng.randi_range(0, made.size() - 1)])
	for attempt in 12:
		layout.resize(w * h)
		layout.fill(TileGrid.FLOOR)
		var n := 1 if rng.randf() < 0.55 else 2
		if r.type != Room.Type.COMBAT and r.type != Room.Type.ELITE:
			n = 1
		var pool := stamps_for.duplicate()
		_shuffle(pool, rng)
		if authored != "" and attempt == 0:
			_stamp_authored(authored, layout, w, h, rng.randf() < 0.5)
			n = 0
		for i in mini(n, pool.size()):
			_stamp(pool[i], layout, w, h, rng)
		for kr in keep:
			for yy in range(kr.position.y, kr.end.y):
				for xx in range(kr.position.x, kr.end.x):
					if xx >= 0 and yy >= 0 and xx < w and yy < h:
						layout[yy * w + xx] = TileGrid.FLOOR
		if _valid(layout, w, h, r):
			best = layout.duplicate()
			if authored != "" and attempt == 0:
				r.authored = authored
			break
	if best.is_empty():
		best.resize(w * h)
		best.fill(TileGrid.FLOOR)
	for y in h:
		for x in w:
			var t := best[y * w + x]
			var gx := r.rect.position.x + x
			var gy := r.rect.position.y + y
			g.put(gx, gy, t)
			if t != TileGrid.VOID:
				g.room_of[gy * g.width + gx] = r.id


static func _stamp_pool(r: Room) -> Array:
	match r.type:
		Room.Type.COMBAT, Room.Type.ELITE:
			var big := r.cells.size() > 1
			var pool := ["pillars4", "pillar_rows", "center_pit", "corners", "center_block", "alcoves", "cross", "twin_pits", "diag_pillars",
				"ring_pillars", "chasm", "pillar_grid", "split_wall", "l_room", "islands"]
			if big:
				pool.append_array(["pit_ring", "pillar_rows", "center_pit", "chasm", "ring_pillars"])
			return pool
		Room.Type.BOSS:
			return ["octagon"]
		Room.Type.START, Room.Type.REST, Room.Type.SHRINE:
			return ["pillars4", "corners", "alcoves"]
		Room.Type.TREASURE, Room.Type.SECRET, Room.Type.EVENT:
			return ["corners", "pillars4"]
		Room.Type.MERCHANT, Room.Type.STAIRS:
			return ["alcoves", "corners"]
	return ["pillars4"]


## A hand-made room, mirrored left-right half the time.
static func _stamp_authored(id: String, L: PackedByteArray, w: int, h: int, mirror: bool) -> void:
	var rows: Array = AUTHORED[id]
	for y in mini(h, rows.size()):
		var row := String(rows[y])
		for x in mini(w, row.length()):
			var ch := row[(row.length() - 1 - x) if mirror else x]
			var t: int = {".": TileGrid.FLOOR, "#": TileGrid.WALL, "o": TileGrid.PILLAR, "~": TileGrid.PIT, " ": TileGrid.VOID}.get(ch, TileGrid.FLOOR)
			_put(L, w, h, x, y, t)


static func _put(layout: PackedByteArray, w: int, h: int, x: int, y: int, t: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		layout[y * w + x] = t


static func _stamp(kind: String, L: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator) -> void:
	match kind:
		"pillars4":
			var px := maxi(3, int(w * rng.randf_range(0.2, 0.3)))
			var py := maxi(2, int(h * rng.randf_range(0.25, 0.32)))
			for p in [Vector2i(px, py), Vector2i(w - 1 - px, py), Vector2i(px, h - 1 - py), Vector2i(w - 1 - px, h - 1 - py)]:
				_put(L, w, h, p.x, p.y, TileGrid.PILLAR)
		"diag_pillars":
			var step := rng.randi_range(4, 6)
			for i in range(3, w - 3, step):
				var y := 2 + int(float(i) / w * (h - 5))
				_put(L, w, h, i, y, TileGrid.PILLAR)
				_put(L, w, h, w - 1 - i, y, TileGrid.PILLAR)
		"pillar_rows":
			var step := rng.randi_range(4, 6)
			var r1 := rng.randi_range(2, 3)
			for x in range(3, w - 3, step):
				_put(L, w, h, x, r1, TileGrid.PILLAR)
				_put(L, w, h, x, h - 1 - r1, TileGrid.PILLAR)
		"center_pit":
			var pw := rng.randi_range(4, mini(12, w - 10))
			var ph := rng.randi_range(2, mini(5, h - 7))
			var x0 := (w - pw) / 2
			var y0 := (h - ph) / 2
			for y in range(y0, y0 + ph):
				for x in range(x0, x0 + pw):
					_put(L, w, h, x, y, TileGrid.PIT)
		"twin_pits":
			var pw := rng.randi_range(3, 5)
			var ph := rng.randi_range(2, 4)
			var y0 := (h - ph) / 2
			for x0 in [4, w - 4 - pw]:
				for y in range(y0, y0 + ph):
					for x in range(x0, x0 + pw):
						_put(L, w, h, x, y, TileGrid.PIT)
		"pit_ring":
			var mx := 4
			var my := 3
			for y in range(my, h - my):
				for x in range(mx, w - mx):
					var edge := x == mx or x == w - mx - 1 or y == my or y == h - my - 1
					var edge2 := x == mx + 1 or x == w - mx - 2 or y == my + 1 or y == h - my - 2
					if edge or edge2:
						_put(L, w, h, x, y, TileGrid.PIT)
			# bridges along both axes
			for y in range(0, h):
				for x in range(w / 2 - 1, w / 2 + 1):
					if L[y * w + x] == TileGrid.PIT:
						L[y * w + x] = TileGrid.FLOOR
			for x in range(0, w):
				for y in range(h / 2 - 1, h / 2 + 1):
					if L[y * w + x] == TileGrid.PIT:
						L[y * w + x] = TileGrid.FLOOR
		"corners":
			var cw := rng.randi_range(2, 5)
			var ch := rng.randi_range(2, 3)
			var both := rng.randf() < 0.6
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)]:
				if not both and (corner == Vector2i(1, 0) or corner == Vector2i(0, 1)):
					continue
				var x0 := 0 if corner.x == 0 else w - cw
				var y0 := 0 if corner.y == 0 else h - ch
				for y in range(y0, y0 + ch):
					for x in range(x0, x0 + cw):
						_put(L, w, h, x, y, TileGrid.VOID)
		"cross":
			var cw := w / 2 - 5
			var ch := h / 2 - 3
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)]:
				var x0 := 0 if corner.x == 0 else w - cw
				var y0 := 0 if corner.y == 0 else h - ch
				for y in range(y0, y0 + ch):
					for x in range(x0, x0 + cw):
						_put(L, w, h, x, y, TileGrid.VOID)
		"center_block":
			var bw := rng.randi_range(2, 4)
			var bh := 2
			var x0 := (w - bw) / 2
			var y0 := (h - bh) / 2
			for y in range(y0, y0 + bh):
				for x in range(x0, x0 + bw):
					_put(L, w, h, x, y, TileGrid.WALL)
		"alcoves":
			for x in range(2, w - 2, 5):
				_put(L, w, h, x, 0, TileGrid.VOID)
				_put(L, w, h, x + 1, 0, TileGrid.VOID)
		"ring_pillars":
			# an arena: a loose ring of pillars around the middle
			var n := rng.randi_range(6, 8)
			var rx := w * 0.3
			var ry := h * 0.3
			var a0 := rng.randf() * TAU
			for i in n:
				var a := a0 + TAU * i / n
				_put(L, w, h, int(round(w * 0.5 - 0.5 + cos(a) * rx)), int(round(h * 0.5 - 0.5 + sin(a) * ry)), TileGrid.PILLAR)
		"chasm":
			# a rift across the room, crossed by one or two bridges
			var vertical := rng.randf() < 0.5
			var thick := rng.randi_range(2, 3)
			var span := w if not vertical else h
			var across := h if not vertical else w
			var c0 := across / 2 - thick / 2
			var bridges: Array = [span / 2] if rng.randf() < 0.5 else [span / 4, span - span / 4]
			for s in range(2, span - 2):
				var on_bridge := false
				for b in bridges:
					if absi(s - int(b)) <= 1:
						on_bridge = true
				if on_bridge:
					continue
				for k in thick:
					if vertical:
						_put(L, w, h, c0 + k, s, TileGrid.PIT)
					else:
						_put(L, w, h, s, c0 + k, TileGrid.PIT)
		"pillar_grid":
			# a hall of columns
			var sx := rng.randi_range(4, 5)
			var sy := 3
			for y in range(3, h - 2, sy):
				for x in range(3, w - 2, sx):
					_put(L, w, h, x, y, TileGrid.PILLAR)
		"split_wall":
			# a broken wall down the middle: two halves joined by gaps
			var x0 := w / 2
			var gaps: Array = [h / 4, h - 1 - h / 4]
			for y in range(1, h - 1):
				var gap := false
				for g in gaps:
					if absi(y - int(g)) <= 1:
						gap = true
				if not gap:
					_put(L, w, h, x0, y, TileGrid.WALL)
		"l_room":
			# one corner of the room missing entirely
			var cx := rng.randi_range(0, 1)
			var cy := rng.randi_range(0, 1)
			var lw := w / 2 - 2
			var lh := h / 2 - 1
			var x0 := 0 if cx == 0 else w - lw
			var y0 := 0 if cy == 0 else h - lh
			for y in range(y0, y0 + lh):
				for x in range(x0, x0 + lw):
					_put(L, w, h, x, y, TileGrid.VOID)
		"islands":
			# scattered sinkholes
			for i in rng.randi_range(3, 5):
				var x0 := rng.randi_range(3, w - 5)
				var y0 := rng.randi_range(2, h - 4)
				for y in range(y0, y0 + 2):
					for x in range(x0, x0 + 2):
						_put(L, w, h, x, y, TileGrid.PIT)
		"octagon":
			var c := mini(9, w / 4)
			for y in h:
				for x in w:
					var dx := mini(x, w - 1 - x)
					var dy := mini(y, h - 1 - y)
					if dx + dy < c:
						_put(L, w, h, x, y, TileGrid.VOID)


static func _valid(L: PackedByteArray, w: int, h: int, r: Room) -> bool:
	var floor_n := 0
	var first := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if L[y * w + x] == TileGrid.FLOOR:
				floor_n += 1
				if first.x < 0:
					first = Vector2i(x, y)
	if floor_n < int(w * h * 0.5):
		return false
	# every door threshold neighbour must be reachable from every other
	var seen := {}
	var start := Vector2i(w / 2, h / 2)
	if L[start.y * w + start.x] != TileGrid.FLOOR:
		start = first
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		for d in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if L[n.y * w + n.x] == TileGrid.FLOOR and not seen.has(n):
				stack.append(n)
	for d in r.doors:
		for t: Vector2i in d.tiles:
			var inner: Vector2i = t - r.rect.position - Vector2i(d.dir)
			if not seen.has(inner):
				return false
	# most of the floor should be connected (no big sealed pockets)
	return seen.size() >= int(floor_n * 0.9)


# ---------------------------------------------------------------------------
# Contents

static func _populate(lay: Layout, rng: RandomNumberGenerator) -> void:
	var g := lay.grid
	var reward_pool := ["relic", "relic", "relic", "embers", "embers", "vigor", "memory"]
	_objectives(lay)
	var foes := float(ROUTES.get(lay.route, {}).get("foes", 1.0))
	for r in lay.rooms:
		# spawn tiles: floor, away from doors and walls
		for y in range(r.rect.position.y, r.rect.end.y):
			for x in range(r.rect.position.x, r.rect.end.x):
				if g.at(x, y) != TileGrid.FLOOR:
					continue
				var near_door := false
				for d in r.doors:
					for t: Vector2i in d.tiles:
						if absi(t.x - x) + absi(t.y - y) < 5:
							near_door = true
				if near_door:
					continue
				var open := true
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if g.at(x + dx, y + dy) != TileGrid.FLOOR:
							open = false
				if open:
					r.spawns.append(Vector2i(x, y))
		match r.type:
			Room.Type.EVENT:
				r.event = Room.EVENTS[rng.randi_range(0, Room.EVENTS.size() - 1)]
				if r.event == "trial":
					r.reward = "trial"
					r.waves = 3
					r.encounter = []
					for wv in 3:
						r.encounter.append(EnemyDB.roll_encounter(rng, lay.region, lay.depth, 8 + lay.depth * 4 + wv * 2))
			Room.Type.COMBAT:
				r.reward = reward_pool[rng.randi_range(0, reward_pool.size() - 1)]
				if r.objective == "seals":
					r.reward = "seals"
				elif r.objective == "flame":
					r.reward = "vault"
			Room.Type.ELITE:
				r.reward = "sunshard"
			Room.Type.SECRET:
				r.reward = "secret"
		if r.is_combat() and r.type != Room.Type.BOSS:
			var area := r.rect.size.x * r.rect.size.y
			var budget := 6 + lay.depth * 3 + int(area / 140)
			if r.type == Room.Type.ELITE:
				budget += 2
			budget = maxi(4, int(round(budget * foes)))
			r.waves = 2 if (area > 400 or (lay.depth >= 2 and rng.randf() < 0.45)) else 1
			if r.objective == "flame":
				r.waves = 3      # the flame must be kept through three waves
			r.encounter = []
			for wv in r.waves:
				var b := budget if wv == 0 else int(budget * 0.75)
				r.encounter.append(EnemyDB.roll_encounter(rng, lay.region, lay.depth, b))
			if r.type == Room.Type.ELITE:
				r.elite_affix = EnemyDB.AFFIXES.keys()[rng.randi_range(0, EnemyDB.AFFIXES.size() - 1)]
		_decorate(lay, r, rng)


static func _decorate(lay: Layout, r: Room, rng: RandomNumberGenerator) -> void:
	var g := lay.grid
	var door_cols := {}
	for d in r.doors:
		for t: Vector2i in d.tiles:
			door_cols[t.x] = true
	# soul-flame sconces on the back wall
	var back_y := r.rect.position.y - 1
	var xs: Array = []
	for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
		if g.at(x, back_y) == TileGrid.WALL and g.at(x, back_y + 1) == TileGrid.FLOOR and g.wall_height(x, back_y) > 1.0 and not door_cols.has(x) and not door_cols.has(x - 1) and not door_cols.has(x + 1):
			xs.append(x)
	var spacing := 5
	var last_x := -99
	for x in xs:
		if x - last_x >= spacing:
			r.props.append({"kind": "torch", "tile": Vector2i(x, back_y)})
			last_x = x
	# banners / cracks / alcoves on the back wall between torches
	for x in xs:
		if rng.randf() < 0.12 and not _prop_at(r, Vector2i(x, back_y)):
			r.props.append({"kind": "banner", "tile": Vector2i(x, back_y)})
	# floor clutter: bones, rubble, cobwebs, urns
	var floor_tiles: Array[Vector2i] = []
	for y in range(r.rect.position.y, r.rect.end.y):
		for x in range(r.rect.position.x, r.rect.end.x):
			if g.at(x, y) == TileGrid.FLOOR:
				floor_tiles.append(Vector2i(x, y))
	# clutter gathers where feet don't go: half of it hugs the walls
	var edge_tiles: Array[Vector2i] = []
	for t in floor_tiles:
		if g.at(t.x, t.y - 1) == TileGrid.WALL or g.at(t.x - 1, t.y) == TileGrid.WALL or g.at(t.x + 1, t.y) == TileGrid.WALL or g.at(t.x, t.y + 1) == TileGrid.WALL:
			edge_tiles.append(t)
	var row := lay.region if lay.region in ["rootmire", "throne"] else "ossuary"
	var n_decal := int(floor_tiles.size() / 11)
	for i in n_decal:
		var pool: Array[Vector2i] = edge_tiles if (not edge_tiles.is_empty() and rng.randf() < 0.5) else floor_tiles
		var t: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		r.props.append({"kind": "decal", "tile": t, "variant": rng.randi_range(0, 9), "row": row})
	# urns hug the walls
	var wall_adj: Array[Vector2i] = []
	for t in floor_tiles:
		if g.at(t.x, t.y - 1) == TileGrid.WALL or g.at(t.x - 1, t.y) == TileGrid.WALL or g.at(t.x + 1, t.y) == TileGrid.WALL:
			var bad := false
			for d in r.doors:
				for dt: Vector2i in d.tiles:
					if absi(dt.x - t.x) + absi(dt.y - t.y) < 4:
						bad = true
			if not bad:
				wall_adj.append(t)
	var n_urn := rng.randi_range(1, 4) if r.type != Room.Type.BOSS else 0
	for i in n_urn:
		if wall_adj.is_empty():
			break
		var t: Vector2i = wall_adj.pop_at(rng.randi_range(0, wall_adj.size() - 1))
		# urns of the region's own make; now and then one glints (rarer near
		# the top, a little more common deeper down)
		var rich := rng.randf() < 0.06 + 0.02 * mini(lay.depth, 6)
		# from depth 2, one glinting urn in three is an Urnling: something lives
		# in it (chosen by the tile, not the rng, so the floor is otherwise the same)
		var urnling := rich and lay.depth >= 2 and posmod(t.x * 7 + t.y * 13 + lay.depth, 3) == 0
		r.props.append({"kind": "urn", "tile": t, "mat": {"rootmire": "root", "throne": "gilded"}.get(lay.region, "clay"),
			"rich": rich, "urnling": urnling})
	# set dressing that gives each region its silhouette, against the walls
	if r.type in [Room.Type.COMBAT, Room.Type.ELITE, Room.Type.TREASURE] and floor_tiles.size() > 60:
		var pieces: Array = {"rootmire": ["stump"], "throne": ["statue", "statue", "column_fallen"]}.get(lay.region, ["sarcophagus", "bone_heap"])
		for i in 1 + int(floor_tiles.size() > 140):
			if wall_adj.is_empty():
				break
			var t: Vector2i = wall_adj.pop_at(rng.randi_range(0, wall_adj.size() - 1))
			if g.at(t.x, t.y - 1) != TileGrid.WALL:
				continue
			var sheet: String = pieces[rng.randi_range(0, pieces.size() - 1)]
			# a piece two tiles wide stands on two tiles (both against the wall)
			# and blocks both: what you see is what stops you
			var want: Array[Vector2i] = [t]
			if WIDE_DRESSING.has(sheet):
				var t2 := t + Vector2i(1, 0)
				if not wall_adj.has(t2) or g.at(t2.x, t2.y - 1) != TileGrid.WALL:
					continue
				want.append(t2)
			# ...and never closes off a nook of the room: its floor stays one piece
			# (a sarcophagus across a two-tile alcove sealed it, unreachable)
			if not WALKABLE_DRESSING.has(sheet) and not _floor_whole(lay, r, want):
				continue
			if want.size() > 1:
				wall_adj.erase(want[1])
				r.props.append({"kind": "dressing", "tile": t, "sheet": sheet, "wide": true})
			else:
				r.props.append({"kind": "dressing", "tile": t, "sheet": sheet})
	# pools of light along the walls of bigger rooms, so a fight can be read
	# beyond the lantern: candles in the Ossuary, glowcaps in the Rootmire,
	# braziers in the Throne
	if r.type in [Room.Type.COMBAT, Room.Type.ELITE] and floor_tiles.size() > 70:
		var lamp: String = {"rootmire": "glowcap", "throne": "brazier"}.get(lay.region, "candles")
		for i in 1 + int(floor_tiles.size() > 150):
			if wall_adj.is_empty():
				break
			var t: Vector2i = wall_adj.pop_at(rng.randi_range(0, wall_adj.size() - 1))
			r.props.append({"kind": lamp, "tile": t})
	var c := Vector2i(r.center())
	if r.type == Room.Type.COMBAT and rng.randf() < 0.3:
		_trap_line(lay, r, rng)
	if lay.region == "rootmire":
		_root_decor(lay, r, rng, floor_tiles, wall_adj)
	match r.type:
		Room.Type.START:
			r.props.append({"kind": "lore", "tile": c + Vector2i(0, -3)})
		Room.Type.TREASURE:
			r.props.append({"kind": "chest", "tile": c, "tier": 1})
			for o in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(2, 1)]:
				r.props.append({"kind": "candles", "tile": c + o})
		Room.Type.SECRET:
			r.props.append({"kind": "chest", "tile": c, "tier": 2})
			r.props.append({"kind": "ember_pile", "tile": c + Vector2i(-3, 1)})
			r.props.append({"kind": "ember_pile", "tile": c + Vector2i(3, 1)})
		Room.Type.SHRINE:
			r.props.append({"kind": "shrine", "tile": c + Vector2i(0, -2)})
			r.props.append({"kind": "brazier", "tile": c + Vector2i(-4, -2)})
			r.props.append({"kind": "brazier", "tile": c + Vector2i(4, -2)})
		Room.Type.MERCHANT:
			r.props.append({"kind": "merchant", "tile": c + Vector2i(0, -2)})
			r.props.append({"kind": "brazier", "tile": c + Vector2i(-3, -1)})
		Room.Type.REST:
			r.props.append({"kind": "fountain", "tile": c})
		Room.Type.EVENT:
			match r.event:
				"well":
					r.props.append({"kind": "ember_well", "tile": c})
				"trial":
					r.props.append({"kind": "trial_altar", "tile": c + Vector2i(0, -2)})
					r.props.append({"kind": "brazier", "tile": c + Vector2i(-4, -2)})
					r.props.append({"kind": "brazier", "tile": c + Vector2i(4, -2)})
				"echo":
					r.props.append({"kind": "echo", "tile": c})
					r.props.append({"kind": "candles", "tile": c + Vector2i(-2, 1)})
					r.props.append({"kind": "candles", "tile": c + Vector2i(2, 1)})
				"vault":
					# four sconces in the corners, a sealed reliquary between them
					r.props.append({"kind": "chest", "tile": c, "tier": 3, "sealed": true})
					var hx := maxi(3, mini(6, r.rect.size.x / 2 - 2))
					var hy := maxi(2, mini(4, r.rect.size.y / 2 - 2))
					for s in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
						# from the corner inward until there is open floor (pillars stand in some rooms)
						var t := c + Vector2i(s.x * hx, s.y * hy)
						for k in hx + hy:
							if lay.grid.at(t.x, t.y) == TileGrid.FLOOR:
								break
							t -= Vector2i(s.x if absi(t.x - c.x) > 1 else 0, s.y if absi(t.y - c.y) > 1 else 0)
						if lay.grid.at(t.x, t.y) == TileGrid.FLOOR and t != c:
							r.props.append({"kind": "sconce", "tile": t})
				"camp":
					r.props.append({"kind": "lost_camp", "tile": c})
					r.props.append({"kind": "lore", "tile": c + Vector2i(3, -2)})
		Room.Type.STAIRS:
			if lay.offer.size() >= 2:
				# the fork: two ways down, each lit in its own colour
				for k in 2:
					var t := c + Vector2i(-3 + 6 * k, -2)
					if g.at(t.x, t.y) != TileGrid.FLOOR:
						t = c + Vector2i(-2 + 4 * k, -2)
					var rid: String = lay.offer[k]
					r.props.append({"kind": "stairs", "tile": t, "route": rid})
					var bt := t + Vector2i(-1 if k == 0 else 1, 0)
					if g.at(bt.x, bt.y) == TileGrid.FLOOR:
						r.props.append({"kind": "brazier", "tile": bt, "flame": ROUTES[rid].color, "sheet": "brazier" if rid == "quiet" else "brazier_warm"})
			else:
				r.props.append({"kind": "stairs", "tile": c + Vector2i(0, -2)})
			r.props.append({"kind": "hearthstone", "tile": c + Vector2i(-5, 1)})
		Room.Type.BOSS:
			var bc := Vector2(r.center())
			var node_kind := "root_node" if lay.region == "rootmire" else "boss_brazier"
			for o in [Vector2(-8, -5), Vector2(8, -5), Vector2(-8, 5), Vector2(8, 5)]:
				var bt := Vector2i(bc + o)
				r.props.append({"kind": node_kind, "tile": bt})


## A line of spike traps across the room, firing in a rolling wave.
static func _trap_line(lay: Layout, r: Room, rng: RandomNumberGenerator) -> void:
	var g := lay.grid
	var horizontal := rng.randf() < 0.5
	var len := rng.randi_range(5, 9)
	for attempt in 8:
		var start := Vector2i(rng.randi_range(r.rect.position.x + 2, r.rect.end.x - 3), rng.randi_range(r.rect.position.y + 2, r.rect.end.y - 3))
		var tiles: Array[Vector2i] = []
		for i in len:
			var t := start + (Vector2i(i, 0) if horizontal else Vector2i(0, i))
			if g.at(t.x, t.y) != TileGrid.FLOOR or not r.rect.has_point(t):
				break
			var near_door := false
			for d in r.doors:
				for dt: Vector2i in d.tiles:
					if absi(dt.x - t.x) + absi(dt.y - t.y) < 4:
						near_door = true
			if near_door:
				break
			tiles.append(t)
		if tiles.size() >= 4:
			for i in tiles.size():
				r.props.append({"kind": "spikes", "tile": tiles[i], "phase": i * 0.18})
			return


## Rootmire dressing: glowing fungus along the walls and thickets of bramble.
## Brambles are solid (until burned or cut), so each cluster is only kept if
## every door of the room can still reach every other.
static func _root_decor(lay: Layout, r: Room, rng: RandomNumberGenerator, floor_tiles: Array[Vector2i], wall_adj: Array[Vector2i]) -> void:
	for i in (8 if r.type == Room.Type.BOSS else rng.randi_range(2, 4)):
		if wall_adj.is_empty():
			break
		var t: Vector2i = wall_adj.pop_at(rng.randi_range(0, wall_adj.size() - 1))
		r.props.append({"kind": "glowcap", "tile": t})
	if r.type == Room.Type.BOSS or r.type == Room.Type.START or floor_tiles.is_empty():
		return
	var g := lay.grid
	var taken := {}
	var solid: Array[Vector2i] = []
	for p in r.props:
		taken[p.tile] = true
	var clusters := rng.randi_range(1, 3) if r.is_combat() else rng.randi_range(0, 1)
	for c in clusters:
		for attempt in 6:
			var seed_t: Vector2i = floor_tiles[rng.randi_range(0, floor_tiles.size() - 1)]
			var cluster: Array[Vector2i] = [seed_t]
			for k in rng.randi_range(1, 4):
				var base: Vector2i = cluster[rng.randi_range(0, cluster.size() - 1)]
				cluster.append(base + DIRS[rng.randi_range(0, 3)])
			var ok := true
			for t in cluster:
				if g.at(t.x, t.y) != TileGrid.FLOOR or taken.has(t) or not r.rect.has_point(t):
					ok = false
					break
				for d in r.doors:
					for dt: Vector2i in d.tiles:
						if absi(dt.x - t.x) + absi(dt.y - t.y) < 4:
							ok = false
			# validate against every bramble placed so far, not just this cluster
			var trial: Array[Vector2i] = solid.duplicate()
			trial.append_array(cluster)
			if not ok or not _doors_connected(lay, r, trial):
				continue
			for t in cluster:
				taken[t] = true
				solid.append(t)
				r.props.append({"kind": "bramble", "tile": t})
			break


static func _doors_connected(lay: Layout, r: Room, blocked: Array[Vector2i]) -> bool:
	var g := lay.grid
	var block := {}
	for t in blocked:
		block[t] = true
	var starts: Array[Vector2i] = []
	for d in r.doors:
		if d.secret:
			continue
		var t: Vector2i = d.tiles[d.tiles.size() / 2] - Vector2i(d.dir)
		starts.append(t)
	if starts.size() < 2:
		return true
	var seen := {starts[0]: true}
	var q: Array[Vector2i] = [starts[0]]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for dd in DIRS:
			var n: Vector2i = c + dd
			if seen.has(n) or block.has(n) or not r.rect.has_point(n) or g.at(n.x, n.y) != TileGrid.FLOOR:
				continue
			seen[n] = true
			q.append(n)
	for s in starts:
		if not seen.has(s):
			return false
	return true


## The route's own rooms: on a Trial of Ash floor the largest hall of the
## main path is warded by seals (break them, or its foes shrug off most of
## every blow); on a Lost Vault floor a treasure room down a branch becomes the
## vault, held through three waves while its failing flame is kept lit.
static func _objectives(lay: Layout) -> void:
	match lay.route:
		"trial":
			var best: Room = null
			for r in lay.rooms:
				if r.type == Room.Type.COMBAT and r.id >= 2 and r.id < lay.exit_id and r.authored == "":
					if best == null or r.rect.get_area() > best.rect.get_area():
						best = r
			if best:
				best.objective = "seals"
		"vault":
			for r in lay.rooms:
				if r.type == Room.Type.TREASURE:
					r.type = Room.Type.COMBAT
					r.objective = "flame"
					break


## Prop kinds that stand on their tile and stop whoever walks into it.
const SOLID_KINDS := ["shrine", "merchant", "fountain", "hearthstone", "lore", "brazier", "boss_brazier", "sconce", "ember_well", "trial_altar", "bramble", "root_node"]


## The tiles a room's props already make solid (as Dungeon places them).
static func _solid_of(r: Room) -> Dictionary:
	var out := {}
	for pd in r.props:
		var k := String(pd.kind)
		if k == "dressing":
			if pd.get("wide", false):
				out[pd.tile] = true
				out[pd.tile + Vector2i(1, 0)] = true
			elif not WALKABLE_DRESSING.has(String(pd.sheet)):
				out[pd.tile] = true
		elif k in SOLID_KINDS:
			out[pd.tile] = true
	return out


## Would the room's floor still be one walkable piece with `more` made solid
## (on top of what its props already block)?
static func _floor_whole(lay: Layout, r: Room, more: Array[Vector2i]) -> bool:
	var g := lay.grid
	var block := _solid_of(r)
	for t in more:
		block[t] = true
	var total := 0
	var start := Vector2i(-1, -1)
	for y in range(r.rect.position.y, r.rect.end.y):
		for x in range(r.rect.position.x, r.rect.end.x):
			if g.at(x, y) == TileGrid.FLOOR and not block.has(Vector2i(x, y)):
				total += 1
				if start.x < 0:
					start = Vector2i(x, y)
	if total == 0:
		return false
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for dd in DIRS:
			var n: Vector2i = c + dd
			if seen.has(n) or block.has(n) or not r.rect.has_point(n) or g.at(n.x, n.y) != TileGrid.FLOOR:
				continue
			seen[n] = true
			q.append(n)
	return seen.size() == total


static func _prop_at(r: Room, t: Vector2i) -> bool:
	for p in r.props:
		if p.tile == t:
			return true
	return false
