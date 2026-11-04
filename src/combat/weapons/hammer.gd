## Cinderhammer: a slow, crushing two-strike combo (sweep, overhead slam with
## shockwave). Breaks guards. Hold to leap toward the cursor and quake the ground.
## Forms (ItemDB "form"):
##   tomb (Tombmaul) - the ground remembers every blow: a slam's shockwave comes
##     again twice, wider; hold for Tombfall: plant the maul and send four
##     quakes rolling outward instead of leaping.
##   forge (Emberforge Mallet) - every blow that lands heats it; hot, its blows
##     throw molten sparks; hold to vent the heat in a fire nova as big as the
##     heat was (and leap only when it is cold).
extends Weapon

const HEAT_PER_HIT := 14.0
const HEAT_SPARKS := 60.0     # from here its blows throw sparks
var heat := 0.0
var _heat_idle := 0.0
var _tombfall := -1.0         # time into a Tombfall (-1: none)
var _tomb_hit := {}           # foe -> quakes it has taken

const STRIKES := [
	{"windup": 0.2, "active": 0.09, "recover": 0.3, "arc": 80.0, "range": 2.35, "kb": 8.0, "poise": 32.0, "lunge": 2.5, "from": 95.0, "to": -80.0},
	{"windup": 0.26, "active": 0.1, "recover": 0.42, "arc": 0.0, "range": 1.5, "kb": 10.0, "poise": 55.0, "lunge": 3.0, "from": 150.0, "to": -20.0, "slam": true},
]

var leaping := false
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO


func _init() -> void:
	charge_time = 0.6


func max_combo() -> int:
	return 2


func move_mult() -> float:
	if leaping or _tombfall >= 0.0:
		return 0.0
	match phase:
		Phase.WINDUP, Phase.ACTIVE:
			return 0.15
		Phase.RECOVER:
			return 0.5
		Phase.CHARGE:
			return 0.4
	return 1.0


func start_strike(index: int) -> void:
	strike = STRIKES[index]
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, strike.windup / speed())
	player.on_attack_start()


func on_active() -> void:
	var p := player.pos
	player.push += aim_dir * float(strike.lunge)
	var dmg: float = def.damage[combo]
	var hits := 0
	if strike.get("slam", false):
		var c := p + aim_dir * 1.4
		Audio.play("slam", 0.0)
		player.stage.fx.ring(c, 1.6, Color(1.0, 0.7, 0.35), 0.18, 0.4)
		player.stage.fx.burst(c, 0.1, Color(0.75, 0.68, 0.6), 16, 5.0, 0.5, 9.0, Vector2.ZERO, PI, 3.0)
		player.stage.fx.burst(c, 0.1, Color(1.0, 0.6, 0.25), 10, 4.0, 0.4, 4.0)
		for a in player.stage.in_circle(player.team, c, 1.5):
			hits += _smash(a, dmg, c)
		var wave_r := 3.0 * (1.3 if tempered() else 1.0) * player.stats.v("area")
		player.stage.fx.ring(c, wave_r, Color(1.0, 0.85, 0.55), 0.35, 0.12)
		for a in player.stage.in_circle(player.team, c, wave_r):
			if not hit_ids.has(a.get_instance_id()):
				hits += _smash(a, dmg * 0.4, c)
		player.stage.fx.shake(0.4)
		player.stage.hitstop(0.09 if hits > 0 else 0.03)
		if masterwork():
			_burning_cracks(c)
		if form == "tomb":
			_aftershocks(c, wave_r, dmg)
	else:
		Audio.play("swing_heavy", 0.0)
		var rev := cos(Iso.screen_angle(aim_dir)) < 0.0
		player.stage.fx.swipe(p, aim_dir, strike.range + 0.15, deg_to_rad(strike.arc + 10.0), Color(1.0, 0.75, 0.45, 0.95), 0.12, 0.3, rev)
		hits = arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, {"unblockable": true})
		if hits > 0:
			player.stage.hitstop(0.07)
			player.stage.fx.shake(0.25)
		if form == "tomb":
			# the end of the sweep strikes the ground too
			var e := p + aim_dir * 1.8
			player.stage.fx.ring(e, 1.4, Color(0.8, 0.75, 0.7), 0.25, 0.18)
			player.stage.fx.burst(e, 0.1, Color(0.7, 0.66, 0.6), 8, 3.5, 0.45, 8.0, Vector2.ZERO, PI, 2.5)
			for a in player.stage.in_circle(player.team, e, 1.4):
				hits += _smash(a, dmg * 0.35, e)
	if form == "forge":
		_heat_up(hits, p)
	player.on_weapon_strike(hits, combo == 1)


