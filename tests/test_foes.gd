## How foes and guardians present themselves: every foe keeps a lit silhouette on
## the dark floors, a guardian falls before its spoils do, and finds taken at once
## are named in turn.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _meta(sheet: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % sheet))


func _foes() -> Array:
	var ids: Array = []
	for rid in EnemyDB.REGIONS:
		for id in EnemyDB.REGIONS[rid].pool + [EnemyDB.REGIONS[rid].boss]:
			if not ids.has(id):
				ids.append(id)
	return ids


func test_every_foe_carries_its_own_light_on_the_dark_floors() -> void:
	for id in _foes():
		var sheet := String(EnemyDB.get_def(id).sheet)
		var m := _meta(sheet)
		check(float(m.get("self_light", 0.0)) > 0.0, "%s keeps some of its own colour" % id)
		check(bool(m.get("emit", false)), "%s has a rim" % id)
		check(ResourceLoader.exists("res://assets/sprites/%s_emit.png" % sheet), "%s has its emission mask" % id)


func test_a_foes_rim_goes_out_as_it_falls() -> void:
	# the top of the husk's silhouette glows while it stands, and not in its last frame
	var m := _meta("husk")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/husk_emit.png"))
	var fw := int(m.frame[0])
	var fh := int(m.frame[1])
	var lit_in := func(col: int, row: int) -> int:
		var n := 0
		for y in range(row * fh, (row + 1) * fh):
			for x in range(col * fw, (col + 1) * fw):
				if img.get_pixel(x, y).r > 0.5:
					n += 1
		return n
	check(lit_in.call(0, int(m.anims.idle.row)) > 10, "it stands rimmed")
	eq(lit_in.call(4, int(m.anims.death.row)), 0, "and lies dark")


func test_every_guardian_has_a_fall_of_its_own() -> void:
	for id in ["warden", "bloom", "ashen_king"]:
		var a: Dictionary = _meta(String(EnemyDB.get_def(id).sheet)).anims
		check(a.has("death"), "%s can fall" % id)
		eq(int(a.death.frames), 6, "%s falls over six frames" % id)
		check(float(a.death.fps) <= 6.0, "%s falls slowly" % id)
		check(not a.has("hurt"), "%s still does not flinch" % id)


func test_the_foes_seen_most_change_shape_before_they_strike() -> void:
	# the attack the player must read: each wind-up differs from the idle body and
	# from the blow itself by more than a few pixels
	for pair in [["husk", "windup", "attack"], ["guard", "windup", "bash"], ["archer", "aim", "shoot"]]:
		var m := _meta(String(pair[0]))
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % pair[0]))
		var fw := int(m.frame[0])
		var fh := int(m.frame[1])
		var last := func(anim: String) -> Image:
			var a: Dictionary = m.anims[anim]
			return img.get_region(Rect2i((int(a.frames) - 1) * fw, int(a.row) * fh, fw, fh))
		var diff := func(x: Image, y: Image) -> int:
			var n := 0
			for py in fh:
				for px in fw:
					if (x.get_pixel(px, py).a > 0.5) != (y.get_pixel(px, py).a > 0.5):
						n += 1
			return n
		var idle: Image = img.get_region(Rect2i(0, int(m.anims.idle.row) * fh, fw, fh))
		check(diff.call(idle, last.call(pair[1])) >= 24, "%s: its wind-up is a different shape (%d px)" % [pair[0], diff.call(idle, last.call(pair[1]))])
		check(diff.call(last.call(pair[1]), last.call(pair[2])) >= 16, "%s: the blow is another (%d px)" % [pair[0], diff.call(last.call(pair[1]), last.call(pair[2]))])


