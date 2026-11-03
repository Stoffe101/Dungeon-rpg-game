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
var _grudge := {}           # the Grudge waiting on this floor (with its owner's peer)
var grudge_spawned := false
var env: Environment
var _clear_t := -1.0
var _clear_room: Room
var _death_t := -1.0
var _killer_id := ""
var _enter_t := 0.0
var built := false     # props made after this are announced to co-op clients


func build(lay: DungeonGen.Layout, r: RunState, v: PixelView) -> void:
	layout = lay
	run = r
	region = EnemyDB.REGIONS[lay.region]
	setup(lay.grid, v)
	rng.seed = lay.seed * 31 + lay.depth
	var theme := LevelBuilder.LevelTheme.named(region.theme)
	add_child(LevelBuilder.build(grid, theme))
	_environment()
	if not replica:
		_pick_grudge_room()
	_place_props()
	if run.has_omen("lightless"):
		_snuff_lights()
	_place_gates()
	_place_door_icons()
	if grudge_room >= 0:
		after(3.5, func() -> void: Events.toast.emit("Something on this floor remembers you. Its fires burn red.", Color(1.0, 0.45, 0.4)))
	# the player (co-op: the whole party)
	var start := layout.room(layout.start_id)
	_spawn_party(start)
	if "autopilot" in Dev.args():
		player.add_child(Bot.new())
	if "hearthcall" in Dev.args():
		# dev: start a Hearthcall once the floor is up
		after(1.0, player.start_hearthcall)
	if "warp=boss" in Dev.args() and layout.boss_depth:
		# dev: start in the antechamber next to the boss arena
		var boss_room := layout.room(layout.exit_id)
		var ante := layout.room(boss_room.doors[0].to)
		player.pos = ante.center() + Vector2(0, 1)
		for rm in layout.rooms:
			if rm != boss_room:
				rm.visited = true
				rm.cleared = true
		start = ante
	if "warp=event" in Dev.args():
		for rm in layout.rooms:
			if rm.type == Room.Type.EVENT:
				player.pos = rm.center() + Vector2(0, 3)
				start = rm
	if view:
		view.focus = Iso.to_world(player.pos)
	_enter_room(start)
	if "hitlab" in Dev.args() and not replica:
		# dev: enemies right beside the player, to look at hit feedback up close
		# (lab=<id,id:affix,...> picks who, and which are elites)
		var ids: Array = ["husk", "husk", "guard"]
		for a in Dev.args():
			if a.begins_with("lab="):
				ids = a.substr(4).split(",")
		for k in ids.size():
			var parts := String(ids[k]).split(":")
			var e := _make_enemy(parts[0])
			if parts.size() > 1:
				e.make_elite(parts[1])
			e.pos = random_floor_near(player.pos + Vector2(1.8 + k * 0.8, -0.5 + k * 0.6), 0.6)
			e.room_id = start.id
			add_actor(e)
	if "coopdive" in Dev.args() and not replica:
		# dev: depth 1 -> the party votes to descend; depth 2 -> Hearthcall home (a vote too)
		if layout.depth == 1:
			after(4.0, func() -> void:
				if Net.i.run_sync and Net.party_size() > 1:
					Net.i.run_sync.start_vote("stairs", -1, player)
				else:
					Game.descend())
		else:
			after(3.0, func() -> void:
				if player and player.alive:
					player.invuln_t = 8.0     # dev: so the ritual is not broken mid-test
					player.start_hearthcall())
	if "lootlab" in Dev.args() and not replica:
		# dev: one drop of each grade near the player, to look at loot beams
		var lr := RandomNumberGenerator.new()
		lr.seed = 4
		var grades := ["common", "rare", "epic", "legendary"]
		for k in grades.size():
			var b: String = "gloamward_lantern" if grades[k] == "legendary" else "grave_iron_helm"
			var it := ItemDB.make_item(b, grades[k], 1, lr, 1)
			var pk := Pickup.spawn(self, "gear", player.pos + Vector2(-3.0 + k * 2.0, -2.5), 1, {"item": it})
			pk.vel = Vector2.ZERO
		var bp := Pickup.spawn(self, "blueprint", player.pos + Vector2(5.0, -2.5), 1, {"id": "gamblers_coin"})
		bp.vel = Vector2.ZERO
	if "dumpmap" in Dev.args():
		_dump_map()
	if OS.is_debug_build():
		for rm in layout.rooms:
			if rm.type == Room.Type.EVENT:
				print("[dungeon] event room %d: %s" % [rm.id, rm.event])
	built = true
	Events.player_died.connect(_on_player_died)
	Events.parry_success.connect(_on_ward)
	actor_died.connect(_on_actor_died)
	Audio.play_music(region.music)
	Audio.play_ambience(String(region.get("ambience", "amb_crypt")))
	var title: String = Delve.NAME if run.delve else String(region.name)
	# a title card already named the place on the way down
	if Game.ui == null or not Game.ui.card_pending:
		Events.banner.emit(title, "Depth %d%s" % [lay.depth, ("  -  %s waits below" % String(EnemyDB.get_def(String(region.boss)).name)) if lay.boss_depth else ""])
		if not run.omens.is_empty() and lay.depth == 1:
			after(2.6, func() -> void: Events.banner.emit("Omens", Omens.names(run.omens)))
	if int(Profile.data.stats.get("runs", 0)) <= 2 and lay.depth == 1 and Game.ui:
		Game.ui.hud.show_controls.call_deferred()


## Dev: prints the floor as ASCII (o = solid prop such as a bramble).
func _dump_map() -> void:
	var chars := {0: " ", 1: ".", 2: "#", 3: "P", 4: "~", 5: "G", 6: "o"}
	for y in grid.height:
		var line := ""
		for x in grid.width:
			line += chars.get(grid.at(x, y), "?")
		if line.strip_edges() != "":
			print("%3d %s" % [y, line])
	for r in layout.rooms:
		print("room %d %s rect=%s doors=%s" % [r.id, r.type_name(), r.rect, r.doors.map(func(d): return d.to)])


