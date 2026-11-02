## Root of the running game: owns the pixel world view and the UI layer,
## then hands control to the Game autoload.
## Dev command line (after `--`): scene=menu|hub|dungeon|boss  seed=N  capture=name frames=N quit
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene = a.substr(6)
	match scene:
		"hub":
			Game.goto_hub()
		"siltest":
			Game.goto_hub()
			Game.stage.player.pos = Vector2(7.5, 6.4)
			Game.stage.player.input_enabled = false
		"dungeon":
			Game.start_run()
		"boss":
			Game.start_run()
			Game.run.depth = 1
			Game._enter_depth(2)
		_:
			Game.goto_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("open="):
			_open_dev_screen.call_deferred(a.substr(5))


func _open_dev_screen(what: String) -> void:
	match what:
		"skilltree":
			ui.skill_tree()
		"forge":
			ui.forge()
		"descent":
			ui.descent_prompt()
		"settings":
			ui.settings()
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
