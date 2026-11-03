## Loot on the floor: embers, memory motes (xp), hearth-light (healing),
## sunshards. Pops out, settles, then is drawn to the Kindled's lantern.
class_name Pickup
extends Node3D

var stage: Stage
var kind := "ember"
var amount := 1
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var height := 0.0
var vz := 0.0
var age := 0.0
var magnet := false
var sprite: PixelSprite
var light: OmniLight3D
var data: Dictionary = {}     # "material": {id}; "gear": {item}
var beam: Node3D              # a pillar of light over notable loot
var grade := 0                # 0 plain, 1 rare, 2 epic, 3 legendary / set / blueprint
var owner_peer := 0           # co-op: 0 shared, else the one player who may take it
var net_id := 0
var replica := false
var _announced := false
var _landed := false
static var _beam_tex: GradientTexture2D

const SHEETS := {"ember": "pickup_ember", "xp": "pickup_memory", "heal": "pickup_heal", "sunshard": "pickup_sunshard",
	"material": "pickup_mat", "gear": "pickup_gear", "blueprint": "pickup_scroll", "rune": "pickup_scroll"}
const COLORS := {"ember": Color(1.0, 0.6, 0.25), "xp": Color(0.4, 1.0, 0.9), "heal": Color(1.0, 0.45, 0.45), "sunshard": Color(1.0, 0.9, 0.5)}


static func spawn(st: Stage, k: String, p: Vector2, amt: int, extra := {}) -> Pickup:
	var pk := Pickup.new()
	pk.stage = st
	pk.kind = k
	pk.amount = amt
	pk.data = extra
	pk.pos = p
	var a := randf() * TAU
	pk.vel = Vector2.from_angle(a) * randf_range(1.0, 3.5)
	pk.vz = randf_range(3.0, 5.0)
	st.add_child(pk)
	st.pickups.append(pk)
	return pk


func _ready() -> void:
	sprite = PixelSprite.new()
	add_child(sprite)
	sprite.setup(SHEETS.get(kind, "pickup_ember"))
	if kind == "rune":
		var rc: Color = Runes.get_def(String(data.get("id", ""))).get("color", Color.WHITE)
		light = OmniLight3D.new()
		light.light_color = rc
		light.light_energy = 1.6
		light.omni_range = 3.0
		light.position = Vector3(0, 0.4, 0)
		add_child(light)
		sprite.set_tint(rc.lightened(0.3))
		grade = 2
		_loot_beam(rc)
	elif kind == "blueprint":
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.35)
		light.light_energy = 1.6
		light.omni_range = 3.0
		light.position = Vector3(0, 0.4, 0)
		add_child(light)
		grade = 3
		_loot_beam(Color(1.0, 0.75, 0.35))
	elif kind == "gear":
		var gc := ItemDB.color(data.get("item", {}))
		light = OmniLight3D.new()
		light.light_color = gc
		light.light_energy = 1.0 + (0.8 if data.get("item", {}).get("rarity", "") in ["epic", "legendary"] else 0.0)
		light.omni_range = 2.8
		light.position = Vector3(0, 0.4, 0)
		add_child(light)
		sprite.flash(gc, 0.6)
		grade = {"rare": 1, "epic": 2, "set": 3, "legendary": 3}.get(String(data.get("item", {}).get("rarity", "")), 0)
		if grade > 0:
			_loot_beam(gc)
	elif kind == "sunshard" or kind == "heal":
		light = OmniLight3D.new()
		light.light_color = COLORS[kind]
		light.light_energy = 0.8
		light.omni_range = 2.5
		light.position = Vector3(0, 0.4, 0)
		add_child(light)
	_sync()


## A pillar of the drop's colour, so a good find is seen across the room.
func _loot_beam(col: Color) -> void:
	if _beam_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_beam_tex = GradientTexture2D.new()
		_beam_tex.gradient = g
		_beam_tex.fill_from = Vector2(0.5, 1.0)
		_beam_tex.fill_to = Vector2(0.5, 0.0)
		_beam_tex.width = 4
		_beam_tex.height = 64
	beam = Node3D.new()
	add_child(beam)
	var tall := 2.4 + grade * 0.9
	for k in 2:
		var q := MeshInstance3D.new()
		var m := QuadMesh.new()
		m.size = Vector2((0.26 if k == 0 else 0.08) * (1.0 + 0.25 * grade), tall * Iso.SQ2)
		q.mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.albedo_texture = _beam_tex
		var c := col.lerp(Color.WHITE, 0.0 if k == 0 else 0.55)
		mat.albedo_color = Color(c.r, c.g, c.b, 0.3 if k == 0 else 0.75)
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = Vector3(0, m.size.y * 0.5, 0)
		beam.add_child(q)
	beam.visible = false   # rises once the drop has landed


