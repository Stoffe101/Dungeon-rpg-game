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
var _base_glow := 1.0
var _hit_flash := 0.0     # the blade glints when it connects
## Co-op client, this machine's Kindled: the weapon keeps its timing and its
## picture (so a swing starts the moment it is asked for) but deals nothing;
## the host deals the blows.
var predicting := false
## The weapon item's form (ItemDB base "form"): how this variant plays - its
## own strikes, charged attack or stance (each archetype script reads it).
var form := ""


func setup(p: Player, weapon_id: String, lvl: int) -> void:
	player = p
	id = weapon_id
	def = GearDB.weapon(weapon_id)
	level = lvl
	# a unique or legendary weapon item is drawn as itself
	var held := String(def.sprite)
	var it0 := p.weapon_item()
	if ItemDB.arch_of(it0) == weapon_id and ItemDB.base(String(it0.base)).has("sprite"):
		held = String(ItemDB.base(String(it0.base)).sprite)
	var sheet := SpriteLib.get_sheet(held)
	visual = MeshInstance3D.new()
	visual.mesh = sheet.mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visual.add_child(visual)
	visual.set_instance_shader_parameter("frame", Vector2.ZERO)
	# forged weapons burn brighter: masterworks glow, ascended ones blaze
	var glow := 2.6 if lvl >= 10 else (1.7 if lvl >= 7 else 1.0)
	# a weapon item of this archetype shows as itself: its metal, its glow
	var it := p.weapon_item()
	if ItemDB.arch_of(it) == weapon_id:
		var b := ItemDB.base(String(it.base))
		if b.has("tint") and not b.has("sprite"):
			visual.set_instance_shader_parameter("tint", b.tint)
		glow = maxf(glow, float(b.get("glow", 1.0)))
		form = String(b.get("form", ""))
	_base_glow = glow
	visual.set_instance_shader_parameter("glow_mult", glow)


func free_visual() -> void:
	if visual and is_instance_valid(visual):
		visual.queue_free()


func speed() -> float:
	return maxf(0.2, player.stats.v("attack_speed") * player.flow_speed())


func tempered() -> bool:
	return level >= 3


func masterwork() -> bool:
	return level >= 7


func ascended() -> bool:
	return level >= 10


## The forge level of the archetype times the weapon item's own might.
func damage_scale() -> float:
	var k := 1.0 + GearDB.FORGE_DAMAGE_PER_LEVEL * level
	if player and player.stats:
		k *= maxf(0.1, player.stats.v("weapon_damage"))
	return k


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
			_fire_charge()
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


## The charged blow: dealt by the host; a predicting client only takes its stance.
func _fire_charge() -> void:
	if predicting:
		predict_charge()
	else:
		release_charge()


## Co-op client: how the start of ACTIVE moves the Kindled (the host deals the hits).
func predict_active() -> void:
	if strike.has("lunge"):
		player.push += aim_dir * float(strike.lunge)


## Co-op client: the charged release's stance and timing (override where it differs).
func predict_charge() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"windup": 0.0, "active": 0.22, "recover": 0.3}
	_set_phase(Phase.ACTIVE, 0.22 / speed())
	combo = 0


## Host, remote Kindled: line the draw up with how long its owner actually held
## (their clock; the packets carrying press and release can arrive unevenly).
func sync_hold(client_hold: float) -> void:
	var d := clampf(client_hold - hold_t, -0.15, 0.15)
	hold_t += d
	if phase == Phase.CHARGE:
		phase_t = maxf(0.0, phase_t + d)
		charged = phase_t >= charge_time / speed()


func max_combo() -> int:
	return 1


## A perfect dodge or a Ward (a form may answer: the Sabre's riposte).
func on_evade() -> void:
	pass


## A stance weapon's guard (the Duelist's Sabre, the Warden's Partisan): true
## when it takes the blow instead of the Kindled (Player._take_enemy_hit).
func guard_hit(_h: Hit, _attacker: Node) -> bool:
	return false


