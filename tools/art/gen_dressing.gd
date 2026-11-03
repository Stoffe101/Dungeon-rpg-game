## Set dressing that gives each region its silhouette: sarcophagi and bone heaps
## in the Ossuary, a hollow stump in the Rootmire, broken statues of the court
## and fallen columns in the Sunken Throne. Static props placed against walls.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func single(dir: String, name: String, c: Px, origin: Vector2i) -> void:
	var s := Sheet.new(c.w, c.h, origin)
	s.add("idle", [c], 1.0)
	s.save(dir, name)


static func build(dir: String) -> void:
	_sarcophagus(dir)
	_bone_heap(dir)
	_stump(dir)
	_statue(dir)
	_column(dir)


static func _sarcophagus(dir: String) -> void:
	var c := Px.new(30, 22)
	# the stone box, its lid carved with a resting figure
	c.paint(c.mask().rect(2, 9, 26, 12), Pal.STONE, 2, true)
	c.paint(c.mask().rect(1, 5, 28, 6), Pal.STONE, 3, true)
	c.paint(c.mask().ellipse(15.0, 7.0, 10.0, 2.2), Pal.STONE, 4)
	c.paint(c.mask().ellipse(6.5, 7.0, 2.0, 1.6), Pal.STONE, 4)
	c.line(9, 6, 22, 6, Pal.STONE[2])
	for x in range(4, 27, 5):
		c.line(x, 12, x, 19, Pal.STONE[1])
	# a crack, soul-light seeping out of it
	c.line(18, 9, 21, 14, Pal.INK)
	c.lit(19, 11, Pal.SOUL[3])
	c.lit(20, 12, Pal.SOUL[4])
	c.outline(Pal.INK)
	single(dir, "sarcophagus", c, Vector2i(15, 20))


static func _bone_heap(dir: String) -> void:
	var c := Px.new(24, 16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	c.paint(c.mask().ellipse(12.0, 11.0, 10.0, 4.5), Pal.BONE, 1)
	for k in 14:
		var x := rng.randi_range(4, 18)
		var y := rng.randi_range(6, 13)
		var l := rng.randi_range(3, 6)
		c.line(x, y, x + l, y + rng.randi_range(-2, 2), Pal.BONE[rng.randi_range(2, 3)])
	for sx in [8, 15]:
		c.paint(c.mask().ellipse(sx, 7.0, 2.6, 2.2), Pal.BONE, 3)
		c.put(sx - 1, 7, Pal.INK)
		c.put(sx + 1, 7, Pal.INK)
	c.outline(Pal.INK)
	single(dir, "bone_heap", c, Vector2i(12, 14))


static func _stump(dir: String) -> void:
	var c := Px.new(26, 24)
	c.paint(c.mask().poly(PackedVector2Array([Vector2(5, 22), Vector2(6, 8), Vector2(20, 8), Vector2(21, 22)])), Pal.WOOD, 2, true)
	c.paint(c.mask().ellipse(13.0, 8.0, 7.5, 2.5), Pal.WOOD, 3)
	c.fill(c.mask().ellipse(13.0, 8.0, 5.0, 1.5), Pal.INK)
	for x in [8, 12, 17]:
		c.line(x, 10, x - 1, 21, Pal.WOOD[1])
	# roots and moss, a few glowing caps on the bark
	c.line(5, 21, 1, 23, Pal.WOOD[2])
	c.line(21, 21, 25, 23, Pal.WOOD[2])
	c.paint(c.mask().ellipse(9.0, 19.0, 4.0, 2.0), Pal.MOSS, 3)
	for p in [Vector2i(19, 13), Vector2i(21, 15), Vector2i(7, 12)]:
		c.lit(p.x, p.y, Pal.SOUL[4])
		c.put(p.x, p.y + 1, Pal.BONE[2])
	c.outline(Pal.INK)
	single(dir, "stump", c, Vector2i(13, 22))


static func _statue(dir: String) -> void:
	var c := Px.new(22, 44)
	# plinth
	c.paint(c.mask().rect(3, 36, 16, 8), Pal.OBSIDIAN, 3, true)
	c.line(3, 37, 18, 37, Pal.GOLD[2])
	# a robed courtier, kneeling to a sun that is gone; the head broke off
	c.paint(c.mask().poly(PackedVector2Array([Vector2(6, 36), Vector2(7, 16), Vector2(15, 16), Vector2(17, 36)])), Pal.ASH, 3, true)
	c.paint(c.mask().ellipse(11.0, 15.0, 5.5, 3.0), Pal.ASH, 3, true)
	for y in range(20, 35, 3):
		c.line(8, y, 15, y + 1, Pal.ASH[2])
	# arms raised, holding up a gilded sun disc
	c.line(7, 16, 4, 6, Pal.ASH[3])
	c.line(15, 16, 18, 6, Pal.ASH[3])
	var disc := c.mask().ellipse(11.0, 5.0, 6.5, 4.5)
	disc.subtract(c.mask().ellipse(11.0, 5.0, 4.5, 2.8))
	c.paint(disc, Pal.GOLD, 2)
	c.lit(8, 2, Pal.GOLD[4])
	# the broken neck and a crack down the body
	c.paint(c.mask().rect(9, 11, 4, 2), Pal.ASH, 1)
	c.line(13, 18, 11, 30, Pal.INK)
	c.outline(Pal.INK)
	single(dir, "statue", c, Vector2i(11, 42))


static func _column(dir: String) -> void:
	var c := Px.new(34, 16)
	# a fallen column drum and its capital, gold banding chipped
	c.paint(c.mask().rect(3, 5, 22, 9), Pal.OBSIDIAN, 3, true)
	for x in range(5, 24, 4):
		c.line(x, 6, x, 12, Pal.OBSIDIAN[2])
	c.line(3, 5, 24, 5, Pal.GOLD[2])
	c.line(3, 13, 24, 13, Pal.GOLD[1])
	c.paint(c.mask().ellipse(28.0, 9.0, 4.5, 5.5), Pal.OBSIDIAN, 4, true)
	c.paint(c.mask().ellipse(28.0, 9.0, 2.0, 2.8), Pal.OBSIDIAN, 1)
	c.put(26, 4, Pal.GOLD[3])
	for k in 4:
		c.put(2 + k * 2, 14, Pal.OBSIDIAN[2])
	c.outline(Pal.INK)
	single(dir, "column_fallen", c, Vector2i(17, 14))
