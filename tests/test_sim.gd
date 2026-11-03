## Headless gameplay simulation: real actors, weapons and AI on a tiny map.
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
	pl.setup_from(RunState.create(1, "ossuary", "sword", 0, ["flare", ""]))
	return pl


func _enemy(st: Stage, id: String, p: Vector2) -> Enemy:
	var scr: GDScript = load(EnemyDB.get_def(id).script)
	var e: Enemy = scr.new()
	e.configure(id)
	e.pos = p
	st.add_actor(e)
	return e


func _run(st: Stage, seconds: float) -> void:
	var dt := 1.0 / 60.0
	var n := int(seconds / dt)
	for i in n:
		st.simulate(dt)
		st.fx.step(dt)


func test_husk_hunts_and_hits_player() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	var e := _enemy(st, "husk", Vector2(12, 7))
	_run(st, 6.0)
	check(e.pos.x < 11.0, "husk moved toward the player")
	check(pl.hp < pl.max_hp, "husk landed a hit (hp %d)" % int(pl.hp))
	st.queue_free()


func test_sword_combo_damages_and_kills() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	var e := _enemy(st, "husk", Vector2(6.4, 7))
	_run(st, 0.8)  # let it finish spawning
	pl.aim = Vector2.RIGHT
	var start_hp := e.hp
	for k in 12:
		pl.aim = (e.pos - pl.pos).normalized() if e.alive else Vector2.RIGHT
		pl.weapon.press()
		pl.weapon.release()
		_run(st, 0.35)
		if not e.alive:
			break
	check(e.hp < start_hp or not e.alive, "sword strikes connect")
	check(not e.alive, "repeated combos kill a husk")
	check(not st.actors.has(e), "dead enemy removed from the stage")
	check(pl.kindle > 0.0, "melee hits generate Kindle")
	st.queue_free()


func test_dodge_grants_invulnerability_and_perfect_dodge() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(8, 7))
	pl._start_dodge()
	var h := Hit.make(null, 50.0, ["melee"])
	var res := pl.take_enemy_hit(h, null)
	eq(res.amount, 0.0, "no damage while dodging")
	check(pl.perfect_done, "early dodge counts as perfect")
	check(pl.kindle > 0.0, "perfect dodge rewards Kindle")
	st.queue_free()


func test_ward_reflects_projectiles() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(8, 7))
	var e := _enemy(st, "archer", Vector2(16, 7))
	_run(st, 0.8)
	pl._start_ward()
	var pr := e.shoot("proj_arrow", Vector2.LEFT, 12.0, 10.0)
	pr.pos = Vector2(9.5, 7.0)
	_run(st, 0.2)
	check(pr.team == Actor.Team.PLAYER or not is_instance_valid(pr), "arrow turned around by the Ward")
	eq(pl.hp, pl.max_hp, "warded hit did no damage")
	st.queue_free()


func test_burn_ticks_kill() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	var e := _enemy(st, "skitter", Vector2(15, 7))
	_run(st, 0.8)
	e.status.apply_burn(3, 6.0, 3, pl)
	_run(st, 3.2)
	check(not e.alive, "burn damage over time kills a skitter")
	st.queue_free()


func test_projectile_stops_at_walls() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	_player(st, Vector2(4, 7))
	var pr := Projectile.create(st, "proj_ember", Vector2(10, 7), Vector2(0, -20), Actor.Team.PLAYER)
	_run(st, 0.5)
	check(not st.projectiles.has(pr), "projectile removed after hitting the wall")
	st.queue_free()


func test_bloat_blast_hurts_enemies_too() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	var b := _enemy(st, "bloat", Vector2(12, 7))
	var h := _enemy(st, "husk", Vector2(13, 7))
	_run(st, 0.8)
	var before := h.hp
	b.take_hit(Hit.make(pl, 999.0, ["melee"]))
	_run(st, 0.8)
	check(h.hp < before or not h.alive, "the bloat's blast damages nearby enemies")
	st.queue_free()


