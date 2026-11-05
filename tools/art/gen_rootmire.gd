## The Rootmire: bioluminescent fungi, brambles that burn, spore pods, and
## the creatures that live among the roots of the dead world-tree.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func limb(c: Px, pts: Array, r: Array, base: int, thick := 2) -> void:
	var m := c.mask()
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		m.line(a[0], a[1], b[0], b[1])
		if thick >= 2:
			m.line(a[0] + 1, a[1], b[0] + 1, b[1])
	c.paint(m, r, base, false, true)


static func build(dir: String) -> void:
	_glowcap(dir)
	_bramble(dir)
	_sporepod(dir)
	_torch_bio(dir)
	_sporeling(dir)
	_thornback(dir)
	_moth(dir)
	_rootweaver(dir)
	_bloom(dir)


# --- props --------------------------------------------------------------------------

static func _glowcap(dir: String) -> void:
	var s := Sheet.new(20, 22, Vector2i(10, 21))
	var fr: Array = []
	for i in 4:
		var c := Px.new(20, 22)
		var sway: int = [0, 1, 0, -1][i]
		for cap in [[6, 12, 4.5, 3.0, Pal.SOUL], [13, 8, 5.5, 3.6, Pal.GLOAM], [15, 15, 3.0, 2.0, Pal.SOUL]]:
			var cx: float = cap[0] + sway * (0.5 if cap[1] < 10 else 0.0)
			var cy: float = cap[1]
			var stem := c.mask().rect(int(cx) - 1, int(cy), 2, 21 - int(cy))
			c.paint(stem, Pal.BONE, 2)
			var top := c.mask().ellipse(cx, cy, cap[2], cap[3])
			top.subtract(c.mask().rect(0, int(cy) + 1, 20, 22))
			var r: Array = cap[4]
			c.fill_lit(top, r[3])
			for x in range(int(cx - cap[2]) + 1, int(cx + cap[2])):
				if top.has(x, int(cy)):
					c.lit(x, int(cy), r[2])
			c.lit(int(cx) - 1, int(cy - cap[3] + 1), r[5])
			c.lit(int(cx) + 1, int(cy - 1), r[4])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 3.0)
	s.save(dir, "glowcap")


static func _bramble(dir: String) -> void:
	var s := Sheet.new(24, 22, Vector2i(12, 20))
	s.add("idle", [_bramble_frame(0, 0), _bramble_frame(1, 0)], 2.0)
	var burn: Array = []
	for i in 4:
		burn.append(_bramble_frame(i % 2, i + 1))
	s.add("burning", burn, 10.0)
	s.add("burnt", [_bramble_frame(0, 9)], 1.0)
	s.save(dir, "bramble")


static func _bramble_frame(sway: int, burn: int) -> Px:
	var c := Px.new(24, 22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	if burn == 9:
		# charred stubs and ash
		for k in 7:
			var x := 3 + k * 3
			c.line(x, 20, x + rng.randi_range(-1, 1), 16 - rng.randi_range(0, 3), Pal.INK)
		c.rect(2, 19, 20, 2, Pal.STONE[1])
		for k in 5:
			c.lit(4 + k * 4, 19, Pal.EMBER[1])
		return c
	var m := c.mask()
	for k in 9:
		var x0 := 2.0 + k * 2.3
		var a := -PI / 2.0 + rng.randf_range(-0.8, 0.8)
		var x := x0
		var y := 20.0
		for st in rng.randi_range(10, 18):
			a += rng.randf_range(-0.4, 0.4)
			x += cos(a) + sway * 0.05 * st
			y += sin(a)
			m.set_bit(int(x), int(y))
			if st % 4 == 0:
				m.set_bit(int(x) + 1, int(y) - 1)
	c.paint(m, Pal.MOSS, 2, false, true)
	# thorns
	for y in 22:
		for x in 24:
			if m.has(x, y) and Px.hash01(x, y, 7) > 0.8:
				c.put(x + 1, y, Pal.BONE[3])
	c.outline(Pal.INK)
	if burn > 0:
		for k in 10 + burn * 2:
			var x := rng.randi_range(2, 21)
			var y := rng.randi_range(5, 20)
			c.lit(x, y, Pal.EMBER[3 + (k + burn) % 3])
			c.lit(x, y - 1, Pal.EMBER[2])
	return c


static func _sporepod(dir: String) -> void:
	var s := Sheet.new(14, 16, Vector2i(7, 15))
	var fr: Array = []
	for i in 2:
		var c := Px.new(14, 16)
		var m := c.mask().ellipse(7.0, 9.0 - i * 0.5, 5.2 + i * 0.4, 6.0 + i * 0.4)
		c.paint(m, Pal.GLOAM, 2, true)
		for k in 5:
			c.lit(4 + (k * 3) % 7, 6 + (k * 5) % 7, Pal.MOSS[5] if k % 2 == 0 else Pal.GLOAM[5])
		c.paint(c.mask().rect(5, 14, 4, 2), Pal.MOSS, 1)
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 2.0)
	s.save(dir, "sporepod")


