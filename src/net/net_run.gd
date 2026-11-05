## One shared expedition floor. On the host it watches the simulation and sends
## each client what it needs to draw it (snapshots at 30 Hz with only what
## changed near that client, reliable events every frame for everything that
## happens once); it also drives the remote Kindled from their owners' input.
## On a client it builds the replicas, draws them a little in the past between
## two snapshots (interpolation), and lets this machine's Kindled run ahead on
## its own input (prediction), pulled toward the host's word (reconciliation).
class_name NetRun
extends Node

const SNAP_HZ := 30.0
const INPUT_HZ := 60.0
const INTEREST := 26.0    # tiles: farther actors are not sent to a client (bosses and players always are)
const KEY_EVERY := 15     # every row is resent at least this often (snapshots), changed or not
const SNAP_DIST := 2.5    # a correction larger than this is a jump (a pull, a teleport), not a slide
## How far the host lets a remote Kindled drift toward where its owner's
## prediction stood, per input: packet timing makes the two disagree by about a
## frame of walking; anything larger (a shove, a wall, a cheat) stays the host's.
const AGREE_STEP := 0.12
## What clients may not do themselves yet (they need a menu on the host).
const HOST_ONLY := ["merchant", "shrine", "ember_well", "trial_altar", "echo", "hearthstone"]

var stage: Dungeon
var host := false
var floor_id := 0             # the depth: every message names the floor it belongs to
var events: Array = []
## Host: finds delivered to a guest and not yet acknowledged, by peer:
## {drop: [kind, what, grade]} - sent again after a rejoin and before the end.
var gifts := {}
var _waiting := false         # host: holding the floor until every guest has built it
var _prop_made: Array = []    # host: props made since the floor was built (for a returning guest)
var _wait_t := 0.0
var _snap_t := 0.0
# host
var _last_presses := {}       # peer -> press counts (Net.PRESS_KEYS order)
var _last_held := {}          # peer -> attack held
var _prop_state := {}         # prop index -> last sent state
var _sent := {}               # peer -> {net id -> row last sent (frame left out)}
var _pick_sent := {}          # peer -> {pickup id -> last sent position}
var _chunk_n := {}            # peer -> snapshot chunks sent
var _key_phase := 0
# client
var replicas := {}            # net id -> Actor
var projs := {}               # net id -> Projectile
var picks := {}               # net id -> Pickup
var teles := {}               # telegraph id -> MeshInstance3D
var _hist := {}               # net id -> [[host ms, row], ...] (oldest first)
var _pl_hist := {}            # net id -> [[host ms, player row], ...] (other Kindled)
var _applied := {}            # net id -> host ms of the row last applied
var _clock := 0.0             # host ms - local ms, for the fastest packets seen
var _clock_set := false
var _late := 0.0              # ms: how much later than the fastest packets they usually come
var _delay := 1000.0 / SNAP_HZ * 2.0
var _last_c := -1
var _lost := 0.0
var _got := 0.0
var diag := {}                # client: figures for the network overlay
# host: party votes (Party.VOTED, the Hearthcall)
var _votes := {}              # id -> {"id", "kind", "idx", "by", "yes": {peer: true}, "until"}
var _vote_n := 0
# client: this machine's Kindled
var _seq := 0
var _seq_t := {}              # input seq -> local seconds it was sent
var _traj: Array = []         # [local seconds, pos], newest last
var _sent_presses: Array = []
var _sent_down := false
var _send_ms := 0
var _hold_t0 := -1
var _hold_ms := 0
var _attack_ms := -100000     # when this machine last pressed attack (local ms)
var _was_predicting := false
var _err_sum := 0.0
var _err_n := 0
var _free_sum := 0.0          # the same, only while nothing touched the Kindled (no foe at hand, no blow)
var _free_n := 0
var _errs: Array = []         # this second's errors (for percentiles)
var _err_max := 0.0
var _fix_n := 0
var _jump_n := 0
var _diag_t := 0.0


func setup(st: Dungeon, as_host: bool) -> void:
	stage = st
	host = as_host
	name = "NetRun"
	floor_id = Net.i.expedition * 1000 + st.layout.depth
	Net.i.run_sync = self
	if host:
		Net.recording = true
		Events.banner.connect(_on_banner)
		Events.toast.connect(_on_toast)
		# everything already on the floor (built before this node) is announced
		for a in stage.actors:
			if a.net_id == 0:
				register_actor(a)
		# nobody starts a floor ahead of the party
		if Net.party_size() > 1:
			_waiting = true
			stage.paused_sim = true
	else:
		Net.recording = false
		for a in stage.actors:
			if a is Player and a.net_id != 0:
				replicas[a.net_id] = a
		apply_events(Net.i.take_early(floor_id))
		Net.i.to_host("_floor_ready", [floor_id])


func _exit_tree() -> void:
	# the next floor's NetRun is set up before this one is freed: only the
	# floor still in charge may stop the recording
	if Net.i and Net.i.run_sync == self:
		Net.i.run_sync = null
		if host:
			Net.recording = false
	if host:
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
	Net.rec(["actor+", a.net_id, _describe(a)])


