## Cinderhammer: a slow, crushing two-strike combo (sweep, overhead slam with
## shockwave). Breaks guards. Hold to leap toward the cursor and quake the ground.
extends Weapon

const STRIKES := [
	{"windup": 0.2, "active": 0.09, "recover": 0.3, "arc": 80.0, "range": 2.35, "kb": 8.0, "poise": 32.0, "lunge": 2.5, "from": 95.0, "to": -80.0},
	{"windup": 0.26, "active": 0.1, "recover": 0.42, "arc": 0.0, "range": 1.5, "kb": 10.0, "poise": 55.0, "lunge": 3.0, "from": 150.0, "to": -20.0, "slam": true},
]

var leaping := false
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO


func _init() -> void:
	charge_time = 0.6


func max_combo() -> int:
	return 2


func move_mult() -> float:
	if leaping:
		return 0.0
	match phase:
		Phase.WINDUP, Phase.ACTIVE:
			return 0.15
		Phase.RECOVER:
			return 0.5
		Phase.CHARGE:
			return 0.4
	return 1.0


func start_strike(index: int) -> void:
	strike = STRIKES[index]
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, strike.windup / speed())
	player.on_attack_start()


func on_active() -> void:
	var p := player.pos
	player.push += aim_dir * float(strike.lunge)
	var dmg: float = def.damage[combo]
	var hits := 0
	if strike.get("slam", false):
		var c := p + aim_dir * 1.4
		Audio.play("slam", 0.0)
		player.stage.fx.ring(c, 1.6, Color(1.0, 0.7, 0.35), 0.18, 0.4)
		player.stage.fx.burst(c, 0.1, Color(0.75, 0.68, 0.6), 16, 5.0, 0.5, 9.0, Vector2.ZERO, PI, 3.0)
		player.stage.fx.burst(c, 0.1, Color(1.0, 0.6, 0.25), 10, 4.0, 0.4, 4.0)
		for a in player.stage.in_circle(player.team, c, 1.5):
			hits += _smash(a, dmg, c)
		var wave_r := 3.0 * (1.3 if tempered() else 1.0) * player.stats.v("area")
		player.stage.fx.ring(c, wave_r, Color(1.0, 0.85, 0.55), 0.35, 0.12)
		for a in player.stage.in_circle(player.team, c, wave_r):
			if not hit_ids.has(a.get_instance_id()):
				hits += _smash(a, dmg * 0.4, c)
		player.stage.fx.shake(0.4)
		player.stage.hitstop(0.09 if hits > 0 else 0.03)
		if masterwork():
			_burning_cracks(c)
	else:
		Audio.play("swing_heavy", 0.0)
		var rev := cos(Iso.screen_angle(aim_dir)) < 0.0
		player.stage.fx.swipe(p, aim_dir, strike.range + 0.15, deg_to_rad(strike.arc + 10.0), Color(1.0, 0.75, 0.45, 0.95), 0.12, 0.3, rev)
		hits = arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, {"unblockable": true})
		if hits > 0:
			player.stage.hitstop(0.07)
			player.stage.fx.shake(0.25)
	player.on_weapon_strike(hits, combo == 1)


## Masterwork: the slam leaves the ground cracked and burning.
func _burning_cracks(c: Vector2) -> void:
	var src := player
	player.stage.fx.splat(c, Color(0.2, 0.08, 0.04), 8.0, 1.4)
	var hz := Hazard.spawn(player.stage, c, 1.6, 3.0, Actor.Team.PLAYER, Color(1.0, 0.5, 0.18), func(_h: Hazard, a: Actor) -> void:
		if a.team != Actor.Team.PLAYER and is_instance_valid(src):
			a.status.apply_burn(1, 5.0, 5, src))
	hz.period = 0.5
	hz.particle_rate = 16.0


func _smash(a: Actor, dmg: float, c: Vector2) -> int:
	if hit_ids.has(a.get_instance_id()):
		return 0
	hit_ids[a.get_instance_id()] = true
	var h := Combat.player_hit(player, player.stats, dmg * damage_scale(), ["melee"])
	h.knockback = (a.pos - c).normalized() * 9.0 * player.stats.v("knockback")
	h.from_dir = (a.pos - c).normalized()
	h.poise = 50.0 * player.stats.v("poise_damage")
	h.unblockable = true
	player.deal_hit(a, h, true)
	return 1


func update(dt: float) -> void:
	if leaping:
		phase_t += dt
		var k := clampf(phase_t / 0.38, 0.0, 1.0)
		var target := leap_from.lerp(leap_to, k)
		player.pos = player.stage.grid.move_box(player.pos, player.box(), target - player.pos)
		player.height = sin(k * PI) * 1.6
		if k >= 1.0:
			leaping = false
			player.height = 0.0
			_land()
		update_visual(dt)
		return
	super.update(dt)
	var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
	if strike.has("from"):
		match phase:
			Phase.WINDUP:
				swing = deg_to_rad(strike.from) * sgn
			Phase.ACTIVE:
				var k := clampf(phase_t / maxf(phase_len, 0.001), 0.0, 1.0)
				swing = lerpf(deg_to_rad(strike.from), deg_to_rad(strike.to), 1.0 - pow(1.0 - k, 4.0)) * sgn
			Phase.RECOVER:
				swing = deg_to_rad(strike.to) * sgn


func release_charge() -> void:
	charged = false
	aim_dir = player.aim
	leap_from = player.pos
	var dist := minf(player.pos.distance_to(player.aim_point), 4.5)
	leap_to = player.pos + aim_dir * dist
	leaping = true
	phase = Phase.ACTIVE
	phase_t = 0.0
	strike = {"active": 0.4, "recover": 0.35}
	player.invuln_t = maxf(player.invuln_t, 0.42)
	Audio.play("leap", 0.0)


func _land() -> void:
	var c := player.pos
	var r := 2.7 * player.stats.v("area")
	hit_ids.clear()
	Audio.play("slam", 2.0)
	player.stage.fx.ring(c, r, Color(1.0, 0.65, 0.3), 0.3, 0.25)
	player.stage.fx.ring(c, r * 1.4, Color(1.0, 0.85, 0.5), 0.45, 0.08)
	player.stage.fx.burst(c, 0.1, Color(0.7, 0.62, 0.55), 26, 7.0, 0.6, 9.0, Vector2.ZERO, PI, 3.0)
	player.stage.fx.burst(c, 0.1, Color(1.0, 0.6, 0.25), 18, 5.0, 0.5, 3.0)
	player.stage.fx.flash_light(c, 0.5, Color(1.0, 0.6, 0.3), 4.0, 6.0, 0.3)
	var hits := 0
	player.stage.strike_props_circle(c, r, player, player.stats.has("living_pyre"))
	for a in player.stage.in_circle(player.team, c, r):
		hits += _smash(a, def.charged, c)
	player.stage.fx.shake(0.6)
	player.stage.hitstop(0.1)
	_set_phase(Phase.RECOVER, 0.35 / speed())
	combo = 0
	player.on_weapon_strike(hits, true)


func cancel() -> void:
	if leaping:
		return
	super.cancel()


func is_busy() -> bool:
	return leaping or super.is_busy()
