## Sanctuary structures and residents: the Hearth, the Descent, forge, smith,
## apothecary, memorial, the Keeper, lantern posts, and the dungeon merchant.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func single(dir: String, name: String, c: Px, origin: Vector2i) -> void:
	var s := Sheet.new(c.w, c.h, origin)
	s.add("idle", [c], 1.0)
	s.save(dir, name)


static func build(dir: String) -> void:
	_hearth(dir)
	_descent(dir)
	_forge(dir)
	_smith(dir)
	_rack(dir)
	_apothecary(dir)
	_memorial(dir)
	_keeper(dir)
	_lantern_post(dir)
	_merchant(dir)


static func _flame(c: Px, cx: float, base_y: float, w: float, h: float, ph: int, r: Array) -> void:
	var outer := c.mask().ellipse(cx, base_y - h * 0.45, w, h * 0.55)
	outer.poly(V([[cx - w * 0.6, base_y - h * 0.5], [cx + (ph % 3 - 1) * 1.5, base_y - h * 1.15], [cx + w * 0.6, base_y - h * 0.5]]))
	c.fill_lit(outer, r[2])
	var mid := c.mask().ellipse(cx, base_y - h * 0.38, w * 0.62, h * 0.42)
	c.fill_lit(mid, r[3])
	var core := c.mask().ellipse(cx, base_y - h * 0.3, w * 0.32, h * 0.25)
	c.fill_lit(core, r[5])


static func _hearth(dir: String) -> void:
	var s := Sheet.new(48, 44, Vector2i(24, 38))
	var fr: Array = []
	for i in 6:
		var c := Px.new(48, 44)
		# stone ring
		var ring := c.mask().ellipse(24.0, 36.0, 21.0, 7.0)
		c.paint(ring, Pal.STONE, 3, true)
		var pit := c.mask().ellipse(24.0, 35.0, 16.0, 4.6)
		c.fill(pit, Pal.INK)
		# coals
		for k in 18:
			var x := 10 + (k * 7) % 28
			var y := 33 + (k * 3) % 4
			c.lit(x, y, Pal.ramp(Pal.EMBER, 1 + (k + i) % 4))
		# logs
		c.paint(c.mask().poly(V([[12, 34], [34, 28], [36, 31], [14, 37]])), Pal.WOOD, 2)
		c.paint(c.mask().poly(V([[34, 35], [13, 28], [11, 31], [32, 38]])), Pal.WOOD, 3)
		# the great flame
		var sway: int = [0, 1, 2, 1, 0, -1][i]
		_flame(c, 24.0 + sway * 0.5, 34.0, 9.0, 26.0 + (i % 2) * 2.0, i, Pal.EMBER)
		_flame(c, 17.0 - sway * 0.5, 34.0, 4.0, 13.0 + (i % 3), i + 1, Pal.EMBER)
		_flame(c, 31.0 + sway * 0.3, 34.0, 4.0, 14.0 - (i % 2), i + 2, Pal.EMBER)
		for k in 3:
			c.lit(20 + (i * 3 + k * 5) % 10, 4 + (k * 5 + i * 2) % 10, Pal.EMBER[4])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("burn", fr, 9.0)
	s.save(dir, "hearth")


static func _descent(dir: String) -> void:
	var s := Sheet.new(64, 48, Vector2i(32, 44))
	var fr: Array = []
	for i in 4:
		var c := Px.new(64, 48)
		# stone archway over a stair into darkness
		var arch := c.mask().rect(6, 8, 52, 38)
		arch.subtract(c.mask().ellipse(32.0, 26.0, 18.0, 22.0).rect(14, 26, 36, 20))
		c.paint(arch, Pal.STONE, 3, true)
		for y in range(10, 46, 6):
			c.line(6, y, 14, y, Pal.STONE[1])
			c.line(50, y, 58, y, Pal.STONE[1])
		var hole := c.mask().ellipse(32.0, 26.0, 18.0, 22.0).rect(14, 26, 36, 20)
		c.fill(hole, Pal.INK)
		for k in 5:
			var y := 30 + k * 3
			c.rect(18 + k * 2, y, 28 - k * 4, 2, Pal.ramp(Pal.STONE, 3 - k / 2))
		# keystone rune breathing soul-light
		c.paint(c.mask().rect(28, 2, 8, 9), Pal.STONE, 4, true)
		c.lit(31 + i % 2, 5, Pal.SOUL[4 + (i % 2)])
		c.lit(32, 6, Pal.SOUL[3])
		for k in 3:
			c.lit(24 + (i * 5 + k * 7) % 16, 14 + (k * 9 + i * 3) % 18, Pal.SOUL[3])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 4.0)
	s.save(dir, "descent")


