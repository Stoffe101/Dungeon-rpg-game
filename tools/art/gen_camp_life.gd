## Things in the sanctuary that change as the Kindled does: trophies of fallen
## bosses, a weapon rack that fills as weapons are forged, lanterns lit for
## feats, a stand for the wardrobe's look, and the camp cat.
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


static func build(dir: String) -> void:
	_rugs(dir)
	_trophies(dir)
	_rack(dir)
	_hang_lantern(dir)
	_stand(dir)
	_cat(dir)


# --- woven rugs, laid flat by the fire and the tent ------------------------------

static func _rugs(dir: String) -> void:
	var s := Sheet.new(44, 28, Vector2i(22, 14))
	for v in 2:
		var c := Px.new(44, 28)
		var base: Array = Pal.BLOOD if v == 0 else Pal.CLOAK
		var trim: Array = Pal.GOLD if v == 0 else Pal.BONE
		for y in 28:
			for x in 44:
				var edge := x < 3 or x > 40 or y < 3 or y > 24
				var col: Color = Pal.ramp(trim, 2) if edge else Pal.ramp(base, 1 + ((x + y * 2) / 2) % 2)
				# a woven diamond down the middle and a row of stripes
				var dx := absi(x - 22)
				var dy := absi(y - 14)
				if not edge and dx + dy * 2 < 14 and dx + dy * 2 > 9:
					col = Pal.ramp(trim, 3)
				elif not edge and dx + dy * 2 <= 5:
					col = Pal.ramp(trim, 1)
				elif not edge and (y == 6 or y == 21) and x % 3 != 0:
					col = Pal.ramp(trim, 2)
				if Px.hash01(x, y, 40 + v) > 0.93:
					col = col.darkened(0.15)
				c.put(x, y, col)
		# frayed fringe
		for y in range(3, 25, 2):
			c.put(0, y, Color(0, 0, 0, 0))
			c.put(43, y, Color(0, 0, 0, 0))
		s.add("rug%d" % v, [c], 1.0)
	s.save(dir, "rug")


# --- trophies -----------------------------------------------------------------

static func _plinth(c: Px, w: int) -> void:
	var x0 := (c.w - w) / 2
	c.paint(c.mask().rect(x0, c.h - 6, w, 6), Pal.STONE, 3, true)
	c.paint(c.mask().rect(x0 - 1, c.h - 7, w + 2, 2), Pal.STONE, 4)


static func _trophies(dir: String) -> void:
	# the Gloam Warden's horned helm on a pike, its visor still faintly lit
	var a := Px.new(18, 30)
	_plinth(a, 10)
	a.paint(a.mask().rect(8, 10, 2, 14), Pal.WOOD, 2)
	var helm := a.mask().ellipse(9.0, 8.0, 4.5, 5.0)
	helm.rect(5, 8, 9, 4)
	a.paint(helm, Pal.STEEL, 1, true)
	a.paint(a.mask().poly(V([[5, 6], [1, 2], [1, 0], [3, 3], [7, 5]])), Pal.BONE, 2)
	a.paint(a.mask().poly(V([[13, 6], [17, 2], [17, 0], [15, 3], [11, 5]])), Pal.BONE, 3)
	for x in range(7, 12):
		a.put(x, 9, Pal.INK)
	a.lit(8, 9, Pal.SOUL[3])
	a.lit(10, 9, Pal.SOUL[3])
	a.outline(Pal.INK)
	single(dir, "trophy_warden", a, Vector2i(9, 29))
	# a dried bloom of the Hollow Bloom in a cracked urn, glowing at the heart
	var b := Px.new(18, 30)
	_plinth(b, 10)
	b.paint(b.mask().ellipse(9.0, 20.0, 4.0, 3.5), Pal.EARTH, 2, true)
	b.line(9, 17, 9, 10, Pal.MOSS[2])
	for k in 6:
		var ang := k * TAU / 6.0
		var p := Vector2(9, 7) + Vector2(cos(ang), sin(ang)) * 3.5
		b.paint(b.mask().ellipse(p.x, p.y, 2.2, 1.6), Pal.BLOOD, 2)
	b.fill_lit(b.mask().ellipse(9.0, 7.0, 1.8, 1.8), Pal.GOLD[4])
	b.outline(Pal.INK)
	single(dir, "trophy_bloom", b, Vector2i(9, 29))
	# the Ashen King's crown on a cushion, a small black sun behind it
	var k2 := Px.new(18, 30)
	_plinth(k2, 12)
	var cor := k2.mask().ellipse(9.0, 10.0, 6.5, 6.5)
	cor.subtract(k2.mask().ellipse(9.0, 10.0, 5.0, 5.0))
	k2.fill_lit(cor, Pal.GOLD[3])
	k2.fill(k2.mask().ellipse(9.0, 10.0, 5.0, 5.0), Pal.INK)
	k2.paint(k2.mask().ellipse(9.0, 21.0, 5.0, 2.5), Pal.BLOOD, 2, true)
	var crown := k2.mask().rect(5, 16, 9, 3)
	for i in 4:
		crown.poly(V([[5 + i * 2.5, 16], [6 + i * 2.5, 12 + (i % 2)], [7.5 + i * 2.5, 16]]))
	k2.paint(crown, Pal.GOLD, 2, true)
	k2.lit(9, 17, Pal.EMBER[4])
	k2.outline(Pal.INK)
	single(dir, "trophy_king", k2, Vector2i(9, 29))


