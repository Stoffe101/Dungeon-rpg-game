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
var foreign := false          # someone else's own find: nothing of it shows on this machine
var net_id := 0
var replica := false
var _announced := false
var _landed := false
var _hang := 0.0              # a great find hangs in the air a moment before it falls
static var _beam_tex: GradientTexture2D

const SHEETS := {"ember": "pickup_ember", "xp": "pickup_memory", "heal": "pickup_heal", "sunshard": "pickup_sunshard",
	"material": "pickup_mat", "gear": "pickup_gear", "blueprint": "pickup_scroll", "rune": "pickup_scroll"}
const COLORS := {"ember": Color(1.0, 0.6, 0.25), "xp": Color(0.4, 1.0, 0.9), "heal": Color(1.0, 0.45, 0.45), "sunshard": Color(1.0, 0.9, 0.5)}


static func spawn(st: Stage, k: String, p: Vector2, amt: int, extra := {}, owner := 0) -> Pickup:
	var pk := Pickup.new()
	pk.stage = st
	pk.kind = k
	pk.amount = amt
	pk.data = extra
	pk.pos = p
	pk.owner_peer = owner
	var a := randf() * TAU
	pk.vel = Vector2.from_angle(a) * randf_range(1.0, 3.5)
	pk.vz = randf_range(3.0, 5.0)
	st.add_child(pk)
	st.pickups.append(pk)
	return pk


## This machine's own seat (solo: 0 and 1 both mean "mine").
func _me() -> int:
	if stage and stage.player:
		return stage.player.peer_id
	return Net.my_id()


func _ready() -> void:
	sprite = PixelSprite.new()
	add_child(sprite)
	sprite.setup(SHEETS.get(kind, "pickup_ember"))
	# another Kindled's own find: on this machine there is nothing to see or
	# hear - no sprite, light, beam, name or chime (the host still carries it
	# for its owner, who alone sees it fall and alone can take it)
	foreign = owner_peer != 0 and owner_peer != _me()
	if foreign:
		visible = false
		if kind == "gear":
			grade = {"rare": 1, "epic": 2, "set": 3, "legendary": 3}.get(String(data.get("item", {}).get("rarity", "")), 0)
		return
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
		if ItemDB.is_unique(String(data.get("item", {}).get("base", ""))):
			grade = 3
		if grade > 0:
			_loot_beam(gc)
		if grade >= 3 and not replica:
			# it rises out of the fallen, turns in the air, and only then drops
			_hang = 0.6
			vz = 0.0
			vel *= 0.3
			Net.mute += 1
			Audio.play_at("drop_rise", pos, -4.0, 1.0, 200)
			Net.mute -= 1
	elif kind == "sunshard" or kind == "heal":
		light = OmniLight3D.new()
		light.light_color = COLORS[kind]
		light.light_energy = 0.8
		light.omni_range = 2.5
		light.position = Vector3(0, 0.4, 0)
		add_child(light)
	# (deferred: whoever spawns a find sets its owner just after)
	_name_tag.call_deferred()
	_sync()


## A notable find says what it is over where it lies, in its own colour, so a
## drop across the room can be read (only to whoever it is for).
func _name_tag() -> void:
	if stage == null or stage.fx == null or not (stage is Dungeon):
		return
	if foreign:
		return
	var text := ""
	var col := Color.WHITE
	match kind:
		"gear":
			if grade <= 0:
				return
			var it: Dictionary = data.get("item", {})
			text = ItemDB.item_name(it)
			col = ItemDB.color(it)
		"rune":
			var rd := Runes.get_def(String(data.get("id", "")))
			text = "Rune: %s" % rd.get("name", "?")
			col = rd.get("color", Color.WHITE)
		"blueprint":
			text = "Blueprint: %s" % ItemDB.base(String(data.get("id", ""))).get("name", "?")
			col = Color(1.0, 0.75, 0.35)
		_:
			return
	stage.fx.tag(self, 0.9, text, col)


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
	if foreign:
		return
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
			Audio.play_at("drop_rare", pos, -8.0, randf_range(0.97, 1.03), 120)
		2:
			Audio.play_at("drop_epic", pos, -5.0, 1.0, 150)
			stage.fx.motes(pos, 0.2, col, 8, 1.4, 1.0, 0.3)
		_:
			Audio.play_at("drop_legendary", pos, -2.0, 1.0, 250)
			stage.fx.flash_light(pos, 1.0, col, 3.0, 6.0, 0.5)
			stage.fx.motes(pos, 0.2, col, 16, 2.0, 1.4, 0.4)
			stage.fx.ring(pos, 2.2, col, 0.7, 0.12)
			stage.fx.shake(0.12)


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
	var ev := ["pick+", [net_id, kind, pos, height, Vector2.ZERO, amount, data, owner_peer]]
	if owner_peer == 0:
		Net.rec(ev)
	elif owner_peer != Net.my_id():
		Net.rec(["own", owner_peer, ev])     # sent to its owner alone


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
	if age > 0.45 and _hang <= 0.0 and (d < rad or magnet):
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
	if _hang > 0.0:
		# held up in the air, turning, glittering; then let go
		_hang -= dt
		height = move_toward(height, 1.3, dt * 4.0)
		pos = stage.grid.move_box(pos, 0.1, vel * dt, false)
		vel *= exp(-6.0 * dt)
		if sprite:
			sprite.flip_h = fmod(age * 5.0, 2.0) < 1.0
		if randf() < dt * 30.0:
			var col: Color = light.light_color if light else Color.WHITE
			stage.fx.motes(pos, height, col, 1, 0.9, 0.5, 0.15)
		if _hang <= 0.0:
			vz = -2.0
			if sprite:
				sprite.flip_h = false
		_sync()
		return
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
		if owner_peer == 0:
			Net.rec(["pick-", net_id])
		elif owner_peer != Net.my_id():
			Net.rec(["own", owner_peer, ["pick-", net_id]])
	if kind in ["gear", "rune", "blueprint"]:
		_take_find(pl)
		queue_free()
		return
	var col: Color = COLORS.get(kind, Color.WHITE)
	stage.fx.burst(pl.pos, 0.8, col, 4, 2.0, 0.25, 0.0)
	# co-op: currency, memories, materials and Sunshards are shared - whoever
	# picks them up, every Kindled's run is credited the same (Party.award_*)
	var party: Array = stage.players if kind in ["ember", "xp", "material", "sunshard"] and owner_peer == 0 else [pl]
	match kind:
		"ember":
			if owner_peer == 0:
				Party.award_embers(stage, amount, String(data.get("src", "orb")))
			else:
				pl.run.embers += int(round(amount * pl.stats.v("ember_gain")))
				Events.currency_changed.emit()
			Audio.play("pickup_ember", -8.0, randf_range(1.0, 1.25))
		"xp":
			Party.award_xp(stage, amount, String(data.get("src", "orb")))
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
		"sunshard":
			for p in party:
				p.run.sunshards += amount
			stage.fx.number(pl.pos, 2.4, "SUNSHARD", Color(1.0, 0.9, 0.5), true)
			if stage is Dungeon:
				(stage as Dungeon).note_request("sunshard", amount)
			Audio.play("pickup_sunshard", 0.0)
			Events.currency_changed.emit()
	queue_free()


