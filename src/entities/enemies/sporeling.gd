## Sporeling: a hopping mushroom. Short telegraphed bite; when it dies it
## bursts into a lingering spore cloud - don't finish it point-blank.
extends Enemy


func behave(dt: float) -> void:
	match state:
		"idle":
			set_state("chase")
		"chase":
			chase(speed, dt)
			sprite.play("walk")
			bob = absf(sin(stage.elapsed * 10.0 + pos.x)) * 0.15
			if dist_to_player() < 1.3:
				aim_dir = dir_to_player()
				facing = aim_dir
				vel = Vector2.ZERO
				bob = 0.0
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(2.6, 2.6), 0.4 / attack_rate, {"half_angle": deg_to_rad(45.0)})
		"windup":
			vel = Vector2.ZERO
			if timer(0.4):
				sprite.play("attack")
				push += aim_dir * 4.0
				strike_arc(pos, aim_dir, 1.3, deg_to_rad(45.0), damage, 3.0)
				Audio.play("claw", -8.0, 1.4)
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			if timer(0.55):
				set_state("chase")
		_:
			set_state("chase")


func die(killer: Node) -> void:
	if not alive:
		return
	_cloud(stage, pos)
	super.die(killer)


## Static so the cloud outlives the sporeling.
static func _cloud(st: Stage, p: Vector2) -> void:
	Audio.play("bloat", -8.0, 1.6)
	st.fx.burst(p, 0.4, Color(0.6, 0.9, 0.35), 18, 3.0, 0.8, -0.5)
	var hz := Hazard.spawn(st, p, 1.3, 2.6, Actor.Team.ENEMY, Color(0.55, 0.85, 0.35), func(_h: Hazard, a: Actor) -> void:
		if a is Player:
			var h := Hit.make(null, 4.0, ["dot", "spore"])
			h.can_crit = false
			h.silent = true
			(a as Player).take_enemy_hit(h, null))
	hz.period = 0.5
	hz.particle_rate = 10.0


func hit_color() -> Color:
	return Color(0.85, 0.35, 0.3)
