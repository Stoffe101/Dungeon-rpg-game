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
## Forms (ItemDB "form"):
##   root (Rootspear) - its thrusts root what they pierce; its sweep drags foes
##     in toward the point; hold to plant it: a ring of thorns that roots
##     whatever walks in.
##   partisan (Warden's Partisan) - hold to Hold the Line: blows and shots from
##     the front are stopped on the shaft, and the point darts at whatever
##     comes into reach (no charged lunge: it does not leave the line).
const ROOT_TIME := 0.8
const LINE_ARC := 0.35        # cosine: how wide "the front" is for the line
const LINE_JAB := 0.45        # seconds between the line's thrusts
const LINE_COST := 4.0        # Kindle each stopped blow costs
var _jab_t := 0.0


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
		var o := {"unblockable": tempered()}
		if form == "root":
			o["each"] = _root
		hits = line_hit(p, tip, float(strike.width), dmg, ["melee"], strike.kb, strike.poise, o)
	else:
		var rev := cos(Iso.screen_angle(aim_dir)) < 0.0
		player.stage.fx.swipe(p, aim_dir, strike.range + 0.15, deg_to_rad(strike.arc + 8.0), Color(1.0, 0.85, 0.5, 0.9), 0.12 / speed(), 0.55, rev)
		Audio.play("swing_heavy", -2.0, 1.15)
		var o2 := {"finisher": true}
		if form == "root":
			# the sweep drags them in toward the point
			var tip2 := p + aim_dir * 1.6
			o2["each"] = func(a: Actor, h: Hit) -> void:
				h.knockback = (tip2 - a.pos) * 3.5
				player.stage.fx.motes(a.pos, 0.6, Color(0.55, 0.8, 0.35), 3, 0.5, 0.4, 0.2)
		hits = arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, o2)
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
	if form == "partisan" and phase == Phase.CHARGE:
		swing = 0.0
		_jab_t -= dt
		if _jab_t <= 0.0 and not predicting:
			_line_jab()
		return
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


func move_mult() -> float:
	if form == "partisan" and phase == Phase.CHARGE:
		return 0.35
	return super.move_mult()


## Rootspear: what the point pierces is held where it stands.
func _root(a: Actor, _h: Hit) -> void:
	if a is Enemy and (a as Enemy).def.get("boss", false):
		a.status.apply_snare(ROOT_TIME)     # a guardian is only slowed
	else:
		a.status.apply_root(ROOT_TIME * (1.5 if player.stats.has("mastery_spear") else 1.0))
	player.stage.fx.burst(a.pos, 0.2, Color(0.5, 0.75, 0.3), 8, 2.0, 0.5, 6.0, Vector2.ZERO, PI, 1.5)
	player.stage.fx.ring(a.pos, 0.7, Color(0.55, 0.85, 0.35), 0.3, 0.2)
	Audio.play_at("root", a.pos, -6.0, randf_range(0.95, 1.1))


## Thornplant: the spear goes into the floor; thorns ring it for four seconds.
func _thornplant() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"windup": 0.0, "active": 0.14, "recover": 0.32}
	_set_phase(Phase.ACTIVE, 0.14)
	var c := player.pos + aim_dir * 0.8
	var r := 2.6 * player.stats.v("area")
	var src := player
	var dmg: float = def.charged * 0.25 * damage_scale()
	var last := {}
	var hz := Hazard.spawn(player.stage, c, r, 4.0, Actor.Team.PLAYER, Color(0.45, 0.75, 0.3), func(hh: Hazard, a: Actor) -> void:
		if a.team == Actor.Team.PLAYER or not is_instance_valid(src):
			return
		var id := a.get_instance_id()
		if float(last.get(id, -99.0)) > hh.stage.elapsed - 2.0:
			return
		last[id] = hh.stage.elapsed
		var h := Combat.player_hit(src, src.stats, dmg, ["melee"])
		h.poise = 15.0
		src.deal_hit(a, h)
		if not (a is Enemy and (a as Enemy).def.get("boss", false)):
			a.status.apply_root(1.2)
		hh.stage.fx.burst(a.pos, 0.2, Color(0.5, 0.75, 0.3), 6, 2.0, 0.4, 6.0))
	hz.period = 0.25
	hz.particle_rate = 18.0
	player.stage.fx.ring(c, r, Color(0.55, 0.85, 0.35), 0.35, 0.3)
	player.stage.fx.burst(c, 0.1, Color(0.45, 0.65, 0.3), 24, 4.0, 0.6, 6.0, Vector2.ZERO, PI, 2.0)
	Audio.play("thornplant", -1.0)
	player.on_weapon_strike(0, true)
	combo = 0


