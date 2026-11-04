## The second human playtest's findings, each pinned down: pointer steering,
## shared co-op XP and income, private loot, the live Satchel, rooms that must
## open, foes that must spawn where they can be fought.
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


# --- pointer steering ---------------------------------------------------------------

func test_steer_follows_a_moved_pointer_only_while_w_is_held() -> void:
	var st := _stage()
	var pl := _player(st)
	var was: Variant = Settings.get_value("steer")
	Settings.values["steer"] = "on"
	var right := Vector2(5, 0)
	# W alone, the mouse resting: the screen's way
	var m := pl.steer(Vector2.UP, 0.0, right, 1.0 / 60.0)
	check(not pl.steering and m.is_equal_approx(Vector2.UP), "keys alone walk up (%s)" % m)
	# a twitch of the hand does not take the wheel
	m = pl.steer(Vector2.UP, 4.0, right, 1.0 / 60.0)
	check(not pl.steering, "a 4 px twitch does not steer")
	# a deliberate sweep does: W turns toward the pointer, smoothly
	for k in 6:
		m = pl.steer(Vector2.UP, 8.0, right, 1.0 / 60.0)
	check(pl.steering, "a sweep while W is held steers")
	for k in 60:
		m = pl.steer(Vector2.UP, 0.0, right, 1.0 / 60.0)
	check(m.dot(Vector2.RIGHT) > 0.95, "W walks toward the pointer, even when the mouse rests (%s)" % m)
	near(m.length(), 1.0, 0.01, "at full pace")
	# S backs away from it, D sidesteps
	m = pl.steer(Vector2(0.7071, -0.7071), 0.0, right, 1.0 / 60.0)
	check(m.dot(Vector2(0.7071, 0.7071)) > 0.95, "W+D walks forward-right of the pointer (%s)" % m)
	# letting go of W lets go of the wheel
	m = pl.steer(Vector2.DOWN, 0.0, right, 1.0 / 60.0)
	check(not pl.steering and m.is_equal_approx(Vector2.DOWN), "S alone after letting go walks down")
	# off: never
	Settings.values["steer"] = "off"
	for k in 10:
		m = pl.steer(Vector2.UP, 30.0, right, 1.0 / 60.0)
	check(not pl.steering and m.is_equal_approx(Vector2.UP), "off: keys walk the screen's way")
	Settings.values["steer"] = was
	st.queue_free()


# --- shared co-op income ------------------------------------------------------------

func _dungeon(seed_v: int, region := "ossuary", depth := 1) -> Dungeon:
	var lay := DungeonGen.generate(seed_v, depth, region, false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	var r := RunState.create(seed_v, region, "sword", 0, ["flare", "", ""])
	r.run_id = "test%d" % seed_v
	d.build(lay, r, null)
	return d


## A second Kindled on the host (REMOTE, as a guest's is), with its own run.
func _friend(d: Dungeon, peer := 2) -> Player:
	var p2 := Player.new()
	p2.peer_id = peer
	p2.controller = Player.Ctrl.REMOTE
	p2.pos = d.player.pos + Vector2(1.5, 0)
	d.add_actor(p2)
	var r := RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""])
	r.run_id = d.run.run_id
	p2.setup_from(r)
	return p2