static func _torch_bio(dir: String) -> void:
	var s := Sheet.new(9, 16, Vector2i(4, 15))
	var fr: Array = []
	for i in 4:
		var c := Px.new(9, 16)
		c.paint(c.mask().rect(3, 9, 3, 6), Pal.WOOD, 2)
		var bulb := c.mask().ellipse(4.5, 6.5, 3.2 + (i % 2) * 0.4, 3.0)
		c.fill_lit(bulb, Pal.MOSS[4])
		c.lit(4, 5, Pal.MOSS[5])
		c.lit(3 + i % 2, 4, Pal.WHITE)
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 4.0)
	s.save(dir, "torch_bio")


# --- enemies ---------------------------------------------------------------------------

static func _sporeling(dir: String) -> void:
	var s := Sheet.new(20, 20, Vector2i(10, 18))
	s.add("idle", [_sporeling_frame(0, 0), _sporeling_frame(1, 0)], 3.0)
	s.add("walk", [_sporeling_frame(0, -2), _sporeling_frame(1, 0), _sporeling_frame(0, -1), _sporeling_frame(1, 0)], 10.0)
	s.add("windup", [_sporeling_frame(2, 1)], 1.0, false)
	s.add("attack", [_sporeling_frame(3, -2)], 1.0, false)
	s.save(dir, "sporeling")


static func _sporeling_frame(pose: int, hop: int) -> Px:
	var c := Px.new(20, 20)
	var b := hop
	# stubby legs
	c.paint(c.mask().rect(7, 15 + maxi(b, 0), 2, 3 - maxi(b, 0)), Pal.BONE, 1)
	c.paint(c.mask().rect(11, 15 + maxi(b, 0), 2, 3 - maxi(b, 0)), Pal.BONE, 1)
	# stalk body
	var body := c.mask().ellipse(10.0, 13.0 + b, 4.0, 3.5)
	c.paint(body, Pal.BONE, 3)
	# cap
	var squash := 1.0 if pose == 2 else 0.0
	var cap := c.mask().ellipse(10.0, 8.5 + b + squash, 7.0 + squash, 5.0 - squash)
	cap.subtract(c.mask().rect(0, int(10.0 + b + squash), 20, 20))
	c.paint(cap, Pal.BLOOD, 3, true)
	for k in 4:
		c.lit(6 + k * 3, 6 + b + (k % 2), Pal.MOSS[5])
	# face
	var mouth_open := pose == 3
	c.put(8, 12 + b, Pal.INK)
	c.put(12, 12 + b, Pal.INK)
	c.lit(8, 12 + b, Pal.MOSS[5])
	c.lit(12, 12 + b, Pal.MOSS[5])
	if mouth_open:
		c.rect(9, 14 + b, 3, 2, Pal.INK)
	else:
		c.line(9, 14 + b, 11, 14 + b, Pal.INK)
	c.outline(Pal.INK)
	return c


static func _thornback(dir: String) -> void:
	var s := Sheet.new(32, 26, Vector2i(16, 24))
	var walk: Array = []
	for i in 4:
		walk.append(_thornback_frame(i, false, 0))
	s.add("idle", [walk[0]], 1.0)
	s.add("walk", walk, 8.0)
	s.add("curl", [_thornback_frame(0, true, 0)], 1.0, false)
	var roll: Array = []
	for i in 4:
		roll.append(_thornback_frame(0, true, i))
	s.add("roll", roll, 16.0)
	s.add("dizzy", [_thornback_frame(1, false, 0), _thornback_frame(3, false, 0)], 4.0)
	s.save(dir, "thornback")


