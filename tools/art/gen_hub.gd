## Sanctuary structures and residents: the Hearth, the Descent, forge, smith,
## apothecary, memorial, the Keeper, lantern posts, the dungeon merchant, the
## survivors who gather at the Hearth, and the camp they build around it.
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
	_residents(dir)
	_camp(dir)


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


# --- survivors ----------------------------------------------------------------------

## head: 0 hood, 1 scarf, 2 bare, 3 cap.  extra: 0 none, 1 basket, 2 lantern,
## 3 logs, 4 sling, 5 child.
static func _resident_specs() -> Array:
	return [
		{"name": "resident_ama", "cloth": Pal.EARTH, "accent": Pal.MOSS, "hair": Pal.EARTH, "head": 1, "extra": 1},
		{"name": "resident_teodric", "cloth": Pal.STEEL, "accent": Pal.BLOOD, "hair": Pal.BONE, "head": 2, "extra": 4},
		{"name": "resident_wren", "cloth": Pal.GLOAM, "accent": Pal.GOLD, "hair": Pal.WOOD, "head": 2, "extra": 5},
		{"name": "resident_bram", "cloth": Pal.FROST, "accent": Pal.STEEL, "hair": Pal.EARTH, "head": 0, "extra": 2},
		{"name": "resident_hollis", "cloth": Pal.WOOD, "accent": Pal.EARTH, "hair": Pal.EMBER, "head": 3, "extra": 3},
		{"name": "resident_sefa", "cloth": Pal.BLOOD, "accent": Pal.BONE, "hair": Pal.WOOD, "head": 1, "extra": 0},
	]


static func _residents(dir: String) -> void:
	for sp in _resident_specs():
		var s := Sheet.new(24, 32, Vector2i(12, 30))
		var idle: Array = []
		var walk: Array = []
		for i in 4:
			idle.append(_resident(sp, "idle", i))
			walk.append(_resident(sp, "walk", i))
		s.add("idle", idle, 3.0)
		s.add("walk", walk, 8.0)
		s.add("sit", [_resident(sp, "sit", 0), _resident(sp, "sit", 1)], 1.5)
		s.save(dir, String(sp.name))


