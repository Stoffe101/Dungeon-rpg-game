## A lingering area on the floor: burning ground, rime trails, frost sigils,
## the Warden's gloamfire. Applies an effect to hostiles inside every `period`.
class_name Hazard
extends Node3D

var stage: Stage
var team := Actor.Team.PLAYER
var pos := Vector2.ZERO
var radius := 1.0
var life := 3.0
var period := 0.4
var effect: Callable          # (hazard, actor) -> void
var on_pulse: Callable = Callable()  # (hazard) -> void, once per period
var color := Color(1.0, 0.5, 0.2)
var particle_rate := 6.0
var shape_node: MeshInstance3D
var _t := 0.0
var _p := 0.0
var _age := 0.0


static func spawn(st: Stage, p: Vector2, r: float, duration: float, t: int, col: Color, fn: Callable) -> Hazard:
	var h := Hazard.new()
	h.stage = st
	h.pos = p
	h.radius = r
	h.life = duration
	h.team = t
	h.color = col
	h.effect = fn
	st.add_child(h)
	st.register_hazard(h)
	# the player's own hazards stay quiet so enemy telegraphs keep priority
	var fill_a := 0.18 if t == Actor.Team.PLAYER else 0.35
	var edge_a := 0.45 if t == Actor.Team.PLAYER else 1.0
	var edge := col.lightened(0.3)
	edge.a = edge_a
	h.shape_node = st.fx.shape(Fx.Shape.DISC, p, Vector2.RIGHT, Vector2(r * 2, r * 2), Color(col.r, col.g, col.b, fill_a), edge, duration, {"progress": 1.0, "glow": 1.1})
	return h


func tick(dt: float) -> void:
	_age += dt
	life -= dt
	_t += dt
	_p += dt * particle_rate
	while _p >= 1.0:
		_p -= 1.0
		var off := Vector2.from_angle(randf() * TAU) * randf() * radius
		stage.fx.motes(pos + off, 0.0, color, 1, 1.2, 0.6, 0.1)
	if _t >= period:
		_t -= period
		if on_pulse.is_valid():
			on_pulse.call(self)
		if effect.is_valid():
			for a in stage.in_circle(team, pos, radius):
				effect.call(self, a)
	if life <= 0.0:
		stage.unregister_hazard(self)
		queue_free()
