## Weapon forms (ItemDB "form"): each variant plays its own way - checked in a
## headless simulation with real weapons, foes and their statuses.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _stage() -> Stage:
	var g := TileGrid.new(24, 14)
	for y in range(2, 12):
		for x in range(2, 22):
			g.put(x, y, TileGrid.FLOOR)
	g.finalize_walls()
	var st := Stage.new()
	st.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(st)
	st.setup(g, null)
	return st


func _player(st: Stage, base: String) -> Player:
	Profile.data = Profile.fresh()
	var it := ItemDB.make_item(base, "common", 1, RandomNumberGenerator.new(), 1)
	Profile.equipped()["weapon"] = it
	var pl := Player.new()
	pl.pos = Vector2(5, 7)
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", ItemDB.arch_of(it), 0, ["flare", ""]))
	pl.set_weapon(ItemDB.arch_of(it), 0)
	pl.aim = Vector2.RIGHT
	pl.kindle = 100.0
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


func _tap(st: Stage, pl: Player, n: int, gap := 0.45) -> void:
	for i in n:
		pl.aim = Vector2.RIGHT
		pl.weapon.press()
		_run(st, 0.05)
		pl.weapon.release()
		_run(st, gap)


func _hold(st: Stage, pl: Player, secs: float) -> void:
	pl.aim = Vector2.RIGHT
	pl.weapon.press()
	_run(st, secs)
	pl.aim = Vector2.RIGHT
	pl.weapon.release()


func _shots(st: Stage, sheet: String) -> int:
	return st.projectiles.filter(func(p): return is_instance_valid(p) and p.sprite and p.sprite.sheet and p.sprite.sheet.name == sheet).size()


func test_every_variant_has_a_form() -> void:
	var forms := {}
	for id in ItemDB.weapon_bases():
		var b := ItemDB.base(id)
		if b.get("unique", false) or b.get("legendary", false):
			continue
		var f := String(b.get("form", ""))
		if f != "":
			forms[f] = id
	eq(forms.size(), 14, "two forms for each of the seven archetypes")


func test_gravecleaver_sunders_and_executes() -> void:
	var st := _stage()
	var pl := _player(st, "gravecleaver")
	eq(pl.weapon.form, "cleaver", "the Gravecleaver plays as a cleaver")
	eq(pl.weapon.max_combo(), 2, "two cleaves")
	var e := _foe(st, Vector2(6.4, 7))
	_run(st, 0.8)
	_tap(st, pl, 3, 0.7)
	check(e.status.exposed_t > 0.0, "the third blow Sunders it (Exposed %.1f s)" % e.status.exposed_t)
	# Grave Drop finishes the wounded
	var w := _foe(st, Vector2(7.0, 7), 100.0)
	w.hp = 20.0
	_run(st, 0.5)
	_hold(st, pl, 0.7)
	_run(st, 0.4)
	check(not w.alive, "Grave Drop executes a foe at a fifth of its health")
	st.queue_free()


func test_duelist_ripostes() -> void:
	var st := _stage()
	var pl := _player(st, "duelist_sabre")
	eq(pl.weapon.max_combo(), 4, "four thrusts")
	var e := _foe(st, Vector2(7.0, 7))
	_run(st, 0.8)
	pl.weapon.on_evade()
	check(pl.weapon.riposte, "a perfect dodge or Ward readies a riposte")
	var hp0 := e.hp
	_tap(st, pl, 1)
	check(not pl.weapon.riposte and e.hp < hp0, "the next thrust is the riposte (%.0f -> %.0f)" % [hp0, e.hp])
	# En Garde: the first blow on the raised blade is turned and answered
	pl.weapon.press()
	_run(st, 0.3)
	eq(int(pl.weapon.phase), int(Weapon.Phase.CHARGE), "holding raises the guard")
	pl.invuln_t = 0.0
	pl.dodge_age = 99.0
	var hp1 := pl.hp
	var hp_e := e.hp
	var h := Hit.make(e, 12.0, ["melee"])
	h.from_dir = Vector2.LEFT
	pl.take_enemy_hit(h, e)
	eq(pl.hp, hp1, "the blow is turned")
	check(e.hp < hp_e, "and answered at once")
	pl.weapon.release()
	st.queue_free()


