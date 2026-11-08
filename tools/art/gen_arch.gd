## Architecture: what a room is built from beyond its walls.
##   inlay_*   lies in the floor and is walked over (Physical GROUND: flat, no outline of its own).
##   monuments stand on the floor and stop you (a foot the width of the tiles they block).
## Each region gets its own: tombs and charnel banks in the Ossuary, a dead court's colossi
## and machinery in the Throne, and a set of strange standing things for each mood of the
## Hollow Below.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
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


## The same drawing turned on its side, for a way that runs the other way.
static func turned(c: Px) -> Px:
	var o := Px.new(c.h, c.w)
	for y in c.h:
		for x in c.w:
			var col := c.get_c(x, y)
			if col.a <= 0.0:
				continue
			if c.glow[y * c.w + x] != 0:
				o.lit(y, x, col)
			else:
				o.put(y, x, col)
	return o


static func both(dir: String, name: String, frames: Dictionary) -> void:
	var a: Px = frames.values()[0]
	var s := Sheet.new(a.w, a.h, Vector2i(a.w / 2, a.h / 2))
	var v := Sheet.new(a.h, a.w, Vector2i(a.h / 2, a.w / 2))
	for k: String in frames:
		s.add(k, [frames[k]], 1.0)
		v.add(k, [turned(frames[k])], 1.0)
	s.save(dir, name)
	v.save(dir, name + "_v")


static func build(dir: String) -> void:
	_inlays(dir)
	_ossuary(dir)
	_throne(dir)
	_hollow(dir)
	_jambs(dir)
	_settlements(dir)


# --- what lies in the floor ---------------------------------------------------------

static func _slab(c: Px, x: int, y: int, w: int, h: int, r: Array, base: int) -> void:
	c.rect(x, y, w, h, r[base])
	c.rect(x, y, w, 1, r[mini(base + 1, r.size() - 1)])
	c.rect(x, y, 1, h, r[mini(base + 1, r.size() - 1)])
	c.rect(x, y + h - 1, w, 1, r[maxi(base - 1, 0)])
	c.rect(x + w - 1, y, 1, h, r[maxi(base - 1, 0)])


