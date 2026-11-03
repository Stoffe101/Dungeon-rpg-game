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
	for m in ["bone_dust", "grave_iron", "soul_glass"]:
		Profile.add_material(m, 20)
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
	eq(int(m.embers), 77 + (1500 if Profile.TEST_STOCKPILE else 0), "currency carried over (plus the v5 test stockpile)")
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
	eq(int(m.embers), 50 + (1500 if Profile.TEST_STOCKPILE else 0), "nothing lost")
	eq(m.skills, ["hearth", "b1"])


func test_gear_rolls_and_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var common := ItemDB.make_item("grave_iron_helm", "common", 1, rng)
	eq((common.affixes as Array).size(), 0, "commons have no affixes")
	var epic := ItemDB.make_item("grave_iron_helm", "epic", 3, rng)
	eq((epic.affixes as Array).size(), 2, "epics roll two")
	var armor := 0.0
	for m in ItemDB.mods_of(epic):
		if m[0] == "armor" and m[1] == "add":
			armor += float(m[2])
	check(armor > 0.06 * 1.3, "level and rarity scale the base (%.3f)" % armor)
	var leg := ItemDB.make_item("gloamward_lantern", "common", 1, rng)
	eq(leg.rarity, "legendary", "boss pieces are always legendary")
	for b in ItemDB.BASES:
		var base: Dictionary = ItemDB.BASES[b]
		check(String(base.slot) in ItemDB.SLOTS, "%s has a valid slot" % b)
		check(base.has("recipe") or base.get("legendary", false) or base.has("set"), "%s can be crafted, drops as a set piece or from a boss" % b)
		if base.has("set"):
			check(ItemDB.SETS.has(base.set), "%s belongs to a known set" % b)
		for k in base.get("recipe", {}):
			check(k == "embers" or ItemDB.MATERIALS.has(k), "%s recipe uses a known material %s" % [b, k])


func test_inventory_equip_craft_salvage() -> void:
	Profile.data = Profile.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	check(not Profile.can_pay(ItemDB.recipe("grave_iron_helm")), "nothing to craft with at first")
	Profile.add_material("grave_iron", 5)
	Profile.add_material("bone_dust", 3)
	Profile.add_currency("embers", 80)
	check(Profile.pay(ItemDB.recipe("grave_iron_helm")), "the recipe is paid")
	eq(Profile.material("grave_iron"), 0)
	eq(Profile.currency("embers"), 0)
	var it := Profile.add_item(ItemDB.craft("grave_iron_helm", rng))
	check(int(it.uid) > 0, "items get ids")
	var base_st := Stats.for_player()
	var before := base_st.v("armor")
	check(Profile.equip(it.uid), "equip")
	eq(Profile.bag().size(), 0, "moved out of the bag")
	var st := Stats.for_player()
	Profile.apply_gear(st)
	check(st.v("armor") > before, "equipped gear adds its stats")
	var other := Profile.add_item(ItemDB.make_item("gravecloth_hood", "common", 1, rng))
	check(Profile.equip(other.uid), "swap")
	eq(Profile.bag().size(), 1, "the old helm went back to the bag")
	eq(int(Profile.equipped().head.uid), int(other.uid))
	var y := Profile.salvage(it.uid)
	check(int(y.get("grave_iron", 0)) >= 1, "salvage returns materials")
	eq(Profile.bag().size(), 0)


func test_run_loot_settlement() -> void:
	var r := RunState.create(1, "ossuary", "sword", 0, ["flare", ""])
	r.add_material("bone_dust", 5)
	r.add_material("soul_glass", 1)
	(r.loot.gear as Array).append({"base": "soft_boots", "rarity": "common", "level": 1, "affixes": []})
	var died := r.settle_loot("died")
	eq(int(died.materials.bone_dust), 2, "half the materials (rounded down) on a death")
	eq(int(died.materials.soul_glass), 0)
	eq((died.gear as Array).size(), 1, "gear found is kept")
	eq(int(r.settle_loot("extracted").materials.bone_dust), 5, "everything on extraction")


func test_sets_uniques_and_looks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for s in ItemDB.SETS:
		eq(ItemDB.set_pieces(s).size(), 5, "%s has five pieces" % s)
	var eq_gear := {}
	eq(ItemDB.gear_look(eq_gear), "kindled", "no gear, plain look")
	eq_gear["head"] = ItemDB.make_item("emberwrought_helm", "common", 1, rng, 2)
	eq(String(eq_gear.head.rarity), "set", "set pieces are set rarity")
	eq(ItemDB.gear_look(eq_gear), "kindled", "one piece is not enough for the look")
	eq_gear["chest"] = ItemDB.make_item("emberwrought_plate", "set", 1, rng, 2)
	eq(ItemDB.gear_look(eq_gear), "emberwrought", "two pieces wear the set's look")
	var st := Stats.for_player()
	var fire_before := st.v("fire_damage")
	ItemDB.apply_equipped(eq_gear, st)
	check(st.v("fire_damage") >= fire_before + 0.2, "2-piece bonus applies")
	check(not st.has("ember_set4"), "4-piece bonus needs four")
	eq_gear["hands"] = ItemDB.make_item("emberwrought_gauntlets", "set", 1, rng, 2)
	eq_gear["feet"] = ItemDB.make_item("emberwrought_greaves", "set", 1, rng, 2)
	var st4 := Stats.for_player()
	ItemDB.apply_equipped(eq_gear, st4)
	check(st4.has("ember_set4"), "4-piece bonus applies")
	var uq := ItemDB.make_item("squeaky_clogs", "common", 1, rng)
	eq(String(uq.rarity), "legendary", "uniques are legendary")
	var st_u := Stats.for_player()
	ItemDB.apply_equipped({"feet": uq}, st_u)
	check(st_u.has("squeaky"), "unique flags apply")
	eq(st_u.v("dodge_charges"), Stats.PLAYER_BASE.dodge_charges + 1.0, "integral mods do not scale")
	var hi := ItemDB.make_item("grave_iron_helm", "common", 1, rng, 5)
	var lo := ItemDB.make_item("grave_iron_helm", "common", 1, rng, 1)
	check(float(ItemDB.mods_of(hi)[0][2]) > float(ItemDB.mods_of(lo)[0][2]) * 2.0, "higher tiers are stronger")
	for b in ItemDB.blueprints():
		check(ItemDB.recipe(b).size() > 0, "%s has a recipe" % b)
	check(ItemDB.roll_blueprint(rng, ItemDB.blueprints()) == "", "nothing left to find when all are known")


