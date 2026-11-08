## The next evolution: rooms built as something, guardians that change what you do, foes
## that are about where you look and where you stand.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _stage(w := 34, h := 26) -> Stage:
	var g := TileGrid.new(w, h)
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			g.put(x, y, TileGrid.FLOOR)
	g.finalize_walls()
	var st := Stage.new()
	st.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(st)
	st.setup(g, null)
	return st


func _player(st: Stage, at := Vector2(8, 13)) -> Player:
	Profile.data = Profile.fresh()
	var pl := Player.new()
	pl.pos = at
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", ""]))
	pl.set_weapon("sword", 0)
	pl.aim = Vector2.RIGHT
	return pl


func _foe(st: Stage, id: String, at: Vector2) -> Enemy:
	var scr: GDScript = load(EnemyDB.get_def(id).script)
	var e: Enemy = scr.new()
	e.configure(id)
	e.pos = at
	st.add_actor(e)
	e.spawn_t = 0.0
	return e


func _run(st: Stage, seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in int(seconds / dt):
		st.simulate(dt)
		st.fx.step(dt)


func _strike(e: Enemy, amount: float, from: Node = null) -> void:
	var h := Hit.make(from, amount, ["melee"])
	h.can_crit = false
	e.take_hit(h)


# --- rooms -----------------------------------------------------------------------------

func _whole(lay: DungeonGen.Layout) -> void:
	for r: Room in lay.rooms:
		check(DungeonGen._floor_whole(lay, r, [] as Array[Vector2i]), "room %d of seed %d is one piece" % [r.id, lay.seed])
		for d in r.doors:
			if d.secret:
				continue
			for dt: Vector2i in d.tiles:
				var inner: Vector2i = dt - Vector2i(d.dir)
				check(not DungeonGen._solid_of(r).has(inner), "room %d's door is clear" % r.id)


func test_every_concept_leaves_every_room_whole_and_every_door_clear() -> void:
	Profile.data = Profile.fresh()
	for c: String in RoomCraft.OSSUARY + RoomCraft.THRONE:
		RoomCraft.force_concept = c
		var region := "ossuary" if c in RoomCraft.OSSUARY else "throne"
		for s in [3, 11]:
			_whole(DungeonGen.generate(s, 2, region, false))
	RoomCraft.force_concept = ""


func test_a_floor_is_built_the_same_on_every_machine() -> void:
	Profile.data = Profile.fresh()
	var a := DungeonGen.generate(23, 2, "throne", false)
	var b := DungeonGen.generate(23, 2, "throne", false)
	eq(a.rooms.size(), b.rooms.size(), "same rooms")
	for i in a.rooms.size():
		eq(a.rooms[i].concept, b.rooms[i].concept, "room %d's concept" % i)
		eq(a.rooms[i].props.size(), b.rooms[i].props.size(), "room %d's props" % i)


func test_regions_build_with_their_own_stone() -> void:
	Profile.data = Profile.fresh()
	var seen := {"ossuary": {}, "throne": {}}
	for region: String in seen:
		for s in range(1, 25):
			var lay := DungeonGen.generate(s, 2, region, false)
			for r: Room in lay.rooms:
				if r.concept != "":
					seen[region][r.concept] = true
	for c in RoomCraft.OSSUARY:
		check(seen.ossuary.has(c), "the Ossuary builds " + c)
	for c in RoomCraft.THRONE:
		check(seen.throne.has(c), "the Throne builds " + c)


func test_monuments_stand_on_as_much_as_they_block() -> void:
	for spec: Array in [["tomb_effigy", 2], ["charnel_bank", 2], ["broken_obelisk", 1], ["bone_cairn", 2], ["colossus_head", 3], ["colossus_foot", 2],
			["broken_throne", 3], ["chain_winch", 2], ["fallen_vault", 2], ["hollow_listener", 1], ["hollow_glass", 1], ["hollow_ribs", 2],
			["hollow_milestone", 1], ["hollow_stair", 2], ["hollow_jaw", 2], ["hollow_pale_cap", 1], ["hollow_riftstone", 1]]:
		var a := Physical.art_of(String(spec[0]))
		var span := int(spec[1])
		check(int(a.foot) >= Physical.FOOT_MIN * span - 2 * (span - 1), "%s stands on its tiles (%d)" % [spec[0], a.foot])
		check(int(a.foot) <= 16 * span + 12, "%s's foot is about what it blocks (%d)" % [spec[0], a.foot])


func test_what_is_let_into_the_floor_is_walked_over() -> void:
	eq(Physical.OF["inlay"], Physical.Cls.GROUND, "inlays are ground")
	eq(Physical.OF["jamb"], Physical.Cls.FIXTURE, "door posts are on the wall")
	check(Physical.WALK_THROUGH.has("inlay"), "an inlay stops nobody")
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(11, 2, "ossuary", false)
	var doors := 0
	for r: Room in lay.rooms:
		for p in r.props:
			if String(p.kind) == "inlay" and String(p.sheet).begins_with("inlay_sill"):
				doors += 1
	check(doors > 0, "ways have thresholds")


func test_every_mood_of_the_hollow_has_its_own_ground_and_stone() -> void:
	Profile.data = Profile.fresh()
	for i in Delve.BANDS.size():
		var band: Dictionary = Delve.BANDS[i]
		var depth := 4 + i * 3
		eq(String(Delve.band(depth).id), String(band.id), "depth %d is this mood" % depth)
		check(band.has("ambient"), String(band.id) + " has its own light")
		var built := {}
		var grown := 0
		for s in range(1, 12):
			var lay := DungeonGen.generate(s, depth, Delve.region_for(depth), false)
			for r: Room in lay.rooms:
				grown += r.flora.size()
				for p in r.props:
					if String(p.kind) == "dressing":
						built[String(p.sheet)] = true
		check(grown > 0, String(band.id) + " has something growing")
		var own: Array = RoomCraft.HOLLOW[String(band.id)].stand
		var found := false
		for sp: Array in own:
			if built.has(String(sp[0])):
				found = true
		check(found, String(band.id) + " stands its own monuments")


func test_a_big_prop_blocks_every_tile_it_stands_on() -> void:
	Profile.data = Profile.fresh()
	eq(DungeonGen.span_of({"span": 3}), 3, "span")
	eq(DungeonGen.span_of({"wide": true}), 2, "wide")
	eq(DungeonGen.span_of({}), 1, "single")
	var r := Room.new()
	r.props.append({"kind": "dressing", "tile": Vector2i(4, 4), "sheet": "broken_throne", "span": 3})
	var solid := DungeonGen._solid_of(r)
	for k in 3:
		check(solid.has(Vector2i(4 + k, 4)), "tile %d of the throne" % k)


# --- the Gloam Warden ----------------------------------------------------------------------

func _warden(st: Stage) -> Enemy:
	var w := _foe(st, "warden", Vector2(17, 13))
	w.arena_center = Vector2(17, 13)
	w.intro = false
	w.set_state("stalk")
	return w


func _motes(st: Stage) -> Array:
	return st.actors.filter(func(a): return a is Enemy and (a as Enemy).id == "soul_mote" and a.alive)


func test_the_harvest_sends_three_souls_and_they_feed_the_reaping() -> void:
	var st := _stage()
	_player(st)
	var w := _warden(st)
	w._begin_harvest()
	eq(_motes(st).size(), 3, "three souls rise")
	for m in _motes(st):
		m.pos = w.pos + Vector2(1.2, 0)
	_run(st, 9.0)
	eq(w.harvest_fed, 3, "they reached the cage")
	eq(_motes(st).size(), 0, "and are gone")
	st.queue_free()


func test_strike_down_every_soul_and_the_cage_rings_empty() -> void:
	var st := _stage()
	var pl := _player(st)
	var w := _warden(st)
	w._begin_harvest()
	pl.kindle = 0.0
	for m: Enemy in _motes(st):
		_strike(m, 999.0, pl)
	_run(st, 0.1)
	check(w.status.stagger_t > 0.5, "it reels")
	check(w.status.exposed_t > 0.5, "and is open")
	eq(w.souls, 0, "nothing was fed")
	st.queue_free()


func test_one_soul_getting_through_means_no_reward() -> void:
	var st := _stage()
	var pl := _player(st)
	var w := _warden(st)
	w._begin_harvest()
	var ms := _motes(st)
	ms[0].pos = w.pos + Vector2(1.2, 0)
	ms[1].pos = Vector2(4, 4)
	ms[2].pos = Vector2(30, 22)
	_strike(ms[1], 999.0, pl)
	_strike(ms[2], 999.0, pl)
	_run(st, 9.0)
	eq(w.harvest_fed, 1, "one was fed")
	eq(w.harvest_out, 0, "and the harvest is over")
	near(w.status.exposed_t, 0.0, 0.01, "so it never reeled")
	st.queue_free()


func _reap_damage(offset: Vector2) -> float:
	var st := _stage()
	var w := _warden(st)
	var pl := _player(st, w.pos + offset)
	pl.max_hp = 9000.0
	pl.hp = 9000.0
	pl.invuln_t = 0.0
	w.aim_dir = Vector2.RIGHT
	w.souls = 3
	w._begin_reap()
	var before := pl.hp
	for i in 300:
		w.harvest_t = 99.0
		w.cooldown = 99.0
		pl.invuln_t = 0.0
		st.simulate(1.0 / 60.0)
		st.fx.step(1.0 / 60.0)
		if w.state == "recover":
			break
	var lost := before - pl.hp
	st.queue_free()
	return lost


func test_the_reaping_passes_over_anyone_close_and_cuts_anyone_in_its_path() -> void:
	check(_reap_damage(Vector2(1.2, 0)) == 0.0, "the haft passes over you up close")
	var far := _reap_damage(Vector2(0, 5))
	check(far > 0.0, "out in its path it cuts")
	check(_reap_damage(Vector2(12, 0)) == 0.0, "beyond its reach nothing")


# --- the Hollow Bloom ------------------------------------------------------------------------

func _bloom(st: Stage) -> Enemy:
	var b := _foe(st, "bloom", Vector2(17, 13))
	b.arena_center = Vector2(17, 13)
	b.intro = false
	return b


func test_hurt_it_enough_while_it_breathes_and_it_chokes() -> void:
	var st := _stage()
	_player(st)
	var b := _bloom(st)
	b.set_state("inhale")
	b._inhaled = 0.0
	_strike(b, b.max_hp * 0.05)    # (double while inhaling)
	eq(b.state, "wilt", "it gags")
	check(b.status.stagger_t > 0.0, "and staggers")
	st.queue_free()


func test_a_little_damage_does_not_stop_the_breath() -> void:
	var st := _stage()
	_player(st)
	var b := _bloom(st)
	b.set_state("inhale")
	b._inhaled = 0.0
	_strike(b, b.max_hp * 0.01)
	eq(b.state, "inhale", "still breathing")
	st.queue_free()


func test_the_breath_takes_every_kindled() -> void:
	var st := _stage()
	var a := _player(st, Vector2(7, 13))
	var c := Player.new()
	c.pos = Vector2(27, 13)
	c.input_enabled = false
	st.add_actor(c)
	c.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", ""]))
	c.set_weapon("sword", 0)
	var b := _bloom(st)
	b.set_state("inhale")
	var xa := a.pos.x
	var xc := c.pos.x
	_run(st, 0.5)
	check(a.pos.x > xa + 0.2, "the near one is dragged")
	check(c.pos.x < xc - 0.2, "and so is the far one")
	st.queue_free()


func test_a_thorn_ridge_never_grows_on_anyone() -> void:
	var st := _stage()
	var pl := _player(st, Vector2(12.5, 13.5))
	var b := _bloom(st)
	b._ridge(b.pos, Vector2.LEFT, 2.0, 8.0)
	var thorns := st.props.filter(func(p): return p.kind == "bramble")
	check(thorns.size() >= 3, "a ridge rose (%d)" % thorns.size())
	eq(st.grid.at(floori(pl.pos.x), floori(pl.pos.y)), TileGrid.FLOOR, "not under the Kindled")
	st.queue_free()


func test_a_ridge_dies_back_on_its_own() -> void:
	var st := _stage()
	_player(st)
	var b := _bloom(st)
	b._ridge(b.pos, Vector2.LEFT, 2.0, 6.0)
	_run(st, b.RIDGE_LIFE + 2.0)
	eq(st.props.filter(func(p): return p.kind == "bramble").size(), 0, "it dies back and the floor is clear")
	st.queue_free()


# --- the Ashen King -----------------------------------------------------------------------------

func _king(st: Stage) -> Enemy:
	var k := _foe(st, "ashen_king", Vector2(17, 13))
	k.arena_center = Vector2(17, 13)
	k.intro = false
	k.set_state("stalk")
	return k


func test_the_court_falls_in_lanes_and_leaves_floor_between_them() -> void:
	var st := _stage()
	var pl := _player(st)
	pl.max_hp = 9000.0
	pl.hp = 9000.0
	var k := _king(st)
	k._begin_lanes()
	eq(k._lanes.size(), 3, "three lanes")
	var a: Vector2 = k._lanes[0][0]
	var b: Vector2 = k._lanes[1][0]
	var gap := absf((a - b).dot(Vector2(k._lanes[0][1]).orthogonal()))
	check(gap - k.LANE_WIDE >= 3.0, "a way between them (%.1f)" % gap)
	var before := st.hazards.size()
	k._lanes_land()
	check(st.hazards.size() > before, "the slag stays")
	st.queue_free()


func test_a_ward_struck_as_the_dark_lands_holds_it_off_for_the_price_of_the_kindle() -> void:
	var st := _stage()
	var pl := _player(st)
	pl.max_hp = 500.0
	pl.hp = 500.0
	pl.kindle = 80.0
	pl.ward_t = 0.2
	var k := _king(st)
	k.phase = 2
	k._eclipse_land()
	eq(pl.hp, 500.0, "the lantern held")
	near(pl.kindle, 80.0 - k.DEFY_KINDLE, 0.01, "it cost the flame")
	check(k.status.stagger_t > 0.0, "and he reels")
	st.queue_free()


func test_a_ward_without_the_kindle_does_not_hold_off_the_dark() -> void:
	var st := _stage()
	var pl := _player(st)
	pl.max_hp = 500.0
	pl.hp = 500.0
	pl.kindle = 5.0
	pl.ward_t = 0.2
	pl.invuln_t = 0.0
	var k := _king(st)
	k.phase = 2
	k._eclipse_land()
	check(pl.hp < 500.0, "the dark takes them")
	st.queue_free()


# --- foes ------------------------------------------------------------------------------------------

func test_the_penitent_is_stone_while_a_lantern_is_on_it() -> void:
	var st := _stage()
	var pl := _player(st, Vector2(8, 13))
	var p := _foe(st, "penitent", Vector2(14, 13))
	pl.look = Vector2.RIGHT
	check(p.watched(), "seen")
	var x := p.pos.x
	for i in 60:
		pl.look = Vector2.RIGHT
		st.simulate(1.0 / 60.0)
	near(p.pos.x, x, 0.02, "it does not move while watched")
	st.queue_free()


func test_turn_away_and_it_comes() -> void:
	var st := _stage()
	var pl := _player(st, Vector2(8, 13))
	pl.max_hp = 9000.0
	pl.hp = 9000.0
	var p := _foe(st, "penitent", Vector2(16, 13))
	var d0 := p.pos.distance_to(pl.pos)
	for i in 40:
		pl.look = Vector2.LEFT
		st.simulate(1.0 / 60.0)
	check(not p.watched(), "nobody is looking")
	check(p.pos.distance_to(pl.pos) < d0 - 2.0, "it came a long way")
	st.queue_free()


func test_one_kindled_looking_is_enough() -> void:
	var st := _stage()
	var a := _player(st, Vector2(8, 13))
	var c := Player.new()
	c.pos = Vector2(10, 9)
	c.input_enabled = false
	st.add_actor(c)
	c.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", ""]))
	c.set_weapon("sword", 0)
	var p := _foe(st, "penitent", Vector2(14, 13))
	a.look = Vector2.LEFT
	c.look = (p.pos - c.pos).normalized()
	check(p.watched(), "a friend has your back")
	st.queue_free()


func _hit_under_canopy(attacker_at: Vector2, tags := ["melee"]) -> float:
	var st := _stage()
	var pl := _player(st, attacker_at)
	var m := _foe(st, "canopy_mother", Vector2(17, 13))
	var e := _foe(st, "husk", Vector2(18, 13))
	e.max_hp = 1000.0
	e.hp = 1000.0
	var h := Hit.make(pl, 100.0, tags)
	h.can_crit = false
	e.take_hit(h)
	var lost := 1000.0 - e.hp
	m.alive = false
	st.queue_free()
	return lost


func test_under_the_canopy_a_foe_can_only_be_hurt_from_under_the_canopy() -> void:
	var outside := _hit_under_canopy(Vector2(8, 13))
	var inside := _hit_under_canopy(Vector2(16, 13))
	check(outside < inside * 0.5, "from outside it barely lands (%.0f against %.0f)" % [outside, inside])
	check(inside > 0.0, "from inside it is an ordinary blow")


func test_slag_burns_both_sides_and_spills_when_its_bearer_falls() -> void:
	var st := _stage()
	_player(st, Vector2(4, 4))
	var s := _foe(st, "slagbearer", Vector2(17, 13))
	var h := _foe(st, "husk", Vector2(17, 14))
	h.speed = 0.0
	h.max_hp = 1000.0
	h.hp = 1000.0
	var before := st.hazards.size()
	s.die(null)
	check(st.hazards.size() > before, "it spilled")
	_run(st, 1.2)
	check(h.hp < 1000.0, "and burned its neighbour (%.0f)" % h.hp)
	st.queue_free()


func test_new_foes_are_on_their_regions_rosters_and_never_in_the_way_of_a_cap() -> void:
	check(EnemyDB.REGIONS.ossuary.pool.has("penitent"), "Ossuary")
	check(EnemyDB.REGIONS.rootmire.pool.has("canopy_mother"), "Rootmire")
	check(EnemyDB.REGIONS.throne.pool.has("slagbearer"), "Throne")
	for id in ["penitent", "canopy_mother", "slagbearer"]:
		check(EnemyDB.roll_affix(RandomNumberGenerator.new(), id) != "", id + " can still be an elite")
	for id in ["penitent", "canopy_mother", "slagbearer", "soul_mote"]:
		check(ResourceLoader.exists("res://assets/sprites/%s.png" % id), id + " has art")


# --- things worn that change the fight ----------------------------------------------------------

func _armed(flags: Dictionary) -> Array:
	var st := _stage()
	var pl := _player(st)
	pl.stats.apply_flags(flags)
	var e := _foe(st, "husk", pl.pos + Vector2(1.2, 0))
	e.speed = 0.0
	e.max_hp = 5000.0
	e.hp = 5000.0
	return [st, pl, e]


func _blow(pl: Player, e: Enemy, amount := 100.0) -> float:
	var before := e.hp
	var h := Hit.make(pl, amount, ["melee"])
	h.can_crit = false
	h.from_dir = Vector2.RIGHT
	pl.deal_hit(e, h)
	return before - e.hp


func test_the_dimmed_wick_hits_harder_the_lower_the_flame() -> void:
	var a := _armed({"dark_eyes": 1})
	a[1].kindle = 0.0
	var low := _blow(a[1], a[2])
	a[1].kindle = a[1].kindle_max()
	var full := _blow(a[1], a[2])
	check(low > full * 1.25, "with no Kindle it hits harder (%.0f against %.0f)" % [low, full])
	a[0].queue_free()


func test_momentum_is_spent_on_one_blow() -> void:
	var a := _armed({"momentum": 1})
	var plain := _blow(a[1], a[2])
	a[1].momentum_t = a[1].MOMENTUM_READY
	var charged := _blow(a[1], a[2])
	var after := _blow(a[1], a[2])
	check(charged > plain * 1.4, "the run lands (%.0f against %.0f)" % [charged, plain])
	near(after, plain, 1.0, "and is spent")
	a[0].queue_free()


func test_the_mountain_stores_what_it_stood_through_and_cannot_be_moved() -> void:
	var a := _armed({"mountain": 1})
	var pl: Player = a[1]
	pl.max_hp = 5000.0
	pl.hp = 5000.0
	var plain := _blow(pl, a[2])
	var h := Hit.make(a[2], 10.0, ["melee"])
	h.knockback = Vector2(20, 0)
	pl.invuln_t = 0.0
	pl.take_enemy_hit(h, a[2])
	near(h.knockback.length(), 0.0, 0.01, "nothing moves it")
	near(pl.mountain_store, 0.1, 0.001, "the blow is kept")
	var stored := _blow(pl, a[2])
	check(stored > plain * 1.05, "and given back (%.0f against %.0f)" % [stored, plain])
	near(pl.mountain_store, 0.0, 0.001, "once")
	a[0].queue_free()


func test_counterpoise_halves_what_lands_until_the_counter_is_struck() -> void:
	var a := _armed({"counterpoise": 1})
	var pl: Player = a[1]
	pl.max_hp = 5000.0
	pl.hp = 5000.0
	pl.counter_guard_t = 2.0
	var h := Hit.make(a[2], 100.0, ["melee"])
	var before := pl.hp
	pl.invuln_t = 0.0
	pl.take_enemy_hit(h, a[2])
	var guarded := before - pl.hp
	_blow(pl, a[2])
	near(pl.counter_guard_t, 0.0, 0.001, "striking ends it")
	var h2 := Hit.make(a[2], 100.0, ["melee"])
	before = pl.hp
	pl.invuln_t = 0.0
	pl.take_enemy_hit(h2, a[2])
	var bare := before - pl.hp
	check(guarded < bare * 0.7, "it was halved (%.0f against %.0f)" % [guarded, bare])
	a[0].queue_free()


func test_a_sappers_charm_makes_breaking_things_a_weapon() -> void:
	var st := _stage()
	var pl := _player(st)
	pl.stats.apply_flags({"sapper": 1})
	pl.kindle = 0.0
	var e := _foe(st, "husk", Vector2(12, 13))
	e.speed = 0.0
	e.max_hp = 5000.0
	e.hp = 5000.0
	var urn := Prop.make(st, "urn", Vector2i(11, 13), {"mat": "clay"})
	urn.on_struck(pl)
	check(e.hp < 5000.0, "the foe beside it was hurt")
	check(pl.kindle > 0.0, "and the flame came back")
	st.queue_free()


func test_whetstone_banks_techniques_and_a_spell_spends_them() -> void:
	var a := _armed({"habit": 1})
	var pl: Player = a[1]
	for k in 7:
		pl.on_technique()
	eq(pl.habit, 5, "at most five")
	a[0].queue_free()


func test_a_chest_pieces_make_is_what_it_asks_of_you() -> void:
	eq(String(ItemDB.weight_of("emberwrought_plate").name), "Heavy", "plate is heavy")
	eq(String(ItemDB.weight_of("grave_iron_mail").name), "Measured", "mail is measured")
	eq(String(ItemDB.weight_of("gravecloth_robe").name), "Flowing", "cloth flows")
	eq(String(ItemDB.weight_of("tattered_cloak").name), "Light", "a cloak is light")
	var heavy := Stats.for_player()
	var it := ItemDB.make_item("emberwrought_plate", "common", 1, RandomNumberGenerator.new(), 1)
	ItemDB.apply_equipped({"chest": it}, heavy)
	check(heavy.has("braced"), "plate braces")
	var light := Stats.for_player()
	var it2 := ItemDB.make_item("tattered_cloak", "common", 1, RandomNumberGenerator.new(), 1)
	ItemDB.apply_equipped({"chest": it2}, light)
	check(not light.has("braced"), "a cloak does not")


func test_two_things_made_for_each_other_do_more_together() -> void:
	var rng := RandomNumberGenerator.new()
	var solo := Stats.for_player()
	ItemDB.apply_equipped({"chest": ItemDB.make_item("thornmail", "legendary", 1, rng, 1)}, solo)
	check(not solo.has("burning_briar"), "alone, nothing")
	var both := Stats.for_player()
	ItemDB.apply_equipped({"chest": ItemDB.make_item("thornmail", "legendary", 1, rng, 1), "hands": ItemDB.make_item("firebrand_gauntlets", "legendary", 1, rng, 1)}, both)
	check(both.has("burning_briar"), "together, the pair")
	for p: Dictionary in ItemDB.PAIRS:
		check(ItemDB.BASES.has(p.a) and ItemDB.BASES.has(p.b), "%s is two real items" % p.name)
		check(String(ItemDB.BASES[p.a].slot) != String(ItemDB.BASES[p.b].slot) or String(ItemDB.BASES[p.a].slot) in ["ring", "charm"], "%s can be worn together" % p.name)


func test_every_new_unique_is_craftable_and_says_what_it_does() -> void:
	for id in ["sappers_charm", "dimmed_wick", "counterpoise", "long_way_greaves", "rimefire_band", "whetstone_of_habit"]:
		var b: Dictionary = ItemDB.BASES[id]
		check(b.has("recipe"), id + " has a recipe")
		check(String(b.desc).length() > 30, id + " says what it does")
		check(not (b.flags as Dictionary).is_empty(), id + " changes a rule")


# --- the hybrid nodes, doing what they say ----------------------------------------------------

func _weaponed(flags: Dictionary, arch := "sword") -> Array:
	var st := _stage()
	var pl := _player(st)
	pl.set_weapon(arch, 0)
	pl.stats.apply_flags(flags)
	var e := _foe(st, "husk", pl.pos + Vector2(1.2, 0))
	e.speed = 0.0
	e.max_hp = 5000.0
	e.hp = 5000.0
	return [st, pl, e]


func test_banked_strikes_pay_kindle_for_a_strike_in_time() -> void:
	var a := _weaponed({"banked_strikes": 1})
	var pl: Player = a[1]
	pl.kindle = 0.0
	pl.weapon.cadenced = true
	pl.weapon.cadence_run = 1
	var h := Hit.make(pl, 10.0, ["melee"])
	pl.weapon._technique(a[2], h)
	check(pl.kindle > 0.0, "a strike in time pays")
	a[0].queue_free()


func test_breakers_coal_lights_the_broken() -> void:
	var a := _weaponed({"breakers_coal": 1, "tech_breaker": 1}, "hammer")
	var pl: Player = a[1]
	pl.kindle = 0.0
	var e: Enemy = a[2]
	e.status.stagger_t = 2.0
	var h := Hit.make(pl, 10.0, ["melee"])
	pl.weapon._after_blow(e, h, false)
	check(pl.kindle >= 10.0, "the coal pays Kindle (%.0f)" % pl.kindle)
	eq(h.burn, 1, "and burns")
	a[0].queue_free()


func test_cold_aim_freezes_the_chilled_at_full_focus() -> void:
	var a := _weaponed({})
	var pl: Player = a[1]
	var e: Enemy = a[2]
	e.status.chill = 0.5
	var h := Hit.make(pl, 10.0, ["ranged", "freeze_chilled"])
	h.can_crit = false
	pl.deal_hit(e, h)
	check(e.status.is_frozen() or e.status.chill >= 0.9, "the cold one froze")
	var b := _weaponed({})
	var f: Enemy = b[2]
	var h2 := Hit.make(b[1], 10.0, ["ranged", "freeze_chilled"])
	h2.can_crit = false
	b[1].deal_hit(f, h2)
	check(not f.status.is_frozen(), "a warm one does not")
	a[0].queue_free()
	b[0].queue_free()


# --- places, and what they remember -------------------------------------------------------------

func test_a_secret_room_can_be_more_than_a_chest() -> void:
	Profile.data = Profile.fresh()
	var seen := {}
	for s in range(1, 90):
		var lay := DungeonGen.generate(s, 2, ["ossuary", "rootmire", "throne"][s % 3], false)
		for r: Room in lay.rooms:
			if r.type == Room.Type.SECRET:
				seen[r.vignette] = true
				check(r.vignette != "", "room %d knows what it is" % r.id)
	for k in ["stash", "camp", "reliquary", "cache", "smith"]:
		check(seen.has(k), "a secret can be a " + k)


func test_a_workshop_lets_the_party_take_one_thing() -> void:
	Profile.data = Profile.fresh()
	eq(DeepEvents.voted(_site("bench", "anvil")), true, "a party agrees")
	for c in ["anvil", "kiln", "lathe"]:
		check(DeepEvents.BENCHES.has(c), c)
		var d := DeepEvents.site_data({"event": "bench", "choice": c}, "ossuary", {})
		eq(String(d.sheet), "workbench", "its own art")
		check(SpriteLib.get_sheet("workbench").anims.has(c), "drawn: " + c)


func _site(ev: String, choice := "") -> Prop:
	var p := Prop.new()
	p.kind = "site"
	p.data = {"event": ev, "choice": choice}
	return p


func test_how_an_altar_was_answered_shows_in_the_rooms() -> void:
	Profile.data = Profile.fresh()
	var marked := {}
	for state: String in ["kindled", "broken", "pact"]:
		for s in range(1, 8):
			var lay := DungeonGen.generate(s, 2, "ossuary", false, "", {"sites": {"ossuary": state}})
			for r: Room in lay.rooms:
				if r.marked != "":
					marked[r.marked] = true
	for state in ["kindled", "broken", "pact"]:
		check(marked.has(state), state + " shows")
	var plain := DungeonGen.generate(3, 2, "ossuary", false)
	for r: Room in plain.rooms:
		eq(r.marked, "", "an untouched altar marks nothing")


func test_a_foe_behind_stone_is_outlined_on_a_floor_with_no_trees() -> void:
	var st := _stage()
	_player(st)
	st.grid.put(14, 13, TileGrid.PILLAR)
	var e := _foe(st, "husk", Vector2(14.5, 12.5))
	e.speed = 0.0
	eq(st.occluders.size(), 0, "no trees here")
	st.update_occlusion(0.2)
	near(float(e.sprite.get_instance_shader_parameter("silhouette")), 1.0, 0.01, "behind the pillar it is outlined")
	e.pos = Vector2(10.5, 10.5)
	st.update_occlusion(0.2)
	near(float(e.sprite.get_instance_shader_parameter("silhouette")), 0.0, 0.01, "in the open it is not")
	st.queue_free()


func test_hints_are_said_once_and_stop_for_the_experienced() -> void:
	Profile.data = Profile.fresh()
	check(Hints.give("spikes"), "the first time")
	check(not Hints.give("spikes"), "and not again")
	Profile.data = Profile.fresh()
	Profile.data.stats["runs"] = Hints.EXPERIENCED
	check(not Hints.give("spikes"), "an old hand is not told")
	Profile.data = Profile.fresh()


func test_a_den_changes_the_guardian_it_belongs_to() -> void:
	var r := RunState.create(1, "ossuary", "sword", 0, ["flare", ""])
	r.hunt_den = "snare"
	var back := RunState.from_dict(r.to_dict())
	eq(back.hunt_den, "snare", "what was done at the den travels with the run")
	for c in ["snare", "hoard"]:
		var d := DeepEvents.site_data({"event": "den", "choice": c}, "ossuary", {})
		check(String(d.prompt) != "", c + " says what it does")
	eq(DeepEvents.voted(_site("den", "snare")), true, "a party agrees on it")


func test_notices_about_a_guardian_wait_until_it_has_been_met() -> void:
	Profile.data = Profile.fresh()
	check(not Contracts._huntable(Contracts.def_of("cage")), "not before the Warden has fallen")
	Profile.data.world["warden_kills"] = 1
	check(Contracts._huntable(Contracts.def_of("cage")), "after")
	Profile.data = Profile.fresh()
