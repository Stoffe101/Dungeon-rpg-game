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


## How each foe falls and flinches (its hurt and death rows are drawn from its
## own idle body, see `_reactions`): skeletal things crumble to a pile as the
## soul-light leaves their eyes, upright fighters topple backwards, crawlers
## fold up, soft and growing things slump and melt into the floor.
const FALL_STYLE := {
	"husk": "crumble", "ash_seal": "crumble", "bonecaller": "crumble", "lampwight": "crumble", "wraith": "crumble", "sunwatcher": "crumble",
	"guard": "topple", "archer": "topple", "duelist": "topple", "sentinel": "topple", "acolyte": "topple", "gravemole": "topple",
	"skitter": "curl", "spider": "curl", "moth": "curl", "hound": "curl", "thornback": "curl",
	"bloat": "melt", "sporeling": "melt", "toad": "melt", "bramblewright": "melt", "rootweaver": "melt", "spore_mortar": "melt",
}


func save(dir: String, sheet_name: String) -> void:
	if FALL_STYLE.has(sheet_name):
		_reactions(String(FALL_STYLE[sheet_name]))
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


# --- hurt and death, drawn from the idle body ----------------------------------------

func _has(anim: String) -> bool:
	for r in rows:
		if r.name == anim:
			return true
	return false


func _reactions(style: String) -> void:
	var base: Px = null
	for r in rows:
		if r.name == "idle" and not (r.frames as Array).is_empty():
			base = r.frames[0]
	if base == null:
		return
	if not _has("hurt"):
		# flinching: the body rocks back from the blow (faces right: back is left)
		add("hurt", [_shear(base, -3, 0), _shear(base, -1, 0)], 12.0, false)
	if not _has("death"):
		var frames: Array = []
		for k in range(1, 6):
			frames.append(_fall(base, style, k / 5.0))
		add("death", frames, 10.0, false)


## The frame with its upper body leaning by up to `lean` px (rows above the
## feet slide in proportion to their height), and `drop` px lower.
func _shear(src: Px, lean: int, drop: int) -> Px:
	var out := Px.new(fw, fh)
	var foot := origin.y
	for y in fh:
		var k := clampf(float(foot - y) / maxf(1.0, float(foot)), 0.0, 1.0)
		var dx := roundi(lean * k)
		for x in fw:
			var c := src.get_c(x, y)
			if c.a <= 0.5:
				continue
			var nx := x + dx
			var ny := y + drop
			if src.glow[y * fw + x] != 0:
				out.lit(nx, ny, c)
			else:
				out.put(nx, ny, c)
	return out


## One moment `t` (0..1] of a fall in `style`, drawn from the body's own
## pixels (darkening as it goes; the eyes' soul-light goes out early).
## Crumbling scatters each piece; toppling, curling and melting sample every
## target pixel from the body (no holes).
func _fall(src: Px, style: String, t: float) -> Px:
	if style == "crumble":
		return _crumble(src, t)
	var out := Px.new(fw, fh)
	var foot := float(origin.y)
	var cx := float(origin.x)
	var dark := 1.0 - 0.28 * t
	var ang := t * deg_to_rad(64.0)      # topple: back onto the floor (the dissolve finishes it)
	if style == "topple":
		cx += 5.0 * t                    # (the pivot slides on, so the body stays in its frame)
	for y in fh:
		for x in fw:
			var px := float(x) - cx + 0.5
			var hh := foot - float(y) - 0.5
			var sx := 0.0
			var sh := 0.0
			match style:
				"topple":
					sx = px * cos(ang) + hh * sin(ang)
					sh = -px * sin(ang) + hh * cos(ang)
				"curl":
					sx = px / (1.0 - 0.3 * t)
					sh = hh / (1.0 - 0.58 * t)
				_:   # melt
					sx = px / (1.0 + 0.45 * t)
					sh = hh / maxf(0.2, 1.0 - 0.78 * t)
			var ix := floori(cx + sx)
			var iy := floori(foot - sh)
			if sh < -0.5 or not src.inside(ix, iy):
				continue
			var c := src.get_c(ix, iy)
			if c.a <= 0.5:
				continue
			if src.glow[iy * fw + ix] != 0 and t < 0.45:
				out.lit(x, y, c)
			else:
				out.put(x, y, Color(c.r * dark, c.g * dark, c.b * dark, 1.0))
	return out


func _crumble(src: Px, t: float) -> Px:
	var out := Px.new(fw, fh)
	var foot := origin.y
	var cx := float(origin.x)
	var dark := 1.0 - 0.28 * t
	# lowest pieces first, so higher ones land on top of the pile
	for y in range(fh - 1, -1, -1):
		for x in fw:
			var c := src.get_c(x, y)
			if c.a <= 0.5:
				continue
			var hgt := float(foot - y)
			var hsh := Px.hash01(x, y, 7)
			var fallen := minf(hgt * 0.8, hgt * t * t * 0.95 + hsh * 2.5 * t)     # (a low pile is left)
			var nx := x + (x - cx) * 0.35 * t * (0.5 + hsh) + (hsh - 0.5) * 3.0 * t
			var tx := roundi(nx)
			var ty := mini(roundi(y + fallen), foot)
			if src.glow[y * fw + x] != 0 and t < 0.45:
				out.lit(tx, ty, c)
			else:
				out.put(tx, ty, Color(c.r * dark, c.g * dark, c.b * dark, 1.0))
	return out
