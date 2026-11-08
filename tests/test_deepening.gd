## The deepening pass: the map, weapons, the Hearthtree, great things, guardian hunts,
## the Undervault's consequences and what keeps a long game going.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


# --- the map ---------------------------------------------------------------------------

func test_the_map_marker_never_reaches_past_its_diamond() -> void:
	var c := Vector2(50, 50)
	for mine in [true, false]:
		for r in [2.5, 3.0, 4.0]:
			var shapes := Minimap.player_mark(c, r, mine)
			eq(shapes.size(), 3 if mine else 2, "outline, fill%s" % (" and a heart" if mine else ""))
			for poly: PackedVector2Array in shapes:
				for pt in poly:
					check(pt.distance_to(c) <= r + 1.01, "nothing sticks out of the marker (%.1f at r %.1f)" % [pt.distance_to(c), r])


func test_the_map_does_not_draw_where_a_kindled_looks() -> void:
	var src := FileAccess.get_file_as_string("res://src/ui/minimap.gd")
	check(not src.contains(".look"), "the map never reads a Kindled's facing")
	check(not src.contains("draw_line(at"), "and draws no line out of a marker")


# --- weapon techniques -------------------------------------------------------------------

func _arena() -> Stage:
	var g := TileGrid.new(30, 18)
	for y in range(2, 16):
		for x in range(2, 28):
			g.put(x, y, TileGrid.FLOOR)
	g.finalize_walls()
	var st := Stage.new()
	st.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(st)
	st.setup(g, null)
	return st


func _wielder(st: Stage, base: String, flags: Array = []) -> Player:
	Profile.data = Profile.fresh()
	var it := Profile.add_item(ItemDB.make_item(base, "rare", 1, RandomNumberGenerator.new(), 1))
	Profile.equip(int(it.uid))
	var pl := Player.new()
	pl.pos = Vector2(10.5, 9.5)
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", Profile.equipped_weapon(), 0, ["", "", ""]))
	pl.stats.base["crit_chance"] = -5.0     # (no luck in these measurements)
	for f in flags:
		pl.stats.apply_flags({f: 1})
	return pl


func _dummy(st: Stage, at: Vector2, id := "husk") -> Enemy:
	var e: Enemy = load(EnemyDB.get_def(id).script).new()
	e.configure(id)
	e.pos = at
	st.add_actor(e)
	e.max_hp = 5000.0
	e.hp = e.max_hp
	e.spawn_t = 0.0
	e.state = "idle"
	return e


func test_every_kind_of_weapon_has_one_technique_and_only_its_own() -> void:
	var st := _arena()
	for base in ["hearthblade", "cinderhammer", "twin_fangs", "sunpiercer", "ashwood_staff", "hearthbow"]:
		var pl := _wielder(st, base)
		var mine := pl.weapon.technique()
		check(mine != "", "%s has a technique" % base)
		for t in Weapon.TECHNIQUES.values():
			eq(pl.weapon.has_technique(t), t == mine, "%s: %s" % [base, t])
		st.remove_child(pl)
		pl.queue_free()
	st.queue_free()


func test_cadence_rewards_a_press_as_the_swing_settles_and_not_before() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthblade")
	var w := pl.weapon
	w.phase = Weapon.Phase.RECOVER
	w.phase_len = 0.3
	w.phase_t = 0.05
	w.press()
	w.update(0.06)
	check(not w.cadenced, "too early: an ordinary strike")
	w.phase = Weapon.Phase.RECOVER
	w.phase_len = 0.3
	w.phase_t = 0.2
	w.press()
	w.update(0.01)
	check(w.cadenced, "as it settles: in time")
	var h := Hit.make(pl, 100.0, ["melee"])
	w._technique(_dummy(st, Vector2(12, 9.5)), h)
	eq(h.amount, 125.0, "and harder")
	w.begin_combo()
	check(not w.cadenced and w.cadence_run == 0, "a fresh combo from rest starts over")
	st.queue_free()


