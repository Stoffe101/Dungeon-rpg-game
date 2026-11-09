## Foes that change what you have to look at: the Penitent, stone while a lantern is turned
## on it; the Canopy Mother, under whose parasol nothing can be hurt from outside; the
## Slagbearer, who pours the floor out from under you; and the Warden's harvested souls.
## All face right.
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
	_mote(dir)
	_penitent(dir)
	_mother(dir)
	_slagbearer(dir)


static func _mote(dir: String) -> void:
	var s := Sheet.new(18, 22, Vector2i(9, 20))
	var idle: Array = []
	for i in 4:
		var c := Px.new(18, 22)
		var sw: int = [0, 1, 0, -1][i]
		var m := c.mask().ellipse(9.0, 13.0, 4.5, 5.5)
		m.poly(V([[5 + sw, 12], [13 + sw, 12], [9 + sw * 2, 2 + (i % 2)]]))
		c.paint(m, Pal.SOUL, 3, true)
		c.fill(c.mask().ellipse(9.0, 13.5, 2.2, 2.8), Pal.SOUL[5] if Pal.SOUL.size() > 5 else Pal.SOUL[4])
		c.lit(8, 13, Pal.INK)
		c.lit(10, 13, Pal.INK)
		for y in 22:
			for x in 18:
				if m.has(x, y) and c.get_c(x, y) != Pal.INK:
					c.lit(x, y, c.get_c(x, y))
		c.outline(Pal.INK)
		idle.append(c)
	s.add("idle", idle, 7.0)
	s.save(dir, "soul_mote")


# --- the Penitent: a kneeling thing of stone, its hands over its eyes ---------------------

static func _penitent(dir: String) -> void:
	var s := Sheet.new(44, 44, Vector2i(22, 42))
	s.add("idle", [_pen({"stone": true})], 1.0)
	s.add("stone", [_pen({"stone": true})], 1.0)
	var walk: Array = []
	for i in 6:
		walk.append(_pen({"bob": i % 2, "step": sin(i / 6.0 * TAU), "lean": 2, "eyes": true}))
	s.add("walk", walk, 13.0)
	s.add("windup", [_pen({"lean": -2, "reach": -3, "eyes": true}), _pen({"lean": -3, "reach": -4, "eyes": true, "bob": 1})], 7.0, false)
	s.add("strike", [_pen({"lean": 4, "reach": 8, "eyes": true})], 8.0, false)
	s.save(dir, "penitent")


static func _pen(p: Dictionary) -> Px:
	var c := Px.new(44, 44)
	var r: Array = Pal.STONE
	var stone: bool = p.get("stone", false)
	var b: int = p.get("bob", 0)
	var ln: int = p.get("lean", 0)
	var st: float = p.get("step", 0.0)
	var reach: int = p.get("reach", 0)
	var base := 3 if stone else 2
	# robe to the floor
	c.paint(c.mask().poly(V([[15 + ln, 14 + b], [28 + ln, 14 + b], [32 + int(st * 2), 42], [11 - int(st * 2), 42]])), r, base, true)
	for y in range(20, 42, 5):
		c.line(14 + ln / 2, y, 30 + ln / 2, y + 1, r[base - 1])
	# the head, bowed, hood worn smooth
	c.paint(c.mask().ellipse(22.0 + ln, 10.0 + b, 7.0, 7.5), r, base + 1, true)
	if stone:
		# hands over the eyes
		c.paint(c.mask().rect(21, 8, 9, 5), r, base + 1, true)
		c.line(22, 9, 29, 9, r[1])
		c.line(22, 11, 29, 11, r[1])
	else:
		c.fill(c.mask().ellipse(26.0 + ln, 11.0 + b, 4.0, 3.0), Pal.INK)
		c.lit(25 + ln, 11 + b, Pal.SOUL[4])
		c.lit(28 + ln, 11 + b, Pal.SOUL[4])
		# the arms come down: long, too long
		var m := c.mask()
		m.line(25 + ln, 18 + b, 33 + ln + reach, 26 + b)
		m.line(26 + ln, 18 + b, 34 + ln + reach, 26 + b)
		m.line(25 + ln, 19 + b, 33 + ln + reach, 27 + b)
		c.paint(m, r, 3)
		c.line(34 + ln + reach, 26 + b, 38 + ln + reach, 28 + b, r[4])
		# cold in the cracks: this is how you can tell it is awake
		for k in 6:
			c.lit(19 + k * 2 + (k % 2), 22 + (k * 3) % 18, Pal.SOUL[2 + k % 2])
	c.outline(Pal.INK)
	return c


# --- the Canopy Mother: a stalk of a thing under a parasol of pale gills ------------------

