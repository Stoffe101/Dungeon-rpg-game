## Twin Fangs: a pair of hearth-forged daggers. Four quick cuts, the last a
## crossing double strike; their points find gaps (+15% crit chance). Hold to
## charge Shadowstep: dash through what stands in front of you, cutting
## everything you pass.
## Forms (ItemDB "form"):
##   kris (Gloam Kris) - every cut leaves a gloam mark on the foe (up to five);
##     the crossing cut, or a Shadowstep that ends behind the most-marked foe,
##     tears the marks open (shadow damage for each, Kindle for you).
##   shivs (Ember Shivs) - the second and fourth cuts also throw a burning shiv;
##     hold to throw a fan of seven that leave small fires where they fall.
extends Weapon

const MARKS_MAX := 5
const MARK_DAMAGE := 5.0      # per mark torn open


## Night's Tally (Hearthtree): a Kris foe holds seven marks, a fan has nine shivs.
func marks_max() -> int:
	return MARKS_MAX + (2 if player and player.stats and player.stats.has("mastery_daggers") else 0)

const CRIT_BONUS := 0.15
const STRIKES := [
	{"windup": 0.04, "active": 0.05, "recover": 0.11, "arc": 55.0, "range": 1.6, "kb": 2.0, "poise": 6.0, "lunge": 1.6, "from": 60.0, "to": -60.0},
	{"windup": 0.04, "active": 0.05, "recover": 0.11, "arc": 55.0, "range": 1.6, "kb": 2.0, "poise": 6.0, "lunge": 1.6, "from": -60.0, "to": 60.0},
	{"windup": 0.04, "active": 0.05, "recover": 0.11, "arc": 55.0, "range": 1.6, "kb": 2.0, "poise": 6.0, "lunge": 1.8, "from": 70.0, "to": -50.0},
	{"windup": 0.08, "active": 0.07, "recover": 0.22, "arc": 70.0, "range": 1.8, "kb": 5.0, "poise": 16.0, "lunge": 3.0, "from": -80.0, "to": 80.0},
]
const STEP := 4.6


func max_combo() -> int:
	return 4


func start_strike(index: int) -> void:
	strike = STRIKES[index]
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, strike.windup / speed())
	swing = deg_to_rad(strike.from) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)
	player.on_attack_start()


func on_active() -> void:
	var finisher := combo == 3
	var dmg: float = def.damage[combo]
	var p := player.pos
	player.push += aim_dir * float(strike.lunge)
	var rev: bool = strike.from < 0.0
	if cos(Iso.screen_angle(aim_dir)) < 0.0:
		rev = not rev
	player.stage.fx.swipe(p, aim_dir, strike.range + 0.1, deg_to_rad(strike.arc + 6.0), Color(0.92, 0.9, 1.0, 0.85), 0.07 / speed(), 0.5, rev)
	Audio.play("swing", -4.0, randf_range(1.25, 1.4))
	var opts := {"finisher": finisher, "crit": randf() < CRIT_BONUS}
	var struck: Array = []
	if form == "kris":
		opts["each"] = func(a: Actor, _h: Hit) -> void:
			struck.append(a)
			_mark(a)
	var hits := arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, opts)
	if form == "shivs" and combo % 2 == 1:
		_shiv(p, aim_dir, dmg * 0.7)
	if finisher and form == "kris":
		for a in struck:
			_tear(a)
	if finisher:
		# the crossing cut: the second fang follows the first
		player.stage.fx.swipe(p, aim_dir, strike.range + 0.1, deg_to_rad(strike.arc + 6.0), Color(1.0, 0.8, 0.5, 0.85), 0.09 / speed(), 0.5, not rev)
		hit_ids.clear()
		var k := 0.9 if tempered() else 0.5
		hits += arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg * k, ["melee"], strike.kb, strike.poise, {"finisher": true, "crit": randf() < CRIT_BONUS})
	if hits > 0:
		player.stage.hitstop(0.035 if not finisher else 0.07)
		player.stage.fx.shake(0.08 if not finisher else 0.2)
	player.on_weapon_strike(hits, finisher)