# --- the weapon rack, one frame per number of weapons forged ----------------

static func _rack(dir: String) -> void:
	var s := Sheet.new(32, 24, Vector2i(16, 22))
	for n in range(0, 6):
		var c := Px.new(32, 24)
		c.paint(c.mask().rect(2, 4, 28, 2), Pal.WOOD, 3)
		c.paint(c.mask().rect(2, 16, 28, 2), Pal.WOOD, 2)
		c.paint(c.mask().rect(3, 4, 2, 19), Pal.WOOD, 2)
		c.paint(c.mask().rect(27, 4, 2, 19), Pal.WOOD, 2)
		# sword, hammer, staff, fangs, glaive - in the order they are usually forged
		var slots := [7, 11, 15, 19, 23]
		for i in mini(n, 5):
			var x: int = slots[i]
			match i:
				0:
					c.paint(c.mask().rect(x, 2, 2, 18), Pal.STEEL, 4)
					c.paint(c.mask().rect(x - 1, 15, 4, 1), Pal.GOLD, 3)
				1:
					c.paint(c.mask().rect(x, 6, 2, 16), Pal.WOOD, 2)
					c.paint(c.mask().rect(x - 2, 3, 6, 5), Pal.STEEL, 2)
				2:
					c.paint(c.mask().rect(x, 2, 2, 20), Pal.WOOD, 3)
					c.lit(x, 1, Pal.EMBER[4])
					c.lit(x + 1, 2, Pal.EMBER[3])
				3:
					c.paint(c.mask().rect(x, 7, 1, 9), Pal.STEEL, 4)
					c.paint(c.mask().rect(x + 2, 8, 1, 8), Pal.STEEL, 4)
					c.put(x, 16, Pal.GOLD[3])
					c.put(x + 2, 16, Pal.GOLD[3])
					c.lit(x, 8, Pal.GLOAM[4])
				4:
					c.paint(c.mask().rect(x, 4, 1, 19), Pal.WOOD, 2)
					c.paint(c.mask().poly(V([[x - 1, 4], [x + 0.5, 0], [x + 2, 4]])), Pal.STEEL, 4)
					c.lit(x, 1, Pal.EMBER[4])
		c.outline(Pal.INK)
		s.add("n%d" % n, [c], 1.0)
	s.save(dir, "rack_display")


# --- a hanging lantern, lit for a feat ----------------------------------------

static func _hang_lantern(dir: String) -> void:
	var s := Sheet.new(10, 22, Vector2i(5, 21))
	var unlit := Px.new(10, 22)
	_lantern(unlit, false, 0)
	s.add("unlit", [unlit], 1.0)
	var lit: Array = []
	for i in 2:
		var c := Px.new(10, 22)
		_lantern(c, true, i)
		lit.append(c)
	s.add("lit", lit, 3.0)
	s.save(dir, "hang_lantern")