func test_the_point_of_a_spear_is_its_far_end() -> void:
	var st := _arena()
	var pl := _wielder(st, "sunpiercer")
	var near := _dummy(st, Vector2(11.5, 9.5))
	var far := _dummy(st, Vector2(14.3, 9.5))
	pl.weapon.line_hit(pl.pos, pl.pos + Vector2(4.0, 0.0), 0.6, 20.0, ["melee"], 0.0, 0.0)
	var a := 5000.0 - near.hp
	var b := 5000.0 - far.hp
	check(a > 0.0 and b > a * 1.3, "the tip bites harder (%.1f against %.1f)" % [b, a])
	st.queue_free()


func test_a_dagger_finds_the_gap_behind_a_foe() -> void:
	var st := _arena()
	var pl := _wielder(st, "twin_fangs")
	var e := _dummy(st, Vector2(11.5, 9.5))
	e.facing = Vector2.RIGHT     # looking away from the Kindled
	var h := Hit.make(pl, 10.0, ["melee"])
	pl.weapon._technique(e, h)
	check(h.forced_crit, "from behind: always critical")
	e.facing = Vector2.LEFT
	var h2 := Hit.make(pl, 10.0, ["melee"])
	pl.weapon._technique(e, h2)
	check(not h2.forced_crit, "face to face: as ever")
	st.queue_free()


func test_a_hammer_that_breaks_one_foe_shakes_its_neighbours() -> void:
	var st := _arena()
	var pl := _wielder(st, "cinderhammer")
	var a := _dummy(st, Vector2(11.6, 9.5))
	var b := _dummy(st, Vector2(12.8, 10.3))
	var c := _dummy(st, Vector2(20.0, 9.5))
	a.poise = 1.0
	pl.weapon.arc_hit(pl.pos, Vector2.RIGHT, 1.5, 0.6, 30.0, ["melee"], 0.0, 50.0)
	check(a.status.is_staggered(), "the one struck breaks")
	check(b.hp < 5000.0, "the shock reaches beside it")
	eq(c.hp, 5000.0, "and not across the room")
	st.queue_free()


func test_overcharge_costs_kindle_and_hits_harder() -> void:
	var st := _arena()
	var pl := _wielder(st, "ashwood_staff")
	var w := pl.weapon
	var plain := w.damage_scale()
	pl.kindle = 50.0
	w.held = true
	w.phase = Weapon.Phase.CHARGE
	w.charged = true
	w.phase_t = w.charge_time / w.speed() + Weapon.OVERCHARGE_AFTER + 0.05
	w.update(0.01)
	check(w.overcharged_ready, "held past full: Overcharged")
	w._fire_charge()
	eq(pl.kindle, 50.0 - Weapon.OVERCHARGE_COST, "paid in Kindle")
	check(is_equal_approx(w.damage_scale(), plain * Weapon.OVERCHARGE_MULT), "and much harder")
	pl.kindle = 5.0
	w.overcharged_ready = true
	w._over_t = 0.0
	w._fire_charge()
	eq(w._over_t, 0.0, "no Kindle, no overcharge")
	st.queue_free()


func test_focus_builds_on_true_shots_and_breaks_when_hit() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthbow")
	var w := pl.weapon
	var plain := w.damage_scale()
	for k in 5:
		w.add_focus()
	eq(w.focus, Weapon.FOCUS_MAX, "it stops at three")
	check(is_equal_approx(w.damage_scale(), plain * (1.0 + Weapon.FOCUS_STEP * 3)), "each worth more damage")
	var e := _dummy(st, pl.pos + Vector2(1, 0))
	pl.invuln_t = 0.0
	pl.take_enemy_hit(e.make_hit(10.0, e.pos), e)
	eq(w.focus, 0, "a blow that lands takes it all")
	st.queue_free()