func test_warden_braziers_sear() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	var w: Enemy = _enemy(st, "warden", Vector2(12, 6))
	var bz: Array = []
	for t in [Vector2i(6, 4), Vector2i(18, 4), Vector2i(6, 10), Vector2i(18, 10)]:
		var p := Prop.make(st, "boss_brazier", t)
		p.data["boss"] = w
		bz.append(p)
	w.set("braziers", bz)
	w.set("intro", false)
	_run(st, 2.0)
	w.hp = w.max_hp * 0.5
	_run(st, 0.2)
	eq(w.get("phase"), 2, "Gloamfall below 55%")
	for b in bz:
		check(not b.lit, "braziers snuffed in phase 2")
	for b in bz:
		b.on_struck(pl)
	check(w.get("seared_t") > 0.0, "relighting all braziers sears the Warden")
	check(w.status.is_staggered(), "seared Warden is staggered")
	check(w.status.exposed_t > 0.0, "seared Warden is exposed")
	st.queue_free()


func test_interact_input_uses_nearest_prop() -> void:
	# a human pressing Interact (not just the bot) must reach props
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5.5, 7.5))
	var spring := Prop.make(st, "spring", Vector2i(6, 7))
	pl.hp = pl.max_hp * 0.5
	pl.input_enabled = true
	Input.action_press("interact")
	pl._process(1.0 / 60.0)
	Input.action_release("interact")
	check(spring.used, "pressing interact drinks from the nearby spring")
	check(pl.hp > pl.max_hp * 0.5, "the spring heals")
	var far := _player(st, Vector2(16.5, 7.5))
	check(far.try_interact() == null, "nothing to use far away")
	st.queue_free()


func test_resident_walks_between_spots() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	_player(st, Vector2(3.5, 3.5))
	var spots := [{"p": Vector2(5.5, 7.5), "pose": "sit", "tag": "bench", "by": null},
		{"p": Vector2(16.5, 7.5), "pose": "idle", "tag": "planters", "by": null}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var w := Wanderer.spawn(st, Residents.LIST[0], spots, rng)
	var start := w.pos
	w.wait = 0.0
	_run(st, 14.0)
	check(w.pos.distance_to(start) > 5.0, "walked to the other spot (%s -> %s)" % [start, w.pos])
	check(spots[w.spot].by == w, "claims the spot it stands on")
	check(not w.moving, "settled at the spot")
	eq(st.nearest_interactable(w.pos), w, "can be talked to")
	st.queue_free()


func test_footsteps_follow_the_run_cycle() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5.5, 7.5))
	pl.sprite.play("run_side", true)
	var heard := []
	for f in [0, 1, 2, 3, 4, 5, 0, 1]:
		var before := pl._foot_i
		pl.sprite.set_frame(f)
		pl._footsteps()
		if pl._foot_i != before:
			heard.append(f)
	eq(heard, [0, 3, 0], "a step lands on each foot-contact frame and nowhere else")
	pl.sprite.play("idle_side", true)
	var before2 := pl._foot_i
	pl._footsteps()
	eq(pl._foot_i, before2, "no steps while standing")
	st.queue_free()


## Walking turns the Kindled; attacking turns them to the aim (playtest bug:
## the sprite only ever faced the mouse, so walking away looked like moonwalking).
func test_walking_turns_the_kindled() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(10, 7))
	pl.aim = Vector2.RIGHT
	pl.move_in = Vector2.LEFT
	_run(st, 0.2)
	check(pl.facing.x < -0.7, "walking left faces left with the mouse to the right (%s)" % pl.facing)
	pl.move_in = Vector2.ZERO
	_run(st, 0.2)
	check(pl.facing.x < -0.7, "stopping keeps the last facing (%s)" % pl.facing)
	pl.aim = Vector2.UP
	_run(st, 0.1)
	check(pl.facing.y < -0.7, "moving the mouse while standing turns to it (%s)" % pl.facing)
	pl.aim = Vector2.RIGHT
	pl.move_in = Vector2.LEFT
	pl.weapon.press()
	_run(st, 0.05)
	check(pl.facing.x > 0.7, "attacking faces the aim even while walking away (%s)" % pl.facing)
	st.queue_free()