func test_tombmaul_aftershocks_and_tombfall() -> void:
	var st := _stage()
	var pl := _player(st, "tombmaul")
	var e := _foe(st, Vector2(7.2, 7))
	_run(st, 0.8)
	_tap(st, pl, 1, 0.9)       # the sweep
	var after_sweep := e.hp
	_tap(st, pl, 1, 1.4)       # the slam, and its two aftershocks
	var slam_only := float(GearDB.weapon("hammer").damage[1])
	check(after_sweep - e.hp > slam_only * 1.1, "the slam's aftershocks strike again (%.0f taken)" % (after_sweep - e.hp))
	var e2 := _foe(st, Vector2(8.6, 7))
	_run(st, 0.3)
	var hp2 := e2.hp
	_hold(st, pl, 1.35)
	check(pl.weapon.is_busy(), "Tombfall plants the maul")
	_run(st, 1.4)
	check(e2.hp < hp2, "and the quakes roll out to what stands near")
	st.queue_free()


func test_emberforge_heats_and_vents() -> void:
	var st := _stage()
	var pl := _player(st, "emberforge_mallet")
	_foe(st, Vector2(6.8, 7))
	_run(st, 0.8)
	_tap(st, pl, 4, 0.9)
	check(pl.weapon.heat >= 50.0, "blows that land heat the mallet (%.0f)" % pl.weapon.heat)
	_tap(st, pl, 2, 0.9)
	check(pl.weapon.heat >= 60.0 and _shots(st, "proj_spark") + st.projectiles.size() >= 0, "hot")
	check(pl.form_meter > 0.5, "the meter shows the heat (%.2f)" % pl.form_meter)
	_hold(st, pl, 1.35)
	_run(st, 0.1)
	eq(pl.weapon.heat, 0.0, "venting spends all of it")
	st.queue_free()


func test_kris_marks_and_tears() -> void:
	var st := _stage()
	var pl := _player(st, "gloam_kris")
	var e := _foe(st, Vector2(6.3, 7))
	_run(st, 0.8)
	_tap(st, pl, 3, 0.3)
	check(int(e.get_meta("gloam_marks", 0)) >= 2, "cuts leave gloam marks (%d)" % int(e.get_meta("gloam_marks", 0)))
	var k0 := pl.kindle
	pl.kindle = 10.0
	_tap(st, pl, 1, 0.4)
	eq(int(e.get_meta("gloam_marks", 0)), 0, "the crossing cut tears them open")
	check(pl.kindle > 10.0, "and feeds the lantern")
	pl.kindle = k0
	st.queue_free()


func test_shivs_throw() -> void:
	var st := _stage()
	var pl := _player(st, "ember_shivs")
	_run(st, 0.5)
	_tap(st, pl, 2, 0.18)
	check(_shots(st, "proj_shiv") >= 1, "the second cut throws a shiv")
	_run(st, 1.0)
	_hold(st, pl, 0.7)
	eq(_shots(st, "proj_shiv"), 7, "the held throw is a fan of seven")
	st.queue_free()


