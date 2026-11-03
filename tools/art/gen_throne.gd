## The Sunken Throne: the drowned palace of the last sun-king. Obsidian marble
## mended with gold, ash where there was sunlight, and the court that still
## kneels to a king made of cinders. Tiles, its creatures, the Ashen King and
## their projectiles. All sprites face right.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")
const GenTiles = preload("res://tools/art/gen_tiles.gd")


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


static func build_tiles(dir: String) -> void:
	_floor(dir.path_join("throne_floor.png"), 128, 71)
	GenTiles._wall(dir.path_join("throne_wall.png"), 64, Pal.OBSIDIAN, 2, 72)
	_gold_band(dir.path_join("throne_wall.png"))
	GenTiles._top(dir.path_join("throne_top.png"), 64, Pal.OBSIDIAN, 73)
	GenTiles._ledge(dir.path_join("throne_ledge.png"), 64, Pal.OBSIDIAN, 2, 74)
	GenTiles._pillar(dir.path_join("throne_pillar.png"), Pal.OBSIDIAN, 2)
	_gold_capital(dir.path_join("throne_pillar.png"))


static func build(dir: String) -> void:
	_sentinel(dir)
	_hound(dir)
	_acolyte(dir)
	_wraith(dir)
	_king(dir)
	_projectiles(dir)


# --- tiles ------------------------------------------------------------------------

## Polished obsidian slabs with pale marble veins; the cracks were mended with
## gold (kintsugi), the court's answer to a world falling apart.
static func _floor(path: String, size: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(size, size)
	var tone := {}
	for sy in size / 32:
		for sx in size / 32:
			tone[Vector2i(sx, sy)] = rng.randi_range(-1, 1)
	for y in size:
		for x in size:
			var cell := Vector2i(x / 32, y / 32)
			var lx := x % 32
			var ly := y % 32
			if lx == 31 or ly == 31:
				c.put(x, y, Pal.OBSIDIAN[0])
				continue
			var b := 3 + int(tone[cell]) * (1 if Px.hash01(cell.x, cell.y, seed_v) > 0.5 else 0)
			var idx := b
			if lx == 0 or ly == 0:
				idx = b + 1
			elif lx == 30 or ly == 30:
				idx = b - 1
			var col: Color = Pal.ramp(Pal.OBSIDIAN, idx)
			var v := GenTiles.pnoise(x / 9.0 + GenTiles.pnoise(x / 5.0, y / 5.0, size / 5, seed_v + 2) * 2.0, y / 9.0, size / 9, seed_v + 1)
			if absf(v - 0.5) < 0.025:
				col = Pal.ramp(Pal.OBSIDIAN, b + 2)
			elif absf(v - 0.5) < 0.05:
				col = col.lerp(Pal.ramp(Pal.OBSIDIAN, b + 1), 0.5)
			if Px.hash01(x, y, seed_v * 3) > 0.985:
				col = Pal.ramp(Pal.OBSIDIAN, b + 1)
			c.put(x, y, col)
	# gold-mended cracks wandering across the slabs
	for k in 7:
		var px := rng.randi_range(0, size - 1)
		var py := rng.randi_range(0, size - 1)
		var dir := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		for st in rng.randi_range(14, 30):
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			px = posmod(px + roundi(dir.x), size)
			py = posmod(py + roundi(dir.y), size)
			c.put(px, py, Pal.GOLD[2] if st % 5 != 0 else Pal.GOLD[3])
			if rng.randf() < 0.08:
				c.put(posmod(px + 1, size), py, Pal.GOLD[1])
	c.save(path)


static func _load(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


## A gilded frieze along the top of every wall face, with sun-disc studs.
static func _gold_band(path: String) -> void:
	var img := _load(path)
	var w := img.get_width()
	for x in w:
		img.set_pixel(x, 3, Pal.GOLD[1])
		img.set_pixel(x, 4, Pal.GOLD[3] if x % 16 != 0 else Pal.GOLD[2])
		img.set_pixel(x, 5, Pal.GOLD[2])
		img.set_pixel(x, 6, Pal.OBSIDIAN[0])
	for x0 in range(8, w, 16):
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 0)]:
			img.set_pixel(x0 + d.x, 10 + d.y, Pal.GOLD[4] if d == Vector2i.ZERO else Pal.GOLD[2])
	img.save_png(ProjectSettings.globalize_path(path))


