## The Gloam Warden - boss of the Hollow Ossuary.
##
## Phase 1: halberd sweeps, triple thrusts, a leaping quake whose shockwave must
## be dodged through, and fans of soul-lanterns.
## Phase 2 (55%): Gloamfall - it snuffs the arena's braziers, calls skitters and
## gains a gloamfire rush. Re-lighting all four braziers (strike them) sears the
## Warden: staggered and exposed for a punishing window.
## Enrage (20%): faster, sweeps come back the other way.
extends Enemy

signal braziers_changed(lit: int)

var phase := 1
var cooldown := 1.6
var last_attack := ""
var braziers: Array = []
var arena_center := Vector2.ZERO
var thrusts_left := 0
var quake_target := Vector2.ZERO
var quake_from := Vector2.ZERO
var rush_trail_t := 0.0
var seared_t := 0.0
var snuff_t := 0.0
var summon_t := 6.0
var double_sweep := false
var intro := true
var _step_t := 0.0


func _ready() -> void:
	super._ready()
	spawn_t = 1.6
	anchored = true
	mass = 20.0
	bar_offset = 8.0


func hit_color() -> Color:
	return Color(0.55, 0.5, 0.6)


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate * tempo
	if phase == 2:
		summon_t -= dt
		if summon_t <= 0.0:
			summon_t = 9.0
			_call_skitters()
		if seared_t > 0.0:
			seared_t -= dt
			if seared_t <= 0.0:
				snuff_t = 10.0
		elif snuff_t > 0.0:
			snuff_t -= dt
			if snuff_t <= 0.0 and _lit_count() > 0:
				_snuff_all()
	if phase == 1 and hp_ratio() <= 0.55 and state != "roar":
		_begin_gloamfall()
		return
	if phase == 2 and attack_rate < 1.29 and hp_ratio() <= 0.2:
		attack_rate = 1.3
		double_sweep = true
		stage.fx.number(pos, 4.0, "ENRAGED", Color(1.0, 0.4, 0.4), true)
	match state:
		"idle":
			if intro:
				intro = false
				set_state("roar")
				sprite.play("roar")
				Audio.play("boss_roar", 2.0)
				stage.fx.shake(0.5)
				return
			set_state("stalk")
		"roar":
			vel = Vector2.ZERO
			invuln_t = 0.2
			if state_t > 1.5:
				set_state("stalk")
		"stalk":
			_stalk(dt)
		"sweep_windup":
			vel = Vector2.ZERO
			if timer(0.85):
				_do_sweep()
		"sweep_recover":
			vel = Vector2.ZERO
			if timer(0.25) and double_sweep and not get_meta("second", false):
				set_meta("second", true)
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("sweep_windup")
				sprite.play("windup")
				telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(8.6, 8.6), 0.55 / attack_rate, {"half_angle": deg_to_rad(105.0)})
			elif timer(0.75):
				set_meta("second", false)
				_end_attack()
		"thrust_windup":
			vel = Vector2.ZERO
			if state_t < 0.25:
				aim_dir = dir_to_player()
				facing = aim_dir
			if timer(0.45):
				sprite.play("thrust")
				push += aim_dir * 7.0
				strike_line(pos, aim_dir, 6.0, 1.4, damage, 7.0)
				stage.fx.shape(Fx.Shape.RECT, pos, aim_dir, Vector2(6.0, 1.0), Color(0.6, 0.95, 0.85, 0.0), Color(0.7, 1.0, 0.9, 1.0), 0.12, {"progress": 1.0, "glow": 1.5})
				Audio.play("thrust", -2.0)
				thrusts_left -= 1
				set_state("thrust_gap")
		"thrust_gap":
			vel = Vector2.ZERO
			if timer(0.22):
				if thrusts_left > 0:
					_begin_thrust()
				else:
					set_state("recover")
		"quake_crouch":
			vel = Vector2.ZERO
			if timer(0.35):
				set_state("quake_air")
				sprite.play("air")
				quake_from = pos
				Audio.play("leap", 0.0, 0.7)
				voice("jump")
		"quake_air":
			var k := clampf(state_t / 0.75, 0.0, 1.0)
			pos = stage.grid.move_box(pos, box(), quake_from.lerp(quake_target, k) - pos, true)
			height = sin(k * PI) * 3.0
			invuln_t = 0.1
			if k >= 1.0:
				height = 0.0
				_quake_land()
		"cast":
			vel = Vector2.ZERO
			if timer(0.6):
				_lanterns()
				set_state("recover")
		"rush_windup":
			vel = Vector2.ZERO
			if timer(0.7):
				set_state("rush")
				sprite.play("thrust")
				Audio.play("rush", 0.0)
		"rush":
			vel = aim_dir * 16.0
			rush_trail_t += dt
			if rush_trail_t > 0.08:
				rush_trail_t = 0.0
				_gloamfire(pos)
			if dist_to_player() < radius + 0.5 and not get_meta("rush_hit", false):
				set_meta("rush_hit", true)
				target().take_enemy_hit(make_hit(damage * 1.3, pos, 12.0), self)
			if state_t > 0.75 or stage.grid.box_blocked(pos + aim_dir * (radius + 0.3), box()):
				vel = Vector2.ZERO
				set_meta("rush_hit", false)
				stage.fx.shake(0.3)
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			sprite.play("idle")
			if timer(0.8):
				_end_attack()
		"seared":
			vel = Vector2.ZERO
			if seared_t <= 0.0:
				set_state("stalk")
		_:
			set_state("stalk")


