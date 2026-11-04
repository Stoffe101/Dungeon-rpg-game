## Spells: the new kinds (a steered beam, a recast orb, a wall, a form) and
## what the reworked ones now do - headless, with real foes.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _stage() -> Stage:
	var g := TileGrid.new(26, 16)
	for y in range(2, 14):
		for x in range(2, 24):
			g.put(x, y, TileGrid.FLOOR)
	g.finalize_walls()
	var st := Stage.new()
	st.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(st)
	st.setup(g, null)
	return st


func _player(st: Stage, spells: Array) -> Player:
	Profile.data = Profile.fresh()
	var pl := Player.new()
	pl.pos = Vector2(5, 8)
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""]))
	pl.ability_slots = spells
	pl.ability_cd = [0.0, 0.0, 0.0]
	pl.aim = Vector2.RIGHT
	pl.aim_point = pl.pos + Vector2(6, 0)
	pl.kindle = 100.0
	pl.invuln_t = 0.0
	return pl


func _foe(st: Stage, p: Vector2, hp := 900.0) -> Enemy:
	var scr: GDScript = load(EnemyDB.get_def("husk").script)
	var e: Enemy = scr.new()
	e.configure("husk")
	e.pos = p
	e.speed = 0.0
	e.max_hp = hp
	e.hp = hp
	st.add_actor(e)
	return e


