## Dev: party-size scaling evaluation (`-- scaling profile=scaling_eval.json`,
## debug builds only; headless is fine). One to four bot-driven Kindled with
## real builds (src/dev/build_presets.gd, no godmode) fight through real
## floors in this one process, stepped as fast as the machine allows. For each
## party it prints how long a combat room takes, how hard each Kindled is hit,
## how often they fall, and what each one earns - so solo and co-op can be
## compared and the scaling in Dungeon._coop_scale / Party.reward_share tuned.
##
## Args: seeds=2 secs=150 tier=1 region=ossuary depth=1 comps=melee,ranged,mixed
## sizes=1,4 routes=,trial,vault,quiet (compares the Forked Descent's ways)
## It does not exercise the network (that is tools/dev/e2e.sh); it measures
## the rules a host applies.
class_name ScalingEval
extends Node

const COMPS := {
	"melee": ["rush", "rush", "rush", "rush"],
	"ranged": ["hail", "hail", "hail", "hail"],
	"caster": ["knives", "knives", "knives", "knives"],
	"mixed": ["rush", "hail", "lantern", "bulwark"],
}

var seeds := 2
var secs := 150.0
var tier := 3
var region := "ossuary"
var depth := 2
var comps: Array = ["melee", "ranged", "mixed"]
var rows: Array = []
var sizes: Array = [1, 2, 3, 4]
var routes: Array = [""]
var route := ""


func _ready() -> void:
	for a in Dev.args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seeds":
				seeds = int(kv[1])
			"secs":
				secs = float(kv[1])
			"tier":
				tier = int(kv[1])
			"region":
				region = kv[1]
			"depth":
				depth = int(kv[1])
			"comps":
				comps = Array(kv[1].split(","))
			"sizes":
				sizes = Array(kv[1].split(",")).map(func(x): return int(x))
			"routes":
				routes = Array(kv[1].split(","))
	_go.call_deferred()


