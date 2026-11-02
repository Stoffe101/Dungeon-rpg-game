## One floor (depth) of an expedition: builds the generated layout and runs
## rooms - encounters, gates, rewards, secrets, Grudges and the boss arena.
class_name Dungeon
extends Stage

signal minimap_changed

const REWARD_ICONS := {
	"relic": "relic", "embers": "embers", "vigor": "vigor", "memory": "memory", "sunshard": "sunshard",
	"treasure": "chest", "shrine": "shrine", "merchant": "merchant", "elite": "skull", "stairs": "stairs",
	"boss": "boss", "rest": "vigor", "secret": "chest",
}

var layout: DungeonGen.Layout
var run: RunState
var region: Dictionary
var current_room: Room
var active_room: Room
var wave := 0
var room_enemies: Array = []
var gate_nodes: Dictionary = {}     # room id -> Array[Node3D]
var door_icons: Array = []          # [{node, to}]
var boss: Enemy
var grudge_room := -1
var grudge_spawned := false
var env: Environment
var _clear_t := -1.0
var _clear_room: Room
var _death_t := -1.0
var _killer_id := ""
var _enter_t := 0.0


func build(lay: DungeonGen.Layout, r: RunState, v: PixelView) -> void:
	layout = lay
	run = r
	region = EnemyDB.REGIONS[lay.region]
	setup(lay.grid, v)
	rng.seed = lay.seed * 31 + lay.depth
	var theme := LevelBuilder.LevelTheme.named(region.theme)
	add_child(LevelBuilder.build(grid, theme))
	_environment()
	_place_props()
	_place_gates()
	_place_door_icons()
	_pick_grudge_room()
	# the player
	var start := layout.room(layout.start_id)
	player = Player.new()
	player.pos = start.center() + Vector2(0, 2)
	add_actor(player)
	player.setup_from(run)
	if "autopilot" in OS.get_cmdline_user_args():
		player.add_child(Bot.new())
	view.focus = Iso.to_world(player.pos)
	_enter_room(start)
	Events.player_died.connect(_on_player_died)
	actor_died.connect(_on_actor_died)
	Audio.play_music(region.music)
	Audio.play_ambience("amb_crypt")
	var title: String = region.name
	Events.banner.emit(title, "Depth %d%s" % [lay.depth, "  -  the Warden waits below" if lay.boss_depth else ""])


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.014, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = region.ambient
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	view.set_environment(env)


func _place_props() -> void:
	var flame: Color = region.flame
	for r in layout.rooms:
		for pd in r.props:
			var extra := {"flame": flame}
			if pd.has("variant"):
				extra["variant"] = pd.variant
			if pd.kind == "chest":
				extra["tier"] = pd.get("tier", 1)
			var p := Prop.make(self, pd.kind, pd.tile, extra)
			p.room_id = r.id
		# secret entrances: a cracked wall on the visible side
		for d in r.doors:
			if d.secret and r.type != Room.Type.SECRET:
				var tiles: Array = d.tiles
				var c := Vector2.ZERO
				for t: Vector2i in tiles:
					c += Vector2(t) + Vector2(0.5, 0.5)
				c /= tiles.size()
				var cw := Prop.make(self, "cracked_wall", tiles[0], {"center": c + Vector2(0, 0.5), "door": d, "room": r.id})
				cw.room_id = r.id


func _place_gates() -> void:
	for r in layout.rooms:
		if not r.is_combat():
			continue
		var nodes: Array = []
		for d in r.doors:
			if d.secret:
				continue
			for t: Vector2i in d.tiles:
				var g := PixelSprite.new()
				add_child(g)
				g.setup("gate", "closed")
				g.position = Iso.to_world(Vector2(t) + Vector2(0.5, 0.5 if d.dir.y == 0 else (0.95 if d.dir.y < 0 else 0.15)), 0.0)
				g.visible = false
				g.set_meta("tile", t)
				nodes.append(g)
		gate_nodes[r.id] = nodes


func _place_door_icons() -> void:
	for r in layout.rooms:
		for d in r.doors:
			if d.secret:
				continue
			var target := layout.room(d.to)
			var key := _icon_key(target)
			if key == "":
				continue
			var tiles: Array = d.tiles
			var c := Vector2.ZERO
			for t: Vector2i in tiles:
				c += Vector2(t) + Vector2(0.5, 0.5)
			c /= tiles.size()
			var icon := PixelSprite.new()
			add_child(icon)
			icon.setup("icons_reward", key)
			icon.material_override = null
			SpriteLib.get_sheet("icons_reward").material.set_shader_parameter("unshaded_sprite", true)
			icon.position = Iso.to_world(c - Vector2(d.dir) * 0.6, 2.4 if d.dir.y >= 0 else 1.9)
			icon.visible = false
			door_icons.append({"node": icon, "to": d.to, "from": r.id})