static func _forge(dir: String) -> void:
	var s := Sheet.new(36, 30, Vector2i(18, 28))
	var fr: Array = []
	for i in 4:
		var c := Px.new(36, 30)
		# furnace
		c.paint(c.mask().rect(2, 4, 16, 24), Pal.EARTH, 2, true)
		c.paint(c.mask().rect(4, 0, 12, 6), Pal.EARTH, 3)
		var mouth := c.mask().ellipse(10.0, 18.0, 5.0, 5.0).rect(5, 18, 10, 6)
		c.fill_lit(mouth, Pal.EMBER[2])
		c.fill_lit(c.mask().ellipse(10.0, 20.0, 3.4, 3.0), Pal.EMBER[3 + (i % 2)])
		c.lit(9 + i % 2, 19, Pal.EMBER[5])
		# anvil
		c.paint(c.mask().poly(V([[20, 18], [34, 18], [32, 21], [22, 21]])), Pal.STEEL, 3, true)
		c.paint(c.mask().rect(25, 21, 4, 5), Pal.STEEL, 2)
		c.paint(c.mask().rect(22, 26, 10, 2), Pal.STEEL, 1)
		if i == 1:
			c.lit(27, 16, Pal.GOLD[4])
			c.lit(30, 15, Pal.EMBER[4])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 5.0)
	s.save(dir, "forge")
	var r := Px.new(36, 26)
	for k in 9:
		var x := 2 + (k * 7) % 28
		var y := 8 + (k * 5) % 14
		r.paint(r.mask().rect(x, y, 5 + k % 3, 3 + k % 2), Pal.EARTH, 2 + k % 2)
	r.paint(r.mask().poly(V([[20, 18], [34, 18], [32, 21], [22, 21]])), Pal.STEEL, 2)
	r.outline(Pal.INK)
	single(dir, "forge_ruin", r, Vector2i(18, 24))


static func _humanoid(c: Px, cloth: Array, b: int, skin := true) -> void:
	c.paint(c.mask().rect(9, 24, 2, 6), Pal.EARTH, 1)
	c.paint(c.mask().rect(13, 24, 2, 6), Pal.EARTH, 1)
	var body := c.mask().poly(V([[7, 13 + b], [17, 13 + b], [18, 26], [6, 26]]))
	c.paint(body, cloth, 2, true)
	if skin:
		c.paint(c.mask().ellipse(12.0, 8.0 + b, 3.6, 4.0), Pal.SKIN, 2)


static func _smith(dir: String) -> void:
	var s := Sheet.new(24, 32, Vector2i(12, 30))
	var fr: Array = []
	for i in 4:
		var c := Px.new(24, 32)
		var b := 1 if i >= 2 else 0
		_humanoid(c, Pal.EARTH, b)
		# leather apron, beard, hammer arm
		c.paint(c.mask().rect(9, 16 + b, 6, 10), Pal.WOOD, 2)
		c.paint(c.mask().poly(V([[9, 9 + b], [15, 9 + b], [13, 15 + b], [11, 15 + b]])), Pal.EMBER, 1)
		c.put(11, 7 + b, Pal.INK)
		c.put(13, 7 + b, Pal.INK)
		var ha := 4 if i == 1 else 0
		c.line(17, 15 + b, 20, 11 + b - ha, Pal.SKIN[1])
		c.paint(c.mask().rect(18, 8 + b - ha, 5, 3), Pal.STEEL, 3)
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 3.0)
	s.save(dir, "smith")


