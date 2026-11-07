## Two foes that go after what a Kindled relies on: the Snuffer steals the lantern's
## flame and runs with it, the Gravehook takes away the distance a Kindled was
## keeping. All face right.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


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
	_snuffer(dir)
	_gravehook(dir)


# --- Snuffer: something thin that carries a candle-snuffer as long as itself ---------

static func _snuffer(dir: String) -> void:
	var s := Sheet.new(48, 30, Vector2i(24, 28))
	var idle: Array = []
	for i in 4:
		idle.append(snuff_frame({"bob": [0, 1, 1, 0][i], "hem": i}))
	s.add("idle", idle, 3.0)
	var walk: Array = []
	for i in 6:
		walk.append(snuff_frame({"bob": i % 2, "hem": i, "step": sin(i / 6.0 * TAU), "lean": 1}))
	s.add("walk", walk, 11.0)
	s.add("windup", [snuff_frame({"lean": -1, "pole": -2}), snuff_frame({"lean": -2, "pole": -3, "bob": 1})], 6.0, false)
	s.add("lunge", [snuff_frame({"lean": 3, "pole": 5, "step": 1.0})], 8.0, false)
	s.add("spent", [snuff_frame({"lean": 2, "pole": 3, "bob": 2}), snuff_frame({"lean": 1, "pole": 1, "bob": 1})], 4.0, false)
	var carry: Array = []
	for i in 6:
		carry.append(snuff_frame({"bob": i % 2, "hem": i, "step": sin(i / 6.0 * TAU), "lean": 2, "flame": i % 3, "pole": -4}))
	s.add("carry", carry, 13.0)
	s.save(dir, "snuffer")


## A frame wide enough for what it reaches with, its feet on the centre (a flipped
## foe mirrors about its origin).
static func _wide(c: Px, w: int, dx: int) -> Px:
	var out := Px.new(w, c.h)
	out.blit(c, dx, 0)
	return out


static func snuff_frame(p: Dictionary) -> Px:
	var c := Px.new(40, 30)
	var b: int = int(p.get("bob", 0))
	var ln: int = int(p.get("lean", 0))
	var hem: int = int(p.get("hem", 0))
	var st: float = p.get("step", 0.0)
	var pl: int = int(p.get("pole", 0))
	var flame: int = int(p.get("flame", -1))
	# two thin legs under the rags
	limb(c, [[12, 20 + b], [11 + roundi(st * 3.0), 25], [10 + roundi(st * 4.0), 28]], Pal.BONE, 2, 1)
	limb(c, [[15, 20 + b], [16 - roundi(st * 3.0), 25], [17 - roundi(st * 4.0), 28]], Pal.BONE, 2, 1)
	# rags: narrow, torn at the hem, and always leaning toward what it wants
	var robe := c.mask().poly(V([[10 + ln, 9 + b], [15 + ln, 9 + b], [18, 23 + b], [8, 23 + b]]))
	for x in range(8, 19):
		if (x + hem) % 3 == 0:
			robe.set_bit(x, 22 + b, false)
	c.paint(robe, Pal.GLOAM, 2, true)
	# hood: a long point that droops backward, a bare pale chin under it
	var hood := c.mask().ellipse(13.0 + ln, 6.5 + b, 3.8, 3.8)
	hood.poly(V([[10 + ln, 5 + b], [8 + ln, 1 + b], [6 + ln, 4 + b], [10 + ln, 8 + b]]))
	c.paint(hood, Pal.GLOAM, 2, true)
	c.paint(c.mask().ellipse(14.5 + ln, 7.5 + b, 1.6, 1.8), Pal.BONE, 3)
	c.lit(15 + ln, 7 + b, Pal.SOUL[5])
	# the snuffer: a brass bell on a pole as long as it is, held out ahead
	var hx := 17 + ln + pl
	var hy := 14 + b
	limb(c, [[13 + ln, 12 + b], [hx, hy]], Pal.BONE, 2, 1)
	c.line(hx - 6, hy + 1, hx + 8, hy - 2, Pal.WOOD[2])
	var bell := c.mask().poly(V([[hx + 8, hy - 3], [hx + 12, hy - 5], [hx + 13, hy + 1], [hx + 9, hy]]))
	c.paint(bell, Pal.GOLD, 2, true)
	if flame >= 0:
		# a stolen flame, cupped under its chin: the thing to chase
		var m := c.mask().ellipse(18.0 + ln, 12.0 + b - flame % 2, 2.4, 3.0)
		c.fill_lit(m, Pal.EMBER[3])
		c.lit(18 + ln, 12 + b - flame % 2, Pal.GOLD[4])
		c.lit(18 + ln, 9 + b - flame, Pal.EMBER[4])
	c.outline(Pal.INK)
	return _wide(c, 48, 10)


