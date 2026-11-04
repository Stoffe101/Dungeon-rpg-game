## Build-defining systems: projectile modifiers (Volley), the spells added in
## the evolution pass, the third spell slot, the new keystones, the tree's
## layout and the co-op reward share.
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


func _player(st: Stage, p: Vector2) -> Player:
	var pl := Player.new()
	pl.pos = p
	pl.input_enabled = false
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", "", ""]))
	return pl


func _foe(st: Stage, p: Vector2, hp := 600.0) -> Enemy:
	var scr: GDScript = load(EnemyDB.get_def("husk").script)
	var e: Enemy = scr.new()
	e.configure("husk")
	e.pos = p
	st.add_actor(e)
	e.speed = 0.0
	e.max_hp = hp
	e.hp = hp
	return e


func _run(st: Stage, seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in int(seconds / dt):
		st.simulate(dt)
		st.fx.step(dt)


func _mine(st: Stage) -> Array:
	return st.projectiles.filter(func(p): return is_instance_valid(p) and p.team == Actor.Team.PLAYER)


## One plain shot from the Kindled along `dir`, shaped by their modifiers.
func _shot(pl: Player, dir: Vector2, life := 1.0, pierce := 0) -> Projectile:
	var out := Volley.fire(pl, "proj_knife", pl.pos, dir, 20.0, 1, func(pr: Projectile, _d: Vector2) -> void:
		pr.damage = 10.0
		pr.tags = ["ability"]
		pr.life = life
		pr.pierce = pierce)
	return out[0]


func test_volley_adds_projectiles_to_every_shot() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	pl.aim = Vector2.RIGHT
	pl.aim_point = Vector2(9, 7)
	var n0 := _mine(st).size()
	check(Abilities.cast(pl, "knives"), "Gloam Knives cast")
	eq(_mine(st).size() - n0, 5, "a fan of five knives")
	_run(st, 1.0)
	pl.stats.apply_mods([["projectiles", "add", 2.0]])
	n0 = _mine(st).size()
	Abilities.cast(pl, "knives")
	eq(_mine(st).size() - n0, 7, "+2 projectiles: seven knives")
	# a volley strikes each foe once, however many of its knives touch it
	var e := _foe(st, Vector2(6.5, 7))
	_run(st, 0.8)
	var hits := [0]
	Events.damage_dealt.connect(func(t, _a, _c) -> void:
		if t == e:
			hits[0] += 1)
	Abilities.cast(pl, "knives")
	_run(st, 0.6)
	eq(hits[0], 1, "one strike per foe per volley")
	# the bow too: one draw, three arrows
	pl.set_weapon("bow", 0)
	e.alive = false
	_run(st, 1.0)
	var seen := 0
	pl.weapon.press()
	_run(st, 0.4)
	pl.weapon.release()
	for i in 20:
		_run(st, 1.0 / 60.0)
		seen = maxi(seen, _mine(st).size())
	eq(seen, 3, "+2 projectiles: a bow looses three arrows")
	st.queue_free()


func test_projectile_chain_fork_and_return() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	# chain: one shot leaps through three foes
	var foes := [_foe(st, Vector2(8, 7)), _foe(st, Vector2(10, 9)), _foe(st, Vector2(12, 7))]
	_run(st, 0.8)
	pl.stats.apply_mods([["chain", "add", 2.0]])
	_shot(pl, Vector2.RIGHT)
	_run(st, 1.5)
	eq(foes.filter(func(f): return f.hp < f.max_hp).size(), 3, "chain 2: one shot strikes three foes")
	for f in foes:
		f.alive = false
		f.queue_free()
	_run(st, 0.1)
	# fork: the first foe struck splits it in two half-strength shots
	pl.stats.apply_mods([["chain", "add", -2.0], ["fork", "add", 1.0]])
	var e := _foe(st, Vector2(7, 7))
	_run(st, 0.8)
	_shot(pl, Vector2.RIGHT)
	for i in 60:
		_run(st, 1.0 / 60.0)
		if e.hp < e.max_hp:
			break
	var parts := _mine(st)
	eq(parts.size(), 2, "the shot splits in two")
	if parts.size() == 2:
		near(float(parts[0].damage), 5.0, 0.01, "each half deals half")
	e.alive = false
	e.queue_free()
	_run(st, 1.0)
	# return: out through a foe, back through it again, and home
	pl.stats.apply_mods([["fork", "add", -1.0]])
	pl.stats.add_flag("proj_return")
	var r := _foe(st, Vector2(7, 7))
	_run(st, 0.8)
	var hits := [0]
	Events.damage_dealt.connect(func(t, _a, _c) -> void:
		if t == r:
			hits[0] += 1)
	var pr := _shot(pl, Vector2.RIGHT, 0.4, 1)
	_run(st, 1.5)
	eq(hits[0], 2, "struck on the way out and on the way home")
	check(not st.projectiles.has(pr), "the shot ends back at the Kindled")
	# turning back on a foe never strikes that foe twice at once
	hits[0] = 0
	_shot(pl, Vector2.RIGHT, 1.0, 0)
	_run(st, 1.5)
	eq(hits[0], 1, "a shot that turns on a foe does not hit it again at once")
	st.queue_free()


func test_new_spells() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	# Ember Rush: across the room in a streak, cutting what is in the way
	var a := _foe(st, Vector2(6, 7))
	var b := _foe(st, Vector2(8, 7.3))
	_run(st, 0.8)
	pl.aim = Vector2.RIGHT
	pl.aim_point = Vector2(10, 7)
	check(Abilities.cast(pl, "rush"), "Ember Rush cast")
	check(pl.pos.x > 9.0, "the Kindled rushed forward (x %.1f)" % pl.pos.x)
	check(a.hp < a.max_hp and b.hp < b.max_hp, "both foes in the path are cut")
	# a rush stops at a wall instead of passing it
	pl.pos = Vector2(18, 7)
	pl.aim_point = Vector2(26, 7)
	Abilities.cast(pl, "rush")
	check(pl.pos.x < 22.0 and not st.grid.box_blocked(pl.pos, pl.box()), "a rush stops at the wall")
	a.alive = false
	b.alive = false
	# Hearth Lantern: a planted light that feeds Kindle, shelters and shoots
	pl.pos = Vector2(5, 7)
	pl.aim = Vector2.RIGHT
	pl.aim_point = Vector2(7, 7)
	pl.kindle = 0.0
	check(Abilities.cast(pl, "lantern"), "Hearth Lantern cast")
	var lanterns := func() -> Array: return st.actors.filter(func(x): return x is LanternTotem and x.alive)
	eq(lanterns.call().size(), 1, "one lantern")
	var t := _foe(st, Vector2(11, 7))
	_run(st, 2.0)
	check(pl.kindle > 3.0, "its light feeds Kindle (%.1f)" % pl.kindle)
	check(pl.shelter_t > 0.0, "and shelters whoever stands in it")
	check(t.hp < t.max_hp, "it looses bolts at foes")
	Abilities.cast(pl, "lantern")
	_run(st, 0.1)
	eq(lanterns.call().size(), 1, "only one burns at once")
	pl.stats.add_flag("lanternwright")
	Abilities.cast(pl, "lantern")
	_run(st, 0.1)
	eq(lanterns.call().size(), 2, "Lanternwright: two at once")
	_run(st, 19.0)
	eq(lanterns.call().size(), 0, "they gutter out")
	t.alive = false
	st.queue_free()


func test_rekindle_raises_and_wards_the_party() -> void:
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(7, 1, "ossuary", false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]), null)
	var p1 := d.player
	var p2 := Player.new()
	p2.peer_id = 2
	p2.pos = p1.pos + Vector2(1.5, 0)
	d.add_actor(p2)
	p2.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]))
	var p3 := Player.new()
	p3.peer_id = 3
	p3.pos = p1.pos + Vector2(0, 1.2)
	d.add_actor(p3)
	p3.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]))
	p2._go_down()
	check(p2.downed, "a friend is down")
	check(Abilities.cast(p1, "rekindle"), "Rekindle cast")
	check(not p2.downed and p2.alive, "the fallen get back up")
	check(p3.barrier > 0.0 and p1.barrier > 0.0, "everyone standing in it is warded")
	d.queue_free()


