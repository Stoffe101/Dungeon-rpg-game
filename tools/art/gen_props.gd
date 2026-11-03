## Dungeon furniture, pickups, projectiles, weapons and small effects.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
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
	_shadow(dir)
	_weapons(dir)
	_projectiles(dir)
	_pickups(dir)
	_torch(dir)
	_banner(dir)
	_urn(dir)
	_candles(dir)
	_chest(dir)
	_ember_pile(dir)
	_brazier(dir)
	_altar(dir)
	_spring(dir)
	_gate(dir)
	_cracks(dir)
	_decals(dir)
	_stairs(dir)
	_hearthstone(dir)
	_lorestone(dir)
	_shrine(dir)
	_fountain(dir)
	_wisp(dir)
	_impact(dir)
	_splat(dir)
	_loot(dir)
	_dummy(dir)
	_spikes(dir)
	_ember_well(dir)
	_trial_altar(dir)


static func _shadow(dir: String) -> void:
	var c := Px.new(32, 16)
	for y in 16:
		for x in 32:
			var dx := (x + 0.5 - 16.0) / 15.0
			var dy := (y + 0.5 - 8.0) / 7.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var t := 1.0 - d
				if Px.bayer(x, y) < t * 1.6 - 0.1:
					c.put(x, y, Color(0, 0, 0, 1))
	c.img.save_png(ProjectSettings.globalize_path(dir.path_join("shadow.png")))


static func _weapons(dir: String) -> void:
	# Hearthblade: grip at x=3
	var s := Px.new(22, 9)
	c_line(s, 1, 4, 5, 4, Pal.WOOD, 2)
	s.paint(s.mask().rect(5, 2, 2, 5), Pal.GOLD, 3)
	var blade := s.mask().poly(V([[7, 3], [19, 3], [21, 4.5], [19, 6], [7, 6]]))
	s.paint(blade, Pal.STEEL, 4, false)
	for x in range(8, 19):
		s.put(x, 4, Pal.STEEL[5])
	s.lit(9, 4, Pal.EMBER[4])
	s.put(0, 4, Pal.GOLD[3])
	s.outline(Pal.INK)
	single(dir, "w_sword", s, Vector2i(3, 4))
	# Cinderhammer
	var h := Px.new(22, 14)
	c_line(h, 1, 7, 13, 7, Pal.WOOD, 2)
	var head := h.mask().rect(13, 2, 7, 11)
	h.paint(head, Pal.STEEL, 2, true)
	for y in range(4, 11):
		h.lit(16, y, Pal.EMBER[3] if y % 2 == 0 else Pal.EMBER[2])
	h.paint(h.mask().rect(12, 5, 1, 5), Pal.GOLD, 2)
	h.outline(Pal.INK)
	single(dir, "w_hammer", h, Vector2i(3, 7))
	# Ashwood Staff
	var st := Px.new(26, 9)
	c_line(st, 0, 4, 19, 4, Pal.WOOD, 2)
	var top := st.mask().ellipse(21.5, 4.5, 3.0, 3.0)
	st.paint(top, Pal.WOOD, 3)
	st.lit(21, 4, Pal.EMBER[5])
	st.lit(22, 4, Pal.EMBER[4])
	st.lit(21, 5, Pal.EMBER[3])
	st.put(17, 3, Pal.GOLD[3])
	st.outline(Pal.INK)
	single(dir, "w_staff", st, Vector2i(5, 4))
	# Twin Fangs: a curved fang of a blade with a wrapped grip
	var dg := Px.new(16, 9)
	c_line(dg, 1, 4, 4, 4, Pal.EARTH, 2)
	dg.paint(dg.mask().rect(4, 3, 1, 4), Pal.GOLD, 3)
	var fang := dg.mask().poly(V([[5, 3], [11, 3], [15, 1.5], [13, 5], [5, 6]]))
	dg.paint(fang, Pal.STEEL, 4, false)
	for x in range(6, 12):
		dg.put(x, 4, Pal.STEEL[5])
	dg.lit(7, 4, Pal.GLOAM[4])
	dg.put(0, 4, Pal.GOLD[3])
	dg.outline(Pal.INK)
	single(dir, "w_daggers", dg, Vector2i(3, 4))
	# Sunpiercer: a long ashwood shaft, a gold collar and a leaf head with a burning edge
	var sp := Px.new(36, 9)
	c_line(sp, 0, 4, 25, 4, Pal.WOOD, 2)
	for x in [3, 9, 15]:
		sp.put(x, 4, Pal.WOOD[4])
	sp.paint(sp.mask().rect(25, 3, 2, 3), Pal.GOLD, 3)
	var leaf := sp.mask().poly(V([[27, 4.5], [30, 1.5], [35.5, 4.5], [30, 7.5]]))
	sp.paint(leaf, Pal.STEEL, 4, false)
	for x in range(28, 35):
		sp.lit(x, 4, Pal.EMBER[4] if x % 2 == 0 else Pal.EMBER[3])
	sp.outline(Pal.INK)
	single(dir, "w_spear", sp, Vector2i(10, 4))
	# Hearthbow: a recurve of blackened ashwood, string glowing faintly (held at the grip, x=4)
	var bw := Px.new(12, 22)
	var limb := bw.mask()
	limb.line(4, 11, 6, 6).line(6, 6, 8, 2).line(8, 2, 10, 1)
	limb.line(4, 11, 6, 16).line(6, 16, 8, 20).line(8, 20, 10, 21)
	limb.line(5, 11, 7, 6).line(5, 11, 7, 16)
	bw.paint(limb, Pal.WOOD, 2, false)
	bw.paint(bw.mask().rect(3, 9, 3, 5), Pal.EARTH, 3)
	for y in range(2, 21):
		bw.lit(10 if y < 4 or y > 18 else 9, y, Pal.EMBER[2] if y % 3 else Pal.EMBER[3])
	bw.put(10, 1, Pal.GOLD[3])
	bw.put(10, 21, Pal.GOLD[3])
	bw.outline(Pal.INK)
	single(dir, "w_bow", bw, Vector2i(4, 11))
	# Emberwright's Tome: an open book of hearth-script, a sigil burning on the page
	var tm := Px.new(14, 12)
	tm.paint(tm.mask().poly(V([[1, 3], [7, 4], [13, 3], [13, 10], [7, 11], [1, 10]])), Pal.BLOOD, 2, true)
	tm.paint(tm.mask().poly(V([[2, 3], [7, 4], [7, 10], [2, 9]])), Pal.BONE, 3)
	tm.paint(tm.mask().poly(V([[7, 4], [12, 3], [12, 9], [7, 10]])), Pal.BONE, 4)
	for y in range(5, 9):
		tm.put(3 + (y % 2), y, Pal.EARTH[2])
		tm.put(5, y, Pal.EARTH[2])
	tm.lit(9, 5, Pal.EMBER[4])
	tm.lit(10, 6, Pal.EMBER[5])
	tm.lit(9, 7, Pal.EMBER[4])
	tm.lit(10, 8, Pal.EMBER[3])
	tm.put(7, 4, Pal.GOLD[3])
	tm.put(7, 10, Pal.GOLD[3])
	tm.outline(Pal.INK)
	single(dir, "w_tome", tm, Vector2i(3, 7))


