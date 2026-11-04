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
var _spark_t := 0.0
var _fly_t := 0.0
var forge_prop: Prop
var anvil_prop: Prop        # the smith's anvil: sparks when the hammer lands
var smith_prop: Prop
var quench_prop: Prop
var _smith_frame := -1
var _bellows_t := 3.0
var _flare_t := 0.0
var _strikes := 0
var _smoke_t := 0.0
var gate_prop: Prop
var _gate_t := 0.0
var _hum_t := 0.0
var _gate_flaring := false
var lit_lanterns: Array = []
var _last_bark := -99.0
## What the camp looks like (see camp_of_profile): this profile's own, or - for
## a guest in a party - the host's. A guest visits the host's sanctuary; their
## own progression (Hearthtree, forge, satchel, requests) stays theirs.
var camp := {}
var sync: HubSync               # co-op: the party in this sanctuary (null alone)
var cat: CampCat


## This profile's camp: what has been built and earned, as the sanctuary shows it.
static func camp_of_profile() -> Dictionary:
	var forged := 0
	for wid in GearDB.WEAPONS:
		if Profile.weapon_unlocked(wid):
			forged += 1
	var trophies: Array = []
	for k in ["warden", "bloom", "ashen_king"]:
		if int(Profile.data.world.get("%s_kills" % k, 0)) > 0:
			trophies.append(k)
	return {"hearth": Profile.building("hearth"), "forge": Profile.building("forge"), "apothecary": Profile.building("apothecary"),
		"shrine": Profile.building("shrine"), "level": Profile.level(), "garden": Residents.garden_stage(),
		"residents": Residents.count_present(), "feats": Feats.earned_count(), "trophies": trophies,
		"cat": int(Profile.data.stats.get("runs", 0)) > 0, "forged": forged, "host": String(Settings.get_value("player_name", "Kindled"))}


## The camp to build: the host's while this machine is a guest in a party.
static func current_camp() -> Dictionary:
	if Net.is_client() and not Net.i.camp.is_empty():
		return Net.i.camp
	return camp_of_profile()


## Is this the local player's own sanctuary (not a guest's visit)?
func own_camp() -> bool:
	return not Net.is_client()


