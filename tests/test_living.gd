## The Living Undervault, played rather than generated: each way's own room is
## entered, fought and won on a real floor; altars, coffers and bowls are used;
## a Grudge wards, lunges, flees and leaves its trophy; an Echo's pattern lands.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _floor(seed_v: int, route := "", region := "ossuary", depth := 2, world := {}) -> Dungeon:
	var lay := DungeonGen.generate(seed_v, depth, region, false, route, world)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(seed_v, region, "sword", 0, ["flare", "", ""])
	run.depth = depth
	run.route = route
	d.build(lay, run, null)
	return d


## The first seed whose floor took this form.
func _seed_of(route: String, variant: String) -> int:
	for s in range(1, 200):
		var lay := DungeonGen.generate(s, 2, "ossuary", false, route)
		if lay.variant == variant:
			for r in lay.rooms:
				if r.objective == variant:
					return s
	return -1


func _room_of(d: Dungeon, objective: String) -> Room:
	for r in d.layout.rooms:
		if r.objective == objective:
			return r
	return null


func _into(d: Dungeon, r: Room) -> void:
	d.player.godmode = true
	d.player.input_enabled = false
	d.player.pos = d.random_floor_near(r.center(), 1.5)
	d.current_room = r
	d._start_encounter(r, d.player)


func _tick(d: Dungeon, seconds: float) -> void:
	var dt := 1.0 / 30.0
	for i in int(seconds / dt):
		d.simulate(dt)


func _fell(d: Dungeon, e: Enemy) -> void:
	var h := Hit.make(d.player, e.hp + e.shield + 99999.0, ["melee"])
	h.can_crit = false
	h.proc = false
	d.player.deal_hit(e, h)


## Win the room: fell whatever stands, wave after wave.
func _win(d: Dungeon, r: Room, skip_seals := false) -> void:
	for i in 900:
		if r.cleared:
			return
		for e in d.room_enemies.duplicate():
			if is_instance_valid(e) and e.alive and not (skip_seals and e.id == "ash_seal"):
				_fell(d, e)
		d.simulate(1.0 / 30.0)


func _props(d: Dungeon, kind: String, ev := "") -> Array:
	return d.props.filter(func(p): return is_instance_valid(p) and p.kind == kind and (ev == "" or String(p.data.get("event", "")) == ev))


func _pickups(d: Dungeon, kind: String) -> Array:
	return d.pickups.filter(func(p): return is_instance_valid(p) and p.kind == kind)


func test_every_ways_own_room_begins_and_can_be_won() -> void:
	for pair in [["trial", "seals"], ["trial", "champion"], ["trial", "gauntlet"], ["vault", "flame"], ["vault", "workshop"], ["breach", "breach"], ["lair", "lair"]]:
		Profile.data = Profile.fresh()
		var s := _seed_of(String(pair[0]), String(pair[1]))
		check(s > 0, "a seed where %s takes the form %s" % pair)
		if s <= 0:
			continue
		var d := _floor(s, String(pair[0]))
		var r := _room_of(d, String(pair[1]))
		check(r != null, "%s: its room is on the floor" % pair[1])
		_into(d, r)
		check(not d.room_enemies.is_empty(), "%s: something to fight" % pair[1])
		if pair[1] in ["seals", "champion", "gauntlet", "flame", "breach"]:
			check(String(d.objective.get("text", "")) != "", "%s: the HUD says what to do" % pair[1])
		if pair[1] in ["champion", "breach", "lair"]:
			var named := d.room_enemies.filter(func(e): return e.has_meta("champion"))
			check(not named.is_empty(), "%s: a champion stands in the room" % pair[1])
		var before := d.props.size()
		_win(d, r)
		check(r.cleared, "%s: the room can be won" % pair[1])
		check(d.objective.is_empty(), "%s: the HUD's task is gone" % pair[1])
		check(d.props.size() > before or not _pickups(d, "ember").is_empty(), "%s: it pays" % pair[1])
		d.queue_free()


