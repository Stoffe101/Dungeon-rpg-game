## Autopilot for automated playtests (dev only). Drives the player like a
## mediocre-but-persistent human: fights the nearest foe, dodges telegraphs,
## uses abilities and the flask, grabs loot, explores unvisited rooms, takes
## the stairs and fights the boss. Enable with `-- autopilot`.
class_name Bot
extends Node

const WINDUPS := ["windup", "bash_windup", "charge_windup", "sweep_windup", "aim", "rush_windup", "thrust_windup", "quake_crouch", "fuse", "quake_air"]

var pl: Player
var _t := 0.0
var _dodge_cd := 0.0
var _strafe := 1.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _jitter := Vector2.ZERO
var log_every := 5.0
var _log_t := 0.0
var _goal := Vector2.ZERO
var _stuck_total := 0.0
var _dumped := false


func _dump_area() -> void:
	var g := pl.stage.grid
	var c := Vector2i(pl.pos)
	print("[bot] STUCK at ", pl.pos, " goal ", _goal, " step ", pl.stage.path_step(pl.pos, _goal))
	var a := Vector2i(floori(pl.pos.x), floori(pl.pos.y))
	var b := Vector2i(floori(_goal.x), floori(_goal.y))
	print("[bot] start solid=", pl.stage.astar.is_point_solid(a), " goal solid=", pl.stage.astar.is_point_solid(b), " path len=", pl.stage.astar.get_id_path(a, b).size(), " partial=", pl.stage.astar.get_id_path(a, b, true).size())
	var chars := {0: " ", 1: ".", 2: "#", 3: "P", 4: "~", 5: "G", 6: "o"}
	for y in range(c.y - 8, c.y + 5):
		var line := ""
		for x in range(c.x - 14, c.x + 15):
			line += "@" if Vector2i(x, y) == c else chars.get(g.at(x, y), "?")
		print("[bot] ", line)


func _ready() -> void:
	pl = get_parent() as Player
	pl.autopilot = true


func _process(delta: float) -> void:
	if pl == null or not pl.alive or get_tree().paused:
		return
	var st := pl.stage
	_t += delta
	_dodge_cd -= delta
	_log_t += delta
	if _log_t > log_every:
		_log_t = 0.0
		var d := st as Dungeon
		print("[bot] t=%.0f hp=%d/%d kindle=%d room=%s kills=%d embers=%d pos=%s goal=%s active=%s enemies=%d" % [_t, int(pl.hp), int(pl.max_hp), int(pl.kindle), str(d.current_room.id) if d and d.current_room else "-", d.run.kills if d else 0, d.run.embers if d else 0, str(pl.pos.snapped(Vector2(0.1, 0.1))), str(_goal.snapped(Vector2(0.1, 0.1))), str(d.active_room.id) if d and d.active_room else "-", d.room_enemies.size() if d else 0])
	var target := _pick_target()
	if target:
		_fight(target, delta)
	else:
		_explore(delta)
	# unstick
	if pl.pos.distance_to(_last_pos) < 0.02 and pl.move_in.length() > 0.1:
		_stuck_t += delta
		_stuck_total += delta
		if _stuck_total > 6.0 and target == null:
			_stuck_total = -20.0
			_dump_area()
		if _stuck_t > 0.8:
			_jitter = Vector2.from_angle(randf() * TAU)
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
		_stuck_total = maxf(0.0, _stuck_total - delta)
	_last_pos = pl.pos
	if _jitter != Vector2.ZERO:
		pl.move_in = (pl.move_in + _jitter).normalized()
		_jitter = _jitter * 0.9 if _jitter.length() > 0.1 else Vector2.ZERO
	if pl.hp_ratio() < 0.4 and pl.flask > 0:
		pl._buf.flask = 0.1


func _pick_target() -> Actor:
	var best: Actor = null
	var bd := 18.0
	for a in pl.stage.hostiles(pl.team):
		if a is Hub.TrainingDummy:
			continue
		if a is Enemy and (a as Enemy).state == "spawn":
			continue
		var d := a.pos.distance_to(pl.pos)
		if d < bd and pl.stage.grid.line_clear(pl.pos, a.pos):
			bd = d
			best = a
	return best