func test_hearthcall_channel() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(10, 7))
	check(pl.hearthcall_blocked() != "", "no Hearthcall outside the Undervault")
	# a hit breaks the call
	pl.hearthcall_t = 0.0
	var e := _enemy(st, "husk", Vector2(10.6, 7))
	pl.take_enemy_hit(e.make_hit(5.0, e.pos), e)
	check(pl.hearthcall_t < 0.0, "a hit breaks the Hearthcall")
	e.queue_free()
	st.actors.erase(e)
	# standing still for the whole channel completes it
	pl.hearthcall_t = 0.0
	_run(st, Player.HEARTHCALL_TIME + 0.2)
	check(pl.hearthcall_t < 0.0 and pl.invuln_t > 4.0, "the call completes after %.0f s" % Player.HEARTHCALL_TIME)
	st.queue_free()


## Every weapon's combo kills a husk, and its charged attack connects.
func test_every_weapon_combo_and_charge() -> void:
	for wid in GearDB.WEAPONS:
		Profile.data = Profile.fresh()
		var st := _stage()
		var pl := _player(st, Vector2(5, 7))
		pl.set_weapon(String(wid), 7)
		var e := _enemy(st, "husk", Vector2(6.6, 7))
		_run(st, 0.8)
		var start_hp := e.hp
		for k in 20:
			pl.aim = (e.pos - pl.pos).normalized() if e.alive else Vector2.RIGHT
			pl.weapon.press()
			pl.weapon.release()
			_run(st, 0.35)
			if not e.alive:
				break
		check(not e.alive, "%s: combos kill a husk (hp %d/%d)" % [wid, int(e.hp), int(start_hp)])
		# charged attack: hold past the charge time, then release toward a fresh husk
		var e2 := _enemy(st, "husk", pl.pos + Vector2(2.2, 0))
		_run(st, 0.8)
		var hp2 := e2.hp
		pl.aim = (e2.pos - pl.pos).normalized()
		pl.weapon.press()
		_run(st, 1.2)
		pl.weapon.release()
		_run(st, 1.2)
		check(e2.hp < hp2 or not e2.alive, "%s: the charged attack connects" % wid)
		st.queue_free()


func test_forge_levels_and_costs() -> void:
	Profile.data = Profile.fresh()
	check(not Profile.forge_cost("sword").is_empty(), "the forge has a next level")
	Profile.data.weapons.sword.level = GearDB.FORGE_MAX
	check(Profile.forge_cost("sword").is_empty(), "nothing past +%d" % GearDB.FORGE_MAX)
	Profile.data.weapons.sword.level = 4
	var c := Profile.forge_cost("sword")
	check(c.has("embers") and c.size() > 1, "higher levels ask for materials too (%s)" % c)
	for wid in GearDB.WEAPONS:
		check(GearDB.FORGE_SIGNATURES.has(wid) and GearDB.FORGE_MASTERWORK.has(wid), "%s has both forge upgrades" % wid)


func _wear(pl: Player, base: String) -> void:
	var it := ItemDB.make_item(base, "legendary", 1, RandomNumberGenerator.new())
	Profile.equipped()[ItemDB.base(base).slot] = it
	pl.rebuild_stats()


func test_new_uniques_work() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(8, 7))
	var e := _enemy(st, "husk", Vector2(9.2, 7))
	_run(st, 0.8)
	# Thornmail: being hit bursts thorns into what stands close
	_wear(pl, "thornmail")
	var hp0 := e.hp
	pl.invuln_t = 0.0
	pl.take_enemy_hit(e.make_hit(10.0, e.pos), e)
	check(e.hp < hp0, "Thornmail's thorns hurt the attacker (%d -> %d)" % [int(hp0), int(e.hp)])
	# Mirrorguard: a Ward throws the blow back
	_wear(pl, "mirrorguard_bracers")
	var hp1 := e.hp
	pl._on_ward(e, false)
	check(e.hp < hp1, "Mirrorguard throws a warded blow back")
	# Executioner: low foes always take crits
	_wear(pl, "executioners_band")
	var e3 := _enemy(st, "guard", Vector2(9.2, 8.5))
	_run(st, 0.8)
	e3.hp = e3.max_hp * 0.2
	var h := Hit.make(pl, 1.0, ["melee"])
	var res := pl.deal_hit(e3, h)
	check(res.crit, "the Executioner's Band crits a foe under a quarter health")
	for b in ItemDB.blueprints():
		check(UIKit.item_icon(String(ItemDB.base(b).icon)) != null, "%s has an icon" % b)
	st.queue_free()