func test_rootspear_roots_and_partisan_holds() -> void:
	var st := _stage()
	var pl := _player(st, "rootspear")
	var e := _foe(st, Vector2(7.5, 7))
	_run(st, 0.8)
	_tap(st, pl, 1, 0.1)
	check(e.status.root_t > 0.0, "a thrust roots what it pierces")
	eq(e.status.speed_mult(), 0.0, "rooted, it cannot move")
	st.queue_free()
	var st2 := _stage()
	var pp := _player(st2, "wardens_partisan")
	var f := _foe(st2, Vector2(9.0, 7))
	_run(st2, 0.5)
	pp.weapon.press()
	_run(st2, 0.6)
	eq(int(pp.weapon.phase), int(Weapon.Phase.CHARGE), "holding forms the line (after the first thrust)")
	pp.invuln_t = 0.0
	pp.dodge_age = 99.0
	var hp := pp.hp
	var k := pp.kindle
	var front := Hit.make(f, 10.0, ["ranged"])
	front.from_dir = Vector2.LEFT     # travelling toward the Kindled, who faces right
	pp.take_enemy_hit(front, f)
	eq(pp.hp, hp, "a blow from the front stops on the shaft")
	check(pp.kindle < k, "for a little Kindle")
	var back := Hit.make(f, 10.0, ["melee"])
	back.from_dir = Vector2.RIGHT     # from behind
	pp.take_enemy_hit(back, f)
	check(pp.hp < hp, "one from behind comes through")
	pp.weapon.release()
	st2.queue_free()


func test_bow_forms() -> void:
	var st := _stage()
	var pl := _player(st, "splitwood_bow")
	_run(st, 0.5)
	_hold(st, pl, 1.15)
	eq(_shots(st, "proj_arrow"), 5, "a long draw looses five nocked arrows")
	st.queue_free()
	var st2 := _stage()
	var pg := _player(st2, "long_rimebow")
	_foe(st2, Vector2(12, 7))
	_run(st2, 0.5)
	_hold(st2, pg, 0.72)
	eq(_shots(st2, "proj_icespear"), 1, "a Steady Shot on time is an ice spear")
	st2.queue_free()


func test_staff_forms() -> void:
	var st := _stage()
	var pl := _player(st, "rimewood_staff")
	_run(st, 0.5)
	_tap(st, pl, 1, 0.05)
	eq(_shots(st, "proj_shard"), 1, "the Rimewood looses frost shards")
	var e := _foe(st, Vector2(9, 7))
	_run(st, 0.8)
	pl.aim = Vector2.RIGHT
	pl.weapon.press()
	_run(st, 1.0)
	e.status.apply_chill(0.3)
	pl.aim = Vector2.RIGHT
	pl.weapon.release()
	_run(st, 0.05)
	check(e.status.is_frozen(), "the Frost Lance freezes the already chilled")
	st.queue_free()
	var st2 := _stage()
	var pb := _player(st2, "splitbranch_staff")
	_run(st2, 0.5)
	_tap(st2, pb, 1, 0.05)
	var forks := st2.projectiles.filter(func(p): return is_instance_valid(p) and p.fork > 0)
	check(not forks.is_empty(), "Splitbranch bolts fork")
	st2.queue_free()


func test_tome_forms() -> void:
	var st := _stage()
	var pl := _player(st, "codex_of_echoes")
	_run(st, 0.5)
	_hold(st, pl, 2.2)
	eq(_shots(st, "proj_glyph"), 3, "reading writes three circling glyphs")
	check(pl.form_meter > 0.99, "the meter counts them")
	pl.ability_slots = ["flare", ""]
	pl.ability_cd = [0.0, 0.0]
	pl.kindle = 100.0
	pl._try_ability(0)
	eq(pl.form_meter, 0.0, "casting with all three spends them on an echo")
	st.queue_free()
	var st2 := _stage()
	var pa := _player(st2, "grimoire_of_ash")
	var e := _foe(st2, Vector2(7.2, 7))
	_run(st2, 0.5)
	var hp := e.hp
	_hold(st2, pa, 1.0)
	check(e.hp < hp, "reading breathes fire on what stands before it")
	check(e.status.burning(), "and it burns")
	st2.queue_free()


