## The unique and legendary weapons as themselves in the Kindled's hand: each
## its own silhouette (held at the same grip point as its archetype, so it
## sits in the hand the same way). ItemDB bases name them with "sprite".
## Job "uniques" in build_art.gd.
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


static func grip(c: Px, x0: int, y0: int, x1: int, r: Array) -> void:
	var m := c.mask()
	m.line(x0, y0, x1, y0)
	m.line(x0, y0 + 1, x1, y0 + 1)
	c.paint(m, r, 2, false)


static func build(dir: String) -> void:
	_thousandth(dir)
	_quakeheart(dir)
	_hundred(dir)
	_gloamfang(dir)
	_searing_pike(dir)
	_windreturn(dir)
	_hollow_index(dir)
	_wardenfang(dir)
	_bloomstring(dir)
	_sunfall(dir)


## The Thousandth Cut: a long, slender blade notched along its whole edge,
## every notch a spark of gloam-light; a hooked guard.
static func _thousandth(dir: String) -> void:
	var c := Px.new(26, 9)
	grip(c, 1, 4, 5, Pal.CLOAK)
	c.paint(c.mask().poly(V([[5, 1], [7, 2], [7, 7], [5, 8], [6, 4.5]])), Pal.GOLD, 3)
	c.paint(c.mask().poly(V([[7, 3.5], [23, 3.8], [25.6, 4.5], [23, 5.4], [7, 5.6]])), Pal.STEEL, 4, false)
	for x in range(8, 23, 2):
		c.lit(x, 5, Pal.GLOAM[4])
	for x in range(9, 23, 4):
		c.lit(x, 4, Pal.GLOAM[5])
	c.lit(24, 4, Pal.WHITE)
	c.put(0, 4, Pal.GLOAM[3])
	c.outline(Pal.INK)
	single(dir, "w_thousandth", c, Vector2i(3, 4))


## Quakeheart: a round stone maul-head split by a crack with a beating ember
## heart inside.
static func _quakeheart(dir: String) -> void:
	var c := Px.new(22, 16)
	grip(c, 1, 7, 12, Pal.WOOD)
	c.paint(c.mask().rect(11, 6, 2, 4), Pal.GOLD, 3)
	c.paint(c.mask().ellipse(16.5, 8.0, 5.5, 7.0), Pal.STONE, 3, true)
	c.line(15, 2, 17, 7, Pal.INK)
	c.line(17, 7, 16, 13, Pal.INK)
	c.fill_lit(c.mask().ellipse(16.5, 8.0, 1.6, 2.0), Pal.EMBER[4])
	c.lit(16, 8, Pal.WHITE)
	c.lit(15, 4, Pal.EMBER[3])
	c.lit(17, 11, Pal.EMBER[3])
	c.outline(Pal.INK)
	single(dir, "w_quakeheart", c, Vector2i(3, 7))


## The Wand of a Hundred Embers: a short charred wand with a crown of embers
## floating above its tip.
static func _hundred(dir: String) -> void:
	var c := Px.new(24, 13)
	grip(c, 0, 6, 15, Pal.OBSIDIAN)
	c.paint(c.mask().rect(15, 5, 2, 4), Pal.GOLD, 3)
	c.paint(c.mask().poly(V([[17, 6], [19, 4.5], [20, 6.5], [19, 8.5]])), Pal.OBSIDIAN, 3)
	for p in [[21, 2], [23, 5], [22, 9], [20, 11], [18, 1], [21, 6]]:
		c.lit(p[0], p[1], Pal.EMBER[4])
	for p in [[22, 3], [23, 7], [19, 10], [20, 0]]:
		c.lit(p[0], p[1], Pal.EMBER[3])
	c.lit(21, 6, Pal.WHITE)
	c.outline(Pal.INK)
	single(dir, "w_hundred", c, Vector2i(5, 6))


## Gloamfang: a black hooked fang with a violet edge and an eye in its pommel.
static func _gloamfang(dir: String) -> void:
	var c := Px.new(17, 10)
	grip(c, 1, 4, 4, Pal.CLOAK)
	c.fill_lit(c.mask().ellipse(1.5, 4.5, 1.5, 1.5), Pal.GLOAM[4])
	c.paint(c.mask().rect(4, 3, 1, 4), Pal.STEEL, 2)
	c.paint(c.mask().poly(V([[5, 3], [12, 2.5], [16.5, 0.5], [14, 5], [5, 6.5]])), Pal.OBSIDIAN, 3, false)
	for x in range(6, 14):
		c.lit(x, 3, Pal.GLOAM[4] if x % 2 else Pal.GLOAM[3])
	c.lit(15, 1, Pal.GLOAM[5])
	c.outline(Pal.INK)
	single(dir, "w_gloamfang", c, Vector2i(3, 4))


## Searing Pike: a split head - one prong red-hot, one rimed with frost.
static func _searing_pike(dir: String) -> void:
	var c := Px.new(36, 11)
	grip(c, 0, 5, 25, Pal.WOOD)
	c.paint(c.mask().rect(25, 4, 2, 4), Pal.STEEL, 3)
	c.paint(c.mask().poly(V([[27, 4], [31, 1], [35.5, 1.5], [31, 4.5]])), Pal.STEEL, 3, false)
	c.paint(c.mask().poly(V([[27, 7], [31, 6.5], [35.5, 9.5], [31, 10]])), Pal.STEEL, 3, false)
	for x in range(28, 35):
		c.lit(x, 2 + (x - 28) / 4, Pal.EMBER[4] if x % 2 else Pal.EMBER[3])
		c.lit(x, 8 + (x - 28) / 4, Pal.FROST[4] if x % 2 else Pal.FROST[3])
	c.outline(Pal.INK)
	single(dir, "w_searing_pike", c, Vector2i(10, 5))


