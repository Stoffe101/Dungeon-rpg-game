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

var _favour := ""     # whose archetype a gear roll is for (weapon finds lean to it)
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
	if "walllab" in Dev.args():
		_wall_lab(lay)
	setup(lay.grid, v)
	rng.seed = lay.seed * 31 + lay.depth
	_warm_up()
	_environment()
	if not replica:
		_pick_grudge_room()
	_place_props()
	# (built after the props: the floor shades a contact shadow around every
	# solid one - LevelBuilder)
	add_child(_build_level())
	if run.has_omen("lightless"):
		_snuff_lights()
	_place_gates()
	_place_locks()
	_place_door_frames()
	_place_door_icons()
	if grudge_room >= 0:
		after(3.5, func() -> void: Events.toast.emit("Something on this floor remembers you. Its fires burn red.", Color(1.0, 0.45, 0.4)))
	# the player (co-op: the whole party)
	var start := layout.room(layout.start_id)
	_spawn_party(start)
	if "walllab" in Dev.args() and "behind" in Dev.args():
		# dev: stand behind the lab's pillar (the silhouette shows through it)
		player.pos = Vector2(Vector2i(start.center()) + Vector2i(3, -3)) + Vector2(0.5, 0.45)
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
	if "warp=landmark" in Dev.args():
		# dev: start beside the floor's landmark, its fight already won
		for rm in layout.rooms:
			if rm.landmark != "":
				player.pos = rm.center() + Vector2(0, 2.5)
				rm.cleared = true
				start = rm
	if "warp=event" in Dev.args():
		for rm in layout.rooms:
			if rm.type == Room.Type.EVENT:
				player.pos = rm.center() + Vector2(0, 3)
				start = rm
	if "warp=rule" in Dev.args():
		for rm in layout.rooms:
			if rm.rule != "":
				for other in layout.rooms:
					if other != rm and other.type != Room.Type.BOSS:
						other.visited = true
						other.cleared = true
				player.pos = _open_spot(rm.center() + Vector2(0, 2.5))
				start = rm
	if "warp=lock" in Dev.args() or "warp=key" in Dev.args():
		# dev: beside the floor's barred way, or at the room that holds its key
		for rm in layout.rooms:
			var hit: bool = rm.id == layout.key_room if "warp=key" in Dev.args() else (not layout.locks.is_empty() and rm.id == int(layout.locks[0].a))
			if hit:
				for other in layout.rooms:
					if other != rm and other.type != Room.Type.BOSS:
						other.visited = true
						other.cleared = true
				player.pos = _open_spot(rm.center() + Vector2(0, 2.5))
				start = rm
	if "warp=stairs" in Dev.args() or "warp=objective" in Dev.args() or "warp=altar" in Dev.args():
		# dev: at the fork (the stairs room), inside the route's own room, or at the altar
		for rm in layout.rooms:
			var hit: bool = rm.event == "altar" if "warp=altar" in Dev.args() else (rm.id == layout.exit_id if "warp=stairs" in Dev.args() else rm.objective != "")
			if hit:
				for other in layout.rooms:
					if other != rm and other.type != Room.Type.BOSS:
						other.visited = true
						other.cleared = true
				player.pos = _open_spot(rm.center() + Vector2(0, 2.5))
				start = rm
	if view:
		view.focus = Iso.to_world(player.pos)
	for pr in _party_runs():
		for k in pr.taken:
			_taken_before += float(pr.taken[k])
	_rooms_before = run.rooms_cleared
	if hunted() and not layout.boss_depth:
		after(2.5, func() -> void: Events.banner.emit("The Hunt", "Two signs of its trail lie on this floor, and its harbinger walks ahead"))
	if layout.depth > 3 and not Delve.band(layout.depth).is_empty():
		var b := Delve.band(layout.depth)
		after(3.0, func() -> void: Events.toast.emit("%s: %s." % [b.name, b.line], Color(0.72, 0.62, 1.0)))
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
		player.kindle = player.kindle_max()
		for a in Dev.args():
			if a.begins_with("cast="):
				# dev: cast=1,3 casts those spell slots in turn at the nearest lab foe
				# (the Kindled stops reading the mouse so the aim holds for captures)
				var order: Array = Array(a.substr(5).split(","))
				player.input_enabled = false
				for k in order.size():
					var slot := int(order[k])
					after(1.0 + k * 0.8, func() -> void:
						var t := nearest_hostile(player.team, player.pos, 14.0)
						if t:
							player.aim_point = t.pos
							player.aim = (t.pos - player.pos).normalized()
						player.kindle = player.kindle_max()
						player.press("a%d" % slot))
	if "rosterlab" in Dev.args() and not replica:
		_roster_lab()
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
	if "proplab" in Dev.args() and not replica:
		# dev: one of each dungeon object around the Kindled, to look at their
		# names, glow and prompts (the chest right beside it is the one in reach)
		var spots := [[Vector2(1.2, 0.0), "chest", {"tier": 1}], [Vector2(-3.0, -1.5), "chest", {"tier": 2}], [Vector2(3.5, -2.5), "relic_altar", {"tier": 1}],
			[Vector2(-4.0, 2.0), "ember_well", {}], [Vector2(4.0, 2.5), "shrine", {}], [Vector2(0.0, -4.0), "spring", {}]]
		for s in spots:
			var t := Vector2i(random_floor_near(player.pos + (s[0] as Vector2), 0.6))
			Prop.make(self, String(s[1]), t, (s[2] as Dictionary).duplicate())
	if "urnlab" in Dev.args() and not replica:
		# dev: a row of urns of every make beside the Kindled (the second of each
		# with something inside), struck one after another from 1.5 s
		var k := 0
		for mat in ["clay", "root", "gilded"]:
			for rich in [false, true]:
				var t := Vector2i(player.pos + Vector2(-2.5 + k * 1.0, -1.6))
				var u := Prop.make(self, "urn", t, {"mat": mat, "rich": rich})
				var delay := 1.5 + k * 0.45
				after(delay, func() -> void:
					if is_instance_valid(u) and not u.used:
						strike_props_circle(u.pos, 0.1, player, false))
				k += 1
		# and an Urnling, struck last: it bursts out instead of breaking
		var ut := Vector2i(player.pos + Vector2(-2.5 + k * 1.0, -1.6))
		var un := Prop.make(self, "urn", ut, {"mat": "clay", "rich": true, "urnling": true})
		after(1.5 + k * 0.45, func() -> void:
			if is_instance_valid(un) and not un.used:
				strike_props_circle(un.pos, 0.1, player, false))
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
	if layout.boss_depth and is_inside_tree():
		# the guardian's floor: a rumble from below once the title card lifts
		get_tree().create_timer(4.5, false).timeout.connect(_guardian_stirs)
	built = true
	_spoor()
	Events.player_died.connect(_on_player_died)
	Events.parry_success.connect(_on_ward)
	actor_died.connect(_on_actor_died)
	# the Hollow Below has its own music; every region its own walk and fight
	Audio.play_music("hollow" if run.delve else String(region.music))
	Audio.set_intensity(0.0)
	Audio.play_ambience(String(region.get("ambience", "amb_crypt")))
	var title: String = Delve.NAME if run.delve else String(region.name)
	# a title card already named the place on the way down
	if Game.ui == null or not Game.ui.card_pending:
		Events.banner.emit(title, String(Delve.depth_title(lay.region, lay.depth, run.delve)[0]))
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
	# each depth has its own mood: the region's ambient leaning toward the
	# floor's tint, a little darker the deeper it goes
	var fd := Delve.floor_def(layout.region, layout.depth, run.delve if run else false)
	var tint: Color = fd[1]
	env.ambient_light_color = region.ambient.lerp(Color(tint.r, tint.g, tint.b), 0.35 if tint.a > 0.0 else 0.0)
	# (raised from 0.84/0.78/0.70 by the second playtest: walls, floor and
	# obstacles must read beyond the lantern - darkness for tension, not for
	# hiding what blocks the way)
	env.ambient_light_energy = [1.08, 1.0, 0.92][Delve.floor_index(layout.depth, run.delve if run else false)]
	if run and run.delve:
		# every pass through the regions, the Hollow is darker
		env.ambient_light_energy *= Delve.gloom(layout.depth)
		if Delve.fractured(layout.depth):
			env.ambient_light_color = env.ambient_light_color.lerp(Color(0.5, 0.35, 0.8), 0.45)
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
	env.adjustment_brightness = float(Settings.get_value("brightness", 1.0))
	if view:
		view.set_environment(env)


## The floor's meshes; on a Fracture, a second region's stone in every odd room.
func _build_level() -> Node3D:
	var k := Delve.floor_index(layout.depth, run.delve) + 1
	var theme := LevelBuilder.LevelTheme.named(region.theme, k)
	var over := String(layout.world.get("fracture", ""))
	if over == "" or not EnemyDB.REGIONS.has(over):
		return LevelBuilder.build(grid, theme)
	return LevelBuilder.build(grid, theme, LevelBuilder.LevelTheme.named(EnemyDB.REGIONS[over].theme, k))


## Dev (`walllab`): one of each kind of thing a floor is built from, around
## where the Kindled starts - a waist-high wall inside the room, a pillar, a
## pit, a solid set piece and a walk-through one - to judge at a glance what
## reads as solid, as floor, as a drop.
func _wall_lab(lay: DungeonGen.Layout) -> void:
	var r := lay.room(lay.start_id)
	var c := Vector2i(r.center())
	var g := lay.grid
	for dx in range(-5, -2):
		g.put(c.x + dx, c.y - 2, TileGrid.WALL)
	g.put(c.x + 3, c.y - 2, TileGrid.PILLAR)
	for p in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3)]:
		g.put(c.x + p.x, c.y + p.y, TileGrid.PIT)
	var solid: String = {"rootmire": "stump", "throne": "column_fallen"}.get(lay.region, "sarcophagus")
	r.props.append({"kind": "dressing", "tile": c + Vector2i(-5, 2), "sheet": solid, "wide": true})
	r.props.append({"kind": "dressing", "tile": c + Vector2i(-1, 3), "sheet": "bone_heap"})
	if lay.region == "throne":
		r.props.append({"kind": "dressing", "tile": c + Vector2i(1, -3), "sheet": "statue"})


func _place_props() -> void:
	var flame: Color = region.flame
	for r in layout.rooms:
		for pd in r.props:
			var extra := {"flame": flame}
			if pd.has("variant"):
				extra["variant"] = pd.variant
			if pd.has("row"):
				extra["row"] = pd.row
			for k in ["mat", "rich", "id", "urnling", "route", "flame", "sheet", "event", "choice", "label", "ask", "vote", "low"]:
				if pd.has(k):
					extra[k] = pd[k]
			for more in ["anim", "tier"]:
				if pd.has(more):
					extra[more] = pd[more]
			if pd.kind == "site":
				extra.merge(DeepEvents.site_data(pd, layout.region, run.world), true)
			if pd.kind == "dressing":
				extra["sheet"] = pd.sheet
				if pd.get("wide", false):
					extra["solid_tiles"] = [pd.tile, pd.tile + Vector2i(1, 0)]
					extra["ox"] = 0.5
				elif DungeonGen.WALKABLE_DRESSING.has(String(pd.sheet)) or pd.get("low", false):
					extra["low"] = true      # underfoot: walked through, drawn behind whoever stands on it
				else:
					extra["solid"] = true
			if pd.kind == "chest":
				extra["tier"] = pd.get("tier", 1)
				if pd.get("sealed", false):
					extra["sealed"] = true
			if pd.kind == "sconce" and region.has("brazier"):
				extra["sheet"] = String(region.brazier)
			if r.id == grudge_room and pd.kind in ["torch", "candles", "brazier"] and not pd.has("flame"):
				# something that remembers you is in here: its fires burn red
				extra["flame"] = Color(1.0, 0.32, 0.25)
			if pd.has("phase"):
				extra["phase"] = pd.phase
			if pd.kind == "torch":
				extra["sheet"] = String(region.get("torch", "torch"))
			if pd.kind in ["brazier", "boss_brazier"] and region.has("brazier") and not pd.has("sheet"):
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


# --- barred ways: a vault's doors, a way back, a pale door ---------------------------

var lock_bars: Dictionary = {}     # lock index -> its bars
var has_key := false               # the party carries the vault's key


func _place_locks() -> void:
	for i in layout.locks.size():
		var lk: Dictionary = layout.locks[i]
		var bars: Array = []
		for t: Vector2i in lk.tiles:
			var s := PixelSprite.new()
			add_child(s)
			s.setup("pale_bars" if lk.kind == "pale" else "lock_bars", "shut")
			s.position = Iso.to_world(Vector2(t) + Vector2(0.5, 0.75), 0.0)
			set_tile_solid(t, true)
			bars.append(s)
		lock_bars[i] = bars
		# what opens it stands on the side you meet it from
		var here: Room = layout.room(int(lk.b if lk.kind == "pale" else lk.a))
		var other := int(lk.a if lk.kind == "pale" else lk.b)
		var d := here.door_to(other)
		if d.is_empty():
			continue
		var mid := Vector2.ZERO
		for t: Vector2i in d.tiles:
			mid += Vector2(t) + Vector2(0.5, 0.5)
		mid /= (d.tiles as Array).size()
		var inward := -Vector2(d.dir)
		var at := mid + inward * 2.0 + Vector2(inward.y, inward.x) * 3.0
		var kind := "lever" if lk.kind == "lever" else "lock_plate"
		var p := Prop.make(self, kind, Vector2i(_open_spot(at)), {"lock": i, "anim": "pale" if lk.kind == "pale" else ("key" if lk.kind == "key" else "up")})
		p.room_id = here.id