# --- Gravehook: the gaoler who never let anyone leave ------------------------------------

static func _gravehook(dir: String) -> void:
	var s := Sheet.new(56, 36, Vector2i(28, 34))
	var idle: Array = []
	for i in 4:
		idle.append(hook_frame({"bob": [0, 0, 1, 1][i], "swing": [0, 1, 0, -1][i]}))
	s.add("idle", idle, 3.0)
	var walk: Array = []
	for i in 6:
		walk.append(hook_frame({"bob": i % 2, "step": sin(i / 6.0 * TAU), "swing": [0, 1, 2, 1, 0, -1][i]}))
	s.add("walk", walk, 8.0)
	s.add("windup", [hook_frame({"arm": 1, "bob": 0}), hook_frame({"arm": 2, "bob": 1}), hook_frame({"arm": 3, "bob": 1})], 5.0, false)
	s.add("throw", [hook_frame({"arm": 5, "bob": 1, "empty": true}), hook_frame({"arm": 4, "bob": 0, "empty": true})], 9.0, false)
	s.add("haul", [hook_frame({"arm": -1, "bob": 2}), hook_frame({"arm": -2, "bob": 1})], 7.0, false)
	s.add("reap", [hook_frame({"arm": 4, "bob": 2}), hook_frame({"arm": 5, "bob": 1})], 10.0, false)
	s.save(dir, "gravehook")


static func hook_frame(p: Dictionary) -> Px:
	var c := Px.new(44, 36)
	var b: int = int(p.get("bob", 0))
	var st: float = p.get("step", 0.0)
	var swing: int = int(p.get("swing", 0))
	var arm: int = int(p.get("arm", 0))
	var empty: bool = p.get("empty", false)
	# broad legs in bound boots
	limb(c, [[12, 24 + b], [11 + roundi(st * 2.0), 30], [11 + roundi(st * 3.0), 33]], Pal.CLOAK, 2, 2)
	limb(c, [[18, 24 + b], [19 - roundi(st * 2.0), 30], [19 - roundi(st * 3.0), 33]], Pal.CLOAK, 2, 2)
	c.paint(c.mask().rect(10 + roundi(st * 3.0), 32, 4, 2), Pal.EARTH, 2)
	c.paint(c.mask().rect(18 - roundi(st * 3.0), 32, 4, 2), Pal.EARTH, 2)
	# a great barrel of a body, a leather apron over it
	var body := c.mask().ellipse(15.0, 16.5 + b, 8.5, 9.5)
	c.paint(body, Pal.STONE, 2, true)
	var apron := c.mask().poly(V([[10, 12 + b], [20, 12 + b], [22, 27 + b], [8, 27 + b]]))
	c.paint(apron, Pal.EARTH, 2, true)
	for y in [15, 19, 23]:
		c.put(14, y + b, Pal.STEEL[3])
		c.put(17, y + b, Pal.STEEL[3])
	# coils of chain at the hip
	for k in 3:
		c.paint(c.mask().ellipse(8.0, 22.0 + k * 2.0 + b, 2.5, 1.2), Pal.STEEL, 2, false, false)
	# small head, sunk between the shoulders, an iron mask with one slit
	c.paint(c.mask().ellipse(16.0, 6.5 + b, 4.0, 4.2), Pal.STEEL, 2, true)
	c.line(14, 6 + b, 19, 6 + b, Pal.INK)
	c.lit(18, 6 + b, Pal.SOUL[5])
	c.lit(16, 6 + b, Pal.SOUL[3])
	# the hook arm: behind, then far forward
	var ax := 24 + arm * 2
	var ay := 14 + b - maxi(arm, 0)
	if arm >= 3:
		ay = 8 + b
	limb(c, [[21, 11 + b], [ax, ay]], Pal.STONE, 2, 2)
	if not empty:
		var hx := ax + 1
		var hy := ay + 2 + swing
		var hook := c.mask()
		hook.line(hx, hy, hx + 2, hy + 3)
		hook.line(hx + 2, hy + 3, hx + 5, hy + 3)
		hook.line(hx + 5, hy + 3, hx + 6, hy)
		hook.line(hx + 1, hy, hx + 3, hy + 3)
		c.paint(hook, Pal.STEEL, 4, false, false)
	c.outline(Pal.INK)
	return _wide(c, 56, 12)