func test_the_tree_lends_a_technique_to_another_weapon() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthblade", ["tech_behind"])
	check(pl.weapon.has_technique("behind") and pl.weapon.has_technique("cadence"), "its own and the lent one")
	var e := _dummy(st, Vector2(11.5, 9.5))
	e.facing = Vector2.RIGHT
	var h := Hit.make(pl, 10.0, ["melee"])
	pl.weapon._technique(e, h)
	check(h.forced_crit, "a sword from behind")
	for id in ["t_cadence", "t_breaker", "t_behind", "t_point", "t_overcharge", "t_focus"]:
		var n := SkillDB.node(id)
		check(not n.is_empty() and String(n.desc) != "", "%s is on the tree and says what it does" % id)
		check(not SkillDB.neighbours(id).is_empty(), "%s can be reached" % id)
	st.queue_free()


# --- specialisation keystones ------------------------------------------------------------

func test_perfect_cadence_crits_in_time_and_costs_out_of_time() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthblade", ["perfect_cadence"])
	var e := _dummy(st, Vector2(12, 9.5))
	pl.weapon.cadenced = true
	var h := Hit.make(pl, 100.0, ["melee"])
	pl.weapon._technique(e, h)
	check(h.forced_crit and is_equal_approx(h.amount, 125.0), "in time: critical and harder")
	pl.weapon.cadenced = false
	var h2 := Hit.make(pl, 100.0, ["melee"])
	pl.weapon._technique(e, h2)
	check(not h2.forced_crit and is_equal_approx(h2.amount, 80.0), "out of time: weaker")
	st.queue_free()


func test_the_lanterns_edge_strikes_inside_the_light_and_gives_no_kindle_for_hits() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthblade", ["lantern_edge"])
	pl._update_lantern(0.02)
	var near := _dummy(st, pl.pos + Vector2(1.0, 0.0))
	var far := _dummy(st, pl.pos + Vector2(pl.light_reach() + 3.0, 0.0))
	pl.kindle = pl.kindle_max()
	var k0 := pl.kindle
	var a := Hit.make(pl, 40.0, ["melee"])
	a.can_crit = false
	var r1 := pl.deal_hit(near, a)
	var b := Hit.make(pl, 40.0, ["melee"])
	b.can_crit = false
	var r2 := pl.deal_hit(far, b)
	check(r1.amount > r2.amount * 1.2, "inside the light it bites (%.1f against %.1f)" % [r1.amount, r2.amount])
	pl.kindle = 10.0
	var c := Hit.make(pl, 10.0, ["melee"])
	c.can_crit = false
	pl.deal_hit(near, c)
	eq(pl.kindle, 10.0, "weapon hits give no Kindle")
	check(k0 > 0.0, "(it started full)")
	st.queue_free()


func test_vanguards_weight_punishes_the_staggered_and_carries_the_shock() -> void:
	var st := _arena()
	var pl := _wielder(st, "cinderhammer", ["vanguard"])
	var a := _dummy(st, Vector2(11.6, 9.5))
	var far := _dummy(st, Vector2(15.4, 9.5))
	a.poise = 1.0
	pl.weapon.arc_hit(pl.pos, Vector2.RIGHT, 1.5, 0.6, 30.0, ["melee"], 0.0, 50.0)
	check(far.hp < 5000.0, "the shock carries further")
	var h := Hit.make(pl, 40.0, ["melee"])
	h.can_crit = false
	var hp := a.hp
	pl.deal_hit(a, h)
	check(hp - a.hp > 40.0 * 1.3, "a staggered foe takes more")
	st.queue_free()


func test_unblinking_holds_five_and_loses_one_at_a_time() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthbow", ["unblinking"])
	var w := pl.weapon
	var none := w.damage_scale()
	for k in 8:
		w.add_focus()
	eq(w.focus, 5, "up to five")
	w.on_hurt()
	eq(w.focus, 4, "a blow costs one")
	w.focus = 0
	var bare := w.damage_scale()
	check(is_equal_approx(bare, none), "(the same with none)")
	pl.stats.flags.erase("unblinking")
	check(w.damage_scale() > bare, "without Unblinking nothing is lost for having none")
	st.queue_free()


# --- great things: no runaway combinations -----------------------------------------------