func test_a_room_is_not_won_while_a_seal_stands() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(_seed_of("trial", "seals"), "trial")
	var r := _room_of(d, "seals")
	_into(d, r)
	eq(d.seals_up(), 3, "three seals")
	var foe: Enemy = null
	for e in d.room_enemies:
		if e.id != "ash_seal":
			foe = e
			break
	check(foe != null, "a warded foe")
	check(d.sealed_foe(foe), "the seals hold it")
	# a warded foe takes half
	var hp0 := foe.hp
	foe.shield = 0.0
	var h := Hit.make(d.player, 20.0, ["melee"])
	h.can_crit = false
	h.proc = false
	d.player.deal_hit(foe, h)
	var warded := hp0 - foe.hp
	check(warded > 0.0 and warded < 20.0, "a warded foe shrugs off part of a blow (took %.1f of 20)" % warded)
	# every foe down, the seals still up: the fight goes on
	for i in 60:
		for e in d.room_enemies.duplicate():
			if is_instance_valid(e) and e.alive and e.id != "ash_seal":
				_fell(d, e)
		d.simulate(1.0 / 30.0)
	eq(d.seals_up(), 3, "the seals remain")
	check(not r.cleared, "the room holds while a seal stands")
	_win(d, r)
	check(r.cleared, "broken, the hall is won")
	eq(d.seals_up(), 0, "no seal left")
	d.queue_free()


func test_a_broken_seal_frees_its_hall() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(_seed_of("trial", "seals"), "trial")
	var r := _room_of(d, "seals")
	_into(d, r)
	var foe: Enemy = null
	for e in d.room_enemies:
		if e.id != "ash_seal":
			foe = e
			break
	for s in d._seals.duplicate():
		_fell(d, s)
	d.simulate(1.0 / 30.0)
	eq(d.seals_up(), 0, "the seals are down")
	check(not d.sealed_foe(foe), "and its foes stand bare")
	var hp0 := foe.hp
	var h := Hit.make(d.player, 20.0, ["melee"])
	h.can_crit = false
	h.proc = false
	d.player.deal_hit(foe, h)
	check(hp0 - foe.hp > 9.5, "a blow lands in full")
	d.queue_free()


func test_the_vigil_is_fed_by_the_near_and_choked_by_foes() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(_seed_of("vault", "flame"), "vault")
	var r := _room_of(d, "flame")
	_into(d, r)
	check(d._vigil != null, "a lantern stands in the vault")
	d.player.pos = d._vigil.pos + Vector2(0.9, 0.9)
	var f0: float = d._flame
	for e in d.room_enemies:
		e.pos = d._vigil.pos + Vector2(6.0, 6.0)
		e.speed = 0.0
	d._tend_objective(1.0)
	check(d._flame > f0, "standing in its light feeds it")
	var f1: float = d._flame
	d.player.pos = d._vigil.pos + Vector2(6.0, 0.0)
	d._tend_objective(1.0)
	check(d._flame < f1, "left alone, it falls")
	var f2: float = d._flame
	d.player.pos = d._vigil.pos + Vector2(6.0, 0.0)
	var foe: Enemy = d.room_enemies[0]
	foe.pos = d._vigil.pos + Vector2(0.5, 0.0)
	d._tend_objective(1.0)
	check(f2 - d._flame > 0.05 + 0.005 * d.layout.depth + 0.001, "a foe at the lantern chokes it faster")
	d._flame = 0.01
	foe.pos = d._vigil.pos + Vector2(0.5, 0.0)
	d._tend_objective(1.0)
	check(d._flame_out, "it can go out")
	d.queue_free()


func test_each_wave_of_a_gauntlet_burns_more_of_the_floor() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(_seed_of("trial", "gauntlet"), "trial")
	var r := _room_of(d, "gauntlet")
	_into(d, r)
	eq(d.hazards.size(), 0, "the first wave comes clean")
	for e in d.room_enemies.duplicate():
		_fell(d, e)
	_tick(d, 2.5)
	check(d.wave >= 1, "a next wave came")
	check(d.hazards.size() >= 3, "ash burns where it fell (%d)" % d.hazards.size())
	d.queue_free()


