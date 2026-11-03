## The Kindled: a hooded warden carrying a lantern of hearth-fire.
## 32x32 frames, feet at (16, 30). Directions: down, up, side (faces right).
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


## Every animation of the Kindled as [name, [[dir, params]...], fps, loop]: the
## one source of poses for the body and for each piece of gear drawn over it
## (tools/art/gen_gear.gd), so armour never drifts from the body it sits on.
static func anim_table() -> Array:
	var out: Array = []
	for dir in ["down", "up", "side"]:
		var idle: Array = []
		for i in 4:
			idle.append([dir, {"by": 1 if i >= 2 else 0, "sway": [0, 1, 1, 0][i], "glow": 4 if i % 2 == 0 else 5}])
		out.append(["idle_" + dir, idle, 5.0, true])
	# run: [legA dx, liftA, legB dx, liftB, bob]
	var cycle_side := [[3, 0, -3, 0, 0], [1, 0, -1, 1, 1], [-1, 0, 1, 2, 0], [-3, 0, 3, 0, 0], [-1, 1, 1, 0, 1], [1, 2, -1, 0, 0]]
	var cycle_front := [[0, 0, 0, 0, 0], [0, 1, 0, 0, 1], [0, 2, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 1, 1], [0, 0, 0, 2, 0]]
	for dir in ["down", "up", "side"]:
		var run: Array = []
		var cyc: Array = cycle_side if dir == "side" else cycle_front
		for i in 6:
			var k: Array = cyc[i]
			run.append([dir, {"legs": k, "by": k[4], "sway": [1, 2, 1, 1, 2, 1][i], "flare": 2, "glow": 4 + (i % 2)}])
		out.append(["run_" + dir, run, 12.0, true])
	for dir in ["down", "up", "side"]:
		out.append(["dash_" + dir, [[dir, {"dash": true, "flare": 4, "glow": 5, "legs": [2, 1, -2, 1, 0]}]], 1.0, false])
	for dir in ["down", "up", "side"]:
		out.append(["hurt_" + dir, [[dir, {"hurt": true, "by": 1, "glow": 3}]], 1.0, false])
	for dir in ["down", "up", "side"]:
		out.append(["cast_" + dir, [[dir, {"cast": 1, "glow": 5}], [dir, {"cast": 2, "glow": 5, "by": -1}]], 10.0, false])
	var death: Array = []
	for i in 5:
		death.append(["down", {"kneel": i + 1, "glow": maxi(1, 4 - i)}])
	out.append(["death", death, 8.0, false])
	return out


static func build(out_dir: String) -> void:
	var s := Sheet.new(32, 32, Vector2i(16, 30))
	for a in anim_table():
		var frames: Array = []
		for f in a[1]:
			frames.append(frame(String(f[0]), f[1]))
		s.add(String(a[0]), frames, float(a[2]), bool(a[3]))
	s.save(out_dir, "player")