func _describe(a: Actor) -> Dictionary:
	var d := {"pos": a.pos}
	if a is Enemy:
		var e := a as Enemy
		# how long it still takes to rise (a guest who arrives late sees it whole)
		var rising := maxf(0.0, e.spawn_t - e.state_t) if e.state == "spawn" else 0.0
		d.merge({"kind": "enemy", "id": e.id, "elite": e.elite, "affix": e.affix, "affix2": e.affix2,
			"grudge": e.grudge, "summoned": e.summoned, "spawn_t": rising, "boss": e == stage.boss})
	else:
		d.merge({"kind": "other", "sheet": a.sprite.sheet.name if a.sprite else "", "radius": a.radius})
		if a.has_method("light_spec"):
			d["light"] = a.call("light_spec")    # a Hearth Lantern glows on every screen
	return d


func _process(delta: float) -> void:
	if not Net.active():
		return
	if host:
		if _waiting:
			_wait_t += delta
			var all := true
			for pid in Net.i.present():
				if int(pid) != 1 and int(Net.i.ready_floor.get(pid, -1)) != floor_id:
					all = false
			if all or _wait_t > 10.0:
				_waiting = false
				stage.paused_sim = false
				Game.send_checkpoints()
				print("[net] floor %d starts (%s, %.1f s)" % [floor_id, "everyone is here" if all else "waited long enough", _wait_t])
		# events go out the frame they happen (a batch per frame, reliable)
		if not events.is_empty():
			var evs := events
			events = []
			var shared: Array = []
			var own := {}      # one guest's alone (their own finds): sent to them only
			for ev in evs:
				if String(ev[0]) == "prop+":
					_prop_made.append(ev)     # a returning guest gets these again
				if String(ev[0]) == "own":
					var who := int(ev[1])
					if who != Net.my_id():
						if not own.has(who):
							own[who] = []
						(own[who] as Array).append(ev)
					continue
				shared.append(ev)
			if not shared.is_empty():
				Net.i.rpc("_events", floor_id, shared)
			for who in own:
				if Net.i.present().has(who):
					Net.i.rpc_id(int(who), "_events", floor_id, own[who])
		_snap_t += delta
		if _snap_t >= 1.0 / SNAP_HZ:
			_snap_t = 0.0
			_capture_props()
			_send_snapshots()
			for v in _votes.values():
				if stage.elapsed > float(v.until):
					_finish_vote(v, false, "Not everyone answered.")
	else:
		_client_tick(delta)


## Floats rounded to 1/64 fit 32 bits exactly, which halves their size on the wire.
static func q(x: float) -> float:
	return roundf(x * 64.0) / 64.0


func _send_snapshots() -> void:
	var t := Time.get_ticks_msec()
	var acts: Array = []      # [row, always sent]
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
		acts.append([[a.net_id, q(a.pos.x), q(a.pos.y), q(a.height), q(a.bob), q(a.facing.x), q(a.facing.y),
			s.anim if s else "", s.frame_i if s else 0, q(a.hp), q(a.max_hp), q(sh), q(shm), flags], a is Player or a == stage.boss])
		if a is Player:
			var p := a as Player
			var w := p.weapon
			pls.append([p.net_id, q(p.kindle), p.flask, q(p.ability_cd[0]), q(p.ability_cd[1]), q(p.dodge_charges),
				p.downed, q(p.bleed_t), q(p.revive_k), q(p.look.x), q(p.look.y), q(p.aim.x), q(p.aim.y),
				int(w.phase) if w else 0, q(w.swing) if w else 0.0, q(w.aim_dir.x) if w else 1.0, q(w.aim_dir.y) if w else 0.0, w.charged if w else false,
				p.hearthcall_t, p.run.embers if p.run else 0, p.run.sunshards if p.run else 0, p.run.relics if p.run else [],
				p.ward_t > 0.0, p.dodge_t > 0.0, p.run.xp_gained if p.run else 0, q(p.hurt_t), q(p.status.speed_mult()), q(p.stats.v("kindle_max")), q(p.ability_cd[2] if p.ability_cd.size() > 2 else 0.0), p.momentum, q(p.form_meter),
				(1 if p.hearthfire_t > 0.0 else 0) | (2 if p.channel_t > 0.0 else 0) | (4 if p.haste_t > 0.0 else 0)])
	var prs: Array = []
	for pr in stage.projectiles:
		if is_instance_valid(pr) and pr.net_id != 0:
			prs.append([pr.net_id, q(pr.pos.x), q(pr.pos.y), q(pr.height), q(pr.vel.x), q(pr.vel.y)])
	_key_phase = (_key_phase + 1) % KEY_EVERY
	for pid in Net.i.present():
		if int(pid) != 1:
			_send_to(int(pid), t, acts, pls, prs)