func _boss_floor(region := "ossuary") -> Dungeon:
	var lay := DungeonGen.generate(5, 3, region, true)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(5, region, "sword", 0, ["flare", "", ""])
	run.depth = 3
	d.build(lay, run, null)
	var r: Room = d.layout.room(d.layout.exit_id)
	d.player.godmode = true
	d.player.input_enabled = false
	d.player.pos = d.random_floor_near(r.center() + Vector2(0, 3), 1.0)
	d.current_room = r
	d._start_encounter(r, d.player)
	for i in int((Dungeon.ENTRANCE + 0.2) * 30.0):
		d.simulate(1.0 / 30.0)
	return d


func test_a_turning_guardian_sheds_its_light_from_then_on() -> void:
	Profile.data = Profile.fresh()
	var d := _boss_floor()
	check(d.boss != null, "it came")
	var b: Enemy = d.boss
	eq(b.aura.a, 0.0, "nothing yet")
	b.phase_moment("Gloamfall", "test", Color(0.7, 0.5, 0.9))
	check(b.aura.a > 0.0, "the fight has turned")
	d.queue_free()


func test_a_guardians_spoils_wait_for_the_end_of_its_fall() -> void:
	Profile.data = Profile.fresh()
	var d := _boss_floor()
	var b: Enemy = d.boss
	var at := b.pos
	var count := func() -> int:
		return d.pickups.filter(func(p): return is_instance_valid(p) and p.kind == "sunshard").size()
	# (no view in a test: `Dungeon` drops at once; with one it hands them to the fall)
	b.spoils = d._spoils_of.bind(b)
	var before: int = count.call()
	eq(before, 0, "no hoard on the floor")
	check(b.spoils.is_valid(), "the hoard is waiting")
	b.spoils.call()
	eq(count.call(), 2, "and lands when it is called")
	check(at.distance_to(b.pos) < 0.01, "where it fell")
	d.queue_free()


func test_a_guardian_fallen_without_a_screen_still_pays() -> void:
	# headless (bots, audits): nothing to wait for
	Profile.data = Profile.fresh()
	var d := _boss_floor()
	var b: Enemy = d.boss
	b.hp = 0.0
	b.die(d.player)
	check(not d.pickups.filter(func(p): return is_instance_valid(p) and p.kind == "sunshard").is_empty(), "the hoard is on the floor")
	d.queue_free()


func test_finds_at_once_are_named_in_turn() -> void:
	Profile.data = Profile.fresh()
	var d := _boss_floor()
	d.find_title(d.player, 2.4, "ONE", Color.WHITE)
	var t0: float = d._title_free
	d.find_title(d.player, 2.4, "TWO", Color.WHITE)
	check(d._title_free >= t0 + 0.55, "the next waits its turn")
	eq(Net.mute, 0, "and nothing is left muted")
	d.queue_free()


func test_a_crowned_foe_stands_taller_and_answers_to_its_title() -> void:
	Profile.data = Profile.fresh()
	var d := _boss_floor()
	var e := d._make_enemy("husk")
	e.pos = d.player.pos + Vector2(2.0, 0.0)
	d.add_actor(e)
	e.crown("Ashen Champion")
	eq(e.display_name, "Ashen Champion", "its name")
	check(e.visual.scale.x > 1.1, "a head taller")
	check(e.has_meta("champion"), "guests are told")
	d.queue_free()


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


func _kindled(st: Stage, p: Vector2) -> Player:
	var pl := Player.new()
	pl.pos = p
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""]))
	return pl


func _foe(st: Stage, id: String, p: Vector2) -> Enemy:
	var scr: GDScript = load(EnemyDB.get_def(id).script)
	var e: Enemy = scr.new()
	e.configure(id)
	e.pos = p
	st.add_actor(e)
	e.spawn_t = 0.01
	e.state = "idle"
	e.sprite.set_dissolve(0.0)
	return e


func test_the_tolls_ring_finds_you_in_the_open_once() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var pl := _kindled(st, Vector2(16.5, 9.5))
	var e := _foe(st, "tollkeeper", Vector2(10.5, 9.5))
	var hp0 := pl.hp
	e._toll()
	for i in 60:
		e._tend_rings(1.0 / 30.0)
	check(pl.hp < hp0, "the ring found them")
	var hp1 := pl.hp
	for i in 30:
		e._tend_rings(1.0 / 30.0)
	eq(pl.hp, hp1, "once")
	check(e._rings.is_empty(), "and it is spent")
	st.queue_free()