func build(v: PixelView, at := Vector2(-1, -1)) -> void:
	camp = current_camp()
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
		player.pos = Vector2(21.0, 15.0) if at.x < 0.0 else at
		if at.x < 0.0 and Net.active() and Net.i.roster.has(Net.my_id()):
			# in a party each seat arrives at its own place by the fire
			var slot := int(Net.i.roster[Net.my_id()].get("slot", 0))
			player.pos = [Vector2(21.0, 15.0), Vector2(19.3, 15.4), Vector2(22.7, 15.4), Vector2(21.0, 16.4)][slot % 4]
		for a in Dev.args():
			if a.begins_with("spawn="):
				# dev: start somewhere else in the camp (captures)
				var q := a.substr(6).split(",")
				player.pos = Vector2(float(q[0]), float(q[1]))
		add_actor(player)
		var r := RunState.create(0, "ossuary", Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
		player.setup_from(r)
		player.kindle = player.kindle_max()
		if Net.active() and Net.party_size() > 1:
			player.set_seat(Net.color_of(Net.my_id()), true)     # find yourself among the party
		view.focus = Iso.to_world(player.pos)
		_spawn_dummies()
		_spawn_residents()
		if "descend" in Dev.args():
			# dev: step through the gate a second after the camp loads (captures)
			after(1.0, func() -> void: Game.begin_descent(String(Profile.data.descent.get("region", "ossuary"))))
		_dev_net()
		# (the very first sanctuary is built before Game has added Net)
		_hook_party.call_deferred()
		if not Profile.data.flags.get("intro_done", false):
			after(0.8, _intro)
	else:
		view.focus = Iso.to_world(Vector2(21.0, 11.5))


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.62)
	env.ambient_light_energy = 0.55 + 0.06 * int(camp.hearth)
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
	var lvl := int(camp.hearth)
	var warm := Color(1.0, 0.62, 0.32)
	# the Hearth burns a little brighter with every level the Kindled gains
	var grow := float(camp.level)
	hearth_prop = Prop.make(self, "hearth", Vector2i(21, 11), {"sheet": "hearth", "anim": "burn", "prompt": "Commune with the Hearth", "radius": 1.8, "solid": true,
		"light": [warm, 2.2 + 0.4 * lvl + 0.012 * grow, 11.0 + 1.5 * lvl + 0.05 * grow], "light_h": 1.6})
	# the fire pit's stone ring is three tiles wide and one deep (its sprite
	# ends a few pixels south of the flames): the row south of it is open
	# ground - it used to block, an invisible step in front of the fire
	for t in [Vector2i(20, 11), Vector2i(22, 11)]:
		if grid.at(t.x, t.y) == TileGrid.FLOOR:
			grid.put(t.x, t.y, TileGrid.PROP)
			set_tile_solid(t, true)
	gate_prop = Prop.make(self, "descent", Vector2i(20, 3), {"sheet": "descent", "anim": "idle", "prompt": "Descend into the Undervault", "radius": 2.2,
		"light": [Color(0.35, 0.95, 0.85), 1.4, 7.0], "light_h": 1.4})
	if int(camp.forge) > 0:
		# the workshop grows with the forge's level (Profile.SANCTUARY.forge):
		# furnace, anvil and smith; a quench barrel and a tool rack; then a
		# master's bellows, banner and grindstone
		var fl := int(camp.forge)
		forge_prop = Prop.make(self, "forge", Vector2i(9, 8), {"sheet": "forge", "anim": "l3" if fl >= 3 else "idle", "prompt": "Use the Forge: temper and forge weapons", "radius": 1.8, "solid": true,
			"solid_tiles": [Vector2i(8, 8), Vector2i(10, 8)], "light": [Color(1.0, 0.5, 0.25), 1.8, 7.0], "light_h": 0.9})
		smith_prop = Prop.make(self, "smith", Vector2i(11, 9), {"sheet": "smith", "anim": "idle", "prompt": "Smithy: craft and temper gear", "radius": 1.0})
		anvil_prop = Prop.make(self, "anvil", Vector2i(12, 9), {"sheet": "anvil", "anim": "idle", "solid": true})
		if fl >= 2:
			quench_prop = Prop.make(self, "quench", Vector2i(14, 8), {"sheet": "quench", "anim": "idle", "solid": true})
			Prop.make(self, "tool_rack", Vector2i(6, 9), {"sheet": "tool_rack", "solid": true})
		if fl >= 3:
			Prop.make(self, "grindstone", Vector2i(13, 11), {"sheet": "grindstone", "anim": "spin", "solid": true})
	else:
		Prop.make(self, "forge_ruin", Vector2i(9, 8), {"sheet": "forge_ruin", "prompt": "Rebuild the Forge", "radius": 1.6, "solid": true})
	# the rack fills as weapons are forged
	var forged := int(camp.forged)
	Prop.make(self, "rack", Vector2i(9, 13), {"sheet": "rack_display", "anim": "n%d" % mini(forged, 5), "prompt": "Choose Weapon", "radius": 1.2, "solid": true})
	# the peddler's stall: gear for Embers, restocked after every descent
	Prop.make(self, "peddler", Vector2i(14, 15), {"sheet": "merchant", "anim": "idle", "prompt": "Browse the Peddler's wares", "radius": 1.4, "solid": true,
		"light": [Color(1.0, 0.75, 0.4), 0.9, 3.5], "light_h": 1.0})
	Prop.make(self, "peddler_crates", Vector2i(16, 15), {"sheet": "crates", "solid": true})
	if int(camp.apothecary) > 0:
		Prop.make(self, "apothecary", Vector2i(33, 8), {"sheet": "apothecary", "anim": "idle", "prompt": "Ember Apothecary", "radius": 1.6, "solid": true,
			"light": [Color(1.0, 0.45, 0.5), 1.2, 5.0], "light_h": 1.0})
	else:
		Prop.make(self, "apothecary", Vector2i(33, 8), {"sheet": "apothecary_ruin", "prompt": "Build the Apothecary", "radius": 1.6, "solid": true})
	if int(camp.shrine) > 0:
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
	_keepsakes()
	if not menu_mode:
		_signboards()
	# woven rugs where people gather: by the fire and at the tent
	Prop.make(self, "rug", Vector2i(21, 14), {"anim": "rug0"})
	Prop.make(self, "rug", Vector2i(30, 19), {"anim": "rug1"})
	for i in 26:
		var t := Vector2i(rng.randi_range(5, 37), rng.randi_range(5, 19))
		if grid.at(t.x, t.y) == TileGrid.FLOOR and Vector2(t).distance_to(Vector2(21, 11)) > 3.0:
			Prop.make(self, "decal", t, {"variant": rng.randi_range(0, 9), "row": "camp"})


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
	var bloom := int(camp.garden)
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
	if int(camp.forge) > 0:
		_spot(Vector2(10.4, 10.6), "idle", "forge")
	if int(camp.shrine) > 0:
		_spot(Vector2(31.8, 15.3), "idle", "memorial")


