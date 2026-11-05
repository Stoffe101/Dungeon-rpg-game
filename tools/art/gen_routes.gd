## The Forked Descent's own pieces: the Ash Seal (a chained obelisk with a
## burning rune, warding the foes of a Trial of Ash hall until it is broken)
## and the Vigil Lantern (the Lost Vault's failing flame, kept lit by standing
## in its ring). Job "routes" in build_art.gd.
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
	_seal(dir)
	_vigil(dir)


## A squat black-stone obelisk on a cracked plinth, bound by two chains, an
## ash-red rune burning on its face (it pulses; its crumbling comes from the
## shared hurt/death rows: Sheet.FALL_STYLE "crumble").
static func _seal(dir: String) -> void:
	var s := Sheet.new(20, 30, Vector2i(10, 28))
	var idle: Array = []
	for i in 4:
		idle.append(_seal_frame(i))
	s.add("idle", idle, 5.0)
	s.add("walk", idle, 5.0)
	s.add("spawn", idle, 5.0)
	s.save(dir, "ash_seal")


static func _seal_frame(i: int) -> Px:
	var c := Px.new(20, 30)
	# plinth
	c.paint(c.mask().rect(3, 24, 14, 4), Pal.STONE, 2, true)
	for k in 3:
		c.put(5 + k * 4, 25 + k % 2, Pal.STONE[0])
	# the obelisk, tapering, its point a little chipped
	var ob := c.mask().poly(V([[5, 24], [6, 6], [10, 2], [14, 6], [15, 24]]))
	c.paint(ob, Pal.OBSIDIAN, 2, true)
	c.put(12, 4, Pal.OBSIDIAN[4])
	# two chains wrapped across it
	for cy in [9, 18]:
		for x in range(4, 17):
			var yy: int = cy + (1 if (x / 2) % 2 == 0 else 0)
			c.put(x, yy, Pal.STEEL[2 if x % 2 == 0 else 3])
	# the rune: a burning eye with a bar through it
	var glow: Color = [Pal.EMBER[3], Pal.EMBER[4], Pal.EMBER[5], Pal.EMBER[4]][i]
	for p in [[10, 11], [9, 12], [11, 12], [8, 13], [12, 13], [9, 14], [11, 14], [10, 15]]:
		c.lit(int(p[0]), int(p[1]), glow)
	c.lit(10, 13, Pal.BLOOD[4])
	for y in range(10, 17):
		c.lit(10, y, Pal.EMBER[3] if y != 13 else Pal.EMBER[5])
	# ash rising off it
	c.lit(7 + (i * 3) % 6, 1 + i % 2, Pal.EMBER[2])
	c.outline(Pal.INK)
	return c


## A tall iron lantern on a tripod, its flame in three states: lit (bright),
## low (guttering) and out (cold glass, a wisp of smoke).
static func _vigil(dir: String) -> void:
	var s := Sheet.new(20, 34, Vector2i(10, 32))
	for state in ["lit", "low", "out"]:
		var fr: Array = []
		for i in 4:
			fr.append(_vigil_frame(state, i))
		s.add(state, fr, 6.0 if state != "out" else 2.0)
	s.save(dir, "vigil_lantern")


static func _vigil_frame(state: String, i: int) -> Px:
	var c := Px.new(20, 34)
	# tripod
	for lx in [[3, 32, 8, 22], [17, 32, 12, 22]]:
		c.paint(c.mask().line(lx[0], lx[1], lx[2], lx[3]), Pal.STEEL, 1)
	c.paint(c.mask().rect(9, 20, 2, 12), Pal.STEEL, 2)
	# the cage
	c.paint(c.mask().rect(5, 8, 10, 12), Pal.STEEL, 1, true)
	var glass := c.mask().rect(6, 9, 8, 10)
	c.fill(glass, Color(0.06, 0.06, 0.1) if state == "out" else Pal.GOLD[0])
	c.paint(c.mask().rect(4, 6, 12, 2), Pal.STEEL, 3)
	c.paint(c.mask().rect(8, 3, 4, 3), Pal.STEEL, 2)
	c.put(10, 2, Pal.STEEL[4])
	for x in [7, 10, 12]:
		c.paint(c.mask().rect(x, 9, 1, 10), Pal.STEEL, 1, false, false)
	match state:
		"lit":
			var h := 6 + (i % 3)
			for y in range(18 - h, 18):
				var w := 1 + (y - (18 - h)) / 3
				for x in range(10 - w, 10 + w + 1):
					c.lit(x, y, Pal.EMBER[5] if absi(x - 10) == 0 else Pal.EMBER[4])
			c.lit(10, 17 - h, Pal.GOLD[4])
		"low":
			var h2 := 2 + (i % 2)
			for y in range(18 - h2, 18):
				c.lit(10, y, Pal.EMBER[3])
				if y == 17:
					c.lit(9, y, Pal.EMBER[2])
					c.lit(11, y, Pal.EMBER[2])
		"out":
			c.put(10, 8 - i % 2, Pal.ASH[3])
			c.put(9 + (i % 2), 6 - i % 3, Pal.ASH[2])
	c.outline(Pal.INK)
	return c
