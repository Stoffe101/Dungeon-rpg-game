## The satchel screen's leather: the bag's body, its flap (outside and the
## underside seen when it is thrown back), stitched pockets, the plum lining
## of the bag's inside, a brass buckle and the hearth emblem pressed into the flap.
## Nine-slice textures are tileable along their edges.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")

const LEATHER := [Color8(38, 20, 18), Color8(64, 36, 26), Color8(94, 56, 36), Color8(128, 82, 50), Color8(162, 112, 68), Color8(196, 146, 92)]
const LINING := [Color8(30, 12, 22), Color8(48, 20, 32), Color8(66, 28, 42), Color8(86, 38, 54)]
const THREAD := Color8(214, 190, 150)


static func build(dir: String) -> void:
	_leather(dir.path_join("ui_satchel.png"), 40, 2, 3, 6, true)
	_leather(dir.path_join("ui_pocket.png"), 24, 1, 2, 3, false)
	_leather(dir.path_join("satchel_flap.png"), 48, 3, 4, 6, true, 8)
	_leather(dir.path_join("satchel_flap_inside.png"), 32, 1, 2, 4, false, 6)
	_lining(dir.path_join("ui_lining.png"))
	_buckle(dir.path_join("satchel_buckle.png"))
	_strap(dir.path_join("satchel_strap.png"))
	_emblem(dir.path_join("satchel_emblem.png"))


## Grained leather with a rolled, lit edge and a running stitch `inset` px in.
## `round_r` rounds the corners (the flap's are soft).
static func _leather(path: String, size: int, base: int, edge: int, inset: int, rivets: bool, round_r := 3) -> void:
	var c := Px.new(size, size)
	var last := size - 1
	for y in size:
		for x in size:
			var i := base
			var g := Px.hash01(x / 2, y, 11) + Px.hash01(x, y / 3, 12) * 0.5
			if g > 1.25:
				i = base + 1
			elif g < 0.2:
				i = base - 1
			var col: Color = Pal.ramp(LEATHER, i)
			# fine pores
			if Px.hash01(x, y, 13) > 0.93:
				col = col.darkened(0.12)
			c.put(x, y, col)
	# rolled edge: dark rim, a lit lip toward the top-left, shade toward the bottom-right
	for i in size:
		c.put(i, 0, Pal.INK)
		c.put(i, last, Pal.INK)
		c.put(0, i, Pal.INK)
		c.put(last, i, Pal.INK)
		c.put(i, 1, Pal.ramp(LEATHER, edge + 1))
		c.put(1, i, Pal.ramp(LEATHER, edge + 1))
		c.put(i, 2, Pal.ramp(LEATHER, edge))
		c.put(2, i, Pal.ramp(LEATHER, edge))
		c.put(i, last - 1, Pal.ramp(LEATHER, base - 1))
		c.put(last - 1, i, Pal.ramp(LEATHER, base - 1))
		c.put(i, last - 2, Pal.ramp(LEATHER, base))
		c.put(last - 2, i, Pal.ramp(LEATHER, base))
		if i > 2 and i < last - 2:
			c.put(i, 3, Pal.ramp(LEATHER, base - 1))
			c.put(3, i, Pal.ramp(LEATHER, base - 1))
	# running stitch (period 4 so it tiles along a nine-slice edge)
	for i in range(inset, size - inset):
		var on := i % 4 < 2
		for p in [Vector2i(i, inset), Vector2i(i, last - inset), Vector2i(inset, i), Vector2i(last - inset, i)]:
			if on:
				c.put(p.x, p.y, THREAD)
			else:
				c.put(p.x, p.y, Pal.ramp(LEATHER, base - 1))
	# rounded corners
	for y in round_r:
		for x in round_r:
			var dx := round_r - x - 0.5
			var dy := round_r - y - 0.5
			if dx * dx + dy * dy > float(round_r * round_r):
				for p in [Vector2i(x, y), Vector2i(last - x, y), Vector2i(x, last - y), Vector2i(last - x, last - y)]:
					c.put(p.x, p.y, Color(0, 0, 0, 0))
	if rivets:
		var r := inset - 2
		for p in [Vector2i(r, r), Vector2i(last - r, r), Vector2i(r, last - r), Vector2i(last - r, last - r)]:
			c.put(p.x, p.y, Pal.GOLD[3])
			c.put(p.x - 1, p.y, Pal.GOLD[2])
			c.put(p.x, p.y - 1, Pal.GOLD[4])
			c.put(p.x + 1, p.y, Pal.GOLD[1])
			c.put(p.x, p.y + 1, Pal.GOLD[1])
	c.save(path)


