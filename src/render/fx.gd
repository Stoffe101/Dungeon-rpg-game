## Visual effects for a stage: pixel particles, floor shapes (telegraphs, slash
## arcs, rings), flash lights, afterimages, damage numbers and screen shake.
class_name Fx
extends Node3D

const GROUND_SHADER := preload("res://assets/shaders/ground_fx.gdshader")
const PARTICLE_SHADER := preload("res://assets/shaders/particle.gdshader")
const MAX_PARTICLES := 2400
const FONT_OUTLINE := preload("res://assets/fonts/kindled_outline.fnt")

enum Shape { DISC, RING, CONE, RECT, SWIPE, SIGIL }

var view: PixelView
var trauma := 0.0
var _pm: MultiMesh
var _p_pos := PackedVector3Array()
var _p_vel := PackedVector3Array()
var _p_life := PackedFloat32Array()
var _p_max := PackedFloat32Array()
var _p_col := PackedColorArray()
var _p_size := PackedFloat32Array()
var _p_grav := PackedFloat32Array()
var _p_drag := PackedFloat32Array()
var _p_count := 0
var _cam_basis := Basis(Vector3.RIGHT, deg_to_rad(Iso.CAMERA_PITCH_DEG))
var _cam_inv := Basis(Vector3.RIGHT, deg_to_rad(Iso.CAMERA_PITCH_DEG)).inverse()
var _ground_mat: ShaderMaterial
var _plane: PlaneMesh
var _shapes: Array = []      # {node, t, life, update:Callable}
var _lights: Array = []      # {light, t, life, energy}
var _numbers: Array = []     # {label, world:Vector3, t, life, vel}
var _ghosts: Array = []      # {sprite, t, life}
var _says: Array = []        # {label, who:WeakRef, height, t, life}
var _marks: Dictionary = {}  # instance id -> {label, who:WeakRef, height}
var _impacts: Array = []     # {sprite, t, life}
var _impact_mat: ShaderMaterial
var _kick := Vector2.ZERO    # directional camera nudge (screen pixels), springs back
var _splats: Array = []      # {mesh, t, life}
const MAX_SPLATS := 60
var intensity := 1.0


func _ready() -> void:
	_pm = MultiMesh.new()
	_pm.transform_format = MultiMesh.TRANSFORM_3D
	_pm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(Iso.TEXEL, Iso.TEXEL)
	var m := ShaderMaterial.new()
	m.shader = PARTICLE_SHADER
	q.material = m
	_pm.mesh = q
	_pm.instance_count = MAX_PARTICLES
	_pm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _pm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1000, -50, -1000), Vector3(2000, 100, 2000))
	add_child(mmi)
	for arr in [_p_pos, _p_vel]:
		arr.resize(MAX_PARTICLES)
	for arr in [_p_life, _p_max, _p_size, _p_grav, _p_drag]:
		arr.resize(MAX_PARTICLES)
	_p_col.resize(MAX_PARTICLES)
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND_SHADER
	_plane = PlaneMesh.new()
	_plane.size = Vector2(1, 1)
	_plane.material = _ground_mat
	intensity = float(Settings.get_value("effects_intensity", 1.0))
	ally = float(Settings.get_value("ally_effects", 0.6))
	Settings.changed.connect(func(key: String) -> void:
		if key == "effects_intensity":
			intensity = float(Settings.get_value("effects_intensity", 1.0))
		elif key == "ally_effects":
			ally = float(Settings.get_value("ally_effects", 0.6)))


## Co-op: another Kindled's particles are drawn at `ally` of your own (the
## Allies' effects setting), so your own Kindled stays easy to read in a crowd.
var ally := 0.6
var ally_k := 1.0     # client: set while drawing an effect another Kindled made


func _who_k() -> float:
	if ally_k < 1.0:
		return ally_k
	if Net.recording and Net.actor_peer != 0 and Net.actor_peer != Net.my_id():
		return ally
	return 1.0


## Particle counts follow the Effects setting; a fractional share is rolled so
## single motes thin out too instead of always surviving.
func _scaled(count: int) -> int:
	var n := count * intensity * _who_k()
	return int(n) + (1 if randf() < n - floorf(n) else 0)


# --- particles ---------------------------------------------------------------