## One client's snapshot: rows near its Kindled that changed (or are due a
## refresh), in small compressed chunks that each fit one packet.
func _send_to(peer: int, t: int, acts: Array, pls: Array, prs: Array) -> void:
	var me := _player_of(peer)
	var ref: Vector2 = me.pos if me else Vector2.ZERO
	var r2 := INTEREST * INTEREST
	var sent: Dictionary = _sent.get(peer, {})
	_sent[peer] = sent
	var rows: Array = []
	for e in acts:
		var row: Array = e[0]
		var id := int(row[0])
		if me and not bool(e[1]) and Vector2(row[1], row[2]).distance_squared_to(ref) > r2:
			continue
		var key := row.duplicate()
		key[8] = 0     # animation frames tick on their own; only a jump is resent
		if sent.get(id) != key or id % KEY_EVERY == _key_phase:
			sent[id] = key
			rows.append(row)
	var near_prs: Array = []
	for p in prs:
		if me == null or Vector2(p[1], p[2]).distance_squared_to(ref) <= r2:
			near_prs.append(p)
	var pk_sent: Dictionary = _pick_sent.get(peer, {})
	_pick_sent[peer] = pk_sent
	var pks: Array = []
	for pk in stage.pickups:
		if is_instance_valid(pk) and pk.net_id != 0:
			var cur := Vector3(pk.pos.x, pk.pos.y, pk.height)
			var last: Variant = pk_sent.get(pk.net_id)
			if last == null or (last as Vector3).distance_to(cur) > 0.01:
				pk_sent[pk.net_id] = cur
				pks.append([pk.net_id, q(cur.x), q(cur.y), q(cur.z)])
	var first := {"t": t, "a": rows.slice(0, 4), "pl": pls, "pr": near_prs, "pk": pks, "rt": q(stage.run.elapsed)}
	if me:
		# which input this answers, and for how long it has been driving the Kindled
		first["me"] = [me.in_seq, int(me.in_age * 1000.0), q(me.pos.x), q(me.pos.y)]
	_ship(peer, first)
	var i := 4
	while i < rows.size():
		# as many rows as stay well inside one packet once compressed
		var n := mini(24, rows.size() - i)
		while n > 6 and var_to_bytes(rows.slice(i, i + n)).size() > 2600:
			n -= 6
		_ship(peer, {"t": t, "a": rows.slice(i, i + n)})
		i += n


func _ship(peer: int, chunk: Dictionary) -> void:
	var n: int = int(_chunk_n.get(peer, 0)) + 1
	_chunk_n[peer] = n
	chunk["c"] = n
	var raw := var_to_bytes(chunk)
	var z := raw.compress(FileAccess.COMPRESSION_ZSTD)
	Net.i.count("snap_out", z.size())
	Net.i.count("snap_pk")
	Net.i.rpc_id(peer, "_snapz", floor_id, z, raw.size())


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


## A client's input packet (see pack_input): newest only, presses counted.
func on_input(peer: int, d: Array) -> void:
	var pl := _player_of(peer)
	if pl == null or not pl.alive or pl.away or d.size() < 11:
		return
	var seq := int(d[0])
	if seq <= pl.in_seq:
		return
	pl.in_seq = seq
	pl.in_age = 0.0
	if d.size() > 12 and not pl.downed:
		# where the owner's prediction stood as it sent this: close enough, with
		# nothing shoving the Kindled and a clear path, and the host agrees
		var claim := Vector2(d[11], d[12])
		var gap := claim - pl.pos
		if gap.length() > 0.001 and gap.length() <= AGREE_STEP * 3.0 and pl.push.length() < 0.3 and pl.hurt_t <= 0.0:
			var step := gap.limit_length(AGREE_STEP)
			pl.pos = stage.grid.move_box(pl.pos, pl.box(), step, pl.flying)
	pl.move_in = Vector2(d[1], d[2]).limit_length(1.0)
	var a := Vector2(d[3], d[4])
	if a.length() > 0.1:
		pl.aim = a.normalized()
	if d.size() > 14:
		pl.remote_look = Vector2(d[13], d[14])     # the owner's own facing
	pl.aim_point = Vector2(d[5], d[6])
	var held := bool(d[7])
	if bool(_last_held.get(peer, false)) and not held:
		pl._release_pending = true
		pl.remote_hold = float(d[10]) / 1000.0
	pl._attack_down = held
	_last_held[peer] = held
	var now: Array = d[8]
	var last: Array = _last_presses.get(peer, [])
	for k in mini(now.size(), Net.PRESS_KEYS.size()):
		if Net.PRESS_KEYS[k] != "interact" and int(now[k]) > (int(last[k]) if k < last.size() else 0):
			pl.press(Net.PRESS_KEYS[k])
	_last_presses[peer] = now
	# the owner sees the world a round trip late: give its dodges and Wards that long
	pl.lag_grace = clampf(float(d[9]) / 1000.0 + 0.05, 0.05, 0.25)


func on_ask(peer: int, kind: String, args: Array) -> void:
	var pl := _player_of(peer)
	if pl == null:
		return
	var p0: Prop = _prop(int(args[0])) if kind in ["buy", "shrine", "echo", "confirm"] else null
	if p0 and p0.pos.distance_to(pl.pos) > p0.interact_radius + 2.5:
		p0 = null     # they walked away with the menu open
	match kind:
		"ping":
			Party.show_ping(stage, peer, args[0])
			Net.rec(["ping", peer, args[0]])
		"buy":
			if p0 and p0.kind == "merchant":
				Party.buy(stage, pl, p0, int(args[1]))
				# the truth either way: what is sold, what is left
				Net.i.rpc_id(peer, "_offer", "shop", [p0.net_idx, Party.shop_stock(stage, pl, p0)])
		"shrine":
			if p0 and p0.kind == "shrine":
				Party.shrine_choice(stage, pl, p0, String(args[1]))
		"echo":
			if p0 and p0.kind == "echo":
				Party.echo_gift(stage, pl, p0)
		"confirm":
			if p0 and p0.kind == "ember_well" and String(args[1]) == "well":
				Party.draw_well(stage, pl, p0)
		"vote":
			cast_vote(peer, int(args[0]), bool(args[1]))
		"gift_ok":
			if gifts.has(peer):
				(gifts[peer] as Dictionary).erase(String(args[0]))
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
	_sent.erase(peer)
	_pick_sent.erase(peer)
	for v in _votes.values():
		v.yes.erase(peer)
		_check_vote(v)