static func c_line(c: Px, x0: int, y0: int, x1: int, y1: int, r: Array, base: int) -> void:
	var m := c.mask()
	m.line(x0, y0, x1, y1)
	m.line(x0, y0 + 1, x1, y1 + 1)
	c.paint(m, r, base, false)


static func _projectiles(dir: String) -> void:
	# ember bolt (points right)
	var sh := Sheet.new(10, 7, Vector2i(5, 3))
	var fr: Array = []
	for i in 2:
		var c := Px.new(10, 7)
		var m := c.mask().ellipse(6.0, 3.5, 3.4, 2.2)
		c.fill_lit(m, Pal.EMBER[3])
		c.fill_lit(c.mask().ellipse(6.5, 3.5, 1.8, 1.2), Pal.EMBER[5])
		c.lit(2 - i, 3, Pal.EMBER[2])
		c.lit(1, 3 + (i * 2 - 1), Pal.EMBER[1])
		fr.append(c)
	sh.add("idle", fr, 12.0)
	sh.save(dir, "proj_ember")
	# a mote of hearth-script: a tiny burning glyph that seeks
	var sm := Sheet.new(8, 8, Vector2i(4, 4))
	fr = []
	for i in 3:
		var c := Px.new(8, 8)
		c.fill_lit(c.mask().ellipse(4.0, 4.0, 2.4, 2.4), Pal.BONE[4])
		c.lit(4, 4, Pal.WHITE)
		c.lit(2 + i, 1, Pal.BONE[3])
		c.lit(6 - i, 6, Pal.BONE[3])
		fr.append(c)
	sm.add("idle", fr, 14.0)
	sm.save(dir, "proj_mote")
	# fireball
	var sf := Sheet.new(14, 14, Vector2i(7, 7))
	fr = []
	for i in 2:
		var c := Px.new(14, 14)
		c.fill_lit(c.mask().ellipse(7.5, 7.0, 5.5 - i * 0.5, 5.0), Pal.EMBER[2])
		c.fill_lit(c.mask().ellipse(8.0, 7.0, 3.6, 3.4), Pal.EMBER[3])
		c.fill_lit(c.mask().ellipse(8.5, 6.5, 2.0, 1.8), Pal.EMBER[5])
		c.lit(2, 5 + i, Pal.EMBER[1])
		c.lit(1, 8 - i, Pal.EMBER[1])
		fr.append(c)
	sf.add("idle", fr, 10.0)
	sf.save(dir, "proj_fireball")
	# cinder lance
	var sl := Sheet.new(20, 7, Vector2i(10, 3))
	fr = []
	for i in 2:
		var c := Px.new(20, 7)
		c.fill_lit(c.mask().poly(V([[0, 3.5], [14, 1], [19.5, 3.5], [14, 6]])), Pal.EMBER[3])
		c.fill_lit(c.mask().poly(V([[3, 3.5], [14, 2.5], [18, 3.5], [14, 4.5]])), Pal.EMBER[5])
		c.lit(1 + i, 2, Pal.EMBER[2])
		fr.append(c)
	sl.add("idle", fr, 14.0)
	sl.save(dir, "proj_lance")
	# soul arrow
	var a := Px.new(12, 5)
	a.line(0, 2, 8, 2, Pal.BONE[3])
	a.lit(9, 2, Pal.SOUL[5])
	a.lit(10, 2, Pal.SOUL[4])
	a.lit(9, 1, Pal.SOUL[3])
	a.lit(9, 3, Pal.SOUL[3])
	a.put(0, 1, Pal.SOUL[2])
	a.put(0, 3, Pal.SOUL[2])
	single(dir, "proj_arrow", a, Vector2i(6, 2))
	# soul orb
	var so := Sheet.new(10, 10, Vector2i(5, 5))
	fr = []
	for i in 2:
		var c := Px.new(10, 10)
		c.fill_lit(c.mask().ellipse(5.0, 5.0, 4.2 - i * 0.4, 4.2 - i * 0.4), Pal.SOUL[2])
		c.fill_lit(c.mask().ellipse(5.0, 5.0, 2.6, 2.6), Pal.SOUL[4])
		c.lit(4, 4, Pal.SOUL[5])
		fr.append(c)
	so.add("idle", fr, 8.0)
	so.save(dir, "proj_orb")
	# cutting wave (crescent)
	var sw := Sheet.new(12, 18, Vector2i(6, 9))
	fr = []
	for i in 2:
		var c := Px.new(12, 18)
		var m := c.mask().ellipse(4.0, 9.0, 6.5, 8.5)
		m.subtract(c.mask().ellipse(1.5 - i * 0.5, 9.0, 6.0, 8.0))
		c.fill_lit(m, Pal.EMBER[4])
		for y in 18:
			for x in 12:
				if m.has(x, y) and not m.has(x + 1, y):
					c.lit(x, y, Pal.EMBER[5])
		fr.append(c)
	sw.add("idle", fr, 12.0)
	sw.save(dir, "proj_wave")


static func _pickups(dir: String) -> void:
	var se := Sheet.new(7, 8, Vector2i(3, 7))
	var fr: Array = []
	for i in 4:
		var c := Px.new(7, 8)
		var m := c.mask().poly(V([[3.5, 1], [6, 4], [3.5, 7], [1, 4]]))
		c.fill_lit(m, Pal.EMBER[3])
		c.lit(3, 3, Pal.EMBER[5] if i != 2 else Pal.WHITE)
		c.lit(2, 4, Pal.EMBER[4])
		c.outline(Pal.EMBER[0])
		fr.append(c)
	se.add("idle", fr, 6.0)
	se.save(dir, "pickup_ember")
	var sm := Sheet.new(7, 8, Vector2i(3, 7))
	fr = []
	for i in 4:
		var c := Px.new(7, 8)
		c.fill_lit(c.mask().ellipse(3.5, 4.0 - (1 if i % 2 == 0 else 0), 2.4, 2.4), Pal.SOUL[3])
		c.lit(3, 3 - (1 if i % 2 == 0 else 0), Pal.SOUL[5])
		fr.append(c)
	sm.add("idle", fr, 6.0)
	sm.save(dir, "pickup_memory")
	var sh := Sheet.new(9, 9, Vector2i(4, 8))
	fr = []
	for i in 2:
		var c := Px.new(9, 9)
		var m := c.mask().ellipse(3.0, 3.5, 2.2, 2.2)
		m.union(c.mask().ellipse(6.0, 3.5, 2.2, 2.2))
		m.poly(V([[1, 4], [8, 4], [4.5, 8]]))
		c.fill_lit(m, Pal.BLOOD[3])
		c.lit(3, 3, Pal.BLOOD[4] if i == 0 else Pal.WHITE)
		c.outline(Pal.BLOOD[0])
		fr.append(c)
	sh.add("idle", fr, 3.0)
	sh.save(dir, "pickup_heal")
	var ss := Sheet.new(9, 11, Vector2i(4, 10))
	fr = []
	for i in 4:
		var c := Px.new(9, 11)
		var m := c.mask().poly(V([[4.5, 0.5], [7.5, 4], [4.5, 10], [1.5, 4]]))
		c.fill_lit(m, Pal.GOLD[3])
		c.lit(4, 3, Pal.GOLD[4])
		c.lit(4, 2 + i, Pal.WHITE)
		c.outline(Pal.GOLD[0])
		fr.append(c)
	ss.add("idle", fr, 6.0)
	ss.save(dir, "pickup_sunshard")