static func _inlays(dir: String) -> void:
	# grave slabs let into the floor: a figure, a skull, one lifted a little
	var tomb := {}
	for k: String in ["figure", "skull", "open"]:
		var c := Px.new(32, 18)
		c.rect(1, 1, 30, 16, Pal.STONE[0])
		_slab(c, 2, 2, 28, 14, Pal.STONE, 2)
		c.rect(4, 4, 24, 10, Pal.STONE[1])
		_slab(c, 5, 5, 22, 8, Pal.STONE, 2)
		match k:
			"figure":
				c.paint(c.mask().ellipse(16.0, 9.0, 8.0, 2.4), Pal.STONE, 3)
				c.paint(c.mask().ellipse(8.5, 9.0, 2.0, 2.0), Pal.STONE, 3)
				c.line(10, 9, 23, 9, Pal.STONE[1])
			"skull":
				c.paint(c.mask().ellipse(16.0, 8.6, 3.0, 2.6), Pal.BONE, 1)
				c.put(15, 9, Pal.INK)
				c.put(17, 9, Pal.INK)
				c.line(9, 6, 23, 12, Pal.STONE[1])
				c.line(23, 6, 9, 12, Pal.STONE[1])
			"open":
				c.rect(6, 6, 20, 6, Pal.INK)
				_slab(c, 10, 5, 18, 8, Pal.STONE, 2)
				for x in range(7, 10):
					c.lit(x, 8, Pal.SOUL[2])
		tomb[k] = c
	var s1 := Sheet.new(32, 18, Vector2i(16, 9))
	for k: String in tomb:
		s1.add(k, [tomb[k]], 1.0)
	s1.save(dir, "inlay_tomb")
	# the worn way down the middle of a burial hall
	var aisle := {}
	for k: String in ["whole", "broken"]:
		var c := Px.new(48, 16)
		var x := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(k)
		while x < 48:
			var w := rng.randi_range(9, 14)
			_slab(c, x, 1, mini(w, 48 - x) - 1, 14, Pal.STONE, 2)
			if k == "broken" and x > 12 and x < 30:
				c.line(x + 2, 2, x + w - 3, 13, Pal.INK)
			x += w
		c.rect(0, 0, 48, 1, Pal.STONE[0])
		c.rect(0, 15, 48, 1, Pal.STONE[0])
		aisle[k] = c
	both(dir, "inlay_aisle", aisle)
	# the court's torn runner, its gold thread gone dull
	var carpet := {}
	for k: String in ["whole", "torn"]:
		var c := Px.new(48, 32)
		for y in range(1, 31):
			for x in 48:
				var v: int = 2 if (y + x / 6) % 7 != 0 else 1
				c.put(x, y, Pal.BLOOD[v - 1])
		for x in 48:
			c.put(x, 1, Pal.GOLD[2])
			c.put(x, 2, Pal.GOLD[1])
			c.put(x, 29, Pal.GOLD[1])
			c.put(x, 30, Pal.GOLD[2])
		for x in range(6, 48, 12):
			var m := c.mask().ellipse(float(x), 16.0, 3.0, 3.0)
			c.fill(m, Pal.GOLD[1])
			c.put(x, 16, Pal.GOLD[3])
		if k == "torn":
			for y in 32:
				var edge := 30 + int(6.0 * sin(float(y) * 0.8)) + int(3.0 * sin(float(y) * 2.1))
				for x in range(edge, 48):
					c.put(x, y, Pal.CLEAR)
					c.img.set_pixel(x, y, Pal.CLEAR)
		carpet[k] = c
	both(dir, "inlay_carpet", carpet)
	# the sun, set in the floor of every great room of the court: it has cracked with it
	var sun := Px.new(64, 64)
	var ctr := Vector2(31.5, 31.5)
	for y in 64:
		for x in 64:
			var d := Vector2(x, y).distance_to(ctr)
			var a := atan2(float(y) - ctr.y, float(x) - ctr.x)
			if d < 29.5 and d > 12.0:
				var ray := fposmod(a * 12.0 / TAU, 1.0) < 0.5
				var col: Color = Pal.OBSIDIAN[3] if ray else Pal.OBSIDIAN[2]
				if d > 27.0:
					col = Pal.GOLD[1]
				elif ray and d < 25.0:
					col = Pal.GOLD[1] if int(d) % 3 == 0 else Pal.OBSIDIAN[3]
				sun.put(x, y, col)
			elif d <= 12.0:
				sun.put(x, y, Pal.GOLD[2] if d > 10.0 else Pal.OBSIDIAN[1])
	# the crack that runs through it, with a little fire left in it
	var cx := 12
	var cy := 6
	var crng := RandomNumberGenerator.new()
	crng.seed = 77
	while cy < 60:
		sun.put(cx, cy, Pal.INK)
		sun.put(cx + 1, cy, Pal.INK)
		if cy % 3 == 0:
			sun.lit(cx, cy, Pal.EMBER[2])
		cx += crng.randi_range(0, 2)
		cy += 1
	var s2 := Sheet.new(64, 64, Vector2i(32, 32))
	s2.add("idle", [sun], 1.0)
	s2.save(dir, "inlay_sun")
	# thresholds: where a way begins and ends
	var sill := {}
	for k: String in ["ossuary", "throne", "rootmire", "hollow"]:
		var c := Px.new(64, 16)
		match k:
			"ossuary":
				for x in range(0, 64, 16):
					_slab(c, x, 2, 15, 12, Pal.STONE, 3)
				c.rect(0, 1, 64, 1, Pal.STONE[0])
				c.rect(0, 14, 64, 1, Pal.STONE[0])
			"throne":
				for x in 64:
					c.put(x, 2, Pal.GOLD[2])
					c.put(x, 13, Pal.GOLD[1])
				for x in range(0, 64, 8):
					_slab(c, x, 3, 8, 10, Pal.OBSIDIAN, 3)
			"rootmire":
				var m := c.mask()
				for x in 64:
					var t := 5 + int(2.0 * sin(float(x) * 0.33))
					m.rect(x, t, 1, 6)
				c.paint(m, Pal.WOOD, 2, true)
			"hollow":
				for x in range(0, 64, 11):
					_slab(c, x, 3 + (x / 11) % 3, 9, 9, Pal.GLOAM, 1)
					c.lit(x + 4, 7 + (x / 11) % 3, Pal.SOUL[3])
		sill[k] = c
	both(dir, "inlay_sill", sill)
	# rifts and road marks for the Hollow
	var road := Px.new(48, 16)
	for x in range(0, 48, 8):
		_slab(road, x, 1 + (x / 8) % 2, 7, 13, Pal.EARTH, 2)
	var mark := Px.new(48, 16)
	mark.blit(road, 0, 0)
	for k in 3:
		mark.lit(10 + k * 12, 8, Pal.GOLD[2])
	both(dir, "inlay_road", {"whole": road, "marked": mark})
	var ring := Px.new(48, 48)
	for y in 48:
		for x in 48:
			var d := Vector2(x, y).distance_to(Vector2(23.5, 23.5))
			if d < 22.0 and d > 19.0:
				ring.put(x, y, Pal.STONE[1])
			elif d < 18.0 and d > 16.8 and int(atan2(y - 23.5, x - 23.5) * 12.0) % 2 == 0:
				ring.lit(x, y, Pal.SOUL[2])
	var s3 := Sheet.new(48, 48, Vector2i(24, 24))
	s3.add("idle", [ring], 1.0)
	s3.save(dir, "inlay_ring")