## Emits pixel particles at plane position `p` (height in tiles).
func burst(p: Vector2, height: float, col: Color, count: int, speed: float, life := 0.5, gravity := 6.0, dir := Vector2.ZERO, spread := PI, up := 2.0, size := 1.0, drag := 2.0) -> void:
	if Net.recording:
		Net.rec(["fx", "burst", p, height, col, count, speed, life, gravity, dir, spread, up, size, drag])
	count = _scaled(count)
	var base_ang := dir.angle() if dir != Vector2.ZERO else 0.0
	for i in count:
		if _p_count >= MAX_PARTICLES:
			return
		var a := base_ang + randf_range(-spread, spread)
		var s := speed * randf_range(0.35, 1.0)
		var v2 := Vector2(cos(a), sin(a)) * s
		var k := _p_count
		_p_pos[k] = Iso.to_world(p + Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)), height)
		_p_vel[k] = Vector3(v2.x, randf_range(0.3, 1.0) * up * Iso.SQ2, v2.y * Iso.SQ2)
		_p_life[k] = life * randf_range(0.6, 1.2)
		_p_max[k] = _p_life[k]
		_p_col[k] = col
		_p_size[k] = size if randf() > 0.3 else maxf(1.0, size - 1.0)
		_p_grav[k] = gravity
		_p_drag[k] = drag
		_p_count += 1


## Slow rising motes (embers, souls).
func motes(p: Vector2, height: float, col: Color, count: int, rise := 1.0, life := 1.2, jitter := 0.4) -> void:
	if Net.recording and (count > 1 or randf() < 0.33):
		Net.rec(["fx", "motes", p, height, col, count, rise, life, jitter])
	for i in _scaled(count):
		if _p_count >= MAX_PARTICLES:
			return
		var k := _p_count
		var off := Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		_p_pos[k] = Iso.to_world(p + off, height + randf_range(0.0, 0.3))
		_p_vel[k] = Vector3(randf_range(-0.3, 0.3), rise * randf_range(0.6, 1.2) * Iso.SQ2, randf_range(-0.2, 0.2))
		_p_life[k] = life * randf_range(0.6, 1.2)
		_p_max[k] = _p_life[k]
		_p_col[k] = col
		_p_size[k] = 1.0
		_p_grav[k] = 0.0
		_p_drag[k] = 0.5
		_p_count += 1


func _update_particles(dt: float) -> void:
	var i := 0
	while i < _p_count:
		_p_life[i] -= dt
		if _p_life[i] <= 0.0:
			_p_count -= 1
			_p_pos[i] = _p_pos[_p_count]
			_p_vel[i] = _p_vel[_p_count]
			_p_life[i] = _p_life[_p_count]
			_p_max[i] = _p_max[_p_count]
			_p_col[i] = _p_col[_p_count]
			_p_size[i] = _p_size[_p_count]
			_p_grav[i] = _p_grav[_p_count]
			_p_drag[i] = _p_drag[_p_count]
			continue
		var v := _p_vel[i]
		v.y -= _p_grav[i] * Iso.SQ2 * dt
		v *= maxf(0.0, 1.0 - _p_drag[i] * dt)
		var pp := _p_pos[i] + v * dt
		if pp.y < 0.02 and _p_grav[i] > 0.0:
			pp.y = 0.02
			v = Vector3(v.x * 0.5, -v.y * 0.25, v.z * 0.5)
		_p_vel[i] = v
		_p_pos[i] = pp
		i += 1
	_pm.visible_instance_count = _p_count
	for k in _p_count:
		var local := _cam_inv * _p_pos[k]
		local.x = roundf(local.x * Iso.PPU) / Iso.PPU
		local.y = roundf(local.y * Iso.PPU) / Iso.PPU
		var s := _p_size[k]
		var t := Transform3D(_cam_basis.scaled(Vector3(s, s, s)), _cam_basis * local)
		_pm.set_instance_transform(k, t)
		var c := _p_col[k]
		var lf := _p_life[k] / _p_max[k]
		if lf < 0.3:
			# blink out in the last moments rather than alpha-fading
			if int(_p_life[k] * 30.0) % 2 == 0:
				c = c * 0.55
		_pm.set_instance_color(k, c)


# --- floor shapes ------------------------------------------------------------

