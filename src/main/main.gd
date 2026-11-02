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
		"dungeon":
			Game.start_run()
		"boss":
			Game.start_run()
			Game.call_deferred("descend")
		_:
			Game.goto_menu()


func _process(_d: float) -> void:
	fps_label.visible = bool(Settings.get_value("show_fps", false))
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Profile.save_profile()
