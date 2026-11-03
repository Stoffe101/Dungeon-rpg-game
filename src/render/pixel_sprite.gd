## Animated pixel-art sprite standing upright in the 3D world.
class_name PixelSprite
extends MeshInstance3D

signal animation_finished(anim: String)

var sheet: SpriteLib.SheetInfo
var anim: String = ""
var frame_i: int = 0
var speed_scale: float = 1.0
var flip_h := false:
	set(v):
		if v != flip_h:
			flip_h = v
			set_instance_shader_parameter("flip", 1.0 if v else 0.0)
var playing := true

var _t := 0.0
var _flash_t := 0.0
var _flash_len := 0.0
var _flash_col := Color.WHITE


func setup(sheet_name: String, start_anim: String = "") -> PixelSprite:
	sheet = SpriteLib.get_sheet(sheet_name)
	mesh = sheet.mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if start_anim == "":
		start_anim = sheet.anims.keys()[0]
	play(start_anim, true)
	return self


func has_anim(a: String) -> bool:
	return sheet.anims.has(a)


func play(a: String, restart := false) -> void:
	if not sheet.anims.has(a):
		return
	if a == anim and not restart:
		return
	anim = a
	frame_i = 0
	_t = 0.0
	playing = true
	_apply()


func set_frame(i: int) -> void:
	var info: Dictionary = sheet.anims[anim]
	frame_i = clampi(i, 0, int(info.frames) - 1)
	_apply()


func flash(col: Color = Color.WHITE, duration := 0.1) -> void:
	_flash_col = col
	_flash_t = duration
	_flash_len = duration
	set_instance_shader_parameter("flash", Color(col.r, col.g, col.b, 1.0))


func set_tint(c: Color) -> void:
	set_instance_shader_parameter("tint", c)


func set_dissolve(v: float) -> void:
	set_instance_shader_parameter("dissolve", v)


func set_glow(v: float) -> void:
	set_instance_shader_parameter("glow_mult", v)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		var a := clampf(_flash_t / maxf(_flash_len, 0.001), 0.0, 1.0)
		set_instance_shader_parameter("flash", Color(_flash_col.r, _flash_col.g, _flash_col.b, a if _flash_t > 0.0 else 0.0))
	if not playing or anim == "":
		return
	var info: Dictionary = sheet.anims[anim]
	var fps: float = float(info.fps) * speed_scale
	if fps <= 0.0:
		return
	_t += delta * fps
	while _t >= 1.0:
		_t -= 1.0
		frame_i += 1
		if frame_i >= int(info.frames):
			if info.loop:
				frame_i = 0
			else:
				frame_i = int(info.frames) - 1
				playing = false
				_apply()
				animation_finished.emit(anim)
				return
		_apply()


func _apply() -> void:
	var info: Dictionary = sheet.anims[anim]
	set_instance_shader_parameter("frame", Vector2(frame_i, int(info.row)))