## A barred way opens, on every machine.
var charted := false


func open_lock(i: int) -> void:
	if i < 0 or i >= layout.locks.size() or layout.locks[i].open:
		return
	Net.rec(["unlock", i])
	var lk: Dictionary = layout.locks[i]
	lk.open = true
	for t: Vector2i in lk.tiles:
		grid.put(t.x, t.y, TileGrid.FLOOR)
		set_tile_solid(t, false)
	var col := Color(0.72, 0.62, 1.0) if lk.kind == "pale" else Color(1.0, 0.8, 0.45)
	for s in lock_bars.get(i, []):
		var bar: PixelSprite = s
		bar.play("open", true)
		bar.animation_finished.connect(func(_a): if is_instance_valid(bar): bar.visible = false, CONNECT_ONE_SHOT)
	var mid: Vector2 = Vector2(lk.tiles[(lk.tiles as Array).size() / 2]) + Vector2(0.5, 0.5)
	fx.burst(mid, 1.2, col, 22, 3.0, 0.7, 4.0)
	Audio.play_at("gate_open", mid, -2.0, 0.7)
	Audio.play_at("crumble", mid, -6.0, 1.3)
	minimap_changed.emit()


func _use_lock(prop: Prop, who: Player) -> void:
	var i := int(prop.data.get("lock", -1))
	match String(layout.locks[i].kind):
		"key":
			if not has_key:
				Audio.play("deny", -2.0)
				Events.toast.emit("Barred. Its key lies elsewhere on this floor, deep in.", Color(1.0, 0.8, 0.5))
				return
			carry_key(false)
			prop.used = true
			prop.sprite.play("open")
			_set_objective("", -1.0, SEAL_COL)
			open_lock(i)
			Events.banner.emit("The Vault Opens", "Whoever sealed this meant it to stay sealed")
			Chronicle.mark("vaults_opened")
			note_request("vault")
		"pale":
			prop.used = true
			who.hp = maxf(1.0, who.hp - who.max_hp * 0.2)
			fx.motes(who.pos, 0.6, Color(0.72, 0.62, 1.0), 16, 1.6, 0.9, 0.4)
			Audio.play("blood_pact", -4.0)
			open_lock(i)
			Events.toast.emit("It opens. It remembers the taste.", Color(0.72, 0.62, 1.0))


func _pull_lever(prop: Prop) -> void:
	prop.used = true
	prop.sprite.play("down")
	Audio.play_at("gate_close", prop.pos, -4.0, 1.4)
	open_lock(int(prop.data.get("lock", -1)))
	Events.toast.emit("Somewhere near the way you came, bars slide up. A short way back.", Color(1.0, 0.8, 0.5))
	Chronicle.mark("ways_back")


## This expedition hunts this region's guardian (the world it carries says so).
func hunted() -> bool:
	return (run.world.get("hunts", []) as Array).has(layout.region)


## One more thing learned about the quarry: it will be weaker for it (up to four).
func hunt_sign(how: String) -> void:
	run.hunt_signs += 1
	Chronicle.mark("hunt_signs")
	var n := mini(run.hunt_signs, HUNT_SIGNS)
	Events.banner.emit("The Hunt  %d of %d" % [n, HUNT_SIGNS], "%s. It will be %d%% weaker for it" % [how, int(round(n * HUNT_WEAKEN * 100.0))])
	Audio.play("ping", -2.0, 0.7)


const HUNT_SIGNS := 4
const HUNT_WEAKEN := 0.08


## The rule of the fight this machine stands in, while it lasts (the objective
## line is what every machine shares, and it goes out with the fight).
func rule_here() -> String:
	if current_room and current_room.rule != "" and not objective.is_empty() and not current_room.cleared:
		return current_room.rule
	return ""


## A floor someone has drawn: every room of it on every map.
func chart_floor() -> void:
	charted = true
	Net.rec(["chart"])
	minimap_changed.emit()


## A grown Grudge, half gone: it will not simply fall. It wards, heals a little
## and calls what it has gathered, once, and the words are its own history.
func grudge_reckoning(e: Enemy) -> void:
	var g: Dictionary = e.grudge
	var h: Array = g.get("history", [])
	Events.banner.emit("%s Will Not Fall" % e.display_name, String(h.back()) if not h.is_empty() else "It remembers you")
	e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.15)
	e.grudge_ward_t = 3.0
	e.invuln_t = 1.2
	fx.ring(e.pos, 5.0, GRUDGE_RED, 0.7, 0.3)
	fx.shake(0.5)
	Audio.play_at("boss_roar", e.pos, -5.0, 1.1)
	var r: Room = layout.room(e.room_id)
	for k in 3:
		var kin := _make_enemy(EnemyDB._filler(layout.region))
		kin.pos = foe_spot(e.pos + Vector2.from_angle(TAU * k / 3.0) * 2.0, 0.6)
		_scale(kin, layout.depth, int(Profile.data.world.get("memory", 0)))
		kin.room_id = r.id
		kin.spawn_t = 1.0
		kin.xp = 1
		kin.embers = 0
		add_actor(kin)
		register_enemy(kin)


## The party has the key: every map shows where it fits.
func carry_key(on: bool) -> void:
	has_key = on
	Net.rec(["key", on])
	if on and layout.vault_room >= 0:
		pings.append({"pos": layout.room(layout.vault_room).center(), "col": Color(1.0, 0.8, 0.45), "t": 10.0})
	minimap_changed.emit()


func _take_key(prop: Prop) -> void:
	prop.used = true
	prop.sprite.play("taken")
	if prop.light:
		prop.light.visible = false
	fx.burst(prop.pos, 1.6, Color(1.0, 0.85, 0.45), 24, 3.0, 0.7, 2.0, Vector2.UP, 1.2)
	Audio.play("relic", -3.0)
	Events.banner.emit("The Bone Key", "The barred vault lies back toward the start of the floor")
	_set_objective("CARRY THE KEY TO THE VAULT", -1.0, Color(1.0, 0.8, 0.45))
	carry_key(true)


## Where you fell. The lantern is cold; lighting it is not much, and it is yours.
func _relight(prop: Prop, who: Player) -> void:
	prop.used = true
	prop.sprite.play("lit")
	if not prop.light:
		prop._light(Color(1.0, 0.65, 0.35), 0.9, 4.5, Vector3(0, 0.6, 0.1))
	var fall: Dictionary = (run.world.get("falls", {}) as Dictionary).get(layout.region, {})
	var by := String(fall.get("by", "the dark"))
	who.kindle = who.kindle_max()
	who.heal(who.max_hp * 0.2)
	Party.award_xp(self, 15 + 10 * layout.depth, "lantern")
	Chronicle.clear_fall(layout.region)
	Chronicle.note("A cold lantern lit again, where %s had won." % by)
	note_request("lantern")
	fx.motes(prop.pos, 0.4, Color(1.0, 0.7, 0.4), 22, 1.8, 1.0, 0.4)
	Audio.play("hearth_feed", -3.0, 1.2)
	Events.banner.emit("You Fell Here", "To %s. The light is yours again." % by)
	if grudge_room >= 0:
		# it has not gone far: the lantern's light shows which way
		pings.append({"pos": layout.room(grudge_room).center(), "col": GRUDGE_RED, "t": 12.0})
		Events.toast.emit("Something passed this way. Its trail still burns on your map.", GRUDGE_RED)


# --- what is in a room to use ---------------------------------------------------------

## Whoever is there, on either side. Foes take a share of their health, so a falling
## column means the same at every tier; guardians are too great to be moved by it.
func _blast(at: Vector2, covers: Callable, foe_share: float, pal_share: float, by: Node, col: Color, burn := 0) -> void:
	var src: Player = by if by is Player else nearest_player(at)
	if src:
		for a in hostiles(Actor.Team.PLAYER):
			if a is Enemy and not (a as Enemy).def.get("boss", false) and covers.call(a):
				var e := a as Enemy
				var h := Hit.make(src, e.max_hp * foe_share * (0.5 if e.elite else 1.0), ["ability"])
				h.can_crit = false
				h.proc = false
				h.poise = 60.0
				h.burn = burn
				src.deal_hit(e, h)
				if not e.alive:
					note_request("room_kill")
	for p in active_players():
		if covers.call(p):
			var h := Hit.make(null, p.max_hp * pal_share, ["hazard"])
			h.can_crit = false
			h.burn = burn
			p.take_enemy_hit(h, null)
	fx.flash_light(at, 1.0, col, 3.0, 6.0, 0.3)


func room_device(p: Prop, by: Node) -> void:
	match p.kind:
		"strut":
			_fell_strut(p, by)
		"kindle_jar":
			_burst_jar(p, by)
		"rime_vent":
			_open_vent(p)


