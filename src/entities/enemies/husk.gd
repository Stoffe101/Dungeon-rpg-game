## Husk: shambling skeleton. Closes in, raises its claws (telegraphed cone),
## then rakes forward with a short lunge. Fodder that punishes greed.
extends Enemy

const REACH := 1.65
const HALF := deg_to_rad(50.0)


func behave(dt: float) -> void:
	match state:
		"idle":
			set_state("chase")
		"chase":
			chase(speed, dt)
			sprite.play("walk")
			if dist_to_player() < REACH + 0.2 and stage.grid.line_clear(pos, target().pos):
				aim_dir = dir_to_player()
				facing = aim_dir
				vel = Vector2.ZERO
				set_state("windup")
				telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(REACH * 2.0, REACH * 2.0), 0.55 / attack_rate, {"half_angle": HALF})
				sprite.play("windup")
				Audio.play("husk_windup", -8.0, randf_range(0.9, 1.1))
		"windup":
			vel = Vector2.ZERO
			if timer(0.55):
				set_state("strike")
				sprite.play("attack")
				push += aim_dir * 4.0
				strike_arc(pos, aim_dir, REACH, HALF, damage, 5.0)
				stage.fx.swipe(pos, aim_dir, REACH, HALF, Color(0.55, 0.95, 0.85, 0.8), 0.08, 0.5)
				Audio.play("claw", -6.0)
		"strike":
			vel = Vector2.ZERO
			if timer(0.65):
				set_state("chase")
		_:
			set_state("chase")