func test_gravemole_burrows_and_erupts() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	var m := _enemy(st, "gravemole", Vector2(12, 7))
	_run(st, 1.0)
	check(m.state == "under" and not st.hostiles(Actor.Team.PLAYER).has(m), "the Gravemole digs under and can't be targeted")
	_run(st, 5.0)
	check(pl.hp < pl.max_hp, "the Gravemole erupts under the Kindled (hp %d)" % int(pl.hp))
	st.queue_free()


func test_lampwight_binds_and_unbinds() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	var h := _enemy(st, "husk", Vector2(14, 7))
	var w := _enemy(st, "lampwight", Vector2(17, 7))
	_run(st, 2.5)
	check(h.shield_max > 0.0 and h.shield > 0.0, "the Lampwight shields an ally (%d)" % int(h.shield))
	w.take_hit(Hit.make(pl, 999.0, ["melee"]))
	_run(st, 0.2)
	check(h.shield_max == 0.0, "killing the Lampwight takes the shield away")
	st.queue_free()


func test_spore_mortar_lobs_bombs() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	var m := _enemy(st, "spore_mortar", Vector2(14, 7))
	var start := m.pos
	_run(st, 5.0)
	check(m.pos.distance_to(start) < 0.05, "the Mortar stays rooted")
	check(pl.hp < pl.max_hp, "a spore bomb lands on a Kindled who stands still (hp %d)" % int(pl.hp))
	st.queue_free()


func test_bramblewright_grows_a_wall_that_withers() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	var b := _enemy(st, "bramblewright", Vector2(11, 7))
	b.grow_cd = 0.0
	_run(st, 3.0)
	var grown := st.props.filter(func(p): return p.kind == "bramble" and p.data.get("grown", false))
	check(grown.size() >= 3, "the Bramblewright grows a wall (%d)" % grown.size())
	var solid := 0
	for p in grown:
		if st.grid.at(p.tile.x, p.tile.y) == TileGrid.PROP:
			solid += 1
	check(solid == grown.size(), "the brambles block the floor")
	b.grow_cd = 99.0
	_run(st, 12.0)
	var left := st.props.filter(func(p): return is_instance_valid(p) and p.kind == "bramble" and p.data.get("grown", false))
	check(left.is_empty(), "grown brambles wither")
	check(st.grid.at(grown[0].tile.x, grown[0].tile.y) == TileGrid.FLOOR if not grown.is_empty() else true, "the floor comes back")
	st.queue_free()


func test_duelist_ripostes_blades() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(8, 7))
	var d := _enemy(st, "duelist", Vector2(9.6, 7))
	_run(st, 0.8)
	d.set_state("stance")
	var hp0 := d.hp
	pl.deal_hit(d, Hit.make(pl, 20.0, ["melee"]))
	check(d.hp == hp0 and d.state == "riposte", "a blade in the stance is turned aside")
	_run(st, 0.4)
	check(pl.hp < pl.max_hp, "the riposte cuts back (hp %d)" % int(pl.hp))
	d.set_state("stance")
	pl.deal_hit(d, Hit.make(pl, 20.0, ["ability", "fire"]))
	check(d.hp < hp0, "a spell still lands in the stance")
	st.queue_free()


func test_sunwatcher_sweeps_a_beam() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(6, 7))
	var s := _enemy(st, "sunwatcher", Vector2(13, 7))
	s.cooldown = 0.0
	_run(st, 4.0)
	check(pl.hp < pl.max_hp, "the Sunwatcher's beam burns a Kindled who stands in it (hp %d)" % int(pl.hp))
	st.queue_free()


