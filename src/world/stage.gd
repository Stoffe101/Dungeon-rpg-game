## A playable space (sanctuary or dungeon floor). Owns the tile grid, every
## actor and projectile, and drives the simulation with its own clock so
## hitstop and slow motion never touch UI or audio.
class_name Stage
extends Node3D

signal actor_died(actor: Actor, killer: Node)

var grid: TileGrid
var view: PixelView
var fx: Fx
var player: Player          # the Kindled this machine controls (camera, HUD)
var players: Array[Player] = []   # every Kindled on the stage (co-op: up to four)
var actors: Array[Actor] = []
var projectiles: Array = []
var interactables: Array = []
var hazards: Array = []
var pickups: Array = []
var props: Array = []
var astar: AStarGrid2D
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var paused_sim := false
var replica := false          # co-op client: draws the host's floor, simulates nothing
var interactor: Player        # who is using a prop right now (co-op: not always this machine's)
var _prop_seq := 0            # the next prop's index (the same on every machine)

var _timers: Array = []   # [time_left, Callable]
var _hitstop := 0.0
var _slow_t := 0.0
var _slow_scale := 1.0


func setup(g: TileGrid, v: PixelView) -> void:
	grid = g
	view = v
	fx = Fx.new()
	fx.name = "Fx"
	fx.view = v
	add_child(fx)
	rebuild_nav()
	if Net.i:
		Net.i.sheet_changed.connect(_on_sheet_changed)


## Co-op: a party member changed what they wear or wield: redraw their Kindled here.
func _on_sheet_changed(pid: int) -> void:
	if not Net.active() or pid == Net.my_id() or not Net.i.roster.has(pid):
		return
	for pl in players:
		if is_instance_valid(pl) and pl.peer_id == pid and pl != player:
			pl.apply_sheet(Net.i.roster[pid].get("sheet", {}))


func rebuild_nav() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid.width, grid.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in grid.height:
		for x in grid.width:
			if grid.at(x, y) != TileGrid.FLOOR:
				astar.set_point_solid(Vector2i(x, y), true)


func set_tile_solid(t: Vector2i, solid: bool) -> void:
	if astar and astar.is_in_boundsv(t):
		astar.set_point_solid(t, solid)


# --- time ---------------------------------------------------------------------

## In a shared expedition the world's clock belongs to everyone: one Kindled's
## blow cannot freeze or slow it for the others (and each client predicts its
## own Kindled against that steady clock).
func shared_clock() -> bool:
	return Net.active() and Net.party_size() > 1

func hitstop(seconds: float) -> void:
	if not Settings.get_value("hitstop", true) or shared_clock():
		return
	_hitstop = maxf(_hitstop, seconds)


func slow_motion(scale: float, seconds: float) -> void:
	if shared_clock():
		return
	_slow_scale = scale
	_slow_t = maxf(_slow_t, seconds)


func _process(delta: float) -> void:
	var real := minf(delta, 1.0 / 20.0)
	var dt := real
	if _hitstop > 0.0:
		_hitstop -= real
		dt = 0.0
	if _slow_t > 0.0:
		_slow_t -= real
		dt *= _slow_scale
	if paused_sim:
		dt = 0.0
	var t_sim := Dev.tick()
	if dt > 0.0:
		simulate(dt)
	Dev.lap("simulate", t_sim)
	var t_fx := Dev.tick()
	fx.step(real if not paused_sim else 0.0)
	Dev.lap("fx", t_fx)
	if view and player and is_instance_valid(player):
		var target := Iso.to_world(player.pos + player.draw_off + player.aim_offset(), 0.0)
		if _look_t > 0.0:
			# something worth seeing: the camera leans most of the way toward it
			_look_t -= real
			var w := clampf(minf(_look_t, _look_len - _look_t) / 0.35, 0.0, 1.0) * 0.6
			target = target.lerp(Iso.to_world(_look_at, 0.0), w)
		view.focus = view.focus.lerp(target, 1.0 - exp(-real * 9.0)) if view.focus.distance_to(target) < 12.0 else target
	_stage_process(real)


var _look_at := Vector2.ZERO
var _look_t := 0.0
var _look_len := 1.0


