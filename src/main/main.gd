## Root of the running game: owns the pixel world view and the UI layer,
## then hands control to the Game autoload.
## Dev command line (after `--`): scene=menu|hub|dungeon|boss  seed=N  capture=name frames=N quit
## open=inventory|smithy|peddler  rich (grant the test stockpile)  pad (pretend a gamepad is in use)  hitlab (enemies beside the player; lab=<id,id:affix> picks them)  burst=<count>:<step> (with capture=)  omens=<id,id>  descend (hub: go through the gate)  open=skilltree|forge|descent|settings|controls|pause|relic|summary
extends Control

var view: PixelView
var ui: UIRoot
var fps_label: Label


func _ready() -> void:
	view = PixelView.new()
	add_child(view)
	ui = UIRoot.new()
	add_child(ui)
	Game.attach(self, view, ui)
	add_child(Capture.from_args())
	if "perflog" in Dev.args():
		get_tree().process_frame.connect(_perf_tick)
	for a in Dev.args():
		if a == "stallog" or a.begins_with("stallog="):
			add_child(StallProbe.new())     # dev: takes slow frames apart
	fps_label = UIKit.label("", 8, UIKit.C_DIM, true)
	fps_label.position = Vector2(4, 0)
	ui.root.add_child(fps_label)
	var scene := "menu"
	var region := "ossuary"
	for a in Dev.args():
		if a.begins_with("region="):
			region = a.substr(7)
	for a in Dev.args():
		if a.begins_with("scene="):
			scene = a.substr(6)
		elif a.begins_with("weapon="):
			Profile.unlock_weapon(a.substr(7))
			Profile.choose_weapon(a.substr(7))
		elif a.begins_with("skills="):
			# dev: skills=all grants levels and allocates the whole tree
			for i in 120:
				Profile.add_xp(Combat.xp_to_next(Profile.level()))
			var changed := true
			while changed:
				changed = false
				for id in SkillDB.all_ids():
					if Profile.allocate(id):
						changed = true
			Profile.data.equipped.slots = ["cinder_lance", "frost_sigil"] if a.substr(7) == "all" else Profile.data.equipped.slots
		elif a.begins_with("forge="):
			# dev: forge=0..3 sets the workshop's level (the camp shows it)
			Profile.data.sanctuary["forge"] = clampi(int(a.substr(6)), 0, int(Profile.SANCTUARY.forge.max))
		elif a.begins_with("build="):
			# dev: build=knives|lantern|rush|hail|bulwark|frost|starter (src/dev/build_presets.gd)
			BuildPresets.apply(a.substr(6))
		elif a.begins_with("grudge="):
			var rng := RandomNumberGenerator.new()
			Profile.record_grudge(a.substr(7), 60, 1, rng)
		elif a.begins_with("wear="):
			# dev: wear=emberwrought (a whole set, made on the spot) or base ids, comma separated
			var rng_w := RandomNumberGenerator.new()
			var ids: Array = Array(a.substr(5).split(","))
			if ids.size() == 1 and ItemDB.SETS.has(ids[0]):
				ids = ItemDB.set_pieces(ids[0])
			for b in ids:
				var it := Profile.add_item(ItemDB.make_item(b, "rare", 1, rng_w, 2))
				Profile.equip(int(it.uid))
		elif a.begins_with("hunt="):
			# dev: carry the hunt notice for this region (its guardian counted as fallen)
			var reg := a.substr(5)
			Profile.data.world["%s_kills" % EnemyDB.REGIONS[reg].boss] = maxi(1, int(Profile.data.world.get("%s_kills" % EnemyDB.REGIONS[reg].boss, 0)))
			Profile.data["contracts"] = {"offer": ["hunt_" + reg], "taken": [], "done": 0}
			Contracts.take("hunt_" + reg)
		elif a.begins_with("evolve="):
			# dev: the worn weapon (a great one) has grown and chosen this path
			var wi: Variant = Profile.equipped().get("weapon")
			if wi is Dictionary and Evolutions.can_evolve(wi):
				wi["res"] = Evolutions.ASCEND
				Evolutions.choose(wi, a.substr(7))
		elif a.begins_with("look="):
			Looks.unlock(a.substr(5))
			Looks.choose(a.substr(5))
		elif a == "unlock=all":
			# dev: open every region and difficulty tier
			for k in ["warden_kills", "bloom_kills", "ashen_king_kills"]:
				Profile.data.world[k] = maxi(1, int(Profile.data.world.get(k, 0)))
			Difficulty._d()["unlocked"] = Difficulty.MAX_TIER
		elif a.begins_with("kit="):
			# dev: wear a random epic level-5 loadout of the given item tier
			var kt := clampi(int(a.substr(4)), 1, ItemDB.MAX_TIER)
			var krng := RandomNumberGenerator.new()
			krng.seed = kt
			var arch_now := Profile.equipped_weapon()
			for slot in ItemDB.SLOTS:
				# (the weapon stays the kind already chosen: a build's weapon is its moveset)
				var pool: Array = ItemDB.weapon_bases(arch_now) if slot == "weapon" else ItemDB.BASES.keys().filter(func(b): return ItemDB.base(b).slot == slot and not ItemDB.is_unique(b) and not ItemDB.base(b).has("set") and not ItemDB.base(b).get("legendary", false))
				Profile.equipped()[slot] = ItemDB.make_item(String(pool[krng.randi_range(0, pool.size() - 1)]), "epic", 5, krng, kt)
		elif a.begins_with("tier="):
			# dev: open and select a difficulty tier
			var t := clampi(int(a.substr(5)), 1, Difficulty.MAX_TIER)
			Difficulty._d()["unlocked"] = maxi(Difficulty.unlocked(), t)
			Difficulty.select(t)
		elif a == "maren":
			Chronicle.rescue("maren")     # (dev: she is already at the Hearth)
		elif a == "rich":
			Profile._grant_stockpile(Profile.data)
		elif a.begins_with("omens="):
			# dev: read these Omens on the next expedition (they still need unlocking)
			Profile.data.descent.omens = Array(a.substr(6).split(","))
		elif a == "pad":
			# dev: start as if a gamepad were in use (prompts, focus)
			Settings.using_pad = true
			UIKit.show_focus_ring(true)
		elif a.begins_with("set="):
			# dev: set=ui_scale:2
			var kv := a.substr(4).split(":")
			if kv.size() == 2:
				Settings.set_value(kv[0], int(kv[1]) if kv[1].is_valid_int() else kv[1], false)
	match scene:
		"hub":
			Game.goto_hub()
		"siltest":
			Game.goto_hub()
			Game.stage.player.pos = Vector2(7.5, 6.4)
			Game.stage.player.input_enabled = false
		"dungeon":
			Game.start_run(region)
			var dev_depth := -1
			for a in Dev.args():
				if a.begins_with("depth="):
					# dev: start deeper (the Hollow Below's Echo depths, mostly)
					dev_depth = int(a.substr(6))
				if a.begins_with("route="):
					# dev: a floor reached by one of the Forked Descent's ways (DungeonGen.ROUTES)
					Game.run.route = a.substr(6)
					dev_depth = maxi(dev_depth, 2)
			if dev_depth > 0:
				Game._enter_depth(dev_depth)
		"boss":
			Game.start_run(region)
			var last := int(EnemyDB.REGIONS[region].depths)
			Game.run.depth = last - 1
			Game._enter_depth(last)
		_:
			Game.goto_menu()
	for a in Dev.args():
		if a.begins_with("open="):
			_open_dev_screen.call_deferred(a.substr(5))
		elif a == "uismoke":
			add_child(preload("res://src/dev/ui_smoke.gd").new())
		elif a == "scaling":
			add_child(ScalingEval.new())     # dev: party-size scaling evaluation
		elif a == "economy":
			add_child(EconomyAudit.new())    # dev: what a floor pays each Kindled, by source
		elif a == "weaponlab":
			add_child(WeaponLab.new())       # dev: every weapon side by side, measured
		elif a == "legendlab":
			add_child(LegendLab.new())       # dev: how often signature weapon moments come
		elif a == "sitefind":
			add_child(SiteFinder.new())      # dev: a seed for each way's form and each event
		elif a.begins_with("scenario="):
			add_child(Scenario.new())


