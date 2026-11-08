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
	eq(w.souls, 3, "they reached the cage")
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