## The camera leans toward `p` for `seconds`, then back to the Kindled (a
## guardian's arrival). This machine's view only; a host sends it on.
func look_toward(p: Vector2, seconds: float) -> void:
	if Net.recording:
		Net.rec(["look", p, seconds])
	_look_at = p
	_look_t = seconds
	_look_len = seconds


## Runs `fn` after `seconds` of simulation time (respects hitstop/slow-mo).
var dangers: Array = []     # blows being wound up: [where, until when] (HUD: off-screen chevrons)


func note_danger(at: Vector2, seconds: float, shape := {}) -> void:
	dangers = dangers.filter(func(d): return float(d[1]) >= elapsed)
	dangers.append([at, elapsed + seconds, elapsed, shape])


func after(seconds: float, fn: Callable) -> void:
	_timers.append([seconds, fn])


## A find's name rising over its finder. Several taken at once are named in
## turn, not printed on top of each other. Only ever the finder's own screen.
var _title_free := 0.0


func find_title(pl: Player, height: float, text: String, col: Color) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var wait := maxf(0.0, _title_free - now)
	_title_free = now + wait + 0.6
	if wait <= 0.0:
		fx.number(pl.pos, height, text, col, true)
		return
	get_tree().create_timer(wait, false).timeout.connect(func() -> void:
		if is_inside_tree() and is_instance_valid(pl):
			Net.mute += 1
			fx.number(pl.pos, height, text, col, true)
			Net.mute -= 1)


func simulate(dt: float) -> void:
	if replica:
		_replica_step(dt)
		return
	elapsed += dt
	if not _timers.is_empty():
		var due: Array = []
		for t in _timers:
			t[0] -= dt
			if t[0] <= 0.0:
				due.append(t)
		for t in due:
			_timers.erase(t)
			if t[1].is_valid():
				t[1].call()
	Audio.in_sim = true
	for a in actors.duplicate():
		if not is_instance_valid(a):
			continue
		if a.replica:
			a.replica_present(dt)     # another machine's Kindled (the shared sanctuary)
		elif a.alive:
			a.tick(dt)
	for p in projectiles.duplicate():
		if is_instance_valid(p):
			p.tick(dt)
	for h in hazards.duplicate():
		if is_instance_valid(h):
			h.tick(dt)
	for pk in pickups.duplicate():
		if is_instance_valid(pk):
			pk.tick(dt)
	for pr in props:
		if is_instance_valid(pr) and pr.ticks:
			pr.tick(dt)
	_separate()
	_stage_tick(dt)
	Audio.in_sim = false


## Co-op client: nothing is simulated here, only drawn where the host says.
func _replica_step(dt: float) -> void:
	elapsed += dt
	if not _timers.is_empty():
		var due: Array = []
		for t in _timers:
			t[0] -= dt
			if t[0] <= 0.0:
				due.append(t)
		for t in due:
			_timers.erase(t)
			if t[1].is_valid():
				t[1].call()
	for a in actors.duplicate():
		if is_instance_valid(a):
			a.replica_present(dt)
	for p in projectiles.duplicate():
		if is_instance_valid(p):
			p.replica_step(dt)
	for pk in pickups.duplicate():
		if is_instance_valid(pk):
			pk.replica_step(dt)


## Override in subclasses.
func _stage_tick(_dt: float) -> void:
	pass


func _stage_process(_real: float) -> void:
	pass


func _separate() -> void:
	var n := actors.size()
	for i in n:
		var a := actors[i]
		if not a.alive or a.ghost:
			continue
		for j in range(i + 1, n):
			var b := actors[j]
			if not b.alive or b.ghost:
				continue
			var d := b.pos - a.pos
			var rr := a.radius + b.radius
			var l2 := d.length_squared()
			if l2 >= rr * rr:
				continue
			var l := sqrt(l2)
			var nrm := d / l if l2 >= 0.00001 else Vector2.from_angle(float((i * 7 + j * 13) % 16) / 16.0 * TAU)
			# (two on the very same spot - a summon, a split - are parted too)
			var push := (rr - l) * 0.5
			# another machine's Kindled (the shared sanctuary) is moved by its owner
			# only: it eases a Kindled that stands in it aside, but never blocks
			# one that is walking (a crowd at a door must not wall anyone in)
			if (a.replica and b is Player and (b as Player).move_in.length() > 0.1) or (b.replica and a is Player and (a as Player).move_in.length() > 0.1):
				continue
			var wa := b.mass / (a.mass + b.mass)
			var wb := 1.0 - wa
			var a_fixed := a.anchored or a.replica
			var b_fixed := b.anchored or b.replica
			if a_fixed:
				wa = 0.0
				wb = 1.0
			if b_fixed:
				wb = 0.0
				wa = 1.0 if not a_fixed else 0.0
			a.pos = grid.move_box(a.pos, a.box(), -nrm * push * 2.0 * wa, a.flying)
			b.pos = grid.move_box(b.pos, b.box(), nrm * push * 2.0 * wb, b.flying)


