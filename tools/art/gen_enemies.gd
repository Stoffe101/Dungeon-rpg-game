## Enemies of the Hollow Ossuary. All face right; the game flips them.
## Undervault creatures share teal soul-light eyes (emissive) so they read in
## the dark and contrast with the Kindled's warm ember palette.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


## A limb: thick line painted with a ramp.
static func limb(c: Px, pts: Array, r: Array, base: int, thick := 2) -> void:
	var m := c.mask()
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		m.line(a[0], a[1], b[0], b[1])
		if thick >= 2:
			m.line(a[0] + 1, a[1], b[0] + 1, b[1])
	c.paint(m, r, base, false, true)


static func build(out_dir: String) -> void:
	_husk(out_dir)
	_skitter(out_dir)
	_archer(out_dir)
	_guard(out_dir)
	_bonecaller(out_dir)
	_bloat(out_dir)


# --- Husk ----------------------------------------------------------------------

static func _husk(dir: String) -> void:
	var s := Sheet.new(24, 24, Vector2i(12, 22))
	var idle: Array = []
	for i in 4:
		idle.append(husk_frame({"bob": 1 if i in [1, 2] else 0, "arm": "idle", "sway": i % 2}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 6:
		var ph := sin(i / 6.0 * TAU)
		# a shamble: the torso rolls over whichever leg is down
		walk.append(husk_frame({"bob": i % 3 == 1, "arm": "reach", "step": ph, "sway": i % 2, "lean": roundi(ph)}))
	s.add("walk", walk, 8.0)
	# both arms up and the head thrown back, then the whole body falls forward
	s.add("windup", [husk_frame({"arm": "raise", "lean": -1}), husk_frame({"arm": "raise", "lean": -2, "both": true, "bob": 1}),
		husk_frame({"arm": "raise", "lean": -3, "both": true, "bob": 1})], 6.0, false)
	s.add("attack", [husk_frame({"arm": "rake", "lean": 3}), husk_frame({"arm": "rake2", "lean": 4, "bob": 1}),
		husk_frame({"arm": "rake2", "lean": 2, "bob": 1})], 12.0, false)
	s.save(dir, "husk")


static func husk_frame(p: Dictionary) -> Px:
	var c := Px.new(24, 24)
	var b: int = int(p.get("bob", 0))
	var st: float = p.get("step", 0.0)
	var arm: String = p.get("arm", "idle")
	var lean: int = p.get("lean", 0)
	var sw: int = p.get("sway", 0)
	# back arm
	if p.get("both", false):
		limb(c, [[11 + lean, 11 + b], [12 + lean, 6 + b], [10 + lean, 2 + b]], Pal.BONE, 1, 1)
	else:
		limb(c, [[11 + lean, 11 + b], [10 + lean, 14 + b], [10 + lean, 17 + b]], Pal.BONE, 1, 1)
	# legs
	var fa := 10 + roundi(st * 2.0)
	var fb := 13 - roundi(st * 2.0)
	limb(c, [[11, 16 + b], [10, 19], [fa, 22]], Pal.BONE, 2, 1)
	limb(c, [[13, 16 + b], [14, 19], [fb, 22]], Pal.BONE, 2, 1)
	c.put(fa + 1, 22, Pal.BONE[2])
	c.put(fb + 1, 22, Pal.BONE[2])
	# pelvis
	c.paint(c.mask().rect(10, 15 + b, 5, 2), Pal.BONE, 2)
	# ribcage with gaps
	var rib := c.mask().ellipse(13.0 + lean, 11.5 + b, 3.4, 3.2)
	c.paint(rib, Pal.BONE, 2)
	for y in range(10 + b, 14 + b, 2):
		for x in range(11 + lean, 16 + lean):
			if rib.has(x, y) and rib.has(x - 1, y) and rib.has(x + 1, y):
				c.put(x, y, Pal.INK)
	# tattered shroud
	var sh := c.mask().poly(V([[8 + lean, 8 + b], [14 + lean, 7 + b], [12 + lean, 14 + b], [10, 18 + b], [7 - sw, 15 + b]]))
	for y in range(14, 20):
		if (y + sw) % 2 == 0:
			sh.set_bit(7 + (y % 3), y + b, false)
	c.paint(sh, Pal.EARTH, 2, true)
	# skull
	var sk := c.mask().ellipse(16.0 + lean, 7.5 + b, 3.6, 3.2)
	c.paint(sk, Pal.BONE, 3)
	c.put(17 + lean, 7 + b, Pal.INK)
	c.put(18 + lean, 7 + b, Pal.INK)
	c.put(17 + lean, 8 + b, Pal.INK)
	c.lit(18 + lean, 7 + b, Pal.SOUL[4])
	c.put(19 + lean, 9 + b, Pal.BONE[1])
	# jaw with teeth
	for x in range(15 + lean, 20 + lean):
		c.put(x, 10 + b, Pal.BONE[2] if x % 2 == 0 else Pal.INK)
		c.put(x, 11 + b, Pal.BONE[1])
	# front arm
	var sx := 14 + lean
	var sy := 10 + b
	match arm:
		"idle":
			limb(c, [[sx, sy], [16 + lean, 13 + b], [17 + lean, 16 + b]], Pal.BONE, 2)
			_claw(c, 17 + lean, 16 + b, 1)
		"reach":
			limb(c, [[sx, sy], [17 + lean, 12 + b], [20 + lean, 13 + b]], Pal.BONE, 2)
			_claw(c, 20 + lean, 13 + b, 0)
		"raise":
			limb(c, [[sx, sy], [16 + lean, 6 + b], [14 + lean, 2 + b]], Pal.BONE, 2)
			_claw(c, 14 + lean, 1 + b, -1)
		"rake":
			limb(c, [[sx, sy], [19 + lean, 11 + b], [22, 14 + b]], Pal.BONE, 2)
			_claw(c, 22, 14 + b, 1)
		"rake2":
			limb(c, [[sx, sy], [18 + lean, 14 + b], [20, 18 + b]], Pal.BONE, 2)
			_claw(c, 20, 18 + b, 1)
	c.outline(Pal.INK)
	return c


static func _claw(c: Px, x: int, y: int, dy: int) -> void:
	c.put(x + 1, y + dy, Pal.BONE[4])
	c.put(x + 2, y + dy, Pal.BONE[3])
	c.put(x + 1, y + dy + 1, Pal.BONE[3])


# --- Skitter ---------------------------------------------------------------------

static func _skitter(dir: String) -> void:
	var s := Sheet.new(16, 16, Vector2i(8, 14))
	s.add("idle", [skitter_frame(0.0, 0, 0), skitter_frame(0.5, 0, 1)], 4.0)
	var run: Array = []
	for i in 4:
		run.append(skitter_frame(i / 4.0, i % 2, 0))
	s.add("run", run, 14.0)
	s.add("crouch", [skitter_frame(0.25, 2, 0, "crouch")], 1.0, false)
	s.add("leap", [skitter_frame(0.0, -2, 0, "leap"), skitter_frame(0.5, -1, 0, "leap")], 8.0, false)
	s.save(dir, "skitter")


static func skitter_frame(ph: float, by: int, blink: int, pose := "") -> Px:
	var c := Px.new(16, 16)
	# legs: three pairs of finger-bones
	for k in 3:
		var bx := 5 + k * 3
		var off := roundi(sin((ph + k / 3.0) * TAU) * 1.5)
		if pose == "leap":
			limb(c, [[bx, 10 + by], [bx - 2, 12 + by], [bx - 3, 13 + by]], Pal.BONE, 2, 1)
		elif pose == "crouch":
			limb(c, [[bx, 10 + by], [bx - 1 + off, 12], [bx - 2 + off, 13]], Pal.BONE, 2, 1)
		else:
			limb(c, [[bx, 10 + by], [bx + 1 + off, 12], [bx + off, 14]], Pal.BONE, 2, 1)
	# squashed to spring, stretched in the air: the leap is told by its shape
	var body := c.mask().ellipse(8.5, 8.0 + by, 4.3, 3.4)
	if pose == "crouch":
		body = c.mask().ellipse(8.5, 8.5 + by, 5.0, 2.6)
	elif pose == "leap":
		body = c.mask().ellipse(9.0, 8.0 + by, 5.4, 2.6)
	c.paint(body, Pal.BONE, 3)
	# crack on the cranium
	c.put(7, 5 + by, Pal.BONE[1])
	c.put(8, 6 + by, Pal.BONE[1])
	# eye socket + glow
	c.put(10, 7 + by, Pal.INK)
	c.put(11, 7 + by, Pal.INK)
	c.put(10, 8 + by, Pal.INK)
	if blink == 0:
		c.lit(11, 7 + by, Pal.SOUL[5])
	c.put(7, 8 + by, Pal.INK)
	# teeth (bared in the air)
	for x in range(8, 13):
		c.put(x, 10 + by, Pal.INK if x % 2 == 0 else Pal.BONE[3])
		if pose == "leap":
			c.put(x, 11 + by, Pal.BONE[4] if x % 2 == 0 else Pal.INK)
	c.outline(Pal.INK)
	return c


# --- Hollow Archer -----------------------------------------------------------------

static func _archer(dir: String) -> void:
	var s := Sheet.new(24, 24, Vector2i(12, 22))
	var idle: Array = []
	for i in 4:
		idle.append(archer_frame({"bob": 1 if i >= 2 else 0, "pose": "idle", "sway": i % 2}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 4:
		walk.append(archer_frame({"bob": i % 2, "pose": "idle", "step": sin(i / 4.0 * TAU), "sway": i % 2}))
	s.add("walk", walk, 8.0)
	# the draw is a slow pull ending in a bright arrowhead: that is the warning
	s.add("aim", [archer_frame({"pose": "draw", "pull": 2}), archer_frame({"pose": "draw", "pull": 1}), archer_frame({"pose": "draw", "glow": 1})], 5.0, false)
	s.add("shoot", [archer_frame({"pose": "loose"}), archer_frame({"pose": "loose", "bob": 1}), archer_frame({"pose": "idle"})], 9.0, false)
	s.save(dir, "archer")


static func archer_frame(p: Dictionary) -> Px:
	var c := Px.new(24, 24)
	var b: int = int(p.get("bob", 0))
	var st: float = p.get("step", 0.0)
	var pose: String = p.get("pose", "idle")
	var sw: int = int(p.get("sway", 0))
	var fa := 10 + roundi(st * 2.0)
	var fb := 13 - roundi(st * 2.0)
	limb(c, [[11, 16 + b], [11, 19], [fa, 22]], Pal.BONE, 2, 1)
	limb(c, [[13, 16 + b], [13, 19], [fb, 22]], Pal.BONE, 2, 1)
	# cloak
	var cl := c.mask().poly(V([[9, 9 + b], [15, 9 + b], [16, 18 + b], [12, 19 + b], [7 - sw, 18 + b]]))
	for x in range(6, 17):
		if (x + sw) % 3 == 0:
			cl.set_bit(x, 18 + b, false)
	c.paint(cl, Pal.GLOAM, 2, true)
	# hood + skull face
	var hood := c.mask().ellipse(12.5, 6.5 + b, 4.0, 3.8)
	hood.poly(V([[9, 5 + b], [6 - sw, 9 + b], [10, 8 + b]]))
	c.paint(hood, Pal.GLOAM, 3, true)
	var face := c.mask().ellipse(14.0, 7.0 + b, 2.4, 2.4)
	c.paint(face, Pal.BONE, 3)
	c.put(15, 6 + b, Pal.INK)
	c.lit(15, 6 + b, Pal.SOUL[4] if p.get("glow", 0) == 0 else Pal.SOUL[5])
	for x in range(13, 17):
		c.put(x, 9 + b, Pal.INK if x % 2 == 1 else Pal.BONE[2])
	# bow
	var bx := 18
	if pose == "draw":
		bx = 19
	var bow := c.mask()
	for y in range(4, 19):
		var t := (y - 11.5) / 7.5
		var x := bx + roundi((1.0 - t * t) * 2.0)
		bow.set_bit(x, y + b)
	c.paint(bow, Pal.WOOD, 3, false, false)
	match pose:
		"draw":
			# string pulled back with a nocked soul-arrow (`pull`: how far short of full)
			var pull: int = int(p.get("pull", 0))
			var hx := 13 + pull * 2
			c.line(bx, 4 + b, hx + 1, 12 + b, Pal.BONE[4])
			c.line(hx + 1, 12 + b, bx, 18 + b, Pal.BONE[4])
			for x in range(hx, bx + 4):
				c.put(x, 12 + b, Pal.BONE[3])
			c.lit(bx + 4, 12 + b, Pal.SOUL[5])
			c.lit(bx + 3, 12 + b, Pal.SOUL[4])
			if p.get("glow", 0) != 0:
				c.lit(bx + 4, 11 + b, Pal.SOUL[4])
				c.lit(bx + 4, 13 + b, Pal.SOUL[4])
			limb(c, [[13, 10 + b], [16, 12 + b], [bx, 12 + b]], Pal.BONE, 2, 1)
			limb(c, [[11, 11 + b], [hx, 12 + b]], Pal.BONE, 2, 1)
		"loose":
			c.line(bx, 4 + b, bx, 18 + b, Pal.BONE[4])
			limb(c, [[13, 10 + b], [16, 12 + b], [bx, 12 + b]], Pal.BONE, 2, 1)
			limb(c, [[11, 11 + b], [10, 13 + b]], Pal.BONE, 2, 1)
		_:
			c.line(bx, 4 + b, bx, 18 + b, Pal.BONE[4])
			limb(c, [[13, 10 + b], [15, 13 + b], [bx, 12 + b]], Pal.BONE, 2, 1)
	c.outline(Pal.INK)
	return c


# --- Ossuary Guard -------------------------------------------------------------------

static func _guard(dir: String) -> void:
	var s := Sheet.new(32, 32, Vector2i(16, 30))
	s.add("idle", [guard_frame({"bob": 0}), guard_frame({"bob": 1})], 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(guard_frame({"bob": i % 2, "step": sin(i / 4.0 * TAU)}))
	s.add("walk", walk, 6.0)
	# gathers behind the shield, weight on the back foot, then drives through it
	s.add("windup", [guard_frame({"shield": -2, "bob": 1, "lean": -1}), guard_frame({"shield": -4, "bob": 2, "lean": -2, "step": 0.5})], 5.0, false)
	s.add("bash", [guard_frame({"shield": 3, "lean": 2, "step": -1.0}), guard_frame({"shield": 3, "lean": 1, "step": -1.0}),
		guard_frame({"shield": 1, "lean": 1, "step": -0.5})], 10.0, false)
	s.save(dir, "guard")


static func guard_frame(p: Dictionary) -> Px:
	var c := Px.new(32, 32)
	var b: int = int(p.get("bob", 0))
	var st: float = p.get("step", 0.0)
	var sh: int = int(p.get("shield", 0))
	var ln: int = int(p.get("lean", 0))
	# spear behind
	limb(c, [[19 + ln, 1 + b], [19 + ln, 29]], Pal.WOOD, 2, 1)
	var tip := c.mask().poly(V([[18 + ln, 3 + b], [20 + ln, -2 + b], [22 + ln, 3 + b]]))
	c.paint(tip, Pal.STEEL, 4)
	# legs (greaves)
	var fa := 13 + roundi(st * 2.0)
	var fb := 17 - roundi(st * 2.0)
	c.paint(c.mask().rect(fa, 23, 3, 7), Pal.STEEL, 2)
	c.paint(c.mask().rect(fb, 23, 3, 7), Pal.STEEL, 2)
	# tabard / skirt
	var sk := c.mask().poly(V([[11 + ln, 18 + b], [20 + ln, 18 + b], [21 + ln, 25], [10 + ln, 25]]))
	c.paint(sk, Pal.BLOOD, 1, true)
	# breastplate
	var tor := c.mask().ellipse(15.5 + ln, 15.5 + b, 5.2, 5.0)
	c.paint(tor, Pal.STEEL, 2, true)
	for x in range(13 + ln, 19 + ln):
		c.put(x, 18 + b, Pal.GOLD[2])
	# pauldron
	c.paint(c.mask().ellipse(12.0 + ln, 12.0 + b, 3.0, 2.4), Pal.STEEL, 3)
	# great helm
	var helm := c.mask().ellipse(16.0 + ln, 7.0 + b, 4.0, 4.4)
	helm.rect(12 + ln, 7 + b, 8, 4)
	c.paint(helm, Pal.STEEL, 2, true)
	for x in range(15 + ln, 20 + ln):
		c.put(x, 7 + b, Pal.INK)
	c.lit(18 + ln, 7 + b, Pal.SOUL[5])
	c.lit(17 + ln, 7 + b, Pal.SOUL[3])
	# plume
	var pl := c.mask().poly(V([[13 + ln, 3 + b], [10 + ln, 1 + b], [7 + ln, 5 + b], [12 + ln, 5 + b]]))
	c.paint(pl, Pal.BLOOD, 3)
	# tower shield
	var sx := 21 + sh + ln
	var shield := c.mask().rect(sx, 10 + b, 6, 18)
	shield.set_bit(sx, 10 + b, false)
	shield.set_bit(sx + 5, 10 + b, false)
	shield.set_bit(sx, 27 + b, false)
	shield.set_bit(sx + 5, 27 + b, false)
	c.paint(shield, Pal.STEEL, 2, true)
	for y in range(10 + b, 28 + b):
		if shield.has(sx + 5, y):
			c.put(sx + 5, y, Pal.GOLD[1])
		if shield.has(sx, y):
			c.put(sx, y, Pal.GOLD[3])
	# skull emblem
	c.paint(c.mask().ellipse(sx + 3.0, 17.0 + b, 1.8, 1.6), Pal.BONE, 3, false, false)
	c.put(sx + 2, 17 + b, Pal.INK)
	c.put(sx + 4, 17 + b, Pal.INK)
	c.outline(Pal.INK)
	return c


# --- Bonecaller ------------------------------------------------------------------------

static func _bonecaller(dir: String) -> void:
	var s := Sheet.new(24, 32, Vector2i(12, 30))
	var idle: Array = []
	for i in 4:
		idle.append(bonecaller_frame({"bob": [0, 1, 1, 0][i], "flame": i % 2, "sway": i % 2}))
	s.add("idle", idle, 5.0)
	var cast: Array = []
	for i in 4:
		cast.append(bonecaller_frame({"cast": true, "flame": 2 + i % 2, "bob": 0, "sway": i % 2}))
	s.add("cast", cast, 8.0)
	s.save(dir, "bonecaller")


static func bonecaller_frame(p: Dictionary) -> Px:
	var c := Px.new(24, 32)
	var b: int = int(p.get("bob", 0))
	var fl: int = int(p.get("flame", 0))
	var cast: bool = p.get("cast", false)
	var sw: int = int(p.get("sway", 0))
	# staff
	var stx := 5
	limb(c, [[stx, 6 + b - (2 if cast else 0)], [stx, 27 + b]], Pal.WOOD, 2, 1)
	var fy := 4 + b - (2 if cast else 0)
	var fm := c.mask().ellipse(stx + 0.5, fy, 1.6 + fl * 0.4, 2.2 + fl * 0.5)
	c.fill_lit(fm, Pal.SOUL[3])
	c.lit(stx, fy, Pal.SOUL[5])
	c.lit(stx + 1, fy - 1, Pal.SOUL[4])
	# robe (floating, tattered hem)
	var robe := c.mask().poly(V([[8, 12 + b], [16, 12 + b], [20 + sw, 28 + b], [4 - sw, 28 + b]]))
	for x in range(2, 22):
		if (x + sw) % 3 != 0:
			robe.set_bit(x, 28 + b, false)
		if (x + sw) % 4 == 0:
			robe.set_bit(x, 27 + b, false)
	c.paint(robe, Pal.GLOAM, 2, true)
	# bone trim
	for y in range(14 + b, 27 + b, 3):
		c.put(12, y, Pal.BONE[2])
	# arms
	if cast:
		limb(c, [[9, 14 + b], [7, 9 + b], [stx + 1, 7 + b]], Pal.GLOAM, 2)
		limb(c, [[15, 14 + b], [18, 9 + b], [19, 6 + b]], Pal.GLOAM, 2)
		c.put(19, 5 + b, Pal.BONE[3])
		c.lit(20, 4 + b, Pal.SOUL[4])
	else:
		limb(c, [[9, 14 + b], [7, 18 + b], [stx + 1, 18 + b]], Pal.GLOAM, 2)
		limb(c, [[15, 14 + b], [16, 19 + b]], Pal.GLOAM, 2)
	# hood + skull
	var hood := c.mask().ellipse(12.5, 8.0 + b, 4.4, 4.6)
	hood.poly(V([[11, 4 + b], [14, 1 + b], [15, 5 + b]]))
	c.paint(hood, Pal.GLOAM, 3, true)
	var face := c.mask().ellipse(13.5, 9.0 + b, 2.6, 2.6)
	c.paint(face, Pal.BONE, 3)
	c.put(13, 8 + b, Pal.INK)
	c.put(15, 8 + b, Pal.INK)
	c.lit(13, 8 + b, Pal.SOUL[4])
	c.lit(15, 8 + b, Pal.SOUL[4])
	for x in range(12, 16):
		c.put(x, 11 + b, Pal.INK if x % 2 == 0 else Pal.BONE[2])
	c.outline(Pal.INK)
	return c


# --- Grave Bloat -------------------------------------------------------------------------

static func _bloat(dir: String) -> void:
	var s := Sheet.new(24, 24, Vector2i(12, 22))
	s.add("idle", [bloat_frame(0, 0, 0), bloat_frame(1, 0, 0)], 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(bloat_frame(i % 2, 0, i))
	s.add("walk", walk, 6.0)
	var swell: Array = []
	for i in 4:
		swell.append(bloat_frame(0, i + 1, 0))
	s.add("swell", swell, 6.0, false)
	s.save(dir, "bloat")


static func bloat_frame(b: int, swell: int, step: int) -> Px:
	var c := Px.new(24, 24)
	var sx := 0.25 * swell
	# stubby legs
	var la := 9 + (1 if step % 4 == 1 else 0)
	var lb := 14 - (1 if step % 4 == 3 else 0)
	c.paint(c.mask().rect(la, 19, 2, 3), Pal.EARTH, 2)
	c.paint(c.mask().rect(lb, 19, 2, 3), Pal.EARTH, 2)
	# belly
	var belly := c.mask().ellipse(12.0, 13.5 + b * 0.5, 7.4 + sx * 2.0, 6.2 + sx * 1.6)
	c.paint(belly, Pal.MOSS, 3, true)
	# blotches
	for k in 5:
		var px := 8 + (k * 7) % 9
		var py := 11 + (k * 5) % 6
		if belly.has(px, py):
			c.put(px, py, Pal.MOSS[1])
			c.put(px + 1, py, Pal.BLOOD[2])
	# stitches
	for y in range(10, 18):
		if belly.has(12, y + b):
			c.put(12, y + b, Pal.INK)
			if y % 2 == 0:
				c.put(11, y + b, Pal.INK)
				c.put(13, y + b, Pal.INK)
	# glowing cracks as it swells
	if swell > 0:
		for k in swell * 3:
			var px := 6 + (k * 5) % 13
			var py := 9 + (k * 3) % 9
			if belly.has(px, py) and belly.has(px + 1, py + 1):
				c.lit(px, py, Pal.GOLD[4])
				c.lit(px + 1, py + 1, Pal.EMBER[4])
	# head
	var head := c.mask().ellipse(12.5, 5.5 + b, 3.0, 2.6)
	c.paint(head, Pal.BONE, 2)
	c.put(12, 5 + b, Pal.INK)
	c.put(14, 5 + b, Pal.INK)
	c.lit(14, 5 + b, Pal.SOUL[4])
	c.put(13, 7 + b, Pal.INK)
	# little arms
	c.paint(c.mask().rect(4, 12 + b, 2, 3), Pal.MOSS, 2)
	c.paint(c.mask().rect(19, 12 + b, 2, 3), Pal.MOSS, 2)
	c.outline(Pal.INK)
	return c