func test_behavioural_affixes() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(4, 7))
	# Molten leaves burning ground where it walks
	var m := _enemy(st, "husk", Vector2(14, 7))
	m.make_elite("molten")
	_run(st, 2.5)
	check(st.hazards.size() >= 3, "a Molten elite leaves a burning trail (%d)" % st.hazards.size())
	m.take_hit(Hit.make(pl, 9999.0, ["melee"]))
	# Splitting: two lesser copies climb out
	var s := _enemy(st, "husk", Vector2(12, 9))
	s.make_elite("splitting")
	_run(st, 0.8)
	var n0 := st.actors.filter(func(a): return a is Enemy and a.alive).size()
	s.take_hit(Hit.make(pl, 9999.0, ["melee"]))
	_run(st, 0.4)
	var kids := st.actors.filter(func(a): return a is Enemy and a.alive and a.summoned)
	check(kids.size() == 2, "a Splitting elite splits in two (%d)" % kids.size())
	check(st.actors.filter(func(a): return a is Enemy and a.alive).size() == n0 + 1, "the elite itself is gone")
	for k in kids:
		k.take_hit(Hit.make(pl, 9999.0, ["melee"]))
	_run(st, 0.4)
	check(st.actors.filter(func(a): return a is Enemy and a.alive and a.summoned).is_empty(), "the copies do not split again")
	# Gloom: near it Kindle comes at half the rate
	var g := _enemy(st, "guard", Vector2(5.5, 7))
	g.make_elite("gloom")
	_run(st, 0.9)
	pl.kindle = 0.0
	pl.gain_kindle(10.0)
	var gloomed := pl.kindle
	g.pos = Vector2(20, 11)
	_run(st, 0.5)
	pl.kindle = 0.0
	pl.gain_kindle(10.0)
	check(gloomed > 0.0 and absf(gloomed * 2.0 - pl.kindle) < 0.01, "Gloom halves Kindle gain (%.1f vs %.1f)" % [gloomed, pl.kindle])
	check(not EnemyDB.affix_ok("spore_mortar", "molten") and not EnemyDB.affix_ok("gravemole", "phasing"), "affixes only go where they work")
	st.queue_free()


## A real Dungeon floor, simulated without a view (for whole-floor tests).
func _dungeon(seed_v: int, region := "ossuary") -> Dungeon:
	var lay := DungeonGen.generate(seed_v, 1, region, false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(seed_v, region, "sword", 0, ["flare", ""]), null)
	return d


func test_room_seals_block_and_release() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var room: Room = null
	for r in d.layout.rooms:
		if r.is_combat() and r.type != Room.Type.BOSS and not d.gate_nodes.get(r.id, []).is_empty():
			room = r
			break
	check(room != null, "a combat room with seals")
	var g: Node = d.gate_nodes[room.id][0]
	var t: Vector2i = g.get_meta("tile")
	# someone standing in the doorway when it seals
	var e := d._make_enemy("husk")
	e.pos = Vector2(t) + Vector2(0.5, 0.5)
	d.add_actor(e)
	d.player.pos = Vector2(t) + Vector2(0.5, 0.5)
	d._set_gates(room, true)
	eq(d.grid.at(t.x, t.y), TileGrid.GATE, "the seal's tile is a gate")
	check(d.grid.blocks_shot(t.x, t.y), "shots stop at the seal")
	check(g.visible, "the seal shows")
	check(not d.grid.box_blocked(d.player.pos, d.player.box()) and room.contains_tile(Vector2i(floori(d.player.pos.x), floori(d.player.pos.y))), "the Kindled is stepped into the room, not trapped")
	check(not d.grid.box_blocked(e.pos, e.box()), "so is a foe in the doorway")
	for i in 20:
		g._process(0.05)   # sprites animate on the frame clock, not the stage's
	eq(String(g.anim), "closed", "it settles into its shimmer")
	d._set_gates(room, false)
	eq(d.grid.at(t.x, t.y), TileGrid.FLOOR, "released, the doorway is floor again")
	for i in 20:
		g._process(0.05)
	check(not g.visible, "and the seal is gone")
	d.queue_free()