func test_party_xp_is_shared_equally() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(11)
	var p1 := d.player
	var p2 := _friend(d)
	# the guest wears an XP bonus the host does not: the party's best applies to both
	p2.stats.add_mod("xp_gain", "add", 0.2)
	p2.stats.add_mod("ember_gain", "add", 0.5)
	var lvl0 := Profile.total_xp()
	var x1 := p1.run.xp_gained
	var x2 := p2.run.xp_gained
	# orbs: one taken by the host, one by the guest
	Pickup.spawn(d, "xp", p1.pos, 10)._collect(p1)
	Pickup.spawn(d, "xp", p2.pos, 10)._collect(p2)
	eq(p1.run.xp_gained - x1, p2.run.xp_gained - x2, "XP orbs credit both the same, whoever takes them")
	eq(p1.run.xp_gained - x1, 24, "with the party's best bonus (+20 percent) for both")
	# the room won: it used to go to the host alone
	x1 = p1.run.xp_gained
	x2 = p2.run.xp_gained
	var room: Room = null
	for r in d.layout.rooms:
		if r.is_combat() and r.type != Room.Type.BOSS:
			room = r
			break
	d._clear_room = room
	d._finish_clear()
	check(p2.run.xp_gained - x2 > 0, "the room's XP reaches the guest too")
	eq(p1.run.xp_gained - x1, p2.run.xp_gained - x2, "the same room XP for both")
	eq(Profile.total_xp() - lvl0, p1.run.xp_gained, "the host's own save got exactly its run's XP")
	# Embers: equal, with the best Ember bonus
	var e1 := p1.run.embers
	var e2 := p2.run.embers
	Pickup.spawn(d, "ember", p2.pos, 10)._collect(p2)
	eq(p1.run.embers - e1, p2.run.embers - e2, "Embers: the same to each")
	eq(p1.run.embers - e1, 15, "with the party's best Ember bonus")
	d.queue_free()


# --- private loot and the live Satchel ---------------------------------------------------

func test_someone_elses_find_is_invisible_here() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(12)
	var p1 := d.player
	var p2 := _friend(d)
	var item := ItemDB.make_item("grave_iron_helm", "legendary", 1, RandomNumberGenerator.new(), 1)
	var theirs := Pickup.spawn(d, "gear", p1.pos + Vector2(0.5, 0), 1, {"item": item}, p2.peer_id)
	var mine := Pickup.spawn(d, "gear", p1.pos + Vector2(0.5, 0), 1, {"item": item.duplicate(true)}, p1.peer_id)
	check(theirs.foreign and not theirs.visible, "a friend's find: not drawn on this machine")
	check(theirs.light == null and theirs.beam == null, "no light, no beam for it here")
	check(not mine.foreign and mine.visible and mine.beam != null, "my own find shows, beam and all")
	check(theirs._owner() == p2, "it answers to its owner")
	d.queue_free()


func test_found_gear_is_in_the_satchel_at_once_and_banked_once() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(13)
	var p1 := d.player
	var bag0 := Profile.bag().size()
	var item := ItemDB.make_item("grave_iron_helm", "rare", 1, RandomNumberGenerator.new(), 1)
	var pk := Pickup.spawn(d, "gear", p1.pos, 1, {"item": item})
	pk._collect(p1)
	eq(Profile.bag().size(), bag0 + 1, "taken below, it is in the Satchel at once")
	var got: Dictionary = Profile.bag().back()
	var drop := String(got.get("drop", ""))
	check(drop.begins_with(d.run.run_id + "/"), "it carries its drop id (%s)" % drop)
	check(Profile.equip(int(got.uid)), "and can be worn below")
	check(not Profile.bank_find("gear", item, drop), "the same drop delivered again is not banked twice")
	eq((d.run.settle_loot("died").gear as Array).size(), 0, "settlement adds no copy, even on a death")
	eq((d.run.found_summary().gear as Array).size(), 1, "the summary still lists it")
	d.queue_free()


# --- rooms that open --------------------------------------------------------------------

func _combat_room(d: Dungeon) -> Room:
	for r in d.layout.rooms:
		if r.is_combat() and r.type != Room.Type.BOSS and r.id != d.layout.start_id and not d.gate_nodes.get(r.id, []).is_empty():
			return r
	return null


## A FLOOR tile just beyond one of the room's gates (the passage between two
## gates, or the next room's floor) - outside its arena.
func _beyond_gate(d: Dungeon, r: Room) -> Vector2i:
	for g in d.gate_nodes[r.id]:
		var gt: Vector2i = g.get_meta("tile")
		for oy in range(-4, 5):
			for ox in range(-4, 5):
				var t := gt + Vector2i(ox, oy)
				if d.grid.at(t.x, t.y) == TileGrid.FLOOR and d.grid.room_at(t.x, t.y) != r.id:
					return t
	return Vector2i(-1, -1)


