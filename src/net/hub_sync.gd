## Co-op in the sanctuary: the party walks the host's camp together.
##
## - Each machine moves its own Kindled itself (there is nothing to fight here,
##   so nothing to predict or correct) and sends where it stands, what it is
##   doing and which way it looks, POSE_HZ times a second, to the host.
## - The host passes every pose on, with its residents and the cat (the camp's
##   own movers, which only the host simulates), to everyone.
## - Everyone else's Kindled is a REPLICA Player drawn DELAY seconds in the
##   past, between the two poses around that moment, in its owner's own gear
##   (Player.sheet, updated live through Net.sheet_changed).
##
## What is personal stays personal: the Hearthtree, forge, smithy, satchel,
## wardrobe and residents' requests open the local profile (Hub.request). The
## camp itself (what is built, who lives there) is the host's (Hub.camp).
class_name HubSync
extends Node

const POSE_HZ := 20.0
const MOVER_HZ := 10.0
const DELAY := 0.1          # seconds behind the newest pose that others are drawn
const GONE_AFTER := 1.5     # seconds without a pose: that Kindled has left the camp

var hub: Hub
var others := {}            # peer -> Player (a REPLICA of another Kindled)
var _buf := {}              # peer -> [[local s, pose], ...] oldest first
var _latest := {}           # host: peer -> [local s, pose] (its own included)
var _t := 0.0
var _mover_t := 0.0


func _ready() -> void:
	name = "HubSync"
	Net.i.hub_sync = self
	Net.i.roster_changed.connect(_on_roster)


func _exit_tree() -> void:
	if Net.i and Net.i.hub_sync == self:
		Net.i.hub_sync = null
	if Net.i and Net.i.roster_changed.is_connected(_on_roster):
		Net.i.roster_changed.disconnect(_on_roster)


static func now_s() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _process(delta: float) -> void:
	if not Net.active():
		return
	_t += delta
	_mover_t += delta
	if _t >= 1.0 / POSE_HZ:
		_t = 0.0
		var mine := _pose_of(hub.player)
		if Net.is_host():
			_latest[1] = [now_s(), mine]
			var poses := {}
			for pid in _latest:
				if now_s() - float(_latest[pid][0]) < GONE_AFTER and Net.i.roster.has(pid):
					poses[pid] = _latest[pid][1]
			var movers: Array = []
			if _mover_t >= 1.0 / MOVER_HZ:
				_mover_t = 0.0
				movers = _movers()
			Net.i.rpc("_hub_world", poses, movers)
			on_world(poses, [])
		elif not mine.is_empty():
			Net.i.to_host("_hub_pose", [mine], "hub", false)
	_draw_others()


## This machine's Kindled as the others draw it (empty while it is not walking
## the camp: a title card, the gate's flare).
func _pose_of(pl: Player) -> Array:
	if pl == null or not is_instance_valid(pl) or not pl.sprite or not pl.sprite.visible:
		return []
	var w := pl.weapon
	return [NetRun.q(pl.pos.x), NetRun.q(pl.pos.y), NetRun.q(pl.height), NetRun.q(pl.bob), NetRun.q(pl.facing.x), NetRun.q(pl.facing.y),
		pl.sprite.anim, pl.sprite.frame_i, NetRun.q(pl.look.x), NetRun.q(pl.look.y), NetRun.q(pl.aim.x), NetRun.q(pl.aim.y),
		int(w.phase) if w else 0, NetRun.q(w.swing) if w else 0.0, NetRun.q(w.aim_dir.x) if w else 1.0, NetRun.q(w.aim_dir.y) if w else 0.0,
		w.charged if w else false, pl.ward_t > 0.0]


## Host: a guest's Kindled moved.
func on_pose(pid: int, pose: Array) -> void:
	if pose.size() >= 18:
		_latest[pid] = [now_s(), pose]


## Everyone: the party's poses (and, from the host, its residents and cat).
func on_world(poses: Dictionary, movers: Array) -> void:
	var t := now_s()
	for pid in poses:
		var id := int(pid)
		if id == Net.my_id() or not Net.i.roster.has(id):
			continue
		var pose: Array = poses[pid]
		if pose.size() < 18:
			continue
		if not others.has(id) or not is_instance_valid(others[id]):
			_arrive(id, Vector2(pose[0], pose[1]))
		var b: Array = _buf.get(id, [])
		b.append([t, pose])
		while b.size() > 12:
			b.pop_front()
		_buf[id] = b
	if not movers.is_empty() and not Net.is_host():
		_apply_movers(movers)


