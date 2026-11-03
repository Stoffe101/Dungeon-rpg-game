## One shared expedition floor. On the host it watches the simulation and sends
## the clients what they need to draw it (snapshots at 20 Hz, reliable events
## for everything that happens once); it also drives the remote Kindled from
## their owners' input. On a client it builds and moves the replicas.
class_name NetRun
extends Node

const SNAP_HZ := 20.0
const INPUT_HZ := 30.0
## What clients may not do themselves yet (they need a menu on the host).
const HOST_ONLY := ["merchant", "shrine", "ember_well", "trial_altar", "echo", "hearthstone"]

var stage: Dungeon
var host := false
var events: Array = []
var _snap_t := 0.0
var _in_t := 0.0
# host
var _last_presses := {}       # peer -> presses
var _last_held := {}          # peer -> attack held
var _prop_state := {}         # prop index -> last sent state
var _pick_pos := {}           # pickup id -> last sent position
# client
var replicas := {}            # net id -> Actor
var projs := {}               # net id -> Projectile
var picks := {}               # net id -> Pickup
var teles := {}               # telegraph id -> MeshInstance3D
var _goal := {}               # net id -> [pos, height]


func setup(st: Dungeon, as_host: bool) -> void:
	stage = st
	host = as_host
	name = "NetRun"
	Net.i.run_sync = self
	if host:
		Net.recording = true
		Events.banner.connect(_on_banner)
		Events.toast.connect(_on_toast)
		# everything already on the floor (built before this node) is announced
		for a in stage.actors:
			if a.net_id == 0:
				register_actor(a)
	else:
		Net.recording = false
		for a in stage.actors:
			if a is Player and a.net_id != 0:
				replicas[a.net_id] = a


func _exit_tree() -> void:
	if Net.i and Net.i.run_sync == self:
		Net.i.run_sync = null
	if host:
		Net.recording = false
		if Events.banner.is_connected(_on_banner):
			Events.banner.disconnect(_on_banner)
			Events.toast.disconnect(_on_toast)


func _on_banner(t: String, s: String) -> void:
	Net.rec(["banner", t, s])


func _on_toast(t: String, c: Color) -> void:
	Net.rec(["toast", t, c])


# --- host: watching the floor -------------------------------------------------------

var _next_id := 0


## Ids for shots, pickups and telegraphs (one counter; each has its own map).
func next_proj_id() -> int:
	_next_id += 1
	return _next_id


## Gives an actor its network id and tells the clients what it is.
func register_actor(a: Actor) -> void:
	if a.net_id == 0:
		_next_id += 1
		a.net_id = _next_id
	if a is Player:
		return    # every peer builds the party itself, ids by seat
	var d := {"pos": a.pos}
	if a is Enemy:
		var e := a as Enemy
		d.merge({"kind": "enemy", "id": e.id, "elite": e.elite, "affix": e.affix, "affix2": e.affix2,
			"grudge": e.grudge, "summoned": e.summoned, "spawn_t": e.spawn_t, "boss": e == stage.boss})
	else:
		d.merge({"kind": "other", "sheet": a.sprite.sheet.name if a.sprite else "", "radius": a.radius})
	Net.rec(["actor+", a.net_id, d])


func _process(delta: float) -> void:
	if not Net.active():
		return
	if host:
		_snap_t += delta
		if _snap_t >= 1.0 / SNAP_HZ:
			_snap_t = 0.0
			_capture_props()
			if not events.is_empty():
				Net.i.rpc("_events", events)
				events = []
			# small, compressed chunks: each fits one packet (no fragmenting)
			for chunk in _snapshot():
				var raw := var_to_bytes(chunk)
				Net.i.rpc("_snapz", raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size())
	else:
		_in_t += delta
		if _in_t >= 1.0 / INPUT_HZ:
			_in_t = 0.0
			_send_input()
		_smooth(delta)


## Floats rounded to 1/64 fit 32 bits exactly, which halves their size on the wire.
static func q(x: float) -> float:
	return roundf(x * 64.0) / 64.0


