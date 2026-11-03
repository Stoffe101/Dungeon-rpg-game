## Builds the 3D presentation of a TileGrid: floors, wall faces, wall tops,
## ledges and pits as chunked meshes with world-aligned pixel-art UVs.
class_name LevelBuilder
extends RefCounted

const WORLD_SHADER := preload("res://assets/shaders/world.gdshader")
const CHUNK := 24
const PIT_DEPTH := 2.5

static var _mats: Dictionary = {}


class LevelTheme:
	var floor_tex: Texture2D
	var wall_tex: Texture2D
	var top_tex: Texture2D
	var ledge_tex: Texture2D
	var pit_tex: Texture2D
	var pillar_tex: Texture2D
	var floor_tint := Color.WHITE
	var wall_tint := Color.WHITE
	var grime := 0.0
	var grime_color := Color(0.35, 0.3, 0.32)

	static func named(n: String) -> LevelTheme:
		var t := LevelTheme.new()
		t.floor_tex = load("res://assets/textures/%s_floor.png" % n)
		t.wall_tex = load("res://assets/textures/%s_wall.png" % n)
		t.top_tex = load("res://assets/textures/%s_top.png" % n)
		t.ledge_tex = load("res://assets/textures/%s_ledge.png" % n)
		t.pit_tex = load("res://assets/textures/pit.png")
		t.pillar_tex = load("res://assets/textures/%s_pillar.png" % n)
		match n:
			"crypt":
				t.grime = 0.55
				t.grime_color = Color(0.45, 0.42, 0.5)
			"root":
				t.grime = 0.5
				t.grime_color = Color(0.5, 0.6, 0.42)
			"throne":
				t.grime = 0.45
				t.grime_color = Color(0.55, 0.5, 0.48)
			"hearth":
				t.grime = 0.4
				t.grime_color = Color(0.6, 0.48, 0.42)
		return t


