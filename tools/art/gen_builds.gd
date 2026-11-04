## Sprites for the build-defining spells: the Gloam Knife (spectral blade
## projectile) and the Hearth Lantern (a planted post with a lantern of
## hearth-fire). Job "builds" in build_art.gd.
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
	_knife(dir)
	_lantern_totem(dir)


## A thin blade of gloam-light pointing right, with a fading shadow tail.
static func _knife(dir: String) -> void:
	var s := Sheet.new(12, 5, Vector2i(6, 2))
	var fr: Array = []
	for i in 2:
		var c := Px.new(12, 5)
		# the tail: two dim streaks that trade places between frames
		c.lit(0 + i, 2, Pal.GLOAM[2])
		c.lit(2, 1 + i * 2, Pal.GLOAM[1])
		c.lit(3, 2, Pal.GLOAM[3])
		# the blade
		c.fill_lit(c.mask().poly(V([[4, 2.5], [9, 1.2], [11.6, 2.5], [9, 3.8]])), Pal.GLOAM[4])
		c.lit(6, 2, Pal.GLOAM[5])
		c.lit(7, 2, Pal.WHITE if i == 0 else Pal.GLOAM[5])
		c.lit(8, 2, Pal.GLOAM[5])
		c.lit(10, 2, Pal.WHITE)
		# a hilt-spark where it was cut from the lantern's shadow
		c.lit(4, 2, Pal.EMBER[4] if i == 0 else Pal.EMBER[3])
		fr.append(c)
	s.add("idle", fr, 14.0)
	s.save(dir, "proj_knife")


## The Hearth Lantern: an iron-shod stake driven into the floor, a crook at
## the top and a caged lantern hanging from it. Four frames of flicker.
static func _lantern_totem(dir: String) -> void:
	var s := Sheet.new(16, 28, Vector2i(8, 27))
	var fr: Array = []
	for i in 4:
		var c := Px.new(16, 28)
		# footing: three stones around the stake
		c.paint(c.mask().ellipse(5.0, 25.5, 2.4, 1.6), Pal.STONE, 2, true)
		c.paint(c.mask().ellipse(11.0, 25.8, 2.2, 1.5), Pal.STONE, 3, true)
		c.paint(c.mask().ellipse(8.0, 26.4, 2.0, 1.2), Pal.STONE, 1)
		# the stake
		c.paint(c.mask().rect(7, 6, 2, 20), Pal.WOOD, 3)
		c.line(7, 6, 7, 25, Pal.WOOD[2])
		c.paint(c.mask().rect(6, 21, 4, 2), Pal.STEEL, 2)
		c.put(9, 21, Pal.STEEL[4])
		# the crook reaching right
		c.line(8, 5, 12, 5, Pal.STEEL[3])
		c.line(8, 4, 11, 4, Pal.STEEL[2])
		c.put(12, 6, Pal.STEEL[3])
		# the lantern: a small cage with glowing glass
		var sway := 1 if i == 1 else (-1 if i == 3 else 0)
		var lx := 12 + sway
		c.put(lx, 7, Pal.STEEL[3])
		c.paint(c.mask().rect(lx - 2, 8, 5, 1), Pal.STEEL, 3)
		c.paint(c.mask().rect(lx - 2, 15, 5, 1), Pal.STEEL, 2)
		var glass := c.mask().rect(lx - 2, 9, 5, 6)
		c.fill_lit(glass, Pal.EMBER[3])
		var fh := 3 + (i % 2)
		c.fill_lit(c.mask().ellipse(float(lx) + 0.5, 13.0 - fh * 0.4, 1.3, fh * 0.6), Pal.EMBER[4])
		c.lit(lx, 12 - (i % 2), Pal.EMBER[5])
		c.lit(lx, 11 - (i % 2), Pal.WHITE if i == 0 else Pal.EMBER[5])
		# cage bars over the glass
		c.line(lx - 2, 9, lx - 2, 14, Pal.STEEL[2])
		c.line(lx + 2, 9, lx + 2, 14, Pal.STEEL[2])
		# a drifting ember above
		c.lit(lx - 1 + (i % 3), 2 - (i % 2), Pal.EMBER[3] if i % 2 == 0 else Pal.EMBER[2])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 7.0)
	s.save(dir, "lantern_totem")