static func _resident(sp: Dictionary, pose: String, f: int) -> Px:
	var c := Px.new(24, 32)
	var child: bool = int(sp.extra) == 5
	var cloth: Array = sp.cloth
	var accent: Array = sp.accent
	var b := 0
	var sit := pose == "sit"
	match pose:
		"idle":
			b = [0, 0, 1, 1][f]
		"walk":
			b = [0, 1, 0, 1][f]
		"sit":
			b = 5
	var top := 6 if child else 0          # children stand lower
	var hw := 4 if child else 5           # half body width
	var head_r := 3.2 if child else 3.6
	var hy := 8.0 + top + b               # head centre
	var body_top := 13 + top + b
	# legs
	if sit:
		c.paint(c.mask().rect(8, 28, 3, 2), Pal.EARTH, 1)
		c.paint(c.mask().rect(13, 28, 3, 2), Pal.EARTH, 1)
	else:
		var swing: int = [0, 1, 0, -1][f] if pose == "walk" else 0
		var leg_y := 26 if child else 24
		var leg_h := 4 if child else 6
		c.paint(c.mask().rect(9 + swing, leg_y, 2, leg_h - absi(swing)), Pal.EARTH, 1)
		c.paint(c.mask().rect(13 - swing, leg_y, 2, leg_h - absi(swing)), Pal.EARTH, 1)
	# body
	var bottom := 29 if sit else (27 if child else 26)
	var body := c.mask().poly(V([[12 - hw, body_top], [12 + hw, body_top], [12 + hw + 1, bottom], [12 - hw - 1, bottom]]))
	c.paint(body, cloth, 2, true)
	# belt / sash in the accent colour
	c.paint(c.mask().rect(12 - hw, body_top + 6, hw * 2 + 1, 1), accent, 2)
	# arms
	var arm_swing: int = [1, 0, -1, 0][f] if pose == "walk" else 0
	c.paint(c.mask().rect(12 - hw - 1, body_top + 1 + arm_swing, 2, 7), cloth, 1)
	c.paint(c.mask().rect(12 + hw, body_top + 1 - arm_swing, 2, 7), cloth, 1)
	c.put(12 - hw - 1, body_top + 8 + arm_swing, Pal.SKIN[2])
	c.put(12 + hw + 1, body_top + 8 - arm_swing, Pal.SKIN[2])
	# head
	if int(sp.head) == 0:
		c.paint(c.mask().ellipse(12.0, hy, head_r + 0.9, head_r + 1.0), cloth, 1, true)
		c.paint(c.mask().ellipse(12.4, hy + 1.0, head_r - 1.1, head_r - 0.9), Pal.SKIN, 2)
	else:
		c.paint(c.mask().ellipse(12.0, hy, head_r, head_r + 0.4), Pal.SKIN, 2)
		var hair: Array = sp.hair
		match int(sp.head):
			1:
				var scarf := c.mask().ellipse(12.0, hy - 2.0, head_r + 0.6, 2.2)
				scarf.rect(int(12 - head_r) - 1, int(hy) - 2, 2, 5)
				c.paint(scarf, accent, 2, true)
			2:
				c.paint(c.mask().ellipse(12.0, hy - 2.2, head_r, 1.8), hair, 2)
			3:
				c.paint(c.mask().rect(int(12 - head_r) - 1, int(hy) - 4, int(head_r * 2) + 3, 2), accent, 3)
				c.paint(c.mask().rect(int(12 - head_r), int(hy) - 6, int(head_r * 2) + 1, 2), accent, 2)
	c.put(11, int(hy) + 1, Pal.INK)
	c.put(13, int(hy) + 1, Pal.INK)
	# what they carry
	match int(sp.extra):
		1:
			c.paint(c.mask().rect(17, body_top + 6, 5, 4), Pal.WOOD, 2)
			c.put(18, body_top + 5, Pal.MOSS[4])
			c.put(20, body_top + 4, Pal.MOSS[3])
		2:
			c.line(18, body_top + 7 - arm_swing, 19, body_top + 9 - arm_swing, Pal.WOOD[2])
			c.paint(c.mask().rect(18, body_top + 10 - arm_swing, 3, 4), Pal.STEEL, 2)
			c.lit(19, body_top + 11 - arm_swing, Pal.EMBER[4 + f % 2])
		3:
			for k in 3:
				c.paint(c.mask().rect(4 + k, body_top - 2 + k * 3, 3, 3), Pal.WOOD, 3 - k % 2)
		4:
			c.paint(c.mask().rect(13, body_top + 3, 4, 3), Pal.BONE, 3)
	c.outline(Pal.INK)
	return c


# --- the camp around the Hearth ---------------------------------------------------------

