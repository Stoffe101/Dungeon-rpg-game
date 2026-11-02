## Base class for player weapons. A weapon is a small state machine driven by
## press / hold / release of the attack button: tap for the combo, hold for a
## charged attack. Subclasses define strikes; the base handles timing, the
## held weapon sprite and arc hit detection.
class_name Weapon
extends RefCounted

enum Phase { IDLE, WINDUP, ACTIVE, RECOVER, CHARGE }

var player: Player
var id := ""
var def: Dictionary = {}
var level := 0
var phase := Phase.IDLE
var phase_t := 0.0
var phase_len := 0.0
var combo := 0
var combo_timer := 0.0
var buffered := false
var held := false
var hold_t := 0.0
var charge_time := 0.45
var charged := false
var strike: Dictionary = {}
var aim_dir := Vector2.RIGHT
var swing := 0.0          # current swing offset (radians, screen space)
var visual: MeshInstance3D
var hit_ids := {}
var _charge_fx_t := 0.0


func setup(p: Player, weapon_id: String, lvl: int) -> void:
	player = p
	id = weapon_id
	def = GearDB.weapon(weapon_id)
	level = lvl
	var sheet := SpriteLib.get_sheet(def.sprite)
	visual = MeshInstance3D.new()
	visual.mesh = sheet.mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visual.add_child(visual)
	visual.set_instance_shader_parameter("frame", Vector2.ZERO)


func free_visual() -> void:
	if visual and is_instance_valid(visual):
		visual.queue_free()


func speed() -> float:
	return maxf(0.2, player.stats.v("attack_speed"))


func tempered() -> bool:
	return level >= 3


func damage_scale() -> float:
	return 1.0 + GearDB.FORGE_DAMAGE_PER_LEVEL * level


# --- input -------------------------------------------------------------------

func press() -> void:
	held = true
	hold_t = 0.0
	if phase == Phase.IDLE:
		begin_combo()
	else:
		buffered = true


func release() -> void:
	held = false
	if phase == Phase.CHARGE:
		if charged:
			release_charge()
		else:
			_set_phase(Phase.IDLE, 0.0)
			begin_combo()


func cancel() -> void:
	if phase == Phase.CHARGE or phase == Phase.WINDUP or phase == Phase.ACTIVE or phase == Phase.RECOVER:
		_set_phase(Phase.IDLE, 0.0)
	buffered = false
	charged = false
	swing = 0.0


func is_busy() -> bool:
	return phase == Phase.WINDUP or phase == Phase.ACTIVE


func is_attacking() -> bool:
	return phase != Phase.IDLE


func move_mult() -> float:
	match phase:
		Phase.WINDUP, Phase.ACTIVE:
			return 0.3
		Phase.RECOVER:
			return 0.65
		Phase.CHARGE:
			return 0.5
	return 1.0


# --- flow --------------------------------------------------------------------

func begin_combo() -> void:
	if combo_timer <= 0.0:
		combo = 0
	start_strike(combo)


## Override: set `strike` and enter WINDUP.
func start_strike(_index: int) -> void:
	pass


## Override: perform the hit at the start of ACTIVE.
func on_active() -> void:
	pass


## Override: charged release.
func release_charge() -> void:
	_set_phase(Phase.IDLE, 0.0)


func max_combo() -> int:
	return 1


func _set_phase(p: int, length: float) -> void:
	phase = p
	phase_t = 0.0
	phase_len = length


