## The Shifting Undervault: floors that ask to be walked differently, barred ways
## and what opens them, what a floor remembers, and what is in a room to use.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _floor(seed_v: int, region := "ossuary", depth := 2, world := {}, route := "") -> Dungeon:
	var lay := DungeonGen.generate(seed_v, depth, region, false, route, world)
	return _built(lay, seed_v, region, depth, world)


func _built(lay: DungeonGen.Layout, seed_v: int, region := "ossuary", depth := 2, world := {}) -> Dungeon:
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(seed_v, region, "sword", 0, ["flare", "", ""])
	run.depth = depth
	run.world = world
	d.build(lay, run, null)
	return d


## The first floor of this plan, and the seed it came from.
func _planned(plan: String) -> Array:
	DungeonGen.force_plan = plan
	var out: Array = []
	for s in range(1, 200):
		var lay := DungeonGen.generate(s, 2, "ossuary", false)
		if lay.plan == plan:
			out = [lay, s]
			break
	DungeonGen.force_plan = ""
	return out


## Rooms reachable from the start through open doors. `open`: locks treated as open.
func _reach(lay: DungeonGen.Layout, open: Array = []) -> Dictionary:
	var seen := {lay.start_id: true}
	var q: Array = [lay.start_id]
	while not q.is_empty():
		var r: Room = lay.room(q.pop_back())
		for d in r.doors:
			var li := int(d.get("lock", -1))
			if d.secret or (li >= 0 and not open.has(li)) or seen.has(d.to):
				continue
			seen[d.to] = true
			q.append(d.to)
	return seen


func _prop(d: Dungeon, kind: String) -> Prop:
	for p in d.props:
		if is_instance_valid(p) and p.kind == kind:
			return p
	return null


func test_every_plan_is_used_and_chosen_by_the_seed_alone() -> void:
	var seen := {}
	for s in 200:
		var p := DungeonGen.plan_of(s, 2, false)
		eq(p, DungeonGen.plan_of(s, 2, false), "the same floor every time")
		seen[p] = int(seen.get(p, 0)) + 1
	for p in DungeonGen.PLANS:
		check(int(seen.get(p, 0)) >= 15, "%s floors exist (%d of 200)" % [p, int(seen.get(p, 0))])
	eq(DungeonGen.plan_of(5, 3, true), "plain", "a guardian's floor keeps its plain way")
	eq(DungeonGen.plan_of(5, 2, false, "breach"), "direct", "a rare way is one idea")


func test_a_direct_floor_is_shorter() -> void:
	DungeonGen.force_plan = "direct"
	var a := DungeonGen.generate(11, 2, "ossuary", false)
	DungeonGen.force_plan = "plain"
	var b := DungeonGen.generate(11, 2, "ossuary", false)
	DungeonGen.force_plan = ""
	check(a.rooms.size() < b.rooms.size(), "fewer rooms (%d against %d)" % [a.rooms.size(), b.rooms.size()])


func test_a_silent_passage_never_holds_a_key_room() -> void:
	for s in 60:
		check(DungeonGen.plan_of(s, 2, false, "quiet") in ["direct", "plain"], "no elite to promise away")


func test_a_wing_can_always_be_finished_and_its_vault_only_with_the_key() -> void:
	DungeonGen.force_plan = "wing"
	var wings := 0
	for region in ["ossuary", "rootmire", "throne"]:
		for depth in [1, 2]:
			for s in range(1, 21):
				var lay := DungeonGen.generate(s, depth, region, false)
				if lay.plan != "wing":
					continue
				wings += 1
				var open := _reach(lay)
				check(open.has(lay.exit_id), "the way down never needs the key (%s %d %d)" % [region, depth, s])
				check(open.has(lay.key_room), "the key is always reachable (%s %d %d)" % [region, depth, s])
				check(not open.has(lay.vault_room), "the vault is shut without it")
				eq(lay.room(lay.key_room).reward, "key", "its room pays the key")
				check(_reach(lay, [0]).has(lay.vault_room), "and open with it")
				var tiles: Array = lay.locks[0].tiles
				check(not tiles.is_empty(), "bars stand in the way")
				for t: Vector2i in tiles:
					eq(lay.grid.at(t.x, t.y), TileGrid.GATE, "shut at the start")
	DungeonGen.force_plan = ""
	check(wings >= 30, "wings were tested (%d)" % wings)


func test_a_way_back_joins_late_to_early_and_needs_nothing_to_finish() -> void:
	DungeonGen.force_plan = "ring"
	var rings := 0
	for s in range(1, 60):
		var lay := DungeonGen.generate(s, 2, "ossuary", false)
		if lay.plan != "ring":
			continue
		rings += 1
		var open := _reach(lay)
		check(open.has(lay.exit_id), "the floor can be finished with it shut")
		check(open.has(int(lay.locks[0].a)), "its lever can be reached")
	DungeonGen.force_plan = ""
	check(rings >= 45, "ways back exist (%d of 59)" % rings)


