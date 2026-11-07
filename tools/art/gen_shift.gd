## The Shifting Undervault: locked ways and what opens them, the marks a floor
## carries of what was done to it, and the things in a room you can turn on a fight.
## Everything here stands in the world, lit by the world; only what truly burns or
## holds soul-light is marked emissive.
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
	_bars(dir, "lock_bars", Pal.GOLD, Pal.EMBER[3])
	_bars(dir, "pale_bars", Pal.GLOAM, Color8(214, 196, 255))
	_lock(dir)
	_key_altar(dir)
	_lever(dir)
	_cold_lantern(dir)
	_strut(dir)
	_kindle_jar(dir)
	_rime_vent(dir)
	_rubble(dir)
	_scar(dir)
	_vigil_lamp(dir)
	_pale_growth(dir)
	_chart_table(dir)
	_noticeboard(dir)
	_whetstone(dir)
	_spoor(dir)


# --- locked ways ------------------------------------------------------------------

## One tile of a barred doorway: heavy bars that slide up into the lintel.
static func _bars(dir: String, name: String, ramp: Array, stud: Color) -> void:
	var s := Sheet.new(16, 30, Vector2i(8, 29))
	s.add("shut", [_bar_frame(0, ramp, stud)], 1.0)
	s.add("open", [_bar_frame(6, ramp, stud), _bar_frame(13, ramp, stud), _bar_frame(20, ramp, stud), _bar_frame(27, ramp, stud)], 9.0, false)
	s.save(dir, name)


static func _bar_frame(lift: int, ramp: Array, stud: Color) -> Px:
	var c := Px.new(16, 30)
	for x in [1, 6, 11]:
		var h := 29 - lift
		if h > 4:
			c.paint(c.mask().rect(x, 3, 4, h - 3), ramp, 2, true)
	# cross-braces ride up with the bars
	for y in [10 - lift, 20 - lift]:
		if y > 3:
			c.paint(c.mask().rect(0, y, 16, 3), ramp, 1, false, true)
			c.put(3, y + 1, stud)
			c.put(8, y + 1, stud)
			c.put(13, y + 1, stud)
	c.paint(c.mask().rect(0, 0, 16, 4), Pal.STONE, 2, true)
	c.outline(Pal.INK)
	return c


## The plate beside a locked way: what it wants is written on it.
static func _lock(dir: String) -> void:
	var s := Sheet.new(22, 26, Vector2i(11, 25))
	s.add("key", [_lock_frame(Pal.GOLD, Pal.EMBER[3], 0), _lock_frame(Pal.GOLD, Pal.EMBER[3], 1)], 2.0)
	s.add("open", [_lock_frame(Pal.STONE, Pal.STONE[1], 0)], 1.0)
	s.add("pale", [_lock_frame(Pal.GLOAM, Color8(214, 196, 255), 0), _lock_frame(Pal.GLOAM, Color8(214, 196, 255), 1)], 2.0)
	s.save(dir, "lock_plate")


static func _lock_frame(ramp: Array, glow: Color, pulse: int) -> Px:
	var c := Px.new(22, 26)
	c.paint(c.mask().rect(9, 16, 4, 9), Pal.STONE, 2, true)
	c.paint(c.mask().rect(6, 23, 10, 2), Pal.STONE, 2)
	var plate := c.mask().ellipse(11.0, 10.0, 8.5, 8.5)
	c.paint(plate, ramp, 2, true)
	c.paint(c.mask().ellipse(11.0, 10.0, 5.5, 5.5), ramp, 1, false, false)
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0) * 7.0
		c.put(11 + roundi(d.x), 10 + roundi(d.y), ramp[3])
	# the keyhole
	c.fill(c.mask().ellipse(11.0, 8.5, 2.0, 2.0), Pal.INK)
	c.fill(c.mask().rect(10, 9, 3, 5), Pal.INK)
	c.lit(11, 9 + pulse, glow)
	c.outline(Pal.INK)
	return c


## A key on a low stone, lit from under itself: worth walking toward from afar.
static func _key_altar(dir: String) -> void:
	var s := Sheet.new(24, 30, Vector2i(12, 29))
	var fr: Array = []
	for i in 4:
		fr.append(_altar_frame([0, -1, -2, -1][i], true))
	s.add("idle", fr, 4.0)
	s.add("taken", [_altar_frame(0, false)], 1.0)
	s.save(dir, "key_altar")