static func _torch(dir: String) -> void:
	_torch_variant(dir, "torch", Pal.SOUL)
	_torch_variant(dir, "torch_warm", Pal.EMBER)


static func _torch_variant(dir: String, name: String, R: Array) -> void:
	var s := Sheet.new(9, 16, Vector2i(4, 15))
	var fr: Array = []
	for i in 4:
		var c := Px.new(9, 16)
		c.paint(c.mask().rect(3, 9, 3, 6), Pal.STEEL, 2)
		c.paint(c.mask().rect(2, 8, 5, 2), Pal.STEEL, 3)
		var fh := 4.0 + (i % 2)
		var fl := c.mask().ellipse(4.5 + (1 if i == 2 else 0) * 0.5, 7.0 - fh * 0.5, 2.2, fh * 0.75)
		c.fill_lit(fl, R[3])
		c.fill_lit(c.mask().ellipse(4.5, 6.5, 1.2, 1.6), R[5])
		c.lit(4 + (i % 2), 2 - (i % 2), R[4])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 8.0)
	s.save(dir, name)


static func _banner(dir: String) -> void:
	var c := Px.new(12, 22)
	c.paint(c.mask().rect(0, 0, 12, 2), Pal.WOOD, 3)
	var cl := c.mask().poly(V([[1, 2], [11, 2], [11, 19], [6, 15], [1, 19]]))
	c.paint(cl, Pal.GLOAM, 2, true)
	# sigil: an eye
	c.paint(c.mask().ellipse(6.0, 8.0, 3.0, 1.8), Pal.BONE, 3, false, false)
	c.put(6, 8, Pal.INK)
	c.put(5, 8, Pal.INK)
	c.outline(Pal.INK)
	single(dir, "banner", c, Vector2i(6, 21))


static func _urn(dir: String) -> void:
	var c := Px.new(12, 14)
	var m := c.mask().ellipse(6.0, 8.5, 4.6, 4.8)
	m.rect(4, 1, 4, 4)
	c.paint(m, Pal.EARTH, 3, true)
	c.paint(c.mask().rect(3, 1, 6, 2), Pal.EARTH, 4)
	c.line(2, 8, 10, 8, Pal.EARTH[2])
	c.put(4, 6, Pal.EARTH[5])
	c.outline(Pal.INK)
	single(dir, "urn", c, Vector2i(6, 13))


static func _candles(dir: String) -> void:
	var s := Sheet.new(12, 10, Vector2i(6, 9))
	var fr: Array = []
	for i in 3:
		var c := Px.new(12, 10)
		for k in [[2, 5, 4], [5, 3, 6], [8, 6, 3]]:
			c.paint(c.mask().rect(k[0], k[1], 2, 9 - k[1]), Pal.BONE, 3)
			c.lit(k[0] + (i + k[0]) % 2, k[1] - 1, Pal.EMBER[5])
			c.lit(k[0], k[1] - 2 + ((i + k[0]) % 2), Pal.EMBER[3])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 6.0)
	s.save(dir, "candles")


static func _chest(dir: String) -> void:
	var s := Sheet.new(16, 16, Vector2i(8, 15))
	var closed := _chest_frame(0)
	s.add("closed", [closed], 1.0)
	s.add("open", [_chest_frame(1), _chest_frame(2), _chest_frame(3)], 10.0, false)
	s.save(dir, "chest")


static func _chest_frame(open: int) -> Px:
	var c := Px.new(16, 16)
	c.paint(c.mask().rect(1, 8, 14, 7), Pal.WOOD, 2, true)
	for x in [1, 7, 14]:
		c.paint(c.mask().rect(x, 8, 1, 7), Pal.GOLD, 2)
	if open == 0:
		var lid := c.mask().ellipse(8.0, 8.0, 7.4, 4.0)
		lid.rect(1, 8, 14, 1)
		var cut := c.mask().rect(0, 9, 16, 7)
		lid.subtract(cut)
		c.paint(lid, Pal.WOOD, 3, true)
		c.paint(c.mask().rect(7, 7, 2, 3), Pal.GOLD, 3)
	else:
		var lid2 := c.mask().rect(1, 8 - open * 2, 14, 2)
		c.paint(lid2, Pal.WOOD, 3)
		var glow := c.mask().rect(2, 8, 12, 2)
		c.fill_lit(glow, Pal.GOLD[4] if open < 3 else Pal.GOLD[3])
		for k in open:
			c.lit(4 + k * 3, 6 - k, Pal.GOLD[4])
	c.outline(Pal.INK)
	return c


static func _ember_pile(dir: String) -> void:
	var c := Px.new(14, 8)
	for k in 9:
		var x := 2 + (k * 5) % 10
		var y := 3 + (k * 3) % 4
		c.lit(x, y, Pal.EMBER[3 + k % 3])
		c.lit(x + 1, y, Pal.EMBER[2])
		c.lit(x, y + 1, Pal.EMBER[2])
	c.outline(Pal.EMBER[0])
	single(dir, "ember_pile", c, Vector2i(7, 7))


static func _brazier(dir: String) -> void:
	var s := Sheet.new(16, 26, Vector2i(8, 24))
	var fr: Array = []
	for i in 4:
		fr.append(_brazier_frame(i, true))
	s.add("lit", fr, 8.0)
	s.add("unlit", [_brazier_frame(0, false)], 1.0)
	s.save(dir, "brazier")
	# the same brazier burning with hearth-gold fire (the Sunken Throne)
	var w := Sheet.new(16, 26, Vector2i(8, 24))
	var wf: Array = []
	for i in 4:
		wf.append(_brazier_frame(i, true, Pal.EMBER, Pal.GOLD))
	w.add("lit", wf, 8.0)
	w.add("unlit", [_brazier_frame(0, false, Pal.EMBER, Pal.GOLD)], 1.0)
	w.save(dir, "brazier_warm")


static func _brazier_frame(i: int, lit: bool, fire: Array = Pal.SOUL, metal: Array = Pal.STEEL) -> Px:
	var c := Px.new(16, 26)
	c.paint(c.mask().rect(6, 14, 4, 10), metal, 2)
	c.paint(c.mask().rect(3, 22, 10, 2), metal, 1)
	var bowl := c.mask().ellipse(8.0, 13.0, 6.0, 3.0)
	bowl.subtract(c.mask().rect(0, 0, 16, 12))
	bowl.rect(2, 11, 12, 2)
	c.paint(bowl, metal, 3, true)
	if lit:
		var h := 8.0 + (i % 2) * 1.5
		var f := c.mask().ellipse(8.0 + (1 if i == 1 else 0) * 0.5, 11.0 - h * 0.45, 4.0, h * 0.6)
		c.fill_lit(f, fire[3])
		c.fill_lit(c.mask().ellipse(8.0, 9.0, 2.2, 3.0), fire[4])
		c.lit(8, 9, fire[5])
		c.lit(7 + i % 3, 2 + (i % 2), fire[4])
	else:
		for x in range(4, 12, 2):
			c.put(x, 11, Pal.INK)
			c.put(x + 1, 11, Pal.EARTH[1])
	c.outline(Pal.INK)
	return c


