## The Undervault's stone, drawn for what it is. Floors are quiet (soft mortar,
## small differences between slabs, wear in long patches), because everything
## that matters stands on them; walls are loud (deep-cut courses, highlights
## on every block, a plinth at the foot) and each region's are its own:
##   the Ossuary  - burial masonry with skull niches,
##   the Rootmire - sunken blockwork strangled by root and moss,
##   the Throne   - black ashlar, gilded frieze, pilasters,
##   the Sanctuary- warm rubble stone between timber posts.
## 16 texels = 1 tile. Floors repeat every 16 tiles, wall faces every 8.
## Everything wraps. Job "tiles" (gen_tiles.gd calls build).
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")

const FLOOR := 256
const WALL_W := 128
const WALL_H := 32


static func build(dir: String) -> void:
	_paving(dir.path_join("crypt_floor.png"), {"ramp": Pal.STONE, "base": 2, "seed": 11, "rows": [20, 30], "wide": [26, 54], "tomb": 0.16, "bones": 26, "moss": Pal.MOSS})
	_paving(dir.path_join("hearth_floor.png"), {"ramp": Pal.EARTH, "base": 2, "seed": 12, "rows": [18, 26], "wide": [22, 44], "soil": 0.38, "straw": 90})
	_throne_paving(dir.path_join("throne_floor.png"), 71)
	_root_ground(dir.path_join("root_floor.png"), 61)
	_masonry(dir.path_join("crypt_wall.png"), Pal.STONE, 2, 31)
	_niches(dir.path_join("crypt_wall.png"), 33)
	_masonry(dir.path_join("hearth_wall.png"), Pal.EARTH, 2, 32)
	_timbers(dir.path_join("hearth_wall.png"))
	_masonry(dir.path_join("root_wall.png"), Pal.EARTH, 1, 62)
	_overgrowth(dir.path_join("root_wall.png"), 63)
	_masonry(dir.path_join("throne_wall.png"), Pal.OBSIDIAN, 2, 72)
	_frieze(dir.path_join("throne_wall.png"))
	_cap(dir.path_join("crypt_top.png"), Pal.STONE, 2, 41)
	_cap(dir.path_join("hearth_top.png"), Pal.EARTH, 2, 42)
	_cap(dir.path_join("root_top.png"), Pal.MOSS, 1, 64)
	_cap(dir.path_join("throne_top.png"), Pal.OBSIDIAN, 3, 73)
	_column(dir.path_join("crypt_pillar.png"), Pal.STONE, 2, "skulls")
	_column(dir.path_join("hearth_pillar.png"), Pal.WOOD, 2, "post")
	_column(dir.path_join("throne_pillar.png"), Pal.OBSIDIAN, 3, "gold")
	_trunk(dir.path_join("root_pillar.png"))
	_pit_wall(dir.path_join("pit_wall.png"), 81)


## The inside of a pit: rough strata, nothing built by anyone.
static func _pit_wall(path: String, seed_v: int) -> void:
	var c := Px.new(64, 64)
	for y in 64:
		for x in 64:
			var strata := pn(x, float(y) * 5.0, 22.0, 64, seed_v)
			var fine := pn(x, y, 5.0, 64, seed_v + 1)
			var v := 0.6 + strata * 1.1 + (fine - 0.5) * 0.5
			var col := ramp(Pal.STONE, v)
			if int(y + strata * 9.0) % 11 == 0:
				col = Pal.INK
			c.put(x, y, col)
	c.save(path)