func test_every_evolution_power_at_once_stays_bounded() -> void:
	var st := _arena()
	var pl := _wielder(st, "twin_fangs")
	var flags := {}
	for base in Evolutions.PATHS:
		for p in Evolutions.PATHS[base]:
			for f in p.flags:
				flags[f] = 1
	pl.stats.apply_flags(flags)
	pl.stats.base["crit_chance"] = 5.0     # every blow critical: the worst case for crit-fed powers
	var foes: Array = []
	for k in 6:
		var e := _dummy(st, pl.pos + Vector2.from_angle(TAU * k / 6.0) * 1.2)
		foes.append(e)
	var n := [0]
	var count := func(_t: Node, _a: float, _c: bool) -> void: n[0] += 1
	Events.damage_dealt.connect(count)
	var worst := 0
	for swing in 20:
		n[0] = 0
		var h := Hit.make(pl, 20.0, ["melee"])
		h.from_dir = Vector2.RIGHT
		pl.deal_hit(foes[swing % 6], h)
		for i in 60:
			st.simulate(1.0 / 30.0)
		worst = maxi(worst, n[0])
		for e in foes:
			e.hp = e.max_hp
	Events.damage_dealt.disconnect(count)
	check(worst < 60, "one blow and everything it sets off stays bounded (worst %d hits)" % worst)
	check(st.projectiles.size() < 40, "no flood of projectiles (%d)" % st.projectiles.size())
	st.queue_free()


# --- uniques of the techniques ---------------------------------------------------------------

func test_the_metronome_widens_cadence_and_gives_kindle() -> void:
	var st := _arena()
	var pl := _wielder(st, "twin_fangs", ["tech_cadence", "metronome"])
	var w := pl.weapon
	w.phase = Weapon.Phase.RECOVER
	w.phase_len = 0.3
	w.phase_t = 0.09     # too early for the plain window, inside the Metronome's
	pl.kindle = 0.0
	w.press()
	w.update(0.03)     # (the press chains at a third of the recovery)
	check(w.cadenced, "a wider window")
	check(pl.kindle > 0.0, "and Kindle back")
	st.queue_free()


func test_the_censer_overcharges_free_on_a_full_lantern() -> void:
	var st := _arena()
	var pl := _wielder(st, "ashwood_staff", ["censer"])
	var w := pl.weapon
	pl.kindle = pl.kindle_max()
	w.overcharged_ready = true
	w._fire_charge()
	check(w._over_t > 0.0, "overcharged")
	eq(pl.kindle, pl.kindle_max(), "for nothing, while full")
	st.queue_free()


func test_the_turncloak_ring_leaves_foes_looking_back() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthblade", ["tech_behind", "turncloak"])     # (as the ring gives them)
	var e := _dummy(st, pl.pos + Vector2(1.5, 0.0))
	e.facing = Vector2.LEFT
	pl.move_in = Vector2.RIGHT
	pl._start_dodge()
	eq(e.facing, Vector2.LEFT, "it looks back where you were (the way you came from)")
	check(e._turned_t > 0.0, "for a moment")
	pl.pos = e.pos + Vector2(1.5, 0.0)
	var h := Hit.make(pl, 10.0, ["melee"])
	pl.weapon._technique(e, h)
	check(h.forced_crit, "and you are behind it")
	st.queue_free()


func test_new_uniques_can_be_learned_and_crafted() -> void:
	for id in ["metronome_hilt", "overflowing_censer", "turncloak_ring"]:
		check(ItemDB.blueprints().has(id), "%s comes as a blueprint" % id)
		var r: Dictionary = ItemDB.base(id).get("recipe", {})
		check(not r.is_empty(), "%s has a recipe" % id)
		for m in r:
			check(m == "embers" or ItemDB.MATERIALS.has(m), "%s needs real materials (%s)" % [id, m])


# --- guardian hunts ----------------------------------------------------------------------

func _hunter(region := "ossuary") -> void:
	Profile.data = Profile.fresh()
	Profile.data.world["%s_kills" % EnemyDB.REGIONS[region].boss] = 1
	Profile.data.contracts = {"offer": [], "taken": [], "done": 0}


