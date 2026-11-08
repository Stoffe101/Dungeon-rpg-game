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


## The first seed with a rule room of this kind, at depth 2.
func _ruled(rule: String) -> Array:
	for s in range(1, 600):
		var lay := DungeonGen.generate(s, 2, "ossuary", false)
		for r in lay.rooms:
			if r.rule == rule:
				return [lay, s, r]
	return []


func _into_rule(rule: String) -> Array:
	var got := _ruled(rule)
	var d := _built(got[0], got[1])
	var r: Room = got[2]
	for a in d.hostiles(Actor.Team.PLAYER):
		a.queue_free()
	d.player.pos = r.center()
	d.current_room = r
	d.active_room = r
	d.objective = {"text": rule, "k": -1.0, "col": Color.WHITE}
	return [d, r]


func test_rule_rooms_are_rare_named_and_fixed_by_the_seed() -> void:
	var floors := 0
	for s in range(1, 121):
		var lay := DungeonGen.generate(s, 2, "ossuary", false)
		var again := DungeonGen.generate(s, 2, "ossuary", false)
		var ruled: Array = lay.rooms.filter(func(r): return r.rule != "")
		eq(ruled.size(), again.rooms.filter(func(r): return r.rule != "").size(), "the same on every machine")
		check(ruled.size() <= 1, "one to a floor")
		if not ruled.is_empty():
			floors += 1
			var r: Room = ruled[0]
			check(DeepEvents.RULES.has(r.rule), "a rule we know")
			eq(r.reward, "rule", "it pays")
			check(r.type == Room.Type.COMBAT and r.objective == "", "only a plain fight")
			check(r.props.filter(func(p): return p.kind == "scar").size() >= 1, "the stone says so first")
	check(floors > 12 and floors < 50, "now and then (%d of 120)" % floors)
	for r in DungeonGen.generate(5, 1, "ossuary", false).rooms:
		eq(r.rule, "", "never on the first floor")


func test_one_pulse_shares_a_blow_with_the_rooms_foes_only() -> void:
	Profile.data = Profile.fresh()
	var o := _into_rule("one_pulse")
	var d: Dungeon = o[0]
	var r: Room = o[1]
	var a := _foe(d, r.center() + Vector2(1, 0))
	var b := _foe(d, r.center() + Vector2(-1, 0))
	var other := _foe(d, r.center() + Vector2(0, 2))
	d.room_enemies = [a, b]
	var h := Hit.make(d.player, 100.0, ["melee"])
	h.can_crit = false
	h.silent = true
	var res := d.player.deal_hit(a, h)
	check(res.amount > 0.0, "the blow lands")
	check(b.hp < 400.0 and b.hp >= 400.0 - res.amount * 0.45, "the other feels part of it (%.0f)" % (400.0 - b.hp))
	eq(other.hp, 400.0, "nothing outside the fight does")
	d.queue_free()


func test_the_unlit_room_shrinks_the_lantern_and_feeds_it_on_a_kill() -> void:
	Profile.data = Profile.fresh()
	var o := _into_rule("unlit")
	var d: Dungeon = o[0]
	var r: Room = o[1]
	d.player._update_lantern(0.02)
	var dim := d.player.lantern.omni_range
	d.objective = {}
	d.player._update_lantern(0.02)
	check(dim < d.player.lantern.omni_range * 0.7, "smaller in there (%.1f, %.1f)" % [dim, d.player.lantern.omni_range])
	d.objective = {"text": "unlit", "k": -1.0, "col": Color.WHITE}
	d.player.kindle = 0.0
	var e := _foe(d, r.center() + Vector2(1, 0), 5.0)
	var h := Hit.make(d.player, 50.0, ["ability"])
	h.can_crit = false
	h.silent = true
	d.player.deal_hit(e, h)
	check(not e.alive and d.player.kindle >= d.player.kindle_max() * 0.19, "a kill feeds it")
	d.queue_free()


