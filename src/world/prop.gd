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
var net_idx := -1             # the same on every machine (co-op)
var _t := 0.0
var _base_energy := 1.0
var _flame_col := Color(0.35, 0.95, 0.85)
var _solid_tiles: Array[Vector2i] = []
## Co-op guest in the host's sanctuary: the host moves this one (a resident,
## the cat); it walks to where the host has it and does what it does there.
var following := false
var follow_goal := Vector2.ZERO
var follow_anim := ""
var follow_flip := false


func follow_to(p: Vector2, anim: String, flip: bool, _spot := -1) -> void:
	if not following or pos.distance_to(p) > 4.0:
		pos = p
		position = Iso.to_world(pos, 0.0)
	following = true
	follow_goal = p
	follow_anim = anim
	follow_flip = flip


## One step toward where the host has it (see follow_to).
func follow_step(dt: float, speed: float) -> void:
	var d := follow_goal - pos
	if d.length() > 0.001:
		pos += d.limit_length(maxf(speed * dt, d.length() * minf(1.0, dt * 6.0)))
		position = Iso.to_world(pos, 0.0)
	if sprite:
		if follow_anim != "" and sprite.anim != follow_anim and sprite.has_anim(follow_anim):
			sprite.play(follow_anim)
		sprite.flip_h = follow_flip


static func make(st: Stage, k: String, t: Vector2i, extra := {}) -> Prop:
	var p := Prop.new()
	p.stage = st
	p.kind = k
	p.tile = t
	p.pos = Vector2(t) + Vector2(0.5, 0.5)
	p.data = extra
	p.net_idx = st._prop_seq
	st._prop_seq += 1
	st.add_child(p)
	st.props.append(p)
	p._build()
	if Net.recording and st.get("built"):
		Net.rec(["prop+", k, t, extra, p.room_id])
	return p


