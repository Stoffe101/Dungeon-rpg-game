## Bog Toad: fat and patient. Hops after you in heavy arcs that splash where
## they land, and lashes its tongue across the room to drag you in close.
extends Enemy

const TONGUE := 6.5
var cooldown := 1.5
var hop_from := Vector2.ZERO
var hop_to := Vector2.ZERO


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate
	match state:
		"idle":
			set_state("sit")
		"sit":
			vel = Vector2.ZERO
			sprite.play("idle")
			var t := target()
			if t == null or cooldown > 0.0:
				return
			var d := dist_to_player()
			aim_dir = dir_to_player()
			facing = aim_dir
			if d > 2.2 and d < TONGUE and stage.grid.line_clear(pos, t.pos) and randf() < 0.45 and may_strike("ranged"):
				set_state("tongue_windup")
				sprite.play("crouch")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(TONGUE, 0.7), 0.6 / attack_rate)
				Audio.play("chant", -10.0, 1.8)
			else:
				hop_to = stage.foe_spot(pos + aim_dir * minf(d, 4.0), 0.4)
				set_state("hop_windup")
				sprite.play("crouch")
				telegraph(Fx.Shape.DISC, hop_to, Vector2.RIGHT, Vector2(3.2, 3.2), (0.35 + 0.55) / attack_rate)
		"hop_windup":
			if timer(0.35):
				hop_from = pos
				set_state("hop")
				sprite.play("hop")
				Audio.play("leap", -6.0, 1.4)
				voice("jump")
		"hop":
			var k := clampf(state_t / 0.55, 0.0, 1.0)
			pos = stage.grid.move_box(pos, box(), hop_from.lerp(hop_to, k) - pos, true)
			height = sin(k * PI) * 1.4
			if k >= 1.0:
				height = 0.0
				_land()
		"tongue_windup":
			vel = Vector2.ZERO
			if timer(0.6):
				sprite.play("tongue")
				_lash()
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			if timer(0.6):
				cooldown = randf_range(1.2, 2.0)
				set_state("sit")
		_:
			set_state("sit")


func _land() -> void:
	sprite.play("idle")
	strike_circle(pos, 1.6, damage, 6.0)
	stage.fx.burst(pos, 0.1, Color(0.45, 0.62, 0.3), 16, 4.0, 0.5, 8.0, Vector2.ZERO, PI, 2.5)
	stage.fx.ring(pos, 1.6, Color(0.55, 0.9, 0.5), 0.25, 0.2)
	stage.fx.splat(pos, Color(0.2, 0.28, 0.14), 10.0, 0.9)
	stage.fx.shake(0.1)
	Audio.play("slam", -8.0, 1.5)
	voice("land", -6.0)
	set_state("recover")


## The tongue pulls instead of pushing (negative knockback).
func _lash() -> void:
	strike_line(pos, aim_dir, TONGUE, 0.7, damage * 0.6, -9.0)
	stage.fx.shape(Fx.Shape.RECT, pos, aim_dir, Vector2(TONGUE, 0.35), Color(0.95, 0.45, 0.5, 0.0), Color(1.0, 0.55, 0.6, 1.0), 0.14, {"progress": 1.0, "glow": 1.2})
	Audio.play("thrust", -6.0, 1.5)


func hit_color() -> Color:
	return Color(0.55, 0.75, 0.4)
