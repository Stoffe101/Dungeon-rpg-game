## The world of depth: what things are made of, whether what you see is what stops you,
## and whether the traps hurt only when they look like they do.
extends TestCase

const REGIONS := ["ossuary", "rootmire", "throne"]

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _floor(region: String, seed_v := 7, depth := 1) -> Dungeon:
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(seed_v, depth, region, false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(seed_v, region, "sword", 0, ["flare", "", ""]), null)
	return d


# --- what things are made of -------------------------------------------------------

func test_every_kind_of_prop_is_what_the_table_says_it_is() -> void:
	var d := _floor("rootmire")
	var t := Vector2i(d.player.pos) + Vector2i(0, 2)
	for kind: String in Physical.OF:
		var spot := _free_tile(d)
		var extra := {}
		if kind == "urn":
			extra = {"mat": "root"}
		if kind == "boss_brazier":
			extra = {"sheet": "brazier"}
		var p := Prop.make(d, kind, spot, extra)
		var solid := not p._solid_tiles.is_empty()
		if Physical.WALK_THROUGH.has(kind):
			check(not solid, "%s does not stop anyone" % kind)
		elif kind != "icewall":
			check(solid, "%s stops whoever walks into it" % kind)
		if Physical.OF[kind] == Physical.Cls.BREAK:
			check(p.breakable, "%s can be broken" % kind)
	t = t
	d.queue_free()


func _free_tile(d: Dungeon) -> Vector2i:
	for y in range(d.grid.height):
		for x in range(d.grid.width):
			if d.grid.at(x, y) == TileGrid.FLOOR and not _used.has(Vector2i(x, y)) and Vector2(x, y).distance_to(d.player.pos) > 6.0:
				_used[Vector2i(x, y)] = true
				return Vector2i(x, y)
	return Vector2i.ZERO


var _used := {}


func test_what_stops_you_has_a_foot_as_wide_as_its_tile() -> void:
	# measured from the drawing itself
	for sheet: Array in [["thicket", "a"], ["thicket", "b"], ["thicket", "c"], ["mire_trunk", "idle"], ["mire_rock", "a"], ["mire_rock", "b"], ["bramble", "idle"], ["glowcap", "idle"], ["mire_log", "idle"]]:
		var a := Physical.art_of(String(sheet[0]), String(sheet[1]))
		check(int(a.foot) >= Physical.FOOT_MIN, "%s stands on something (%d texels)" % [sheet[0], a.foot])
		check(int(a.foot) <= Physical.FOOT_MAX + 12, "%s's foot is not far wider than what stops you (%d)" % [sheet[0], a.foot])


func test_ground_cover_is_low_and_thin_enough_to_be_walked_through() -> void:
	var info := SpriteLib.get_sheet("flora_low")
	for row: String in info.anims:
		var a := Physical.art_of("flora_low", row)
		check(int(a.h) <= Physical.GROUND_MAX_H, "%s is no taller than a boot (%d)" % [row, a.h])
	# thin: a plant's drawing is mostly air
	var img := info.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var solid := 0
	for y in info.frame_size.y:
		for x in info.frame_size.x:
			if img.get_pixel(x, y).a > 0.5:
				solid += 1
	check(solid < info.frame_size.x * info.frame_size.y / 3, "grass is blades, not a clump (%d texels)" % solid)


func test_a_solid_things_drawing_stands_on_its_tile_not_behind_it() -> void:
	var d := _floor("rootmire")
	var p := Prop.make(d, "thicket", _free_tile(d), {"anim": "a"})
	check(p.sprite.position.z > 0.3 * Iso.SQ2, "the foot is at the front of the tile (%.2f)" % p.sprite.position.z)
	d.queue_free()


func test_walking_into_a_pot_breaks_it_and_it_never_stopped_anyone() -> void:
	var d := _floor("rootmire")
	var t := _free_tile(d)
	var u := Prop.make(d, "urn", t, {"mat": "root"})
	check(u._solid_tiles.is_empty(), "no collider")
	d.player.pos = Vector2(t) + Vector2(0.5, 0.5)
	u.tick(0.02)
	check(u.used or not is_instance_valid(u) or not u.breakable, "it broke underfoot")
	d.queue_free()


func test_a_chest_made_on_top_of_someone_never_traps_them() -> void:
	var d := _floor("ossuary")
	var t := Vector2i(d.player.pos)
	Prop.make(d, "chest", t, {"tier": 1})
	var before := d.player.pos
	var r: float = d.player.box()
	var out := d.grid.move_box(before, r, Vector2(0.3, 0.0))
	check(out.distance_to(before) > 0.2, "they can walk off it")
	d.queue_free()


