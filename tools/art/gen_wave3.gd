## Three foes that each ask something new of the Kindled: the Tollkeeper of the
## Ossuary (a bell whose ring you dodge through), the Lurecap of the Rootmire (a
## glowcap until you stand beside it) and the Ash Herald of the Throne (a decree
## that marks one Kindled for the whole court). All face right.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")
const GenThrone = preload("res://tools/art/gen_throne.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func limb(c: Px, pts: Array, r: Array, base: int, thick := 2) -> void:
	var m := c.mask()
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		m.line(a[0], a[1], b[0], b[1])
		if thick >= 2:
			m.line(a[0] + 1, a[1], b[0] + 1, b[1])
	c.paint(m, r, base, false, true)


static func build(dir: String) -> void:
	_tollkeeper(dir)
	_lurecap(dir)
	_herald(dir)


# --- Tollkeeper: a bent bearer under a funeral bell --------------------------------

static func _tollkeeper(dir: String) -> void:
	var s := Sheet.new(30, 32, Vector2i(14, 30))
	var idle: Array = []
	for i in 4:
		idle.append(toll_frame({"bob": [0, 1, 1, 0][i], "bell": 0, "hem": i}))
	s.add("idle", idle, 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(toll_frame({"bob": i % 2, "bell": [0, 1, 0, -1][i], "hem": i, "step": sin(i / 4.0 * TAU)}))
	s.add("walk", walk, 6.0)
	# the bell comes up in both arms over the head: the warning is the whole shape
	s.add("windup", [toll_frame({"raise": 1, "bob": 0}), toll_frame({"raise": 2, "bob": 1}), toll_frame({"raise": 3, "bob": 1})], 4.0, false)
	s.add("toll", [toll_frame({"raise": 0, "bob": 2, "bell": 2, "struck": true}), toll_frame({"raise": 0, "bob": 1, "bell": 1, "struck": true})], 8.0, false)
	s.save(dir, "tollkeeper")


static func toll_frame(p: Dictionary) -> Px:
	var c := Px.new(30, 32)
	var b: int = int(p.get("bob", 0))
	var hem: int = int(p.get("hem", 0))
	var st: float = p.get("step", 0.0)
	var raise: int = int(p.get("raise", 0))
	var swing: int = int(p.get("bell", 0))
	# robe: long, bent forward under the weight
	var robe := c.mask().poly(V([[9, 11 + b], [16, 11 + b], [19, 29], [6, 29]]))
	for x in range(6, 20):
		if (x + hem) % 3 == 0:
			robe.set_bit(x, 28, false)
	c.paint(robe, Pal.CLOAK, 3, true)
	var fa := 9 + roundi(st * 2.0)
	var fb := 14 - roundi(st * 2.0)
	c.paint(c.mask().rect(fa, 28, 3, 2), Pal.BONE, 2)
	c.paint(c.mask().rect(fb, 28, 3, 2), Pal.BONE, 2)
	# a rope belt with a small hand-bell's worth of knots
	c.line(8, 19 + b, 17, 19 + b, Pal.BONE[1])
	for x in [10, 13, 16]:
		c.put(x, 20 + b, Pal.BONE[2])
	# hood and a skull's face, bowed
	var hood := c.mask().ellipse(13.0, 7.5 + b, 4.4, 4.4)
	hood.poly(V([[9, 8 + b], [16, 8 + b], [17, 12 + b], [8, 12 + b]]))
	c.paint(hood, Pal.CLOAK, 3, true)
	c.paint(c.mask().ellipse(14.5, 8.5 + b, 2.2, 2.2), Pal.BONE, 3)
	c.put(15, 8 + b, Pal.INK)
	c.lit(16, 8 + b, Pal.SOUL[5])
	# the bell, and the arms that carry it
	var bx := 22 + swing
	var by := 14 + b
	if raise > 0:
		bx = 20 - raise
		by = 12 - raise * 3 + b
	var bell := c.mask().poly(V([[bx - 2, by], [bx + 2, by], [bx + 4, by + 8], [bx - 4, by + 8]]))
	bell.ellipse(bx, by, 2.6, 2.2)
	c.paint(bell, Pal.GOLD, 2, true)
	c.line(bx - 4, by + 8, bx + 4, by + 8, Pal.GOLD[3])
	c.line(bx - 2, by + 3, bx + 2, by + 3, Pal.GOLD[1])
	c.put(bx, by - 2, Pal.GOLD[4])
	c.lit(bx + (1 if p.get("struck", false) else 0), by + 9, Pal.SOUL[5])
	if p.get("struck", false):
		# the note going out
		c.lit(bx - 6, by + 4, Pal.SOUL[4])
		c.lit(bx - 6, by + 6, Pal.SOUL[4])
		c.lit(mini(bx + 6, 29), by + 4, Pal.SOUL[4])
		c.lit(mini(bx + 6, 29), by + 6, Pal.SOUL[4])
	if raise > 0:
		limb(c, [[11, 13 + b], [12 + raise, 9 - raise + b], [bx - 2, by + 4]], Pal.BONE, 2, 1)
		limb(c, [[15, 13 + b], [16, 10 - raise + b], [bx + 2, by + 4]], Pal.BONE, 2, 1)
	else:
		limb(c, [[14, 13 + b], [17, 13 + b], [bx - 2, by + 3]], Pal.BONE, 2, 1)
		limb(c, [[12, 14 + b], [16, 16 + b], [bx - 3, by + 6]], Pal.BONE, 2, 1)
	c.outline(Pal.INK)
	return c


# --- Lurecap: three glowcaps, until they are not -----------------------------------

static func _lurecap(dir: String) -> void:
	var s := Sheet.new(22, 26, Vector2i(11, 25))
	var idle: Array = []
	for i in 4:
		idle.append(lure_frame({"sway": [0, 1, 0, -1][i]}))
	s.add("idle", idle, 3.0)
	s.add("rise", [lure_frame({"up": 1}), lure_frame({"up": 2, "maw": 1}), lure_frame({"up": 3, "maw": 2})], 7.0, false)
	s.add("bite", [lure_frame({"up": 3, "maw": 3, "lean": 2}), lure_frame({"up": 2, "maw": 1, "lean": 1})], 10.0, false)
	var walk: Array = []
	for i in 4:
		walk.append(lure_frame({"up": 2, "maw": 1, "step": i, "bob": i % 2}))
	s.add("walk", walk, 10.0)
	s.save(dir, "lurecap")


## At rest this is the Rootmire's glowcap, cap for cap (tools/art/gen_rootmire.gd),
## but for one thing a careful eye can find: a pale eye under the great cap.
static func lure_frame(p: Dictionary) -> Px:
	var c := Px.new(22, 26)
	var sway: int = int(p.get("sway", 0))
	var up: int = int(p.get("up", 0))
	var maw: int = int(p.get("maw", 0))
	var ln: int = int(p.get("lean", 0))
	var b: int = int(p.get("bob", 0))
	var st: int = int(p.get("step", -1))
	var floor_y := 25
	if up > 0:
		# roots unfold into legs
		for k in 4:
			var lx: int = 5 + k * 4
			var off: int = 0 if st < 0 else [[1, -1, 1, -1], [0, 0, 0, 0], [-1, 1, -1, 1], [0, 0, 0, 0]][st][k]
			limb(c, [[lx + ln, floor_y - 4 - b], [lx + off - 1, floor_y - 2], [lx + off - 2, floor_y]], Pal.WOOD, 3, 1)
		var body := c.mask().ellipse(11.0 + ln, floor_y - 7.0 - up - b, 5.0, 4.5)
		c.paint(body, Pal.BONE, 2, true)
	for cap in [[7, 16, 4.5, 3.0, Pal.SOUL], [14, 12, 5.5, 3.6, Pal.GLOAM], [16, 19, 3.0, 2.0, Pal.SOUL]]:
		var cx: float = float(cap[0]) + sway * (0.5 if cap[1] < 14 else 0.0) + ln
		var cy: float = float(cap[1]) - up * 2 - b
		if up > 0:
			cx = lerpf(cx, 11.0 + ln, up / 3.5)
		var stem := c.mask().rect(int(cx) - 1, int(cy), 2, floor_y - int(cy))
		if up == 0:
			c.paint(stem, Pal.BONE, 2)
		var top := c.mask().ellipse(cx, cy, cap[2], cap[3])
		top.subtract(c.mask().rect(0, int(cy) + 1, 22, 26))
		var r: Array = cap[4]
		c.fill_lit(top, r[3])
		for x in range(int(cx - cap[2]) + 1, int(cx + cap[2])):
			if top.has(x, int(cy)):
				c.lit(x, int(cy), r[2])
		c.lit(int(cx) - 1, int(cy - cap[3] + 1), r[5])
		c.lit(int(cx) + 1, int(cy - 1), r[4])
	if up == 0:
		# the one tell: it is watching
		c.lit(13 + sway, 14, Pal.BONE[4])
	if maw > 0:
		var my: int = floor_y - 8 - up - b
		var mx: int = 13 + ln
		c.fill(c.mask().rect(mx - 3, my, 7, maw + 1), Pal.INK)
		for x in range(mx - 3, mx + 4, 2):
			c.put(x, my, Pal.BONE[4])
			c.put(x + 1, my + maw, Pal.BONE[4])
		c.lit(mx - 1, my - 2, Pal.BLOOD[4])
		c.lit(mx + 2, my - 2, Pal.BLOOD[4])
	c.outline(Pal.INK)
	return c


# --- Ash Herald: a thin courtier with a long horn -----------------------------------

static func _herald(dir: String) -> void:
	var s := Sheet.new(30, 30, Vector2i(12, 28))
	var idle: Array = []
	for i in 4:
		idle.append(herald_frame({"bob": [0, 1, 1, 0][i], "hem": i}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 4:
		walk.append(herald_frame({"bob": i % 2, "hem": i, "step": sin(i / 4.0 * TAU)}))
	s.add("walk", walk, 7.0)
	# the horn comes up, the chest fills, the head tips back
	s.add("windup", [herald_frame({"horn": 1}), herald_frame({"horn": 2, "bob": -1}), herald_frame({"horn": 3, "bob": -1})], 4.0, false)
	s.add("blow", [herald_frame({"horn": 3, "bob": 0, "note": 1}), herald_frame({"horn": 3, "bob": 0, "note": 2})], 8.0, false)
	s.save(dir, "herald")


static func herald_frame(p: Dictionary) -> Px:
	var c := Px.new(30, 30)
	var b: int = int(p.get("bob", 0))
	var hem: int = int(p.get("hem", 0))
	var st: float = p.get("step", 0.0)
	var horn: int = int(p.get("horn", 0))
	var note: int = int(p.get("note", 0))
	var PL: Array = GenThrone.PLATE
	# a long tabard over thin legs
	var fa := 9 + roundi(st * 2.0)
	var fb := 13 - roundi(st * 2.0)
	limb(c, [[10, 19 + b], [fa, 28]], PL, 2, 1)
	limb(c, [[13, 19 + b], [fb, 28]], PL, 2, 1)
	var coat := c.mask().poly(V([[8, 10 + b], [15, 10 + b], [17, 23 + b], [6, 23 + b]]))
	for x in range(6, 18):
		if (x + hem) % 4 == 0:
			coat.set_bit(x, 23 + b, false)
	c.paint(coat, PL, 3, true)
	c.line(11, 11 + b, 11, 22 + b, Pal.GOLD[3])
	c.line(7, 22 + b, 16, 22 + b, Pal.GOLD[2])
	c.paint(c.mask().ellipse(11.0, 15.0 + b, 2.0, 2.0), Pal.GOLD, 3)
	c.lit(11, 15 + b, Pal.EMBER[4])
	# a mask of beaten gold under a sun-crest
	var hy := 6 + b
	var head := c.mask().ellipse(12.0, hy, 3.4, 3.8)
	c.paint(head, Pal.GOLD, 3, true)
	c.put(13, hy, Pal.INK)
	c.lit(14, hy, Pal.EMBER[4])
	for a in [-2, -1, 0, 1, 2]:
		c.lit(12 + a * 2, hy - 5 + absi(a), Pal.GOLD[4])
	# the horn
	var hx := 15
	var hyy := hy + 3
	match horn:
		0:
			limb(c, [[14, 12 + b], [17, 19 + b]], PL, 3, 1)
			c.line(16, 14 + b, 18, 27, Pal.GOLD[3])
			c.line(17, 14 + b, 19, 27, Pal.GOLD[2])
			c.paint(c.mask().rect(17, 25, 4, 3), Pal.GOLD, 3)
		1:
			limb(c, [[14, 12 + b], [18, 13 + b]], PL, 3, 1)
			c.line(15, 13 + b, 27, 17 + b, Pal.GOLD[3])
			c.paint(c.mask().rect(25, 15 + b, 3, 4), Pal.GOLD, 3)
		2:
			limb(c, [[14, 12 + b], [17, 11 + b]], PL, 3, 1)
			c.line(hx, hyy + 1, 27, hyy - 2, Pal.GOLD[3])
			c.paint(c.mask().rect(25, hyy - 4, 3, 4), Pal.GOLD, 3)
		_:
			limb(c, [[14, 12 + b], [17, 10 + b]], PL, 3, 1)
			c.line(hx, hyy, 27, hyy - 5, Pal.GOLD[4])
			c.line(hx, hyy + 1, 27, hyy - 4, Pal.GOLD[3])
			c.paint(c.mask().rect(25, hyy - 7, 4, 5), Pal.GOLD, 3)
	if note > 0:
		for k in 3:
			c.lit(mini(26 + note, 29), hyy - 9 + k * 3 - note, Pal.EMBER[4])
	c.outline(Pal.INK)
	return c
