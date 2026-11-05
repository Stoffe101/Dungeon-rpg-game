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


# --- what you see is what stops you: the floor stays one walkable piece ---------------

const SOLID_PROPS := ["shrine", "merchant", "fountain", "hearthstone", "lore", "brazier", "boss_brazier", "sconce", "ember_well", "trial_altar"]
const REACH_PROPS := ["chest", "ember_pile", "relic_altar", "spring", "fountain", "ember_well", "trial_altar", "lost_camp", "shrine", "merchant",
	"stairs", "hearthstone", "lore", "echo"]


## The tiles a layout's props make solid (as Dungeon._place_props and Prop do).
static func _solid_tiles(lay: DungeonGen.Layout) -> Dictionary:
	var out := {}
	for r in lay.rooms:
		for pd in r.props:
			var k := String(pd.kind)
			if k == "dressing":
				if pd.get("wide", false):
					out[pd.tile] = true
					out[pd.tile + Vector2i(1, 0)] = true
				elif not DungeonGen.WALKABLE_DRESSING.has(String(pd.sheet)):
					out[pd.tile] = true
			elif k in SOLID_PROPS:
				out[pd.tile] = true
	return out


func test_solid_props_never_cut_a_room_off_or_hide_what_you_use() -> void:
	var cases := 0
	for region in ["ossuary", "rootmire", "throne"]:
		for s in [1, 2, 3, 7, 42, 99, 123, 777, 2024, 31337]:
			for depth in [1, 2, 3]:
				var lay := DungeonGen.generate(s, depth, region, depth == 3)
				var g := lay.grid
				var solid := _solid_tiles(lay)
				var a := Vector2i(lay.room(lay.start_id).center())
				var seen := {a: true}
				var q: Array[Vector2i] = [a]
				while not q.is_empty():
					var p: Vector2i = q.pop_back()
					for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						var n: Vector2i = p + d
						if seen.has(n) or solid.has(n):
							continue
						var t := g.at(n.x, n.y)
						if t == TileGrid.FLOOR or t == TileGrid.GATE:
							seen[n] = true
							q.append(n)
				var tag := "%s seed %d depth %d" % [region, s, depth]
				for r in lay.rooms:
					if r.type == Room.Type.SECRET:
						continue
					var cut: Array[Vector2i] = []
					for y in range(r.rect.position.y, r.rect.end.y):
						for x in range(r.rect.position.x, r.rect.end.x):
							var t2 := Vector2i(x, y)
							if g.at(x, y) == TileGrid.FLOOR and g.room_of[y * g.width + x] == r.id and not solid.has(t2) and not seen.has(t2):
								cut.append(t2)
					check(cut.is_empty(), "%s: room %d (%s) has %d floor tiles nobody can reach%s" % [tag, r.id, Room.Type.keys()[r.type], cut.size(),
						"" if cut.is_empty() else _around(g, solid, seen, cut[0], r)])
					for d in r.doors:
						if d.secret:
							continue
						for dt: Vector2i in d.tiles:
							check(seen.has(dt), "%s: room %d's door at %s is blocked" % [tag, r.id, dt])
					for pd in r.props:
						if not (String(pd.kind) in REACH_PROPS):
							continue
						var ok := seen.has(pd.tile)
						for dy in range(-1, 2):
							for dx in range(-1, 2):
								ok = ok or seen.has(pd.tile + Vector2i(dx, dy))
						check(ok, "%s: the %s at %s cannot be reached" % [tag, pd.kind, pd.tile])
				cases += 1
	check(cases == 90, "90 floors walked (%d)" % cases)


## A little map around a tile for a failure message: # wall, P pillar, o solid
## prop, . reachable floor, x unreachable floor, ~ pit, + gate.
static func _around(g: TileGrid, solid: Dictionary, seen: Dictionary, c: Vector2i, r: Room) -> String:
	var out := "
"
	for y in range(c.y - 4, c.y + 5):
		for x in range(c.x - 6, c.x + 7):
			var t := g.at(x, y)
			var ch := " "
			if solid.has(Vector2i(x, y)):
				ch = "o"
				for pd in r.props:
					if pd.tile == Vector2i(x, y):
						ch = String(pd.get("sheet", pd.kind)).substr(0, 1).to_upper()
			elif t == TileGrid.WALL:
				ch = "#"
			elif t == TileGrid.PILLAR:
				ch = "P"
			elif t == TileGrid.PIT:
				ch = "~"
			elif t == TileGrid.GATE:
				ch = "+"
			elif t == TileGrid.FLOOR:
				ch = "." if seen.has(Vector2i(x, y)) else "x"
			out += ch
		out += "