func test_coop_downed_revive_and_wipe() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p1 := d.player
	var p2 := Player.new()
	p2.peer_id = 2
	p2.pos = p1.pos + Vector2(1.0, 0)
	d.add_actor(p2)
	p2.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", ""]))
	eq(d.players.size(), 2, "two Kindled on the floor")
	# a husk picks the nearest Kindled
	var e := d._make_enemy("husk")
	e.pos = p2.pos + Vector2(2.0, 0)
	d.add_actor(e)
	check(e.target() == p2, "foes go for the nearest Kindled")
	# p2 falls: downed, not dead, and no longer a target
	var h := Hit.make(e, 9999.0, ["melee"])
	h.can_crit = false
	p2.take_enemy_hit(h, e)
	check(p2.downed and p2.alive, "at 0 health with a friend near, a Kindled is downed")
	check(not d.active_players().has(p2), "the downed are not targets")
	check(e.target() == p1 or e._tgt_t > 0.0, "the foe turns elsewhere")
	# p1 stands beside them: revived after the revive time
	p1.pos = p2.pos + Vector2(0.6, 0)
	e.alive = false
	_run(d, Player.REVIVE_TIME + 0.4)
	check(not p2.downed and p2.alive and p2.hp > 0.0, "standing beside them brings them back (hp %d)" % int(p2.hp))
	# both down: the party has fallen
	p1.take_enemy_hit(h, null)
	p1.invuln_t = 0.0
	p2.invuln_t = 0.0
	p2.take_enemy_hit(h, null)
	_run(d, 0.2)
	check(d._death_t > 0.0, "everyone down ends the run")
	d.queue_free()


func test_coop_shared_pickups() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p1 := d.player
	var p2 := Player.new()
	p2.peer_id = 2
	p2.controller = Player.Ctrl.REMOTE
	p2.pos = p1.pos + Vector2(3.0, 0)
	d.add_actor(p2)
	p2.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", ""]))
	var e1 := p1.run.embers
	var e2 := p2.run.embers
	var pk := Pickup.spawn(d, "ember", p1.pos, 10)
	pk._collect(p1)
	check(p1.run.embers > e1 and p2.run.embers > e2, "Embers picked up by one Kindled are credited to both")
	var g := Pickup.spawn(d, "gear", p1.pos, 1, {"item": ItemDB.make_item("grave_iron_helm", "rare", 1, RandomNumberGenerator.new(), 1)})
	g.owner_peer = 2
	check(g._owner() == p2, "an instanced find knows its owner")
	g._collect(p2)
	eq((p2.run.loot.gear as Array).size(), 1, "the owner gets their gear")
	eq((p1.run.loot.gear as Array).size(), 0, "and nobody else does")
	d.queue_free()