func test_a_hunt_goes_up_only_once_its_guardian_has_fallen_and_is_always_on_the_board() -> void:
	Profile.data = Profile.fresh()
	for k in 20:
		Profile.data.contracts = {"offer": [], "taken": [], "done": k}
		for id in Contracts.offers():
			check(not Contracts.def_of(String(id)).has("hunt"), "no hunt before the guardian has fallen")
	_hunter()
	var up := Contracts.offers()
	check(up.has("hunt_ossuary"), "once it has: on the board")
	check(not up.has("hunt_throne"), "and only that one")
	check(Contracts.take("hunt_ossuary"), "taken")
	eq(Contracts.hunt_regions(), ["ossuary"], "the next expedition there is a hunt")
	eq(Chronicle.snapshot().hunts, ["ossuary"], "and the world it carries (to every guest) says so")


func test_a_hunted_floor_holds_two_signs_and_a_harbinger_and_others_do_not() -> void:
	var world := {"hunts": ["ossuary"]}
	var hunted := 0
	for s in range(1, 9):
		var lay := DungeonGen.generate(s, 2, "ossuary", false, "", world)
		var plain := DungeonGen.generate(s, 2, "ossuary", false, "", {})
		var signs := 0
		var harb := 0
		for r in lay.rooms:
			signs += r.props.filter(func(p): return p.kind == "site" and p.get("event", "") == "spoor").size()
			harb += 1 if r.harbinger else 0
		check(signs == 2, "two signs (%d)" % signs)
		check(harb <= 1, "one harbinger at most")
		hunted += harb
		eq(plain.rooms.size(), lay.rooms.size(), "the floor is otherwise the same floor")
		for r in plain.rooms:
			check(not r.harbinger, "no harbinger unhunted")
	check(hunted >= 6, "a harbinger on nearly every floor (%d of 8)" % hunted)
	for r in DungeonGen.generate(3, 1, "rootmire", false, "", world).rooms:
		check(r.props.filter(func(p): return p.get("event", "") == "spoor").is_empty(), "only the hunted region")


func test_reading_signs_weakens_the_quarry_and_the_hunt_ends_in_its_rarer_form() -> void:
	_hunter()
	Contracts.take("hunt_ossuary")
	var world := Chronicle.snapshot()
	var lay := DungeonGen.generate(3, 3, "ossuary", true, "", world)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(3, "ossuary", "sword", 0, ["flare", "", ""])
	run.depth = 3
	run.world = world
	run.hunt_signs = 3
	d.build(lay, run, null)
	check(d.hunted(), "a hunt")
	var r: Room = d.layout.room(d.layout.exit_id)
	d.player.pos = r.center() + Vector2(0, 4)
	d.current_room = r
	d.active_room = r
	d._start_boss(r)
	for i in int((Dungeon.ENTRANCE + 0.2) * 30.0):
		d.simulate(1.0 / 30.0)
	var b: Enemy = d.boss
	eq(b.form, "lightless", "always its rarer form")
	var full := float(EnemyDB.get_def("warden").hp) * float(Guardians.FORMS.warden.hp)
	check(b.max_hp < full * 0.8 and b.max_hp > full * 0.6, "weaker for three signs (%.0f of %.0f)" % [b.max_hp, full])
	d._guardian_hoard(b)
	check(Contracts.finished(Contracts.taken()[0]), "the hunt is done")
	eq(d.run.resonance_bonus, 100, "and everything great worn remembers it")
	d.queue_free()