## Lightless: every torch, candle, brazier and glowcap is dark; only the
## lantern (and what the Undervault itself gives off) remains.
func _snuff_lights() -> void:
	env.ambient_light_energy *= 0.62
	for p in props:
		if p.kind in ["torch", "candles", "brazier", "glowcap"]:
			p.lit = false
			if p.light:
				p.light.visible = false
			if p.sprite:
				p.sprite.set_glow(0.0)
				p.sprite.set_tint(Color(0.5, 0.5, 0.55))
				p.sprite.playing = false


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.014, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = region.ambient
	env.ambient_light_energy = 0.78
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
	if view:
		view.set_environment(env)


func _place_props() -> void:
	var flame: Color = region.flame
	for r in layout.rooms:
		for pd in r.props:
			var extra := {"flame": flame}
			if pd.has("variant"):
				extra["variant"] = pd.variant
			if pd.has("row"):
				extra["row"] = pd.row
			if pd.kind == "dressing":
				extra["sheet"] = pd.sheet
				extra["solid"] = true
			if pd.kind == "chest":
				extra["tier"] = pd.get("tier", 1)
				if pd.get("sealed", false):
					extra["sealed"] = true
			if pd.kind == "sconce" and region.has("brazier"):
				extra["sheet"] = String(region.brazier)
			if r.id == grudge_room and pd.kind in ["torch", "candles", "brazier"]:
				# something that remembers you is in here: its fires burn red
				extra["flame"] = Color(1.0, 0.32, 0.25)
			if pd.has("phase"):
				extra["phase"] = pd.phase
			if pd.kind == "torch":
				extra["sheet"] = String(region.get("torch", "torch"))
			if pd.kind in ["brazier", "boss_brazier"] and region.has("brazier"):
				extra["sheet"] = String(region.brazier)
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
				var kind := "bramble_wall" if layout.region == "rootmire" else "cracked_wall"
				var cw := Prop.make(self, kind, tiles[0], {"center": c + Vector2(0, 0.5), "door": d, "room": r.id})
				cw.room_id = r.id


func _place_gates() -> void:
	for r in layout.rooms:
		if not r.is_combat() and r.event != "trial":
			continue
		var nodes: Array = []
		for d in r.doors:
			if d.secret:
				continue
			for t: Vector2i in d.tiles:
				var g := PixelSprite.new()
				add_child(g)
				g.setup(String(region.get("gate", "gate")), "closed")
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
		Room.Type.EVENT:
			return {"well": "embers", "trial": "skull", "echo": "relic", "vault": "chest", "camp": "vigor"}.get(r.event, "")
	return ""


## Every Kindled's Grudges, each with its owner's peer (co-op: the guests' come
## from their character sheets; their own profile settles them).
func party_grudges() -> Array:
	var out: Array = []
	for g in Profile.active_grudges():
		var c: Dictionary = g.duplicate()
		c["owner"] = Net.my_id()
		out.append(c)
	for pl in players:
		if is_instance_valid(pl) and not pl.sheet.is_empty():
			for g in pl.sheet.get("grudges", []):
				var c2: Dictionary = (g as Dictionary).duplicate()
				c2["owner"] = pl.peer_id
				out.append(c2)
	return out


func _pick_grudge_room() -> void:
	# a Grudge waits on the depth where it won, or on the last one if that was deeper
	var gs := party_grudges().filter(func(g): return int(g.get("depth", 1)) == layout.depth or (layout.boss_depth and int(g.get("depth", 1)) > layout.depth))
	if run.has_omen("hunted"):
		gs = party_grudges()
	if gs.is_empty():
		return
	_grudge = gs[rng.randi_range(0, gs.size() - 1)]
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
	if replica:
		if player:
			var rt := layout.room_at_tile(Vector2i(floori(player.pos.x), floori(player.pos.y)))
			if rt and rt != current_room:
				current_room = rt
				minimap_changed.emit()
		return
	if players.size() > 1:
		_coop_tick(dt)
	if player == null or not player.alive:
		return
	run.elapsed += dt
	var t := Vector2i(floori(player.pos.x), floori(player.pos.y))
	var r := layout.room_at_tile(t)
	if r and r != current_room:
		_enter_room(r)
	# co-op: whoever steps in first starts the fight (not only this machine's Kindled)
	for pl in active_players():
		var pt := Vector2i(floori(pl.pos.x), floori(pl.pos.y))
		var pr := layout.room_at_tile(pt)
		if pl != player and pr and not pr.visited:
			_enter_room(pr, false)
		if pr and not pr.cleared and pr.is_combat() and active_room == null and pr.rect.grow(-1).has_point(pt):
			if pl != player:
				_start_encounter(pr)
				break
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


## The air of each region: soul motes rising in the Ossuary, spores drifting in
## the Rootmire, ash (and the odd ember) falling in the Sunken Throne.
var _air_t := 0.0
var _rising := 0   # Restless Dead still getting up

## Every Kindled on the floor. Solo: just this machine's. Co-op: one per seat,
## the same on every machine (ids by seat); this machine's own drives the camera.
func _spawn_party(start: Room) -> void:
	if not Net.active():
		player = Player.new()
		player.pos = start.center() + Vector2(0, 2)
		add_actor(player)
		player.setup_from(run)
		return
	var seats: Array = Net.i.roster.keys()
	seats.sort_custom(func(a, b): return int(Net.i.roster[a].slot) < int(Net.i.roster[b].slot))
	for pid in seats:
		var slot := int(Net.i.roster[pid].slot)
		var pl := Player.new()
		pl.peer_id = int(pid)
		pl.net_id = 1000 + slot
		var mine := int(pid) == Net.my_id()
		if replica:
			pl.controller = Player.Ctrl.REPLICA
			pl.replica = true
			pl.predicting = mine
		elif not mine:
			pl.controller = Player.Ctrl.REMOTE
		if not mine:
			pl.sheet = Net.i.roster[pid].sheet
		# side by side near the entrance, on open floor (rooms have pillars and pits)
		pl.pos = _floor_inside(start, start.center() + Vector2(-1.5 + slot, 2.0 + (slot % 2) * 0.6))
		add_actor(pl)
		pl.setup_from(Game.run_of(int(pid)))
		var col := Net.color_of(int(pid))
		pl.set_seat(col)
		if mine:
			player = pl
		else:
			fx.mark(pl, 2.5, Net.name_of(int(pid)), col, 8)


