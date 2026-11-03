## Procedural generation: connectivity, structure and determinism.
extends TestCase


func _layouts() -> Array:
	var out: Array = []
	for s in [1, 2, 3, 42, 777, 2024, 31337, 99991]:
		out.append(DungeonGen.generate(s, 1, "ossuary", false))
		out.append(DungeonGen.generate(s, 2, "ossuary", true))
	return out


func test_generates() -> void:
	for lay in _layouts():
		check(lay != null, "layout generated")


func test_room_graph_connected() -> void:
	for lay: DungeonGen.Layout in _layouts():
		var seen := {lay.start_id: true}
		var q := [lay.start_id]
		while not q.is_empty():
			var r := lay.room(q.pop_front())
			for d in r.doors:
				if not seen.has(d.to):
					seen[d.to] = true
					q.append(d.to)
		eq(seen.size(), lay.rooms.size(), "all rooms reachable (seed %d depth %d)" % [lay.seed, lay.depth])


func test_tile_path_start_to_exit() -> void:
	# walking on FLOOR only (secret walls closed) from start to exit
	for lay: DungeonGen.Layout in _layouts():
		var g := lay.grid
		var a := Vector2i(lay.room(lay.start_id).center())
		var b := Vector2i(lay.room(lay.exit_id).center())
		var seen := {}
		var q: Array[Vector2i] = [a]
		seen[a] = true
		var found := false
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			if c == b:
				found = true
				break
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if not seen.has(n) and g.at(n.x, n.y) == TileGrid.FLOOR:
					seen[n] = true
					q.append(n)
		check(found, "exit reachable on foot (seed %d depth %d)" % [lay.seed, lay.depth])


func test_structure() -> void:
	for lay: DungeonGen.Layout in _layouts():
		eq(lay.room(lay.start_id).type, Room.Type.START)
		var exit_type := lay.room(lay.exit_id).type
		eq(exit_type, Room.Type.BOSS if lay.boss_depth else Room.Type.STAIRS)
		var has_elite := false
		for r in lay.rooms:
			if r.type == Room.Type.ELITE:
				has_elite = true
			if r.is_combat() and r.type != Room.Type.BOSS:
				check(not r.spawns.is_empty(), "combat room %d has spawn points" % r.id)
				check(not r.encounter.is_empty() and not r.encounter[0].is_empty(), "combat room %d has enemies" % r.id)
			for d in r.doors:
				for t: Vector2i in d.tiles:
					var tt := lay.grid.at(t.x, t.y)
					check(tt == (TileGrid.WALL if d.secret else TileGrid.FLOOR), "door tile type")
		check(has_elite, "every floor has an elite room")
		# outer border is never floor
		for x in lay.grid.width:
			check(lay.grid.at(x, 0) != TileGrid.FLOOR, "top border closed")


func test_rooms_do_not_overlap() -> void:
	for lay: DungeonGen.Layout in _layouts():
		for i in lay.rooms.size():
			for j in range(i + 1, lay.rooms.size()):
				check(not lay.rooms[i].rect.intersects(lay.rooms[j].rect), "rooms %d/%d overlap" % [i, j])


func test_deterministic() -> void:
	var a := DungeonGen.generate(1234, 1, "ossuary", false)
	var b := DungeonGen.generate(1234, 1, "ossuary", false)
	eq(a.grid.cells, b.grid.cells, "same seed, same tiles")
	eq(a.rooms.size(), b.rooms.size())
	for i in a.rooms.size():
		eq(a.rooms[i].encounter, b.rooms[i].encounter, "same encounters")
	var c := DungeonGen.generate(1235, 1, "ossuary", false)
	check(a.grid.cells != c.grid.cells, "different seed, different floor")


func test_wall_heights_never_hide_floor() -> void:
	var lay := DungeonGen.generate(77, 1, "ossuary", false)
	var g := lay.grid
	for y in g.height:
		for x in g.width:
			if g.at(x, y) == TileGrid.WALL and g.wall_height(x, y) > 1.0:
				for k in [1, 2]:
					check(g.at(x, y - k) != TileGrid.FLOOR, "tall wall at %d,%d hides floor" % [x, y])


