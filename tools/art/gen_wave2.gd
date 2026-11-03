## The second wave of the Undervault's creatures, each with a role the first
## lacked: the Gravemole (burrowing ambusher) and the Lampwight (a support that
## shields its allies) in the Ossuary; the Spore Mortar (artillery) and the
## Bramblewright (raises bramble walls) in the Rootmire; the Gilded Duelist
## (riposte stance) and the Sunwatcher (sweeping beam) in the Sunken Throne.
## All face right.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
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
	_gravemole(dir)
	_lampwight(dir)
	_mortar(dir)
	_bramblewright(dir)
	_duelist(dir)
	_sunwatcher(dir)


# --- Gravemole: a skeletal digger with shovel claws ---------------------------

static func _gravemole(dir: String) -> void:
	var s := Sheet.new(28, 22, Vector2i(14, 20))
	s.add("idle", [_mole({}), _mole({"bob": 1})], 3.0)
	s.add("emerge", [_mole({"sink": 8}), _mole({"sink": 3, "claws": "up"})], 8.0, false)
	s.add("burrow", [_mole({"sink": 3}), _mole({"sink": 9})], 8.0, false)
	s.add("mound", [_mound(0), _mound(1)], 6.0)
	s.add("swipe", [_mole({"claws": "swipe"}), _mole({"claws": "swipe2"})], 10.0, false)
	s.save(dir, "gravemole")


static func _mole(p: Dictionary) -> Px:
	var c := Px.new(28, 22)
	var sink: int = int(p.get("sink", 0))
	var b: int = int(p.get("bob", 0)) + sink
	var claws: String = p.get("claws", "rest")
	# hunched ribcage body
	var body := c.mask().ellipse(12.0, 13.0 + b, 7.0, 5.0)
	c.paint(body, Pal.BONE, 2, true)
	for x in range(8, 17, 2):
		c.line(x, 11 + b, x, 15 + b, Pal.BONE[0])
	# long snouted skull with soul-lit eyes
	var head := c.mask().poly(V([[16, 9 + b], [25, 11 + b], [24, 14 + b], [16, 15 + b]]))
	c.paint(head, Pal.BONE, 3, true)
	c.lit(19, 11 + b, Pal.SOUL[4])
	for x in range(20, 25, 2):
		c.put(x, 14 + b, Pal.BONE[4])
	# shovel claws
	match claws:
		"up":
			limb(c, [[14, 13 + b], [18, 7 + b], [21, 4 + b]], Pal.BONE, 3)
			c.paint(c.mask().rect(20, 1 + b, 4, 4), Pal.STONE, 4)
		"swipe":
			limb(c, [[14, 13 + b], [20, 13 + b], [25, 9 + b]], Pal.BONE, 3)
			c.paint(c.mask().rect(24, 7 + b, 4, 4), Pal.STONE, 4)
		"swipe2":
			limb(c, [[14, 13 + b], [20, 17 + b], [25, 19 + b]], Pal.BONE, 3)
			c.paint(c.mask().rect(24, 17 + b, 4, 4), Pal.STONE, 4)
		_:
			limb(c, [[14, 14 + b], [18, 17 + b], [20, 19 + b]], Pal.BONE, 3)
			c.paint(c.mask().rect(19, 18 + b, 4, 3), Pal.STONE, 4)
	limb(c, [[8, 16 + b], [6, 19 + b]], Pal.BONE, 2, 1)
	if sink > 0:
		# the ground still covers the lower half
		for y in range(20 - sink + 2, 22):
			for x in 28:
				c.put(x, y, Color(0, 0, 0, 0))
		c.paint(c.mask().ellipse(13.0, 19.0, 11.0, 2.5), Pal.EARTH, 2, true)
	c.outline(Pal.INK)
	return c


## The travelling mound of earth that shows where it digs.
static func _mound(i: int) -> Px:
	var c := Px.new(28, 22)
	c.paint(c.mask().ellipse(14.0, 18.0, 8.0 + i, 3.5), Pal.EARTH, 2, true)
	for k in 5:
		c.put(8 + k * 3, 15 + (k + i) % 3, Pal.STONE[2])
	c.put(13 + i, 15, Pal.BONE[3])
	c.outline(Pal.INK)
	return c


