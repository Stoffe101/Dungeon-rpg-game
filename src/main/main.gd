## Root of the running game: owns the pixel world view and the UI layer,
## then hands control to the Game autoload.
## Dev command line (after `--`): scene=menu|hub|dungeon|boss  seed=N  capture=name frames=N quit
## open=inventory|smithy|peddler  rich (grant the test stockpile)  pad (pretend a gamepad is in use)  hitlab (enemies beside the player; lab=<id,id:affix> picks them)  burst=<count>:<step> (with capture=)  omens=<id,id>  open=skilltree|forge|descent|settings|controls|pause|relic|summary
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
	fps_label = UIKit.label("", 8, UIKit.C_DIM, true)
	fps_label.position = Vector2(4, 0)
	ui.root.add_child(fps_label)
	var scene := "menu"
	var region := "ossuary"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("region="):
			region = a.substr(7)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene = a.substr(6)
		elif a.begins_with("weapon="):
			Profile.unlock_weapon(a.substr(7))
			Profile.data.equipped.weapon = a.substr(7)
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
		elif a.begins_with("look="):
			Looks.unlock(a.substr(5))
			Looks.choose(a.substr(5))
		elif a == "unlock=all":
			# dev: open every region and difficulty tier
			for k in ["warden_kills", "bloom_kills"]:
				Profile.data.world[k] = maxi(1, int(Profile.data.world.get(k, 0)))
			Difficulty._d()["unlocked"] = Difficulty.MAX_TIER
		elif a.begins_with("kit="):
			# dev: wear a random epic level-5 loadout of the given item tier
			var kt := clampi(int(a.substr(4)), 1, ItemDB.MAX_TIER)
			var krng := RandomNumberGenerator.new()
			krng.seed = kt
			for slot in ItemDB.SLOTS:
				var pool: Array = ItemDB.BASES.keys().filter(func(b): return ItemDB.base(b).slot == slot and not ItemDB.is_unique(b) and not ItemDB.base(b).has("set") and not ItemDB.base(b).get("legendary", false))
				Profile.equipped()[slot] = ItemDB.make_item(String(pool[krng.randi_range(0, pool.size() - 1)]), "epic", 5, krng, kt)
		elif a.begins_with("tier="):
			# dev: open and select a difficulty tier
			var t := clampi(int(a.substr(5)), 1, Difficulty.MAX_TIER)
			Difficulty._d()["unlocked"] = maxi(Difficulty.unlocked(), t)
			Difficulty.select(t)
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
		"boss":
			Game.start_run(region)
			var last := int(EnemyDB.REGIONS[region].depths)
			Game.run.depth = last - 1
			Game._enter_depth(last)
		_:
			Game.goto_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("open="):
			_open_dev_screen.call_deferred(a.substr(5))
		elif a == "uismoke":
			add_child(preload("res://src/dev/ui_smoke.gd").new())


func _open_dev_screen(what: String) -> void:
	match what:
		"skilltree":
			ui.skill_tree()
			for a in OS.get_cmdline_user_args():
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
		"settings":
			ui.settings()
		"controls":
			ui.settings()
			var tabs := ui.modal_layer.find_children("*", "TabContainer", true, false)
			if not tabs.is_empty():
				(tabs[0] as TabContainer).current_tab = 3
		"pause":
			ui.pause_menu()
		"feats":
			ui.open(Screens.feats(ui))
		"bestiary":
			ui.open(Screens.bestiary(ui))
		"inventory":
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
		"relic":
			var rng := RandomNumberGenerator.new()
			ui.relic_choice(RelicDB.roll_offer(rng, 3, [], {}, ["flare"], 2), func(_id): pass)
		"summary":
			ui.show_summary({"outcome": "died", "depth": 2, "kills": 37, "rooms": 11, "time": 612.0, "xp": 240, "relics": ["tinderbox", "echo_mask", "coal_heart"],
				"embers_kept": 84, "embers_lost": 85, "bonus": 0, "sunshards": 1, "grudge": {"name": "Morrow the Patient", "embers": 85}, "settled": [], "unlocked": ""})


func _process(_d: float) -> void:
	fps_label.visible = bool(Settings.get_value("show_fps", false))
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Profile.save_profile()