func _open_dev_screen(what: String) -> void:
	match what:
		"noticeboard":
			Game.ui.noticeboard()
		"skilltree":
			ui.skill_tree()
			for a in Dev.args():
				if a.begins_with("hover="):
					# dev: show the tooltip / path preview for a node
					var tree := ui.modal_layer.find_children("*", "SkillTreeUI", true, false)
					if not tree.is_empty():
						var t: SkillTreeUI = tree[0]
						await get_tree().process_frame
						t._set_hovered(a.substr(6))
						t._place_tip(t.to_screen(SkillDB.position_of(a.substr(6))))
				elif a.begins_with("focus="):
					var tf := ui.modal_layer.find_children("*", "SkillTreeUI", true, false)
					if not tf.is_empty():
						await get_tree().process_frame
						(tf[0] as SkillTreeUI)._focus_branch(a.substr(6))
				elif a.begins_with("search="):
					var trees := ui.modal_layer.find_children("*", "SkillTreeUI", true, false)
					if not trees.is_empty():
						(trees[0] as SkillTreeUI).search_box.text = a.substr(7)
						(trees[0] as SkillTreeUI)._on_search(a.substr(7))
		"forge":
			ui.forge()
		"descent":
			ui.descent_prompt()
		"spellpick":
			ui.descent_prompt()
			ui.open(Screens.spell_picker(ui, 1, func() -> void: pass))
		"settings", "controls":
			ui.settings()
			# dev: page=<audio|display|gameplay|access|coop|controls>
			var pg := "controls" if what == "controls" else ""
			for a in Dev.args():
				if a.begins_with("page="):
					pg = a.substr(5)
			var sets := ui.modal_layer.find_children("*", "SettingsUI", true, false)
			if pg != "" and not sets.is_empty():
				(sets[0] as SettingsUI)._open_page(pg)
		"pause":
			ui.pause_menu()
		"chronicle":
			if "sample" in Dev.args():
				# dev: something for the screen to say (a dev profile only)
				Chronicle.set_site("ossuary", "kindled")
				Chronicle.set_site("rootmire", "broken")
				Chronicle.set_site("throne", "pact")
				Chronicle.mark("rifts_closed", 2)
				Chronicle.mark("grudges_settled", 3)
				Chronicle.note("Sarn the Patient is settled.")
				Chronicle.note("A cold brazier lit again, among those who held the line.")
			ui.open(Screens.chronicle(ui))
		"feats":
			ui.open(Screens.feats(ui))
		"bestiary":
			ui.open(Screens.bestiary(ui))
		"map":
			# the full map (with `explored`: every room walked, to see a whole floor)
			await get_tree().create_timer(1.2).timeout
			if Game.stage is Dungeon:
				if Dev.args().has("explored"):
					for r in (Game.stage as Dungeon).layout.rooms:
						r.visited = true
				ui.hud.toggle_big_map()
		"minimap":
			await get_tree().create_timer(1.2).timeout
			if Game.stage is Dungeon and Dev.args().has("explored"):
				for r in (Game.stage as Dungeon).layout.rooms:
					r.visited = true
		"inventory":
			if Dev.args().has("saveload"):
				Profile.save_loadout(0)     # (dev: a saved build to look at)
			ui.inventory()
		"wardrobe":
			ui.inventory()
			var invs := ui.modal_layer.find_children("*", "InventoryUI", true, false)
			if not invs.is_empty():
				(invs[0] as InventoryUI).wardrobe_open = true
				(invs[0] as InventoryUI).rebuild()
		"smithy":
			ui.smithy()
		"peddler":
			ui.peddler()
		"apothecary":
			ui.apothecary()
		"relic":
			var rng := RandomNumberGenerator.new()
			ui.relic_choice(RelicDB.roll_offer(rng, 3, [], {}, ["flare"], 2), func(_id): pass)
		"coop":
			ui.party()
		"runes":
			ui.open(Screens.runes(ui))
		"summary":
			ui.show_summary({"outcome": "died", "depth": 2, "kills": 37, "rooms": 11, "time": 612.0, "xp": 240, "relics": ["tinderbox", "echo_mask", "coal_heart"],
				"embers_kept": 84, "embers_lost": 85, "bonus": 0, "sunshards": 1, "grudge": {"name": "Morrow the Patient", "embers": 85}, "settled": [], "unlocked": "",
				"omens": ["lightless", "restless"], "omen_embers": 19, "omen_xp": 55, "grudges_grew": ["Vesk the Hungry"],
				"blows": [[100.0, "Hollow Archer", 11.0], [101.2, "Grave Bloat", 26.0], [103.0, "Morrow the Patient", 18.0]], "taken": {"Morrow the Patient": 120.0, "Grave Bloat": 78.0, "Hollow Archer": 40.0},
				"dealt": {"Hearthblade": 2140.0, "Cinder Lance": 880.0, "Burn and poison": 310.0}, "woke": ["Gloamfang stirs."], "contracts": ["Old Scores: 260 Embers, 100 Memories"]})


