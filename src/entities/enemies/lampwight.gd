## Lampwight: keeps away from the fight and binds an ally with its soul-lamp:
## the bound one wears a soul shield that refills while the tether holds. Break
## the tether by killing the Lampwight, or by putting a wall between them.
extends Enemy

const REACH := 9.0
var bound: Enemy = null
var bind_cd := 1.2
var _line_t := 0.0
var _granted := 0.0
var _shot_cd := 1.5
var _cast_t := 0.0
var lamp: OmniLight3D


func _ready() -> void:
	super._ready()
	flying = true
	bar_offset = 5.0
	# the lamp it carries is a real light: you see it coming across a dark room
	lamp = OmniLight3D.new()
	lamp.light_color = Color(0.45, 1.0, 0.9)
	lamp.light_energy = 1.1
	lamp.omni_range = 4.5
	lamp.position = Vector3(0.25, 2.1 * Iso.SQ2, 0.3)
	visual.add_child(lamp)


func behave(dt: float) -> void:
	bind_cd -= dt * attack_rate
	_shot_cd -= dt * attack_rate
	_cast_t -= dt
	bob = sin(stage.elapsed * 2.2) * 0.1 + 0.2
	if state == "idle":
		set_state("float")
	kite(5.0, 8.5, speed, dt)
	if bound and (not is_instance_valid(bound) or not bound.alive or bound.pos.distance_to(pos) > REACH or not stage.grid.line_clear(pos, bound.pos)):
		_unbind()
	if bound == null:
		lamp.light_energy = 1.1
		if _cast_t <= 0.0:
			sprite.play("idle")
		if bind_cd <= 0.0:
			_bind()
		# with no one left to guard, it flicks slow soul-sparks instead
		var t := target()
		if bound == null and _shot_cd <= 0.0 and t and stage.grid.line_clear(pos, t.pos):
			_shot_cd = randf_range(1.8, 2.4)
			sprite.play("cast")
			_cast_t = 0.4
			var pr := shoot("proj_orb", dir_to_player(), 4.6, damage, 0.24)
			pr.life = 3.5
			Audio.play_at("orb", pos, -8.0, 1.5)
	else:
		sprite.play("cast")
		lamp.light_energy = 1.6 + sin(stage.elapsed * 9.0) * 0.25
		# the shield refills while the light holds
		bound.shield = minf(bound.shield_max, bound.shield + bound.shield_max * 0.14 * dt)
		_line_t -= dt
		if _line_t <= 0.0:
			_line_t = 0.09
			var d := bound.pos - pos
			stage.fx.shape(Fx.Shape.RECT, pos, d.normalized(), Vector2(d.length(), 0.22), Color(0.4, 1.0, 0.9, 0.35), Color(0.6, 1.0, 0.95, 0.9), 0.11, {"progress": 1.0, "glow": 1.6})
			stage.fx.motes(pos.lerp(bound.pos, randf()), 0.9, Color(0.5, 1.0, 0.9), 1, 0.6, 0.5, 0.1)


func _bind() -> void:
	var best: Enemy = null
	var bd := REACH
	for a in stage.actors:
		if not (a is Enemy) or a == self or not a.alive or a.get_script() == get_script():
			continue
		var e := a as Enemy
		var d := e.pos.distance_to(pos)
		if d < bd and stage.grid.line_clear(pos, e.pos):
			bd = d
			best = e
	if best == null:
		bind_cd = 1.0
		return
	bound = best
	_granted = best.max_hp * 0.45
	bound.shield_max += _granted
	bound.shield = bound.shield_max
	sprite.play("cast")
	stage.fx.ring(bound.pos, 1.2, Color(0.5, 1.0, 0.9), 0.3, 0.3)
	stage.fx.number(bound.pos, 2.4, "BOUND", Color(0.55, 1.0, 0.9))
	Audio.play_at("chant", pos, -6.0, 1.4)


func _unbind() -> void:
	if bound and is_instance_valid(bound) and bound.alive:
		bound.shield_max = maxf(0.0, bound.shield_max - _granted)
		bound.shield = minf(bound.shield, bound.shield_max)
		stage.fx.burst(bound.pos, 1.0, Color(0.5, 1.0, 0.9), 10, 3.0, 0.4, 0.0)
	bound = null
	_granted = 0.0
	bind_cd = 2.5


func die(killer: Node) -> void:
	_unbind()
	super.die(killer)


func hit_color() -> Color:
	return Color(0.55, 0.9, 0.85)