func _ambient_air(real: float) -> void:
	if player == null:
		return
	_air_t += real
	while _air_t > 0.07:
		_air_t -= 0.07
		var p := player.pos + Vector2(randf_range(-11.0, 11.0), randf_range(-7.0, 7.0))
		var ti := Vector2i(floori(p.x), floori(p.y))
		if grid.at(ti.x, ti.y) != TileGrid.FLOOR:
			continue
		match layout.region:
			"rootmire":
				fx.motes(p, randf_range(0.3, 1.6), Color(0.7, 0.9, 0.45, 1.0) if randf() < 0.7 else Color(0.5, 1.0, 0.85), 1, 0.15, 3.5, 0.2)
			"throne":
				if randf() < 0.12:
					fx.motes(p, randf_range(1.0, 2.5), Color(1.0, 0.6, 0.25), 1, -0.25, 3.0, 0.2)
				else:
					fx.motes(p, randf_range(1.5, 3.0), Color(0.55, 0.52, 0.5), 1, -0.35, 4.0, 0.2)
			_:
				fx.motes(p, randf_range(0.1, 1.0), Color(0.45, 0.95, 0.85), 1, 0.3, 3.0, 0.2)


func _stage_process(real: float) -> void:
	_ambient_air(real)
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


func _enter_room(r: Room, mine := true) -> void:
	if mine:
		current_room = r
		_enter_t = 0.0
	if not r.visited:
		Net.rec(["room", r.id])
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
		elif r.type == Room.Type.EVENT:
			var msg := {"well": "An Ember Well glows with molten sunlight.", "trial": "A trial altar thrums. It wants a challenger.", "echo": "Someone is already here. Someone who was you, once.",
				"vault": "A sealed reliquary, and cold sconces around it. Light them together.", "camp": "A camp. Its fire went out long ago."}
			Events.toast.emit(msg.get(r.event, ""), Color(1.0, 0.8, 0.55))
	if not r.is_combat():
		r.cleared = true
	minimap_changed.emit()
	if not mine:
		return
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
	_pull_party_in(r)
	_set_gates(r, true)
	if r.type == Room.Type.BOSS:
		_start_boss(r)
		return
	_spawn_wave(r)
	if r.grudge and not grudge_spawned:
		_spawn_grudge(r)


func _spawn_wave(r: Room) -> void:
	var ids: Array = r.encounter[wave] if wave < r.encounter.size() else []
	var spots := r.spawns.filter(func(t): return grid.at(t.x, t.y) == TileGrid.FLOOR)
	spots.shuffle()
	var far: Array = spots.filter(func(t): return (Vector2(t) + Vector2(0.5, 0.5)).distance_to(player.pos) > 4.5)
	if far.size() >= ids.size():
		spots = far
	var elite_done := false
	if players.size() > 1:
		# about 30% more foes per extra Kindled, drawn from the same fight
		var extra := int(round(ids.size() * 0.3 * (players.size() - 1)))
		var base_ids := ids.duplicate()
		for k in extra:
			ids.append(base_ids[rng.randi_range(0, base_ids.size() - 1)])
	var tempered := run.has_omen("tempered") and r.type != Room.Type.ELITE
	var memory := int(Profile.data.world.get("memory", 0)) + int(region.get("memory_bonus", 0))
	for i in ids.size():
		var id: String = ids[i]
		var t: Vector2i = spots[i % spots.size()] if not spots.is_empty() else Vector2i(r.center())
		var e := _make_enemy(id)
		e.pos = Vector2(t) + Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7))
		_scale(e, layout.depth, memory)
		_coop_scale(e)
		var swarm := EnemyDB.get_def(id).has("pack")
		if r.type == Room.Type.ELITE and not elite_done and not swarm:
			var ea := r.elite_affix if EnemyDB.affix_ok(id, r.elite_affix) else EnemyDB.roll_affix(rng, id)
			e.make_elite(ea, _second_affix(ea, id))
			elite_done = true
		elif r.elite_affix == "" and rng.randf() < 0.04 * layout.depth + Difficulty.elite_chance(run.tier) and not swarm:
			var a := EnemyDB.roll_affix(rng, id)
			e.make_elite(a, _second_affix(a, id))
		if tempered and not swarm:
			if not e.elite:
				var ta := EnemyDB.roll_affix(rng, id)
				e.make_elite(ta, _second_affix(ta, id))
			tempered = false
		e.room_id = r.id
		e.spawn_t = 0.6 + i * 0.08
		add_actor(e)
		register_enemy(e)
		fx.shape(Fx.Shape.SIGIL, e.pos, Vector2.RIGHT, Vector2(1.6, 1.6), Color(0.3, 0.95, 0.85, 0.35), Color(0.5, 1.0, 0.9, 1.0), e.spawn_t + 0.1, {"glow": 1.5})
		Profile.note_seen("enemies", id)
	if not ids.is_empty():
		Audio.play("spawn", -2.0)


## Depth, Undervault Memory and the difficulty tier; the Lantern of Avarice
## makes everything tougher in exchange for its riches.
## Co-op: each extra Kindled makes a foe sturdier by a third (a boss by half).
func _coop_scale(e: Enemy) -> void:
	var extra := players.size() - 1
	if extra <= 0:
		return
	e.max_hp *= 1.0 + (0.5 if e.def.get("boss", false) else 0.35) * extra
	e.hp = e.max_hp


func _scale(e: Enemy, depth: int, memory: int) -> void:
	e.scale_for(depth, memory, run.tier)
	if player and player.stats.has("avarice"):
		e.max_hp *= 1.2
		e.hp = e.max_hp


## From Tier IV elites carry a second, different affix.
func _second_affix(first: String, id := "") -> String:
	if not Difficulty.double_affix(run.tier):
		return ""
	return EnemyDB.roll_affix(rng, id, first)


func _make_enemy(id: String) -> Enemy:
	var def := EnemyDB.get_def(id)
	var scr: GDScript = load(def.script)
	var e: Enemy = scr.new()
	e.configure(id)
	return e


func register_enemy(e: Enemy) -> void:
	room_enemies.append(e)
	# everything met goes in the bestiary: waves, bosses, summons, Grudges
	Profile.note_seen("enemies", e.id)