## A blow brings it down the way it was struck. Marked first: it falls on anyone.
func _fell_strut(p: Prop, by: Node) -> void:
	var from: Vector2 = (by as Actor).pos if by is Actor else p.pos + Vector2(0, -1)
	var dir := (p.pos - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var col := Color(1.0, 0.5, 0.22)
	var fall_t := 0.8
	p.sprite.play("shake")
	Audio.play_at("crumble", p.pos, -5.0, 0.7)
	fx.shape(Fx.Shape.RECT, p.pos, dir, Vector2(5.4, 2.6), Color(col.r, col.g, col.b, 0.3), col, fall_t + 0.05, {})
	after(fall_t, func() -> void:
		if not is_inside_tree() or not is_instance_valid(p):
			return
		p.sprite.play("down")
		p.stops_shots = false
		var covers := func(a: Actor) -> bool:
			var v: Vector2 = a.pos - p.pos
			var along := v.dot(dir)
			return along > -0.6 and along < 5.8 and absf(v.dot(dir.orthogonal())) < 1.5
		_blast(p.pos + dir * 2.7, covers, 0.55, 0.22, by, col)
		for k in 5:
			fx.burst(p.pos + dir * (0.8 + k * 1.1), 0.4, Color(0.6, 0.58, 0.55), 10, 3.5, 0.6, 9.0)
		fx.shake(0.5)
		Audio.play_at("crumble", p.pos + dir * 2.5, 2.0, 0.6))


## Ember in a jar: a short fuse, a hot breath, and whatever else nearby can burn.
func _burst_jar(p: Prop, by: Node) -> void:
	var col := Color(1.0, 0.5, 0.2)
	var r := 2.3
	var at := p.pos
	fx.shape(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(r * 2.0, r * 2.0), Color(col.r, col.g, col.b, 0.25), col, 0.45, {})
	Audio.play_at("ignite", at, -6.0, 1.3)
	after(0.4, func() -> void:
		if not is_inside_tree():
			return
		if is_instance_valid(p) and p.sprite:
			p.sprite.visible = false
			if p.light:
				p.light.visible = false
		var covers := func(a: Actor) -> bool:
			return a.pos.distance_to(at) <= r + a.radius
		_blast(at, covers, 0.3, 0.12, by, col, 2)
		fx.burst(at, 0.6, col, 34, 6.0, 0.6, 3.0)
		fx.ring(at, r, col, 0.3, 0.3)
		fx.shake(0.25)
		Audio.play_at("bloat", at, -3.0, 1.1)
		strike_props_circle(at, r, by, true))     # the next jar, the brambles, the roots


## A vent let go: cold spreads over the floor and takes the foes standing on it,
## fast enough that a frozen foe is a shattered one.
func _open_vent(p: Prop) -> void:
	p.sprite.play("spent")
	if p.light:
		p.light.visible = false
	var col := Color(0.55, 0.85, 1.0)
	Audio.play_at("gate_close", p.pos, -8.0, 1.8)
	Hazard.spawn(self, p.pos, 2.7, 3.2, Actor.Team.PLAYER, col, func(_h: Hazard, a: Actor) -> void:
		if a is Enemy and not (a as Enemy).def.get("boss", false):
			a.status.apply_chill(0.34))


func _place_gates() -> void:
	for r in layout.rooms:
		if not r.is_combat() and not (r.event in ["trial", "procession"]):
			continue
		var nodes: Array = []
		for d in r.doors:
			if d.secret:
				continue
			for t: Vector2i in d.tiles:
				var g := PixelSprite.new()
				add_child(g)
				g.setup(String(region.get("gate", "gate")), "closed")
				g.set_meta("lock", int(d.get("lock", -1)))
				g.position = Iso.to_world(Vector2(t) + Vector2(0.5, 0.5 if d.dir.y == 0 else (0.95 if d.dir.y < 0 else 0.15)), 0.0)
				g.visible = false
				g.set_meta("tile", t)
				nodes.append(g)
		gate_nodes[r.id] = nodes


## Doorways on the north and south of a room are framed by stone posts: an
## opening reads as a door, and its width as what it is. (Plain sprites, like
## the gates: nothing to replicate, every machine places the same.)
func _place_door_frames() -> void:
	var seen := {}
	var anim: String = {"rootmire": "rootmire", "throne": "throne"}.get(layout.region, "ossuary")
	for r in layout.rooms:
		for d in r.doors:
			if d.secret or d.dir.y == 0 or (d.tiles as Array).is_empty():
				continue
			var lo: Vector2i = d.tiles[0]
			var hi: Vector2i = d.tiles[0]
			for t: Vector2i in d.tiles:
				lo.x = mini(lo.x, t.x)
				hi.x = maxi(hi.x, t.x)
			for x in [lo.x - 1, hi.x + 1]:
				var t := Vector2i(x, lo.y)
				if seen.has(t) or grid.at(t.x, t.y) != TileGrid.WALL:
					continue
				seen[t] = true
				var p := PixelSprite.new()
				add_child(p)
				p.setup("door_post", anim)
				p.position = Iso.to_world(Vector2(t) + Vector2(0.5, 1.02), 0.0)


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
	if run.has_omen("hunted") or layout.route == "lair":
		gs = party_grudges()
	if not run.wounded.is_empty():
		# one that fled this expedition is still bleeding, and still here
		var w := party_grudges().filter(func(g): return run.wounded.has(String(g.id)))
		if not w.is_empty():
			gs = w
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
	for r in layout.rooms:
		if r.objective == "lair":
			grudge_room = r.id      # its own ground
	layout.room(grudge_room).grudge = true


# --- per-frame -----------------------------------------------------------------------

func _stage_tick(dt: float) -> void:
	for pg in pings:
		pg.t -= dt
	pings = pings.filter(func(pg): return pg.t > 0.0)
	if replica:
		if player:
			var rt := layout.room_at_tile(Vector2i(floori(player.pos.x), floori(player.pos.y)))
			if rt and rt != current_room:
				current_room = rt
				minimap_changed.emit()
		return
	if players.size() > 1:
		_coop_tick(dt)
	# the floor goes on while any Kindled stands: a host who bled out watches
	# the others win the room that brings it back (this used to stop every
	# wave and the room's clearing - the room stayed sealed for good)
	var up := player != null and player.alive
	if not up and active_players().is_empty():
		return
	run.elapsed += dt
	var t := Vector2i(floori(player.pos.x), floori(player.pos.y)) if player else Vector2i(-9999, -9999)
	if up:
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
				_start_encounter(pr, pl)
				break
	if up and current_room and not current_room.cleared and current_room.is_combat() and active_room == null:
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
	var spots := party_spots(start, maxi(1, Net.i.roster.size() if Net.active() else 1))
	if not Net.active():
		player = Player.new()
		player.pos = spots[0] if not spots.is_empty() else start.center() + Vector2(0, 2)
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
		# side by side on open floor, in plain view (see party_spots)
		var k := seats.find(pid)
		pl.pos = spots[k] if k < spots.size() else _floor_inside(start, start.center() + Vector2(-1.5 + slot, 2.0))
		add_actor(pl)
		pl.setup_from(Game.run_of(int(pid)))
		var col := Net.color_of(int(pid))
		pl.set_seat(col, mine)
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


var _fight_t := 0.0          # music: how long this machine's Kindled has been in a fight
var _elite_heard := {}
var _amb_t := 6.0


## The music follows the fight this machine's Kindled is in (on host and
## guests alike, from what is near it): the fight's layer swells while foes
## are awake close by, an elite's arrival strikes a sting, and the end of a
## real fight a quiet chord. Now and then the place makes a sound of its own.
func _music_watch(real: float) -> void:
	if player == null or not is_instance_valid(player) or boss != null:
		return
	var near := 0
	for a in hostiles(player.team):
		if a is Enemy and (a as Enemy).state != "spawn" and a.pos.distance_to(player.pos) < 12.0:
			near += 1
			var e := a as Enemy
			if e.elite and not _elite_heard.has(e.get_instance_id()):
				_elite_heard[e.get_instance_id()] = true
				Audio.sting("sting_elite", -3.0)
	if near > 0:
		_fight_t += real
		Audio.set_intensity(clampf(0.55 + 0.12 * near, 0.0, 1.0))
	else:
		if _fight_t > 4.0:
			Audio.sting("sting_clear", -6.0)
		_fight_t = 0.0
		Audio.set_intensity(0.0)
	_amb_t -= real
	if _amb_t <= 0.0:
		_amb_t = randf_range(7.0, 16.0)
		var pool: Array = AMB_ONESHOTS.get(layout.region, AMB_ONESHOTS.ossuary)
		var at := player.pos + Vector2.from_angle(randf() * TAU) * randf_range(5.0, 10.0)
		# every machine has its own (never sent on: a guest would hear the host's too)
		Net.mute += 1
		Audio.play_at(String(pool[randi() % pool.size()]), at, -8.0, randf_range(0.9, 1.1), 500)
		Net.mute -= 1


const AMB_ONESHOTS := {"ossuary": ["amb_drip", "amb_chain", "amb_stone", "amb_whisper"], "rootmire": ["amb_drip", "amb_creak", "amb_bubble", "amb_stone"],
	"throne": ["amb_bell", "amb_stone", "amb_chain", "amb_gust"]}


func _stage_process(real: float) -> void:
	_ambient_air(real)
	_music_watch(real)
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
			if layout.offer.size() >= 2:
				Events.toast.emit("%d ways down. Each shapes the floor below." % layout.offer.size(), Color(1.0, 0.8, 0.55))
			else:
				Events.toast.emit("Stairs descend into the dark. The Hearthstone can carry you home.", Color(1.0, 0.8, 0.55))
		if r.landmark != "":
			# a great sight, and one more for the record of what this Kindled has seen
			Profile.note_seen("landmarks", r.landmark)
			if not replica:
				var ld := DungeonGen.landmark_def(r.landmark)
				Events.banner.emit(String(ld.get("name", "")), String(ld.get("line", "")))
		if r.type == Room.Type.EVENT:
			var msg := {"survivor": "Someone is breathing in here.", "artisan": "A grindstone, still turning. Nobody near it.", "well": "An Ember Well glows with molten sunlight.", "trial": "A trial altar thrums. It wants a challenger.", "echo": "Someone is already here. Someone who was you, once.",
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

var _fight_began := 0.0


## Thin Walls: foes break in through the room's doors, mid-fight.
func _break_in(r: Room) -> void:
	var ids := EnemyDB.party_extras(rng, layout.region, layout.depth, [], 3)
	var memory := int(Profile.data.world.get("memory", 0))
	Events.toast.emit("The walls are thin here. Something is coming through.", Omens.COLOR)
	for k in ids.size():
		var door: Dictionary = r.doors[k % r.doors.size()]
		var t: Vector2i = door.tiles[0]
		var e := _make_enemy(String(ids[k]))
		e.pos = arena_spot(r, Vector2(t) - Vector2(door.dir) * 2.0)
		_scale(e, layout.depth, memory)
		_coop_scale(e)
		e.xp = 0
		e.room_id = r.id
		e.spawn_t = 0.8
		add_actor(e)
		register_enemy(e)


func _start_encounter(r: Room, by: Player = null) -> void:
	if OS.is_debug_build():
		print("[dungeon] encounter start room %d (%s) waves=%d" % [r.id, r.type_name(), r.encounter.size()])
	active_room = r
	wave = 0
	_fight_began = elapsed
	if r.rule != "":
		var ru: Dictionary = DeepEvents.RULES[r.rule]
		Events.banner.emit(String(ru.name), String(ru.line))
		_set_objective(String(ru.name).to_upper(), -1.0, ru.col)
		Chronicle.mark("rules_met")
	if r.harbinger and hunted():
		after(0.6, func() -> void:
			var g := EnemyDB.get_def(String(region.boss))
			var e := _champion("Harbinger of %s" % String(g.get("name", "the Guardian")).trim_prefix("The "), 2.2)
			if e:
				e.set_meta("harbinger", true)
				Events.banner.emit("Its Harbinger", "It went ahead of its master. It knows the way"))
	if String(Delve.band(layout.depth).get("id", "")) == "crowded" and r.type in [Room.Type.COMBAT, Room.Type.ELITE] and not r.get_meta("crowded", false):
		r.set_meta("crowded", true)
		r.encounter = r.encounter.duplicate()
		r.encounter.append(EnemyDB.party_extras(rng, layout.region, layout.depth, [], 2))
	# three or four Kindled: the room calls one more, smaller wave of flankers
	# and marksmen when its own are done
	if players.size() >= 3 and r.type in [Room.Type.COMBAT, Room.Type.ELITE] and not r.get_meta("party_wave", false):
		r.set_meta("party_wave", true)
		r.encounter = r.encounter.duplicate()
		r.encounter.append(EnemyDB.party_extras(rng, layout.region, layout.depth, [], players.size()))
	_pull_party_in(r, by if by else player)
	# a new fight counts its own foes only (a split's halves or a riser from
	# the last fight used to be carried in and could hold this room shut)
	room_enemies.clear()
	_set_gates(r, true)
	_arena_room = -1
	arena_of(r)
	if r.type == Room.Type.BOSS:
		_start_boss(r)
		return
	_spawn_wave(r)
	if r.grudge and not grudge_spawned:
		_spawn_grudge(r)
	if r.objective != "" and not replica:
		_begin_objective(r)


func _spawn_wave(r: Room) -> void:
	if r.objective == "gauntlet" and not replica:
		_ash_fall(r)
	var ids: Array = (r.encounter[wave] as Array).duplicate() if wave < r.encounter.size() else []
	var spots := r.spawns.filter(func(t): return grid.at(t.x, t.y) == TileGrid.FLOOR)
	spots.shuffle()
	var far: Array = spots.filter(func(t): return (Vector2(t) + Vector2(0.5, 0.5)).distance_to(player.pos) > 4.5)
	if far.size() >= ids.size():
		spots = far
	var elite_done := false
	# past the first pass, the Hollow's regions bleed together: one foe of
	# the next region takes a place in some fights
	var bleed := Delve.bleed_region(layout.depth) if run.delve else ""
	if bleed != "" and not ids.is_empty() and rng.randf() < 0.45:
		var guest := EnemyDB.party_extras(rng, bleed, layout.depth, [], 1)
		var slot := ids.find(ids.filter(func(i): return not EnemyDB.get_def(String(i)).has("pack")).front()) if ids.any(func(i): return not EnemyDB.get_def(String(i)).has("pack")) else -1
		if not guest.is_empty() and slot >= 0:
			ids[slot] = guest[0]
	var n_own := ids.size()
	if players.size() > 1:
		# about 30% more foes per extra Kindled, chosen for what they add
		# (flankers, back-line pressure) and placed from the far side
		var extra := int(round(ids.size() * 0.3 * (players.size() - 1)))
		ids.append_array(EnemyDB.party_extras(rng, layout.region, layout.depth, ids, extra))
		if spots.size() > n_own:
			var c := Vector2.ZERO
			for p in players:
				c += p.pos
			c /= players.size()
			var rest := spots.slice(n_own)
			rest.sort_custom(func(a, b): return (Vector2(a) - c).length_squared() > (Vector2(b) - c).length_squared())
			spots = spots.slice(0, n_own) + rest
	var share := 1.0
	var closing := false
	var route_embers := float(DungeonGen.ROUTES.get(layout.route, {}).get("embers", 1.0))
	if players.size() > 1:
		var own_v := 0.0
		var all_v := 0.0
		for k in ids.size():
			var v := float(EnemyDB.get_def(String(ids[k])).get("xp", 1))
			all_v += v
			if k < n_own:
				own_v += v
		closing = r.get_meta("party_wave", false) and wave == r.encounter.size() - 1
		share = Party.PARTY_WAVE_SHARE if closing else Party.wave_share(own_v, all_v, players.size())
	var tempered := run.has_omen("tempered") and r.type != Room.Type.ELITE
	var memory := int(Profile.data.world.get("memory", 0)) + int(region.get("memory_bonus", 0))
	for i in ids.size():
		var id: String = ids[i]
		var t: Vector2i = spots[i % spots.size()] if not spots.is_empty() else Vector2i(r.center())
		var e := _make_enemy(id)
		# a spawn tile that is no longer open (a wall of ice, brambles), or the
		# room's middle as a last resort, becomes the arena's nearest open spot
		e.pos = arena_spot(r, Vector2(t) + Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7)))
		_scale(e, layout.depth, memory)
		_coop_scale(e)
		# a party shares out what its extra foes pay (Party.wave_share)
		if closing:
			# a big party's closing wave is for the fight: it pays no Embers or
			# experience (measured with -- economy: even 1 XP each lifted a
			# four-player party's XP to ~1.5x solo)
			e.xp = 0
			e.embers = 0
			e.set_meta("share", share)
		elif share < 1.0:
			e.xp = maxi(1, int(round(e.xp * share)))
			e.embers = int(round(e.embers * share))
			e.set_meta("share", share)
		if route_embers != 1.0:
			e.embers = int(round(e.embers * route_embers))     # the way down's spoils
		var swarm := EnemyDB.get_def(id).has("pack")
		if r.type == Room.Type.ELITE and not elite_done and not swarm:
			var ea := r.elite_affix if EnemyDB.affix_ok(id, r.elite_affix) else EnemyDB.roll_affix(rng, id)
			e.make_elite(ea, _second_affix(ea, id))
			elite_done = true
		elif r.elite_affix == "" and rng.randf() < 0.04 * layout.depth + Difficulty.elite_chance(run.tier) + _unbound_chance() and not swarm:
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
	var is_boss: bool = e.def.get("boss", false)
	# a guardian is not just more health for more Kindled: a little more,
	# a quicker tempo, and its call for help (Dungeon._guardian_call)
	e.max_hp *= 1.0 + (0.4 if is_boss else 0.35) * extra
	e.hp = e.max_hp
	if is_boss:
		e.tempo = 1.0 + 0.07 * extra
	# a party splits the blows and raises its fallen: each foe hits a little
	# harder so each Kindled is pressed about as hard as alone (measured with
	# src/dev/scaling_eval.gd: without this a party member took about half
	# the damage per room a solo Kindled did)
	e.damage *= 1.0 + 0.1 * extra


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


## What this floor can show, loaded now. A foe or a find seen for the first time
## used to load in the frame it appeared, up to 60 ms in the middle of a fight;
## this is the floor's own loading moment, when nobody is fighting.
static var _kept: Dictionary = {}