func test_what_falls_or_bursts_stops_nobody_afterwards() -> void:
	var d := _floor("ossuary")
	var t := _free_tile(d)
	var j := Prop.make(d, "kindle_jar", t, {})
	eq(d.grid.at(t.x, t.y), TileGrid.PROP, "a jar stands in the way")
	d.room_device(j, d.player)
	for k in 30:
		d.simulate(0.05)
	eq(d.grid.at(t.x, t.y), TileGrid.FLOOR, "burst, its tile is open")
	var t2 := _free_tile(d)
	var s := Prop.make(d, "strut", t2, {})
	d.room_device(s, d.player)
	for k in 30:
		d.simulate(0.05)
	eq(d.grid.at(t2.x, t2.y), TileGrid.FLOOR, "fallen, its tile is open")
	d.queue_free()


func test_a_hair_inside_a_prop_is_not_a_way_through_it() -> void:
	var d := _floor("rootmire")
	var t := _free_tile(d)
	Prop.make(d, "thicket", t, {"anim": "a"})
	var r: float = d.player.box()
	# just south of it, rounded a hair into it (what a position across the network can be)
	var p := Vector2(t.x + 0.5, t.y + 1.0 + r - 0.004)
	var y0 := p.y
	for k in 40:
		p = d.grid.move_box(p, r, Vector2(0.0, -0.1))
	check(p.y >= y0 - 0.02, "it stays out (%.3f from %.3f)" % [p.y, y0])
	d.queue_free()


func test_a_broken_thing_gives_its_tile_back() -> void:
	var d := _floor("rootmire")
	var t := _free_tile(d)
	var b := Prop.make(d, "bramble", t, {})
	eq(d.grid.at(t.x, t.y), TileGrid.PROP, "solid while it stands")
	for k in 5:
		b.on_struck(d.player)
	eq(d.grid.at(t.x, t.y), TileGrid.FLOOR, "open once cut")
	d.queue_free()


# --- the floors stay walkable -----------------------------------------------------

func test_the_real_box_can_reach_every_room_and_the_way_down() -> void:
	# not the nav grid: the same move_box that moves a Kindled, from where they start
	for region: String in REGIONS:
		for s in [3, 11, 23]:
			for depth in [1, 2]:
				var d := _floor(region, s, depth)
				var box: float = d.player.box()
				var reach := ColView.flood(d.grid, d.player.pos, box)
				for r in d.layout.rooms:
					# (doors are closed only while a fight holds them)
					var seen := false
					for t in _room_tiles(d, r):
						if reach.has(t):
							seen = true
							break
					if d.layout.locks.is_empty() and not _behind_secret(r):
						check(seen, "%s seed %d depth %d: room %d can be walked to" % [region, s, depth, r.id])
				for p in d.props:
					if is_instance_valid(p) and p.kind == "stairs":
						check(reach.has(Vector2i(p.pos)) or _near_reached(reach, Vector2i(p.pos)), "%s seed %d: the stairs" % [region, s])
				d.queue_free()


## A room whose only way in is a cracked wall: found by breaking it, not by walking.
func _behind_secret(r: Room) -> bool:
	if r.doors.is_empty():
		return false
	for door in r.doors:
		if not door.secret:
			return false
	return true


func _room_tiles(d: Dungeon, r: Room) -> Array:
	var out: Array = []
	for y in range(r.rect.position.y, r.rect.end.y):
		for x in range(r.rect.position.x, r.rect.end.x):
			if d.grid.room_of[y * d.grid.width + x] == r.id and d.grid.at(x, y) == TileGrid.FLOOR:
				out.append(Vector2i(x, y))
	return out