# --- actors -------------------------------------------------------------------

func add_actor(a: Actor) -> void:
	a.stage = self
	actors.append(a)
	if a is Player and not players.has(a):
		players.append(a)
	add_child(a)
	if Net.recording and Net.i.run_sync:
		Net.i.run_sync.register_actor(a)


func remove_actor(a: Actor) -> void:
	actors.erase(a)
	if a is Player:
		players.erase(a)


## Players who are up and fighting (alive, not downed).
func active_players() -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if is_instance_valid(p) and p.alive and not p.downed and not p.away:
			out.append(p)
	return out


## The nearest active player to `p` (within `max_d`), or null.
func nearest_player(p: Vector2, max_d := INF) -> Player:
	var best: Player = null
	var bd := max_d
	for pl in active_players():
		var d := pl.pos.distance_to(p)
		if d < bd:
			bd = d
			best = pl
	return best


## Active players whose body is within `r` of `p`.
func players_near(p: Vector2, r: float) -> Array[Player]:
	var out: Array[Player] = []
	for pl in active_players():
		if pl.pos.distance_to(p) <= r + pl.radius:
			out.append(pl)
	return out


func notify_death(a: Actor, killer: Node) -> void:
	actor_died.emit(a, killer)


func register_hazard(h: Node) -> void:
	hazards.append(h)


func unregister_hazard(h: Node) -> void:
	hazards.erase(h)


func add_projectile(p: Node) -> void:
	projectiles.append(p)
	add_child(p)


func remove_projectile(p: Node) -> void:
	projectiles.erase(p)


func hostiles(team: int) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in actors:
		if a.alive and a.targetable and a.team != team and a.team != Actor.Team.NEUTRAL:
			out.append(a)
	return out


func in_circle(team: int, p: Vector2, r: float) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in hostiles(team):
		if a.pos.distance_to(p) <= r + a.radius:
			out.append(a)
	return out


func in_arc(team: int, p: Vector2, dir: Vector2, r: float, half_angle: float) -> Array[Actor]:
	var out: Array[Actor] = []
	var d := dir.normalized()
	for a in hostiles(team):
		var to := a.pos - p
		var dist := to.length()
		if dist > r + a.radius:
			continue
		if dist < a.radius + 0.3:
			out.append(a)
			continue
		var ang := absf(d.angle_to(to))
		# widen the arc by the target's angular size
		var slack := asin(clampf(a.radius / maxf(dist, 0.01), 0.0, 1.0))
		if ang <= half_angle + slack:
			out.append(a)
	return out


func in_line(team: int, a0: Vector2, a1: Vector2, width: float) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in hostiles(team):
		var q := Geometry2D.get_closest_point_to_segment(a.pos, a0, a1)
		if q.distance_to(a.pos) <= width + a.radius:
			out.append(a)
	return out


func nearest_hostile(team: int, p: Vector2, max_r := 99.0, need_los := false) -> Actor:
	var best: Actor = null
	var bd := max_r
	for a in hostiles(team):
		var d := a.pos.distance_to(p)
		if d < bd and (not need_los or grid.line_clear(p, a.pos)):
			bd = d
			best = a
	return best


## Next waypoint along a path from `from` to `to` (plane coords).
func path_step(from: Vector2, to: Vector2) -> Vector2:
	if grid.line_clear(from, to) and _clear_walk(from, to):
		return to
	var a := Vector2i(floori(from.x), floori(from.y))
	var b := Vector2i(floori(to.x), floori(to.y))
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return to
	if astar.is_point_solid(a):
		return to
	# a solid goal (a prop, a pillar) still yields a partial path to its edge
	var pts := astar.get_id_path(a, b, true)
	if pts.size() >= 2:
		var idx := mini(2, pts.size() - 1)
		# skip ahead while there is a straight walk
		for k in range(pts.size() - 1, 0, -1):
			var c := Vector2(pts[k]) + Vector2(0.5, 0.5)
			if k <= 4 and _clear_walk(from, c):
				idx = k
				break
		return Vector2(pts[idx]) + Vector2(0.5, 0.5)
	return to


