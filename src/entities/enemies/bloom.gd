## The Hollow Bloom - boss of the Rootmire. A colossal corpse-flower rooted to
## the floor: it cannot move, so it controls space.
##
## Lash: a tendril slams a long line toward you.
## Spore volley: pods rain onto marked circles and leave clouds.
## Inhale: the maw opens and drags you in. While inhaling it takes double
##   damage - greed is rewarded, until the bite at the end.
## Phase 2 (55%): radial root eruptions and sporeling broods.
## Its four root nodes can be burned (or hacked apart): each one wilts the
## Bloom - a chunk of its life, a stagger, and an opening.
extends Enemy

var phase := 1
var cooldown := 2.0
var last_attack := ""
var braziers: Array = []   # the root nodes (named for the shared boss hookup)
var arena_center := Vector2.ZERO
var inhale_cd := 6.0
var brood_t := 8.0
var volley_marks: Array = []
var root_angle := 0.0
var intro := true


func _ready() -> void:
	super._ready()
	spawn_t = 1.8
	anchored = true
	mass = 50.0
	bar_offset = 10.0
	shadow_scale = 1.6
	# the maw glows: the boss is always the brightest thing in its arena
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.65, 1.0, 0.5)
	glow.light_energy = 1.6
	glow.omni_range = 12.0
	glow.omni_attenuation = 0.8
	glow.position = Vector3(0, 3.0 * Iso.SQ2, 0.6)
	visual.add_child(glow)


func hit_color() -> Color:
	return Color(0.75, 0.3, 0.3)


func extra_damage_taken(_h: Hit) -> float:
	return 2.0 if state == "inhale" else 1.0


func behave(dt: float) -> void:
	vel = Vector2.ZERO
	cooldown -= dt * attack_rate * tempo
	inhale_cd -= dt
	if phase == 1 and hp_ratio() <= 0.55 and state in ["idle", "recover"]:
		_bloom_phase()
		return
	if phase == 2:
		brood_t -= dt
		if brood_t <= 0.0:
			brood_t = 11.0
			_brood()
	match state:
		"idle":
			if intro:
				intro = false
				set_state("roar")
				sprite.play("open")
				Audio.play("boss_roar", 0.0, 1.3)
				stage.fx.shake(0.4)
				return
			sprite.play("idle")
			if cooldown <= 0.0 and target():
				_choose()
		"roar":
			invuln_t = 0.2
			if state_t > 1.4:
				sprite.play("close")
				set_state("recover")
		"lash":
			if timer(0.8):
				sprite.play("spit")
				strike_line(pos, aim_dir, 13.0, 1.8, damage * 1.1, 8.0)
				for i in 13:
					stage.fx.burst(pos + aim_dir * (i + 0.5), 0.3, Color(0.45, 0.65, 0.3), 2, 3.0, 0.35, 8.0, Vector2.ZERO, PI, 3.0)
				stage.fx.shake(0.25)
				Audio.play("sweep", -2.0, 1.2)
				set_state("recover")
		"volley":
			if timer(1.0):
				Audio.play("explode", -6.0, 1.5)
				for at: Vector2 in volley_marks:
					stage.fx.burst(at, 0.3, Color(0.6, 0.85, 0.35), 12, 3.0, 0.5, 2.0)
					strike_circle(at, 1.3, damage * 0.8, 3.0)
					var hz := Hazard.spawn(stage, at, 1.2, 3.0, Team.ENEMY, Color(0.55, 0.85, 0.35), Callable())
					hz.period = 0.5
					hz.effect = _cloud_tick
				volley_marks.clear()
				set_state("recover")
		"inhale":
			sprite.play("inhale")
			var t := target()
			if t:
				var to := pos - t.pos
				if to.length() > radius + t.radius + 0.4:
					# steady pull (~4.5 tiles/s) - you can walk against it, barely
					t.push += to.normalized() * 40.0 * dt
				if randf() < 0.6:
					var off := Vector2.from_angle(randf() * TAU) * randf_range(3.0, 7.0)
					stage.fx.burst(pos + off, 0.4, Color(0.75, 0.9, 0.6), 1, 0.2, 0.4, 0.0, -off, 0.1)
			if state_t > 2.4:
				set_state("bite")
				telegraph(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(6.0, 6.0), 0.5 / attack_rate)
		"bite":
			if timer(0.5):
				sprite.play("close")
				strike_circle(pos, 3.0, damage * 1.6, 10.0)
				stage.fx.shake(0.45)
				Audio.play("slam", 0.0, 1.3)
				inhale_cd = 12.0
				set_state("recover")
		"roots":
			if timer(1.0):
				Audio.play("crumble", 0.0, 0.8)
				for k in 8:
					var d := Vector2.from_angle(root_angle + k * TAU / 8.0)
					strike_line(pos, d, 14.0, 1.2, damage, 6.0)
					for i in range(2, 14, 2):
						stage.fx.burst(pos + d * i, 0.2, Color(0.5, 0.4, 0.3), 3, 3.0, 0.4, 9.0, Vector2.ZERO, PI, 3.0)
				stage.fx.shake(0.35)
				set_state("recover")
		"wilt":
			if state_t > 3.0:
				sprite.play("idle")
				set_state("recover")
		"recover":
			if state_t > 0.7:
				cooldown = randf_range(0.8, 1.5) if phase == 1 else randf_range(0.5, 1.0)
				set_state("idle")
		_:
			set_state("idle")


