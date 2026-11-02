## Ossuary Guard: a tower shield blocks most frontal damage. It turns slowly, so
## flanking works; heavy weapons and staggers break through. Its shield charge
## stuns it if it slams into a wall - bait it.
extends Enemy

const TURN := 2.4
var cooldown := 1.0
var charge_hit := false


func block_mult(h: Hit) -> float:
	var base := super.block_mult(h)
	if h.unblockable or h.has_tag("dot") or status.is_staggered() or state == "charge" or state == "stunned":
		return base
	# hit travelling against our facing = frontal
	if h.from_dir != Vector2.ZERO and h.from_dir.dot(facing) < -0.35:
		stage.fx.burst(pos + facing * 0.5, 0.7, Color(1.0, 0.9, 0.6), 5, 4.0, 0.2, 6.0, facing, 0.8)
		Audio.play("clank", -4.0, randf_range(0.9, 1.1))
		return base * 0.15
	return base


func _turn_to(d: Vector2, dt: float) -> void:
	var a := facing.angle()
	var b := d.angle()
	var diff := wrapf(b - a, -PI, PI)
	a += clampf(diff, -TURN * dt, TURN * dt)
	facing = Vector2.from_angle(a)


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate
	var t := target()
	match state:
		"idle":
			set_state("advance")
		"advance":
			if t == null:
				vel = Vector2.ZERO
				return
			move_toward_point(t.pos, speed, dt)
			_turn_to(dir_to_player(), dt)
			sprite.play("walk")
			var d := dist_to_player()
			var los := stage.grid.line_clear(pos, t.pos)
			if cooldown <= 0.0 and los:
				if d < 2.1:
					aim_dir = facing
					set_state("bash_windup")
					sprite.play("windup")
					telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(4.0, 4.0), 0.6 / attack_rate, {"half_angle": deg_to_rad(45.0)})
				elif d > 3.2 and d < 7.5 and absf(facing.angle_to(dir_to_player())) < 0.5:
					aim_dir = facing
					set_state("charge_windup")
					sprite.play("windup")
					telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(7.0, 1.3), 0.8 / attack_rate)
					Audio.play("guard_roar", -6.0)
		"bash_windup":
			vel = Vector2.ZERO
			if timer(0.6):
				sprite.play("bash")
				push += aim_dir * 5.0
				strike_arc(pos, aim_dir, 2.0, deg_to_rad(45.0), damage, 9.0)
				stage.fx.shake(0.15)
				Audio.play("clank", -2.0, 0.8)
				set_state("recover")
		"charge_windup":
			vel = Vector2.ZERO
			if timer(0.8):
				set_state("charge")
				charge_hit = false
				sprite.play("bash")
		"charge":
			vel = aim_dir * 11.0
			if state_t > 0.05 and stage.grid.box_blocked(pos + aim_dir * (radius + 0.2), box()):
				vel = Vector2.ZERO
				stage.fx.shake(0.3)
				stage.fx.burst(pos + aim_dir * 0.6, 1.0, Color(0.7, 0.68, 0.62), 14, 5.0, 0.4, 9.0)
				stage.fx.number(pos, 2.4, "DAZED", Color(1.0, 0.9, 0.5))
				Audio.play("slam", -3.0, 1.2)
				status.stagger_t = 1.6
				set_state("recover")
				return
			if not charge_hit and dist_to_player() < radius + t.radius + 0.3:
				charge_hit = true
				t.take_enemy_hit(make_hit(damage * 1.2, pos, 10.0), self)
			if state_t > 0.55:
				vel = Vector2.ZERO
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			sprite.play("idle")
			if timer(0.7):
				cooldown = randf_range(0.8, 1.4)
				set_state("advance")
		_:
			set_state("advance")


func hit_color() -> Color:
	return Color(0.75, 0.75, 0.72)