func _build() -> void:
	var flame: Color = data.get("flame", Color(0.35, 0.95, 0.85))
	_flame_col = flame
	match kind:
		"torch":
			# mounted on the south face of a back-wall tile
			pos = Vector2(tile.x + 0.5, tile.y + 1.0)
			_sprite(String(data.get("sheet", "torch_warm" if flame.r > flame.b + 0.3 else "torch")), 1.1, 0.04)
			_light(flame, 1.8, 8.5, Vector3(0, 1.45 * Iso.SQ2, 0.35))
			ticks = true
		"banner":
			pos = Vector2(tile.x + 0.5, tile.y + 1.0)
			_sprite(String(data.get("sheet", "banner")), 0.85, 0.03)
		"decal":
			_decal(int(data.get("variant", 0)))
		"urn":
			var mat := String(data.get("mat", "clay"))
			_sprite("urn" if mat == "clay" else "urn_" + mat, 0.0, 0.0, "rich" if data.get("rich", false) else "idle")
			breakable = true
			strike_radius = 0.45
			ticks = data.get("urnling", false)
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
			_flat("stairs", "idle")
			if data.has("route"):
				# each way down under its own arch, lit in its own colour: told
				# apart by its shape before its name
				var arch := PixelSprite.new()
				add_child(arch)
				arch.setup("route_arch", String(data.route))
				arch.position = Vector3(0, 0, -0.55 * Iso.SQ2)
				_light(DungeonGen.route_def(String(data.route)).get("color", Color.WHITE), 1.3, 4.5, Vector3(0, 1.2 * Iso.SQ2, -0.2))
				ticks = true
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
			_sprite(String(data.get("sheet", "brazier")), 0.0, 0.0, "lit")
			if kind == "boss_brazier":
				_light(flame, 2.4, 11.0, Vector3(0, 1.5 * Iso.SQ2, 0.2))
			else:
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
		"glowcap":
			_sprite("glowcap", 0.0, 0.0, "idle")
			var gc := Color(0.4, 1.0, 0.9) if (tile.x + tile.y) % 2 == 0 else Color(0.9, 0.5, 1.0)
			_light(gc, 1.1, 5.0, Vector3(0, 0.9, 0.2))
			_flame_col = gc
			ticks = true
		"bramble", "root_node":
			_sprite("bramble", 0.0, 0.0, "idle")
			_solid([tile])
			breakable = true
			stops_shots = true
			strike_radius = 0.55
			data["hp"] = 3 if kind == "bramble" else 6
			if kind == "root_node":
				sprite.set_tint(Color(1.0, 0.55, 0.6))
				_light(Color(1.0, 0.4, 0.6), 1.2, 4.0, Vector3(0, 0.8, 0.2))
				_flame_col = Color(1.0, 0.4, 0.6)
			ticks = true
		"bramble_wall":
			pos = Vector2(data.get("center", Vector2(tile) + Vector2(0.5, 1.0)))
			_sprite("bramble", 0.0, 0.05, "idle")
			breakable = true
			stops_shots = true
			strike_radius = 1.6
			data["hp"] = 4
			ticks = true
		"sconce":
			_sprite(String(data.get("sheet", "brazier")), 0.0, 0.0, "unlit")
			_light(flame, 1.4, 6.0, Vector3(0, 1.5 * Iso.SQ2, 0.2))
			light.visible = false
			lit = false
			interact_radius = 1.2
			ticks = true
			_solid([tile])
		"lost_camp":
			_sprite("lost_camp", 0.0, 0.0, "cold")
			_light(Color(1.0, 0.55, 0.25), 1.8, 7.0, Vector3(0, 0.6, 0.3))
			light.visible = false
			lit = false
			interact_radius = 1.8
			ticks = true
		"ember_well":
			_sprite("ember_well", 0.0, 0.0, "idle")
			_light(Color(1.0, 0.55, 0.25), 1.4, 5.0, Vector3(0, 0.6, 0.3))
			interact_radius = 1.5
			_solid([tile])
			ticks = true
		"trial_altar":
			_sprite(String(data.get("sheet", "trial_altar")), 0.0, 0.0, "idle")
			_light(Color(1.0, 0.3, 0.35), 1.6, 6.0, Vector3(0, 1.4, 0.3))
			interact_radius = 1.4
			_solid([tile])
			ticks = true
		"echo":
			_sprite("player", 0.0, 0.0, "idle_down")
			var gm := (stage.fx._ghost_material(sprite.sheet) as ShaderMaterial).duplicate() as ShaderMaterial
			gm.set_shader_parameter("detail", 1.0)
			sprite.material_override = gm
			sprite.set_instance_shader_parameter("flash", Color(0.4, 0.95, 0.85, 1.0))
			sprite.set_instance_shader_parameter("tint", Color(1, 1, 1, 0.7))
			_light(Color(0.4, 0.95, 0.85), 1.3, 5.5, Vector3(0, 1.0, 0.3))
			interact_radius = 1.3
			ticks = true
		"icewall":
			# Rimewall: a block of ice raised on one tile - it stops foes and
			# their shots (a pillar until it melts; unsolid() gives the floor back)
			_sprite("icewall", 0.0, 0.0, "idle")
			if stage.grid.at(tile.x, tile.y) == TileGrid.FLOOR:
				stage.grid.put(tile.x, tile.y, TileGrid.PILLAR)
				stage.set_tile_solid(tile, true)
				_solid_tiles.append(tile)
			_light(Color(0.6, 0.85, 1.0), 0.5, 3.0, Vector3(0, 0.8 * Iso.SQ2, 0.2))
			ticks = data.get("bastion", false)
		"landmark":
			# a region's great centrepiece (DungeonGen._landmark), three tiles wide
			var ld := DungeonGen.landmark_def(String(data.get("id", "colossus")))
			pos = Vector2(tile) + Vector2(0.5, 0.85)
			_sprite("landmark_" + String(data.get("id", "colossus")), 0.0, 0.0, "idle")
			_flame_col = ld.get("light", Color(0.4, 0.95, 0.85))
			# lit from above and behind, so the light is around it, not on it
			_light(_flame_col, float(ld.get("energy", 0.9)), 7.5, Vector3(0, 2.4 * Iso.SQ2, -0.6))
			interact_radius = 1.6
			ticks = true
			var foot: Array = []
			for dx in [-1, 0, 1]:
				for dy in [-1, 0]:
					foot.append(tile + Vector2i(dx, dy))
			_solid(foot)
		"rug":
			_flat("rug", String(data.get("anim", "rug0")))
		"spikes":
			_flat("spikes", "down")
			ticks = true
			_t = float(data.get("phase", 0.0))
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
				if data.has("ox"):
					position = Iso.to_world(pos + Vector2(float(data.ox), 0.0), 0.0)
				if data.get("low", false):
					sprite.set_instance_shader_parameter("lead", 0.0)
			if not data.get("light", []).is_empty():
				var L: Array = data.light
				_light(L[0], L[1], L[2], Vector3(0, float(data.get("light_h", 1.2)) * Iso.SQ2, 0.3))
				ticks = true
			interact_radius = float(data.get("radius", 1.2))
			if data.get("solid", false):
				_solid([tile])
			if data.has("solid_tiles"):
				_solid(data.solid_tiles)     # a wide prop blocks more than its own tile
	if stage is Dungeon and label_name() != "":
		stage.fx.beacon(self, _label_height(), label_color())