## Ruins say what they could be: a sign over each one that can be rebuilt.
func _signboards() -> void:
	var ruins := {
		"forge_ruin": ["forge", "RUINED FORGE", "Brings back the smith"],
		"apothecary": ["apothecary", "RUINED APOTHECARY", "More, stronger flasks"],
		"memorial": ["shrine", "FALLEN SHRINE", "Settle Grudges for more"],
	}
	if not own_camp():
		return     # a guest's own ruins are at home
	for p in props:
		if not is_instance_valid(p) or not ruins.has(p.kind):
			continue
		var r: Array = ruins[p.kind]
		if Profile.building(String(r[0])) > 0:
			continue
		var cost := Profile.building_cost(String(r[0]))
		var price := ", ".join(PackedStringArray(cost.keys().map(func(k): return "%d %s" % [int(cost[k]), "Embers" if k == "embers" else ("Sunshard" if k == "sunshards" else String(k))])))
		fx.signboard(p, 2.4, String(r[1]), "Rebuild: %s" % price, Color(1.0, 0.75, 0.35))
		p.data["prompt"] = "%s  -  %s" % [String(p.data.get("prompt", "Rebuild")), r[2]]


## What the camp keeps of the Kindled's story: trophies of fallen bosses, a
## lantern lit for every two feats, a stand wearing the chosen look, and (once
## the Kindled has come home once) a cat who has decided this is its fire now.
func _keepsakes() -> void:
	var trophies := [
		["warden", "trophy_warden", "The Gloam Warden's helm", Color(0.35, 0.95, 0.85), [
			"Its visor still glows when the Hearth gutters. The residents swear it watches the dark for you."]],
		["bloom", "trophy_bloom", "A dried Hollow Bloom", Color(1.0, 0.8, 0.45), [
			"Even dried and potted, it leans toward the Hearth. Hollis waters it anyway. 'Old habits,' she says."]],
		["ashen_king", "trophy_king", "The Ashen King's crown", Color(1.0, 0.75, 0.35), [
			"The last crown of the day. It is cold to the touch, and the black sun behind it never quite stops burning."]],
	]
	for i in trophies.size():
		var t: Array = trophies[i]
		if (camp.trophies as Array).has(t[0]):
			Prop.make(self, "trophy", Vector2i(30 + i * 2, 4), {"sheet": t[1], "prompt": t[2], "radius": 1.1, "solid": true,
				"lines": t[4], "light": [t[3], 0.7, 2.6], "light_h": 1.0})
	# feat lanterns along the south wall
	var xs := [5, 7, 9, 11, 13, 15, 27, 29, 32, 34, 36]
	var lit := int(ceil(int(camp.feats) * xs.size() / float(Feats.FEATS.size())))
	for i in xs.size():
		var on: bool = i < lit
		var lp := Prop.make(self, "feat_lantern", Vector2i(xs[i], 19), {"sheet": "hang_lantern", "anim": "lit" if on else "unlit", "solid": true,
			"light": [Color(1.0, 0.7, 0.35), 0.55, 2.8] if on else [], "light_h": 1.6})
		if on:
			lit_lanterns.append(lp)
	# the wardrobe stand wears whatever look the Kindled has chosen
	Prop.make(self, "stand", Vector2i(6, 10), {"sheet": "stand_base"})
	var m := Prop.make(self, "wardrobe", Vector2i(6, 10), {"sheet": "player", "anim": "idle_down", "prompt": "Wardrobe: change your look", "radius": 1.2, "solid": true,
		"light": [Color(1.0, 0.8, 0.55), 0.6, 2.6], "light_h": 1.4})
	if m.sprite:
		m.sprite.speed_scale = 0.0
		m.sprite.set_tint(Color(0.8, 0.78, 0.76))
	if bool(camp.cat):
		cat = CampCat.new()
		cat.stage = self
		cat.kind = "cat"
		cat.tile = Vector2i(20, 13)
		cat.pos = Vector2(20.4, 13.7)
		cat.data = {"sheet": "cat", "anim": "sleep", "prompt": "Pet the cat", "radius": 0.5}
		add_child(cat)
		props.append(cat)
		cat._build()
		cat.ticks = true