func _spawn_grudge(r: Room) -> void:
	var g: Dictionary = _grudge
	if g.is_empty():
		var gs := party_grudges()
		if gs.is_empty():
			return
		g = gs[0]
	grudge_spawned = true
	var e := _make_enemy(g.enemy)
	var t: Vector2i = r.spawns[rng.randi_range(0, r.spawns.size() - 1)] if not r.spawns.is_empty() else Vector2i(r.center())
	e.pos = Vector2(t) + Vector2(0.5, 0.5)
	_scale(e, layout.depth, int(Profile.data.world.get("memory", 0)))
	e.make_grudge(g)
	e.room_id = r.id
	e.spawn_t = 1.2
	e.set_meta("grudge_id", g.id)
	e.set_meta("grudge_owner", int(g.get("owner", Net.my_id())))
	e.set_meta("grudge_embers", int(g.embers))
	e.set_meta("grudge_level", int(g.level))
	add_actor(e)
	register_enemy(e)
	if (g.get("traits", []) as Array).has("escorted"):
		# it does not come alone any more
		for k in 2:
			var kin := _make_enemy(EnemyDB._filler(layout.region))
			kin.pos = random_floor_near(e.pos + Vector2.from_angle(TAU * k / 2.0) * 1.5, 0.6)
			_scale(kin, layout.depth, int(Profile.data.world.get("memory", 0)))
			kin.room_id = r.id
			kin.spawn_t = 1.2
			add_actor(kin)
			register_enemy(kin)
	Events.banner.emit(String(g.name), "Your Grudge has found you. It carries %d of your Embers." % int(g.embers))
	print("[dungeon] grudge %s (%s Lv%d) spawned in room %d" % [g.name, g.enemy, int(g.level), r.id])
	Audio.play("boss_roar", -6.0, 1.3)


func _update_encounter(_dt: float) -> void:
	room_enemies = room_enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	if room_enemies.is_empty() and _rising == 0 and active_room.type != Room.Type.BOSS:
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
	_rekindle_fallen()
	_clear_t = 0.6
	_clear_room = r
	Events.room_cleared.emit(r.id)
	if player and player.alive and player.stats.has("bottomless") and player.flask < int(player.stats.v("flask_charges")):
		player.flask += 1
		fx.number(player.pos, 2.4, "+1 FLASK", Color(1.0, 0.55, 0.45))
		Audio.play("flask", -6.0, 1.3)
	minimap_changed.emit()
	slow_motion(0.4, 0.25)
	Audio.play("room_clear", 0.0)


## Co-op: a won room brings back whoever bled out (and stands up the downed).
func _rekindle_fallen() -> void:
	if players.size() <= 1:
		return
	var leader := nearest_player(current_room.center() if current_room else Vector2.ZERO)
	for pl in players:
		if pl.downed:
			pl.revive(0.4)
		elif not pl.alive and leader:
			pl.pos = random_floor_near(leader.pos, 1.5)
			pl.revive(0.3)


func _finish_clear() -> void:
	var r := _clear_room
	_clear_room = null
	if OS.is_debug_build():
		print("[dungeon] gates open room %s" % (str(r.id) if r else "null"))
	if r == null:
		return
	_set_gates(r, false)
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
		"trial":
			Pickup.spawn(self, "sunshard", c, 1)
			_rune_drop(c + Vector2(1.5, 0))
			Prop.make(self, "relic_altar", Vector2i(c) + Vector2i(0, 2), {"tier": 3})
			for i in 10:
				Pickup.spawn(self, "ember", c, 4)
			Events.banner.emit("Trial Complete", "The Undervault grudgingly yields its prize")


func _open_spot(p: Vector2) -> Vector2:
	var t := Vector2i(floori(p.x), floori(p.y))
	for rad in 4:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := t + Vector2i(dx, dy)
				if grid.at(q.x, q.y) == TileGrid.FLOOR and grid.at(q.x, q.y - 1) == TileGrid.FLOOR and grid.at(q.x, q.y + 1) == TileGrid.FLOOR:
					return Vector2(q) + Vector2(0.5, 0.5)
	return p


## Seals (closed) or releases a room's doors. The grid, the nav grid and the
## seal sprites always change together, so what you see is what blocks.
func _set_gates(r: Room, closed: bool) -> void:
	Net.rec(["gate", r.id, closed])
	Net.mute += 1
	_seal(r, closed)
	Net.mute -= 1


func _seal(r: Room, closed: bool) -> void:
	var soul := Color(0.45, 1.0, 0.9)
	for g in gate_nodes.get(r.id, []):
		var t: Vector2i = g.get_meta("tile")
		var c := Vector2(t) + Vector2(0.5, 0.5)
		grid.put(t.x, t.y, TileGrid.GATE if closed else TileGrid.FLOOR)
		set_tile_solid(t, closed)
		var gg: PixelSprite = g
		gg.visible = true
		gg.play("rise" if closed else "fall", true)
		for cn in gg.animation_finished.get_connections():
			gg.animation_finished.disconnect(cn.callable)
		if closed:
			# light gathers on the threshold, then the seal weaves itself shut
			fx.motes(c, 0.0, soul, 5, 1.8, 0.45, 0.4)
			fx.burst(c, 0.1, soul, 4, 1.5, 0.35, -2.0, Vector2.ZERO, PI, 0.5)
			gg.animation_finished.connect(func(_a): if is_instance_valid(gg) and gg.anim == "rise": gg.play("closed"), CONNECT_ONE_SHOT)
		else:
			# released: it comes apart into motes that drift up and away
			fx.motes(c, 0.4, soul, 10, 2.6, 1.0, 0.45)
			fx.burst(c, 1.0, soul.lightened(0.3), 6, 2.5, 0.5, -3.0)
			gg.animation_finished.connect(func(_a): if is_instance_valid(gg) and gg.anim == "fall": gg.visible = false, CONNECT_ONE_SHOT)
	if closed:
		# nobody is left standing inside a closing seal: step them into the room
		for a in actors:
			if a.alive and not a.flying and grid.box_blocked(a.pos, a.box()):
				a.pos = _floor_inside(r, a.pos)
	Audio.play("seal_close" if closed else "seal_open", -2.0)