## Creates a floor shape. `size` is in tiles (x = length/forward, y = width).
## For RECT the shape starts at `p` and extends along `dir`; others centre on `p`.
func shape(kind: int, p: Vector2, dir: Vector2, size: Vector2, col: Color, edge: Color, life: float, params := {}) -> MeshInstance3D:
	if Net.recording:
		Net.rec(["fx", "shape", kind, p, dir, size, col, edge, life, params])
	var mi := MeshInstance3D.new()
	mi.mesh = _plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	var side := Vector2(-d.y, d.x)
	var bx := Vector3(d.x, 0, d.y * Iso.SQ2) * size.x
	var bz := Vector3(side.x, 0, side.y * Iso.SQ2) * size.y
	var center := p + (d * size.x * 0.5 if kind == Shape.RECT else Vector2.ZERO)
	mi.transform = Transform3D(Basis(bx, Vector3.UP, bz), Iso.to_world(center, 0.0) + Vector3(0, 0.015 + randf() * 0.01, 0))
	mi.set_instance_shader_parameter("shape", float(kind))
	mi.set_instance_shader_parameter("color", col)
	mi.set_instance_shader_parameter("edge_color", edge)
	mi.set_instance_shader_parameter("px_size", maxf(size.x, size.y) * Iso.PPU)
	for k in params:
		mi.set_instance_shader_parameter(k, params[k])
	_shapes.append({"node": mi, "t": 0.0, "life": life, "update": Callable()})
	return mi


## A sweeping slash arc on the floor around `p`.
func swipe(p: Vector2, dir: Vector2, radius: float, half_angle: float, col: Color, duration := 0.16, inner := 0.45, reverse := false) -> void:
	if Net.recording:
		Net.rec(["fx", "swipe", p, dir, radius, half_angle, col, duration, inner, reverse])
	var mi := shape(Shape.SWIPE, p, dir, Vector2(radius * 2.0, radius * 2.0), col, Color(1, 1, 0.9, 1), duration + 0.12, {"half_angle": half_angle, "inner": inner, "glow": 1.6})
	if reverse:
		# mirror the sweep direction by flipping the side axis
		var b := mi.transform.basis
		mi.transform.basis = Basis(b.x, b.y, -b.z)
	var data: Dictionary = _shapes[_shapes.size() - 1]
	data.update = func(t: float, node: MeshInstance3D) -> void:
		node.set_instance_shader_parameter("progress", clampf(t / duration, 0.0, 1.0) * 1.08)
		node.set_instance_shader_parameter("fade", clampf(1.0 - (t - duration) / 0.12, 0.0, 1.0))


## Expanding ring (shockwaves, nova outlines).
func ring(p: Vector2, radius: float, col: Color, duration := 0.3, thickness := 0.25) -> void:
	if Net.recording:
		Net.rec(["fx", "ring", p, radius, col, duration, thickness])
	var mi := shape(Shape.RING, p, Vector2.RIGHT, Vector2(radius * 2, radius * 2), col, col.lightened(0.4), duration, {"inner": 1.0 - thickness, "glow": 1.5})
	var data: Dictionary = _shapes[_shapes.size() - 1]
	var base_t := mi.transform
	data.update = func(t: float, node: MeshInstance3D) -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		var s := lerpf(0.25, 1.0, 1.0 - pow(1.0 - k, 3.0))
		node.transform = Transform3D(base_t.basis.scaled(Vector3(s, 1, s)), base_t.origin)
		node.set_instance_shader_parameter("fade", 1.0 - k)


func _update_shapes(dt: float) -> void:
	for i in range(_shapes.size() - 1, -1, -1):
		var s: Dictionary = _shapes[i]
		var node: MeshInstance3D = s.node
		if not is_instance_valid(node):
			_shapes.remove_at(i)
			continue
		s.t += dt
		if s.update is Callable and s.update.is_valid():
			s.update.call(s.t, node)
		if s.life >= 0.0 and s.t >= s.life:
			node.queue_free()
			_shapes.remove_at(i)


func release(node: MeshInstance3D) -> void:
	if Net.recording and is_instance_valid(node) and node.has_meta("tid"):
		Net.rec(["tele-", int(node.get_meta("tid"))])
	for s in _shapes:
		if s.node == node:
			s.life = 0.0


# --- lights ------------------------------------------------------------------

func flash_light(p: Vector2, height: float, col: Color, energy: float, rng: float, life: float) -> void:
	if Net.recording:
		Net.rec(["fx", "flash_light", p, height, col, energy, rng, life])
	if Settings.get_value("reduce_flashes", false):
		energy *= 0.45
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.position = Iso.to_world(p, height)
	add_child(l)
	_lights.append({"light": l, "t": 0.0, "life": life, "energy": energy})


