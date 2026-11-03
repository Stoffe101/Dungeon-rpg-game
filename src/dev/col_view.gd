## Dev (`showcol`): every tile a Kindled cannot walk onto is drawn as a red
## square on the floor (pits blue), and each Kindled's collision box green,
## so collision footprints can be checked against the art in a capture.
class_name ColView
extends Node3D


static func attach(st: Stage) -> void:
	var v := ColView.new()
	v.name = "ColView"
	st.add_child(v)
	v._build(st)


func _build(st: Stage) -> void:
	var g := st.grid
	for y in g.height:
		for x in g.width:
			var t := g.at(x, y)
			if t == TileGrid.FLOOR or t == TileGrid.VOID:
				continue
			if t == TileGrid.WALL and not _touches_floor(g, x, y):
				continue
			var col := Color(0.3, 0.5, 1.0, 0.35) if t == TileGrid.PIT else Color(1.0, 0.15, 0.1, 0.38)
			_quad(Iso.to_world(Vector2(x + 0.5, y + 0.5), 0.0) + Vector3(0, 0.03, 0), Vector2(0.96, 0.96), col)
	for pl in st.players:
		var r := pl.box()
		var q := _quad(Vector3(0, 0.04, 0), Vector2(r * 2.0, r * 2.0), Color(0.3, 1.0, 0.4, 0.6))
		q.reparent(pl, false)


func _touches_floor(g: TileGrid, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if g.at(x + dx, y + dy) == TileGrid.FLOOR:
				return true
	return false


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