func _go() -> void:
	var t0 := Time.get_ticks_msec()
	print("[scaling] %d seeds x %.0f s, Tier %d, %s depth %d" % [seeds, secs, tier, region, depth])
	for way in routes:
		route = String(way)
		for comp_id in comps:
			for n in sizes:
				var builds: Array = (COMPS.get(comp_id, [comp_id, comp_id, comp_id, comp_id]) as Array).slice(0, n)     # (a preset alone: four of it)
				var agg := {}
				for s in seeds:
					var r := _run_one(builds, 1000 + s * 17 + n)
					await get_tree().process_frame     # let the finished floor go
					for k in r:
						agg[k] = float(agg.get(k, 0.0)) + float(r[k]) / seeds
				agg["comp"] = comp_id
				agg["n"] = n
				agg["route"] = route
				rows.append(agg)
				print("[scaling] %-7s %-6s x%d  rooms %4.1f  room %5.1fs  floor %4.0fs  hurt/room %4.0f%%  downs/room %.2f  wipes %.2f  xp/room %5.1f  embers/room %5.1f  embers/floor %4.0f finds %.1f" % [route if route != "" else "plain", comp_id, n,
					agg.rooms, agg.room_s, agg.secs, agg.hurt * 100.0, agg.downs, agg.wipe, agg.xp_room, agg.embers_room, agg.embers_room * agg.rooms, agg.finds])
	_report()
	print("[scaling] done in %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit()


## One floor with this party: per-player averages.
func _run_one(builds: Array, seed_v: int) -> Dictionary:
	seed(seed_v)
	# every Kindled's character sheet, as their own machine would send it
	var sheets: Array = []
	for b in builds:
		Profile.data = Profile.fresh()
		BuildPresets.apply(String(b))
		sheets.append(Profile.character_sheet().duplicate(true))
	Profile.data = Profile.fresh()
	BuildPresets.apply(String(builds[0]))
	var run := RunState.create(seed_v, region, Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
	run.tier = tier
	run.route = route
	var lay := DungeonGen.generate(seed_v, depth, region, false, route)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(d)
	d.build(lay, run, null)
	var pls: Array = [d.player]
	for k in range(1, builds.size()):
		var sh: Dictionary = sheets[k]
		var p := Player.new()
		p.peer_id = k + 1
		p.sheet = sh
		p.pos = d.random_floor_near(d.player.pos + Vector2(0.9 * k, 0.6), 1.2)
		d.add_actor(p)
		var r := RunState.create(seed_v, region, String(sh.get("weapon", "sword")), int(sh.get("weapon_level", 0)), sh.get("slots", ["flare", "", ""]))
		r.tier = tier
		p.setup_from(r)
		pls.append(p)
	var bots: Array = []
	for p in pls:
		var bot := Bot.new()
		bot.eval_mode = true
		bot.log_every = 1e9
		p.add_child(bot)
		bots.append(bot)
	var combat_rooms := 0
	for rm in lay.rooms:
		if rm.is_combat() and rm.type != Room.Type.BOSS:
			combat_rooms += 1
	var cleared := [0]
	var on_clear := func(_id: int) -> void: cleared[0] += 1
	Events.room_cleared.connect(on_clear)
	var dt := 1.0 / 60.0
	var t := 0.0
	var combat_t := 0.0
	var hp_prev: Array = pls.map(func(p): return p.hp)
	var hurt: Array = pls.map(func(_p): return 0.0)
	var downs: Array = pls.map(func(_p): return 0)
	var was_down: Array = pls.map(func(_p): return false)
	var wipe := false
	while t < secs:
		for bot in bots:
			if is_instance_valid(bot) and bot.pl and bot.pl.alive and not bot.pl.downed:
				bot._process(dt)
		d.simulate(dt)
		d.fx.step(dt)
		t += dt
		if Game.ui and Game.ui.has_modal():
			Game.ui.close_all()     # relic offers and such: the bots fight on
		if not d.room_enemies.is_empty():
			combat_t += dt
		for i in pls.size():
			var p: Player = pls[i]
			if p.hp < hp_prev[i]:
				hurt[i] += (hp_prev[i] - p.hp) / maxf(1.0, p.max_hp)
			hp_prev[i] = p.hp
			if p.downed and not was_down[i]:
				downs[i] += 1
			was_down[i] = p.downed
		if d._death_t > 0.0:
			wipe = true
			break
		if cleared[0] >= combat_rooms:
			break
	Events.room_cleared.disconnect(on_clear)
	var n := float(pls.size())
	var rooms := maxf(1.0, float(cleared[0]))
	var mins := maxf(t, 1.0) / 60.0
	var out := {
		"rooms": float(cleared[0]),
		"room_s": combat_t / rooms,
		"hurt": _mean(hurt) / rooms,
		"downs": _mean(downs) / rooms,
		"wipe": 1.0 if wipe else 0.0,
		"xp_min": _mean(pls.map(func(p): return p.run.xp_gained)) / mins,
		"embers_min": _mean(pls.map(func(p): return p.run.embers)) / mins,
		# rewards per room cleared: what each Kindled earns for the same content
		"xp_room": _mean(pls.map(func(p): return p.run.xp_gained)) / rooms,
		"embers_room": _mean(pls.map(func(p): return p.run.embers)) / rooms,
		"gear_min": _mean(pls.map(func(p): return (p.run.loot.gear as Array).size())) / mins,
		"finds": _mean(pls.map(func(p): return (p.run.loot.gear as Array).size() + p.run.found.size())),
		"secs": t,
	}
	d.queue_free()
	return out


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


## Each party size against solo with the same builds: the numbers to keep fair.
func _report() -> void:
	var lines: Array = ["# Party-size scaling (Tier %d, %s depth %d, %d seeds x %.0f s, bots, no godmode)" % [tier, region, depth, seeds, secs], "",
		"| party | size | rooms | room time | x solo | hurt per room | downs/room | wipes | XP/room each | x solo | Embers/room each | x solo |", "|---|---|---|---|---|---|---|---|---|---|---|---|"]
	for r in rows:
		var solo := {}
		for o in rows:
			if o.comp == r.comp and int(o.n) == 1:
				solo = o
		lines.append("| %s | %d | %.1f | %.1f s | %.2f | %.0f%% | %.2f | %.2f | %.1f | %.2f | %.1f | %.2f |" % [r.comp, int(r.n), r.rooms, r.room_s,
			r.room_s / maxf(0.1, float(solo.get("room_s", r.room_s))), r.hurt * 100.0, r.downs, r.wipe, r.xp_room,
			r.xp_room / maxf(0.1, float(solo.get("xp_room", r.xp_room))), r.embers_room,
			r.embers_room / maxf(0.1, float(solo.get("embers_room", r.embers_room)))])
	var txt := "\n".join(lines)
	print(txt)
	# beside the dev profiles (game code never writes into the project)
	var f := FileAccess.open("user://scaling_eval.md", FileAccess.WRITE)
	if f:
		f.store_string(txt + "\n")
		f.close()
		print("[scaling] written to ", ProjectSettings.globalize_path("user://scaling_eval.md"))