static func _lantern(c: Px, on: bool, ph: int) -> void:
	# a hook post with a lantern hanging from it
	c.paint(c.mask().rect(4, 4, 2, 18), Pal.WOOD, 2)
	c.paint(c.mask().rect(4, 3, 5, 1), Pal.WOOD, 3)
	c.put(8, 4, Pal.STEEL[3])
	var body := c.mask().rect(6, 6, 4, 5)
	c.paint(body, Pal.STEEL, 1)
	if on:
		c.fill_lit(c.mask().rect(7, 7, 2, 3), Pal.EMBER[3 + ph])
	else:
		c.fill(c.mask().rect(7, 7, 2, 3), Pal.INK)
	c.put(7, 5, Pal.STEEL[3])
	c.outline(Pal.INK)


# --- the wardrobe stand: a base for the mannequin -------------------------------

static func _stand(dir: String) -> void:
	var c := Px.new(20, 8)
	c.paint(c.mask().ellipse(10.0, 4.5, 8.5, 3.0), Pal.WOOD, 2, true)
	c.paint(c.mask().rect(9, 0, 2, 4), Pal.WOOD, 3)
	c.put(5, 4, Pal.GOLD[3])
	c.put(15, 4, Pal.GOLD[3])
	c.outline(Pal.INK)
	single(dir, "stand_base", c, Vector2i(10, 6))


# --- the camp cat ------------------------------------------------------------------

static func _cat(dir: String) -> void:
	var s := Sheet.new(16, 12, Vector2i(8, 11))
	s.add("idle", [_cat_frame({}), _cat_frame({"tail": 1}), _cat_frame({"tail": 2}), _cat_frame({"tail": 1})], 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(_cat_frame({"walk": i}))
	s.add("walk", walk, 8.0)
	s.add("sleep", [_cat_frame({"sleep": true}), _cat_frame({"sleep": true, "breath": 1})], 1.2)
	s.save(dir, "cat")


static func _cat_frame(p: Dictionary) -> Px:
	var c := Px.new(16, 12)
	var fur := [Pal.INK, Pal.VOID, Pal.STONE[1], Pal.STONE[2], Pal.STONE[3]]
	if p.get("sleep", false):
		var b := int(p.get("breath", 0))
		c.paint(c.mask().ellipse(8.0, 8.5 - b * 0.3, 5.5, 2.8 + b * 0.3), fur, 2, true)
		c.paint(c.mask().ellipse(12.0, 8.5, 2.6, 2.2), fur, 3, true)
		c.line(3, 10, 7, 10, fur[3])
		c.put(12, 6, fur[4])
		c.put(13, 6, fur[4])
		c.put(12, 8, Pal.INK)
		c.put(13, 8, Pal.INK)
		c.outline(Pal.INK)
		return c
	var w := int(p.get("walk", -1))
	var t := int(p.get("tail", 0))
	# legs
	for i in 4:
		var lx: int = [4, 6, 9, 11][i]
		var off := 0
		if w >= 0:
			off = [1, -1, -1, 1][(i + w) % 4]
		c.line(lx, 8, lx + off, 10, fur[2])
	# body and head
	c.paint(c.mask().ellipse(7.5, 7.0, 4.5, 2.3), fur, 2, true)
	c.paint(c.mask().ellipse(12.0, 5.0, 2.4, 2.2), fur, 3, true)
	c.put(11, 2, fur[3])
	c.put(13, 2, fur[3])
	c.put(11, 3, fur[2])
	c.put(13, 3, fur[2])
	c.lit(12, 5, Pal.GOLD[4])
	c.lit(13, 5, Pal.GOLD[4])
	# tail
	var tip: Array = [[1, 3], [0, 5], [1, 6]][t]
	c.line(3, 7, tip[0], tip[1], fur[2])
	c.outline(Pal.INK)
	return c