static func _rack(dir: String) -> void:
	var c := Px.new(28, 24)
	c.paint(c.mask().rect(2, 4, 24, 2), Pal.WOOD, 3)
	c.paint(c.mask().rect(2, 16, 24, 2), Pal.WOOD, 2)
	c.paint(c.mask().rect(3, 4, 2, 19), Pal.WOOD, 2)
	c.paint(c.mask().rect(23, 4, 2, 19), Pal.WOOD, 2)
	# a sword, a hammer and a staff on display
	c.paint(c.mask().rect(9, 2, 2, 18), Pal.STEEL, 4)
	c.paint(c.mask().rect(8, 15, 4, 1), Pal.GOLD, 3)
	c.paint(c.mask().rect(14, 6, 2, 16), Pal.WOOD, 2)
	c.paint(c.mask().rect(12, 3, 6, 5), Pal.STEEL, 2)
	c.paint(c.mask().rect(19, 2, 2, 20), Pal.WOOD, 3)
	c.lit(19, 1, Pal.EMBER[4])
	c.lit(20, 2, Pal.EMBER[3])
	c.outline(Pal.INK)
	single(dir, "rack", c, Vector2i(14, 22))


static func _apothecary(dir: String) -> void:
	var s := Sheet.new(32, 32, Vector2i(16, 30))
	var fr: Array = []
	for i in 4:
		var c := Px.new(32, 32)
		c.paint(c.mask().rect(2, 14, 28, 14), Pal.WOOD, 2, true)
		c.paint(c.mask().rect(1, 12, 30, 3), Pal.WOOD, 3)
		# bottles and an alembic
		for k in 5:
			var x := 4 + k * 5
			var col: Array = [Pal.BLOOD, Pal.EMBER, Pal.SOUL, Pal.GOLD, Pal.GLOAM][k]
			c.paint(c.mask().rect(x, 6, 3, 6), col, 3)
			c.lit(x + 1, 8 + (i + k) % 3, col[4])
			c.put(x + 1, 5, Pal.WOOD[3])
		c.paint(c.mask().ellipse(26.0, 22.0, 3.0, 3.0), Pal.STEEL, 3)
		c.lit(26, 18 - i % 2, Pal.BLOOD[4])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 4.0)
	s.save(dir, "apothecary")
	var r := Px.new(32, 24)
	r.paint(r.mask().poly(V([[2, 22], [6, 12], [14, 16], [20, 10], [30, 22]])), Pal.WOOD, 1, true)
	for k in 4:
		r.put(6 + k * 6, 20, Pal.STEEL[3])
	r.outline(Pal.INK)
	single(dir, "apothecary_ruin", r, Vector2i(16, 22))


static func _memorial(dir: String) -> void:
	var s := Sheet.new(24, 38, Vector2i(12, 36))
	var fr: Array = []
	for i in 4:
		var c := Px.new(24, 38)
		var m := c.mask().poly(V([[3, 36], [4, 10], [12, 2], [20, 10], [21, 36]]))
		c.paint(m, Pal.STONE, 3, true)
		for y in range(12, 33, 4):
			for x in range(7, 18, 2):
				if Px.hash01(x, y, 11) > 0.4:
					c.put(x, y, Pal.STONE[1])
		c.lit(12, 8, Pal.GLOAM[4 + (i % 2)])
		for k in 3:
			c.lit(7 + (k * 5 + i) % 10, 14 + (k * 7 + i * 3) % 18, Pal.GLOAM[3])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 4.0)
	s.save(dir, "memorial")
	var r := Px.new(24, 24)
	r.paint(r.mask().poly(V([[3, 22], [4, 12], [10, 9], [12, 14], [20, 11], [21, 22]])), Pal.STONE, 2, true)
	r.outline(Pal.INK)
	single(dir, "memorial_ruin", r, Vector2i(12, 22))