## Tombmaul: the shockwave comes back twice, each time wider and weaker.
func _aftershocks(c: Vector2, r: float, dmg: float) -> void:
	var st := player.stage
	var me: WeakRef = weakref(self)
	for k in (3 if player.stats.has("mastery_hammer") else 2):
		var rr := r * (1.3 + 0.35 * k)
		var pitch := 1.0 - 0.08 * k
		st.after(0.32 * (k + 1), func() -> void:
			var w = me.get_ref()
			if w == null or w.player == null or not is_instance_valid(w.player):
				return
			st.fx.ring(c, rr, Color(0.85, 0.8, 0.72), 0.35, 0.16)
			st.fx.burst(c, 0.1, Color(0.66, 0.62, 0.58), 10, rr * 1.4, 0.5, 6.0, Vector2.ZERO, PI, 2.0)
			st.fx.shake(0.18)
			Audio.play_at("aftershock", c, -3.0, pitch)
			w.hit_ids.clear()
			for a in st.in_circle(w.player.team, c, rr):
				w._smash(a, dmg * 0.35, c))


## Emberforge Mallet: blows that land heat it; hot, they throw molten sparks.
func _heat_up(hits: int, p: Vector2) -> void:
	if hits > 0:
		var forged := 2.0 if player.hearthfire_t > 0.0 and player.stats.has("hearthforged") else 1.0
		if player.stats.has("mastery_hammer"):
			forged *= 1.5     # Earthshaker: the Mallet heats half as fast again
		heat = minf(100.0, heat + HEAT_PER_HIT * hits * forged)
		_heat_idle = 0.0
	if heat >= HEAT_SPARKS:
		var dmg: float = float(def.damage[0]) * 0.3
		for k in 3:
			var d := aim_dir.rotated(deg_to_rad(-18.0 + 18.0 * k))
			var pr := shoot("proj_spark", p + d * 0.7, d, 13.0, dmg, ["melee", "fire"], 0.45)
			pr.burn = 1
			pr.radius = 0.25
			pr.trail_color = Color(1.0, 0.6, 0.2)
			pr.trail_rate = 30.0
			pr.with_light(Color(1.0, 0.55, 0.2), 0.6, 2.0)
		Audio.play("sparks", -6.0, randf_range(0.95, 1.1))


## Vent: the heat goes out of it all at once - a nova as big as it was hot.
func _vent() -> void:
	var c := player.pos
	var k := heat / 100.0
	var r := (1.8 + 2.4 * k) * player.stats.v("area")
	strike = {"windup": 0.0, "active": 0.2, "recover": 0.4}
	_set_phase(Phase.ACTIVE, 0.2 / speed())
	hit_ids.clear()
	var col := Color(1.0, 0.55, 0.2)
	player.stage.fx.ring(c, r, col, 0.35, 0.4)
	player.stage.fx.ring(c, r * 0.6, Color(1.0, 0.85, 0.5), 0.25, 0.25)
	player.stage.fx.burst(c, 0.3, col, int(20 + 30 * k), 6.0 + 4.0 * k, 0.5, 2.0)
	player.stage.fx.flash_light(c, 0.8, col, 3.0 + 3.0 * k, r * 2.0, 0.4)
	player.stage.fx.shake(0.25 + 0.3 * k)
	Audio.play("vent", 0.0, 1.1 - 0.2 * k)
	player.stage.strike_props_circle(c, r, player, true)
	var hits := 0
	for a in player.stage.in_circle(player.team, c, r):
		var h := Combat.player_hit(player, player.stats, def.charged * (0.5 + k) * damage_scale(), ["melee", "fire"])
		h.burn = 2 + int(2.0 * k)
		h.knockback = (a.pos - c).normalized() * 9.0
		h.from_dir = (a.pos - c).normalized()
		h.poise = 50.0
		player.deal_hit(a, h, true)
		hits += 1
	player.stage.hitstop(0.1 if hits > 0 else 0.03)
	heat = 0.0
	combo = 0
	player.on_weapon_strike(hits, true)