func _fight(t: Actor, _delta: float) -> void:
	var st := pl.stage
	var d := t.pos.distance_to(pl.pos)
	pl.aim_point = t.pos
	pl.aim = (t.pos - pl.pos).normalized()
	var ranged := pl.weapon and pl.weapon.id == "staff"
	var want := 6.0 if ranged else 1.4
	var to := (t.pos - pl.pos).normalized()
	if d > want + 0.3:
		pl.move_in = (st.path_step(pl.pos, t.pos) - pl.pos).normalized()
	elif d < want * 0.5 and ranged:
		pl.move_in = -to
	else:
		pl.move_in = to.orthogonal() * _strafe * 0.4
		if randf() < 0.01:
			_strafe = -_strafe
	if d < want + 0.6:
		pl._buf.attack = 0.1
		pl._release_pending = true
	# dodge threats: enemies winding up close by, or projectiles inbound
	if _dodge_cd <= 0.0:
		for a in st.hostiles(pl.team):
			if a is Enemy and (a as Enemy).state in WINDUPS and a.pos.distance_to(pl.pos) < 4.5:
				var e := a as Enemy
				if e.state_t > 0.25:
					pl.move_in = (pl.pos - a.pos).normalized().rotated(randf_range(-1.0, 1.0))
					pl._buf.dodge = 0.1
					_dodge_cd = 0.7
					break
		for p in st.projectiles:
			if is_instance_valid(p) and p.team != pl.team and p.pos.distance_to(pl.pos) < 2.2:
				if randf() < 0.5 and pl.ward_cd <= 0.0:
					pl._buf.ward = 0.1
				else:
					pl.move_in = p.vel.normalized().orthogonal()
					pl._buf.dodge = 0.1
				_dodge_cd = 0.6
				break
	# abilities
	for i in 2:
		var id: String = pl.ability_slots[i] if i < pl.ability_slots.size() else ""
		if id == "" or pl.ability_cd[i] > 0.0:
			continue
		var cost: float = GearDB.ability(id).cost * pl.stats.v("ability_cost")
		if pl.kindle >= cost and d < 3.5:
			pl._buf["a1" if i == 0 else "a2"] = 0.1


func _explore(_delta: float) -> void:
	var st := pl.stage
	# loot first
	var best_p: Vector2 = Vector2.INF
	for pk in st.pickups:
		if is_instance_valid(pk) and pk.pos.distance_to(pl.pos) < 10.0 and (pk.kind != "heal" or pl.hp < pl.max_hp):
			if best_p == Vector2.INF or pk.pos.distance_to(pl.pos) < best_p.distance_to(pl.pos):
				best_p = pk.pos
	var d := st as Dungeon
	if best_p == Vector2.INF and d:
		for p in st.props:
			if is_instance_valid(p) and p.room_id == (d.current_room.id if d.current_room else -2) and p.interactable() and p.kind in ["relic_altar", "chest", "spring", "ember_pile", "fountain"]:
				best_p = p.pos
				if p.pos.distance_to(pl.pos) < p.interact_radius + 0.6:
					p.interact(pl)
				break
	if best_p == Vector2.INF and d:
		best_p = _next_room_point(d)
	if best_p == Vector2.INF:
		pl.move_in = Vector2.ZERO
		return
	_goal = best_p
	pl.move_in = (st.path_step(pl.pos, best_p) - pl.pos).normalized()
	pl.aim_point = best_p
	pl.aim = pl.move_in if pl.move_in != Vector2.ZERO else pl.aim


func _next_room_point(d: Dungeon) -> Vector2:
	var cur := d.current_room
	if cur == null:
		return Vector2.INF
	# stairs / hearthstone when everything is explored (or 60% explored and hurt)
	var visited := 0
	for r in d.layout.rooms:
		if r.visited:
			visited += 1
	var done := visited >= d.layout.rooms.size() - 1
	if done or d.run.elapsed > 600.0:
		for p in d.props:
			if is_instance_valid(p) and p.kind in ["stairs", "hearthstone"]:
				if p.room_id == cur.id or p.kind == "hearthstone":
					if p.pos.distance_to(pl.pos) < p.interact_radius + 0.8:
						if p.kind == "stairs" or p.data.get("victory", false):
							p.interact(pl)
					return p.pos
	# go through a door toward the nearest unvisited room (BFS over doors)
	var dist := {cur.id: 0}
	var first := {cur.id: null}
	var q := [cur.id]
	while not q.is_empty():
		var rid: int = q.pop_front()
		var r := d.layout.room(rid)
		if not r.visited:
			var dd: Variant = first[rid]
			if dd is Dictionary:
				var c := Vector2.ZERO
				for t: Vector2i in dd.tiles:
					c += Vector2(t) + Vector2(0.5, 0.5)
				c /= dd.tiles.size()
				return c + Vector2(dd.dir) * 5.5
		for door in r.doors:
			if door.secret:
				continue
			var o: Room = d.layout.room(door.to)
			if o.type == Room.Type.BOSS and not done:
				continue
			if not dist.has(o.id):
				dist[o.id] = dist[rid] + 1
				first[o.id] = door if rid == cur.id else first[rid]
				q.append(o.id)
	# everything visited: head for the exit room
	var ex := d.layout.room(d.layout.exit_id)
	return ex.center()