func _snapshot() -> Array:
	var acts: Array = []
	var pls: Array = []
	for a in stage.actors:
		if not is_instance_valid(a) or a.net_id == 0:
			continue
		var s := a.sprite
		var flags := (1 if a.alive else 0) | (2 if a.targetable else 0) | (4 if (a.visual == null or a.visual.visible) else 0)
		var sh := 0.0
		var shm := 0.0
		if a is Enemy:
			sh = (a as Enemy).shield
			shm = (a as Enemy).shield_max
		acts.append([a.net_id, q(a.pos.x), q(a.pos.y), q(a.height), q(a.bob), q(a.facing.x), q(a.facing.y),
			s.anim if s else "", s.frame_i if s else 0, q(a.hp), q(a.max_hp), q(sh), q(shm), flags])
		if a is Player:
			var p := a as Player
			var w := p.weapon
			pls.append([p.net_id, q(p.kindle), p.flask, q(p.ability_cd[0]), q(p.ability_cd[1]), q(p.dodge_charges),
				p.downed, q(p.bleed_t), q(p.revive_k), q(p.look.x), q(p.look.y), q(p.aim.x), q(p.aim.y),
				int(w.phase) if w else 0, q(w.swing) if w else 0.0, q(w.aim_dir.x) if w else 1.0, q(w.aim_dir.y) if w else 0.0, w.charged if w else false,
				p.hearthcall_t, p.run.embers if p.run else 0, p.run.sunshards if p.run else 0, p.run.relics if p.run else [],
				p.ward_t > 0.0, p.dodge_t > 0.0, p.run.xp_gained if p.run else 0])
	var prs: Array = []
	for pr in stage.projectiles:
		if is_instance_valid(pr) and pr.net_id != 0:
			prs.append([pr.net_id, q(pr.pos.x), q(pr.pos.y), q(pr.height)])
	var pks: Array = []
	for pk in stage.pickups:
		if is_instance_valid(pk) and pk.net_id != 0:
			var last: Variant = _pick_pos.get(pk.net_id)
			var cur := Vector3(pk.pos.x, pk.pos.y, pk.height)
			if last == null or (last as Vector3).distance_to(cur) > 0.01:
				_pick_pos[pk.net_id] = cur
				pks.append([pk.net_id, q(cur.x), q(cur.y), q(cur.z)])
	var chunks: Array = [{"a": acts.slice(0, 4), "pl": pls, "pr": prs, "pk": pks, "t": q(stage.run.elapsed)}]
	var i := 4
	while i < acts.size():
		chunks.append({"a": acts.slice(i, i + 8)})
		i += 8
	return chunks


## Props change rarely: send what changed (opened, lit, emptied, gone).
func _capture_props() -> void:
	for p in stage.props:
		if not is_instance_valid(p):
			continue
		var st := [p.sprite.anim if p.sprite else "", p.sprite.visible if p.sprite else true, p.lit, p.used,
			p.light.visible if p.light else false, p.data.get("taken", [])]
		if _prop_state.get(p.net_idx) != st:
			if _prop_state.has(p.net_idx):
				Net.rec(["prop", p.net_idx, st])
			_prop_state[p.net_idx] = st
	for idx in _prop_state.keys():
		var alive := false
		for p in stage.props:
			if is_instance_valid(p) and p.net_idx == idx:
				alive = true
				break
		if not alive:
			Net.rec(["prop", idx, null])
			_prop_state.erase(idx)


func on_input(peer: int, d: Dictionary) -> void:
	var pl := _player_of(peer)
	if pl == null or not pl.alive:
		return
	pl.move_in = (d.get("m", Vector2.ZERO) as Vector2).limit_length(1.0)
	var a: Vector2 = d.get("a", pl.aim)
	if a.length() > 0.1:
		pl.aim = a.normalized()
	pl.aim_point = d.get("ap", pl.aim_point)
	var held := bool(d.get("h", false))
	if bool(_last_held.get(peer, false)) and not held:
		pl._release_pending = true
	pl._attack_down = held
	_last_held[peer] = held
	var last: Dictionary = _last_presses.get(peer, {})
	var now: Dictionary = d.get("p", {})
	for k in now:
		if k != "interact" and int(now[k]) > int(last.get(k, 0)):
			pl.press(String(k))
	_last_presses[peer] = now.duplicate()