static func _altar_frame(b: int, key: bool) -> Px:
	var c := Px.new(24, 30)
	c.paint(c.mask().poly(V([[5, 18], [18, 18], [20, 28], [3, 28]])), Pal.STONE, 2, true)
	c.paint(c.mask().rect(3, 15, 18, 3), Pal.STONE, 3, true)
	c.line(6, 22, 17, 22, Pal.STONE[1])
	c.line(7, 25, 16, 25, Pal.STONE[1])
	if key:
		var y := 6 + b
		c.fill_lit(c.mask().ellipse(12.0, y + 1.0, 3.5, 3.5), Pal.GOLD[4])
		c.fill(c.mask().ellipse(12.0, y + 1.0, 1.5, 1.5), Pal.INK)
		c.paint(c.mask().rect(11, y + 4, 3, 7), Pal.GOLD, 3)
		c.lit(14, y + 8, Pal.GOLD[3])
		c.lit(14, y + 10, Pal.GOLD[3])
		c.lit(12, y + 12, Pal.EMBER[3])
	c.outline(Pal.INK)
	return c


static func _lever(dir: String) -> void:
	var s := Sheet.new(16, 24, Vector2i(8, 23))
	s.add("up", [_lever_frame(-1)], 1.0)
	s.add("down", [_lever_frame(1)], 1.0)
	s.save(dir, "lever")


static func _lever_frame(side: int) -> Px:
	var c := Px.new(16, 24)
	c.paint(c.mask().rect(4, 16, 8, 7), Pal.STONE, 2, true)
	c.paint(c.mask().rect(3, 21, 10, 2), Pal.STONE, 1)
	var tip := Vector2i(8 + side * 5, 6)
	var m := c.mask()
	m.line(8, 17, tip.x, tip.y)
	m.line(9, 17, tip.x + 1, tip.y)
	c.paint(m, Pal.STEEL, 2, false, true)
	c.paint(c.mask().ellipse(float(tip.x), float(tip.y), 2.6, 2.6), Pal.BLOOD, 3, true)
	c.outline(Pal.INK)
	return c


## Where you fell: your own lantern, gone cold, on its side.
static func _cold_lantern(dir: String) -> void:
	var s := Sheet.new(18, 18, Vector2i(9, 17))
	s.add("cold", [_lantern_frame(false, 0)], 1.0)
	s.add("lit", [_lantern_frame(true, 0), _lantern_frame(true, 1)], 5.0)
	s.save(dir, "cold_lantern")


static func _lantern_frame(lit: bool, flick: int) -> Px:
	var c := Px.new(18, 18)
	c.paint(c.mask().rect(4, 8, 10, 7), Pal.STEEL, 1, true)
	c.line(3, 15, 14, 15, Pal.STEEL[0])
	c.line(4, 7, 13, 7, Pal.STEEL[2])
	var glass := c.mask().rect(6, 9, 6, 5)
	if lit:
		c.fill_lit(glass, Pal.EMBER[3 + flick])
		c.lit(8 + flick, 11, Pal.GOLD[4])
	else:
		c.fill(glass, Pal.ASH[1])
		c.put(8, 11, Pal.ASH[0])
	var ring := c.mask()
	ring.line(6, 6, 7, 4)
	ring.line(7, 4, 10, 4)
	ring.line(10, 4, 11, 6)
	c.paint(ring, Pal.STEEL, 2, false, false)
	c.outline(Pal.INK)
	return c


# --- what you can turn on a fight -------------------------------------------------

## A column already failing: a blow brings it down across the room.
static func _strut(dir: String) -> void:
	var s := Sheet.new(24, 44, Vector2i(12, 43))
	s.add("whole", [_strut_frame(0)], 1.0)
	s.add("shake", [_strut_frame(1), _strut_frame(2)], 14.0)
	s.add("down", [_strut_frame(3)], 1.0)
	s.save(dir, "strut")


