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


## A near wall's height. It was half a tile: the camera looks over it, so its cap covered
## the last half tile of floor and you were stopped half a tile past where it seemed to
## begin, your feet behind it.
const LOW_WALL := 0.25


## Wall height in tiles. Near (south) walls are short ledges so they never hide
## the floor behind them; everything else is a full two-tile wall. A wall
## standing inside a room (a central block, a broken wall) is a waist-high
## block: plainly solid, never mistaken for a step (it was an 8-px ledge that
## read as one), and low enough to see the fight beyond it.
func wall_height(x: int, y: int) -> float:
	var t := at(x, y)
	if t == PILLAR:
		return 2.0
	if t != WALL:
		return 0.0
	if room_of[y * width + x] >= 0:
		return 1.0
	for k in [1, 2]:
		var n := at(x, y - k)
		if n == FLOOR or n == PIT or n == GATE or n == PROP:
			return LOW_WALL
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
	if _on_prop(p, r):
		return _walk_off(p, r, motion, can_cross_pits)
	var out := p
	out.x += motion.x
	var x_blocked := false
	if _box_hits(out, r, can_cross_pits):
		x_blocked = true
		if motion.x > 0.0:
			out.x = floorf(out.x + r) - r - 0.001
		else:
			out.x = floorf(out.x - r) + 1.0 + r + 0.001
		if _box_hits(out, r, can_cross_pits):
			out.x = p.x
	out.y += motion.y
	var y_blocked := false
	if _box_hits(out, r, can_cross_pits):
		y_blocked = true
		if motion.y > 0.0:
			out.y = floorf(out.y + r) - r - 0.001
		else:
			out.y = floorf(out.y - r) + 1.0 + r + 0.001
		if _box_hits(out, r, can_cross_pits):
			out.y = p.y
	# rounding corners: walking along one axis into the very edge of a block
	# (a hair of the box on it) slides around it instead of stopping dead
	if x_blocked and absf(motion.x) > absf(motion.y) and absf(out.x - p.x) < absf(motion.x) * 0.5:
		out = _round_corner(out, r, Vector2(signf(motion.x), 0.0), absf(motion.x), can_cross_pits)
	elif y_blocked and absf(motion.y) > absf(motion.x) and absf(out.y - p.y) < absf(motion.y) * 0.5:
		out = _round_corner(out, r, Vector2(0.0, signf(motion.y)), absf(motion.y), can_cross_pits)
	return out


const CORNER := 0.26


## The box was stopped going along `dir`: if sliding sideways by at most
## CORNER frees the way, slide (no faster than the walk itself).
func _round_corner(p: Vector2, r: float, dir: Vector2, step: float, cross: bool) -> Vector2:
	var side := Vector2(dir.y, dir.x)     # the other axis
	var k := 0 if side.x != 0.0 else 1   # (index of the other axis)
	var best := p
	var best_need := INF
	for s in [1.0, -1.0]:
		var c: float = p[k]
		var edge: float = (floorf(c - r) + 1.0 + r + 0.001) if s > 0.0 else (floorf(c + r) - r - 0.001)
		var need := absf(edge - c)
		if need <= 0.0005 or need > CORNER or need >= best_need:
			continue
		var q := p
		q[k] = edge
		if _box_hits(q, r, cross) or _box_hits(q + dir * 0.05, r, cross):
			continue
		best_need = need
		best = p
		best[k] = move_toward(c, edge, step)
	if best_need < INF and not _box_hits(best, r, cross):
		return best
	return p


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


## Something solid appeared on top of this box (a chest out of a won fight, a wall of
## ice): nobody is ever trapped in a prop. They walk off it; walls still stop them, and no
## step may take them further into it (a position rounded on its way across the network
## sits a hair inside one: that must not become a way through).
func _on_prop(p: Vector2, r: float) -> bool:
	return _prop_overlap(p, r) > 0.0


func _prop_overlap(p: Vector2, r: float) -> float:
	var total := 0.0
	for ty in range(floori(p.y - r), floori(p.y + r) + 1):
		for tx in range(floori(p.x - r), floori(p.x + r) + 1):
			if at(tx, ty) == PROP:
				var ox := minf(p.x + r, tx + 1.0) - maxf(p.x - r, float(tx))
				var oy := minf(p.y + r, ty + 1.0) - maxf(p.y - r, float(ty))
				total += maxf(0.0, ox) * maxf(0.0, oy)
	return total


func _walk_off(p: Vector2, r: float, motion: Vector2, cross: bool) -> Vector2:
	var out := p + motion
	for ty in range(floori(out.y - r), floori(out.y + r) + 1):
		for tx in range(floori(out.x - r), floori(out.x + r) + 1):
			var t := at(tx, ty)
			if t != FLOOR and t != PROP and not (t == PIT and cross):
				return p
	if _prop_overlap(out, r) > _prop_overlap(p, r) + 0.0001:
		# (one axis at a time, so a step along the edge of what it touches still slides)
		var a := Vector2(p.x + motion.x, p.y)
		if _prop_overlap(a, r) <= _prop_overlap(p, r) + 0.0001:
			return a
		var b := Vector2(p.x, p.y + motion.y)
		if _prop_overlap(b, r) <= _prop_overlap(p, r) + 0.0001:
			return b
		return p
	return out


func box_blocked(p: Vector2, r: float) -> bool:
	return _box_hits(p, r, false)
