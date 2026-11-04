## Projectiles of the weapon forms (ItemDB "form"): molten sparks (Emberforge
## Mallet), thrown shivs (Ember Shivs), frost shards and their splinters
## (Rimewood Staff), the ice spear (Long Rimebow), the written glyph (Codex of
## Echoes) and the scattered embers (Splitbranch Staff). Every one points right
## (the projectile turns it to its flight). Job "forms" in build_art.gd.
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
	_spark(dir)
	_shiv(dir)
	_shard(dir)
	_splinter(dir)
	_icespear(dir)
	_glyph(dir)
	_bomblet(dir)


## A drop of molten metal with a short glowing tail.
static func _spark(dir: String) -> void:
	var s := Sheet.new(7, 5, Vector2i(3, 2))
	var fr: Array = []
	for i in 2:
		var c := Px.new(7, 5)
		c.lit(0 + i, 2, Pal.EMBER[2])
		c.lit(2, 2, Pal.EMBER[3])
		c.fill_lit(c.mask().ellipse(4.5, 2.5, 1.8, 1.5), Pal.EMBER[4])
		c.lit(4, 2, Pal.WHITE if i == 0 else Pal.GOLD[4])
		fr.append(c)
	s.add("idle", fr, 16.0)
	s.save(dir, "proj_spark")


## A small throwing knife, its edge still glowing from the forge.
static func _shiv(dir: String) -> void:
	var s := Sheet.new(10, 5, Vector2i(5, 2))
	var fr: Array = []
	for i in 2:
		var c := Px.new(10, 5)
		# a wrapped grip
		c.paint(c.mask().rect(0, 2, 3, 1), Pal.WOOD, 2)
		c.put(1, 2, Pal.BLOOD[2])
		c.put(3, 1, Pal.STEEL[1])
		c.put(3, 3, Pal.STEEL[1])
		# the blade
		c.paint(c.mask().poly(V([[3, 1.5], [8, 1.8], [9.8, 2.5], [8, 3.2], [3, 3.5]])), Pal.STEEL, 3)
		c.lit(5 + i, 2, Pal.EMBER[4])
		c.lit(8, 2, Pal.EMBER[3])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 12.0)
	s.save(dir, "proj_shiv")


## A shard of frost: a long crystal, bright at its point.
static func _shard(dir: String) -> void:
	var s := Sheet.new(10, 6, Vector2i(5, 3))
	var fr: Array = []
	for i in 2:
		var c := Px.new(10, 6)
		c.lit(0, 3, Pal.FROST[1])
		c.lit(1 + i, 2 + i, Pal.FROST[2])
		c.fill_lit(c.mask().poly(V([[2, 3], [5, 1.2], [9.8, 3], [5, 4.8]])), Pal.FROST[3])
		c.lit(5, 2, Pal.FROST[5])
		c.lit(6, 3, Pal.FROST[4])
		c.lit(8, 3, Pal.WHITE)
		fr.append(c)
	s.add("idle", fr, 10.0)
	s.save(dir, "proj_shard")


static func _splinter(dir: String) -> void:
	var s := Sheet.new(5, 3, Vector2i(2, 1))
	var c := Px.new(5, 3)
	c.lit(0, 1, Pal.FROST[2])
	c.lit(1, 1, Pal.FROST[3])
	c.lit(2, 1, Pal.FROST[4])
	c.lit(3, 1, Pal.FROST[5])
	c.lit(4, 1, Pal.WHITE)
	c.lit(2, 0, Pal.FROST[2])
	s.add("idle", [c], 1.0)
	s.save(dir, "proj_splinter")


## The Long Rimebow's Steady Shot: a spear of clear ice with frost streaming off.
static func _icespear(dir: String) -> void:
	var s := Sheet.new(20, 7, Vector2i(10, 3))
	var fr: Array = []
	for i in 3:
		var c := Px.new(20, 7)
		# streaming frost behind
		for k in 4:
			c.lit(k * 2 + (i + k) % 2, 3 + ((k + i) % 3) - 1, Pal.FROST[1 + k % 2])
		# the shaft and the head
		c.fill_lit(c.mask().rect(6, 2, 9, 3), Pal.FROST[3])
		c.fill_lit(c.mask().poly(V([[14, 0.8], [19.8, 3.5], [14, 6.2], [15.5, 3.5]])), Pal.FROST[4])
		c.lit(16, 3, Pal.WHITE)
		c.lit(18, 3, Pal.WHITE)
		c.lit(8 + i * 2, 3, Pal.FROST[5])
		c.lit(7, 2, Pal.FROST[5])
		fr.append(c)
	s.add("idle", fr, 14.0)
	s.save(dir, "proj_icespear")


## A written glyph of hearth-script, turning slowly.
static func _glyph(dir: String) -> void:
	var s := Sheet.new(11, 11, Vector2i(5, 5))
	var fr: Array = []
	for i in 4:
		var c := Px.new(11, 11)
		var a := i * PI / 8.0
		# the ring
		for k in 16:
			var d := Vector2.from_angle(k * TAU / 16.0 + a)
			c.lit(int(5.5 + d.x * 4.4), int(5.5 + d.y * 4.4), Pal.SOUL[3] if k % 4 else Pal.SOUL[5])
		# the word in it: three strokes that turn with it
		for k in 3:
			var d2 := Vector2.from_angle(k * TAU / 3.0 - a * 2.0)
			c.lit(int(5.5 + d2.x * 2.2), int(5.5 + d2.y * 2.2), Pal.GOLD[4])
			c.lit(int(5.5 + d2.x * 1.1), int(5.5 + d2.y * 1.1), Pal.SOUL[4])
		c.lit(5, 5, Pal.WHITE)
		fr.append(c)
	s.add("idle", fr, 8.0)
	s.save(dir, "proj_glyph")


## A scattered ember from the Splitbranch's fireball: a little coal, glowing.
static func _bomblet(dir: String) -> void:
	var s := Sheet.new(6, 6, Vector2i(3, 3))
	var fr: Array = []
	for i in 2:
		var c := Px.new(6, 6)
		c.paint(c.mask().ellipse(3.0, 3.0, 2.4, 2.4), Pal.OBSIDIAN, 2, true)
		c.lit(2 + i, 2, Pal.EMBER[4])
		c.lit(3, 3 + i, Pal.EMBER[3])
		c.lit(2, 3, Pal.EMBER[2])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 10.0)
	s.save(dir, "proj_bomblet")