static func material(tex: Texture2D, tint := Color.WHITE) -> ShaderMaterial:
	var key := "%s|%s" % [tex.resource_path, tint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	_mats[key] = m
	return m


static func build(grid: TileGrid, theme: LevelTheme) -> Node3D:
	var root := Node3D.new()
	root.name = "Level"
	var cx_n := int(ceil(grid.width / float(CHUNK)))
	var cy_n := int(ceil(grid.height / float(CHUNK)))
	var mats := {
		"floor": material(theme.floor_tex, theme.floor_tint),
		"wall": material(theme.wall_tex, theme.wall_tint),
		"top": material(theme.top_tex, theme.wall_tint),
		"ledge": material(theme.ledge_tex, theme.wall_tint),
		"pit": material(theme.pit_tex),
		"pillar": material(theme.pillar_tex, theme.wall_tint),
	}
	(mats.floor as ShaderMaterial).set_shader_parameter("grime", theme.grime)
	(mats.floor as ShaderMaterial).set_shader_parameter("grime_color", theme.grime_color)
	var tex_sizes := {
		"floor": theme.floor_tex.get_size(),
		"wall": theme.wall_tex.get_size(),
		"top": theme.top_tex.get_size(),
		"ledge": theme.ledge_tex.get_size(),
		"pit": theme.pit_tex.get_size(),
		"pillar": theme.pillar_tex.get_size(),
	}
	for cy in cy_n:
		for cx in cx_n:
			var tools := {}
			for k in mats:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[k] = {"st": st, "n": 0}
			for y in range(cy * CHUNK, mini((cy + 1) * CHUNK, grid.height)):
				for x in range(cx * CHUNK, mini((cx + 1) * CHUNK, grid.width)):
					_emit_tile(grid, x, y, tools, tex_sizes)
			for k in tools:
				if tools[k].n == 0:
					continue
				var st: SurfaceTool = tools[k].st
				st.set_material(mats[k])
				var mi := MeshInstance3D.new()
				mi.mesh = st.commit()
				mi.name = "%s_%d_%d" % [k, cx, cy]
				if k == "floor" or k == "pit":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				else:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				root.add_child(mi)
	return root


static func _quad(t: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	# a-b-c-d are given counter-clockwise as seen from the normal side; Godot's
	# front faces are clockwise, so emit them reversed.
	var st: SurfaceTool = t.st
	for v in [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])
	t.n += 1


static func _emit_tile(grid: TileGrid, x: int, y: int, tools: Dictionary, ts: Dictionary) -> void:
	var t := grid.at(x, y)
	var S := Iso.SQ2
	var x0 := float(x)
	var x1 := float(x + 1)
	var z0 := y * S
	var z1 := (y + 1) * S
	if t == TileGrid.FLOOR or t == TileGrid.GATE or t == TileGrid.PROP:
		var fs: Vector2 = ts.floor
		var u0 := x * 16.0 / fs.x
		var u1 := (x + 1) * 16.0 / fs.x
		var v0 := y * 16.0 / fs.y
		var v1 := (y + 1) * 16.0 / fs.y
		_quad(tools.floor, Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3.UP,
			Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0))
	elif t == TileGrid.PIT:
		var depth := -PIT_DEPTH * S
		var ps: Vector2 = ts.pit
		_quad(tools.pit, Vector3(x0, depth, z0), Vector3(x0, depth, z1), Vector3(x1, depth, z1), Vector3(x1, depth, z0), Vector3.UP,
			Vector2(x * 16.0 / ps.x, y * 16.0 / ps.y), Vector2(x * 16.0 / ps.x, (y + 1) * 16.0 / ps.y),
			Vector2((x + 1) * 16.0 / ps.x, (y + 1) * 16.0 / ps.y), Vector2((x + 1) * 16.0 / ps.x, y * 16.0 / ps.y))
		# the far (north) inner wall of the pit faces the camera
		if grid.at(x, y - 1) != TileGrid.PIT:
			var ws: Vector2 = ts.wall
			var u0 := x * 16.0 / ws.x
			var u1 := (x + 1) * 16.0 / ws.x
			_quad(tools.wall, Vector3(x0, 0, z0), Vector3(x0, depth, z0), Vector3(x1, depth, z0), Vector3(x1, 0, z0), Vector3.BACK,
				Vector2(u0, 0.0), Vector2(u0, PIT_DEPTH / 2.0), Vector2(u1, PIT_DEPTH / 2.0), Vector2(u1, 0.0))
	elif t == TileGrid.WALL or t == TileGrid.PILLAR:
		var hh := grid.wall_height(x, y)
		var top := hh * S
		var tsz: Vector2 = ts.top
		_quad(tools.top, Vector3(x0, top, z0), Vector3(x0, top, z1), Vector3(x1, top, z1), Vector3(x1, top, z0), Vector3.UP,
			Vector2(x * 16.0 / tsz.x, y * 16.0 / tsz.y), Vector2(x * 16.0 / tsz.x, (y + 1) * 16.0 / tsz.y),
			Vector2((x + 1) * 16.0 / tsz.x, (y + 1) * 16.0 / tsz.y), Vector2((x + 1) * 16.0 / tsz.x, y * 16.0 / tsz.y))
		var key := "wall" if hh > 1.0 else "ledge"
		if t == TileGrid.PILLAR:
			key = "pillar"
		var fsz: Vector2 = ts[key]
		var u0 := x * 16.0 / fsz.x
		var u1 := (x + 1) * 16.0 / fsz.x
		if key == "pillar":
			u0 = 0.0
			u1 = 1.0
		var vb := 1.0
		# south face (toward camera) unless hidden by an equally tall neighbour
		var sn := grid.at(x, y + 1)
		if not (grid.is_solid_block(sn) and grid.wall_height(x, y + 1) >= hh):
			_quad(tools[key], Vector3(x0, top, z1), Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, top, z1), Vector3.BACK,
				Vector2(u0, 0.0), Vector2(u0, vb), Vector2(u1, vb), Vector2(u1, 0.0))
		# hidden faces: still built so lantern shadows are watertight
		if not grid.is_solid_block(grid.at(x, y - 1)):
			_quad(tools[key], Vector3(x1, top, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(x0, top, z0), Vector3.FORWARD,
				Vector2(u1, 0.0), Vector2(u1, vb), Vector2(u0, vb), Vector2(u0, 0.0))
		if not grid.is_solid_block(grid.at(x - 1, y)):
			_quad(tools[key], Vector3(x0, top, z0), Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x0, top, z1), Vector3.LEFT,
				Vector2(0.0, 0.0), Vector2(0.0, vb), Vector2(0.25, vb), Vector2(0.25, 0.0))
		if not grid.is_solid_block(grid.at(x + 1, y)):
			_quad(tools[key], Vector3(x1, top, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x1, top, z0), Vector3.RIGHT,
				Vector2(0.0, 0.0), Vector2(0.0, vb), Vector2(0.25, vb), Vector2(0.25, 0.0))
