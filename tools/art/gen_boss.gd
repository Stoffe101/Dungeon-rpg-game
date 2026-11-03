## The Gloam Warden: a towering knight in blackened plate, horned helm with a
## soul-lit visor, a caged soul-lantern at the hip and a great halberd.
## 64x64 frames, feet at (32, 60), facing right.
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
	var s := Sheet.new(64, 64, Vector2i(32, 60))
	var idle: Array = []
	for i in 4:
		idle.append(frame({"bob": [0, 1, 1, 0][i], "hal": 80.0, "cape": i % 2, "glow": i % 2}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 4:
		walk.append(frame({"bob": i % 2, "hal": 75.0, "step": sin(i / 4.0 * TAU), "cape": i % 2}))
	s.add("walk", walk, 6.0)
	s.add("windup", [frame({"hal": 150.0, "lean": -2, "bob": 1}), frame({"hal": 165.0, "lean": -3, "bob": 2, "glow": 1})], 5.0, false)
	s.add("sweep", [frame({"hal": 20.0, "lean": 2}), frame({"hal": -15.0, "lean": 3}), frame({"hal": -35.0, "lean": 2})], 12.0, false)
	s.add("thrust", [frame({"hal": 0.0, "lean": 4, "reach": 6}), frame({"hal": 0.0, "lean": 3, "reach": 4})], 10.0, false)
	s.add("crouch", [frame({"hal": 120.0, "bob": 5, "lean": -1})], 1.0, false)
	s.add("air", [frame({"hal": 140.0, "bob": -1, "tuck": true})], 1.0, false)
	s.add("slam", [frame({"hal": -60.0, "bob": 4, "lean": 3}), frame({"hal": -55.0, "bob": 3, "lean": 2})], 8.0, false)
	s.add("cast", [frame({"hal": 80.0, "lantern_up": true, "glow": 1}), frame({"hal": 80.0, "lantern_up": true, "glow": 2})], 6.0)
	s.add("roar", [frame({"hal": 95.0, "roar": true, "bob": -1, "glow": 2}), frame({"hal": 100.0, "roar": true, "bob": 0, "glow": 1})], 6.0)
	s.add("stagger", [frame({"hal": 20.0, "bob": 4, "lean": -3, "slump": true}), frame({"hal": 15.0, "bob": 5, "lean": -3, "slump": true})], 3.0)
	s.save(dir, "warden")


static func frame(p: Dictionary) -> Px:
	var c := Px.new(64, 64)
	var b: int = int(p.get("bob", 0))
	var ln: int = int(p.get("lean", 0))
	var hal: float = p.get("hal", 80.0)
	var st: float = p.get("step", 0.0)
	var cape: int = int(p.get("cape", 0))
	var glow: int = int(p.get("glow", 0))
	var tuck: bool = p.get("tuck", false)
	var roar: bool = p.get("roar", false)
	var slump: bool = p.get("slump", false)
	var cx := 30 + ln
	# --- cape (behind) ---
	var cp := c.mask().poly(V([[cx - 6, 20 + b], [cx + 4, 20 + b], [cx - 2, 50 + b], [cx - 14 - cape, 54 + b], [cx - 16 - cape, 40 + b]]))
	for x in range(cx - 18, cx + 2):
		if (x + cape) % 3 == 0:
			cp.set_bit(x, 54 + b, false)
			cp.set_bit(x, 53 + b, false)
	c.paint(cp, Pal.GLOAM, 1, true)
	# --- legs ---
	if tuck:
		c.paint(c.mask().rect(cx - 6, 40 + b, 6, 8), Pal.STEEL, 1, true)
		c.paint(c.mask().rect(cx + 2, 40 + b, 6, 8), Pal.STEEL, 1, true)
	else:
		var la := cx - 7 + roundi(st * 3.0)
		var lb := cx + 3 - roundi(st * 3.0)
		for lx in [la, lb]:
			c.paint(c.mask().rect(lx, 44 + b / 2, 6, 61 - (44 + b / 2)), Pal.STEEL, 1, true)
			c.paint(c.mask().rect(lx - 1, 57, 8, 4), Pal.STEEL, 2)
			c.put(lx + 2, 50 + b / 2, Pal.GOLD[2])
	# --- tasset skirt ---
	var sk := c.mask().poly(V([[cx - 9, 36 + b], [cx + 9, 36 + b], [cx + 11, 47 + b], [cx - 11, 47 + b]]))
	for x in range(cx - 11, cx + 12, 3):
		sk.set_bit(x, 47 + b, false)
	c.paint(sk, Pal.GLOAM, 2, true)
	# --- torso ---
	var tor := c.mask().poly(V([[cx - 9, 20 + b], [cx + 9, 20 + b], [cx + 8, 37 + b], [cx - 8, 37 + b]]))
	c.paint(tor, Pal.STEEL, 2, true)
	for y in range(23 + b, 36 + b, 4):
		c.line(cx - 6, y, cx + 6, y, Pal.STEEL[1])
	c.paint(c.mask().rect(cx - 9, 35 + b, 18, 2), Pal.EARTH, 2)
	c.put(cx, 35 + b, Pal.GOLD[3])
	# --- lantern cage at the hip ---
	var lx0 := cx - 12
	var ly0 := 37 + b
	if p.get("lantern_up", false):
		lx0 = cx + 8
		ly0 = 6 + b
	c.paint(c.mask().rect(lx0, ly0, 6, 8), Pal.STEEL, 1)
	var core := c.mask().ellipse(lx0 + 3.0, ly0 + 4.0, 2.0 + glow * 0.3, 2.5 + glow * 0.3)
	c.fill_lit(core, Pal.SOUL[3 + mini(glow, 2)])
	c.lit(lx0 + 3, ly0 + 4, Pal.SOUL[5])
	for y in range(ly0, ly0 + 8, 2):
		c.put(lx0, y, Pal.STEEL[3])
		c.put(lx0 + 5, y, Pal.STEEL[3])
	c.line(lx0 + 3, ly0 - 1, lx0 + 3, ly0 - 3, Pal.STEEL[2])
	# --- pauldrons ---
	var pr := 22 + b
	c.paint(c.mask().ellipse(cx - 9.0, pr, 5.0, 4.0), Pal.STEEL, 3, true)
	c.paint(c.mask().ellipse(cx + 9.0, pr, 5.0, 4.0), Pal.STEEL, 3, true)
	c.put(cx - 9, pr - 1, Pal.GOLD[3])
	c.put(cx + 9, pr - 1, Pal.GOLD[3])
	# --- helm with horns ---
	var hy := 16 + b + (2 if slump else 0)
	var hx := cx + 1 + (1 if roar else 0)
	var horn_l := c.mask().poly(V([[hx - 4, hy - 3], [hx - 10, hy - 8], [hx - 11, hy - 14], [hx - 8, hy - 10], [hx - 2, hy - 6]]))
	var horn_r := c.mask().poly(V([[hx + 4, hy - 3], [hx + 9, hy - 9], [hx + 9, hy - 15], [hx + 6, hy - 10], [hx + 2, hy - 6]]))
	c.paint(horn_l, Pal.BONE, 2)
	c.paint(horn_r, Pal.BONE, 3)
	var helm := c.mask().ellipse(hx, hy, 6.0, 7.0)
	helm.rect(hx - 5, hy, 11, 6)
	c.paint(helm, Pal.STEEL, 1, true)
	# soul-lit visor
	for x in range(hx - 1, hx + 6):
		c.put(x, hy + 1, Pal.INK)
		c.put(x, hy + 2, Pal.INK)
	for x in range(hx + 1, hx + 5):
		c.lit(x, hy + 1, Pal.SOUL[4 if glow == 0 else 5])
	if roar:
		for x in range(hx, hx + 6):
			c.lit(x, hy + 2, Pal.SOUL[3])
	# --- halberd ---
	var hand := Vector2(cx + 9 + int(p.get("reach", 0)), 31 + b)
	var a := deg_to_rad(hal)
	var d := Vector2(cos(a), -sin(a))
	var top := hand + d * 19.0
	var bot := hand - d * 11.0
	var shaft := c.mask()
	shaft.line(int(bot.x), int(bot.y), int(top.x), int(top.y))
	shaft.line(int(bot.x) + 1, int(bot.y), int(top.x) + 1, int(top.y))
	shaft.line(int(bot.x), int(bot.y) + 1, int(top.x), int(top.y) + 1)
	c.paint(shaft, Pal.WOOD, 2, false, false)
	# axe blade near the top, perpendicular to the shaft
	var n := Vector2(-d.y, d.x)
	if n.x < 0.0:
		n = -n
	var b0 := top - d * 3.0
	var blade := c.mask().poly(PackedVector2Array([b0 - d * 5.0, b0 + n * 9.0 - d * 7.0, b0 + n * 10.0, b0 + n * 8.0 + d * 4.0, b0 + d * 2.0]))
	c.paint(blade, Pal.STEEL, 3, true)
	var spike := c.mask().poly(PackedVector2Array([top - n * 1.0, top + d * 6.0, top + n * 1.5]))
	c.paint(spike, Pal.STEEL, 4)
	# gauntlet on the shaft
	c.paint(c.mask().ellipse(hand.x, hand.y, 2.6, 2.6), Pal.STEEL, 3)
	# arm from shoulder to hand
	var arm := c.mask()
	arm.line(cx + 9, pr + 2, int(hand.x), int(hand.y))
	arm.line(cx + 10, pr + 2, int(hand.x) + 1, int(hand.y))
	arm.line(cx + 9, pr + 3, int(hand.x), int(hand.y) + 1)
	c.paint(arm, Pal.STEEL, 2, false, false)
	c.outline(Pal.INK)
	return c
