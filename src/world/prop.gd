## Static and interactive dungeon furniture. One class keyed by `kind` keeps the
## many small behaviours (light a torch, break an urn, open a chest...) together.
class_name Prop
extends Node3D

var stage: Stage
var kind := ""
var pos := Vector2.ZERO
var tile := Vector2i.ZERO
var sprite: PixelSprite
var light: OmniLight3D
var breakable := false
var stops_shots := false
var strike_radius := 0.5
var interact_radius := 0.8
var used := false
var lit := true
var ticks := false
var data: Dictionary = {}
var room_id := -1
var _t := 0.0
var _base_energy := 1.0
var _flame_col := Color(0.35, 0.95, 0.85)
var _solid_tiles: Array[Vector2i] = []


static func make(st: Stage, k: String, t: Vector2i, extra := {}) -> Prop:
	var p := Prop.new()
	p.stage = st
	p.kind = k
	p.tile = t
	p.pos = Vector2(t) + Vector2(0.5, 0.5)
	p.data = extra
	st.add_child(p)
	st.props.append(p)
	p._build()
	return p


func _build() -> void:
	var flame: Color = data.get("flame", Color(0.35, 0.95, 0.85))
	_flame_col = flame
	match kind:
		"torch":
			# mounted on the south face of a back-wall tile
			pos = Vector2(tile.x + 0.5, tile.y + 1.0)
			_sprite("torch", 1.1, 0.04)
			_light(flame, 1.8, 8.5, Vector3(0, 1.45 * Iso.SQ2, 0.35))
			ticks = true
		"banner":
			pos = Vector2(tile.x + 0.5, tile.y + 1.0)
			_sprite("banner", 0.85, 0.03)
		"decal":
			_decal(int(data.get("variant", 0)))
		"urn":
			_sprite("urn", 0.0)
			breakable = true
			strike_radius = 0.45
		"candles":
			_sprite("candles", 0.0)
			_light(Color(1.0, 0.7, 0.4), 0.7, 3.2, Vector3(0, 0.5, 0.1))
			ticks = true
		"chest":
			_sprite("chest", 0.0, 0.0, "closed")
			interact_radius = 1.0
			_light(Color(1.0, 0.8, 0.4), 0.5, 2.5, Vector3(0, 0.6, 0.2))
		"ember_pile":
			_sprite("ember_pile", 0.0)
			interact_radius = 0.9
			_light(Color(1.0, 0.55, 0.25), 0.6, 2.5, Vector3(0, 0.3, 0.2))
		"shrine":
			_sprite("shrine", 0.0)
			_light(Color(0.75, 0.45, 0.95), 1.0, 5.0, Vector3(0, 2.0, 0.3))
			interact_radius = 1.3
			_solid([tile])
		"merchant":
			_sprite("merchant", 0.0, 0.0, "idle")
			_light(Color(1.0, 0.7, 0.4), 1.0, 5.0, Vector3(0.6, 1.4, 0.4))
			interact_radius = 1.4
			_solid([tile])
		"fountain":
			_sprite("fountain", 0.0, 0.0, "idle")
			_light(Color(1.0, 0.6, 0.35), 1.2, 5.5, Vector3(0, 1.0, 0.2))
			interact_radius = 1.4
			ticks = true
			_solid([tile])
		"stairs":
			_sprite("stairs", 0.0, -0.4)
			interact_radius = 1.5
			_light(Color(0.35, 0.95, 0.85), 1.0, 5.0, Vector3(0, -0.5, 0.0))
		"hearthstone":
			_sprite("hearthstone", 0.0, 0.0, "idle")
			_light(Color(1.0, 0.65, 0.35), 1.4, 6.0, Vector3(0, 1.6, 0.3))
			interact_radius = 1.3
			ticks = true
			_solid([tile])
		"lore":
			_sprite("lorestone", 0.0)
			interact_radius = 1.1
			_light(Color(0.4, 0.95, 0.85), 0.5, 3.0, Vector3(0, 1.0, 0.3))
			_solid([tile])
		"brazier", "boss_brazier":
			_sprite("brazier", 0.0, 0.0, "lit")
			_light(flame, 1.6, 7.0, Vector3(0, 1.5 * Iso.SQ2, 0.2))
			ticks = true
			_solid([tile])
			if kind == "boss_brazier":
				breakable = true
				strike_radius = 0.8
				stops_shots = true
		"relic_altar":
			_sprite("altar", 0.0, 0.0, "idle")
			_light(Color(1.0, 0.8, 0.45), 1.2, 4.0, Vector3(0, 1.2, 0.3))
			interact_radius = 1.1
			ticks = true
		"spring":
			_sprite("spring", 0.0, 0.0, "idle")
			_light(Color(1.0, 0.55, 0.45), 1.0, 4.0, Vector3(0, 0.8, 0.3))
			interact_radius = 1.1
			ticks = true
		"cracked_wall":
			pos = Vector2(data.get("center", Vector2(tile) + Vector2(0.5, 1.0)))
			_sprite("cracks", 0.6, 0.05)
			breakable = true
			stops_shots = true
			strike_radius = 1.6
		_:
			# generic data-driven prop (used by the sanctuary)
			if data.has("sheet"):
				_sprite(String(data.sheet), float(data.get("h", 0.0)), float(data.get("z", 0.0)), String(data.get("anim", "")))
			if data.has("light"):
				var L: Array = data.light
				_light(L[0], L[1], L[2], Vector3(0, float(data.get("light_h", 1.2)) * Iso.SQ2, 0.3))
				ticks = true
			interact_radius = float(data.get("radius", 1.2))
			if data.get("solid", false):
				_solid([tile])