func test_build_keystones() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	var e := _foe(st, Vector2(6.2, 7), 5000.0)
	_run(st, 0.8)
	var plain := func() -> float:
		var h := Hit.make(pl, 10.0, ["melee"])
		h.can_crit = false
		return pl.deal_hit(e, h).amount
	var base: float = plain.call()
	# Thousand Cuts: weaker blows, faster, and every third one throws a knife
	pl.stats.add_flag("thousand_cuts")
	var cut: float = plain.call()
	near(cut / base, 0.7, 0.02, "Thousand Cuts: 30% less per hit")
	var n0 := _mine(st).size()
	pl.cuts = 0
	for k in 3:
		var h := Hit.make(pl, 10.0, ["melee"])
		h.can_crit = false
		pl.deal_hit(e, h)
	check(_mine(st).size() > n0, "the third cut throws a knife")
	# Momentum: hits in quick succession speed the weapon up
	var st2 := _stage()
	var p2 := _player(st2, Vector2(5, 7))
	var e2 := _foe(st2, Vector2(6.2, 7), 5000.0)
	_run(st2, 0.8)
	p2.stats.add_flag("momentum")
	var s0 := p2.weapon.speed()
	for k in 5:
		var h := Hit.make(p2, 5.0, ["melee"])
		h.can_crit = false
		p2.deal_hit(e2, h)
	check(p2.weapon.speed() > s0 * 1.15, "Momentum: faster after a string of hits (%.2f -> %.2f)" % [s0, p2.weapon.speed()])
	_run(st2, 2.0)
	eq(p2.momentum, 0, "Momentum fades when the hits stop")
	# Spellblade: a spell charges the next three weapon hits
	p2.stats.add_flag("spellblade")
	var h0 := Hit.make(p2, 10.0, ["melee"])
	h0.can_crit = false
	var before: float = p2.deal_hit(e2, h0).amount
	p2.aim_point = e2.pos
	p2.kindle = 100.0
	Abilities.cast(p2, "flare")
	eq(p2.spellblade_n, 3, "a spell charges three blows")
	var h1 := Hit.make(p2, 10.0, ["melee"])
	h1.can_crit = false
	var charged: float = p2.deal_hit(e2, h1).amount
	check(charged > before * 1.3, "a charged blow lands harder (%.1f vs %.1f)" % [charged, before])
	eq(p2.spellblade_n, 2, "and spends a charge")
	# Last Light: Kindle takes the blow first
	p2.stats.add_flag("last_light")
	p2.kindle = 50.0
	var hp0 := p2.hp
	var blow := Hit.make(e2, 20.0, ["melee"])
	blow.can_crit = false
	p2.invuln_t = 0.0
	p2.take_enemy_hit(blow, e2)
	near(p2.hp, hp0, 0.01, "Last Light: health untouched")
	check(p2.kindle < 50.0, "the Kindle paid for it (%.1f)" % p2.kindle)
	# Retribution: blows taken come back out of the next Ward
	p2.stats.add_flag("retribution")
	p2.kindle = 0.0
	p2.invuln_t = 0.0
	var blow2 := Hit.make(e2, 30.0, ["melee"])
	blow2.can_crit = false
	p2.take_enemy_hit(blow2, e2)
	check(p2.retribution > 0.0, "Retribution stores the blow (%.1f)" % p2.retribution)
	var e_hp := e2.hp
	p2._retribute()
	check(e2.hp < e_hp, "and the Ward releases it")
	eq(p2.retribution, 0.0, "spent")
	st.queue_free()
	st2.queue_free()