func _clear_walk(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(ceil(d.length() * 3.0))
	for i in range(1, steps + 1):
		var p := a + d * (float(i) / maxf(steps, 1))
		if grid.at(floori(p.x), floori(p.y)) != TileGrid.FLOOR:
			return false
	return true


## Props that react to being struck (urns, braziers, cracked walls).
func strike_props(origin: Vector2, dir: Vector2, rng: float, half_angle: float, src: Node, fire := false) -> void:
	for pr in props.duplicate():
		if not is_instance_valid(pr) or not pr.breakable or pr.used:
			continue
		var to: Vector2 = pr.pos - origin
		var dist := to.length()
		if dist > rng + pr.strike_radius:
			continue
		if dist > 0.6 and absf(dir.angle_to(to)) > half_angle + 0.3:
			continue
		pr.on_struck(src, fire)


## Props along a line (a thrust, a rush, a beam).
func strike_props_line(a: Vector2, b: Vector2, width: float, src: Node, fire := false) -> void:
	var seg := b - a
	var len2 := maxf(seg.length_squared(), 0.0001)
	for pr in props.duplicate():
		if not is_instance_valid(pr) or not pr.breakable or pr.used:
			continue
		var t := clampf((pr.pos - a).dot(seg) / len2, 0.0, 1.0)
		if pr.pos.distance_to(a + seg * t) <= width + pr.strike_radius:
			pr.on_struck(src, fire)


func strike_props_circle(p: Vector2, r: float, src: Node, fire := false) -> void:
	for pr in props.duplicate():
		if is_instance_valid(pr) and pr.breakable and not pr.used and pr.pos.distance_to(p) <= r + pr.strike_radius:
			pr.on_struck(src, fire)


func nearest_interactable(p: Vector2, max_r := 1.6) -> Prop:
	var best: Prop = null
	var bd := max_r
	for pr in props:
		if not is_instance_valid(pr) or not pr.interactable():
			continue
		var d: float = pr.pos.distance_to(p) - pr.interact_radius
		if d < bd:
			bd = d
			best = pr
	return best


## The interactable under the mouse (`at`, plane coords) that a Kindled at
## `from` can reach, or null. Props are tall: the point may be on its body,
## a little north of where it stands.
func interactable_at(at: Vector2, from: Vector2, reach := 1.6) -> Prop:
	var best: Prop = null
	var bd := 1.0
	for pr in props:
		if not is_instance_valid(pr) or not pr.interactable():
			continue
		var d: float = minf(pr.pos.distance_to(at), (pr.pos + Vector2(0, -0.7)).distance_to(at))
		if d < bd and pr.pos.distance_to(from) - pr.interact_radius < reach:
			bd = d
			best = pr
	return best


## Hook for props asking the stage to open a UI or change flow.
func request(_what: String, _prop: Prop) -> void:
	pass


## Where a foe may appear near `p` (summons, splits, adds, hops): open floor
## near it. A Dungeon in a sealed fight keeps it inside the room (Dungeon.foe_spot).
func foe_spot(p: Vector2, r: float, _room_id := -1) -> Vector2:
	return random_floor_near(p, r)


func random_floor_near(p: Vector2, r: float, tries := 20) -> Vector2:
	for i in tries:
		var q := p + Vector2(randf_range(-r, r), randf_range(-r, r))
		var t := Vector2i(floori(q.x), floori(q.y))
		if grid.at(t.x, t.y) == TileGrid.FLOOR and not grid.box_blocked(Vector2(t) + Vector2(0.5, 0.5), 0.4):
			# a little off the tile's centre: two asked for near one spot do
			# not land exactly on each other (and stack, unpartable)
			var c := Vector2(t) + Vector2(0.5, 0.5)
			var j := c + Vector2(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
			return j if not grid.box_blocked(j, 0.3) else c
	return p