## A find of one's own (gear, a rune, a blueprint) goes into its finder's
## Satchel the moment it is taken - inspected, compared and worn on the same
## expedition. Gear, runes and blueprints were always kept, even on a death,
## so nothing is risked by banking them at once; materials still ride with
## the run (half are lost on a death). A guest's find is delivered to their
## machine (NetRun.give: acknowledged, sent again after a rejoin, and banked
## once by its drop id). Only the finder sees and hears it found.
func _take_find(pl: Player) -> void:
	var payload: Variant = data.get("item", {}) if kind == "gear" else String(data.get("id", ""))
	var drop := String(data.get("drop", ""))
	if drop == "" and stage is Dungeon:
		drop = (stage as Dungeon).next_drop()
	if kind == "gear":
		payload = (payload as Dictionary).duplicate(true)
		payload["drop"] = drop
	if pl.run:
		pl.run.found.append({"kind": kind, "what": payload, "drop": drop})
	if pl.controller == Player.Ctrl.LOCAL:
		Profile.bank_find(kind, payload, drop)
		Net.mute += 1
		found_fx(stage, pl, kind, payload, grade)
		Net.mute -= 1
	elif Net.active() and Net.i.run_sync:
		Net.i.run_sync.give(pl, kind, payload, drop, grade)
	elif pl.run:
		# (no link: a stand-in Kindled in a test - its run carries it home)
		var key: String = {"gear": "gear", "rune": "runes", "blueprint": "blueprints"}[kind]
		(pl.run.loot[key] as Array).append(payload)
	if kind == "gear" and grade >= 2:
		Party.announce_find(stage, pl, payload)


## The finder's own moment (only on their machine): the name rising, rings,
## the chime, a banner for the great ones, and where it went.
static func found_fx(st: Stage, pl: Player, kind: String, what: Variant, grade: int) -> void:
	if st == null or pl == null or not is_instance_valid(pl):
		return
	match kind:
		"rune":
			var rd := Runes.get_def(String(what))
			var rc2: Color = rd.get("color", Color.WHITE)
			st.fx.number(pl.pos, 2.6, String(rd.get("name", "RUNE")).to_upper(), rc2, true)
			st.fx.ring(pl.pos, 1.6, rc2, 0.4, 0.25)
			Events.toast.emit("Rune found: %s - in your Satchel; set it in a spell at the Gate (Runes)" % rd.get("name", "?"), rc2)
			Audio.play("learn", -4.0, 1.2)
		"blueprint":
			var bid := String(what)
			st.fx.number(pl.pos, 2.6, "BLUEPRINT", Color(1.0, 0.75, 0.35), true)
			st.fx.ring(pl.pos, 1.6, Color(1.0, 0.75, 0.35), 0.4, 0.25)
			st.fx.flash_light(pl.pos, 1.0, Color(1.0, 0.75, 0.35), 3.0, 5.0, 0.4)
			Events.toast.emit("Blueprint found: %s - learn it in your Satchel" % ItemDB.base(bid).get("name", "?"), Color(1.0, 0.75, 0.35))
			Audio.play("learn", -2.0)
		"gear":
			var it: Dictionary = what
			var rc := ItemDB.color(it)
			st.fx.number(pl.pos, 2.4, ItemDB.item_name(it).to_upper(), rc, true)
			st.fx.ring(pl.pos, 1.2, rc, 0.3, 0.2)
			if grade >= 2:
				st.fx.ring(pl.pos, 2.0, rc, 0.5, 0.15)
				st.fx.motes(pl.pos, 0.3, rc, 12 + 8 * grade, 1.8, 1.2, 0.5)
				st.fx.flash_light(pl.pos, 1.0, rc, 2.5 + grade, 6.0, 0.5)
			if grade >= 3 and Game.ui:
				Game.ui.banner(ItemDB.item_name(it), "%s found" % ItemDB.RARITY[it.rarity].name)
			Events.toast.emit("Found: %s %s - in your Satchel [%s]" % [ItemDB.RARITY[it.rarity].name, ItemDB.item_name(it), Settings.describe_action("inventory")], rc)
			Audio.play("relic", -4.0)

