## The Living Undervault's places: the Hollow Altars and what is offered at
## them, a Last Stand's barricade, the Lost Procession's bier, the Pale Bowl, a
## treasury's coffers, the arch over each way down, a Grudge's brand and spoor.
## Job "sites" in build_art.gd.
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
	_altar(dir)
	_offerings(dir)
	_brazier(dir)
	_bowl(dir)
	_coffers(dir)
	_bier(dir)
	_scene(dir)
	_arches(dir)
	_brand(dir)


## A Hollow Altar: a stepped plinth, a great cracked basin, the flame (or what
## was done to it). Unlit; rekindled; broken in two; bound in pale fire.
static func _altar(dir: String) -> void:
	var s := Sheet.new(44, 46, Vector2i(22, 43))
	for st in ["idle", "kindled", "broken", "pact"]:
		var fr: Array = []
		for i in 4:
			var c := Px.new(44, 46)
			c.paint(c.mask().rect(4, 37, 36, 6), Pal.STONE, 2, true)
			c.paint(c.mask().rect(9, 32, 26, 6), Pal.STONE, 3, true)
			c.paint(c.mask().rect(15, 22, 14, 11), Pal.STONE, 2, true)
			for x in [18, 22, 26]:
				c.paint(c.mask().rect(x, 24, 1, 8), Pal.STONE, 1, false, false)
			if st == "broken":
				c.paint(c.mask().poly(V([[8, 22], [20, 18], [19, 12], [10, 13]])), Pal.STONE, 3, true)
				c.paint(c.mask().poly(V([[36, 22], [25, 20], [24, 15], [33, 11]])), Pal.STONE, 2, true)
				c.line(21, 12, 23, 22, Pal.INK)
				c.line(22, 22, 20, 36, Pal.INK)
				for k in 4:
					c.lit(16 + k * 4, 24 - (i + k) % 3 * 4, Pal.BLOOD[3 + (k + i) % 2])
				c.lit(22, 14 + i, Pal.BLOOD[4])
			else:
				c.paint(c.mask().ellipse(22.0, 19.0, 15.0, 5.0), Pal.STONE, 3, true)
				c.paint(c.mask().ellipse(22.0, 17.0, 11.0, 2.6), Pal.STONE, 1, false, false)
				var r: Array = Pal.EMBER if st == "kindled" else Pal.GLOAM
				if st != "idle":
					var h := 11 + (i % 3)
					for k in 3:
						var cx := 17 + k * 5
						var hh: int = h - absi(k - 1) * 3 + ((i + k) % 2)
						c.fill_lit(c.mask().poly(V([[cx - 3, 18], [cx + 3, 18], [cx + 1, 18 - hh / 2], [cx, 18 - hh]])), r[3])
						c.fill_lit(c.mask().poly(V([[cx - 1, 18], [cx + 1, 18], [cx, 18 - hh / 2]])), r[5])
			c.outline(Pal.INK)
			fr.append(c)
		s.add(st, fr, 6.0)
	s.save(dir, "hollow_altar")


## What is offered at an altar: a torch in a cradle, a maul resting on the
## stone, a pale bowl on a stem - each a shape you can tell apart at a glance.
static func _offerings(dir: String) -> void:
	var s := Sheet.new(22, 30, Vector2i(11, 28))
	for st in ["kindled", "broken", "pact", "spent"]:
		var fr: Array = []
		for i in 3:
			var c := Px.new(22, 30)
			c.paint(c.mask().rect(4, 23, 14, 5), Pal.STONE, 2, true)
			c.paint(c.mask().rect(7, 17, 8, 6), Pal.STONE, 3, true)
			match st:
				"kindled":
					c.paint(c.mask().rect(10, 8, 2, 10), Pal.WOOD, 3)
					c.fill_lit(c.mask().poly(V([[7, 9], [15, 9], [12, 4 - i % 2], [10, 1 + i % 2]])), Pal.EMBER[3])
					c.fill_lit(c.mask().poly(V([[9, 9], [13, 9], [11, 4]])), Pal.EMBER[5])
				"broken":
					c.paint(c.mask().rect(10, 5, 2, 12), Pal.WOOD, 2)
					c.paint(c.mask().rect(5, 2, 12, 6), Pal.STEEL, 3, true)
					c.lit(6, 4 + i % 2, Pal.BLOOD[4])
				"pact":
					c.paint(c.mask().rect(10, 11, 2, 6), Pal.STEEL, 2)
					c.paint(c.mask().ellipse(11.0, 10.0, 7.0, 3.0), Pal.ASH, 4, true)
					c.fill_lit(c.mask().ellipse(11.0, 9.0, 5.0, 1.4), Pal.GLOAM[4])
					c.lit(9 + i, 6 - i % 2, Pal.GLOAM[5])
			c.outline(Pal.INK)
			fr.append(c)
		s.add(st, fr, 5.0)
	s.save(dir, "altar_offering")