func _warm_up() -> void:
	var t := Dev.tick()
	var ids: Array = (region.pool as Array).duplicate()
	ids.append(String(region.boss))
	for id in ids:
		var def := EnemyDB.get_def(String(id))
		if def.is_empty() or _kept.has(id):
			continue
		_kept[id] = load(String(def.script))     # (held: an unreferenced script is dropped)
		SpriteLib.get_sheet(String(def.sheet))
	for sheet in Pickup.SHEETS.values():
		SpriteLib.get_sheet(String(sheet))
	Dev.lap("warm up", t, 0.0)


## The Hungry Floor: what comes here is quicker, and worth more.
func _hungry(e: Enemy) -> void:
	if active_room and active_room.rule == "hungry":
		e.speed *= 1.25
		e.embers *= 2


func _make_enemy(id: String) -> Enemy:
	var t := Dev.tick()
	var def := EnemyDB.get_def(id)
	var scr: GDScript = load(def.script)
	var e: Enemy = scr.new()
	e.configure(id)
	Dev.lap("foe " + id, t, 1.0)
	return e


func register_enemy(e: Enemy) -> void:
	# everything met goes in the bestiary: waves, bosses, summons, Grudges
	Profile.note_seen("enemies", e.id)
	if active_room == null:
		return     # no fight to hold open: it roams the open floor
	e.room_id = active_room.id
	if not room_enemies.has(e):
		room_enemies.append(e)
		_hungry(e)


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
	e.pos = arena_spot(r, Vector2(t) + Vector2(0.5, 0.5))
	_scale(e, layout.depth, int(Profile.data.world.get("memory", 0)))
	e.make_grudge(g)
	e.hp = e.max_hp * float(run.wounded.get(String(g.id), 1.0))     # (it fled here, still bleeding)
	e._wound_checked = run.wounded.has(String(g.id)) or r.objective == "lair"     # it will not run twice, nor from its own ground
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
			kin.pos = foe_spot(e.pos + Vector2.from_angle(TAU * k / 2.0) * 1.5, 0.6)
			_scale(kin, layout.depth, int(Profile.data.world.get("memory", 0)))
			kin.room_id = r.id
			kin.spawn_t = 1.2
			add_actor(kin)
			register_enemy(kin)
	var slew := int(g.get("slew", 1))
	var count := {1: "It killed you once", 2: "It killed you twice"}.get(slew, "It has killed you %d times" % slew) as String
	var owner_id := int(g.get("owner", 0))
	var whose := "%s's Grudge. " % Net.name_of(owner_id) if owner_id != 0 and Net.active() and Net.party_size() > 1 else ""
	var marks := ""
	for m in g.get("marks", []):
		marks += " " + String(Profile.GRUDGE_MARKS[m].banner)
	var lesson := marks + " It has learned to close the distance." if String(g.get("learned", "ward")) == "closer" else marks + " It has learned to ward your blows."
	Events.banner.emit(String(g.name), "%s%s. %s It carries %d Embers." % [whose, count, lesson, int(g.embers)])
	fx.ring(e.pos, 3.0, GRUDGE_RED, 1.2, 0.3)
	fx.shake(0.3)
	print("[dungeon] grudge %s (%s Lv%d) spawned in room %d" % [g.name, g.enemy, int(g.level), r.id])
	Audio.play("boss_roar", -6.0, 1.3)


func _update_encounter(dt: float) -> void:
	room_enemies = room_enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	_tend_objective(dt)
	_watch_t -= dt
	if _watch_t <= 0.0:
		_watch_t = 0.5
		_watch_arena(0.5)
	if run.has_omen("thin_walls") and active_room and active_room.is_combat() and active_room.type != Room.Type.BOSS and not active_room.get_meta("thin", false) and room_enemies.size() <= 2 and elapsed > _fight_began + 4.0:
		active_room.set_meta("thin", true)
		_break_in(active_room)
	if room_enemies.is_empty() and _rising == 0 and elapsed >= _clear_hold and active_room.type != Room.Type.BOSS:
		wave += 1
		if wave < active_room.encounter.size():
			_spawn_wave(active_room)
		else:
			_room_cleared()


# --- the arena: where a sealed fight is fought ---------------------------------------
# (the second playtest's sealed room: a Bonecaller backed against a door raised
# its husks in the passage between two closed gates - unreachable, and counted)

var _arena := {}                 # tile -> true: the sealed room's floor the party can reach
var _arena_room := -1
var _clear_hold := 0.0           # (stage time) a split's halves are on their way: not won yet
var _watch_t := 0.0
var arena_fixes := 0             # foes the watchdog brought back (tests, the debug log)


## The tiles of `r` its fight may use: the room's own tiles that the party
## (or the room's middle) reaches across open floor - never the passage
## between two gates, a neighbour's floor or a walled-off pocket. Ice walls
## count as floor (they melt), so do pits (flyers hold them) and the small
## solid props a foe walks around.
func arena_of(r: Room) -> Dictionary:
	if _arena_room == r.id and not _arena.is_empty():
		return _arena
	var temp := {}
	for p in props:
		if is_instance_valid(p) and p.kind == "icewall":
			temp[p.tile] = true
	var q: Array[Vector2i] = []
	var out := {}
	for p in active_players():
		var pt := Vector2i(floori(p.pos.x), floori(p.pos.y))
		if grid.room_at(pt.x, pt.y) == r.id and not out.has(pt):
			out[pt] = true
			q.append(pt)
	var c := Vector2i(_floor_inside(r, r.center()))
	if not out.has(c):
		out[c] = true
		q.append(c)
	var head := 0
	while head < q.size():
		var t := q[head]
		head += 1
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := t + dv
			if out.has(n) or grid.room_at(n.x, n.y) != r.id:
				continue
			var k := grid.at(n.x, n.y)
			if k == TileGrid.WALL or k == TileGrid.VOID or k == TileGrid.GATE or (k == TileGrid.PILLAR and not temp.has(n)):
				continue
			out[n] = true
			q.append(n)
	_arena = out
	_arena_room = r.id
	return out


func _open_in(ar: Dictionary, t: Vector2i) -> bool:
	return ar.has(t) and grid.at(t.x, t.y) == TileGrid.FLOOR and not grid.box_blocked(Vector2(t) + Vector2(0.5, 0.5), 0.4)


## The open arena spot nearest to `want` (itself when it is one).
func arena_spot(r: Room, want: Vector2) -> Vector2:
	var ar := arena_of(r)
	var wt := Vector2i(floori(want.x), floori(want.y))
	if _open_in(ar, wt):
		return want if not grid.box_blocked(want, 0.3) else Vector2(wt) + Vector2(0.5, 0.5)
	var seen := {wt: true}
	var q: Array[Vector2i] = [wt]
	var head := 0
	while head < q.size() and head < 6000:
		var t := q[head]
		head += 1
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n := t + dv
			if seen.has(n) or not grid.inb(n.x, n.y):
				continue
			seen[n] = true
			if _open_in(ar, n):
				return Vector2(n) + Vector2(0.5, 0.5)
			q.append(n)
	return _floor_inside(r, r.center())


## Where a foe may appear near `p` (summons, a split's halves, risers, adds, a
## hop or a burrow's end): open floor near it - and while a room is sealed,
## inside that room's arena.
func foe_spot(p: Vector2, r: float, _room_id := -1) -> Vector2:
	var want := random_floor_near(p, r)
	if active_room == null:
		return want
	return arena_spot(active_room, want)


var _door_tiles := {}


## A doorway's tile (where a room's gate stands when sealed, and the passage
## tiles of its door): Rimewall never raises ice there.
func is_door_tile(t: Vector2i) -> bool:
	if _door_tiles.is_empty():
		for rid in gate_nodes:
			for g in gate_nodes[rid]:
				_door_tiles[g.get_meta("tile")] = true
		for r in layout.rooms:
			for dd in r.doors:
				for dt in dd.tiles:
					_door_tiles[dt] = true
		_door_tiles[Vector2i(-1, -1)] = true    # (made)
	return _door_tiles.has(t)


var _drop_seq := 0


## A fight is on around this machine's Kindled (host: an encounter; a guest:
## its room's gates stand closed): the Satchel holds gear as it is.
func fight_on() -> bool:
	if not replica:
		return active_room != null
	var r := current_room
	if r == null:
		return false
	for g in gate_nodes.get(r.id, []):
		var t: Vector2i = g.get_meta("tile")
		if grid.at(t.x, t.y) == TileGrid.GATE:
			return true
	return false


## A find's id, unique within the expedition (run / depth / count): what the
## Satchel banks once.
func next_drop() -> String:
	_drop_seq += 1
	return "%s/%d/%d" % [run.run_id if run.run_id != "" else "solo", layout.depth, _drop_seq]


## A split's halves (or the like) are on their way: the fight is not won yet.
func hold_clear(sec: float) -> void:
	_clear_hold = maxf(_clear_hold, elapsed + sec)


## Every half second of a fight: a counted foe that has been outside the arena
## for a moment and a half (raised beyond a gate, hopped into a passage, left
## on a gate tile, knocked into a pocket) is brought back into the room. The
## fight stays the fight - nothing is opened or won for it.
func _watch_arena(step: float) -> void:
	var r := active_room
	if r == null:
		return
	var ar := arena_of(r)
	for e: Enemy in room_enemies:
		if not is_instance_valid(e) or not e.alive or e.state == "spawn" or e.ghost:
			continue
		var t := Vector2i(floori(e.pos.x), floori(e.pos.y))
		var inside := ar.has(t) and grid.at(t.x, t.y) != TileGrid.GATE
		if not inside and e.flying and grid.room_at(t.x, t.y) == r.id and grid.at(t.x, t.y) == TileGrid.PIT:
			inside = true
		var out := 0.0 if inside else float(e.get_meta("out_t", 0.0)) + step
		e.set_meta("out_t", out)
		if out >= 1.5:
			_bring_back(e, arena_spot(r, e.pos), "outside")


func _bring_back(e: Enemy, to: Vector2, why: String) -> void:
	arena_fixes += 1
	if OS.is_debug_build():
		print("[dungeon] arena watchdog: %s (%s) room %d at %s -> %s" % [e.id, why, active_room.id if active_room else -1, e.pos, to])
	fx.motes(e.pos, 0.4, Color(0.45, 1.0, 0.9), 8, 1.4, 0.6, 0.3)
	fx.shape(Fx.Shape.SIGIL, to, Vector2.RIGHT, Vector2(1.6, 1.6), Color(0.3, 0.95, 0.85, 0.35), Color(0.5, 1.0, 0.9, 1.0), 0.5, {"glow": 1.4})
	e.pos = to
	e.vel = Vector2.ZERO
	e.push = Vector2.ZERO
	e.set_meta("out_t", 0.0)


func _room_cleared() -> void:
	var r := active_room
	_arena_room = -1
	_arena = {}
	if OS.is_debug_build():
		print("[dungeon] room %d cleared" % r.id)
	active_room = null
	r.cleared = true
	if r.rule != "" and r.type != Room.Type.BOSS:
		note_request("rule")
	if not objective.is_empty():
		_set_objective("", -1.0, SEAL_COL)     # (its task is done, whatever it was)
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
	# every Kindled is credited the room (it used to go to the host alone)
	Party.award_xp(self, 6 + 3 * layout.depth, "room")
	_spawn_reward(r)


func _spawn_reward(r: Room) -> void:
	var c := _open_spot(r.center())
	match r.reward:
		"rule":
			Prop.make(self, "chest", Vector2i(c), {"tier": 2})
		"key":
			Prop.make(self, "key_altar", Vector2i(c), {})
			for i in 6:
				Pickup.spawn(self, "ember", c + Vector2(1.0, 1.0), 3)
			Events.banner.emit("It Was Guarding Something", "A key lies here. Far from any door you have seen")
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
		"seals":
			# the Trial of Ash's warded hall, won
			Prop.make(self, "relic_altar", Vector2i(c), {"tier": 2})
			_rune_drop(c + Vector2(1.5, 0))
			for i in 8 + layout.depth * 2:
				Pickup.spawn(self, "ember", c, 3)
			Events.banner.emit("The Ash Hall Falls", "Its spoils are yours")
		"vault":
			_open_vault(r, c)
		"rift":
			Prop.make(self, "chest", Vector2i(c), {"tier": 2})
			Pickup.spawn(self, "sunshard", c + Vector2(1.0, 0.0), 1)
			_rune_drop(c + Vector2(-1.2, 0.4))
			Chronicle.mark("rifts_closed")
			Events.banner.emit("The Rift Closes", "For a moment, the Undervault remembers what shape it was")
		"workshop":
			# a forgotten alchemist's bench: what the fight was guarding
			Prop.make(self, "relic_altar", Vector2i(c), {"tier": 2})
			_reagent_drop(c + Vector2(1.2, 0.4), "gloamcap", 1.0)
			Pickup.spawn(self, "material", c, 2, {"id": "ember_core"})
			Events.banner.emit("A Forgotten Workshop", "Someone was distilling something here, long ago")
		"breach":
			Prop.make(self, "chest", Vector2i(c), {"tier": 3})
			_maybe_blueprint(c + Vector2(1.5, 0.4), 0.6)
			_rune_drop(c + Vector2(-1.5, 0.4))
			for i in 10:
				Pickup.spawn(self, "ember", c, 5)
			Chronicle.mark("breach_won")
			Events.banner.emit("The Breach Holds", "For now")
		"procession":
			Prop.make(self, "chest", Vector2i(c), {"tier": 2})
			_maybe_blueprint(c + Vector2(1.5, 0.4), 0.35)
			for i in 6:
				Pickup.spawn(self, "ember", c, 3)
			Chronicle.mark("procession")
			Chronicle.note("A bier opened, far below. What walked behind it walks no more.")
			Events.banner.emit("The Procession Ends", "Its last gift was meant for someone else")
		"trial":
			Pickup.spawn(self, "sunshard", c, 1)
			_rune_drop(c + Vector2(1.5, 0))
			Prop.make(self, "relic_altar", Vector2i(c) + Vector2i(0, 2), {"tier": 3})
			for i in 10:
				Pickup.spawn(self, "ember", c, 4)
			Events.banner.emit("Trial Complete", "The Undervault grudgingly yields its prize")