## Periodic value noise (wraps with `period` cells).
static func pn(x: float, y: float, cell: float, size: int, s: int) -> float:
	var period := maxi(1, int(size / cell))
	var fx := x / cell
	var fy := y / cell
	var xi := floori(fx)
	var yi := floori(fy)
	var tx := fx - xi
	var ty := fy - yi
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := Px.hash01(posmod(xi, period), posmod(yi, period), s)
	var b := Px.hash01(posmod(xi + 1, period), posmod(yi, period), s)
	var c := Px.hash01(posmod(xi, period), posmod(yi + 1, period), s)
	var d := Px.hash01(posmod(xi + 1, period), posmod(yi + 1, period), s)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func split(total: int, lo: int, hi: int, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var left := total
	while left > 0:
		if left <= hi:
			if left < lo and out.size() > 0:
				out[out.size() - 1] += left
			else:
				out.append(left)
			break
		var s := rng.randi_range(lo, hi)
		if left - s < lo:
			s = left - lo
		out.append(s)
		left -= s
	return out


## A colour on the ramp at a fractional index, stepped to quarters so patches
## stay flat like hand-placed pixels (never a smooth gradient).
static func ramp(r: Array, v: float) -> Color:
	var q := floorf(clampf(v, 0.0, float(r.size() - 1)) * 4.0 + 0.5) / 4.0
	var i := int(floor(q))
	return (r[i] as Color).lerp(r[mini(i + 1, r.size() - 1)], q - i)


## Worn burial paving or a sanctuary's flags: rows of long slabs in running
## bond. Mortar is only a step darker than the stone, a slab differs from its
## neighbour by a quarter step, and wear runs in long soft patches across them.
static func _paving(path: String, spec: Dictionary) -> void:
	var size := FLOOR
	var r: Array = spec.ramp
	var base := float(spec.base)
	var seed_v := int(spec.seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(size, size)
	var ids := PackedInt32Array()
	ids.resize(size * size)
	var seam := PackedByteArray()
	seam.resize(size * size)
	var tone := {}
	var slabs: Array = []
	var stone := 0
	var y0 := 0
	for rh in split(size, int(spec.rows[0]), int(spec.rows[1]), rng):
		var off := rng.randi_range(0, size - 1)
		var x0 := 0
		for sw in split(size, int(spec.wide[0]), int(spec.wide[1]), rng):
			stone += 1
			tone[stone] = rng.randf_range(-0.25, 0.25)
			slabs.append({"x": x0 + off, "y": y0, "w": sw, "h": rh, "id": stone})
			for yy in range(y0, y0 + rh):
				for xx in range(x0, x0 + sw):
					var px := posmod(xx + off, size)
					ids[yy * size + px] = stone
					if yy == y0 + rh - 1 or xx == x0 + sw - 1:
						seam[yy * size + px] = 1
			x0 += sw
		y0 += rh
	for y in size:
		for x in size:
			var i := y * size + x
			var wear := pn(x, y, 32.0, size, seed_v + 1)
			var fine := pn(x, y, 6.0, size, seed_v + 2)
			var v := base + float(tone[ids[i]]) + (wear - 0.5) * 0.7 + (fine - 0.5) * 0.25
			if seam[i] == 1:
				v = base - 0.9 + (wear - 0.5) * 0.4
			var col := ramp(r, v)
			if spec.has("soil"):
				# packed earth over the flags, thick where feet do not go
				var soil := pn(x, y, 24.0, size, seed_v + 5)
				if soil > 1.0 - float(spec.soil):
					col = ramp(r, 1.6 + (fine - 0.5) * 0.5)
			if Px.hash01(x, y, seed_v * 7) > 0.994:
				col = ramp(r, v - 0.5)
			c.put(x, y, col)
	# some slabs were graves: an inset border and a worn inscription
	if spec.has("tomb"):
		for s: Dictionary in slabs:
			if s.w < 36 or s.h < 22 or rng.randf() > float(spec.tomb):
				continue
			var a := Vector2i(int(s.x) + 3, int(s.y) + 3)
			var b := Vector2i(int(s.x) + int(s.w) - 5, int(s.y) + int(s.h) - 5)
			for xx in range(a.x, b.x + 1):
				_tint(c, xx, a.y, r[int(base) - 1], 0.55)
				_tint(c, xx, b.y, r[int(base) - 1], 0.55)
			for yy in range(a.y, b.y + 1):
				_tint(c, a.x, yy, r[int(base) - 1], 0.55)
				_tint(c, b.x, yy, r[int(base) - 1], 0.55)
			var mid := (a + b) / 2
			for k in 7:
				_tint(c, mid.x - 6 + k * 2, mid.y + (k % 2), r[int(base) - 1], 0.5)
	# bone chips and pebbles, barely there
	for k in int(spec.get("bones", 0)):
		var p := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		for q in rng.randi_range(2, 4):
			_tint(c, p.x + q, p.y + (q % 2), Pal.BONE[1], 0.5)
	for k in int(spec.get("straw", 0)):
		var p := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		for q in rng.randi_range(1, 3):
			_tint(c, p.x + q, p.y, Pal.GOLD[1], 0.35)
	# hairline cracks, one step darker
	for k in 14:
		_crack(c, rng, r[int(base) - 1], 0.6, size)
	if spec.has("moss"):
		var mo: Array = spec.moss
		for y in size:
			for x in size:
				if seam[y * size + x] == 1 and pn(x, y, 20.0, size, seed_v + 9) > 0.74:
					c.put(x, y, mo[1])
	c.save(path)


static func _tint(c: Px, x: int, y: int, col: Color, k: float) -> void:
	var px := posmod(x, c.w)
	var py := posmod(y, c.h)
	c.put(px, py, c.get_c(px, py).lerp(col, k))


static func _crack(c: Px, rng: RandomNumberGenerator, col: Color, k: float, size: int) -> void:
	var p := Vector2(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
	var dir := Vector2.from_angle(rng.randf() * TAU)
	for s in rng.randi_range(8, 22):
		dir = dir.rotated(rng.randf_range(-0.45, 0.45))
		p += dir
		_tint(c, int(p.x), int(p.y), col, k)


## Black polished slabs laid square, four tiles wide, under dust: faint veins,
## a thin gold mend here and there. It is a palace floor, not a pattern.
static func _throne_paving(path: String, seed_v: int) -> void:
	var size := FLOOR
	var r: Array = Pal.OBSIDIAN
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(size, size)
	var cell := 64
	var n := size / cell
	var tone := {}
	for sy in n:
		for sx in n:
			tone[Vector2i(sx, sy)] = rng.randf_range(-0.2, 0.2)
	for y in size:
		for x in size:
			var cl := Vector2i(x / cell, y / cell)
			var lx := x % cell
			var ly := y % cell
			var fine := pn(x, y, 7.0, size, seed_v + 2)
			var dust := pn(x, y, 40.0, size, seed_v + 3)
			var v := 2.5 + float(tone[cl]) + (dust - 0.5) * 0.8 + (fine - 0.5) * 0.2
			if lx == cell - 1 or ly == cell - 1:
				v = 1.3
			elif lx == 0 or ly == 0:
				v += 0.25
			var col := ramp(r, v)
			var w := pn(x + pn(x, y, 11.0, size, seed_v + 4) * 12.0, y, 22.0, size, seed_v + 1)
			if absf(w - 0.5) < 0.012:
				col = col.lerp(r[4], 0.5)
			c.put(x, y, col)
	for k in 5:
		var p := Vector2(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for st in rng.randi_range(18, 40):
			dir = dir.rotated(rng.randf_range(-0.45, 0.45))
			p += dir
			_tint(c, int(p.x), int(p.y), Pal.GOLD[2], 0.8)
	c.save(path)


## Dark wet soil with moss worn into it and a few thin roots: ground that lets
## what stands on it stand out (it was a patchwork of bright green).
static func _root_ground(path: String, seed_v: int) -> void:
	var size := FLOOR
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(size, size)
	for y in size:
		for x in size:
			var low := pn(x, y, 40.0, size, seed_v)
			var mid := pn(x, y, 12.0, size, seed_v + 1)
			var fine := pn(x, y, 4.0, size, seed_v + 2)
			var col := ramp(Pal.EARTH, 0.9 + (low - 0.5) * 0.9 + (fine - 0.5) * 0.4)
			var moss := low * 0.6 + mid * 0.4
			if moss > 0.58:
				col = ramp(Pal.MOSS, 0.7 + (moss - 0.58) * 1.6 + (fine - 0.5) * 0.3)
			c.put(x, y, col)
	for k in 150:
		var p := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		_tint(c, p.x, p.y, ([Pal.EARTH[3], Pal.WOOD[2], Pal.BLOOD[1]][k % 3] as Color), 0.5)
	for k in 12:
		var p := Vector2(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		var a := rng.randf() * TAU
		for s in rng.randi_range(30, 80):
			a += rng.randf_range(-0.3, 0.3)
			p += Vector2.from_angle(a)
			_tint(c, int(p.x), int(p.y), Pal.WOOD[1], 0.75)
	c.save(path)


## Deep-cut coursed masonry: a dressed cap course, three rows of blocks with a
## lit top and left edge and a shadowed foot, dark mortar, a plinth where the
## wall meets the floor. Loud on purpose: walls must not read as floor.
static func _masonry(path: String, r: Array, base: int, seed_v: int) -> void:
	var w := WALL_W
	var h := WALL_H
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(w, h)
	var rmax := r.size() - 1
	for x in w:
		c.put(x, 0, r[mini(base + 2, rmax)])
		c.put(x, 1, r[mini(base + 2, rmax)] if Px.hash01(x, 1, seed_v) > 0.2 else r[mini(base + 1, rmax)])
		c.put(x, 2, r[mini(base + 1, rmax)])
		c.put(x, 3, r[0])
	var tops := [4, 13, 22]
	var hs := [9, 9, 7]
	for ri in tops.size():
		var top: int = tops[ri]
		var rh: int = hs[ri]
		var off := rng.randi_range(0, w - 1)
		var x0 := 0
		for bw in split(w, 13, 29, rng):
			var t := rng.randf()
			var b := base + (-1 if t < 0.22 else (1 if t > 0.82 else 0))
			var chip := rng.randi_range(0, 9)
			for yy in range(top, top + rh):
				for xx in range(x0, x0 + bw):
					var px := posmod(xx + off, w)
					var col: Color
					if yy == top + rh - 1 or xx == x0 + bw - 1:
						col = r[0]
					elif yy == top or xx == x0:
						col = r[mini(b + 1, rmax)]
					elif yy == top + rh - 2 or xx == x0 + bw - 2:
						col = r[maxi(b - 1, 0)]
					else:
						col = ramp(r, float(b) + (pn(px, yy, 5.0, w, seed_v + ri) - 0.5) * 0.7)
					if chip == 0 and xx > x0 + bw - 5 and yy > top + rh - 4:
						col = r[0]
					if chip == 1 and xx < x0 + 3 and yy < top + 3:
						col = r[maxi(b - 1, 0)]
					c.put(px, yy, col)
			x0 += bw
	# the plinth: one dark course where the wall stands on the floor
	for x in w:
		c.put(x, 29, r[maxi(base - 1, 0)] if x % 11 != 0 else r[0])
		c.put(x, 30, r[1] if x % 7 != 0 else r[0])
		c.put(x, 31, r[0])
	c.save(path)


## Burial niches cut into the Ossuary's walls: an arched recess, a skull in the
## dark of each, soul-light in a few of the sockets.
static func _niches(path: String, seed_v: int) -> void:
	var c := _load(path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := 9
	var k := 0
	while x < WALL_W - 12:
		var nw := 10
		var top := 8
		var bot := 21
		for yy in range(top - 1, bot + 2):
			for xx in range(x - 1, x + nw + 1):
				var dx := absf(xx - (x + nw * 0.5 - 0.5))
				var arch := yy >= top + 2 or dx < float(nw) * 0.5 - float(top + 2 - yy) * 0.9
				if not arch:
					continue
				var edge := xx < x or xx >= x + nw or yy >= bot + 1 or yy < top
				c.put(xx, yy, Pal.STONE[4] if edge and (xx < x or yy < top) else (Pal.STONE[3] if edge else Pal.INK))
		# the skull (or a jar, or nothing: not every grave was filled)
		var what := k % 3
		var sx := x + 2
		var sy := 13
		if what != 2:
			if what == 0:
				for p in [[1, 0], [2, 0], [3, 0], [4, 0], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [0, 2], [2, 2], [3, 2], [5, 2], [1, 3], [2, 3], [3, 3], [4, 3], [1, 4], [3, 4]]:
					c.put(sx + int(p[0]), sy + int(p[1]) + 2, Pal.BONE[2])
				c.lit(sx + 1, sy + 4, Pal.SOUL[3 + k % 2])
				c.put(sx + 4, sy + 4, Pal.INK)
			else:
				for yy in 6:
					var hw := 2 if yy > 0 and yy < 5 else 1
					for xx in range(-hw, hw + 1):
						c.put(sx + 3 + xx, sy + 1 + yy, Pal.EARTH[3] if xx < 0 else Pal.EARTH[2])
		for xx in range(x - 1, x + nw + 1):
			c.put(xx, bot + 1, Pal.STONE[4] if xx % 3 != 0 else Pal.STONE[3])
		x += nw + rng.randi_range(14, 26)
		k += 1
	c.save(path)


static func _load(path: String) -> Px:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	var c := Px.new(img.get_width(), img.get_height())
	c.blit_image(img, 0, 0)
	return c


## The sanctuary's walls: timber posts and a beam along the top.
static func _timbers(path: String) -> void:
	var c := _load(path)
	for x0 in range(0, WALL_W, 40):
		for yy in range(0, WALL_H - 1):
			for k in 4:
				c.put(x0 + k, yy, Pal.WOOD[[3, 2, 2, 0][k]])
			if yy % 7 == 3:
				c.put(x0 + 1, yy, Pal.WOOD[0])
	for x in WALL_W:
		c.put(x, 0, Pal.WOOD[4] if x % 13 != 0 else Pal.WOOD[3])
		c.put(x, 1, Pal.WOOD[3])
		c.put(x, 2, Pal.WOOD[2])
		c.put(x, 3, Pal.WOOD[0])
	c.save(path)


## Root and moss taking the Rootmire's sunken blockwork back: trunks of root
## down the face, moss hanging from the cap, fungus glowing in the shade.
static func _overgrowth(path: String, seed_v: int) -> void:
	var c := _load(path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for x in WALL_W:
		var drip := 2 + int(pn(x, 0.0, 9.0, WALL_W, seed_v) * 8.0) + (1 if x % 3 == 0 else 0)
		for y in drip:
			c.put(x, y, Pal.MOSS[2 if y < drip - 2 else 1])
		c.put(x, 0, Pal.MOSS[3])
	for k in 7:
		var x := float(rng.randi_range(0, WALL_W - 1))
		var wide := rng.randi_range(2, 4)
		for y in range(1, WALL_H - 1):
			x += rng.randf_range(-0.8, 0.8)
			for q in wide:
				var col: Color = Pal.WOOD[3] if q == 0 else (Pal.WOOD[1] if q == wide - 1 else Pal.WOOD[2])
				c.put(posmod(int(x) + q, WALL_W), y, col)
			c.put(posmod(int(x) + wide, WALL_W), y, Pal.WOOD[0])
	for k in 14:
		var gx := rng.randi_range(0, WALL_W - 2)
		var gy := rng.randi_range(10, WALL_H - 4)
		c.lit(gx, gy, Pal.SOUL[4])
		c.lit(gx + 1, gy, Pal.SOUL[3])
	c.save(path)


## The Throne's walls: a gilded frieze with studs under the cap, a black
## pilaster every three tiles, a thin gold line along the plinth.
static func _frieze(path: String) -> void:
	var c := _load(path)
	for x0 in range(4, WALL_W, 48):
		for yy in range(6, 29):
			for k in 8:
				var col: Color = Pal.OBSIDIAN[[4, 3, 3, 2, 2, 2, 1, 0][k]]
				if k == 3 and yy % 5 == 0:
					col = Pal.OBSIDIAN[1]
				c.put(x0 + k, yy, col)
		for k in range(-1, 9):
			c.put(x0 + k, 7, Pal.GOLD[3])
			c.put(x0 + k, 8, Pal.GOLD[1])
			c.put(x0 + k, 27, Pal.GOLD[2])
	for x in WALL_W:
		c.put(x, 3, Pal.GOLD[1])
		c.put(x, 4, Pal.GOLD[3] if x % 16 != 0 else Pal.GOLD[2])
		c.put(x, 5, Pal.GOLD[2])
		c.put(x, 6, Pal.OBSIDIAN[0])
		if x % 3 != 0:
			c.put(x, 28, Pal.GOLD[1])
	for x0 in range(28, WALL_W, 48):
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			c.put(x0 + d.x, 14 + d.y, Pal.GOLD[2])
		c.lit(x0, 14, Pal.GOLD[4])
	c.save(path)


## A wall's cap: rough dressed stone, nearly flat, no specks.
static func _cap(path: String, r: Array, base: int, seed_v: int) -> void:
	var size := 64
	var c := Px.new(size, size)
	for y in size:
		for x in size:
			var low := pn(x, y, 16.0, size, seed_v)
			var fine := pn(x, y, 4.0, size, seed_v + 1)
			c.put(x, y, ramp(r, float(base) - 0.6 + (low - 0.5) * 0.7 + (fine - 0.5) * 0.3))
	c.save(path)


## A free-standing column (16x32) shaded as a round form: capital, shaft and
## plinth, wider than the shaft, each lit on the left.
static func _column(path: String, r: Array, base: int, kind: String) -> void:
	var c := Px.new(16, 32)
	var band := [0, 1, 2, 3, 3, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0]
	for y in 32:
		for x in 16:
			var idx := float(base) - 2.0 + float(band[x])
			var col := ramp(r, idx)
			if kind == "skulls" and x % 4 == 2:
				col = ramp(r, idx - 0.75)      # flutes
			c.put(x, y, col)
	var cap_h := 5
	var foot := 26
	for y in cap_h:
		for x in 16:
			c.put(x, y, ramp(r, float(base) + (1.6 if y == 0 else (1.0 if y == 1 else 0.0)) - float(x) * 0.1))
		c.put(0, y, r[0] if y > 1 else r[1])
		c.put(15, y, r[0])
	for x in 16:
		c.put(x, cap_h, r[0])
	for y in range(foot, 32):
		for x in 16:
			c.put(x, y, ramp(r, float(base) + (1.0 if y == foot else (0.3 if y < 30 else -1.2)) - float(x) * 0.1))
	for x in 16:
		c.put(x, foot - 1, r[0])
	match kind:
		"skulls":
			# a ring of small skulls below the capital
			for sx in [2, 7, 12]:
				for p in [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [1, 2]]:
					c.put(sx + int(p[0]), 8 + int(p[1]), Pal.BONE[2])
				c.put(sx + 1, 1 + 8, Pal.INK)
		"gold":
			for x in 16:
				c.put(x, 1, Pal.GOLD[4])
				c.put(x, 2, Pal.GOLD[3])
				c.put(x, 3, Pal.GOLD[1])
				c.put(x, 27, Pal.GOLD[3])
				c.put(x, 28, Pal.GOLD[1])
				c.put(x, 14, Pal.GOLD[2])
		"post":
			for y in range(6, 25, 6):
				for x in 16:
					c.put(x, y, Pal.WOOD[1])
	c.save(path)


## A great root as thick as a column, bark running up it, moss at its foot.
static func _trunk(path: String) -> void:
	var c := Px.new(16, 32)
	var band := [0, 1, 2, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0]
	for y in 32:
		for x in 16:
			var seam := (x + int(y * 0.45) + int(pn(x, y, 8.0, 16, 9) * 4.0)) % 5 == 0
			var idx := float(band[x]) + (-0.75 if seam else 0.0)
			var col := ramp(Pal.WOOD, idx)
			var moss := float(y - 20) / 12.0 + (pn(x, y, 5.0, 16, 3) - 0.5)
			if moss > 0.45:
				col = ramp(Pal.MOSS, 1.0 + float(band[x]) * 0.5)
			c.put(x, y, col)
	c.save(path)