static func _altar(dir: String) -> void:
	var s := Sheet.new(16, 22, Vector2i(8, 21))
	var fr: Array = []
	for i in 4:
		fr.append(_altar_frame(i, true))
	s.add("idle", fr, 6.0)
	s.add("empty", [_altar_frame(0, false)], 1.0)
	s.save(dir, "altar")


static func _altar_frame(i: int, full: bool) -> Px:
	var c := Px.new(16, 22)
	c.paint(c.mask().rect(3, 14, 10, 7), Pal.STONE, 3, true)
	c.paint(c.mask().rect(2, 13, 12, 2), Pal.STONE, 4)
	c.paint(c.mask().rect(2, 20, 12, 1), Pal.STONE, 2)
	if full:
		var y := 6 - (1 if i in [1, 2] else 0)
		var m := c.mask().poly(V([[8, y - 3], [11, y + 1], [8, y + 5], [5, y + 1]]))
		c.fill_lit(m, Pal.GOLD[3])
		c.lit(8, y, Pal.WHITE)
		c.lit(7, y + 1, Pal.GOLD[4])
		c.outline(Pal.INK)
		c.lit(8, y - 5 - i % 2, Pal.GOLD[4])
	else:
		c.outline(Pal.INK)
	return c


static func _spring(dir: String) -> void:
	var s := Sheet.new(20, 16, Vector2i(10, 14))
	var fr: Array = []
	for i in 4:
		fr.append(_spring_frame(i, true))
	s.add("idle", fr, 6.0)
	s.add("empty", [_spring_frame(0, false)], 1.0)
	s.save(dir, "spring")


static func _spring_frame(i: int, full: bool) -> Px:
	var c := Px.new(20, 16)
	var rim := c.mask().ellipse(10.0, 10.0, 9.0, 5.0)
	c.paint(rim, Pal.STONE, 3, true)
	var pool := c.mask().ellipse(10.0, 10.0, 7.0, 3.4)
	if full:
		c.fill_lit(pool, Pal.EMBER[2])
		c.fill_lit(c.mask().ellipse(10.0, 10.0, 4.0, 1.8), Pal.BLOOD[4])
		c.lit(6 + i * 2, 9 + i % 2, Pal.EMBER[5])
	else:
		c.fill(pool, Pal.INK)
	c.outline(Pal.INK)
	return c


## Soul-light seals across a fighting room's doors: a woven lattice of the
## Undervault's teal light with a column of runes climbing through it, standing
## on a rune plate set in the floor. They form in stages, shimmer while the room
## holds, and break into rising motes when it is won. The lattice tiles
## seamlessly across wide doors; the plate is each region's material.
const SEAL_RUNES := [[[0, 0], [1, 1], [2, 0]], [[1, 0], [0, 1], [2, 1], [1, 2]], [[0, 0], [0, 1], [1, 2], [2, 2]], [[2, 0], [1, 1], [0, 2]]]


static func _gate(dir: String) -> void:
	for v in [["gate", Pal.BONE, Pal.STONE], ["gate_root", Pal.WOOD, Pal.MOSS], ["gate_throne", Pal.GOLD, Pal.STONE]]:
		var s := Sheet.new(16, 36, Vector2i(8, 35))
		var idle: Array = []
		for i in 6:
			idle.append(_seal(1.0, i, v[1], v[2], 0.0))
		s.add("closed", idle, 8.0)
		var rise: Array = []
		for i in 6:
			rise.append(_seal(float(i + 1) / 6.0, i, v[1], v[2], 0.0))
		s.add("rise", rise, 18.0, false)
		var fall: Array = []
		for i in 6:
			fall.append(_seal(1.0, i, v[1], v[2], float(i + 1) / 6.0))
		s.add("fall", fall, 16.0, false)
		s.save(dir, String(v[0]))


## k: how far the seal has formed (0..1); ph: animation phase; gone: how far
## it has broken apart (0..1).
static func _seal(k: float, ph: int, plate: Array, trim: Array, gone: float) -> Px:
	var c := Px.new(16, 36)
	# the plate in the floor: the region's material with a seal glyph
	var pk := clampf(k * 3.0, 0.0, 1.0)
	if pk > 0.0:
		c.paint(c.mask().rect(0, 32, 16, 4), plate, 2, true)
		c.line(0, 32, 15, 32, plate[3])
		c.put(3, 34, trim[1])
		c.put(12, 34, trim[1])
		var glow := Pal.SOUL[5] if gone <= 0.0 else Pal.SOUL[3]
		for p in [[6, 33], [7, 34], [8, 34], [9, 33], [7, 33], [8, 33]]:
			if pk >= 1.0:
				c.lit(p[0], p[1], glow if (p[0] + ph) % 3 == 0 else Pal.SOUL[3])
	# the lattice rises out of the plate after it lights
	var lk := clampf((k - 0.25) / 0.75, 0.0, 1.0)
	var h := int(round(30.0 * lk))
	if h <= 0:
		return c
	var top := 32 - h
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + ph * 7
	for y in range(top, 32):
		for x in 16:
			var a := (x + y + ph) % 8 == 0
			var b := (x - y + 64 - ph) % 8 == 0
			if not (a or b):
				continue
			# breaking apart: the lattice comes undone from the top down, in flecks
			if gone > 0.0 and (float(32 - y) / 30.0 > 1.0 - gone or rng.randf() < gone * 0.8):
				continue
			c.lit(x, y, Pal.SOUL[4] if a and b else Pal.SOUL[2 + (y + ph) % 2])
	# the rune column climbing through the middle
	if gone < 0.5:
		for k2 in 4:
			var ry := 32 - ((ph * 2 + k2 * 8) % 32) - 3
			if ry < top or ry > 29:
				continue
			for p in SEAL_RUNES[(k2 + ph / 3) % SEAL_RUNES.size()]:
				c.lit(6 + p[0], ry + p[1], Pal.SOUL[5] if k2 % 2 == 0 else Pal.SOUL[4])
	# a bright crest where it is still growing (or where it stands)
	if gone <= 0.0:
		for x in range(0, 16, 2):
			c.lit(x + (ph % 2), top, Pal.SOUL[5] if lk < 1.0 or (x / 2 + ph) % 3 == 0 else Pal.SOUL[3])
	return c


static func _cracks(dir: String) -> void:
	var c := Px.new(40, 30)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 7:
		var x := 20
		var y := 29
		var dx := rng.randf_range(-1.2, 1.2)
		for s in rng.randi_range(10, 24):
			c.put(x, y, Pal.INK)
			if rng.randf() < 0.3:
				c.put(x + 1, y, Pal.STONE[0])
			y -= 1
			x += roundi(dx + rng.randf_range(-0.8, 0.8))
			if x < 1 or x > 38 or y < 1:
				break
	for k in 12:
		c.put(rng.randi_range(8, 32), rng.randi_range(18, 29), Pal.STONE[4])
	single(dir, "cracks", c, Vector2i(20, 29))


static func _decals(dir: String) -> void:
	# one row of floor clutter per region (ossuary, rootmire, throne), ten each;
	# a few carry faint light (soul seeps, glowing caps, cinders, gold veins)
	var s := Sheet.new(20, 20, Vector2i(10, 10))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for row in ["ossuary", "rootmire", "throne", "camp"]:
		var fr: Array = []
		for v in 10:
			var c := Px.new(20, 20)
			match row:
				"ossuary":
					_decal_ossuary(c, v, rng)
				"rootmire":
					_decal_rootmire(c, v, rng)
				"camp":
					_decal_camp(c, v, rng)
				_:
					_decal_throne(c, v, rng)
			fr.append(c)
		s.add(row, fr, 1.0)
	s.save(dir, "decals")


