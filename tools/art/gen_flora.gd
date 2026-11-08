## The Rootmire's plants, drawn to a rule (docs/DESIGN.md, "What things are made of"):
##   ground cover  thin separate blades, no outline, muted, no taller than a boot: walk through it.
##   solid growth  a mound and woody roots you can see, one dense outlined mass, rigid.
##   thorns        solid until cut: arched canes you can see through, pale cuts of sap on them.
##   trees         a root-flared trunk that is the obstacle, and a canopy that is only overhead.
## A solid thing's drawing fills its tile at the foot: what stops you is what you see.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Sheet = preload("res://tools/art/sheet.gd")
const Pal = preload("res://src/render/pal.gd")


static func build(dir: String) -> void:
	_trophies(dir)
	_ground_cover(dir)
	_thicket(dir)
	_bramble(dir)
	_giantcap(dir)
	_tree(dir)
	_rock(dir)
	_log(dir)


## What the sanctuary hangs on its back wall for each guardian that has fallen.
static func _trophies(dir: String) -> void:
	var s := Sheet.new(18, 22, Vector2i(9, 21))
	for spec in [["warden", Pal.STEEL, Pal.SOUL], ["bloom", Pal.WOOD, Pal.BLOOD], ["king", Pal.OBSIDIAN, Pal.GOLD]]:
		var c := Px.new(18, 22)
		var plate := c.mask().rect(2, 2, 14, 15)
		c.paint(plate, spec[1], 2, true, true)
		c.paint(c.mask().rect(4, 17, 10, 3), spec[1], 1, true, false)
		match String(spec[0]):
			"warden":
				c.fill_lit(c.mask().ellipse(9.0, 9.0, 3.0, 4.0), spec[2][3])
				c.line(6, 5, 12, 13, Pal.INK)
			"bloom":
				for a in 5:
					var v := Vector2.from_angle(float(a) / 5.0 * TAU) * 4.0
					c.fill(c.mask().ellipse(9.0 + v.x, 9.0 + v.y, 2.0, 2.0), spec[2][2])
				c.fill_lit(c.mask().ellipse(9.0, 9.0, 1.6, 1.6), Pal.EMBER[4])
			_:
				for x in [5, 9, 13]:
					c.line(x, 11, x, 5, spec[2][3])
				c.line(4, 12, 14, 12, spec[2][3])
				c.lit(9, 8, Pal.EMBER[4])
		c.outline(Pal.INK)
		s.add(String(spec[0]), [c], 1.0)
	s.save(dir, "guardian_trophy")


# --- ground cover (FloraField draws these) ------------------------------------------

## Rows: grass, sedge, fern, flowers, pin caps, clover. Columns: two of swaying, the
## plant parted by a foot, burnt to stubs.
const LOW_W := 16
const LOW_H := 12
const LOW_KINDS := ["grass", "sedge", "fern", "flowers", "pincaps", "clover"]


static func _ground_cover(dir: String) -> void:
	var s := Sheet.new(LOW_W, LOW_H, Vector2i(8, 11))
	for i in LOW_KINDS.size():
		var fr: Array = []
		for pose in 4:
			fr.append(_low_frame(i, pose))
		s.add(String(LOW_KINDS[i]), fr, 1.5)
	s.save(dir, "flora_low")