static func _keeper(dir: String) -> void:
	var s := Sheet.new(24, 34, Vector2i(12, 32))
	var fr: Array = []
	for i in 4:
		var c := Px.new(24, 34)
		var b: int = [0, 1, 1, 0][i]
		# an old woman wrapped in ember-coloured shawls, leaning on a staff
		c.paint(c.mask().rect(18, 8 + b, 2, 24 - b), Pal.WOOD, 2)
		c.lit(18, 6 + b, Pal.EMBER[4])
		c.lit(19, 7 + b, Pal.EMBER[3])
		var robe := c.mask().poly(V([[7, 12 + b], [16, 12 + b], [18, 31], [5, 31]]))
		c.paint(robe, Pal.CLOAK, 2, true)
		var shawl := c.mask().poly(V([[6, 11 + b], [17, 11 + b], [15, 19 + b], [8, 19 + b]]))
		c.paint(shawl, Pal.EMBER, 1, true)
		var hood := c.mask().ellipse(12.0, 8.0 + b, 4.4, 4.6)
		c.paint(hood, Pal.EMBER, 1, true)
		var face := c.mask().ellipse(12.5, 9.0 + b, 2.5, 2.8)
		c.paint(face, Pal.SKIN, 2)
		c.put(12, 9 + b, Pal.INK)
		c.put(14, 9 + b, Pal.INK)
		c.put(11, 12 + b, Pal.BONE[4])
		c.put(12, 13 + b, Pal.BONE[4])
		c.line(16, 15 + b, 18, 14 + b, Pal.SKIN[2])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 3.0)
	s.save(dir, "keeper")


static func _lantern_post(dir: String) -> void:
	var s := Sheet.new(12, 34, Vector2i(6, 33))
	var fr: Array = []
	for i in 4:
		fr.append(_post(i, true))
	s.add("lit", fr, 5.0)
	s.add("unlit", [_post(0, false)], 1.0)
	s.save(dir, "lantern_post")


static func _post(i: int, on: bool) -> Px:
	var c := Px.new(12, 34)
	c.paint(c.mask().rect(5, 8, 2, 25), Pal.WOOD, 2)
	c.paint(c.mask().rect(3, 31, 6, 2), Pal.STONE, 2)
	c.paint(c.mask().rect(4, 7, 7, 1), Pal.WOOD, 3)
	c.paint(c.mask().rect(8, 8, 3, 1), Pal.STEEL, 2)
	c.paint(c.mask().rect(7, 9, 5, 6), Pal.STEEL, 1)
	if on:
		c.fill_lit(c.mask().rect(8, 10, 3, 4), Pal.EMBER[3 + (i % 2)])
		c.lit(9, 11, Pal.EMBER[5])
	else:
		c.fill(c.mask().rect(8, 10, 3, 4), Pal.INK)
	c.outline(Pal.INK)
	return c


static func _merchant(dir: String) -> void:
	var s := Sheet.new(32, 34, Vector2i(16, 32))
	var fr: Array = []
	for i in 4:
		var c := Px.new(32, 34)
		var b: int = [0, 1, 1, 0][i]
		# a hunched wanderer under a pack piled with wares and a dangling lamp
		var pack := c.mask().rect(3, 6 + b, 14, 18)
		c.paint(pack, Pal.WOOD, 2, true)
		for k in 4:
			c.paint(c.mask().rect(4 + k * 3, 3 + b + (k % 2), 3, 4), [Pal.BLOOD, Pal.GOLD, Pal.SOUL, Pal.EARTH][k], 3)
		var body := c.mask().poly(V([[12, 12 + b], [22, 12 + b], [24, 31], [10, 31]]))
		c.paint(body, Pal.EARTH, 2, true)
		var hood := c.mask().ellipse(19.0, 10.0 + b, 4.6, 4.4)
		c.paint(hood, Pal.EARTH, 3, true)
		c.fill(c.mask().ellipse(21.0, 11.0 + b, 2.6, 2.4), Pal.INK)
		c.lit(21, 11 + b, Pal.GOLD[4])
		c.lit(23, 11 + b, Pal.GOLD[4])
		# lamp
		c.line(25, 14 + b, 28, 17 + b, Pal.WOOD[2])
		c.paint(c.mask().rect(27, 18 + b, 3, 4), Pal.STEEL, 2)
		c.lit(28, 19 + b, Pal.EMBER[4 + (i % 2)])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 3.0)
	s.save(dir, "merchant")