func _spot(p: Vector2, pose: String, tag: String) -> void:
	spots.append({"p": p, "pose": pose, "tag": tag, "by": null})


func _spawn_residents() -> void:
	var n := int(camp.residents)
	for i in n:
		residents.append(Wanderer.spawn(self, Residents.LIST[i], spots, rng))
	if not own_camp():
		return
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
	var choices: Array = []
	if not Residents.present(id):
		# a guest in someone else's sanctuary: their favours are asked at home
		lines = Residents.talk(id).slice(0, 1)
		lines.append("You're %s's guest tonight, aren't you? Warm yourself. Your own camp's folk will want you back." % Net.name_of(1))
	else:
		match Residents.request_state(id):
			"":
				if not req.is_empty():
					lines = req.ask
					choices = [["Accept", func() -> void:
						if Residents.request_state(id) == "":
							Residents.start_request(id)
							Game.ui.toast("New request: %s" % req.title, UIKit.C_GOLD)
							Audio.play("skill_unlock", -8.0, 1.3)
							Profile.save_profile()], ["Not now", Callable()]]
			"active":
				lines.append("(%s: %d/%d)" % [req.title, Residents.request_progress(id), int(req.goal)])
			"complete":
				lines = req.done
				# the gift is theirs however the conversation ends (claim() pays once)
				after = func() -> void:
					if Residents.claim(id):
						Audio.play("relic", 0.0)
						Game.ui.toast("Gift - %s" % req.gift, UIKit.C_GOLD)
						fx.burst(w.pos, 1.0, Color(1.0, 0.85, 0.45), 24, 3.0, 0.8, 2.0)
						if player:
							player.rebuild_stats()
						Profile.save_profile()
	if OS.is_debug_build():
		print("[hub] talk to %s: request '%s', %d choices, %d lines" % [id, Residents.request_state(id), choices.size(), lines.size()])
	w.listen(600.0)   # until the conversation closes
	Game.ui.dialogue(who, lines, func() -> void:
		after.call()
		if is_instance_valid(w):
			w.listen(1.5, false)
			w.refresh_mark(), choices)


## Residents take turns speaking so the sanctuary never turns into a chorus.
func may_bark() -> bool:
	if elapsed - _last_bark < 7.0:
		return false
	_last_bark = elapsed
	return true