func test_the_hungry_floor_makes_foes_quick_and_rich() -> void:
	Profile.data = Profile.fresh()
	var o := _into_rule("hungry")
	var d: Dungeon = o[0]
	var plain := d._make_enemy("husk")
	var e := d._make_enemy("husk")
	e.pos = (o[1] as Room).center()
	d.add_actor(e)
	d.register_enemy(e)
	check(is_equal_approx(e.speed, plain.speed * 1.25), "quicker")
	eq(e.embers, plain.embers * 2, "worth more")
	d.queue_free()


func test_a_rule_fight_pays_a_chest() -> void:
	Profile.data = Profile.fresh()
	var o := _into_rule("hungry")
	var d: Dungeon = o[0]
	var before := d.props.filter(func(p): return is_instance_valid(p) and p.kind == "chest").size()
	d._spawn_reward(o[1])
	eq(d.props.filter(func(p): return is_instance_valid(p) and p.kind == "chest").size(), before + 1, "a chest")
	d.queue_free()


func _event_floor(ev: String) -> Array:
	for s in range(1, 800):
		var lay := DungeonGen.generate(s, 2, "ossuary", false)
		for r in lay.rooms:
			if r.event == ev:
				return [lay, s]
	return []


func _site(d: Dungeon, ev: String) -> Prop:
	for p in d.props:
		if is_instance_valid(p) and p.kind == "site" and String(p.data.get("event", "")) == ev:
			return p
	return null


func test_a_survivor_gives_the_floor_and_comes_home_once() -> void:
	Profile.data = Profile.fresh()
	var got := _event_floor("survivor")
	check(not got.is_empty(), "she can be found")
	var d := _built(got[0], got[1])
	check(Minimap.known_rooms(d).size() < d.layout.rooms.size(), "the floor is unknown")
	var s := _site(d, "survivor")
	check(s != null and s.interactable(), "she can be helped")
	check(not Residents.present("maren"), "not at the Hearth yet")
	s.interact(d.player)
	check(d.charted and s.used, "her map")
	eq(Minimap.known_rooms(d).size(), d.layout.rooms.size(), "every room of it")
	check(Residents.present("maren"), "she is home")
	check(Chronicle.rescued("maren"), "the Chronicle knows")
	d.queue_free()
	# nobody is lost twice
	var world := Chronicle.snapshot()
	for sd in range(1, 100):
		for r in DungeonGen.generate(sd, 2, "ossuary", false, "", world).rooms:
			check(r.event != "survivor", "found is found")


func test_her_request_counts_vaults_and_pays() -> void:
	Profile.data = Profile.fresh()
	Chronicle.rescue("maren")
	Residents.start_request("maren")
	Residents.note("vault")
	eq(Residents.request_state("maren"), "active", "one is not two")
	Residents.note("vault")
	eq(Residents.request_state("maren"), "complete", "two is")
	check(Residents.claim("maren"), "she pays")
	var st := Stats.new()
	st.base["move_speed"] = 5.0
	Residents.apply_rewards(st)
	check(st.v("move_speed") > 5.0, "the gift is real")


func test_the_chart_table_sells_one_descent() -> void:
	Profile.data = Profile.fresh()
	Profile.data.flags["chart_ready"] = true
	Game._take_chart()
	check(Game.chart_run, "this descent's map is whole")
	check(not Profile.data.flags.has("chart_ready"), "and it is spent")
	Game._take_chart()
	check(not Game.chart_run, "only the one")