static func _brazier(dir: String) -> void:
	var s := Sheet.new(22, 26, Vector2i(11, 24))
	for st in ["dead", "lit"]:
		var fr: Array = []
		for i in 3:
			var c := Px.new(22, 26)
			c.paint(c.mask().poly(V([[3, 12], [19, 12], [15, 19], [7, 19]])), Pal.STEEL, 2, true)
			for lx in [[7, 19, 4, 24], [15, 19, 18, 24], [11, 19, 11, 24]]:
				c.paint(c.mask().line(lx[0], lx[1], lx[2], lx[3]), Pal.STEEL, 1)
			for k in 5:
				c.put(6 + k * 2, 11, Pal.ASH[1 + k % 2])
			if st == "lit":
				c.fill_lit(c.mask().poly(V([[5, 12], [17, 12], [13, 5], [11, 1 + i], [8, 5]])), Pal.EMBER[3])
				c.fill_lit(c.mask().poly(V([[8, 12], [14, 12], [11, 5 + i % 2]])), Pal.EMBER[5])
			c.outline(Pal.INK)
			fr.append(c)
		s.add(st, fr, 7.0)
	s.save(dir, "dead_brazier")


static func _bowl(dir: String) -> void:
	var s := Sheet.new(24, 24, Vector2i(12, 22))
	var fr: Array = []
	for i in 4:
		var c := Px.new(24, 24)
		c.paint(c.mask().rect(9, 13, 6, 8), Pal.ASH, 3, true)
		c.paint(c.mask().rect(6, 20, 12, 2), Pal.ASH, 2)
		c.paint(c.mask().ellipse(12.0, 11.0, 10.0, 4.0), Pal.ASH, 4, true)
		c.fill_lit(c.mask().ellipse(12.0, 9.0, 7.5, 1.8), Pal.GLOAM[3 + i % 2])
		c.lit(7 + (i * 3) % 10, 7 - i % 3, Pal.GLOAM[5])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 5.0)
	s.save(dir, "pale_bowl")


static func _coffers(dir: String) -> void:
	var s := Sheet.new(24, 22, Vector2i(12, 20))
	for spec in [["gold", Pal.GOLD, Pal.WOOD], ["bone", Pal.BONE, Pal.ASH], ["glass", Pal.SOUL, Pal.STEEL], ["shut", Pal.ASH, Pal.ASH]]:
		var c := Px.new(24, 22)
		var r: Array = spec[1]
		var r2: Array = spec[2]
		c.paint(c.mask().rect(3, 10, 18, 10), r2, 2, true)
		c.paint(c.mask().poly(V([[2, 11], [22, 11], [20, 4], [4, 4]])), r, 2, true)
		for x in [6, 17]:
			c.paint(c.mask().rect(x, 4, 2, 16), r, 3)
		if spec[0] != "shut":
			c.lit(12, 13, r[mini(4, r.size() - 1)])
			c.put(11, 13, r[1])
			c.put(13, 13, r[1])
		c.outline(Pal.INK)
		s.add(String(spec[0]), [c], 1.0)
	s.save(dir, "coffer")


