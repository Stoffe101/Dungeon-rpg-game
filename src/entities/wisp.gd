## A hearth-wisp summoned by the Wisp Familiar ability. Orbits the Kindled and
## pelts nearby enemies with ember bolts.
class_name Wisp
extends Actor

var owner_player: Player
var duration := 18.0
var damage := 7.0
var orbit_phase := 0.0
var _fire_t := 0.0
var _light: OmniLight3D


func _ready() -> void:
	team = Team.PLAYER
	ghost = true
	targetable = false
	flying = true
	radius = 0.2
	height = 1.3
	build_visual("wisp", "idle")
	shadow.visible = false
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.4)
	_light.light_energy = 0.9
	_light.omni_range = 3.0
	visual.add_child(_light)


func think(dt: float) -> void:
	duration -= dt
	if duration <= 0.0 or owner_player == null or not owner_player.alive:
		stage.fx.burst(pos, height, Color(1.0, 0.8, 0.45), 10, 2.0, 0.4, -1.0)
		die(null)
		return
	orbit_phase += dt * 1.8
	var want := owner_player.pos + Vector2.from_angle(orbit_phase) * 1.4
	pos = pos.lerp(want, 1.0 - exp(-dt * 6.0))
	bob = sin(stage.elapsed * 4.0 + orbit_phase) * 0.12
	_fire_t -= dt
	if _fire_t <= 0.0:
		var t := stage.nearest_hostile(team, pos, 8.0, true)
		if t:
			_fire_t = 0.6
			var d := (t.pos - pos).normalized()
			var pr := Projectile.create(stage, "proj_ember", pos, d * 13.0, team)
			pr.source = owner_player
			pr.height = height
			pr.spin = true
			pr.reflectable = false
			pr.trail_color = Color(1.0, 0.75, 0.4)
			pr.trail_rate = 20.0
			pr.life = 0.8
			var dmg := damage
			pr.make_hit_fn = func(proj: Projectile, _tg: Actor) -> Hit:
				var h := Combat.player_hit(owner_player, owner_player.stats, dmg, ["summon", "fire"])
				h.knockback = proj.vel.normalized() * 1.5
				h.from_dir = proj.vel.normalized()
				return h
		else:
			_fire_t = 0.2
	if stage.rng.randf() < dt * 8.0:
		stage.fx.motes(pos, height, Color(1.0, 0.75, 0.35), 1, 0.4, 0.5, 0.1)


func _death_effect() -> void:
	queue_free()
