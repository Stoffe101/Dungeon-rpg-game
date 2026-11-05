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
				elif not DungeonGen.WALKABLE_DRESSING.has(String(pd.sheet)) and not pd.get("low", false):
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


# --- the Forked Descent -------------------------------------------------------------------

func test_each_floor_offers_two_ways_down_the_same_for_everyone() -> void:
	var seen := {}
	var plain := 0
	for s in [1, 2, 3, 7, 42, 99, 123, 777]:
		for depth in [1, 2]:
			var a := DungeonGen.route_offer(s, depth)
			eq(a, DungeonGen.route_offer(s, depth), "the same ways again (seed %d depth %d)" % [s, depth])
			if a.is_empty():
				plain += 1
			else:
				check(a.size() == 2 and a[0] != a[1], "two different ways")
			for r in a:
				seen[r] = true
			var lay := DungeonGen.generate(s, depth, "ossuary", false)
			var stairs: Array = []
			for pd in lay.room(lay.exit_id).props:
				if pd.kind == "stairs":
					stairs.append(String(pd.get("route", "")))
			eq(stairs.size(), maxi(1, a.size()), "a stairway for each way (seed %d depth %d)" % [s, depth])
			for r2 in a:
				check(stairs.has(r2), "each the way it names")
	eq(seen.size(), 3, "every way turns up across seeds")
	check(plain > 0 and plain < 16, "some floors simply go down (%d of 16)" % plain)
	# a broken altar's Breach, a Grudge's lair: a third way
	var w := {"sites": {"ossuary": "broken"}}
	check(DungeonGen.route_offer(7, 1, w, "ossuary").has("breach"), "a broken altar opens a Breach")
	check(not DungeonGen.route_offer(7, 1, w, "throne").has("breach"), "in its own region only")
	var boss := DungeonGen.generate(1, 3, "ossuary", true)
	check(boss.offer.is_empty(), "a guardian's floor has no fork")


func test_the_way_down_shapes_the_floor() -> void:
	var foes := {"": 0, "trial": 0, "quiet": 0}
	var elites := {"": 0, "trial": 0, "quiet": 0}
	for s in [1, 2, 3, 7, 42, 99, 123, 777, 2024, 31337]:
		for route in ["", "trial", "vault", "quiet"]:
			var lay := DungeonGen.generate(s, 2, "ossuary", false, route)
			eq(lay.route, route, "the layout knows its way")
			var det := DungeonGen.generate(s, 2, "ossuary", false, route)
			eq(det.rooms.size(), lay.rooms.size(), "deterministic per seed and way")
			var objectives: Array = []
			var rest := false
			for r in lay.rooms:
				if r.objective != "":
					objectives.append(r.objective)
				if r.type == Room.Type.REST:
					rest = true
				if r.type == Room.Type.ELITE and elites.has(route):
					elites[route] += 1
				if foes.has(route) and r.type != Room.Type.BOSS:
					for w in r.encounter:
						foes[route] += (w as Array).size()
			match route:
				"trial":
					check(objectives.size() == 1 and objectives[0] in ["seals", "champion", "gauntlet"], "a Trial of Ash floor has its hall (seed %d: %s)" % [s, objectives])
				"vault":
					check(objectives.size() == 1 and objectives[0] in ["flame", "treasury", "workshop"], "a Lost Vault floor has its vault (seed %d: %s)" % [s, objectives])
				"quiet":
					check(rest, "a Silent Passage has a spring (seed %d)" % s)
				"":
					check(objectives.is_empty(), "the plain way has no route task")
	eq(elites.quiet, 0, "no elite on a Silent Passage")
	check(elites.trial >= 20, "two elites a Trial of Ash floor (%d over 10)" % elites.trial)
	check(foes.quiet < foes[""] and foes[""] < foes.trial, "fewer foes the quiet way, more the trial's (%d / %d / %d)" % [foes.quiet, foes[""], foes.trial])


func test_route_floors_stay_walkable() -> void:
	for route in ["trial", "vault", "quiet"]:
		for s in [1, 7, 42, 777, 31337]:
			for depth in [2, 3]:
				var lay := DungeonGen.generate(s, depth, "throne" if s % 2 == 0 else "rootmire", depth == 3, route)
				var solid := _solid_tiles(lay)
				var a := Vector2i(lay.room(lay.start_id).center())
				var seen := {a: true}
				var q: Array[Vector2i] = [a]
				while not q.is_empty():
					var p: Vector2i = q.pop_back()
					for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						var n: Vector2i = p + d
						var t := lay.grid.at(n.x, n.y)
						if not seen.has(n) and not solid.has(n) and (t == TileGrid.FLOOR or t == TileGrid.GATE):
							seen[n] = true
							q.append(n)
				for r in lay.rooms:
					for pd in r.props:
						if pd.kind == "stairs":
							var ok := false
							for dy in range(-1, 2):
								for dx in range(-1, 2):
									ok = ok or seen.has(pd.tile + Vector2i(dx, dy))
							check(ok, "%s seed %d depth %d: the %s stairway can be reached" % [route, s, depth, pd.get("route", "plain")])
					if r.objective != "":
						var reach := false
						for y in range(r.rect.position.y, r.rect.end.y):
							for x in range(r.rect.position.x, r.rect.end.x):
								reach = reach or (lay.grid.room_of[y * lay.grid.width + x] == r.id and seen.has(Vector2i(x, y)))
						check(reach, "%s seed %d: the %s room can be reached" % [route, s, r.objective])


# --- the Chronicle: the Undervault remembers -----------------------------------------------

