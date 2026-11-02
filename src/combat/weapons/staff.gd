## Ashwood Staff: tap to loose ember bolts; hold to gather a fireball that
## bursts on impact.
extends Weapon

var _cool := 0.0


func _init() -> void:
	charge_time = 0.7


func max_combo() -> int:
	return 1


func move_mult() -> float:
	if phase == Phase.CHARGE:
		return 0.55
	if phase != Phase.IDLE:
		return 0.8
	return 1.0


func update(dt: float) -> void:
	_cool = maxf(0.0, _cool - dt)
	super.update(dt)
	swing = 0.0


func begin_combo() -> void:
	start_strike(0)


func start_strike(_i: int) -> void:
	if _cool > 0.0:
		buffered = true
		strike = {"recover": _cool}
		_set_phase(Phase.RECOVER, _cool)
		return
	strike = {"windup": 0.02, "active": 0.02, "recover": 0.16}
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, 0.02)
	player.on_attack_start()


func on_active() -> void:
	_cool = 0.18 / speed()
	var spread := deg_to_rad(randf_range(-4.0, 4.0))
	var d := aim_dir.rotated(spread)
	var pr := Projectile.create(player.stage, "proj_ember", player.pos + d * 0.5, d * 15.0 * player.stats.v("projectile_speed"), player.team)
	pr.source = player
	pr.damage = def.damage[0] * damage_scale()
	pr.tags = ["ranged", "fire"]
	pr.pierce = 1 if tempered() else 0
	pr.radius = 0.22
	pr.life = 0.9
	pr.height = 0.6
	pr.knockback = 1.5
	pr.trail_color = Color(1.0, 0.6, 0.25)
	pr.trail_rate = 30.0
	pr.reflectable = false
	pr.spin = true
	pr.on_hit_fn = func(proj: Projectile, target: Actor, _res) -> void:
		player.gain_kindle(2.5)
		if player.stats.has("forked_ember") and not proj.tags.has("forked"):
			_fork(proj, target)
	pr.with_light(Color(1.0, 0.55, 0.25), 0.7, 2.2)
	Audio.play("bolt", -4.0, randf_range(0.92, 1.1))
	player.stage.fx.burst(player.pos + d * 0.6, 0.6, Color(1.0, 0.75, 0.4), 3, 3.0, 0.15, 0.0, d, 0.5)
	player.on_weapon_strike(0, false)


func _fork(proj: Projectile, target: Actor) -> void:
	for s in [-0.5, 0.5]:
		var d := proj.vel.normalized().rotated(s)
		var f := Projectile.create(player.stage, "proj_ember", proj.pos, d * proj.vel.length(), player.team)
		f.source = player
		f.damage = proj.damage * 0.5
		f.tags = ["ranged", "fire", "forked"]
		f.life = 0.4
		f.spin = true
		f.trail_color = proj.trail_color
		f.trail_rate = 20.0
		f.reflectable = false
		f.hit_set[target.get_instance_id()] = true


func release_charge() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"recover": 0.3}
	_set_phase(Phase.RECOVER, 0.3 / speed())
	var pr := Projectile.create(player.stage, "proj_fireball", player.pos + aim_dir * 0.6, aim_dir * 10.0, player.team)
	pr.source = player
	pr.damage = def.charged * damage_scale()
	pr.tags = ["ranged", "fire"]
	pr.radius = 0.35
	pr.life = 1.4
	pr.height = 0.7
	pr.burn = 2
	pr.trail_color = Color(1.0, 0.55, 0.2)
	pr.trail_rate = 60.0
	pr.reflectable = false
	pr.with_light(Color(1.0, 0.5, 0.2), 1.6, 4.0)
	pr.on_end_fn = func(proj: Projectile, at: Vector2) -> void:
		_explode(at, proj.damage)
	Audio.play("fireball", 0.0)
	player.on_weapon_strike(0, true)


func _explode(at: Vector2, dmg: float) -> void:
	var r := 2.2 * player.stats.v("area")
	player.stage.fx.ring(at, r, Color(1.0, 0.6, 0.25), 0.25, 0.35)
	player.stage.fx.burst(at, 0.4, Color(1.0, 0.65, 0.25), 24, 7.0, 0.45, 3.0)
	player.stage.fx.burst(at, 0.4, Color(0.4, 0.35, 0.35), 10, 3.0, 0.8, -1.0)
	player.stage.fx.flash_light(at, 0.6, Color(1.0, 0.55, 0.25), 4.0, 6.0, 0.35)
	player.stage.fx.shake(0.35)
	Audio.play("explode", 0.0)
	for a in player.stage.in_circle(player.team, at, r):
		var h := Combat.player_hit(player, player.stats, dmg, ["ranged", "fire"])
		h.knockback = (a.pos - at).normalized() * 8.0
		h.from_dir = (a.pos - at).normalized()
		h.burn = 2
		h.poise = 30.0
		player.deal_hit(a, h)