# --- Lampwight: a hooded caretaker carrying a soul-lamp on a pole -------------

static func _lampwight(dir: String) -> void:
	var s := Sheet.new(20, 30, Vector2i(10, 28))
	var idle: Array = []
	for i in 4:
		idle.append(_wight(i, false))
	s.add("idle", idle, 5.0)
	s.add("cast", [_wight(0, true), _wight(1, true)], 6.0)
	s.save(dir, "lampwight")


static func _wight(i: int, cast: bool) -> Px:
	var c := Px.new(20, 30)
	var b: int = [0, 1, 1, 0][i % 4]
	# tattered robe fading into soul-smoke
	var robe := c.mask().poly(V([[6, 10 + b], [12, 10 + b], [14, 25], [9 + (i % 2), 28], [4, 25]]))
	c.paint(robe, Pal.STONE, 2, true)
	for y in range(22, 29):
		for x in 20:
			if robe.has(x, y) and Px.bayer(x + i, y) < (y - 21) / 8.0:
				c.put(x, y, Color(0, 0, 0, 0))
	# hood and the faint face inside
	c.paint(c.mask().ellipse(9.0, 8.0 + b, 4.0, 4.5), Pal.STONE, 3, true)
	c.fill(c.mask().ellipse(10.0, 9.0 + b, 2.2, 2.4), Pal.INK)
	c.lit(10, 9 + b, Pal.SOUL[3])
	# the lamp pole, raised when it binds an ally
	var top := 2 if cast else 6
	c.line(14, top + b, 14, 24, Pal.WOOD[2])
	var lamp := c.mask().rect(13, top - 3 + b, 4, 4)
	c.paint(lamp, Pal.STEEL, 2)
	c.fill_lit(c.mask().rect(14, top - 2 + b, 2, 2), Pal.SOUL[5] if cast else Pal.SOUL[4])
	c.outline(Pal.INK)
	return c


# --- Spore Mortar: a rooted bulb that coughs spore bombs into the air ----------

static func _mortar(dir: String) -> void:
	var s := Sheet.new(26, 26, Vector2i(13, 24))
	s.add("idle", [_bulb(0), _bulb(1)], 2.0)
	s.add("charge", [_bulb(2), _bulb(3)], 6.0, false)
	s.add("fire", [_bulb(4), _bulb(1)], 10.0, false)
	s.save(dir, "spore_mortar")
	# the bomb: a tumbling spore pod with a glowing seam
	var sp := Sheet.new(10, 10, Vector2i(5, 5))
	var fr: Array = []
	for i in 2:
		var c := Px.new(10, 10)
		c.paint(c.mask().ellipse(5.0, 5.0, 3.6, 3.2 + i * 0.4), Pal.MOSS, 2, true)
		c.lit(3 + i, 4, Pal.MOSS[5])
		c.lit(6 - i, 6, Pal.MOSS[5])
		c.lit(5, 3 + i * 2, Pal.MOSS[4])
		c.outline(Pal.INK)
		fr.append(c)
	sp.add("idle", fr, 8.0)
	sp.save(dir, "proj_spore")


static func _bulb(f: int) -> Px:
	var c := Px.new(26, 26)
	var swell: int = [0, 1, 2, 3, -1][f]
	# roots gripping the floor
	for x in [4, 9, 16, 21]:
		c.line(13, 22, x, 25, Pal.WOOD[2])
	var body := c.mask().ellipse(13.0, 16.0 - swell * 0.5, 8.0 + swell * 0.6, 7.0 + swell * 0.5)
	c.paint(body, Pal.MOSS, 2, true)
	# glowing spore sacs and the vent on top
	for p in [[9, 15], [16, 13], [13, 19], [18, 18]]:
		c.lit(p[0], p[1] - swell / 2, Pal.MOSS[5] if f >= 2 else Pal.MOSS[4])
	var vent := c.mask().ellipse(13.0, 9.0 - swell * 0.8, 3.5, 2.0)
	c.paint(vent, Pal.BLOOD, 2)
	c.fill(c.mask().ellipse(13.0, 9.0 - swell * 0.8, 2.0, 1.0), Pal.INK)
	if f == 4:
		for k in 4:
			c.lit(11 + k, 5 - (k % 2), Pal.MOSS[5])
	c.outline(Pal.INK)
	return c