static func _gold_capital(path: String) -> void:
	var img := _load(path)
	for x in 16:
		img.set_pixel(x, 0, Pal.GOLD[4])
		img.set_pixel(x, 1, Pal.GOLD[3])
		img.set_pixel(x, 2, Pal.GOLD[2])
		img.set_pixel(x, 3, Pal.GOLD[1])
		img.set_pixel(x, 28, Pal.GOLD[3])
		img.set_pixel(x, 29, Pal.GOLD[1])
	img.save_png(ProjectSettings.globalize_path(path))


# --- Gilded Sentinel: black plate, a sun-crested helm and a tower shield --------

static func _sentinel(dir: String) -> void:
	var s := Sheet.new(32, 32, Vector2i(16, 30))
	s.add("idle", [sentinel_frame({}), sentinel_frame({"bob": 1})], 2.0)
	var walk: Array = []
	for i in 4:
		walk.append(sentinel_frame({"bob": i % 2, "step": sin(i / 4.0 * TAU)}))
	s.add("walk", walk, 6.0)
	s.add("windup", [sentinel_frame({"shield": -2, "sword": "up", "lean": -1}), sentinel_frame({"shield": -3, "sword": "up", "lean": -2, "bob": 1})], 5.0, false)
	s.add("bash", [sentinel_frame({"shield": 4, "sword": "down", "lean": 2}), sentinel_frame({"shield": 3, "sword": "down", "lean": 1})], 10.0, false)
	s.save(dir, "sentinel")


static func sentinel_frame(p: Dictionary) -> Px:
	var c := Px.new(32, 32)
	var b: int = int(p.get("bob", 0))
	var ln: int = int(p.get("lean", 0))
	var st: float = p.get("step", 0.0)
	var sh: int = int(p.get("shield", 0))
	var sword: String = p.get("sword", "rest")
	var cx := 13 + ln
	# sword arm behind
	match sword:
		"up":
			c.paint(c.mask().rect(cx - 6, 4 + b, 2, 12), Pal.STEEL, 3)
			c.put(cx - 6, 3 + b, Pal.STEEL[5])
			c.paint(c.mask().rect(cx - 8, 15 + b, 6, 2), Pal.GOLD, 2)
		"down":
			limb(c, [[cx - 2, 14 + b], [cx + 6, 19 + b], [cx + 13, 21 + b]], Pal.STEEL, 3)
		_:
			c.paint(c.mask().rect(cx - 7, 12 + b, 2, 13), Pal.STEEL, 3)
			c.paint(c.mask().rect(cx - 9, 12 + b, 6, 2), Pal.GOLD, 2)
	# legs
	var la := cx - 4 + roundi(st * 2.0)
	var lb := cx + 1 - roundi(st * 2.0)
	for lx in [la, lb]:
		c.paint(c.mask().rect(lx, 21 + b / 2, 4, 30 - (21 + b / 2)), Pal.OBSIDIAN, 2, true)
		c.paint(c.mask().rect(lx - 1, 28, 6, 2), Pal.OBSIDIAN, 3)
		c.put(lx + 1, 24, Pal.GOLD[3])
	# tabard and torso
	var tor := c.mask().poly(V([[cx - 6, 10 + b], [cx + 5, 10 + b], [cx + 5, 22 + b], [cx - 6, 22 + b]]))
	c.paint(tor, Pal.OBSIDIAN, 3, true)
	c.paint(c.mask().rect(cx - 2, 14 + b, 3, 10), Pal.BLOOD, 2)
	c.line(cx - 6, 20 + b, cx + 5, 20 + b, Pal.GOLD[2])
	# pauldron
	c.paint(c.mask().ellipse(cx - 4.0, 11.0 + b, 3.6, 2.8), Pal.OBSIDIAN, 4, true)
	c.put(cx - 5, 10 + b, Pal.GOLD[3])
	# great helm with a sun-crest fan
	var hx := cx + 1
	var hy := 6 + b
	for k in 7:
		var a := deg_to_rad(-165.0 + k * 25.0)
		var e := Vector2(hx, hy - 3) + Vector2(cos(a), sin(a)) * 6.5
		c.line(hx, hy - 3, int(e.x), int(e.y), Pal.GOLD[3] if k % 2 == 0 else Pal.GOLD[2])
		c.lit(int(e.x), int(e.y), Pal.GOLD[4])
	var helm := c.mask().rect(hx - 4, hy - 3, 8, 8)
	helm.ellipse(hx, hy - 3, 4.0, 2.0)
	c.paint(helm, Pal.OBSIDIAN, 3, true)
	c.line(hx - 1, hy, hx + 3, hy, Pal.INK)
	c.lit(hx + 1, hy, Pal.GOLD[4])
	c.lit(hx + 2, hy, Pal.GOLD[3])
	c.line(hx - 4, hy + 4, hx + 3, hy + 4, Pal.GOLD[2])
	# tower shield with the sun of the old court
	var sx := mini(cx + 6 + sh, 24)
	var shm := c.mask().rect(sx, 9 + b, 7, 17)
	shm.ellipse(sx + 3.5, 25.0 + b, 3.5, 2.0)
	c.paint(shm, Pal.GOLD, 2, true)
	c.paint(c.mask().rect(sx + 1, 10 + b, 5, 15), Pal.OBSIDIAN, 2)
	var sun := c.mask().ellipse(sx + 3.5, 16.5 + b, 2.2, 2.2)
	c.fill(sun, Pal.GOLD[3])
	c.lit(sx + 3, 16 + b, Pal.GOLD[4])
	for d in [Vector2i(0, -4), Vector2i(0, 4), Vector2i(-2, -3), Vector2i(2, 3), Vector2i(2, -3), Vector2i(-2, 3)]:
		c.put(sx + 3 + d.x, 16 + b + d.y, Pal.GOLD[2])
	c.outline(Pal.INK)
	return c