static func frame(dir: String, p: Dictionary) -> Px:
	var c := Px.new(32, 32)
	var by: int = p.get("by", 0)
	var legs: Array = p.get("legs", [0, 0, 0, 0, 0])
	var sway: int = p.get("sway", 0)
	var flare: int = p.get("flare", 0)
	var glow: int = p.get("glow", 4)
	var hurt: bool = p.get("hurt", false)
	var cast: int = p.get("cast", 0)
	var dash: bool = p.get("dash", false)
	var kneel: int = p.get("kneel", 0)
	if kneel > 0:
		return _death(kneel, glow)
	var side := dir == "side"
	var up := dir == "up"
	var lean := 2 if dash and side else 0
	if hurt:
		lean = -1 if side else 0
	var oy := by + (1 if dash else 0)

	# --- Lantern behind body (back view) ---
	if up and cast == 0:
		_lantern(c, 20, 20 + oy, glow)

	# --- Legs ---
	var legm := c.mask()
	if side:
		var ax: int = 15 + legs[0]
		var bx: int = 15 + legs[2]
		legm.rect(bx, 26 + oy - legs[3], 2, 4 - (0 if legs[3] == 0 else 0), true)
		legm.rect(ax, 26 + oy - legs[1], 2, 4, true)
	else:
		legm.rect(13, 26 + oy - legs[1], 2, 4)
		legm.rect(17, 26 + oy - legs[3], 2, 4)
	c.paint(legm, [Pal.INK, Pal.EARTH[0], Pal.EARTH[1], Pal.EARTH[2]], 2, false, true)

	# --- Scarf tail (behind cloak) ---
	var tail := c.mask()
	if side:
		tail.poly(V([[12 + lean, 16 + oy], [13 + lean, 18 + oy], [8 - flare - sway, 21 + oy], [7 - flare - sway, 19 + oy]]))
	elif up:
		tail.poly(V([[15, 16 + oy], [18, 16 + oy], [18 + sway, 23 + oy], [16 + sway, 23 + oy]]))
	else:
		tail.poly(V([[19, 16 + oy], [21, 17 + oy], [23 + sway, 22 + oy], [21 + sway, 22 + oy]]))
	c.paint(tail, Pal.EMBER, 2)

	# --- Cloak / body ---
	var cloak := c.mask()
	if side:
		cloak.poly(V([[12 + lean, 15 + oy], [20 + lean, 15 + oy], [21 + lean, 27 + oy], [10 - flare, 27 + oy], [11 - flare / 2, 21 + oy]]))
	else:
		var hw := 1 if dash else 0
		cloak.poly(V([[11, 15 + oy], [21, 15 + oy], [23 + hw + sway / 2, 27 + oy], [9 - hw - sway / 2, 27 + oy]]))
	# tattered hem
	for x in 32:
		if (x + sway) % 3 == 0:
			cloak.set_bit(x, 26 + oy, false)
	c.paint(cloak, Pal.CLOAK, 2, true)
	if not side and not up:
		# open front showing leather tunic and belt
		var tunic := c.mask().poly(V([[14, 18 + oy], [18, 18 + oy], [19, 26 + oy], [13, 26 + oy]]))
		c.paint(tunic, Pal.EARTH, 2)
		for x in range(13, 19):
			c.put(x, 22 + oy, Pal.EARTH[1])
		c.put(16, 22 + oy, Pal.GOLD[3])
	elif up:
		for y in range(17, 26):
			c.put(16, y + oy, Pal.CLOAK[1])
	else:
		var tunic := c.mask().poly(V([[17 + lean, 18 + oy], [20 + lean, 18 + oy], [21 + lean, 26 + oy], [17 + lean, 26 + oy]]))
		c.paint(tunic, Pal.EARTH, 2)
		for x in range(17, 21):
			c.put(x + lean, 22 + oy, Pal.EARTH[1])

	# --- Scarf wrap ---
	var scarf := c.mask()
	if side:
		scarf.rect(12 + lean, 15 + oy, 9, 3)
	else:
		scarf.rect(11, 15 + oy, 10, 3)
	c.paint(scarf, Pal.EMBER, 2)

	# --- Hood ---
	var hood := c.mask()
	var hx := 16.0 + (0.5 + lean if side else 0.0)
	var hy := 10.5 + oy
	hood.ellipse(hx, hy, 6.0, 5.6)
	if side:
		hood.poly(V([[13 + lean, 7 + oy], [7 - sway, 5 + oy], [12 + lean, 11 + oy]]))
	else:
		hood.poly(V([[17, 6 + oy], [22 + sway, 3 + oy], [20, 9 + oy]]))
	c.paint(hood, Pal.CLOAK, 3, true)
	# hood rim
	if not up:
		var face := c.mask()
		if side:
			face.ellipse(19.5 + lean, 11.5 + oy, 2.8, 3.0)
		else:
			face.ellipse(16.0, 11.8 + oy, 3.4, 3.0)
		var rim := c.mask()
		if side:
			rim.ellipse(19.5 + lean, 11.5 + oy, 3.8, 4.0)
		else:
			rim.ellipse(16.0, 11.8 + oy, 4.4, 4.0)
		rim.subtract(face)
		for y in 32:
			for x in 32:
				if rim.has(x, y) and hood.has(x, y) and y < 12 + oy:
					c.put(x, y, Pal.CLOAK[4])
		c.fill(face, Pal.INK)
		var eye := Pal.WHITE if hurt else Pal.EMBER[5]
		var eye2 := Pal.EMBER[3]
		if side:
			c.lit(20 + lean, 11 + oy, eye)
			c.lit(21 + lean, 11 + oy, eye2)
		else:
			c.lit(14, 12 + oy, eye)
			c.lit(17, 12 + oy, eye)
	else:
		# seam on the back of the hood
		for y in range(7, 15):
			c.put(16, y + oy, Pal.CLOAK[2])

	# --- Lantern + arm ---
	if cast > 0:
		var ly := 6 + oy if cast == 2 else 9 + oy
		var lx := 21 if not side else 22 + lean
		var arm := c.mask().rect(lx - 1, ly + 3, 2, 17 + oy - ly - 3)
		c.paint(arm, Pal.CLOAK, 2)
		_lantern(c, lx, ly, glow)
	elif side:
		var arm := c.mask().poly(V([[19 + lean, 17 + oy], [21 + lean, 17 + oy], [23 + lean, 20 + oy], [21 + lean, 21 + oy]]))
		c.paint(arm, Pal.CLOAK, 2)
		_lantern(c, 22 + lean, 20 + oy, glow)
	elif not up:
		var arm := c.mask().rect(20, 17 + oy, 2, 4)
		c.paint(arm, Pal.CLOAK, 2)
		_lantern(c, 21, 20 + oy, glow)

	c.outline(Pal.INK)
	# warm lantern spill on nearby cloth (after outline so it stays subtle)
	return c