func test_a_sign_is_read_once_and_counts() -> void:
	_hunter()
	Contracts.take("hunt_ossuary")
	var world := Chronicle.snapshot()
	var d: Dungeon = null
	for s in range(1, 9):
		var lay := DungeonGen.generate(s, 2, "ossuary", false, "", world)
		d = Dungeon.new()
		d.process_mode = Node.PROCESS_MODE_DISABLED
		tree_root.add_child(d)
		var run := RunState.create(s, "ossuary", "sword", 0, ["flare", "", ""])
		run.depth = 2
		run.world = world
		d.build(lay, run, null)
		break
	var sign: Prop = null
	for p in d.props:
		if is_instance_valid(p) and p.kind == "site" and String(p.data.get("event", "")) == "spoor":
			sign = p
	check(sign != null and sign.interactable(), "a sign to read")
	sign.interact(d.player)
	eq(d.run.hunt_signs, 1, "read")
	check(not sign.interactable(), "once")
	d.queue_free()


# --- the Undervault's own rooms and what the altars change ----------------------------------

func test_authored_device_rooms_place_their_devices_on_open_floor() -> void:
	var found := {}
	for region in ["ossuary", "rootmire", "throne"]:
		for s in range(1, 120):
			var lay := DungeonGen.generate(s, 2, region, false)
			for r in lay.rooms:
				if DungeonGen.AUTHORED.has(r.authored) and ["ossuary_leaning", "root_cellar", "throne_ember_aisle", "ossuary_cold_crypt"].has(r.authored):
					var devs: Array = r.props.filter(func(p): return p.kind in ["strut", "kindle_jar", "rime_vent"])
					check(not devs.is_empty(), "%s has its devices" % r.authored)
					for p in devs:
						check(lay.grid.at(p.tile.x, p.tile.y) == TileGrid.FLOOR, "on floor")
						check(r.rect.has_point(p.tile), "inside the room")
					found[r.authored] = true
	check(found.size() >= 3, "the new rooms turn up (%s)" % str(found.keys()))


func test_a_broken_altar_makes_every_fight_restless_and_its_rubble_can_be_dug() -> void:
	Profile.data = Profile.fresh()
	var world := {"sites": {"ossuary": "broken"}}
	var lay := DungeonGen.generate(5, 2, "ossuary", false, "", world)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(5, "ossuary", "sword", 0, ["flare", "", ""])
	run.depth = 2
	run.world = world
	d.build(lay, run, null)
	var rubble: Prop = null
	for p in d.props:
		if is_instance_valid(p) and p.kind == "rubble":
			rubble = p
	check(rubble != null and rubble.interactable(), "rubble to dig")
	var before := d.props.size()
	rubble.interact(d.player)
	check(rubble.used and not d.astar.is_point_solid(rubble.tile), "dug away, the way is open")
	var fight: Room = null
	for r in d.layout.rooms:
		if r.type == Room.Type.COMBAT and not r.encounter.is_empty():
			fight = r
			break
	var n := (fight.encounter[0] as Array).size()
	d._start_encounter(fight, d.player)
	eq((fight.encounter[0] as Array).size(), n + 1, "one more foe")
	check(before > 0, "(props)")
	d.queue_free()


func test_a_kindled_altar_lamp_gives_its_flame_once() -> void:
	Profile.data = Profile.fresh()
	var world := {"sites": {"ossuary": "kindled"}}
	var lay := DungeonGen.generate(5, 2, "ossuary", false, "", world)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(5, "ossuary", "sword", 0, ["flare", "", ""])
	run.depth = 2
	run.world = world
	d.build(lay, run, null)
	var lamp: Prop = null
	for p in d.props:
		if is_instance_valid(p) and p.kind == "lamp":
			lamp = p
	check(lamp != null and lamp.interactable(), "a lamp to take a flame from")
	d.player.kindle = 0.0
	lamp.interact(d.player)
	check(d.player.kindle >= 25.0, "Kindle from it")
	check(not lamp.interactable(), "once")
	d.queue_free()


func test_a_foes_own_blow_sets_off_a_jar() -> void:
	var st := _arena()
	var pl := _wielder(st, "hearthblade")
	st.queue_free()
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(7, 2, "ossuary", false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]), null)
	var c := Vector2i(d.layout.room(d.layout.start_id).center())
	var jar := Prop.make(d, "kindle_jar", c, {})
	var e := _dummy(d, Vector2(c) + Vector2(1.5, 0.5))
	e.strike_circle(Vector2(c) + Vector2(0.5, 0.5), 1.2, 5.0)
	check(jar.used, "the jar goes up")
	check(pl != null, "(a Kindled existed)")
	d.queue_free()