func test_a_v14_save_gains_a_chronicle_and_its_grudges_a_history() -> void:
	var old := Profile.fresh()
	old.erase("chronicle")
	old["version"] = 14
	old["grudges"] = [{"id": "g1", "enemy": "husk", "name": "Morrow the Patient", "level": 2, "embers": 90, "depth": 1, "settled": false}]
	var m := Profile.migrate(old)
	check(m.get("chronicle") is Dictionary, "a Chronicle is added")
	eq(int(m.version), Profile.VERSION, "at the current version")
	eq(String(m.grudges[0].learned), "ward", "an old Grudge gets a lesson")
	eq(int(m.grudges[0].embers), 90, "and keeps its hoard")


func test_the_altar_waits_on_one_floor_and_answers_change_later_expeditions() -> void:
	Profile.data = Profile.fresh()
	var altars := 0
	for s in [1, 2, 3, 7, 42, 99, 123, 777]:
		var n := 0
		for depth in [1, 2]:
			var lay := DungeonGen.generate(s, depth, "ossuary", false)
			for r in lay.rooms:
				if r.event == "altar":
					n += 1
					var offers := 0
					for pd in r.props:
						if pd.kind == "site" and String(pd.get("event", "")) == "altar":
							offers += 1
					eq(offers, 3, "three answers at the altar (seed %d)" % s)
		check(n == 1, "one altar an expedition while it is unanswered (seed %d: %d)" % [s, n])
		altars += n
	eq(altars, 8, "every expedition found it")
	# the answers, as a run's world reads them
	var kindled := DungeonGen.generate(5, 1, "ossuary", false, "", {"sites": {"ossuary": "kindled"}})
	var springs := 0
	for r in kindled.rooms:
		if r.type == Room.Type.REST:
			springs += 1
	check(springs >= 1, "a rekindled Vigil's spring on the floor")
	var pact := DungeonGen.generate(5, 1, "ossuary", false, "", {"sites": {"ossuary": "pact"}})
	var bowl := false
	for pd in pact.room(pact.start_id).props:
		bowl = bowl or (pd.kind == "site" and String(pd.get("event", "")) == "bowl")
	check(bowl, "the Pale Bowl waits by the door")
	# always reversible, and it writes the story
	Chronicle.set_site("ossuary", "broken")
	eq(Chronicle.site("ossuary"), "broken", "answered")
	eq(String(Chronicle.snapshot().sites.ossuary), "broken", "a run reads it")
	Chronicle.set_site("ossuary", "")
	eq(Chronicle.site("ossuary"), "", "let rest")
	check((Profile.data.chronicle.log as Array).size() >= 2, "the Chronicle tells it")


func test_a_grudge_remembers_how_you_fought() -> void:
	Profile.data = Profile.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var g := Profile.record_grudge("husk", 120, 2, rng, "bow", "ossuary")
	eq(String(g.learned), "closer", "kept your distance: it closes it")
	eq(int(g.slew), 1, "killed you once")
	check((g.history as Array).size() == 1, "and remembers where")
	g = Profile.record_grudge("husk", 40, 3, rng, "hammer", "ossuary")
	eq(String(g.learned), "ward", "stood and swung: it wards")
	eq(int(g.slew), 2, "killed you twice")
	eq(int(g.level), 2, "and grew")
	Profile.scar_grudge(String(g.id))
	eq(int(g.scars), 1, "a scar it carries")
	var sheet := Profile.character_sheet()
	eq(String(sheet.grudges[0].learned), "ward", "a host hears what it learned")
	var lv := int(g.level)
	Profile.age_grudges(rng, 3)
	eq(int(g.level), lv + 1, "the Pale Bowl feeds it a whole level")


# --- the Hollow Below -------------------------------------------------------------------------

func test_the_hollow_fractures_and_its_milestones_pay_once() -> void:
	Profile.data = Profile.fresh()
	check(Delve.fractured(4) and Delve.fractured(10) and not Delve.fractured(5), "every sixth depth from the fourth")
	check(not Delve.is_boss_depth(4) and not Delve.is_boss_depth(10) and not Delve.is_boss_depth(16), "never an Echo's floor")
	eq(Delve.overlap_region(4), "throne", "the next region lies over this one")
	var lay := DungeonGen.generate(11, 4, Delve.region_for(4), false, "", {"fracture": Delve.overlap_region(4)})
	var rift := 0
	var pools := {}
	for r in lay.rooms:
		if r.objective == "rift":
			rift += 1
		for w in r.encounter:
			for id in w:
				pools[EnemyDB.get_def(String(id)).get("sheet", "")] = true
	eq(rift, 1, "one rift to close")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var before := Profile.currency("sunshards")
	check(not Delve.reach(5, rng).is_empty(), "a milestone reached")
	eq(Profile.currency("sunshards"), before + 2, "it pays")
	check(Delve.reach(5, rng).is_empty(), "once")
	check(Delve.reach(6, rng).is_empty(), "only at its depth")


func test_omens_cap_and_exclude_each_other() -> void:
	Profile.data = Profile.fresh()
	Profile.data.world["warden_kills"] = 1
	Profile.data.world["bloom_kills"] = 1
	Profile.data.world["delve_best"] = 9
	check(Omens.unlocked("volatile") and Omens.unlocked("bleeding_lantern"), "the Hollow's signs are readable once reached")
	check(not Omens.compatible("volatile", ["glass"]), "Glass and Volatile never together")
	check(not Omens.compatible("bleeding_lantern", ["dry_flask"]), "nor a Dry Flask and a Bleeding Lantern")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var active: Array = []
	for k in 12:
		var o := Delve.next_omen(rng, active)
		if o != "":
			active.append(o)
	eq(active.size(), Delve.MAX_OMENS, "a descent reads no more than five")
	for a in active:
		check(Omens.compatible(String(a), active.filter(func(x): return x != a)), "no excluded pair (%s)" % a)
