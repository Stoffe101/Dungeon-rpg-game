## Collects animation rows of equally sized frames and writes a sprite sheet
## PNG plus a JSON sidecar the game reads (frame size, origin, animations).
extends RefCounted

const Px = preload("res://tools/art/px.gd")

var fw: int
var fh: int
var origin: Vector2i
var rows: Array = []


func _init(frame_w: int, frame_h: int, foot: Vector2i) -> void:
	fw = frame_w
	fh = frame_h
	origin = foot


func add(anim: String, frames: Array, fps: float, loop := true) -> void:
	rows.append({"name": anim, "frames": frames, "fps": fps, "loop": loop})


func save(dir: String, sheet_name: String) -> void:
	var cols := 1
	for r in rows:
		cols = maxi(cols, r.frames.size())
	var out := Px.new(cols * fw, rows.size() * fh)
	var anims := {}
	for ri in rows.size():
		var r: Dictionary = rows[ri]
		for fi in r.frames.size():
			out.blit(r.frames[fi], fi * fw, ri * fh)
		anims[r.name] = {"row": ri, "frames": r.frames.size(), "fps": r.fps, "loop": r.loop}
	out.save(dir.path_join(sheet_name + ".png"))
	var emit_path := ProjectSettings.globalize_path(dir.path_join(sheet_name + "_emit.png"))
	if out.has_glow():
		out.glow_image().save_png(emit_path)
	elif FileAccess.file_exists(emit_path):
		DirAccess.remove_absolute(emit_path)
	var meta := {"frame": [fw, fh], "origin": [origin.x, origin.y], "anims": anims, "emit": out.has_glow()}
	var f := FileAccess.open(ProjectSettings.globalize_path(dir.path_join(sheet_name + ".json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