func test_a_grindstone_whets_each_kindled_once() -> void:
	Profile.data = Profile.fresh()
	var got := _event_floor("artisan")
	check(not got.is_empty(), "it can be found")
	var d := _built(got[0], got[1])
	var run := RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""])
	d.player.run = run
	var s := _site(d, "artisan")
	var before: float = d.player.stats.v("weapon_damage")
	s.interact(d.player)
	check(d.player.run.has_relic("whetted"), "whetted")
	check(s.interactable(), "the stone stays for the next")
	eq((s.data.taken as Array).size(), 1, "one edge")
	s.interact(d.player)
	eq((s.data.taken as Array).size(), 1, "once each")
	check(RelicDB.relic("whetted").get("found", false), "found, never offered")
	for k in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = k
		for o in RelicDB.roll_offer(rng, 3, [], {}, [], 2):
			check(String(o) != "whetted", "not in an offer")
	check(d.player.stats.v("weapon_damage") >= before, "it does not take away")
	d.queue_free()


# --- great things that grow ----------------------------------------------------------

func _great(base := "gloamfang") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return ItemDB.make_item(base, "legendary", 1, rng, 1)


func test_a_great_thing_wakes_with_use_and_says_so() -> void:
	var it := _great()
	check(Evolutions.can_evolve(it), "it can grow")
	eq(Evolutions.stage(it), 0, "asleep")
	check(Evolutions.progress(it).contains("0/"), "the tooltip counts it")
	var before := ItemDB.mods_of(it)
	var said := Evolutions.feed({"weapon": it}, Evolutions.AWAKE)
	eq(Evolutions.stage(it), 1, "awake")
	check(ItemDB.item_name(it).begins_with("Awakened"), "its name says so")
	check(not said.is_empty(), "and the way home says so")
	var grown := ItemDB.mods_of(it)
	check(float(grown[0][2]) > float(before[0][2]), "its own powers grew")


func test_a_path_is_chosen_once_and_gives_another_great_things_power() -> void:
	var it := _great()
	check(not Evolutions.choose(it, "storm"), "not before it is ready")
	it["res"] = Evolutions.ASCEND
	check(Evolutions.ready(it), "ready")
	check(not Evolutions.choose(it, "nothing"), "only its own paths")
	check(Evolutions.choose(it, "storm"), "chosen")
	check(not Evolutions.ready(it), "once")
	check(not Evolutions.choose(it, "shade"), "for good")
	eq(ItemDB.item_name(it), "Gloamfang, Fang of Storms", "named for it")
	var st := Stats.new()
	ItemDB.apply_equipped({"weapon": it}, st)
	check(st.has("storm_crit"), "it has the other's power")
	check(st.has("crit_knives"), "and keeps its own")


func test_every_path_names_a_flag_the_game_reads() -> void:
	var src := FileAccess.get_file_as_string("res://src/entities/player.gd") + FileAccess.get_file_as_string("res://src/entities/enemy.gd") \
		+ FileAccess.get_file_as_string("res://src/combat/volley.gd") + FileAccess.get_file_as_string("res://src/combat/abilities.gd")
	for id in Evolutions.PATHS:
		check(not ItemDB.base(String(id)).is_empty(), "%s exists" % id)
		eq((Evolutions.PATHS[id] as Array).size(), 2, "two ways")
		for p in Evolutions.PATHS[id]:
			for f in p.flags:
				check(src.contains('"%s"' % f), "%s is read somewhere" % f)


func test_anything_else_great_has_the_common_paths_and_trophies_stay_as_they_are() -> void:
	var it := _great("glass_lantern")
	eq(Evolutions.paths_of(it), Evolutions.COMMON, "the common paths")
	it["res"] = Evolutions.ASCEND
	check(Evolutions.choose(it, "hearth"), "chosen")
	var st := Stats.new()
	st.base["kindle_max"] = 100.0
	ItemDB.apply_equipped({"charm": it}, st)
	check(st.v("kindle_max") >= 115.0, "its mods apply")
	check(not Evolutions.can_evolve(_great("rival_fang")), "a trophy is a trophy")
	var plain := ItemDB.make_item("hearthblade", "rare", 1, RandomNumberGenerator.new(), 1)
	check(not Evolutions.can_evolve(plain), "and a sword is a sword")


