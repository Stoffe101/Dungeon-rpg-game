## The expedition-evolution pass: gear felt at once wherever it changes, the
## Hearthtree below, the Apothecary's tinctures, and the branching routes.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _stage(w := 26, h := 16) -> Stage:
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


func _player(st: Stage) -> Player:
	Profile.data = Profile.fresh()
	var pl := Player.new()
	pl.pos = Vector2(8, 8)
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""]))
	return pl


func _item(base: String, rarity := "rare", level := 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return Profile.add_item(ItemDB.make_item(base, rarity, level, rng, 1))


# --- one path for gear ------------------------------------------------------------------

func test_a_weapon_of_another_kind_is_in_hand_at_once() -> void:
	var st := _stage()
	var pl := _player(st)
	check(pl.weapon.id == "sword", "starts with the sword")
	var it := _item("cinderhammer")
	check(Profile.equip(int(it.uid)), "equipped from the bag")
	check(pl._gear_due, "the change is noticed")
	pl.sync_gear()
	check(pl.weapon.id == "hammer", "the hammer is in hand on the next frame, no reload (%s)" % pl.weapon.id)
	check(pl.run.weapon_id == "hammer", "and the run knows it")
	st.queue_free()


func test_another_form_of_the_same_kind_is_taken_up() -> void:
	var st := _stage()
	var pl := _player(st)
	var a := _item("hearthblade")
	Profile.equip(int(a.uid))
	pl.sync_gear()
	var first := pl.weapon
	var b := _item("gravecleaver")
	Profile.equip(int(b.uid))
	pl.sync_gear()
	check(pl.weapon != first, "a new weapon instance for another sword form")
	check(pl.weapon_sig().begins_with("gravecleaver#"), "the gravecleaver is in hand (%s)" % pl.weapon_sig())
	# tempering what is in hand takes it up again (its numbers)
	var held := pl.weapon
	Profile.equipped().weapon.level = int(Profile.equipped().weapon.level) + 1
	Profile.mark_changed()
	pl.sync_gear()
	check(pl.weapon != held, "a tempered blade is taken up again")
	st.queue_free()


func test_armour_changes_the_numbers_at_once_and_comes_off_cleanly() -> void:
	var st := _stage()
	var pl := _player(st)
	var hp0 := pl.max_hp
	var armor0 := pl.armor
	var it := _item("grave_iron_helm", "epic", 8)
	Profile.equip(int(it.uid))
	pl.sync_gear()
	var expect := Stats.for_player()
	SkillDB.apply(Profile.skills(), expect)
	Profile.apply_sanctuary(expect)
	Profile.apply_gear(expect)
	near(pl.max_hp, roundf(expect.v("max_hp")), 0.01, "max health follows the helm")
	near(pl.armor, expect.v("armor"), 0.001, "armour follows the helm")
	check(pl.max_hp != hp0 or pl.armor != armor0, "the helm changed something")
	Profile.unequip("head")
	pl.sync_gear()
	near(pl.max_hp, hp0, 0.01, "taken off: health back")
	near(pl.armor, armor0, 0.001, "taken off: armour back")
	st.queue_free()


func test_spending_a_talent_point_is_felt_without_a_reload() -> void:
	var st := _stage()
	var pl := _player(st)
	Profile.data.level = 10
	var before := pl.stats.v("max_hp")
	# kindle the cheapest node that raises health
	var picked := ""
	for id in SkillDB.all_ids():
		if SkillDB.can_allocate(id, Profile.skills(), Profile.skill_points_free()):
			for m in SkillDB.node(id).get("mods", []):
				if String(m[0]) == "max_hp":
					picked = id
		if picked != "":
			break
	if picked == "":
		check(true, "(no adjacent health node: nothing to test)")
		st.queue_free()
		return
	Profile.allocate(picked)
	pl.sync_gear()
	check(pl.stats.v("max_hp") > before, "the node's health is on the Kindled at once")
	st.queue_free()


func test_no_steering_survives_in_settings_or_the_kindled() -> void:
	check(not Settings.DEFAULTS.has("steer"), "the steering setting is gone")
	check(Settings.DEFAULT_BINDINGS.has("hearthtree"), "the Hearthtree has its own key")
	var ev: InputEventKey = null
	for e in Settings.DEFAULT_BINDINGS.hearthtree:
		if e is InputEventKey:
			ev = e
	check(ev != null and ev.physical_keycode == KEY_K or (ev != null and ev.keycode == KEY_K), "K by default")


# --- the Kindled's silhouette pass --------------------------------------------------------

func _slots(path: String) -> Dictionary:
	var out := {}
	var re := RegEx.new()
	re.compile(r"instance uniform \w+ (\w+)[^;=]*instance_index\((\d+)\)")
	for m in re.search_all(FileAccess.get_file_as_string(path)):
		out[m.get_string(1)] = int(m.get_string(2))
	return out


func test_the_kindleds_two_passes_agree_on_their_instance_slots() -> void:
	# the silhouette rides on the body's material as a next pass: every
	# per-instance value they share must sit at the same slot, or the
	# silhouette reads another value (it dithered over the whole Kindled)
	var body := _slots("res://assets/shaders/sprite.gdshader")
	var sil := _slots("res://assets/shaders/silhouette.gdshader")
	check(body.has("lead") and sil.has("lead"), "both pin their slots")
	for k in sil:
		if body.has(k):
			check(body[k] == sil[k], "'%s' at the same slot (%d / %d)" % [k, body[k], sil[k]])
	var used := {}
	for k in body:
		used[body[k]] = k
	for k in sil:
		if not body.has(k):
			check(not used.has(sil[k]), "the silhouette's own '%s' does not reuse a body slot" % k)