## An altar is spent when every Kindled on the floor has taken from it.
func _relic_taken(prop: Prop, who: Player) -> void:
	var taken: Array = prop.data.get("taken", [])
	if not taken.has(who.peer_id):
		taken.append(who.peer_id)
	prop.data["taken"] = taken
	if taken.size() >= players.size():
		prop.used = true
		prop.sprite.play("empty")
		if prop.light:
			prop.light.light_energy = 0.3


## Co-op host: a guest chose from the relics offered to them (an altar, a
## chest, a pact). One pick per offer: a repeated answer finds nothing.
func coop_relic_pick(pl: Player, idx: int, id: String) -> void:
	for prop in props:
		if is_instance_valid(prop) and prop.net_idx == idx:
			var key := "offer_%d" % pl.peer_id
			var offer: Array = prop.data.get(key, [])
			if not offer.has(id):
				return
			prop.data.erase(key)
			print("[net] %s chose relic %s (%s)" % [Net.name_of(pl.peer_id), id, prop.kind])
			Game.grant_relic_to(pl, id)
			if prop.kind == "relic_altar":
				_relic_taken(prop, pl)
			return


## Co-op: a room sealing never shuts a friend outside - the light draws them in.
func _pull_party_in(r: Room) -> void:
	var anchor := Vector2.ZERO
	var n := 0
	for pl in players:
		if pl.alive and r.contains_tile(Vector2i(floori(pl.pos.x), floori(pl.pos.y))):
			anchor += pl.pos
			n += 1
	if n == 0:
		return
	anchor /= n
	for pl in players:
		if not pl.alive or r.contains_tile(Vector2i(floori(pl.pos.x), floori(pl.pos.y))):
			continue
		fx.motes(pl.pos, 0.4, Color(0.45, 1.0, 0.9), 12, 2.0, 0.8, 0.4)
		pl.pos = _floor_inside(r, anchor + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)))
		fx.ring(pl.pos, 1.2, Color(0.45, 1.0, 0.9), 0.35, 0.25)


## Co-op upkeep each tick: everyone down means the party has fallen.
func _coop_tick(_dt: float) -> void:
	if _death_t < 0.0 and active_players().is_empty():
		for pl in players:
			if pl.downed:
				pl.downed = false
				pl.alive = false
		_death_t = 2.6
		_killer_id = player.last_attacker_id if player else ""
		Events.banner.emit("The Party Falls", "Every light below has gone out")


## Co-op client: the host says this room was entered (map, toasts).
func visit_room(r: Room) -> void:
	if r == null or r.visited:
		return
	_enter_room(r, false)


## The open floor of `r` nearest to `p` (for nudging anyone out of a seal).
func _floor_inside(r: Room, p: Vector2) -> Vector2:
	var best := r.center()
	var bd := INF
	for t in r.cells:
		if grid.at(t.x, t.y) != TileGrid.FLOOR:
			continue
		var c := Vector2(t) + Vector2(0.5, 0.5)
		var d := c.distance_squared_to(p)
		if d < bd and not grid.box_blocked(c, 0.4):
			bd = d
			best = c
	return best


# --- boss ----------------------------------------------------------------------------

func _start_boss(r: Room) -> void:
	Audio.stop_music(1.0)
	var c := r.center()
	after(1.2, func() -> void:
		var e := _make_enemy(String(region.boss))
		e.pos = c + Vector2(0, -3)
		e.room_id = r.id
		_scale(e, 1, int(Profile.data.world.get("memory", 0)))
		if run.delve:
			var n := Delve.echo_n(layout.depth)
			e.max_hp *= 1.0 + 0.35 * n
			e.hp = e.max_hp
			e.damage *= 1.0 + 0.1 * n
			var a := EnemyDB.roll_affix(rng, e.id)
			e.affix = a
			e._apply_affix(a)
			e.elite = true
			e.display_name = "Echo of %s" % e.display_name
		add_actor(e)
		register_enemy(e)
		boss = e
		var w := e as Enemy
		w.set("arena_center", c)
		var bz: Array = []
		for p in props:
			if is_instance_valid(p) and p.kind in ["boss_brazier", "root_node"] and p.room_id == r.id:
				p.data["boss"] = e
				bz.append(p)
		w.set("braziers", bz)
		Net.rec(["boss", e.net_id])
		Events.boss_started.emit(e)
		Events.banner.emit(e.display_name, String(e.def.get("epithet", "")))
		Audio.play_music("boss", 0.5))


## Materials (and now and then gear) from a fallen enemy; elites and bosses
## drop more, and a boss's first defeat always yields its legendary.
func _drop_loot(e: Enemy) -> void:
	var mult := (2.0 if e.elite else 1.0) * Difficulty.material_mult(run.tier)
	if player and player.stats.has("avarice"):
		mult *= 1.6
	for d in ItemDB.enemy_drops(e.id, layout.region):
		if rng.randf() < float(d[1]) * mult:
			Pickup.spawn(self, "material", e.pos, rng.randi_range(int(d[2]), int(d[3])), {"id": d[0]})
	if e.elite:
		_maybe_blueprint(e.pos, 0.03 + 0.01 * run.tier)
		if rng.randf() < 0.08 + 0.01 * run.tier:
			_rune_drop(e.pos)
		var rare: String = {"rootmire": "spore_silk", "throne": "sun_gold"}.get(layout.region, "soul_glass")
		Pickup.spawn(self, "material", e.pos, rng.randi_range(1, 2), {"id": rare})
		if rng.randf() < 0.3:
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.1, run.tier))
	if e == boss:
		_maybe_blueprint(e.pos, 1.0 if layout.region == "throne" else 0.3 + 0.05 * run.tier)
		_rune_drop(e.pos)
		var cat: String = {"rootmire": "bloom_heart", "throne": "eclipse_shard"}.get(layout.region, "warden_sigil")
		Pickup.spawn(self, "material", e.pos, 2, {"id": cat})
		var leg: String = {"rootmire": "bloom_crown", "throne": "sunfall_mantle"}.get(layout.region, "gloamward_lantern")
		var flag := "legendary_" + leg
		if not Profile.data.flags.get(flag, false) or rng.randf() < 0.35:
			Profile.data.flags[flag] = true
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.make_item(leg, "legendary", 1, rng, run.tier))
		_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 1, rng, 0.25, run.tier))
		if run.tier >= 2:
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_set_piece(rng, layout.depth, run.tier))