func test_a_wall_or_a_dodge_stops_the_toll() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var pl := _kindled(st, Vector2(16.5, 9.5))
	var e := _foe(st, "tollkeeper", Vector2(10.5, 9.5))
	for y in range(7, 13):
		st.grid.put(13, y, TileGrid.WALL)
	var hp0 := pl.hp
	e._toll()
	for i in 60:
		e._tend_rings(1.0 / 30.0)
	eq(pl.hp, hp0, "a wall shelters them")
	for y in range(7, 13):
		st.grid.put(13, y, TileGrid.FLOOR)
	pl.dodge_t = 9.0
	e._toll()
	for i in 60:
		e._tend_rings(1.0 / 30.0)
	eq(pl.hp, hp0, "a dodge goes through it")
	st.queue_free()


func test_the_ring_you_see_is_the_ring_that_hits() -> void:
	# Fx.ring's curve, sampled
	var R: float = load(EnemyDB.get_def("tollkeeper").script).RING_R
	var script: GDScript = load(EnemyDB.get_def("tollkeeper").script)
	near(script.ring_radius(0.0), R * 0.25, 0.01, "it starts small")
	near(script.ring_radius(script.RING_LIFE), R, 0.01, "and ends at its edge")


func test_a_lurecap_waits_until_you_are_close() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var pl := _kindled(st, Vector2(20.5, 9.5))
	var e := _foe(st, "lurecap", Vector2(10.5, 9.5))
	for i in 30:
		e.behave(1.0 / 30.0)
	check(e.hidden, "far off it is a mushroom")
	eq(e.vel, Vector2.ZERO, "and stands still")
	pl.pos = e.pos + Vector2(1.6, 0.0)
	e.behave(1.0 / 30.0)
	check(not e.hidden, "close by it is not")
	eq(e.state, "unfold", "it unfolds first: there is a moment to react")
	st.queue_free()


func test_a_struck_lurecap_gives_up_the_pretence() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var pl := _kindled(st, Vector2(20.5, 9.5))
	var e := _foe(st, "lurecap", Vector2(10.5, 9.5))
	e.hp -= 1.0
	e.behave(1.0 / 30.0)
	check(not e.hidden, "hit first, it has lost its chance")
	check(pl != null, "(a Kindled was there)")
	st.queue_free()


func test_a_room_never_ends_on_a_hunt_for_a_mushroom() -> void:
	Profile.data = Profile.fresh()
	var d := _boss_floor("rootmire")
	var e := d._make_enemy("lurecap")
	e.pos = d.player.pos + Vector2(9.0, 0.0)
	d.add_actor(e)
	d.room_enemies = [e]
	e.spawn_t = 0.01
	e.state = "idle"
	check(e._spotted(), "the last foe of a room stops pretending")
	d.queue_free()


func test_a_decree_marks_one_kindled_until_its_voice_falls() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var pl := _kindled(st, Vector2(16.5, 9.5))
	var e := _foe(st, "herald", Vector2(10.5, 9.5))
	var blow := func() -> float:
		var hp0 := pl.hp
		var h := Hit.make(null, 10.0, ["melee"])
		h.can_crit = false
		pl.invuln_t = 0.0
		pl.take_enemy_hit(h, null)
		var lost: float = hp0 - pl.hp
		pl.hp = pl.max_hp
		return lost
	var plain: float = blow.call()
	e._proclaim()
	check(pl.marked_t > 0.0, "marked")
	check(float(blow.call()) > plain, "every foe strikes harder")
	e.hp = 0.0
	e.die(null)
	eq(pl.marked_t, 0.0, "the decree dies with its voice")
	eq(float(blow.call()), plain, "and they stand as they were")
	st.queue_free()


