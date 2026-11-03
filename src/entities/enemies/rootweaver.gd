## Rootweaver: keeps its distance and makes the floor dangerous - lines of
## erupting thorns and snaring root circles that slow you to a crawl.
extends Enemy

var cast_cd := 1.6
var next_cast := "thorns"


func _ready() -> void:
	super._ready()
	bar_offset = 6.0


func behave(dt: float) -> void:
	cast_cd -= dt * attack_rate
	var t := target()
	match state:
		"idle":
			set_state("drift")
		"drift":
			kite(5.0, 9.0, speed, dt)
			sprite.play("walk" if vel.length() > 0.3 else "idle")
			if t and cast_cd <= 0.0 and dist_to_player() < 10.0:
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				sprite.play("cast")
				Audio.play("chant", -8.0, 1.3)
				if next_cast == "thorns":
					set_state("thorns")
					# three lines fanning toward the player
					for k in [-0.35, 0.0, 0.35]:
						stage.fx.shape(Fx.Shape.RECT, pos, aim_dir.rotated(k), Vector2(9.0, 1.0), TELE_COLOR, TELE_EDGE, 0.85, {"progress": 0.0})
					telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(9.0, 1.0), 0.85 / attack_rate)
					next_cast = "snare"
				else:
					set_state("snare")
					var at := t.pos
					set_meta("snare_at", at)
					telegraph(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(3.4, 3.4), 0.9 / attack_rate)
					next_cast = "thorns"
		"thorns":
			vel = Vector2.ZERO
			if timer(0.85):
				Audio.play("crumble", -6.0, 1.4)
				for k in [-0.35, 0.0, 0.35]:
					var d := aim_dir.rotated(k)
					strike_line(pos, d, 9.0, 1.0, damage, 4.0)
					for i in 9:
						stage.fx.burst(pos + d * (i + 0.5), 0.2, Color(0.5, 0.65, 0.3), 2, 3.0, 0.4, 8.0, Vector2.ZERO, PI, 3.0)
				cast_cd = randf_range(2.4, 3.2)
				set_state("drift")
		"snare":
			vel = Vector2.ZERO
			if timer(0.9):
				var at: Vector2 = get_meta("snare_at", pos)
				stage.fx.ring(at, 1.7, Color(0.55, 0.8, 0.35), 0.3, 0.3)
				var hz := Hazard.spawn(stage, at, 1.7, 2.2, Team.ENEMY, Color(0.5, 0.75, 0.3), func(_h: Hazard, a: Actor) -> void:
					if a is Player:
						a.status.apply_chill(0.35))
				hz.period = 0.25
				if t and t.pos.distance_to(at) < 1.7 + t.radius:
					t.take_enemy_hit(make_hit(damage * 0.6, at, 0.0), self)
				cast_cd = randf_range(2.4, 3.2)
				set_state("drift")
		_:
			set_state("drift")


func hit_color() -> Color:
	return Color(0.55, 0.45, 0.3)