## A gear drop. Co-op: one roll for each Kindled, visible to and taken by its
## owner only (nobody walks off with a friend's find).
func _gear_drop(p: Vector2, roll: Callable) -> void:
	if players.size() <= 1:
		Pickup.spawn(self, "gear", p, 1, {"item": roll.call()})
		return
	for pl in players:
		var pk := Pickup.spawn(self, "gear", p, 1, {"item": roll.call()})
		pk.owner_peer = pl.peer_id


## An Ember Rune: one roll for each Kindled (theirs alone, like gear).
func _rune_drop(p: Vector2) -> void:
	var ids: Array = Runes.RUNES.keys()
	if players.size() <= 1:
		Pickup.spawn(self, "rune", p, 1, {"id": ids[rng.randi_range(0, ids.size() - 1)]})
		return
	for pl in players:
		var pk := Pickup.spawn(self, "rune", p, 1, {"id": ids[rng.randi_range(0, ids.size() - 1)]})
		pk.owner_peer = pl.peer_id


## A blueprint the Kindled doesn't have yet (else a few Ember Cores).
func _maybe_blueprint(p: Vector2, chance: float) -> void:
	if rng.randf() >= chance:
		return
	var have: Array = Profile.known_blueprints() + Profile.scrolls() + (run.loot.blueprints as Array)
	var b := ItemDB.roll_blueprint(rng, have)
	if b == "":
		Pickup.spawn(self, "material", p, 3, {"id": "ember_core"})
	elif players.size() <= 1:
		Pickup.spawn(self, "blueprint", p, 1, {"id": b})
	else:
		for pl in players:
			var pk := Pickup.spawn(self, "blueprint", p, 1, {"id": b})
			pk.owner_peer = pl.peer_id


## A chest's materials and its chance of gear.
func _chest_loot(prop: Prop, tier: int) -> void:
	var pool: Array = {"rootmire": ["rootwood", "spore_silk"], "throne": ["sun_gold", "grave_iron", "soul_glass", "spore_silk"]}.get(layout.region, ["bone_dust", "grave_iron", "soul_glass"])
	for i in 1 + tier:
		Pickup.spawn(self, "material", prop.pos, rng.randi_range(1, 2 + tier), {"id": pool[rng.randi_range(0, pool.size() - 1)]})
	if rng.randf() < 0.3 + 0.2 * tier:
		Pickup.spawn(self, "material", prop.pos, 1, {"id": "ember_core"})
	var lucky := player != null and player.stats.has("lucky")
	if rng.randf() < 0.25 + 0.25 * tier:
		_gear_drop(prop.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.05 * tier + (0.15 if lucky else 0.0), run.tier))
	if lucky:
		# the Four-Leaf Ring: one more treasure, every time
		if rng.randf() < 0.5:
			_gear_drop(prop.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.2, run.tier))
		else:
			Pickup.spawn(self, "material", prop.pos, 2, {"id": "ember_core"})
	_maybe_blueprint(prop.pos, (0.015 + 0.005 * run.tier) if tier <= 1 else (0.06 + 0.02 * run.tier))


## Counts progress on residents' requests and tells the player when one is done.
func note_request(key: String, amount := 1) -> void:
	var done := Residents.note(key, amount)
	if OS.is_debug_build() and not Residents.journal().is_empty():
		print("[request] %s x%d -> %s" % [key, amount, Residents.journal()])
	for name in done:
		Events.toast.emit("Request complete - return to %s at the Hearth." % name, UIKit.C_GOLD)
		Audio.play("relic", -4.0)
	for r in Residents.LIST:
		var req: Dictionary = r.request
		if req.key == key and Residents.request_state(r.id) == "active":
			var n := Residents.request_progress(r.id)
			if int(req.goal) <= 5 or n == int(req.goal) / 2:
				Events.toast.emit("%s: %d/%d" % [req.title, n, int(req.goal)], UIKit.C_DIM)


func _on_ward() -> void:
	note_request("ward")


func _on_actor_died(a: Actor, killer: Node) -> void:
	if a is Enemy:
		var e := a as Enemy
		run.kills += 1
		# the party's kills count for everyone (guests bank them when they settle)
		for pr in _party_runs():
			pr.kill_counts[e.id] = int(pr.kill_counts.get(e.id, 0)) + 1
		Profile.stat_add("kills")
		Profile.stat_add("k_" + e.id)
		if e.elite:
			run.elites_slain += 1
			Profile.stat_add("elites")
			note_request("elite")
		# loot (embers are deliberately scarce: they are both shop money and progress)
		var memory := int(Profile.data.world.get("memory", 0))
		var total := int(round(e.embers * 0.6 * (1.0 + 0.15 * memory)))
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
		_drop_loot(e)
		if rng.randf() < 0.06:
			Pickup.spawn(self, "heal", e.pos, 10)
		if run.has_omen("restless") and not e.summoned and not e.def.get("boss", false) and not e.has_meta("grudge_id") and e.room_id >= 0 and rng.randf() < 0.33:
			_rise_again(e.id, e.pos, e.room_id)
		if e.has_meta("grudge_id"):
			# settled for its owner (a guest's on their machine, when they bank)
			var owner := int(e.get_meta("grudge_owner", Net.my_id()))
			var bearer: Player = player
			var g := {}
			if owner == Net.my_id():
				g = Profile.settle_grudge(e.get_meta("grudge_id"))
			for pl in players:
				if is_instance_valid(pl) and pl.peer_id == owner and owner != Net.my_id():
					bearer = pl
					pl.run.grudges_won.append(String(e.get_meta("grudge_id")))
					for pg in pl.sheet.get("grudges", []):
						if String(pg.id) == String(e.get_meta("grudge_id")):
							g = pg
			var shrine_lv := Profile.building("shrine") if bearer == player else int(bearer.sheet.get("sanctuary", {}).get("shrine", 0))
			var back := int(e.get_meta("grudge_embers")) * (2 if shrine_lv > 0 else 1)
			if run.has_omen("hunted"):
				back *= 2
			if bearer and bearer.stats.has("grudgebearer"):
				back = int(back * 1.5)
			for i in 10:
				Pickup.spawn(self, "ember", e.pos, int(ceil(back / 10.0)))
			Pickup.spawn(self, "sunshard", e.pos, 1)
			if int(e.get_meta("grudge_level", 1)) >= 2:
				# what it hoarded while it grew
				_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 1, rng, 0.2 + 0.1 * int(e.get_meta("grudge_level", 1)), run.tier))
			run.grudges_settled.append(g.get("name", "?"))
			Events.banner.emit("Grudge Settled", "%s returns to the dust." % g.get("name", "It"))
		if e == boss:
			_boss_defeated(e)


