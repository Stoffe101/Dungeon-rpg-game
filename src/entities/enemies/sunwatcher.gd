## Sunwatcher: a floating eye that stares with the old sun's light. It tracks
## you with a thin line, then fires a beam that sweeps across the room - dash
## through the beam, or get behind the eye before it turns.
extends Enemy

const BEAM_LEN := 11.0
const SWEEP := 1.25          # radians swept while firing
const FIRE_TIME := 1.1
var cooldown := 2.0
var sweep_from := 0.0
var sweep_sign := 1.0
var _hit_cd := 0.0


func _ready() -> void:
	super._ready()
	flying = true
	bar_offset = 5.0


func behave(dt: float) -> void:
	cooldown -= dt * attack_rate
	_hit_cd -= dt
	bob = sin(stage.elapsed * 1.8) * 0.12 + 0.25
	match state:
		"idle":
			set_state("drift")
		"drift":
			kite(5.0, 9.0, speed, dt)
			sprite.play("idle")
			var t := target()
			if t and cooldown <= 0.0 and stage.grid.line_clear(pos, t.pos) and dist_to_player() < BEAM_LEN - 1.0:
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("charge")
				sprite.play("charge")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(BEAM_LEN, 0.3), 1.0 / attack_rate)
				Audio.play_at("chant", pos, -4.0, 1.8)
		"charge":
			vel = Vector2.ZERO
			if state_t < 0.6 and target():
				aim_dir = aim_dir.slerp(dir_to_player(), 0.12)
				facing = aim_dir
				if tele and is_instance_valid(tele):
					var side := Vector2(-aim_dir.y, aim_dir.x)
					var bx := Vector3(aim_dir.x, 0, aim_dir.y * Iso.SQ2) * BEAM_LEN
					var bz := Vector3(side.x, 0, side.y * Iso.SQ2) * 0.3
					tele.transform = Transform3D(Basis(bx, Vector3.UP, bz), Iso.to_world(pos + aim_dir * BEAM_LEN * 0.5, 0.0) + Vector3(0, 0.02, 0))
			if timer(1.0):
				# sweep away from where the Kindled stood, so stepping with it is a trap
				sweep_sign = -1.0 if randf() < 0.5 else 1.0
				sweep_from = aim_dir.angle() - SWEEP * 0.5 * sweep_sign
				set_state("fire")
				sprite.play("fire")
				Audio.play_at("sunlance", pos, 0.0, 0.6)
		"fire":
			vel = Vector2.ZERO
			var k := clampf(state_t / FIRE_TIME, 0.0, 1.0)
			var dir := Vector2.from_angle(sweep_from + SWEEP * k * sweep_sign)
			facing = dir
			var length := _beam_length(dir)
			stage.fx.shape(Fx.Shape.RECT, pos, dir, Vector2(length, 0.55), Color(1.0, 0.8, 0.4, 0.55), Color(1.0, 0.95, 0.75, 1.0), 0.06, {"progress": 1.0, "glow": 2.2})
			stage.fx.burst(pos + dir * length, 0.4, Color(1.0, 0.8, 0.4), 1, 2.0, 0.25, 0.0)
			var pl := target()
			if pl and _hit_cd <= 0.0 and pl.height < 0.5:
				var t2 := clampf((pl.pos - pos).dot(dir), 0.0, length)
				if pl.pos.distance_to(pos + dir * t2) < 0.3 + pl.radius:
					_hit_cd = 0.4
					var h := make_hit(damage * 0.8, pos, 3.0)
					h.tags = ["ranged", "fire"]
					pl.take_enemy_hit(h, self)
			if k >= 1.0:
				cooldown = randf_range(3.0, 3.8)
				set_state("drift")
		_:
			set_state("drift")


## The beam stops at the first wall.
func _beam_length(dir: Vector2) -> float:
	var l := 0.0
	while l < BEAM_LEN:
		var p := pos + dir * l
		if stage.grid.blocks_shot(floori(p.x), floori(p.y)):
			return l
		l += 0.25
	return BEAM_LEN


func hit_color() -> Color:
	return Color(1.0, 0.85, 0.55)