# --- Bramblewright: a hunched figure of roots that sings brambles up ----------

static func _bramblewright(dir: String) -> void:
	var s := Sheet.new(24, 30, Vector2i(12, 28))
	var idle: Array = []
	for i in 4:
		idle.append(_wright({"sway": [0, 1, 0, -1][i]}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 4:
		walk.append(_wright({"step": i, "sway": i % 2}))
	s.add("walk", walk, 7.0)
	s.add("cast", [_wright({"raise": true}), _wright({"raise": true, "glow": true})], 6.0)
	s.add("whip", [_wright({"whip": 1}), _wright({"whip": 2})], 10.0, false)
	s.save(dir, "bramblewright")


static func _wright(p: Dictionary) -> Px:
	var c := Px.new(24, 30)
	var sw: int = int(p.get("sway", 0))
	var st: int = int(p.get("step", -1))
	# legs of root
	var la := 9 + (1 if st == 0 else (-1 if st == 2 else 0))
	var lb := 14 - (1 if st == 0 else (-1 if st == 2 else 0))
	limb(c, [[10, 20], [la, 27]], Pal.WOOD, 2)
	limb(c, [[13, 20], [lb, 27]], Pal.WOOD, 2)
	# hunched trunk wound with thorny vines
	var body := c.mask().poly(V([[7 + sw, 9], [15 + sw, 8], [16, 21], [8, 21]]))
	c.paint(body, Pal.WOOD, 2, true)
	for y in range(10, 21, 3):
		c.line(8, y, 15, y + 1, Pal.MOSS[2])
		c.put(15, y, Pal.BONE[3])
	# a mask of bark with glowing eyes, a crown of thorns
	c.paint(c.mask().ellipse(12.0 + sw, 6.0, 4.0, 3.5), Pal.WOOD, 3, true)
	c.lit(11 + sw, 6, Pal.MOSS[5])
	c.lit(14 + sw, 6, Pal.MOSS[5])
	for k in 4:
		c.line(9 + k * 2 + sw, 3, 8 + k * 2 + sw, 0, Pal.WOOD[1])
	# arms
	if p.get("raise", false):
		limb(c, [[8, 11], [5, 6], [4, 2]], Pal.WOOD, 2, 1)
		limb(c, [[15, 11], [18, 6], [19, 2]], Pal.WOOD, 2, 1)
		if p.get("glow", false):
			c.lit(4, 1, Pal.MOSS[5])
			c.lit(19, 1, Pal.MOSS[5])
	elif int(p.get("whip", 0)) > 0:
		var wy := 10 if int(p.get("whip")) == 1 else 16
		limb(c, [[15, 12], [19, wy], [23, wy + 1]], Pal.WOOD, 2, 1)
		c.put(23, wy, Pal.BONE[3])
	else:
		limb(c, [[15, 12], [17, 17], [17, 21]], Pal.WOOD, 2, 1)
	c.outline(Pal.INK)
	return c


# --- Gilded Duelist: a slender fencer in black and gold with a rapier ----------

static func _duelist(dir: String) -> void:
	var s := Sheet.new(24, 30, Vector2i(12, 28))
	s.add("idle", [_fencer({}), _fencer({"bob": 1})], 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(_fencer({"step": i, "bob": i % 2}))
	s.add("walk", walk, 8.0)
	s.add("stance", [_fencer({"stance": true}), _fencer({"stance": true, "glint": true})], 6.0)
	s.add("lunge", [_fencer({"lunge": true}), _fencer({"lunge": true, "bob": 1})], 12.0, false)
	s.add("riposte", [_fencer({"riposte": 1}), _fencer({"riposte": 2})], 14.0, false)
	s.save(dir, "duelist")


static func _fencer(p: Dictionary) -> Px:
	var c := Px.new(24, 30)
	var b: int = int(p.get("bob", 0))
	var st: int = int(p.get("step", -1))
	var lunge: bool = p.get("lunge", false)
	var lean := 2 if lunge else 0
	# legs: long, in a fencer's stance
	var fa := 8 + (1 if st == 0 else (-1 if st == 2 else 0)) - lean
	var fb := 13 - (1 if st == 0 else (-1 if st == 2 else 0)) + lean * 2
	limb(c, [[10, 18 + b], [9, 23], [fa, 28]], Pal.OBSIDIAN, 2, 1)
	limb(c, [[12, 18 + b], [13, 23], [fb, 28]], Pal.OBSIDIAN, 2, 1)
	# a short gold cape behind
	c.paint(c.mask().poly(V([[8 + lean, 9 + b], [10 + lean, 9 + b], [7, 20 + b], [4, 19 + b]])), Pal.GOLD, 2, true)
	# slim torso, gold trim
	c.paint(c.mask().rect(9 + lean, 9 + b, 5, 10), Pal.OBSIDIAN, 3, true)
	c.line(9 + lean, 13 + b, 13 + lean, 13 + b, Pal.GOLD[3])
	# helm with a plume
	c.paint(c.mask().ellipse(11.0 + lean, 6.0 + b, 3.0, 3.2), Pal.OBSIDIAN, 3, true)
	c.line(11 + lean, 9 + b, 14 + lean, 9 + b, Pal.GOLD[2])
	c.lit(12 + lean, 6 + b, Pal.GOLD[4])
	c.line(10 + lean, 3 + b, 7 + lean, 0 + b, Pal.BLOOD[3])
	c.line(11 + lean, 3 + b, 8 + lean, 1 + b, Pal.BLOOD[2])
	# the rapier
	var hand := Vector2(14 + lean, 12 + b)
	var tip := hand + Vector2(9, -1)
	if p.get("stance", false):
		tip = hand + Vector2(1, -9)
	elif lunge:
		tip = hand + Vector2(10, 0)
	elif int(p.get("riposte", 0)) == 1:
		tip = hand + Vector2(7, -7)
	elif int(p.get("riposte", 0)) == 2:
		tip = hand + Vector2(8, 6)
	c.line(int(hand.x), int(hand.y), int(tip.x), int(tip.y), Pal.STEEL[5])
	c.put(int(hand.x), int(hand.y), Pal.GOLD[3])
	if p.get("glint", false):
		c.lit(int(tip.x), int(tip.y), Pal.WHITE)
		c.lit(int(tip.x) + 1, int(tip.y), Pal.GOLD[4])
	c.outline(Pal.INK)
	return c


# --- Sunwatcher: a great eye in a gilded ring, staring a beam of old sun ------

static func _sunwatcher(dir: String) -> void:
	var s := Sheet.new(26, 26, Vector2i(13, 24))
	var idle: Array = []
	for i in 4:
		idle.append(_eye(i, 0))
	s.add("idle", idle, 4.0)
	s.add("charge", [_eye(0, 1), _eye(1, 2)], 8.0)
	s.add("fire", [_eye(0, 3), _eye(1, 3)], 12.0)
	s.save(dir, "sunwatcher")


static func _eye(i: int, mode: int) -> Px:
	var c := Px.new(26, 26)
	var b: int = [0, 1, 1, 0][i % 4]
	var cy := 11.0 + b
	# gilded ring with rays
	var ring := c.mask().ellipse(13.0, cy, 10.0, 10.0)
	ring.subtract(c.mask().ellipse(13.0, cy, 8.0, 8.0))
	c.paint(ring, Pal.GOLD, 2, true)
	for k in 8:
		var a := k * TAU / 8.0 + i * 0.1
		c.put(int(13 + cos(a) * 11.5), int(cy + sin(a) * 11.5), Pal.GOLD[3])
	# the eye itself: pale, veined, a burning iris that grows as it charges
	c.paint(c.mask().ellipse(13.0, cy, 7.0, 6.0), Pal.BONE, 3)
	c.line(7, int(cy) - 2, 10, int(cy) - 1, Pal.BLOOD[2])
	var ir := 2.5 + mode * 0.6
	c.fill_lit(c.mask().ellipse(15.0, cy, ir, ir), Pal.GOLD[3] if mode < 3 else Pal.GOLD[4])
	c.fill(c.mask().ellipse(15.5, cy, 1.0, 1.4), Pal.INK if mode < 3 else Pal.WHITE)
	# a tail of ash hanging below
	for y in range(int(cy) + 9, 25):
		if (y + i) % 2 == 0:
			c.put(13 + (y % 3) - 1, y, Pal.ASH[2])
	c.outline(Pal.INK)
	return c
