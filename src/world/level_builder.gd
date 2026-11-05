## Builds the 3D presentation of a TileGrid: floors, wall faces, wall tops,
## ledges and pits as chunked meshes with world-aligned pixel-art UVs.
##
## The surfaces carry what the shader needs to make the dungeon's grammar
## readable (world.gdshader): a floor knows which of its edges touch something
## solid (a wall, a pillar, a solid prop: a contact shadow there) or a pit (a lit
## lip); a wall's cap knows which of its edges are open (a bright rim: "this is
## the top of something you cannot walk through") and how deep it sits inside
## the rock (thick walls darken toward their middle instead of reading as a
## raised floor); a wall's face knows its height (dark at the foot, a lip at the
## top). Every wall face is masonry, bottom-anchored at the texture's own scale.
class_name LevelBuilder
extends RefCounted

const WORLD_SHADER := preload("res://assets/shaders/world.gdshader")
const CHUNK := 24
const PIT_DEPTH := 2.5
const SURFACE := {"floor": 0, "top": 1, "wall": 2, "ledge": 2, "pillar": 2, "pit": 3}
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
const MASS_MAX := 6

static var _mats: Dictionary = {}
static var _mids: Dictionary = {}


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
	var floor_contrast := 0.74      # floors quieter than what stands on them
	var rim := Color(0.5, 0.52, 0.62)   # the dressed stone of a wall's cap edge

	## `depth_k`: which of the region's three depths (1-3): the second and third
	## have their own floor and wall faces where they exist (tools/art/gen_depths.gd).
	static func named(n: String, depth_k := 1) -> LevelTheme:
		var t := LevelTheme.new()
		var fv := "res://assets/textures/%s_floor_d%d.png" % [n, depth_k]
		var wv := "res://assets/textures/%s_wall_d%d.png" % [n, depth_k]
		t.floor_tex = load(fv if depth_k > 1 and ResourceLoader.exists(fv) else "res://assets/textures/%s_floor.png" % n)
		t.wall_tex = load(wv if depth_k > 1 and ResourceLoader.exists(wv) else "res://assets/textures/%s_wall.png" % n)
		t.top_tex = load("res://assets/textures/%s_top.png" % n)
		t.ledge_tex = load("res://assets/textures/%s_ledge.png" % n)
		t.pit_tex = load("res://assets/textures/pit.png")
		t.pillar_tex = load("res://assets/textures/%s_pillar.png" % n)
		match n:
			"crypt":
				t.grime = 0.55
				t.grime_color = Color(0.45, 0.42, 0.5)
				t.rim = Color(0.5, 0.54, 0.66)
			"root":
				t.grime = 0.5
				t.grime_color = Color(0.5, 0.6, 0.42)
				t.rim = Color(0.44, 0.54, 0.36)
			"throne":
				t.grime = 0.45
				t.grime_color = Color(0.55, 0.5, 0.48)
				t.rim = Color(0.7, 0.6, 0.44)
			"hearth":
				t.grime = 0.4
				t.grime_color = Color(0.6, 0.48, 0.42)
				t.rim = Color(0.62, 0.48, 0.4)
				t.floor_contrast = 0.85
		return t


static func material(tex: Texture2D, tint := Color.WHITE, surface := 0) -> ShaderMaterial:
	var key := "%s|%s|%d" % [tex.resource_path, tint.to_html(), surface]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("surface", surface)
	_mats[key] = m
	return m


## The texture's average colour (what a floor's contrast is eased toward).
static func mid_of(tex: Texture2D) -> Color:
	if _mids.has(tex.resource_path):
		return _mids[tex.resource_path]
	var img := tex.get_image()
	var acc := Color(0, 0, 0, 0)
	var n := 0
	if img:
		if img.is_compressed():
			img.decompress()
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				acc += Color(c.r, c.g, c.b, 0.0)
				n += 1
	var mid := Color(acc.r / maxf(n, 1), acc.g / maxf(n, 1), acc.b / maxf(n, 1))
	_mids[tex.resource_path] = mid
	return mid


