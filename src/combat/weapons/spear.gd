## Sunpiercer: a long glaive with a sun-forged head. Two reaching thrusts that
## skewer everything in a line, then a wide sweep. Hold to charge Comet Lunge:
## hurl yourself forward point-first and burst in sunfire where you land.
extends Weapon

const STRIKES := [
	{"windup": 0.09, "active": 0.07, "recover": 0.2, "range": 3.1, "width": 0.75, "kb": 4.0, "poise": 14.0, "lunge": 1.4, "thrust": true},
	{"windup": 0.08, "active": 0.07, "recover": 0.2, "range": 3.1, "width": 0.75, "kb": 4.0, "poise": 14.0, "lunge": 1.4, "thrust": true},
	{"windup": 0.13, "active": 0.09, "recover": 0.3, "arc": 80.0, "range": 2.9, "kb": 8.0, "poise": 24.0, "lunge": 1.5, "from": 85.0, "to": -85.0},
]
const LUNGE := 5.0


func max_combo() -> int:
	return 3


func start_strike(index: int) -> void:
	strike = STRIKES[index]
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, strike.windup / speed())
	swing = deg_to_rad(strike.get("from", 0.0)) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)
	player.on_attack_start()


func on_active() -> void:
	var finisher := combo == 2
	var dmg: float = def.damage[combo]
	var p := player.pos
	player.push += aim_dir * float(strike.lunge)
	var hits := 0
	if strike.get("thrust", false):
		var tip := p + aim_dir * float(strike.range)
		player.stage.fx.shape(Fx.Shape.RECT, p, aim_dir, Vector2(strike.range, 0.5), Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.95, 0.75, 1.0), 0.09, {"progress": 1.0, "glow": 1.6})
		player.stage.fx.burst(tip, 0.6, Color(1.0, 0.85, 0.5), 5, 5.0, 0.16, 0.0, aim_dir, 0.25)
		Audio.play("thrust", -3.0, randf_range(1.05, 1.15))
		# tempered: the point slips past shields
		hits = line_hit(p, tip, float(strike.width), dmg, ["melee"], strike.kb, strike.poise, {"unblockable": tempered()})
	else:
		var rev := cos(Iso.screen_angle(aim_dir)) < 0.0
		player.stage.fx.swipe(p, aim_dir, strike.range + 0.15, deg_to_rad(strike.arc + 8.0), Color(1.0, 0.85, 0.5, 0.9), 0.12 / speed(), 0.55, rev)
		Audio.play("swing_heavy", -2.0, 1.15)
		hits = arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, {"finisher": true})
		if masterwork():
			_sun_lance(dmg * 0.8)
	if hits > 0:
		player.stage.hitstop(0.05 if not finisher else 0.08)
		player.stage.fx.shake(0.12 if not finisher else 0.24)
	player.on_weapon_strike(hits, finisher)


## Masterwork: the sweep hurls a lance of sunfire.
func _sun_lance(dmg: float) -> void:
	var pr := Projectile.create(player.stage, "proj_lance", player.pos + aim_dir * 0.6, aim_dir * 18.0, player.team)
	pr.source = player
	pr.damage = dmg * damage_scale()
	pr.tags = ["melee", "ranged", "fire"]
	pr.pierce = 4
	pr.life = 0.6
	pr.knockback = 3.0
	pr.trail_color = Color(1.0, 0.8, 0.4)
	pr.trail_rate = 30.0
	pr.reflectable = false


func update(dt: float) -> void:
	super.update(dt)
	if strike.has("from"):
		var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
		if phase == Phase.ACTIVE:
			var k := clampf(phase_t / maxf(phase_len, 0.001), 0.0, 1.0)
			swing = lerpf(deg_to_rad(strike.from), deg_to_rad(strike.to), 1.0 - pow(1.0 - k, 3.0)) * sgn
		elif phase == Phase.RECOVER:
			swing = deg_to_rad(strike.to) * sgn
	else:
		swing = 0.0


func update_visual(dt: float) -> void:
	super.update_visual(dt)
	# the head drives forward on a thrust
	if visual and phase == Phase.ACTIVE and strike.get("thrust", false):
		visual.position += Iso.to_world(aim_dir * 0.45, 0.0) - Iso.to_world(Vector2.ZERO, 0.0)


## Comet Lunge: point-first through the line, then a burst of sunfire.
func release_charge() -> void:
	aim_dir = player.aim
	charged = false
	var from := player.pos
	var to := player.stage.grid.move_box(from, player.box(), aim_dir * LUNGE, true)
	strike = {"windup": 0.0, "active": 0.14, "recover": 0.3, "thrust": true}
	_set_phase(Phase.ACTIVE, 0.14)
	hit_ids.clear()
	player.invuln_t = maxf(player.invuln_t, 0.25)
	for i in 4:
		player.stage.fx.ghost(player.sprite, Iso.to_world(from.lerp(to, i / 3.0), 0.0), Color(1.0, 0.75, 0.35), 0.2 + i * 0.04)
	player.pos = to
	Audio.play("rush", -2.0, 1.1)
	var hits := line_hit(from, to, 0.9, def.charged, ["melee"], 6.0, 30.0, {"finisher": true, "unblockable": true})
	# the landing burst
	var r := 1.9 * player.stats.v("area")
	player.stage.fx.ring(to, r, Color(1.0, 0.8, 0.4), 0.25, 0.3)
	player.stage.fx.burst(to, 0.3, Color(1.0, 0.8, 0.4), 22, 6.0, 0.45, 2.0)
	player.stage.fx.flash_light(to, 0.8, Color(1.0, 0.8, 0.45), 3.5, 6.0, 0.3)
	Audio.play("slam", -2.0, 1.2)
	for a in player.stage.in_circle(player.team, to, r):
		if hit_ids.has(a.get_instance_id()):
			continue
		hit_ids[a.get_instance_id()] = true
		var h := Combat.player_hit(player, player.stats, def.charged * 0.6 * damage_scale(), ["melee", "fire"])
		h.knockback = (a.pos - to).normalized() * 7.0
		h.from_dir = (a.pos - to).normalized()
		h.poise = 20.0
		h.burn = 1
		player.deal_hit(a, h, true)
		hits += 1
	if hits > 0:
		player.stage.hitstop(0.08)
		player.stage.fx.shake(0.35)
	player.on_weapon_strike(hits, true)
	combo = 0