func _sprite(sheet: String, h: float, z := 0.0, anim := "") -> void:
	sprite = PixelSprite.new()
	add_child(sprite)
	sprite.setup(sheet, anim)
	position = Iso.to_world(pos, 0.0)
	sprite.position = Vector3(0, h * Iso.SQ2, z)


## A sprite lying flat on the floor (traps, stairs).
func _flat(sheet: String, anim: String) -> void:
	sprite = PixelSprite.new()
	add_child(sprite)
	sprite.setup(sheet, anim)
	sprite.set_instance_shader_parameter("lead", 0.0)     # (it lies on the floor: no lead)
	var info := sprite.sheet
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(info.frame_size.x * Iso.TEXEL, info.frame_size.y * Iso.TEXEL * Iso.SQ2)
	q.material = info.material
	sprite.mesh = q
	position = Iso.to_world(pos, 0.0)
	sprite.position = Vector3(0, 0.008, 0)


const SPIKE_CYCLE := 2.6


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
	var row := ["ossuary", "rootmire", "throne", "camp"].find(String(data.get("row", "ossuary")))
	mi.set_instance_shader_parameter("frame", Vector2(v % info.cols, maxi(row, 0)))
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
	if kind == "spikes":
		_spike_tick()
		return
	if data.get("burning", 0.0) > 0.0:
		_burn_tick(dt)
		return
	if kind == "sconce" and lit:
		# a lit sconce burns down unless its fellows are lit in time
		data["left"] = float(data.get("left", INF)) - dt
		if float(data.left) < 3.0 and fmod(_t, 0.5) < dt:
			stage.fx.motes(pos, 1.4, Color(0.6, 0.6, 0.65), 2, 0.8, 0.6, 0.15)
		if float(data.left) <= 0.0:
			set_lit(false)
			stage.fx.burst(pos, 1.4, Color(0.55, 0.55, 0.6), 8, 1.5, 0.6, -1.5)
			Audio.play_at("steam", pos, -6.0, 1.2)
	if light and lit:
		var fl := 0.85 + 0.15 * sin(_t * 11.0 + pos.x) * sin(_t * 4.3 + pos.y * 2.0)
		var dying := clampf(float(data.get("left", INF)) / 3.0, 0.25, 1.0) if kind == "sconce" else 1.0
		light.light_energy = _base_energy * fl * dying
	if kind == "torch" and randf() < dt * 3.0:
		stage.fx.motes(pos + Vector2(0, -0.05), 1.75, _flame_col.lightened(0.2), 1, 0.8, 0.6, 0.06)
	elif (kind == "brazier" or kind == "boss_brazier") and lit and randf() < dt * 8.0:
		stage.fx.motes(pos, 1.6, _flame_col.lightened(0.2), 1, 1.4, 0.8, 0.2)
	elif kind == "boss_brazier" and not lit:
		# a cold brazier calls for fire: a slow warm pulse on the floor
		if fmod(_t, 1.4) < dt:
			stage.fx.ring(pos, 1.5, Color(1.0, 0.6, 0.3), 0.7, 0.18)
			stage.fx.motes(pos, 1.2, Color(1.0, 0.6, 0.3), 2, 0.6, 0.6, 0.2)
	elif kind == "hearthstone" and randf() < dt * 5.0:
		stage.fx.motes(pos, 1.0, Color(1.0, 0.65, 0.35), 1, 1.0, 1.0, 0.3)
	elif kind == "relic_altar" and not used and randf() < dt * 6.0:
		stage.fx.motes(pos, 1.0, Color(1.0, 0.85, 0.5), 1, 0.8, 0.8, 0.25)
	elif kind == "glowcap" and randf() < dt * 1.5:
		stage.fx.motes(pos + Vector2(randf_range(-0.4, 0.4), 0), 0.8, _flame_col, 1, 0.5, 1.6, 0.2)
	elif kind == "urn" and data.get("urnling", false) and not used:
		# an Urnling: now and then it trembles; come close and it bursts out
		if sprite:
			var shake := fmod(_t, 2.6) < 0.25
			sprite.position.x = (roundf(sin(_t * 70.0) * 1.0) / 16.0) if shake else 0.0
		if not Net.is_client() and stage.nearest_player(pos, 1.8) != null:
			used = true
			breakable = false
			_urnling_wakes()
	elif kind == "icewall" and data.get("bastion", false) and fmod(_t, 1.0) < dt and not Net.is_client():
		# Frozen Bastion: the wall chills what stands beside it
		for a in stage.hostiles(Actor.Team.PLAYER):
			if a.pos.distance_to(pos) < 1.4:
				a.status.apply_chill(0.3)
		stage.fx.motes(pos, 0.4, Color(0.7, 0.9, 1.0), 4, 0.6, 0.6, 0.6)
	elif kind == "landmark" and randf() < dt * (6.0 if used else 2.5):
		stage.fx.motes(pos + Vector2(randf_range(-1.0, 1.0), -0.2), 1.6, _flame_col.lightened(0.2), 1, 0.7, 1.4, 0.35)
	elif kind == "fountain" and not used and randf() < dt * 6.0:
		stage.fx.motes(pos, 0.9, Color(1.0, 0.6, 0.4), 1, 1.0, 0.8, 0.3)