func _sprite(sheet: String, h: float, z := 0.0, anim := "") -> void:
	sprite = PixelSprite.new()
	add_child(sprite)
	sprite.setup(sheet, anim)
	position = Iso.to_world(pos, 0.0)
	sprite.position = Vector3(0, h * Iso.SQ2, z)


func _light(col: Color, energy: float, rng: float, at: Vector3) -> void:
	light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = energy
	light.omni_range = rng
	light.omni_attenuation = 1.1
	light.position = at
	_base_energy = energy
	add_child(light)


func _decal(v: int) -> void:
	position = Iso.to_world(pos + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), 0.0)
	var info := SpriteLib.get_sheet("decals")
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(info.frame_size.x * Iso.TEXEL, info.frame_size.y * Iso.TEXEL * Iso.SQ2)
	q.material = info.material
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.006, 0)
	mi.set_instance_shader_parameter("frame", Vector2(v % info.cols, 0))
	mi.set_instance_shader_parameter("flip", 1.0 if randf() > 0.5 else 0.0)
	add_child(mi)


func _solid(tiles: Array) -> void:
	for t: Vector2i in tiles:
		if stage.grid.at(t.x, t.y) == TileGrid.FLOOR:
			stage.grid.put(t.x, t.y, TileGrid.PROP)
			stage.set_tile_solid(t, true)
			_solid_tiles.append(t)


## Restores the floor under a solid prop (used when it's removed).
func unsolid() -> void:
	for t in _solid_tiles:
		stage.grid.put(t.x, t.y, TileGrid.FLOOR)
		stage.set_tile_solid(t, false)
	_solid_tiles.clear()


func tick(dt: float) -> void:
	_t += dt
	if light and lit:
		var fl := 0.85 + 0.15 * sin(_t * 11.0 + pos.x) * sin(_t * 4.3 + pos.y * 2.0)
		light.light_energy = _base_energy * fl
	if kind == "torch" and randf() < dt * 3.0:
		stage.fx.motes(pos + Vector2(0, -0.05), 1.75, _flame_col.lightened(0.2), 1, 0.8, 0.6, 0.06)
	elif (kind == "brazier" or kind == "boss_brazier") and lit and randf() < dt * 8.0:
		stage.fx.motes(pos, 1.6, _flame_col.lightened(0.2), 1, 1.4, 0.8, 0.2)
	elif kind == "hearthstone" and randf() < dt * 5.0:
		stage.fx.motes(pos, 1.0, Color(1.0, 0.65, 0.35), 1, 1.0, 1.0, 0.3)
	elif kind == "relic_altar" and not used and randf() < dt * 6.0:
		stage.fx.motes(pos, 1.0, Color(1.0, 0.85, 0.5), 1, 0.8, 0.8, 0.25)
	elif kind == "fountain" and not used and randf() < dt * 6.0:
		stage.fx.motes(pos, 0.9, Color(1.0, 0.6, 0.4), 1, 1.0, 0.8, 0.3)