## The Lost Procession's bier: a covered litter on broken carrying poles.
static func _bier(dir: String) -> void:
	var s := Sheet.new(44, 30, Vector2i(22, 27))
	for st in ["idle", "spent"]:
		var fr: Array = []
		for i in 3:
			var c := Px.new(44, 30)
			c.paint(c.mask().rect(1, 19, 42, 3), Pal.WOOD, 2, true)
			c.paint(c.mask().line(2, 25, 12, 20), Pal.WOOD, 2)
			c.paint(c.mask().line(41, 25, 32, 20), Pal.WOOD, 2)
			c.paint(c.mask().rect(8, 11, 28, 9), Pal.STONE, 2, true)
			if st == "idle":
				c.paint(c.mask().poly(V([[7, 12], [37, 12], [33, 5], [11, 5]])), Pal.GLOAM, 1, true)
				for x in range(10, 35, 4):
					c.put(x, 12, Pal.GOLD[3])
				c.lit(22, 8 + i % 2, Pal.SOUL[4])
			else:
				c.paint(c.mask().poly(V([[24, 12], [42, 16], [38, 9], [26, 7]])), Pal.GLOAM, 1, true)
				c.fill(c.mask().rect(11, 10, 22, 2), Pal.INK)
			c.outline(Pal.INK)
			fr.append(c)
		s.add(st, fr, 3.0)
	s.save(dir, "bier")


## A Last Stand: a barricade of planks and shields, shields on the ground; bones
## of the bearers who put the bier down and never got up.
static func _scene(dir: String) -> void:
	var s := Sheet.new(26, 24, Vector2i(13, 22))
	var c := Px.new(26, 24)
	c.paint(c.mask().poly(V([[1, 21], [7, 6], [10, 7], [6, 22]])), Pal.WOOD, 2, true)
	c.paint(c.mask().poly(V([[24, 21], [18, 5], [15, 6], [20, 22]])), Pal.WOOD, 2, true)
	c.paint(c.mask().rect(4, 12, 19, 3), Pal.WOOD, 3, true)
	c.paint(c.mask().rect(3, 17, 21, 3), Pal.WOOD, 2, true)
	c.paint(c.mask().ellipse(13.0, 13.0, 5.0, 6.0), Pal.STEEL, 2, true)
	c.line(13, 8, 13, 18, Pal.EMBER[1])
	c.line(9, 13, 17, 13, Pal.EMBER[1])
	c.outline(Pal.INK)
	s.add("idle", [c], 1.0)
	s.save(dir, "barricade")
	var b := Sheet.new(18, 12, Vector2i(9, 9))
	var d := Px.new(18, 12)
	d.paint(d.mask().ellipse(9.0, 7.0, 7.0, 3.6), Pal.STEEL, 1, true)
	d.line(4, 7, 14, 7, Pal.EMBER[1])
	d.put(8, 5, Pal.STEEL[3])
	d.outline(Pal.INK)
	b.add("idle", [d], 1.0)
	b.save(dir, "fallen_shield")
	var p := Sheet.new(20, 12, Vector2i(10, 9))
	var e := Px.new(20, 12)
	e.paint(e.mask().rect(3, 6, 12, 2), Pal.BONE, 2)
	for x in [5, 8, 11]:
		e.line(x, 4, x - 1, 9, Pal.BONE[1])
	e.paint(e.mask().ellipse(16.0, 6.0, 2.5, 2.2), Pal.BONE, 2)
	e.put(16, 6, Pal.INK)
	e.outline(Pal.INK)
	p.add("idle", [e], 1.0)
	p.save(dir, "pallbearer_bones")