## A guest lost the link: its Kindled waits where it stands, untouchable,
## while its seat waits (Net.SEAT_WAIT); the party's votes go on without it.
func on_peer_away(peer: int) -> void:
	var pl := _player_of(peer)
	if pl:
		pl.set_away(true)
		Events.toast.emit("%s's light flickers - they lost the link." % Net.name_of(peer), Color(1.0, 0.75, 0.5))
	for v in _votes.values():
		_check_vote(v)


## The same Kindled is back under a new peer id: everything of theirs follows.
func on_rejoin(old: int, new: int) -> void:
	var pl := _player_of(old)
	if pl:
		pl.peer_id = new
		pl.in_seq = 0
		pl.set_away(false)
	if Game.coop_runs.has(old):
		Game.coop_runs[new] = Game.coop_runs[old]
		Game.coop_runs.erase(old)
	if gifts.has(old):
		gifts[new] = gifts[old]
		gifts.erase(old)
		resend_gifts.call_deferred(new)
	for pk in stage.pickups:
		if is_instance_valid(pk) and pk.owner_peer == old:
			pk.owner_peer = new
	# their stock, bargains and pending offers keep their name
	for p in stage.props:
		if not is_instance_valid(p):
			continue
		for key in p.data.keys():
			if String(key).ends_with("_%d" % old):
				p.data[String(key).trim_suffix("_%d" % old) + "_%d" % new] = p.data[key]
				p.data.erase(key)
		var taken: Array = p.data.get("taken", [])
		if taken.has(old):
			taken[taken.find(old)] = new
	for m in [_sent, _pick_sent, _chunk_n, _last_presses, _last_held]:
		(m as Dictionary).erase(old)


## Everything a client needs to draw this floor as it is now (a guest who
## rebuilt it after losing the link): what was made, what changed, who is here.
func world_dump(for_peer := 0) -> Array:
	var out: Array = []
	out.append_array(_prop_made)
	for idx in _prop_state:
		out.append(["prop", idx, _prop_state[idx]])
	for r in stage.layout.rooms:
		if r.visited:
			out.append(["room", r.id])
	for rid in stage.gate_nodes:
		var nodes: Array = stage.gate_nodes[rid]
		if not nodes.is_empty():
			var t: Vector2i = nodes[0].get_meta("tile")
			if stage.grid.at(t.x, t.y) == TileGrid.GATE:
				out.append(["gate", rid, true])
	for a in stage.actors:
		if is_instance_valid(a) and a.alive and a.net_id != 0 and not (a is Player):
			out.append(["actor+", a.net_id, _describe(a)])
	if stage.boss and is_instance_valid(stage.boss) and stage.boss.alive:
		out.append(["boss", stage.boss.net_id])
	for pk in stage.pickups:
		if is_instance_valid(pk) and pk.net_id != 0 and (pk.owner_peer == 0 or pk.owner_peer == for_peer):
			out.append(["pick+", [pk.net_id, pk.kind, pk.pos, pk.height, Vector2.ZERO, pk.amount, pk.data, pk.owner_peer]])
	return out


# --- host: party votes ---------------------------------------------------------------

## Someone asks the party (the stairs, the Hearthstone, the Trial, a Hearthcall):
## everyone has to agree, within Party.VOTE_TIME; one "not yet" ends it.
func start_vote(kind: String, idx: int, by: Player) -> void:
	for v in _votes.values():
		if v.kind == kind and int(v.idx) == idx:
			cast_vote(by.peer_id, int(v.id), true)
			return
	_vote_n += 1
	var nv := {"id": _vote_n, "kind": kind, "idx": idx, "by": by.peer_id, "yes": {by.peer_id: true},
		"until": stage.elapsed + Party.VOTE_TIME}
	# whoever is already standing there with them is plainly agreeing
	var at := _prop(idx)
	if at:
		for pl in stage.players:
			if is_instance_valid(pl) and pl.alive and not pl.away and pl.pos.distance_to(at.pos) < 3.0:
				nv.yes[pl.peer_id] = true
	_votes[_vote_n] = nv
	print("[net] vote %d: %s asked by %s" % [_vote_n, kind, Net.name_of(by.peer_id)])
	_announce_vote(nv)
	_check_vote(nv)


func cast_vote(peer: int, id: int, agree: bool) -> void:
	var v: Dictionary = _votes.get(id, {})
	if v.is_empty() or not Net.i.present().has(peer):
		return
	if not agree:
		_finish_vote(v, false, "%s is not ready yet." % Net.name_of(peer))
		return
	if v.yes.has(peer):
		return
	v.yes[peer] = true
	_announce_vote(v)
	_check_vote(v)


func _announce_vote(v: Dictionary) -> void:
	var yes: Array = v.yes.keys()
	var need := Net.i.present().size()
	Net.rec(["vote", v.id, v.kind, v.by, yes, need])
	Party.show_vote(int(v.id), String(v.kind), int(v.by), yes, need)