func _fight(d: Dungeon, r: Room, pls: Array) -> void:
	for p in pls:
		p.godmode = true
		p.pos = d.random_floor_near(r.center(), 1.5)
	d.current_room = r
	d._start_encounter(r, pls[0])


func _fell_all(d: Dungeon, by: Player) -> void:
	for e in d.room_enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			var h := Hit.make(by, e.hp + e.shield + 9999.0, ["melee"])
			h.can_crit = false
			h.proc = false
			by.deal_hit(e, h)


func test_a_foe_beyond_the_gate_is_brought_back() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(21, "ossuary", 2)
	var r := _combat_room(d)
	_fight(d, r, [d.player])
	var out := _beyond_gate(d, r)
	check(out.x >= 0, "a tile beyond the gate")
	# a husk raised in the passage (the playtest's sealed room)
	var e := d._make_enemy("husk")
	e.pos = Vector2(out) + Vector2(0.5, 0.5)
	d.add_actor(e)
	d.register_enemy(e)
	e.spawn_t = 0.0
	for k in 90:
		d.simulate(1.0 / 30.0)
	var t := Vector2i(floori(e.pos.x), floori(e.pos.y))
	check(d.grid.room_at(t.x, t.y) == r.id, "the watchdog brought it into the room (at %s)" % t)
	check(d.arena_fixes >= 1, "and logged the fix")
	var s := d.foe_spot(Vector2(out) + Vector2(0.5, 0.5), 0.0)
	check(d.arena_of(r).has(Vector2i(floori(s.x), floori(s.y))), "foe_spot keeps a summon in the arena")
	for w in 8:
		_fell_all(d, d.player)
		for k in 30:
			d.simulate(1.0 / 30.0)
		if r.cleared:
			break
	for k in 30:
		d.simulate(1.0 / 30.0)
	check(r.cleared, "the room is won")
	var g: Node = d.gate_nodes[r.id][0]
	var gt: Vector2i = g.get_meta("tile")
	eq(d.grid.at(gt.x, gt.y), TileGrid.FLOOR, "and its gates open")
	d.queue_free()


func test_the_room_goes_on_while_the_host_lies_dead() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(22)
	var p1 := d.player
	var p2 := _friend(d)
	var r := _combat_room(d)
	_fight(d, r, [p1, p2])
	# the host bleeds out: dead, waiting for the room to be won
	p1.alive = false
	p1.targetable = false
	for w in 8:
		_fell_all(d, p2)
		for k in 30:
			d.simulate(1.0 / 30.0)
		if r.cleared:
			break
	check(r.cleared, "the guest wins the room while the host is dead")
	for k in 30:
		d.simulate(1.0 / 30.0)
	check(p1.alive, "and the host is rekindled at its end")
	d.queue_free()


func test_bleeding_out_ends_in_death_not_another_fall() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(23)
	var p1 := d.player
	var p2 := _friend(d)
	p2.godmode = true
	p2.input_enabled = false
	p2.pos = d.random_floor_near(p1.pos + Vector2(6, 0), 2.0)     # too far to help
	p1.hp = 1.0
	p1.die(null)
	check(p1.downed and p1.alive, "a Kindled in a party goes down first")
	p1.bleed_t = 0.01
	for k in 10:
		d.simulate(1.0 / 30.0)
	check(not p1.alive and not p1.downed, "bleeding out is death (it used to lay them down again)")
	d.queue_free()


func test_a_late_trial_vote_does_not_seal_another_fight() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(24)
	var r := _combat_room(d)
	_fight(d, r, [d.player])
	var altar := Prop.new()
	altar.kind = "trial_altar"
	altar.room_id = r.id
	d.begin_trial(altar)
	check(not altar.used, "the altar waits while another fight is on")
	eq(d.active_room, r, "the fight in progress is still the one counted")
	altar.free()
	d.queue_free()