func update(dt: float) -> void:
	if held:
		hold_t += dt
	combo_timer = maxf(0.0, combo_timer - dt)
	phase_t += dt
	match phase:
		Phase.IDLE:
			if held and hold_t >= 0.12 and can_charge():
				_set_phase(Phase.CHARGE, 0.0)
				charged = false
		Phase.WINDUP:
			if phase_t >= phase_len:
				_set_phase(Phase.ACTIVE, strike.get("active", 0.07) / speed())
				hit_ids.clear()
				on_active()
		Phase.ACTIVE:
			if phase_t >= phase_len:
				_set_phase(Phase.RECOVER, strike.get("recover", 0.16) / speed())
		Phase.RECOVER:
			if buffered and phase_t >= phase_len * 0.35:
				buffered = false
				combo = (combo + 1) % max_combo()
				combo_timer = 0.0
				start_strike(combo)
			elif phase_t >= phase_len:
				combo = (combo + 1) % max_combo()
				combo_timer = 0.35 if combo != 0 else 0.0
				_set_phase(Phase.IDLE, 0.0)
				if held and can_charge():
					_set_phase(Phase.CHARGE, 0.0)
					charged = false
					hold_t = 0.0
		Phase.CHARGE:
			if not held:
				_set_phase(Phase.IDLE, 0.0)
			elif not charged and phase_t >= charge_time / speed():
				charged = true
				player.on_weapon_charged()
			_charge_fx_t += dt
			if _charge_fx_t > 0.05:
				_charge_fx_t = 0.0
				var c := Color(1.0, 0.8, 0.4) if charged else Color(1.0, 0.55, 0.25)
				player.stage.fx.motes(player.pos + aim_dir * 0.4, 0.6, c, 1 if not charged else 2, 1.5, 0.35, 0.3)
	update_visual(dt)


func can_charge() -> bool:
	return true


# --- visuals -----------------------------------------------------------------

## Angle (screen space) the weapon points at, before swing offsets.
func base_angle() -> float:
	return Iso.screen_angle(player.aim if phase == Phase.IDLE or phase == Phase.CHARGE else aim_dir)


func update_visual(_dt: float) -> void:
	if visual == null:
		return
	var ang := base_angle()
	var left := cos(ang) < 0.0
	var off := swing
	if phase == Phase.IDLE:
		off = deg_to_rad(-35.0) if not left else deg_to_rad(35.0)
	elif phase == Phase.CHARGE:
		off = deg_to_rad(110.0) if not left else deg_to_rad(-110.0)
		var pulse := 0.5 + 0.5 * sin(phase_t * 30.0)
		visual.set_instance_shader_parameter("flash", Color(1.0, 0.7, 0.3, (0.6 if charged else 0.25) * pulse))
	if phase != Phase.CHARGE:
		visual.set_instance_shader_parameter("flash", Color(1, 1, 1, 0.0))
	var a := ang + off
	visual.basis = Iso.screen_basis(a, left)
	var d := Vector2(cos(a), -sin(a))
	var hand := d * 0.18
	# draw behind the body when pointing away from the camera
	var behind := sin(a) > 0.35
	visual.position = Iso.to_world(hand, 0.55) + Vector3(0, 0, -0.06 if behind else 0.06)


# --- helpers -----------------------------------------------------------------

## Hits every enemy in an arc; returns how many were struck.
func arc_hit(origin: Vector2, dir: Vector2, rng: float, half_angle: float, dmg: float, tags: Array, kb: float, poise: float, opts := {}) -> int:
	var n := 0
	player.stage.strike_props(origin, dir, rng, half_angle, player)
	for a in player.stage.in_arc(player.team, origin, dir, rng * player.stats.v("area") if opts.get("area", false) else rng, half_angle):
		if hit_ids.has(a.get_instance_id()):
			continue
		if not player.stage.grid.line_clear(origin, a.pos) and a.pos.distance_to(origin) > 1.0:
			continue
		hit_ids[a.get_instance_id()] = true
		var h := Combat.player_hit(player, player.stats, dmg * damage_scale(), tags)
		h.knockback = (a.pos - origin).normalized() * kb * player.stats.v("knockback")
		h.from_dir = (a.pos - origin).normalized()
		h.poise = poise * player.stats.v("poise_damage")
		h.forced_crit = opts.get("crit", false)
		if opts.get("unblockable", false):
			h.unblockable = true
		player.deal_hit(a, h, opts.get("finisher", false))
		n += 1
	return n
