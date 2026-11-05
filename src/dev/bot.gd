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
## Scaling evaluation (src/dev/scaling_eval.gd): fight and explore only - no
## chests, altars, shrines or stairs, which would open screens or end the floor.
var eval_mode := false


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


## Dev (`botcharge`): every third attack is held for a charged attack or a
## stance (to see and test the weapon forms' held moves).
var _hold_t := -1.0
var _attacks := 0


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
		print("[bot] fps=%d actors=%d particles=%d t=%.0f hp=%d/%d kindle=%d room=%s kills=%d embers=%d pos=%s goal=%s active=%s enemies=%d" % [Engine.get_frames_per_second(), pl.stage.actors.size(), pl.stage.fx._p_count, _t, int(pl.hp), int(pl.max_hp), int(pl.kindle), str(d.current_room.id) if d and d.current_room else "-", d.run.kills if d else 0, d.run.embers if d else 0, str(pl.pos.snapped(Vector2(0.1, 0.1))), str(_goal.snapped(Vector2(0.1, 0.1))), str(d.active_room.id) if d and d.active_room else "-", d.room_enemies.size() if d else 0])
		# the last foes of a room, to diagnose a bot that cannot finish one
		if d and d.room_enemies.size() in [1, 2]:
			for e in d.room_enemies:
				if is_instance_valid(e):
					print("[bot]   foe %s%s state=%s pos=%s hp=%d/%d" % [e.id, " (elite %s %s)" % [e.affix, e.affix2] if e.elite else "", e.state, str(e.pos.snapped(Vector2(0.1, 0.1))), int(e.hp), int(e.max_hp)])
	if pl.hearthcall_t >= 0.0:
		pl.move_in = Vector2.ZERO     # the ritual needs stillness (moving breaks it)
		return
	var target := _pick_target()
	# boss phase 2: relight the braziers to sear the Warden
	for a in pl.stage.actors:
		var warden_window: bool = a is Enemy and a.def.get("boss", false) and a.get("phase") == 2 and a.get("seared_t") != null and a.get("seared_t") <= 0.0
		var bloom_roots: bool = a is Enemy and a.id == "bloom"
		if warden_window or bloom_roots:
			for b in a.get("braziers"):
				if is_instance_valid(b) and ((b.kind == "boss_brazier" and not b.lit) or (b.kind == "root_node" and not b.used)):
					_goal = b.pos
					pl.aim_point = b.pos
					pl.aim = (b.pos - pl.pos).normalized()
					if b.pos.distance_to(pl.pos) > 1.6:
						pl.move_in = (pl.stage.path_step(pl.pos, b.pos) - pl.pos).normalized()
					else:
						pl.move_in = Vector2.ZERO
						pl.press("attack")
						pl._release_pending = true
					return
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
			# (the dump runs full path searches: a ~0.2s stall of the bot's own,
			# not the game's - ignore it in perflog measurements)
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
		pl.press("flask")


func _pick_target() -> Actor:
	# a person breaks the seals first: their foes are warded until then
	if pl.stage is Dungeon and (pl.stage as Dungeon).seals_up() > 0:
		for s in (pl.stage as Dungeon)._seals:
			if is_instance_valid(s) and s.alive:
				return s
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