## Tombfall: planted, four quakes roll outward, one after another.
func _tombfall_step(dt: float) -> void:
	var before := _tombfall
	_tombfall += dt
	for q in 4:
		var at := 0.3 * q
		if before < at and _tombfall >= at:
			var r := (1.4 + 1.15 * q) * player.stats.v("area")
			var c := player.pos
			player.stage.fx.ring(c, r, Color(0.86, 0.8, 0.72), 0.3, 0.22)
			player.stage.fx.burst(c + Vector2.from_angle(randf() * TAU) * r * 0.7, 0.1, Color(0.68, 0.64, 0.6), 14, 4.0, 0.5, 8.0, Vector2.ZERO, PI, 2.5)
			player.stage.fx.shake(0.2 + 0.06 * q)
			Audio.play("aftershock", -1.0 + q, 1.05 - 0.06 * q)
			if not predicting:
				player.stage.strike_props_circle(c, r, player, false)
				for a in player.stage.in_circle(player.team, c, r):
					var n := int(_tomb_hit.get(a.get_instance_id(), 0))
					if n >= 2 or a.pos.distance_to(c) < r - 1.6:
						continue
					_tomb_hit[a.get_instance_id()] = n + 1
					hit_ids.erase(a.get_instance_id())
					_smash(a, def.charged * 0.45, c)
	if _tombfall >= 1.15:
		_tombfall = -1.0
		_set_phase(Phase.RECOVER, 0.35 / speed())
		combo = 0
		if not predicting:
			player.on_weapon_strike(_tomb_hit.size(), true)


## Masterwork: the slam leaves the ground cracked and burning.
func _burning_cracks(c: Vector2) -> void:
	var src := player
	player.stage.fx.splat(c, Color(0.2, 0.08, 0.04), 8.0, 1.4)
	var hz := Hazard.spawn(player.stage, c, 1.6, 3.0, Actor.Team.PLAYER, Color(1.0, 0.5, 0.18), func(_h: Hazard, a: Actor) -> void:
		if a.team != Actor.Team.PLAYER and is_instance_valid(src):
			a.status.apply_burn(1, 5.0, 5, src))
	hz.period = 0.5
	hz.particle_rate = 16.0


func _smash(a: Actor, dmg: float, c: Vector2) -> int:
	if hit_ids.has(a.get_instance_id()):
		return 0
	hit_ids[a.get_instance_id()] = true
	var h := Combat.player_hit(player, player.stats, dmg * damage_scale(), ["melee"])
	h.knockback = (a.pos - c).normalized() * 9.0 * player.stats.v("knockback")
	h.from_dir = (a.pos - c).normalized()
	h.poise = 50.0 * player.stats.v("poise_damage")
	h.unblockable = true
	player.deal_hit(a, h, true)
	return 1


