## Loads generated sprite sheets (PNG + JSON sidecar) and caches one shared
## ShaderMaterial and quad mesh per sheet.
class_name SpriteLib
extends RefCounted

const SPRITE_SHADER := preload("res://assets/shaders/sprite.gdshader")

static var _sheets: Dictionary = {}


class SheetInfo:
	var name: String
	var texture: Texture2D
	var frame_size: Vector2i
	var origin: Vector2i
	var cols: int
	var rows: int
	var anims: Dictionary
	var material: ShaderMaterial
	var mesh: QuadMesh


static func get_sheet(sheet_name: String) -> SheetInfo:
	if _sheets.has(sheet_name):
		return _sheets[sheet_name]
	var t_load := Dev.tick()
	var base := "res://assets/sprites/" + sheet_name
	var info := SheetInfo.new()
	info.name = sheet_name
	info.texture = load(base + ".png")
	var meta: Dictionary = {}
	if FileAccess.file_exists(base + ".json"):
		meta = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if meta.is_empty():
		var sz := info.texture.get_size()
		meta = {"frame": [sz.x, sz.y], "origin": [sz.x / 2, sz.y], "anims": {"idle": {"row": 0, "frames": 1, "fps": 1, "loop": true}}}
	info.frame_size = Vector2i(int(meta.frame[0]), int(meta.frame[1]))
	info.origin = Vector2i(int(meta.origin[0]), int(meta.origin[1]))
	info.anims = meta.anims
	info.cols = int(info.texture.get_width() / info.frame_size.x)
	info.rows = int(info.texture.get_height() / info.frame_size.y)
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("atlas", info.texture)
	mat.set_shader_parameter("frame_uv", Vector2(1.0 / info.cols, 1.0 / info.rows))
	if meta.get("emit", false) and ResourceLoader.exists(base + "_emit.png"):
		mat.set_shader_parameter("emit_atlas", load(base + "_emit.png"))
	mat.set_shader_parameter("self_light", float(meta.get("self_light", 0.0)))
	info.material = mat
	# Quad sized so one texel is one screen pixel; origin (feet) sits at local 0.
	var q := QuadMesh.new()
	var w := info.frame_size.x * Iso.TEXEL
	var h := info.frame_size.y * Iso.TEXEL * Iso.SQ2
	q.size = Vector2(w, h)
	var ox := (info.frame_size.x * 0.5 - info.origin.x) * Iso.TEXEL
	var oy := (info.frame_size.y - info.origin.y) * Iso.TEXEL * Iso.SQ2
	q.center_offset = Vector3(ox, h * 0.5 - oy, 0.0)
	q.material = mat
	info.mesh = q
	_sheets[sheet_name] = info
	Dev.lap("sheet " + sheet_name, t_load, 1.0)
	return info


static func clear_cache() -> void:
	_sheets.clear()