func test_an_old_save_item_is_simply_asleep_and_a_new_one_survives_the_file() -> void:
	var old := {"uid": 1, "base": "gloamfang", "rarity": "legendary", "level": 1, "tier": 1, "affixes": []}
	eq(Evolutions.stage(old), 0, "asleep")
	eq(ItemDB.item_name(old), "Gloamfang", "named as it was")
	var it := _great()
	it["res"] = Evolutions.ASCEND
	Evolutions.choose(it, "shade")
	var back: Dictionary = JSON.parse_string(JSON.stringify(it))
	eq(Evolutions.stage(back), 2, "after a save it has still chosen")
	eq(ItemDB.item_name(back), ItemDB.item_name(it), "and is still named so")


func test_an_expedition_pays_resonance_half_on_a_death() -> void:
	var run := RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""])
	run.kills = 60
	run.bosses = ["warden"]
	eq(Evolutions.gain_of(run, "extracted"), 90, "by what was done")
	eq(Evolutions.gain_of(run, "died"), 45, "half on a death")


# --- the noticeboard -----------------------------------------------------------------

func test_the_noticeboard_offers_three_and_lets_you_carry_two() -> void:
	Profile.data = Profile.fresh()
	var up := Contracts.offers()
	eq(up.size(), Contracts.OFFERS, "three up")
	check(Contracts.take(String(up[0])), "one taken")
	check(Contracts.take(String(Contracts.offers()[0])), "two taken")
	eq(Contracts.taken().size(), Contracts.CARRY, "hands full")
	var third := String(Contracts.offers()[0])
	check(not Contracts.take(third), "no third")
	check(not Contracts.offers().has(String(Contracts.taken()[0].id)), "what you carry is not on the board")
	Contracts.drop(String(Contracts.taken()[0].id))
	check(Contracts.take(third), "one put back, one taken")


func test_a_notice_counts_what_it_asks_and_pays_on_the_way_home() -> void:
	Profile.data = Profile.fresh()
	Profile.data.contracts = {"offer": ["elites"], "taken": [], "done": 0}
	check(Contracts.take("elites"), "taken")
	Contracts.note("chest")
	eq(int(Contracts.taken()[0].n), 0, "not what it asked for")
	Contracts.note("elite")
	Contracts.note("elite")
	eq(Contracts.note("elite"), ["A Verse or Two"], "finished")
	check(Contracts.note("elite").is_empty(), "counts stop at the goal")
	var embers := Profile.currency("embers")
	var said := Contracts.settle()
	eq(said.size(), 1, "paid")
	eq(Profile.currency("embers"), embers + 200, "in Embers")
	check(Contracts.taken().is_empty(), "off your hands")
	eq(int(Profile.data.contracts.done), 1, "counted")


func test_an_unfinished_notice_is_kept_and_nothing_expires() -> void:
	Profile.data = Profile.fresh()
	Profile.data.contracts = {"offer": ["chests"], "taken": [], "done": 0}
	Contracts.take("chests")
	Contracts.note("chest", 2)
	check(Contracts.settle().is_empty(), "nothing to pay")
	eq(int(Contracts.taken()[0].n), 2, "kept for the next expedition")


func test_every_notice_counts_something_the_game_notes() -> void:
	var src := ""
	for f in ["res://src/world/dungeon.gd", "res://src/world/prop.gd", "res://src/world/pickup.gd", "res://src/entities/enemies/snuffer.gd", "res://src/combat/weapon.gd"]:
		src += FileAccess.get_file_as_string(f)
	for c in Contracts.LIST:
		var counted: bool = src.contains('note_request("%s"' % c.key) or src.contains('_practised("%s"' % c.key) 			or (String(c.key).begins_with("hunt_") and src.contains('note_request("hunt_" + layout.region)'))
		check(counted, "%s is counted" % c.key)
		check(Contracts.pay_text(c.pay) != "", "%s pays" % c.id)
		if c.pay.has("material"):
			check(ItemDB.MATERIALS.has(c.pay.material[0]), "%s is a material" % c.pay.material[0])


