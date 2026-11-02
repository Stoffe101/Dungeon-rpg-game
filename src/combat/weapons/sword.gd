## Hearthblade: fast three-strike combo (slash, backslash, lunging thrust);
## hold to charge a whirling cut that hits all around.
extends Weapon

const STRIKES := [
	{"windup": 0.07, "active": 0.07, "recover": 0.17, "arc": 62.0, "range": 1.95, "kb": 3.5, "poise": 10.0, "lunge": 2.2, "from": 75.0, "to": -75.0},
	{"windup": 0.06, "active": 0.07, "recover": 0.17, "arc": 62.0, "range": 1.95, "kb": 3.5, "poise": 10.0, "lunge": 2.2, "from": -75.0, "to": 75.0},
	{"windup": 0.11, "active": 0.08, "recover": 0.26, "arc": 26.0, "range": 2.7, "kb": 8.0, "poise": 26.0, "lunge": 5.0, "from": 0.0, "to": 0.0, "thrust": true},
]


func max_combo() -> int:
	return 3


func start_strike(index: int) -> void:
	strike = STRIKES[index]
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, strike.windup / speed())
	swing = deg_to_rad(strike.from) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)
	player.on_attack_start()


func on_active() -> void:
	var finisher := combo == 2
	var dmg: float = def.damage[combo]
	var kind: String = "thrust" if strike.get("thrust", false) else "slash"
	var p := player.pos
	player.push += aim_dir * float(strike.lunge)
	var col := Color(1.0, 0.86, 0.6, 0.9)
	if kind == "thrust":
		player.stage.fx.shape(Fx.Shape.CONE, p, aim_dir, Vector2(strike.range * 2.0, strike.range * 2.0), Color(1.0, 0.8, 0.5, 0.0), Color(1.0, 0.95, 0.8, 1.0), 0.09, {"half_angle": deg_to_rad(strike.arc), "progress": 1.0, "glow": 1.6})
		player.stage.fx.burst(p + aim_dir * 1.2, 0.6, Color(1.0, 0.85, 0.5), 6, 6.0, 0.18, 0.0, aim_dir, 0.2)
	else:
		var rev: bool = strike.from < 0.0
		if cos(Iso.screen_angle(aim_dir)) < 0.0:
			rev = not rev
		player.stage.fx.swipe(p, aim_dir, strike.range + 0.1, deg_to_rad(strike.arc + 8.0), col, 0.09 / speed(), 0.42, rev)
	Audio.play("swing", -2.0, randf_range(0.95, 1.08))
	var hits := arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, {"finisher": finisher})
	if hits > 0:
		player.stage.hitstop(0.05 if not finisher else 0.08)
		player.stage.fx.shake(0.12 if not finisher else 0.24)
	if finisher and (tempered() or player.stats.has("combo_wave")):
		_cutting_wave(dmg * 0.6)
	player.on_weapon_strike(hits, finisher)


func _cutting_wave(dmg: float) -> void:
	var pr := Projectile.create(player.stage, "proj_wave", player.pos + aim_dir * 0.6, aim_dir * 13.0, player.team)
	pr.source = player
	pr.damage = dmg * damage_scale()
	pr.tags = ["melee", "ranged"]
	pr.pierce = 3
	pr.radius = 0.45
	pr.life = 0.45
	pr.spin = true
	pr.knockback = 4.0
	pr.trail_color = Color(1.0, 0.8, 0.45)
	pr.trail_rate = 40.0
	pr.reflectable = false


func update(dt: float) -> void:
	super.update(dt)
	if phase == Phase.WINDUP and strike.has("from"):
		var k := clampf(phase_t / maxf(phase_len, 0.001), 0.0, 1.0)
		var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
		swing = deg_to_rad(strike.from) * sgn * (1.0 + 0.15 * k)
	elif phase == Phase.ACTIVE and strike.has("from"):
		var k := clampf(phase_t / maxf(phase_len, 0.001), 0.0, 1.0)
		var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
		swing = lerpf(deg_to_rad(strike.from), deg_to_rad(strike.to), 1.0 - pow(1.0 - k, 3.0)) * sgn
	elif phase == Phase.RECOVER and strike.has("from"):
		var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
		swing = deg_to_rad(strike.to) * sgn


func release_charge() -> void:
	aim_dir = player.aim
	strike = {"windup": 0.0, "active": 0.22, "recover": 0.3}
	_set_phase(Phase.ACTIVE, 0.22 / speed())
	hit_ids.clear()
	charged = false
	var p := player.pos
	var r := 2.5 * player.stats.v("area")
	player.stage.fx.swipe(p, aim_dir, r, PI, Color(1.0, 0.75, 0.4, 0.95), 0.18, 0.35)
	player.stage.fx.ring(p, r, Color(1.0, 0.7, 0.35), 0.25, 0.15)
	player.stage.fx.burst(p, 0.5, Color(1.0, 0.7, 0.3), 18, 7.0, 0.35, 2.0)
	Audio.play("whirl", 0.0)
	var hits := arc_hit(p, aim_dir, r, PI, def.charged, ["melee"], 9.0, 40.0, {"finisher": true})
	if hits > 0:
		player.stage.hitstop(0.08)
		player.stage.fx.shake(0.3)
	player.stage.fx.flash_light(p, 1.0, Color(1.0, 0.7, 0.35), 2.6, r + 1.5, 0.25)
	player.stage.fx.splat(p, Color(0.14, 0.1, 0.09), 14.0, 1.6)
	player.on_weapon_strike(hits, true)
	combo = 0


func base_angle() -> float:
	if phase == Phase.ACTIVE and strike.get("active", 0.0) >= 0.2:
		# whirling cut spins the blade a full turn
		return Iso.screen_angle(aim_dir) + phase_t / maxf(phase_len, 0.001) * TAU
	return super.base_angle()
