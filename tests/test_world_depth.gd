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
		for s in [3, 7, 11, 19, 23, 31]:
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