func _run(st: Stage, seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in int(seconds / dt):
		st.simulate(dt)
		st.fx.step(dt)


func _cast(pl: Player, slot := 0) -> void:
	pl.cast_t = 0.0
	pl._try_ability(slot)


func test_soulfire_beam() -> void:
	var st := _stage()
	var pl := _player(st, ["beam", "", ""])
	var e := _foe(st, Vector2(10, 8))
	_run(st, 0.5)
	var hp := e.hp
	_cast(pl)
	check(pl.channel_t > 1.0, "pouring the beam holds the Kindled to a walk")
	check(pl._move_mult() < 0.5, "slowly (%.2f)" % pl._move_mult())
	_run(st, 0.4)
	var early := hp - e.hp
	var mid := e.hp
	_run(st, 1.3)
	var late := mid - e.hp
	check(early > 0.0, "it burns what it touches (%.0f in 0.4s)" % early)
	check(late / 1.3 > early / 0.4, "hotter the longer it holds (%.0f/s, then %.0f/s)" % [early / 0.4, late / 1.3])
	check(e.status.burning(), "and sets it alight")
	# steered: turned away, it no longer reaches the foe
	_run(st, 0.5)
	pl.ability_cd = [0.0, 0.0, 0.0]
	pl.kindle = 100.0
	pl.aim = Vector2.UP
	e.status.clear()
	var hp2 := e.hp
	_cast(pl)
	_run(st, 0.8)
	eq(e.hp, hp2, "a beam turned away misses it")
	st.queue_free()


func test_cinder_orb_recast() -> void:
	var st := _stage()
	var pl := _player(st, ["orb", "", ""])
	var e := _foe(st, Vector2(9, 8))
	_run(st, 0.5)
	_cast(pl)
	eq(Abilities.live_orbs(pl).size(), 1, "an orb drifts out")
	var k := pl.kindle
	_run(st, 1.2)
	var hp := e.hp
	_cast(pl)     # on cooldown, but a second cast bursts the orb
	_run(st, 0.1)
	check(Abilities.live_orbs(pl).is_empty(), "a second cast bursts it")
	check(e.hp < hp - 20.0, "the burst strikes what is near (%.0f)" % (hp - e.hp))
	eq(pl.kindle >= k - 0.01, true, "bursting it costs nothing")
	st.queue_free()


func test_rimewall() -> void:
	var st := _stage()
	var pl := _player(st, ["rimewall", "", ""])
	pl.aim_point = pl.pos + Vector2(4, 0)
	_run(st, 0.3)
	_cast(pl)
	var walls := st.props.filter(func(p): return is_instance_valid(p) and p.kind == "icewall")
	check(walls.size() >= 4, "a wall of ice rises across the aim (%d blocks)" % walls.size())
	var t: Vector2i = walls[0].tile
	check(st.grid.blocks_shot(t.x, t.y), "it stops shots")
	eq(st.grid.at(t.x, t.y), TileGrid.PILLAR, "and foes")
	var e := _foe(st, Vector2(t) + Vector2(1.5, 0.5))
	_run(st, 5.2)
	eq(st.grid.at(t.x, t.y), TileGrid.FLOOR, "melted, the floor is free again")
	check(e.hp < e.max_hp, "and its shards cut what stood beside it")
	check(st.props.filter(func(p): return is_instance_valid(p) and p.kind == "icewall").is_empty(), "no ice is left")
	st.queue_free()


func test_hearthfire_form() -> void:
	var st := _stage()
	var pl := _player(st, ["hearthfire", "", ""])
	var a := _foe(st, Vector2(6.3, 8))
	var b := _foe(st, Vector2(6.6, 8.6))
	_run(st, 0.5)
	pl.status.apply_chill(0.6)
	_cast(pl)
	check(pl.hearthfire_t > 6.0, "the Kindled becomes hearth-fire")
	eq(pl.status.chill, 0.0, "cold lets go of it")
	_run(st, 0.3)
	check(pl._move_mult() > 1.2, "it moves faster (%.2f)" % pl._move_mult())
	var hb := b.hp
	var h := Hit.make(pl, 10.0, ["melee"])
	h.can_crit = false
	pl.deal_hit(a, h)
	check(b.hp < hb, "a weapon hit bursts in flame onto its neighbour")
	check(a.status.burning(), "and sets the struck alight")
	var ha := a.hp
	_run(st, 7.1)
	eq(pl.hearthfire_t, 0.0, "it ends")
	check(a.hp < ha, "in a nova")
	st.queue_free()


func test_reworked_spells() -> void:
	# Gloam Knives lodge, and a melee blow tears them open
	var st := _stage()
	var pl := _player(st, ["knives", "", ""])
	var e := _foe(st, Vector2(8, 8))
	_run(st, 0.3)
	_cast(pl)
	_run(st, 0.4)
	check(int(e.get_meta("knives_in", 0)) >= 1, "knives lodge in what they strike (%d)" % int(e.get_meta("knives_in", 0)))
	var hp := e.hp
	var h := Hit.make(pl, 1.0, ["melee"])
	h.can_crit = false
	pl.deal_hit(e, h)
	eq(int(e.get_meta("knives_in", 0)), 0, "a melee blow tears them open")
	check(hp - e.hp > 4.0, "for more than the blow itself (%.0f)" % (hp - e.hp))
	st.queue_free()
	# Ember Rush through a burning foe gives back most of its cooldown
	var st2 := _stage()
	var pr := _player(st2, ["rush", "", ""])
	var f := _foe(st2, Vector2(8, 8))
	f.status.apply_burn(2, 3.0, 4)
	_run(st2, 0.3)
	_cast(pr)
	var full := float(GearDB.ability("rush").cooldown) * pr.stats.v("cooldown")
	check(pr.ability_cd[0] < full * 0.5, "a Rush through the burning comes back sooner (%.1f of %.1f s)" % [pr.ability_cd[0], full])
	st2.queue_free()
	# Rekindle shakes off what clings and quickens
	var st3 := _stage()
	var pk := _player(st3, ["rekindle", "", ""])
	_run(st3, 0.3)
	pk.status.apply_chill(0.5)
	pk.status.apply_root(2.0)
	_cast(pk)
	check(pk.status.chill == 0.0 and pk.status.root_t == 0.0, "Rekindle burns off chill and roots")
	check(pk.haste_t > 0.0, "and quickens the step")
	st3.queue_free()
	# the Hearth Lantern's light leaves nothing hidden
	var st4 := _stage()
	var pn := _player(st4, ["lantern", "", ""])
	pn.aim_point = pn.pos + Vector2(3, 0)
	var g := _foe(st4, Vector2(8.6, 8))
	_run(st4, 0.3)
	_cast(pn)
	_run(st4, 0.5)
	check(g.status.exposed_t > 0.0, "a foe in the lantern's light is Exposed")
	st4.queue_free()


func test_new_spells_are_in_the_tree() -> void:
	for sp in ["beam", "orb", "rimewall", "hearthfire"]:
		var found := false
		for id in SkillDB.all_ids():
			if String(SkillDB.node(id).get("ability", "")) == sp:
				found = true
		check(found, "%s is learned in the Hearthtree" % sp)
		check(GearDB.ability(sp).has("icon"), "%s has an icon" % sp)