func test_a_decree_runs_out_on_its_own() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var pl := _kindled(st, Vector2(16.5, 9.5))
	var e := _foe(st, "herald", Vector2(10.5, 9.5))
	e._proclaim()
	for i in int(5.5 * 30.0):
		st.simulate(1.0 / 30.0)
	eq(pl.marked_t, 0.0, "five seconds, no more")
	st.queue_free()


func test_a_ring_or_a_slash_reaches_guests_once() -> void:
	# (a still full-size copy used to arrive with it: on a guest's screen a
	# Tollkeeper's ring showed its last size from the first moment)
	var st := _arena()
	var net := Net.new()
	tree_root.add_child(net)
	var had := Net.i
	Net.i = net
	var sync := NetRun.new()
	net.run_sync = sync
	var was_rec := Net.recording
	Net.recording = true
	st.fx.ring(Vector2(5, 5), 6.0, Color.WHITE, 0.5, 0.25)
	st.fx.swipe(Vector2(5, 5), Vector2.RIGHT, 2.0, 1.0, Color.WHITE)
	var kinds: Array = sync.events.map(func(ev): return String(ev[1]))
	eq(kinds, ["ring", "swipe"], "one event each, and nothing more")
	Net.recording = was_rec
	Net.i = had
	net.run_sync = null
	sync.free()
	net.queue_free()
	st.queue_free()


func test_a_snuffer_steals_a_third_of_the_flame_and_killing_it_brings_it_home() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var p := _kindled(st, Vector2(10.5, 9.5))
	var e := _foe(st, "snuffer", Vector2(9.0, 9.5))
	var full := p.kindle_max()
	p.kindle = full
	e.landed_on(p)
	eq(p.kindle, full, "a stray blow steals nothing")
	e.state = "spent"
	e.landed_on(p)
	check(p.kindle < full * 0.7, "the flame is gone (%.0f of %.0f)" % [p.kindle, full])
	check(p.snuffed_t > 0.0, "the lantern burns low")
	eq(e.state, "flee", "it runs")
	p._update_lantern(0.02)
	var dim := p.lantern.omni_range
	e.die(p)
	check(p.kindle > full * 0.85, "it comes home with interest (%.0f)" % p.kindle)
	eq(p.snuffed_t, 0.0, "and the lantern burns as it did")
	p._update_lantern(0.02)
	check(dim < p.lantern.omni_range, "brighter again")
	st.queue_free()


func test_a_snuffer_left_alone_keeps_the_flame_and_stays_bounded() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var p := _kindled(st, Vector2(10.5, 9.5))
	var e := _foe(st, "snuffer", Vector2(9.0, 9.5))
	e.state = "spent"
	p.kindle = p.kindle_max()
	e.landed_on(p)
	var after := p.kindle
	e.hp = e.max_hp * 0.5
	var fast: float = e.speed
	e._swallow()
	eq(e.stolen, 0.0, "swallowed")
	check(e.hp > e.max_hp * 0.7, "it heals")
	check(e.speed > fast, "it is quicker")
	e.die(p)
	eq(p.kindle, after, "and that flame is gone")
	st.queue_free()


func test_a_dodge_goes_through_a_snuffer() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var p := _kindled(st, Vector2(10.5, 9.5))
	var e := _foe(st, "snuffer", Vector2(10.0, 9.5))
	p.kindle = p.kindle_max()
	p.dodge_t = 0.3
	e.state = "lunge"
	e._touch()
	eq(p.kindle, p.kindle_max(), "nothing taken")
	eq(e.state, "spent", "and it has missed")
	st.queue_free()


func test_a_ward_stops_a_snuffer() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var p := _kindled(st, Vector2(10.5, 9.5))
	var e := _foe(st, "snuffer", Vector2(10.0, 9.5))
	p.kindle = p.kindle_max()
	p.ward_t = 0.3
	e.state = "lunge"
	e._touch()
	eq(e.stolen, 0.0, "a Ward keeps the flame")
	st.queue_free()