# --- Ash Hound: a cinder-hound with embers smouldering through its ribs ---------

static func _hound(dir: String) -> void:
	var s := Sheet.new(22, 16, Vector2i(11, 14))
	s.add("idle", [hound_frame({}), hound_frame({"breath": 1})], 3.0)
	var run: Array = []
	for i in 4:
		run.append(hound_frame({"run": i, "bob": [0, 1, 0, -1][i]}))
	s.add("run", run, 12.0)
	s.add("crouch", [hound_frame({"crouch": true})], 1.0, false)
	s.add("leap", [hound_frame({"leap": true}), hound_frame({"leap": true, "bob": -1})], 10.0, false)
	s.save(dir, "hound")


static func hound_frame(p: Dictionary) -> Px:
	var c := Px.new(22, 16)
	var b: int = int(p.get("bob", 0))
	var crouch: bool = p.get("crouch", false)
	var leap: bool = p.get("leap", false)
	var r: int = int(p.get("run", -1))
	var by := 8 + b + (2 if crouch else 0)
	# legs (back pair darker)
	var legs: Array = [[6, 3], [8, 2], [13, 3], [15, 2]]
	for i in 4:
		var lx: int = legs[i][0]
		var off := 0
		if r >= 0:
			off = [[-2, 1, 2, -1], [1, 2, -1, -2], [2, -1, -2, 1], [-1, -2, 1, 2]][r][i]
		if leap:
			off = -3 if i < 2 else 3
		var col: Array = Pal.ASH if i % 2 == 1 else [Pal.INK, Pal.ASH[0], Pal.ASH[1], Pal.ASH[2]]
		limb(c, [[lx, by + 2], [lx + off / 2, by + 4], [lx + off, 14 if not leap else by + 5]], col, 1, 1)
	# body
	var body := c.mask().ellipse(10.5, by + 0.5, 6.5, 3.0)
	c.paint(body, Pal.ASH, 2, true)
	# ember cracks along the ribs
	for x in [7, 9, 11, 13]:
		c.lit(x, by + int(p.get("breath", 0)), Pal.EMBER[3] if x % 4 == 1 else Pal.EMBER[2])
		c.put(x, by + 1, Pal.ASH[0])
	# tail of smoke and sparks
	c.line(4, by - 1, 1, by - 3 - b, Pal.ASH[1])
	c.lit(1, by - 4 - b, Pal.EMBER[3])
	# head
	var hx := 17 + (1 if leap else 0)
	var hy := by - 2 - (1 if crouch else 0)
	var head := c.mask().ellipse(hx, hy, 3.0, 2.4)
	head.rect(hx, hy, 4, 2)
	c.paint(head, Pal.ASH, 3, true)
	c.put(hx - 1, hy - 3, Pal.ASH[2])
	c.put(hx - 2, hy - 3, Pal.ASH[1])
	c.lit(hx + 1, hy - 1, Pal.EMBER[4])
	c.put(hx + 3, hy + 1, Pal.INK)
	if leap or crouch:
		c.lit(hx + 2, hy + 2, Pal.EMBER[3])
	c.outline(Pal.INK)
	return c


