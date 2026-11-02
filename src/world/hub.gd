## The Last Hearth: the sanctuary between expeditions. It is a real place you
## walk around - the Hearth (skill tree), the forge, the descent, the memorial -
## and it visibly grows as you invest in it.
class_name Hub
extends Stage

const MAP := [
	"##########################################",
	"##########################################",
	"################........##################",
	"################........##################",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####...P........................P.....####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####...P........................P.....####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"####..................................####",
	"##########################################",
	"##########################################",
]

var menu_mode := false
var env: Environment
var hearth_prop: Prop
var cookpot: Prop
var residents: Array = []
var spots: Array = []        # where residents like to stand or sit (see _camp)
var _ember_t := 0.0
var _steam_t := 0.0
var _last_bark := -99.0


func build(v: PixelView) -> void:
	var g := TileGrid.new(MAP[0].length(), MAP.size())
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			match row[x]:
				".":
					g.put(x, y, TileGrid.FLOOR)
				"P":
					g.put(x, y, TileGrid.PILLAR)
	setup(g, v)
	add_child(LevelBuilder.build(grid, LevelBuilder.LevelTheme.named("hearth")))
	# the sanctuary sits on a dark, wind-scoured plateau: fill the world beyond the walls
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160 * Iso.SQ2)
	var gm := LevelBuilder.material(load("res://assets/textures/hearth_floor.png"), Color(0.42, 0.4, 0.45)).duplicate() as ShaderMaterial
	gm.set_shader_parameter("uv_scale", Vector2(160.0 / 8.0, 160.0 / 8.0))
	pm.material = gm
	ground.mesh = pm
	ground.position = Iso.to_world(Vector2(21, 11), 0.0) + Vector3(0, -0.05, 0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_environment()
	_place()
	if not menu_mode:
		player = Player.new()
		player.pos = Vector2(21.0, 15.0)
		add_actor(player)
		var r := RunState.create(0, "ossuary", Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
		player.setup_from(r)
		player.kindle = player.kindle_max()
		view.focus = Iso.to_world(player.pos)
		_spawn_dummies()
		_spawn_residents()
		if not Profile.data.flags.get("intro_done", false):
			Profile.data.flags.intro_done = true
			after(0.8, func() -> void:
				Game.ui.dialogue("The Keeper", [
					"Another Kindled wakes. Good. The Hearth was starting to forget what hands felt like.",
					"Below us lies the Undervault. It swallowed the sun, piece by piece. Every ember you carry back feeds the Hearth - and you.",
					"Walk to the Descent when you're ready. Commune with the Hearth to grow stronger. And Kindled... the dark remembers who hurts it.",
				]))
	else:
		view.focus = Iso.to_world(Vector2(21.0, 11.5))


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.62)
	env.ambient_light_energy = 0.55 + 0.06 * Profile.building("hearth")
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08
	view.set_environment(env)


func _place() -> void:
	var lvl := Profile.building("hearth")
	var warm := Color(1.0, 0.62, 0.32)
	hearth_prop = Prop.make(self, "hearth", Vector2i(21, 11), {"sheet": "hearth", "anim": "burn", "prompt": "Commune with the Hearth", "radius": 1.8, "solid": true,
		"light": [warm, 2.2 + 0.4 * lvl, 11.0 + 1.5 * lvl], "light_h": 1.6})
	for t in [Vector2i(20, 11), Vector2i(22, 11), Vector2i(21, 12), Vector2i(20, 12), Vector2i(22, 12)]:
		if grid.at(t.x, t.y) == TileGrid.FLOOR:
			grid.put(t.x, t.y, TileGrid.PROP)
			set_tile_solid(t, true)
	Prop.make(self, "descent", Vector2i(20, 3), {"sheet": "descent", "anim": "idle", "prompt": "Descend into the Undervault", "radius": 2.0,
		"light": [Color(0.35, 0.95, 0.85), 1.4, 7.0], "light_h": 1.0})
	if Profile.building("forge") > 0:
		Prop.make(self, "forge", Vector2i(9, 8), {"sheet": "forge", "anim": "idle", "prompt": "Use the Forge", "radius": 1.6, "solid": true,
			"light": [Color(1.0, 0.5, 0.25), 1.6, 6.0], "light_h": 0.8})
		Prop.make(self, "smith", Vector2i(11, 9), {"sheet": "smith", "anim": "idle", "prompt": "Talk", "radius": 1.0})
	else:
		Prop.make(self, "forge_ruin", Vector2i(9, 8), {"sheet": "forge_ruin", "prompt": "Rebuild the Forge", "radius": 1.6, "solid": true})
	Prop.make(self, "rack", Vector2i(9, 13), {"sheet": "rack", "prompt": "Choose Weapon", "radius": 1.2, "solid": true})
	if Profile.building("apothecary") > 0:
		Prop.make(self, "apothecary", Vector2i(33, 8), {"sheet": "apothecary", "anim": "idle", "prompt": "Ember Apothecary", "radius": 1.6, "solid": true,
			"light": [Color(1.0, 0.45, 0.5), 1.2, 5.0], "light_h": 1.0})
	else:
		Prop.make(self, "apothecary", Vector2i(33, 8), {"sheet": "apothecary_ruin", "prompt": "Build the Apothecary", "radius": 1.6, "solid": true})
	if Profile.building("shrine") > 0:
		Prop.make(self, "memorial", Vector2i(33, 14), {"sheet": "memorial", "anim": "idle", "prompt": "Shrine of Memory", "radius": 1.6, "solid": true,
			"light": [Color(0.75, 0.45, 0.95), 1.2, 5.0], "light_h": 1.4})
	else:
		Prop.make(self, "memorial", Vector2i(33, 14), {"sheet": "memorial_ruin", "prompt": "Raise the Shrine of Memory", "radius": 1.6, "solid": true})
	Prop.make(self, "keeper", Vector2i(24, 13), {"sheet": "keeper", "anim": "idle", "prompt": "Speak with the Keeper", "radius": 1.2,
		"light": [Color(1.0, 0.8, 0.5), 0.6, 3.0], "light_h": 1.2})
	# the sanctuary grows: more lanterns lit with each Hearth level
	var posts := [Vector2i(6, 5), Vector2i(36, 5), Vector2i(6, 19), Vector2i(36, 19), Vector2i(15, 5), Vector2i(27, 5), Vector2i(15, 19), Vector2i(27, 19)]
	for i in posts.size():
		var on := i < 2 + lvl * 2
		var p := Prop.make(self, "lantern_post", posts[i], {"sheet": "lantern_post", "anim": "lit" if on else "unlit", "solid": true,
			"light": [warm, 1.0, 5.0] if on else [warm, 0.0, 0.1], "light_h": 1.9})
		if not on and p.light:
			p.light.visible = false
	# torches along the north wall
	for x in [7, 13, 29, 35]:
		Prop.make(self, "torch", Vector2i(x, 3), {"flame": Color(1.0, 0.6, 0.3)})
	_camp()
	for i in 10:
		var t := Vector2i(rng.randi_range(5, 37), rng.randi_range(5, 19))
		if grid.at(t.x, t.y) == TileGrid.FLOOR and Vector2(t).distance_to(Vector2(21, 11)) > 3.0:
			Prop.make(self, "decal", t, {"variant": rng.randi_range(4, 7)})


## The survivors' camp around the Hearth, and the spots residents gravitate to.
func _camp() -> void:
	for x in [10, 32]:
		Prop.make(self, "banner", Vector2i(x, 3), {"sheet": "hearth_banner"})
	for b in [Vector2i(17, 12), Vector2i(25, 11)]:
		Prop.make(self, "bench", b, {"sheet": "bench", "solid": true})
		_spot(Vector2(b) + Vector2(0.5, 0.56), "sit", "bench")
	cookpot = Prop.make(self, "cookpot", Vector2i(18, 9), {"sheet": "cookpot", "anim": "idle", "solid": true,
		"light": [Color(1.0, 0.5, 0.25), 0.5, 2.5], "light_h": 0.3})
	_spot(Vector2(17.15, 9.7), "idle", "cookpot")
	Prop.make(self, "crates", Vector2i(12, 5), {"sheet": "crates", "solid": true})
	_spot(Vector2(13.4, 6.0), "idle", "crates")
	Prop.make(self, "tent", Vector2i(30, 17), {"sheet": "tent", "solid": true})
	for t in [Vector2i(29, 17), Vector2i(31, 17)]:
		grid.put(t.x, t.y, TileGrid.PROP)
		set_tile_solid(t, true)
	_spot(Vector2(30.5, 18.45), "sit", "tent")
	var bloom := Residents.garden_stage()
	for x in [18, 20, 22, 24]:
		Prop.make(self, "planter", Vector2i(x, 19), {"sheet": "planter", "anim": "s%d" % bloom, "solid": true,
			"light": [Color(1.0, 0.85, 0.45), 0.35, 1.6] if bloom >= 3 else [], "light_h": 0.5})
	_spot(Vector2(19.5, 18.3), "idle", "planters")
	_spot(Vector2(23.5, 18.3), "idle", "planters")
	_spot(Vector2(19.2, 13.5), "idle", "hearth")
	_spot(Vector2(23.0, 13.7), "sit", "hearth")
	_spot(Vector2(9.8, 16.2), "idle", "dummies")
	_spot(Vector2(15.5, 6.3), "idle", "posts")
	_spot(Vector2(27.5, 6.3), "idle", "posts")
	_spot(Vector2(18.6, 5.0), "idle", "descent")
	if Profile.building("forge") > 0:
		_spot(Vector2(11.6, 10.6), "idle", "forge")
	if Profile.building("shrine") > 0:
		_spot(Vector2(31.8, 15.3), "idle", "memorial")


func _spot(p: Vector2, pose: String, tag: String) -> void:
	spots.append({"p": p, "pose": pose, "tag": tag, "by": null})


func _spawn_residents() -> void:
	var n := Residents.count_present()
	for i in n:
		residents.append(Wanderer.spawn(self, Residents.LIST[i], spots, rng))
	# newcomers are announced once
	var seen := int(Profile.data.flags.get("residents_seen", 1))
	if n > seen:
		var names: Array = []
		for i in range(seen, n):
			names.append(Residents.LIST[i].name)
		after(1.2, func() -> void:
			Game.ui.toast("New at the Hearth: %s" % ", ".join(names), UIKit.C_GOLD))
	Profile.data.flags["residents_seen"] = maxi(seen, n)


## A conversation: a resident asks for a favour, hands over a gift for a
## finished one, or just talks (mentioning how the favour is going).
func _talk_to(w: Wanderer) -> void:
	var d: Dictionary = w.def
	var id := String(d.id)
	var req: Dictionary = d.get("request", {})
	var who := String(d.name) + ("" if String(d.title) == "" else ", " + String(d.title))
	var lines: Array = Residents.talk(id).duplicate()
	var after := func() -> void: pass
	match Residents.request_state(id):
		"":
			if not req.is_empty():
				lines = req.ask
				after = func() -> void:
					Residents.start_request(id)
					Game.ui.toast("New request: %s" % req.title, UIKit.C_GOLD)
					Profile.save_profile()
		"active":
			lines.append("(%s: %d/%d)" % [req.title, Residents.request_progress(id), int(req.goal)])
		"complete":
			lines = req.done
			after = func() -> void:
				if Residents.claim(id):
					Audio.play("relic", 0.0)
					Game.ui.toast("Gift - %s" % req.gift, UIKit.C_GOLD)
					fx.burst(w.pos, 1.0, Color(1.0, 0.85, 0.45), 24, 3.0, 0.8, 2.0)
					if player:
						player.rebuild_stats()
					Profile.save_profile()
	w.listen(600.0)   # until the conversation closes
	Game.ui.dialogue(who, lines, func() -> void:
		after.call()
		if is_instance_valid(w):
			w.listen(1.5, false)
			w.refresh_mark())


## Residents take turns speaking so the sanctuary never turns into a chorus.
func may_bark() -> bool:
	if elapsed - _last_bark < 7.0:
		return false
	_last_bark = elapsed
	return true


func _spawn_dummies() -> void:
	for p in [Vector2(7.5, 17.5), Vector2(11.5, 18.0)]:
		var d := TrainingDummy.new()
		d.pos = p
		add_actor(d)


func _stage_process(real: float) -> void:
	_steam_t += real
	if cookpot and _steam_t > 0.22:
		_steam_t = 0.0
		fx.motes(cookpot.pos + Vector2(randf_range(-0.2, 0.2), 0), 1.0, Color(0.7, 0.68, 0.72), 1, 0.4, 1.8, 0.15)
	_ember_t += real
	if _ember_t > 0.06:
		_ember_t = 0.0
		fx.motes(Vector2(21.0, 11.5) + Vector2(randf_range(-0.6, 0.6), 0), 1.0, Color(1.0, randf_range(0.5, 0.8), 0.3), 1, 2.2, 1.6, 0.3)


func request(what: String, prop: Prop) -> void:
	match what:
		"hearth":
			Game.ui.skill_tree()
		"descent":
			Game.ui.descent_prompt()
		"rack":
			Game.ui.weapon_select()
		"forge", "smith":
			Game.ui.forge()
		"forge_ruin", "apothecary", "memorial":
			if what == "memorial" and Profile.building("shrine") > 0:
				Game.ui.memorial()
			else:
				Game.ui.sanctuary_build({"forge_ruin": "forge", "apothecary": "apothecary", "memorial": "shrine"}[what])
		"keeper":
			prop.sprite.play("talk")
			prop.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
			Game.ui.dialogue("The Keeper", Keeper.lines(), func() -> void:
				if is_instance_valid(prop):
					prop.sprite.process_mode = Node.PROCESS_MODE_INHERIT
					prop.sprite.play("idle"))
		"resident":
			_talk_to(prop as Wanderer)
	prop.set_meta("last_used", elapsed)


class TrainingDummy:
	extends Actor

	func _ready() -> void:
		team = Team.ENEMY
		radius = 0.4
		anchored = true
		max_hp = 9999.0
		hp = max_hp
		display_name = "Training Dummy"
		build_visual("dummy", "idle")

	func think(dt: float) -> void:
		hp = minf(max_hp, hp + 400.0 * dt)
		if randf() < dt * 0.1:
			status.clear()

	func on_damaged(hit: Hit, res: Combat.Result) -> void:
		super.on_damaged(hit, res)
		sprite.play("hit", true)

	func die(_k: Node) -> void:
		hp = max_hp
