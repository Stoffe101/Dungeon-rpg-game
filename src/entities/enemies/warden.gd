## The Gloam Warden - boss of the Hollow Ossuary.
##
## Phase 1: halberd sweeps, triple thrusts, a leaping quake whose shockwave must
## be dodged through, and fans of soul-lanterns.
## Phase 2 (55%): Gloamfall - it snuffs the arena's braziers, calls skitters and
## gains a gloamfire rush. Re-lighting all four braziers (strike them) sears the
## Warden: staggered and exposed for a punishing window.
## Enrage (20%): faster, sweeps come back the other way.
## The Harvest (all phases): souls rise at the edges of the arena and drift to its cage.
## Strike them down on the way. Every one that arrives feeds the Reaping, a turning blade
## that passes over anyone standing close; none arriving leaves the cage empty and it reels.
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
var harvest_t := 10.0
var souls := 0
var harvest_out := 0
var harvest_fed := 0
var reap_angle := 0.0
var reap_turn := 1.0
var reap_arc := 1.0
var _reap_hit: Array = []
var _reap_fx := 0.0

const REAP_REACH := 9.0
const REAP_INSIDE := 1.7       # the haft passes over this close
const REAP_TIME := 2.2


func _ready() -> void:
	super._ready()
	spawn_t = 1.6
	anchored = true
	mass = 20.0
	bar_offset = 8.0


func hit_color() -> Color:
	return Color(0.55, 0.5, 0.6)


## The Lightless Warden: the arena is dark from the start, the lantern shrinks in
## it, and the Warden steps through the dark to wherever you are. Relighting the
## braziers takes that away a flame at a time, and all four sear it, at any health.
func take_form(id: String) -> void:
	super.take_form(id)
	if stage is Dungeon:
		var d := stage as Dungeon
		d.layout.room(d.layout.exit_id).rule = "unlit"


func begin_form() -> void:
	if form == "lightless":
		_snuff_all()


func _dark_task() -> void:
	if form == "lightless" and stage is Dungeon:
		var n := _lit_count()
		(stage as Dungeon)._set_objective("" if n >= braziers.size() else "RELIGHT THE BRAZIERS  %d/%d" % [n, braziers.size()], -1.0, Color(0.72, 0.5, 1.0))


func _begin_step() -> void:
	set_state("step_out")
	sprite.play("crouch")
	Audio.play_at("wisp", pos, -4.0, 0.6)
	stage.fx.burst(pos, 1.0, Color(0.5, 0.35, 0.8), 18, 2.5, 0.5, -1.0)


func _step_through() -> void:
	var t := target()
	if t == null:
		set_state("stalk")
		return
	var behind := t.pos - t.look.normalized() * 2.6
	pos = stage.foe_spot(behind, 0.6, room_id)
	aim_dir = (t.pos - pos).normalized()
	facing = aim_dir
	set_state("sweep_windup")
	sprite.play("windup")
	stage.fx.burst(pos, 1.0, Color(0.5, 0.35, 0.8), 18, 2.5, 0.5, -1.0)
	telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(8.6, 8.6), 0.85 / attack_rate, {"half_angle": deg_to_rad(65.0)})
	Audio.play("boss_windup", -2.0)


## Souls rise at the edges and come in; each is a small foe with one thing to do.
func _begin_harvest() -> void:
	harvest_t = 17.0 if phase == 1 else 14.0
	harvest_fed = 0
	harvest_out = 3
	stage.fx.number(pos, 4.0, "THE HARVEST", Color(0.5, 1.0, 0.92), true)
	Audio.play("chant", -2.0, 1.2)
	var a := randf() * TAU
	for k in harvest_out:
		var p := stage.foe_spot(arena_center + Vector2.from_angle(a + k * TAU / harvest_out) * 8.5, 2.0, room_id)
		var s: Enemy = preload("res://src/entities/enemies/soul_mote.gd").new()
		s.configure("soul_mote")
		s.xp = 0
		s.embers = 0
		s.pos = p
		s.room_id = room_id
		s.set("warden", self)
		stage.add_actor(s)
		if stage.has_method("register_enemy"):
			stage.register_enemy(s)
		stage.share_danger(p, 1.0, {"kind": Fx.Shape.DISC, "dir": Vector2.RIGHT, "size": Vector2(1.6, 1.6)})


## A soul reached the cage.
func soul_arrived() -> void:
	harvest_fed += 1
	souls = mini(3, souls + 1)
	_soul_settled()
	stage.fx.burst(pos, 3.0, Color(0.5, 1.0, 0.92), 14, 3.0, 0.5, -1.0)
	Audio.play_at("wisp", pos, -2.0, 0.8)


## A soul was struck down before it got there.
func soul_lost() -> void:
	_soul_settled()


func _soul_settled() -> void:
	harvest_out -= 1
	if harvest_out > 0:
		return
	if harvest_fed == 0 and state in ["stalk", "recover", "idle"]:
		# every soul stopped: the cage rings empty and it reels
		status.stagger_t = 1.8
		status.exposed_t = 3.5
		if tele and is_instance_valid(tele):
			stage.fx.release(tele)
		set_state("recover")
		sprite.play("stagger")
		stage.fx.number(pos, 4.0, "THE CAGE IS EMPTY", Color(1.0, 0.8, 0.45), true)
		Audio.play("boss_hurt", 0.0, 1.1)