## Dev: net=host | net=join:<ip>, name=<name>, coop=<n> (the host takes the
## party down once n Kindled are in), for testing co-op with real instances.
static var _dev_net_done := false

func _dev_net() -> void:
	if _dev_net_done:
		return
	_dev_net_done = true
	var want := 0
	for a in Dev.args():
		if a.begins_with("name="):
			Settings.set_value("player_name", a.substr(5), false)
		elif a.begins_with("coop="):
			want = int(a.substr(5))
	for a in Dev.args():
		if a == "net=host" and not Net.active():
			after(0.3, func() -> void: Net.i.host())
		elif a == "net=steamhost" and not Net.active():
			# a private lobby (friends see nothing to join) hosted over Steam
			after(0.5, func() -> void: Net.i.steam.host_lobby(false))
		elif a.begins_with("net=steamjoin:") and not Net.active():
			# straight to a host's Steam ID ("self": this account, for a second process)
			var who := a.substr(14)
			after(1.0, func() -> void: Net.i.steam.connect_to(Net.i.steam.my_id if who == "self" else int(who)))
		if (a.begins_with("net=join:") or a.begins_with("net=steamjoin:")) and not Net.active():
			if a.begins_with("net=join:"):
				var addr := a.substr(9)
				after(0.6, func() -> void: Net.i.join(addr))
	if want > 1:
		# dev: once n Kindled are in the sanctuary the host proposes the
		# expedition; the bots answer it (Net._dev_answer)
		var check := func(again: Callable) -> void:
			if not is_inside_tree():
				return
			var here := 0
			if Net.is_host():
				for pid in Net.i.roster:
					if String(Net.i.roster[pid].get("where", "")) == "hub":
						here += 1
			if Net.is_host() and here >= want and Net.i.proposal.is_empty():
				after(1.0, func() -> void:
					Expedition.request(String(Profile.data.descent.get("region", "ossuary")), Difficulty.selected(),
						(Profile.data.descent.get("omens", []) as Array).filter(func(o): return Omens.unlocked(String(o)))))
			else:
				after(0.5, again.bind(again))
		after(0.5, check.bind(check))


## The Keeper greets a new Kindled - once nothing else is on screen (a menu
## opened in the first moment keeps it waiting, it never covers one).
func _intro() -> void:
	if Profile.data.flags.get("intro_done", false):
		return
	if Game.ui.has_modal() or Game.ui.card_pending:
		after(0.5, _intro)
		return
	Profile.data.flags.intro_done = true
	Game.ui.dialogue("The Keeper", [
		"Another Kindled wakes. Good. The Hearth was starting to forget what hands felt like.",
		"Below us lies the Undervault. It swallowed the sun, piece by piece. Every ember you carry back feeds the Hearth - and you.",
		"Walk to the Descent when you're ready. Commune with the Hearth to grow stronger. And Kindled... the dark remembers who hurts it.",
	])


func _hook_party() -> void:
	if Net.i == null or not is_inside_tree():
		return
	Net.i.roster_changed.connect(_on_party_changed)
	Net.i.camp_changed.connect(_on_camp_changed)
	if not Net.i.sheet_changed.is_connected(_on_sheet_changed):
		Net.i.sheet_changed.connect(_on_sheet_changed)
	if Net.active():
		_join_party_here()
		if Net.is_client() and camp != current_camp():
			Game.reload_hub()


## Co-op: the party is here (a session started, or this sanctuary was built
## with one running): everyone walks it together (HubSync).
func _join_party_here() -> void:
	if sync != null or menu_mode or not Net.active():
		return
	sync = HubSync.new()
	sync.hub = self
	add_child(sync)


func _on_party_changed() -> void:
	if menu_mode or not is_inside_tree():
		return
	if Net.active():
		_join_party_here()
	elif sync != null:
		# the party broke up: back to this profile's own camp
		sync.queue_free()
		sync = null
		for a in actors.duplicate():
			if a is Player and a != player:
				remove_actor(a)
				fx.unmark(a)
				a.queue_free()
		if camp != camp_of_profile():
			Game.reload_hub()


