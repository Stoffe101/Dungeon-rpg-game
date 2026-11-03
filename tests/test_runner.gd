## Runs every tests/test_*.gd. Usage:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 when everything passes.
extends Node


func _ready() -> void:
	# never touch the real save
	Profile.path = "user://test_profile.json"
	Profile.data = Profile.fresh()
	var total := 0
	var failed: Array[String] = []
	var d := DirAccess.open("res://tests")
	var files := Array(d.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd" and f != "test_case.gd")
	files.sort()
	for f in files:
		var scr: GDScript = load("res://tests/" + f)
		var inst: TestCase = scr.new()
		if inst.has_method("setup_tree"):
			inst.call("setup_tree", self)
		for m in inst.get_method_list():
			var n: String = m.name
			if not n.begins_with("test_"):
				continue
			inst.current = "%s.%s" % [f.get_basename(), n]
			var before := inst.failures.size()
			var r: Variant = inst.call(n)
			if r is Object and r.has_method("is_valid"):
				pass
			total += 1
			if inst.failures.size() == before:
				print("  ok    ", inst.current)
			else:
				print("  FAIL  ", inst.current)
		failed.append_array(inst.failures)
	print("")
	for f in failed:
		print("FAILURE: ", f)
	print("%d tests, %d failures" % [total, failed.size()])
	get_tree().quit(0 if failed.is_empty() else 1)