# --- rivals --------------------------------------------------------------------------

func _rival(level: int, marks: Array = []) -> Dictionary:
	return {"id": "g1", "enemy": "husk", "name": "Oth the Ruined", "affix": "hasted", "level": level, "embers": 80, "depth": 2,
		"settled": false, "slew": level, "scars": 0, "learned": "ward", "history": ["Slew you: the Ossuary, depth 2."], "marks": marks}


func test_what_drove_a_grudge_off_marks_it_and_something_else_still_works() -> void:
	Profile.data = Profile.fresh()
	Profile.data.grudges = [_rival(2)]
	Profile.scar_grudge("g1", "flamescarred")
	eq(Profile.data.grudges[0].marks, ["flamescarred"], "marked")
	check((Profile.data.grudges[0].history as Array).back().contains("Flamescarred"), "its story says so")
	var d := _floor(7)
	var e := _foe(d, Vector2(_spot(d)) + Vector2(2.5, 0.5))
	e.make_grudge(Profile.data.grudges[0])
	check(e.display_name.contains("Flamescarred"), "named for it")
	e.hp = e.max_hp
	var fire := Hit.make(d.player, 100.0, ["fire"])
	fire.can_crit = false
	var res := e.take_hit(fire)
	check(res.amount < 70.0, "fire does little (%.0f)" % res.amount)
	var steel := Hit.make(d.player, 100.0, ["melee"])
	steel.can_crit = false
	var res2 := e.take_hit(steel)
	check(res2.amount > res.amount * 1.5, "anything else bites as ever (%.0f)" % res2.amount)
	d.queue_free()


func test_a_scar_is_only_counted_once_per_kind() -> void:
	Profile.data = Profile.fresh()
	Profile.data.grudges = [_rival(2)]
	Profile.scar_grudge("g1", "hardened")
	Profile.scar_grudge("g1", "hardened")
	eq((Profile.data.grudges[0].marks as Array).size(), 1, "bounded")
	eq(int(Profile.data.grudges[0].scars), 2, "both scars counted")


func test_a_grown_grudge_makes_a_last_stand_once() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var e := _foe(d, Vector2(_spot(d)) + Vector2(2.5, 0.5))
	e.make_grudge(_rival(4))
	e.state = "chase"
	e.set_meta("grudge_id", "g1")
	var foes: int = d.hostiles(Actor.Team.PLAYER).size()
	e.room_id = d.layout.start_id
	e.hp = e.max_hp * 0.4
	e._grudge_tick(0.03)
	check(e._reckoned, "it stands")
	check(e.hp > e.max_hp * 0.5, "it heals a little")
	check(d.hostiles(Actor.Team.PLAYER).size() >= foes + 3, "it calls kin")
	var hp := e.hp
	e.hp = e.max_hp * 0.4
	foes = d.hostiles(Actor.Team.PLAYER).size()
	e._grudge_tick(0.03)
	eq(d.hostiles(Actor.Team.PLAYER).size(), foes, "only once")
	check(hp > 0.0, "still standing")
	d.queue_free()


func test_a_grudge_at_its_greatest_no_longer_runs() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var e := _foe(d, Vector2(_spot(d)) + Vector2(2.5, 0.5))
	e.make_grudge(_rival(Profile.GRUDGE_MAX_LEVEL))
	e.state = "chase"
	e._reckoned = true
	e.hp = e.max_hp * 0.2
	e._grudge_tick(0.03)
	check(e.alive and not e.has_meta("fled"), "this ends one way or the other")
	d.queue_free()