func _choose() -> void:
	var t := target()
	var opts := ["lash", "lash", "volley"]
	if inhale_cd <= 0.0 and dist_to_player() > 3.5:
		opts.append_array(["inhale", "inhale"])
	if phase == 2:
		opts.append_array(["roots", "volley"])
	opts.erase(last_attack)
	var pick: String = opts[randi() % opts.size()]
	last_attack = pick
	aim_dir = dir_to_player()
	match pick:
		"lash":
			set_state("lash")
			sprite.play("open")
			telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(13.0, 1.8), 0.8 / attack_rate)
			Audio.play("boss_windup", -4.0, 1.4)
		"volley":
			set_state("volley")
			sprite.play("spit")
			volley_marks = [t.pos]
			var n := 4 if phase == 1 else 6
			for k in n - 1:
				volley_marks.append(stage.random_floor_near(t.pos + Vector2.from_angle(randf() * TAU) * randf_range(1.5, 3.5), 1.0))
			for at in volley_marks:
				stage.fx.shape(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(2.6, 2.6), TELE_COLOR, TELE_EDGE, 1.05, {"progress": 0.4})
			Audio.play("orb", -2.0, 0.7)
		"inhale":
			set_state("inhale")
			sprite.play("open")
			Events.toast.emit("The Bloom inhales - its maw is exposed!", Color(0.7, 1.0, 0.5))
			Audio.play("boss_roar", -6.0, 1.8)
		"roots":
			set_state("roots")
			root_angle = randf() * TAU
			for k in 8:
				var d := Vector2.from_angle(root_angle + k * TAU / 8.0)
				stage.fx.shape(Fx.Shape.RECT, pos, d, Vector2(14.0, 1.2), TELE_COLOR, TELE_EDGE, 1.05, {"progress": 0.3})
			telegraph(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(3.0, 3.0), 1.0 / attack_rate)


static func _cloud_tick(_h: Hazard, a: Actor) -> void:
	if a is Player:
		var h := Hit.make(null, 4.0, ["dot"])
		h.can_crit = false
		h.silent = true
		(a as Player).take_enemy_hit(h, null)


func _bloom_phase() -> void:
	if OS.is_debug_build():
		print("[bloom] full bloom at %d%%" % int(hp_ratio() * 100.0))
	phase = 2
	attack_rate = 1.15
	set_state("roar")
	sprite.play("open")
	Audio.play("boss_roar", 2.0, 1.1)
	stage.fx.shake(0.6)
	stage.fx.number(pos, 5.0, "FULL BLOOM", Color(1.0, 0.45, 0.5), true)
	Events.banner.emit("Full Bloom", "Burn its roots to wilt it")
	brood_t = 3.0


func _brood() -> void:
	var n := 0
	for a in stage.actors:
		if a is Enemy and a != self and a.alive:
			n += 1
	if n >= 5:
		return
	for i in 3:
		var p := stage.random_floor_near(pos + Vector2.from_angle(randf() * PI) * 4.0 + Vector2(0, 3), 2.0)
		var s := preload("res://src/entities/enemies/sporeling.gd").new()
		s.configure("sporeling")
		s.xp = 1
		s.embers = 0
		s.pos = p
		s.room_id = room_id
		stage.add_actor(s)
		if stage.has_method("register_enemy"):
			stage.register_enemy(s)


## Called by a root node when it is burned or hacked apart.
func on_root_burned(_node: Node) -> void:
	if not alive:
		return
	if OS.is_debug_build():
		print("[bloom] root destroyed at %d%%" % int(hp_ratio() * 100.0))
	var left := 0
	for b in braziers:
		if is_instance_valid(b) and not b.used:
			left += 1
	var h := Hit.make(stage.player, max_hp * 0.06, ["fire"])
	h.can_crit = false
	h.unblockable = true
	take_hit(h)
	if not alive:
		return
	status.stagger_t = 3.0
	status.exposed_t = 5.0
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	set_state("wilt")
	sprite.play("wilt")
	stage.fx.number(pos, 5.0, "WILTED", Color(1.0, 0.7, 0.3), true)
	stage.fx.burst(pos, 2.0, Color(1.0, 0.6, 0.25), 30, 5.0, 0.8, 2.0)
	Audio.play("boss_hurt", 0.0, 1.3)
	Events.toast.emit("A root burns. %d remain." % left, Color(1.0, 0.7, 0.4))


func on_poise_break(h: Hit) -> void:
	super.on_poise_break(h)
	if state != "wilt":
		if tele and is_instance_valid(tele):
			stage.fx.release(tele)
		set_state("recover")


func die(killer: Node) -> void:
	if not alive:
		return
	stage.slow_motion(0.2, 1.5)
	stage.fx.shake(1.0)
	stage.fx.flash_light(pos, 2.0, Color(0.6, 1.0, 0.5), 8.0, 14.0, 1.5)
	for i in 3:
		stage.fx.burst(pos, 2.0, Color(0.9, 0.3, 0.35), 40, 8.0, 1.2, 1.0)
	stage.fx.burst(pos, 1.0, Color(0.6, 0.9, 0.4), 30, 5.0, 1.5, -1.0)
	Audio.play("boss_death", 3.0, 1.2)
	super.die(killer)
	Events.boss_defeated.emit(self)


func _death_effect() -> void:
	sprite.play("wilt")
	var tw := create_tween()
	tw.tween_method(sprite.set_dissolve, 0.0, 1.05, 2.4)
	tw.tween_callback(queue_free)
	if shadow:
		shadow.visible = false