static func _mother(dir: String) -> void:
	var s := Sheet.new(64, 62, Vector2i(32, 60))
	var idle: Array = []
	for i in 4:
		idle.append(_moth({"sway": [0, 1, 1, 0][i], "glow": i % 2}))
	s.add("idle", idle, 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(_moth({"sway": i % 2, "foot": i}))
	s.add("walk", walk, 6.0)
	s.add("windup", [_moth({"sway": -1, "glow": 1, "wide": 1})], 4.0, false)
	s.add("spit", [_moth({"sway": 2, "glow": 1, "wide": 2})], 6.0, false)
	s.save(dir, "canopy_mother")


static func _moth(p: Dictionary) -> Px:
	var c := Px.new(64, 62)
	var sw: int = p.get("sway", 0)
	var wide: int = p.get("wide", 0)
	var foot: int = p.get("foot", 0)
	# skirt of root-feet
	for k in 5:
		var x := 22 + k * 5
		var dy := (foot + k) % 2
		c.paint(c.mask().poly(V([[x, 48], [x + 4, 48], [x + 2, 60 - dy]])), Pal.WOOD, 2, true)
	c.paint(c.mask().poly(V([[24, 28], [40, 28], [44 + sw, 54], [20 + sw, 54]])), Pal.MOSS, 2, true)
	# a pale face low on the stalk
	c.paint(c.mask().ellipse(33.0 + sw, 38.0, 6.0, 5.5), Pal.BONE, 2, true)
	c.put(31 + sw, 38, Pal.INK)
	c.put(36 + sw, 38, Pal.INK)
	c.line(31 + sw, 41, 36 + sw, 41, Pal.BONE[0])
	# the parasol
	var cap := c.mask().ellipse(32.0 + sw, 18.0, 26.0 + wide, 14.0)
	cap.rect(0, 22, 64, 40, false)
	c.paint(cap, Pal.MOSS, 3, true)
	for x in range(10, 56, 4):
		c.line(x + sw, 22, x + sw + (x - 32) / 8, 27, Pal.BONE[2])
	for k: Array in [[20, 12], [34, 7], [46, 13], [27, 17], [41, 18]]:
		c.fill(c.mask().ellipse(float(k[0]) + sw, float(k[1]), 2.4, 1.7), Pal.BONE[3])
	if p.get("glow", 0) == 1:
		for x in range(14, 52, 6):
			c.lit(x + sw, 24, Pal.MOSS[5] if Pal.MOSS.size() > 5 else Pal.MOSS[4])
	c.outline(Pal.INK)
	return c


# --- the Slagbearer: a yoke, two buckets of what the court's furnaces still make -----------

static func _slagbearer(dir: String) -> void:
	var s := Sheet.new(56, 40, Vector2i(28, 38))
	var idle: Array = []
	for i in 4:
		idle.append(_slag({"bob": [0, 1, 1, 0][i], "fire": i}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 6:
		walk.append(_slag({"bob": i % 2, "step": sin(i / 6.0 * TAU), "fire": i}))
	s.add("walk", walk, 8.0)
	s.add("windup", [_slag({"tip": 2, "fire": 1}), _slag({"tip": 4, "fire": 2})], 5.0, false)
	s.add("pour", [_slag({"tip": 8, "fire": 3}), _slag({"tip": 9, "fire": 4})], 8.0, true)
	s.save(dir, "slagbearer")


static func _slag(p: Dictionary) -> Px:
	var c := Px.new(56, 40)
	var r: Array = Pal.ASH
	var b: int = p.get("bob", 0)
	var st: float = p.get("step", 0.0)
	var tip: int = p.get("tip", 0)
	var fire: int = p.get("fire", 0)
	# legs
	c.paint(c.mask().rect(21 + int(st * 2), 30, 5, 9), r, 1, true)
	c.paint(c.mask().rect(30 - int(st * 2), 30, 5, 9), r, 1, true)
	# hunched body
	c.paint(c.mask().ellipse(28.0, 21.0 + b, 11.0, 11.0), r, 2, true)
	c.paint(c.mask().ellipse(35.0, 13.0 + b, 5.0, 4.6), Pal.OBSIDIAN, 3, true)
	c.lit(37, 13 + b, Pal.EMBER[4])
	# the yoke, tipping forward as it pours
	c.line(8, 12 + b + tip / 2, 48, 12 + b - tip / 2, Pal.WOOD[3])
	c.line(8, 13 + b + tip / 2, 48, 13 + b - tip / 2, Pal.WOOD[1])
	for sd: Array in [[8, tip / 2], [48, -tip / 2]]:
		var x: int = sd[0]
		var y: int = 16 + b + int(sd[1])
		c.line(x, 13 + b + int(sd[1]), x, y, Pal.STEEL[2])
		c.paint(c.mask().poly(V([[x - 6, y], [x + 6, y], [x + 4, y + 11], [x - 4, y + 11]])), Pal.STEEL, 1, true)
		for k in 9:
			c.lit(x - 4 + k, y, Pal.ramp(Pal.EMBER, 3 + (k + fire) % 3))
			c.lit(x - 3 + (k * 2) % 7, y - 1 - (k + fire) % 2, Pal.EMBER[3])
	if tip >= 8:
		for k in 5:
			c.lit(50 + (k % 2), 28 + k * 2, Pal.ramp(Pal.EMBER, 2 + k % 3))
	c.outline(Pal.INK)
	return c