func _on_camp_changed() -> void:
	if not menu_mode and camp != current_camp():
		Game.reload_hub()


func _spawn_dummies() -> void:
	for p in [Vector2(7.5, 17.5), Vector2(11.5, 18.0)]:
		var d := TrainingDummy.new()
		d.pos = p
		add_actor(d)


## The workshop at work: sparks and a clank as the smith's hammer lands on
## the anvil (his strike frame), smoke from the chimney, the fire breathing.
func _workshop(real: float) -> void:
	if forge_prop == null:
		return
	if smith_prop and smith_prop.sprite and anvil_prop:
		var f := smith_prop.sprite.frame_i
		if f != _smith_frame:
			_smith_frame = f
			if f == 3:
				_strikes += 1
				var at := anvil_prop.pos + Vector2(-0.2, -0.1)
				fx.burst(at, 0.55, Color(1.0, 0.72, 0.32), 6 + (_strikes % 3) * 2, 3.2, 0.3, 7.0, Vector2.UP, 1.3)
				if anvil_prop.sprite:
					anvil_prop.sprite.play("struck", true)
				# every blow rings (its own anvil, three takes); every fourth one
				# lands harder, the fire answering it
				var hard := _strikes % 4 == 0
				Audio.play_at("anvil", at, -9.0 if hard else -13.0, randf_range(0.97, 1.03), 200)
				if hard:
					fx.flash_light(at, 0.6, Color(1.0, 0.65, 0.3), 1.6, 4.0, 0.2)
			elif f == 5 and anvil_prop.sprite and anvil_prop.sprite.anim == "struck":
				anvil_prop.sprite.play("idle")
	# chimney smoke, thicker for a master's workshop
	_smoke_t += real
	var every := 0.45 if int(camp.forge) >= 3 else 0.7
	if _smoke_t > every:
		_smoke_t = 0.0
		fx.motes(forge_prop.pos + Vector2(randf_range(-0.15, 0.15), -0.2), 2.6, Color(0.42, 0.4, 0.44), 1, 0.25, 2.4, 0.2)
	# the bellows now and then, and the fire flares with them
	_bellows_t -= real
	if _bellows_t <= 0.0:
		_bellows_t = randf_range(5.0, 8.0)
		_flare_t = 1.2
		Audio.play_at("bellows", forge_prop.pos, -12.0, randf_range(0.95, 1.05), 300)
		fx.motes(forge_prop.pos + Vector2(0, -0.1), 1.0, Color(1.0, 0.6, 0.25), 6, 1.2, 0.8, 0.25)
	_flare_t = maxf(0.0, _flare_t - real)
	# the fire breathes
	if forge_prop.light:
		var t := Time.get_ticks_msec() / 1000.0
		var flare := sin(clampf(_flare_t / 1.2, 0.0, 1.0) * PI) * 0.8
		forge_prop.light.light_energy = 1.7 + 0.22 * sin(t * 6.3) + 0.12 * sin(t * 15.7) + flare


## Crafting feedback in the world: the smith's anvil flares and the quench
## barrel hisses when something is made or tempered (SmithyUI, the forge).
func workshop_flare(big := false) -> void:
	if anvil_prop == null:
		return
	var at := anvil_prop.pos + Vector2(-0.2, -0.1)
	fx.burst(at, 0.6, Color(1.0, 0.75, 0.35), 24 if big else 14, 4.5, 0.45, 8.0, Vector2.UP, 1.4)
	fx.flash_light(at, 0.8, Color(1.0, 0.65, 0.3), 3.0 if big else 2.0, 5.0, 0.35)
	if anvil_prop.sprite:
		anvil_prop.sprite.play("struck", true)
	Audio.play_at("clank", at, -6.0, 0.9, 120)
	if quench_prop and quench_prop.sprite:
		quench_prop.sprite.play("steam", true)
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_instance_valid(quench_prop) and quench_prop.sprite:
				quench_prop.sprite.play("idle"))
		fx.motes(quench_prop.pos + Vector2(0, -0.2), 1.4, Color(0.85, 0.85, 0.9), 8, 0.4, 1.6, 0.3)


