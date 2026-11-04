## Landmarks: one great centrepiece per region, rare enough to remember -
## the Bone Colossus (a half-buried skull whose eyes still hold soul-light),
## the Heart-Root (a knot of the dead tree's roots around a slow red pulse),
## the Fallen Sun-Disc (the sun-king's cracked emblem, leaning in rubble).
## Job "landmarks" in build_art.gd.
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
	_colossus(dir)
	_heart_root(dir)
	_sun_disc(dir)


static func _colossus(dir: String) -> void:
	var s := Sheet.new(56, 44, Vector2i(28, 42))
	for state in ["idle", "woken"]:
		s.add(state, _colossus_frames(state == "woken"), 3.0 if state == "idle" else 6.0)
	s.save(dir, "landmark_colossus")


static func _colossus_frames(woken: bool) -> Array:
	var fr: Array = []
	for i in 4:
		var c := Px.new(56, 44)
		# rubble it sank into
		for k in 9:
			c.paint(c.mask().ellipse(6.0 + k * 5.5, 39.0 + (k % 3), 4.0 + k % 2, 2.6), Pal.STONE, 2 + k % 2, true)
		# the skull: cranium, brow, cheekbones, a broken jaw half in the floor
		var sk := c.mask().ellipse(28.0, 20.0, 19.0, 16.0)
		sk.poly(V([[14, 26], [42, 26], [38, 38], [18, 38]]))
		c.paint(sk, Pal.BONE, 3, true)
		c.line(14, 14, 42, 14, Pal.BONE[4])
		# a long crack across the crown
		c.line(22, 5, 26, 12, Pal.BONE[1])
		c.line(26, 12, 24, 17, Pal.BONE[1])
		# eye sockets with soul-light breathing in them
		for ex in [20, 36]:
			c.fill(c.mask().ellipse(float(ex), 22.0, 5.0, 4.5), Pal.INK)
			var g := 3 + (i % 2)
			if woken:
				# it remembers: its eyes blaze and soul-light runs down its face
				c.fill_lit(c.mask().ellipse(float(ex), 22.0, 4.0, 3.6), Pal.SOUL[4])
				c.fill_lit(c.mask().ellipse(float(ex), 22.0, 2.0, 1.8), Pal.SOUL[5])
				for ty in range(26, 29 + i % 3):
					c.lit(ex + (1 if ex > 28 else -1), ty, Pal.SOUL[3])
			else:
				c.fill_lit(c.mask().ellipse(float(ex), 22.5, 2.0 + (i % 2) * 0.4, 1.8), Pal.SOUL[g])
				c.lit(ex, 22, Pal.SOUL[5])
		# the nose, the teeth
		c.fill(c.mask().poly(V([[27, 27], [30, 27], [28.5, 31]])), Pal.INK)
		for tx in range(19, 38, 3):
			c.paint(c.mask().rect(tx, 33, 2, 3), Pal.BONE, 4)
		# candles left at its brow
		for cx in [12, 44]:
			c.paint(c.mask().rect(cx, 9, 2, 4), Pal.BONE, 3)
			c.lit(cx + (i % 2), 7 + (i / 2) % 2, Pal.EMBER[4])
		c.outline(Pal.INK)
		fr.append(c)
	return fr


static func _heart_root(dir: String) -> void:
	var s := Sheet.new(56, 50, Vector2i(28, 48))
	for state in ["idle", "fed"]:
		s.add(state, _heart_frames(state == "fed"), 2.5 if state == "idle" else 4.0)
	s.save(dir, "landmark_heartroot")


