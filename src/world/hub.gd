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
var _ember_t := 0.0


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
	env.ambient_light_energy = 0.32 + 0.03 * Profile.building("hearth")
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
	for i in 10:
		var t := Vector2i(rng.randi_range(5, 37), rng.randi_range(5, 19))
		if grid.at(t.x, t.y) == TileGrid.FLOOR and Vector2(t).distance_to(Vector2(21, 11)) > 3.0:
			Prop.make(self, "decal", t, {"variant": rng.randi_range(4, 7)})


func _spawn_dummies() -> void:
	for p in [Vector2(7.5, 17.5), Vector2(11.5, 18.0)]:
		var d := TrainingDummy.new()
		d.pos = p
		add_actor(d)


func _stage_process(real: float) -> void:
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
			Game.ui.dialogue("The Keeper", Keeper.lines())
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
