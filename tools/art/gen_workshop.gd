## The smith's workshop in the sanctuary: a stone furnace with a hood and
## chimney (a bellows and a banner once the workshop is a master's), an anvil
## on a stump with a glowing work-piece, a quench barrel, a tool rack and a
## grindstone. Job "workshop" in build_art.gd (run after "hub": it replaces
## the old "forge" sheet).
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func build(dir: String) -> void:
	_furnace(dir)
	_anvil(dir)
	_quench(dir)
	_tool_rack(dir)
	_grindstone(dir)


## 44x46: brick furnace, arched mouth of fire, an iron hood and a chimney.
## "idle" 4 frames of flicker; "l3" the same with bellows and a banner.
static func _furnace(dir: String) -> void:
	var s := Sheet.new(44, 46, Vector2i(22, 44))
	for variant in ["idle", "l3"]:
		var fr: Array = []
		for i in 4:
			fr.append(_furnace_frame(i, variant == "l3"))
		s.add(variant, fr, 6.0)
	s.save(dir, "forge")


static func _furnace_frame(i: int, master: bool) -> Px:
	var c := Px.new(44, 46)
	# chimney rising out of the hood
	c.paint(c.mask().rect(18, 0, 9, 14), Pal.STONE, 2, true)
	for y in range(1, 14, 3):
		c.line(18, y, 26, y, Pal.STONE[1])
	c.paint(c.mask().rect(17, 0, 11, 2), Pal.STONE, 3)
	# the hood: an iron cowl over the fire
	c.paint(c.mask().poly(V([[8, 22], [14, 12], [31, 12], [37, 22]])), Pal.STEEL, 2, true)
	c.line(14, 13, 30, 13, Pal.STEEL[3])
	for x in [16, 22, 28]:
		c.put(x, 15, Pal.STEEL[4])
	# brick body
	var body := c.mask().rect(6, 22, 33, 22)
	c.paint(body, Pal.EARTH, 2, true)
	for row in 7:
		var y := 23 + row * 3
		var off := 0 if row % 2 == 0 else 3
		for x in range(6 + off, 39, 6):
			c.put(x, y + 1, Pal.EARTH[1])
			c.put(x, y + 2, Pal.EARTH[1])
		c.line(6, y, 38, y, Pal.EARTH[1])
	# the mouth: an arch full of fire, coals glowing in its throat
	var mouth := c.mask().ellipse(22.5, 31.0, 8.0, 6.0).rect(15, 31, 16, 8)
	c.fill(mouth, Pal.INK)
	c.fill_lit(c.mask().ellipse(22.5, 35.0, 7.0, 4.0 + (i % 2)), Pal.EMBER[2])
	c.fill_lit(c.mask().ellipse(22.5, 36.0, 5.0, 2.5), Pal.EMBER[3 + (i % 2)])
	for k in 5:
		var fx := 17 + ((k * 3 + i * 2) % 11)
		c.lit(fx, 34 - (k + i) % 3, Pal.EMBER[4 + (k + i) % 2])
	c.lit(22, 33 - i % 2, Pal.EMBER[5])
	# coal bed lip and an ash tray
	c.paint(c.mask().rect(14, 39, 18, 2), Pal.STONE, 3)
	for k in 6:
		c.lit(16 + k * 3, 38, Pal.EMBER[3] if (k + i) % 3 == 0 else Pal.EMBER[2])
	c.paint(c.mask().rect(8, 42, 29, 2), Pal.STONE, 1)
	# glow on the hood's underside
	c.lit(15, 21, Pal.EMBER[2])
	c.lit(30, 21, Pal.EMBER[2])
	if master:
		# leather bellows on the left, a hearth-banner on the right
		c.paint(c.mask().poly(V([[0, 31], [6, 28], [6, 38], [0, 35]])), Pal.WOOD, 2, true)
		var puff := 1 if i % 2 == 0 else 0
		c.paint(c.mask().poly(V([[1, 31 + puff], [6, 29], [6, 37], [1, 35 - puff]])), Pal.EARTH, 3)
		c.line(0, 33, -1 + 2, 33, Pal.WOOD[3])
		c.paint(c.mask().rect(38, 14, 2, 30), Pal.WOOD, 2)
		c.paint(c.mask().poly(V([[40, 15], [44, 15], [44, 27], [42, 25], [40, 27]])), Pal.BLOOD, 2)
		c.lit(42, 19, Pal.EMBER[4])
	c.outline(Pal.INK)
	return c


## 22x18: an anvil on a stump; the work-piece on it glows. "idle" 2 frames,
## "struck" 2 frames (a flash as the hammer lands).
static func _anvil(dir: String) -> void:
	var s := Sheet.new(22, 18, Vector2i(11, 17))
	var idle: Array = []
	for i in 2:
		idle.append(_anvil_frame(i, false))
	s.add("idle", idle, 3.0)
	s.add("struck", [_anvil_frame(0, true), _anvil_frame(1, false)], 10.0)
	s.save(dir, "anvil")