## Many floors, every combat room fought to its end: every foe spawned inside
## its arena and every room's gates open again (parties of one and four).
func test_every_room_opens_across_many_floors() -> void:
	var rooms := 0
	var outside := 0
	var stuck: Array = []
	for region in ["ossuary", "rootmire", "throne"]:
		for depth in [1, 2, 3]:
			for k in 2:
				Profile.data = Profile.fresh()
				var seed_v: int = 300 + depth * 17 + k * 101 + String(region).length()
				var d := _dungeon(seed_v, region, depth)
				var pls: Array = [d.player]
				if k == 1:
					for n in 3:
						pls.append(_friend(d, n + 2))
				for r in d.layout.rooms:
					if not r.is_combat() or r.type == Room.Type.BOSS or r.id == d.layout.start_id:
						continue
					rooms += 1
					_fight(d, r, pls)
					var guard := 0
					while d.active_room == r and guard < 40:
						guard += 1
						var ar := d.arena_of(r)
						for e in d.room_enemies:
							if is_instance_valid(e) and e.alive and not e.flying:
								var t := Vector2i(floori(e.pos.x), floori(e.pos.y))
								if not ar.has(t):
									outside += 1
						_fell_all(d, pls[guard % pls.size()])
						for f in 20:
							d.simulate(1.0 / 30.0)
					for f in 30:
						d.simulate(1.0 / 30.0)
					if not r.cleared:
						stuck.append("%s d%d seed %d room %d" % [region, depth, seed_v, r.id])
				d.queue_free()
	check(rooms > 60, "fought %d rooms" % rooms)
	eq(outside, 0, "no foe spawned outside its arena")
	check(stuck.is_empty(), "every room opened (stuck: %s)" % str(stuck))


# --- a guest at the host's forge -------------------------------------------------------

func test_a_guest_works_at_the_hosts_forge_with_their_own_purse() -> void:
	Profile.data = Profile.fresh()
	eq(Profile.building("forge"), 0, "the guest has no forge of their own")
	var item := ItemDB.make_item("grave_iron_helm", "rare", 2, RandomNumberGenerator.new(), 1)
	var own_cost := ItemDB.temper_cost(item)
	# standing in a host's camp with a level-3 workshop
	Profile.visiting = {"forge": 3}
	eq(Profile.facility("forge"), 3, "the camp's forge is the one at hand")
	check(int(ItemDB.temper_cost(item).embers) < int(own_cost.embers), "and its workshop's discount applies")
	eq(Profile.building("forge"), 0, "but no forge becomes the guest's own")
	Profile.visiting = {}
	eq(Profile.facility("forge"), 0, "home again: their own (none)")
	# a host whose forge is a ruin, a guest with one: the camp decides
	Profile.data.sanctuary["forge"] = 2
	Profile.visiting = {"forge": 0}
	eq(Profile.facility("forge"), 0, "a ruined host forge is a ruin for the guest too")
	Profile.visiting = {}


# --- what blocks looks like it blocks ---------------------------------------------------

func test_walking_into_a_corner_slides_around_it() -> void:
	var g := TileGrid.new(12, 12)
	for y in range(1, 11):
		for x in range(1, 11):
			g.put(x, y, TileGrid.FLOOR)
	g.put(6, 5, TileGrid.PILLAR)
	# walking east, the box's top edge just catching the pillar's bottom corner
	var p := Vector2(4.5, 6.0 + 0.27 - 0.1)
	for k in 40:
		p = g.move_box(p, 0.27, Vector2(0.1, 0.0))
	check(p.x > 7.0, "the walker rounds the corner and goes on (x %.2f)" % p.x)
	# but straight into the pillar's face: stopped
	var q := Vector2(4.5, 5.5)
	for k in 40:
		q = g.move_box(q, 0.27, Vector2(0.1, 0.0))
	check(q.x < 6.0, "a wall met head-on still stops you (x %.2f)" % q.x)


func test_a_wall_inside_a_room_stands_waist_high() -> void:
	Profile.data = Profile.fresh()
	var found := false
	for seed_v in range(40, 80):
		var lay := DungeonGen.generate(seed_v, 2, "ossuary", false)
		var g := lay.grid
		for y in g.height:
			for x in g.width:
				if g.at(x, y) == TileGrid.WALL and g.room_at(x, y) >= 0:
					found = true
					eq(g.wall_height(x, y), 1.0, "an interior wall is a block, not a step")
					break
			if found:
				break
		if found:
			break
	check(found, "some room has a wall inside it")