static func _bones(c: Px, rng: RandomNumberGenerator, n: int, r: Array) -> void:
	for k in n:
		var x := rng.randi_range(3, 13)
		var y := rng.randi_range(4, 15)
		var l := rng.randi_range(3, 6)
		var dy := rng.randi_range(-2, 2)
		c.line(x, y, x + l, y + dy, r[2])
		c.put(x, y, r[3])
		c.put(x + l, y + dy, r[3])
		c.put(x, y + 1, r[1])


static func _crack(c: Px, rng: RandomNumberGenerator, col: Color, glow: Color = Color(0, 0, 0, 0)) -> void:
	var x := 2
	var y := rng.randi_range(5, 12)
	for k in 17:
		if glow.a > 0.0 and k % 3 != 0:
			c.lit(x, y, glow)
		else:
			c.put(x, y, col)
		x += 1
		y = clampi(y + rng.randi_range(-1, 1), 2, 17)
		if rng.randf() < 0.2:
			c.put(x, y + 1, col)


static func _blob(c: Px, cx: float, cy: float, rx: float, ry: float, col: Color, density := 0.4, seed_v := 3) -> void:
	var m := c.mask().ellipse(cx, cy, rx, ry)
	for y in 20:
		for x in 20:
			if m.has(x, y) and Px.hash01(x, y, seed_v) > density:
				c.put(x, y, col)


static func _decal_ossuary(c: Px, v: int, rng: RandomNumberGenerator) -> void:
	match v:
		0:
			_bones(c, rng, 3, Pal.BONE)
		1:
			_bones(c, rng, 2, Pal.BONE)
			c.paint(c.mask().ellipse(11.0, 10.0, 2.6, 2.2), Pal.BONE, 2)
			c.put(10, 10, Pal.INK)
			c.put(12, 10, Pal.INK)
			c.put(11, 12, Pal.BONE[1])
		2:
			_crack(c, rng, Pal.STONE[0])
		3:
			_blob(c, 10.0, 10.0, 6.0, 3.5, Pal.BLOOD[0], 0.35)
		4:
			for k in 7:
				var x := rng.randi_range(2, 16)
				var y := rng.randi_range(2, 16)
				c.put(x, y, Pal.STONE[3])
				c.put(x + 1, y, Pal.STONE[2])
				c.put(x, y + 1, Pal.STONE[1])
		5:
			# a cobweb, strung between nothing in particular
			var o := Vector2(3, 3)
			for k in 5:
				var a := k * 0.35
				var e := o + Vector2(cos(a), sin(a)) * 15.0
				c.line(int(o.x), int(o.y), int(e.x), int(e.y), Color(0.75, 0.75, 0.8, 0.55))
			for rr: float in [6.0, 10.0, 14.0]:
				for k in 12:
					var a := k * 0.15
					var p := o + Vector2(cos(a), sin(a)) * rr
					c.put(int(p.x), int(p.y), Color(0.7, 0.7, 0.75, 0.45))
		6:
			# soul-light seeping through a crack
			_crack(c, rng, Pal.STONE[0], Pal.SOUL[3])
		7:
			# a guttered candle in its wax
			_blob(c, 10.0, 12.0, 4.0, 2.2, Pal.BONE[3], 0.15)
			c.paint(c.mask().rect(9, 7, 2, 5), Pal.BONE, 3)
			c.lit(9, 6, Pal.EMBER[4])
			c.lit(10, 5, Pal.EMBER[3])
		8:
			# lost coins
			for k in 4:
				var x := rng.randi_range(4, 15)
				var y := rng.randi_range(5, 15)
				c.put(x, y, Pal.GOLD[3])
				c.put(x + 1, y, Pal.GOLD[2])
		_:
			# shards of a burial urn
			for k in 5:
				var x := rng.randi_range(3, 14)
				var y := rng.randi_range(4, 15)
				c.paint(c.mask().poly(PackedVector2Array([Vector2(x, y), Vector2(x + 3, y), Vector2(x + 1, y + 2)])), Pal.EARTH, 3)


static func _decal_rootmire(c: Px, v: int, rng: RandomNumberGenerator) -> void:
	match v:
		0:
			_blob(c, 10.0, 10.0, 7.0, 4.0, Pal.MOSS[2], 0.3, 5)
			_blob(c, 9.0, 9.0, 4.0, 2.4, Pal.MOSS[3], 0.45, 6)
		1:
			# a root crossing the floor
			var y := rng.randi_range(6, 12)
			for x in range(1, 19):
				y = clampi(y + rng.randi_range(-1, 1), 3, 16)
				c.put(x, y, Pal.WOOD[2])
				c.put(x, y + 1, Pal.WOOD[1])
		2:
			# glowing caps
			for k in 4:
				var x := rng.randi_range(4, 15)
				var y := rng.randi_range(6, 15)
				c.put(x, y + 1, Pal.BONE[2])
				var col: Color = Pal.SOUL[4] if k % 2 == 0 else Pal.GLOAM[4]
				c.lit(x, y, col)
				c.lit(x + 1, y, col)
		3:
			# a still puddle
			_blob(c, 10.0, 10.0, 6.0, 3.0, Color8(18, 28, 30), 0.0)
			c.put(7, 9, Pal.SOUL[2])
			c.put(8, 9, Pal.SOUL[1])
			c.put(12, 11, Pal.SOUL[1])
		4:
			for k in 9:
				var x := rng.randi_range(2, 17)
				var y := rng.randi_range(2, 17)
				c.put(x, y, Pal.MOSS[3] if k % 2 == 0 else Pal.EARTH[2])
				c.put(x + 1, y, Pal.MOSS[2])
		5:
			# a ring of spores
			for k in 10:
				var a := k * TAU / 10.0
				c.lit(int(10 + cos(a) * 6.0), int(10 + sin(a) * 3.5), Pal.MOSS[5])
		6:
			_bones(c, rng, 2, Pal.BONE)
			_blob(c, 10.0, 11.0, 5.0, 2.5, Pal.MOSS[2], 0.55)
		7:
			_crack(c, rng, Pal.EARTH[0])
			_blob(c, 8.0, 10.0, 3.0, 2.0, Pal.MOSS[3], 0.5)
		8:
			# a fern
			for k in 5:
				var a := -PI * 0.5 + (k - 2) * 0.45
				var e := Vector2(10, 15) + Vector2(cos(a), sin(a)) * 7.0
				c.line(10, 15, int(e.x), int(e.y), Pal.MOSS[3])
		_:
			for k in 6:
				c.lit(3 + k * 2, 10 + (k % 2), Pal.SOUL[3])
				c.put(3 + k * 2, 11 + (k % 2), Pal.BONE[1])