func _check_vote(v: Dictionary) -> void:
	if not _votes.has(v.id):
		return
	for pid in Net.i.present():
		if not v.yes.has(pid):
			return
	_finish_vote(v, true, "")
	match String(v.kind).get_slice(":", 0):
		"stairs":
			# (the way down rides in the vote's kind: "stairs:trial")
			Game.descend(String(v.kind).get_slice(":", 1))
		"site":
			DeepEvents.resolve(stage, _prop(int(v.idx)), stage.player)
		"hearthstone":
			var hs := _prop(int(v.idx))
			Game.end_run("victory" if hs and hs.data.get("victory", false) else "extracted")
		"trial":
			var tp := _prop(int(v.idx))
			if tp:
				stage.begin_trial(tp)
		"hearthcall":
			Game.end_run("extracted")


func _finish_vote(v: Dictionary, passed: bool, why: String) -> void:
	_votes.erase(v.id)
	print("[net] vote %d (%s) %s %s" % [int(v.id), String(v.kind), "passed" if passed else "failed:", why])
	Net.rec(["vote_end", v.id, passed, why])
	Party.end_vote(int(v.id), passed, why)


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
## Host: a guest took a find of their own - it goes to their machine, which
## banks it in their Satchel (once per drop id) and answers "gift_ok".
func give(pl: Player, kind: String, what: Variant, drop: String, grade: int) -> void:
	var peer := pl.peer_id
	if not gifts.has(peer):
		gifts[peer] = {}
	gifts[peer][drop] = [kind, what, grade]
	if Net.i.present().has(peer):
		Net.i.rpc_id(peer, "_gift", floor_id, drop, kind, what, grade)


## Host: every find a guest has not yet acknowledged, again (a rejoin, the end).
func resend_gifts(peer: int) -> void:
	for drop in gifts.get(peer, {}):
		var g: Array = gifts[peer][drop]
		Net.i.rpc_id(peer, "_gift", floor_id, drop, g[0], g[1], g[2])


func tell(pl: Player, text: String, col: Color) -> void:
	if pl.peer_id == Net.my_id():
		# straight to this screen (Events.toast would be recorded for everyone)
		if Game.ui:
			Game.ui.toast(text, col)
	else:
		Net.i.rpc_id(pl.peer_id, "_tell", text, col)


# --- client: this machine's Kindled ---------------------------------------------------

func _client_tick(delta: float) -> void:
	var pl := stage.player
	var now_s := Time.get_ticks_usec() / 1000000.0
	if pl and is_instance_valid(pl):
		var can := pl.can_predict()
		if can and not _was_predicting:
			# back on its feet (or just arrived): start the record afresh from the host's word
			_traj.clear()
			_seq_t.clear()
		_was_predicting = can
		_send_input(pl, now_s)
		if can:
			_traj.append([now_s, pl.pos])
			while _traj.size() > 2 and now_s - float(_traj[0][0]) > 2.0:
				_traj.pop_front()
	_interpolate()
	_diag_t += delta
	if _diag_t >= 1.0:
		diag["err_avg"] = _err_sum / maxf(1.0, _err_n)
		_errs.sort()
		diag["err_p50"] = _errs[_errs.size() / 2] if not _errs.is_empty() else 0.0
		diag["err_p95"] = _errs[mini(_errs.size() - 1, int(_errs.size() * 0.95))] if not _errs.is_empty() else 0.0
		_errs.clear()
		diag["err_free"] = _free_sum / maxf(1.0, _free_n)
		_free_sum = 0.0
		_free_n = 0
		diag["err_max"] = _err_max
		diag["fixes"] = _fix_n / _diag_t
		diag["jumps"] = _jump_n / _diag_t
		diag["delay"] = _delay
		diag["loss"] = _lost / maxf(1.0, _lost + _got)
		_err_sum = 0.0
		_err_n = 0
		_err_max = 0.0
		_fix_n = 0
		_jump_n = 0
		_diag_t = 0.0


## Input goes out every frame something changes, and at least INPUT_HZ times a
## second; the prediction only ever uses what was sent, so it and the host agree.
var _sent_look := Vector2.RIGHT     # the facing in the last input sent (a turn goes out at once)


func _send_input(pl: Player, now_s: float) -> void:
	var now := Time.get_ticks_msec()
	var pr: Array = []
	for k in Net.PRESS_KEYS:
		pr.append(int(pl.presses.get(k, 0)))
	var down := pl._attack_down
	var changed := pr != _sent_presses or down != _sent_down or absf(pl.look.angle_to(_sent_look)) > 0.3
	_sent_look = pl.look
	if not changed and now - _send_ms < 1000.0 / INPUT_HZ - 1.0:
		return
	if pr[0] != (_sent_presses[0] if not _sent_presses.is_empty() else 0):
		_attack_ms = now
	if down and not _sent_down:
		_hold_t0 = now
	if _hold_t0 >= 0:
		_hold_ms = now - _hold_t0
	if not down:
		_hold_t0 = -1
	_seq += 1
	var m := pl.move_in.limit_length(1.0)
	var pkt := [_seq, q(m.x), q(m.y), q(pl.aim.x), q(pl.aim.y), q(pl.aim_point.x), q(pl.aim_point.y), down, pr,
		int(Net.rtt_s() * 1000.0), _hold_ms, q(pl.pos.x), q(pl.pos.y), q(pl.look.x), q(pl.look.y)]
	Net.i.to_host("_n_input", [floor_id, pkt], "in", false)
	Net.i.count("in_out")
	pl.pred_move = Vector2(pkt[1], pkt[2])
	_seq_t[_seq] = now_s
	_sent_presses = pr
	_sent_down = down
	_send_ms = now