# --- practice notices and the deep ---------------------------------------------------------

func test_a_techniques_notice_goes_up_for_whoever_wields_it() -> void:
	Profile.data = Profile.fresh()
	Profile.choose_weapon("sword")
	var seen := {}
	for k in 30:
		Profile.data.contracts = {"offer": [], "taken": [], "done": k}
		for id in Contracts.offers():
			var c := Contracts.def_of(String(id))
			if c.has("tech"):
				seen[String(c.tech)] = true
	check(seen.has("cadence"), "a sword's notice")
	check(not seen.has("focus") and not seen.has("point"), "not another weapon's")


func test_practice_is_counted_by_the_technique_itself() -> void:
	Profile.data = Profile.fresh()
	Profile.choose_weapon("sword")
	Profile.data.contracts = {"offer": ["t_cadence"], "taken": [], "done": 0}
	check(Contracts.take("t_cadence"), "taken")
	var lay := DungeonGen.generate(7, 2, "ossuary", false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]), null)
	var w := d.player.weapon
	w._cadence_next = true
	w._begin_cadenced()
	eq(int(Contracts.taken()[0].n), 1, "a strike in time counts")
	d.queue_free()


func test_deep_hollow_echoes_wear_their_rarer_forms() -> void:
	var src := FileAccess.get_file_as_string("res://src/world/dungeon.gd")
	check(src.contains("layout.depth >= 12"), "from depth 12")
	check(Delve.MILESTONES.has(25) and Delve.MILESTONES.has(40), "new milestones deeper down")


# --- saves -----------------------------------------------------------------------------------

func test_a_save_with_everything_new_survives_many_load_and_save_cycles() -> void:
	Profile.data = Profile.fresh()
	Profile.data.world["warden_kills"] = 2
	Profile.data.contracts = {"offer": [], "taken": [{"id": "hunt_ossuary", "n": 0}, {"id": "t_cadence", "n": 7}], "done": 3}
	var it := Profile.add_item(ItemDB.make_item("gloamfang", "legendary", 3, RandomNumberGenerator.new(), 2))
	it["res"] = 640
	Evolutions.choose(it, "storm")
	Profile.equip(int(it.uid))
	Profile.data.grudges = [{"id": "g1", "enemy": "husk", "name": "Oth", "level": 3, "embers": 50, "settled": false, "marks": ["hardened"], "history": ["x"]}]
	Chronicle.rescue("maren")
	Chronicle.set_site("ossuary", "broken")
	Profile.data.skills = ["hearth", "t_cadence", "s_cadence"]
	var txt := JSON.stringify(Profile.data)
	for k in 6:
		var d: Dictionary = Profile.migrate(JSON.parse_string(txt))
		txt = JSON.stringify(d)
	var back: Dictionary = JSON.parse_string(txt)
	var w: Dictionary = {}
	for e in back.inventory.bag:
		if int(e.uid) == int(it.uid):
			w = e
	if w.is_empty():
		var worn: Variant = back.inventory.equipped
		w = worn.get("weapon", {}) if worn is Dictionary else {}
	eq(String(w.get("path", "")), "storm", "the weapon has still chosen")
	eq(int(w.get("res", 0)), 640, "with its Resonance")
	eq((back.contracts.taken as Array).size(), 2, "the notices carried")
	eq(int(back.contracts.taken[1].n), 7, "and their progress")
	eq(back.grudges[0].marks, ["hardened"], "a Grudge's mark")
	check((back.chronicle.rescued as Array).has("maren"), "Maren")
	eq(String(back.chronicle.sites.ossuary), "broken", "the altar's answer")
	eq(back.skills, ["hearth", "t_cadence", "s_cadence"], "the tree")
	eq(int(back.version), Profile.VERSION, "and the version")