func _open_spot(p: Vector2) -> Vector2:
	var t := Vector2i(floori(p.x), floori(p.y))
	for rad in 8:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := t + Vector2i(dx, dy)
				if grid.at(q.x, q.y) == TileGrid.FLOOR and grid.at(q.x, q.y - 1) == TileGrid.FLOOR and grid.at(q.x, q.y + 1) == TileGrid.FLOOR:
					return Vector2(q) + Vector2(0.5, 0.5)
	return p


## Seals (closed) or releases a room's doors. The grid, the nav grid and the
## seal sprites always change together, so what you see is what blocks.
## This gate stands in a way that is still barred.
func behind_bars(g: Node) -> bool:
	var li := int(g.get_meta("lock", -1))
	return li >= 0 and not layout.locks[li].open


func _set_gates(r: Room, closed: bool) -> void:
	Net.rec(["gate", r.id, closed])
	Net.mute += 1
	_seal(r, closed)
	Net.mute -= 1


func _seal(r: Room, closed: bool) -> void:
	var soul := Color(0.45, 1.0, 0.9)
	for g in gate_nodes.get(r.id, []):
		if behind_bars(g):
			continue     # a room's seal never touches a barred way
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
			if not a.alive:
				continue
			var at := Vector2i(floori(a.pos.x), floori(a.pos.y))
			if (not a.flying and grid.box_blocked(a.pos, a.box())) or grid.at(at.x, at.y) == TileGrid.GATE:
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


## Co-op: a room sealing never shuts a friend outside - the light draws them
## in. They arrive just inside the door the fight was started through (beside
## whoever started it), not in the middle of the room, which may hold a
## pillar, a pit or the fight itself: on open floor they can move from, clear
## of walls, props, hazards, foes and each other (see regroup_spots).
func _pull_party_in(r: Room, by: Player = null) -> void:
	var inside: Array = []
	var outside: Array = []
	for pl in players:
		if not is_instance_valid(pl) or not pl.alive:
			continue
		if r.contains_tile(Vector2i(floori(pl.pos.x), floori(pl.pos.y))):
			inside.append(pl)
		else:
			outside.append(pl)
	if inside.is_empty() or outside.is_empty():
		return
	var lead: Player = by if by != null and inside.has(by) else inside[0]
	var door := door_near(r, lead.pos)
	var taken: Array = inside.map(func(p): return p.pos)
	var spots := regroup_spots(r, door, outside.size(), taken)
	for k in outside.size():
		var pl: Player = outside[k]
		var to: Vector2 = spots[k] if k < spots.size() else _floor_inside(r, lead.pos)
		var from := pl.pos
		fx.motes(from, 0.4, Color(0.45, 1.0, 0.9), 14, 2.0, 0.8, 0.4)
		fx.flash_light(from, 0.8, Color(0.45, 1.0, 0.9), 2.0, 4.0, 0.35)
		pl.pos = to
		pl.vel = Vector2.ZERO
		pl.push = Vector2.ZERO
		pl.invuln_t = maxf(pl.invuln_t, 0.75)
		fx.ring(to, 1.2, Color(0.45, 1.0, 0.9), 0.35, 0.25)
		fx.motes(to, 0.2, Color(0.45, 1.0, 0.9), 10, 1.4, 0.7, 0.5)
		fx.flash_light(to, 0.8, Color(0.45, 1.0, 0.9), 2.4, 4.5, 0.4)
		Party.tell(pl, "The light draws you to %s." % Net.name_of(lead.peer_id), Color(0.6, 1.0, 0.92))
		print("[dungeon] regroup: %s drawn from (%.1f, %.1f) to (%.1f, %.1f) by room %d's door toward room %d" % [
			Net.name_of(pl.peer_id), from.x, from.y, to.x, to.y, r.id, int(door.get("to", -1))])


## Where the party appears on a new floor: open floor near the start room's
## middle, room to move around each, apart from each other, and in plain view
## (no pillar or wall just south of them: the camera looks over that side, and
## a Kindled behind one is drawn only as its silhouette).
func party_spots(r: Room, n: int) -> Array:
	var c := r.center() + Vector2(0, 2)
	var tiles: Array = []
	# the room's own floor tiles (r.cells are map cells, not tiles)
	for y in range(r.rect.position.y, r.rect.end.y):
		for x in range(r.rect.position.x, r.rect.end.x):
			if grid.room_of[y * grid.width + x] == r.id:
				tiles.append(Vector2i(x, y))
	tiles.sort_custom(func(a, b): return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(c) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(c))
	var inner := r.rect.grow(-1)
	var out: Array = []
	for strict in [true, false]:
		for t: Vector2i in tiles:
			if out.size() >= n:
				return out
			if not safe_spot(t, inner, out):
				continue
			if strict and (grid.blocks_move(t.x, t.y + 1) or grid.blocks_move(t.x, t.y + 2)):
				continue
			out.append(Vector2(t) + Vector2(0.5, 0.5))
	return out


## The door of `r` closest to `p` (the one a Kindled at `p` just came through).
func door_near(r: Room, p: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for d in r.doors:
		if d.secret:
			continue
		for t: Vector2i in d.tiles:
			var dd := (Vector2(t) + Vector2(0.5, 0.5)).distance_squared_to(p)
			if dd < bd:
				bd = dd
				best = d
	return best


## Where `n` Kindled can safely arrive in room `r` through `door`: floor
## reached from just inside that door (nearest first, so they appear at the
## threshold the fight began from), at least a tile in from the room's edge
## (no closing seal can catch them), with open ground around, no wall, prop,
## pit or hazard under them, no foe at arm's length and apart from each other
## and from `taken`. Fewer than `n` when the room cannot give that many.
func regroup_spots(r: Room, door: Dictionary, n: int, taken: Array = []) -> Array:
	var out: Array = []
	var queue: Array = []
	var seen := {}
	var inward: Vector2i = -(door.get("dir", Vector2i.ZERO) as Vector2i)
	for t: Vector2i in door.get("tiles", []):
		var s: Vector2i = t + inward
		if not seen.has(s):
			seen[s] = true
			queue.append(s)
	if queue.is_empty():
		var c := Vector2i(floori(r.center().x), floori(r.center().y))
		seen[c] = true
		queue.append(c)
	var inner := r.rect.grow(-1)
	var used: Array = taken.duplicate()
	var head := 0
	while head < queue.size() and out.size() < n:
		var t: Vector2i = queue[head]
		head += 1
		if safe_spot(t, inner, used):
			var c := Vector2(t) + Vector2(0.5, 0.5)
			out.append(c)
			used.append(c)
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var q: Vector2i = t + d
			if not seen.has(q) and r.rect.has_point(q) and grid.at(q.x, q.y) == TileGrid.FLOOR:
				seen[q] = true
				queue.append(q)
	return out


## Can a Kindled be put down on tile `t` (see regroup_spots)?
func safe_spot(t: Vector2i, inner: Rect2i, used: Array) -> bool:
	if not inner.has_point(t) or grid.at(t.x, t.y) != TileGrid.FLOOR:
		return false
	var c := Vector2(t) + Vector2(0.5, 0.5)
	if grid.box_blocked(c, 0.45):
		return false
	var open := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and grid.at(t.x + dx, t.y + dy) == TileGrid.FLOOR:
				open += 1
	if open < 6:
		return false     # wedged between props: no room to move or dodge
	for h in hazards:
		if is_instance_valid(h) and h.pos.distance_to(c) < h.radius + 0.6:
			return false
	for a in actors:
		if is_instance_valid(a) and a.alive and a.team == Actor.Team.ENEMY and a.pos.distance_to(c) < a.radius + 1.4:
			return false
	for u in used:
		if (u as Vector2).distance_to(c) < 1.1:
			return false
	return true


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
	# the open floor tile of this room nearest to `p` (the room's own tiles:
	# its centre may be a pit, a wall or a pillar)
	var best := r.center()
	var bd := INF
	for y in range(r.rect.position.y, r.rect.end.y):
		for x in range(r.rect.position.x, r.rect.end.x):
			if grid.at(x, y) != TileGrid.FLOOR or grid.room_of[y * grid.width + x] != r.id:
				continue
			var c := Vector2(x, y) + Vector2(0.5, 0.5)
			var d := c.distance_squared_to(p)
			if d < bd and not grid.box_blocked(c, 0.4):
				bd = d
				best = c
	return best


# --- boss ----------------------------------------------------------------------------

func _start_boss(r: Room) -> void:
	_boss_flasks = player.flask if player else 0
	Audio.stop_music(1.0)
	var c := r.center()
	var at := c + Vector2(0, -3)
	_boss_entrance(at)
	after(ENTRANCE, func() -> void:
		var e := _make_enemy(String(region.boss))
		e.pos = at
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
			_echo_t = 7.0
		add_actor(e)
		register_enemy(e)
		boss = e
		var form := "" if run.delve else Guardians.form_of(String(region.boss), layout.region, run.seed, layout.depth, run.world)
		if hunted():
			# the quarry: always its rarer form, weaker for all that was learned on the way
			form = String(Guardians.FORMS.get(String(region.boss), {}).get("id", ""))
		for a in Dev.args():
			if a.begins_with("bossat="):
				e.hp = e.max_hp * float(a.substr(7))     # dev: its later moments, sooner
			elif a.begins_with("bossdie="):
				# dev: its fall, on time (to look at it, or test it on every machine)
				after(float(a.substr(8)), func() -> void:
					if is_instance_valid(e) and e.alive and player:
						print("[dungeon] the guardian falls at frame %d" % Engine.get_process_frames())
						e.hp = 0.0
						e.die(player))
		var w := e as Enemy
		w.set("arena_center", c)
		var bz: Array = []
		for p in props:
			if is_instance_valid(p) and p.kind in ["boss_brazier", "root_node"] and p.room_id == r.id:
				p.data["boss"] = e
				bz.append(p)
		w.set("braziers", bz)
		var sub_line := String(e.def.get("epithet", ""))
		if form != "":
			var fd := Guardians.def_of(form)
			e.max_hp *= float(fd.hp)
			e.hp = e.max_hp
			e.take_form(form)
			e.begin_form()
			sub_line = String(fd.sub)
			if hunted():
				var n := mini(run.hunt_signs, HUNT_SIGNS)
				e.max_hp *= 1.0 - HUNT_WEAKEN * n
				e.hp = e.max_hp
				e.set_meta("quarry", true)
				sub_line = "The quarry. You read %d sign%s of it on the way down" % [n, "" if n == 1 else "s"]
			Chronicle.mark("form_met_" + form)
		Net.rec(["boss", e.net_id, form])
		if players.size() > 1:
			after(10.0, _guardian_call)
		Events.boss_started.emit(e)
		Events.banner.emit(e.display_name, sub_line)
		Audio.play_music(String(region.get("boss_music", "boss")), 0.5)
		# it is here: a blow on the floor, a burst of its light, a held breath
		var col: Color = region.flame
		fx.flash_light(at, 2.0, col, 7.0, 14.0, 0.9)
		fx.ring(at, 5.0, col, 0.7, 0.4)
		fx.ring(at, 3.0, Color(1, 1, 1), 0.4, 0.2)
		fx.burst(at, 1.0, col, 40, 6.0, 0.8, 4.0)
		fx.shake(0.55)
		slow_motion(0.35, 0.35)
		Audio.play("boss_arrive", -1.0)
		look_toward(at, 1.6))


## A guardian's arrival takes this long: the room trembles, light is drawn in
## to where it will stand under a widening sigil, the stone groans.
const ENTRANCE := 1.6


func _boss_entrance(at: Vector2) -> void:
	var col: Color = region.flame
	Audio.play("boss_rise", -2.0)
	look_toward(at, ENTRANCE + 0.2)
	fx.shape(Fx.Shape.SIGIL, at, Vector2.RIGHT, Vector2(3.4, 3.4), Color(col.r, col.g, col.b, 0.3), col.lightened(0.3), ENTRANCE + 0.1, {"glow": 2.0})
	for k in 6:
		after(k * 0.27, func() -> void:
			fx.shake(0.06 + 0.03 * k)
			for j in 8:
				var a := TAU * j / 8.0 + k * 0.4
				fx.motes(at + Vector2.from_angle(a) * (3.5 - k * 0.5), 0.2, col, 1, 0.6, 0.5, 0.1)
			fx.motes(at, 0.2, col.lightened(0.2), 2 + k * 2, 1.2 + k * 0.3, 0.7, 0.4 - k * 0.05))
	match String(region.boss):
		"warden":
			# it walks in out of the dark: four footfalls, each nearer, each heavier
			for k in 4:
				after(0.1 + k * 0.36, func() -> void:
					var p: Vector2 = at + Vector2(-0.7 if k % 2 == 0 else 0.7, -4.5 + k * 1.4)
					fx.ring(p, 1.2 + k * 0.4, col, 0.45, 0.2)
					fx.burst(p, 0.2, col, 8 + k * 4, 2.2, 0.5, 6.0)
					fx.shake(0.16 + k * 0.07)
					Audio.play("step_stone_%d" % k, 1.0 + k, 0.5))
		"bloom":
			# roots run in under the floor from every side and heave it up
			for k in 8:
				var dir := Vector2.from_angle(TAU * k / 8.0)
				for j in 6:
					after(0.08 + j * 0.2 + k * 0.015, func() -> void:
						fx.burst(at + dir * (6.5 - j * 1.1), 0.1, Color(0.5, 0.82, 0.36), 5, 2.4, 0.45, 8.0))
			after(1.3, func() -> void:
				fx.burst(at, 0.5, Color(0.92, 0.3, 0.36), 34, 5.0, 0.9, 3.0))
		"ashen_king":
			# the fires lean toward him one by one, and ash starts to fall
			var fires: Array = props.filter(func(p): return is_instance_valid(p) and p.kind == "boss_brazier")
			for k in fires.size():
				var b: Prop = fires[k]
				after(0.1 + k * 0.26, func() -> void:
					if is_instance_valid(b):
						fx.flash_light(b.pos, 1.6, col, 4.0, 7.0, 0.6)
						fx.burst(b.pos, 1.2, col, 12, 3.0, 0.6, 2.0))
			for k in 14:
				after(k * 0.11, func() -> void:
					fx.motes(at + Vector2(randf_range(-5.0, 5.0), randf_range(-3.5, 3.5)), 4.0, Color(0.62, 0.58, 0.56), 3, -1.0, 1.3, 0.4))


## A guardian facing a party calls for help: every so often foes of its
## region rise beside the Kindled who stands farthest from it (marked a
## moment before), so nobody fights from a safe spot behind it. More
## Kindled, more often and more of them.
func _guardian_call() -> void:
	if boss == null or not is_instance_valid(boss) or not boss.alive or players.size() <= 1:
		return
	var far: Player = null
	var fd := -1.0
	for p in active_players():
		var d := p.pos.distance_to(boss.pos)
		if d > fd:
			fd = d
			far = p
	if far:
		var n := players.size() - 1
		var ids := EnemyDB.party_extras(rng, layout.region, maxi(layout.depth, 2), [], n)
		for i in ids.size():
			var at := foe_spot(far.pos + Vector2.from_angle(rng.randf() * TAU) * 3.0, 1.5)
			fx.shape(Fx.Shape.SIGIL, at, Vector2.RIGHT, Vector2(1.6, 1.6), Color(1.0, 0.45, 0.4, 0.4), Color(1.0, 0.6, 0.5, 1.0), 1.0, {"glow": 1.5})
			var id: String = ids[i]
			after(0.9, func() -> void:
				if boss == null or not is_instance_valid(boss) or not boss.alive:
					return
				var e := _make_enemy(id)
				e.pos = at
				e.room_id = boss.room_id
				_scale(e, layout.depth, int(Profile.data.world.get("memory", 0)))
				e.xp = 0
				e.embers = 0
				e.spawn_t = 0.5
				add_actor(e)
				register_enemy(e))
		Audio.play("spawn", -2.0, 0.8)
	after(maxf(9.0, 16.0 - 2.0 * (players.size() - 1)), _guardian_call)


## Anticipation on a guardian's floor: the ground shakes, something below
## answers, and every Kindled is told who waits. Each machine does this
## itself (nothing recorded for the network).
func _guardian_stirs() -> void:
	if not is_inside_tree() or boss != null or player == null:
		return
	var bname := String(EnemyDB.get_def(String(region.get("boss", ""))).get("name", "the guardian"))
	Net.mute += 1
	fx.shake(0.4)
	Audio.play("boss_roar", -16.0, 0.55)
	Net.mute -= 1
	var echo := "An Echo of %s" % bname if run.delve else bname
	Events.toast.emit("The floor trembles. %s stirs somewhere ahead." % echo, Color(1.0, 0.6, 0.5))


## Materials (and now and then gear) from a fallen enemy; elites and bosses
## drop more, and a boss's first defeat always yields its legendary.
func _drop_loot(e: Enemy) -> void:
	var mult := (2.0 if e.elite else 1.0) * Difficulty.material_mult(run.tier) * float(e.get_meta("share", 1.0))
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
		# the region's reagent for the Apothecary
		_reagent_drop(e.pos + Vector2(0.4, 0.3), Tinctures.region_reagent(layout.region), 0.3)
		if rng.randf() < (0.55 if layout.route == "trial" else 0.3):
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.1, run.tier, _favour))
	if e == boss:
		_maybe_blueprint(e.pos, 1.0 if layout.region == "throne" else 0.3 + 0.05 * run.tier)
		_rune_drop(e.pos)
		var cat: String = {"rootmire": "bloom_heart", "throne": "eclipse_shard"}.get(layout.region, "warden_sigil")
		Pickup.spawn(self, "material", e.pos, 2, {"id": cat})
		_reagent_drop(e.pos + Vector2(-0.6, 0.4), "ashen_marrow", 1.0)
		var leg: String = {"rootmire": "bloom_crown", "throne": "sunfall_mantle"}.get(layout.region, "gloamward_lantern")
		var flag := "legendary_" + leg
		var had_first := bool(Profile.data.flags.get(flag, false))
		if not had_first or rng.randf() < 0.35:
			Profile.data.flags[flag] = true
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.make_item(leg, "legendary", 1, rng, run.tier))
		# its legendary weapon: sure the first time it is due (the second
		# victory), then now and then
		var wleg: String = ItemDB.BOSS_WEAPONS.get(layout.region, "")
		if wleg != "":
			var wflag := "legendary_" + wleg
			if (had_first and not Profile.data.flags.get(wflag, false)) or rng.randf() < 0.2:
				Profile.data.flags[wflag] = true
				_gear_drop(e.pos, func() -> Dictionary: return ItemDB.make_item(wleg, "legendary", 1, rng, run.tier))
		_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 1, rng, 0.25, run.tier, _favour))
		if run.tier >= 2:
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_set_piece(rng, layout.depth, run.tier))