func on_ask(peer: int, kind: String, args: Array) -> void:
	var pl := _player_of(peer)
	if pl == null:
		return
	match kind:
		"interact":
			var p := _prop(int(args[0]))
			if p == null or not p.interactable() or pl.downed or not pl.alive:
				return
			if p.pos.distance_to(pl.pos) > p.interact_radius + 1.2:
				return
			if p.kind in HOST_ONLY:
				tell(pl, "Only the host can use that, for now.", Color(1.0, 0.75, 0.5))
				return
			stage.interactor = pl
			p.interact(pl)
			stage.interactor = null
		"relic":
			stage.coop_relic_pick(pl, int(args[0]), String(args[1]))


func on_peer_left(peer: int) -> void:
	var pl := _player_of(peer)
	if pl:
		Events.toast.emit("%s's light left the party." % Net.name_of(peer), Color(1.0, 0.6, 0.5))
		pl.alive = false
		stage.remove_actor(pl)
		pl.queue_free()


func _player_of(peer: int) -> Player:
	for p in stage.players:
		if p.peer_id == peer:
			return p
	return null


func _prop(idx: int) -> Prop:
	for p in stage.props:
		if is_instance_valid(p) and p.net_idx == idx:
			return p
	return null


## A line for one player only: on this machine, or sent to theirs.
func tell(pl: Player, text: String, col: Color) -> void:
	if pl.peer_id == Net.my_id():
		Events.toast.emit(text, col)
	else:
		Net.i.rpc_id(pl.peer_id, "_tell", text, col)


# --- client: drawing the floor ------------------------------------------------------

func _send_input() -> void:
	var pl := stage.player
	if pl == null:
		return
	Net.i.rpc_id(1, "_n_input", {"m": pl.move_in, "a": pl.aim, "ap": pl.aim_point, "h": pl._attack_down, "p": pl.presses})


func apply_events(evs: Array) -> void:
	for ev in evs:
		match String(ev[0]):
			"fx":
				stage.fx.callv(String(ev[1]), ev.slice(2))
			"snd":
				if ev[2] == null:
					Audio.play(String(ev[1]), float(ev[3]), float(ev[4]))
				else:
					Audio.play_at(String(ev[1]), ev[2], float(ev[3]), float(ev[4]))
			"actor+":
				_spawn_replica(int(ev[1]), ev[2])
			"die":
				var r = replicas.get(int(ev[1]))
				if is_instance_valid(r):
					replicas.erase(int(ev[1]))
					r.replica_die()
			"react":
				var r2 = replicas.get(int(ev[1]))
				if is_instance_valid(r2):
					r2.hit_react(ev[2], float(ev[3]))
					if r2.sprite:
						r2.sprite.flash(Color(1, 1, 1), 0.09)
			"proj+":
				_spawn_proj(ev[1])
			"proj-":
				var pr = projs.get(int(ev[1]))
				if is_instance_valid(pr):
					projs.erase(int(ev[1]))
					stage.remove_projectile(pr)
					pr.queue_free()
			"pick+":
				_spawn_pick(ev[1])
			"pick-":
				var pk = picks.get(int(ev[1]))
				if is_instance_valid(pk):
					picks.erase(int(ev[1]))
					stage.pickups.erase(pk)
					pk.queue_free()
			"prop+":
				var np := Prop.make(stage, String(ev[1]), ev[2], ev[3])
				np.room_id = int(ev[4])
			"prop":
				_apply_prop(int(ev[1]), ev[2])
			"gate":
				stage._set_gates(stage.layout.room(int(ev[1])), bool(ev[2]))
			"room":
				stage.visit_room(stage.layout.room(int(ev[1])))
			"tele":
				_tele(ev)
			"tele-":
				var t = teles.get(int(ev[1]))
				if is_instance_valid(t):
					stage.fx.release(t)
				teles.erase(int(ev[1]))
			"banner":
				Events.banner.emit(String(ev[1]), String(ev[2]))
			"toast":
				Events.toast.emit(String(ev[1]), ev[2])
			"boss":
				var b = replicas.get(int(ev[1]))
				if b:
					stage.boss = b as Enemy
					Events.boss_started.emit(b)
			"boss_down":
				Events.boss_defeated.emit(stage.boss)