static func _strut_frame(st: int) -> Px:
	var c := Px.new(24, 44)
	if st == 3:
		c.paint(c.mask().ellipse(12.0, 39.0, 10.0, 4.0), Pal.STONE, 1, true)
		c.paint(c.mask().ellipse(7.0, 36.0, 4.0, 3.0), Pal.STONE, 2, true)
		c.paint(c.mask().ellipse(16.0, 37.0, 4.5, 3.0), Pal.STONE, 2, true)
		c.paint(c.mask().rect(5, 30, 7, 6), Pal.STONE, 2, true)
		c.outline(Pal.INK)
		return c
	var ox := 0 if st == 0 else (1 if st == 1 else -1)
	c.paint(c.mask().rect(4, 37, 16, 6), Pal.STONE, 2, true)
	c.paint(c.mask().rect(7 + ox, 8, 10, 30), Pal.STONE, 3, true)
	c.paint(c.mask().rect(5 + ox, 3, 14, 6), Pal.STONE, 2, true)
	# the crack that tells you: bright enough to read from across a fight
	var pts := [[12, 9], [10, 14], [13, 18], [9, 23], [12, 28], [10, 33]]
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		c.line(a[0] + ox, a[1], b[0] + ox, b[1], Pal.INK)
		c.lit(a[0] + ox + 1, a[1], Pal.EMBER[3])
	c.outline(Pal.INK)
	return c


## Ember in a stoppered jar. Fragile, and it does not care who breaks it.
static func _kindle_jar(dir: String) -> void:
	var s := Sheet.new(16, 20, Vector2i(8, 19))
	var fr: Array = []
	for i in 3:
		fr.append(_jar_frame(i))
	s.add("idle", fr, 5.0)
	s.save(dir, "kindle_jar")


static func _jar_frame(f: int) -> Px:
	var c := Px.new(16, 20)
	var body := c.mask().ellipse(8.0, 12.0, 6.0, 6.5)
	body.rect(5, 4, 6, 4)
	c.paint(body, Pal.EARTH, 2, true)
	c.paint(c.mask().rect(4, 3, 8, 2), Pal.WOOD, 2)
	# bands of light through the clay's cracks
	for k in 3:
		c.lit(5 + k * 3, 10 + (k + f) % 3, Pal.EMBER[3 + (k + f) % 2])
		c.lit(6 + k * 2, 14 - (k + f) % 2, Pal.EMBER[3])
	c.outline(Pal.INK)
	return c


## A crack in the floor breathing cold. Struck, it lets go.
static func _rime_vent(dir: String) -> void:
	var s := Sheet.new(22, 14, Vector2i(11, 13))
	s.add("idle", [_vent_frame(0), _vent_frame(1)], 3.0)
	s.add("spent", [_vent_frame(2)], 1.0)
	s.save(dir, "rime_vent")


static func _vent_frame(st: int) -> Px:
	var c := Px.new(22, 14)
	c.paint(c.mask().ellipse(11.0, 9.0, 9.5, 4.0), Pal.STONE, 2, true)
	c.fill(c.mask().ellipse(11.0, 9.0, 6.0, 2.0), Pal.INK)
	if st < 2:
		c.lit(7 + st, 9, Pal.FROST[4])
		c.lit(11, 8 + st, Pal.FROST[4])
		c.lit(15 - st, 9, Pal.FROST[3])
		c.lit(9, 5 - st, Pal.FROST[3])
		c.lit(13, 4 + st, Pal.FROST[3])
	c.outline(Pal.INK)
	return c


# --- what a floor remembers -------------------------------------------------------

static func _rubble(dir: String) -> void:
	var s := Sheet.new(30, 20, Vector2i(15, 19))
	s.add("a", [_rubble_frame(0)], 1.0)
	s.add("b", [_rubble_frame(1)], 1.0)
	s.save(dir, "rubble")


static func _rubble_frame(v: int) -> Px:
	var c := Px.new(30, 20)
	c.paint(c.mask().ellipse(15.0, 15.0, 13.0, 4.0), Pal.STONE, 1, true)
	c.paint(c.mask().rect(5 + v * 3, 7, 9, 8), Pal.STONE, 2, true)
	c.paint(c.mask().rect(16 - v * 2, 9, 8, 6), Pal.STONE, 3, true)
	c.paint(c.mask().ellipse(12.0, 14.0, 3.5, 2.5), Pal.STONE, 2, true)
	c.line(8 + v, 8, 11, 13, Pal.STONE[0])
	c.outline(Pal.INK)
	return c


## Cracks in the floor with light in them: red where an altar was broken.
static func _scar(dir: String) -> void:
	var s := Sheet.new(48, 32, Vector2i(24, 16))
	s.add("broken", [_scar_frame(Pal.BLOOD, 1)], 1.0)
	s.add("broken2", [_scar_frame(Pal.BLOOD, 2)], 1.0)
	s.add("pale", [_scar_frame(Pal.GLOAM, 3)], 1.0)
	s.add("kindled", [_scar_frame(Pal.EMBER, 4)], 1.0)
	s.save(dir, "floor_scar")