# --- Eclipse Acolyte: a hooded priest bearing the black sun ------------------

static func _acolyte(dir: String) -> void:
	var s := Sheet.new(24, 32, Vector2i(12, 30))
	var idle: Array = []
	for i in 4:
		idle.append(acolyte_frame({"bob": [0, 1, 1, 0][i], "hem": i}))
	s.add("idle", idle, 4.0)
	var cast: Array = []
	for i in 4:
		cast.append(acolyte_frame({"bob": i % 2, "hem": i, "cast": true, "glow": i}))
	s.add("cast", cast, 8.0)
	s.save(dir, "acolyte")


static func acolyte_frame(p: Dictionary) -> Px:
	var c := Px.new(24, 32)
	var b: int = int(p.get("bob", 0))
	var hem: int = int(p.get("hem", 0))
	var cast: bool = p.get("cast", false)
	var glow: int = int(p.get("glow", 0))
	# robe, fraying into ash at the hem
	var robe := c.mask().poly(V([[9, 9 + b], [15, 9 + b], [18, 27 + b], [6, 27 + b]]))
	for x in range(6, 19):
		if (x + hem) % 3 == 0:
			robe.set_bit(x, 26 + b, false)
			robe.set_bit(x, 25 + b, false)
	c.paint(robe, Pal.OBSIDIAN, 2, true)
	c.line(7, 24 + b, 17, 24 + b, Pal.GOLD[2])
	c.line(12, 12 + b, 12, 23 + b, Pal.GOLD[1])
	for x in range(7, 18, 3):
		if (x + hem) % 2 == 0:
			c.put(x, 28 + b + (x % 2), Pal.ASH[2])
	# hood with the dark inside and two small suns for eyes
	var hood := c.mask().ellipse(12.5, 6.5 + b, 4.5, 4.8)
	hood.poly(V([[8, 7 + b], [17, 7 + b], [16, 11 + b], [9, 11 + b]]))
	c.paint(hood, Pal.OBSIDIAN, 3, true)
	c.paint(c.mask().ellipse(13.5, 7.5 + b, 2.6, 2.8), [Pal.INK, Pal.INK, Pal.VOID], 1, false, false)
	c.lit(13, 7 + b, Pal.GOLD[4])
	c.lit(15, 7 + b, Pal.GOLD[4])
	# the black sun
	var dx := 17
	var dy := 15 + b
	if cast:
		dx = 17
		dy = 11 + b
	var rr := 3.4 + (1.0 + 0.6 * (glow % 2) if cast else 0.0)
	var corona := c.mask().ellipse(dx, dy, rr + 1.5, rr + 1.5)
	corona.subtract(c.mask().ellipse(dx, dy, rr - 0.5, rr - 0.5))
	c.fill_lit(corona, Pal.GOLD[3] if glow % 2 == 0 else Pal.GOLD[4])
	c.fill(c.mask().ellipse(dx, dy, rr - 0.5, rr - 0.5), Pal.INK)
	c.lit(dx - 1, dy - 1, Pal.GLOAM[2])
	# hands
	if cast:
		limb(c, [[14, 11 + b], [16, 12 + b]], Pal.ASH, 2, 1)
		limb(c, [[14, 13 + b], [16, 15 + b]], Pal.ASH, 2, 1)
	else:
		limb(c, [[14, 12 + b], [16, 15 + b]], Pal.ASH, 2, 1)
	c.outline(Pal.INK)
	return c