func _icon_key(r: Room) -> String:
	match r.type:
		Room.Type.COMBAT:
			return REWARD_ICONS.get(r.reward, "")
		Room.Type.ELITE:
			return "skull"
		Room.Type.TREASURE:
			return "chest"
		Room.Type.SHRINE:
			return "shrine"
		Room.Type.MERCHANT:
			return "merchant"
		Room.Type.REST:
			return "vigor"
		Room.Type.STAIRS:
			return "stairs"
		Room.Type.BOSS:
			return "boss"
	return ""


func _pick_grudge_room() -> void:
	var gs := Profile.active_grudges().filter(func(g): return int(g.get("depth", 1)) == layout.depth or (layout.depth == 2 and int(g.get("depth", 1)) > 2))
	if gs.is_empty():
		return
	var cands: Array = []
	for r in layout.rooms:
		if r.type == Room.Type.COMBAT and r.id != layout.start_id:
			cands.append(r.id)
	if cands.is_empty():
		return
	grudge_room = cands[rng.randi_range(0, cands.size() - 1)]
	layout.room(grudge_room).grudge = true


# --- per-frame -----------------------------------------------------------------------

func _stage_tick(dt: float) -> void:
	if player == null or not player.alive:
		return
	run.elapsed += dt
	var t := Vector2i(floori(player.pos.x), floori(player.pos.y))
	var r := layout.room_at_tile(t)
	if r and r != current_room:
		_enter_room(r)
	if current_room and not current_room.cleared and current_room.is_combat() and active_room == null:
		# start once the player is properly inside (not on the threshold)
		var inner := current_room.rect.grow(-1)
		if inner.has_point(t):
			_enter_t += dt
			if _enter_t > 0.05:
				_start_encounter(current_room)
	if active_room:
		_update_encounter(dt)
	if _clear_t >= 0.0:
		_clear_t -= dt
		if _clear_t < 0.0:
			_finish_clear()


func _stage_process(real: float) -> void:
	if _death_t >= 0.0:
		_death_t -= real
		if _death_t < 0.0:
			Game.end_run("died", _killer_id)
		return
	for ic in door_icons:
		var target := layout.room(ic.to)
		var node: PixelSprite = ic.node
		var show: bool = not target.visited and current_room != null and (ic.from == current_room.id) and (current_room.cleared or not current_room.is_combat())
		node.visible = show
		if show:
			var base: Vector3 = node.get_meta("base", node.position)
			node.set_meta("base", base)
			node.position = base + Vector3(0, roundf(sin(elapsed * 3.0 + base.x) * 1.5) / 16.0, 0)


func _enter_room(r: Room) -> void:
	current_room = r
	_enter_t = 0.0
	if not r.visited:
		r.visited = true
		run.seen_rooms += 1
		Events.room_entered.emit(r.id)
		if r.type == Room.Type.SECRET:
			Events.banner.emit("Hidden Chamber", "The Undervault forgot this place")
		elif r.type == Room.Type.SHRINE:
			Events.toast.emit("A shrine hums with cursed power.", Color(0.8, 0.6, 1.0))
		elif r.type == Room.Type.MERCHANT:
			Events.toast.emit("\"Embers for wares, wanderer?\"", Color(1.0, 0.8, 0.5))
		elif r.type == Room.Type.STAIRS:
			Events.toast.emit("Stairs descend into the dark. The Hearthstone can carry you home.", Color(1.0, 0.8, 0.55))
	if not r.is_combat():
		r.cleared = true
	minimap_changed.emit()
	# only lights near the player need shadows
	for p in props:
		if is_instance_valid(p) and p.light and p.kind in ["brazier", "boss_brazier", "torch"]:
			p.light.shadow_enabled = p.room_id == r.id and p.kind != "torch"


# --- encounters ------------------------------------------------------------------------

