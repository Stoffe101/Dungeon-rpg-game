## Armour drawn onto the Kindled: one overlay sheet per armour base (see
## src/data/gear_looks.gd), with exactly the body's animations and poses
## (GenPlayer.anim_table), so a helmet stays on the head through every run,
## dash and cast. Pieces are clipped against the body: capes and cloaks show
## only around it (behind), the lantern arm always stays in front.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")
const GenPlayer = preload("res://tools/art/gen_player.gd")
const Looks = preload("res://src/data/gear_looks.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func ramp(n: String) -> Array:
	match n:
		"STONE": return Pal.STONE
		"EARTH": return Pal.EARTH
		"BONE": return Pal.BONE
		"EMBER": return Pal.EMBER
		"SOUL": return Pal.SOUL
		"FROST": return Pal.FROST
		"GLOAM": return Pal.GLOAM
		"MOSS": return Pal.MOSS
		"BLOOD": return Pal.BLOOD
		"GOLD": return Pal.GOLD
		"STEEL": return Pal.STEEL
		"CLOAK": return Pal.CLOAK
		"OBSIDIAN": return Pal.OBSIDIAN
		"ASH": return Pal.ASH
		"WOOD": return Pal.WOOD
	return Pal.STEEL


static func build(dir: String) -> void:
	var table := GenPlayer.anim_table()
	for base in Looks.VIS:
		var v: Array = Looks.VIS[base]
		var s := Sheet.new(32, 32, Vector2i(16, 30))
		for a in table:
			var frames: Array = []
			for f in a[1]:
				frames.append(piece(String(v[0]), ramp(String(v[1])), ramp(String(v[2])), String(v[3]), String(f[0]), f[1]))
			s.add(String(a[0]), frames, float(a[2]), bool(a[3]))
		s.save(dir, "gear_" + String(base))


# --- the body's geometry for one pose (mirrors GenPlayer.frame) -----------------

static func geo(dir: String, p: Dictionary) -> Dictionary:
	var g := {}
	g.side = dir == "side"
	g.up = dir == "up"
	g.dash = p.get("dash", false)
	g.hurt = p.get("hurt", false)
	g.cast = int(p.get("cast", 0))
	g.sway = int(p.get("sway", 0))
	g.flare = int(p.get("flare", 0))
	g.legs = p.get("legs", [0, 0, 0, 0, 0])
	g.kneel = int(p.get("kneel", 0))
	var lean := 2 if g.dash and g.side else 0
	if g.hurt:
		lean = -1 if g.side else 0
	g.lean = lean
	g.oy = int(p.get("by", 0)) + (1 if g.dash else 0)
	g.hx = 16.0 + (0.5 + lean if g.side else 0.0)
	g.hy = 10.5 + g.oy
	g.face = Vector2(19.5 + lean, 11.5 + g.oy) if g.side else Vector2(16.0, 11.8 + g.oy)
	g.face_r = Vector2(2.8, 3.0) if g.side else Vector2(3.4, 3.0)
	# falling: the body sinks and its head rolls with it (GenPlayer._death)
	if g.kneel == 1 or g.kneel == 2:
		g.oy = 3 if g.kneel == 1 else 6
		g.hx = 16.0 + g.kneel
		g.hy = 10.5 + g.oy
		g.face = Vector2(16.0 + g.kneel, 12.5 + g.oy)
		g.face_r = Vector2(3.4, 2.4)
	return g


static func cloak_poly(g: Dictionary) -> PackedVector2Array:
	var oy: int = g.oy
	if g.side:
		var l: int = g.lean
		return V([[12 + l, 15 + oy], [20 + l, 15 + oy], [21 + l, 27 + oy], [10 - g.flare, 27 + oy], [11 - g.flare / 2, 21 + oy]])
	var hw := 1 if g.dash else 0
	return V([[11, 15 + oy], [21, 15 + oy], [23 + hw + g.sway / 2, 27 + oy], [9 - hw - g.sway / 2, 27 + oy]])


## The lantern and the arm that holds it (never covered by armour).
static func arm_mask(c: Px, g: Dictionary) -> Px.Mask:
	var m := c.mask()
	var oy: int = g.oy
	if g.cast > 0:
		var ly := 6 + oy if g.cast == 2 else 9 + oy
		var lx: int = 21 if not g.side else 22 + g.lean
		m.rect(lx - 1, ly - 1, 4, 22 + oy - ly)
	elif g.side:
		m.poly(V([[19 + g.lean, 17 + oy], [21 + g.lean, 17 + oy], [23 + g.lean, 20 + oy], [21 + g.lean, 21 + oy]]))
		m.rect(22 + g.lean, 19 + oy, 3, 6)
	elif not g.up:
		m.rect(20, 17 + oy, 2, 4)
		m.rect(21, 19 + oy, 3, 6)
	return m


## Where the lantern hand is (x, y of its top-left; 2x2), or null.
static func hand(g: Dictionary) -> Variant:
	var oy: int = g.oy
	if g.cast > 0:
		var ly := 6 + oy if g.cast == 2 else 9 + oy
		var lx: int = 21 if not g.side else 22 + g.lean
		return Vector2i(lx - 1, ly + 3)
	if g.side:
		return Vector2i(21 + g.lean, 19 + oy)
	if g.up:
		return null
	return Vector2i(20, 19 + oy)


## Each leg's rectangle top-left (2 wide, 4 tall).
static func legs(g: Dictionary) -> Array:
	var oy: int = g.oy
	var k: Array = g.legs
	if g.side:
		return [Vector2i(15 + k[2], 26 + oy - k[3]), Vector2i(15 + k[0], 26 + oy - k[1])]
	return [Vector2i(13, 26 + oy - k[1]), Vector2i(17, 26 + oy - k[3])]


# --- one frame of one piece ---------------------------------------------------------

static func piece(style: String, m: Array, a: Array, variant: String, dir: String, p: Dictionary) -> Px:
	var c := Px.new(32, 32)
	var g := geo(dir, p)
	if g.kneel >= 3:
		_fallen(c, g, style, m, a)
		return c
	var body := GenPlayer.frame(dir, p)
	match style:
		"hood": _hood(c, g, m, a, variant)
		"helm": _helm(c, g, m, a, variant)
		"circlet": _circlet(c, g, m, a, variant)
		"crown": _crown(c, g, m, a, variant)
		"cap": _cap(c, g, m, a, variant)
		"mask": _mask(c, g, m, a)
		"robe": _robe(c, g, m, a, variant)
		"mail": _mail(c, g, m, a, variant)
		"plate": _plate(c, g, m, a, variant)
		"cloak": _cloak(c, g, m, a, variant, body)
		"coat": _coat(c, g, m, a)
		"gauntlets", "gloves", "wraps", "bracers":
			if g.kneel == 0:
				_hands(c, g, m, a, style, variant)
			return c
		"boots", "greaves", "treads", "sandals", "waders", "clogs":
			if g.kneel == 0:
				_feet(c, g, m, a, style, variant)
			return c
	c.outline(Pal.INK)
	# the lantern and its arm stay in front of whatever is worn (shoulders stay over the arm)
	var arm := arm_mask(c, g)
	if style in ["mail", "plate"]:
		arm.rect(0, 0, 32, 20 + g.oy, false)
	for y in 32:
		for x in 32:
			if arm.has(x, y):
				c.put(x, y, Pal.CLEAR)
	return c


## Fallen flat: what was worn stays on the heap (GenPlayer._death), a helm rolled clear of it.
static func _fallen(c: Px, g: Dictionary, style: String, m: Array, a: Array) -> void:
	var flat: int = 1 if g.kneel == 3 else 0
	var last: bool = g.kneel == 5
	match style:
		"hood", "helm", "cap", "mask", "circlet", "crown":
			var head := c.mask()
			if last:
				head.ellipse(23.0, 26.0, 3.2, 2.2)
			else:
				head.ellipse(21.0, 24.5 - flat, 4.5, 3.0 + flat)
			c.paint(head, m, 2, true)
			c.outline(Pal.INK)
		"robe", "mail", "plate", "cloak", "coat":
			var body := c.mask()
			if last:
				body.ellipse(14.0, 27.0, 7.5, 2.0)
			else:
				body.ellipse(14.0, 26.0, 7.5, 2.8 + flat)
			c.paint(body, m, 2, true)
			if style in ["mail", "plate"] and not last:
				c.paint(c.mask().ellipse(19.0, 25.0, 2.4, 1.8), m, 3, true)
			for x in range(9, 19):
				if body.has(x, 26):
					c.put(x, 26, a[1])
			c.outline(Pal.INK)


# --- heads ------------------------------------------------------------------------------

static func _hood_mask(c: Px, g: Dictionary, grow := 0.2) -> Px.Mask:
	var oy: int = g.oy
	var h := c.mask().ellipse(g.hx, g.hy, 6.0 + grow, 5.6 + grow)
	if g.side:
		h.poly(V([[13 + g.lean, 7 + oy], [7 - g.sway, 5 + oy], [12 + g.lean, 11 + oy]]))
	else:
		h.poly(V([[17, 6 + oy], [22 + g.sway, 3 + oy], [20, 9 + oy]]))
	return h


static func _face(c: Px, g: Dictionary) -> Px.Mask:
	return c.mask().ellipse(g.face.x, g.face.y, g.face_r.x, g.face_r.y)


## The Kindled's eyes, drawn again so they glow through whatever is on the head.
static func _eyes(c: Px, g: Dictionary) -> void:
	if g.up:
		return
	var oy: int = g.oy
	if g.side:
		c.lit(20 + g.lean, 11 + oy, Pal.EMBER[5])
		c.lit(21 + g.lean, 11 + oy, Pal.EMBER[3])
	else:
		c.lit(14, 12 + oy, Pal.EMBER[5])
		c.lit(17, 12 + oy, Pal.EMBER[5])


static func _hood(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var oy: int = g.oy
	var h := _hood_mask(c, g)
	if variant == "cowl":
		# a shorter, broader cowl with a mantle of leaves
		h.ellipse(g.hx, g.hy + 3.5, 6.5, 2.5)
	if not g.up:
		h.subtract(_face(c, g))
	c.paint(h, m, 2, true)
	if not g.up:
		var rim := c.mask().ellipse(g.face.x, g.face.y, g.face_r.x + 1.0, g.face_r.y + 1.0)
		rim.subtract(_face(c, g))
		for y in 32:
			for x in 32:
				if rim.has(x, y) and h.has(x, y) and y < 12 + oy:
					c.put(x, y, a[3])
	match variant:
		"cowl":
			for k in 5:
				var lx: int = int(g.hx) - 5 + k * 2 + (k % 2)
				c.put(lx, int(g.hy) + 4 + (k % 2), Pal.MOSS[4])
				c.put(lx + 1, int(g.hy) + 4, Pal.MOSS[3])
		"gloam":
			c.lit(int(g.hx) - 3 if not g.side else int(g.hx) - 2, int(g.hy) - 3, Pal.GLOAM[5])
			c.lit(int(g.hx) + 3 if not g.side else int(g.hx) - 4, int(g.hy) - 1, Pal.GLOAM[4])
		"feather":
			var bx: int = int(g.hx) + (-5 if g.side else 4)
			for k in 6:
				c.put(bx + (k / 2 if not g.side else -k / 2), int(g.hy) - 4 - k, Pal.WHITE if k % 2 == 0 else Pal.BONE[4])
	_eyes(c, g)


static func _helm(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var oy: int = g.oy
	var hx: float = g.hx
	var hy: float = g.hy
	# a helm is wider than a head: a dome, cheek plates and a guard over the neck
	var dome := c.mask().ellipse(hx, hy - 0.6, 6.6, 5.8)
	if g.side:
		dome.rect(int(hx) - 6, int(hy) + 2, 6, 3)         # the neck guard
		dome.rect(int(hx) + 1, int(hy) + 2, 5, 3)         # the cheek
	elif g.up:
		dome.rect(int(hx) - 6, int(hy) + 2, 13, 3)
	else:
		dome.rect(int(hx) - 7, int(hy) + 1, 4, 4)
		dome.rect(int(hx) + 4, int(hy) + 1, 4, 4)
		dome.rect(int(hx) - 3, int(hy) + 3, 7, 2)
	c.paint(dome, m, 2, true)
	# the hood's point is under there: a plume grows from the crest over it
	var plume := c.mask()
	if g.side:
		plume.poly(V([[13 + g.lean, 6 + oy], [6 - g.sway, 5 + oy], [8 - g.sway, 7 + oy], [12 + g.lean, 9 + oy]]))
	else:
		plume.poly(V([[16, 5 + oy], [22 + g.sway, 2 + oy], [23 + g.sway, 4 + oy], [20, 8 + oy]]))
	plume.subtract(dome)
	c.paint(plume, Pal.BLOOD if a == m and m == Pal.STEEL else a, 2)
	# a ridge over the crown
	for y in range(int(hy) - 5, int(hy) + 1):
		c.put(int(hx) if not g.side else int(hx) - 1, y, m[4] if m.size() > 4 else m[3])
	if not g.up:
		# the visor: a dark slit, with the eyes burning in it
		var ey: int = 12 + oy if not g.side else 11 + oy
		var x0: int = 13 if not g.side else 18 + g.lean
		var x1: int = 18 if not g.side else 22 + g.lean
		for x in range(x0, x1 + 1):
			c.put(x, ey, Pal.INK)
			c.put(x, ey + 1, m[1])
		if not g.side:
			for y in range(ey + 1, ey + 3):
				c.put(15, y, m[3])
				c.put(16, y, m[3])
		_eyes(c, g)
	match variant:
		"horned":
			for s in ([-1, 1] if not g.side else [-1]):
				var bx: int = int(hx) + s * 6
				for k in 5:
					var x: int = bx + s * (k / 2)
					var y := int(hy) - 2 - k
					c.put(x, y, Pal.BONE[3] if k < 4 else Pal.BONE[4])
					c.put(x + s * -1, y, Pal.BONE[2])
		"ember":
			for k in 3:
				c.lit(int(hx) - 1 + k if not g.side else int(hx) - 2 + k, int(hy) - 6, Pal.EMBER[4 + k % 2])
		"visor":
			if not g.up:
				c.lit(int(g.face.x), int(hy) - 3, Pal.FROST[5])
			c.put(int(hx) - 3, int(hy) - 4, Pal.FROST[5])


static func _circlet(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var y := int(g.hy) - 2
	var x0: int = int(g.hx) - 5
	var x1: int = int(g.hx) + 5
	for x in range(x0, x1 + 1):
		c.put(x, y, m[3])
		c.put(x, y + 1, m[2])
	if g.up:
		return
	var gx: int = int(g.hx) if not g.side else int(g.hx) + 4
	var big := variant == "big"
	c.lit(gx, y, a[5] if a.size() > 5 else a[4])
	c.lit(gx, y + 1, a[4])
	if big:
		c.lit(gx - 1, y, a[3])
		c.lit(gx + 1, y, a[3])
		c.lit(gx, y - 1, a[4])


static func _crown(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var y := int(g.hy) - 3
	var x0: int = int(g.hx) - 5
	for x in range(x0, x0 + 11):
		c.put(x, y, m[3])
		c.put(x, y + 1, m[2])
	var points := [0, 3, 5, 7, 10] if not g.side else [1, 4, 7, 9]
	for k in points.size():
		var px: int = x0 + points[k]
		var tall := 3 if k % 2 == 0 else 2
		for t in tall:
			if variant == "bloom":
				c.put(px, y - 1 - t, Pal.BLOOD[3] if t == tall - 1 else Pal.MOSS[3])
			else:
				c.put(px, y - 1 - t, m[3] if t < tall - 1 else (m[4] if m.size() > 4 else m[3]))
		if not g.up:
			c.lit(px, y, a[4] if k % 2 == 0 else a[3])


static func _cap(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var hx: float = g.hx
	var hy: float = g.hy
	if variant == "fool":
		# two floppy points, two colours, a bell at each tip
		var top := c.mask().ellipse(hx, hy - 2.5, 5.5, 3.0)
		c.paint(top, m, 2, true)
		var sides := [[-1, Pal.BLOOD], [1, Pal.GOLD]] if not g.side else [[-1, Pal.GOLD]]
		for sd in sides:
			var s: int = sd[0]
			var r: Array = sd[1]
			var pts := c.mask().poly(V([[hx + s * 2, hy - 5], [hx + s * 8, hy - 3], [hx + s * 9, hy + 1], [hx + s * 5, hy - 2]]))
			c.paint(pts, r, 2)
			c.lit(int(hx) + s * 9, int(hy) + 2, Pal.GOLD[4])
		_eyes(c, g)
		return
	# a miner's leather cap with a little lamp
	var dome := c.mask().ellipse(hx, hy - 2.5, 5.6, 3.3)
	dome.rect(int(hx) - 6, int(hy) - 2, 13, 1)
	c.paint(dome, m, 2, true)
	if not g.up:
		var lx: int = int(hx) if not g.side else int(hx) + 4
		c.put(lx - 1, int(hy) - 4, Pal.STEEL[2])
		c.lit(lx, int(hy) - 4, Pal.GOLD[4])
		c.lit(lx, int(hy) - 3, Pal.GOLD[3])
	_eyes(c, g)


static func _mask(c: Px, g: Dictionary, m: Array, a: Array) -> void:
	if g.up:
		var strap := c.mask().rect(int(g.hx) - 5, int(g.hy) - 1, 11, 1)
		c.paint(strap, Pal.EARTH, 2)
		return
	var f: Vector2 = g.face
	var beak: Px.Mask
	if g.side:
		beak = c.mask().poly(V([[f.x - 2, f.y - 2], [f.x + 6, f.y + 2], [f.x - 1, f.y + 3]]))
		beak.ellipse(f.x, f.y, 2.6, 2.6)
	else:
		beak = c.mask().ellipse(f.x, f.y - 0.5, 3.6, 2.8)
		beak.poly(V([[f.x - 2, f.y + 1], [f.x + 2, f.y + 1], [f.x, f.y + 6]]))
	c.paint(beak, m, 2, true)
	if g.side:
		c.lit(int(f.x) + 1, int(f.y) - 1, a[4])
	else:
		c.lit(int(f.x) - 2, int(f.y) - 1, a[4])
		c.lit(int(f.x) + 1, int(f.y) - 1, a[4])


# --- chests ------------------------------------------------------------------------------

static func _scarf(c: Px, g: Dictionary) -> Px.Mask:
	if g.side:
		return c.mask().rect(12 + g.lean, 15 + g.oy, 9, 3)
	return c.mask().rect(11, 15 + g.oy, 10, 3)


## Cloth: it hangs past the cloak and flares at the hem, the widest thing at the feet.
static func _robe(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var oy: int = g.oy
	var body := c.mask().poly(cloak_poly(g))
	var hem: int = mini(29, 28 + oy)
	if g.side:
		var l: int = g.lean
		body.poly(V([[12 + l, 22 + oy], [22 + l, 22 + oy], [23 + l, hem], [8 - g.flare, hem]]))
	else:
		var flare: int = 1 + g.sway / 2
		body.poly(V([[10, 22 + oy], [22, 22 + oy], [24 + flare, hem], [8 - flare, hem]]))
	# wide sleeves
	if not g.side:
		body.poly(V([[10, 17 + oy], [8, 23 + oy], [11, 23 + oy], [12, 18 + oy]]))
		if g.up:
			body.poly(V([[22, 17 + oy], [24, 23 + oy], [21, 23 + oy], [20, 18 + oy]]))
	body.subtract(_scarf(c, g))
	c.paint(body, m, 2, true)
	if g.up:
		for y in range(18 + oy, hem):
			c.put(16, y, m[1])
		return
	var cx: int = 16 if not g.side else 19 + g.lean
	for y in range(18 + oy, hem + 1):
		if body.has(cx, y):
			c.put(cx, y, a[3])
	for x in range(10, 23):
		if body.has(x, 22 + oy):
			c.put(x, 22 + oy, a[1])
	match variant:
		"pilgrim":
			c.lit(cx, 19 + oy, Pal.GOLD[4])
			c.lit(cx - 1, 19 + oy, Pal.GOLD[3])
			c.lit(cx + 1, 19 + oy, Pal.GOLD[3])
			c.lit(cx, 18 + oy, Pal.GOLD[3])
		"bark":
			for k in 4:
				var x: int = 12 + k * 3
				if body.has(x, 24 + oy):
					c.put(x, 24 + oy, Pal.WOOD[0])
					c.put(x, 25 + oy, Pal.WOOD[0])
			c.put(cx - 2, 20 + oy, Pal.MOSS[4])
			c.put(cx + 2, 25 + oy, Pal.MOSS[4])


## Mail: a shaped shirt of rings. Capped shoulders, a belt at the waist, a split skirt.
static func _mail(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var oy: int = g.oy
	var torso := c.mask()
	var waist: int = 23 + oy
	var hem: int = 27 + oy
	if g.side:
		var l: int = g.lean
		torso.poly(V([[13 + l, 18 + oy], [20 + l, 18 + oy], [20 + l, waist], [14 + l, waist]]))
		torso.poly(V([[14 + l, waist], [20 + l, waist], [21 + l, hem], [12 + l, hem]]))
	else:
		torso.poly(V([[11, 18 + oy], [21, 18 + oy], [19, waist], [13, waist]]))
		torso.poly(V([[13, waist], [19, waist], [21, hem], [11, hem]]))
		if not g.up:
			torso.rect(16, waist + 1, 1, hem - waist, false)
	for y in 32:
		for x in 32:
			if not torso.has(x, y):
				continue
			if variant == "scale":
				# overlapping scales: rows of little arcs
				var k := (x + (1 if (y - oy) % 4 >= 2 else 0) * 2) % 4
				c.put(x, y, m[1] if (y - oy) % 2 == 1 and k == 0 else (m[3] if (y - oy) % 2 == 0 else m[2]))
			else:
				# rings read as fine rows, not a checkerboard
				c.put(x, y, m[3] if (y - oy) % 2 == 0 else m[2])
	# the belt
	for x in 32:
		if torso.has(x, waist):
			c.put(x, waist, a[1])
	if not g.up:
		c.put(16 if not g.side else 18 + g.lean, waist, a[3])
	# capped shoulders, past the line of the cloak
	var caps: Array = [[16.5 + g.lean, 2.8, 2.0]] if g.side else [[10.5, 2.6, 1.9], [21.5, 2.6, 1.9]]
	for k: Array in caps:
		c.paint(c.mask().ellipse(k[0], 18.0 + oy, k[1], k[2]), m, 3, true)
	match variant:
		"rime":
			c.lit(14 if not g.side else 17 + g.lean, 20 + oy, Pal.FROST[5])
			c.lit(18 if not g.side else 19 + g.lean, 22 + oy, Pal.FROST[4])
		"thorn":
			for p in ([[8, 17], [24, 17], [10, 20], [22, 20]] if not g.side else [[14, 15], [11, 18]]):
				c.put(p[0] + (g.lean if g.side else 0), p[1] + oy, Pal.MOSS[4])
				c.put(p[0] + (g.lean if g.side else 0) + (1 if p[0] < 16 else -1), p[1] + 1 + oy, Pal.WOOD[2])


## Plate: the shape of someone who means to stand there. Great shoulders well past the
## body, a breastplate with a ridge, hanging plates over the hips.
static func _plate(c: Px, g: Dictionary, m: Array, a: Array, variant: String) -> void:
	var oy: int = g.oy
	var plate := c.mask()
	if g.side:
		var l: int = g.lean
		plate.poly(V([[13 + l, 18 + oy], [21 + l, 18 + oy], [21 + l, 24 + oy], [14 + l, 25 + oy]]))
		plate.rect(13 + l, 25 + oy, 8, 2)
	else:
		plate.poly(V([[11, 18 + oy], [21, 18 + oy], [20, 25 + oy], [12, 25 + oy]]))
		plate.rect(11, 25 + oy, 4, 2)
		plate.rect(17, 25 + oy, 4, 2)
	c.paint(plate, m, 2, true)
	# a line where the hip plates hang from
	for x in 32:
		if plate.has(x, 25 + oy):
			c.put(x, 25 + oy, m[1])
	if not g.up:
		var cx: int = 16 if not g.side else 18 + g.lean
		for y in range(19 + oy, 25 + oy):
			c.put(cx, y, m[4] if m.size() > 4 else m[3])
	var shoulders: Array = [[15.5 + g.lean, 3.8, 3.0]] if g.side else [[8.5, 3.6, 3.0], [23.5, 3.6, 3.0]]
	for k: Array in shoulders:
		var pad := c.mask().ellipse(k[0], 17.5 + oy, k[1], k[2])
		c.paint(pad, m, 3, true)
		# a rim of the second metal
		var x0: int = int(float(k[0]) - float(k[1])) + 1
		for x in range(x0, x0 + int(float(k[1]) * 2.0) - 1):
			if pad.has(x, 19 + oy):
				c.put(x, 19 + oy, a[2])
	match variant:
		"ember":
			c.lit(14 if not g.side else 17 + g.lean, 21 + oy, Pal.EMBER[4])
			c.lit(18 if not g.side else 19 + g.lean, 21 + oy, Pal.EMBER[4])
			c.lit(16 if not g.side else 18 + g.lean, 23 + oy, Pal.EMBER[3])
		"mountain":
			c.lit(16 if not g.side else 18 + g.lean, 20 + oy, Pal.EMBER[4])
			c.put(14 if not g.side else 16 + g.lean, 22 + oy, Pal.STONE[0])
			c.put(13 if not g.side else 15 + g.lean, 23 + oy, Pal.STONE[0])


## Capes and mantles: behind the Kindled (only around the body) seen from the
## front or side; over the back when walking away.
static func _cloak(c: Px, g: Dictionary, m: Array, a: Array, variant: String, body: Px) -> void:
	var oy: int = g.oy
	var sway: int = g.sway
	var cape: Px.Mask
	if g.side:
		cape = c.mask().poly(V([[12 + g.lean, 15 + oy], [17 + g.lean, 15 + oy], [16 + g.lean, 29], [7 - g.flare - sway, 29], [9 - g.flare, 21 + oy]]))
	else:
		cape = c.mask().poly(V([[9, 15 + oy], [23, 15 + oy], [26 + sway, 29], [6 - sway, 29]]))
	if variant == "tattered" or variant == "moth":
		for x in 32:
			if (x + sway) % (3 if variant == "tattered" else 2) == 0:
				cape.set_bit(x, 28, false)
				if variant == "tattered" and x % 5 == 0:
					cape.set_bit(x, 27, false)
	if not g.up:
		for y in 32:
			for x in 32:
				if body.opaque(x, y):
					cape.set_bit(x, y, false)
	c.paint(cape, m, 2, true)
	match variant:
		"stars":
			for p in [[9, 22], [23, 20], [8, 26], [24, 25], [16, 24]]:
				if cape.has(p[0], p[1]):
					c.lit(p[0], p[1], Pal.GLOAM[5])
		"moth":
			for p in [[9, 21], [23, 21], [16, 22], [8, 25], [24, 25]]:
				if cape.has(p[0], p[1]):
					c.lit(p[0], p[1], Pal.GOLD[4])
					if cape.has(p[0] + 1, p[1]):
						c.put(p[0] + 1, p[1], Pal.INK)
		"sunfall":
			for p in [[8, 24], [24, 24], [16, 26], [10, 20], [22, 20], [16, 22]]:
				if cape.has(p[0], p[1]):
					c.lit(p[0], p[1], Pal.GOLD[4])
	# the collar or mantle over the shoulders, in front
	if variant in ["fur", "sunfall"]:
		var col := c.mask().ellipse(16.0 if not g.side else 16.0 + g.lean, 15.5 + oy, 6.5 if not g.side else 4.5, 2.0)
		col.subtract(_scarf(c, g))
		c.paint(col, Pal.BONE if variant == "fur" else Pal.GOLD, 3, true)
		if variant == "sunfall" and not g.up:
			c.lit(16 if not g.side else 18 + g.lean, 14 + oy, Pal.GOLD[4])
	elif not g.up:
		# seen from the front a cloak is what lies over the shoulders
		var mantle := c.mask()
		if g.side:
			mantle.poly(V([[12 + g.lean, 18 + oy], [17 + g.lean, 18 + oy], [16 + g.lean, 22 + oy], [11 + g.lean, 21 + oy]]))
		else:
			mantle.poly(V([[10, 18 + oy], [15, 18 + oy], [14, 21 + oy], [9, 22 + oy]]))
			mantle.poly(V([[17, 18 + oy], [22, 18 + oy], [23, 22 + oy], [18, 21 + oy]]))
		c.paint(mantle, m, 2, true)
		c.put(14 if not g.side else 16 + g.lean, 18 + oy, a[3])
		if not g.side:
			c.put(18, 18 + oy, a[3])


static func _coat(c: Px, g: Dictionary, m: Array, a: Array) -> void:
	var oy: int = g.oy
	var body := c.mask().poly(cloak_poly(g))
	body.subtract(_scarf(c, g))
	if not g.up and not g.side:
		body.subtract(c.mask().rect(15, 18 + oy, 3, 10))
	c.paint(body, m, 2, true)
	if not g.up:
		for y in range(18 + oy, 27 + oy):
			var x: int = 14 if not g.side else 19 + g.lean
			if body.has(x, y):
				c.put(x, y, a[3])
	# a high collar either side of the scarf
	c.put(10 if not g.side else 11 + g.lean, 15 + oy, m[3])
	c.put(10 if not g.side else 11 + g.lean, 16 + oy, m[3])
	if not g.side:
		c.put(21, 15 + oy, m[3])
		c.put(21, 16 + oy, m[3])


# --- hands and feet: small, so they are drawn bigger than life -----------------------

## The forearm's top-left for each arm that can be seen: [lantern arm, the other].
static func _arms(g: Dictionary) -> Array:
	var oy: int = g.oy
	var out: Array = []
	var h: Variant = hand(g)
	if h != null:
		out.append(h)
	if g.side:
		return out
	if g.up:
		out.append(Vector2i(21, 20 + oy))
	out.append(Vector2i(9, 20 + oy))
	return out


static func _hands(c: Px, g: Dictionary, m: Array, a: Array, style: String, variant: String) -> void:
	for arm in _arms(g):
		var p: Vector2i = arm
		match style:
			"gauntlets":
				# a heavy fist and a flared cuff
				var fist := c.mask().rect(p.x - 1, p.y + 1, 4, 3)
				fist.rect(p.x - 1, p.y - 1, 4, 2)
				c.paint(fist, m, 2, true)
				for x in range(p.x - 1, p.x + 3):
					c.put(x, p.y, m[4] if m.size() > 4 else m[3])
				if variant == "glow":
					c.lit(p.x + 1, p.y + 2, a[4])
			"gloves":
				var g2 := c.mask().rect(p.x, p.y, 3, 3)
				c.paint(g2, m, 2, true)
				if variant == "haste":
					c.lit(p.x + 1, p.y - 1, Pal.GOLD[4])
			"wraps":
				for y in range(p.y - 1, p.y + 3):
					c.put(p.x, y, a[3] if y % 2 == 0 else m[3])
					c.put(p.x + 1, y, m[3] if y % 2 == 0 else a[3])
			"bracers":
				var band := c.mask().rect(p.x - 1, p.y - 1, 4, 2)
				c.paint(band, m, 3, true)
				c.lit(p.x + (1 if variant != "mirror" else 0), p.y - 1, a[4] if variant != "mirror" else Pal.WHITE)
	if style == "gauntlets":
		c.outline(Pal.INK)


static func _feet(c: Px, g: Dictionary, m: Array, a: Array, style: String, variant: String) -> void:
	for lp in legs(g):
		var p: Vector2i = lp
		match style:
			"boots":
				for y in range(p.y + 2, p.y + 4):
					c.put(p.x, y, m[2])
					c.put(p.x + 1, y, m[3])
				c.put(p.x, p.y + 1, m[3])
				c.put(p.x + 1, p.y + 1, m[3])
				if g.side:
					c.put(p.x + 2, p.y + 3, m[2])
				if variant == "winged":
					c.put(p.x - 1, p.y + 1, Pal.WHITE)
					c.put(p.x - 1, p.y + 2, Pal.BONE[4])
			"greaves":
				# plate from knee to toe, wider than the leg
				var leg := c.mask().rect(p.x - 1, p.y, 4, 4)
				if g.side:
					leg.rect(p.x + 3, p.y + 3, 1, 1)
				c.paint(leg, m, 2, true)
				for x in range(p.x - 1, p.x + 3):
					c.put(x, p.y, m[4] if m.size() > 4 else m[3])
			"treads":
				for y in range(p.y + 1, p.y + 4):
					c.put(p.x, y, m[2] if y % 2 == 0 else a[2])
					c.put(p.x + 1, y, m[3] if y % 2 == 0 else a[3])
			"sandals":
				c.put(p.x, p.y + 3, m[2])
				c.put(p.x + 1, p.y + 3, m[3])
				if variant == "glow":
					c.lit(p.x + 1, p.y + 2, a[4])
				else:
					c.put(p.x + 1, p.y + 2, a[3])
				if variant == "slipper":
					c.put(p.x, p.y + 2, m[3])
			"waders":
				for y in range(p.y - 1, p.y + 4):
					c.put(p.x, y, m[2])
					c.put(p.x + 1, y, m[3])
				c.put(p.x, p.y - 1, a[3])
				c.put(p.x + 1, p.y - 1, a[3])
			"clogs":
				for x in range(p.x, p.x + 3):
					c.put(x, p.y + 3, m[2])
					c.put(x, p.y + 2, m[3])
	if style == "greaves":
		c.outline(Pal.INK)
