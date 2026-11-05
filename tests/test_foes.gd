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