func _stalk(dt: float) -> void:
	var t := target()
	if t == null:
		vel = Vector2.ZERO
		return
	var d := dist_to_player()
	if d > 3.0:
		chase(speed, dt)
		sprite.play("walk")
		_step_t -= dt
		if _step_t <= 0.0:
			_step_t = 0.42
			voice("step", -10.0)
	else:
		vel = Vector2.ZERO
		sprite.play("idle")
	facing = dir_to_player()
	if cooldown > 0.0:
		return
	var opts: Array = []
	if d < 4.2:
		opts.append_array(["sweep", "sweep"])
	if d > 2.5 and d < 9.0:
		opts.append("thrust")
	opts.append("quake")
	if d > 4.0:
		opts.append("cast")
	if phase == 2 and d > 3.0:
		opts.append_array(["rush", "rush"])
	opts.erase(last_attack)
	if opts.is_empty():
		opts = ["quake"]
	var pick: String = opts[randi() % opts.size()]
	last_attack = pick
	aim_dir = dir_to_player()
	facing = aim_dir
	match pick:
		"sweep":
			set_state("sweep_windup")
			sprite.play("windup")
			telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(8.6, 8.6), 0.85 / attack_rate, {"half_angle": deg_to_rad(105.0)})
			Audio.play("boss_windup", -2.0)
		"thrust":
			thrusts_left = 3
			_begin_thrust()
		"quake":
			quake_target = stage.random_floor_near(t.pos, 0.5)
			set_state("quake_crouch")
			sprite.play("crouch")
			telegraph(Fx.Shape.DISC, quake_target, Vector2.RIGHT, Vector2(5.8, 5.8), (0.35 + 0.75) / attack_rate)
		"cast":
			set_state("cast")
			sprite.play("cast")
			Audio.play("chant", -2.0, 0.7)
		"rush":
			set_state("rush_windup")
			sprite.play("windup")
			telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(13.0, 1.9), 0.7 / attack_rate)


func _begin_thrust() -> void:
	aim_dir = dir_to_player()
	facing = aim_dir
	set_state("thrust_windup")
	sprite.play("windup")
	telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(6.0, 1.4), 0.45 / attack_rate)


func _do_sweep() -> void:
	sprite.play("sweep")
	strike_arc(pos, aim_dir, 4.3, deg_to_rad(105.0), damage, 9.0)
	stage.fx.swipe(pos, aim_dir, 4.3, deg_to_rad(108.0), Color(0.55, 0.95, 0.85, 0.9), 0.14, 0.55)
	stage.fx.shake(0.3)
	Audio.play("sweep", 0.0)
	set_state("sweep_recover")


func _quake_land() -> void:
	sprite.play("slam")
	stage.fx.shake(0.7)
	stage.fx.burst(pos, 0.1, Color(0.6, 0.58, 0.62), 30, 7.0, 0.7, 9.0, Vector2.ZERO, PI, 3.0)
	stage.fx.burst(pos, 0.1, Color(0.35, 0.95, 0.85), 16, 5.0, 0.6, 2.0)
	Audio.play("slam", 3.0, 0.7)
	voice("land", -4.0)
	strike_circle(pos, 2.9, damage * 1.2, 10.0)
	# expanding shockwave: dodge through it
	var center := pos
	var st := stage
	var wave_dmg := damage * 0.8
	var hit_done: Array = []
	var ring := st.fx.shape(Fx.Shape.RING, center, Vector2.RIGHT, Vector2(2, 2), Color(0.5, 1.0, 0.9, 0.8), Color(0.85, 1.0, 0.95, 1.0), 1.0, {"inner": 0.86, "glow": 1.6})
	var data: Dictionary = st.fx._shapes[st.fx._shapes.size() - 1]
	var base_t := ring.transform
	data.update = func(t: float, n: MeshInstance3D) -> void:
		var rr := lerpf(1.0, 10.0, clampf(t / 0.95, 0.0, 1.0))
		n.transform = Transform3D(Basis(Vector3(rr * 2.0, 0, 0), Vector3.UP, Vector3(0, 0, rr * 2.0 * Iso.SQ2)), base_t.origin)
		n.set_instance_shader_parameter("px_size", rr * 2.0 * Iso.PPU)
		for pl in st.active_players():
			if hit_done.has(pl) or pl.height >= 0.3:
				continue
			var pd := pl.pos.distance_to(center)
			if absf(pd - rr * 0.93) < 0.45:
				hit_done.append(pl)
				var h := Hit.make(null, wave_dmg, ["melee"])
				h.can_crit = false
				h.knockback = (pl.pos - center).normalized() * 8.0
				h.from_dir = (pl.pos - center).normalized()
				pl.take_enemy_hit(h, null)
	set_state("recover")