func update(dt: float) -> void:
	if form == "forge":
		_heat_idle += dt
		if _heat_idle > 2.0:
			heat = maxf(0.0, heat - 8.0 * dt)
		if visual:
			# the hotter, the brighter it glows
			visual.set_instance_shader_parameter("glow_mult", _base_glow + heat / 100.0 * 2.2)
			if heat >= HEAT_SPARKS and randf() < dt * 10.0:
				player.cosmetic(func() -> void:
					player.stage.fx.motes(player.pos + Vector2(randf_range(-0.3, 0.3), 0), 0.9, Color(1.0, 0.6, 0.2), 1, 1.0, 0.4, 0.1))
		if not predicting:
			player.form_meter = heat / 100.0
	if _tombfall >= 0.0:
		_tombfall_step(dt)
		update_visual(dt)
		return
	if leaping:
		phase_t += dt
		var k := clampf(phase_t / 0.38, 0.0, 1.0)
		var target := leap_from.lerp(leap_to, k)
		player.pos = player.stage.grid.move_box(player.pos, player.box(), target - player.pos)
		player.height = sin(k * PI) * 1.6
		if k >= 1.0:
			leaping = false
			player.height = 0.0
			_land()
		update_visual(dt)
		return
	super.update(dt)
	var sgn := 1.0 if cos(Iso.screen_angle(aim_dir)) >= 0.0 else -1.0
	if strike.has("from"):
		match phase:
			Phase.WINDUP:
				swing = deg_to_rad(strike.from) * sgn
			Phase.ACTIVE:
				var k := clampf(phase_t / maxf(phase_len, 0.001), 0.0, 1.0)
				swing = lerpf(deg_to_rad(strike.from), deg_to_rad(strike.to), 1.0 - pow(1.0 - k, 4.0)) * sgn
			Phase.RECOVER:
				swing = deg_to_rad(strike.to) * sgn


func release_charge() -> void:
	if form == "tomb":
		_plant()
		return
	if form == "forge" and heat >= 30.0:
		charged = false
		aim_dir = player.aim
		_vent()
		return
	charged = false
	aim_dir = player.aim
	leap_from = player.pos
	var dist := minf(player.pos.distance_to(player.aim_point), 4.5)
	leap_to = player.pos + aim_dir * dist
	leaping = true
	phase = Phase.ACTIVE
	phase_t = 0.0
	strike = {"active": 0.4, "recover": 0.35}
	player.invuln_t = maxf(player.invuln_t, 0.42)
	player.cosmetic(func() -> void: Audio.play("leap", 0.0))


## Tombfall: the maul goes into the ground where the Kindled stands.
func _plant() -> void:
	charged = false
	aim_dir = player.aim
	_tombfall = 0.0
	_tomb_hit.clear()
	phase = Phase.ACTIVE
	phase_t = 0.0
	strike = {"active": 1.2, "recover": 0.35}
	player.stage.fx.splat(player.pos, Color(0.12, 0.1, 0.1), 14.0, 1.6)
	Audio.play("slam", 1.0, 0.85)


## The leap is movement: a predicting client makes it too (the host lands the blow).
func predict_charge() -> void:
	if form == "forge" and player.form_meter * 100.0 >= 30.0:
		charged = false
		aim_dir = player.aim
		strike = {"windup": 0.0, "active": 0.2, "recover": 0.4}
		_set_phase(Phase.ACTIVE, 0.2 / speed())
		combo = 0
		return
	release_charge()


func _land() -> void:
	if predicting:
		_set_phase(Phase.RECOVER, 0.35 / speed())
		combo = 0
		return
	var c := player.pos
	var r := 2.7 * player.stats.v("area")
	hit_ids.clear()
	Audio.play("slam", 2.0)
	player.stage.fx.ring(c, r, Color(1.0, 0.65, 0.3), 0.3, 0.25)
	player.stage.fx.ring(c, r * 1.4, Color(1.0, 0.85, 0.5), 0.45, 0.08)
	player.stage.fx.burst(c, 0.1, Color(0.7, 0.62, 0.55), 26, 7.0, 0.6, 9.0, Vector2.ZERO, PI, 3.0)
	player.stage.fx.burst(c, 0.1, Color(1.0, 0.6, 0.25), 18, 5.0, 0.5, 3.0)
	player.stage.fx.flash_light(c, 0.5, Color(1.0, 0.6, 0.3), 4.0, 6.0, 0.3)
	var hits := 0
	player.stage.strike_props_circle(c, r, player, player.stats.has("living_pyre"))
	for a in player.stage.in_circle(player.team, c, r):
		hits += _smash(a, def.charged, c)
	player.stage.fx.shake(0.6)
	player.stage.hitstop(0.1)
	_set_phase(Phase.RECOVER, 0.35 / speed())
	combo = 0
	player.on_weapon_strike(hits, true)


func cancel() -> void:
	if leaping or _tombfall >= 0.0:
		return
	super.cancel()


func is_busy() -> bool:
	return leaping or _tombfall >= 0.0 or super.is_busy()
