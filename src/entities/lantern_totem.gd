## A Hearth Lantern planted by its Kindled (the ability): a post with a
## lantern of hearth-fire. It looses ember bolts at the nearest foe (shaped by
## its owner's projectile modifiers), and every Kindled standing in its light
## regains Kindle and takes less damage - a place for a party to hold.
class_name LanternTotem
extends Actor

const LIGHT_COL := Color(1.0, 0.72, 0.38)

var owner_player: Player
var duration := 12.0
var damage := 8.0
var light_r := 3.5
var fire_every := 0.6
var flare_out := false          # Rune of Echoes: it bursts as it gutters
var draws_in := false           # Rune of the Well: its light pulls foes
var _fire_t := 0.4
var _light: OmniLight3D
var _mote_t := 0.0


func _ready() -> void:
	team = Team.PLAYER
	ghost = true
	targetable = false
	anchored = true
	radius = 0.3
	build_visual("lantern_totem", "idle")
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COL
	_light.light_energy = 1.6
	_light.omni_range = light_r * 1.6
	_light.position = Vector3(0, 1.4 * Iso.SQ2, 0)
	visual.add_child(_light)


## Co-op: guests draw its glow too (NetRun sends this with the actor).
func light_spec() -> Array:
	return [LIGHT_COL, 1.6, light_r * 1.6, 1.4]


func think(dt: float) -> void:
	duration -= dt
	if duration <= 0.0 or owner_player == null or not is_instance_valid(owner_player):
		_gutter()
		return
	# its light: Kindle for every Kindled in it, and shelter (Player.shelter_t)
	for pl in stage.players_near(pos, light_r):
		pl.shelter_t = 0.3
		pl.gain_kindle(3.0 * dt)
	# nothing hides in its light: foes in it are Exposed (they take more damage)
	for a in stage.in_circle(team, pos, light_r):
		a.status.exposed_t = maxf(a.status.exposed_t, 0.25)
	if draws_in:
		for a in stage.in_circle(team, pos, light_r + 1.5):
			if not a.anchored:
				a.push += (pos - a.pos).normalized() * 6.0 * dt
	_fire_t -= dt
	if _fire_t <= 0.0:
		var t := stage.nearest_hostile(team, pos, 7.5, true)
		if t:
			_fire_t = fire_every
			_bolt(t)
		else:
			_fire_t = 0.2
	_mote_t -= dt
	if _mote_t <= 0.0:
		_mote_t = 0.12
		stage.fx.motes(pos + Vector2.from_angle(stage.rng.randf() * TAU) * stage.rng.randf_range(0.5, light_r), 0.2, LIGHT_COL, 1, 0.5, 1.2, 0.1)


func _bolt(t: Actor) -> void:
	var me := owner_player
	var dmg := damage
	Volley.fire(me, "proj_ember", pos, (t.pos - pos).normalized(), 14.0 * me.stats.v("projectile_speed"), 1, func(pr: Projectile, _d: Vector2) -> void:
		pr.pos = pos + Vector2(0, -0.1)
		pr.height = 1.3
		pr.damage = dmg
		pr.tags = ["summon", "fire"]
		pr.spin = true
		pr.reflectable = false
		pr.trail_color = LIGHT_COL
		pr.trail_rate = 22.0
		pr.life = 0.75
		pr.make_hit_fn = func(proj: Projectile, _tg: Actor) -> Hit:
			var h := Combat.player_hit(me, me.stats, proj.damage, proj.tags.duplicate())
			h.knockback = proj.vel.normalized() * 1.5
			h.from_dir = proj.vel.normalized()
			h.burn = 1 if stage.rng.randf() < 0.3 else 0
			return h)
	Audio.play_at("bolt", pos, -10.0, 1.3, 200)


func _gutter() -> void:
	if flare_out and owner_player and is_instance_valid(owner_player):
		# Rune of Echoes: one last flare as the flame dies
		stage.fx.ring(pos, 2.6, LIGHT_COL, 0.3, 0.3)
		stage.fx.burst(pos, 0.8, LIGHT_COL, 24, 4.0, 0.5, 2.0)
		stage.strike_props_circle(pos, 2.6, owner_player, true)
		for a in stage.in_circle(team, pos, 2.6):
			var h := Combat.player_hit(owner_player, owner_player.stats, damage * 3.0, ["summon", "fire"])
			h.burn = 2
			h.knockback = (a.pos - pos).normalized() * 6.0
			owner_player.deal_hit(a, h)
	stage.fx.burst(pos, 1.0, LIGHT_COL, 12, 2.0, 0.5, -1.0)
	die(null)


func _death_effect() -> void:
	queue_free()