func _fight(t: Actor, delta: float) -> void:
	var st := pl.stage
	var d := t.pos.distance_to(pl.pos)
	pl.aim_point = t.pos
	pl.aim = (t.pos - pl.pos).normalized()
	var ranged := pl.weapon and ["staff", "bow", "tome"].has(pl.weapon.id)
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
	if _hold_t >= 0.0:
		# holding: keep aiming at it until the hold is done
		_hold_t -= delta
		pl.aim = to
		pl.aim_point = t.pos
		if _hold_t < 0.0:
			pl._attack_down = false
			pl._release_pending = true
	elif d < want + 0.6:
		_attacks += 1
		pl.press("attack")
		if "botcharge" in Dev.args() and _attacks % 3 == 0:
			pl._attack_down = true
			_hold_t = 1.35
		else:
			pl._release_pending = true
	# dodge threats: enemies winding up close by, or projectiles inbound
	if _dodge_cd <= 0.0:
		for a in st.hostiles(pl.team):
			if a is Enemy and (a as Enemy).state in WINDUPS and a.pos.distance_to(pl.pos) < 4.5:
				var e := a as Enemy
				if e.state_t > 0.25:
					pl.move_in = (pl.pos - a.pos).normalized().rotated(randf_range(-1.0, 1.0))
					pl.press("dodge")
					_dodge_cd = 0.7
					break
		for p in st.projectiles:
			if is_instance_valid(p) and p.team != pl.team and p.pos.distance_to(pl.pos) < 2.2:
				if randf() < 0.5 and pl.ward_cd <= 0.0:
					pl.press("ward")
				else:
					pl.move_in = p.vel.normalized().orthogonal()
					pl.press("dodge")
				_dodge_cd = 0.6
				break
	# spells: each when it suits what it does (all three slots)
	for i in pl.ability_slots.size():
		var id: String = pl.ability_slots[i]
		if id == "orb" and pl.cast_t <= 0.0:
			# a Cinder Orb drifting beside a foe: burst it (the second cast)
			for o in Abilities.live_orbs(pl):
				if st.nearest_hostile(pl.team, o.pos, 1.8) != null:
					pl.press("a%d" % (i + 1))
					break
		if id == "" or i >= pl.ability_cd.size() or pl.ability_cd[i] > 0.0 or not pl.slot_open(i):
			continue
		var cost: float = GearDB.ability(id).cost * pl.stats.v("ability_cost")
		if pl.kindle < cost:
			continue
		var use := d < 3.5
		match id:
			"knives", "cinder_lance", "frost_sigil":
				use = d < 7.0
			"rush", "gloamstep":
				use = d > 2.5 and d < 6.0
			"lantern", "aegis", "wisp":
				use = d < 6.0
			"beam", "orb":
				use = d < 7.0
			"rimewall":
				use = d < 5.0 and d > 2.0
			"hearthfire":
				use = d < 3.5
			"rekindle":
				use = d < 5.0 and (pl.hp < pl.max_hp * 0.6 or st.players.any(func(o): return o != pl and o.downed and o.pos.distance_to(pl.pos) < 4.0))
		if use:
			pl.press("a%d" % (i + 1))
			break


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
			if is_instance_valid(p) and p.room_id == (d.current_room.id if d.current_room else -2) and p.interactable() and not p.data.get("sealed", false) and p.kind in ["relic_altar", "chest", "spring", "ember_pile", "fountain", "ember_well", "trial_altar", "echo", "sconce", "lost_camp", "landmark"]:
				best_p = p.pos
				if p.pos.distance_to(pl.pos) < p.interact_radius + 0.6:
					_use(p, pl)
				break
	if best_p == Vector2.INF and d:
		best_p = _next_room_point(d)
	if best_p == Vector2.INF:
		pl.move_in = Vector2.ZERO
		return
	_goal = best_p
	pl.move_in = (st.path_step(pl.pos, best_p) - pl.pos).normalized()
	if "botdebug" in Dev.args() and Engine.get_process_frames() % 30 == 0:
		print("[botdbg] pos=%s goal=%s step=%s pickups=%d" % [pl.pos.snapped(Vector2(0.1, 0.1)), best_p.snapped(Vector2(0.1, 0.1)), st.path_step(pl.pos, best_p).snapped(Vector2(0.1, 0.1)), st.pickups.size()])
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
							_use(p, pl)
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


## Co-op client: props belong to the host, so the bot asks like a player would.
func _use(p: Prop, pl: Player) -> void:
	if eval_mode:
		return
	if pl.controller == Player.Ctrl.REPLICA:
		pl.try_interact()
	else:
		p.interact(pl)
