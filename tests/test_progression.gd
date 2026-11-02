## Skill tree rules, relic offers, profile currencies, saves and migrations.
extends TestCase


func test_tree_links_are_valid() -> void:
	for id in SkillDB.all_ids():
		for l in SkillDB.node(id).get("links", []):
			check(not SkillDB.node(l).is_empty(), "%s links to missing %s" % [id, l])
		var n := SkillDB.node(id)
		if n.kind == "ability":
			check(GearDB.ABILITIES.has(n.ability), "%s grants unknown ability" % id)


func test_every_node_reachable() -> void:
	var all: Array = SkillDB.all_ids()
	eq(SkillDB.connected_set(all).size(), all.size(), "every node connects to the Hearth")


func test_nodes_do_not_overlap() -> void:
	var ids: Array = SkillDB.all_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var d := SkillDB.position_of(ids[i]).distance_to(SkillDB.position_of(ids[j]))
			check(d > 18.0, "%s and %s overlap (%.1f)" % [ids[i], ids[j], d])


func test_allocation_rules() -> void:
	var alloc := ["hearth"]
	check(SkillDB.can_allocate("b1", alloc, 1), "adjacent to root")
	check(not SkillDB.can_allocate("b2", alloc, 5), "not adjacent")
	check(not SkillDB.can_allocate("b3", ["hearth", "b1", "b2"], 1), "notable needs 2 points")
	check(SkillDB.can_allocate("b3", ["hearth", "b1", "b2"], 2), "notable affordable")
	# refunding a node others depend on is refused
	check(not SkillDB.can_refund("b1", ["hearth", "b1", "b2"]), "b2 depends on b1")
	check(SkillDB.can_refund("b2", ["hearth", "b1", "b2"]), "leaf refund")
	check(not SkillDB.can_refund("hearth", ["hearth"]), "root is permanent")
	eq(SkillDB.spent(["hearth", "b1", "b3", "b6"]), 1 + 2 + 3)


func test_tree_applies_mods_and_abilities() -> void:
	var st := Stats.for_player()
	SkillDB.apply(["hearth", "w1", "g1", "g3"], st)
	near(st.v("max_hp"), 115.0, 0.001)
	check(st.has("dodge_afterimage"), "notable flag applied")
	var ab := SkillDB.abilities(["hearth", "p1", "p2", "p3l"])
	check(ab.has("flare") and ab.has("cinder_lance"), "abilities from nodes")


func test_relic_offer_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var held := ["tinderbox", "whetstone"]
	for i in 30:
		var o := RelicDB.roll_offer(rng, 3, held, {"pyre": 4}, ["flare"], 1)
		eq(o.size(), 3)
		var uniq := {}
		for id in o:
			uniq[id] = true
			check(not held.has(id), "held relic offered")
			var req: String = RelicDB.relic(id).get("requires_ability", "")
			check(req == "" or req == "flare", "offered %s without its ability" % id)
		eq(uniq.size(), 3, "offers are distinct")


func test_relic_offer_deterministic() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	eq(RelicDB.roll_offer(a, 3, [], {}, ["flare"], 1), RelicDB.roll_offer(b, 3, [], {}, ["flare"], 1))


func test_profile_currency_and_levels() -> void:
	Profile.data = Profile.fresh()
	Profile.add_currency("embers", 100)
	check(not Profile.spend("embers", 150), "cannot overspend")
	check(Profile.spend("embers", 60), "spend")
	eq(Profile.currency("embers"), 40)
	check(Profile.pay({"embers": 40}), "pay exact")
	check(not Profile.pay({"embers": 1, "sunshards": 1}), "pay fails atomically")
	eq(Profile.currency("embers"), 0)
	var gained := Profile.add_xp(Combat.xp_to_next(1) + Combat.xp_to_next(2))
	eq(gained, 2)
	eq(Profile.level(), 3)
	eq(Profile.skill_points_free(), 2)
	check(Profile.allocate("b1"), "allocate with points")
	eq(Profile.skill_points_free(), 1)


