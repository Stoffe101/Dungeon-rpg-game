## Dev: what a floor pays each Kindled, by source, for a party of one to four
## (`-- economy profile=economy.json`, debug builds only; headless is fine).
## No combat skill and no clock in it: every combat room's waves are spawned
## exactly as the game spawns them (a party's extra foes and its reward
## share included), every foe is felled at once by a Kindled of the party in
## turn, every drop is picked up, every urn broken and every chest opened. So
## it measures the rules, not the bots - the noise in ScalingEval's
## "Embers per room" (it divides by how many rooms bots cleared in a time
## window) is gone.
##
## Args: seeds=12 region=ossuary depth=2 tier=3
class_name EconomyAudit
extends Node

var seeds := 12
var region := "ossuary"
var depth := 2
var tier := 3


func _ready() -> void:
	for a in Dev.args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seeds":
				seeds = int(kv[1])
			"region":
				region = kv[1]
			"depth":
				depth = int(kv[1])
			"tier":
				tier = int(kv[1])
	_go.call_deferred()


func _go() -> void:
	var t0 := Time.get_ticks_msec()
	print("[economy] %d seeds, %s depth %d, Tier %d" % [seeds, region, depth, tier])
	var rows := {}
	for n in range(1, 5):
		var agg := {}
		for s in seeds:
			var r := _floor(n, 5000 + s * 31)
			await get_tree().process_frame
			for k in r:
				agg[k] = float(agg.get(k, 0.0)) + float(r[k]) / seeds
		rows[n] = agg
		print("[economy] x%d  rooms %.1f  embers/Kindled: kills %.1f  rewards %.1f  urns %.1f  chests %.1f  total %.1f   xp/Kindled: kills %.1f  total %.1f   foes %.1f" % [n,
			agg.rooms, agg.e_kills, agg.e_rewards, agg.e_urns, agg.e_chests, agg.e_total, agg.x_kills, agg.x_total, agg.foes])
	_report(rows)
	print("[economy] done in %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit()


## One floor cleared by a party of `n`: what each Kindled banked, by source.
func _floor(n: int, seed_v: int) -> Dictionary:
	seed(seed_v)
	Profile.data = Profile.fresh()
	var run := RunState.create(seed_v, region, "sword", 0, ["flare", "", ""])
	run.tier = tier
	var lay := DungeonGen.generate(seed_v, depth, region, false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(d)
	d.build(lay, run, null)
	var pls: Array = [d.player]
	var sheet := Profile.character_sheet().duplicate(true)
	for k in range(1, n):
		var p := Player.new()
		p.peer_id = k + 1
		p.sheet = sheet
		p.pos = d.random_floor_near(d.player.pos + Vector2(0.9 * k, 0.6), 1.2)
		d.add_actor(p)
		var r := RunState.create(seed_v, region, "sword", 0, ["flare", "", ""])
		r.tier = tier
		p.setup_from(r)
		pls.append(p)
	for p in pls:
		p.godmode = true
	var out := {"e_kills": 0.0, "e_rewards": 0.0, "e_urns": 0.0, "e_chests": 0.0, "x_kills": 0.0, "rooms": 0.0, "foes": 0.0}
	var killer := [0]
	for rm in lay.rooms:
		if not rm.is_combat() or rm.type == Room.Type.BOSS or rm.id == lay.start_id:
			continue
		# everyone into the room, as a party would come in
		for p in pls:
			p.pos = d.random_floor_near(rm.center(), 2.0)
		var e0 := _embers(pls)
		var x0 := _xp(pls)
		d.current_room = rm
		d._start_encounter(rm, pls[0])
		var guard := 0
		while d.active_room == rm and guard < 4000:
			guard += 1
			for e in d.room_enemies.duplicate():
				if is_instance_valid(e) and e.alive and e.state != "spawn":
					var pl: Player = pls[killer[0] % pls.size()]
					killer[0] += 1
					var h := Hit.make(pl, e.hp + e.shield + 9999.0, ["melee"])
					h.can_crit = false
					h.proc = false
					pl.deal_hit(e, h)
					out.foes += 1.0
			d.simulate(1.0 / 30.0)
		_collect(d, pls)
		out.e_kills += _embers(pls) - e0
		out.x_kills += _xp(pls) - x0
		# the room's reward when its gates open
		var e1 := _embers(pls)
		for k in 60:
			d.simulate(1.0 / 30.0)
		_collect(d, pls)
		out.e_rewards += _embers(pls) - e1
		out.rooms += 1.0
	# every urn on the floor, every chest
	var e2 := _embers(pls)
	for pr in d.props.duplicate():
		if is_instance_valid(pr) and pr.kind == "urn" and not pr.used:
			if pr.data.get("urnling", false):
				pr.data["urnling"] = false     # (an Urnling's own fight is not counted here)
			pr.on_struck(pls[0], false)
	for k in 10:
		d.simulate(1.0 / 30.0)
	_collect(d, pls)
	out.e_urns = _embers(pls) - e2
	var e3 := _embers(pls)
	for pr in d.props.duplicate():
		if is_instance_valid(pr) and pr.kind == "chest" and not pr.used and not pr.data.get("sealed", false):
			d.interactor = pls[0]
			pr.interact(pls[0])
	if Game.ui and Game.ui.has_modal():
		Game.ui.close_all()
	for k in 10:
		d.simulate(1.0 / 30.0)
	_collect(d, pls)
	out.e_chests = _embers(pls) - e3
	out["e_total"] = out.e_kills + out.e_rewards + out.e_urns + out.e_chests
	out["x_total"] = _xp(pls) / maxf(1.0, pls.size())
	for k in ["e_kills", "e_rewards", "e_urns", "e_chests", "e_total", "x_kills"]:
		out[k] = float(out[k]) / pls.size() if k != "e_total" else float(out[k]) / pls.size()
	d.queue_free()
	return out


func _collect(d: Dungeon, pls: Array) -> void:
	for pk in d.pickups.duplicate():
		if not is_instance_valid(pk):
			continue
		var who: Player = pls[0]
		for p in pls:
			if p.peer_id == pk.owner_peer:
				who = p
		pk._collect(who)


func _embers(pls: Array) -> float:
	var s := 0.0
	for p in pls:
		s += p.run.embers
	return s


func _xp(pls: Array) -> float:
	var s := 0.0
	for p in pls:
		s += p.run.xp_gained
	return s


func _report(rows: Dictionary) -> void:
	var lines: Array = ["# Economy audit (%s depth %d, Tier %d, %d seeds; every foe felled, every drop taken)" % [region, depth, tier, seeds], "",
		"| party | rooms | foes per room | Embers each: kills | room rewards | urns | chests | total | x solo | XP each: kills | x solo |",
		"|---|---|---|---|---|---|---|---|---|---|---|"]
	var solo: Dictionary = rows[1]
	for n in rows:
		var r: Dictionary = rows[n]
		lines.append("| %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.2f | %.1f | %.2f |" % [n, r.rooms, r.foes / maxf(1.0, r.rooms),
			r.e_kills, r.e_rewards, r.e_urns, r.e_chests, r.e_total, r.e_total / maxf(1.0, solo.e_total), r.x_kills, r.x_kills / maxf(1.0, solo.x_kills)])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open("user://economy_audit.md", FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")
	print("[economy] report written to ", ProjectSettings.globalize_path("user://economy_audit.md"))