# --- Ash Wraith: what is left of a courtier, hurling lances of dead sunlight --

static func _wraith(dir: String) -> void:
	var s := Sheet.new(24, 24, Vector2i(12, 22))
	var idle: Array = []
	for i in 4:
		idle.append(wraith_frame({"bob": [0, 1, 1, 0][i], "tail": i}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 4:
		walk.append(wraith_frame({"bob": i % 2, "tail": i + 1, "lean": 1}))
	s.add("walk", walk, 8.0)
	s.add("aim", [wraith_frame({"arm": "draw", "tail": 0}), wraith_frame({"arm": "draw", "tail": 1, "glow": 1})], 6.0)
	s.add("shoot", [wraith_frame({"arm": "throw", "tail": 2, "lean": 2}), wraith_frame({"arm": "throw", "tail": 3, "lean": 1})], 10.0, false)
	s.save(dir, "wraith")


static func wraith_frame(p: Dictionary) -> Px:
	var c := Px.new(24, 24)
	var b: int = int(p.get("bob", 0))
	var tail: int = int(p.get("tail", 0))
	var ln: int = int(p.get("lean", 0))
	var arm: String = p.get("arm", "idle")
	var glow: int = int(p.get("glow", 0))
	# smoke tail instead of legs
	var body := c.mask().poly(V([[8 + ln, 8 + b], [15 + ln, 8 + b], [14 + ln, 15 + b], [11 + (tail % 3) - 1, 21], [9 + ln, 15 + b]]))
	c.paint(body, Pal.ASH, 2, true)
	for y in range(16, 22):
		for x in range(8, 16):
			if body.has(x, y) and Px.bayer(x + tail, y) < (y - 15) / 7.0:
				c.put(x, y, Pal.CLEAR)
	# ember-burnt hem lines
	c.lit(10 + ln, 14 + b, Pal.EMBER[2])
	c.lit(13 + ln, 13 + b, Pal.EMBER[2])
	# head: a cracked mask
	var hx := 13 + ln
	var hy := 5 + b
	var head := c.mask().ellipse(hx, hy, 3.4, 3.6)
	c.paint(head, Pal.BONE, 3, true)
	c.put(hx - 2, hy - 3, Pal.ASH[3])
	c.lit(hx + 1, hy, Pal.GOLD[4])
	c.lit(hx + 2, hy, Pal.GOLD[3])
	c.line(hx - 1, hy + 2, hx + 2, hy + 2, Pal.BONE[1])
	c.put(hx, hy - 2, Pal.INK)
	c.put(hx - 1, hy - 1, Pal.INK)
	# arm and lance
	match arm:
		"draw":
			limb(c, [[hx - 1, 9 + b], [hx - 4, 9 + b], [hx - 6, 7 + b]], Pal.ASH, 3, 1)
			var lm := c.mask()
			lm.line(hx - 9, 7 + b, hx + 6, 4 + b)
			c.fill_lit(lm, Pal.GOLD[4] if glow == 1 else Pal.GOLD[3])
			c.lit(hx + 6, 4 + b, Pal.WHITE)
		"throw":
			limb(c, [[hx - 1, 9 + b], [hx + 3, 9 + b], [hx + 7, 8 + b]], Pal.ASH, 3, 1)
		_:
			limb(c, [[hx - 1, 9 + b], [hx + 1, 12 + b], [hx + 2, 14 + b]], Pal.ASH, 3, 1)
	c.outline(Pal.INK)
	return c


# --- The Ashen King -----------------------------------------------------------
## A towering king of cinders: a crimson mantle, black-gold plate, a crown of
## ash and the eclipse burning behind his head; a greatsword with a molten edge.
## 64x64 frames, feet at (32, 60).

static func _king(dir: String) -> void:
	var s := Sheet.new(64, 64, Vector2i(32, 60))
	var idle: Array = []
	for i in 4:
		idle.append(king_frame({"bob": [0, 1, 1, 0][i], "sw": 70.0, "cape": i % 2, "glow": i % 2}))
	s.add("idle", idle, 4.0)
	var walk: Array = []
	for i in 4:
		walk.append(king_frame({"bob": i % 2, "sw": 65.0, "step": sin(i / 4.0 * TAU), "cape": i % 2}))
	s.add("walk", walk, 6.0)
	s.add("windup", [king_frame({"sw": 150.0, "lean": -2, "bob": 1}), king_frame({"sw": 165.0, "lean": -3, "bob": 2, "glow": 1})], 5.0, false)
	s.add("sweep", [king_frame({"sw": 20.0, "lean": 2}), king_frame({"sw": -15.0, "lean": 3}), king_frame({"sw": -35.0, "lean": 2})], 12.0, false)
	s.add("thrust", [king_frame({"sw": 0.0, "lean": 4, "reach": 6}), king_frame({"sw": 0.0, "lean": 3, "reach": 4})], 10.0, false)
	s.add("crouch", [king_frame({"sw": 120.0, "bob": 5, "lean": -1})], 1.0, false)
	s.add("air", [king_frame({"sw": 140.0, "bob": -1})], 1.0, false)
	s.add("slam", [king_frame({"sw": -60.0, "bob": 4, "lean": 3}), king_frame({"sw": -55.0, "bob": 3, "lean": 2})], 8.0, false)
	s.add("cast", [king_frame({"sw": 75.0, "hand_up": true, "glow": 1}), king_frame({"sw": 75.0, "hand_up": true, "glow": 2})], 6.0)
	s.add("roar", [king_frame({"sw": 95.0, "roar": true, "bob": -1, "glow": 2}), king_frame({"sw": 100.0, "roar": true, "glow": 1})], 6.0)
	s.add("stagger", [king_frame({"sw": 20.0, "bob": 4, "lean": -3, "slump": true}), king_frame({"sw": 15.0, "bob": 5, "lean": -3, "slump": true})], 3.0)
	s.save(dir, "ashen_king")


static func king_frame(p: Dictionary) -> Px:
	var c := Px.new(64, 64)
	var b: int = int(p.get("bob", 0))
	var ln: int = int(p.get("lean", 0))
	var sw: float = p.get("sw", 70.0)
	var st: float = p.get("step", 0.0)
	var cape: int = int(p.get("cape", 0))
	var glow: int = int(p.get("glow", 0))
	var roar: bool = p.get("roar", false)
	var slump: bool = p.get("slump", false)
	var cx := 30 + ln
	var hy := 15 + b + (2 if slump else 0)
	var hx := cx + 1 + (1 if roar else 0)
	# --- the eclipse behind his head: a black sun with a burning corona ---
	var er := 7.5 + glow * 0.5
	var cor := c.mask().ellipse(hx - 1, hy - 2, er + 2.5, er + 2.5)
	for k in 12:
		var a := k * TAU / 12.0 + (0.13 if glow % 2 == 1 else 0.0)
		var tip := Vector2(hx - 1, hy - 2) + Vector2(cos(a), sin(a)) * (er + 5.5)
		cor.line(hx - 1, hy - 2, int(tip.x), int(tip.y))
	cor.subtract(c.mask().ellipse(hx - 1, hy - 2, er, er))
	c.fill_lit(cor, Pal.GOLD[3])
	var rim := c.mask().ellipse(hx - 1, hy - 2, er + 1.0, er + 1.0)
	rim.subtract(c.mask().ellipse(hx - 1, hy - 2, er, er))
	c.fill_lit(rim, Pal.GOLD[4] if glow < 2 else Pal.WHITE)
	c.fill(c.mask().ellipse(hx - 1, hy - 2, er, er), Pal.INK)
	# --- crimson mantle ---
	var cp := c.mask().poly(V([[cx - 7, 19 + b], [cx + 5, 19 + b], [cx - 1, 52 + b], [cx - 15 - cape, 56 + b], [cx - 17 - cape, 38 + b]]))
	for x in range(cx - 19, cx + 2):
		if (x + cape) % 3 == 0:
			cp.set_bit(x, 56 + b, false)
			cp.set_bit(x, 55 + b, false)
	c.paint(cp, Pal.BLOOD, 1, true)
	for y in range(40 + b, 56 + b, 3):
		c.lit(cx - 13 - cape + (y % 2), y, Pal.EMBER[2])
	# --- legs ---
	var la := cx - 7 + roundi(st * 3.0)
	var lb := cx + 3 - roundi(st * 3.0)
	for lx in [la, lb]:
		c.paint(c.mask().rect(lx, 44 + b / 2, 6, 61 - (44 + b / 2)), Pal.OBSIDIAN, 2, true)
		c.paint(c.mask().rect(lx - 1, 57, 8, 4), Pal.OBSIDIAN, 3)
		c.put(lx + 2, 50 + b / 2, Pal.GOLD[3])
	# --- robe skirt, ash grey with a gold hem ---
	var sk := c.mask().poly(V([[cx - 9, 34 + b], [cx + 9, 34 + b], [cx + 12, 49 + b], [cx - 12, 49 + b]]))
	for x in range(cx - 12, cx + 13, 3):
		sk.set_bit(x, 49 + b, false)
	c.paint(sk, Pal.ASH, 2, true)
	for x in range(cx - 8, cx + 9, 4):
		c.line(x, 36 + b, x + (x - cx) / 4, 46 + b, Pal.ASH[1])
	c.line(cx - 11, 47 + b, cx + 11, 47 + b, Pal.GOLD[2])
	# --- torso: black plate with a gilded sunburst ---
	var tor := c.mask().poly(V([[cx - 9, 19 + b], [cx + 9, 19 + b], [cx + 8, 36 + b], [cx - 8, 36 + b]]))
	c.paint(tor, Pal.OBSIDIAN, 3, true)
	var sb := Vector2(cx + 1, 26 + b)
	for k in 8:
		var a := k * TAU / 8.0
		var e := sb + Vector2(cos(a), sin(a)) * 4.0
		c.line(int(sb.x), int(sb.y), int(e.x), int(e.y), Pal.GOLD[2])
	c.fill(c.mask().ellipse(sb.x, sb.y, 1.6, 1.6), Pal.GOLD[4])
	c.paint(c.mask().rect(cx - 9, 34 + b, 18, 2), Pal.GOLD, 2)
	# --- pauldrons ---
	var pr := 21 + b
	c.paint(c.mask().ellipse(cx - 9.0, pr, 5.0, 4.0), Pal.OBSIDIAN, 4, true)
	c.paint(c.mask().ellipse(cx + 9.0, pr, 5.0, 4.0), Pal.OBSIDIAN, 4, true)
	c.line(cx - 13, pr + 2, cx - 6, pr + 2, Pal.GOLD[3])
	c.line(cx + 6, pr + 2, cx + 13, pr + 2, Pal.GOLD[3])
	# --- head: an ash-grey face, ember eyes, a crown of cinders ---
	var face := c.mask().ellipse(hx, hy, 5.0, 6.0)
	face.rect(hx - 4, hy, 9, 5)
	c.paint(face, Pal.ASH, 3, true)
	for x in range(hx, hx + 5):
		c.put(x, hy, Pal.INK)
	c.lit(hx + 1, hy, Pal.EMBER[4 if glow == 0 else 5])
	c.lit(hx + 3, hy, Pal.EMBER[4 if glow == 0 else 5])
	if roar:
		for x in range(hx, hx + 5):
			c.lit(x, hy + 3, Pal.EMBER[3])
	else:
		c.line(hx + 1, hy + 3, hx + 3, hy + 3, Pal.ASH[0])
	for x in range(hx - 1, hx + 4):
		if x % 2 == 0:
			c.lit(x, hy + 1 + (x % 3) / 2, Pal.EMBER[2])
	var crown := c.mask().rect(hx - 5, hy - 6, 11, 3)
	for k in 4:
		crown.poly(V([[hx - 5 + k * 3, hy - 6], [hx - 4 + k * 3, hy - 10 - (k % 2) * 2], [hx - 2 + k * 3, hy - 6]]))
	c.paint(crown, Pal.GOLD, 2, true)
	c.lit(hx, hy - 5, Pal.EMBER[4])
	# --- the greatsword, its edge still molten ---
	var hand := Vector2(cx + 9 + int(p.get("reach", 0)), 30 + b)
	var a := deg_to_rad(sw)
	var d := Vector2(cos(a), -sin(a))
	var tip := hand + d * 31.0
	var pommel := hand - d * 6.0
	var n := Vector2(-d.y, d.x)
	var blade := c.mask().poly(PackedVector2Array([hand + d * 3.0 - n * 2.5, tip - n * 1.0, tip + d * 2.0, tip + n * 1.0, hand + d * 3.0 + n * 2.5]))
	c.paint(blade, Pal.STEEL, 3, true)
	var edge := c.mask()
	var e0 := hand + d * 4.0 + n * 2.0
	var e1 := tip + n * 0.8
	edge.line(int(e0.x), int(e0.y), int(e1.x), int(e1.y))
	c.fill_lit(edge, Pal.EMBER[3] if glow == 0 else Pal.EMBER[4])
	var guard := c.mask()
	var g0 := hand + d * 3.0 - n * 4.0
	var g1 := hand + d * 3.0 + n * 4.0
	guard.line(int(g0.x), int(g0.y), int(g1.x), int(g1.y))
	guard.line(int(g0.x) + 1, int(g0.y), int(g1.x) + 1, int(g1.y))
	c.paint(guard, Pal.GOLD, 3)
	var grip := c.mask()
	grip.line(int(pommel.x), int(pommel.y), int(hand.x), int(hand.y))
	c.paint(grip, Pal.WOOD, 2, false, false)
	c.paint(c.mask().ellipse(pommel.x, pommel.y, 1.4, 1.4), Pal.GOLD, 3)
	c.paint(c.mask().ellipse(hand.x, hand.y, 2.6, 2.6), Pal.OBSIDIAN, 4)
	var arm := c.mask()
	arm.line(cx + 9, pr + 2, int(hand.x), int(hand.y))
	arm.line(cx + 10, pr + 2, int(hand.x) + 1, int(hand.y))
	arm.line(cx + 9, pr + 3, int(hand.x), int(hand.y) + 1)
	c.paint(arm, Pal.OBSIDIAN, 3, false, false)
	# --- off hand: raised with a sun-orb when casting ---
	if p.get("hand_up", false):
		limb(c, [[cx - 9, pr + 1], [cx - 13, pr - 6], [cx - 12, pr - 12]], Pal.OBSIDIAN, 3)
		var orb := c.mask().ellipse(cx - 12, pr - 16, 3.5 + glow * 0.5, 3.5 + glow * 0.5)
		c.fill_lit(orb, Pal.GOLD[4])
		c.lit(cx - 13, pr - 17, Pal.WHITE)
	else:
		limb(c, [[cx - 9, pr + 1], [cx - 11, pr + 8], [cx - 10, pr + 14]], Pal.OBSIDIAN, 3)
	c.outline(Pal.INK)
	return c


# --- projectiles ------------------------------------------------------------------

static func _projectiles(dir: String) -> void:
	# a lance of dead sunlight (points right)
	var sl := Sheet.new(18, 5, Vector2i(9, 2))
	var fr: Array = []
	for i in 2:
		var c := Px.new(18, 5)
		c.fill_lit(c.mask().poly(V([[0, 2.5], [12, 1], [17.5, 2.5], [12, 4]])), Pal.GOLD[3])
		c.fill_lit(c.mask().poly(V([[4, 2.5], [12, 2], [16, 2.5], [12, 3]])), Pal.GOLD[4])
		c.lit(16, 2, Pal.WHITE)
		c.lit(1 + i, 1 + i * 2, Pal.ASH[3])
		fr.append(c)
	sl.add("idle", fr, 14.0)
	sl.save(dir, "proj_sun")
	# a black sun: dark core, burning rim
	var se := Sheet.new(12, 12, Vector2i(6, 6))
	fr = []
	for i in 2:
		var c := Px.new(12, 12)
		var rim := c.mask().ellipse(6.0, 6.0, 5.0 - i * 0.4, 5.0 - i * 0.4)
		rim.subtract(c.mask().ellipse(6.0, 6.0, 3.0, 3.0))
		c.fill_lit(rim, Pal.GOLD[3] if i == 0 else Pal.GOLD[4])
		c.fill(c.mask().ellipse(6.0, 6.0, 3.0, 3.0), Pal.INK)
		c.lit(4, 4, Pal.GLOAM[3])
		fr.append(c)
	se.add("idle", fr, 8.0)
	se.save(dir, "proj_eclipse")
