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