## The camp's floor: straw, wood chips, pebbles, spilled grain, flowers from the
## planters, a ring of old ash, boot prints and (of course) paw prints.
static func _decal_camp(c: Px, v: int, rng: RandomNumberGenerator) -> void:
	match v:
		0, 1:
			# straw
			for k in 7:
				var x := rng.randi_range(2, 14)
				var y := rng.randi_range(3, 16)
				c.line(x, y, x + rng.randi_range(2, 4), y + rng.randi_range(-1, 1), Pal.GOLD[2] if k % 2 == 0 else Pal.GOLD[1])
		2:
			# wood chips from the woodpile
			for k in 6:
				var x := rng.randi_range(3, 15)
				var y := rng.randi_range(3, 15)
				c.put(x, y, Pal.WOOD[3])
				c.put(x + 1, y, Pal.WOOD[2])
		3:
			for k in 6:
				var x := rng.randi_range(3, 15)
				var y := rng.randi_range(3, 15)
				c.put(x, y, Pal.STONE[3])
				c.put(x, y + 1, Pal.STONE[1])
		4:
			# spilled grain
			_blob(c, 10.0, 10.0, 5.0, 2.6, Pal.BONE[3], 0.45)
		5:
			# fallen petals from the planters
			for k in 5:
				var x := rng.randi_range(3, 15)
				var y := rng.randi_range(4, 15)
				c.put(x, y, Pal.BLOOD[3] if k % 2 == 0 else Pal.GOLD[3])
		6:
			# a ring of old ash where a fire once was
			for k in 14:
				var a := k * TAU / 14.0
				c.put(int(10 + cos(a) * 6.0), int(10 + sin(a) * 3.5), Pal.ASH[1])
			_blob(c, 10.0, 10.0, 3.0, 1.6, Pal.ASH[0], 0.4)
		7:
			# boot prints
			for k in 3:
				var x := 4 + k * 5
				var y := 12 - k * 2 + (k % 2) * 3
				c.put(x, y, Pal.EARTH[0])
				c.put(x + 1, y, Pal.EARTH[0])
				c.put(x, y + 1, Pal.EARTH[0])
		8:
			# paw prints: the cat has been everywhere
			for k in 4:
				var x := 3 + k * 4
				var y := 9 + (k % 2) * 2
				c.put(x, y, Pal.EARTH[0])
				c.put(x - 1, y - 1, Pal.EARTH[0])
				c.put(x + 1, y - 1, Pal.EARTH[0])
		_:
			# a tuft of tough grass
			for k in 5:
				var x := 6 + k * 2
				c.line(x, 15, x + rng.randi_range(-1, 1), 11 - (k % 2) * 2, Pal.MOSS[3])


static func _decal_throne(c: Px, v: int, rng: RandomNumberGenerator) -> void:
	match v:
		0:
			for k in 5:
				var x := rng.randi_range(3, 15)
				var y := rng.randi_range(4, 15)
				c.put(x, y, Pal.GOLD[3])
				c.put(x + 1, y, Pal.GOLD[4] if k == 0 else Pal.GOLD[2])
		1:
			_blob(c, 10.0, 11.0, 6.0, 3.0, Pal.ASH[2], 0.25)
			_blob(c, 10.0, 10.0, 3.5, 2.0, Pal.ASH[3], 0.4)
		2:
			# a scorch mark
			_blob(c, 10.0, 10.0, 7.0, 4.0, Color8(20, 14, 14), 0.3)
			_blob(c, 10.0, 10.0, 3.0, 1.8, Color8(10, 8, 10), 0.1)
		3:
			# a broken gilded pot
			for k in 4:
				var x := rng.randi_range(4, 14)
				var y := rng.randi_range(5, 14)
				c.paint(c.mask().poly(PackedVector2Array([Vector2(x, y), Vector2(x + 4, y), Vector2(x + 2, y + 3)])), Pal.EARTH, 2)
				c.put(x + 1, y, Pal.GOLD[3])
		4:
			# glass shards catching the light
			for k in 5:
				var x := rng.randi_range(3, 16)
				var y := rng.randi_range(3, 16)
				c.put(x, y, Pal.FROST[4])
				c.put(x + 1, y + 1, Pal.FROST[2])
		5:
			# cinders that have not gone out
			for k in 6:
				var x := rng.randi_range(4, 15)
				var y := rng.randi_range(5, 15)
				c.put(x, y, Pal.ASH[1])
				if k % 2 == 0:
					c.lit(x + 1, y, Pal.EMBER[3])
		6:
			# a fallen gilt tile
			c.paint(c.mask().poly(PackedVector2Array([Vector2(5, 8), Vector2(13, 6), Vector2(15, 12), Vector2(7, 14)])), Pal.GOLD, 2)
			c.put(10, 10, Pal.INK)
		7:
			_blob(c, 10.0, 10.0, 5.0, 3.0, Pal.BLOOD[0], 0.35)
		8:
			_crack(c, rng, Pal.OBSIDIAN[0], Pal.GOLD[3])
		_:
			# a torn strip of royal cloth
			var y := 9
			for x in range(3, 17):
				y = clampi(y + rng.randi_range(-1, 1), 6, 13)
				c.put(x, y, Pal.BLOOD[2])
				c.put(x, y + 1, Pal.BLOOD[1])
				if x % 3 == 0:
					c.put(x, y - 1, Pal.GOLD[2])


static func _stairs(dir: String) -> void:
	var c := Px.new(32, 32)
	var m := c.mask().rect(2, 2, 28, 28)
	c.fill(m, Pal.INK)
	for k in 6:
		var y := 4 + k * 4
		var col: Color = Pal.ramp(Pal.STONE, 4 - k)
		c.rect(4 + k, y, 24 - k * 2, 3, col)
		c.rect(4 + k, y + 3, 24 - k * 2, 1, Pal.INK)
	for y in 32:
		for x in 32:
			if (x < 2 or x > 29 or y < 2 or y > 29):
				c.put(x, y, Pal.STONE[3])
	c.lit(15, 27, Pal.SOUL[3])
	c.lit(16, 27, Pal.SOUL[3])
	single(dir, "stairs", c, Vector2i(16, 16))


static func _hearthstone(dir: String) -> void:
	var s := Sheet.new(16, 32, Vector2i(8, 30))
	var fr: Array = []
	for i in 4:
		var c := Px.new(16, 32)
		var m := c.mask().poly(V([[4, 30], [3, 10], [8, 2], [13, 10], [12, 30]]))
		c.paint(m, Pal.STONE, 3, true)
		# carved ember rune
		var g := 3 + (1 if i in [1, 2] else 0)
		c.lit(8, 12, Pal.ramp(Pal.EMBER, g + 1))
		for y in range(13, 22):
			c.lit(8, y, Pal.ramp(Pal.EMBER, g))
		c.lit(6, 16, Pal.ramp(Pal.EMBER, g))
		c.lit(10, 16, Pal.ramp(Pal.EMBER, g))
		c.lit(7, 17, Pal.ramp(Pal.EMBER, g))
		c.lit(9, 17, Pal.ramp(Pal.EMBER, g))
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 4.0)
	s.save(dir, "hearthstone")


static func _lorestone(dir: String) -> void:
	var c := Px.new(14, 20)
	var m := c.mask().poly(V([[2, 19], [2, 5], [7, 1], [12, 5], [12, 19]]))
	c.paint(m, Pal.STONE, 2, true)
	for y in range(6, 17, 3):
		for x in range(4, 10):
			if Px.hash01(x, y, 7) > 0.4:
				c.lit(x, y, Pal.SOUL[3])
	c.outline(Pal.INK)
	single(dir, "lorestone", c, Vector2i(7, 19))


