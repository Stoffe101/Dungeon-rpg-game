## Hollow Archer: keeps its distance and looses soul-arrows after a visible aim
## line. The aim tracks you, then locks just before release - step aside late.
extends Enemy

var cooldown := 1.2


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate
	match state:
		"idle":
			set_state("kite")
		"kite":
			kite(4.5, 8.5, speed, dt)
			sprite.play("walk" if vel.length() > 0.3 else "idle")
			var t := target()
			if t and cooldown <= 0.0 and dist_to_player() < 10.0 and stage.grid.line_clear(pos, t.pos):
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				set_state("aim")
				sprite.play("aim")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(10.0, 0.35), 0.75 / attack_rate)
		"aim":
			vel = Vector2.ZERO
			var t := target()
			if t and state_t < 0.45 / attack_rate:
				aim_dir = aim_dir.slerp(dir_to_player(), 0.25)
				facing = aim_dir
				if tele and is_instance_valid(tele):
					var side := Vector2(-aim_dir.y, aim_dir.x)
					var bx := Vector3(aim_dir.x, 0, aim_dir.y * Iso.SQ2) * 10.0
					var bz := Vector3(side.x, 0, side.y * Iso.SQ2) * 0.35
					tele.transform = Transform3D(Basis(bx, Vector3.UP, bz), Iso.to_world(pos + aim_dir * 5.0, 0.0) + Vector3(0, 0.02, 0))
			if timer(0.75):
				_loose()
				set_state("recover")
				sprite.play("shoot")
		"recover":
			vel = Vector2.ZERO
			if timer(0.45):
				cooldown = randf_range(1.4, 2.0)
				set_state("kite")
		_:
			set_state("kite")


func _loose() -> void:
	var dirs := [aim_dir]
	if elite:
		dirs = [aim_dir.rotated(-0.2), aim_dir, aim_dir.rotated(0.2)]
	for d: Vector2 in dirs:
		var pr := shoot("proj_arrow", d, 12.0, damage, 0.18)
		pr.knockback = 3.0
	Audio.play("bow", -4.0, randf_range(0.95, 1.05))