func test_finishing_a_nemesis_is_kept_for_good() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	var e := _foe(d, Vector2(_spot(d)) + Vector2(2.5, 0.5))
	e.make_grudge(_rival(Profile.GRUDGE_MAX_LEVEL))
	e.set_meta("grudge_level", Profile.GRUDGE_MAX_LEVEL)
	e.set_meta("grudge_owner", Net.my_id())
	d._grudge_trophy(e)
	check((Profile.data.world.nemeses as Array).size() == 1, "on the Shrine's list")
	eq(Chronicle.marks("nemeses"), 1, "and in the Chronicle")
	d.queue_free()


func test_an_old_grudge_reads_without_marks() -> void:
	Profile.data = Profile.fresh()
	var old := _rival(2)
	old.erase("marks")
	var m := Profile.migrate({"version": 15, "grudges": [old], "contracts": null})
	eq(int(m.version), Profile.VERSION, "brought up to date")
	eq(m.grudges[0].marks, [], "no marks yet")
	check(m.contracts is Dictionary, "a noticeboard")


# --- the satchel ---------------------------------------------------------------------

func test_the_bag_can_be_filtered_and_ordered_without_changing_it() -> void:
	var bag: Array = [
		{"uid": 1, "base": "hearthblade", "rarity": "common", "tier": 1, "level": 1},
		{"uid": 2, "base": "gloamfang", "rarity": "legendary", "tier": 1, "level": 1},
		{"uid": 3, "base": "glass_lantern", "rarity": "legendary", "tier": 3, "level": 1},
	]
	eq(int(InventoryUI.arranged(bag, "all", "new")[0].uid), 3, "newest first")
	eq(InventoryUI.arranged(bag, "weapon", "new").size(), 2, "arms only")
	eq(InventoryUI.arranged(bag, "jewel", "new").size(), 1, "rings and charms")
	eq(InventoryUI.arranged(bag, "armour", "new").size(), 0, "nothing worn on the body")
	eq(int(InventoryUI.arranged(bag, "all", "tier")[0].uid), 3, "highest tier")
	eq(int(InventoryUI.arranged(bag, "all", "rarity").back().uid), 1, "plainest last")
	eq(int(bag[0].uid), 1, "the bag itself is untouched")


func test_a_rough_upgrade_hint_goes_by_tier_then_rarity() -> void:
	var a := {"tier": 2, "rarity": "common", "level": 1}
	var b := {"tier": 1, "rarity": "legendary", "level": 9}
	check(InventoryUI.looks_better(a, b), "tier first")
	check(not InventoryUI.looks_better(b, a), "and not the other way")
	check(InventoryUI.looks_better(a, {}), "anything beats an empty slot")


# --- old hands, the deep, bots ---------------------------------------------------------

func test_mastery_notices_wait_for_a_seasoned_kindled() -> void:
	Profile.data = Profile.fresh()
	for k in 40:
		Profile.data.contracts = {"offer": [], "taken": [], "done": k}
		for id in Contracts.offers():
			check(not Contracts.def_of(String(id)).get("mastery", false), "not for a beginner")
	Profile.data.stats["victories"] = 1
	var seen := false
	for k in 40:
		Profile.data.contracts = {"offer": [], "taken": [], "done": k}
		for id in Contracts.offers():
			seen = seen or Contracts.def_of(String(id)).get("mastery", false)
	check(seen, "up once a guardian has fallen")


func test_a_floor_left_unhurt_and_quickly_counts_and_a_hurt_one_does_not() -> void:
	Profile.data = Profile.fresh()
	Profile.data.stats["victories"] = 1
	Profile.data.contracts = {"offer": ["untouched", "quick"], "taken": [], "done": 0}
	Contracts.take("untouched")
	Contracts.take("quick")
	var d := _floor(7)
	d.run.rooms_cleared += 1
	d.floor_left()
	eq(Contracts.taken().filter(func(t): return Contracts.finished(t)).size(), 2, "both")
	d.queue_free()
	Profile.data.contracts = {"offer": ["untouched"], "taken": [], "done": 0}
	Contracts.take("untouched")
	var e := _floor(7)
	e.run.rooms_cleared += 1
	e.run.note_blow(1.0, "Husk", 12.0)
	e.floor_left()
	check(not Contracts.finished(Contracts.taken()[0]), "a blow landed")
	e.queue_free()