func _spike_tick() -> void:
	var k := fmod(_t, SPIKE_CYCLE)
	var state := "down"
	if k > SPIKE_CYCLE - 1.0:
		state = "up"
	elif k > SPIKE_CYCLE - 1.6:
		state = "warn"
	if sprite.anim != state:
		sprite.play(state)
		if state == "up":
			used = false
			Audio.play_at("spikes", pos, -10.0, randf_range(0.9, 1.1), 120)
	if state == "up" and not used:
		used = true
		# spikes don't care whose foot is on them
		for a in stage.actors.duplicate():
			if a.alive and not a.flying and a.height < 0.3 and absf(a.pos.x - pos.x) < 0.5 + a.radius * 0.5 and absf(a.pos.y - pos.y) < 0.5 + a.radius * 0.5:
				var h := Hit.make(null, 14.0, ["melee"])
				h.can_crit = false
				h.knockback = Vector2.ZERO
				if a is Player:
					if (a as Player).stats.has("featherfall"):
						continue
					(a as Player).take_enemy_hit(h, null)
				else:
					h.source = stage.player
					a.take_hit(h)
				stage.fx.burst(a.pos, 0.3, Color(0.85, 0.85, 0.9), 4, 2.0, 0.2, 6.0)


# --- interaction ---------------------------------------------------------------

func interactable() -> bool:
	match kind:
		"chest", "ember_pile", "relic_altar", "spring", "fountain", "ember_well", "trial_altar", "lost_camp":
			return not used
		"sconce":
			return not lit
		"echo":
			return not used
		"landmark":
			# the Heart takes blood from each Kindled once; the others answer once
			return not used
		"shrine", "merchant", "stairs", "hearthstone", "lore":
			return true
	return data.has("prompt") and not used