## The drop hits the floor: a chime by rarity, and its beam goes up.
func _land() -> void:
	_landed = true
	Net.mute += 1    # every machine plays its own landing
	_land_fx()
	Net.mute -= 1


func _land_fx() -> void:
	if beam:
		beam.visible = true
		beam.scale = Vector3(1.0, 0.05, 1.0)
		var tw := create_tween()
		tw.tween_property(beam, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if grade <= 0:
		return
	var col: Color = light.light_color if light else Color.WHITE
	stage.fx.ring(pos, 0.6 + 0.3 * grade, col, 0.4, 0.2)
	match grade:
		1:
			Audio.play_at("wisp", pos, -10.0, 1.1, 120)
		2:
			Audio.play_at("wisp", pos, -6.0, 0.85, 120)
			stage.fx.motes(pos, 0.2, col, 8, 1.4, 1.0, 0.3)
		_:
			Audio.play_at("learn", pos, -4.0, 1.0, 200)
			stage.fx.flash_light(pos, 1.0, col, 3.0, 6.0, 0.5)
			stage.fx.motes(pos, 0.2, col, 16, 2.0, 1.4, 0.4)


## A find is news for its finder only (co-op: on their machine).
func _tell(pl: Player, text: String, col: Color) -> void:
	Net.mute += 1
	if Net.recording and Net.i.run_sync and pl != stage.player:
		Net.i.run_sync.tell(pl, text, col)
	else:
		Events.toast.emit(text, col)
	Net.mute -= 1


func _owner() -> Player:
	for p in stage.players:
		if p.peer_id == owner_peer:
			return p
	return null


func _announce() -> void:
	_announced = true
	if not Net.recording or Net.i.run_sync == null:
		return
	net_id = Net.i.run_sync.next_proj_id()
	Net.rec(["pick+", [net_id, kind, pos, height, Vector2.ZERO, amount, data, owner_peer]])


## Co-op client: sits where the host says (positions arrive in snapshots).
func replica_step(dt: float) -> void:
	age += dt
	if beam and beam.visible and not Settings.get_value("reduce_flashes", false):
		var pulse := 1.0 + 0.12 * sin(age * 3.0)
		beam.scale.x = pulse
		beam.scale.z = pulse
	_sync()


func tick(dt: float) -> void:
	if not _announced:
		_announce()
	age += dt
	if beam and beam.visible and not Settings.get_value("reduce_flashes", false):
		var pulse := 1.0 + 0.12 * sin(age * 3.0)
		beam.scale.x = pulse
		beam.scale.z = pulse
	# drawn to the nearest Kindled (co-op: anyone, unless it is someone's own find)
	var pl: Player = stage.nearest_player(pos) if owner_peer == 0 else _owner()
	if pl == null or not pl.alive:
		_physics(dt)
		return
	var d := pl.pos.distance_to(pos)
	var rad := pl.stats.v("pickup_radius")
	if kind == "heal" and pl.hp >= pl.max_hp:
		rad = 0.0
	if age > 0.45 and (d < rad or magnet):
		var spd := 6.0 + (12.0 if magnet else 0.0) + age * 2.0
		pos = pos.move_toward(pl.pos, spd * dt)
		height = move_toward(height, 0.5, dt * 2.0)
		if pos.distance_to(pl.pos) < 0.35:
			_collect(pl)
			return
	else:
		_physics(dt)
	_sync()


func _physics(dt: float) -> void:
	if height > 0.0 or vz > 0.0:
		vz -= 18.0 * dt
		height += vz * dt
		if height <= 0.0:
			height = 0.0
			vz = -vz * 0.35 if absf(vz) > 1.5 else 0.0
			if not _landed and age > 0.1:
				_land()
	pos = stage.grid.move_box(pos, 0.1, vel * dt, false)
	vel *= exp(-4.0 * dt)
	_sync()


func _sync() -> void:
	var bob := sin(age * 5.0 + pos.x) * 0.06 if height <= 0.01 else 0.0
	position = Iso.to_world(Vector2(roundf(pos.x * 16.0) / 16.0, roundf(pos.y * 16.0) / 16.0), 0.0)
	sprite.position = Vector3(0, roundf((height + bob + 0.1) * 16.0) / 16.0 * Iso.SQ2, 0)


func _collect(pl: Player) -> void:
	stage.pickups.erase(self)
	if net_id != 0 and Net.recording:
		Net.rec(["pick-", net_id])
	var col: Color = COLORS.get(kind, Color.WHITE)
	stage.fx.burst(pl.pos, 0.8, col, 4, 2.0, 0.25, 0.0)
	# co-op: currency, memories, materials and Sunshards are shared - whoever
	# picks them up, every Kindled's run is credited (each with their own bonuses)
	var party: Array = stage.players if kind in ["ember", "xp", "material", "sunshard"] and owner_peer == 0 else [pl]
	match kind:
		"ember":
			for p in party:
				p.run.embers += int(round(amount * p.stats.v("ember_gain")))
			Audio.play("pickup_ember", -8.0, randf_range(1.0, 1.25))
			Events.currency_changed.emit()
		"xp":
			for p in party:
				var n2 := int(round(amount * p.stats.v("xp_gain")))
				p.run.xp_gained += n2
				if p.controller == Player.Ctrl.LOCAL:
					Profile.add_xp(n2)
			Audio.play("pickup_xp", -8.0, randf_range(0.95, 1.15))
		"heal":
			pl.heal(amount * pl.stats.v("heal_mult"))
			Audio.play("pickup_heal", -4.0)
		"material":
			var mid := String(data.get("id", "bone_dust"))
			for p in party:
				p.run.add_material(mid, amount)
			stage.fx.number(pl.pos, 2.0, "+%d %s" % [amount, ItemDB.MATERIALS[mid].name], Color(0.85, 0.82, 0.7))
			Audio.play("pickup_xp", -6.0, 0.8)
		"rune":
			var rid := String(data.get("id", ""))
			(pl.run.loot.get("runes", []) as Array).append(rid)
			if not pl.run.loot.has("runes"):
				pl.run.loot["runes"] = [rid]
			var rd := Runes.get_def(rid)
			var rc2: Color = rd.get("color", Color.WHITE)
			stage.fx.number(pl.pos, 2.6, String(rd.get("name", "RUNE")).to_upper(), rc2, true)
			stage.fx.ring(pl.pos, 1.6, rc2, 0.4, 0.25)
			_tell(pl, "Rune found: %s - set it in a spell at the Gate (Runes)" % rd.get("name", "?"), rc2)
			Audio.play("learn", -4.0, 1.2)
		"blueprint":
			var bid := String(data.get("id", ""))
			(pl.run.loot.blueprints as Array).append(bid)
			stage.fx.number(pl.pos, 2.6, "BLUEPRINT", Color(1.0, 0.75, 0.35), true)
			stage.fx.ring(pl.pos, 1.6, Color(1.0, 0.75, 0.35), 0.4, 0.25)
			stage.fx.flash_light(pl.pos, 1.0, Color(1.0, 0.75, 0.35), 3.0, 5.0, 0.4)
			_tell(pl, "Blueprint found: %s - learn it in your Satchel" % ItemDB.base(bid).get("name", "?"), Color(1.0, 0.75, 0.35))
			Audio.play("learn", -2.0)
		"gear":
			var it: Dictionary = data.get("item", {})
			(pl.run.loot.gear as Array).append(it)
			var rc := ItemDB.color(it)
			stage.fx.number(pl.pos, 2.4, ItemDB.item_name(it).to_upper(), rc, true)
			stage.fx.ring(pl.pos, 1.2, rc, 0.3, 0.2)
			if grade >= 2:
				stage.fx.ring(pl.pos, 2.0, rc, 0.5, 0.15)
				stage.fx.motes(pl.pos, 0.3, rc, 12 + 8 * grade, 1.8, 1.2, 0.5)
				stage.fx.flash_light(pl.pos, 1.0, rc, 2.5 + grade, 6.0, 0.5)
			if grade >= 3 and pl == stage.player:
				Events.banner.emit(ItemDB.item_name(it), "%s found" % ItemDB.RARITY[it.rarity].name)
			_tell(pl, "Found: %s %s - [%s] Satchel" % [ItemDB.RARITY[it.rarity].name, ItemDB.item_name(it), Settings.describe_action("inventory")], rc)
			Audio.play("relic", -4.0)
		"sunshard":
			for p in party:
				p.run.sunshards += amount
			stage.fx.number(pl.pos, 2.4, "SUNSHARD", Color(1.0, 0.9, 0.5), true)
			if stage is Dungeon:
				(stage as Dungeon).note_request("sunshard", amount)
			Audio.play("pickup_sunshard", 0.0)
			Events.currency_changed.emit()
	queue_free()
