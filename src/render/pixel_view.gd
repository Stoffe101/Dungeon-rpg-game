## Renders the 3D world into a low-resolution SubViewport and shows it upscaled by
## an integer factor. The camera is snapped to the texel grid and the remaining
## sub-texel offset is applied to the displayed image, so motion is smooth while
## pixels never swim.
class_name PixelView
extends Control

const MARGIN := 2
const BASE_HEIGHT := 270.0

var viewport: SubViewport
var display: TextureRect
var camera: Camera3D
var world: Node3D
var overlay: CanvasLayer

var pixel_scale := 4
var internal := Vector2i(480, 270)
var focus := Vector3.ZERO
var shake_px := Vector2.ZERO
var zoom_px := 0.0

var _frac := Vector2.ZERO


func _ready() -> void:
	add_to_group("pixel_view")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_debanding = false
	viewport.positional_shadow_atlas_size = 4096
	viewport.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	viewport.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	viewport.positional_shadow_atlas_quad_2 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16
	viewport.positional_shadow_atlas_quad_3 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	display = TextureRect.new()
	display.name = "Display"
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.rotation_degrees = Vector3(Iso.CAMERA_PITCH_DEG, 0, 0)
	camera.near = 1.0
	camera.far = 120.0
	viewport.add_child(camera)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	viewport.add_child(overlay)
	get_window().size_changed.connect(relayout)
	relayout()


func relayout() -> void:
	var win := Vector2(get_window().size)
	var forced := int(Settings.get_value("pixel_scale", 0))
	pixel_scale = forced if forced > 0 else maxi(1, roundi(win.y / BASE_HEIGHT))
	internal = Vector2i(int(ceil(win.x / pixel_scale)) + MARGIN * 2, int(ceil(win.y / pixel_scale)) + MARGIN * 2)
	viewport.size = internal
	camera.size = (internal.y) / Iso.PPU
	_place_display()


func ui_scale() -> float:
	return get_window().content_scale_factor


func _place_display() -> void:
	var s := float(pixel_scale) / ui_scale()
	display.size = Vector2(internal) * s
	display.position = (Vector2(-MARGIN, -MARGIN) - _frac) * s


func clear_world() -> void:
	for c in world.get_children():
		c.queue_free()
	for c in overlay.get_children():
		c.queue_free()


func set_environment(env: Environment) -> void:
	camera.environment = env


func _process(_delta: float) -> void:
	update_camera()


func update_camera() -> void:
	var basis := camera.global_transform.basis
	var target := focus
	var local := basis.inverse() * target
	local.x += shake_px.x * Iso.TEXEL
	local.y += shake_px.y * Iso.TEXEL
	var sx := roundf(local.x * Iso.PPU) / Iso.PPU
	var sy := roundf(local.y * Iso.PPU) / Iso.PPU
	_frac = Vector2((local.x - sx) * Iso.PPU, -(local.y - sy) * Iso.PPU)
	var snapped := basis * Vector3(sx, sy, local.z)
	camera.global_position = snapped + basis.z * Iso.CAMERA_DISTANCE
	_place_display()


## Converts a position in root-viewport (logical UI) coordinates into the world
## viewport's pixel coordinates.
func screen_to_internal(p: Vector2) -> Vector2:
	var s := float(pixel_scale) / ui_scale()
	return (p - display.position) / s


func internal_to_screen(p: Vector2) -> Vector2:
	var s := float(pixel_scale) / ui_scale()
	return p * s + display.position


## Projects a screen point onto the ground plane (at a given height in tiles).
func screen_to_plane(p: Vector2, height := 0.0) -> Vector2:
	var ip := screen_to_internal(p)
	var o := camera.project_ray_origin(ip)
	var n := camera.project_ray_normal(ip)
	var plane := Plane(Vector3.UP, height * Iso.SQ2)
	var hit = plane.intersects_ray(o, n)
	if hit == null:
		return Iso.to_plane(focus)
	return Iso.to_plane(hit)


func world_to_internal(w: Vector3) -> Vector2:
	return camera.unproject_position(w)