func _start_encounter(r: Room) -> void:
	if OS.is_debug_build():
		print("[dungeon] encounter start room %d (%s) waves=%d" % [r.id, r.type_name(), r.encounter.size()])
	active_room = r
	wave = 0
	_set_gates(r, true)
	Audio.play("gate_close", 0.0)
	if r.type == Room.Type.BOSS:
		_start_boss(r)
		return
	_spawn_wave(r)
	if r.grudge and not grudge_spawned:
		_spawn_grudge(r)


func _spawn_wave(r: Room) -> void:
	var ids: Array = r.encounter[wave] if wave < r.encounter.size() else []
	var spots := r.spawns.duplicate()
	spots.shuffle()
	var far: Array = spots.filter(func(t): return (Vector2(t) + Vector2(0.5, 0.5)).distance_to(player.pos) > 4.5)
	if far.size() >= ids.size():
		spots = far
	var elite_done := false
	var memory := int(Profile.data.world.get("memory", 0))
	for i in ids.size():
		var id: String = ids[i]
		var t: Vector2i = spots[i % spots.size()] if not spots.is_empty() else Vector2i(r.center())
		var e := _make_enemy(id)
		e.pos = Vector2(t) + Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7))
		e.scale_for(layout.depth, memory)
		if r.type == Room.Type.ELITE and not elite_done and id != "skitter":
			e.make_elite(r.elite_affix)
			elite_done = true
		elif r.elite_affix == "" and rng.randf() < 0.04 * layout.depth and id != "skitter":
			e.make_elite(EnemyDB.AFFIXES.keys()[rng.randi_range(0, EnemyDB.AFFIXES.size() - 1)])
		e.room_id = r.id
		e.spawn_t = 0.6 + i * 0.08
		add_actor(e)
		register_enemy(e)
		fx.shape(Fx.Shape.SIGIL, e.pos, Vector2.RIGHT, Vector2(1.6, 1.6), Color(0.3, 0.95, 0.85, 0.35), Color(0.5, 1.0, 0.9, 1.0), e.spawn_t + 0.1, {"glow": 1.5})
		Profile.note_seen("enemies", id)
	if not ids.is_empty():
		Audio.play("spawn", -2.0)


func _make_enemy(id: String) -> Enemy:
	var def := EnemyDB.get_def(id)
	var scr: GDScript = load(def.script)
	var e: Enemy = scr.new()
	e.configure(id)
	return e


func register_enemy(e: Enemy) -> void:
	room_enemies.append(e)


func _spawn_grudge(r: Room) -> void:
	var gs := Profile.active_grudges()
	if gs.is_empty():
		return
	var g: Dictionary = gs[0]
	grudge_spawned = true
	var e := _make_enemy(g.enemy)
	var t: Vector2i = r.spawns[rng.randi_range(0, r.spawns.size() - 1)] if not r.spawns.is_empty() else Vector2i(r.center())
	e.pos = Vector2(t) + Vector2(0.5, 0.5)
	e.scale_for(layout.depth, int(Profile.data.world.get("memory", 0)))
	e.make_grudge(g)
	e.room_id = r.id
	e.spawn_t = 1.2
	e.set_meta("grudge_id", g.id)
	e.set_meta("grudge_embers", int(g.embers))
	add_actor(e)
	register_enemy(e)
	Events.banner.emit(String(g.name), "Your Grudge has found you. It carries %d of your Embers." % int(g.embers))
	Audio.play("boss_roar", -6.0, 1.3)


func _update_encounter(_dt: float) -> void:
	room_enemies = room_enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	if room_enemies.is_empty() and active_room.type != Room.Type.BOSS:
		wave += 1
		if wave < active_room.encounter.size():
			_spawn_wave(active_room)
		else:
			_room_cleared()


func _room_cleared() -> void:
	var r := active_room
	if OS.is_debug_build():
		print("[dungeon] room %d cleared" % r.id)
	active_room = null
	r.cleared = true
	run.rooms_cleared += 1
	_clear_t = 0.6
	_clear_room = r
	Events.room_cleared.emit(r.id)
	minimap_changed.emit()
	slow_motion(0.4, 0.25)
	Audio.play("room_clear", 0.0)


func _finish_clear() -> void:
	var r := _clear_room
	_clear_room = null
	if OS.is_debug_build():
		print("[dungeon] gates open room %s" % (str(r.id) if r else "null"))
	if r == null:
		return
	_set_gates(r, false)
	Audio.play("gate_open", 0.0)
	for pk in pickups:
		pk.magnet = true
	var xpv := 6 + 3 * layout.depth
	run.xp_gained += xpv
	Profile.add_xp(xpv)
	_spawn_reward(r)


