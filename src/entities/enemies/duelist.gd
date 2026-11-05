## Gilded Duelist: fights in two rhythms. It presses with quick lunges, then
## settles into a riposte stance - its blade glints gold. Strike it with a blade
## then and it turns the blow aside and cuts back. Wait the stance out, Ward
## the riposte, or break the stance with something that isn't steel.
extends Enemy

const STANCE_TIME := 1.7
var cooldown := 1.2
var lunges_left := 0
var _glint_t := 0.0


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
			if d > 2.4:
				chase(speed, dt)
				sprite.play("walk")
			else:
				vel = Vector2.ZERO
				sprite.play("idle")
			facing = dir_to_player()
			if cooldown <= 0.0 and d < 4.5 and may_strike():
				if randf() < 0.45:
					vel = Vector2.ZERO
					set_state("stance")
					sprite.play("stance")
					Audio.play_at("parry", pos, -10.0, 1.6)
					stage.fx.number(pos, 2.6, "!", Color(1.0, 0.85, 0.4), true)
				else:
					lunges_left = 3 if elite else 2
					_begin_lunge()
		"stance":
			vel = Vector2.ZERO
			facing = dir_to_player()
			_glint_t -= dt
			if _glint_t <= 0.0:
				_glint_t = 0.18
				stage.fx.motes(pos + facing * 0.6, 1.2, Color(1.0, 0.85, 0.45), 1, 0.5, 0.35, 0.15)
			if state_t > STANCE_TIME:
				cooldown = 0.6
				set_state("stalk")
		"lunge_windup":
			vel = Vector2.ZERO
			if timer(0.32):
				sprite.play("lunge")
				set_state("lunge")
				set_meta("hit", false)
				Audio.play_at("thrust", pos, -4.0, 1.25)
		"lunge":
			vel = aim_dir * 11.0
			if not get_meta("hit", false) and target() and dist_to_player() < radius + target().radius + 0.6:
				set_meta("hit", true)
				target().take_enemy_hit(make_hit(damage, pos, 4.0), self)
			if state_t > 0.16:
				vel = Vector2.ZERO
				lunges_left -= 1
				if lunges_left > 0:
					_begin_lunge()
				else:
					cooldown = randf_range(1.0, 1.6)
					set_state("recover")
		"riposte":
			vel = Vector2.ZERO
			if state_t > 0.14 and not get_meta("cut", false):
				set_meta("cut", true)
				sprite.play("riposte")
				strike_arc(pos, aim_dir, 2.6, deg_to_rad(75.0), damage * 1.6, 8.0)
				stage.fx.swipe(pos, aim_dir, 2.6, deg_to_rad(78.0), Color(1.0, 0.85, 0.45, 0.95), 0.1, 0.5)
				Audio.play_at("swing", pos, 0.0, 1.3)
			if state_t > 0.6:
				set_meta("cut", false)
				cooldown = 0.9
				set_state("stalk")
		"recover":
			vel = Vector2.ZERO
			if timer(0.45):
				set_state("stalk")
		_:
			set_state("stalk")


func _begin_lunge() -> void:
	aim_dir = dir_to_player()
	facing = aim_dir
	set_state("lunge_windup")
	sprite.play("idle")
	telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(3.0, 0.8), 0.32 / attack_rate)


## In the stance a blade is turned aside entirely, and answered.
func block_mult(h: Hit) -> float:
	if state == "stance" and h.has_tag("melee") and not h.unblockable:
		aim_dir = dir_to_player()
		facing = aim_dir
		set_state("riposte")
		set_meta("cut", false)
		stage.fx.number(pos, 2.6, "RIPOSTE", Color(1.0, 0.85, 0.45))
		stage.fx.ring(pos, 1.2, Color(1.0, 0.85, 0.45), 0.2, 0.3)
		stage.fx.burst(pos + aim_dir * 0.5, 0.9, Color(1.0, 0.9, 0.6), 10, 5.0, 0.25, 4.0)
		Audio.play_at("parry", pos, 0.0, 0.8)
		return 0.0
	return super.block_mult(h)


func hit_color() -> Color:
	return Color(1.0, 0.85, 0.5)