## Another Kindled walks into the camp: drawn in its owner's gear and colour.
func _arrive(pid: int, at: Vector2) -> void:
	var sh: Dictionary = Net.i.roster[pid].get("sheet", {})
	var pl := Player.new()
	pl.peer_id = pid
	pl.controller = Player.Ctrl.REPLICA
	pl.replica = true
	pl.sheet = sh
	pl.pos = at
	hub.add_actor(pl)
	var r := RunState.create(0, "ossuary", String(sh.get("weapon", "sword")), int(sh.get("weapon_level", 0)), sh.get("slots", ["flare", ""]))
	pl.setup_from(r)
	pl.kindle = pl.kindle_max()
	var col := Net.color_of(pid)
	pl.set_seat(col)
	hub.fx.mark(pl, 2.5, Net.name_of(pid), col, 8)
	others[pid] = pl
	# they come in out of the dark, as through the gate
	pl.sprite.set_dissolve(1.0)
	var tw := pl.create_tween()
	tw.tween_method(pl.sprite.set_dissolve, 1.0, 0.0, 0.5)
	hub.fx.motes(at, 0.4, Color(1.0, 0.75, 0.4), 10, 1.2, 0.8, 0.4)
	print("[hub] %s is in the sanctuary" % Net.name_of(pid))


func _leave(pid: int) -> void:
	var pl: Player = others.get(pid)
	others.erase(pid)
	_buf.erase(pid)
	if pl and is_instance_valid(pl):
		hub.fx.unmark(pl)
		hub.fx.motes(pl.pos, 0.4, Color(1.0, 0.75, 0.4), 10, 1.2, 0.8, 0.4)
		hub.remove_actor(pl)
		if pl.weapon:
			pl.weapon.free_visual()
		pl.queue_free()


func _on_roster() -> void:
	for pid in others.keys():
		if not Net.active() or not Net.i.roster.has(pid):
			_leave(int(pid))
	# once there is a party, this machine's Kindled wears its own seat's ring
	if Net.active() and Net.party_size() > 1 and hub.player and is_instance_valid(hub.player):
		hub.player.set_seat(Net.color_of(Net.my_id()), true)
	for pid in _latest.keys():
		if not Net.i.roster.has(pid):
			_latest.erase(pid)


## Each other Kindled DELAY behind its newest pose: position between the two
## poses around that moment, everything else from the older one.
func _draw_others() -> void:
	var t := now_s()
	var rt := t - DELAY
	for pid in others.keys():
		var pl: Player = others[pid]
		var b: Array = _buf.get(pid, [])
		if not is_instance_valid(pl):
			others.erase(pid)
			continue
		if b.is_empty() or t - float(b.back()[0]) > GONE_AFTER:
			_leave(int(pid))
			continue
		while b.size() > 2 and float(b[1][0]) <= rt:
			b.pop_front()
		var p0: Array = b[0][1]
		var at := Vector2(p0[0], p0[1])
		if b.size() > 1 and rt > float(b[0][0]):
			var p1: Array = b[1][1]
			var k := clampf((rt - float(b[0][0])) / maxf(float(b[1][0]) - float(b[0][0]), 0.001), 0.0, 1.0)
			at = at.lerp(Vector2(p1[0], p1[1]), k)
		if at.distance_to(pl.pos) > 6.0:
			hub.fx.motes(pl.pos, 0.4, Color(1.0, 0.75, 0.4), 6, 1.0, 0.6, 0.3)
		pl.pos = at
		_apply(pl, p0)


func _apply(pl: Player, p: Array) -> void:
	pl.height = float(p[2])
	pl.bob = float(p[3])
	pl.facing = Vector2(p[4], p[5])
	var anim := String(p[6])
	if pl.sprite and anim != "" and pl.sprite.has_anim(anim):
		if pl.sprite.anim != anim:
			pl.sprite.play(anim, true)
		if absi(pl.sprite.frame_i - int(p[7])) > 1:
			pl.sprite.set_frame(int(p[7]))
	pl.look = Vector2(p[8], p[9])
	pl.aim = Vector2(p[10], p[11])
	if pl.weapon:
		pl.weapon.phase = int(p[12])
		pl.weapon.swing = float(p[13])
		pl.weapon.aim_dir = Vector2(p[14], p[15])
		pl.weapon.charged = bool(p[16])
	pl.ward_t = 0.1 if bool(p[17]) else 0.0


# --- the camp's movers (the host's residents and cat) --------------------------------

func _movers() -> Array:
	var out: Array = []
	for i in hub.residents.size():
		var w: Wanderer = hub.residents[i]
		if is_instance_valid(w) and w.sprite:
			out.append([i, NetRun.q(w.pos.x), NetRun.q(w.pos.y), w.sprite.anim, w.sprite.flip_h, w.spot])
	if hub.cat and is_instance_valid(hub.cat) and hub.cat.sprite:
		out.append([-1, NetRun.q(hub.cat.pos.x), NetRun.q(hub.cat.pos.y), hub.cat.sprite.anim, hub.cat.sprite.flip_h, -1])
	return out


func _apply_movers(movers: Array) -> void:
	for m in movers:
		var i := int(m[0])
		var who: Prop = hub.cat if i < 0 else (hub.residents[i] if i < hub.residents.size() else null)
		if who == null or not is_instance_valid(who):
			continue
		who.follow_to(Vector2(m[1], m[2]), String(m[3]), bool(m[4]), int(m[5]))
