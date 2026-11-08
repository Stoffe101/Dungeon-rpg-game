## Dev (`showcol`): what the world really does, drawn over what it looks like.
##   red      walls, closed gates (and rock)      blue     pits
##   orange   solid props                         yellow   solid until broken
##   green    walkable decoration (outline)       magenta  a hazard's real danger area
##   cyan     where something can be used from    white    a door's opening
##   purple   floor nobody can reach from the start of the floor
## Each Kindled's and foe's collision box follows it. Debug builds only.
class_name ColView
extends Node3D

const COLS := {
	"wall": Color(1.0, 0.15, 0.1, 0.38), "pit": Color(0.3, 0.5, 1.0, 0.35), "solid": Color(1.0, 0.55, 0.1, 0.5),
	"break": Color(1.0, 0.95, 0.2, 0.5), "walk": Color(0.35, 1.0, 0.45, 0.7), "hazard": Color(1.0, 0.2, 0.9, 0.5),
	"use": Color(0.3, 0.95, 1.0, 0.6), "door": Color(1.0, 1.0, 1.0, 0.45), "lost": Color(0.7, 0.2, 1.0, 0.6),
	"me": Color(0.3, 1.0, 0.4, 0.6), "foe": Color(1.0, 0.85, 0.85, 0.5),
}


static func attach(st: Stage) -> void:
	var v := ColView.new()
	v.name = "ColView"
	st.add_child(v)
	v._build(st)


func _build(st: Stage) -> void:
	var g := st.grid
	var by_prop := {}
	for pr in st.props:
		if is_instance_valid(pr):
			for t: Vector2i in pr._solid_tiles:
				by_prop[t] = pr
	var reach := reachable(st)
	for y in g.height:
		for x in g.width:
			var t := g.at(x, y)
			var p := Vector2i(x, y)
			if t == TileGrid.FLOOR:
				if not reach.is_empty() and not reach.has(p):
					_tile(p, COLS.lost)
				continue
			if t == TileGrid.VOID or (t == TileGrid.WALL and not _touches_floor(g, x, y)):
				continue
			if by_prop.has(p):
				_tile(p, COLS["break"] if by_prop[p].breakable else COLS.solid)
			elif t == TileGrid.PROP:
				_tile(p, COLS.solid)
			elif t == TileGrid.PIT:
				_tile(p, COLS.pit)
			else:
				_tile(p, COLS.wall)
	for pr in st.props:
		if not is_instance_valid(pr):
			continue
		var w := Vector2(pr.pos)
		if pr.kind == "spikes":
			_quad(Iso.to_world(w, 0.0) + Vector3(0, 0.05, 0), Vector2(Prop.SPIKE_REACH * 2.0, Prop.SPIKE_REACH * 2.0), COLS.hazard)
		elif pr.kind == "urn" or (pr._solid_tiles.is_empty() and pr.kind in ["candles", "ember_pile"]):
			_frame(Iso.to_world(w, 0.0), Vector2(0.7, 0.7), COLS.walk)
		if pr.interactable():
			_frame(Iso.to_world(w, 0.0), Vector2(pr.interact_radius * 1.6, pr.interact_radius * 1.6), COLS.use)
	if st.flora:
		for t: Vector2i in st.flora.tiles():
			_frame(Iso.to_world(Vector2(t) + Vector2(0.5, 0.5), 0.0), Vector2(0.46, 0.46), COLS.walk)
	if st is Dungeon:
		for r in (st as Dungeon).layout.rooms:
			for d in r.doors:
				for t: Vector2i in d.tiles:
					_frame(Iso.to_world(Vector2(t) + Vector2(0.5, 0.5), 0.0), Vector2(0.8, 0.8), COLS.door)
	_legend()


func _process(_dt: float) -> void:
	var st := get_parent() as Stage
	if st == null:
		return
	for a in st.actors:
		if is_instance_valid(a) and not a.has_meta("colbox"):
			var r: float = a.box()
			var q := _quad(Vector3(0, 0.04, 0), Vector2(r * 2.0, r * 2.0), COLS.me if a is Player else COLS.foe)
			q.reparent(a, false)
			a.set_meta("colbox", true)


## The floor a Kindled's real box can get to from the start of the floor (by walking,
## in quarter-tile steps through the same code that moves it); {} on a non-dungeon.
static func reachable(st: Stage) -> Dictionary:
	if not (st is Dungeon) or st.player == null:
		return {}
	return flood(st.grid, st.player.pos, st.player.box())


static func flood(g: TileGrid, from: Vector2, r: float) -> Dictionary:
	var seen := {}
	var tiles := {}
	var q: Array[Vector2] = [from]
	var step := 0.25
	seen[Vector2i((from / step).floor())] = true
	while not q.is_empty():
		var c: Vector2 = q.pop_back()
		tiles[Vector2i(floori(c.x), floori(c.y))] = true
		for d: Vector2 in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
			var n: Vector2 = g.move_box(c, r, d)
			if n.distance_to(c + d) > 0.01:
				continue
			var k := Vector2i((n / step).floor())
			if not seen.has(k):
				seen[k] = true
				q.append(n)
	return tiles


func _legend() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 70)
	layer.add_child(box)
	for row in [["wall", "wall / gate"], ["pit", "pit"], ["solid", "solid prop"], ["break", "solid until broken"], ["walk", "walkable decoration"],
			["hazard", "hazard area"], ["use", "usable from here"], ["door", "door"], ["lost", "unreachable floor"]]:
		var l := Label.new()
		l.text = String(row[1])
		var c: Color = COLS[row[0]]
		l.add_theme_color_override("font_color", Color(c.r, c.g, c.b, 1.0))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_font_size_override("font_size", 8)
		box.add_child(l)


func _touches_floor(g: TileGrid, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if g.at(x + dx, y + dy) == TileGrid.FLOOR:
				return true
	return false


func _tile(t: Vector2i, col: Color) -> void:
	_quad(Iso.to_world(Vector2(t) + Vector2(0.5, 0.5), 0.0) + Vector3(0, 0.03, 0), Vector2(0.96, 0.96), col)


## Four thin bars: an outline, so what is under it stays visible.
func _frame(at: Vector3, size: Vector2, col: Color) -> void:
	var y := Vector3(0, 0.035, 0)
	var t := 0.05
	_quad(at + y + Vector3(0, 0, -size.y * 0.5 * Iso.SQ2), Vector2(size.x, t), col)
	_quad(at + y + Vector3(0, 0, size.y * 0.5 * Iso.SQ2), Vector2(size.x, t), col)
	_quad(at + y + Vector3(-size.x * 0.5, 0, 0), Vector2(t, size.y), col)
	_quad(at + y + Vector3(size.x * 0.5, 0, 0), Vector2(t, size.y), col)


func _quad(at: Vector3, size: Vector2, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.y * Iso.SQ2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.no_depth_test = true
	mat.render_priority = 10
	pm.material = mat
	m.mesh = pm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	add_child(m)
	return m