func _spawn_replica(id: int, d: Dictionary) -> void:
	var a: Actor
	if String(d.kind) == "enemy":
		var def := EnemyDB.get_def(String(d.id))
		if def.is_empty():
			return
		var e: Enemy = load(def.script).new()
		e.configure(String(d.id))
		if bool(d.elite) and not (d.grudge as Dictionary).is_empty():
			e.make_grudge(d.grudge)
		elif bool(d.elite):
			e.make_elite(String(d.affix), String(d.affix2))
		e.summoned = bool(d.summoned)
		e.spawn_t = float(d.spawn_t)
		a = e
	else:
		var o := ReplicaActor.new()
		o.sheet_name = String(d.sheet)
		o.radius = float(d.radius)
		a = o
	a.net_id = id
	a.pos = d.pos
	a.replica = true
	stage.add_actor(a)
	replicas[id] = a
	_goal[id] = [a.pos, 0.0]
	if a is Enemy and bool(d.get("boss", false)):
		stage.boss = a


func _spawn_proj(d: Array) -> void:
	var pr := Projectile.create(stage, String(d[1]), d[2], d[3], int(d[5]))
	pr.net_id = int(d[0])
	pr.height = float(d[4])
	pr.spin = bool(d[6])
	pr.replica = true
	if float(d[7]) > 0.0:
		pr.lob(float(d[7]), float(d[8]))
	if d[9] != null:
		pr.with_light(d[9], 0.6, 2.0)
	pr.trail_color = d[10]
	pr.trail_rate = float(d[11])
	projs[pr.net_id] = pr


func _spawn_pick(d: Array) -> void:
	var owner := int(d[7])
	if owner != 0 and owner != Net.my_id():
		return    # someone else's find: not on this machine's floor
	var pk := Pickup.spawn(stage, String(d[1]), d[2], int(d[5]), d[6])
	pk.net_id = int(d[0])
	pk.vel = Vector2.ZERO
	pk.vz = 0.0
	pk.height = float(d[3])
	pk.owner_peer = owner
	pk.replica = true
	picks[pk.net_id] = pk


func _apply_prop(idx: int, st: Variant) -> void:
	var p := _prop(idx)
	if p == null:
		return
	if st == null:
		p.unsolid()
		stage.props.erase(p)
		p.queue_free()
		return
	var s: Array = st
	if p.sprite:
		if String(s[0]) != "" and p.sprite.has_anim(String(s[0])):
			p.sprite.play(String(s[0]))
		p.sprite.visible = bool(s[1])
	p.lit = bool(s[2])
	p.used = bool(s[3])
	if p.light:
		p.light.visible = bool(s[4])
	p.data["taken"] = s[5]


func _tele(ev: Array) -> void:
	var dur := float(ev[6])
	var params: Dictionary = (ev[7] as Dictionary).duplicate()
	params["progress"] = 0.0
	var n := stage.fx.shape(int(ev[2]), ev[3], ev[4], ev[5], Enemy.TELE_COLOR, Enemy.TELE_EDGE, dur + 0.05, params)
	teles[int(ev[1])] = n
	var start := stage.elapsed
	var st := stage
	var data: Dictionary = stage.fx._shapes[stage.fx._shapes.size() - 1]
	data.update = func(_t: float, node: MeshInstance3D) -> void:
		node.set_instance_shader_parameter("progress", clampf((st.elapsed - start) / maxf(dur, 0.01), 0.0, 1.0))