static func build(grid: TileGrid, theme: LevelTheme) -> Node3D:
	var root := Node3D.new()
	root.name = "Level"
	var cx_n := int(ceil(grid.width / float(CHUNK)))
	var cy_n := int(ceil(grid.height / float(CHUNK)))
	var mats := {
		"floor": material(theme.floor_tex, theme.floor_tint, SURFACE.floor),
		"wall": material(theme.wall_tex, theme.wall_tint, SURFACE.wall),
		"top": material(theme.top_tex, theme.wall_tint, SURFACE.top),
		"ledge": material(theme.ledge_tex, theme.wall_tint, SURFACE.ledge),
		"pit": material(theme.pit_tex, Color.WHITE, SURFACE.pit),
		"pillar": material(theme.pillar_tex, theme.wall_tint, SURFACE.pillar),
		"pitwall": material(theme.wall_tex, theme.wall_tint, SURFACE.pit),
	}
	var fm := mats.floor as ShaderMaterial
	fm.set_shader_parameter("grime", theme.grime)
	fm.set_shader_parameter("grime_color", theme.grime_color)
	fm.set_shader_parameter("contrast", theme.floor_contrast)
	fm.set_shader_parameter("mid", mid_of(theme.floor_tex))
	for k in ["top", "pitwall"]:
		(mats[k] as ShaderMaterial).set_shader_parameter("rim_color", theme.rim)
	var tex_sizes := {
		"floor": theme.floor_tex.get_size(),
		"wall": theme.wall_tex.get_size(),
		"top": theme.top_tex.get_size(),
		"ledge": theme.ledge_tex.get_size(),
		"pit": theme.pit_tex.get_size(),
		"pillar": theme.pillar_tex.get_size(),
		"pitwall": theme.wall_tex.get_size(),
	}
	var mass := mass_depth(grid)
	for cy in cy_n:
		for cx in cx_n:
			var tools := {}
			for k in mats:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[k] = {"st": st, "n": 0}
			for y in range(cy * CHUNK, mini((cy + 1) * CHUNK, grid.height)):
				for x in range(cx * CHUNK, mini((cx + 1) * CHUNK, grid.width)):
					_emit_tile(grid, x, y, tools, tex_sizes, mass)
			for k in tools:
				if tools[k].n == 0:
					continue
				var st: SurfaceTool = tools[k].st
				st.set_material(mats[k])
				var mi := MeshInstance3D.new()
				mi.mesh = st.commit()
				mi.name = "%s_%d_%d" % [k, cx, cy]
				if k == "floor" or k == "pit" or k == "pitwall":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				else:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				root.add_child(mi)
	return root


## Something a floor's edge meets that stands up from it: a contact shadow.
static func blocks(t: int) -> bool:
	return t == TileGrid.WALL or t == TileGrid.PILLAR or t == TileGrid.PROP


## Open ground beside a wall's cap (its rim lights up on that side).
static func open(t: int) -> bool:
	return t == TileGrid.FLOOR or t == TileGrid.PIT or t == TileGrid.GATE or t == TileGrid.PROP


## How many tiles each solid tile sits inside the rock (1 = it touches open
## ground, counted 8-ways; open tiles are 0; capped at MASS_MAX).
static func mass_depth(grid: TileGrid) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(grid.width * grid.height)
	d.fill(MASS_MAX)
	var q: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			if open(grid.at(x, y)):
				d[y * grid.width + x] = 0
				q.append(Vector2i(x, y))
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		var nd := d[p.y * grid.width + p.x] + 1
		if nd >= MASS_MAX:
			continue
		for dir: Vector2i in DIRS:
			var n := p + dir
			if not grid.inb(n.x, n.y):
				continue
			var i := n.y * grid.width + n.x
			if d[i] > nd:
				d[i] = nd
				q.append(n)
	return d


static func _mass_at(grid: TileGrid, mass: PackedByteArray, x: int, y: int) -> int:
	if not grid.inb(x, y):
		return MASS_MAX
	return mass[y * grid.width + x]


## A corner's depth into the rock: the least of the four tiles around it.
static func _corner(grid: TileGrid, mass: PackedByteArray, cx: int, cy: int) -> float:
	var m := MASS_MAX
	for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		m = mini(m, _mass_at(grid, mass, cx + o.x, cy + o.y))
	return float(m) / MASS_MAX