static func _anvil_frame(i: int, hot: bool) -> Px:
	var c := Px.new(22, 18)
	# stump
	c.paint(c.mask().ellipse(11.0, 15.0, 6.0, 2.4).rect(5, 10, 12, 5), Pal.WOOD, 2, true)
	c.line(6, 11, 6, 14, Pal.WOOD[1])
	c.line(15, 11, 15, 14, Pal.WOOD[3])
	c.paint(c.mask().ellipse(11.0, 10.0, 6.0, 1.6), Pal.WOOD, 3)
	# anvil: horn to the left, heel to the right
	c.paint(c.mask().poly(V([[1, 5], [6, 3], [19, 3], [20, 6], [15, 7], [7, 7]])), Pal.STEEL, 2, true)
	c.line(6, 3, 19, 3, Pal.STEEL[4])
	c.paint(c.mask().rect(8, 7, 7, 3), Pal.STEEL, 1)
	# the work-piece: a bar of glowing iron
	var bar := c.mask().rect(8, 1, 7, 2)
	c.fill_lit(bar, Pal.EMBER[4] if hot else Pal.EMBER[3 - i % 2 + 1])
	c.lit(11, 1, Pal.WHITE if hot else Pal.EMBER[5])
	if hot:
		for k in 4:
			c.lit(6 + k * 3, 0, Pal.EMBER[5])
	# tongs leaning on the stump
	c.line(17, 8, 21, 16, Pal.STEEL[3])
	c.line(18, 8, 21, 14, Pal.STEEL[2])
	c.outline(Pal.INK)
	return c


## 16x20: an iron-bound barrel of water; "idle" ripples, "steam" a hiss.
static func _quench(dir: String) -> void:
	var s := Sheet.new(16, 22, Vector2i(8, 21))
	var idle: Array = []
	for i in 2:
		idle.append(_quench_frame(i, 0))
	s.add("idle", idle, 2.0)
	var steam: Array = []
	for i in 4:
		steam.append(_quench_frame(i, i + 1))
	s.add("steam", steam, 8.0)
	s.save(dir, "quench")


static func _quench_frame(i: int, puff: int) -> Px:
	var c := Px.new(16, 22)
	var barrel := c.mask().ellipse(8.0, 19.0, 6.5, 2.4).rect(2, 9, 13, 10)
	c.paint(barrel, Pal.WOOD, 2, true)
	for x in [4, 8, 12]:
		c.line(x, 10, x, 18, Pal.WOOD[1])
	for y in [11, 16]:
		c.line(2, y, 14, y, Pal.STEEL[2])
	c.paint(c.mask().ellipse(8.0, 9.0, 6.5, 2.2), Pal.WOOD, 3)
	c.fill(c.mask().ellipse(8.0, 9.0, 5.2, 1.5), Pal.FROST[1])
	c.put(5 + i * 3, 9, Pal.FROST[3])
	c.put(9 - i, 8, Pal.FROST[2])
	if puff > 0:
		# steam: soft grey-white puffs climbing out
		for k in puff + 1:
			var y := 7 - k * 2
			var x := 6 + (k * 3 + puff) % 5
			c.ellipse(float(x), float(y), 1.8 + k * 0.3, 1.2, Pal.STONE[5] if k < 2 else Pal.STONE[4])
	c.outline(Pal.INK)
	return c


## 22x26: a wooden rack hung with the smith's tools.
static func _tool_rack(dir: String) -> void:
	var c := Px.new(22, 26)
	c.paint(c.mask().rect(2, 2, 2, 24), Pal.WOOD, 2)
	c.paint(c.mask().rect(18, 2, 2, 24), Pal.WOOD, 2)
	c.paint(c.mask().rect(1, 3, 20, 2), Pal.WOOD, 3)
	c.paint(c.mask().rect(2, 20, 18, 2), Pal.WOOD, 2)
	# tongs, two hammers, a file, a chisel
	c.line(6, 5, 5, 15, Pal.STEEL[3])
	c.line(7, 5, 8, 15, Pal.STEEL[2])
	c.paint(c.mask().rect(10, 5, 1, 9), Pal.WOOD, 3)
	c.paint(c.mask().rect(9, 13, 3, 3), Pal.STEEL, 3)
	c.paint(c.mask().rect(14, 5, 1, 7), Pal.WOOD, 3)
	c.paint(c.mask().rect(13, 11, 3, 2), Pal.STEEL, 2)
	c.line(17, 5, 17, 13, Pal.STEEL[4])
	# a bucket of nails on the shelf
	c.paint(c.mask().rect(5, 17, 5, 3), Pal.STEEL, 2)
	c.paint(c.mask().rect(12, 17, 4, 3), Pal.EARTH, 3)
	c.put(13, 16, Pal.STEEL[4])
	c.outline(Pal.INK)
	var s := Sheet.new(22, 26, Vector2i(11, 25))
	s.add("idle", [c], 1.0)
	s.save(dir, "tool_rack")


## 22x20: a grindstone on a trestle; "spin" turns the wheel, sparks off it.
static func _grindstone(dir: String) -> void:
	var s := Sheet.new(22, 20, Vector2i(11, 19))
	var fr: Array = []
	for i in 4:
		var c := Px.new(22, 20)
		# trestle legs
		c.line(4, 19, 7, 10, Pal.WOOD[2])
		c.line(17, 19, 14, 10, Pal.WOOD[2])
		c.paint(c.mask().rect(5, 9, 12, 2), Pal.WOOD, 3)
		# the wheel, with a notch that turns
		c.paint(c.mask().ellipse(11.0, 7.0, 6.0, 6.0), Pal.STONE, 3, true)
		c.paint(c.mask().ellipse(11.0, 7.0, 1.5, 1.5), Pal.STEEL, 3)
		var a := i * PI / 2.0
		c.line(11, 7, int(11 + cos(a) * 5.0), int(7 + sin(a) * 5.0), Pal.STONE[1])
		# a treadle and a few sparks off the edge
		c.line(3, 18, 9, 16, Pal.WOOD[3])
		c.lit(17 + i % 2, 9 - i % 3, Pal.EMBER[4])
		c.lit(19, 11 - i % 2, Pal.EMBER[3])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("spin", fr, 8.0)
	s.save(dir, "grindstone")