static func _lantern(c: Px, x: int, y: int, glow: int) -> void:
	# handle
	c.put(x + 1, y - 1, Pal.STEEL[2])
	c.put(x, y, Pal.STEEL[1])
	c.put(x + 1, y, Pal.STEEL[3])
	c.put(x + 2, y, Pal.STEEL[1])
	for yy in range(y + 1, y + 4):
		c.put(x, yy, Pal.STEEL[1])
		c.lit(x + 1, yy, Pal.ramp(Pal.EMBER, glow + (1 if yy == y + 2 else 0)))
		c.put(x + 2, yy, Pal.STEEL[1])
	c.put(x, y + 4, Pal.STEEL[0])
	c.put(x + 1, y + 4, Pal.STEEL[2])
	c.put(x + 2, y + 4, Pal.STEEL[0])


static func _death(stage: int, glow: int) -> Px:
	var c := Px.new(32, 32)
	match stage:
		1, 2:
			var oy := 3 if stage == 1 else 6
			var cloak := c.mask().poly(V([[11, 15 + oy], [21, 15 + oy], [24, 27], [8, 27]]))
			c.paint(cloak, Pal.CLOAK, 2, true)
			var scarf := c.mask().rect(11, 15 + oy, 10, 3)
			c.paint(scarf, Pal.EMBER, 2)
			var hood := c.mask().ellipse(16.0 + stage, 10.5 + oy, 6.0, 5.6)
			c.paint(hood, Pal.CLOAK, 3, true)
			var face := c.mask().ellipse(16.0 + stage, 12.5 + oy, 3.4, 2.4)
			c.fill(face, Pal.INK)
			c.lit(14 + stage, 13 + oy, Pal.EMBER[3])
			c.lit(17 + stage, 13 + oy, Pal.EMBER[3])
			_lantern(c, 22, 23, glow)
		3, 4:
			var flat := 1 if stage == 3 else 0
			var cloak := c.mask().ellipse(16.0, 26.0, 10.0, 3.5 + flat)
			c.paint(cloak, Pal.CLOAK, 2, true)
			var hood := c.mask().ellipse(21.0, 24.5 - flat, 4.5, 3.0 + flat)
			c.paint(hood, Pal.CLOAK, 3)
			var scarf := c.mask().poly(V([[12, 25], [18, 24], [17, 27], [10, 28]]))
			c.paint(scarf, Pal.EMBER, 2)
			_lantern(c, 6, 23, glow)
		_:
			var cloak := c.mask().ellipse(16.0, 27.0, 10.0, 2.5)
			c.paint(cloak, Pal.CLOAK, 1)
			_lantern(c, 6, 24, glow)
	c.outline(Pal.INK)
	return c