func test_third_spell_slot() -> void:
	Profile.data = Profile.fresh()
	var s := Profile.slots()
	eq(s.size(), 3, "three spell slots")
	eq(String(s[0]), "flare", "Flare in the first")
	Profile.data.skills = ["hearth", "k3", "g4r"]
	Profile.set_slot(1, "wisp")
	Profile.set_slot(2, "gloamstep")
	eq(Profile.slots(), ["flare", "wisp", "gloamstep"], "spells set in all three")
	Profile.set_slot(0, "gloamstep")
	eq(Profile.slots(), ["gloamstep", "wisp", "flare"], "a spell sits in one slot only: taking it swaps")
	# an old two-slot save gains the third slot
	Profile.data.equipped["slots"] = ["flare", "wisp"]
	eq(Profile.slots().size(), 3, "old saves gain a third slot")
	# the third slot opens at level 5
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	pl.ability_slots = ["flare", "", "wisp"]
	pl.kindle = 100.0
	Profile.data.level = 1
	check(not pl.slot_open(2), "locked below level %d" % Player.THIRD_SLOT_LEVEL)
	pl._try_ability(2)
	eq(pl.ability_cd[2], 0.0, "a locked slot casts nothing")
	Profile.data.level = Player.THIRD_SLOT_LEVEL
	check(pl.slot_open(2), "open at level %d" % Player.THIRD_SLOT_LEVEL)
	pl._try_ability(2)
	check(pl.ability_cd[2] > 0.0, "the third slot casts")
	# another Kindled's lock follows their own level, not this machine's
	pl.sheet = {"level": 2}
	check(not pl.slot_open(2), "a friend's sheet decides their lock")
	st.queue_free()


