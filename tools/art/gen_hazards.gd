## Spike traps you can recognise before they move. Two layers: a plate let into the floor
## (a frame, rivets, slots, warning notches), and the teeth that stand up out of it, drawn
## upright so they are as tall as they are dangerous. One family per region, same timing
## and same shapes: bone-and-iron in the Ossuary, thorn through root-wood in the Rootmire,
## ember iron in the Throne, something not quite straight in the Hollow.
##   spike_plate_<r>: armed, warn0, warn1, spent   (flat, 16x16)
##   spike_teeth_<r>: 0 peek, 1 quarter, 2 half, 3 full, 4 full glint  (upright, 16x24)
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Sheet = preload("res://tools/art/sheet.gd")
const Pal = preload("res://src/render/pal.gd")

const SLOTS := [Vector2i(3, 4), Vector2i(8, 3), Vector2i(12, 4), Vector2i(3, 8), Vector2i(8, 8), Vector2i(12, 8), Vector2i(3, 12), Vector2i(8, 12), Vector2i(12, 12)]

const STYLES := {
	"ossuary": {"frame": Pal.STONE, "base": 2, "metal": Pal.STEEL, "tip": Pal.BONE, "notch": Pal.BONE[3]},
	"rootmire": {"frame": Pal.WOOD, "base": 2, "metal": Pal.BONE, "tip": Pal.BONE, "notch": Pal.MOSS[4]},
	"throne": {"frame": Pal.OBSIDIAN, "base": 3, "metal": Pal.STEEL, "tip": Pal.EMBER, "notch": Pal.GOLD[3]},
	"hollow": {"frame": Pal.GLOAM, "base": 1, "metal": Pal.SOUL, "tip": Pal.SOUL, "notch": Pal.SOUL[4]},
}


static func build(dir: String) -> void:
	for style in STYLES:
		_plate(dir, style)
		_teeth(dir, style)


static func _plate(dir: String, style: String) -> void:
	var st: Dictionary = STYLES[style]
	var s := Sheet.new(16, 16, Vector2i(8, 8))
	s.add("armed", [_plate_frame(st, 0, style)], 1.0)
	s.add("warn", [_plate_frame(st, 1, style), _plate_frame(st, 2, style)], 8.0)
	s.save(dir, "spike_plate_" + style)


## state 0: armed (the tips just visible in their slots); 1/2: the warning: the plate has
## dropped a pixel and the notches around it stand out and alternate, so it is told by
## shape and motion, never by colour alone.
static func _plate_frame(st: Dictionary, state: int, style: String) -> Px:
	var c := Px.new(16, 16)
	var fr: Array = st.frame
	var b: int = st.base
	# a raised frame around a sunk bed
	c.rect(0, 0, 16, 16, fr[b])
	c.rect(0, 0, 16, 1, fr[mini(b + 1, fr.size() - 1)])
	c.rect(0, 0, 1, 16, fr[mini(b + 1, fr.size() - 1)])
	c.rect(0, 15, 16, 1, fr[maxi(b - 1, 0)])
	c.rect(15, 0, 1, 16, fr[maxi(b - 1, 0)])
	var drop := 1 if state > 0 else 0
	c.rect(2, 2, 12, 12, Pal.INK)
	c.rect(2, 2 + drop, 12, 12 - drop, fr[maxi(b - 1, 0)])
	# corner rivets
	for p in [Vector2i(1, 1), Vector2i(14, 1), Vector2i(1, 14), Vector2i(14, 14)]:
		c.put(p.x, p.y, st.metal[mini(4, st.metal.size() - 1)])
	if style == "rootmire":
		# roots gripping the frame
		c.line(0, 5, 3, 3, Pal.WOOD[1])
		c.line(15, 11, 12, 13, Pal.WOOD[1])
	elif style == "hollow":
		# a frame that does not quite close
		c.put(0, 7, Color(0, 0, 0, 0))
		c.put(0, 8, Color(0, 0, 0, 0))
		c.put(15, 4, Color(0, 0, 0, 0))
	# the slots, and the steel waiting in each one
	for p in SLOTS:
		c.rect(p.x, p.y + drop, 2, 2, Pal.INK)
		var tip: Array = st.tip
		c.put(p.x, p.y + drop, tip[mini(2, tip.size() - 1)])
	# warning notches along the frame (chevrons, teeth of the frame itself)
	var n: Color = st.notch
	for k in range(0, 4):
		var x: int = 2 + k * 4
		if state == 0:
			if k % 2 == 0:
				c.put(x, 0, n)
				c.put(x, 15, n)
		else:
			var on: bool = (k + state) % 2 == 0
			c.rect(x, 0, 2, 2 if on else 1, n if on else Pal.INK)
			c.rect(x, 14 if on else 15, 2, 2 if on else 1, n if on else Pal.INK)
			c.rect(0, x, 2 if on else 1, 2, n if on else Pal.INK)
			c.rect(14 if on else 15, x, 2 if on else 1, 2, n if on else Pal.INK)
	return c


static func _teeth(dir: String, style: String) -> void:
	var st: Dictionary = STYLES[style]
	var s := Sheet.new(16, 26, Vector2i(8, 18))
	var fr: Array = []
	for h in [0.16, 0.36, 0.66, 1.0]:
		fr.append(_teeth_frame(st, h, false, style))
	fr.append(_teeth_frame(st, 1.0, true, style))
	s.add("idle", fr, 1.0)
	s.save(dir, "spike_teeth_" + style)


## Each tooth stands in a slot of the plate, back row first: a tapering blade, lit down its
## left side, dark on its right, coming to one bright point. `k` is how far out they are.
## (Thin bright blades with air between them: the first version outlined every tooth in
## black, and three rows of them read as a picket fence.)
static func _teeth_frame(st: Dictionary, k: float, glint: bool, style: String) -> Px:
	var c := Px.new(16, 26)
	var m: Array = st.metal
	var tip: Array = st.tip
	var hi: Color = m[mini(4, m.size() - 1)]
	var mid_c: Color = m[mini(3, m.size() - 1)]
	var dark: Color = m[1]
	for row in [[14, 13], [18, 15], [22, 13]]:
		var base_y: int = row[0]
		var tall: int = row[1]
		for x0: int in [3, 8, 12]:
			var h := maxi(1, int(round(tall * k)))
			var bend := 0.0
			if style == "hollow":
				bend = 1.0 if (x0 + base_y) % 4 == 0 else -1.0
			for y in h:
				var t := float(y) / maxf(float(h - 1), 1.0)
				var cx: int = x0 + int(round(bend * t * t * 2.0))
				var y1 := base_y - y
				if t < 0.45:
					c.put(cx - 1, y1, hi)
					c.put(cx, y1, mid_c)
					c.put(cx + 1, y1, dark)
				else:
					c.put(cx, y1, hi if t < 0.85 else tip[mini(3, tip.size() - 1)])
					if t < 0.75:
						c.put(cx + 1, y1, dark)
			if k >= 0.6:
				var top_x: int = x0 + int(round(bend * 2.0))
				var top_y := base_y - h + 1
				if glint:
					c.lit(top_x, top_y, tip[tip.size() - 1])
				else:
					c.put(top_x, top_y, tip[tip.size() - 1])
			# where it comes out of its slot
			c.put(x0 - 1, base_y + 1, Pal.INK)
			c.put(x0, base_y + 1, Pal.INK)
			c.put(x0 + 1, base_y + 1, Pal.INK)
	return c
