## Lantern Moth: drawn to your light. Flutters around you, then dives; a hit
## drinks Kindle from your lantern (your light shrinks). Fragile and flighty.
extends Enemy

var orbit := 0.0
var dive_cd := 1.5


func _ready() -> void:
	super._ready()
	flying = true
	height = 1.0
	bar_offset = 2.0
	orbit = randf() * TAU


func behave(dt: float) -> void:
	dive_cd -= dt * attack_rate
	var t := target()
	if t == null:
		vel = Vector2.ZERO
		return
	match state:
		"idle":
			set_state("flutter")
		"flutter":
			sprite.play("idle")
			orbit += dt * 1.6
			var want := t.pos + Vector2.from_angle(orbit) * 3.2 + Vector2(sin(stage.elapsed * 3.0 + orbit) * 0.8, 0)
			vel = (want - pos).limit_length(1.0) * speed * 1.2
			height = 1.0 + sin(stage.elapsed * 5.0 + orbit) * 0.25
			facing = (t.pos - pos).normalized()
			if dive_cd <= 0.0 and dist_to_player() < 5.0:
				aim_dir = dir_to_player()
				set_state("mark")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(5.0, 0.8), 0.45 / attack_rate)
		"mark":
			vel = Vector2.ZERO
			if state_t < 0.25:
				aim_dir = dir_to_player()
			if timer(0.45):
				set_state("dive")
				sprite.play("dive")
				Audio.play("dodge", -6.0, 1.5)
		"dive":
			vel = aim_dir * 11.0
			height = maxf(0.3, height - dt * 3.0)
			if dist_to_player() < radius + t.radius + 0.2:
				var res := t.take_enemy_hit(make_hit(damage, pos, 2.0), self)
				if res.amount > 0.0:
					var drained := minf(t.kindle, 15.0)
					t.kindle -= drained
					if drained > 0.0:
						stage.fx.number(t.pos, 2.4, "-%d kindle" % int(drained), Color(0.85, 0.55, 1.0))
						stage.fx.motes(t.pos, 1.0, Color(1.0, 0.7, 0.35), 8, -0.5, 0.6, 0.3)
				_end_dive()
			elif state_t > 0.5 or stage.grid.blocks_shot(floori(pos.x + aim_dir.x * 0.4), floori(pos.y + aim_dir.y * 0.4)):
				_end_dive()
		_:
			set_state("flutter")


func _end_dive() -> void:
	dive_cd = randf_range(2.2, 3.4)
	set_state("flutter")


func hit_color() -> Color:
	return Color(0.75, 0.5, 0.85)
