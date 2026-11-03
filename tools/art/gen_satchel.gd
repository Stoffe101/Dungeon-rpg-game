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
	_closed_body(dir.path_join("satchel_closed.png"))
	_closed_flap(dir.path_join("satchel_closed_flap.png"))
	_buckle_big(dir.path_join("satchel_buckle_big.png"))
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


# --- the closed satchel (shown while it opens and closes) -------------------------
## A messenger satchel seen from the front: a shoulder strap arching over it on
## brass rings, a gusseted body with a front pocket, and (in its own image so it
## can swing up) the flap with its rounded tongue, the pressed hearth emblem and
## two straps that run down into buckles.

const CB_W := 260
const CB_H := 184


static func _grain(x: int, y: int, base: int) -> Color:
	var i := base
	var g := Px.hash01(x / 2, y, 21) + Px.hash01(x, y / 3, 22) * 0.5
	if g > 1.28:
		i = base + 1
	elif g < 0.18:
		i = base - 1
	var col: Color = Pal.ramp(LEATHER, i)
	if Px.hash01(x, y, 23) > 0.94:
		col = col.darkened(0.12)
	return col


## True when (x, y) is inside a rectangle with separately rounded top and bottom corners.
static func _in_round_rect(x: int, y: int, r: Rect2i, rt: int, rb: int) -> bool:
	if not r.has_point(Vector2i(x, y)):
		return false
	var rad := 0
	var cy := 0.0
	if y < r.position.y + rt:
		rad = rt
		cy = r.position.y + rt - 0.5
	elif y >= r.end.y - rb:
		rad = rb
		cy = r.end.y - rb - 0.5
	else:
		return true
	var cx := 0.0
	if x < r.position.x + rad:
		cx = r.position.x + rad - 0.5
	elif x >= r.end.x - rad:
		cx = r.end.x - rad - 0.5
	else:
		return true
	return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= float(rad * rad)


static func _closed_body(path: String) -> void:
	var c := Px.new(CB_W, CB_H)
	# the shoulder strap, arching over the bag between two brass rings
	var cx := CB_W / 2.0
	for y in 56:
		for x in CB_W:
			var dx := (x - cx) / 112.0
			var dy := (y - 58.0) / 54.0
			var dxi := (x - cx) / 99.0
			var dyi := (y - 58.0) / 41.0
			var o := dx * dx + dy * dy
			var n := dxi * dxi + dyi * dyi
			if o <= 1.0 and n > 1.0:
				var col := _grain(x, y, 2)
				if o > 0.93 or n < 1.07:
					col = Pal.ramp(LEATHER, 1)
				# running stitches along both edges
				var s1 := absf(sqrt(o) - 0.975)
				var s2 := absf(sqrt(n) - 1.035)
				if (s1 < 0.006 or s2 < 0.008) and (x + y) % 4 < 2:
					col = THREAD
				c.put(x, y, col)
	var body := Rect2i(18, 52, CB_W - 36, CB_H - 56)
	var rim := Rect2i(body.position + Vector2i(2, 2), body.size - Vector2i(4, 4))
	for y in CB_H:
		for x in CB_W:
			if not _in_round_rect(x, y, body, 6, 18):
				continue
			var col := _grain(x, y, 2)
			# side gussets, folded in
			if x < body.position.x + 10 or x >= body.end.x - 10:
				col = _grain(x, y, 1)
				if x == body.position.x + 9 or x == body.end.x - 10:
					col = Pal.ramp(LEATHER, 0)
			# the bag's mouth, dark lining, seen only when the flap is up
			if y < body.position.y + 10 and x > body.position.x + 10 and x < body.end.x - 11:
				col = LINING[1] if y > body.position.y + 2 else Pal.ramp(LEATHER, 3)
			# bottom seam
			if y >= body.end.y - 7:
				col = _grain(x, y, 1)
				if y == body.end.y - 5 and x % 4 < 2:
					col = THREAD
			# rolled edge
			if not _in_round_rect(x, y, rim, 5, 16):
				col = Pal.ramp(LEATHER, 3) if (x < body.position.x + 2 or y < body.position.y + 2) else Pal.ramp(LEATHER, 0)
			c.put(x, y, col)
	# front pocket between the straps, with its own little flap and stud
	var pocket := Rect2i(100, 148, 60, 28)
	for y in range(pocket.position.y, pocket.end.y):
		for x in range(pocket.position.x, pocket.end.x):
			if _in_round_rect(x, y, pocket, 3, 7):
				var edge := y == pocket.end.y - 1 or x == pocket.position.x or x == pocket.end.x - 1
				c.put(x, y, Pal.ramp(LEATHER, 0) if edge else _grain(x, y, 3))
	var pflap := Rect2i(100, 148, 60, 11)
	for y in range(pflap.position.y, pflap.end.y):
		for x in range(pflap.position.x, pflap.end.x):
			if _in_round_rect(x, y, pflap, 3, 6):
				c.put(x, y, _grain(x, y, 4) if y < pflap.end.y - 1 else Pal.ramp(LEATHER, 0))
	for x in range(pflap.position.x + 4, pflap.end.x - 4):
		if x % 4 < 2:
			c.put(x, pflap.position.y + 3, THREAD)
	c.put(129, 156, Pal.GOLD[3])
	c.put(130, 156, Pal.GOLD[4])
	c.put(129, 157, Pal.GOLD[2])
	c.put(130, 157, Pal.GOLD[2])
	# brass rings where the strap meets the bag
	for rx in [22, CB_W - 23]:
		var ring := c.mask().ellipse(rx, 53.0, 4.5, 4.5)
		ring.subtract(c.mask().ellipse(rx, 53.0, 2.5, 2.5))
		c.paint(ring, Pal.GOLD, 3)
		c.lit(rx - 2, 50, Pal.GOLD[4])
	c.outline(Pal.INK)
	c.save(path)