func apply_snapshot(d: Dictionary) -> void:
	for e in d.get("a", []):
		var id := int(e[0])
		var a = replicas.get(id)
		if not is_instance_valid(a):
			continue
		_goal[id] = [Vector2(e[1], e[2]), float(e[3])]
		a.bob = float(e[4])
		a.facing = Vector2(e[5], e[6])
		if a.sprite and String(e[7]) != "":
			if a.sprite.anim != String(e[7]) and a.sprite.has_anim(String(e[7])):
				a.sprite.play(String(e[7]), true)
			if absi(a.sprite.frame_i - int(e[8])) > 1:
				a.sprite.set_frame(int(e[8]))
		a.hp = float(e[9])
		a.max_hp = float(e[10])
		if a is Enemy:
			(a as Enemy).shield = float(e[11])
			(a as Enemy).shield_max = float(e[12])
		var flags := int(e[13])
		a.targetable = flags & 2 != 0
		if a.visual:
			a.visual.visible = flags & 4 != 0
		if a is Player and flags & 1 == 0 and a.alive:
			a.alive = false
		elif a is Player and flags & 1 != 0 and not a.alive:
			(a as Player).revive_replica()
	for p in d.get("pl", []):
		var pl = replicas.get(int(p[0]))
		if not is_instance_valid(pl):
			continue
		pl.kindle = float(p[1])
		pl.flask = int(p[2])
		pl.ability_cd[0] = float(p[3])
		pl.ability_cd[1] = float(p[4])
		pl.dodge_charges = float(p[5])
		pl.downed = bool(p[6])
		pl.bleed_t = float(p[7])
		pl.revive_k = float(p[8])
		pl.look = Vector2(p[9], p[10])
		if pl != stage.player:
			pl.aim = Vector2(p[11], p[12])
		if pl.weapon:
			pl.weapon.phase = int(p[13])
			pl.weapon.swing = float(p[14])
			pl.weapon.aim_dir = Vector2(p[15], p[16])
			pl.weapon.charged = bool(p[17])
		pl.hearthcall_t = float(p[18])
		pl.ward_t = 0.1 if bool(p[22]) else 0.0
		if pl == stage.player and Game.run:
			Game.run.embers = int(p[19])
			Game.run.sunshards = int(p[20])
			Game.run.xp_gained = int(p[24])
			if Game.run.relics != p[21]:
				Game.run.relics = (p[21] as Array).duplicate()
				pl.rebuild_stats()
	if Game.run and d.has("t"):
		Game.run.elapsed = float(d.t)
	for p in d.get("pr", []):
		var pr = projs.get(int(p[0]))
		if is_instance_valid(pr):
			var to := Vector2(p[1], p[2])
			if pr.pos.distance_to(to) > 0.6:
				pr.pos = to
			pr.height = float(p[3])
	for p in d.get("pk", []):
		var pk = picks.get(int(p[0]))
		if is_instance_valid(pk):
			pk.pos = Vector2(p[1], p[2])
			pk.height = float(p[3])
			if pk.height <= 0.01 and not pk._landed:
				pk._land()


## Replicas glide toward where the host last saw them.
func _smooth(delta: float) -> void:
	var k := 1.0 - exp(-delta * 16.0)
	for id in _goal.keys():
		var a = replicas.get(id)
		if not is_instance_valid(a):
			_goal.erase(id)
			continue
		var g: Array = _goal[id]
		var to: Vector2 = g[0]
		a.pos = to if a.pos.distance_to(to) > 3.0 else a.pos.lerp(to, k)
		a.height = lerpf(a.height, float(g[1]), k)


func on_offer(kind: String, args: Array) -> void:
	match kind:
		"relic":
			var idx := int(args[0])
			Game.ui.relic_choice(args[1], func(id: String) -> void:
				if id != "":
					Net.ask("relic", [idx, id]))


## A plain picture of a non-enemy actor (familiars and such) on a client.
class ReplicaActor:
	extends Actor
	var sheet_name := ""

	func _ready() -> void:
		team = Team.NEUTRAL
		build_visual(sheet_name, "")