func _update_lights(dt: float) -> void:
	for i in range(_lights.size() - 1, -1, -1):
		var L: Dictionary = _lights[i]
		L.t += dt
		var k: float = L.t / L.life
		if k >= 1.0:
			L.light.queue_free()
			_lights.remove_at(i)
		else:
			L.light.light_energy = L.energy * (1.0 - k) * (1.0 - k)


# --- afterimages -------------------------------------------------------------

func ghost(src: PixelSprite, world_pos: Vector3, col: Color, life := 0.3) -> void:
	var g := PixelSprite.new()
	add_child(g)
	g.setup(src.sheet.name, src.anim)
	g.material_override = _ghost_material(src.sheet)
	g.set_frame(src.frame_i)
	g.playing = false
	g.flip_h = src.flip_h
	g.position = world_pos + Vector3(0, 0, -0.02)
	g.set_instance_shader_parameter("flash", Color(col.r, col.g, col.b, 0.85))
	_ghosts.append({"sprite": g, "t": 0.0, "life": life})


var _ghost_mats := {}


func _ghost_material(sheet: SpriteLib.SheetInfo) -> ShaderMaterial:
	if _ghost_mats.has(sheet.name):
		return _ghost_mats[sheet.name]
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/ghost.gdshader")
	m.set_shader_parameter("atlas", sheet.texture)
	m.set_shader_parameter("frame_uv", Vector2(1.0 / sheet.cols, 1.0 / sheet.rows))
	_ghost_mats[sheet.name] = m
	return m


func _update_ghosts(dt: float) -> void:
	for i in range(_ghosts.size() - 1, -1, -1):
		var G: Dictionary = _ghosts[i]
		G.t += dt
		var k: float = G.t / G.life
		if k >= 1.0:
			G.sprite.queue_free()
			_ghosts.remove_at(i)
		else:
			G.sprite.set_tint(Color(1, 1, 1, 1.0 - k))


# --- numbers -----------------------------------------------------------------

func number(p: Vector2, height: float, text: String, col: Color, big := false) -> void:
	if Net.recording:
		Net.rec(["fx", "number", p, height, text, col, big])
	if not Settings.get_value("damage_numbers", true) or view == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_OUTLINE)
	l.add_theme_font_size_override("font_size", 16 if big else 8)
	l.add_theme_color_override("font_color", col)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.overlay.add_child(l)
	var w := Iso.to_world(p + Vector2(randf_range(-0.25, 0.25), 0), height)
	_numbers.append({"label": l, "world": w, "t": 0.0, "life": 0.75 if not big else 1.0, "rise": 0.0, "big": big})
	_place_number(_numbers[_numbers.size() - 1])


func _place_number(n: Dictionary) -> void:
	var l: Label = n.label
	var sp := view.world_to_internal(n.world)
	var sz := l.get_minimum_size()
	l.position = Vector2(roundf(sp.x - sz.x * 0.5), roundf(sp.y - sz.y - n.rise))


## A speech bubble that follows a speaker (a Prop or Actor with `pos`).
func say(who: Node, height: float, text: String, life := 3.6) -> void:
	if view == null:
		return
	for s in _says:
		if s.who.get_ref() == who:
			s.t = s.life   # replace what they were saying
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_OUTLINE)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.98, 0.92, 0.8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.06, 0.72)
	sb.set_content_margin_all(2)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	l.add_theme_stylebox_override("normal", sb)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.overlay.add_child(l)
	_says.append({"label": l, "who": weakref(who), "height": height, "t": 0.0, "life": life})


## A persistent marker over someone's head ("!" = has a request, "?" = ready to hand in).
func mark(who: Node, height: float, text: String, col: Color, size := 16) -> void:
	unmark(who)
	if view == null or text == "":
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_OUTLINE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.overlay.add_child(l)
	_marks[who.get_instance_id()] = {"label": l, "who": weakref(who), "height": height}


## A small signboard that hangs over something in the world (ruins waiting to be
## rebuilt): a title and a line saying what it takes and what it gives.
func signboard(who: Node, height: float, title: String, sub: String, col: Color) -> void:
	unmark(who)
	if view == null:
		return
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.05, 0.8)
	sb.border_color = col.darkened(0.3)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	for line in [[title, col], [sub, Color(0.86, 0.8, 0.7)]]:
		var l := Label.new()
		l.text = String(line[0])
		l.add_theme_font_override("font", FONT_OUTLINE)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", line[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.overlay.add_child(p)
	_marks[who.get_instance_id()] = {"label": p, "who": weakref(who), "height": height, "still": true}