## Where the prediction had the Kindled at local time `te`.
func _traj_at(te: float) -> Vector2:
	for k in range(_traj.size() - 1, -1, -1):
		var a: Array = _traj[k]
		if float(a[0]) <= te:
			if k + 1 < _traj.size():
				var b: Array = _traj[k + 1]
				var f := clampf((te - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.000001), 0.0, 1.0)
				return (a[1] as Vector2).lerp(b[1], f)
			return a[1]
	return _traj[0][1] if not _traj.is_empty() else stage.player.pos


## The host says where the Kindled stood after input `seq` had driven it for
## `age` ms. The prediction compares its own record for that same moment and
## moves by the difference; the picture keeps up over a few frames.
func _reconcile(me: Array) -> void:
	var pl := stage.player
	if pl == null or not is_instance_valid(pl) or not pl.can_predict() or _traj.is_empty():
		return
	var seq := int(me[0])
	if seq > _seq:
		# the host is applying input this floor never sent: the two disagree
		# about whose numbers these are (should never happen; say so once)
		if not diag.has("bad_ack"):
			print("[net] floor %d: the host acknowledged input %d, but only %d were sent here" % [floor_id, seq, _seq])
		diag["bad_ack"] = int(diag.get("bad_ack", 0)) + 1
		return
	if not _seq_t.has(seq):
		return
	var te := float(_seq_t[seq]) + float(me[1]) / 1000.0
	for s in _seq_t.keys():
		if int(s) < seq:
			_seq_t.erase(s)
	var server := Vector2(me[2], me[3])
	var err := server - _traj_at(te)
	var e := err.length()
	_err_sum += e
	_err_n += 1
	_errs.append(e)
	if pl.hurt_t <= 0.0 and stage.nearest_hostile(pl.team, pl.pos, 2.5, false) == null:
		_free_sum += e
		_free_n += 1
	_err_max = maxf(_err_max, e)
	if e < 0.04:
		return
	var before := pl.pos
	# from the host's spot, redo the movement made since (staying out of walls)
	pl.pos = stage.grid.move_box(server, pl.box(), pl.pos - _traj_at(te), pl.flying)
	var moved := pl.pos - before
	for s in _traj:
		s[1] = (s[1] as Vector2) + moved
	if e > SNAP_DIST:
		pl.draw_off = Vector2.ZERO
		_jump_n += 1
	else:
		pl.draw_off = (pl.draw_off - moved).limit_length(1.5)
		_fix_n += 1


# --- client: drawing the floor ------------------------------------------------------

func apply_events(evs: Array) -> void:
	for ev in evs:
		match String(ev[0]):
			"fx":
				stage.fx.callv(String(ev[1]), ev.slice(2))
			"snd":
				var who := int(ev[5]) if ev.size() > 5 else 0
				if ev[2] == null and (who == 0 or who == Net.my_id()):
					Audio.play(String(ev[1]), float(ev[3]), float(ev[4]))
				elif ev[2] == null:
					# another Kindled's own sound: heard from where they stand
					var other := _player_of(who)
					if other:
						Audio.play_at(String(ev[1]), other.pos, float(ev[3]) - 3.0, float(ev[4]))
				else:
					Audio.play_at(String(ev[1]), ev[2], float(ev[3]), float(ev[4]))
			"not":
				if int(ev[1]) != Net.my_id():
					apply_events([ev[2]])
			"by":
				stage.fx.ally_k = 1.0 if int(ev[1]) == Net.my_id() else maxf(0.05, stage.fx.ally)
				apply_events([ev[2]])
				stage.fx.ally_k = 1.0
			"own":
				if int(ev[1]) == Net.my_id():
					apply_events([ev[2]])
			"actor+":
				_spawn_replica(int(ev[1]), ev[2])
			"die":
				var r = replicas.get(int(ev[1]))
				if is_instance_valid(r):
					replicas.erase(int(ev[1]))
					_hist.erase(int(ev[1]))
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
			"ping":
				Party.show_ping(stage, int(ev[1]), ev[2])
			"wit":
				Chronicle.mark("witnessed_" + String(ev[1]))     # a guest saw it; the world is the host's
			"obj":
				if stage is Dungeon:
					(stage as Dungeon).objective = {} if String(ev[1]) == "" else {"text": String(ev[1]), "k": float(ev[2]), "col": ev[3]}
			"toast":
				Events.toast.emit(String(ev[1]), ev[2])
			"boss":
				var b = replicas.get(int(ev[1]))
				if b:
					stage.boss = b as Enemy
					Events.boss_started.emit(b)
			"boss_down":
				Events.boss_defeated.emit(stage.boss)
			"look":
				stage.look_toward(ev[1], float(ev[2]))
			"vote":
				Party.show_vote(int(ev[1]), String(ev[2]), int(ev[3]), ev[4], int(ev[5]))
			"vote_end":
				Party.end_vote(int(ev[1]), bool(ev[2]), String(ev[3]))


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
		o.light = d.get("light", [])
		a = o
	a.net_id = id
	a.pos = d.pos
	a.replica = true
	stage.add_actor(a)
	replicas[id] = a
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
	var pk := Pickup.spawn(stage, String(d[1]), d[2], int(d[5]), d[6], owner)
	pk.net_id = int(d[0])
	pk.vel = Vector2.ZERO
	pk.vz = 0.0
	pk.height = float(d[3])
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
	if ev.size() > 8:
		# the foe winding up glows on this screen too
		var who = replicas.get(int(ev[8]))
		if who is Enemy and is_instance_valid(who):
			(who as Enemy).begin_tell(dur)
	var start := stage.elapsed
	var st := stage
	var data: Dictionary = stage.fx._shapes[stage.fx._shapes.size() - 1]
	data.update = func(_t: float, node: MeshInstance3D) -> void:
		node.set_instance_shader_parameter("progress", clampf((st.elapsed - start) / maxf(dur, 0.01), 0.0, 1.0))