func test_ember_runes() -> void:
	Profile.data = Profile.fresh()
	for r in Runes.RUNES:
		Profile.add_rune(r)
	# sockets: one, a second at level 20; a rune sits in one place at a time
	check(Profile.set_rune("cinder_lance", 0, "split"), "a rune goes into a socket")
	check(not Profile.set_rune("cinder_lance", 1, "chain"), "no second socket before level %d" % Runes.SECOND_SOCKET_LEVEL)
	check(not Profile.set_rune("flare", 0, "split"), "one Rune of Many cannot sit in two spells")
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	pl.ability_slots = ["cinder_lance", "flare"]
	pl.kindle = 100.0
	var before := st.projectiles.size()
	pl._try_ability(0)
	eq(st.projectiles.size() - before, 3, "a Lance with the Rune of Many fans into three")
	_run(st, 1.0)    # let the lances finish their flight
	# Arcing: a spell hit leaps to the next foe
	Profile.set_rune("flare", 0, "chain")
	var a := _enemy(st, "husk", Vector2(6.5, 7))
	var b := _enemy(st, "husk", Vector2(9.0, 7))
	_run(st, 0.8)
	var hp_b := b.hp
	pl.kindle = 100.0
	pl._try_ability(1)
	check(b.hp < hp_b, "the Rune of Arcing reaches a foe outside the flare (%d -> %d)" % [int(hp_b), int(b.hp)])
	# Rime: the flare chills instead of burning
	Profile.set_rune("flare", 0, "rime")
	var g := _enemy(st, "guard", Vector2(4.0, 6.0))
	_run(st, 0.8)
	pl.ability_cd = [0.0, 0.0]
	pl.kindle = 100.0
	pl._try_ability(1)
	check(g.status.chill > 0.0 and not g.status.burning(), "a Rime Flare chills, not burns")
	g.alive = false
	st.remove_actor(g)
	# Ruin: a spell kill bursts onto its neighbours
	Profile.set_rune("flare", 0, "volatile")
	var c := _enemy(st, "husk", Vector2(5.6, 8.6))
	var d := _enemy(st, "husk", Vector2(6.4, 9.6))
	_run(st, 0.8)
	c.hp = 1.0
	var hp_d := d.hp
	pl.ability_cd = [0.0, 0.0]
	pl.kindle = 100.0
	pl.pos = Vector2(5, 8.5)
	pl._try_ability(1)
	check(not c.alive and d.hp < hp_d, "the Rune of Ruin's burst hits the next foe")
	# Haste and Might trade cooldown, damage and cost
	Profile.set_rune("flare", 0, "haste")
	check(Runes.cooldown_mult(pl, "flare") < 1.0 and Runes.damage_mult(pl, "flare") < 1.0, "Haste: shorter cooldown, less damage")
	Profile.set_rune("flare", 0, "might")
	check(Runes.cost_mult(pl, "flare") > 1.0 and Runes.damage_mult(pl, "flare") > 1.0, "Might: more damage, more Kindle")
	# Echoes: the flare happens again
	Profile.set_rune("flare", 0, "echo")
	var e := _enemy(st, "guard", Vector2(6.0, 7.0))
	_run(st, 0.8)
	pl.ability_cd = [0.0, 0.0]
	pl.kindle = 100.0
	pl.pos = Vector2(5, 7)
	var hp0 := e.hp
	pl._try_ability(1)
	var hp1 := e.hp
	_run(st, 0.8)
	check(e.hp < hp1 and hp1 < hp0, "the Rune of Echoes flares a second time")
	st.queue_free()
	# an old save gains its rune pouch
	var old := Profile.fresh()
	old.version = 8
	old.erase("runes")
	var m := Profile.migrate(old)
	check(m.has("runes") and (m.runes as Dictionary).has("socketed"), "v8 saves gain runes")


func test_bow_and_tome() -> void:
	Profile.data = Profile.fresh()
	var st := _stage()
	var pl := _player(st, Vector2(5, 7))
	# a Steady Shot released on the draw's peak always crits
	pl.set_weapon("bow", 0)
	var e := _enemy(st, "husk", Vector2(9, 7))
	e.speed = 0.0     # a still target
	_run(st, 0.8)
	var crits := [0]
	Events.damage_dealt.connect(func(_t, _a, crit) -> void:
		if crit:
			crits[0] += 1)
	pl.aim = Vector2.RIGHT
	pl.weapon.press()
	_run(st, 0.75)        # draw peaks at 0.6 s; let go inside the window
	pl.weapon.release()
	_run(st, 0.5)
	check(crits[0] >= 1, "a perfectly timed Steady Shot crits")
	# the Tome: words that land hurry the spells; a spell writes its element
	pl.set_weapon("tome", 0)
	var t2 := _enemy(st, "husk", Vector2(8, 7))
	t2.speed = 0.0
	t2.max_hp = 900.0
	t2.hp = 900.0
	_run(st, 0.8)
	pl.aim = Vector2.RIGHT
	pl.ability_slots = ["flare", ""]
	pl.ability_cd = [3.0, 0.0]
	pl.weapon.press()
	_run(st, 1.2)
	pl.weapon.release()
	check(pl.ability_cd[0] < 3.0 - 1.2 - 0.1, "Tome hits shorten cooldowns (%.2f)" % pl.ability_cd[0])
	pl.ability_cd = [0.0, 0.0]
	pl.kindle = 100.0
	pl._try_ability(0)
	eq(String(pl.weapon.inscribed), "fire", "casting Flare writes fire into the Tome")
	check(int(pl.weapon.inscribed_n) > 0, "for the next motes")
	st.queue_free()