## A gear drop. Co-op: one roll for each Kindled, visible to and taken by its
## owner only (nobody walks off with a friend's find). Weapon finds lean
## toward the archetype the finder fights with (`_favour`).
func _gear_drop(p: Vector2, roll: Callable) -> void:
	if players.size() <= 1:
		_favour = player.weapon.id if player and player.weapon else ""
		Pickup.spawn(self, "gear", p, 1, {"item": roll.call()})
		return
	for pl in players:
		_favour = pl.weapon.id if pl.weapon else ""
		Pickup.spawn(self, "gear", p, 1, {"item": roll.call()}, pl.peer_id)


## An Ember Rune: one roll for each Kindled (theirs alone, like gear).
func _rune_drop(p: Vector2) -> void:
	var ids: Array = Runes.RUNES.keys()
	if players.size() <= 1:
		Pickup.spawn(self, "rune", p, 1, {"id": ids[rng.randi_range(0, ids.size() - 1)]})
		return
	for pl in players:
		Pickup.spawn(self, "rune", p, 1, {"id": ids[rng.randi_range(0, ids.size() - 1)]}, pl.peer_id)


## A blueprint the Kindled doesn't have yet (else a few Ember Cores). Co-op:
## one for each Kindled, rolled against what *they* know (their sheet).
func _maybe_blueprint(p: Vector2, chance: float) -> void:
	if rng.randf() >= chance:
		return
	if players.size() <= 1:
		var have: Array = Profile.known_blueprints() + Profile.scrolls() + _found_blueprints(run)
		var b := ItemDB.roll_blueprint(rng, have)
		if b == "":
			Pickup.spawn(self, "material", p, 3, {"id": "ember_core"})
		else:
			Pickup.spawn(self, "blueprint", p, 1, {"id": b})
		return
	for pl in players:
		var have2: Array = _found_blueprints(pl.run)
		if pl.sheet.is_empty():
			have2 += Profile.known_blueprints() + Profile.scrolls()
		else:
			have2 += (pl.sheet.get("known", []) as Array) + (pl.sheet.get("scrolls", []) as Array)
		var b2 := ItemDB.roll_blueprint(rng, have2)
		if b2 == "":
			Pickup.spawn(self, "material", p, 3, {"id": "ember_core"})
		else:
			Pickup.spawn(self, "blueprint", p, 1, {"id": b2}, pl.peer_id)


func _found_blueprints(r: RunState) -> Array:
	var out: Array = (r.loot.get("blueprints", []) as Array).duplicate() if r else []
	if r:
		for f in r.found:
			if String(f.get("kind", "")) == "blueprint":
				out.append(f.what)
	return out


## A chest's materials and its chance of gear.
func _chest_loot(prop: Prop, tier: int) -> void:
	var pool: Array = {"rootmire": ["rootwood", "spore_silk"], "throne": ["sun_gold", "grave_iron", "soul_glass", "spore_silk"]}.get(layout.region, ["bone_dust", "grave_iron", "soul_glass"])
	for i in 1 + tier:
		Pickup.spawn(self, "material", prop.pos, rng.randi_range(1, 2 + tier), {"id": pool[rng.randi_range(0, pool.size() - 1)]})
	if rng.randf() < 0.3 + 0.2 * tier:
		Pickup.spawn(self, "material", prop.pos, 1, {"id": "ember_core"})
	var lucky := player != null and player.stats.has("lucky")
	if rng.randf() < 0.25 + 0.25 * tier:
		_gear_drop(prop.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.05 * tier + (0.15 if lucky else 0.0), run.tier, _favour))
	if lucky:
		# the Four-Leaf Ring: one more treasure, every time
		if rng.randf() < 0.5:
			_gear_drop(prop.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.2, run.tier, _favour))
		else:
			Pickup.spawn(self, "material", prop.pos, 2, {"id": "ember_core"})
	_maybe_blueprint(prop.pos, (0.015 + 0.005 * run.tier) if tier <= 1 else (0.06 + 0.02 * run.tier))
	if tier >= 2:
		_reagent_drop(prop.pos + Vector2(0.5, 0.5), "wardmoth_milk", 0.3)


# --- the route's own tasks (DungeonGen._objectives) -----------------------------------
# Simulated by the host; what the HUD shows (`objective`) reaches guests as
# an "obj" event. Neither can hold a room shut: a seal is a foe like any
# other (every blow, spell and shot breaks it), and a guttered flame only
# costs the vault its best spoils - the room still opens when its foes fall.

var objective := {}              # {text, k (0..1, or -1), col} - the HUD's line
var pings: Array = []            # {pos, col, t}: marks on the map (Party.ping)
var _seals: Array = []
var _seal_room := -1
var _vigil: Prop
var _flame := 0.0
var _flame_out := false
var _ward_fx_t := 0.0
const SEAL_COL := Color(1.0, 0.45, 0.25)
const GRUDGE_RED := Color(1.0, 0.32, 0.25)
const FLAME_COL := Color(1.0, 0.8, 0.4)


func _begin_objective(r: Room) -> void:
	match r.objective:
		"champion":
			var e := _champion("Ashen Champion", 2.1)
			if e:
				Events.banner.emit("The Ashen Champion", "One foe, burning. It will not be hurried")
				_set_objective("FELL THE CHAMPION", -1.0, SEAL_COL)
		"breach":
			var e2 := _champion("The Unbound", 3.2)
			if e2:
				Events.banner.emit("The Unbound", "It was sealed here for a reason")
				_set_objective("FELL THE UNBOUND", -1.0, Color(0.95, 0.35, 0.3))
		"rift":
			_seals_up(r)
			Events.banner.emit("The Rift Holds", "Three anchors keep this place torn open, and its foes warded")
		"gauntlet":
			Events.banner.emit("The Ash Falls", "Four waves. Keep moving: the floor burns between them")
			_set_objective("ENDURE   WAVE 1 OF %d" % r.encounter.size(), -1.0, SEAL_COL)
		"lair":
			if grudge_spawned:
				Events.banner.emit("Its Lair", "It has been waiting for you here")
			elif _champion("What Was Left Behind", 2.0):
				# (settled since the stairs were chosen: something else took the lair)
				Events.banner.emit("An Empty Lair", "Something else has moved in")
		"seals":
			_seals_up(r)
			Events.banner.emit("The Seals Hold", "While a seal stands, this hall's foes shrug off most of every blow")
		"flame":
			var t := Vector2i(_open_spot(r.center()))
			_vigil = Prop.make(self, "vigil", t, {"sheet": "vigil_lantern", "anim": "lit", "solid": true,
				"light": [FLAME_COL, 1.6, 6.0], "light_h": 1.4})
			_vigil.room_id = r.id
			_flame = 0.6
			_flame_out = false
			fx.ring(_vigil.pos, 2.4, FLAME_COL, 0.6, 0.3)
			Events.banner.emit("Keep the Flame", "Stand in its light to feed it; foes at the lantern choke it. If it goes out, the vault's best is lost")
			_set_objective("KEEP THE FLAME", _flame, FLAME_COL)


## Dev: a region's foes in rows on its real floor and light, held in one pose
## (`rosterlab anim=windup lab=<id,id>`; the default is the region's pool).
func _roster_lab() -> void:
	var ids: Array = EnemyDB.REGIONS[layout.region].pool.duplicate()
	var pose := "idle"
	for a in Dev.args():
		if a.begins_with("lab="):
			ids = Array(a.substr(4).split(","))
		elif a.begins_with("anim="):
			pose = a.substr(5)
	var best: Room = null
	for r in layout.rooms:
		if best == null or r.rect.get_area() > best.rect.get_area():
			best = r
	player.pos = _open_spot(best.center())
	best.cleared = true
	best.visited = true
	var cols := 5
	var lab: Array[Enemy] = []
	for k in ids.size():
		var e := _make_enemy(String(ids[k]))
		var at := player.pos + Vector2(-4.4 + (k % cols) * 2.2, -3.0 + (k / cols) * 2.4)
		e.pos = _open_spot(at)
		e.room_id = best.id
		e.spawn_t = 0.0
		e.replica = true     # (presents itself, simulates nothing: it stays put)
		add_actor(e)
		lab.append(e)
	for e in lab:
		if e.sprite:
			e.sprite.set_dissolve(0.0)
			if e.sprite.has_anim(pose):
				e.sprite.play(pose, true)