## Restless Dead: the fallen climb back up once, weaker, a moment later.
func _rise_again(kind: String, at: Vector2, room: int) -> void:
	_rising += 1
	fx.shape(Fx.Shape.SIGIL, at, Vector2.RIGHT, Vector2(1.4, 1.4), Color(0.6, 0.45, 1.0, 0.35), Color(0.75, 0.6, 1.0, 1.0), 1.5, {"glow": 1.4})
	fx.motes(at, 0.0, Omens.COLOR, 8, 1.2, 1.2, 0.5)
	after(1.4, func() -> void:
		_rising = maxi(0, _rising - 1)
		if run.result != "" or player == null or not player.alive:
			return
		var e := _make_enemy(kind)
		_scale(e, layout.depth, int(Profile.data.world.get("memory", 0)))
		e.max_hp *= 0.5
		e.hp = e.max_hp
		e.summoned = true
		e.xp = 1
		e.embers = 0
		e.pos = random_floor_near(at, 0.4)
		e.room_id = room
		e.spawn_t = 0.45
		add_actor(e)
		e.sprite.set_tint(Color(0.8, 0.72, 1.0))
		register_enemy(e)
		Audio.play_at("spawn", at, -6.0, 0.8))


func _boss_defeated(e: Enemy) -> void:
	Net.rec(["boss_down"])
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
	var fall := String(e.def.get("fall", "Victory"))
	if run.delve:
		# in the Hollow Below a fallen guardian opens the way further down
		after(2.5, func() -> void:
			Prop.make(self, "stairs", Vector2i(_open_spot(r.center() + Vector2(0, -2))))
			Prop.make(self, "hearthstone", Vector2i(_open_spot(r.center() + Vector2(0, 3))))
			Events.banner.emit("The Echo Fades", "Go deeper, or let the Hearthstone take you home"))
		Audio.play_music("victory", 2.0)
		return
	after(2.5, func() -> void:
		Prop.make(self, "hearthstone", Vector2i(r.center()) + Vector2i(0, 2), {"victory": true})
		Events.banner.emit(fall, "Touch the Hearthstone to return in triumph"))
	Audio.play_music("victory", 2.0)
	var key := "%s_kills" % e.id
	Profile.data.world[key] = int(Profile.data.world.get(key, 0)) + 1
	# every Kindled in the party felled it (guests bank it when they settle)
	for pr in _party_runs():
		if pr != run:
			pr.bosses.append(e.id)


## The guests' runs on this floor (the host's own is `run`).
func _party_runs() -> Array:
	var out: Array = [run]
	for pl in players:
		if is_instance_valid(pl) and pl.run and pl.run != run:
			out.append(pl.run)
	return out


func _on_player_died() -> void:
	if players.size() > 1:
		# co-op: one light out is not the end; _coop_tick decides when it is
		return
	_death_t = 2.6
	# whoever dealt the last blow becomes a Grudge (bosses never do)
	_killer_id = player.last_attacker_id
	if _killer_id != "" and EnemyDB.get_def(_killer_id).get("boss", false):
		_killer_id = ""
	if _killer_id != "":
		return
	for e in room_enemies:
		if is_instance_valid(e) and e.alive and e is Enemy:
			if e.pos.distance_to(player.pos) < 6.0 and not (e as Enemy).def.get("boss", false):
				_killer_id = (e as Enemy).id
				break


# --- props asking for things -----------------------------------------------------------

func request(what: String, prop: Prop) -> void:
	var who: Player = interactor if interactor else player
	if Party.serve(self, who, what, prop):
		return
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
			if (prop.data.get("taken", []) as Array).has(who.peer_id):
				return
			var tier: int = prop.data.get("tier", 1)
			var skills := Party.skills_of(who)
			var offer := RelicDB.roll_offer(run.rng, 6 if tier >= 3 else 3, who.run.relics, SkillDB.branch_counts(skills), SkillDB.abilities(skills), layout.depth + tier - 1, tier < 3)
			if tier >= 3:
				# trial prizes: no commons
				var better := offer.filter(func(id): return RelicDB.relic(id).rarity != "common")
				offer = (better if better.size() >= 2 else offer).slice(0, 3)
			# their choice, on their screen
			Party.offer_relic(self, who, prop, offer, func() -> void: _relic_taken(prop, who))
		"chest":
			note_request("chest")
			_chest_loot(prop, int(prop.data.get("tier", 1)))
			if Residents.wants_toy():
				fx.number(prop.pos, 2.4, "WOODEN BIRD", Color(1.0, 0.6, 0.45), true)
				Events.toast.emit("A small wooden bird with a red wing. Wren will be glad.", Color(1.0, 0.75, 0.55))
				note_request("toy")
			var tier2: int = prop.data.get("tier", 1)
			for i in 6 + tier2 * 6:
				Pickup.spawn(self, "ember", prop.pos, 2 + tier2)
			if tier2 >= 2 and rng.randf() < 0.6:
				Pickup.spawn(self, "sunshard", prop.pos, 1)
			# the spill is everyone's; every Kindled chooses a relic of their own
			for pl in players:
				if not is_instance_valid(pl) or not pl.alive or pl.run == null:
					continue
				var sk := Party.skills_of(pl)
				Party.offer_relic(self, pl, prop, RelicDB.roll_offer(run.rng, 3, pl.run.relics, SkillDB.branch_counts(sk), SkillDB.abilities(sk), layout.depth + tier2 - 1, false))
		"shrine":
			Game.ui.shrine(prop)
		"merchant":
			Game.ui.shop(prop)
		"lore":
			Game.ui.lore(Lore.random_for(layout.region, rng))
		"sconce":
			_light_sconce(prop)
		"sealed":
			Events.toast.emit("Sealed. The sconces, burning together, will open it.", Color(1.0, 0.8, 0.55))
			Audio.play("deny", -6.0)
		"lost_camp":
			_rekindle_camp(prop)
		"secret":
			_open_secret(prop)
		"well":
			_ask("Draw from the Ember Well?", "Lose 20%% of your health. Gain about %d Embers." % Party.well_gain(self), func() -> void:
				Party.draw_well(self, who, prop))
		"trial":
			_ask("Begin the Trial?", "Three hard waves. The doors seal until it is done. The prize: a rare relic and a Sunshard.", func() -> void:
				begin_trial(prop))
		"echo":
			var line: Array = Lore.random_for(layout.region, rng)
			if Party.spent(prop, who):
				Game.ui.dialogue("Echo of a Fallen Kindled", ["...the light was warm, once. Go on. Carry it further than I did."])
				return
			var offer_fn := func() -> void:
				_ask("Offer 30 Embers to the Echo?", "You carry %d Embers." % run.embers, func() -> void: Party.echo_gift(self, who, prop))
			if player.autopilot:
				offer_fn.call()
			else:
				Game.ui.dialogue("Echo of a Fallen Kindled", ["I came down with a lantern like yours. %s" % line[1], "Leave a little light for me - thirty Embers - and take what I no longer need."], offer_fn)



