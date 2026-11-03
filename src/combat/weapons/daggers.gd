## Twin Fangs: a pair of hearth-forged daggers. Four quick cuts, the last a
## crossing double strike; their points find gaps (+15% crit chance). Hold to
## charge Shadowstep: dash through what stands in front of you, cutting
## everything you pass.
extends Weapon

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
	var hits := arc_hit(p, aim_dir, strike.range, deg_to_rad(strike.arc), dmg, ["melee"], strike.kb, strike.poise, {"finisher": finisher, "crit": randf() < CRIT_BONUS})
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


## Shadowstep: the Kindled becomes a streak of shadow and reappears beyond,
## every foe on the way cut. Masterwork: the shadow left behind cuts again.
func release_charge() -> void:
	aim_dir = player.aim
	charged = false
	var from := player.pos
	var to := player.stage.grid.move_box(from, player.box(), aim_dir * STEP, true)
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
	Audio.play("blink", -2.0, 1.1)
	var hits := line_hit(from, to, 0.9, def.charged, ["melee"], 4.0, 24.0, {"finisher": true, "crit": randf() < CRIT_BONUS + 0.2})
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
