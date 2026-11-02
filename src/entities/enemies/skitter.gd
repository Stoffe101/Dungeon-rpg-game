## Skitter: a skull on borrowed fingers. Circles at a distance, then leaps in a
## straight, telegraphed line. Comes in packs; dies fast.
extends Enemy

var orbit_t := 0.0
var leap_hit := false


func behave(dt: float) -> void:
	match state:
		"idle":
			orbit_t = randf_range(0.8, 1.8)
			set_state("circle")
		"circle":
			sprite.play("run")
			var t := target()
			if t == null:
				vel = Vector2.ZERO
				return
			var d := dist_to_player()
			if d > 4.5 or not stage.grid.line_clear(pos, t.pos):
				chase(speed, dt)
			else:
				var to := (t.pos - pos).normalized()
				var tang := to.orthogonal() * _strafe_sign
				var radial := to * (d - 3.2) * 0.8
				vel = (tang + radial).normalized() * speed
				facing = to
				if stage.grid.box_blocked(pos + vel.normalized() * 0.5, box()):
					_strafe_sign *= -1.0
			if state_t > orbit_t and d < 5.0 and stage.grid.line_clear(pos, t.pos):
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("windup")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(4.2, 0.9), 0.38 / attack_rate)
				sprite.play("crouch")
				Audio.play("skitter", -10.0, randf_range(1.0, 1.25))
		"windup":
			vel = Vector2.ZERO
			if timer(0.38):
				set_state("leap")
				leap_hit = false
				sprite.play("leap")
		"leap":
			vel = aim_dir * 13.0
			height = sin(clampf(state_t / 0.3, 0.0, 1.0) * PI) * 0.5
			if not leap_hit and dist_to_player() < radius + target().radius + 0.15:
				leap_hit = true
				target().take_enemy_hit(make_hit(damage, pos, 4.0), self)
			if state_t >= 0.3:
				height = 0.0
				vel = Vector2.ZERO
				set_state("recover")
				sprite.play("idle")
		"recover":
			vel = Vector2.ZERO
			if timer(0.55):
				orbit_t = randf_range(0.8, 1.6)
				set_state("circle")
		_:
			set_state("circle")