func test_the_key_opens_the_vault_on_a_real_floor() -> void:
	Profile.data = Profile.fresh()
	var got := _planned("wing")
	var d := _built(got[0], got[1])
	var plate := _prop(d, "lock_plate")
	check(plate != null, "a plate beside the bars")
	check(plate.interactable(), "it can be used")
	# no key: nothing moves
	plate.interact(d.player)
	check(not plate.used and not d.layout.locks[0].open, "barred without the key")
	var t: Vector2i = d.layout.locks[0].tiles[0]
	check(d.astar.is_point_solid(t), "foes cannot path through it either")
	# the key's room won, the key taken
	d._spawn_reward(d.layout.room(d.layout.key_room))
	var altar := _prop(d, "key_altar")
	check(altar != null, "the room pays its key")
	altar.interact(d.player)
	check(d.has_key, "the party carries it")
	check(String(d.objective.get("text", "")).contains("KEY"), "the HUD says what to do with it")
	plate.interact(d.player)
	check(d.layout.locks[0].open, "it opens")
	eq(d.grid.at(t.x, t.y), TileGrid.FLOOR, "the way is floor")
	check(not d.astar.is_point_solid(t), "and walkable")
	check(not d.has_key, "the key is spent")
	check(not String(d.objective.get("text", "")).contains("KEY"), "and the HUD's task is done")
	d.queue_free()


func test_a_rooms_seal_leaves_barred_ways_alone_and_works_once_open() -> void:
	Profile.data = Profile.fresh()
	var got := _planned("ring")
	var d := _built(got[0], got[1])
	var lk: Dictionary = d.layout.locks[0]
	var a: Room = d.layout.room(int(lk.a))
	var bars: Array = lk.tiles
	d._seal(a, false)
	for t: Vector2i in bars:
		eq(d.grid.at(t.x, t.y), TileGrid.GATE, "the fight ending does not lift the bars")
		check(d.astar.is_point_solid(t), "and foes still cannot pass")
	d.open_lock(0)
	d._seal(a, true)
	var sealed := 0
	for g in d.gate_nodes.get(a.id, []):
		if int(g.get_meta("lock", -1)) == 0:
			var t: Vector2i = g.get_meta("tile")
			eq(d.grid.at(t.x, t.y), TileGrid.GATE, "an open way seals like any door")
			sealed += 1
	check(sealed > 0, "it has gates of its own")
	d.queue_free()


func test_a_lever_opens_the_way_back_once() -> void:
	Profile.data = Profile.fresh()
	var got := _planned("ring")
	var d := _built(got[0], got[1])
	var lever := _prop(d, "lever")
	check(lever != null, "a lever on the far side")
	eq(lever.room_id, int(d.layout.locks[0].a), "in the late room")
	lever.interact(d.player)
	check(d.layout.locks[0].open and lever.used, "pulled, it stays")
	check(not lever.interactable(), "once")
	d.queue_free()


func test_each_altar_answer_changes_the_stone_and_stays_walkable() -> void:
	for state in ["kindled", "broken", "pact"]:
		var want: String = {"kindled": "lamp", "broken": "rubble", "pact": "pale_growth"}[state]
		var found := 0
		for s in range(1, 13):
			var lay := DungeonGen.generate(s, 2, "ossuary", false, "", {"sites": {"ossuary": state}})
			check(_reach(lay).has(lay.exit_id), "%s: the floor still goes down" % state)
			for r in lay.rooms:
				for pd in r.props:
					if String(pd.kind) == want or String(pd.get("sheet", "")) == want:
						found += 1
		check(found >= 12, "%s leaves a mark you can see (%d)" % [state, found])


func test_a_pact_opens_a_pale_door_where_the_map_allows() -> void:
	var doors := 0
	for s in range(1, 40):
		var lay := DungeonGen.generate(s, 2, "ossuary", false, "", {"sites": {"ossuary": "pact"}})
		for lk in lay.locks:
			if lk.kind == "pale":
				doors += 1
	check(doors >= 3, "some floors have one (%d)" % doors)


