## Hearthblade: fast three-strike combo (slash, backslash, lunging thrust);
## hold to charge a whirling cut that hits all around.
## Forms (ItemDB "form"):
##   cleaver (Gravecleaver) - two slow, wide cleaves; every third blow on a foe
##     Sunders it (it takes more damage); hold for Grave Drop, an overhead that
##     cracks the ground ahead and executes the wounded.
##   duelist (Duelist's Sabre) - four quick thrusts; hold for En Garde, a guard
##     that answers the first blow it meets with a riposte; a perfect dodge or a
##     Ward readies a riposte too (the next thrust is a flashing lunge-crit).
extends Weapon

const STRIKES := [
	{"windup": 0.07, "active": 0.07, "recover": 0.17, "arc": 62.0, "range": 1.95, "kb": 3.5, "poise": 10.0, "lunge": 2.2, "from": 75.0, "to": -75.0},
	{"windup": 0.06, "active": 0.07, "recover": 0.17, "arc": 62.0, "range": 1.95, "kb": 3.5, "poise": 10.0, "lunge": 2.2, "from": -75.0, "to": 75.0},
	{"windup": 0.11, "active": 0.08, "recover": 0.26, "arc": 26.0, "range": 2.7, "kb": 8.0, "poise": 26.0, "lunge": 5.0, "from": 0.0, "to": 0.0, "thrust": true},
]
const CLEAVES := [
	{"windup": 0.16, "active": 0.09, "recover": 0.28, "arc": 96.0, "range": 2.35, "kb": 6.5, "poise": 28.0, "lunge": 2.4, "from": 105.0, "to": -95.0, "dmg": 20.0},
	{"windup": 0.18, "active": 0.09, "recover": 0.34, "arc": 96.0, "range": 2.35, "kb": 7.5, "poise": 34.0, "lunge": 2.8, "from": -105.0, "to": 95.0, "dmg": 30.0},
]
const THRUSTS := [
	{"windup": 0.05, "active": 0.05, "recover": 0.12, "range": 2.5, "width": 0.5, "kb": 2.5, "poise": 8.0, "lunge": 1.9, "from": 0.0, "to": 0.0, "thrust": true, "dmg": 11.0},
	{"windup": 0.05, "active": 0.05, "recover": 0.12, "range": 2.5, "width": 0.5, "kb": 2.5, "poise": 8.0, "lunge": 1.9, "from": 0.0, "to": 0.0, "thrust": true, "dmg": 11.0},
	{"windup": 0.05, "active": 0.05, "recover": 0.12, "range": 2.5, "width": 0.5, "kb": 2.5, "poise": 8.0, "lunge": 1.9, "from": 0.0, "to": 0.0, "thrust": true, "dmg": 12.0},
	{"windup": 0.07, "active": 0.06, "recover": 0.18, "range": 2.9, "width": 0.6, "kb": 5.0, "poise": 16.0, "lunge": 3.2, "from": 0.0, "to": 0.0, "thrust": true, "dmg": 18.0},
]
const SUNDER_AT := 3          # blows on one foe that Sunder it
const SUNDER_TIME := 4.0      # seconds a Sundered foe takes more damage (Exposed)
const GUARD_TIME := 1.0       # En Garde holds this long, then the arm drops
const RIPOSTE_RANGE := 4.0

var riposte := false          # the Sabre's next thrust is a riposte
var _guard_hit := false


func max_combo() -> int:
	match form:
		"cleaver":
			return 2
		"duelist":
			return 4
	return 3


func _table() -> Array:
	match form:
		"cleaver":
			return CLEAVES
		"duelist":
			return THRUSTS
	return STRIKES


func start_strike(index: int) -> void:
	strike = _table()[index]
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, strike.windup / speed())
	swing = deg_to_rad(strike.from) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)
	player.on_attack_start()


func move_mult() -> float:
	if form == "cleaver" and phase in [Phase.WINDUP, Phase.ACTIVE]:
		return 0.2
	if form == "duelist" and phase == Phase.CHARGE:
		return 0.35
	return super.move_mult()


func on_active() -> void:
	match form:
		"cleaver":
			_cleave()
			return
		"duelist":
			_thrust()
			return
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


# --- Gravecleaver -------------------------------------------------------------------

func _cleave() -> void:
	var finisher := combo == 1
	var p := player.pos
	player.push += aim_dir * float(strike.lunge)
	var rev: bool = strike.from < 0.0
	if cos(Iso.screen_angle(aim_dir)) < 0.0:
		rev = not rev
	player.stage.fx.swipe(p, aim_dir, strike.range + 0.2, deg_to_rad(strike.arc + 10.0), Color(0.82, 0.86, 0.95, 0.95), 0.12 / speed(), 0.32, rev)
	player.stage.fx.swipe(p, aim_dir, strike.range - 0.4, deg_to_rad(strike.arc), Color(0.55, 0.6, 0.75, 0.7), 0.14 / speed(), 0.5, rev)
	Audio.play("swing_heavy", -1.0, randf_range(0.95, 1.05))
	var hits := arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), float(strike.dmg), ["melee"], strike.kb, strike.poise,
		{"finisher": finisher, "each": _sunder})
	if hits > 0:
		Audio.play("cleave_hit", -2.0, randf_range(0.95, 1.05))
		player.stage.hitstop(0.08 if not finisher else 0.11)
		player.stage.fx.shake(0.22 if not finisher else 0.32)
		player.stage.fx.kick(aim_dir, 2.0)
	if finisher and (tempered() or player.stats.has("combo_wave")):
		_cutting_wave(float(strike.dmg) * 0.5)
	player.on_weapon_strike(hits, finisher)