func update(dt: float) -> void:
	super.update(dt)
	if phase == Phase.WINDUP and strike.has("from"):
		swing = deg_to_rad(strike.from) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)
	elif phase == Phase.ACTIVE and strike.has("from"):
		var k := clampf(phase_t / maxf(phase_len, 0.001), 0.0, 1.0)
		var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
		swing = lerpf(deg_to_rad(strike.from), deg_to_rad(strike.to), 1.0 - pow(1.0 - k, 3.0)) * sgn
	elif phase == Phase.RECOVER and strike.has("from"):
		swing = deg_to_rad(strike.to) * (1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0)


## The step is movement: a predicting client makes it too (the host cuts).
func predict_charge() -> void:
	if form == "shivs":
		charged = false
		aim_dir = player.aim
		strike = {"windup": 0.0, "active": 0.1, "recover": 0.28}
		_set_phase(Phase.ACTIVE, 0.1 / speed())
		combo = 0
		return
	aim_dir = player.aim
	charged = false
	var from := player.pos
	var to := player.stage.grid.move_box(from, player.box(), aim_dir * STEP, true)
	strike = {"windup": 0.0, "active": 0.12, "recover": 0.22}
	_set_phase(Phase.ACTIVE, 0.12)
	for i in 5:
		player.stage.fx.ghost(player.sprite, Iso.to_world(from.lerp(to, i / 4.0), 0.0), Color(0.55, 0.4, 0.9), 0.25 + i * 0.04)
	player.pos = to
	Audio.play("blink", -2.0, 1.1)
	combo = 0


## Shadowstep: the Kindled becomes a streak of shadow and reappears beyond,
## every foe on the way cut. Masterwork: the shadow left behind cuts again.
## (Gloam Kris: it ends just behind the most-marked foe in reach.)
var _step_target: Actor = null


func release_charge() -> void:
	if form == "shivs":
		_shiv_fan()
		return
	aim_dir = player.aim
	charged = false
	var from := player.pos
	var to := player.stage.grid.move_box(from, player.box(), aim_dir * STEP, true)
	if form == "kris":
		_step_target = _most_marked(from)
		if _step_target:
			aim_dir = (_step_target.pos - from).normalized()
			to = player.stage.grid.move_box(from, player.box(), (_step_target.pos + aim_dir * 1.1) - from, true)
	strike = {"windup": 0.0, "active": 0.12, "recover": 0.22}
	_set_phase(Phase.ACTIVE, 0.12)
	hit_ids.clear()
	player.invuln_t = maxf(player.invuln_t, 0.3)
	for i in 5:
		var at: Vector2 = from.lerp(to, i / 4.0)
		player.stage.fx.ghost(player.sprite, Iso.to_world(at, 0.0), Color(0.55, 0.4, 0.9), 0.25 + i * 0.04)
	player.pos = to
	player.stage.fx.burst(to, 0.6, Color(0.6, 0.45, 0.95), 14, 4.0, 0.4, 2.0)
	player.stage.fx.shape(Fx.Shape.RECT, from, aim_dir, Vector2(from.distance_to(to), 0.8), Color(0.6, 0.45, 0.95, 0.0), Color(0.8, 0.7, 1.0, 1.0), 0.14, {"progress": 1.0, "glow": 1.4})
	player.cosmetic(func() -> void: Audio.play("blink", -2.0, 1.1))
	var hits := line_hit(from, to, 0.9, def.charged, ["melee"], 4.0, 24.0, {"finisher": true, "crit": randf() < CRIT_BONUS + 0.2})
	if form == "kris" and _step_target and is_instance_valid(_step_target) and _step_target.alive:
		_tear(_step_target)
	_step_target = null
	if hits > 0:
		player.stage.hitstop(0.07)
		player.stage.fx.shake(0.2)
	if masterwork():
		var st := player.stage
		var me: WeakRef = weakref(self)
		st.after(0.35, func() -> void:
			var w = me.get_ref()
			if w == null or w.player == null or not is_instance_valid(w.player):
				return
			w.hit_ids.clear()
			st.fx.shape(Fx.Shape.RECT, from, (to - from).normalized(), Vector2(from.distance_to(to), 0.8), Color(0.6, 0.45, 0.95, 0.0), Color(0.8, 0.7, 1.0, 1.0), 0.14, {"progress": 1.0, "glow": 1.4})
			Audio.play("blink", -6.0, 1.3)
			w.line_hit(from, to, 0.9, w.def.charged * 0.6, ["melee"], 3.0, 12.0, {}))
	player.on_weapon_strike(hits, true)
	combo = 0