func test_a_treasury_gives_one_and_seals_the_rest() -> void:
	Profile.data = Profile.fresh()
	var s := -1
	for k in range(1, 200):
		if DungeonGen.generate(k, 2, "ossuary", false, "vault").variant == "treasury":
			s = k
			break
	var d := _floor(s, "vault")
	var coffers := _props(d, "site", "coffer")
	eq(coffers.size(), 3, "three coffers")
	DeepEvents.resolve(d, coffers[0], d.player)
	for c in coffers:
		check(c.used, "every coffer is spent")
	eq(String(coffers[1].sprite.anim), "shut", "the others seal")
	check(not bool(coffers[0].sprite.anim == "shut"), "the chosen one does not")
	var before := d.pickups.size()
	DeepEvents.resolve(d, coffers[1], d.player)
	eq(d.pickups.size(), before, "a sealed coffer gives nothing")
	d.queue_free()


func test_each_coffer_pays_what_it_says() -> void:
	for pair in [[0, "gear"], [1, "material"], [2, ""]]:
		Profile.data = Profile.fresh()
		var s := -1
		for k in range(1, 200):
			if DungeonGen.generate(k, 2, "ossuary", false, "vault").variant == "treasury":
				s = k
				break
		var d := _floor(s, "vault")
		var coffer: Prop = _props(d, "site", "coffer")[int(pair[0])]
		var altars := _props(d, "relic_altar").size()
		DeepEvents.resolve(d, coffer, d.player)
		if pair[1] != "":
			check(not _pickups(d, String(pair[1])).is_empty(), "coffer %d gives %s" % pair)
		else:
			eq(_props(d, "relic_altar").size(), altars + 1, "the reliquary raises a relic")
		d.queue_free()


func test_an_answered_altar_marks_the_chronicle_and_spends_its_offerings() -> void:
	Profile.data = Profile.fresh()
	var seed_v := -1
	for s in range(1, 200):
		for depth in [1, 2]:
			var lay := DungeonGen.generate(s, depth, "ossuary", false)
			for r in lay.rooms:
				if r.event == "altar":
					seed_v = s * 10 + depth
		if seed_v > 0:
			break
	check(seed_v > 0, "an altar on a floor")
	var d := _floor(seed_v / 10, "", "ossuary", seed_v % 10)
	var offers := _props(d, "site", "altar")
	eq(offers.size(), 3, "three answers")
	var broken: Prop = null
	for o in offers:
		if String(o.data.choice) == "broken":
			broken = o
	DeepEvents.resolve(d, broken, d.player)
	eq(Chronicle.site("ossuary"), "broken", "the Chronicle remembers")
	for o in offers:
		check(o.used, "the other answers are gone")
	check(DungeonGen.route_offer(7, 1, Chronicle.snapshot(), "ossuary").has("breach"), "a Breach opens on later expeditions")
	# nothing is ruined for good
	Chronicle.set_site("ossuary", "")
	eq(Chronicle.site("ossuary"), "", "it can be let rest")
	check(not DungeonGen.route_offer(7, 1, Chronicle.snapshot(), "ossuary").has("breach"), "and the Breach closes")
	d.queue_free()


func test_the_pale_bowl_takes_each_kindled_once_a_floor() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(5, "", "ossuary", 1, {"sites": {"ossuary": "pact"}})
	var bowls := _props(d, "site", "bowl")
	eq(bowls.size(), 1, "a Pale Bowl at the head of the floor")
	var hp0 := d.player.hp
	var ground := d.pickups.size()
	DeepEvents.resolve(d, bowls[0], d.player)
	check(d.player.hp < hp0, "it takes blood")
	eq(d.run.pale, 1, "and the expedition remembers")
	eq(d.pickups.size(), ground + 1, "a reagent for it")
	var hp1 := d.player.hp
	DeepEvents.resolve(d, bowls[0], d.player)
	eq(d.player.hp, hp1, "once a floor")
	eq(d.run.pale, 1, "no second mark")
	d.queue_free()