## Every blow on a foe counts; the third Sunders it: it takes more damage.
func _sunder(a: Actor, h: Hit) -> void:
	var n := int(a.get_meta("sunder_n", 0)) + 1
	if float(a.get_meta("sunder_t", -99.0)) < player.stage.elapsed - 3.0:
		n = 1     # the count fades if the cleaver stops coming
	a.set_meta("sunder_t", player.stage.elapsed)
	if n >= SUNDER_AT:
		n = 0
		h.expose = maxf(h.expose, SUNDER_TIME)
		h.poise *= 1.5
		player.stage.fx.number(a.pos, 2.2, "SUNDERED", Color(0.75, 0.85, 1.0), true)
		player.stage.fx.ring(a.pos, 1.0, Color(0.7, 0.8, 1.0), 0.3, 0.25)
		player.stage.fx.burst(a.pos, 0.8, Color(0.8, 0.85, 0.95), 12, 4.0, 0.35, 6.0)
		Audio.play_at("sunder", a.pos, -2.0)
	a.set_meta("sunder_n", n)


## Grave Drop: the cleaver comes down from overhead; the ground splits ahead,
## and the wounded (a quarter of their health or less) are finished.
func _grave_drop() -> void:
	var p := player.pos
	var to := p + aim_dir * 3.4
	strike = {"windup": 0.0, "active": 0.2, "recover": 0.42}
	_set_phase(Phase.ACTIVE, 0.2 / speed())
	hit_ids.clear()
	player.push += aim_dir * 3.0
	player.stage.fx.shape(Fx.Shape.RECT, p, aim_dir, Vector2(3.4, 1.1), Color(0.55, 0.6, 0.75, 0.0), Color(0.85, 0.9, 1.0, 1.0), 0.2, {"progress": 1.0, "glow": 1.4})
	player.stage.fx.splat(p.lerp(to, 0.6), Color(0.1, 0.09, 0.12), 12.0, 1.4)
	for k in 5:
		player.stage.fx.burst(p.lerp(to, (k + 1) / 5.0), 0.1, Color(0.7, 0.68, 0.72), 6, 4.0, 0.5, 8.0, Vector2.ZERO, PI, 2.5)
	Audio.play("slam", 0.0, 1.1)
	var hits := line_hit(p, to, 1.0, def.charged * 1.15, ["melee"], 6.0, 45.0, {"finisher": true, "unblockable": true, "each": _execute})
	player.stage.fx.shake(0.45)
	player.stage.hitstop(0.12 if hits > 0 else 0.04)
	player.on_weapon_strike(hits, true)
	combo = 0


func _execute(a: Actor, h: Hit) -> void:
	if a.hp_ratio() <= 0.25 and not (a is Enemy and (a as Enemy).def.get("boss", false)):
		h.amount *= 2.5
		h.forced_crit = true
		player.stage.fx.number(a.pos, 2.6, "EXECUTED", Color(0.85, 0.9, 1.0), true)
		player.stage.fx.flash_light(a.pos, 0.6, Color(0.8, 0.85, 1.0), 2.5, 4.0, 0.25)


# --- Duelist's Sabre ------------------------------------------------------------------

func _thrust() -> void:
	var finisher := combo == 3
	var p := player.pos
	var dmg := float(strike.dmg)
	var rng := float(strike.range)
	var opts := {"finisher": finisher}
	if riposte:
		# the riposte: a flash of a lunge, always true
		riposte = false
		player.push += aim_dir * 6.5
		rng += 1.4
		dmg *= 2.2
		opts["crit"] = true
		player.stage.fx.flash_light(p, 0.8, Color(1.0, 0.95, 0.75), 2.5, 4.0, 0.2)
		player.stage.fx.ghost(player.sprite, player.global_position + player.sprite.position, Color(1.0, 0.9, 0.6), 0.25)
		Audio.play("riposte", -1.0)
	else:
		player.push += aim_dir * float(strike.lunge)
	var tip := p + aim_dir * rng
	player.stage.fx.shape(Fx.Shape.RECT, p, aim_dir, Vector2(rng, 0.35), Color(1.0, 0.92, 0.7, 0.0), Color(1.0, 0.97, 0.85, 1.0), 0.07, {"progress": 1.0, "glow": 1.8})
	player.stage.fx.burst(tip, 0.6, Color(1.0, 0.9, 0.65), 4, 5.0, 0.15, 0.0, aim_dir, 0.25)
	Audio.play("thrust", -3.0, randf_range(1.1, 1.25))
	var hits := line_hit(p, tip, float(strike.width), dmg, ["melee"], strike.kb, strike.poise, opts)
	if hits > 0:
		player.stage.hitstop(0.035 if not finisher and not opts.has("crit") else 0.07)
		player.stage.fx.shake(0.08 if not finisher else 0.18)
	player.on_weapon_strike(hits, finisher)