## The name over it in the world ("" for none): what it is, at a glance.
func label_name() -> String:
	match kind:
		"chest":
			if data.get("sealed", false):
				return "Sealed Reliquary"
			return "Ancient Chest" if int(data.get("tier", 1)) >= 2 else "Treasure Chest"
		"ember_pile":
			return "Ember Pile"
		"relic_altar":
			return "Relic Altar"
		"spring":
			return "Spring of Vigor"
		"fountain":
			return "Ember Fountain"
		"shrine":
			return "Shrine of Pacts"
		"merchant":
			return "Merchant"
		"stairs":
			if data.has("route"):
				return String(DungeonGen.route_def(String(data.route)).get("name", "Stairs Down"))
			return "Stairs Down"
		"hearthstone":
			return "Hearthstone"
		"lore":
			return "Lorestone"
		"ember_well":
			return "Ember Well"
		"site":
			return String(data.get("label", ""))
		"trial_altar":
			return String(data.get("label", "Trial Altar"))
		"echo":
			return "Echo of a Fallen Kindled"
		"sconce":
			return "Unlit Sconce"
		"lost_camp":
			return "Lost Camp"
		"landmark":
			return String(DungeonGen.landmark_def(String(data.get("id", ""))).get("name", ""))
	return ""


## The colour of its kind: treasure gold, the Undervault's magic soul-teal,
## a bargain with a price rose, the way onward pale gold, trade amber.
func label_color() -> Color:
	match kind:
		"chest", "ember_pile":
			return Color(1.0, 0.82, 0.4)
		"shrine":
			return Color(0.98, 0.48, 0.62)
		"site":
			return data.get("col", Color(0.52, 0.96, 0.88))
		"stairs", "hearthstone":
			if kind == "stairs" and data.has("route"):
				return (DungeonGen.route_def(String(data.route)).get("color", Color.WHITE) as Color).lightened(0.25)
			return Color(1.0, 0.94, 0.74)
		"merchant":
			return Color(1.0, 0.7, 0.42)
		"sconce", "lost_camp":
			return Color(1.0, 0.62, 0.32)
		"landmark":
			match String(data.get("id", "")):
				"heartroot":
					return Color(0.98, 0.48, 0.62)
				"sundisc":
					return Color(1.0, 0.82, 0.4)
	return Color(0.52, 0.96, 0.88)


func _label_height() -> float:
	if kind == "stairs" and data.has("route"):
		return 2.9      # over its arch
	if sprite and sprite.sheet:
		return float(sprite.sheet.frame_size.y) / 16.0 / Iso.SQ2 + 0.3
	return 1.0


func prompt() -> String:
	match kind:
		"chest":
			return "Sealed reliquary" if data.get("sealed", false) else "Open"
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
			if data.has("route"):
				return "Descend: %s" % DungeonGen.route_def(String(data.route)).get("act", "")
			return "Descend"
		"hearthstone":
			return "Return to the Hearth"
		"lore":
			return "Read"
		"ember_well":
			return "Draw from the Well"
		"trial_altar":
			return String(data.get("ask", "Begin the Trial"))
		"echo":
			return "Speak with the Echo"
		"sconce":
			return "Light the sconce"
		"lost_camp":
			return "Rekindle the fire"
		"landmark":
			return String(DungeonGen.landmark_def(String(data.get("id", ""))).get("prompt", "Touch"))
	return String(data.get("prompt", ""))


func interact(pl: Player) -> void:
	match kind:
		"chest":
			if data.get("sealed", false):
				stage.request("sealed", self)
				return
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
		"ember_well":
			stage.request("well", self)
		"trial_altar":
			stage.request("trial", self)
		_:
			stage.request(kind, self)


