## Tiles the centre of several captures into one image, to review fast moments
## (e.g. a burst capture of hits). Dev tool.
## godot --headless --path . -s res://tools/dev/contact_sheet.gd -- out=captures/sheet.png crop=640x400 cols=6 captures/hit_0.png ...
extends SceneTree


func _init() -> void:
	var files: Array[String] = []
	var out := "res://captures/contact_sheet.png"
	var crop := Vector2i(640, 400)
	var cols := 6
	var scale := 0.5
	var at := Vector2i(-1, -1)   # top-left of the crop (default: centred)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = "res://" + a.substr(4)
		elif a.begins_with("crop="):
			var p := a.substr(5).split("x")
			crop = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("cols="):
			cols = int(a.substr(5))
		elif a.begins_with("scale="):
			scale = float(a.substr(6))
		elif a.begins_with("at="):
			var q := a.substr(3).split(",")
			at = Vector2i(int(q[0]), int(q[1]))
		else:
			files.append(a)
	var cell := Vector2i(int(crop.x * scale), int(crop.y * scale))
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create_empty(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	for i in files.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://" + files[i]))
		if img == null:
			continue
		var c := (img.get_size() - crop) / 2 if at.x < 0 else at
		img.convert(Image.FORMAT_RGBA8)
		var part := img.get_region(Rect2i(c, crop))
		part.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	sheet.save_png(ProjectSettings.globalize_path(out))
	print("wrote ", out)
	quit()