## Keeps an estimate of the host's clock from the fastest packets, and of how
## much later than those the rest tend to arrive (that, plus a snapshot
## interval and a half, is how far in the past the floor is drawn).
func _note_clock(t: float, c: int) -> void:
	var off := t - float(Time.get_ticks_msec())
	if not _clock_set:
		_clock = off
		_clock_set = true
	elif off > _clock:
		_clock = off
	else:
		_clock += (off - _clock) * 0.002
	_late = lerpf(_late, _clock - off, 0.1)
	_delay = clampf(1000.0 / SNAP_HZ * 1.5 + _late * 2.0 + 4.0, 40.0, 250.0)
	if c > 0:
		if _last_c > 0 and c > _last_c + 1:
			_lost += c - _last_c - 1
		if c > _last_c:
			_last_c = c
		_got += 1.0
		_lost *= 0.995
		_got *= 0.995


func _push_row(buf: Dictionary, id: int, t: float, row: Array) -> void:
	var h: Array = buf.get(id, [])
	if not h.is_empty():
		var last: Array = h.back()
		if t <= float(last[0]):
			return
		if t - float(last[0]) > 1.6 * 1000.0 / SNAP_HZ:
			# rows only come when something changes: it stood still until just now
			h.append([t - 1000.0 / SNAP_HZ, last[1]])
	h.append([t, row])
	buf[id] = h


func apply_snapshot(d: Dictionary) -> void:
	var t := float(d.get("t", 0))
	_note_clock(t, int(d.get("c", -1)))
	for row in d.get("a", []):
		_push_row(_hist, int(row[0]), t, row)
	if d.has("me"):
		_reconcile(d.me)
	for p in d.get("pl", []):
		var pl = replicas.get(int(p[0]))
		if not is_instance_valid(pl):
			continue
		if pl == stage.player:
			_apply_own(pl, p)
		else:
			_push_row(_pl_hist, int(p[0]), t, p)
	if Game.run and d.has("rt"):
		Game.run.elapsed = float(d.rt)
	for p in d.get("pr", []):
		var pr = projs.get(int(p[0]))
		if is_instance_valid(pr):
			var to := Vector2(p[1], p[2])
			if pr.pos.distance_to(to) > 0.6:
				pr.pos = to
			pr.height = float(p[3])
			if p.size() > 5:
				pr.vel = Vector2(p[4], p[5])     # it chained, turned back or was turned
	for p in d.get("pk", []):
		var pk = picks.get(int(p[0]))
		if is_instance_valid(pk):
			pk.pos = Vector2(p[1], p[2])
			pk.height = float(p[3])
			if pk.height <= 0.01 and not pk._landed:
				pk._land()


## This machine's Kindled: the host's word on what only the host knows; what the
## prediction just did itself (a dodge, a Ward, a spell) is kept until the host
## has had time to hear of it.
func _apply_own(pl: Player, p: Array) -> void:
	var predicting := pl.can_predict()
	if not pl.held_local("kindle"):
		pl.kindle = float(p[1])
	if not pl.held_local("flask"):
		pl.flask = int(p[2])
	for k in 2:
		if not pl.held_local("a%d" % k):
			pl.ability_cd[k] = float(p[3 + k])
	if p.size() > 28 and not pl.held_local("a2"):
		pl.ability_cd[2] = float(p[28])
	if p.size() > 29:
		pl.momentum = int(p[29])     # its weapon's pace (Momentum) is the host's
	if p.size() > 30:
		pl.form_meter = float(p[30])  # its weapon form's gauge (heat, nocked arrows, glyphs)
	if p.size() > 31:
		_spell_bits(pl, int(p[31]))
	if not pl.held_local("dodge"):
		pl.dodge_charges = float(p[5])
	pl.downed = bool(p[6])
	pl.bleed_t = float(p[7])
	pl.revive_k = float(p[8])
	pl.hearthcall_t = float(p[18])
	if p.size() > 26:
		if float(p[25]) > pl.hurt_t + 0.05:
			pl.hurt_t = float(p[25])
		pl.pred_speed = float(p[26])
	if not predicting:
		pl.look = Vector2(p[9], p[10])
		pl.ward_t = 0.1 if bool(p[22]) else 0.0
	if pl.weapon:
		var host_phase := int(p[13])
		var mine_idle := pl.weapon.phase == Weapon.Phase.IDLE
		# something the host started on its own (a Counterweight blow): take its word
		var quiet := Time.get_ticks_msec() - _attack_ms > int(Net.rtt_s() * 1000.0) + 250
		if not predicting or (mine_idle and host_phase != Weapon.Phase.IDLE and quiet):
			pl.weapon.phase = host_phase
			pl.weapon.swing = float(p[14])
			pl.weapon.aim_dir = Vector2(p[15], p[16])
			pl.weapon.charged = bool(p[17])
	if Game.run:
		Game.run.embers = int(p[19])
		Game.run.sunshards = int(p[20])
		Game.run.xp_gained = int(p[24])
		# experience lands as it is earned, as it does for the host (a guest
		# levels up mid-expedition); the settlement adds only what is left
		Profile.live_xp(Game.run.run_id, Game.run.xp_gained)
		if Game.run.relics != p[21]:
			Game.run.relics = (p[21] as Array).duplicate()
			pl.rebuild_stats()