func test_the_deep_has_moods_three_depths_at_a_time() -> void:
	eq(Delve.band(3), {}, "not in the regions")
	eq(String(Delve.band(4).id), "whisper", "the first")
	eq(String(Delve.band(6).id), "whisper", "three depths of it")
	eq(String(Delve.band(7).id), "thin", "then the next")
	eq(String(Delve.band(16).id), "whisper", "and round again")
	eq(DungeonGen.plan_of(5, 13, false) in ["wing", "ring"], true, "the Old Roads run in rings and wings")


func test_a_bot_reads_the_warning_shapes_a_player_sees() -> void:
	check(Bot.inside(Vector2(1, 0), Vector2.ZERO, {"kind": Fx.Shape.DISC, "size": Vector2(4, 4)}), "in a disc")
	check(not Bot.inside(Vector2(5, 0), Vector2.ZERO, {"kind": Fx.Shape.DISC, "size": Vector2(4, 4)}), "outside it")
	var line := {"kind": Fx.Shape.RECT, "dir": Vector2.RIGHT, "size": Vector2(8, 1)}
	check(Bot.inside(Vector2(4, 0.2), Vector2.ZERO, line), "on a line")
	check(not Bot.inside(Vector2(4, 2.0), Vector2.ZERO, line), "beside it")
	var cone := {"kind": Fx.Shape.CONE, "dir": Vector2.RIGHT, "size": Vector2(6, 6), "half": 0.6}
	check(Bot.inside(Vector2(2, 0.2), Vector2.ZERO, cone), "in a cone")
	check(not Bot.inside(Vector2(-2, 0), Vector2.ZERO, cone), "behind it")


# --- what a run keeps ------------------------------------------------------------------

func test_a_run_remembers_who_hurt_you_and_keeps_only_the_last_few_blows() -> void:
	var r := RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""])
	for k in 9:
		r.note_blow(float(k), "Husk" if k < 8 else "Archer", 10.0)
	eq(r.blows.size(), RunState.BLOWS_KEPT, "the last few")
	eq(String(r.blows.back()[1]), "Archer", "in order")
	eq(float(r.taken["Husk"]), 80.0, "the whole account")
	var back := RunState.from_dict(r.to_dict())
	eq(float(back.taken["Archer"]), 10.0, "it reaches a guest's machine")


func test_a_blow_on_a_kindled_is_counted_under_its_name() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(7)
	d.player.run = RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""])
	var e := _foe(d, d.player.pos + Vector2(1, 0))
	var h := Hit.make(e, 20.0, ["melee"])
	h.can_crit = false
	d.player.take_enemy_hit(h, e)
	check(d.player.run.taken.has(e.display_name), "by name")
	d.queue_free()


func test_the_top_of_a_ledger_is_named_with_its_share() -> void:
	eq(Screens.top_source({}), [], "nothing")
	var t := Screens.top_source({"Husk": 75.0, "Archer": 25.0})
	eq(String(t[0]), "Husk", "the most")
	eq(float(t[1]), 0.75, "and how much")


func test_the_hud_only_comes_in_on_very_wide_screens() -> void:
	eq(HUD.side_inset(Vector2(960, 540), "centered"), 0.0, "16:9 is left alone")
	eq(HUD.side_inset(Vector2(640, 360), "centered"), 0.0, "at any scale")
	check(HUD.side_inset(Vector2(1720, 720), "centered") > 100.0, "21:9 comes in")
	eq(HUD.side_inset(Vector2(1720, 720), "full"), 0.0, "and the setting keeps it out")