static func _low_frame(kind: int, pose: int) -> Px:
	var c := Px.new(LOW_W, LOW_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + kind * 13
	var lean := [0.0, 1.0, 0.0, 0.0][pose] as float
	if pose == 3:
		# burnt to stubs: an ash smear and a few black ends
		for k in 5:
			var x := rng.randi_range(3, 12)
			c.put(x, 11, Pal.ASH[1])
			c.put(x, 10, Pal.INK)
		return c
	var flat := pose == 2
	match kind:
		0:
			_blades(c, rng, 7, 5, 8, lean, flat, [Pal.MOSS[1], Pal.MOSS[2], Pal.MOSS[3]])
		1:
			_blades(c, rng, 4, 8, 10, lean, flat, [Pal.MOSS[1], Pal.MOSS[2], Pal.BONE[1]])
			if not flat:
				c.put(6 + int(lean), 1, Pal.EARTH[3])
		2:
			_fronds(c, lean, flat)
		3:
			_blades(c, rng, 4, 3, 5, lean, flat, [Pal.MOSS[1], Pal.MOSS[2], Pal.MOSS[2]])
			if not flat:
				for p in [Vector2i(4, 6), Vector2i(9, 5), Vector2i(12, 7)]:
					var x: int = p.x + int(lean)
					c.put(x, p.y, Pal.BONE[3])
					c.put(x + 1, p.y, Pal.BONE[2])
					c.put(x, p.y + 1, Pal.GOLD[3])
		4:
			# pin caps: dim points of cold light on hair stems (bright ones read as noise)
			for p in [Vector2i(5, 8), Vector2i(10, 9)]:
				if flat:
					c.put(p.x, 11, Pal.SOUL[1])
					continue
				c.put(p.x, p.y + 1, Pal.BONE[0])
				c.put(p.x, p.y + 2, Pal.BONE[0])
				c.put(p.x, p.y + 3, Pal.BONE[0])
				c.lit(p.x, p.y, Pal.SOUL[1 + (p.x % 2)])
		_:
			# clover: a low broken mat, never a mound
			for k in 11:
				var x := rng.randi_range(2, 13)
				var y := rng.randi_range(9, 11) if not flat else 11
				if (x + y) % 2 == 0:
					c.put(x, y, Pal.MOSS[2] if k % 3 != 0 else Pal.MOSS[3])
	return c


static func _blades(c: Px, rng: RandomNumberGenerator, n: int, lo: int, hi: int, lean: float, flat: bool, ramp: Array) -> void:
	var xs: Array = []
	var slot := 13.0 / float(n)
	for i in n:
		xs.append(int(2.0 + slot * (i + rng.randf())))
	for x0: int in xs:
		var h := rng.randi_range(lo, hi)
		if flat:
			h = mini(h, 2)
		var side := 1.0 if x0 >= 8 else -1.0
		var curve := rng.randf_range(0.5, 1.6) * side
		for y in h:
			var t := float(y) / maxf(1.0, float(h - 1))
			var x := x0 + int(round((curve + lean) * t * t))
			var col: Color = ramp[mini(int(t * 3.0), 2)]
			c.put(x, 11 - y, col)


static func _fronds(c: Px, lean: float, flat: bool) -> void:
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.52
		var reach := 7.0 if not flat else 5.0
		var end := Vector2(8, 11) + Vector2(cos(a) + lean * 0.1, sin(a) * (1.0 if not flat else 0.25)) * reach
		var steps := 7
		for s in steps:
			var t := float(s) / float(steps - 1)
			var p := Vector2(8, 11).lerp(end, t)
			if not flat:
				p.y += t * t * 1.5
			c.put(int(p.x), int(p.y), Pal.MOSS[1 + int(t * 2.0)])
			if s % 2 == 1 and not flat:
				c.put(int(p.x) + 1, int(p.y) + 1, Pal.MOSS[1])


# --- solid growth ---------------------------------------------------------------------

## The foot: a mound of raked earth the plant stands on, as wide as its tile.
static func _mound(c: Px, cx: int, foot_y: int, half: int) -> void:
	for y in 5:
		var inset := int(y * y * 0.45)
		var row := foot_y - 4 + y
		for x in range(cx - half + (4 - y) + 1 - 1, cx + half - (4 - y) + 1):
			if y == 4 or x > cx - half + inset:
				c.put(x, row, Pal.EARTH[1] if y >= 3 else Pal.EARTH[2])


static func _thicket(dir: String) -> void:
	var s := Sheet.new(24, 32, Vector2i(12, 31))
	s.add("a", [_thicket_frame(1, false)], 1.0)
	s.add("b", [_thicket_frame(2, false)], 1.0)
	s.add("c", [_thicket_frame(3, true)], 1.0)
	s.save(dir, "thicket")


static func _thicket_frame(seed_v: int, tall: bool) -> Px:
	var c := Px.new(24, 32)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + seed_v
	var top := 3 if tall else 8
	# the crown: lobes of dark leaf piled on each other, one solid thing
	var crown := c.mask()
	for lobe in [[12.0, top + 7.0, 8.5, 7.5], [6.5, top + 11.0, 5.0, 5.5], [17.5, top + 11.0, 5.0, 5.5], [12.0, top + 14.0, 8.0, 5.0]]:
		crown.ellipse(lobe[0], lobe[1], lobe[2], lobe[3])
	c.paint(crown, Pal.MOSS, 1, true, false)
	# leaf texture in the mass (dark gaps, a few lit clusters on the upper left)
	for y in 32:
		for x in 24:
			if not crown.has(x, y):
				continue
			var n := Px.hash01(x, y, seed_v * 3)
			if n > 0.8:
				c.put(x, y, Pal.MOSS[0])
			elif n < 0.14 and y < top + 11 and x < 15:
				c.put(x, y, Pal.MOSS[3])
	# roots and trunk: woody, gripping the mound, plainly what keeps it standing
	var woody := c.mask()
	woody.poly(PackedVector2Array([Vector2(9, top + 15), Vector2(15, top + 15), Vector2(17, 27), Vector2(7, 27)]))
	c.paint(woody, Pal.WOOD, 1, true, false)
	_mound(c, 12, 31, 9)
	for r in [[9, 22, 4, 30], [12, 22, 12, 30], [15, 22, 20, 30], [10, 25, 6, 30], [14, 25, 18, 30]]:
		c.line(r[0], r[1], r[2], r[3], Pal.WOOD[2])
		c.put(r[2], r[3], Pal.WOOD[3])
	for x in [5, 9, 15, 19]:
		c.put(x, 29, Pal.WOOD[1])
	# stiff thorns breaking the outline: nothing soft about it
	for k in 11:
		var a := rng.randf() * TAU
		var p := Vector2(12.0 + cos(a) * 9.0, top + 11.0 + sin(a) * 9.5)
		if crown.has(int(p.x), int(p.y)):
			c.put(int(p.x), int(p.y), Pal.BONE[2])
	c.outline(Pal.INK)
	return c


static func _bramble(dir: String) -> void:
	var s := Sheet.new(22, 24, Vector2i(11, 23))
	s.add("idle", [_bramble_frame(0, 0), _bramble_frame(1, 0)], 1.6)
	var burn: Array = []
	for i in 4:
		burn.append(_bramble_frame(i % 2, i + 1))
	s.add("burning", burn, 10.0)
	s.add("burnt", [_bramble_frame(0, 9)], 1.0)
	s.save(dir, "bramble")


## Thorns that can be cut: a knot at the foot, canes arching out of it with air
## between them (not a bush: you can see through it), thorn tips, and pale wet cuts
## on the canes where a blade or a flame would get in.
static func _bramble_frame(pulse: int, burn: int) -> Px:
	var c := Px.new(22, 24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	if burn == 9:
		for k in 7:
			var x := 4 + k * 2
			c.line(x, 23, x + rng.randi_range(-1, 1), 19 - rng.randi_range(0, 3), Pal.INK)
		c.rect(3, 22, 16, 2, Pal.ASH[1])
		for k in 4:
			c.lit(5 + k * 4, 22, Pal.EMBER[1])
		return c
	# the arches: each cane goes up from the knot and comes down again
	var arches := [[-7.0, 15.0], [-3.0, 21.0], [3.0, 20.0], [7.5, 14.0], [0.0, 11.0]]
	var canes := c.mask()
	var path: Array = []
	for ar in arches:
		var dx: float = ar[0]
		var h: float = ar[1]
		var steps := 22
		for s in steps:
			var t := float(s) / float(steps - 1)
			var x := 11.0 + dx * sin(t * 1.25) * 1.25
			var y := 22.0 - h * sin(t * PI * 0.72) * 1.04
			canes.set_bit(int(x), int(y))
			canes.set_bit(int(x), int(y) + 1)
			path.append(Vector2i(int(x), int(y)))
	c.paint(canes, Pal.BLOOD, 1, false, true)
	# hooked thorns, sticking out of the canes
	for i in range(3, path.size(), 5):
		var p: Vector2i = path[i]
		var off := Vector2i(1 if i % 2 == 0 else -1, -1)
		c.put(p.x + off.x, p.y + off.y, Pal.BONE[3])
	# the knot and its roots fill the tile at the foot
	var knot := c.mask().ellipse(11.0, 21.5, 7.5, 2.8)
	c.paint(knot, Pal.WOOD, 1, true, true)
	for x in [5, 8, 14, 17]:
		c.put(x, 23, Pal.WOOD[2])
	c.outline(Pal.INK)
	# the cuts: pale, and glowing just enough to find in the dark
	for p in [Vector2i(6, 13), Vector2i(10, 6), Vector2i(15, 8), Vector2i(17, 15)]:
		var col: Color = Pal.EMBER[4 if pulse == 0 else 5]
		c.lit(p.x, p.y, col)
		c.put(p.x + 1, p.y, Pal.BONE[3])
		c.put(p.x, p.y + 1, Pal.BONE[2])
	if burn > 0:
		for k in 10 + burn * 2:
			var x := rng.randi_range(3, 19)
			var y := rng.randi_range(6, 22)
			c.lit(x, y, Pal.EMBER[3 + (k + burn) % 3])
			c.lit(x, y - 1, Pal.EMBER[2])
	return c


## Glowcaps that stop you: thick stems on a root foot, a broad cap above. (The little
## pin caps in the grass are the ones to walk through.)
static func _giantcap(dir: String) -> void:
	var s := Sheet.new(24, 30, Vector2i(12, 29))
	var fr: Array = []
	for i in 4:
		var c := Px.new(24, 30)
		_mound(c, 12, 29, 8)
		var pulse: int = [0, 1, 1, 0][i]
		for cap in [[7, 17, 5.0, 3.2, Pal.SOUL, 3], [14, 8, 8.0, 5.0, Pal.GLOAM, 5], [19, 18, 3.6, 2.4, Pal.SOUL, 3]]:
			var cx: int = cap[0]
			var cy: int = cap[1]
			var w: int = cap[5]
			var stem := c.mask().rect(cx - w / 2, cy, w, 27 - cy)
			c.paint(stem, Pal.BONE, 1, true, true)
			var top := c.mask().ellipse(float(cx), float(cy), cap[2], cap[3])
			top.subtract(c.mask().rect(0, cy + 1, 24, 30))
			var r: Array = cap[4]
			c.fill_lit(top, r[3 + pulse])
			for x in range(int(cx - cap[2]) + 1, int(cx + cap[2])):
				if top.has(x, cy):
					c.lit(x, cy, r[2])
			for x in range(int(cx - cap[2]) + 2, int(cx + cap[2]) - 1):
				c.put(x, cy + 1, r[1])
			c.lit(cx - 2, int(cy - cap[3] + 1), r[5])
			c.lit(cx + 2, cy - 1, r[5 - pulse])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 2.0)
	s.save(dir, "glowcap")


## A dead-tree's living shoot: the trunk (one tile, root-flared) is the obstacle; the
## canopy is a separate sheet hung overhead, which thins when anyone is under it.
static func _tree(dir: String) -> void:
	var t := Px.new(32, 44)
	var trunk := t.mask()
	trunk.poly(PackedVector2Array([Vector2(11, 0), Vector2(21, 0), Vector2(21, 30), Vector2(25, 41), Vector2(7, 41), Vector2(11, 30)]))
	t.paint(trunk, Pal.WOOD, 1, true, false)
	for x in [13, 16, 19]:
		t.line(x, 1, x + (x - 16) / 3, 36, Pal.WOOD[0])
	for x in [14, 20]:
		t.line(x, 3, x, 30, Pal.WOOD[2])
	_mound(t, 16, 43, 12)
	for r in [[11, 34, 3, 43], [13, 36, 9, 43], [16, 36, 16, 43], [19, 36, 23, 43], [21, 34, 29, 43]]:
		t.line(r[0], r[1], r[2], r[3], Pal.WOOD[3])
		t.line(r[0], r[1] + 1, r[2], r[3], Pal.WOOD[1])
	t.paint(t.mask().ellipse(12.0, 18.0, 3.0, 2.0), Pal.MOSS, 2)
	t.lit(20, 12, Pal.SOUL[4])
	t.lit(21, 14, Pal.SOUL[3])
	t.outline(Pal.INK)
	var ts := Sheet.new(32, 44, Vector2i(16, 43))
	ts.add("idle", [t], 1.0)
	ts.save(dir, "mire_trunk")
	var cs := Sheet.new(76, 46, Vector2i(38, 45))
	cs.add("a", [_canopy(21)], 1.0)
	cs.add("b", [_canopy(22)], 1.0)
	cs.save(dir, "mire_canopy")


static func _canopy(seed_v: int) -> Px:
	var c := Px.new(76, 46)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var m := c.mask()
	for i in 13:
		var a := float(i) / 13.0 * TAU
		m.ellipse(38.0 + cos(a) * 24.0 + rng.randf_range(-2.0, 2.0), 22.0 + sin(a) * 12.0 + rng.randf_range(-1.5, 1.5), rng.randf_range(8.0, 11.0), rng.randf_range(6.0, 8.0))
	m.ellipse(38.0, 22.0, 26.0, 15.0)
	c.paint(m, Pal.MOSS, 1, true, false)
	for y in 46:
		for x in 76:
			if not m.has(x, y):
				continue
			var n := Px.vnoise(x * 0.24, y * 0.3, seed_v)
			var f := Px.hash01(x, y, seed_v)
			if n > 0.6 and y < 26:
				c.put(x, y, Pal.MOSS[2] if f > 0.15 else Pal.MOSS[3])
			elif n < 0.38:
				c.put(x, y, Pal.MOSS[0])
	# hanging strands under it, and a few cold lights
	for k in 12:
		var x := rng.randi_range(14, 62)
		var y := 34 + rng.randi_range(-3, 3)
		c.line(x, y, x, y + rng.randi_range(3, 7), Pal.MOSS[1])
	for k in 9:
		var x := rng.randi_range(12, 64)
		var y := rng.randi_range(8, 32)
		if m.has(x, y):
			c.lit(x, y, Pal.SOUL[4] if k % 2 == 0 else Pal.GLOAM[4])
	c.outline(Pal.INK)
	return c


static func _rock(dir: String) -> void:
	var s := Sheet.new(22, 22, Vector2i(11, 21))
	for v in 2:
		var c := Px.new(22, 22)
		var m := c.mask()
		if v == 0:
			m.poly(PackedVector2Array([Vector2(2, 21), Vector2(1, 12), Vector2(6, 5), Vector2(14, 3), Vector2(20, 9), Vector2(21, 21)]))
		else:
			m.poly(PackedVector2Array([Vector2(1, 21), Vector2(3, 10), Vector2(9, 8), Vector2(12, 2), Vector2(18, 7), Vector2(21, 21)]))
		c.paint(m, Pal.STONE, 2, true, true)
		# hard facets (stone has corners), and moss only on its head
		c.line(8, 6 + v, 6, 20, Pal.STONE[1])
		c.line(14, 5, 16, 20, Pal.STONE[1])
		c.line(9, 12, 15, 11, Pal.STONE[3])
		for y in 22:
			for x in 22:
				if m.has(x, y) and y < 8 + Px.vnoise(x * 0.4, 1.0, v) * 5.0:
					c.put(x, y, Pal.MOSS[2] if Px.hash01(x, y, 3) > 0.3 else Pal.MOSS[3])
		c.rect(2, 20, 18, 2, Pal.STONE[0])
		c.outline(Pal.INK)
		s.add("a" if v == 0 else "b", [c], 1.0)
	s.save(dir, "mire_rock")


static func _log(dir: String) -> void:
	var c := Px.new(38, 22)
	var m := c.mask().rect(3, 6, 28, 13)
	c.paint(m, Pal.WOOD, 1, true, true)
	for x in range(5, 30, 5):
		c.line(x, 7, x + 2, 17, Pal.WOOD[0])
	c.paint(c.mask().ellipse(32.0, 12.5, 4.5, 6.5), Pal.WOOD, 3, true)
	c.paint(c.mask().ellipse(32.0, 12.5, 2.4, 3.8), Pal.WOOD, 1)
	c.put(32, 12, Pal.INK)
	for x in range(5, 28):
		if Px.vnoise(x * 0.3, 2.0, 5) > 0.42:
			c.put(x, 6, Pal.MOSS[3])
			c.put(x, 7, Pal.MOSS[2])
	for p in [Vector2i(10, 4), Vector2i(20, 3), Vector2i(23, 4)]:
		c.lit(p.x, p.y, Pal.SOUL[4])
		c.lit(p.x + 1, p.y, Pal.SOUL[3])
		c.put(p.x, p.y + 1, Pal.BONE[2])
		c.put(p.x, p.y + 2, Pal.BONE[1])
	c.rect(2, 19, 32, 2, Pal.EARTH[1])
	for x in [4, 12, 22, 30]:
		c.line(x, 19, x - 2, 21, Pal.WOOD[1])
	c.outline(Pal.INK)
	var s := Sheet.new(38, 22, Vector2i(19, 21))
	s.add("idle", [c], 1.0)
	s.save(dir, "mire_log")