func test_tree_layout_and_new_nodes() -> void:
	# nothing overlaps in the constellation: every node keeps its own space
	var ids := SkillDB.all_ids()
	var worst := 999.0
	var pair := ""
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var dd := SkillDB.position_of(ids[i]).distance_to(SkillDB.position_of(ids[j]))
			if dd < worst:
				worst = dd
				pair = "%s/%s" % [ids[i], ids[j]]
	check(worst >= 30.0, "closest nodes %s are %.1f apart" % [pair, worst])
	# every link names a real node, every spell node a real spell with an icon
	var icons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/icons.json")).icons
	for id in ids:
		var n := SkillDB.node(id)
		for l in n.get("links", []):
			check(not SkillDB.node(l).is_empty(), "%s links to a real node (%s)" % [id, l])
		if n.has("ability"):
			var a := GearDB.ability(String(n.ability))
			check(not a.is_empty(), "%s grants a real spell" % id)
			check(icons.has(String(a.get("icon", ""))), "%s's spell has an icon" % id)
		check(icons.has(SkillDB.icon_of(id)), "%s has an icon (%s)" % [id, SkillDB.icon_of(id)])
	# the build paths are reachable from the root
	for id in ["b8", "p8", "r_ret", "g_ric", "w8", "k8", "k_lw"]:
		var path := SkillDB.path_to(id, ["hearth"])
		check(not path.is_empty(), "%s can be reached" % id)


func test_coop_reward_share() -> void:
	near(Party.reward_share(1), 1.0, 0.0001, "solo is untouched")
	for n: int in [2, 3, 4]:
		# more foes come for a bigger party; each player's whole take grows a little
		var foes := 1.0 + Party.FOES_PER_EXTRA * (n - 1)
		near(foes * Party.reward_share(n), 1.0 + Party.BONUS_PER_EXTRA * (n - 1), 0.0001, "party of %d" % n)
		check(Party.reward_share(n) < 1.0, "each foe is worth less in a party of %d" % n)


## A party is pressed as a party: foes share themselves out instead of all
## falling on whoever stands nearest; a Kindled standing alone is sought out;
## extra foes for a party are flankers and marksmen, within the role caps.
func test_party_targeting_and_extras() -> void:
	Profile.data = Profile.fresh()
	var lay := DungeonGen.generate(7, 1, "ossuary", false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]), null)
	var ps: Array = [d.player]
	for k in 3:
		var p := Player.new()
		p.peer_id = k + 2
		p.pos = d.random_floor_near(d.player.pos + Vector2(1.2 * (k + 1), 0.0), 0.4)
		d.add_actor(p)
		p.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", "", ""]))
		ps.append(p)
	var foes: Array = []
	for k in 8:
		var e := d._make_enemy("husk")
		e.pos = d.random_floor_near(d.player.pos + Vector2(-2.5, 0.5 * k - 2.0), 0.5)
		d.add_actor(e)
		e.state = "idle"
		foes.append(e)
	for e in foes:
		e.target()
	var per := {}
	for e in foes:
		per[e._tgt] = int(per.get(e._tgt, 0)) + 1
	check(per.size() >= 3, "eight foes spread over at least three of four Kindled (%d)" % per.size())
	check(int(per.get(d.player, 0)) < 8, "the nearest Kindled is not the only target (%d on it)" % int(per.get(d.player, 0)))
	var extras := EnemyDB.party_extras(d.rng, "ossuary", 2, ["husk", "husk"], 6)
	eq(extras.size(), 6, "six extras")
	var roles := {}
	for id in extras:
		var r := String(EnemyDB.get_def(id).get("role", ""))
		roles[r] = int(roles.get(r, 0)) + 1
		check(not EnemyDB.get_def(id).has("pack"), "no pack summoners among the extras (%s)" % id)
	for r in roles:
		if EnemyDB.ROLE_CAP.has(r):
			check(int(roles[r]) <= int(EnemyDB.ROLE_CAP[r]), "role cap kept for %s" % r)
	d.queue_free()