# --- the Ossuary -----------------------------------------------------------------------

static func _ossuary(dir: String) -> void:
	# a raised tomb with its effigy on the lid, panels down the side, stubs of candle at the feet
	var t := Px.new(36, 30)
	t.paint(t.mask().rect(2, 16, 32, 13), Pal.STONE, 2, true)
	for x in range(5, 32, 6):
		t.rect(x, 18, 4, 9, Pal.STONE[1])
		t.rect(x, 18, 4, 1, Pal.STONE[0])
		t.put(x + 1, 22, Pal.BONE[1])
	t.paint(t.mask().rect(0, 11, 36, 6), Pal.STONE, 3, true)
	# the figure, lying with hands crossed
	t.paint(t.mask().ellipse(19.0, 10.0, 11.0, 3.0), Pal.BONE, 1, true)
	t.paint(t.mask().ellipse(6.5, 9.5, 3.0, 2.8), Pal.BONE, 2, true)
	t.line(16, 9, 22, 11, Pal.BONE[0])
	t.line(22, 9, 16, 11, Pal.BONE[0])
	t.put(5, 9, Pal.INK)
	t.put(7, 9, Pal.INK)
	t.rect(32, 8, 2, 4, Pal.BONE[3])
	t.lit(32, 7, Pal.SOUL[4])
	t.lit(33, 6, Pal.SOUL[3])
	t.outline(Pal.INK)
	single(dir, "tomb_effigy", t, Vector2i(18, 28))
	# skulls in rows behind a stone kerb, the long bones laid crosswise between them
	var b := Px.new(36, 38)
	b.paint(b.mask().rect(1, 4, 34, 28), Pal.STONE, 1, true)
	b.rect(3, 6, 30, 24, Pal.INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for row in 5:
		var y := 7 + row * 5
		if row % 2 == 1:
			for x in range(3, 33):
				var col: Color = Pal.BONE[2] if (x + row) % 7 > 1 else Pal.BONE[0]
				b.put(x, y + 1, col)
				b.put(x, y + 2, Pal.BONE[1] if (x + row) % 7 > 1 else Pal.INK)
		else:
			for x in range(5, 33, 6):
				var dx := rng.randi_range(-1, 0)
				b.paint(b.mask().ellipse(float(x + dx), float(y) + 1.5, 2.3, 2.2), Pal.BONE, 2 + rng.randi_range(0, 1))
				b.put(x + dx - 1, y + 2, Pal.INK)
				b.put(x + dx + 1, y + 2, Pal.INK)
				b.put(x + dx, y + 3, Pal.BONE[0])
	# the kerb and cap
	b.paint(b.mask().rect(0, 31, 36, 6), Pal.STONE, 3, true)
	b.paint(b.mask().rect(0, 1, 36, 4), Pal.STONE, 3, true)
	b.lit(18, 2, Pal.SOUL[3])
	b.outline(Pal.INK)
	single(dir, "charnel_bank", b, Vector2i(18, 36))
	# a monument, snapped: the names on it are still there
	var o := Px.new(20, 48)
	o.paint(o.mask().poly(V([[4, 44], [16, 44], [14, 14], [12, 8], [10, 13], [6, 10]])), Pal.STONE, 3, true)
	o.paint(o.mask().rect(1, 41, 18, 6), Pal.STONE, 2, true)
	for y in range(18, 40, 4):
		o.line(7, y, 13, y, Pal.STONE[1])
	o.line(9, 13, 11, 30, Pal.INK)
	o.lit(10, 22, Pal.SOUL[3])
	o.outline(Pal.INK)
	single(dir, "broken_obelisk", o, Vector2i(10, 46))
	# a cairn of what fell from the ceiling, a skull on the top
	var ca := Px.new(30, 26)
	var m := ca.mask().ellipse(15.0, 18.0, 13.0, 7.5)
	ca.paint(m, Pal.STONE, 2, true)
	for k in 9:
		var x := rng.randi_range(5, 24)
		var y := rng.randi_range(13, 22)
		ca.paint(ca.mask().ellipse(float(x), float(y), 2.6, 1.9), Pal.STONE, 3, true)
	ca.paint(ca.mask().ellipse(15.0, 9.0, 3.2, 3.0), Pal.BONE, 2, true)
	ca.put(14, 9, Pal.INK)
	ca.put(16, 9, Pal.INK)
	ca.outline(Pal.INK)
	single(dir, "bone_cairn", ca, Vector2i(15, 25))


# --- the Sunken Throne --------------------------------------------------------------------

static func _throne(dir: String) -> void:
	var o := Pal.OBSIDIAN
	# the head of a colossus, on its side where it fell
	var h := Px.new(56, 44)
	h.paint(h.mask().ellipse(28.0, 24.0, 25.0, 18.0), o, 3, true)
	h.paint(h.mask().rect(2, 36, 52, 7), o, 2, true)
	# the brow, a shut eye, a nose, a split lip
	h.line(14, 20, 40, 18, o[1])
	h.line(14, 21, 40, 19, o[5] if o.size() > 5 else o[4])
	h.paint(h.mask().ellipse(21.0, 25.0, 6.0, 2.2), o, 2)
	h.paint(h.mask().ellipse(37.0, 24.0, 6.0, 2.2), o, 2)
	h.line(16, 25, 26, 25, o[0])
	h.line(32, 24, 42, 24, o[0])
	h.paint(h.mask().poly(V([[27, 25], [32, 25], [33, 31], [27, 31]])), o, 4)
	h.line(20, 35, 40, 34, o[0])
	# a crown, broken, gold still in it
	for k in 6:
		var x := 8 + k * 8
		var tall := 8 - absi(k - 3)
		h.paint(h.mask().poly(V([[x, 12], [x + 6, 12], [x + 3, 12 - tall]])), Pal.GOLD, 2, true)
	h.line(40, 6, 46, 40, Pal.INK)
	for y in range(14, 36, 5):
		h.lit(41 + (y - 14) / 5, y, Pal.EMBER[3])
	h.outline(Pal.INK)
	single(dir, "colossus_head", h, Vector2i(28, 42))
	# what is left of the statue: a foot on its plinth
	var f := Px.new(36, 36)
	f.paint(f.mask().rect(0, 26, 36, 9), o, 2, true)
	f.rect(0, 27, 36, 1, Pal.GOLD[2])
	f.paint(f.mask().poly(V([[6, 27], [30, 27], [30, 20], [20, 20], [19, 6], [9, 3], [7, 6]])), o, 4, true)
	for x in [24, 27]:
		f.line(x, 21, x, 26, o[1])
	f.line(9, 3, 19, 6, o[5] if o.size() > 5 else o[4])
	f.lit(14, 16, Pal.EMBER[3])
	f.lit(15, 18, Pal.EMBER[2])
	f.outline(Pal.INK)
	single(dir, "colossus_foot", f, Vector2i(18, 34))
	# the seat itself, split down the middle, on three steps nobody climbs now
	var t := Px.new(56, 64)
	for k in 3:
		var w := 54 - k * 10
		t.paint(t.mask().rect(28 - w / 2, 55 - k * 5, w, 6), o, 3 - k % 2, true)
		t.rect(28 - w / 2, 55 - k * 5, w, 1, Pal.GOLD[2 - k % 2])
	t.paint(t.mask().poly(V([[14, 44], [26, 44], [26, 6], [22, 2], [14, 12]])), o, 4, true)
	t.paint(t.mask().poly(V([[29, 44], [42, 44], [42, 14], [36, 8], [31, 18]])), o, 3, true)
	t.paint(t.mask().rect(12, 34, 32, 8), o, 2, true)
	t.rect(12, 34, 32, 1, Pal.GOLD[3])
	for k: Array in [[18, 8], [38, 16]]:
		t.paint(t.mask().ellipse(float(k[0]), float(k[1]) + 6.0, 3.0, 3.0), Pal.GOLD, 2, true)
		t.lit(int(k[0]), int(k[1]) + 6, Pal.EMBER[4])
	for y in range(6, 44):
		t.put(27, y, Pal.INK)
		t.put(28, y, Pal.INK)
		if y % 5 == 0:
			t.lit(28, y, Pal.EMBER[3])
	t.outline(Pal.INK)
	single(dir, "broken_throne", t, Vector2i(28, 62))
	# the machine that raised the court's gates: a drum, a chain going up into the dark
	var w2 := Px.new(36, 46)
	w2.paint(w2.mask().rect(2, 34, 32, 11), o, 2, true)
	w2.paint(w2.mask().rect(4, 18, 5, 18), Pal.STEEL, 1, true)
	w2.paint(w2.mask().rect(27, 18, 5, 18), Pal.STEEL, 1, true)
	w2.paint(w2.mask().ellipse(18.0, 24.0, 11.0, 7.0), Pal.STEEL, 2, true)
	for x in range(9, 28, 3):
		w2.line(x, 18, x, 30, Pal.STEEL[0])
	for y in range(0, 18, 3):
		w2.paint(w2.mask().ellipse(18.0, float(y) + 1.0, 1.6, 2.0), Pal.STEEL, 3)
	w2.lit(6, 40, Pal.EMBER[3])
	w2.lit(30, 40, Pal.EMBER[3])
	w2.outline(Pal.INK)
	single(dir, "chain_winch", w2, Vector2i(18, 44))
	# a rib of the vault and everything it brought down with it
	var v := Px.new(36, 32)
	v.paint(v.mask().ellipse(18.0, 24.0, 17.0, 7.0), o, 2, true)
	v.paint(v.mask().poly(V([[5, 26], [10, 26], [18, 6], [24, 3], [26, 6], [16, 26]])), o, 4, true)
	for p: Array in [[10, 24], [20, 26], [28, 23], [14, 28], [24, 28]]:
		v.paint(v.mask().ellipse(float(p[0]), float(p[1]), 3.2, 2.0), o, 3, true)
	v.line(22, 5, 12, 25, Pal.GOLD[1])
	v.outline(Pal.INK)
	single(dir, "fallen_vault", v, Vector2i(18, 31))


# --- the Hollow Below: a set of standing things for each of its moods ------------------

static func _hollow(dir: String) -> void:
	var g := Pal.GLOAM
	# The Whispering Halls: stones with mouths, turned toward whoever passes
	var e := Px.new(20, 40)
	e.paint(e.mask().ellipse(10.0, 19.0, 7.5, 18.0), Pal.STONE, 2, true)
	e.paint(e.mask().rect(2, 34, 16, 5), Pal.STONE, 1, true)
	e.paint(e.mask().ellipse(10.0, 19.0, 3.4, 5.0), Pal.BONE, 0)
	e.fill(e.mask().ellipse(10.0, 19.5, 2.0, 3.6), Pal.INK)
	e.lit(10, 19, Pal.SOUL[3])
	e.lit(10, 21, Pal.SOUL[2])
	e.outline(Pal.INK)
	single(dir, "hollow_listener", e, Vector2i(10, 38))
	# The Thin Light: black glass, grown up through the floor, a cold edge on it
	var s := Px.new(26, 44)
	var m := s.mask().poly(V([[8, 42], [20, 42], [17, 18], [13, 2], [9, 16]]))
	m.poly(V([[2, 42], [10, 42], [6, 24]]))
	m.poly(V([[17, 42], [25, 42], [21, 28]]))
	s.fill(m, Pal.OBSIDIAN[1])
	s.line(13, 3, 12, 40, Pal.FROST[3])
	s.line(6, 25, 5, 41, Pal.FROST[2])
	s.line(21, 29, 22, 41, Pal.FROST[2])
	s.lit(13, 6, Pal.FROST[4])
	s.lit(13, 12, Pal.FROST[4])
	s.outline(Pal.INK)
	single(dir, "hollow_glass", s, Vector2i(13, 43))
	# The Crowded Dark: something very large died here, and things have moved in
	var r := Px.new(38, 44)
	for k in 5:
		var x := 4 + k * 7
		var top := 6 + absi(k - 2) * 5
		r.paint(r.mask().poly(V([[x, 42], [x + 4, 42], [x + 6, top + 8], [x + 3, top], [x + 1, top + 8]])), Pal.BONE, 2, true)
	r.paint(r.mask().rect(0, 38, 38, 5), Pal.BONE, 0, true)
	r.outline(Pal.INK)
	single(dir, "hollow_ribs", r, Vector2i(19, 43))
	# The Old Roads: a mile mark for a road that goes nowhere anyone remembers
	var ms := Px.new(18, 30)
	ms.paint(ms.mask().poly(V([[3, 28], [15, 28], [14, 6], [9, 2], [4, 6]])), Pal.EARTH, 2, true)
	for k in 3:
		ms.lit(9, 10 + k * 5, Pal.GOLD[3])
	ms.outline(Pal.INK)
	single(dir, "hollow_milestone", ms, Vector2i(9, 29))
	# ...and a stair that climbs into the ceiling and stops
	var st := Px.new(36, 42)
	for k in 7:
		st.paint(st.mask().rect(2 + k * 2, 36 - k * 5, 32 - k * 4, 6), Pal.EARTH, 2 + k % 2, true)
	st.outline(Pal.INK)
	single(dir, "hollow_stair", st, Vector2i(18, 41))
	# The Toothed Galleries: a jaw, standing on end
	var j := Px.new(36, 42)
	j.paint(j.mask().poly(V([[2, 40], [10, 40], [12, 12], [26, 12], [28, 40], [34, 40], [32, 4], [4, 4]])), Pal.BONE, 1, true)
	for x in range(13, 26, 3):
		j.paint(j.mask().poly(V([[x, 13], [x + 3, 13], [x + 1, 20]])), Pal.BONE, 3)
	for y in range(16, 38, 5):
		j.paint(j.mask().poly(V([[11, y], [11, y + 3], [16, y + 1]])), Pal.BONE, 3)
		j.paint(j.mask().poly(V([[27, y], [27, y + 3], [22, y + 1]])), Pal.BONE, 3)
	j.outline(Pal.INK)
	single(dir, "hollow_jaw", j, Vector2i(18, 41))
	# The Overgrown Dark: a pale thing like a tree that has only heard of them
	var f := Px.new(30, 46)
	f.paint(f.mask().poly(V([[11, 44], [19, 44], [17, 22], [13, 22]])), g, 2, true)
	f.paint(f.mask().ellipse(15.0, 16.0, 13.0, 9.0), g, 3, true)
	for k in 7:
		var x := 5 + k * 3
		f.line(x, 20, x, 24 + (k * 5) % 7, g[4])
	f.lit(9, 13, Pal.SOUL[4])
	f.lit(20, 11, Pal.SOUL[4])
	f.lit(15, 18, Pal.SOUL[3])
	f.outline(Pal.INK)
	single(dir, "hollow_pale_cap", f, Vector2i(15, 45))
	# a rift-stone: rare, and every mood of the deep has one
	var rs := Px.new(22, 50)
	var rm := rs.mask().poly(V([[4, 48], [18, 48], [20, 26], [16, 6], [11, 1], [5, 10], [2, 28]]))
	rs.paint(rm, g, 1, true)
	for y in range(6, 46):
		var x := 11 + int(3.0 * sin(float(y) * 0.45))
		rs.lit(x, y, Pal.SOUL[3 + y % 2])
		rs.put(x + 1, y, Pal.INK)
	rs.outline(Pal.INK)
	single(dir, "hollow_riftstone", rs, Vector2i(11, 49))


# --- places people worked and lived ---------------------------------------------------------

static func _settlements(dir: String) -> void:
	var s := Sheet.new(36, 38, Vector2i(18, 34))
	s.add("anvil", [_bench("anvil")], 1.0)
	s.add("kiln", [_bench("kiln")], 1.0)
	s.add("lathe", [_bench("lathe")], 1.0)
	s.save(dir, "workbench")
	# a house made of what was to hand, its door a shield
	var h := Px.new(36, 34)
	h.paint(h.mask().rect(3, 15, 30, 18), Pal.WOOD, 1, true)
	h.paint(h.mask().poly(V([[0, 16], [18, 2], [36, 16]])), Pal.EARTH, 1, true)
	for x in range(4, 33, 5):
		h.line(x, 16, x, 32, Pal.WOOD[0])
	h.paint(h.mask().ellipse(18.0, 25.0, 5.0, 7.5), Pal.STEEL, 1, true)
	h.fill(h.mask().ellipse(18.0, 25.0, 2.0, 3.5), Pal.INK)
	h.line(5, 8, 13, 5, Pal.EARTH[3])
	h.outline(Pal.INK)
	single(dir, "settlers_hut", h, Vector2i(18, 33))


static func _bench(kind: String) -> Px:
	var c := Px.new(36, 38)
	match kind:
		"anvil":
			c.paint(c.mask().rect(12, 26, 12, 11), Pal.WOOD, 1, true)
			c.paint(c.mask().poly(V([[6, 16], [30, 16], [27, 22], [22, 22], [22, 27], [14, 27], [14, 22], [10, 22]])), Pal.STEEL, 2, true)
			c.line(7, 16, 29, 16, Pal.STEEL[4])
			c.paint(c.mask().poly(V([[12, 15], [24, 15], [20, 12], [14, 12]])), Pal.EMBER, 1, true)
			c.lit(18, 13, Pal.EMBER[3])
		"kiln":
			c.paint(c.mask().ellipse(18.0, 22.0, 13.0, 14.0), Pal.EARTH, 2, true)
			c.paint(c.mask().rect(4, 32, 28, 5), Pal.STONE, 2, true)
			c.fill(c.mask().ellipse(18.0, 26.0, 6.0, 5.0), Pal.INK)
			for k in 7:
				c.lit(13 + k * 2, 28 + (k % 2), Pal.ramp(Pal.EMBER, 2 + k % 3))
			c.paint(c.mask().rect(15, 2, 6, 9), Pal.EARTH, 1, true)
		"lathe":
			c.paint(c.mask().rect(3, 20, 30, 4), Pal.WOOD, 3, true)
			c.paint(c.mask().rect(5, 24, 3, 13), Pal.WOOD, 1, true)
			c.paint(c.mask().rect(28, 24, 3, 13), Pal.WOOD, 1, true)
			c.paint(c.mask().poly(V([[8, 19], [26, 16], [28, 19], [10, 21]])), Pal.BONE, 3, true)
			c.line(11, 19, 24, 17, Pal.FROST[2])
			c.line(13, 20, 20, 19, Pal.FROST[2])
	c.outline(Pal.INK)
	return c


# --- what stands either side of a way through a wall -------------------------------------

static func _jambs(dir: String) -> void:
	var s := Sheet.new(18, 56, Vector2i(9, 54))
	s.add("ossuary", [_jamb(Pal.STONE, "skull")], 1.0)
	s.add("throne", [_jamb(Pal.OBSIDIAN, "gold")], 1.0)
	s.add("rootmire", [_jamb(Pal.WOOD, "root")], 1.0)
	s.add("hollow", [_jamb(Pal.GLOAM, "rift")], 1.0)
	s.save(dir, "door_jamb")


static func _jamb(r: Array, kind: String) -> Px:
	var c := Px.new(18, 56)
	c.paint(c.mask().rect(3, 8, 12, 46), r, 2, true)
	c.paint(c.mask().rect(1, 46, 16, 8), r, 3, true)
	c.paint(c.mask().rect(1, 3, 16, 6), r, 3, true)
	for y in range(12, 46, 8):
		c.line(4, y, 13, y, r[1])
	match kind:
		"skull":
			c.paint(c.mask().ellipse(9.0, 15.0, 3.4, 3.2), Pal.BONE, 2, true)
			c.put(8, 15, Pal.INK)
			c.put(10, 15, Pal.INK)
		"gold":
			c.rect(1, 3, 16, 1, Pal.GOLD[4])
			c.rect(1, 7, 16, 1, Pal.GOLD[2])
			c.rect(1, 46, 16, 1, Pal.GOLD[3])
			c.rect(3, 22, 12, 2, Pal.GOLD[2])
			c.lit(9, 14, Pal.EMBER[4])
			c.lit(9, 15, Pal.EMBER[3])
		"root":
			for y in range(8, 50, 5):
				c.line(3, y, 14, y + 3, Pal.MOSS[2])
		"rift":
			for y in range(10, 44):
				c.lit(9 + int(2.0 * sin(float(y) * 0.6)), y, Pal.SOUL[3])
	c.outline(Pal.INK)
	return c