static func _heart_frames(fed: bool) -> Array:
	var fr: Array = []
	for i in 4:
		var c := Px.new(56, 50)
		# a mound of old coils where the roots broke through the floor
		c.paint(c.mask().ellipse(28.0, 44.0, 24.0, 5.0), Pal.WOOD, 1, true)
		# roots climbing up both sides and closing over the top
		for k in 4:
			var side := -1.0 if k < 2 else 1.0
			var x0 := 28.0 + side * (22.0 - (k % 2) * 9.0)
			var m := c.mask()
			for st in 28:
				var t := st / 27.0
				var a := Vector2(x0, 44.0)
				var b := Vector2(28.0 + side * (20.0 - (k % 2) * 4.0), 18.0)
				var e := Vector2(28.0 - side * 2.0, 5.0 + (k % 2) * 3.0)
				var q := a.lerp(b, t).lerp(b.lerp(e, t), t)
				var th := lerpf(3.6, 1.2, t)
				m.ellipse(q.x, q.y, th, th * 0.9)
			c.paint(m, Pal.WOOD, 1 + k % 2, true)
		# tendrils from the heart down into the floor, feeding on it
		for k in 3:
			var tx := 22 + k * 6
			for ty in range(28, 42):
				c.put(tx + int(sin(ty * 0.5 + k) * 1.5), ty, Pal.BLOOD[1] if ty % 3 else Pal.BLOOD[2])
		# the heart they hold: a red core that swells and settles
		var r: float = 8.5 + [0.0, 0.8, 1.4, 0.6][i]
		c.paint(c.mask().ellipse(28.0, 24.0, r + 1.0, r), Pal.BLOOD, 2, true)
		c.fill_lit(c.mask().ellipse(28.0, 24.0, r * 0.55, r * 0.45), Pal.BLOOD[3])
		if fed:
			# blood given: it beats hard and bright
			c.fill_lit(c.mask().ellipse(28.0, 24.0, r * 0.8, r * 0.7), Pal.BLOOD[4])
			c.fill_lit(c.mask().ellipse(27.0, 22.0, r * 0.3, r * 0.25), Pal.EMBER[4])
		c.lit(26, 21, Pal.EMBER[4])
		c.lit(27, 21, Pal.BLOOD[4])
		# one root bound across the front of it
		var m2 := c.mask()
		for st in 20:
			var t := st / 19.0
			m2.ellipse(lerpf(15.0, 41.0, t), lerpf(32.0, 20.0, t) + sin(t * PI) * 2.5, 1.9, 1.6)
		c.paint(m2, Pal.WOOD, 2, false)
		# the Bloom's red seeping into the mound; moss and pale caps
		for k in 7:
			c.lit(9 + k * 6, 42 - (k % 3), Pal.BLOOD[3] if (k + i) % 3 == 0 else Pal.BLOOD[2])
		for k in 6:
			c.put(8 + k * 8, 45 - (k % 2) * 2, Pal.MOSS[3])
			if k % 2 == 0:
				c.put(9 + k * 8, 44 - (k % 2) * 2, Pal.BONE[4])
		c.outline(Pal.INK)
		fr.append(c)
	return fr


static func _sun_disc(dir: String) -> void:
	var s := Sheet.new(56, 52, Vector2i(28, 50))
	for state in ["idle", "lit"]:
		s.add(state, _sun_frames(state == "lit"), 3.0 if state == "idle" else 6.0)
	s.save(dir, "landmark_sundisc")


static func _sun_frames(lit: bool) -> Array:
	var fr: Array = []
	for i in 4:
		var c := Px.new(56, 52)
		for k in 8:
			c.paint(c.mask().ellipse(5.0 + k * 6.5, 47.0 + (k % 2), 4.5, 3.0), Pal.STONE, 2 + k % 2, true)
		# the disc, leaning, with a wedge broken out of it
		var disc := c.mask().ellipse(28.0, 24.0, 21.0, 21.0)
		disc.subtract(c.mask().poly(V([[40, 5], [52, 2], [50, 22], [36, 16]])))
		c.paint(disc, Pal.GOLD, 2, true)
		c.paint(c.mask().ellipse(28.0, 24.0, 15.0, 15.0).intersect(disc), Pal.GOLD, 3)
		# rays carved into it; the face of the dead sun
		for k in 12:
			var d := Vector2.from_angle(k * TAU / 12.0)
			for st in range(9, 19):
				var px := int(28 + d.x * st)
				var py := int(24 + d.y * st)
				if disc.has(px, py):
					if lit and (k + i) % 2 == 0 and st < 9 + (i % 4) * 2 + 2:
						# warmth runs out along its rays again, a pulse at a time
						c.lit(px, py, Pal.EMBER[4] if st < 12 else Pal.EMBER[3])
					else:
						c.put(px, py, Pal.GOLD[1] if k % 2 == 0 else Pal.GOLD[4])
		c.fill(c.mask().ellipse(23.0, 21.0, 2.0, 1.5), Pal.GOLD[0])
		c.fill(c.mask().ellipse(33.0, 21.0, 2.0, 1.5), Pal.GOLD[0])
		c.line(23, 30, 33, 30, Pal.GOLD[0])
		# a crack, and the last warmth glinting in it
		c.line(28, 5, 31, 14, Pal.INK)
		c.line(31, 14, 27, 26, Pal.INK)
		c.lit(30, 12 + i, Pal.EMBER[4])
		c.lit(29, 18 - i % 2, Pal.EMBER[3])
		if lit:
			c.lit(28, 24, Pal.EMBER[4])
			c.lit(27, 24, Pal.EMBER[3])
			c.lit(28, 23, Pal.EMBER[3])
		c.outline(Pal.INK)
		fr.append(c)
	return fr
