## Hearthbow: pressing starts the draw. Let go early for a quick shot; let go
## as the draw peaks for a Steady Shot that pierces and always crits. Hold too
## long and the arm tires (a weaker shot). Drawing slows the Kindled to a walk.
extends Weapon

const PERFECT := 0.28     # seconds after the draw peaks that count as "on time"
const TIRE := 1.2         # past this the arm tires
## Forms (ItemDB "form"):
##   volley (Splitwood Bow) - the draw nocks one more arrow every quarter
##     second, up to five, loosed together in a fan: draw long for more arrows,
##     or on time for true ones - not both.
##   glacial (Long Rimebow) - its arrows chill; a Steady Shot is an ice spear
##     that passes through everything, freezes the already chilled and leaves
##     a trail of frost where it flew.
const NOCK_EVERY := 0.25
const NOCK_MAX := 5


## Quiver Lore (Hearthtree): the Splitwood nocks seven.
func nock_max() -> int:
	return NOCK_MAX + (2 if player and player.stats and player.stats.has("mastery_bow") else 0)
var _cool := 0.0
var _nocked := 1


func _init() -> void:
	charge_time = 0.6


func max_combo() -> int:
	return 1


func move_mult() -> float:
	if phase == Phase.CHARGE:
		return 0.4
	if phase != Phase.IDLE:
		return 0.75
	return 1.0


func update(dt: float) -> void:
	_cool = maxf(0.0, _cool - dt)
	super.update(dt)
	# drawn: the string glows brighter the closer to the perfect moment
	if phase == Phase.CHARGE and charged and visual:
		var over := phase_t - charge_time / speed()
		var k := 1.0 if over <= PERFECT else 0.3
		visual.set_instance_shader_parameter("flash", Color(1.0, 0.85, 0.45, 0.7 * k * (0.6 + 0.4 * sin(phase_t * 40.0))))
	if form == "volley":
		if phase == Phase.CHARGE:
			var n := mini(nock_max(), 1 + int(phase_t * speed() / NOCK_EVERY))
			if n > _nocked:
				_nocked = n
				player.cosmetic(func() -> void:
					player.stage.fx.motes(player.pos + player.aim * 0.5, 0.8, Color(1.0, 0.9, 0.6), 2, 0.6, 0.25, 0.1)
					Audio.play("nock", -8.0, 0.9 + 0.06 * n))
		else:
			_nocked = 1
		player.form_meter = float(_nocked) / nock_max() if phase == Phase.CHARGE else 0.0
	swing = 0.0


func begin_combo() -> void:
	start_strike(0)


func press() -> void:
	held = true
	hold_t = 0.0
	if phase == Phase.IDLE and _cool <= 0.0:
		aim_dir = player.aim
		charged = false
		_set_phase(Phase.CHARGE, 0.0)
	else:
		buffered = true


func release() -> void:
	held = false
	if phase == Phase.CHARGE:
		if charged:
			_fire_charge()
		else:
			# let go early: a quick shot
			_set_phase(Phase.IDLE, 0.0)
			start_strike(0)


func can_charge() -> bool:
	return held


func start_strike(_i: int) -> void:
	if _cool > 0.0:
		buffered = true
		strike = {"recover": _cool}
		_set_phase(Phase.RECOVER, _cool)
		return
	strike = {"windup": 0.03, "active": 0.02, "recover": 0.18}
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, 0.03)
	player.on_attack_start()


func on_active() -> void:
	_cool = 0.3 / speed()
	_arrow(player.aim.rotated(deg_to_rad(randf_range(-2.5, 2.5))), def.damage[0] * damage_scale(), 1 if tempered() else 0, false)
	Audio.play("bow", -3.0, randf_range(1.05, 1.2))
	player.on_weapon_strike(0, false)


func predict_active() -> void:
	_cool = 0.3 / speed()


func predict_charge() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"recover": 0.32}
	_set_phase(Phase.RECOVER, 0.32 / speed())


func release_charge() -> void:
	var nocked := mini(nock_max(), 1 + int(phase_t * speed() / NOCK_EVERY))
	var over := phase_t - charge_time / speed()
	var perfect := over <= PERFECT
	var tired := over > TIRE
	charged = false
	aim_dir = player.aim
	strike = {"recover": 0.32}
	_set_phase(Phase.RECOVER, 0.32 / speed())
	var dmg: float = def.charged * damage_scale() * (0.7 if tired else 1.0)
	if form == "volley":
		# the nocked arrows, loosed together in a fan
		var n := nocked
		var group := {}
		for i in n:
			var d := aim_dir.rotated(deg_to_rad((i - (n - 1) * 0.5) * 8.0))
			_one_arrow(d, dmg * 0.48, 1, perfect, group)
		player.stage.fx.burst(player.pos + aim_dir * 0.6, 0.6, Color(1.0, 0.85, 0.6), 4 + 2 * n, 3.0, 0.15, 0.0, aim_dir, 0.7)
		if n >= nock_max():
			player.stage.fx.number(player.pos, 2.2, "VOLLEY", Color(1.0, 0.9, 0.6))
	elif form == "glacial" and perfect:
		_ice_spear(aim_dir, dmg * 1.15)
	else:
		_arrow(aim_dir, dmg, 3, perfect)
	if perfect:
		player.stage.fx.number(player.pos, 2.2, "STEADY", Color(1.0, 0.85, 0.45))
		player.stage.fx.ring(player.pos + aim_dir * 0.6, 0.8, Color(1.0, 0.85, 0.45), 0.2, 0.15)
		player.gain_kindle(6.0)
	Audio.play("bow", 0.0, 0.8 if perfect else 0.95)
	player.stage.fx.shake(0.12 if perfect else 0.05)
	player.on_weapon_strike(0, true)