static func _closed_flap(path: String) -> void:
	var w := CB_W - 28
	var h := 102
	var c := Px.new(w, h + 18)
	var shape := Rect2i(0, 0, w, h)
	var rim := Rect2i(2, 2, w - 4, h - 4)
	var stitch_o := Rect2i(6, 6, w - 12, h - 12)
	var stitch_i := Rect2i(7, 7, w - 14, h - 14)
	for y in h:
		for x in w:
			if not _in_round_rect(x, y, shape, 5, 38):
				continue
			var col := _grain(x, y, 3)
			if not _in_round_rect(x, y, rim, 4, 36):
				col = Pal.ramp(LEATHER, 4) if (y < 3 or x < 2) else Pal.ramp(LEATHER, 1)
			elif _in_round_rect(x, y, stitch_o, 3, 32) and not _in_round_rect(x, y, stitch_i, 2, 31) and (x + y) % 4 < 2:
				col = THREAD
			c.put(x, y, col)
	# the hearth emblem, pressed in and gilded
	var ex := w / 2.0
	var ey := 46.0
	var flame := c.mask().poly(PackedVector2Array([Vector2(ex, ey - 22), Vector2(ex + 9, ey - 8), Vector2(ex + 13, ey + 4), Vector2(ex + 9, ey + 16), Vector2(ex, ey + 21), Vector2(ex - 9, ey + 16), Vector2(ex - 13, ey + 4), Vector2(ex - 9, ey - 8)]))
	c.paint(flame, LEATHER, 2, true)
	var core := c.mask().poly(PackedVector2Array([Vector2(ex, ey - 6), Vector2(ex + 6, ey + 6), Vector2(ex + 4, ey + 14), Vector2(ex, ey + 16), Vector2(ex - 4, ey + 14), Vector2(ex - 6, ey + 6)]))
	c.fill(core, Pal.GOLD[2])
	for y in h:
		for x in w:
			if flame.has(x, y) and not flame.has(x, y - 1):
				c.put(x, y, Pal.GOLD[3])
	c.put(int(ex), int(ey) + 2, Pal.GOLD[4])
	c.put(int(ex) - 1, int(ey) + 6, Pal.GOLD[4])
	# two straps running down off the flap; their tongues reach the buckles
	for sx in [56, w - 72]:
		var top := h + 16
		for y in top:
			for x in range(sx, sx + 16):
				if y >= top - 6 and absf(x - (sx + 7.5)) > (top - y) * 1.3:
					continue
				var col: Color = Pal.ramp(LEATHER, 1 if (x == sx or x == sx + 15) else 2)
				if (x == sx + 2 or x == sx + 13) and y % 4 < 2:
					col = THREAD
				c.put(x, y, col)
		for hy in [h - 2, h + 4]:
			c.put(sx + 7, hy, Pal.INK)
			c.put(sx + 8, hy, Pal.INK)
	c.outline(Pal.INK)
	c.save(path)


## A brass buckle frame with its prong; the strap shows through the middle.
static func _buckle_big(path: String) -> void:
	var c := Px.new(24, 16)
	var frame := c.mask().rect(0, 0, 24, 16)
	frame.subtract(c.mask().rect(3, 3, 18, 10))
	c.paint(frame, Pal.GOLD, 3, true)
	c.line(3, 8, 18, 8, Pal.GOLD[4])
	c.put(19, 8, Pal.GOLD[2])
	c.lit(1, 1, Pal.GOLD[4])
	c.outline(Pal.INK)
	c.save(path)