func test_party_rewards_by_worth() -> void:
	# a wave's pay per Kindled follows what its own foes are worth, whatever
	# pricier flankers a party brings with it
	eq(Party.wave_share(10.0, 10.0, 1), 1.0, "alone: everything")
	check(absf(Party.wave_share(10.0, 20.0, 2) - 0.56) < 0.001, "two Kindled, foes worth twice as much: 0.56 each")
	check(absf(Party.wave_share(20.0, 40.0, 4) * 40.0 / 20.0 - 1.36) < 0.001, "four Kindled: 36% more each than alone")
	check(Party.PARTY_WAVE_SHARE < 0.5, "a big party's closing wave pays little")


func test_landmarks() -> void:
	DungeonGen.force_landmark = true
	var found := {}
	for region in ["ossuary", "rootmire", "throne"]:
		for s in [3, 11, 29]:
			var with := DungeonGen.generate(s, 2, region, false)
			DungeonGen.force_landmark = false
			var without := DungeonGen.generate(s, 2, region, false)
			DungeonGen.force_landmark = true
			var lr: Room = null
			for r in with.rooms:
				if r.landmark != "":
					lr = r
			if lr == null:
				continue
			found[region] = true
			eq(lr.landmark, String(DungeonGen.LANDMARKS[region].id), "the region's own landmark")
			eq(with.rooms.size(), without.rooms.size(), "the same floor around it (%s %d)" % [region, s])
			var same := true
			for r in with.rooms:
				if r != lr and (r.type != without.room(r.id).type or r.encounter != without.room(r.id).encounter):
					same = false
			check(same, "every other room is untouched (%s %d)" % [region, s])
			var lm: Array = lr.props.filter(func(pd): return pd.kind == "landmark")
			eq(lm.size(), 1, "one centrepiece")
			# its room still joins every door with every other around it
			var g := with.grid
			var c: Vector2i = lm[0].tile
			for dx in [-1, 0, 1]:
				for dy in [-1, 0]:
					check(g.at(c.x + dx, c.y + dy) == TileGrid.FLOOR, "it stands on open floor")
			var block := {}
			for dx in [-1, 0, 1]:
				for dy in [-1, 0]:
					block[c + Vector2i(dx, dy)] = true
			var doors: Array = []
			for d in lr.doors:
				if not d.secret:
					doors.append(d.tiles[0])
			var seen := {doors[0]: true}
			var stack: Array = [doors[0]]
			while not stack.is_empty():
				var t: Vector2i = stack.pop_back()
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = t + o
					if seen.has(n) or block.has(n) or g.room_at(n.x, n.y) != lr.id and not doors.has(n):
						continue
					if g.at(n.x, n.y) != TileGrid.FLOOR:
						continue
					seen[n] = true
					stack.append(n)
			for dt in doors:
				check(seen.has(dt), "every door of the landmark's room reachable past it (%s %d)" % [region, s])
	DungeonGen.force_landmark = false
	eq(found.size(), 3, "a landmark found in every region")
	# the Wonders feat counts the landmarks this Kindled has seen
	Profile.data = Profile.fresh()
	eq(Feats.progress("wonders"), 0, "none seen yet")
	Profile.note_seen("landmarks", "colossus")
	Profile.note_seen("landmarks", "colossus")
	Profile.note_seen("landmarks", "sundisc")
	eq(Feats.progress("wonders"), 2, "two different landmarks")


func test_hollow_cycles() -> void:
	# the first pass through the three regions is plain; after it, the next
	# region's foes bleed in and every pass is darker
	eq(Delve.cycle(9), 0, "depth 9 is the first pass")
	eq(Delve.cycle(10), 1, "depth 10 begins the second")
	eq(Delve.bleed_region(5), "", "no bleed on the first pass")
	eq(Delve.region_for(10), "ossuary", "the second pass starts in the Ossuary")
	eq(Delve.bleed_region(10), "rootmire", "where the Rootmire's dead walk")
	eq(Delve.bleed_region(25), "ossuary", "the Throne takes the Ossuary's")
	check(Delve.gloom(10) < Delve.gloom(9), "darker on the second pass")
	check(Delve.gloom(200) >= 0.55, "never black")
	check(String(Delve.depth_title("ossuary", 10, true)[1]).contains("Rootmire"), "the title card says who walks here")
