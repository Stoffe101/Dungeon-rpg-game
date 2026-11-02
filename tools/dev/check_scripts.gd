## Loads every script under res://src and res://tests so parse errors surface.
## Usage: godot --headless --path . -s res://tools/dev/check_scripts.gd
extends SceneTree


func _init() -> void:
	var files: Array[String] = []
	for root in ["res://src", "res://tests"]:
		_collect(root, files)
	var bad := 0
	for f in files:
		var s: Script = load(f)
		if s == null or not s.can_instantiate():
			bad += 1
			print("FAILED: ", f)
	print("checked %d scripts, %d failed" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)