const URN_COLORS := {"clay": [Color(0.86, 0.8, 0.68), Color(0.42, 0.85, 0.8)], "root": [Color(0.5, 0.38, 0.26), Color(0.45, 0.62, 0.3)],
	"gilded": [Color(0.32, 0.31, 0.38), Color(1.0, 0.78, 0.35)]}
const URN_MATS := ["clay", "root", "gilded"]


## An urn goes: a crack, then shards and dust, its pieces left on the floor,
## the sound of its own material - and whatever was inside. (Drops come from
## the stage's generator: a glinting urn always pays, a plain one sometimes.)
func _shatter_urn() -> void:
	var mat := String(data.get("mat", "clay"))
	if sprite and sprite.has_anim("crack"):
		sprite.play("crack")
		sprite.flash(Color(1, 1, 1), 0.05)
	var st := stage
	var p := pos
	var rich: bool = data.get("rich", false)
	var cols: Array = URN_COLORS.get(mat, URN_COLORS.clay)
	Audio.play_at("urn" if mat == "clay" else "urn_" + mat, p, -1.0, randf_range(0.94, 1.06))
	st.after(0.06, func() -> void:
		st.fx.burst(p, 0.45, cols[0], 16, 4.6, 0.55, 10.0, Vector2.ZERO, PI, 2.6, 1.0)
		st.fx.burst(p, 0.45, cols[1], 6, 4.0, 0.5, 10.0)
		st.fx.burst(p, 0.2, Color(0.55, 0.5, 0.46), 8, 1.1, 0.9, -0.6)
		st.fx.debris(p + Vector2(0, 0.05), "urn_shards", URN_MATS.find(mat), 45.0)
		if rich:
			st.fx.flash_light(p, 0.5, Color(1.0, 0.8, 0.4), 2.0, 3.0, 0.3)
			st.fx.motes(p, 0.5, Color(1.0, 0.85, 0.45), 10, 1.0, 0.8, 0.4)
		_urn_loot(st, p, rich, mat)
		st.props.erase(self)
		queue_free())


const URNLINGS := {"clay": "skitter", "root": "sporeling", "gilded": "hound"}


## An Urnling breaks out: the urn bursts and a quick, hasted thing comes out
## of it - felled, it spills what the urn held, twice over.
func _urnling_wakes() -> void:
	var st := stage
	var d := st as Dungeon
	var mat := String(data.get("mat", "clay"))
	var p := pos
	if sprite and sprite.has_anim("crack"):
		sprite.play("crack")
	Audio.play_at("urn" if mat == "clay" else "urn_" + mat, p, 0.0, 0.85)
	Audio.play_at("frenzy", p, -4.0, 1.4)
	var cols: Array = URN_COLORS.get(mat, URN_COLORS.clay)
	st.fx.burst(p, 0.45, cols[0], 18, 5.0, 0.55, 10.0, Vector2.ZERO, PI, 2.6, 1.0)
	st.fx.debris(p + Vector2(0, 0.05), "urn_shards", URN_MATS.find(mat), 45.0)
	st.fx.number(p, 2.2, "URNLING!", Color(1.0, 0.6, 0.45), true)
	if d:
		var id: String = URNLINGS.get(mat, "skitter")
		var e := d._make_enemy(id)
		e.pos = p
		d._scale(e, d.layout.depth, int(Profile.data.world.get("memory", 0)))
		d._coop_scale(e)
		e.make_elite("hasted")
		e.display_name = "Urnling"
		e.spawn_t = 0.25
		e.room_id = room_id
		var rng_mat := mat
		e.died_enemy.connect(func(_e: Enemy) -> void:
			_urn_loot(st, p, true, rng_mat)
			_urn_loot(st, p, true, rng_mat))
		d.add_actor(e)
		Profile.note_seen("enemies", id)
	st.props.erase(self)
	unsolid()
	queue_free()