## Windreturn: a pale bow whose limbs curl back into wind spirals.
static func _windreturn(dir: String) -> void:
	var c := Px.new(14, 24)
	var limb := c.mask()
	limb.line(4, 12, 6, 7).line(6, 7, 8, 3).line(8, 3, 11, 2)
	limb.line(4, 12, 6, 17).line(6, 17, 8, 21).line(8, 21, 11, 22)
	limb.line(5, 12, 7, 7).line(5, 12, 7, 17)
	c.paint(limb, Pal.BONE, 3, false)
	c.paint(c.mask().rect(3, 10, 3, 5), Pal.MOSS, 2)
	# the spirals
	for p in [[12, 1], [13, 2], [12, 3], [11, 0], [12, 23], [13, 22], [12, 21], [11, 23]]:
		c.lit(p[0], p[1], Pal.SOUL[4])
	for y in range(3, 22):
		c.lit(10, y, Pal.SOUL[3] if y % 3 else Pal.SOUL[5])
	c.outline(Pal.INK)
	single(dir, "w_windreturn", c, Vector2i(4, 12))


## The Index of Hollow Words: a teal-bound book that stays open on an eye.
static func _hollow_index(dir: String) -> void:
	var c := Px.new(15, 13)
	c.paint(c.mask().poly(V([[1, 3], [7, 4], [14, 3], [14, 11], [7, 12], [1, 11]])), Pal.SOUL, 1, true)
	c.paint(c.mask().poly(V([[2, 3], [7, 4], [7, 11], [2, 10]])), Pal.BONE, 3)
	c.paint(c.mask().poly(V([[7, 4], [13, 3], [13, 10], [7, 11]])), Pal.BONE, 4)
	c.fill_lit(c.mask().ellipse(10.0, 7.0, 2.4, 1.6), Pal.SOUL[4])
	c.lit(10, 7, Pal.INK)
	for y in range(5, 10):
		c.put(4 if y % 2 else 3, y, Pal.SOUL[2])
	c.put(0, 12, Pal.STEEL[3])
	c.put(1, 12, Pal.STEEL[2])
	c.outline(Pal.INK)
	single(dir, "w_hollow_index", c, Vector2i(3, 7))


## Wardenfang: one of the Gloam Warden's fangs - jagged bone, soul-light
## burning along its edge.
static func _wardenfang(dir: String) -> void:
	var c := Px.new(18, 10)
	grip(c, 1, 4, 4, Pal.STEEL)
	c.paint(c.mask().poly(V([[4, 2.5], [8, 3], [10, 1.5], [12, 3], [17.6, 2], [14, 6], [10, 5.5], [8, 7], [4, 6.5]])), Pal.BONE, 4, false)
	for x in range(5, 16):
		c.lit(x, 4 + (1 if x % 3 == 0 else 0), Pal.SOUL[4] if x % 2 else Pal.SOUL[5])
	c.lit(17, 2, Pal.WHITE)
	c.outline(Pal.INK)
	single(dir, "w_wardenfang", c, Vector2i(3, 4))


## Bloomstring: a living bow - green wood, thorns, blossoms of the Bloom's red.
static func _bloomstring(dir: String) -> void:
	var c := Px.new(14, 24)
	var limb := c.mask()
	limb.line(4, 12, 6, 7).line(6, 7, 8, 3).line(8, 3, 10, 1)
	limb.line(4, 12, 6, 17).line(6, 17, 8, 21).line(8, 21, 10, 23)
	limb.line(5, 12, 7, 7).line(5, 12, 7, 17)
	c.paint(limb, Pal.MOSS, 2, false)
	c.paint(c.mask().rect(3, 10, 3, 5), Pal.WOOD, 2)
	for p in [[7, 5], [6, 19], [9, 2], [9, 22]]:
		c.fill_lit(c.mask().ellipse(float(p[0]) + 0.5, float(p[1]) + 0.5, 1.3, 1.3), Pal.BLOOD[3])
	for p in [[5, 8], [5, 16], [7, 10]]:
		c.put(p[0], p[1], Pal.BONE[4])
	for y in range(2, 22):
		c.lit(10, y, Pal.BLOOD[3] if y % 2 else Pal.EMBER[3])
	c.outline(Pal.INK)
	single(dir, "w_bloomstring", c, Vector2i(4, 12))


## Sunfall Glaive: a golden glaive with a crescent of the dead sun for a blade.
static func _sunfall(dir: String) -> void:
	var c := Px.new(38, 13)
	grip(c, 0, 6, 25, Pal.OBSIDIAN)
	for x in [4, 10, 16, 22]:
		c.put(x, 6, Pal.GOLD[4])
	c.paint(c.mask().rect(25, 5, 2, 4), Pal.GOLD, 3)
	var blade := c.mask().ellipse(31.0, 6.5, 6.5, 6.0)
	blade.subtract(c.mask().ellipse(28.0, 6.5, 5.0, 5.0))
	c.paint(blade, Pal.GOLD, 3, false)
	for k in 6:
		var a := -1.2 + k * 0.48
		c.lit(int(31.0 + cos(a) * 5.5), int(6.5 + sin(a) * 5.2), Pal.EMBER[4])
	c.lit(37, 6, Pal.WHITE)
	c.outline(Pal.INK)
	single(dir, "w_sunfall", c, Vector2i(10, 6))