static func _thornback_frame(step: int, ball: bool, spin: int) -> Px:
	var c := Px.new(32, 26)
	if ball:
		var m := c.mask().ellipse(16.0, 15.0, 9.5, 9.0)
		c.paint(m, Pal.STEEL, 1, true)
		for k in 8:
			var a := k * PI / 4.0 + spin * PI / 8.0
			var p := Vector2(16, 15) + Vector2(cos(a), sin(a)) * 9.0
			var q := Vector2(16, 15) + Vector2(cos(a), sin(a)) * 12.0
			c.line(int(p.x), int(p.y), int(q.x), int(q.y), Pal.BONE[3])
			c.lit(int(Vector2(16, 15).x + cos(a) * 5.0), int(15 + sin(a) * 5.0), Pal.MOSS[4])
		c.outline(Pal.INK)
		return c
	# six legs
	for k in 3:
		var lx := 9 + k * 6
		var off := 1 if (step + k) % 2 == 0 else -1
		limb(c, [[lx, 17], [lx - 2 + off, 21], [lx - 3 + off, 24]], Pal.STEEL, 1, 1)
	# shell
	var shell := c.mask().ellipse(16.0, 13.0, 11.0, 7.0)
	shell.subtract(c.mask().rect(0, 17, 32, 9))
	c.paint(shell, Pal.STEEL, 2, true)
	# moss and glowing spore spots
	for k in 6:
		var x := 8 + k * 3
		c.put(x, 8 + (k % 2), Pal.MOSS[2])
		c.lit(x + 1, 11 + (k % 3), Pal.MOSS[4])
	# spines
	for k in 5:
		var x := 9 + k * 3
		c.line(x, 7, x - 1, 3 + (k % 2), Pal.BONE[3])
	# head
	var head := c.mask().ellipse(26.0, 15.0, 4.0, 3.2)
	c.paint(head, Pal.STEEL, 1)
	c.lit(28, 14, Pal.MOSS[5])
	c.line(29, 17, 31, 18, Pal.BONE[3])
	c.outline(Pal.INK)
	return c


static func _moth(dir: String) -> void:
	var s := Sheet.new(24, 22, Vector2i(12, 21))
	var fr: Array = []
	for i in 4:
		fr.append(_moth_frame(i))
	s.add("idle", fr, 14.0)
	s.add("dive", [_moth_frame(1), _moth_frame(3)], 20.0)
	s.save(dir, "moth")


static func _moth_frame(flap: int) -> Px:
	var c := Px.new(24, 22)
	var wy: int = [0, -3, -5, -3][flap]
	for side in [-1, 1]:
		var w := c.mask().poly(V([[12, 9], [12 + side * 11, 4 + wy], [12 + side * 10, 12 + wy / 2], [12, 13]]))
		c.paint(w, Pal.GLOAM, 3, true)
		# glowing eye-spots on the wings: they drink lantern light
		c.lit(12 + side * 7, 8 + wy / 2, Pal.EMBER[4])
		c.lit(12 + side * 7, 9 + wy / 2, Pal.EMBER[2])
	var body := c.mask().ellipse(12.0, 11.0, 2.2, 4.5)
	c.paint(body, Pal.EARTH, 3)
	c.line(11, 6, 9, 3, Pal.EARTH[4])
	c.line(13, 6, 15, 3, Pal.EARTH[4])
	c.lit(11, 8, Pal.WHITE)
	c.lit(13, 8, Pal.WHITE)
	c.outline(Pal.INK)
	return c


static func _rootweaver(dir: String) -> void:
	var s := Sheet.new(24, 32, Vector2i(12, 30))
	var idle: Array = []
	for i in 4:
		idle.append(_weaver_frame(i, false))
	s.add("idle", idle, 4.0)
	s.add("walk", idle, 6.0)
	s.add("cast", [_weaver_frame(0, true), _weaver_frame(2, true)], 6.0)
	s.save(dir, "rootweaver")


static func _weaver_frame(i: int, cast: bool) -> Px:
	var c := Px.new(24, 32)
	var b: int = [0, 1, 1, 0][i]
	# root skirt
	for k in 7:
		var x0 := 6 + k * 2
		limb(c, [[x0 + 1, 18 + b], [x0 - 1 + (k + i) % 3, 25], [x0 - 2 + (k % 3), 30]], Pal.WOOD, 3, 1)
	# bark body
	var body := c.mask().poly(V([[9, 10 + b], [15, 10 + b], [16, 20 + b], [8, 20 + b]]))
	c.paint(body, Pal.WOOD, 3, true)
	for y in range(12 + b, 20 + b, 3):
		c.put(11, y, Pal.MOSS[3])
	# leafy hair and mask-like face
	var hair := c.mask().ellipse(12.0, 6.5 + b, 5.5, 5.0)
	c.paint(hair, Pal.MOSS, 2, true)
	var face := c.mask().ellipse(12.5, 7.5 + b, 2.8, 3.0)
	c.paint(face, Pal.BONE, 3)
	c.lit(11, 7 + b, Pal.MOSS[5])
	c.lit(14, 7 + b, Pal.MOSS[5])
	c.put(12, 9 + b, Pal.INK)
	# arms
	if cast:
		limb(c, [[9, 12 + b], [5, 7 + b], [4, 3 + b]], Pal.WOOD, 3, 1)
		limb(c, [[15, 12 + b], [19, 7 + b], [20, 3 + b]], Pal.WOOD, 3, 1)
		for k in 3:
			c.lit(3 + k * 8, 1 + b + (k % 2), Pal.MOSS[5])
	else:
		limb(c, [[9, 12 + b], [6, 17 + b]], Pal.WOOD, 3, 1)
		limb(c, [[15, 12 + b], [18, 17 + b]], Pal.WOOD, 3, 1)
	c.outline(Pal.INK)
	return c