static func _camp(dir: String) -> void:
	# log bench
	var bench := Px.new(26, 12)
	bench.paint(bench.mask().rect(3, 3, 20, 6), Pal.WOOD, 2, true)
	bench.paint(bench.mask().ellipse(3.0, 6.0, 2.6, 3.2), Pal.WOOD, 3)
	bench.put(3, 6, Pal.WOOD[1])
	bench.paint(bench.mask().ellipse(23.0, 6.0, 2.6, 3.2), Pal.WOOD, 3)
	bench.put(23, 6, Pal.WOOD[1])
	for x in range(6, 21, 4):
		bench.put(x, 5, Pal.WOOD[1])
	bench.outline(Pal.INK)
	single(dir, "bench", bench, Vector2i(13, 10))
	# lean-to tent with a bedroll
	var tent := Px.new(34, 28)
	tent.line(4, 26, 17, 3, Pal.WOOD[2])
	tent.line(30, 26, 17, 3, Pal.WOOD[2])
	tent.paint(tent.mask().poly(V([[17, 4], [31, 25], [5, 25]])), Pal.EARTH, 2, true)
	tent.fill(tent.mask().poly(V([[17, 10], [24, 25], [10, 25]])), Pal.STONE[0])
	tent.paint(tent.mask().rect(11, 21, 12, 4), Pal.BLOOD, 1)
	tent.paint(tent.mask().rect(21, 12, 5, 4), Pal.MOSS, 2)   # a patch
	tent.outline(Pal.INK)
	single(dir, "tent", tent, Vector2i(17, 26))
	# crates and a barrel
	var cr := Px.new(26, 24)
	cr.paint(cr.mask().rect(1, 10, 11, 12), Pal.WOOD, 2, true)
	cr.paint(cr.mask().rect(4, 2, 9, 9), Pal.WOOD, 3, true)
	cr.line(1, 10, 11, 21, Pal.WOOD[1])
	cr.line(4, 2, 12, 10, Pal.WOOD[1])
	cr.paint(cr.mask().ellipse(19.0, 15.0, 5.0, 7.0), Pal.WOOD, 2, true)
	cr.paint(cr.mask().rect(14, 11, 11, 1), Pal.STEEL, 2)
	cr.paint(cr.mask().rect(14, 18, 11, 1), Pal.STEEL, 2)
	cr.outline(Pal.INK)
	single(dir, "crates", cr, Vector2i(13, 22))
	# cookpot on a tripod over coals
	var s := Sheet.new(20, 24, Vector2i(10, 22))
	var fr: Array = []
	for i in 4:
		var c := Px.new(20, 24)
		c.line(2, 22, 10, 2, Pal.WOOD[1])
		c.line(18, 22, 10, 2, Pal.WOOD[1])
		c.line(10, 3, 10, 9, Pal.STEEL[3])
		c.paint(c.mask().ellipse(10.0, 13.0, 6.0, 4.6), Pal.STEEL, 1, true)
		c.paint(c.mask().ellipse(10.0, 9.6, 5.0, 1.4), Pal.EARTH, 3)
		for k in 6:
			c.lit(5 + k * 2, 20 + (k + i) % 2, Pal.ramp(Pal.EMBER, 2 + (k + i) % 3))
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 5.0)
	s.save(dir, "cookpot")
	# a hearth banner for the north wall
	var bn := Px.new(12, 24)
	bn.paint(bn.mask().rect(0, 0, 12, 2), Pal.WOOD, 3)
	bn.paint(bn.mask().poly(V([[1, 2], [11, 2], [11, 21], [6, 17], [1, 21]])), Pal.EMBER, 1, true)
	var sig := bn.mask().ellipse(6.0, 10.0, 2.4, 3.2)
	sig.poly(V([[4, 9], [6, 4], [8, 9]]))
	bn.paint(sig, Pal.GOLD, 3, false, false)
	bn.lit(6, 10, Pal.GOLD[4])
	bn.outline(Pal.INK)
	single(dir, "hearth_banner", bn, Vector2i(6, 23))
	# planters: bare soil -> sprout -> leaves -> a glowing sunbloom
	var ps := Sheet.new(18, 20, Vector2i(9, 18))
	for stage in 4:
		var c := Px.new(18, 20)
		c.paint(c.mask().rect(2, 12, 14, 6), Pal.WOOD, 2, true)
		c.paint(c.mask().rect(3, 11, 12, 2), Pal.EARTH, 1)
		if stage >= 1:
			c.line(9, 11, 9, 11 - stage * 2, Pal.MOSS[2])
			c.put(8, 10, Pal.MOSS[3])
		if stage >= 2:
			c.paint(c.mask().ellipse(6.5, 8.0, 2.2, 1.2), Pal.MOSS, 3)
			c.paint(c.mask().ellipse(11.5, 6.5, 2.2, 1.2), Pal.MOSS, 3)
			c.put(5, 11, Pal.MOSS[2])
			c.put(13, 10, Pal.MOSS[2])
		if stage >= 3:
			c.fill_lit(c.mask().ellipse(9.0, 3.0, 2.6, 2.2), Pal.GOLD[3])
			c.lit(9, 3, Pal.EMBER[5])
			c.lit(8, 2, Pal.GOLD[4])
		c.outline(Pal.INK)
		ps.add("s%d" % stage, [c], 1.0)
	ps.save(dir, "planter")