func _spawn_reward(r: Room) -> void:
	var c := _open_spot(r.center())
	match r.reward:
		"relic":
			Prop.make(self, "relic_altar", Vector2i(c), {"tier": 1})
		"embers":
			for i in 8 + layout.depth * 3:
				Pickup.spawn(self, "ember", c, 2)
		"vigor":
			Prop.make(self, "spring", Vector2i(c))
		"memory":
			for i in 6:
				Pickup.spawn(self, "xp", c, 5 + layout.depth * 2)
		"sunshard":
			Pickup.spawn(self, "sunshard", c, 1)
			Prop.make(self, "relic_altar", Vector2i(c) + Vector2i(0, -2), {"tier": 2})
			for i in 6:
				Pickup.spawn(self, "ember", c, 3)


func _open_spot(p: Vector2) -> Vector2:
	var t := Vector2i(floori(p.x), floori(p.y))
	for rad in 4:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := t + Vector2i(dx, dy)
				if grid.at(q.x, q.y) == TileGrid.FLOOR and grid.at(q.x, q.y - 1) == TileGrid.FLOOR and grid.at(q.x, q.y + 1) == TileGrid.FLOOR:
					return Vector2(q) + Vector2(0.5, 0.5)
	return p


func _set_gates(r: Room, closed: bool) -> void:
	for g in gate_nodes.get(r.id, []):
		var t: Vector2i = g.get_meta("tile")
		grid.put(t.x, t.y, TileGrid.GATE if closed else TileGrid.FLOOR)
		set_tile_solid(t, closed)
		g.visible = true
		g.play("rise" if closed else "fall", true)
		if not closed:
			var gg: PixelSprite = g
			gg.animation_finished.connect(func(_a): gg.visible = false, CONNECT_ONE_SHOT)
		fx.burst(Vector2(t) + Vector2(0.5, 0.5), 0.2, Color(0.4, 0.95, 0.85), 3, 2.0, 0.4, -1.0)
	# push the player out of a closing gate
	if closed and player and grid.box_blocked(player.pos, player.box()):
		player.pos = random_floor_near(r.center(), 2.0)


# --- boss ----------------------------------------------------------------------------

func _start_boss(r: Room) -> void:
	Audio.stop_music(1.0)
	var c := r.center()
	after(1.2, func() -> void:
		var e := _make_enemy(String(region.boss))
		e.pos = c + Vector2(0, -3)
		e.room_id = r.id
		e.scale_for(1, int(Profile.data.world.get("memory", 0)))
		add_actor(e)
		register_enemy(e)
		boss = e
		var w := e as Enemy
		w.set("arena_center", c)
		var bz: Array = []
		for p in props:
			if is_instance_valid(p) and p.kind == "boss_brazier" and p.room_id == r.id:
				p.data["boss"] = e
				bz.append(p)
		w.set("braziers", bz)
		Events.boss_started.emit(e)
		Events.banner.emit(e.display_name, "Keeper of the Lightless Heart")
		Audio.play_music("boss", 0.5))


func _on_actor_died(a: Actor, killer: Node) -> void:
	if a is Enemy:
		var e := a as Enemy
		run.kills += 1
		Profile.stat_add("kills")
		if e.elite:
			run.elites_slain += 1
		# loot (embers are deliberately scarce: they are both shop money and progress)
		var total := int(round(e.embers * 0.6))
		var n := total
		var chunks := clampi(n, 0, 6)
		for i in chunks:
			if n <= 0:
				break
			var amt := int(ceil(float(total) / chunks))
			Pickup.spawn(self, "ember", e.pos, amt)
			n -= amt
		if e.xp > 0:
			Pickup.spawn(self, "xp", e.pos, e.xp)
		if rng.randf() < 0.06:
			Pickup.spawn(self, "heal", e.pos, 10)
		if e.has_meta("grudge_id"):
			var g := Profile.settle_grudge(e.get_meta("grudge_id"))
			var back := int(e.get_meta("grudge_embers")) * (2 if Profile.building("shrine") > 0 else 1)
			for i in 10:
				Pickup.spawn(self, "ember", e.pos, int(ceil(back / 10.0)))
			Pickup.spawn(self, "sunshard", e.pos, 1)
			run.grudges_settled.append(g.get("name", "?"))
			Events.banner.emit("Grudge Settled", "%s returns to the dust." % g.get("name", "It"))
		if e == boss:
			_boss_defeated(e)


