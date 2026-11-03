## Thornback: an armoured beetle. Curls into a spiked ball and rolls in a
## straight line, ricocheting off walls. After the roll it is dizzy - armour
## down and exposed. Dodge the ball, then punish.
extends Enemy

var bounces := 0
var roll_hit := false
var base_armor := 0.35


func _ready() -> void:
	super._ready()
	base_armor = armor


func behave(dt: float) -> void:
	match state:
		"idle":
			set_state("approach")
		"approach":
			armor = base_armor
			chase(speed, dt)
			sprite.play("walk")
			var d := dist_to_player()
			if d < 8.0 and d > 2.0 and state_t > 1.0 and stage.grid.line_clear(pos, target().pos):
				aim_dir = dir_to_player()
				facing = aim_dir
				vel = Vector2.ZERO
				set_state("curl")
				sprite.play("curl")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(9.0, 1.4), 0.75 / attack_rate)
				Audio.play("guard_roar", -10.0, 1.6)
		"curl":
			vel = Vector2.ZERO
			if state_t < 0.4:
				aim_dir = aim_dir.slerp(dir_to_player(), 0.2)
			if timer(0.75):
				set_state("roll")
				sprite.play("roll")
				bounces = 0
				roll_hit = false
				Audio.play("rush", -6.0, 1.3)
		"roll":
			vel = aim_dir * 12.0
			var ahead := pos + aim_dir * (radius + 0.25)
			if stage.grid.box_blocked(ahead, box()):
				# ricochet: reflect on the blocked axis
				var bx := stage.grid.box_blocked(pos + Vector2(aim_dir.x, 0).normalized() * (radius + 0.25), box())
				var by := stage.grid.box_blocked(pos + Vector2(0, aim_dir.y).normalized() * (radius + 0.25), box())
				if bx:
					aim_dir.x = -aim_dir.x
				if by:
					aim_dir.y = -aim_dir.y
				if not bx and not by:
					aim_dir = -aim_dir
				bounces += 1
				stage.fx.shake(0.15)
				stage.fx.burst(pos, 0.4, Color(0.7, 0.68, 0.6), 8, 4.0, 0.3, 8.0)
				Audio.play("clank", -6.0, 0.7)
				roll_hit = false
			if not roll_hit and target() and dist_to_player() < radius + target().radius + 0.1:
				roll_hit = true
				target().take_enemy_hit(make_hit(damage, pos, 9.0), self)
			if bounces > 2 or state_t > 2.4:
				vel = Vector2.ZERO
				set_state("dizzy")
				sprite.play("dizzy")
				armor = 0.0
				status.exposed_t = 1.8
				stage.fx.number(pos, 2.0, "DIZZY", Color(1.0, 0.9, 0.5))
		"dizzy":
			vel = Vector2.ZERO
			if state_t > 1.8:
				set_state("approach")
		_:
			set_state("approach")


func hit_color() -> Color:
	return Color(0.6, 0.65, 0.7)