func _stage_process(real: float) -> void:
	_steam_t += real
	if cookpot and _steam_t > 0.22:
		_steam_t = 0.0
		fx.motes(cookpot.pos + Vector2(randf_range(-0.2, 0.2), 0), 1.0, Color(0.7, 0.68, 0.72), 1, 0.4, 1.8, 0.15)
	_workshop(real)
	# moths and fireflies drift around the lit lanterns
	_fly_t += real
	if _fly_t > 0.5 and not lit_lanterns.is_empty():
		_fly_t = 0.0
		var lp: Prop = lit_lanterns[randi() % lit_lanterns.size()]
		fx.motes(lp.pos + Vector2(randf_range(-0.6, 0.6), randf_range(-0.4, 0.2)), 1.4, Color(1.0, 0.9, 0.55), 1, 0.25, 2.6, 0.8)
	_gate(real)
	_ember_t += real
	if _ember_t > 0.06:
		_ember_t = 0.0
		fx.motes(Vector2(21.0, 11.5) + Vector2(randf_range(-0.6, 0.6), 0), 1.0, Color(1.0, randf_range(0.5, 0.8), 0.3), 1, 2.2, 1.6, 0.3)


## The Undervault Gate breathes: soul motes rise out of the veil, and its runes
## all wake (light swelling) when the Kindled comes near. It hums, low.
func _gate(real: float) -> void:
	if gate_prop == null or _gate_flaring or menu_mode:
		return
	var mouth := gate_prop.pos + Vector2(0, -0.6)
	var near := player != null and player.pos.distance_to(gate_prop.pos) < 4.5
	gate_prop.sprite.play("wake" if near else "idle")
	if gate_prop.light:
		var want := 2.4 if near else 1.4
		gate_prop.light.light_energy = lerpf(gate_prop.light.light_energy, want + sin(elapsed * 2.2) * 0.15, minf(1.0, real * 3.0))
	_gate_t += real
	if _gate_t > (0.08 if near else 0.18):
		_gate_t = 0.0
		fx.motes(mouth + Vector2(randf_range(-1.0, 1.0), randf_range(-0.2, 0.3)), randf_range(0.4, 1.6), Color(0.45, 1.0, 0.88), 1, 0.9, 2.2, 0.2)
	_hum_t -= real
	if _hum_t <= 0.0 and player and player.pos.distance_to(gate_prop.pos) < 10.0:
		_hum_t = 2.4
		Audio.play_at("gate_hum", gate_prop.pos, -9.0 if near else -15.0, 1.0, 500)


## The Kindled steps through: the veil flares, they come apart into embers.
## Returns how long it takes.
func flare_gate() -> float:
	if gate_prop == null or player == null:
		return 0.0
	_gate_flaring = true
	player.input_enabled = false
	player.vel = Vector2.ZERO
	gate_prop.sprite.play("flare", true)
	var mouth := gate_prop.pos + Vector2(0, -0.6)
	fx.flash_light(mouth, 1.2, Color(0.5, 1.0, 0.9), 6.0, 10.0, 1.2)
	fx.ring(mouth, 2.6, Color(0.55, 1.0, 0.9), 0.6, 0.3)
	fx.motes(mouth, 0.6, Color(0.55, 1.0, 0.9), 30, 2.4, 1.2, 1.2)
	fx.shake(0.2)
	Audio.play("gate_flare", -2.0)
	var pl := player
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(pl.hide_gear)
	tw.tween_method(pl.sprite.set_dissolve, 0.0, 1.0, 0.75)
	# the whole party goes into the light together
	if sync:
		sync.set_process(false)
		for other in sync.others.values():
			if is_instance_valid(other):
				var tw2 := create_tween()
				tw2.tween_interval(0.25)
				tw2.tween_callback(other.hide_gear)
				tw2.tween_method(other.sprite.set_dissolve, 0.0, 1.0, 0.75)
				fx.motes(other.pos, 0.4, Color(1.0, 0.7, 0.35), 10, 1.6, 0.8, 0.3)
	for k in 6:
		after(0.25 + k * 0.12, func() -> void:
			fx.motes(pl.pos, 0.4, Color(1.0, 0.7, 0.35), 3, 1.6, 0.8, 0.3))
	return 1.1