# --- interaction ---------------------------------------------------------------

func interactable() -> bool:
	match kind:
		"chest", "ember_pile", "relic_altar", "spring", "fountain":
			return not used
		"shrine", "merchant", "stairs", "hearthstone", "lore":
			return true
	return data.has("prompt") and not used


func prompt() -> String:
	match kind:
		"chest":
			return "Open"
		"ember_pile":
			return "Gather Embers"
		"relic_altar":
			return "Take Relic"
		"spring", "fountain":
			return "Drink"
		"shrine":
			return "Commune"
		"merchant":
			return "Trade"
		"stairs":
			return "Descend"
		"hearthstone":
			return "Return to the Hearth"
		"lore":
			return "Read"
	return String(data.get("prompt", ""))


func interact(pl: Player) -> void:
	match kind:
		"chest":
			used = true
			sprite.play("open")
			Audio.play("chest", 0.0)
			stage.fx.burst(pos, 0.6, Color(1.0, 0.85, 0.45), 18, 3.0, 0.6, 2.0)
			stage.request("chest", self)
		"ember_pile":
			used = true
			sprite.visible = false
			if light:
				light.visible = false
			for i in 6:
				Pickup.spawn(stage, "ember", pos, int(data.get("amount", 5)))
			Audio.play("chest", -4.0, 1.3)
		"relic_altar":
			stage.request("relic", self)
		"spring":
			used = true
			pl.heal(pl.max_hp * 0.35)
			pl.flask = mini(pl.flask + 1, int(pl.stats.v("flask_charges")))
			stage.fx.motes(pl.pos, 0.5, Color(1.0, 0.55, 0.45), 20, 1.6, 0.9, 0.5)
			Audio.play("flask", 0.0, 0.9)
			sprite.play("empty")
			if light:
				light.light_energy = 0.2
				_base_energy = 0.2
		"fountain":
			used = true
			pl.heal(pl.max_hp)
			pl.flask = int(pl.stats.v("flask_charges"))
			stage.fx.motes(pl.pos, 0.5, Color(1.0, 0.65, 0.45), 30, 1.8, 1.0, 0.5)
			stage.fx.number(pl.pos, 2.6, "RESTORED", Color(1.0, 0.8, 0.55), true)
			Audio.play("flask", 0.0, 0.8)
			sprite.play("empty")
		_:
			stage.request(kind, self)


func on_struck(src: Node) -> void:
	match kind:
		"urn":
			used = true
			breakable = false
			stage.fx.burst(pos, 0.4, Color(0.62, 0.5, 0.42), 14, 4.0, 0.5, 9.0)
			Audio.play("urn", -4.0, randf_range(0.9, 1.15))
			var roll := randf()
			if roll < 0.5:
				for i in randi_range(1, 3):
					Pickup.spawn(stage, "ember", pos, 1)
			elif roll < 0.62:
				Pickup.spawn(stage, "heal", pos, 8)
			queue_free()
			stage.props.erase(self)
		"boss_brazier":
			if not lit and src is Player:
				set_lit(true, Color(1.0, 0.6, 0.3))
				Audio.play("ignite", 0.0)
				stage.fx.burst(pos, 1.6, Color(1.0, 0.6, 0.3), 24, 4.0, 0.6, 0.0)
				stage.fx.flash_light(pos, 1.5, Color(1.0, 0.6, 0.3), 3.0, 6.0, 0.4)
				var b = data.get("boss")
				if b and is_instance_valid(b):
					b.on_brazier_lit()
		"cracked_wall":
			used = true
			breakable = false
			stage.request("secret", self)


func set_lit(on: bool, col := Color(-1, 0, 0)) -> void:
	lit = on
	if col.r >= 0.0:
		_flame_col = col
		if light:
			light.light_color = col
	if light:
		light.visible = on
	if sprite:
		sprite.play("lit" if on else "unlit")
		if on and col.r >= 0.0:
			sprite.set_tint(Color(1.0, 0.85, 0.75))