static func _shrine(dir: String) -> void:
	var c := Px.new(24, 40)
	c.paint(c.mask().rect(4, 32, 16, 6), Pal.STONE, 2, true)
	c.paint(c.mask().rect(6, 12, 12, 21), Pal.STONE, 3, true)
	var head := c.mask().ellipse(12.0, 9.0, 5.0, 6.0)
	c.paint(head, Pal.STONE, 3, true)
	# hooded idol with weeping purple eyes
	c.put(10, 9, Pal.INK)
	c.put(14, 9, Pal.INK)
	c.lit(10, 9, Pal.GLOAM[4])
	c.lit(14, 9, Pal.GLOAM[4])
	for y in range(10, 16):
		c.lit(10, y, Pal.GLOAM[3])
		c.lit(14, y + 1, Pal.GLOAM[3])
	for y in range(18, 30, 3):
		c.line(8, y, 16, y, Pal.STONE[1])
	c.lit(12, 22, Pal.GLOAM[5])
	c.outline(Pal.INK)
	single(dir, "shrine", c, Vector2i(12, 38))


static func _fountain(dir: String) -> void:
	var s := Sheet.new(24, 26, Vector2i(12, 22))
	var fr: Array = []
	for i in 4:
		fr.append(_fountain_frame(i, true))
	s.add("idle", fr, 6.0)
	s.add("empty", [_fountain_frame(0, false)], 1.0)
	s.save(dir, "fountain")


static func _fountain_frame(i: int, full: bool) -> Px:
	var c := Px.new(24, 26)
	var basin := c.mask().ellipse(12.0, 18.0, 11.0, 5.5)
	c.paint(basin, Pal.STONE, 3, true)
	var pool := c.mask().ellipse(12.0, 17.5, 9.0, 3.8)
	if full:
		c.fill_lit(pool, Pal.EMBER[2])
		c.lit(7 + i * 3, 17, Pal.EMBER[5])
		c.lit(16 - i * 2, 18, Pal.EMBER[4])
	else:
		c.fill(pool, Pal.INK)
	c.paint(c.mask().rect(10, 5, 4, 12), Pal.STONE, 3, true)
	c.paint(c.mask().ellipse(12.0, 5.0, 4.0, 2.0), Pal.STONE, 4)
	if full:
		for y in range(6, 15):
			if (y + i) % 3 != 0:
				c.lit(12, y, Pal.EMBER[4])
		c.lit(12, 3, Pal.EMBER[5])
	c.outline(Pal.INK)
	return c


static func _wisp(dir: String) -> void:
	var s := Sheet.new(10, 12, Vector2i(5, 11))
	var fr: Array = []
	for i in 4:
		var c := Px.new(10, 12)
		c.fill_lit(c.mask().ellipse(5.0, 5.0, 3.6, 3.6), Pal.EMBER[3])
		c.fill_lit(c.mask().ellipse(5.0, 4.6, 2.0, 2.0), Pal.EMBER[5])
		c.lit(4 - (i % 2), 9 + (i % 2), Pal.EMBER[2])
		c.lit(5 + (i % 2), 10, Pal.EMBER[1])
		c.put(4, 4, Pal.INK)
		c.put(6, 4, Pal.INK)
		fr.append(c)
	s.add("idle", fr, 8.0)
	s.save(dir, "wisp")


## Impact flash for landed hits: a 4-frame starburst drawn in greys; the game
## tints it per damage type and draws it additively so it blooms.
static func _impact(dir: String) -> void:
	var s := Sheet.new(24, 24, Vector2i(12, 12))
	var fr: Array = []
	var spec := [
		# [core radius, cross spike length, diagonal spike length, ring radius]
		[2.2, 7, 4, 0.0],
		[3.0, 10, 6, 0.0],
		[1.2, 11, 7, 7.0],
		[0.0, 0, 0, 9.5],
	]
	for i in 4:
		var c := Px.new(24, 24)
		var core: float = spec[i][0]
		var cl: int = spec[i][1]
		var dl: int = spec[i][2]
		var rr: float = spec[i][3]
		for k in range(1, cl + 1):
			var v := Pal.WHITE if k < cl * 0.4 else (Pal.BONE[4] if k < cl * 0.75 else Pal.BONE[2])
			if i == 2 and k % 3 == 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				c.put(12 + d.x * k, 12 + d.y * k, v)
			if k < cl * 0.4:
				# a little thickness near the core
				c.put(12 + k, 11, Pal.BONE[3])
				c.put(12 - k, 13, Pal.BONE[3])
				c.put(11, 12 - k, Pal.BONE[3])
				c.put(13, 12 + k, Pal.BONE[3])
		for k in range(1, dl + 1):
			var v2 := Pal.BONE[4] if k < dl * 0.5 else Pal.BONE[2]
			for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				c.put(12 + d.x * k, 12 + d.y * k, v2)
		if core > 0.0:
			c.ellipse(12.0, 12.0, core, core, Pal.WHITE)
		if rr > 0.0:
			for a in 32:
				if i == 3 and a % 3 != 0:
					continue
				var ang := a * TAU / 32.0
				c.put(int(round(12 + cos(ang) * rr)), int(round(12 + sin(ang) * rr)), Pal.BONE[3] if i == 2 else Pal.BONE[1])
		fr.append(c)
	s.add("pop", fr, 26.0, false)
	s.save(dir, "impact")


## Floor splats left where things die (tinted per enemy in game) and scorch
## marks: irregular blobs with droplets, drawn in greys. 4 variants.
static func _splat(dir: String) -> void:
	var s := Sheet.new(24, 16, Vector2i(12, 8))
	var fr: Array = []
	for v in 4:
		var c := Px.new(24, 16)
		var m := c.mask()
		for k in 5:
			var ox := 12.0 + (Px.hash01(k, v, 3) - 0.5) * 10.0
			var oy := 8.0 + (Px.hash01(v, k, 5) - 0.5) * 5.0
			m.ellipse(ox, oy, 2.5 + Px.hash01(k, v, 9) * 3.5, 1.6 + Px.hash01(v, k, 11) * 2.0)
		for k in 6:
			var a := Px.hash01(k, v, 13) * TAU
			var d := 7.0 + Px.hash01(v, k, 17) * 4.0
			m.set_bit(int(12 + cos(a) * d), int(8 + sin(a) * d * 0.6))
		for y in 16:
			for x in 24:
				if m.has(x, y):
					var edge := not (m.has(x + 1, y) and m.has(x - 1, y) and m.has(x, y + 1) and m.has(x, y - 1))
					c.put(x, y, Pal.BONE[2] if edge else (Pal.BONE[3] if Px.hash01(x, y, v) > 0.8 else Pal.BONE[1]))
		fr.append(c)
	s.add("idle", fr, 1.0)
	s.save(dir, "splat")