## The inside of the bag: a plum twill with a soft shadow under the rim.
static func _lining(path: String) -> void:
	var size := 16
	var c := Px.new(size, size)
	var last := size - 1
	for y in size:
		for x in size:
			var i := 1 + (1 if (x + y * 2) % 4 == 0 else 0)
			c.put(x, y, LINING[i])
	for i in size:
		c.put(i, 0, Pal.INK)
		c.put(0, i, Pal.INK)
		c.put(i, last, LINING[3])
		c.put(last, i, LINING[3])
		c.put(i, 1, LINING[0])
		c.put(1, i, LINING[0])
		c.put(i, 2, LINING[0] if i % 2 == 0 else LINING[1])
	c.save(path)


## A strap running down the flap (tiles vertically).
static func _strap(path: String) -> void:
	var c := Px.new(12, 8)
	for y in 8:
		for x in 12:
			var i := 1
			if x == 1 or x == 2:
				i = 2
			elif x >= 9:
				i = 0
			c.put(x, y, Pal.ramp(LEATHER, i))
		c.put(0, y, Pal.INK)
		c.put(11, y, Pal.INK)
		c.put(3, y, THREAD if y % 4 < 2 else Pal.ramp(LEATHER, 0))
		c.put(8, y, THREAD if y % 4 < 2 else Pal.ramp(LEATHER, 0))
	c.save(path)


## A brass buckle on a short strap: the clasp the flap fastens with.
static func _buckle(path: String) -> void:
	var c := Px.new(22, 26)
	# strap
	c.paint(c.mask().rect(7, 0, 8, 26), LEATHER, 2, true)
	for y in range(1, 25, 4):
		c.put(8, y, THREAD)
		c.put(13, y, THREAD)
	# frame
	var outer := c.mask().rect(2, 9, 18, 13)
	outer.subtract(c.mask().rect(5, 12, 12, 7))
	c.paint(outer, Pal.GOLD, 3, true)
	# strap under the frame, prong across
	c.paint(c.mask().rect(5, 12, 12, 7), LEATHER, 1)
	c.line(4, 15, 15, 15, Pal.GOLD[4])
	c.put(16, 15, Pal.GOLD[2])
	c.lit(3, 10, Pal.GOLD[4])
	c.outline(Pal.INK)
	c.save(path)


## The hearth flame pressed into the flap, edged in gold leaf.
static func _emblem(path: String) -> void:
	var c := Px.new(18, 20)
	var flame := c.mask().poly(PackedVector2Array([Vector2(9, 1), Vector2(13, 7), Vector2(15, 12), Vector2(13, 17), Vector2(9, 19), Vector2(5, 17), Vector2(3, 12), Vector2(5, 7)]))
	c.paint(flame, LEATHER, 1, true)
	var inner := c.mask().poly(PackedVector2Array([Vector2(9, 7), Vector2(12, 12), Vector2(11, 16), Vector2(9, 17), Vector2(7, 16), Vector2(6, 12)]))
	c.fill(inner, Pal.GOLD[2])
	c.put(9, 10, Pal.GOLD[4])
	c.put(8, 12, Pal.GOLD[3])
	for y in 20:
		for x in 18:
			if flame.has(x, y) and not flame.has(x, y - 1):
				c.put(x, y, Pal.GOLD[3])
	c.save(path)