## A shot this weapon looses (forms' own projectiles): the player's team, its
## source, damage scaled by the forge and the item.
func shoot(sheet: String, from: Vector2, dir: Vector2, spd: float, dmg: float, tags: Array, life: float) -> Projectile:
	var pr := Projectile.create(player.stage, sheet, from, dir * spd, player.team)
	pr.source = player
	pr.damage = dmg * damage_scale()
	pr.tags = tags
	pr.life = life
	pr.reflectable = false
	return pr


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
				if predicting:
					predict_active()
				else:
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
				player.cosmetic(func() -> void:
					player.stage.fx.motes(player.pos + aim_dir * 0.4, 0.6, c, 1 if not charged else 2, 1.5, 0.35, 0.3))
	update_visual(dt)


func can_charge() -> bool:
	return true


# --- visuals -----------------------------------------------------------------

## Angle (screen space) the weapon points at, before swing offsets.
func base_angle() -> float:
	# carried, the weapon goes where the Kindled faces; drawn back or swung, it
	# points where the blow goes
	match phase:
		Phase.IDLE:
			return Iso.screen_angle(player.look)
		Phase.CHARGE:
			return Iso.screen_angle(player.aim)
	return Iso.screen_angle(aim_dir)


func hit_flash() -> void:
	_hit_flash = 0.9
	if visual:
		visual.set_instance_shader_parameter("flash", Color(1.0, 0.95, 0.8, _hit_flash))


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
		_hit_flash = maxf(0.0, _hit_flash - _dt * 8.0)
		visual.set_instance_shader_parameter("flash", Color(1.0, 0.95, 0.8, _hit_flash))
	var a := ang + off
	visual.basis = Iso.screen_basis(a, left)
	var d := Vector2(cos(a), -sin(a))
	var hand := d * 0.18
	# draw behind the body when pointing away from the camera
	var behind := sin(a) > 0.35
	visual.position = Iso.to_world(hand, 0.55) + Vector3(0, 0, -0.06 if behind else 0.06)


# --- helpers -----------------------------------------------------------------

## Hits every enemy within `width` of the segment from -> to.
func line_hit(from: Vector2, to: Vector2, width: float, dmg: float, tags: Array, kb: float, poise: float, opts := {}) -> int:
	var n := 0
	var seg := to - from
	var len2 := maxf(seg.length_squared(), 0.0001)
	var dir := seg.normalized() if seg.length() > 0.01 else player.aim
	player.stage.strike_props_line(from, to, width, player, tags.has("fire") or player.stats.has("living_pyre") or player.stats.has("searing_edge"))
	for a in player.stage.hostiles(player.team):
		if hit_ids.has(a.get_instance_id()) or not a.targetable:
			continue
		var t := clampf((a.pos - from).dot(seg) / len2, 0.0, 1.0)
		if a.pos.distance_to(from + seg * t) > width + a.radius:
			continue
		hit_ids[a.get_instance_id()] = true
		var h := Combat.player_hit(player, player.stats, dmg * damage_scale(), tags)
		h.knockback = dir * kb * player.stats.v("knockback")
		h.from_dir = dir
		h.poise = poise * player.stats.v("poise_damage")
		h.forced_crit = opts.get("crit", false)
		if opts.get("unblockable", false):
			h.unblockable = true
		if opts.has("each"):
			# a form's touch on each foe struck (marks, roots, executions)
			(opts.each as Callable).call(a, h)
		player.deal_hit(a, h, opts.get("finisher", false))
		n += 1
	return n


## Hits every enemy in an arc; returns how many were struck.
func arc_hit(origin: Vector2, dir: Vector2, rng: float, half_angle: float, dmg: float, tags: Array, kb: float, poise: float, opts := {}) -> int:
	var n := 0
	player.stage.strike_props(origin, dir, rng, half_angle, player, tags.has("fire") or player.stats.has("living_pyre") or player.stats.has("searing_edge"))
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
		if opts.has("each"):
			# a form's touch on each foe struck (marks, roots, executions)
			(opts.each as Callable).call(a, h)
		player.deal_hit(a, h, opts.get("finisher", false))
		n += 1
	return n