func _boss_defeated(e: Enemy) -> void:
	var r := layout.room(layout.exit_id)
	active_room = null
	r.cleared = true
	_set_gates(r, false)
	for i in 2:
		Pickup.spawn(self, "sunshard", e.pos, 1)
	for i in 16:
		Pickup.spawn(self, "ember", e.pos, 8)
	for i in 8:
		Pickup.spawn(self, "xp", e.pos, 20)
	after(2.5, func() -> void:
		Prop.make(self, "hearthstone", Vector2i(r.center()) + Vector2i(0, 2), {"victory": true})
		Events.banner.emit("The Warden Falls", "Touch the Hearthstone to return in triumph"))
	Audio.play_music("victory", 2.0)
	Profile.data.world.warden_kills = int(Profile.data.world.get("warden_kills", 0)) + 1


func _on_player_died() -> void:
	_death_t = 2.6
	_killer_id = ""
	# whoever dealt the last blow becomes a Grudge
	for e in room_enemies:
		if is_instance_valid(e) and e.alive and e is Enemy:
			if e.pos.distance_to(player.pos) < 6.0 and not (e as Enemy).def.get("boss", false):
				_killer_id = (e as Enemy).id
				break


# --- props asking for things -----------------------------------------------------------

func request(what: String, prop: Prop) -> void:
	match what:
		"stairs":
			Game.descend()
		"hearthstone":
			if prop.data.get("victory", false):
				Game.end_run("victory")
			else:
				Game.ui.confirm("Return to the Last Hearth?", "You keep everything you carry. The descent ends here.", func() -> void:
					Game.end_run("extracted"))
		"relic":
			var tier: int = prop.data.get("tier", 1)
			var offer := RelicDB.roll_offer(run.rng, 3, run.relics, SkillDB.branch_counts(Profile.skills()), SkillDB.abilities(Profile.skills()), layout.depth + (1 if tier > 1 else 0), true)
			if player.autopilot:
				if not offer.is_empty():
					Game.grant_relic(offer[0])
					print("[bot] took relic ", offer[0])
				prop.used = true
				return
			Game.ui.relic_choice(offer, func(id: String) -> void:
				if id != "":
					Game.grant_relic(id)
					prop.used = true
					prop.sprite.play("empty")
					if prop.light:
						prop.light.light_energy = 0.3)
		"chest":
			var tier2: int = prop.data.get("tier", 1)
			for i in 6 + tier2 * 6:
				Pickup.spawn(self, "ember", prop.pos, 2 + tier2)
			if tier2 >= 2 and rng.randf() < 0.6:
				Pickup.spawn(self, "sunshard", prop.pos, 1)
			var offer2 := RelicDB.roll_offer(run.rng, 3, run.relics, SkillDB.branch_counts(Profile.skills()), SkillDB.abilities(Profile.skills()), layout.depth + tier2 - 1, false)
			if player.autopilot:
				if not offer2.is_empty():
					Game.grant_relic(offer2[0])
				return
			Game.ui.relic_choice(offer2, func(id: String) -> void:
				if id != "":
					Game.grant_relic(id))
		"shrine":
			Game.ui.shrine(prop)
		"merchant":
			Game.ui.shop(prop)
		"lore":
			Game.ui.lore(Lore.random_ossuary(rng))
		"secret":
			_open_secret(prop)


func _open_secret(prop: Prop) -> void:
	var d: Dictionary = prop.data.get("door", {})
	for t: Vector2i in d.get("gap", []):
		grid.put(t.x, t.y, TileGrid.FLOOR)
	for c in get_children():
		if c.name == "Level":
			c.queue_free()
	var theme := LevelBuilder.LevelTheme.named(region.theme)
	var lvl := LevelBuilder.build(grid, theme)
	add_child(lvl)
	rebuild_nav()
	# re-apply solid props to the fresh nav grid
	for p in props:
		if is_instance_valid(p):
			for t in p._solid_tiles:
				set_tile_solid(t, true)
	fx.burst(prop.pos, 1.0, Color(0.6, 0.58, 0.56), 30, 5.0, 0.7, 9.0, Vector2.ZERO, PI, 3.0)
	fx.shake(0.4)
	Audio.play("crumble", 0.0)
	prop.queue_free()
	props.erase(prop)
	Events.toast.emit("The wall crumbles - a hidden passage!", Color(1.0, 0.85, 0.5))
	minimap_changed.emit()
