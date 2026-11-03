## Grave Spider: keeps to the edge of the fight and spits webs that snare
## whoever walks through them; when you come close it rears and lunges.
extends Enemy

const WEB_R := 1.3
var cooldown := 1.2


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate
	match state:
		"idle":
			set_state("stalk")
		"stalk":
			var t := target()
			if t == null:
				vel = Vector2.ZERO
				return
			var d := dist_to_player()
			if cooldown <= 0.0 and d < 2.6:
				aim_dir = dir_to_player()
				facing = aim_dir
				vel = Vector2.ZERO
				set_state("lunge_windup")
				sprite.play("windup")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(3.2, 0.9), 0.4 / attack_rate)
				Audio.play("skitter", -8.0, 0.8)
			elif cooldown <= 0.0 and d < 8.0 and stage.grid.line_clear(pos, t.pos):
				vel = Vector2.ZERO
				facing = dir_to_player()
				set_state("spit_windup")
				sprite.play("windup")
			else:
				kite(3.0, 6.0, speed, dt)
				sprite.play("walk" if vel.length() > 0.3 else "idle")
		"spit_windup":
			vel = Vector2.ZERO
			if timer(0.45):
				sprite.play("spit")
				_spit()
				set_state("recover")
		"lunge_windup":
			vel = Vector2.ZERO
			if timer(0.4):
				set_state("lunge")
				sprite.play("lunge")
				set_meta("bit", false)
		"lunge":
			vel = aim_dir * 11.0
			if not get_meta("bit", false) and target() and dist_to_player() < radius + target().radius + 0.2:
				set_meta("bit", true)
				target().take_enemy_hit(make_hit(damage, pos, 3.0), self)
			if state_t >= 0.24:
				vel = Vector2.ZERO
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			if timer(0.55):
				cooldown = randf_range(1.6, 2.4)
				set_state("stalk")
		_:
			set_state("stalk")


## Globs of web land where the Kindled stands (three from an elite).
func _spit() -> void:
	var t := target()
	if t == null:
		return
	Audio.play("orb", -8.0, 1.6)
	var spots: Array = [t.pos + t.vel * 0.3]
	if elite:
		var side := dir_to_player().orthogonal() * 2.2
		spots.append_array([spots[0] + side, spots[0] - side])
	for at: Vector2 in spots:
		stage.fx.shape(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(WEB_R * 2.0, WEB_R * 2.0), TELE_COLOR, TELE_EDGE, 0.5, {"progress": 0.0})
		var st := stage
		st.after(0.45, func() -> void: _web(st, at))


static func _web(st: Stage, at: Vector2) -> void:
	var hz := Hazard.spawn(st, at, WEB_R, 6.0, Team.ENEMY, Color(0.82, 0.86, 0.92), func(_h: Hazard, a: Actor) -> void:
		if a is Player:
			a.status.apply_snare(0.35))
	hz.period = 0.15
	hz.particle_rate = 2.0
	st.fx.burst(at, 0.1, Color(0.85, 0.9, 0.95), 10, 2.5, 0.4, 4.0)


func hit_color() -> Color:
	return Color(0.9, 0.86, 0.78)