func test_uniques_are_themselves() -> void:
	# each unique and legendary weapon is drawn as itself
	for id in ["thousandth_cut", "quakeheart", "hundred_embers", "gloamfang", "searing_pike", "windreturn", "hollow_index", "wardenfang", "bloomstring", "sunfall_glaive"]:
		var spr := String(ItemDB.base(id).get("sprite", ""))
		check(spr != "" and ResourceLoader.exists("res://assets/sprites/%s.png" % spr), "%s has its own sprite (%s)" % [id, spr])
	# the Thousandth Cut: swings that land gather it; when full, a flurry all around
	var st := _stage()
	var pl := _player(st, "thousandth_cut")
	eq(pl.weapon.form, "thousandth", "the Thousandth Cut counts its blows")
	var e := _foe(st, Vector2(7.5, 7))
	_run(st, 0.5)
	pl.blade_charge = Player.THOUSANDTH - 1.0
	var hp := e.hp
	pl.on_weapon_strike(1, false)
	_run(st, 0.6)
	check(e.hp < hp, "the last swing it needs is a flurry that reaches it (%.0f -> %.0f)" % [hp, e.hp])
	eq(pl.blade_charge, 0.0, "and it gathers anew")
	# what it gathered keeps through a pause between fights (4 s), then fades
	pl.on_weapon_strike(1, false)
	pl.on_weapon_strike(1, false)
	_run(st, 3.0)
	near(pl.blade_charge, 2.0, 0.01, "kept through a short pause")
	_run(st, 3.0)
	check(pl.blade_charge < 2.0, "fading once the blade rests longer")
	st.queue_free()
	# the Wand of a Hundred Embers: the hundredth calls down a great one
	var st2 := _stage()
	var pw := _player(st2, "hundred_embers")
	_run(st2, 0.5)
	pw.weapon._embers = 99
	pw.aim_point = pw.pos + Vector2(4, 0)
	_tap(st2, pw, 1, 0.05)
	eq(_shots(st2, "proj_fireball"), 1, "the hundredth ember is a great one")
	st2.queue_free()
	# the Sunfall Glaive: a falling sun where the Comet Lunge lands
	var st3 := _stage()
	var pg := _player(st3, "sunfall_glaive")
	var f := _foe(st3, Vector2(11.5, 7), 2000.0)
	_run(st3, 0.5)
	pg.aim_point = Vector2(15, 7)
	_hold(st3, pg, 1.2)
	var after_lunge := f.hp
	_run(st3, 0.6)
	check(f.hp < after_lunge, "and the sun falls after it (%.0f -> %.0f)" % [after_lunge, f.hp])
	st3.queue_free()


## The weapon masteries (Hearthtree notables) change their forms.
func test_weapon_masteries_change_their_forms() -> void:
	for id in ["m_sword", "m_hammer", "m_daggers", "m_spear", "m_bow", "m_staff", "m_tome"]:
		check(not SkillDB.node(id).is_empty(), "%s is on the Hearthtree" % id)
	var st := _stage()
	var pk := _player(st, "gloam_kris")
	eq(pk.weapon.marks_max(), 5, "a Kris foe holds five marks")
	pk.stats.add_flag("mastery_daggers")
	eq(pk.weapon.marks_max(), 7, "with Night's Tally, seven")
	st.queue_free()
	var st2 := _stage()
	var pb := _player(st2, "splitwood_bow")
	eq(pb.weapon.nock_max(), 5, "the Splitwood nocks five")
	pb.stats.add_flag("mastery_bow")
	eq(pb.weapon.nock_max(), 7, "with Quiver Lore, seven")
	st2.queue_free()
	# the Gravecleaver: two blows Sunder with the mastery
	var st3 := _stage()
	var ps := _player(st3, "gravecleaver")
	ps.stats.add_flag("mastery_sword")
	var e := _foe(st3, Vector2(6.2, 7))
	for k in 2:
		var h := Hit.make(ps, 1.0, ["melee"])
		ps.weapon._sunder(e, h)
		if k == 1:
			check(h.expose > 0.0, "the second blow Sunders")
	st3.queue_free()