func test_forge_upgrade_costs() -> void:
	Profile.data = Profile.fresh()
	Profile.add_currency("embers", 10000)
	for i in 2:
		check(Profile.upgrade_weapon("sword"), "upgrade %d" % i)
	check(not Profile.upgrade_weapon("sword"), "level 3 needs a sunshard")
	Profile.add_currency("sunshards", 1)
	check(Profile.upgrade_weapon("sword"), "with a sunshard")
	eq(Profile.weapon_level("sword"), 3)


func test_grudges_stack() -> void:
	Profile.data = Profile.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var g := Profile.record_grudge("husk", 40, 1, rng)
	eq(int(g.level), 1)
	var g2 := Profile.record_grudge("husk", 10, 2, rng)
	eq(int(g2.level), 2, "same killer levels up")
	eq(int(g2.embers), 50)
	eq(Profile.active_grudges().size(), 1)
	check(Profile.record_grudge("warden", 10, 2, rng).is_empty(), "bosses never become grudges")
	Profile.settle_grudge(g.id)
	eq(Profile.active_grudges().size(), 0)


func test_save_roundtrip_and_backup() -> void:
	Profile.path = "user://test_profile.json"
	for f in [Profile.path, Profile.path + ".bak", Profile.path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Profile.data = Profile.fresh()
	Profile.data.embers = 123
	check(Profile.save_profile(), "first save")
	Profile.data.embers = 456
	check(Profile.save_profile(), "second save")
	check(FileAccess.file_exists(Profile.path + ".bak"), "backup kept")
	Profile.data = {}
	Profile.load_profile()
	eq(Profile.currency("embers"), 456)
	eq(Profile.last_load_status, "ok")
	# corrupt the main save: the backup is used
	var f := FileAccess.open(Profile.path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Profile.load_profile()
	eq(Profile.last_load_status, "restored_backup")
	eq(Profile.currency("embers"), 123)


func test_migration_from_v1() -> void:
	var old := {"version": 1, "currency": 77, "skills": {"hearth": true, "b1": true}, "level": 4}
	var m := Profile.migrate(old)
	eq(int(m.version), Profile.VERSION)
	eq(int(m.embers), 77)
	check((m.skills as Array).has("b1"), "skills converted")
	check(m.has("sanctuary") and m.has("grudges") and m.has("stats"), "new sections added")
	eq(int(m.level), 4, "progress preserved")


func test_residents_arrive_with_progress() -> void:
	Profile.data = Profile.fresh()
	eq(Residents.count_present(), 1, "one survivor at first")
	eq(Residents.garden_stage(), 0, "bare planters at first")
	Profile.data.sanctuary.hearth = 3
	Profile.data.stats.runs = 9
	eq(Residents.count_present(), Residents.LIST.size(), "capped at the full roster")
	eq(Residents.garden_stage(), 3, "sunblooms with a strong Hearth")
	var rng := RandomNumberGenerator.new()
	for r in Residents.LIST:
		check(not Residents.talk(r.id).is_empty(), "%s has things to say" % r.id)
		check(Residents.bark(r.id, rng) != "", "%s barks" % r.id)
		check(ResourceLoader.exists("res://assets/sprites/%s.png" % r.sheet), "%s sheet exists" % r.id)
	Profile.data.world.warden_kills = 1
	check(Residents.talk("teodric") != Residents.LIST[1].talk[0], "talk changes after the Warden falls")


func test_skill_path_and_totals() -> void:
	var alloc := ["hearth"]
	var route := SkillDB.path_to("b3", alloc)
	eq(route.get("from"), "hearth", "routes grow from the tree")
	eq(route.nodes.back(), "b3", "ends at the target")
	eq(int(route.cost), SkillDB.cost("b1") + SkillDB.cost("b2") + SkillDB.cost("b3"), "cheapest route cost")
	# every step of the route is allocatable in order
	var pts := 99
	for id in route.nodes:
		check(SkillDB.can_allocate(id, alloc, pts), "%s allocatable in order" % id)
		alloc.append(id)
	check(SkillDB.path_to("b3", alloc).is_empty(), "nothing to route to an allocated node")
	var t := SkillDB.totals(["hearth", "b1", "b4", "w1", "w4"])
	var seen := {}
	for m in t:
		seen["%s|%s" % [m[0], m[1]]] = m[2]
	near(float(seen["melee_damage|add"]), 0.18, 0.001, "melee damage summed")
	near(float(seen["max_hp|add"]), 35.0, 0.001, "health summed")
	UIKit.icon("star")   # loads the atlas map
	for id in SkillDB.all_ids():
		check(UIKit._icon_map.has(SkillDB.icon_of(id)), "%s has an icon (%s)" % [id, SkillDB.icon_of(id)])


func test_mastery_ranks() -> void:
	var alloc: Array = ["hearth", "b1", "b2", "b3", "b4", "b5"]
	check(SkillDB.can_allocate("b_m", alloc, 1), "mastery hangs off a ring-5 notable")
	for r in 5:
		check(SkillDB.can_allocate("b_m", alloc, 1), "rank %d available" % (r + 1))
		alloc.append("b_m")
	eq(SkillDB.rank("b_m", alloc), 5)
	check(not SkillDB.can_allocate("b_m", alloc, 9), "capped at max rank")
	eq(SkillDB.spent(alloc), SkillDB.spent(["hearth", "b1", "b2", "b3", "b4", "b5"]) + 5, "each rank costs a point")
	var st := Stats.for_player()
	var base := st.v("melee_damage")
	SkillDB.apply(["hearth", "b_m", "b_m", "b_m"], st)
	near(st.v("melee_damage") - base, 0.12, 0.0001, "ranks stack")
	check(SkillDB.can_refund("b_m", alloc), "a rank can be removed")
	check(not SkillDB.can_refund("b5", alloc), "the mastery depends on its notable")
	eq(int(SkillDB.branch_counts(alloc).blade), 6, "a ranked mastery counts once per branch")


func test_resident_requests() -> void:
	Profile.data = Profile.fresh()
	eq(Residents.request_state("ama"), "", "not asked yet")
	eq(Residents.note("chest"), [], "nothing counts before the request is given")
	Residents.start_request("ama")
	for i in 3:
		eq(Residents.note("chest"), [], "chest %d counted" % (i + 1))
	eq(Residents.request_progress("ama"), 3)
	eq(Residents.note("chest"), ["Ama"], "the fourth chest completes it")
	eq(Residents.request_state("ama"), "complete")
	Residents.note("chest")
	eq(Residents.request_progress("ama"), 4, "progress stops at the goal")
	var st := Stats.for_player()
	var before := st.v("flask_heal")
	Residents.apply_rewards(st)
	near(st.v("flask_heal"), before, 0.0001, "no gift before handing in")
	check(Residents.claim("ama"), "hand in")
	check(not Residents.claim("ama"), "only once")
	var st2 := Stats.for_player()
	Residents.apply_rewards(st2)
	near(st2.v("flask_heal") - before, 0.1, 0.0001, "the gift is permanent")
	eq(Residents.journal().size(), 1)
	for r in Residents.LIST:
		var req: Dictionary = r.request
		check(req.has_all(["key", "goal", "title", "ask", "done", "reward", "gift"]), "%s request complete" % r.id)


func test_migrate_v3_adds_requests() -> void:
	var old := {"version": 3, "embers": 50, "sunshards": 1, "skills": ["hearth", "b1"], "level": 3,
		"sanctuary": {"hearth": 2, "forge": 1, "apothecary": 0, "shrine": 0}, "grudges": []}
	var m := Profile.migrate(old)
	eq(int(m.version), Profile.VERSION)
	check(m.requests is Dictionary and (m.requests as Dictionary).is_empty(), "requests added")
	eq(int(m.embers), 50, "nothing lost")
	eq(m.skills, ["hearth", "b1"])
