## The Ashen King - boss of the Sunken Throne, the capstone of the Undervault.
##
## Phase 1: greatsword sweeps, Sunfall (pillars of dead sunlight that chase
## you), the Corona (a ring of black suns with a gap to slip through) and a
## leaping slam whose shockwave must be dodged through.
## Phase 2 (50%): the Eclipse. Every few breaths the King puts the sun out:
## only the light of the arena's braziers shelters you, and each eclipse eats
## one of them. Strike a dark brazier to relight it; relight all four and the
## dawn sears him, staggered and exposed. His sweeps now cast lances, and ash
## hounds answer his call.
## Enrage (20%): faster, double rings.
extends Enemy

const SAFE_R := 2.6
const ECLIPSE_T := 2.8

var phase := 1
var cooldown := 1.8
var last_attack := ""
var braziers: Array = []
var arena_center := Vector2.ZERO
var leap_target := Vector2.ZERO
var leap_from := Vector2.ZERO
var eclipse_t := 6.0
var hound_t := 5.0
var seared_t := 0.0
var sunrise_cd := 0.0
var double_ring := false
var intro := true
var _step_t := 0.0
var _eclipses := 0


func _ready() -> void:
	super._ready()
	spawn_t = 1.6
	anchored = true
	mass = 22.0
	bar_offset = 9.0


func hit_color() -> Color:
	return Color(0.75, 0.6, 0.45)


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate * tempo
	sunrise_cd -= dt
	if phase == 2:
		eclipse_t -= dt
		hound_t -= dt
		if hound_t <= 0.0:
			hound_t = 11.0
			_call_hounds()
		if seared_t > 0.0:
			seared_t -= dt
	if phase == 1 and hp_ratio() <= 0.5 and state != "roar":
		_begin_eclipse_phase()
		return
	if phase == 2 and attack_rate < 1.29 and hp_ratio() <= 0.2:
		attack_rate = 1.3
		double_ring = true
		stage.fx.number(pos, 4.5, "ENRAGED", Color(1.0, 0.45, 0.3), true)
	match state:
		"idle":
			if intro:
				intro = false
				set_state("roar")
				sprite.play("roar")
				Audio.play("boss_roar", 2.0, 0.85)
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
			if timer(0.8):
				_do_sweep()
		"sweep_recover":
			vel = Vector2.ZERO
			if timer(0.7):
				_end_attack()
		"sunfall":
			vel = Vector2.ZERO
			if timer(1.9):
				set_state("recover")
		"corona":
			vel = Vector2.ZERO
			if timer(0.65):
				_corona(0.0)
				if phase == 2 or double_ring:
					var me: WeakRef = weakref(self)
					stage.after(0.6, func() -> void:
						var k = me.get_ref()
						if k and k.alive:
							k._corona(0.5))
				set_state("recover")
		"leap_crouch":
			vel = Vector2.ZERO
			if timer(0.4):
				set_state("leap_air")
				sprite.play("air")
				leap_from = pos
				Audio.play("leap", 0.0, 0.65)
				voice("jump")
		"leap_air":
			var k := clampf(state_t / 0.8, 0.0, 1.0)
			pos = stage.grid.move_box(pos, box(), leap_from.lerp(leap_target, k) - pos, true)
			height = sin(k * PI) * 3.4
			invuln_t = 0.1
			if k >= 1.0:
				height = 0.0
				_slam()
		"eclipse":
			vel = Vector2.ZERO
			invuln_t = 0.1
			if timer(ECLIPSE_T):
				_eclipse_land()
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
	if d > 3.2:
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
	if phase == 2 and eclipse_t <= 0.0:
		_begin_eclipse()
		return
	if cooldown > 0.0:
		return
	var opts: Array = []
	if d < 4.6:
		opts.append_array(["sweep", "sweep"])
	opts.append("sunfall")
	if d > 3.5:
		opts.append("corona")
	opts.append("leap")
	opts.erase(last_attack)
	var pick: String = opts[randi() % opts.size()]
	last_attack = pick
	aim_dir = dir_to_player()
	facing = aim_dir
	match pick:
		"sweep":
			set_state("sweep_windup")
			sprite.play("windup")
			telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(9.2, 9.2), 0.8 / attack_rate, {"half_angle": deg_to_rad(105.0)})
			Audio.play("boss_windup", -2.0, 0.9)
		"sunfall":
			set_state("sunfall")
			sprite.play("cast")
			Audio.play("chant", -2.0, 0.6)
			_sunfall(4 if phase == 1 else 6)
		"corona":
			set_state("corona")
			sprite.play("cast")
			Audio.play("chant", -2.0, 0.8)
			telegraph(Fx.Shape.RING, pos, Vector2.RIGHT, Vector2(3.0, 3.0), 0.65 / attack_rate, {"inner": 0.8})
		"leap":
			leap_target = stage.random_floor_near(t.pos, 0.5)
			set_state("leap_crouch")
			sprite.play("crouch")
			telegraph(Fx.Shape.DISC, leap_target, Vector2.RIGHT, Vector2(6.0, 6.0), (0.4 + 0.8) / attack_rate)