func unmark(who: Node) -> void:
	var m: Dictionary = _marks.get(who.get_instance_id(), {})
	if not m.is_empty():
		(m.label as Label).queue_free()
		_marks.erase(who.get_instance_id())


func _update_marks() -> void:
	for k in _marks.keys():
		var m: Dictionary = _marks[k]
		var who: Node = m.who.get_ref()
		if who == null or not is_instance_valid(who):
			(m.label as Label).queue_free()
			_marks.erase(k)
			continue
		var l: Control = m.label
		var sp := view.world_to_internal(Iso.to_world(who.get("pos"), m.height))
		var sz := l.get_minimum_size()
		var bob := 0.0 if m.get("still", false) else roundf(sin(Time.get_ticks_msec() / 260.0) * 1.5)
		l.position = Vector2(roundf(sp.x - sz.x * 0.5), roundf(sp.y - sz.y + bob))
		if m.get("still", false):
			# signboards stay on screen and only show up close
			var ov := Vector2(view.internal)
			l.position.x = clampf(l.position.x, 2.0, maxf(2.0, ov.x - sz.x - 2.0))
			l.position.y = clampf(l.position.y, 14.0, maxf(14.0, ov.y - sz.y - 2.0))
			var st = Game.stage
			if st and st.player:
				var d: float = (st.player.pos as Vector2).distance_to(who.get("pos"))
				l.modulate.a = clampf((8.0 - d) / 2.5, 0.0, 1.0)
		l.visible = not _speaking(who)


func _speaking(who: Node) -> bool:
	for s in _says:
		if s.who.get_ref() == who:
			return true
	return false


func _update_says(dt: float) -> void:
	for i in range(_says.size() - 1, -1, -1):
		var s: Dictionary = _says[i]
		s.t += dt
		var who: Node = s.who.get_ref()
		if s.t >= s.life or who == null or not is_instance_valid(who):
			s.label.queue_free()
			_says.remove_at(i)
			continue
		var sp := view.world_to_internal(Iso.to_world(who.get("pos"), s.height))
		var sz: Vector2 = s.label.get_minimum_size()
		s.label.position = Vector2(roundf(sp.x - sz.x * 0.5), roundf(sp.y - sz.y))
		s.label.modulate.a = clampf((s.life - s.t) / 0.4, 0.0, 1.0) * clampf(s.t / 0.12, 0.0, 1.0)


func _update_numbers(dt: float) -> void:
	for i in range(_numbers.size() - 1, -1, -1):
		var n: Dictionary = _numbers[i]
		n.t += dt
		var k: float = n.t / n.life
		n.rise = 14.0 * (1.0 - pow(1.0 - minf(k * 1.8, 1.0), 3.0)) + (6.0 if n.big else 0.0)
		if k >= 1.0:
			n.label.queue_free()
			_numbers.remove_at(i)
			continue
		_place_number(n)
		if k > 0.7:
			n.label.visible = int(n.t * 24.0) % 2 == 0


# --- screen shake ------------------------------------------------------------

## Random shake that decays; every shake is also felt through the controller.
func shake(amount: float) -> void:
	if Net.recording and Net.actor_peer != Net.my_id():
		# another Kindled's blow shakes their screen; the world's shakes everyone's
		Net.rec(["fx", "shake", amount] if Net.actor_peer == 0 else ["own", Net.actor_peer, ["fx", "shake", amount]])
		if Net.actor_peer != 0:
			return
	trauma = minf(1.0, trauma + amount * float(Settings.get_value("screen_shake", 1.0)))
	Settings.rumble(clampf(amount * 0.9, 0.0, 1.0), clampf(amount * 1.1 - 0.15, 0.0, 1.0), 0.06 + amount * 0.2)


## A directional nudge of the camera: hits push the view the way the blow went.
func kick(dir: Vector2, pixels: float) -> void:
	if Net.recording and Net.actor_peer != Net.my_id():
		if Net.actor_peer != 0:
			Net.rec(["own", Net.actor_peer, ["fx", "kick", dir, pixels]])
		return
	var k := float(Settings.get_value("screen_shake", 1.0))
	if k <= 0.0 or dir == Vector2.ZERO:
		return
	_kick += dir.normalized() * pixels * k
	_kick = _kick.limit_length(6.0)