# --- Gloam Kris ---------------------------------------------------------------------

func _mark(a: Actor) -> void:
	var add := 2 if player.hearthfire_t > 0.0 and player.stats.has("hearthforged") else 1
	var n := mini(marks_max(), int(a.get_meta("gloam_marks", 0)) + add)
	a.set_meta("gloam_marks", n)
	a.set_meta("gloam_mark_t", player.stage.elapsed)
	player.stage.fx.motes(a.pos, 1.4, Color(0.7, 0.45, 1.0), n, 0.5, 0.5, 0.25)
	if not predicting:
		player.form_meter = float(n) / marks_max()


## The marks on a foe torn open at once: shadow for each, Kindle for you.
func _tear(a: Actor) -> void:
	var n := int(a.get_meta("gloam_marks", 0))
	if float(a.get_meta("gloam_mark_t", -99.0)) < player.stage.elapsed - 6.0:
		n = 0     # old marks fade
	a.set_meta("gloam_marks", 0)
	if n <= 0 or not a.alive:
		return
	var h := Combat.player_hit(player, player.stats, MARK_DAMAGE * n * damage_scale(), ["melee", "shadow"])
	h.poise = 6.0 * n
	h.from_dir = (a.pos - player.pos).normalized()
	player.deal_hit(a, h, true)
	player.gain_kindle(3.0 * n)
	var col := Color(0.72, 0.45, 1.0)
	player.stage.fx.burst(a.pos, 1.0, col, 6 + 4 * n, 3.0 + n, 0.35, 0.0)
	player.stage.fx.ring(a.pos, 0.5 + 0.25 * n, col, 0.25, 0.2)
	player.stage.fx.number(a.pos, 2.4, "%d MARKS" % n, col.lightened(0.3), n >= marks_max())
	Audio.play_at("gloam_tear", a.pos, -3.0 + n * 0.6, 1.15 - 0.05 * n)
	player.form_meter = 0.0


func _most_marked(from: Vector2) -> Actor:
	var best: Actor = null
	var bn := 0
	for a in player.stage.hostiles(player.team):
		if not a.targetable or a.pos.distance_to(from) > STEP + 1.5:
			continue
		var n := int(a.get_meta("gloam_marks", 0))
		if n > bn and player.stage.grid.line_clear(from, a.pos):
			bn = n
			best = a
	return best


# --- Ember Shivs --------------------------------------------------------------------

func _shiv(p: Vector2, d: Vector2, dmg: float) -> Projectile:
	var pr := shoot("proj_shiv", p + d * 0.5, d, 19.0 * player.stats.v("projectile_speed"), dmg, ["melee", "ranged", "fire"], 0.5)
	pr.burn = 1
	pr.radius = 0.22
	pr.spin = true
	pr.knockback = 1.5
	pr.trail_color = Color(1.0, 0.55, 0.25)
	pr.trail_rate = 26.0
	Audio.play("shiv", -6.0, randf_range(0.95, 1.1))
	return pr


## A fan of seven shivs; where they come down, small fires.
func _shiv_fan() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"windup": 0.0, "active": 0.1, "recover": 0.28}
	_set_phase(Phase.ACTIVE, 0.1 / speed())
	var st := player.stage
	var src := player
	for k in (9 if player.stats.has("mastery_daggers") else 7):
		var d := aim_dir.rotated(deg_to_rad(-54.0 + 18.0 * k))
		var pr := _shiv(player.pos, d, def.charged * 0.4)
		pr.life = 0.42
		pr.on_end_fn = func(_proj: Projectile, at: Vector2) -> void:
			var hz := Hazard.spawn(st, at, 0.7, 2.2, Actor.Team.PLAYER, Color(1.0, 0.5, 0.2), func(_h: Hazard, a: Actor) -> void:
				if a.team != Actor.Team.PLAYER and is_instance_valid(src):
					a.status.apply_burn(1, 4.0, 4, src))
			hz.period = 0.5
			hz.particle_rate = 10.0
	st.fx.burst(player.pos + aim_dir * 0.5, 0.7, Color(1.0, 0.6, 0.3), 12, 4.0, 0.25, 0.0, aim_dir, 1.0)
	Audio.play("knives", -2.0, 0.85)
	player.on_weapon_strike(0, true)
	combo = 0