func test_blueprints_and_difficulty() -> void:
	Profile.data = Profile.fresh()
	eq(Difficulty.unlocked(), 2, "tiers I and II open")
	Difficulty.select(5)
	eq(Difficulty.selected(), 2, "cannot pick a locked tier")
	eq(Difficulty.on_victory("ossuary", 2), [], "a normal region opens nothing")
	eq(Difficulty.craft_tier(), 2, "crafting follows the best win")
	eq(Difficulty.on_victory("throne", 2), [3, 4], "the capstone opens the next two tiers")
	eq(Difficulty.unlocked(), 4)
	check(Difficulty.hp_mult(4) > Difficulty.hp_mult(3), "tiers get tougher")
	Profile.scrolls().append("gamblers_coin")
	check(Profile.learn_blueprint("gamblers_coin"), "learn a scroll")
	check(Profile.known_blueprints().has("gamblers_coin"), "it is known")
	check(Profile.scrolls().is_empty(), "the scroll is used up")
	check(Difficulty.power() >= 90, "a fresh Kindled has about 100 power (%d)" % Difficulty.power())
	eq(Difficulty.recommended(), 1, "fresh: Tier I")


func _husk() -> Enemy:
	var scr: GDScript = load(EnemyDB.get_def("husk").script)
	var e: Enemy = scr.new()
	e.configure("husk")
	return e


func test_tier_scaling() -> void:
	var a := _husk()
	var b := _husk()
	a.scale_for(1, 0, 1)
	b.scale_for(1, 0, 4)
	near(b.max_hp / a.max_hp, Difficulty.hp_mult(4), 0.01, "tier IV health")
	near(b.damage / a.damage, Difficulty.damage_mult(4), 0.01, "tier IV damage")
	check(b.embers > a.embers and b.xp > a.xp, "tier IV pays more")
	var e := _husk()
	e.make_elite("hasted", "vampiric")
	check(e.has_affix("hasted") and e.has_affix("vampiric"), "two affixes")
	check(not e.has_affix("volatile"), "only those two")
	var f := _husk()
	f.make_elite("warded", "warded")
	eq(f.affix2, "", "a duplicate second affix is dropped")
	for x in [a, b, e, f]:
		x.free()


func test_level_cap_and_renown() -> void:
	Profile.data = Profile.fresh()
	Profile.data.level = Profile.MAX_LEVEL - 1
	Profile.add_xp(Combat.xp_to_next(Profile.MAX_LEVEL - 1) + Profile.renown_step() * 2 + 5)
	eq(Profile.level(), Profile.MAX_LEVEL, "levels stop at the cap")
	eq(Profile.renown(), 2, "experience past the cap becomes Renown")
	eq(Profile.skill_points_total(), Profile.MAX_LEVEL - 1, "no points past the cap")
	check(Profile.currency("embers") >= 120, "Renown pays Embers")
	var full := 0
	for id in SkillDB.all_ids():
		full += SkillDB.cost(id) * SkillDB.max_rank(id)
	check(full > Profile.skill_points_total() * 2, "the tree (%d points) costs over twice what the cap gives: builds are choices" % full)


func test_hearthtree_pages() -> void:
	Profile.data = Profile.fresh()
	Profile.data.level = 10
	check(Profile.allocate("b1"), "allocate on page I")
	Profile.switch_page(1)
	eq(Profile.skills(), ["hearth"], "page II starts empty")
	check(Profile.allocate("p1"), "allocate on page II")
	Profile.switch_page(0)
	check(Profile.skills().has("b1") and not Profile.skills().has("p1"), "page I kept its build")
	Profile.switch_page(1)
	check(Profile.skills().has("p1"), "page II kept its build")


func test_feats() -> void:
	Profile.data = Profile.fresh()
	var pts := Profile.skill_points_total()
	check(Feats.check().is_empty(), "nothing earned on a fresh save")
	Profile.data.world["warden_kills"] = 1
	Profile.data.stats["kills"] = 150.0
	var got := Feats.check()
	check(got.has("warden") and got.has("kills_100"), "reached feats are granted (%s)" % [got])
	eq(Profile.skill_points_total(), pts + 1, "Wardenfall grants a skill point past the cap")
	check(Feats.check().is_empty(), "each feat is granted once")
	for id in Feats.FEATS:
		var r: Dictionary = Feats.FEATS[id].reward
		if r.has("look"):
			check(Looks.LOOKS.has(r.look), "%s rewards a real look" % id)


func test_migration_v7_caps_level() -> void:
	var old := Profile.fresh()
	old.version = 6
	old.level = 70
	old.erase("skill_pages")
	old.erase("renown")
	var m := Profile.migrate(old)
	eq(int(m.level), Profile.MAX_LEVEL, "an old save over the cap is capped")
	eq(int(m.renown), 10, "its extra levels become Renown")
	eq((m.skill_pages as Array).size(), Profile.PAGES, "pages exist")