func _do_sweep() -> void:
	sprite.play("sweep")
	strike_arc(pos, aim_dir, 4.6, deg_to_rad(105.0), damage, 9.0)
	stage.fx.swipe(pos, aim_dir, 4.6, deg_to_rad(108.0), Color(1.0, 0.75, 0.35, 0.9), 0.14, 0.55)
	stage.fx.shake(0.3)
	Audio.play("sweep", 0.0, 0.85)
	if phase == 2:
		for k in 5:
			var pr := shoot("proj_sun", aim_dir.rotated((k - 2) * 0.28), 9.0, damage * 0.5, 0.2)
			pr.knockback = 3.0
		Audio.play("sunlance", -2.0, 0.8)
	set_state("sweep_recover")


## Pillars of dead sunlight fall where the Kindled stands, one after another.
func _sunfall(n: int) -> void:
	var me: WeakRef = weakref(self)
	for i in n:
		stage.after(0.35 * i, func() -> void:
			var k = me.get_ref()
			if k == null or not k.alive or k.target() == null:
				return
			var at: Vector2 = k.target().pos + k.target().vel * 0.25
			k.stage.fx.shape(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(3.0, 3.0), TELE_COLOR, TELE_EDGE, 0.9, {"progress": 0.0})
			k.stage.after(0.85, func() -> void:
				var k2 = me.get_ref()
				if k2 and k2.alive:
					k2._pillar(at)))


func _pillar(at: Vector2) -> void:
	strike_circle(at, 1.5, damage * 0.9, 6.0)
	stage.fx.burst(at, 0.2, Color(1.0, 0.85, 0.45), 18, 5.0, 0.5, -2.0, Vector2.ZERO, PI, 6.0)
	stage.fx.flash_light(at, 2.5, Color(1.0, 0.8, 0.4), 4.0, 5.0, 0.35)
	stage.fx.ring(at, 1.6, Color(1.0, 0.85, 0.5), 0.3, 0.2)
	stage.fx.splat(at, Color(0.18, 0.14, 0.12), 6.0, 0.8)
	Audio.play("slam", -6.0, 1.4)


## A ring of black suns with a gap three wide to slip through.
func _corona(offset: float) -> void:
	var n := 18
	var gap := randi() % n
	Audio.play("orb", 0.0, 0.7)
	for k in n:
		if posmod(k - gap, n) < 3:
			continue
		var d := Vector2.RIGHT.rotated((k + offset) * TAU / n)
		var pr := shoot("proj_eclipse", d, 4.6, damage * 0.6, 0.3)
		pr.life = 5.0
		pr.spin = false