## Sconce Vault: a sconce burns for a while once lit; when all four burn at
## once the reliquary unseals.
const SCONCE_BURN := 9.0

func _light_sconce(prop: Prop) -> void:
	if prop.lit:
		return
	prop.set_lit(true, region.flame)
	prop.data["left"] = SCONCE_BURN
	fx.burst(prop.pos, 1.4, region.flame, 10, 3.0, 0.4, -1.0)
	Audio.play_at("ignite", prop.pos, -2.0)
	var group := props.filter(func(p): return is_instance_valid(p) and p.kind == "sconce" and p.room_id == prop.room_id)
	var burning := group.filter(func(p): return p.lit).size()
	fx.number(prop.pos, 2.6, "%d / %d" % [burning, group.size()], region.flame.lightened(0.3))
	if OS.is_debug_build():
		print("[dungeon] sconce lit %d/%d" % [burning, group.size()])
	if burning < group.size():
		return
	for p in group:
		p.data["left"] = INF
		fx.ring(p.pos, 1.4, region.flame, 0.4, 0.25)
	for p in props:
		if is_instance_valid(p) and p.kind == "chest" and p.room_id == prop.room_id and p.data.get("sealed", false):
			p.data.erase("sealed")
			fx.flash_light(p.pos, 1.0, region.flame, 4.0, 8.0, 0.8)
			fx.motes(p.pos, 0.4, region.flame, 24, 2.0, 1.2, 0.6)
			after(0.6, func() -> void:
				if is_instance_valid(p) and not p.used:
					p.interact(player)
					# the reliquary keeps something better than a chest
					_gear_drop(p.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 1, rng, 0.35, run.tier))
					Pickup.spawn(self, "sunshard", p.pos, 1)
					_rune_drop(p.pos))
	if OS.is_debug_build():
		print("[dungeon] vault opened in room %d" % prop.room_id)
	Events.banner.emit("The Vault Opens", "The flames burn together")
	Audio.play("gate_open", -2.0, 1.2)


## A dead Kindled's camp: rekindling it rests you, and their pack is yours.
func _rekindle_camp(prop: Prop) -> void:
	if prop.used:
		return
	prop.used = true
	if OS.is_debug_build():
		print("[dungeon] camp rekindled in room %d" % prop.room_id)
	prop.sprite.play("lit")
	if prop.light:
		prop.light.visible = true
		prop.lit = true
	# a fire rests everyone who sits by it
	for pl in players_near(prop.pos, 6.0):
		pl.heal(pl.max_hp * 0.4)
		pl.flask = mini(pl.flask + 1, int(pl.stats.v("flask_charges")))
		pl.gain_kindle(pl.kindle_max())
	fx.motes(prop.pos, 0.4, Color(1.0, 0.65, 0.35), 24, 1.8, 1.2, 0.5)
	fx.number(player.pos, 2.6, "RESTED", Color(1.0, 0.8, 0.55), true)
	Audio.play("ignite", -2.0, 0.8)
	Audio.play("flask", -4.0, 0.9)
	if rng.randf() < 0.55:
		_gear_drop(prop.pos + Vector2(1.6, -0.4), func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.25, run.tier))
	else:
		for i in 6:
			Pickup.spawn(self, "ember", prop.pos + Vector2(1.6, -0.4), 4 + layout.depth * 2)
	_chest_loot(prop, 1)
	if not player.autopilot and (interactor == null or interactor == player):
		var line: Array = Lore.random_for(layout.region, rng)
		Game.ui.dialogue("A Kindled's Last Camp", ["A note, tucked in the pack: \"%s\"" % String(line[1]), "The fire takes again. It is good to sit by a fire."])


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
	Events.toast.emit("The brambles part - a hidden passage!" if prop.kind == "bramble_wall" else "The wall crumbles - a hidden passage!", Color(1.0, 0.85, 0.5))
	minimap_changed.emit()


## The Trial altar wakes: three hard waves behind sealed doors.
func begin_trial(prop: Prop) -> void:
	if prop.used:
		return
	prop.used = true
	prop.sprite.play("spent")
	var r := layout.room(prop.room_id)
	r.cleared = false
	active_room = r
	wave = 0
	_set_gates(r, true)
	Audio.play("boss_roar", -6.0, 1.4)
	Events.banner.emit("The Trial Begins", "Survive three waves")
	_spawn_wave(r)


## Confirmation that the autopilot answers "yes" to.
func _ask(title: String, body: String, yes: Callable) -> void:
	if player.autopilot:
		yes.call()
	else:
		Game.ui.confirm(title, body, yes)