## Warden's Partisan: the line holds what comes at it from the front.
func guard_hit(h: Hit, _attacker: Node) -> bool:
	if form != "partisan" or phase != Phase.CHARGE or h.unblockable:
		return false
	if h.from_dir.length() > 0.01 and h.from_dir.normalized().dot(aim_dir) > -LINE_ARC:
		return false     # from the side or behind: the line does not cover it
	if player.kindle < LINE_COST:
		# nothing left to hold it with: the line breaks and the blow comes through
		held = false
		_set_phase(Phase.IDLE, 0.0)
		player.stage.fx.number(player.pos, 2.2, "LINE BROKEN", Color(0.8, 0.75, 0.7))
		return false
	player.kindle -= LINE_COST
	var at := player.pos + aim_dir * 0.6
	player.stage.fx.burst(at, 0.8, Color(0.8, 0.95, 1.0), 10, 4.0, 0.2, 0.0, -h.from_dir, 0.8)
	player.stage.fx.ring(at, 0.6, Color(0.75, 0.95, 0.95), 0.15, 0.2)
	Audio.play("block", -2.0, randf_range(0.95, 1.08))
	player.stage.hitstop(0.03)
	player.push -= aim_dir * 1.2
	return true


## The point darts at the nearest foe in front, within reach.
func _line_jab() -> void:
	var best: Actor = null
	var bd := 3.1
	for a in player.stage.hostiles(player.team):
		var d := a.pos.distance_to(player.pos)
		if a.targetable and d < bd and (a.pos - player.pos).normalized().dot(player.aim) > 0.5:
			bd = d
			best = a
	if best == null:
		return
	_jab_t = LINE_JAB / speed()
	aim_dir = player.aim
	var tip := player.pos + aim_dir * 3.1
	hit_ids.clear()
	player.stage.fx.shape(Fx.Shape.RECT, player.pos, aim_dir, Vector2(3.1, 0.45), Color(0.8, 0.95, 1.0, 0.0), Color(0.9, 1.0, 1.0, 1.0), 0.08, {"progress": 1.0, "glow": 1.5})
	Audio.play("thrust", -5.0, 1.2)
	var hits := line_hit(player.pos, tip, 0.6, float(def.damage[0]) * 0.8, ["melee"], 3.0, 10.0, {})
	player.on_weapon_strike(hits, false)


## The lunge is movement: a predicting client makes it too (the host strikes).
func predict_charge() -> void:
	if form in ["root", "partisan"]:
		charged = false
		aim_dir = player.aim
		strike = {"windup": 0.0, "active": 0.14, "recover": 0.32}
		_set_phase(Phase.ACTIVE if form == "root" else Phase.IDLE, 0.14)
		combo = 0
		return
	aim_dir = player.aim
	charged = false
	var from := player.pos
	var to := player.stage.grid.move_box(from, player.box(), aim_dir * LUNGE, true)
	strike = {"windup": 0.0, "active": 0.14, "recover": 0.3, "thrust": true}
	_set_phase(Phase.ACTIVE, 0.14)
	for i in 4:
		player.stage.fx.ghost(player.sprite, Iso.to_world(from.lerp(to, i / 3.0), 0.0), Color(1.0, 0.75, 0.35), 0.2 + i * 0.04)
	player.pos = to
	Audio.play("rush", -2.0, 1.1)
	combo = 0


## Comet Lunge: point-first through the line, then a burst of sunfire.
func release_charge() -> void:
	match form:
		"root":
			_thornplant()
			return
		"partisan":
			# the line is let go: no lunge
			charged = false
			_set_phase(Phase.IDLE, 0.0)
			return
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
	player.cosmetic(func() -> void: Audio.play("rush", -2.0, 1.1))
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
	if form == "sunfall":
		_sunfall(to)
	player.on_weapon_strike(hits, true)
	combo = 0


## Sunfall Glaive: where the Comet Lunge lands, a falling sun follows it down.
func _sunfall(at: Vector2) -> void:
	player.set_meta("legend_moments", int(player.get_meta("legend_moments", 0)) + 1)
	var st := player.stage
	var col := Color(1.0, 0.8, 0.4)
	var r := 3.2 * player.stats.v("area") * (1.25 if player.stats.has("mastery_spear") else 1.0)
	st.fx.shape(Fx.Shape.SIGIL, at, Vector2.RIGHT, Vector2(r * 2.0, r * 2.0), Color(1.0, 0.7, 0.3, 0.25), Color(1.0, 0.9, 0.55, 1.0), 0.45, {"glow": 1.8})
	var pl := player
	var dmg: float = def.charged * 0.9 * damage_scale()
	st.after(0.4, func() -> void:
		if not is_instance_valid(pl):
			return
		st.fx.ring(at, r, col, 0.4, 0.45)
		st.fx.ring(at, r * 0.5, Color(1.0, 0.95, 0.75), 0.25, 0.3)
		st.fx.burst(at, 0.3, col, 46, 9.0, 0.6, 3.0)
		st.fx.flash_light(at, 1.2, col, 6.0, 10.0, 0.6)
		st.fx.shake(0.5)
		Audio.play("boss_arrive", -4.0, 1.4)
		st.strike_props_circle(at, r, pl, true)
		for a in st.in_circle(pl.team, at, r):
			var h := Combat.player_hit(pl, pl.stats, dmg, ["melee", "fire"])
			h.burn = 2
			h.knockback = (a.pos - at).normalized() * 10.0
			h.poise = 50.0
			pl.deal_hit(a, h, true))