func on_evade() -> void:
	if form == "duelist" and not riposte:
		riposte = true
		if visual:
			visual.set_instance_shader_parameter("flash", Color(1.0, 0.95, 0.7, 0.9))
		player.stage.fx.number(player.pos, 2.4, "RIPOSTE", Color(1.0, 0.92, 0.65))


## En Garde: the raised sabre takes the first blow (not a guardian's slam)
## and answers it at once; a second does not come through the same guard.
func guard_hit(h: Hit, attacker: Node) -> bool:
	if form != "duelist" or phase != Phase.CHARGE or phase_t > GUARD_TIME or _guard_hit or h.unblockable:
		return false
	_guard_hit = true
	player.stage.fx.burst(player.pos + aim_dir * 0.5, 0.8, Color(1.0, 0.9, 0.6), 14, 5.0, 0.25, 0.0, aim_dir, 0.9)
	player.stage.fx.ring(player.pos, 1.2, Color(1.0, 0.9, 0.6), 0.2, 0.2)
	Audio.play("parry", -1.0, 1.15)
	player.stage.hitstop(0.08)
	var foe: Actor = attacker if attacker is Actor and is_instance_valid(attacker) and (attacker as Actor).alive else null
	if foe == null and h.source is Actor and is_instance_valid(h.source):
		foe = h.source as Actor
	_riposte_at(foe)
	return true


func _riposte_at(foe: Actor) -> void:
	held = false
	charged = false
	riposte = true
	if foe and foe.team != player.team and foe.pos.distance_to(player.pos) <= RIPOSTE_RANGE:
		aim_dir = (foe.pos - player.pos).normalized()
		player.aim = aim_dir
	combo = 3
	strike = THRUSTS[3]
	_set_phase(Phase.ACTIVE, float(strike.active) / speed())
	hit_ids.clear()
	_thrust()


func update(dt: float) -> void:
	super.update(dt)
	if form == "duelist":
		if phase == Phase.CHARGE:
			if phase_t > GUARD_TIME and not _guard_hit:
				# the arm drops: a guard held too long is no guard
				held = false
				_set_phase(Phase.IDLE, 0.0)
				player.stage.fx.number(player.pos, 2.0, "GUARD DROPPED", Color(0.75, 0.7, 0.65))
			swing = deg_to_rad(-20.0) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)
		else:
			_guard_hit = false
		if not predicting:
			player.form_meter = 1.0 if riposte else 0.0
		return
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


## Co-op client: the stance of each form's charged attack.
func predict_charge() -> void:
	match form:
		"cleaver":
			charged = false
			aim_dir = player.aim
			strike = {"windup": 0.0, "active": 0.2, "recover": 0.42}
			_set_phase(Phase.ACTIVE, 0.2 / speed())
			player.push += aim_dir * 3.0
			combo = 0
		"duelist":
			charged = false
			aim_dir = player.aim
			strike = THRUSTS[3]
			_set_phase(Phase.ACTIVE, float(strike.active) / speed())
			player.push += aim_dir * 5.0
			combo = 0
		_:
			super.predict_charge()


func release_charge() -> void:
	match form:
		"cleaver":
			charged = false
			aim_dir = player.aim
			_grave_drop()
			return
		"duelist":
			# a guard released unbroken: a flèche, a long lunge that is always true
			charged = false
			aim_dir = player.aim
			riposte = true
			combo = 3
			strike = THRUSTS[3]
			_set_phase(Phase.ACTIVE, float(strike.active) / speed())
			hit_ids.clear()
			_thrust()
			combo = 0
			return
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
	if masterwork():
		_ember_ring(p, r)
	player.on_weapon_strike(hits, true)
	combo = 0


## Masterwork: a ring of embers where the whirl passed; foes in it catch fire.
func _ember_ring(p: Vector2, r: float) -> void:
	var src := player
	var hz := Hazard.spawn(player.stage, p, r, 2.5, Actor.Team.PLAYER, Color(1.0, 0.55, 0.2), func(_h: Hazard, a: Actor) -> void:
		if a.team != Actor.Team.PLAYER and is_instance_valid(src):
			a.status.apply_burn(1, 4.0, 4, src))
	hz.period = 0.5
	hz.particle_rate = 14.0


func base_angle() -> float:
	if phase == Phase.ACTIVE and form == "" and strike.get("active", 0.0) >= 0.2:
		# whirling cut spins the blade a full turn
		return Iso.screen_angle(aim_dir) + phase_t / maxf(phase_len, 0.001) * TAU
	return super.base_angle()