func _slam() -> void:
	sprite.play("slam")
	stage.fx.shake(0.7)
	stage.fx.burst(pos, 0.1, Color(0.55, 0.5, 0.5), 30, 7.0, 0.7, 9.0, Vector2.ZERO, PI, 3.0)
	stage.fx.burst(pos, 0.1, Color(1.0, 0.75, 0.35), 18, 5.0, 0.6, 2.0)
	Audio.play("slam", 3.0, 0.65)
	voice("land", -4.0)
	strike_circle(pos, 3.0, damage * 1.2, 10.0)
	_shockwave(pos, damage * 0.8)
	set_state("recover")


func _shockwave(center: Vector2, wave_dmg: float) -> void:
	var st := stage
	var hit_done: Array = []
	var ring := st.fx.shape(Fx.Shape.RING, center, Vector2.RIGHT, Vector2(2, 2), Color(1.0, 0.75, 0.35, 0.8), Color(1.0, 0.92, 0.7, 1.0), 1.0, {"inner": 0.86, "glow": 1.6})
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


# --- the Eclipse --------------------------------------------------------------

func _begin_eclipse_phase() -> void:
	print("[ashen_king] eclipse phase at %d%%" % int(hp_ratio() * 100.0))
	phase = 2
	attack_rate = 1.15
	vel = Vector2.ZERO
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	set_state("roar")
	sprite.play("roar")
	Audio.play("boss_roar", 3.0, 0.7)
	stage.fx.shake(0.8)
	stage.fx.number(pos, 4.5, "THE ECLIPSE", Color(1.0, 0.75, 0.35), true)
	phase_moment("The Eclipse", "When the sun goes out, stand in a brazier's light", Color(1.0, 0.72, 0.32))
	eclipse_t = 3.0
	hound_t = 4.0


func _lit() -> Array:
	return braziers.filter(func(b): return is_instance_valid(b) and b.lit)


func _begin_eclipse() -> void:
	eclipse_t = 13.0 if not double_ring else 10.0
	_eclipses += 1
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	set_state("eclipse")
	sprite.play("cast")
	Audio.play("chant", 2.0, 0.5)
	stage.fx.number(pos, 4.5, "ECLIPSE", Color(0.75, 0.5, 1.0), true)
	# the dark comes in from everywhere; the brazier light holds
	stage.fx.shape(Fx.Shape.DISC, arena_center, Vector2.RIGHT, Vector2(30, 30), Color(0.12, 0.04, 0.2, 0.5), Color(0.55, 0.3, 0.8, 1.0), ECLIPSE_T + 0.1, {"progress": 0.0})
	for b in _lit():
		stage.fx.shape(Fx.Shape.DISC, b.pos, Vector2.RIGHT, Vector2(SAFE_R * 2.0, SAFE_R * 2.0), Color(1.0, 0.8, 0.4, 0.3), Color(1.0, 0.9, 0.6, 1.0), ECLIPSE_T + 0.1, {"glow": 1.6})


## True when the Kindled stands in the light of a lit brazier.
func sheltered(p: Vector2) -> bool:
	for b in _lit():
		if b.pos.distance_to(p) <= SAFE_R:
			return true
	return false


func _eclipse_land() -> void:
	var pl := target()
	stage.fx.shake(0.6)
	stage.fx.flash_light(arena_center, 3.0, Color(0.5, 0.2, 0.8), 6.0, 16.0, 0.6)
	Audio.play("boss_hurt", 0.0, 0.5)
	if pl and not sheltered(pl.pos):
		var h := make_hit(damage * 2.2, pos, 0.0)
		h.tags = ["eclipse"]
		h.unblockable = true
		pl.take_enemy_hit(h, self)
		stage.fx.burst(pl.pos, 0.8, Color(0.4, 0.15, 0.6), 24, 4.0, 0.6, 0.0)
	# each eclipse eats one of the lights
	var lit := _lit()
	if lit.size() > 1:
		var b = lit[randi() % lit.size()]
		b.set_lit(false)
		stage.fx.burst(b.pos, 1.4, Color(0.45, 0.2, 0.65), 18, 3.0, 0.6, 0.0)
	set_state("recover")