static func _quad(t: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
		u2 := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], cols := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]) -> void:
	# a-b-c-d are given counter-clockwise as seen from the normal side; Godot's
	# front faces are clockwise, so emit them reversed.
	var st: SurfaceTool = t.st
	for v in [[a, ua, 0], [c, uc, 2], [b, ub, 1], [a, ua, 0], [d, ud, 3], [c, uc, 2]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.set_uv2(u2[v[2]])
		st.set_color(cols[v[2]])
		st.add_vertex(v[0])
	t.n += 1


static func _emit_tile(grid: TileGrid, x: int, y: int, tools: Dictionary, ts: Dictionary, mass: PackedByteArray) -> void:
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
		# what each edge meets: solids (8 ways) and pits (4 ways)
		var sb := 0
		for i in DIRS.size():
			if blocks(grid.at(x + DIRS[i].x, y + DIRS[i].y)):
				sb |= 1 << i
		var pb := 0
		for i in 4:
			if grid.at(x + DIRS[i].x, y + DIRS[i].y) == TileGrid.PIT:
				pb |= 1 << i
		var e := Vector2(sb, pb)
		_quad(tools.floor, Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3.UP,
			Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), [e, e, e, e])
	elif t == TileGrid.PIT:
		var depth := -PIT_DEPTH * S
		var ps: Vector2 = ts.pit
		_quad(tools.pit, Vector3(x0, depth, z0), Vector3(x0, depth, z1), Vector3(x1, depth, z1), Vector3(x1, depth, z0), Vector3.UP,
			Vector2(x * 16.0 / ps.x, y * 16.0 / ps.y), Vector2(x * 16.0 / ps.x, (y + 1) * 16.0 / ps.y),
			Vector2((x + 1) * 16.0 / ps.x, (y + 1) * 16.0 / ps.y), Vector2((x + 1) * 16.0 / ps.x, y * 16.0 / ps.y),
			[Vector2(0, 1), Vector2(0, 1), Vector2(0, 1), Vector2(0, 1)])
		# the far (north) inner wall of the pit faces the camera
		if grid.at(x, y - 1) != TileGrid.PIT:
			var ws: Vector2 = ts.wall
			var u0 := x * 16.0 / ws.x
			var u1 := (x + 1) * 16.0 / ws.x
			_quad(tools.pitwall, Vector3(x0, 0, z0), Vector3(x0, depth, z0), Vector3(x1, depth, z0), Vector3(x1, 0, z0), Vector3.BACK,
				Vector2(u0, 0.0), Vector2(u0, PIT_DEPTH / 2.0), Vector2(u1, PIT_DEPTH / 2.0), Vector2(u1, 0.0),
				[Vector2(PIT_DEPTH, 0), Vector2(PIT_DEPTH, 1), Vector2(PIT_DEPTH, 1), Vector2(PIT_DEPTH, 0)])
	elif t == TileGrid.WALL or t == TileGrid.PILLAR:
		var hh := grid.wall_height(x, y)
		var top := hh * S
		var tsz: Vector2 = ts.top
		# the cap: which edges are open (a rim), how deep each corner sits in the rock
		var ob := 0
		for i in DIRS.size():
			if open(grid.at(x + DIRS[i].x, y + DIRS[i].y)):
				ob |= 1 << i
		var cap := Vector2(ob, hh)
		var c00 := _corner(grid, mass, x, y)
		var c01 := _corner(grid, mass, x, y + 1)
		var c11 := _corner(grid, mass, x + 1, y + 1)
		var c10 := _corner(grid, mass, x + 1, y)
		_quad(tools.top, Vector3(x0, top, z0), Vector3(x0, top, z1), Vector3(x1, top, z1), Vector3(x1, top, z0), Vector3.UP,
			Vector2(x * 16.0 / tsz.x, y * 16.0 / tsz.y), Vector2(x * 16.0 / tsz.x, (y + 1) * 16.0 / tsz.y),
			Vector2((x + 1) * 16.0 / tsz.x, (y + 1) * 16.0 / tsz.y), Vector2((x + 1) * 16.0 / tsz.x, y * 16.0 / tsz.y),
			[cap, cap, cap, cap], [Color(c00, 0, 0), Color(c01, 0, 0), Color(c11, 0, 0), Color(c10, 0, 0)])
		# every wall face is masonry at the texture's own scale, anchored at the
		# foot (a low wall shows the bottom courses: no stretched trim strip)
		var key := "wall"
		if t == TileGrid.PILLAR:
			key = "pillar"
		var fsz: Vector2 = ts[key]
		var u0 := x * 16.0 / fsz.x
		var u1 := (x + 1) * 16.0 / fsz.x
		var va := 1.0 - minf(hh * 16.0 / fsz.y, 1.0)
		var vb := 1.0
		if key == "pillar":
			u0 = 0.0
			u1 = 1.0
			va = 0.0
		var fu := [Vector2(hh, 0), Vector2(hh, 1), Vector2(hh, 1), Vector2(hh, 0)]
		# south face (toward camera) unless hidden by an equally tall neighbour
		var sn := grid.at(x, y + 1)
		if not (grid.is_solid_block(sn) and grid.wall_height(x, y + 1) >= hh):
			_quad(tools[key], Vector3(x0, top, z1), Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, top, z1), Vector3.BACK,
				Vector2(u0, va), Vector2(u0, vb), Vector2(u1, vb), Vector2(u1, va), fu)
		# hidden faces: still built so lantern shadows are watertight
		if not grid.is_solid_block(grid.at(x, y - 1)):
			_quad(tools[key], Vector3(x1, top, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(x0, top, z0), Vector3.FORWARD,
				Vector2(u1, va), Vector2(u1, vb), Vector2(u0, vb), Vector2(u0, va), fu)
		if not grid.is_solid_block(grid.at(x - 1, y)):
			_quad(tools[key], Vector3(x0, top, z0), Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x0, top, z1), Vector3.LEFT,
				Vector2(0.0, va), Vector2(0.0, vb), Vector2(0.25, vb), Vector2(0.25, va), fu)
		if not grid.is_solid_block(grid.at(x + 1, y)):
			_quad(tools[key], Vector3(x1, top, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x1, top, z0), Vector3.RIGHT,
				Vector2(0.0, va), Vector2(0.0, vb), Vector2(0.25, vb), Vector2(0.25, va), fu)