var _frames: PackedFloat32Array = []
var _perf_t := 0.0
var _perf_last := 0


func _process(_d: float) -> void:
	fps_label.visible = bool(Settings.get_value("show_fps", false))
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()



## Dev (`perflog`): every 10 s, how long frames took - the median, the slow
## ones (95th, 99th percentile) and the worst - and what was on screen.
## (timed from the tree's frame signal and the clock, so it keeps counting
## while a screen pauses the tree - the sanctuary keeps living under one)
func _perf_tick() -> void:
	var now := Time.get_ticks_usec()
	if _perf_last > 0:
		_perf((now - _perf_last) / 1000000.0)
	_perf_last = now


var _worst_at := 0.0
var _worst := 0.0


func _perf(dt: float) -> void:
	_frames.append(dt * 1000.0)
	if dt * 1000.0 > _worst:
		_worst = dt * 1000.0
		_worst_at = Time.get_ticks_msec() / 1000.0
	_perf_t += dt
	if _perf_t < 10.0:
		return
	var f := _frames.duplicate()
	f.sort()
	var n := f.size()
	var st = Game.stage
	print("[perf] frames %d  p50 %.1f ms  p95 %.1f  p99 %.1f  worst %.1f (at %.2f s)  actors %d  particles %d  stage %s" % [n, f[n / 2], f[int(n * 0.95)], f[int(n * 0.99)], f[n - 1], _worst_at,
		st.actors.size() if st else 0, st.fx._p_count if st and st.fx else 0, "-" if st == null else String(st.name)])
	_frames.clear()
	_perf_t = 0.0
	_worst = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Profile.save_profile()