func test_a_gravehook_drags_what_it_catches_and_a_dodge_leaves_it_nothing() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var p := _kindled(st, Vector2(16.5, 9.5))
	var e := _foe(st, "gravehook", Vector2(10.5, 9.5))
	e.aim_dir = Vector2.RIGHT
	p.dodge_t = 0.3
	e._throw()
	check(e.caught == null, "a dodge goes through the chain")
	eq(p.push, Vector2.ZERO, "and drags nothing")
	p.dodge_t = 0.0
	p.invuln_t = 0.0
	e._throw()
	check(e.caught == p, "caught")
	check(p.push.x < -10.0, "dragged toward it (%.0f)" % p.push.x)
	# the drag ends at its feet, not through them
	var d: float = p.push.length() / 9.0
	check(absf(d - (p.pos.distance_to(e.pos) - 1.6)) < 0.2, "at arm's length")
	st.queue_free()


func test_a_chain_does_not_pass_through_a_wall() -> void:
	Profile.data = Profile.fresh()
	var st := _arena()
	var p := _kindled(st, Vector2(16.5, 9.5))
	var e := _foe(st, "gravehook", Vector2(10.5, 9.5))
	st.grid.put(13, 9, TileGrid.WALL)
	e.aim_dir = Vector2.RIGHT
	e._throw()
	check(e.caught == null, "stone stops it")
	st.queue_free()


func test_a_guard_steps_between_a_kindled_and_the_rooms_shooter() -> void:
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(7, 2, "ossuary", false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]), null)
	var c: Vector2 = d.layout.room(d.layout.start_id).center()
	var g: Enemy = d._make_enemy("guard")
	g.pos = c + Vector2(-4, 0)
	d.add_actor(g)
	var a: Enemy = d._make_enemy("archer")
	a.pos = c
	d.add_actor(a)
	d.room_enemies = [g, a]
	d.player.pos = c + Vector2(4, 0)
	var at: Vector2 = g._stand(d.player)
	check(at.x > c.x and at.x < d.player.pos.x, "between them (%.1f)" % at.x)
	d.room_enemies = [g]
	eq(g._stand(d.player), d.player.pos, "with nobody to guard it just comes for you")
	d.queue_free()


func _guardian_floor(region: String, form: String) -> Dungeon:
	Profile.data = Profile.fresh()
	Guardians.force = form
	var boss: String = EnemyDB.REGIONS[region].boss
	var lay := DungeonGen.generate(3, 3, region, true)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var run := RunState.create(3, region, "sword", 0, ["flare", "", ""])
	run.depth = 3
	d.build(lay, run, null)
	var r: Room = d.layout.room(d.layout.exit_id)
	d.player.pos = r.center() + Vector2(0, 4)
	d.current_room = r
	d.active_room = r
	d._start_boss(r)
	for i in int((Dungeon.ENTRANCE + 0.2) * 30.0):
		d.simulate(1.0 / 30.0)
	Guardians.force = ""
	check(is_instance_valid(d.boss) and d.boss.id == boss, "%s has arrived" % boss)
	return d


func test_a_guardian_is_only_changed_after_it_has_been_learned() -> void:
	eq(Guardians.form_of("warden", "ossuary", 7, 3, {"felled": {"ossuary": 0}}), "", "the first meeting is the plain one")
	var seen := 0
	for s in 200:
		var f := Guardians.form_of("warden", "ossuary", s, 3, {"felled": {"ossuary": 2}})
		eq(f, Guardians.form_of("warden", "ossuary", s, 3, {"felled": {"ossuary": 2}}), "the same for every machine")
		if f != "":
			eq(f, "lightless", "its own form")
			seen += 1
	check(seen > 40 and seen < 120, "sometimes (%d of 200)" % seen)