func test_a_cold_brazier_lit_leaves_a_gift() -> void:
	Profile.data = Profile.fresh()
	var seed_v := -1
	for s in range(1, 400):
		var lay := DungeonGen.generate(s, 2, "ossuary", false)
		for r in lay.rooms:
			if r.event == "last_stand":
				seed_v = s
	check(seed_v > 0, "a Last Stand on some floor")
	var d := _floor(seed_v)
	var braziers := _props(d, "site", "dead_brazier")
	eq(braziers.size(), 1, "one cold brazier")
	var chests := _props(d, "chest").size()
	DeepEvents.resolve(d, braziers[0], d.player)
	check(braziers[0].used, "lit once")
	eq(_props(d, "chest").size(), chests + 1, "what they left")
	eq(Chronicle.marks("last_stand"), 1, "the Chronicle counts it")
	d.queue_free()


func _grudge_foe(d: Dungeon, g: Dictionary, at: Vector2) -> Enemy:
	var e := d._make_enemy("husk")
	e.make_grudge(g)
	e.set_meta("grudge_id", String(g.id))
	e.set_meta("grudge_embers", int(g.embers))
	e.set_meta("grudge_level", int(g.level))
	e.pos = at
	d.add_actor(e)
	d.room_enemies.append(e)
	return e


func test_a_grown_grudge_flees_once_scarred_and_leaves_part_of_its_hoard() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var e := _grudge_foe(d, {"id": "g1", "name": "Vethis the Patient", "level": 2, "embers": 90, "affix": "hasted", "learned": "ward"}, d.player.pos + Vector2(3.0, 0.0))
	e.spawn_t = 0.0
	_tick(d, 0.2)
	e.hp = e.max_hp * 0.2
	var before := _pickups(d, "ember").size()
	_tick(d, 0.3)
	check(not e.alive or not is_instance_valid(e), "it is gone from the floor")
	check(d.run.wounded.has("g1"), "and waits further down, wounded")
	check(d.run.scars.has("g1"), "scarred")
	check(_pickups(d, "ember").size() > before, "it drops part of its hoard")
	# (a second meeting: it will not run twice)
	var e2 := _grudge_foe(d, {"id": "g1", "name": "Vethis the Patient", "level": 2, "embers": 60, "affix": "hasted", "learned": "ward"}, d.player.pos + Vector2(3.0, 0.0))
	check(not d.grudge_flees(e2), "it does not run twice")
	d.queue_free()


func test_a_grudge_does_not_run_from_the_last_floor() -> void:
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(3, 3, "ossuary", true)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(3, "ossuary", "sword", 0, ["flare", "", ""]), null)
	var e := _grudge_foe(d, {"id": "g2", "name": "Oth the Ruined", "level": 4, "embers": 40, "affix": "hasted", "learned": "ward"}, d.player.pos + Vector2(3.0, 0.0))
	check(not d.grudge_flees(e), "nowhere to go: it fights to the end")
	d.queue_free()


func test_a_ward_grudge_turns_your_blows_for_a_moment() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var e := _grudge_foe(d, {"id": "g3", "name": "Sarn", "level": 1, "embers": 10, "affix": "hasted", "learned": "ward"}, d.player.pos + Vector2(3.0, 0.0))
	e.spawn_t = 0.0
	e.speed = 0.0
	e.state = "idle"
	e._grudge_cd = 0.0
	e._grudge_tick(0.01)
	check(e.grudge_ward_t > 0.0, "its ward rises")
	var bare := 1000.0
	e.max_hp = 5000.0
	e.hp = 5000.0
	e.shield = 0.0
	var h := Hit.make(d.player, bare, ["melee"])
	h.can_crit = false
	h.proc = false
	var hp0 := e.hp
	d.player.deal_hit(e, h)
	check(hp0 - e.hp < bare * 0.5, "a blow lands at less than half (%.0f)" % (hp0 - e.hp))
	d.queue_free()


