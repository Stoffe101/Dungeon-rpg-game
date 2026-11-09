## Ground cover: what you walk through. One MultiMesh a room, so a floor can be thick
## with it for a handful of draw calls; a plant parts when something walks through it
## and fire burns it to stubs. Presentation only: it stops nothing, and every machine
## grows the same field from the floor's plan.
class_name FloraField
extends Node3D

const SHADER := preload("res://assets/shaders/flora.gdshader")
const PART_TIME := 0.7
const STEP := 0.08
const STATE_UP := 0.0
const STATE_PARTED := 0.5
const STATE_BURNT := 1.0

var stage: Stage
var count := 0
var _groups: Array[MultiMesh] = []
var _at: Dictionary = {}          # tile -> [[group, instance], ...]
var _custom: Array = []           # group -> each plant's custom data
var _parted: Dictionary = {}      # Vector2i(group, instance) -> seconds left
var _burnt: Dictionary = {}       # Vector2i(group, instance) -> true
var _t := 0.0


## `rooms`: Array of Array of {"pos": Vector2, "row": int, "seed": float, "flip": bool}.
func build(st: Stage, rooms: Array, tint := Color(0, 0, 0, 0)) -> void:
	stage = st
	var info := SpriteLib.get_sheet("flora_low")
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("atlas", info.texture)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("frame_uv", Vector2(1.0 / info.cols, 1.0 / info.rows))
	if ResourceLoader.exists("res://assets/sprites/flora_low_emit.png"):
		mat.set_shader_parameter("emit_atlas", load("res://assets/sprites/flora_low_emit.png"))
	var quad := info.mesh.duplicate() as QuadMesh
	quad.material = mat
	for items: Array in rooms:
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = items.size()
		var g := _groups.size()
		var customs: Array = []
		for i in items.size():
			var it: Dictionary = items[i]
			var p: Vector2 = it.pos
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Iso.to_world(p, 0.0)))
			var cu := Color(float(it.row) / 255.0, float(it.seed), STATE_UP, 1.0 if it.flip else 0.0)
			mm.set_instance_custom_data(i, cu)
			customs.append(cu)
			var t := Vector2i(floori(p.x), floori(p.y))
			if not _at.has(t):
				_at[t] = []
			_at[t].append([g, i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node)
		_groups.append(mm)
		_custom.append(customs)
		count += items.size()


func _set_state(g: int, i: int, state: float) -> void:
	var c: Color = _custom[g][i]
	if c.b == state:
		return
	c.b = state
	_custom[g][i] = c
	_groups[g].set_instance_custom_data(i, c)


## How each plant on this tile stands (STATE_*).
func state_at(t: Vector2i) -> Array:
	var out: Array = []
	for e in _at.get(t, []):
		out.append(float((_custom[e[0]][e[1]] as Color).b))
	return out


func tiles() -> Array:
	return _at.keys()


func tick(dt: float) -> void:
	_t += dt
	if not _parted.is_empty():
		for k: Vector2i in _parted.keys():
			_parted[k] = float(_parted[k]) - dt
			if float(_parted[k]) <= 0.0:
				_parted.erase(k)
				_set_state(k.x, k.y, STATE_UP)
	if _t < STEP:
		return
	_t = 0.0
	for a in stage.actors:
		if not is_instance_valid(a) or not a.alive or a.flying or a.height > 0.3:
			continue
		var t := Vector2i(floori(a.pos.x), floori(a.pos.y))
		for e in _at.get(t, []):
			var k := Vector2i(e[0], e[1])
			if _burnt.has(k):
				continue
			_parted[k] = PART_TIME
			_set_state(k.x, k.y, STATE_PARTED)


## Fire took this part of the floor: the grass is stubs from now on.
func scorch(p: Vector2, r: float) -> void:
	var c := Vector2i(floori(p.x), floori(p.y))
	var n := ceili(r)
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var t := c + Vector2i(dx, dy)
			if not _at.has(t) or (Vector2(t) + Vector2(0.5, 0.5)).distance_to(p) > r + 0.5:
				continue
			for e in _at[t]:
				var k := Vector2i(e[0], e[1])
				if _burnt.has(k):
					continue
				_burnt[k] = true
				_parted.erase(k)
				_set_state(k.x, k.y, STATE_BURNT)