func _near_reached(reach: Dictionary, t: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if reach.has(t + Vector2i(dx, dy)):
				return true
	return false


func test_every_usable_thing_can_be_reached_and_used_from_open_floor() -> void:
	for region: String in REGIONS:
		for s in [5, 9, 13]:
			var d := _floor(region, s, 1)
			if not d.layout.locks.is_empty():
				d.queue_free()
				continue
			var reach := ColView.flood(d.grid, d.player.pos, d.player.box())
			for p in d.props:
				if not is_instance_valid(p) or not p.interactable():
					continue
				var rid := d.grid.room_of[p.tile.y * d.grid.width + p.tile.x]
				if rid >= 0 and _behind_secret(d.layout.room(rid)):
					continue
				var ok := false
				for t: Vector2i in reach:
					if (Vector2(t) + Vector2(0.5, 0.5)).distance_to(p.pos) <= p.interact_radius + 0.15:
						ok = true
						break
				check(ok, "%s seed %d: %s at %s can be used" % [region, s, p.kind, str(p.tile)])
			d.queue_free()


func test_ground_cover_grows_on_floor_never_under_what_stands_there() -> void:
	var d := _floor("rootmire", 3, 1)
	check(d.flora != null and d.flora.count > 20, "the Rootmire is green (%d plants)" % (d.flora.count if d.flora else 0))
	for t: Vector2i in d.flora.tiles():
		eq(d.grid.at(t.x, t.y), TileGrid.FLOOR, "a plant on open floor at %s" % str(t))
	d.queue_free()


func test_ground_cover_parts_underfoot_and_burns() -> void:
	var d := _floor("rootmire", 3, 1)
	var t: Vector2i = d.flora.tiles()[0]
	d.player.pos = Vector2(t) + Vector2(0.5, 0.5)
	d.flora.tick(0.2)
	check(d.flora.state_at(t).has(FloraField.STATE_PARTED), "it parts")
	d.player.pos += Vector2(30, 30)
	d.flora.tick(1.0)
	check(not d.flora.state_at(t).has(FloraField.STATE_PARTED), "and stands up again")
	d.flora.scorch(Vector2(t) + Vector2(0.5, 0.5), 0.6)
	check(d.flora.state_at(t).has(FloraField.STATE_BURNT), "fire leaves stubs")
	d.queue_free()


func test_flora_is_the_same_on_every_machine() -> void:
	var a := DungeonGen.generate(11, 2, "rootmire", false)
	var b := DungeonGen.generate(11, 2, "rootmire", false)
	for i in a.rooms.size():
		eq(a.rooms[i].flora.size(), b.rooms[i].flora.size(), "room %d" % i)


# --- spike traps ----------------------------------------------------------------------

func test_a_trap_goes_through_its_states_in_order() -> void:
	var seen: Array = []
	var k := 0.0
	while k < Prop.SPIKE_CYCLE:
		var s := Prop.spike_state(k)
		if seen.is_empty() or seen[-1] != s:
			seen.append(s)
		k += 0.01
	eq(seen, ["armed", "warn", "rise", "up", "fall"], "armed, warning, rising, up, falling")


func test_teeth_only_hurt_while_they_are_visibly_out() -> void:
	check(Prop.SPIKE_WARN >= 0.6, "time to step off (%.2f s)" % Prop.SPIKE_WARN)
	var k := 0.0
	while k < Prop.SPIKE_CYCLE:
		if Prop.spike_bites(k):
			check(Prop.spike_state(k) in ["rise", "up"], "biting only when out (%.2f)" % k)
		if Prop.spike_state(k) in ["armed", "warn", "fall"]:
			check(not Prop.spike_bites(k), "harmless at %.2f" % k)
		k += 0.01


func _trap(d: Dungeon) -> Prop:
	return Prop.make(d, "spikes", _free_tile(d), {})


func _run_trap(d: Dungeon, p: Prop, from: float, to: float) -> void:
	# (the floor's own clock: what a solo trap keeps)
	d.elapsed = from
	while d.elapsed < to:
		d.elapsed += 0.02
		p.tick(0.02)


func test_a_foot_on_the_plate_is_hurt_once_each_time_they_rise() -> void:
	var d := _floor("ossuary")
	var p := _trap(d)
	d.player.pos = p.pos
	d.player.invuln_t = 0.0
	var hp := d.player.hp
	_run_trap(d, p, 0.0, Prop.SPIKE_ARMED + Prop.SPIKE_WARN)
	eq(d.player.hp, hp, "nothing during the warning")
	_run_trap(d, p, Prop.SPIKE_ARMED + Prop.SPIKE_WARN, Prop.SPIKE_ARMED + Prop.SPIKE_WARN + Prop.SPIKE_RISE + Prop.SPIKE_UP)
	check(d.player.hp < hp, "the teeth bit")
	var after := d.player.hp
	d.player.invuln_t = 0.0
	_run_trap(d, p, Prop.SPIKE_ARMED + Prop.SPIKE_WARN + Prop.SPIKE_RISE + Prop.SPIKE_UP, Prop.SPIKE_CYCLE)
	eq(d.player.hp, after, "and not as they go back in")
	d.queue_free()


func test_standing_beside_the_plate_is_safe_right_up_to_its_edge() -> void:
	var d := _floor("ossuary")
	var p := _trap(d)
	d.player.pos = p.pos + Vector2(Prop.SPIKE_REACH + 0.04, 0.0)
	var hp := d.player.hp
	_run_trap(d, p, 0.0, Prop.SPIKE_CYCLE)
	eq(d.player.hp, hp, "no damage from a trap's corner")
	d.queue_free()


func test_walking_onto_raised_teeth_hurts_too() -> void:
	var d := _floor("ossuary")
	var p := _trap(d)
	d.player.pos = p.pos + Vector2(3.0, 0.0)
	var hp := d.player.hp
	var up_at := Prop.SPIKE_ARMED + Prop.SPIKE_WARN + Prop.SPIKE_RISE + 0.1
	_run_trap(d, p, 0.0, up_at)
	d.player.pos = p.pos
	_run_trap(d, p, up_at, up_at + 0.1)
	check(d.player.hp < hp, "what is up is dangerous")
	d.queue_free()


func test_a_dodge_goes_through_the_teeth() -> void:
	var d := _floor("ossuary")
	var p := _trap(d)
	d.player.pos = p.pos
	d.player.dodge_t = 5.0
	var hp := d.player.hp
	_run_trap(d, p, 0.0, Prop.SPIKE_CYCLE)
	eq(d.player.hp, hp, "dodging")
	d.queue_free()


func test_a_trap_has_its_regions_look() -> void:
	for pair: Array in [["ossuary", "ossuary"], ["rootmire", "rootmire"], ["throne", "throne"]]:
		var d := _floor(String(pair[0]))
		var p := _trap(d)
		eq(p.sprite.sheet.name, "spike_plate_" + String(pair[1]), "its plate")
		eq(p.teeth.sheet.name, "spike_teeth_" + String(pair[1]), "its teeth")
		d.queue_free()


# --- tall things thin -----------------------------------------------------------------

func test_a_canopy_thins_over_someone_under_it_and_only_then() -> void:
	var d := _floor("rootmire")
	var t := _free_tile(d)
	var tree := Prop.make(d, "tree", t, {"anim": "a"})
	d.player.pos = tree.pos + Vector2(0.0, -2.0)
	d._occ_t = 0.0
	d.update_occlusion(0.2)
	check(tree.thinned, "someone under it")
	d.player.pos = tree.pos + Vector2(0.0, 3.0)
	d._occ_t = 0.0
	d.update_occlusion(0.2)
	check(not tree.thinned, "nobody under it")
	d.queue_free()


# --- the rest of the world --------------------------------------------------------------

func test_every_new_hybrid_node_is_reachable_and_does_something() -> void:
	for id: String in ["z_kb", "z_bp", "z_pr", "z_rg", "z_gw", "z_wk"]:
		var n := SkillDB.node(id)
		check(not n.is_empty(), id)
		check(not (n.get("flags", {}) as Dictionary).is_empty(), "%s has a power" % id)
		check(not (n.links as Array).is_empty(), "%s joins the tree" % id)


func _swing(d: Dungeon, target: Enemy, flag: String) -> Hit:
	d.player.stats.flags[flag] = 1
	var h := Hit.make(d.player, 10.0, ["melee"])
	d.player.weapon._technique(target, h)
	return h


func _foe(d: Dungeon) -> Enemy:
	var e := d._make_enemy("husk")
	e.pos = d.player.pos + Vector2(1.0, 0.0)
	d.add_actor(e)
	return e


func test_turned_aside_opens_the_next_blow_only() -> void:
	var d := _floor("ossuary")
	d.player.stats.flags["turned_aside"] = 1
	d.player.weapon.on_evade()
	var e := _foe(d)
	var h := Hit.make(d.player, 10.0, ["melee"])
	d.player.weapon._technique(e, h)
	check(h.forced_crit, "the next blow is critical")
	var h2 := Hit.make(d.player, 10.0, ["melee"])
	d.player.weapon._technique(e, h2)
	check(not h2.forced_crit, "and only that one")
	d.queue_free()


func test_rime_knife_spends_the_chill_for_half_again() -> void:
	var d := _floor("ossuary")
	var e := _foe(d)
	d.player.weapon.id = "daggers"
	e.status.apply_chill(0.3)
	e.facing = (e.pos - d.player.pos).normalized()
	var h := _swing(d, e, "rime_knife")
	check(h.amount >= 14.9, "half again (%.1f)" % h.amount)
	eq(e.status.chill, 0.0, "the chill is spent")
	d.queue_free()


func test_searing_time_lights_what_it_strikes_in_time() -> void:
	var d := _floor("ossuary")
	var e := _foe(d)
	d.player.weapon.cadenced = true
	var h := _swing(d, e, "searing_time")
	check(h.burn >= 1, "it burns")
	d.queue_free()


func test_a_great_hall_is_a_room_of_four_cells_with_a_wave_more() -> void:
	var was := DungeonGen.force_plan
	DungeonGen.force_plan = "hall"
	var lay := DungeonGen.generate(5, 2, "ossuary", false)
	DungeonGen.force_plan = was
	check(lay.hall_room >= 0, "this floor has one")
	var r := lay.room(lay.hall_room)
	check(r.rect.size.x >= 30 and r.rect.size.y >= 18, "it is big (%s)" % str(r.rect.size))
	check(r.waves >= 2, "and fought for")


func test_every_new_authored_room_stays_walkable_door_to_door() -> void:
	for id: String in ["ossuary_teeth", "root_thorn_court", "root_grove", "throne_teeth"]:
		var rows: Array = DungeonGen.AUTHORED[id]
		eq(rows.size(), 12, "%s is twelve rows" % id)
		for row: String in rows:
			eq(row.length(), 22, "%s is twenty-two wide" % id)
		# the edge of the room (where doors open) never has anything standing in it
		for x in 22:
			eq(String(rows[0])[x], ".", "%s: nothing at the north edge" % id)
			eq(String(rows[11])[x], ".", "%s: nothing at the south edge" % id)
		# door mouths clear
		for y in DungeonGen.DOOR_ROWS[0] + 3:
			pass
		var seen := {Vector2i(0, 0): true}
		var q: Array[Vector2i] = [Vector2i(0, 0)]
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			for dd: Vector2i in DungeonGen.DIRS:
				var n := c + dd
				if n.x < 0 or n.y < 0 or n.x >= 22 or n.y >= 12 or seen.has(n):
					continue
				if String(rows[n.y])[n.x] in ["#", "o", "~", " ", "T", "R", "B", "S", "J"]:
					continue
				seen[n] = true
				q.append(n)
		for y in 12:
			for x in 22:
				if String(rows[y])[x] == ".":
					check(seen.has(Vector2i(x, y)), "%s: floor at %d,%d can be walked to even with every thorn standing" % [id, x, y])


func test_an_errand_counts_only_the_stage_it_has_reached() -> void:
	Profile.data = Profile.fresh()
	Profile.data.contracts = {"offer": ["c_clapper"], "taken": [], "done": 0}
	check(Contracts.take("c_clapper"), "taken")
	Contracts.note("vault")
	eq(int(Contracts.taken()[0].n), 0, "the vault does not count before the chests")
	Contracts.note("chest", 3)
	eq(int(Contracts.taken()[0].n), 1, "the chests")
	Contracts.note("vault")
	eq(int(Contracts.taken()[0].n), 2, "now the vault")
	Contracts.note("grudge")
	check(Contracts.finished(Contracts.taken()[0]), "and the errand is done")


func test_someone_says_it_once_and_then_goes_back_to_talking() -> void:
	Profile.data = Profile.fresh()
	Profile.data.world["warden_kills"] = 1
	var first := Residents.talk("teodric")
	check(String(first[0]).contains("bell"), "the news")
	var second := Residents.talk("teodric")
	check(not String(second[0]).contains("I heard the bell"), "said once")


func test_a_hunts_style_is_the_same_on_every_machine() -> void:
	var world := {"hunts": ["ossuary"]}
	var a := DungeonGen.generate(3, 1, "ossuary", false, "", world)
	var b := DungeonGen.generate(3, 1, "ossuary", false, "", world)
	eq(a.hunt_style, b.hunt_style, "the same style")


func test_grown_sheets_exist_for_every_path_of_every_great_weapon() -> void:
	for base: String in Evolutions.PATHS:
		var sprite := String(ItemDB.base(base).sprite)
		check(ResourceLoader.exists("res://assets/sprites/%s_awake.png" % sprite), "%s awake" % base)
		for p: Dictionary in Evolutions.PATHS[base]:
			check(ResourceLoader.exists("res://assets/sprites/%s_%s.png" % [sprite, p.id]), "%s %s" % [base, p.id])
