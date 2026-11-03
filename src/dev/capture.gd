## Development helper: saves screenshots of the real rendered window.
## Command line (after `--`):  capture=<name>  frames=<n>  quit  [burst=<count>:<step>]
## (burst saves <name>_0.. every <step> frames from <n>, to catch fast moments)
## Also bound to F12 (action "screenshot") during play.
class_name Capture
extends Node

var shots: Array = []   # [{frame:int, name:String}]
var quit_after := false
var quit_frame := -1
var _frame := 0


static func from_args() -> Capture:
	var args := Dev.args()
	var c := Capture.new()
	var name := ""
	var frames := 90
	var burst := Vector2i(1, 1)
	for a in args:
		if a.begins_with("capture="):
			name = a.substr(8)
		elif a.begins_with("frames="):
			frames = int(a.substr(7))
		elif a == "quit":
			c.quit_after = true
		elif a.begins_with("burst="):
			var parts := a.substr(6).split(":")
			burst = Vector2i(int(parts[0]), int(parts[1]) if parts.size() > 1 else 1)
	if name != "":
		if burst.x <= 1:
			c.shots.append({"frame": frames, "name": name})
		else:
			for i in burst.x:
				c.shots.append({"frame": frames + i * burst.y, "name": "%s_%d" % [name, i]})
	c.quit_frame = frames if c.quit_after and name == "" else -1
	return c


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_frame += 1
	if quit_frame > 0 and _frame >= quit_frame:
		get_tree().quit()
	for s in shots.duplicate():
		if _frame >= s.frame:
			shots.erase(s)
			save_now(s.name)
			if shots.is_empty() and quit_after:
				get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		save_now("shot_%d" % Time.get_unix_time_from_system())


static func save_now(name: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var img := tree.root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://captures") if OS.has_feature("editor") else OS.get_user_data_dir().path_join("captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[capture] saved ", path, " ", img.get_size())
	return path
