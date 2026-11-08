## Dev: many sprite sheets on one board, upscaled, on a dark floor colour.
##   godot --headless --path . -s res://tools/art/preview_many.gd -- out=captures/x.png scale=3 cols=6 a b c
## Names are sprites without path or extension.
extends SceneTree


func _init() -> void:
	var out := "captures/preview_many.png"
	var scale := 3
	var cols := 6
	var names: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("scale="):
			scale = int(a.substr(6))
		elif a.begins_with("cols="):
			cols = int(a.substr(5))
		else:
			names.append(a)
	var imgs: Array[Image] = []
	var cw := 0
	var ch := 0
	for n in names:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % n))
		imgs.append(img)
		cw = maxi(cw, img.get_width())
		ch = maxi(ch, img.get_height())
	var rows := ceili(float(imgs.size()) / float(cols))
	var board := Image.create_empty((cw + 6) * cols, (ch + 6) * rows, false, Image.FORMAT_RGBA8)
	board.fill(Color(0.14, 0.13, 0.18))
	for i in imgs.size():
		var at := Vector2i((i % cols) * (cw + 6) + 3, (i / cols) * (ch + 6) + 3)
		board.blend_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), at)
	board.resize(board.get_width() * scale, board.get_height() * scale, Image.INTERPOLATE_NEAREST)
	board.save_png(ProjectSettings.globalize_path("res://" + out))
	print("wrote ", out)
	quit()