func _begin_reap() -> void:
	reap_arc = 0.55 + 0.2 * souls
	souls = 0
	reap_angle = aim_dir.angle()
	reap_turn = 1.0 if randf() < 0.5 else -1.0
	set_state("reap_windup")
	sprite.play("windup")
	telegraph(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(REAP_REACH * 2.0, REAP_REACH * 2.0), 0.95 / attack_rate, {"progress": 0.2})
	Audio.play("boss_windup", 0.0, 0.75)
	stage.fx.number(pos, 3.6, "GET CLOSE", Color(0.75, 1.0, 0.92))


## One turn of the blade: anyone in its path, out past the haft.
func _reap_tick(dt: float) -> void:
	vel = Vector2.ZERO
	var k := clampf(state_t / (REAP_TIME * reap_arc), 0.0, 1.0)
	var a := reap_angle + reap_turn * k * TAU * reap_arc
	var dir := Vector2.from_angle(a)
	facing = dir
	_reap_fx -= dt
	if _reap_fx <= 0.0:
		_reap_fx = 0.09
		stage.fx.shape(Fx.Shape.RECT, pos, dir, Vector2(REAP_REACH, 1.1), Color(0.5, 1.0, 0.9, 0.0), Color(0.7, 1.0, 0.95, 1.0), 0.12, {"progress": 1.0, "glow": 1.4})
		stage.share_danger(pos + dir.rotated(reap_turn * 0.5) * REAP_REACH * 0.5, 0.25, {"kind": Fx.Shape.DISC, "dir": Vector2.RIGHT, "size": Vector2(REAP_REACH, REAP_REACH)})
	for pl in stage.active_players():
		if pl in _reap_hit or pl.height >= 0.3:
			continue
		var off := pl.pos - pos
		var d := off.length()
		if d <= REAP_INSIDE or d > REAP_REACH:
			continue
		if absf(angle_difference(off.angle(), a)) * d < 0.8:
			_reap_hit.append(pl)
			var h := make_hit(damage * 1.15, pos, 9.0)
			pl.take_enemy_hit(h, self)
	if k >= 1.0:
		_reap_hit.clear()
		stage.fx.shake(0.2)
		set_state("recover")


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate * tempo
	harvest_t -= dt
	if harvest_t <= 0.0 and state in ["stalk", "recover"]:
		_begin_harvest()
	if phase == 2 or form == "lightless":
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
		"step_out":
			vel = Vector2.ZERO
			invuln_t = 0.1
			if timer(0.6):
				_step_through()
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
		"reap_windup":
			vel = Vector2.ZERO
			if timer(0.95):
				_reap_hit.clear()
				_reap_fx = 0.0
				set_state("reap")
				sprite.play("sweep")
				Audio.play("rush", 0.0, 0.7)
		"reap":
			_reap_tick(dt)
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
	if form == "lightless" and _lit_count() < braziers.size():
		opts.append_array(["step", "step"])
	opts.erase(last_attack)
	if opts.is_empty():
		opts = ["quake"]
	var pick: String = opts[randi() % opts.size()]
	if souls > 0 and last_attack != "reap":
		pick = "reap"       # what the cage took, it spends
	last_attack = pick
	aim_dir = dir_to_player()
	facing = aim_dir
	match pick:
		"step":
			_begin_step()
		"reap":
			_begin_reap()
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
	stage.note_danger(quake_target if quake_target != Vector2.ZERO else pos, 0.95, {"kind": -1, "wave": [1.0, 10.0, 0.95]})
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
				var h := Hit.make(null, wave_dmg, ["melee", "shockwave"])
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
			var h := Hit.make(null, 7.0, ["dot", "gloamfire"])
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
	phase_moment("Gloamfall", "Relight the braziers to sear the Warden, and strike down what comes to its cage", Color(0.72, 0.48, 0.95))
	_snuff_all()
	summon_t = 3.0


func _snuff_all() -> void:
	for b in braziers:
		if is_instance_valid(b):
			b.set_lit(false)
	stage.fx.ring(pos, 12.0, Color(0.55, 0.3, 0.8), 0.6, 0.05)
	braziers_changed.emit(0)
	_dark_task()


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
	_dark_task()
	if (phase == 2 or form == "lightless") and n >= braziers.size() and seared_t <= 0.0:
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
		var p := stage.foe_spot(arena_center + Vector2.from_angle(randf() * TAU) * 6.0, 2.0)
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
	# the cage at its hip breaks: what it kept goes up past you
	var at := pos
	stage.look_toward(at, 2.4)
	for k in 9:
		stage.after(0.3 + k * 0.22, func() -> void:
			stage.fx.motes(at + Vector2(randf_range(-1.2, 1.2), randf_range(-0.8, 0.8)), 1.2, Color(0.5, 1.0, 0.92), 6, 3.2, 1.4, 0.4))
	stage.after(1.4, func() -> void:
		stage.fx.ring(at, 8.0, Color(0.5, 1.0, 0.92), 1.2, 0.2)
		stage.fx.flash_light(at, 3.0, Color(0.55, 1.0, 0.95), 5.0, 18.0, 1.6))
	super.die(killer)
	Events.boss_defeated.emit(self)


func _death_effect() -> void:
	guardian_fall()