func test_a_closing_grudge_lands_beside_you_after_a_warning() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var from := d.player.pos
	var e := _grudge_foe(d, {"id": "g4", "name": "Kell", "level": 1, "embers": 10, "affix": "hasted", "learned": "closer"}, from + Vector2(6.0, 0.0))
	e.spawn_t = 0.0
	e.state = "idle"
	e._grudge_cd = 0.0
	e.speed = 0.0
	var at := e.pos
	e._grudge_tick(0.01)
	eq(e.pos, at, "it does not jump at once: the mark comes first")
	_tick(d, 1.0)
	check(e.pos.distance_to(d.player.pos) < 3.0, "it lands by you (%.1f)" % e.pos.distance_to(d.player.pos))
	d.queue_free()


func test_a_settled_grown_grudge_leaves_a_trophy_with_its_name() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var e := _grudge_foe(d, {"id": "g5", "name": "Morrow the Hollow", "level": 3, "embers": 10, "affix": "hasted", "learned": "ward"}, d.player.pos + Vector2(3.0, 0.0))
	d._grudge_trophy(e)
	var gear := _pickups(d, "gear")
	eq(gear.size(), 1, "a fang on the floor")
	check(String(gear[0].data.item.get("title", "")).contains("Morrow"), "named after the rival")
	check(ItemDB.item_name(gear[0].data.item).contains("Morrow"), "and the name shows")
	eq(Chronicle.marks("grudges_settled"), 1, "the Chronicle counts it")
	d.queue_free()


func test_a_frozen_foe_shatters_under_another_kindleds_blow() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var p2 := Player.new()
	p2.peer_id = 2
	p2.pos = d.player.pos + Vector2(1.0, 0.0)
	d.add_actor(p2)
	p2.setup_from(RunState.create(9, "ossuary", "sword", 0, ["flare", "", ""]))
	var e := d._make_enemy("husk")
	e.pos = d.player.pos + Vector2(2.0, 0.0)
	d.add_actor(e)
	e.max_hp = 9000.0
	e.hp = 9000.0
	e.spawn_t = 0.0
	# Kindled 2 freezes it; the same Kindled's blow is a plain one
	var mk := func(by: Player) -> Hit:
		var h := Hit.make(by, 100.0, ["melee"])
		h.can_crit = false
		h.proc = false
		return h
	e.status.frozen_t = 3.0
	e.set_meta("frozen_by", 2)
	var hp0 := e.hp
	p2.deal_hit(e, mk.call(p2))
	var own := hp0 - e.hp
	e.status.frozen_t = 3.0
	e.set_meta("frozen_by", 2)
	hp0 = e.hp
	d.player.deal_hit(e, mk.call(d.player))
	var other := hp0 - e.hp
	check(other > own * 1.3, "another's blow shatters (%.0f against %.0f)" % [other, own])
	check(not e.has_meta("frozen_by"), "once")
	d.queue_free()


func test_the_new_uniques_change_what_you_do() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var pl := d.player
	pl.input_enabled = false
	# Ashwalker's Cinder: a dodge leaves burning ground
	pl.stats.flags["ash_cinder"] = 1
	var hz := d.hazards.size()
	pl._ash_trail()
	_tick(d, 0.4)
	check(d.hazards.size() > hz, "a dodge leaves burning ground")
	pl.stats.flags.erase("ash_cinder")
	# Stillwater Stone: stand still in a fight and a barrier rises
	pl.stats.flags["stillwater"] = 1
	var r: Room = null
	for rm in d.layout.rooms:
		if rm.is_combat() and rm.type != Room.Type.BOSS:
			r = rm
			break
	_into(d, r)
	pl.godmode = true
	pl.barrier = 0.0
	pl.move_in = Vector2.ZERO
	for e in d.room_enemies:
		e.speed = 0.0
		e.pos = pl.pos + Vector2(9.0, 9.0)
	_tick(d, 1.3)
	check(pl.barrier > 0.0, "stillness raises a barrier (%.1f)" % pl.barrier)
	check(pl.stillwater_t > 0.0, "then it must wait")
	pl.stats.flags.erase("stillwater")
	# Mirror of the Deep: a Ward throws back the last spell
	pl.stats.flags["deep_mirror"] = 1
	pl.last_spell = "flare"
	pl.mirror_t = 0.0
	pl._on_ward(null, false)
	check(pl.mirror_t > 0.0, "a Ward answers")
	d.queue_free()


