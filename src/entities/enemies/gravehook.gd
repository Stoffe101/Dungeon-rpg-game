## Gravehook: a gaoler with a chain. The distance a Kindled keeps is the distance it
## throws: a long straight warning, a hook that drags whoever it catches to its feet,
## and a reaping blow shown in plenty of time. The chain goes where it was aimed, so a
## step aside, a dodge or a Ward all answer it. It is slow, and strong only up close.
extends Enemy

const RANGE := 8.5
const WIDE := 1.0
const COL := Color(0.65, 0.85, 0.9)

var cd := 2.5
var reap_cd := 0.0
var caught: Player = null


func behave(dt: float) -> void:
	cd -= dt * attack_rate
	reap_cd -= dt * attack_rate
	match state:
		"idle":
			set_state("walk")
		"walk":
			var d := dist_to_player()
			var t := target()
			# it keeps its chain's distance, and closes in while the chain is coiled
			if d > 5.5 or (cd > 0.0 and d > 1.9):
				chase(speed, dt)
			else:
				vel = Vector2.ZERO
				if t:
					facing = dir_to_player()
			sprite.play("walk" if vel.length() > 0.2 else "idle")
			if t and d < 2.2 and reap_cd <= 0.0 and may_strike():
				_begin_reap()
			elif t and cd <= 0.0 and d > 3.0 and d < RANGE and stage.grid.line_clear(pos, t.pos) and may_strike("ranged"):
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(RANGE, WIDE), 0.95 / attack_rate)
				Audio.play_at("clank", pos, -8.0, 0.6)
				voice("attack")
		"windup":
			vel = Vector2.ZERO
			if timer(0.95):
				_throw()
		"thrown":
			vel = Vector2.ZERO
			if timer(0.45):
				if caught:
					_begin_reap()
				else:
					set_state("slack")
		"slack":
			vel = Vector2.ZERO
			if timer(1.2):
				cd = 5.5
				set_state("walk")
		"reap_windup":
			vel = Vector2.ZERO
			if timer(0.7):
				sprite.play("reap")
				strike_arc(pos, aim_dir, 2.6, 1.05, damage, 8.0)
				stage.fx.swipe(pos, aim_dir, 2.6, 1.05, Color(COL.r, COL.g, COL.b, 0.8), 0.1, 0.55)
				Audio.play_at("claw", pos, -3.0, 0.7)
				set_state("slack")
				reap_cd = 2.5
				caught = null
		_:
			set_state("walk")


func _begin_reap() -> void:
	var t := target()
	aim_dir = dir_to_player() if t else facing
	facing = aim_dir
	set_state("reap_windup")
	sprite.play("windup")
	telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(5.2, 5.2), 0.7 / attack_rate, {"half_angle": 1.05})


func _throw() -> void:
	set_state("thrown")
	sprite.play("throw")
	caught = null
	# the chain, flung out and hauled back
	stage.fx.shape(Fx.Shape.RECT, pos, aim_dir, Vector2(RANGE, 0.22), Color(COL.r, COL.g, COL.b, 0.5), COL, 0.22)
	Audio.play_at("chain_throw", pos + aim_dir * 3.0, -3.0)
	for p in stage.active_players():
		var q := Geometry2D.get_closest_point_to_segment(p.pos, pos, pos + aim_dir * RANGE)
		if q.distance_to(p.pos) > WIDE * 0.5 + p.radius or not stage.grid.line_clear(pos, p.pos):
			continue
		var h := _hit_on(p, damage * 0.5, pos, 0.0)
		h.knockback = Vector2.ZERO
		p.take_enemy_hit(h, self)     # (a dodge or a Ward: the chain finds nothing)
		return


## Dragged to its feet, in a straight line: a wall on the way stops the drag.
func landed_on(p: Player) -> void:
	if state != "thrown" or caught:
		return
	caught = p
	sprite.play("haul")
	p.hauled(pos + (p.pos - pos).normalized() * 1.6)
	stage.fx.number(p.pos, 2.4, "CAUGHT", COL, true)
	stage.fx.shake(0.2)
	Audio.play_at("chain_haul", p.pos, -3.0)