## The arch over each way down: told apart by its shape before its name.
##   trial  - a jagged iron gate with embers in the bars
##   vault  - a gilded keystone arch
##   quiet  - a low mossy lintel
##   breach - the wall itself torn open, red in the crack
##   lair   - bones and claw-marks, a red ember eye
static func _arches(dir: String) -> void:
	var s := Sheet.new(36, 40, Vector2i(18, 37))
	for st in ["trial", "vault", "quiet", "breach", "lair"]:
		var fr: Array = []
		for i in 3:
			var c := Px.new(36, 40)
			match st:
				"trial":
					for x in [3, 29]:
						c.paint(c.mask().poly(V([[x, 37], [x + 4, 37], [x + 3, 8], [x + 1, 2]])), Pal.OBSIDIAN, 2, true)
					c.paint(c.mask().poly(V([[3, 10], [33, 10], [28, 5], [24, 8], [18, 1], [12, 8], [8, 5]])), Pal.OBSIDIAN, 3, true)
					for k in 4:
						c.lit(8 + k * 7, 6 + (k + i) % 3, Pal.EMBER[3 + (k + i) % 3])
					c.lit(18, 4, Pal.EMBER[5])
				"vault":
					for x in [4, 27]:
						c.paint(c.mask().rect(x, 12, 5, 25), Pal.STONE, 3, true)
						c.paint(c.mask().rect(x - 1, 34, 7, 3), Pal.GOLD, 2)
					var m := c.mask().ellipse(18.0, 14.0, 16.0, 12.0)
					m.subtract(c.mask().ellipse(18.0, 15.0, 10.0, 8.0))
					m.subtract(c.mask().rect(0, 14, 36, 26))
					c.paint(m, Pal.GOLD, 3, true)
					c.paint(c.mask().poly(V([[15, 2], [21, 2], [20, 9], [16, 9]])), Pal.GOLD, 4, true)
					c.lit(18, 5, Pal.GOLD[4])
				"quiet":
					for x in [5, 26]:
						c.paint(c.mask().rect(x, 20, 5, 17), Pal.STONE, 2, true)
					c.paint(c.mask().rect(3, 16, 30, 6), Pal.STONE, 3, true)
					for x in range(4, 33, 3):
						c.paint(c.mask().rect(x, 15, 3, 2 + (x % 4)), Pal.MOSS, 2)
					c.lit(12 + i * 5, 26 + i, Pal.SOUL[4])
				"breach":
					c.paint(c.mask().poly(V([[1, 37], [5, 12], [12, 4], [14, 18], [12, 37]])), Pal.STONE, 2, true)
					c.paint(c.mask().poly(V([[35, 37], [32, 8], [24, 2], [22, 20], [25, 37]])), Pal.STONE, 2, true)
					for k in 5:
						c.lit(13 + k % 2 * 8, 10 + k * 5 + i, Pal.BLOOD[3 + (k + i) % 2])
					c.lit(18, 12 + i * 4, Pal.EMBER[4])
				"lair":
					for k in 5:
						var a := PI + PI * k / 4.0
						var p := Vector2(18, 28) + Vector2.from_angle(a) * Vector2(15, 24)
						c.paint(c.mask().line(int(p.x), int(p.y), int(18 + (p.x - 18) * 0.75), int(28 + (p.y - 28) * 0.75)), Pal.BONE, 2)
						c.paint(c.mask().line(int(p.x) + 1, int(p.y), int(18 + (p.x - 18) * 0.75) + 1, int(28 + (p.y - 28) * 0.75)), Pal.BONE, 2)
					c.lit(18, 7, Pal.BLOOD[4])
					c.lit(17, 7, Pal.BLOOD[3 + i % 2])
					c.lit(19, 7, Pal.BLOOD[3 + i % 2])
			c.outline(Pal.INK)
			fr.append(c)
		s.add(st, fr, 5.0)
	s.save(dir, "route_arch")


## The red brand over a Grudge (one more spike a level), and its spoor.
static func _brand(dir: String) -> void:
	var s := Sheet.new(17, 11, Vector2i(8, 10))
	for lv in range(1, 6):
		var fr: Array = []
		for i in 2:
			var c := Px.new(17, 11)
			for k in lv:
				var x := 8 + (k - (lv - 1) / 2) * 3 - (1 if lv % 2 == 0 else 0)
				var h := 5 + (2 if k == (lv - 1) / 2 else 0)
				for y in h:
					c.lit(x, 9 - y, Pal.BLOOD[4] if y > h - 3 else Pal.BLOOD[3])
					if y < 2:
						c.lit(x + 1, 9 - y, Pal.BLOOD[2])
			c.lit(8, 8, Pal.EMBER[4 + i % 2])
			c.outline(Pal.INK)
			fr.append(c)
		s.add("l%d" % lv, fr, 3.0)
	s.save(dir, "grudge_brand")
	var sp := Sheet.new(24, 14, Vector2i(12, 8))
	for v in 3:
		var c := Px.new(24, 14)
		for k in 3:
			var x0 := 5 + k * 5 + v
			for t in 9:
				c.lit(x0 + t / 3 - v, 2 + t, Pal.BLOOD[2 if t % 3 == 0 else 1])
		sp.add("v%d" % v, [c], 1.0)
	sp.save(dir, "grudge_spoor")