static func _urn_loot(st: Stage, p: Vector2, rich: bool, mat: String) -> void:
	var rng := st.rng
	var region_mat: String = {"root": "rootwood", "gilded": "sun_gold"}.get(mat, "bone_dust")
	if rich:
		for i in rng.randi_range(4, 7):
			Pickup.spawn(st, "ember", p, 2)
		Pickup.spawn(st, "material", p, 1, {"id": region_mat})
		if rng.randf() < 0.15:
			Pickup.spawn(st, "material", p, 1, {"id": "ember_core"})
		return
	var roll := rng.randf()
	if roll < 0.4:
		for i in rng.randi_range(1, 2):
			Pickup.spawn(st, "ember", p, 1)
	elif roll < 0.5:
		Pickup.spawn(st, "heal", p, 8)
	elif roll < 0.55:
		Pickup.spawn(st, "material", p, 1, {"id": region_mat})


func on_struck(src: Node, fire := false) -> void:
	match kind:
		"bramble", "root_node", "bramble_wall":
			if data.get("burning", 0.0) > 0.0 or used:
				return
			if fire:
				ignite()
				return
			data["hp"] = int(data.get("hp", 3)) - 1
			stage.fx.burst(pos, 0.5, Color(0.45, 0.6, 0.3), 6, 3.0, 0.3, 6.0)
			Audio.play("claw", -6.0, randf_range(1.1, 1.3))
			if int(data.hp) <= 0:
				_clear_bramble(false)
		"urn":
			used = true
			breakable = false
			if data.get("urnling", false) and not Net.is_client():
				_urnling_wakes()
			else:
				_shatter_urn()
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


## Brambles catch fire from any fire hit, burn for a moment (scorching nearby
## enemies) and pass the flames on to neighbouring brambles.
func ignite() -> void:
	if used or data.get("burning", 0.0) > 0.0:
		return
	data["burning"] = 1.1
	sprite.play("burning")
	if light == null:
		_light(Color(1.0, 0.55, 0.25), 1.6, 4.0, Vector3(0, 0.6, 0.2))
	else:
		light.light_color = Color(1.0, 0.55, 0.25)
		_base_energy = 1.8
	Audio.play("ignite", -6.0, randf_range(0.9, 1.15))
	var st := stage
	var me: WeakRef = weakref(self)
	st.after(0.3, func() -> void:
		var self_ref = me.get_ref()
		if self_ref == null:
			return
		for p in st.props:
			if is_instance_valid(p) and p != self_ref and p.kind in ["bramble", "root_node", "bramble_wall"] and not p.used and p.pos.distance_to(self_ref.pos) < 1.6:
				p.ignite())


func _burn_tick(dt: float) -> void:
	data["burning"] = float(data.burning) - dt
	_t += dt
	if light:
		light.light_energy = _base_energy * (0.8 + 0.2 * sin(_t * 20.0))
	if randf() < dt * 20.0:
		stage.fx.motes(pos, 0.4, Color(1.0, randf_range(0.4, 0.8), 0.2), 1, 2.0, 0.6, 0.4)
	if fmod(_t, 0.35) < dt:
		for a in stage.in_circle(Actor.Team.PLAYER, pos, 1.3):
			var h := Hit.make(stage.player, 6.0, ["fire", "dot"])
			h.burn = 1
			h.can_crit = false
			h.silent = true
			a.take_hit(h)
	if float(data.burning) <= 0.0:
		_clear_bramble(true)


func _clear_bramble(burnt: bool) -> void:
	if not used and stage is Dungeon and kind != "root_node":
		(stage as Dungeon).note_request("bramble")
	used = true
	breakable = false
	data["burning"] = 0.0
	stops_shots = false
	unsolid()
	if light:
		light.visible = false
	if kind == "bramble_wall":
		stage.request("secret", self)
		return
	sprite.play("burnt" if burnt else "burnt")
	# what is left lies low and dark: plainly no longer a wall of thorns
	sprite.scale = Vector3(1.0, 0.45, 1.0)
	sprite.set_tint(Color(0.55, 0.5, 0.5, 1.0))
	if not burnt:
		stage.fx.burst(pos, 0.5, Color(0.45, 0.6, 0.3), 12, 4.0, 0.4, 6.0)
	if kind == "root_node":
		var b = data.get("boss")
		if b and is_instance_valid(b):
			b.on_root_burned(self)


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