# --- boss -------------------------------------------------------------------------------

## The Hollow Bloom: a colossal corpse-flower rooted in the floor. 80x80.
static func _bloom(dir: String) -> void:
	var s := Sheet.new(80, 80, Vector2i(40, 76))
	s.add("idle", [_bloom_frame(0, 0), _bloom_frame(1, 0), _bloom_frame(2, 0), _bloom_frame(1, 0)], 4.0)
	s.add("open", [_bloom_frame(0, 1), _bloom_frame(0, 2), _bloom_frame(0, 3)], 8.0, false)
	s.add("inhale", [_bloom_frame(0, 3), _bloom_frame(1, 3)], 8.0)
	s.add("close", [_bloom_frame(0, 2), _bloom_frame(0, 1), _bloom_frame(0, 0)], 10.0, false)
	s.add("spit", [_bloom_frame(2, 1), _bloom_frame(0, 2)], 8.0, false)
	s.add("wilt", [_bloom_frame(3, 0)], 1.0)
	s.save(dir, "bloom")


static func _bloom_frame(sway: int, open_k: int) -> Px:
	var c := Px.new(80, 80)
	var wilt := sway == 3
	var sw: int = [0, 1, 0, 0][sway]
	# roots splaying across the floor
	for k in 7:
		var a := PI + k * PI / 6.0
		var x := 40.0
		var y := 74.0
		var m := c.mask()
		for st in 22:
			x += cos(a) * 1.4
			y += sin(a) * 0.25 + 0.05
			m.set_bit(int(x), int(y))
			m.set_bit(int(x), int(y) - 1)
		c.paint(m, Pal.WOOD, 2, false, false)
	# thick stem
	var stem := c.mask().poly(V([[34, 76], [46, 76], [44 + sw, 40], [36 + sw, 40]]))
	c.paint(stem, Pal.MOSS, 2, true)
	for y in range(44, 74, 5):
		c.put(39 + sw, y, Pal.MOSS[1])
	# leaves
	var leaf_l := c.mask().poly(V([[37, 60], [18, 50], [10, 58], [24, 64]]))
	var leaf_r := c.mask().poly(V([[43, 56], [62, 46], [70, 54], [56, 60]]))
	c.paint(leaf_l, Pal.MOSS, 2, true)
	c.paint(leaf_r, Pal.MOSS, 3, true)
	# head: petals around a maw
	var hx := 40 + sw
	var hy := 26 + (6 if wilt else 0)
	var spread := 7.0 + open_k * 4.0
	for k in 6:
		var a := -PI / 2.0 + (k - 2.5) * (0.55 + open_k * 0.12)
		var tip := Vector2(hx, hy) + Vector2(cos(a), sin(a)) * (spread + 10.0)
		var l := Vector2(hx, hy) + Vector2(cos(a - 0.4), sin(a - 0.4)) * spread
		var r := Vector2(hx, hy) + Vector2(cos(a + 0.4), sin(a + 0.4)) * spread
		var petal := c.mask().poly(PackedVector2Array([Vector2(hx, hy), l, tip, r]))
		c.paint(petal, Pal.BLOOD if not wilt else Pal.EARTH, 3, true)
		c.put(int(tip.x), int(tip.y) + 1, Pal.BLOOD[4])
	# lower petals curling down
	for k in 2:
		var side := -1 if k == 0 else 1
		var lp := c.mask().poly(V([[hx, hy + 2], [hx + side * (14 + open_k * 3), hy + 6], [hx + side * 10, hy + 14]]))
		c.paint(lp, Pal.BLOOD if not wilt else Pal.EARTH, 2, true)
	# the maw: glows when open
	var maw := c.mask().ellipse(float(hx), float(hy), 5.0 + open_k * 2.0, 4.0 + open_k * 1.6)
	c.fill(maw, Pal.INK)
	if open_k > 0:
		var core := c.mask().ellipse(float(hx), float(hy) + 1.0, 2.0 + open_k, 1.5 + open_k * 0.8)
		c.fill_lit(core, Pal.MOSS[4])
		for k in open_k * 3:
			var a := k * TAU / (open_k * 3)
			c.lit(int(hx + cos(a) * (3.5 + open_k * 1.8)), int(hy + sin(a) * (3.0 + open_k * 1.4)), Pal.BONE[4])
	# spore glands
	for k in 5:
		c.lit(hx - 12 + k * 6, hy + 14 + (k % 2) * 2, Pal.GLOAM[5] if not wilt else Pal.GLOAM[2])
	c.outline(Pal.INK)
	return c
