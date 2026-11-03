## Writes upscaled previews of generated PNGs to captures/ for review.
## Usage: godot --headless --path . -s res://tools/art/preview.gd -- res://assets/sprites/player.png [scale=4]
extends SceneTree


func _init() -> void:
	var scale := 4
	var files: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scale="):
			scale = int(a.substr(6))
		else:
			files.append(a)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(f))
		if img == null:
			push_error("cannot load " + f)
			continue
		var bg := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(Color(0.16, 0.15, 0.2))
		# checker to show transparency
		for y in img.get_height():
			for x in img.get_width():
				if ((x >> 3) + (y >> 3)) % 2 == 0:
					bg.set_pixel(x, y, Color(0.2, 0.19, 0.25))
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		bg.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
		var out := "res://captures/preview_" + f.get_file()
		bg.save_png(ProjectSettings.globalize_path(out))
		print("wrote ", out)
	quit()