func _seals_up(r: Room) -> void:
	_seal_room = r.id
	_seals.clear()
	var c := r.center()
	var memory := int(Profile.data.world.get("memory", 0)) + int(region.get("memory_bonus", 0))
	for o in [Vector2(-0.3, -0.28), Vector2(0.3, -0.28), Vector2(0.0, 0.3)]:
		var at := c + Vector2(o.x * r.rect.size.x, o.y * r.rect.size.y)
		var e := _make_enemy("ash_seal")
		e.pos = arena_spot(r, at)
		_scale(e, layout.depth, memory)
		_coop_scale(e)
		e.room_id = r.id
		e.spawn_t = 0.3
		add_actor(e)
		register_enemy(e)
		_seals.append(e)
	_set_objective("BREAK THE SEALS   %d LEFT" % _seals.size(), -1.0, SEAL_COL)


## The room's greatest foe made greater: its first real fighter, two affixes,
## much more health, a name. (Not a health sponge alone: its affixes are what
## you fight.)
func _champion(title: String, hp_k: float) -> Enemy:
	for e: Enemy in room_enemies:
		if is_instance_valid(e) and not e.def.get("pack", false) and not e.def.get("boss", false):
			if not e.elite:
				var a := EnemyDB.roll_affix(rng, e.id)
				e.make_elite(a, EnemyDB.roll_affix(rng, e.id, a))
			e.max_hp *= hp_k
			e.hp = e.max_hp
			e.damage *= 1.2
			e.crown(title)
			return e
	return null


## The Gauntlet: ash falls between its waves, marked first, and burns a while.
func _ash_fall(r: Room) -> void:
	_set_objective("ENDURE   WAVE %d OF %d" % [wave + 1, r.encounter.size()], -1.0, SEAL_COL)
	if wave == 0:
		return
	var n := 2 + wave
	for k in n:
		var at := arena_spot(r, r.center() + Vector2(randf_range(-0.42, 0.42) * r.rect.size.x, randf_range(-0.42, 0.42) * r.rect.size.y))
		fx.ring(at, 1.5, SEAL_COL, 0.9, 0.2)
		after(1.1 + k * 0.1, func() -> void:
			if not is_inside_tree():
				return
			var h := Hazard.spawn(self, at, 1.4, 6.0, Actor.Team.ENEMY, Color(1.0, 0.45, 0.2), func(_h: Hazard, a: Actor) -> void:
				if a is Player:
					var hit := Hit.make(null, 4.0 + layout.depth, ["dot"])
					hit.can_crit = false
					hit.silent = true
					(a as Player).take_enemy_hit(hit, null))
			h.period = 0.6)


# --- an Echo is not its guardian with more health: each has a pattern of its own ------

var _echo_t := -1.0


func _echo_tick(dt: float) -> void:
	if _echo_t < 0.0 or boss == null or not is_instance_valid(boss) or not boss.alive or replica:
		return
	_echo_t -= dt
	if _echo_t > 0.0:
		return
	var n := Delve.echo_n(layout.depth)
	_echo_t = maxf(6.0, 10.0 - 0.6 * n)
	var t := nearest_player(boss.pos)
	if t == null:
		return
	var dmg := boss.damage * 0.7
	match layout.region:
		"ossuary":
			# Soul Lances: a line of bursts through where you stand
			var dir := Vector2.from_angle(randf() * TAU)
			for k in range(-3, 4):
				_echo_burst(t.pos + dir * k * 1.6, 1.0, 0.9 + absf(k) * 0.1, dmg, Color(0.45, 0.95, 0.85))
		"rootmire":
			# Grasping Ring: a closing circle of roots: step out, or through
			var c := 7 + mini(n, 3)
			for k in c:
				_echo_burst(t.pos + Vector2.from_angle(TAU * k / c) * 2.6, 0.9, 1.1, dmg, Color(0.55, 0.9, 0.4))
		_:
			# Falling Suns: scattered, then one right on you
			for k in 4 + mini(n, 4):
				_echo_burst(t.pos + Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0)), 1.2, 1.0 + k * 0.08, dmg, Color(1.0, 0.72, 0.35))
			_echo_burst(t.pos, 1.0, 1.5, dmg, Color(1.0, 0.72, 0.35))


## A marked burst: the mark first, always (Enemy.telegraph), the blow after.
func _echo_burst(at: Vector2, r: float, delay: float, dmg: float, col: Color) -> void:
	var p := foe_spot(at, 0.3, boss.room_id)
	boss.telegraph(Fx.Shape.DISC, p, Vector2.RIGHT, Vector2(r * 2.0, r * 2.0), delay)
	after(delay, func() -> void:
		if not is_inside_tree() or boss == null or not is_instance_valid(boss) or not boss.alive:
			return
		fx.burst(p, 0.6, col, 10, 3.0, 0.4, 3.0)
		boss.strike_arc(p, Vector2.RIGHT, r, PI, dmg, 2.0))


func _tend_objective(dt: float) -> void:
	_echo_tick(dt)
	if replica:
		return
	if _seal_room >= 0 and seals_up() > 0:
		# warded foes shed ash: you can see which ones the seals hold
		_ward_fx_t -= dt
		if _ward_fx_t <= 0.0:
			_ward_fx_t = 0.35
			for e in room_enemies:
				if sealed_foe(e):
					fx.motes(e.pos, 0.9, SEAL_COL, 1, 0.6, 0.8, 0.25)
	if _vigil and is_instance_valid(_vigil) and not _flame_out and active_room and active_room.objective == "flame":
		var near := 0
		for p in active_players():
			if p.pos.distance_to(_vigil.pos) < 2.4:
				near += 1
		var was := _flame
		if near > 0:
			_flame = minf(1.0, _flame + (0.05 + 0.02 * (near - 1)) * dt)
		else:
			_flame = maxf(0.0, _flame - (0.05 + 0.005 * layout.depth) * dt)
		# foes at the lantern choke it: standing there is not enough, keep them
		# off it (more Kindled, more foes: a party has its own hands full)
		var choking := 0
		for e in room_enemies:
			if is_instance_valid(e) and e.pos.distance_to(_vigil.pos) < 1.9:
				choking += 1
		_flame = maxf(0.0, _flame - 0.04 * mini(choking, 3) * dt)
		if _vigil.sprite:
			_vigil.sprite.play("low" if _flame < 0.3 else "lit")
		if _vigil.light:
			_vigil.light.light_energy = 0.4 + 1.4 * _flame
			_vigil.light.omni_range = 3.0 + 4.0 * _flame
		if near > 0 and fmod(elapsed, 0.5) < dt:
			fx.motes(_vigil.pos, 1.2, FLAME_COL, 3, 0.8, 0.9, 0.3)
		if _flame <= 0.0:
			_flame_out = true
			if _vigil.sprite:
				_vigil.sprite.play("out")
			if _vigil.light:
				_vigil.light.visible = false
			fx.burst(_vigil.pos, 1.2, Color(0.5, 0.45, 0.42), 14, 1.5, 0.8, 1.0)
			Events.banner.emit("The Flame Gutters", "The vault will open - but what it guarded is lost")
			_set_objective("THE FLAME IS OUT", 0.0, Color(0.6, 0.55, 0.55))
		elif absf(_flame - float(objective.get("k", -1.0))) >= 0.02 or (was >= 0.3) != (_flame >= 0.3):
			_set_objective("KEEP THE FLAME", _flame, FLAME_COL)


## Signs of a Grudge on this floor: red scratches at the doors of its room and
## of the rooms around it (announced to guests: props made after `built`).
func _spoor() -> void:
	if grudge_room < 0 or replica:
		return
	var r := layout.room(grudge_room)
	for d in r.doors:
		if d.secret or (d.tiles as Array).is_empty():
			continue
		var t: Vector2i = d.tiles[0]
		for q in [t - Vector2i(d.dir) * 2, t + Vector2i(d.dir) * 2, t - Vector2i(d.dir) * 3]:
			if grid.at(q.x, q.y) == TileGrid.FLOOR:
				Prop.make(self, "spoor", q, {"sheet": "grudge_spoor", "flat": true, "anim": "v%d" % (posmod(q.x + q.y, 3))})


## A Grudge of level 3 or more, settled for good, leaves something with its
## name on it: a charm for its owner alone, and a line in the Chronicle.
func _grudge_trophy(e: Enemy) -> void:
	var nm := e.display_name
	Chronicle.mark("grudges_settled")
	Chronicle.note("%s is settled." % nm)
	note_request("grudge")
	if int(e.get_meta("grudge_level", 1)) >= Profile.GRUDGE_MAX_LEVEL:
		# the last of it: a line in the story for good
		Chronicle.mark("nemeses")
		Chronicle.note("%s, who would not stay dead, is finished. It took the whole Undervault's patience." % nm)
		var ns: Array = Profile.data.world.get("nemeses", [])
		if not ns.has(nm):
			ns.append(nm)
		Profile.data.world["nemeses"] = ns
		Events.banner.emit("The Reckoning Is Over", "%s will not be coming back" % nm)
	if int(e.get_meta("grudge_level", 1)) < 3:
		return
	var it := ItemDB.make_item("rival_fang", "epic", 1, rng, run.tier)
	it["title"] = "Fang of %s" % nm.get_slice(" ", 0)
	var owner := int(e.get_meta("grudge_owner", Net.my_id()))
	Pickup.spawn(self, "gear", e.pos + Vector2(0.6, 0.0), 1, {"item": it}, 0 if players.size() <= 1 else owner)


## A grown Grudge, badly hurt, runs: it drops a third of its hoard, takes a scar
## and waits on the next floor, still bleeding. Never from the last floor (there
## is nowhere to go): there it turns and fights to the end. False: it stays.
func grudge_flees(e: Enemy) -> bool:
	if layout.boss_depth and not run.delve:
		return false
	var gid := String(e.get_meta("grudge_id", ""))
	if gid == "" or run.wounded.has(gid):
		return false
	run.wounded[gid] = maxf(0.35, e.hp_ratio() + 0.2)
	var owner := int(e.get_meta("grudge_owner", Net.my_id()))
	var hoard := int(e.get_meta("grudge_embers", 0))
	var share := hoard / 3
	# what drove it off marks it: it comes back armoured against that, and only that
	var kind := "flamescarred" if e.last_hit_tags.has("fire") else ("rimebound" if e.last_hit_tags.has("frost") else "hardened")
	if owner == Net.my_id():
		run.scars.append(gid)
		run.scar_marks[gid] = kind
	else:
		for pl in players:
			if pl.peer_id == owner and pl.run:
				pl.run.scars.append(gid)
				pl.run.scar_marks[gid] = kind
	for i in 6:
		Pickup.spawn(self, "ember", e.pos, maxi(1, share / 6), {"src": "grudge"})
	e.set_meta("grudge_embers", hoard - share)
	fx.burst(e.pos, 0.9, GRUDGE_RED, 30, 4.0, 0.6, 4.0, Vector2.UP, 1.3)
	Audio.play_at("grudge_flee", e.pos, -4.0)
	Events.banner.emit("%s Flees" % e.display_name, "Wounded. It will be waiting further down")
	Chronicle.note("%s fled, wounded, with what was left of your Embers." % e.display_name)
	e.set_meta("fled", true)
	e.die(null)
	return true


## A broken altar lets things out: more elites in that region; on the Breach,
## many more.
func _unbound_chance() -> float:
	var k := 0.0
	if Chronicle.site_of(run.world, layout.region) == "broken":
		k += 0.08
	if layout.route == "breach":
		k += 0.25
	return k


## Seals still standing in the warded hall.
func seals_up() -> int:
	var n := 0
	for s in _seals:
		if is_instance_valid(s) and s.alive:
			n += 1
	return n


## Is `t` one of the foes the seals ward (their blows land at a third)?
func sealed_foe(t: Actor) -> bool:
	return _seal_room >= 0 and t is Enemy and (t as Enemy).id != "ash_seal" and (t as Enemy).room_id == _seal_room and seals_up() > 0


func on_seal_broken() -> void:
	var left := seals_up()
	if left > 0:
		_set_objective("BREAK THE SEALS   %d LEFT" % left, -1.0, SEAL_COL)
		Events.toast.emit("A seal breaks. %d left." % left, SEAL_COL)
		return
	_set_objective("", -1.0, SEAL_COL)
	Events.banner.emit("The Seals Break", "The hall's foes bleed again")
	for e in room_enemies:
		if is_instance_valid(e) and e.alive:
			fx.burst(e.pos, 0.8, SEAL_COL, 8, 2.0, 0.4, 2.0)


func _set_objective(text: String, k: float, col: Color) -> void:
	if text == "" and has_key:
		text = "CARRY THE KEY TO THE VAULT"     # (it outlives the room's own task)
		k = -1.0
		col = Color(1.0, 0.8, 0.45)
	objective = {} if text == "" else {"text": text, "k": k, "col": col}
	if Net.recording:
		Net.rec(["obj", text, snappedf(k, 0.01), col])


