## A moving hit: ember bolts, arrows, soul orbs, lances, reflected shots.
class_name Projectile
extends Node3D

var stage: Stage
var team := Actor.Team.ENEMY
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var height := 0.7
var radius := 0.2
var life := 2.0
var pierce := 0
var damage := 10.0
var tags: Array = ["ranged"]
var source: Node = null
var homing_target: Actor = null
var homing_turn := 0.0
var reflectable := true
var reflected := false
var burn := 0
var chill := 0.0
var knockback := 3.0
var trail_color := Color(1, 0.6, 0.3)
var trail_rate := 0.0
var on_hit_fn: Callable = Callable()   # (proj, target, result)
var on_end_fn: Callable = Callable()   # (proj, pos)
var make_hit_fn: Callable = Callable() # (proj, target) -> Hit
var hit_set := {}
var sprite: PixelSprite
var light: OmniLight3D
var spin := false
var _trail_t := 0.0
# lobbed shots fly over walls and actors and only act where they land
var lob_max := 0.0
var lob_peak := 0.0
var _lob_t := 0.0
var _lob_base := 0.0


static func create(st: Stage, sheet: String, p: Vector2, v: Vector2, t: int) -> Projectile:
	var pr := Projectile.new()
	pr.stage = st
	pr.pos = p
	pr.vel = v
	pr.team = t
	if sheet != "":
		pr.sprite = PixelSprite.new()
		pr.add_child(pr.sprite)
		pr.sprite.setup(sheet)
	st.add_projectile(pr)
	pr._sync()
	return pr


func with_light(col: Color, energy := 0.8, rng := 2.5) -> Projectile:
	light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = energy
	light.omni_range = rng
	light.position = Vector3(0, 0.3, 0)
	add_child(light)
	return self


## Makes this a lobbed shot: it arcs up to `peak` and comes down after `flight`.
func lob(flight: float, peak: float) -> Projectile:
	lob_max = flight
	lob_peak = peak
	life = flight
	_lob_base = height
	return self


func tick(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		_end()
		return
	if lob_max > 0.0:
		_lob_t += dt
		var k := clampf(_lob_t / lob_max, 0.0, 1.0)
		pos += vel * dt
		height = lerpf(_lob_base, 0.0, k) + 4.0 * lob_peak * k * (1.0 - k)
		if trail_rate > 0.0:
			_trail_t += dt
			while _trail_t > 1.0 / trail_rate:
				_trail_t -= 1.0 / trail_rate
				stage.fx.burst(pos, height, trail_color, 1, 0.3, 0.4, 0.0, -vel, 0.6, 0.3)
		_sync()
		return
	if homing_target and is_instance_valid(homing_target) and homing_target.alive and homing_turn > 0.0:
		var want := (homing_target.pos - pos).normalized() * vel.length()
		vel = vel.lerp(want, clampf(homing_turn * dt, 0.0, 1.0)).normalized() * vel.length()
	var step := vel * dt
	var n := maxi(1, int(ceil(step.length() / 0.2)))
	for i in n:
		pos += step / n
		if stage.grid.blocks_shot(floori(pos.x), floori(pos.y)):
			_impact_wall()
			return
		if _check_hits():
			return
	if trail_rate > 0.0:
		_trail_t += dt
		while _trail_t > 1.0 / trail_rate:
			_trail_t -= 1.0 / trail_rate
			stage.fx.burst(pos, height, trail_color, 1, 0.4, 0.3, 0.0, -vel, 0.6, 0.3)
	_sync()


func _check_hits() -> bool:
	# the shooter may have died while this was in flight
	if not is_instance_valid(source):
		source = null
	if team == Actor.Team.PLAYER:
		for pr in stage.props:
			if is_instance_valid(pr) and pr.breakable and not pr.used and pr.pos.distance_to(pos) <= radius + pr.strike_radius:
				pr.on_struck(source, tags.has("fire"))
				if pr.stops_shots:
					_end()
					return true
	# the player's ward / aegis can turn enemy shots around
	if team == Actor.Team.ENEMY:
		var pl := stage.player
		if pl and pl.alive and pl.pos.distance_to(pos) <= radius + pl.radius + 0.15:
			if reflectable and pl.try_reflect(self):
				return false
	for a in stage.hostiles(team):
		if hit_set.has(a.get_instance_id()):
			continue
		if a.pos.distance_to(pos) <= radius + a.radius:
			hit_set[a.get_instance_id()] = true
			var res: Combat.Result = null
			if a is Player and team == Actor.Team.ENEMY:
				res = (a as Player).take_enemy_hit(_build_hit(a), source)
			elif source is Player:
				res = (source as Player).deal_hit(a, _build_hit(a))
			else:
				res = a.take_hit(_build_hit(a))
			if on_hit_fn.is_valid():
				on_hit_fn.call(self, a, res)
			if pierce <= 0:
				_end()
				return true
			pierce -= 1
	return false


func _build_hit(target: Actor) -> Hit:
	if make_hit_fn.is_valid():
		return make_hit_fn.call(self, target)
	var h := Hit.make(source, damage, tags.duplicate())
	h.burn = burn
	h.chill = chill
	h.knockback = vel.normalized() * knockback
	h.from_dir = vel.normalized()
	h.can_crit = source is Player
	h.poise = damage * 0.5
	if source is Player:
		var st: Stats = (source as Player).stats
		h.crit_chance = st.v("crit_chance")
		h.crit_mult = st.v("crit_mult")
	return h


## Turns the projectile around for the player's team.
func reflect(by: Actor, mult: float, extra_pierce: int) -> void:
	reflected = true
	team = by.team
	source = by
	var target := stage.nearest_hostile(team, pos, 14.0, true)
	var dir := (target.pos - pos).normalized() if target else -vel.normalized()
	vel = dir * vel.length() * 1.5
	damage *= mult
	pierce += extra_pierce
	life = 2.0
	hit_set.clear()
	tags = ["ranged", "reflected"]
	trail_color = Color(1.0, 0.85, 0.4)
	trail_rate = maxf(trail_rate, 30.0)
	if sprite:
		sprite.set_instance_shader_parameter("flash", Color(1.0, 0.8, 0.35, 0.8))
	if light:
		light.light_color = Color(1.0, 0.7, 0.35)


func _impact_wall() -> void:
	stage.fx.burst(pos - vel.normalized() * 0.15, height, trail_color, 6, 2.5, 0.35, 5.0, -vel, 1.2)
	_end()


func _end() -> void:
	if on_end_fn.is_valid():
		on_end_fn.call(self, pos)
		on_end_fn = Callable()
	stage.remove_projectile(self)
	queue_free()


func _sync() -> void:
	var sx := roundf(pos.x * Iso.PPU) / Iso.PPU
	var sy := roundf(pos.y * Iso.PPU) / Iso.PPU
	position = Iso.to_world(Vector2(sx, sy), 0.0)
	if sprite:
		sprite.position = Vector3(0, height * Iso.SQ2, 0)
		if spin:
			sprite.basis = Iso.screen_basis(Iso.screen_angle(vel))
		else:
			sprite.flip_h = vel.x < 0.0
