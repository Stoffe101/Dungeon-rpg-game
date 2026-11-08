## What a great weapon looks like once it has grown. Every weapon with paths gets one
## sheet per path, its own drawing with the path worked into its silhouette, and one for
## having Awakened: never only a colour. w_<x>_awake, w_<x>_<path id>. Job "grown" (after
## "uniques"). A path means the same shape on every weapon: storm forks, frost grows
## crystals, blood grows barbs, fire stands up in tongues, shade trails rags, echo has a
## second edge, chain is wrapped, knives hang beside it, seek hooks, steam splits and vents.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")
const PAD := 5

const WEAPONS := {
	"w_thousandth": ["echo", "chain"], "w_quakeheart": ["frost", "blood"], "w_hundred": ["wild", "steam"],
	"w_gloamfang": ["shade", "storm"], "w_searing_pike": ["pyre", "knives"], "w_windreturn": ["seek", "wild"],
	"w_hollow_index": ["storm", "steam"], "w_wardenfang": ["knives", "echo"], "w_bloomstring": ["pyre", "seek"],
	"w_sunfall": ["wild", "echo"],
}


static func build(dir: String) -> void:
	for w: String in WEAPONS:
		_one(dir, w, "awake")
		for p: String in WEAPONS[w]:
			_one(dir, w, p)