func request(what: String, prop: Prop) -> void:
	match what:
		"hearth":
			Game.ui.skill_tree()
		"descent":
			Game.ui.descent_prompt()
		"rack":
			Game.ui.weapon_select()
		"forge", "forge_ruin":
			# a guest at the host's forge uses (or rebuilds) their own
			if Profile.building("forge") > 0:
				Game.ui.forge()
			else:
				Game.ui.sanctuary_build("forge")
		"smith":
			if Profile.building("forge") > 0:
				Game.ui.smithy()
			else:
				Game.ui.toast("Your own camp needs its forge rebuilt first.", UIKit.C_DIM)
		"peddler":
			Game.ui.peddler()
		"apothecary", "memorial":
			if what == "memorial" and Profile.building("shrine") > 0:
				Game.ui.memorial()
			else:
				Game.ui.sanctuary_build({"apothecary": "apothecary", "memorial": "shrine"}[what])
		"keeper":
			prop.sprite.play("talk")
			prop.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
			Game.ui.dialogue("The Keeper", Keeper.lines(), func() -> void:
				if is_instance_valid(prop):
					prop.sprite.process_mode = Node.PROCESS_MODE_INHERIT
					prop.sprite.play("idle"))
		"resident":
			_talk_to(prop as Wanderer)
		"trophy":
			Game.ui.dialogue(String(prop.data.prompt), prop.data.get("lines", []))
		"wardrobe":
			Game.ui.wardrobe()
		"cat":
			(prop as CampCat).pet()
	prop.set_meta("last_used", elapsed)


## The camp cat: wanders between warm places, naps by the Hearth, and does
## not mind being petted. Moves itself (a Prop that ticks), so it can still be
## interacted with wherever it ends up.
class CampCat:
	extends Prop

	# its own warm places, clear of where the residents stand and sit
	const SPOTS := [Vector2(20.4, 13.7), Vector2(16.3, 11.0), Vector2(27.2, 13.1), Vector2(13.2, 10.9), Vector2(28.4, 15.6)]
	var mode := "sleep"
	var mode_t := 6.0
	var target := Vector2.ZERO

	func tick(dt: float) -> void:
		if following:
			follow_step(dt, 1.6)
			return
		mode_t -= dt
		match mode:
			"walk":
				var d := target - pos
				if d.length() < 0.15:
					mode = "sleep" if randf() < 0.5 else "idle"
					mode_t = randf_range(6.0, 14.0) if mode == "sleep" else randf_range(2.0, 4.0)
					sprite.play(mode)
				else:
					pos += d.normalized() * minf(1.1 * dt, d.length())
					sprite.flip_h = d.x < 0.0
					position = Iso.to_world(pos, 0.0)
			_:
				if mode_t <= 0.0:
					target = SPOTS[randi() % SPOTS.size()]
					mode = "walk"
					sprite.play("walk")

	func pet() -> void:
		mode = "idle"
		mode_t = 3.0
		sprite.play("idle")
		stage.fx.burst(pos, 0.6, Color(1.0, 0.55, 0.6), 6, 1.5, 0.6, -1.0)
		stage.fx.number(pos, 1.4, "purr", Color(1.0, 0.8, 0.75))
		Audio.play("pickup_heal", -8.0, 1.6)


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
