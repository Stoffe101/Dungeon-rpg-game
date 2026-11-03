## Pure-data tile map of a level. Used by collision, pathfinding, generation and
## mesh building. Coordinates are tile indices; tile (x, y) covers [x, x+1) x [y, y+1).
class_name TileGrid
extends RefCounted

enum { VOID, FLOOR, WALL, PILLAR, PIT, GATE, PROP }

var width: int
var height: int
var cells: PackedByteArray
## Room id for each tile (-1 = none); filled by the generator.
var room_of: PackedInt32Array


func _init(w: int = 1, h: int = 1) -> void:
	width = w
	height = h
	cells.resize(w * h)
	room_of.resize(w * h)
	room_of.fill(-1)


func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func at(x: int, y: int) -> int:
	if not inb(x, y):
		return VOID
	return cells[y * width + x]


func put(x: int, y: int, t: int) -> void:
	if inb(x, y):
		cells[y * width + x] = t


func room_at(x: int, y: int) -> int:
	if not inb(x, y):
		return -1
	return room_of[y * width + x]


## Floor-like tiles are those the player stands on (gates are walkable when open).
static func is_floorish(t: int) -> bool:
	return t == FLOOR or t == GATE or t == PROP


func walkable(x: int, y: int) -> bool:
	return at(x, y) == FLOOR


## Walls, pillars, void and closed gates stop movement; pits stop walking only.
func blocks_move(x: int, y: int) -> bool:
	var t := at(x, y)
	return t != FLOOR


func blocks_shot(x: int, y: int) -> bool:
	var t := at(x, y)
	return t == WALL or t == PILLAR or t == VOID or t == GATE


func is_solid_block(t: int) -> bool:
	return t == WALL or t == PILLAR


## Turns every VOID tile that touches floor (8-neighbourhood) into WALL.
func finalize_walls() -> void:
	var out := cells.duplicate()
	for y in height:
		for x in width:
			if at(x, y) != VOID:
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var t := at(x + dx, y + dy)
					if t == FLOOR or t == PIT or t == GATE or t == PROP:
						out[y * width + x] = WALL
	cells = out


## Wall height in tiles. Near (south) walls are short ledges so they never hide
## the floor behind them; everything else is a full two-tile wall.
func wall_height(x: int, y: int) -> float:
	var t := at(x, y)
	if t == PILLAR:
		return 2.0
	if t != WALL:
		return 0.0
	for k in [1, 2]:
		var n := at(x, y - k)
		if n == FLOOR or n == PIT or n == GATE or n == PROP:
			return 0.5
	return 2.0


## Line of sight for shots / AI between two plane positions (DDA over tiles).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var dist := d.length()
	if dist < 0.001:
		return true
	var steps := int(ceil(dist * 3.0))
	for i in range(1, steps + 1):
		var p := a + d * (float(i) / steps)
		if blocks_shot(floori(p.x), floori(p.y)):
			return false
	return true


## Moves a box (centre p, half-size r) by `motion`, sliding along blocking tiles.
## Resolves each axis separately; returns the new centre.
func move_box(p: Vector2, r: float, motion: Vector2, can_cross_pits := false) -> Vector2:
	var out := p
	out.x += motion.x
	if _box_hits(out, r, can_cross_pits):
		if motion.x > 0.0:
			out.x = floorf(out.x + r) - r - 0.001
		else:
			out.x = floorf(out.x - r) + 1.0 + r + 0.001
		if _box_hits(out, r, can_cross_pits):
			out.x = p.x
	out.y += motion.y
	if _box_hits(out, r, can_cross_pits):
		if motion.y > 0.0:
			out.y = floorf(out.y + r) - r - 0.001
		else:
			out.y = floorf(out.y - r) + 1.0 + r + 0.001
		if _box_hits(out, r, can_cross_pits):
			out.y = p.y
	return out


func _box_hits(p: Vector2, r: float, can_cross_pits: bool) -> bool:
	for ty in range(floori(p.y - r), floori(p.y + r) + 1):
		for tx in range(floori(p.x - r), floori(p.x + r) + 1):
			var t := at(tx, ty)
			if t == FLOOR:
				continue
			if t == PIT and can_cross_pits:
				continue
			return true
	return false


func box_blocked(p: Vector2, r: float) -> bool:
	return _box_hits(p, r, false)