func _lanterns() -> void:
	Audio.play("orb", 0.0, 0.8)
	var base := dir_to_player()
	var n := 7 if phase == 1 else 9
	for k in n:
		var d := base.rotated(lerpf(-0.9, 0.9, float(k) / (n - 1)))
		var pr := shoot("proj_orb", d, 5.0, damage * 0.6, 0.3)
		pr.homing_target = target()
		pr.homing_turn = 0.5
		pr.life = 4.5
		pr.spin = false


func _gloamfire(p: Vector2) -> void:
	var hz := Hazard.spawn(stage, p, 0.9, 4.0, Team.ENEMY, Color(0.55, 0.3, 0.8), func(_h: Hazard, a: Actor) -> void:
		if a is Player:
			var h := Hit.make(null, 7.0, ["dot"])
			h.can_crit = false
			(a as Player).take_enemy_hit(h, null))
	hz.period = 0.45
	hz.particle_rate = 8.0


func _end_attack() -> void:
	cooldown = randf_range(0.7, 1.3) if phase == 1 else randf_range(0.4, 0.9)
	set_state("stalk")


func _begin_gloamfall() -> void:
	print("[warden] gloamfall at %d%%" % int(hp_ratio() * 100.0))
	phase = 2
	attack_rate = 1.15
	vel = Vector2.ZERO
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	set_state("roar")
	sprite.play("roar")
	Audio.play("boss_roar", 3.0, 0.8)
	stage.fx.shake(0.8)
	stage.fx.number(pos, 4.0, "GLOAMFALL", Color(0.75, 0.5, 0.95), true)
	Events.banner.emit("Gloamfall", "Relight the braziers to sear the Warden")
	_snuff_all()
	summon_t = 3.0


func _snuff_all() -> void:
	for b in braziers:
		if is_instance_valid(b):
			b.set_lit(false)
	stage.fx.ring(pos, 12.0, Color(0.55, 0.3, 0.8), 0.6, 0.05)
	braziers_changed.emit(0)


func _lit_count() -> int:
	var n := 0
	for b in braziers:
		if is_instance_valid(b) and b.lit:
			n += 1
	return n


## Called by a brazier when the player relights it.
func on_brazier_lit() -> void:
	var n := _lit_count()
	braziers_changed.emit(n)
	print("[warden] braziers lit: %d/%d" % [n, braziers.size()])
	if phase == 2 and n >= braziers.size() and seared_t <= 0.0:
		print("[warden] seared")
		seared_t = 5.0
		status.stagger_t = 5.0
		status.exposed_t = 7.0
		if tele and is_instance_valid(tele):
			stage.fx.release(tele)
		set_state("seared")
		sprite.play("stagger")
		vel = Vector2.ZERO
		height = 0.0
		stage.fx.number(pos, 4.0, "SEARED!", Color(1.0, 0.7, 0.3), true)
		stage.fx.burst(pos, 1.5, Color(1.0, 0.6, 0.25), 40, 6.0, 0.8, 2.0)
		stage.fx.flash_light(pos, 2.0, Color(1.0, 0.6, 0.3), 6.0, 10.0, 0.8)
		Audio.play("boss_hurt", 2.0)


func _call_skitters() -> void:
	var alive_n := 0
	for a in stage.actors:
		if a is Enemy and a != self and a.alive:
			alive_n += 1
	if alive_n >= 4:
		return
	for i in 2:
		var p := stage.random_floor_near(arena_center + Vector2.from_angle(randf() * TAU) * 6.0, 2.0)
		var s := preload("res://src/entities/enemies/skitter.gd").new()
		s.configure("skitter")
		s.xp = 1
		s.embers = 0
		s.pos = p
		s.room_id = room_id
		stage.add_actor(s)
		if stage.has_method("register_enemy"):
			stage.register_enemy(s)


func on_poise_break(h: Hit) -> void:
	super.on_poise_break(h)
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	if state != "seared":
		set_state("recover")
		sprite.play("stagger")
		height = 0.0


func die(killer: Node) -> void:
	if not alive:
		return
	stage.slow_motion(0.2, 1.5)
	stage.fx.shake(1.0)
	stage.fx.flash_light(pos, 2.0, Color(0.5, 1.0, 0.9), 8.0, 14.0, 1.5)
	for i in 3:
		stage.fx.burst(pos, 1.5, Color(0.4, 1.0, 0.9), 40, 8.0, 1.2, 1.0)
	stage.fx.burst(pos, 1.0, Color(1.0, 0.85, 0.5), 30, 5.0, 1.5, -1.0)
	Audio.play("boss_death", 3.0)
	super.die(killer)
	Events.boss_defeated.emit(self)


func _death_effect() -> void:
	sprite.play("stagger")
	var tw := create_tween()
	tw.tween_method(sprite.set_dissolve, 0.0, 1.05, 2.2)
	tw.tween_callback(queue_free)
	if shadow:
		shadow.visible = false