## The Lost Vault's reward: a kept flame opens its reliquary (an ancient chest,
## a Gloamcap for each Kindled, now and then a blueprint); a guttered one only
## a plain chest.
func _open_vault(r: Room, c: Vector2) -> void:
	_set_objective("", -1.0, FLAME_COL)
	if _flame_out:
		Prop.make(self, "chest", Vector2i(c), {"tier": 1})
		Events.toast.emit("The vault opens on what little the dark left.", Color(0.7, 0.66, 0.62))
		return
	Prop.make(self, "chest", Vector2i(c), {"tier": 3})
	_reagent_drop(c + Vector2(1.2, 0.4), "gloamcap", 1.0)
	_maybe_blueprint(c + Vector2(-1.2, 0.4), 0.4)
	for i in 6:
		Pickup.spawn(self, "ember", c, 4)
	if _vigil and is_instance_valid(_vigil):
		fx.burst(_vigil.pos, 1.4, FLAME_COL, 30, 3.5, 0.8, 4.0, Vector2.UP, 1.0)
	Events.banner.emit("The Flame Holds", "The Lost Vault opens")
	note_request("chest")


## A reagent for the Apothecary: one for each Kindled, theirs alone (like a
## rune). The first of a kind teaches a tincture; more distil it.
func _reagent_drop(p: Vector2, id: String, chance: float) -> void:
	if rng.randf() >= chance:
		return
	if players.size() <= 1:
		Pickup.spawn(self, "reagent", p, 1, {"id": id})
		return
	for pl in players:
		Pickup.spawn(self, "reagent", p, 1, {"id": id}, pl.peer_id)


## Counts progress on residents' requests and tells the player when one is done.
func note_request(key: String, amount := 1) -> void:
	if not replica:
		Net.rec(["note", key, amount])     # (a guest's own favours and notices count too)
	Net.mute += 1     # each machine's own news, told only there
	for title in Contracts.note(key, amount):
		Events.toast.emit("Notice fulfilled: %s. It pays when you are home." % title, UIKit.C_GOLD)
		Audio.play("relic", -6.0, 1.2)
	var done := Residents.note(key, amount)
	if OS.is_debug_build() and not Residents.journal().is_empty():
		print("[request] %s x%d -> %s" % [key, amount, Residents.journal()])
	for name in done:
		Events.toast.emit("Request complete - return to %s at the Hearth." % name, UIKit.C_GOLD)
		Audio.play("relic", -4.0)
	for r in Residents.everyone():
		var req: Dictionary = r.request
		if req.key == key and Residents.request_state(r.id) == "active":
			var n := Residents.request_progress(r.id)
			if int(req.goal) <= 5 or n == int(req.goal) / 2:
				Events.toast.emit("%s: %d/%d" % [req.title, n, int(req.goal)], UIKit.C_DIM)
	Net.mute -= 1


func _on_ward() -> void:
	note_request("ward")


func _on_actor_died(a: Actor, killer: Node) -> void:
	if a is Enemy:
		var e := a as Enemy
		if e.has_meta("fled"):
			return     # (no death: it is waiting further down)
		if run.has_omen("volatile") and not e.def.get("boss", false) and e.id != "ash_seal" and rng.randf() < 0.5:
			var at := e.pos
			var dmg := e.damage * 0.8
			fx.ring(at, 1.5, Color(1.0, 0.5, 0.25), 0.9, 0.2)
			after(0.9, func() -> void:
				if not is_inside_tree():
					return
				fx.burst(at, 0.5, Color(1.0, 0.5, 0.25), 14, 3.5, 0.35, 3.0)
				Audio.play_at("bloat", at, -8.0, 1.4)
				for p in players_near(at, 1.5):
					p.take_enemy_hit(Hit.make(null, dmg, ["fire"]), null))
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
		# a guardian's wait until it has finished falling (no view: nothing to wait for)
		if e == boss and view != null and is_instance_valid(e):
			e.spoils = _spoils_of.bind(e)
		else:
			_spoils_of(e)
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
			_grudge_trophy(e)
			if int(e.get_meta("grudge_level", 1)) >= 2:
				# what it hoarded while it grew
				_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 1, rng, 0.2 + 0.1 * int(e.get_meta("grudge_level", 1)), run.tier, _favour))
			run.grudges_settled.append(g.get("name", "?"))
			Events.banner.emit("Grudge Settled", "%s returns to the dust." % g.get("name", "It"))
		if e == boss:
			_boss_defeated(e)


## What a felled foe leaves on the floor.
func _spoils_of(e: Enemy) -> void:
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
	if e == boss:
		_guardian_hoard(e)
	if e.has_meta("harbinger"):
		hunt_sign("Its harbinger is down")


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
		e.pos = foe_spot(at, 0.4)
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


## A guardian's own hoard, on top of what any foe leaves.
## Leaving a floor: the old hands' notices look at how it went.
func floor_left() -> void:
	var taken := 0.0
	for r in _party_runs():
		for k in r.taken:
			taken += float(r.taken[k])
	if is_equal_approx(taken, _taken_before) and run.rooms_cleared > _rooms_before:
		note_request("clean_floor")
	if elapsed < 150.0 and run.rooms_cleared > _rooms_before:
		note_request("quick_floor")


var _taken_before := 0.0
var _rooms_before := 0
var _boss_flasks := 0


func _guardian_hoard(e: Enemy) -> void:
	if e.has_meta("quarry"):
		# a hunt's end: its weapon for certain, and everything great worn remembers it
		var wleg: String = ItemDB.BOSS_WEAPONS.get(layout.region, "")
		if wleg != "":
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.make_item(wleg, "legendary", 1, rng, run.tier))
		for pr in _party_runs():
			pr.resonance_bonus += 100
		note_request("hunt_" + layout.region)
		Chronicle.mark("hunts")
		Chronicle.note("%s was hunted down through its own halls." % e.display_name)
		Events.banner.emit("The Hunt Is Over", "Its weapon is yours, and everything great you carry remembers this")
	if "bossquit" in Dev.args():
		# dev: a guardian fought to its end by real hits, timed
		print("[dungeon] guardian felled: %s, %s left of the Kindled, %.0f s on this floor" % [e.display_name, player.hp_ratio() if player else 0.0, elapsed])
		get_tree().quit()
	if player and player.flask >= _boss_flasks:
		note_request("dry_guardian")
	if e.form != "":
		# a rarer form guards more, and is worth a line in the story
		Pickup.spawn(self, "sunshard", e.pos, 2)
		for k in 2:
			_gear_drop(e.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 2, rng, 0.45, run.tier, _favour))
		Chronicle.mark("form_felled_" + e.form)
		note_request("form")
		Chronicle.note("%s fell, and the Undervault marked it." % e.display_name)
	for i in 2:
		Pickup.spawn(self, "sunshard", e.pos, 1)
	for i in 16:
		Pickup.spawn(self, "ember", e.pos, 8)
	for i in 8:
		Pickup.spawn(self, "xp", e.pos, 20)


## The guests' runs on this floor (the host's own is `run`).
func _party_runs() -> Array:
	var out: Array = [run]
	for pl in players:
		if is_instance_valid(pl) and pl.run and pl.run != run:
			out.append(pl.run)
	return out


func _on_player_died() -> void:
	if "bossquit" in Dev.args() and player:
		# dev: a guardian fight to the end by real hits, told honestly when it is lost
		var last: Array = []
		for b in (run.blows as Array).slice(maxi(0, run.blows.size() - 3)):
			last.append("%s %d" % [b[1], int(b[2])])
		print("[dungeon] the Kindled fell after %.0f s on this floor, the guardian at %d%%; last blows: %s" % [elapsed,
			int(round(boss.hp_ratio() * 100.0)) if boss and is_instance_valid(boss) else -1, ", ".join(PackedStringArray(last))])
		get_tree().quit()
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
		"lock_plate":
			_use_lock(prop, who)
		"lever":
			_pull_lever(prop)
		"key_altar":
			_take_key(prop)
		"cold_lantern":
			_relight(prop, who)
		"site":
			DeepEvents.interact(self, who, prop)
		"stairs":
			Game.descend(String(prop.data.get("route", "")))
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
		"landmark":
			_landmark_answer(prop, who)
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
			var offer_fn := func() -> void: Party.echo_gift(self, who, prop)
			if player.autopilot:
				offer_fn.call()
			else:
				# the offering is the conversation's choice (backing out offers nothing)
				Game.ui.dialogue("Echo of a Fallen Kindled", ["I came down with a lantern like yours. %s" % line[1], "Leave a little light for me - thirty Embers - and take what I no longer need."],
					Callable(), [["Offer 30 Embers (you carry %d)" % run.embers, offer_fn], ["Leave", Callable()]])



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
					_gear_drop(p.pos, func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth + 1, rng, 0.35, run.tier, _favour))
					Pickup.spawn(self, "sunshard", p.pos, 1)
					_rune_drop(p.pos))
	if OS.is_debug_build():
		print("[dungeon] vault opened in room %d" % prop.room_id)
	Events.banner.emit("The Vault Opens", "The flames burn together")
	Audio.play("gate_open", -2.0, 1.2)


## A landmark answers (DungeonGen.LANDMARKS):
##  the Bone Colossus remembers the whole depth - every room, the hidden
##  ones too, appears on every Kindled's map (Minimap reads its spent state);
##  the Heart-Root takes 15% of a Kindled's health for a relic of their
##  choosing, once each;
##  the Fallen Sun-Disc warms every Kindled near it once: Kindle full, a third
##  of their health, a flask, and a Sunshard left at its foot.
func _landmark_answer(prop: Prop, who: Player) -> void:
	var col: Color = prop._flame_col
	match String(prop.data.get("id", "")):
		"colossus":
			if prop.used:
				return
			prop.used = true
			prop.sprite.play("woken")
			prop._base_energy = 1.2
			fx.flash_light(prop.pos, 2.0, col, 5.0, 12.0, 1.2)
			fx.ring(prop.pos, 3.0, col, 0.9, 0.3)
			fx.motes(prop.pos, 1.6, col, 30, 2.0, 1.4, 0.6)
			Audio.play_at("colossus_wake", prop.pos, -3.0, 1.0, 400)
			Events.banner.emit("The Colossus Remembers", "Every hall of this depth is on your map")
			minimap_changed.emit()
		"heartroot":
			if Party.spent(prop, who) or not who.alive or who.downed:
				Party.tell(who, "The Heart has had your blood.", Color(0.9, 0.6, 0.6))
				return
			Party.spend(self, prop, who)
			who.hp = maxf(1.0, who.hp - who.max_hp * 0.15)
			prop.sprite.play("fed")
			prop._base_energy = 2.0
			fx.burst(who.pos, 0.8, Color(0.9, 0.25, 0.3), 16, 3.0, 0.5, 4.0)
			fx.motes(prop.pos, 1.4, col, 20, 1.6, 1.0, 0.5)
			Audio.play_at("pact", prop.pos, -2.0, 0.8)
			var skills := Party.skills_of(who)
			var offer := RelicDB.roll_offer(run.rng, 3, who.run.relics, SkillDB.branch_counts(skills), SkillDB.abilities(skills), layout.depth + 1, false)
			Party.offer_relic(self, who, prop, offer)
		"sundisc":
			if prop.used:
				return
			prop.used = true
			prop.sprite.play("lit")
			prop._base_energy = 1.6
			prop.light.omni_range = 10.0
			for pl in players_near(prop.pos, 9.0):
				pl.gain_kindle(pl.kindle_max())
				pl.heal(pl.max_hp * 0.35)
				pl.flask = mini(pl.flask + 1, int(pl.stats.v("flask_charges")))
				fx.motes(pl.pos, 0.5, col, 16, 1.6, 1.0, 0.5)
			Pickup.spawn(self, "sunshard", prop.pos + Vector2(0, 1.4), 1)
			fx.flash_light(prop.pos, 2.0, col, 6.0, 12.0, 1.4)
			fx.ring(prop.pos, 3.5, col, 1.0, 0.35)
			Audio.play_at("ignite", prop.pos, 0.0, 0.7)
			Audio.play_at("flask", prop.pos, -4.0, 0.8)
			Events.banner.emit("The Last Warmth", "The sun-king's emblem burns once more")
	if OS.is_debug_build():
		print("[dungeon] landmark %s answered %s" % [prop.data.get("id", ""), who.name])


## Has a Bone Colossus on this depth been heard (every room on the map)?
func remembered() -> bool:
	for p in props:
		if is_instance_valid(p) and p.kind == "landmark" and p.used and String(p.data.get("id", "")) == "colossus":
			return true
	return false


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
		_gear_drop(prop.pos + Vector2(1.6, -0.4), func() -> Dictionary: return ItemDB.random_drop(layout.region, layout.depth, rng, 0.25, run.tier, _favour))
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
	add_child(_build_level())
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
	var r := layout.room(prop.room_id)
	# never over another fight (a vote can pass late), never without a Kindled
	# in its room: either used to seal the wrong room for good
	var inside := active_players().filter(func(p): return r.contains_tile(Vector2i(floori(p.pos.x), floori(p.pos.y))))
	if active_room != null or inside.is_empty():
		Events.toast.emit("The trial altar waits - finish the fight, and stand by it.", Color(1.0, 0.7, 0.5))
		return
	prop.used = true
	prop.sprite.play("spent")
	r.cleared = false
	active_room = r
	wave = 0
	_pull_party_in(r, inside[0])
	room_enemies.clear()
	_set_gates(r, true)
	_arena_room = -1
	arena_of(r)
	Audio.play("boss_roar", -6.0, 1.4)
	if r.event == "procession":
		Events.banner.emit("The Procession Wakes", "Those who carried it never stopped walking")
	else:
		Events.banner.emit("The Trial Begins", "Survive three waves")
	_spawn_wave(r)


## Confirmation that the autopilot answers "yes" to.
func _ask(title: String, body: String, yes: Callable) -> void:
	if player.autopilot:
		yes.call()
	else:
		Game.ui.confirm(title, body, yes)
