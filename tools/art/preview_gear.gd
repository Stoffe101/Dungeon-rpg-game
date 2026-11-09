## Dev: the Kindled wearing outfits, in a grid of poses, upscaled.
##   godot --headless --path . -s res://tools/art/preview_gear.gd -- out=captures/gear.png outfits=helm+mail,hood+robe
## Each outfit is a "+"-joined list of armour bases (see GearLooks).
extends SceneTree

const GearLooks = preload("res://src/data/gear_looks.gd")

const POSES := [["idle_down", 0], ["run_down", 2], ["idle_side", 0], ["run_side", 1], ["run_side", 4], ["dash_side", 0], ["cast_down", 1], ["idle_up", 0], ["run_up", 2], ["hurt_side", 0], ["death", 1], ["death", 3], ["death", 4]]


func _init() -> void:
	var out := "res://captures/preview_gear.png"
	var outfits: Array = [""]
	var scale := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = "res://" + a.substr(4) if not a.substr(4).begins_with("res://") else a.substr(4)
		elif a.begins_with("outfits="):
			outfits = Array(a.substr(8).split(","))
		elif a.begins_with("scale="):
			scale = int(a.substr(6))
	var body := _sheet("player")
	var w := 32 * POSES.size()
	var img := Image.create(w, 32 * outfits.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.16, 0.15, 0.2))
	for r in outfits.size():
		var layers: Array = []
		for slot in ["feet", "chest", "hands", "head"]:
			for b in String(outfits[r]).split("+"):
				var vis: Array = GearLooks.VIS.get(b, [])
				if vis.is_empty():
					continue
				if _slot_of(b) == slot:
					layers.append(_sheet("gear_" + b))
		for c in POSES.size():
			var dst := Vector2i(c * 32, r * 32)
			_blit(img, body, POSES[c][0], POSES[c][1], dst)
			for l in layers:
				_blit(img, l, POSES[c][0], POSES[c][1], dst)
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(out))
	print("wrote ", out)
	quit()


func _slot_of(base: String) -> String:
	var s := FileAccess.get_file_as_string("res://src/data/item_db.gd")
	var i := s.find('"%s": {' % base)
	if i < 0:
		return ""
	var j := s.find('"slot": "', i)
	return s.substr(j + 9, s.find('"', j + 9) - j - 9)


func _sheet(name: String) -> Array:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % name))
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % name))
	return [img, info]


func _blit(dst: Image, sh: Array, anim: String, frame: int, at: Vector2i) -> void:
	var src: Image = sh[0]
	var info: Dictionary = sh[1]
	var a: Dictionary = info.anims[anim]
	var fw := int(info.frame[0])
	var fh := int(info.frame[1])
	var rect := Rect2i(frame * fw, int(a.row) * fh, fw, fh)
	dst.blend_rect(src, rect, at)