func _update_shake(dt: float) -> void:
	if view == null:
		return
	trauma = maxf(0.0, trauma - dt * 2.2)
	var t := trauma * trauma
	var tm := Time.get_ticks_msec() / 1000.0
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-dt * 16.0))
	view.shake_px = Vector2(sin(tm * 61.0) + sin(tm * 27.3), cos(tm * 53.0) + sin(tm * 33.1)) * 0.5 * t * 7.0 + _kick


# --- floor marks ---------------------------------------------------------------

## A mark on the floor (death splat, scorch) that lingers, then dithers away.
func splat(p: Vector2, col: Color, life := 24.0, scale_k := 1.0) -> void:
	if Net.recording:
		Net.rec(["fx", "splat", p, col, life, scale_k])
	var info := SpriteLib.get_sheet("splat")
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(info.frame_size.x * Iso.TEXEL, info.frame_size.y * Iso.TEXEL * Iso.SQ2) * scale_k
	q.material = info.material
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Iso.to_world(p, 0.0) + Vector3(0, 0.004 + randf() * 0.002, 0)
	mi.set_instance_shader_parameter("frame", Vector2(randi() % maxi(info.cols, 1), 0))
	mi.set_instance_shader_parameter("flip", 1.0 if randf() > 0.5 else 0.0)
	mi.set_instance_shader_parameter("tint", Color(col.r, col.g, col.b, 1.0))
	add_child(mi)
	_splats.append({"mesh": mi, "t": 0.0, "life": life, "col": col})
	while _splats.size() > MAX_SPLATS:
		var old: Dictionary = _splats.pop_front()
		if is_instance_valid(old.mesh):
			old.mesh.queue_free()


func _update_splats(dt: float) -> void:
	for i in range(_splats.size() - 1, -1, -1):
		var s: Dictionary = _splats[i]
		s.t += dt
		var left: float = s.life - s.t
		if left <= 0.0 or not is_instance_valid(s.mesh):
			if is_instance_valid(s.mesh):
				s.mesh.queue_free()
			_splats.remove_at(i)
		elif left < 3.0:
			var c: Color = s.col
			s.mesh.set_instance_shader_parameter("tint", Color(c.r, c.g, c.b, left / 3.0))


# --- impact flashes ----------------------------------------------------------

## A starburst at the point of contact, tinted by what landed. Animates in real
## time, so it plays out during the hitstop freeze.
func impact(p: Vector2, height: float, col: Color, big := false, dir := Vector2.ZERO) -> void:
	if Net.recording:
		Net.rec(["fx", "impact", p, height, col, big, dir])
	var s := PixelSprite.new()
	add_child(s)
	s.setup("impact", "pop")
	if _impact_mat == null:
		_impact_mat = (_ghost_material(s.sheet) as ShaderMaterial).duplicate() as ShaderMaterial
		_impact_mat.set_shader_parameter("detail", 1.0)
	s.material_override = _impact_mat
	var strength := 0.75 if Settings.get_value("reduce_flashes", false) else 1.0
	s.set_instance_shader_parameter("flash", Color(col.r * strength, col.g * strength, col.b * strength, 1.0))
	s.set_instance_shader_parameter("tint", Color(1, 1, 1, 1))
	s.flip_h = randf() < 0.5
	s.position = Iso.to_world(p - dir * 0.15, height) + Vector3(0, 0, 0.12)
	if big:
		s.scale = Vector3(2, 2, 2)
	_impacts.append({"sprite": s, "t": 0.0, "life": 4.0 / 26.0})


func _update_impacts(dt: float) -> void:
	for i in range(_impacts.size() - 1, -1, -1):
		var m: Dictionary = _impacts[i]
		m.t += dt
		if m.t >= m.life or not is_instance_valid(m.sprite):
			if is_instance_valid(m.sprite):
				m.sprite.queue_free()
			_impacts.remove_at(i)


## Called with real (unscaled) time so effects keep animating through hitstop.
func step(dt: float) -> void:
	_update_particles(dt)
	_update_shapes(dt)
	_update_lights(dt)
	_update_ghosts(dt)
	_update_numbers(dt)
	_update_says(dt)
	_update_impacts(dt)
	_update_splats(dt)
	_update_marks()
	_update_shake(dt)


func clear_all() -> void:
	_p_count = 0
	_pm.visible_instance_count = 0
	for s in _shapes:
		if is_instance_valid(s.node):
			s.node.queue_free()
	_shapes.clear()
	for n in _numbers:
		n.label.queue_free()
	_numbers.clear()