func test_the_lightless_warden_fights_in_the_dark_and_the_braziers_answer_it() -> void:
	var d := _guardian_floor("ossuary", "lightless")
	var w: Enemy = d.boss
	eq(w.form, "lightless", "its form")
	eq(w.display_name, "The Lightless Warden", "named")
	eq(w._lit_count(), 0, "the arena is dark")
	eq(d.layout.room(d.layout.exit_id).rule, "unlit", "the lantern shrinks here")
	check(String(d.objective.get("text", "")).contains("0/4"), "the HUD says what to do")
	eq(d.rule_here(), "unlit", "and the rule holds")
	for b in w.braziers:
		b.set_lit(true)
		w.on_brazier_lit()
	eq(w.state, "seared", "all four sear it, whatever its health")
	check(d.objective.is_empty(), "the task is done")
	eq(d.rule_here(), "", "the light is back")
	d.queue_free()


func test_the_lightless_warden_steps_behind_you_with_a_warning() -> void:
	var d := _guardian_floor("ossuary", "lightless")
	var w: Enemy = d.boss
	d.player.look = Vector2.RIGHT
	w.intro = false
	w._begin_step()
	eq(w.state, "step_out", "it goes into the dark")
	w._step_through()
	eq(w.state, "sweep_windup", "and comes out winding up, never mid-blow")
	check(w.pos.distance_to(d.player.pos) < 5.0, "beside you")
	check(not d.grid.box_blocked(w.pos, w.box()), "on open floor")
	d.queue_free()


func test_the_plain_warden_is_as_it_was() -> void:
	var d := _guardian_floor("ossuary", "")
	var w: Enemy = d.boss
	eq(w.form, "", "no form")
	eq(w._lit_count(), w.braziers.size(), "its braziers burn")
	eq(d.rule_here(), "", "no rule")
	d.queue_free()


func test_the_rootbound_bloom_moves_between_roots_and_burning_them_pins_it() -> void:
	var d := _guardian_floor("rootmire", "rootbound")
	var b: Enemy = d.boss
	eq(b.form, "rootbound", "its form")
	b.intro = false
	b.state = "idle"
	var from: Vector2 = b.pos
	check(b._begin_burrow(), "it goes under")
	eq(b.state, "burrow", "with a warning where it will rise")
	for i in 60:
		b.behave(1.0 / 30.0)
		b.state_t += 1.0 / 30.0
	check(b.pos.distance_to(from) > 3.0, "it has moved (%.1f)" % b.pos.distance_to(from))
	check(not d.grid.box_blocked(b.pos, 0.4), "onto open floor")
	for n in b.braziers:
		n.used = true
	b.state = "idle"
	check(not b._begin_burrow(), "all burned: nowhere to go")
	d.queue_free()


func test_the_eclipsed_king_opens_with_the_eclipse_and_it_finds_everyone() -> void:
	var d := _guardian_floor("throne", "eclipsed")
	var k: Enemy = d.boss
	eq(k.phase, 2, "the Eclipse from the first blow")
	check(k.eclipse_t > 0.0, "with time to find the light")
	for b in k.braziers:
		b.set_lit(false)
	k.braziers[0].set_lit(true)
	d.player.pos = k.braziers[0].pos + Vector2(1, 0)
	check(k.sheltered(d.player.pos), "the light shelters")
	var hp: float = d.player.hp
	k._eclipse_land()
	eq(d.player.hp, hp, "and it holds")
	d.player.pos = k.braziers[0].pos + Vector2(6, 0)
	d.player.invuln_t = 0.0
	k._eclipse_land()
	check(d.player.hp < hp, "outside it does not")
	k.hp = k.max_hp * 0.4
	k.state = "recover"
	k.behave(0.01)
	check(k._long_night and k.safe_r < 2.6, "the Long Night")
	d.queue_free()


func test_a_rarer_form_guards_more() -> void:
	var d := _guardian_floor("ossuary", "lightless")
	var w: Enemy = d.boss
	var before: int = d.get_child_count()
	d._guardian_hoard(w)
	check(d.get_child_count() > before, "its hoard")
	eq(Chronicle.marks("form_felled_lightless"), 1, "the Chronicle keeps it")
	d.queue_free()