func test_wide_dressing_blocks_what_it_covers() -> void:
	Profile.data = Profile.fresh()
	var checked := 0
	for seed_v in range(1, 30):
		var d := _dungeon(seed_v, "ossuary", 2)
		for p in d.props:
			if is_instance_valid(p) and String(p.data.get("sheet", "")) == "sarcophagus":
				eq(d.grid.at(p.tile.x, p.tile.y), TileGrid.PROP, "the sarcophagus's tile blocks")
				eq(d.grid.at(p.tile.x + 1, p.tile.y), TileGrid.PROP, "and the second tile it covers")
				checked += 1
			if is_instance_valid(p) and String(p.data.get("sheet", "")) == "bone_heap":
				eq(d.grid.at(p.tile.x, p.tile.y), TileGrid.FLOOR, "a heap of bones is walked through")
		d.queue_free()
		if checked >= 3:
			break
	check(checked >= 1, "sarcophagi were placed (%d)" % checked)


# --- a crowd takes turns -----------------------------------------------------------------

func test_a_crowd_takes_turns_winding_up() -> void:
	var st := _stage(30, 20)
	var pl := _player(st)
	pl.godmode = true
	pl.pos = Vector2(14, 10)
	var foes: Array = []
	for k in 6:
		var e: Enemy = load(EnemyDB.get_def("husk").script).new()
		e.configure("husk")
		e.pos = pl.pos + Vector2.from_angle(TAU * k / 6.0) * 1.4
		st.add_actor(e)
		e.spawn_t = 0.0
		foes.append(e)
	var most := 0
	var any := 0
	for f in 300:
		st.simulate(1.0 / 60.0)
		var n := 0
		for e in foes:
			if e.alive and e.state == "windup":
				n += 1
		most = maxi(most, n)
		any += n
	check(any > 0, "the husks do attack")
	check(most <= Enemy.STRIKERS, "never more than %d winding up on one Kindled at once (saw %d)" % [Enemy.STRIKERS, most])
	st.queue_free()


# --- loadouts that never half-change without saying so --------------------------------

func test_a_loadout_is_checked_before_it_is_worn() -> void:
	Profile.data = Profile.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var helm := Profile.add_item(ItemDB.make_item("grave_iron_helm", "rare", 1, rng, 1))
	var ring := Profile.add_item(ItemDB.make_item("clover_ring", "rare", 1, rng, 1))
	Profile.equip(int(helm.uid))
	Profile.equip(int(ring.uid))
	Profile.data.skills = BuildPresets.nodes_of("knives")
	Profile.data.equipped.slots = ["flare", "knives", ""]
	Profile.save_loadout(1)
	check(String(Profile.loadout(1).get("name", "")) != "", "a saved build is named for its weapon")
	eq(Profile.loadouts_using(int(helm.uid)), ["II"], "the helm is known to be part of loadout II")
	# since then: the helm salvaged, another helm worn, Knives unlearned (a respec)
	Profile.unequip("head")
	Profile.salvage(int(helm.uid))
	var other := Profile.add_item(ItemDB.make_item("grave_iron_helm", "rare", 1, rng, 1))
	Profile.equip(int(other.uid))
	Profile.data.skills = ["hearth"]
	var c := Profile.loadout_check(1)
	eq(c.missing, ["head"], "the check names the piece that is gone")
	eq(c.spells_lost, ["knives"], "and the spell no longer taught")
	var rep := Profile.wear_loadout_report(1)
	eq(int(Profile.equipped().get("head", {}).get("uid", -1)), int(other.uid), "the helm worn now stays on (nothing left bare)")
	eq(int(Profile.equipped().get("ring", {}).get("uid", -1)), int(ring.uid), "the rest of the build goes on")
	eq(String(Profile.data.equipped.slots[1]), "", "an untaught spell leaves its slot empty")
	eq((rep.missing as Array).size(), 1, "and the report says what could not be put back")