func test_the_deep_hybrids_turn_defence_into_attack() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	var pl := d.player
	var e := d._make_enemy("husk")
	e.pos = pl.pos + Vector2(1.0, 0.0)
	d.add_actor(e)
	e.max_hp = 9000.0
	e.hp = 9000.0
	var mk := func() -> Hit:
		var h := Hit.make(pl, 100.0, ["melee"])
		h.can_crit = false
		h.proc = false
		return h
	var hp0 := e.hp
	pl.deal_hit(e, mk.call())
	var plain := hp0 - e.hp
	# Furnace Heart: Kindle spent, struck
	pl.stats.flags["furnace_heart"] = 1
	pl.furnace = 50.0
	hp0 = e.hp
	pl.deal_hit(e, mk.call())
	check(hp0 - e.hp > plain * 1.4, "what was spent is struck (%.0f against %.0f)" % [hp0 - e.hp, plain])
	eq(pl.furnace, 0.0, "and it is gone")
	pl.stats.flags.erase("furnace_heart")
	# Perfect Answer: after a Ward, a sure critical
	pl.stats.flags["perfect_answer"] = 1
	pl._on_ward(null, false)
	check(pl.answer_ready, "the Ward readies the answer")
	var h: Hit = mk.call()
	pl.deal_hit(e, h)
	check(h.forced_crit, "the next blow is sure")
	check(not pl.answer_ready, "once")
	pl.stats.flags.erase("perfect_answer")
	# Shadowfrost: chilled foes take more
	pl.stats.flags["shadowfrost"] = 1
	e.status.chill = 0.4
	hp0 = e.hp
	pl.deal_hit(e, mk.call())
	check(hp0 - e.hp > plain * 1.2, "a shade strikes with you")
	d.queue_free()


func test_an_echo_keeps_its_pattern_coming_in_a_real_boss_fight() -> void:
	Profile.data = Profile.fresh()
	var depth := 0
	for k in range(1, 40):
		if Delve.is_boss_depth(k):
			depth = k
			break
	check(depth > 0, "an Echo depth")
	var region := Delve.region_for(depth)
	var lay := DungeonGen.generate(13, depth, region, true)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(13, region, "sword", 0, ["flare", "", ""])
	run.delve = true
	run.depth = depth
	d.build(lay, run, null)
	var r: Room = null
	for rm in d.layout.rooms:
		if rm.type == Room.Type.BOSS:
			r = rm
	check(r != null, "a guardian's room")
	_into(d, r)
	_tick(d, Dungeon.ENTRANCE + 0.5)
	check(d.boss != null and d._echo_t >= 0.0, "an Echo with a pattern")
	if d.boss == null:
		d.queue_free()
		return
	d.boss.speed = 0.0
	var tele := d._timers.size()
	_tick(d, 7.5)
	check(d._timers.size() > tele or d._echo_t < 7.0, "the pattern came (timers %d, next in %.1f)" % [d._timers.size(), d._echo_t])
	d.queue_free()


func test_a_ping_marks_the_map_and_fades() -> void:
	Profile.data = Profile.fresh()
	var d := _floor(9)
	Party.show_ping(d, 1, d.player.pos)
	eq(d.pings.size(), 1, "on the map")
	_tick(d, 4.5)
	eq(d.pings.size(), 0, "and gone")
	d.queue_free()