## Loot on the floor: a material bundle (a tied pouch) and gear (a wrapped
## bundle with a glint). Drawn neutral; the game tints the glow by rarity.
static func _loot(dir: String) -> void:
	var sm := Sheet.new(10, 10, Vector2i(5, 9))
	var fr: Array = []
	for i in 4:
		var c := Px.new(10, 10)
		c.paint(c.mask().ellipse(5.0, 6.5, 3.6, 3.0), Pal.EARTH, 3, true)
		c.paint(c.mask().rect(3, 2, 4, 2), Pal.EARTH, 2)
		c.put(4, 4, Pal.GOLD[3])
		c.put(5, 4, Pal.GOLD[3])
		c.lit(7 - (i % 2), 3, Pal.BONE[4] if i < 2 else Pal.SOUL[4])
		c.outline(Pal.INK)
		fr.append(c)
	sm.add("idle", fr, 5.0)
	sm.save(dir, "pickup_mat")
	var sg := Sheet.new(14, 13, Vector2i(7, 12))
	fr = []
	for i in 4:
		var c := Px.new(14, 13)
		c.paint(c.mask().rect(2, 5, 10, 6), Pal.WOOD, 3, true)
		c.paint(c.mask().rect(2, 4, 10, 2), Pal.STEEL, 3)
		c.paint(c.mask().rect(6, 4, 2, 7), Pal.GOLD, 3)
		var g: Vector2i = [Vector2i(3, 2), Vector2i(10, 1), Vector2i(11, 3), Vector2i(4, 1)][i]
		c.lit(g.x, g.y, Pal.WHITE)
		c.lit(g.x + 1, g.y, Pal.GOLD[4])
		c.outline(Pal.INK)
		fr.append(c)
	sg.add("idle", fr, 6.0)
	sg.save(dir, "pickup_gear")
	# a blueprint: a rolled scroll tied with gold, glinting
	var sc := Sheet.new(12, 10, Vector2i(6, 9))
	fr = []
	for i in 4:
		var c := Px.new(12, 10)
		c.paint(c.mask().rect(2, 3, 8, 5), Pal.BONE, 3, true)
		c.paint(c.mask().ellipse(2.0, 5.5, 1.6, 2.6).ellipse(10.0, 5.5, 1.6, 2.6), Pal.BONE, 2, true)
		c.paint(c.mask().rect(5, 3, 2, 5), Pal.GOLD, 3)
		var g2: Vector2i = [Vector2i(3, 2), Vector2i(9, 1), Vector2i(10, 3), Vector2i(2, 1)][i]
		c.lit(g2.x, g2.y, Pal.WHITE)
		c.outline(Pal.INK)
		fr.append(c)
	sc.add("idle", fr, 6.0)
	sc.save(dir, "pickup_scroll")


static func _dummy(dir: String) -> void:
	var s := Sheet.new(20, 30, Vector2i(10, 28))
	s.add("idle", [_dummy_frame(0)], 1.0)
	s.add("hit", [_dummy_frame(2), _dummy_frame(-1), _dummy_frame(0)], 12.0, false)
	s.save(dir, "dummy")


static func _dummy_frame(lean: int) -> Px:
	var c := Px.new(20, 30)
	c.paint(c.mask().rect(9, 16, 2, 13), Pal.WOOD, 2)
	c.paint(c.mask().rect(5, 27, 10, 2), Pal.WOOD, 1)
	var body := c.mask().ellipse(10.0 + lean, 14.0, 5.0, 6.0)
	c.paint(body, Pal.EARTH, 4, true)
	for y in range(10, 19, 3):
		c.line(6 + lean, y, 14 + lean, y, Pal.EARTH[2])
	c.paint(c.mask().rect(3 + lean, 11, 14, 2), Pal.WOOD, 3)
	var head := c.mask().ellipse(10.0 + lean, 5.5, 3.5, 3.5)
	c.paint(head, Pal.EARTH, 4)
	c.put(9 + lean, 5, Pal.INK)
	c.put(11 + lean, 5, Pal.INK)
	c.outline(Pal.INK)
	return c


## Floor spike trap (flat, seen from above): holes, warning glint, spikes up.
static func _spikes(dir: String) -> void:
	var s := Sheet.new(16, 16, Vector2i(8, 8))
	var holes := [Vector2i(3, 3), Vector2i(8, 3), Vector2i(12, 4), Vector2i(5, 8), Vector2i(10, 8), Vector2i(3, 12), Vector2i(8, 12), Vector2i(12, 12)]
	var down := Px.new(16, 16)
	down.rect(1, 1, 14, 14, Pal.STONE[1])
	down.rect(1, 1, 14, 1, Pal.STONE[2])
	for h in holes:
		down.put(h.x, h.y, Pal.INK)
		down.put(h.x + 1, h.y, Pal.INK)
	s.add("down", [down], 1.0)
	var warn := Px.new(16, 16)
	warn.blit(down, 0, 0)
	for h in holes:
		warn.lit(h.x, h.y, Pal.BLOOD[3])
	s.add("warn", [warn], 1.0)
	var up := Px.new(16, 16)
	up.blit(down, 0, 0)
	for h in holes:
		up.put(h.x, h.y - 1, Pal.STEEL[5])
		up.put(h.x, h.y, Pal.STEEL[4])
		up.put(h.x + 1, h.y, Pal.STEEL[2])
		up.put(h.x, h.y + 1, Pal.STEEL[1])
	s.add("up", [up], 1.0)
	s.save(dir, "spikes")


static func _ember_well(dir: String) -> void:
	var s := Sheet.new(26, 22, Vector2i(13, 20))
	var fr: Array = []
	for i in 4:
		fr.append(_well_frame(i, true))
	s.add("idle", fr, 5.0)
	s.add("empty", [_well_frame(0, false)], 1.0)
	s.save(dir, "ember_well")


static func _well_frame(i: int, full: bool) -> Px:
	var c := Px.new(26, 22)
	var rim := c.mask().ellipse(13.0, 13.0, 11.5, 6.0)
	rim.rect(2, 13, 23, 6)
	c.paint(rim, Pal.STONE, 3, true)
	for x in range(3, 24, 4):
		c.line(x, 14, x, 18, Pal.STONE[1])
	var pool := c.mask().ellipse(13.0, 12.5, 9.0, 4.0)
	if full:
		c.fill_lit(pool, Pal.EMBER[2])
		c.fill_lit(c.mask().ellipse(13.0, 12.5, 5.0, 2.0), Pal.EMBER[3 + (i % 2)])
		c.lit(8 + i * 3, 12, Pal.EMBER[5])
		c.lit(17 - i, 13, Pal.EMBER[4])
	else:
		c.fill(pool, Pal.INK)
	c.outline(Pal.INK)
	return c


static func _trial_altar(dir: String) -> void:
	var s := Sheet.new(20, 30, Vector2i(10, 28))
	var fr: Array = []
	for i in 4:
		var c := Px.new(20, 30)
		c.paint(c.mask().rect(3, 20, 14, 8), Pal.STONE, 2, true)
		c.paint(c.mask().rect(5, 8, 10, 13), Pal.STONE, 3, true)
		var skull := c.mask().ellipse(10.0, 6.0, 4.0, 3.6)
		c.paint(skull, Pal.BONE, 3)
		c.put(8, 6, Pal.INK)
		c.put(11, 6, Pal.INK)
		c.lit(8, 6, Pal.BLOOD[3 + (i % 2)])
		c.lit(11, 6, Pal.BLOOD[3 + (i % 2)])
		for k in 3:
			c.lit(7 + k * 3, 12 + ((k + i) % 3) * 3, Pal.BLOOD[3])
		c.outline(Pal.INK)
		fr.append(c)
	s.add("idle", fr, 4.0)
	s.add("spent", [fr[0]], 1.0)
	s.save(dir, "trial_altar")