static func _one(dir: String, weapon: String, path: String) -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(dir.path_join(weapon + ".png")))
	src.convert(Image.FORMAT_RGBA8)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(weapon + ".json")))
	var fw := int(meta.frame[0])
	var fh := int(meta.frame[1])
	var c := Px.new(fw + PAD, fh + PAD * 2)
	for y in fh:
		for x in fw:
			var col := src.get_pixel(x, y)
			if col.a > 0.5:
				c.put(x, y + PAD, Color(col.r, col.g, col.b, 1.0))
	var emit_path := ProjectSettings.globalize_path(dir.path_join(weapon + "_emit.png"))
	if FileAccess.file_exists(emit_path):
		var e := Image.load_from_file(emit_path)
		e.convert(Image.FORMAT_RGBA8)
		for y in fh:
			for x in fw:
				if e.get_pixel(x, y).r > 0.5:
					c.glow[(y + PAD) * c.w + x] = 1
	# the part of the drawing away from the hand
	var top: Array = []
	var bot: Array = []
	top.resize(c.w)
	bot.resize(c.w)
	for x in c.w:
		top[x] = -1
		bot[x] = -1
		for y in c.h:
			if c.opaque(x, y):
				if top[x] < 0:
					top[x] = y
				bot[x] = y
	var from := int(fw * 0.32)
	var tip := fw - 1
	while tip > 0 and top[tip] < 0:
		tip -= 1
	match path:
		"awake":
			# a line of light drawn up the middle, one more texel of point
			for x in range(from, tip + 1):
				if top[x] >= 0:
					var y: int = (top[x] + bot[x]) / 2
					if (x + y) % 3 != 0:
						c.lit(x, y, Pal.GOLD[4])
			c.lit(tip + 1, (top[tip] + bot[tip]) / 2, Pal.GOLD[4])
		"storm":
			var y := int((top[tip] + bot[tip]) / 2)
			var x := tip + 1
			for k in 5:
				c.lit(x, y, Pal.FROST[5])
				x += 1
				y += -1 if k % 2 == 0 else 1
			for x0 in range(from + 2, tip, 5):
				if top[x0] < 0:
					continue
				var yy: int = top[x0] - 1
				c.lit(x0, yy, Pal.FROST[5])
				c.lit(x0 + 1, yy - 1, Pal.FROST[4])
				c.lit(x0, yy - 2, Pal.FROST[5])
				c.put(x0 + 1, yy - 3, Pal.FROST[3])
		"frost":
			for x0 in range(from, tip + 1, 3):
				if top[x0] < 0:
					continue
				var tall := 2 + (x0 / 3) % 3
				for k in tall:
					c.put(x0, top[x0] - 1 - k, Pal.FROST[5 - mini(k, 2)])
				c.put(x0 + 1, top[x0] - 1, Pal.FROST[3])
				if bot[x0] >= 0:
					c.put(x0, bot[x0] + 1, Pal.FROST[4])
		"blood":
			for x0 in range(from, tip + 1, 4):
				if bot[x0] < 0:
					continue
				c.put(x0, bot[x0] + 1, Pal.BLOOD[2])
				c.put(x0 - 1, bot[x0] + 2, Pal.BLOOD[3])
				c.put(x0 - 2, bot[x0] + 3, Pal.BONE[3])
				c.put(x0, top[x0] - 1, Pal.BLOOD[1])
		"wild", "pyre":
			var r: Array = Pal.EMBER
			for x0 in range(from, tip + 1, 2):
				if top[x0] < 0:
					continue
				var tall := 2 + ((x0 * 7) % 4)
				if path == "pyre":
					tall += 1
				for k in tall:
					c.lit(x0, top[x0] - 1 - k, r[mini(5, 2 + k)] if k < tall - 1 else r[3])
			c.lit(tip + 1, top[tip], r[4])
		"steam":
			for x0 in range(from + 1, tip, 4):
				if top[x0] < 0:
					continue
				for y in range(top[x0], bot[x0] + 1):
					c.lit(x0, y, Pal.FROST[4])
				c.put(x0 + 1, top[x0] - 2, Pal.BONE[4])
				c.put(x0, top[x0] - 3, Pal.BONE[3])
				c.put(x0 + 1, top[x0] - 4, Pal.BONE[2])
		"shade":
			for x0 in range(from, tip + 1, 2):
				if bot[x0] < 0:
					continue
				var drop := 2 + ((x0 * 5) % 4)
				for k in drop:
					if (x0 + k) % 2 == 0 or k < 2:
						c.put(x0, bot[x0] + 1 + k, Pal.GLOAM[mini(3, 3 - k / 2)])
			c.lit(tip, top[tip], Pal.GLOAM[5])
		"echo":
			# a second edge a little above the first, drawn in light
			for x0 in range(from, tip + 1):
				if top[x0] >= 0:
					var ty: int = top[x0] - 3
					c.lit(x0, ty, Pal.GOLD[4] if x0 % 2 == 0 else Pal.GOLD[3])
					if x0 % 4 == 0:
						c.put(x0, ty + 1, Pal.GOLD[1])
		"chain":
			var i := 0
			for x0 in range(from, tip + 1, 3):
				if top[x0] < 0:
					continue
				var y0: int = top[x0] - 1 if i % 2 == 0 else bot[x0] + 1
				c.put(x0, y0, Pal.STEEL[5])
				c.put(x0 + 1, y0, Pal.STEEL[3])
				i += 1
			var y1 := int(bot[tip]) + 1
			for k in 5:
				c.put(tip + 1 - k, y1 + (k % 2) + 1, Pal.STEEL[4 - (k % 2)])
		"knives":
			for k in 3:
				var x0: int = from + 3 + k * 5
				if x0 >= c.w - 3 or top[x0] < 0:
					continue
				var y0: int = top[x0] - 3 - (k % 2)
				for s in 3:
					c.lit(x0 + s, y0, Pal.GLOAM[5 - s])
				c.put(x0 - 1, y0, Pal.INK)
		"seek":
			var yt: int = top[tip]
			c.put(tip + 1, yt, Pal.MOSS[5])
			c.put(tip + 2, yt + 1, Pal.MOSS[5])
			c.put(tip + 2, yt + 2, Pal.MOSS[4])
			c.put(tip + 1, yt + 3, Pal.MOSS[3])
			for k in 3:
				var x0: int = from + k * 2
				if top[x0] >= 0:
					c.put(x0, top[x0] - 1, Pal.MOSS[5])
					c.put(x0 - 1, top[x0] - 2, Pal.MOSS[4])
					c.put(x0 - 2, top[x0] - 3, Pal.MOSS[3])
	var s := Sheet.new(c.w, c.h, Vector2i(int(meta.origin[0]), int(meta.origin[1]) + PAD))
	s.add("idle", [c], 1.0)
	s.save(dir, "%s_%s" % [weapon, path])
