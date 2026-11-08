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
## Choking: hurt it enough while it inhales and the maw clogs: no bite, and it gags.
## Its living arena: from Full Bloom a lash leaves a ridge of thorn along its line, and
## the moment it blooms hedges grow in between the roots. Thorn can be cut and it burns.
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
var _inhaled := 0.0
const CHOKE_AT := 0.07        # of its life, in one breath
const RIDGE_LIFE := 9.0


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


func on_damaged(hit: Hit, res: Combat.Result) -> void:
	super.on_damaged(hit, res)
	if state == "inhale" and alive:
		_inhaled += res.amount
		if _inhaled >= max_hp * CHOKE_AT:
			_choke()


## It breathed in more than it could swallow.
func _choke() -> void:
	inhale_cd = 12.0
	status.stagger_t = 2.5
	status.exposed_t = 3.5
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	set_state("wilt")
	sprite.play("wilt")
	stage.fx.number(pos, 5.0, "CHOKED", Color(1.0, 0.75, 0.35), true)
	stage.fx.burst(pos, 3.0, Color(0.75, 0.9, 0.5), 30, 5.0, 0.7, 2.0)
	Audio.play("boss_hurt", 0.0, 1.5)


## Thorn along a line from here, where it can stand; it dies back on its own.
func _ridge(from: Vector2, dir: Vector2, start: float, length: float) -> void:
	var st := stage
	var r := start
	var done := {}
	while r < length:
		var p := from + dir * r
		r += 0.9
		var ti := Vector2i(floori(p.x), floori(p.y))
		if done.has(ti) or st.grid.at(ti.x, ti.y) != TileGrid.FLOOR:
			continue
		done[ti] = true
		var c := Vector2(ti) + Vector2(0.5, 0.5)
		var clear := true
		for a in st.actors:
			if a.alive and a != self and a.pos.distance_to(c) < 1.1:
				clear = false
		if not clear:
			continue
		var pr := Prop.make(st, "bramble", ti, {"grown": true})
		pr.room_id = room_id
		st.fx.burst(c, 0.3, Color(0.4, 0.6, 0.25), 6, 3.0, 0.4, 6.0, Vector2.ZERO, PI, 3.0)
		var keep: WeakRef = weakref(pr)
		st.after(RIDGE_LIFE + randf_range(0.0, 1.5), func() -> void:
			var q = keep.get_ref()
			if q and is_instance_valid(q) and not q.used:
				q.unsolid()
				st.props.erase(q)
				st.fx.burst(q.pos, 0.4, Color(0.35, 0.3, 0.2), 6, 2.0, 0.5, 5.0)
				q.queue_free())


## Full Bloom: hedges between its roots: the way to each root must now be cut or gone round.
func _grow_hedges() -> void:
	var live: Array = braziers.filter(func(b): return is_instance_valid(b) and not b.used)
	for b in live:
		var c: Vector2 = (b as Prop).pos
		_ridge(c, (arena_center - c).orthogonal().normalized(), 1.5, 5.0)
		_ridge(c, -(arena_center - c).orthogonal().normalized(), 1.5, 5.0)
	Audio.play_at("crumble", pos, 0.0, 0.8)


## The Rootbound Bloom: it is not rooted to the floor, it is rooted to its roots.
## It goes under and comes up at another of them. A burned root is one less place
## to go; with all of them burned it has to stay where it stands.
var burrow_t := 13.0
var _burrow_to := Vector2.ZERO


func _burrow_spot() -> Vector2:
	var open: Array = []
	for b in braziers:
		if is_instance_valid(b) and not b.used and b.pos.distance_to(pos) > 4.0:
			open.append(b)
	if open.is_empty():
		return Vector2.INF
	var n: Node = open[randi() % open.size()]
	var c: Vector2 = (n as Prop).pos
	return stage.foe_spot(c + (arena_center - c).normalized() * 2.2, 1.2, room_id)


func _begin_burrow() -> bool:
	_burrow_to = _burrow_spot()
	if _burrow_to == Vector2.INF:
		burrow_t = 9999.0
		return false
	burrow_t = 13.0 if phase == 1 else 10.0
	set_state("burrow")
	sprite.play("wilt")
	telegraph(Fx.Shape.DISC, _burrow_to, Vector2.RIGHT, Vector2(6.4, 6.4), 1.5 / attack_rate)
	Audio.play_at("crumble", pos, 0.0, 0.7)
	stage.fx.shake(0.3)
	return true


func behave(dt: float) -> void:
	vel = Vector2.ZERO
	cooldown -= dt * attack_rate * tempo
	inhale_cd -= dt
	if form == "rootbound":
		burrow_t -= dt
		if burrow_t <= 0.0 and state in ["idle", "recover"] and _begin_burrow():
			return
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
		"burrow":
			invuln_t = 0.1
			if timer(1.0):
				pos = _burrow_to
				set_state("erupt")
				sprite.play("open")
		"erupt":
			invuln_t = 0.1
			if timer(0.5):
				strike_circle(pos, 3.2, damage * 1.2, 9.0)
				stage.fx.burst(pos, 0.4, Color(0.5, 0.42, 0.3), 30, 5.0, 0.6, 8.0)
				stage.fx.shake(0.4)
				Audio.play_at("slam", pos, -1.0, 0.9)
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
				if phase == 2:
					_ridge(pos, aim_dir, 3.5, 11.0)
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
			# (the breath takes everyone in the arena, not only the one it looks at)
			for t: Player in stage.active_players():
				var to := pos - t.pos
				if to.length() > radius + t.radius + 0.4 and to.length() < 16.0:
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
			_inhaled = 0.0
			sprite.play("open")
			Events.toast.emit("The Bloom inhales. Hurt it enough and it chokes!", Color(0.7, 1.0, 0.5))
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
		var h := Hit.make(null, 4.0, ["dot", "spore"])
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
	phase_moment("Full Bloom", "Burn its roots to wilt it. Thorn can be cut, and it burns", Color(1.0, 0.42, 0.5))
	brood_t = 3.0
	_grow_hedges()


func _brood() -> void:
	var n := 0
	for a in stage.actors:
		if a is Enemy and a != self and a.alive:
			n += 1
	if n >= 5:
		return
	for i in 3:
		var p := stage.foe_spot(pos + Vector2.from_angle(randf() * PI) * 4.0 + Vector2(0, 3), 2.0)
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
	if form == "rootbound" and left == 0:
		Events.toast.emit("It has nowhere left to go.", Color(1.0, 0.7, 0.4))


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
	# it lets go: petals fall a long way, greying as they come
	var at := pos
	stage.look_toward(at, 2.4)
	for k in 7:
		var col := Color(0.9, 0.3, 0.35).lerp(Color(0.5, 0.48, 0.42), k / 6.0)
		stage.after(0.25 + k * 0.3, func() -> void:
			stage.fx.burst(at + Vector2(randf_range(-2.2, 2.2), randf_range(-1.2, 1.2)), 3.0, col, 12, 1.6, 1.6, 1.2))
	super.die(killer)
	Events.boss_defeated.emit(self)


func _death_effect() -> void:
	guardian_fall()
