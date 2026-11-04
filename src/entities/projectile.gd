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
# the Kindled's projectile modifiers (see Volley)
var chain := 0                # leaps left to the next foe
var fork := 0                 # splits left (on a first hit)
var returning := false        # flies back to its shooter, striking again
var group: Dictionary = {}    # shared by a volley: a foe is struck by one of its shots only
var _back := false            # on the way back
var sprite: PixelSprite
var light: OmniLight3D
var spin := false
var phasing := false          # passes through walls (orbiting glyphs)
var net_id := 0
var replica := false
var _announced := false
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


## Co-op host: tell the clients once its flight is set up (callers configure a
## projectile after create(), so the first tick is when it is complete).
func _announce() -> void:
	_announced = true
	if not Net.recording or Net.i.run_sync == null:
		return
	net_id = Net.i.run_sync.next_proj_id()
	Net.rec(["proj+", [net_id, sprite.sheet.name if sprite else "", pos, vel, height, team, spin, lob_max, lob_peak,
		light.light_color if light else null, trail_color, trail_rate]])


## Co-op client: fly where the host's shot flies (no hits here).
func replica_step(dt: float) -> void:
	if lob_max > 0.0:
		_lob_t += dt
		var k := clampf(_lob_t / lob_max, 0.0, 1.0)
		height = lerpf(_lob_base, 0.0, k) + 4.0 * lob_peak * k * (1.0 - k)
	pos += vel * dt
	if trail_rate > 0.0:
		_trail_t += dt
		while _trail_t > 1.0 / trail_rate:
			_trail_t -= 1.0 / trail_rate
			stage.fx.burst(pos, height, trail_color, 1, 0.4, 0.3, 0.0, -vel, 0.6, 0.3)
	_sync()


func tick(dt: float) -> void:
	if not _announced:
		_announce()
	life -= dt
	if life <= 0.0:
		if returning and not _back:
			_turn_back()
		else:
			_end()
			return
	if _back:
		_fly_back(dt)
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
		if not phasing and stage.grid.blocks_shot(floori(pos.x), floori(pos.y)):
			if returning and not _back:
				pos -= step / n
				_turn_back()
				_sync()
				return
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
	if team == Actor.Team.ENEMY and reflectable:
		for pl in stage.players_near(pos, radius + 0.15):
			if pl.try_reflect(self):
				return false
	for a in stage.hostiles(team):
		var aid := a.get_instance_id()
		if hit_set.has(aid):
			continue
		if not _back and not group.is_empty() and group.has(aid):
			continue    # another shot of this volley struck it
		if a.pos.distance_to(pos) <= radius + a.radius:
			hit_set[aid] = true
			if not group.is_empty():
				group[aid] = true
			var res: Combat.Result = null
			if a is Player and team == Actor.Team.ENEMY:
				res = (a as Player).take_enemy_hit(_build_hit(a), source)
			elif source is Player:
				res = (source as Player).deal_hit(a, _build_hit(a))
			else:
				res = a.take_hit(_build_hit(a))
			if on_hit_fn.is_valid():
				on_hit_fn.call(self, a, res)
			if fork > 0:
				_fork_from(a)
			if chain > 0 and _chain_from(a):
				return false
			if pierce <= 0:
				if returning and not _back:
					_turn_back(a)
					return false
				_end()
				return true
			pierce -= 1
	return false


## Chain: on to the nearest foe this shot has not struck (in sight, close).
func _chain_from(_from: Actor) -> bool:
	var best: Actor = null
	var bd := 7.0
	for a in stage.hostiles(team):
		if hit_set.has(a.get_instance_id()) or not a.targetable:
			continue
		var d := a.pos.distance_to(pos)
		if d < bd and stage.grid.line_clear(pos, a.pos):
			bd = d
			best = a
	if best == null:
		return false
	chain -= 1
	vel = (best.pos - pos).normalized() * vel.length()
	life = maxf(life, bd / maxf(vel.length(), 0.1) + 0.15)
	stage.fx.burst(pos, height, trail_color, 4, 2.0, 0.2, 0.0, vel, 0.5)
	return true


## Fork: two shots split off the first foe struck, each at half strength.
func _fork_from(a: Actor) -> void:
	fork = 0
	for s in [-0.45, 0.45]:
		var f := Projectile.create(stage, sprite.sheet.name if sprite else "", pos, vel.rotated(s), team)
		f.source = source
		f.damage = damage * 0.5
		f.tags = tags.duplicate()
		f.radius = radius
		f.height = height
		f.life = 0.55
		f.chain = chain
		f.burn = burn
		f.chill = chill
		f.knockback = knockback * 0.5
		f.spin = spin
		f.reflectable = false
		f.make_hit_fn = make_hit_fn
		f.trail_color = trail_color
		f.trail_rate = trail_rate * 0.5
		f.hit_set[a.get_instance_id()] = true


## Return: about face, toward whoever loosed it; it can strike everything again
## on the way home - except the foe it just turned on (no double blow).
func _turn_back(off: Actor = null) -> void:
	if source == null or not is_instance_valid(source) or not (source is Actor):
		_end()
		return
	_back = true
	hit_set.clear()
	if off:
		hit_set[off.get_instance_id()] = true
	pierce = 99
	life = 3.0
	vel = ((source as Actor).pos - pos).normalized() * maxf(vel.length(), 12.0)


func _fly_back(dt: float) -> void:
	if source == null or not is_instance_valid(source) or not (source as Actor).alive:
		_end()
		return
	var to: Vector2 = (source as Actor).pos - pos
	if to.length() < 0.5:
		_end()
		return
	vel = to.normalized() * vel.length()
	var step := vel * dt
	var n := maxi(1, int(ceil(step.length() / 0.2)))
	for i in n:
		pos += step / n
		if _check_hits():
			return
	if trail_rate > 0.0:
		_trail_t += dt
		while _trail_t > 1.0 / trail_rate:
			_trail_t -= 1.0 / trail_rate
			stage.fx.burst(pos, height, trail_color, 1, 0.4, 0.3, 0.0, -vel, 0.6, 0.3)
	_sync()


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
	if net_id != 0 and Net.recording:
		Net.rec(["proj-", net_id])
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