"
	return out


# --- the Ember Apothecary ----------------------------------------------------------------

func test_a_v13_save_gains_an_apothecary_record_untouched_otherwise() -> void:
	var old := Profile.fresh()
	old.erase("alchemy")
	old["version"] = 13
	old["embers"] = 321
	var m := Profile.migrate(old)
	check(m.get("alchemy") is Dictionary, "alchemy added")
	eq(String(m.alchemy.steeped), "hearthbalm", "Hearthbalm steeped")
	eq(int(m.embers), 321, "nothing else changes")
	eq(int(m.version), Profile.VERSION, "at the current version")


func test_reagents_teach_and_distil_tinctures() -> void:
	Profile.data = Profile.fresh()
	check(not Profile.tincture_known("kindleroot"), "unknown before its reagent")
	eq(Profile.tincture_rank("hearthbalm"), 0, "no Apothecary: nothing steeped")
	eq(String(Profile.tincture().id), "", "a plain flask")
	Profile.data.sanctuary.apothecary = 1
	check(Profile.bank_find("reagent", "kindleroot", "r1/1/1"), "a reagent banked")
	check(not Profile.bank_find("reagent", "kindleroot", "r1/1/1"), "the same drop is never banked twice")
	check(Profile.tincture_known("kindleroot"), "the first reagent teaches")
	eq(Profile.tincture_rank("kindleroot"), 1, "rank I")
	Profile.add_reagent("kindleroot")
	Profile.add_reagent("kindleroot")
	eq(Profile.tincture_rank("kindleroot"), 2, "more distil it - to II while the Apothecary is not restored")
	Profile.data.sanctuary.apothecary = 3
	eq(Profile.tincture_rank("kindleroot"), 3, "III once it is")
	check(Profile.steep("kindleroot"), "steeped")
	eq(String(Profile.character_sheet().tincture.id), "kindleroot", "the sheet carries it (a host pours a guest's draught)")
	check(not Profile.steep("gloamwater"), "an unknown tincture cannot be steeped")


func test_each_tincture_changes_what_a_drink_does() -> void:
	var st := _stage()
	var pl := _player(st)
	Profile.data.sanctuary.apothecary = 3
	for r in ["kindleroot", "wardmoth_milk", "sunwater", "grave_salt", "ashen_marrow", "gloamcap"]:
		Profile.add_reagent(r)
	pl.sync_gear(true)
	var drink := func(id: String, hp_frac: float) -> float:
		Profile.steep(id)
		pl.hp = pl.max_hp * hp_frac
		pl.flask = 3
		var before := pl.hp
		pl._drink()
		return pl.hp - before
	pl.kindle = 0.0
	var k_heal: float = drink.call("kindleroot", 0.3)
	near(pl.kindle, pl.stats.v("kindle_max"), 0.01, "Kindleroot fills the Kindle")
	var h_heal: float = drink.call("hearthbalm", 0.3)
	check(k_heal < h_heal, "...and heals less than Hearthbalm (%.0f < %.0f)" % [k_heal, h_heal])
	pl.barrier = 0.0
	drink.call("wardmilk", 0.3)
	check(pl.barrier > 0.0 and pl.barrier_t > 0.0, "Wardmilk leaves a barrier (%.0f)" % pl.barrier)
	pl.haste_t = 0.0
	pl.dodge_charges = 0.0
	drink.call("sunwater", 0.3)
	check(pl.haste_t > 0.0 and pl.dodge_charges >= pl.stats.v("dodge_charges"), "Sunwater: haste and the dodges back")
	pl.status.apply_chill(2.0)
	drink.call("salt", 0.3)
	check(pl.status.chill <= 0.0 and pl.salt_t > 0.0, "Grave-salt washes the chill off and wards")
	var low: float = drink.call("last_ember", 0.2)
	var high: float = drink.call("last_ember", 0.6)
	check(low > high * 2.0, "Last Ember heals far more on the edge (%.0f vs %.0f)" % [low, high])
	drink.call("gloamwater", 0.3)
	check(pl.tonic_chill_t > 0.0, "Gloamwater: blows chill for a while")
	st.queue_free()