## Another Kindled's HUD-free state, applied when the floor's clock reaches it.
func _apply_other(pl: Player, p: Array) -> void:
	pl.kindle = float(p[1])
	pl.flask = int(p[2])
	pl.ability_cd[0] = float(p[3])
	pl.ability_cd[1] = float(p[4])
	if p.size() > 28:
		pl.ability_cd[2] = float(p[28])
	pl.dodge_charges = float(p[5])
	pl.downed = bool(p[6])
	pl.bleed_t = float(p[7])
	pl.revive_k = float(p[8])
	pl.look = Vector2(p[9], p[10])
	pl.aim = Vector2(p[11], p[12])
	if pl.weapon:
		pl.weapon.phase = int(p[13])
		pl.weapon.swing = float(p[14])
		pl.weapon.aim_dir = Vector2(p[15], p[16])
		pl.weapon.charged = bool(p[17])
	pl.hearthcall_t = float(p[18])
	pl.ward_t = 0.1 if bool(p[22]) else 0.0
	if p.size() > 27:
		pl.kindle_cap = float(p[27])
	if p.size() > 29:
		pl.momentum = int(p[29])
	if p.size() > 30:
		pl.form_meter = float(p[30])
	if p.size() > 31:
		_spell_bits(pl, int(p[31]))


## The spells on a Kindled the host knows of (Hearthfire Form, a beam, haste):
## kept alive a moment past each snapshot, so they show (and, for this
## machine's own Kindled, so its predicted step keeps the right pace).
func _spell_bits(pl: Player, bits: int) -> void:
	if bits & 1:
		pl.hearthfire_t = maxf(pl.hearthfire_t, 0.2)
	if bits & 2:
		pl.channel_t = maxf(pl.channel_t, 0.12)
	if bits & 4:
		pl.haste_t = maxf(pl.haste_t, 0.2)


func _apply_row(a: Actor, e: Array, own: bool) -> void:
	if not own:
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
	if a.visual and not own:
		a.visual.visible = flags & 4 != 0
	if a is Player and flags & 1 == 0 and a.alive:
		a.alive = false
	elif a is Player and flags & 1 != 0 and not a.alive:
		(a as Player).revive_replica()


## Every replica is drawn `_delay` ms in the past, between the two snapshots
## around that moment: smooth at any snapshot rate, and true to the host's path.
func _interpolate() -> void:
	var rt := float(Time.get_ticks_msec()) + _clock - _delay
	for id in _hist.keys():
		var a = replicas.get(id)
		if not is_instance_valid(a):
			_hist.erase(id)
			_applied.erase(id)
			continue
		var h: Array = _hist[id]
		while h.size() > 1 and float(h[1][0]) <= rt:
			h.pop_front()
		var r0: Array = h[0]
		var row: Array = r0[1]
		var own: bool = a == stage.player and (a as Player).can_predict()
		if not own:
			var p := Vector2(row[1], row[2])
			var ht := float(row[3])
			if h.size() > 1 and rt > float(r0[0]):
				var r1: Array = h[1]
				var k := clampf((rt - float(r0[0])) / maxf(float(r1[0]) - float(r0[0]), 1.0), 0.0, 1.0)
				p = p.lerp(Vector2(r1[1][1], r1[1][2]), k)
				ht = lerpf(ht, float(r1[1][3]), k)
			a.pos = p
			a.height = ht
		if float(_applied.get(id, -1.0)) != float(r0[0]):
			_applied[id] = float(r0[0])
			_apply_row(a, row, own)
	for id in _pl_hist.keys():
		var pl = replicas.get(id)
		if not is_instance_valid(pl):
			_pl_hist.erase(id)
			continue
		var hp: Array = _pl_hist[id]
		var due: Array = []
		while not hp.is_empty() and float(hp[0][0]) <= rt:
			due = hp.pop_front()[1]
		if not due.is_empty():
			_apply_other(pl, due)
		if hp.is_empty():
			_pl_hist.erase(id)


func on_offer(kind: String, args: Array) -> void:
	Party.on_offer(kind, args)


## A plain picture of a non-enemy actor (familiars and such) on a client.
class ReplicaActor:
	extends Actor
	var sheet_name := ""
	var light: Array = []    # [colour, energy, range, height] (Hearth Lantern)

	func _ready() -> void:
		team = Team.NEUTRAL
		build_visual(sheet_name, "")
		if light.size() >= 4:
			var l := OmniLight3D.new()
			l.light_color = light[0]
			l.light_energy = float(light[1])
			l.omni_range = float(light[2])
			l.position = Vector3(0, float(light[3]) * Iso.SQ2, 0)
			visual.add_child(l)
