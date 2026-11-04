## Gravemole: digs under the floor (untouchable; a moving mound of earth gives
## it away) toward wherever the Kindled stands, then erupts beneath them. Keep
## moving. Once up it lingers, swiping, before it digs again - that is the window.
extends Enemy

const ERUPT_R := 1.45
var erupt_at := Vector2.ZERO
var swipe_cd := 0.0
var _dust_t := 0.0


func behave(dt: float) -> void:
	swipe_cd -= dt * attack_rate
	match state:
		"idle":
			_go_under()
		"under":
			var t := target()
			if t == null:
				vel = Vector2.ZERO
				return
			chase(speed * 1.7, dt)
			_dust_t -= dt
			if _dust_t <= 0.0:
				_dust_t = 0.12
				stage.fx.burst(pos, 0.1, Color(0.45, 0.38, 0.32), 2, 2.0, 0.35, 6.0, Vector2.ZERO, PI, 2.0)
			if dist_to_player() < 1.3 or state_t > 3.2:
				vel = Vector2.ZERO
				pos = stage.foe_spot(t.pos, 0.2)
				erupt_at = pos
				set_state("rising")
				telegraph(Fx.Shape.DISC, erupt_at, Vector2.RIGHT, Vector2(ERUPT_R * 2.0, ERUPT_R * 2.0), 0.75 / attack_rate)
				Audio.play_at("crumble", pos, -4.0, 0.7)
		"rising":
			vel = Vector2.ZERO
			if timer(0.75):
				_erupt()
		"surfaced":
			vel = Vector2.ZERO
			var t2 := target()
			if t2 and swipe_cd <= 0.0 and dist_to_player() < 2.0:
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("swipe_windup")
				telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(4.4, 4.4), 0.4 / attack_rate, {"half_angle": deg_to_rad(60.0)})
			elif state_t > 2.6:
				set_state("digging")
				sprite.play("burrow")
		"swipe_windup":
			vel = Vector2.ZERO
			if timer(0.4):
				sprite.play("swipe")
				strike_arc(pos, aim_dir, 2.2, deg_to_rad(60.0), damage, 5.0)
				stage.fx.swipe(pos, aim_dir, 2.2, deg_to_rad(62.0), Color(0.85, 0.82, 0.7, 0.9), 0.1, 0.5)
				Audio.play_at("claw", pos, -2.0, 0.85)
				swipe_cd = 1.2
				set_state("surfaced")
		"digging":
			vel = Vector2.ZERO
			if timer(0.45):
				_go_under()
		_:
			_go_under()


func _go_under() -> void:
	set_state("under")
	targetable = false
	ghost = true
	sprite.play("mound")
	if shadow:
		shadow.visible = false
	Audio.play_at("crumble", pos, -10.0, 1.2)


func _erupt() -> void:
	targetable = true
	ghost = false
	if shadow:
		shadow.visible = true
	sprite.play("emerge")
	strike_circle(pos, ERUPT_R, damage * 1.25, 7.0)
	stage.fx.burst(pos, 0.2, Color(0.5, 0.42, 0.35), 22, 6.0, 0.55, 9.0, Vector2.ZERO, PI, 4.0)
	stage.fx.burst(pos, 0.3, Color(0.85, 0.82, 0.7), 8, 4.0, 0.5, 8.0, Vector2.ZERO, PI, 3.0)
	stage.fx.ring(pos, ERUPT_R, Color(0.8, 0.7, 0.55), 0.25, 0.25)
	stage.fx.splat(pos, Color(0.16, 0.12, 0.1), 12.0, 1.2)
	stage.fx.shake(0.25)
	Audio.play_at("slam", pos, -2.0, 1.1)
	voice("attack", -6.0)
	swipe_cd = 0.6
	set_state("surfaced")


func hit_color() -> Color:
	return Color(0.85, 0.8, 0.7)
