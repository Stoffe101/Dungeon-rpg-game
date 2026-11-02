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

const SHEETS := {"ember": "pickup_ember", "xp": "pickup_memory", "heal": "pickup_heal", "sunshard": "pickup_sunshard"}
const COLORS := {"ember": Color(1.0, 0.6, 0.25), "xp": Color(0.4, 1.0, 0.9), "heal": Color(1.0, 0.45, 0.45), "sunshard": Color(1.0, 0.9, 0.5)}


static func spawn(st: Stage, k: String, p: Vector2, amt: int) -> Pickup:
	var pk := Pickup.new()
	pk.stage = st
	pk.kind = k
	pk.amount = amt
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
	if kind == "sunshard" or kind == "heal":
		light = OmniLight3D.new()
		light.light_color = COLORS[kind]
		light.light_energy = 0.8
		light.omni_range = 2.5
		light.position = Vector3(0, 0.4, 0)
		add_child(light)
	_sync()


func tick(dt: float) -> void:
	age += dt
	var pl := stage.player
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
	pos = stage.grid.move_box(pos, 0.1, vel * dt, false)
	vel *= exp(-4.0 * dt)
	_sync()


func _sync() -> void:
	var bob := sin(age * 5.0 + pos.x) * 0.06 if height <= 0.01 else 0.0
	position = Iso.to_world(Vector2(roundf(pos.x * 16.0) / 16.0, roundf(pos.y * 16.0) / 16.0), 0.0)
	sprite.position = Vector3(0, roundf((height + bob + 0.1) * 16.0) / 16.0 * Iso.SQ2, 0)


func _collect(pl: Player) -> void:
	stage.pickups.erase(self)
	var col: Color = COLORS.get(kind, Color.WHITE)
	stage.fx.burst(pl.pos, 0.8, col, 4, 2.0, 0.25, 0.0)
	match kind:
		"ember":
			var n := int(round(amount * pl.stats.v("ember_gain")))
			pl.run.embers += n
			Audio.play("pickup_ember", -8.0, randf_range(1.0, 1.25))
			Events.currency_changed.emit()
		"xp":
			var n2 := int(round(amount * pl.stats.v("xp_gain")))
			pl.run.xp_gained += n2
			Profile.add_xp(n2)
			Audio.play("pickup_xp", -8.0, randf_range(0.95, 1.15))
		"heal":
			pl.heal(amount * pl.stats.v("heal_mult"))
			Audio.play("pickup_heal", -4.0)
		"sunshard":
			pl.run.sunshards += amount
			stage.fx.number(pl.pos, 2.4, "SUNSHARD", Color(1.0, 0.9, 0.5), true)
			Audio.play("pickup_sunshard", 0.0)
			Events.currency_changed.emit()
	queue_free()