func test_encounter_budget() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in 50:
		var e := EnemyDB.roll_encounter(rng, "ossuary", 1, 9)
		var cost := 0
		for id in e:
			cost += int(EnemyDB.get_def(id).cost)
			check(int(EnemyDB.get_def(id).min_depth) <= 1, "%s too deep for depth 1" % id)
		check(cost <= 9 and cost >= 5, "budget respected (%d)" % cost)


func test_event_rooms() -> void:
	# events appear, their centrepieces stand on open floor, and trials have three waves
	var seen := {}
	for s in range(1, 41):
		for region in ["ossuary", "rootmire"]:
			var lay := DungeonGen.generate(s, 1 + s % 2, region, false)
			for r in lay.rooms:
				if r.type != Room.Type.EVENT:
					continue
				check(r.event in Room.EVENTS, "event kind '%s'" % r.event)
				seen[r.event] = true
				for p in r.props:
					if p.kind in ["ember_well", "trial_altar", "echo"]:
						eq(lay.grid.at(p.tile.x, p.tile.y), TileGrid.FLOOR, "seed %d %s centrepiece on floor" % [s, r.event])
				if r.event == "trial":
					eq(r.encounter.size(), 3, "trial has three waves")
					check(not r.spawns.is_empty(), "trial room has spawn points")
	eq(seen.size(), Room.EVENTS.size(), "every event kind generated")


func test_rootmire_brambles_never_seal_doors() -> void:
	# brambles are solid until burned/cut; every door must stay reachable without them
	for s in [1, 2, 3, 7, 42, 99, 123, 777]:
		for depth in [1, 2]:
			var lay := DungeonGen.generate(s, depth, "rootmire", depth == 2)
			for r in lay.rooms:
				var blocked: Array[Vector2i] = []
				for p in r.props:
					if p.kind in ["bramble", "root_node"]:
						blocked.append(p.tile)
				check(DungeonGen._doors_connected(lay, r, blocked), "seed %d depth %d room %d sealed by brambles" % [s, depth, r.id])


func test_regions_and_their_creatures() -> void:
	for rid in EnemyDB.REGIONS:
		var reg: Dictionary = EnemyDB.REGIONS[rid]
		eq(int(reg.depths), 3, "%s has three depths" % rid)
		check(EnemyDB.get_def(String(reg.boss)).has("epithet"), "%s boss has an epithet" % rid)
		check(FileAccess.file_exists("res://assets/textures/%s_floor.png" % reg.theme), "%s tiles exist" % rid)
		for id in reg.pool + [reg.boss]:
			var d := EnemyDB.get_def(String(id))
			check(ResourceLoader.exists(String(d.script)), "%s script" % id)
			check(FileAccess.file_exists("res://assets/sprites/%s.json" % d.sheet), "%s sheet" % id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 20:
			for id in EnemyDB.roll_encounter(rng, rid, 3, 9):
				check(reg.pool.has(id), "%s rolls only its own creatures (%s)" % [rid, id])
	Profile.data = Profile.fresh()
	check(not EnemyDB.region_unlocked("throne"), "the Throne is sealed at first")
	Profile.data.world["warden_kills"] = 1
	check(not EnemyDB.region_unlocked("throne"), "one boss is not enough")
	Profile.data.world["bloom_kills"] = 1
	check(EnemyDB.region_unlocked("throne"), "both bosses open the Throne")


func test_tier_might() -> void:
	var rng := RandomNumberGenerator.new()
	var lo := ItemDB.make_item("soft_boots", "common", 1, rng, 1)
	var hi := ItemDB.make_item("soft_boots", "common", 1, rng, 5)
	eq(ItemDB.tier_might(lo), 0.0, "no might at Tier I")
	near(ItemDB.tier_might(hi), 0.16, 0.001, "+4% damage per tier above I")
	var last: Array = ItemDB.mods_of(hi).back()
	eq(last[0], "damage", "tier might is the last mod")
	eq(ItemDB.mods_of(lo).size() + 1, ItemDB.mods_of(hi).size(), "only higher tiers carry it")