static func _scar_frame(ramp: Array, seed_v: int) -> Px:
	var c := Px.new(48, 32)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 977
	for arm in 5:
		var a := rng.randf() * TAU
		var p := Vector2(24, 16)
		for st in rng.randi_range(9, 16):
			a += rng.randf_range(-0.6, 0.6)
			p += Vector2.from_angle(a) * Vector2(1.6, 0.9)
			var x := clampi(roundi(p.x), 0, 47)
			var y := clampi(roundi(p.y), 0, 31)
			c.put(x, y, Pal.INK)
			if st % 2 == 0:
				c.lit(x, clampi(y + 1, 0, 31), ramp[3] if st % 4 == 0 else ramp[2])
	return c


## A keeper's lamp on a post, tended. Warm: it is the player's colour, not the dark's.
static func _vigil_lamp(dir: String) -> void:
	var s := Sheet.new(14, 32, Vector2i(7, 31))
	s.add("lit", [_lamp_frame(0), _lamp_frame(1), _lamp_frame(2), _lamp_frame(1)], 6.0)
	s.save(dir, "vigil_lamp")


static func _lamp_frame(f: int) -> Px:
	var c := Px.new(14, 32)
	c.paint(c.mask().rect(6, 10, 2, 20), Pal.WOOD, 2, false, true)
	c.paint(c.mask().rect(3, 28, 8, 3), Pal.STONE, 2, true)
	c.paint(c.mask().rect(3, 4, 8, 8), Pal.STEEL, 1, true)
	c.line(2, 3, 11, 3, Pal.STEEL[2])
	c.line(3, 12, 10, 12, Pal.STEEL[0])
	c.fill_lit(c.mask().rect(4, 5, 6, 6), Pal.EMBER[3])
	c.lit(6 + (f % 2), 7, Pal.GOLD[4])
	c.lit(7, 6 + f, Pal.GOLD[4])
	c.outline(Pal.INK)
	return c


## What a pact grows: pale and soft, and it faces you.
static func _pale_growth(dir: String) -> void:
	var s := Sheet.new(26, 20, Vector2i(13, 19))
	s.add("a", [_growth_frame(0)], 1.0)
	s.add("b", [_growth_frame(1)], 1.0)
	s.save(dir, "pale_growth")


static func _growth_frame(v: int) -> Px:
	var c := Px.new(26, 20)
	var r := [Color8(70, 60, 86), Color8(120, 106, 140), Color8(170, 156, 190), Color8(212, 200, 226), Color8(240, 232, 248)]
	for k in 4:
		var x: int = [6, 11, 16, 20][(k + v) % 4]
		var h: int = [9, 13, 7, 11][k]
		var stem := c.mask()
		stem.line(x, 19, x + (k % 2), 19 - h)
		c.paint(stem, r, 1, false, false)
		c.paint(c.mask().ellipse(float(x + k % 2), 18.0 - h, 2.8, 2.2), r, 3, true)
		c.lit(x + k % 2, 18 - h, Color8(214, 196, 255))
	c.outline(Pal.INK)
	return c


# --- the sanctuary's new corners ----------------------------------------------------

static func _chart_table(dir: String) -> void:
	var s := Sheet.new(44, 34, Vector2i(22, 33))
	var c := Px.new(44, 34)
	c.paint(c.mask().rect(6, 22, 3, 11), Pal.WOOD, 2, true)
	c.paint(c.mask().rect(35, 22, 3, 11), Pal.WOOD, 2, true)
	c.paint(c.mask().poly(V([[3, 14], [40, 14], [43, 23], [0, 23]])), Pal.WOOD, 2, true)
	# the chart: pinned corners, ink rooms, a red route
	c.paint(c.mask().poly(V([[7, 15], [36, 15], [38, 21], [5, 21]])), Pal.BONE, 3, false, false)
	for r in [[11, 16, 5, 2], [19, 17, 6, 2], [28, 16, 4, 3], [14, 19, 5, 1]]:
		c.fill(c.mask().rect(r[0], r[1], r[2], r[3]), Pal.BONE[1])
	c.line(14, 17, 21, 18, Pal.BLOOD[2])
	c.line(21, 18, 29, 17, Pal.BLOOD[2])
	c.paint(c.mask().ellipse(34.0, 12.0, 2.5, 2.5), Pal.GOLD, 3, true)
	c.line(33, 13, 36, 15, Pal.WOOD[0])
	c.paint(c.mask().rect(4, 9, 3, 6), Pal.BONE, 3, true)
	c.put(5, 8, Pal.EMBER[3])
	c.outline(Pal.INK)
	s.add("idle", [c], 1.0)
	s.save(dir, "chart_table")