func test_a_cold_lantern_waits_where_you_fell_and_is_lit_once() -> void:
	Profile.data = Profile.fresh()
	Chronicle.record_fall("ossuary", 2, "Sarn")
	var world := Chronicle.snapshot()
	eq(DungeonGen.generate(4, 1, "ossuary", false, "", world).lantern_room, -1, "not on another depth")
	var d := _floor(4, "ossuary", 2, world)
	var lamp := _prop(d, "cold_lantern")
	check(lamp != null, "it lies on that depth")
	d.player.kindle = 0.0
	lamp.interact(d.player)
	check(d.player.kindle > 0.0, "it gives your light back")
	check(lamp.used, "once")
	check((Chronicle.snapshot().falls as Dictionary).is_empty(), "and the Chronicle lets it go")
	d.queue_free()


func _foe(d: Dungeon, at: Vector2, hp := 400.0) -> Enemy:
	var e := d._make_enemy("husk")
	e.pos = at
	d.add_actor(e)
	e.max_hp = hp
	e.hp = hp
	e.speed = 0.0
	return e


func _spot(d: Dungeon) -> Vector2i:
	return Vector2i(d.layout.room(d.layout.start_id).center())


func _run(d: Dungeon, seconds: float) -> void:
	for i in int(seconds * 30.0):
		d.simulate(1.0 / 30.0)


func test_a_struck_column_falls_the_way_it_was_hit_and_hurts_what_is_there() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var t := _spot(d)
	var strut := Prop.make(d, "strut", t, {})
	check(strut.breakable, "it answers to a blow")
	d.player.pos = Vector2(t) + Vector2(-2.0, 0.5)
	var under := _foe(d, Vector2(t) + Vector2(3.0, 0.5))
	var clear := _foe(d, Vector2(t) + Vector2(-3.5, 0.5))
	strut.on_struck(d.player)
	eq(under.hp, 400.0, "marked first: it does not land at once")
	_run(d, 1.2)
	check(under.hp < 300.0, "it lands on what stood there (%.0f left)" % under.hp)
	eq(clear.hp, 400.0, "and only there")
	check(not strut.breakable, "it falls once")
	d.queue_free()


func test_a_guardian_is_too_great_for_the_room() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var e := _foe(d, Vector2(_spot(d)) + Vector2(0.5, 0.5))
	e.def = e.def.duplicate()
	e.def["boss"] = true
	d._blast(e.pos, func(_a): return true, 0.5, 0.0, d.player, Color.WHITE)
	eq(e.hp, 400.0, "a column does not settle a guardian")
	d.queue_free()


func test_jars_set_each_other_off() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var t := _spot(d)
	var a := Prop.make(d, "kindle_jar", t, {})
	var b := Prop.make(d, "kindle_jar", t + Vector2i(2, 0), {})
	var far := Prop.make(d, "kindle_jar", t + Vector2i(7, 0), {})
	d.player.pos = Vector2(t) + Vector2(-5.0, 0.5)
	a.on_struck(d.player)
	_run(d, 1.0)
	check(b.used, "the next jar goes up")
	check(not far.used, "and not the room")
	d.queue_free()


func test_a_vent_freezes_foes_and_leaves_kindled_alone() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var t := _spot(d)
	var v := Prop.make(d, "rime_vent", t, {})
	var e := _foe(d, Vector2(t) + Vector2(1.0, 0.5))
	d.player.pos = Vector2(t) + Vector2(0.5, 1.0)
	v.on_struck(d.player)
	_run(d, 2.0)
	check(e.status.is_frozen() or e.status.chill > 0.3, "cold takes the foe")
	eq(d.player.status.chill, 0.0, "not the Kindled who loosed it")
	d.queue_free()


func test_a_click_out_of_reach_walks_over_and_uses_it() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var t := _spot(d)
	var p := Prop.make(d, "lever", t, {"lock": -1, "prompt": "Pull", "label": "A lever"})
	d.player.pos = Vector2(t) + Vector2(4.5, 0.5)
	check(d.interactable_at(p.pos, d.player.pos) == null, "out of reach")
	check(d.player.approach(p), "the click is heard")
	var used := int(d.player.presses.interact)
	for i in 120:
		d.player.move_in = Vector2.ZERO
		d.player._tend_approach(1.0 / 30.0)
		d.player.pos += d.player.move_in * 5.0 / 30.0
		if int(d.player.presses.interact) > used:
			break
	check(int(d.player.presses.interact) > used, "it walked over and used it")
	check(d.player._approach == null, "and stopped")
	d.queue_free()


func test_keys_take_over_from_a_click() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var t := _spot(d)
	var p := Prop.make(d, "lever", t, {"lock": -1, "prompt": "Pull", "label": "A lever"})
	d.player.pos = Vector2(t) + Vector2(4.5, 0.5)
	d.player.approach(p)
	d.player.move_in = Vector2.RIGHT
	d.player._tend_approach(0.03)
	check(d.player._approach == null, "walking cancels it")
	d.queue_free()