## Called by a brazier when the player relights it.
func on_brazier_lit() -> void:
	if phase == 2 and _lit().size() >= braziers.size() and sunrise_cd <= 0.0 and state != "eclipse":
		sunrise_cd = 20.0
		seared_t = 4.5
		status.stagger_t = 4.5
		status.exposed_t = 6.0
		if tele and is_instance_valid(tele):
			stage.fx.release(tele)
		set_state("seared")
		sprite.play("stagger")
		vel = Vector2.ZERO
		height = 0.0
		stage.fx.number(pos, 4.5, "DAWN!", Color(1.0, 0.85, 0.4), true)
		stage.fx.burst(pos, 1.5, Color(1.0, 0.8, 0.35), 40, 6.0, 0.8, 2.0)
		stage.fx.flash_light(pos, 2.0, Color(1.0, 0.8, 0.4), 6.0, 10.0, 0.8)
		Audio.play("boss_hurt", 2.0)


func _call_hounds() -> void:
	var alive_n := 0
	for a in stage.actors:
		if a is Enemy and a != self and a.alive:
			alive_n += 1
	if alive_n >= 4:
		return
	for i in 2:
		var p := stage.foe_spot(arena_center + Vector2.from_angle(randf() * TAU) * 6.0, 2.0)
		var h := preload("res://src/entities/enemies/skitter.gd").new()
		h.configure("hound")
		h.xp = 1
		h.embers = 0
		h.pos = p
		h.room_id = room_id
		stage.add_actor(h)
		if stage.has_method("register_enemy"):
			stage.register_enemy(h)


func _end_attack() -> void:
	cooldown = randf_range(0.7, 1.3) if phase == 1 else randf_range(0.4, 0.9)
	set_state("stalk")


func on_poise_break(h: Hit) -> void:
	# nothing interrupts the eclipse once it has begun
	if state == "eclipse":
		stage.fx.number(pos, 4.0, "UNSHAKEN", Color(0.75, 0.5, 1.0))
		return
	super.on_poise_break(h)
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	if state not in ["seared", "eclipse"]:
		set_state("recover")
		sprite.play("stagger")
		height = 0.0


func die(killer: Node) -> void:
	if not alive:
		return
	stage.slow_motion(0.2, 1.8)
	stage.fx.shake(1.0)
	stage.fx.flash_light(pos, 2.0, Color(1.0, 0.85, 0.5), 9.0, 16.0, 1.8)
	for i in 3:
		stage.fx.burst(pos, 1.5, Color(1.0, 0.8, 0.4), 40, 8.0, 1.2, 1.0)
	stage.fx.burst(pos, 1.0, Color(0.5, 0.45, 0.45), 40, 5.0, 1.8, -1.0)
	# the fires come back one by one, and he comes down as ash
	var at := pos
	stage.look_toward(at, 2.4)
	var k := 0
	for b in braziers:
		if is_instance_valid(b):
			stage.after(0.2 + k * 0.28, func() -> void:
				if is_instance_valid(b):
					b.set_lit(true)
					stage.fx.flash_light(b.pos, 1.6, Color(1.0, 0.8, 0.45), 4.0, 7.0, 0.7))
			k += 1
	for j in 16:
		stage.after(0.2 + j * 0.16, func() -> void:
			stage.fx.motes(at + Vector2(randf_range(-4.5, 4.5), randf_range(-3.0, 3.0)), 4.0, Color(0.62, 0.58, 0.56), 4, -1.0, 1.5, 0.4))
	Audio.play("boss_death", 3.0, 0.85)
	super.die(killer)
	Events.boss_defeated.emit(self)


func _death_effect() -> void:
	guardian_fall()