## A guardian's trail: three deep gouges in the stone and its light still dripping
## from them. Read, it goes dim.
static func _spoor(dir: String) -> void:
	var s := Sheet.new(40, 24, Vector2i(20, 14))
	s.add("fresh", [_spoor_frame(0, true), _spoor_frame(1, true)], 2.5)
	s.add("read", [_spoor_frame(0, false)], 1.0)
	s.save(dir, "spoor")


static func _spoor_frame(k: int, fresh: bool) -> Px:
	var c := Px.new(40, 24)
	for g in 3:
		var x0 := 8 + g * 8
		for t in 14:
			var x := x0 + t
			var y := 4 + roundi(t * 0.9) + (g % 2)
			c.put(x, y, Pal.INK)
			c.put(x, y + 1, Pal.STONE[0])
			if fresh and (t + k + g) % 4 == 0:
				c.lit(x, y + 2, Pal.SOUL[4] if t % 8 == 0 else Pal.SOUL[3])
	if fresh:
		c.lit(26, 19 + k, Pal.SOUL[5])
		c.lit(14, 17, Pal.SOUL[4])
	return c


## A travelling artisan's grindstone: a wheel in a frame, sparks still warm on it.
static func _whetstone(dir: String) -> void:
	var s := Sheet.new(32, 30, Vector2i(16, 28))
	var frames: Array = []
	for k in 2:
		var c := Px.new(32, 30)
		for x in [7, 23]:
			c.paint(c.mask().rect(x, 14, 2, 14), Pal.WOOD, 2, true)
		c.paint(c.mask().rect(5, 24, 22, 3), Pal.WOOD, 1, true)
		c.paint(c.mask().ellipse(16.0, 14.0, 9.0, 9.0), Pal.STONE, 3, true)
		c.paint(c.mask().ellipse(16.0, 14.0, 2.0, 2.0), Pal.STEEL, 3, true)
		c.line(9, 14, 23, 14, Pal.STONE[1])
		c.line(16, 7, 16, 21, Pal.STONE[1])
		for p in [[25, 9 + k], [27, 12 - k], [26, 6 + k * 2]]:
			c.put(p[0], p[1], Pal.GOLD[4])
		c.outline(Pal.INK)
		frames.append(c)
	s.add("idle", frames, 3.0)
	s.save(dir, "whetstone")


static func _noticeboard(dir: String) -> void:
	var s := Sheet.new(40, 44, Vector2i(20, 43))
	s.add("idle", [_board_frame(true)], 1.0)
	s.add("empty", [_board_frame(false)], 1.0)
	s.save(dir, "noticeboard")


static func _board_frame(notes: bool) -> Px:
	var c := Px.new(40, 44)
	c.paint(c.mask().rect(6, 8, 3, 35), Pal.WOOD, 2, true)
	c.paint(c.mask().rect(31, 8, 3, 35), Pal.WOOD, 2, true)
	c.paint(c.mask().rect(3, 8, 34, 22), Pal.WOOD, 1, true)
	c.paint(c.mask().rect(2, 5, 36, 3), Pal.WOOD, 3, true)
	c.line(5, 13, 34, 13, Pal.WOOD[0])
	c.line(5, 21, 34, 21, Pal.WOOD[0])
	if notes:
		for n in [[6, 10, 8, 10], [16, 11, 9, 9], [27, 10, 7, 11], [10, 21, 8, 7], [22, 21, 9, 7]]:
			c.paint(c.mask().rect(n[0], n[1], n[2], n[3]), Pal.BONE, 3, false, false)
			c.line(n[0] + 1, n[1] + 2, n[0] + n[2] - 2, n[1] + 2, Pal.BONE[1])
			c.line(n[0] + 1, n[1] + 4, n[0] + n[2] - 3, n[1] + 4, Pal.BONE[1])
			c.put(n[0] + n[2] / 2, n[1], Pal.BLOOD[3])
	c.outline(Pal.INK)
	return c