## One shot: an arrow, or a fan of them with the Kindled's extra projectiles
## (Volley: chain, split, return and pierce apply to every one).
func _arrow(d0: Vector2, dmg: float, pierce: int, perfect: bool) -> void:
	var group := {}
	for d: Vector2 in Volley.directions(player, d0, 1, 0.1):
		_one_arrow(d, dmg, pierce, perfect, group)
	player.stage.fx.burst(player.pos + d0 * 0.6, 0.6, Color(1.0, 0.85, 0.6), 3 if not perfect else 9, 3.0, 0.15, 0.0, d0, 0.4)


func _one_arrow(d: Vector2, dmg: float, pierce: int, perfect: bool, group: Dictionary) -> void:
	var pr := Projectile.create(player.stage, "proj_arrow", player.pos + d * 0.5, d * (26.0 if perfect else 21.0) * player.stats.v("projectile_speed"), player.team)
	pr.source = player
	pr.damage = dmg
	pr.tags = ["ranged"]
	pr.pierce = pierce
	pr.radius = 0.2 if not perfect else 0.26
	pr.life = 0.75 if not perfect else 0.9
	pr.height = 0.6
	pr.knockback = 2.0 if not perfect else 5.0
	pr.reflectable = false
	pr.spin = true
	pr.trail_color = Color(1.0, 0.8, 0.45) if perfect else Color(0.85, 0.75, 0.6)
	pr.trail_rate = 50.0 if perfect else 18.0
	if ascended():
		pr.burn = 1
		pr.tags.append("fire")
	if form == "glacial":
		pr.tags.append("frost")
		pr.chill = 0.25
		pr.trail_color = Color(0.7, 0.9, 1.0)
	if perfect:
		pr.with_light(Color(1.0, 0.8, 0.45), 1.0, 2.5)
		pr.make_hit_fn = func(proj: Projectile, _t: Actor) -> Hit:
			var h := Combat.player_hit(player, player.stats, proj.damage, proj.tags.duplicate())
			h.forced_crit = true
			h.knockback = proj.vel.normalized() * proj.knockback
			h.from_dir = proj.vel.normalized()
			h.poise = 30.0
			h.burn = proj.burn
			return h
		if masterwork():
			# a Masterwork's steady shot splits at the first foe it meets
			var split := [false]
			pr.on_hit_fn = func(proj: Projectile, target: Actor, _res) -> void:
				if split[0]:
					return
				split[0] = true
				for s in [-0.35, 0.35]:
					var f := Projectile.create(player.stage, "proj_arrow", proj.pos, proj.vel.rotated(s), player.team)
					f.source = player
					f.damage = proj.damage * 0.5
					f.tags = ["ranged"]
					f.life = 0.4
					f.spin = true
					f.reflectable = false
					f.hit_set[target.get_instance_id()] = true
	else:
		pr.on_hit_fn = func(_proj: Projectile, _t: Actor, _res) -> void:
			player.gain_kindle(1.8)
	Volley.shape(pr, player, group)



## Long Rimebow: the Steady Shot as a spear of ice - through everything, the
## chilled frozen solid, frost left along its flight.
func _ice_spear(d: Vector2, dmg: float) -> void:
	var start := player.pos + d * 0.5
	var pr := shoot("proj_icespear", start, d, 24.0 * player.stats.v("projectile_speed"), dmg / damage_scale(), ["ranged", "frost"], 0.85)
	pr.pierce = 99
	pr.radius = 0.3
	pr.knockback = 4.0
	pr.trail_color = Color(0.75, 0.92, 1.0)
	pr.trail_rate = 60.0
	pr.with_light(Color(0.6, 0.85, 1.0), 1.2, 3.0)
	pr.make_hit_fn = func(proj: Projectile, t: Actor) -> Hit:
		var h := Combat.player_hit(player, player.stats, proj.damage, ["ranged", "frost"])
		h.forced_crit = true
		h.chill = 1.0 if (t.status.chill > 0.0 or t.status.is_frozen()) else 0.5
		h.knockback = proj.vel.normalized() * proj.knockback
		h.from_dir = proj.vel.normalized()
		h.poise = 30.0
		return h
	var src := player
	var st := player.stage
	pr.on_end_fn = func(_proj: Projectile, at: Vector2) -> void:
		var steps := int(start.distance_to(at) / 1.4)
		for k in steps + 1:
			var p: Vector2 = start.lerp(at, float(k) / maxf(1.0, steps))
			var hz := Hazard.spawn(st, p, 0.75, 3.0, Actor.Team.PLAYER, Color(0.65, 0.88, 1.0), func(_h: Hazard, a: Actor) -> void:
				if a.team != Actor.Team.PLAYER and is_instance_valid(src):
					a.status.apply_chill(0.2), true)
			hz.period = 0.5
			hz.particle_rate = 3.0
	player.stage.fx.burst(start, 0.6, Color(0.75, 0.92, 1.0), 12, 4.0, 0.2, 0.0, d, 0.5)
	player.stage.fx.number(player.pos, 2.2, "GLACIAL", Color(0.75, 0.92, 1.0))
	player.gain_kindle(6.0)
	Audio.play("ice_spear", -1.0)
