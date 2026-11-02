## Seamless environment textures. 16 texels = 1 world tile.
## Floors and wall tops tile in both axes; wall faces tile horizontally and are
## exactly one wall height (32px = 2 tiles) tall.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")


static func build(out_dir: String) -> void:
	_slabs(out_dir.path_join("crypt_floor.png"), 128, Pal.STONE, 2, 11, 0.16, Pal.MOSS)
	_pillar(out_dir.path_join("crypt_pillar.png"), Pal.STONE, 2)
	_pillar(out_dir.path_join("hearth_pillar.png"), Pal.EARTH, 2)
	_wall(out_dir.path_join("crypt_wall.png"), 64, Pal.STONE, 2, 31)
	_top(out_dir.path_join("crypt_top.png"), 64, Pal.STONE, 41)
	_ledge(out_dir.path_join("crypt_ledge.png"), 64, Pal.STONE, 2, 51)
	_floor(out_dir.path_join("hearth_floor.png"), 128, Pal.EARTH, 2, 12, 0.3, Pal.MOSS)
	_wall(out_dir.path_join("hearth_wall.png"), 64, Pal.EARTH, 2, 32)
	_top(out_dir.path_join("hearth_top.png"), 64, Pal.EARTH, 42)
	_ledge(out_dir.path_join("hearth_ledge.png"), 64, Pal.EARTH, 2, 52)
	_pit(out_dir.path_join("pit.png"), 64)


## Periodic value noise so textures wrap seamlessly.
static func pnoise(x: float, y: float, period: int, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(xi, period)
	var y0 := posmod(yi, period)
	var x1 := posmod(xi + 1, period)
	var y1 := posmod(yi + 1, period)
	var a := Px.hash01(x0, y0, s)
	var b := Px.hash01(x1, y0, s)
	var c := Px.hash01(x0, y1, s)
	var d := Px.hash01(x1, y1, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Square crypt slabs on a 32px grid, randomly subdivided, with chipped corners.
static func _slabs(path: String, size: int, r: Array, base: int, seed_v: int, moss_amt: float, moss: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(size, size)
	var ids := PackedInt32Array()
	ids.resize(size * size)
	var stone := 0
	var tones := {}
	var rects: Array = []
	for sy in size / 32:
		for sx in size / 32:
			var x0 := sx * 32
			var y0 := sy * 32
			var k := rng.randf()
			if k < 0.3:
				rects.append(Rect2i(x0, y0, 32, 32))
			elif k < 0.55:
				rects.append(Rect2i(x0, y0, 32, 16))
				rects.append(Rect2i(x0, y0 + 16, 32, 16))
			elif k < 0.8:
				rects.append(Rect2i(x0, y0, 16, 32))
				rects.append(Rect2i(x0 + 16, y0, 16, 32))
			else:
				for q in 4:
					rects.append(Rect2i(x0 + (q % 2) * 16, y0 + (q / 2) * 16, 16, 16))
	for rc: Rect2i in rects:
		stone += 1
		tones[stone] = rng.randf()
		var chip := rng.randi_range(0, 7)
		for yy in range(rc.position.y, rc.end.y):
			for xx in range(rc.position.x, rc.end.x):
				ids[yy * size + xx] = stone
		# chipped corner: hand the corner pixels to the mortar
		if chip < 4:
			var cx := rc.position.x if chip % 2 == 0 else rc.end.x - 2
			var cy := rc.position.y if chip < 2 else rc.end.y - 2
			for q in 3:
				ids[(cy + q / 2) * size + cx + q % 2] = 0
	for y in size:
		for x in size:
			var id := ids[y * size + x]
			var right := ids[y * size + (x + 1) % size]
			var down := ids[((y + 1) % size) * size + x]
			if id == 0 or right != id or down != id:
				var mm := pnoise(x / 8.0, y / 8.0, size / 8, seed_v + 7) > 1.0 - moss_amt
				c.put(x, y, moss[1] if mm and Px.hash01(x, y, 5) > 0.4 else Pal.ramp(r, base - 2))
				continue
			var left := ids[y * size + posmod(x - 1, size)]
			var upi := ids[posmod(y - 1, size) * size + x]
			var right2 := ids[y * size + (x + 2) % size]
			var down2 := ids[((y + 2) % size) * size + x]
			var tone: float = tones[id]
			var b := base
			if tone < 0.25:
				b = base - 1
			elif tone > 0.9:
				b = base + 1
			var idx := b
			if left != id or upi != id:
				idx = b + 1
			elif right2 != id or down2 != id:
				idx = b - 1 if tone > 0.5 else b
			var col: Color = Pal.ramp(r, idx)
			var grain := pnoise(x / 4.0, y / 4.0, size / 4, seed_v + id)
			if grain > 0.72 and idx == b:
				col = col.lerp(Pal.ramp(r, b - 1), 0.5)
			if Px.hash01(x, y, seed_v * 7) > 0.975:
				col = Pal.ramp(r, b - 1)
			var stain := pnoise(x / 16.0, y / 16.0, size / 16, seed_v + 3)
			if stain > 0.7:
				col = col.lerp(Pal.EARTH[1], 0.35)
			var mpatch := pnoise(x / 8.0, y / 8.0, size / 8, seed_v + 9)
			if mpatch > 1.0 - moss_amt * 0.5 and Px.hash01(x, y, seed_v + 77) > 0.55:
				col = moss[2] if grain > 0.5 else moss[1]
			c.put(x, y, col)
	for k in 6:
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var dx := 1 if rng.randf() > 0.5 else -1
		var py := cy
		for st in rng.randi_range(5, 11):
			var px := posmod(cx + st * dx, size)
			if rng.randf() < 0.45:
				py += 1
			if ids[posmod(py, size) * size + px] != 0:
				c.put(px, posmod(py, size), Pal.ramp(r, base - 2))
	c.save(path)


## A free-standing column face (16x32): capital, fluted shaft, plinth.
static func _pillar(path: String, r: Array, base: int) -> void:
	var c := Px.new(16, 32)
	for y in 32:
		for x in 16:
			var col: Color
			if y < 4:
				col = Pal.ramp(r, base + (2 if y == 0 else (1 if y < 3 else -1)))
			elif y >= 28:
				col = Pal.ramp(r, base + (1 if y == 28 else (0 if y < 31 else -2)))
			else:
				var fl := x % 4
				if x == 0 or x == 15:
					col = Pal.ramp(r, base - 2)
				elif fl == 1:
					col = Pal.ramp(r, base + 1)
				elif fl == 3:
					col = Pal.ramp(r, base - 1)
				else:
					col = Pal.ramp(r, base)
				if y > 20 and Px.bayer(x, y) < (y - 20) / 16.0:
					col = col.lerp(Pal.ramp(r, 0), 0.4)
			c.put(x, y, col)
	c.save(path)


## Splits `total` into random segment lengths in [lo, hi] that sum exactly.
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


static func _floor(path: String, size: int, r: Array, base: int, seed_v: int, moss_amt: float, moss: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var c := Px.new(size, size)
	# Stone id map: rows of flagstones with random widths and per-row offsets.
	var ids := PackedInt32Array()
	ids.resize(size * size)
	var edge := PackedByteArray()  # 1 = mortar
	edge.resize(size * size)
	var rows := split(size, 10, 18, rng)
	var y0 := 0
	var stone := 0
	var tones := {}
	for rh in rows:
		var widths := split(size, 12, 26, rng)
		var off := rng.randi_range(0, size - 1)
		var x0 := 0
		for sw in widths:
			stone += 1
			tones[stone] = rng.randf()
			for yy in range(y0, y0 + rh):
				for xx in range(x0, x0 + sw):
					var px := posmod(xx + off, size)
					ids[yy * size + px] = stone
					if yy == y0 + rh - 1 or xx == x0 + sw - 1:
						edge[yy * size + px] = 1
			x0 += sw
		y0 += rh
	for y in size:
		for x in size:
			var i := y * size + x
			if edge[i] == 1:
				var mortar_moss := pnoise(x / 8.0, y / 8.0, size / 8, seed_v + 7) > 1.0 - moss_amt
				c.put(x, y, moss[1] if mortar_moss else Pal.ramp(r, base - 2))
				continue
			var id := ids[i]
			var tone: float = tones[id]
			var b := base
			if tone < 0.22:
				b = base - 1
			elif tone > 0.86:
				b = base + 1
			# bevel: light top-left inner edge, dark bottom-right inner edge
			var up := ids[posmod(y - 1, size) * size + x] != id or edge[posmod(y - 1, size) * size + x] == 1
			var lf := ids[y * size + posmod(x - 1, size)] != id or edge[y * size + posmod(x - 1, size)] == 1
			var dn := edge[posmod(y + 1, size) * size + x] == 1
			var rt := edge[y * size + posmod(x + 1, size)] == 1
			var idx := b
			if up or lf:
				idx = b + 1
			elif dn or rt:
				idx = b - 1
			# surface grain
			var n := pnoise(x / 4.0, y / 4.0, size / 4, seed_v + id)
			var speck := Px.hash01(x, y, seed_v * 13 + id)
			if speck > 0.93:
				idx -= 1
			elif speck < 0.04 and not (dn or rt):
				idx += 1
			var col: Color = Pal.ramp(r, idx)
			# low-frequency staining + moss patches
			var stain := pnoise(x / 16.0, y / 16.0, size / 16, seed_v + 3)
			if stain > 0.72:
				col = col.lerp(Pal.ramp(r, base - 2), 0.35)
			var mm := pnoise(x / 8.0, y / 8.0, size / 8, seed_v + 9)
			if mm > 1.0 - moss_amt * 0.6 and Px.hash01(x, y, seed_v + 77) > 0.45:
				col = moss[2] if n > 0.5 else moss[1]
			c.put(x, y, col)
	# hairline cracks on a few stones
	for k in 7:
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var len := rng.randi_range(4, 9)
		var dx := 1 if rng.randf() > 0.5 else -1
		for s in len:
			var px := posmod(cx + s * dx, size)
			var py := posmod(cy + int(s * 0.6 + rng.randf() * 1.2), size)
			if edge[py * size + px] == 0:
				c.put(px, py, Pal.ramp(r, base - 2))
	c.save(path)


static func _wall(path: String, width: int, r: Array, base: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := 32
	var c := Px.new(width, h)
	# Cap ledge (top 3px)
	for x in width:
		c.put(x, 0, Pal.ramp(r, base + 2))
		c.put(x, 1, Pal.ramp(r, base + 1))
		c.put(x, 2, Pal.ramp(r, base - 1))
		c.put(x, 3, Pal.ramp(r, base - 2))
	var row_tops := [4, 11, 18, 25]
	for ri in row_tops.size():
		var top: int = row_tops[ri]
		var rh := 7
		var widths := split(width, 9, 17, rng)
		var off := rng.randi_range(0, width - 1)
		var x0 := 0
		for bw in widths:
			var tone := rng.randf()
			var b := base
			if tone < 0.2:
				b = base - 1
			elif tone > 0.88:
				b = base + 1
			var chipped := rng.randf() < 0.12
			for yy in range(top, top + rh):
				for xx in range(x0, x0 + bw):
					var px := posmod(xx + off, width)
					var col: Color
					if yy == top + rh - 1 or xx == x0 + bw - 1:
						col = Pal.ramp(r, base - 2)
					elif yy == top or xx == x0:
						col = Pal.ramp(r, b + 1)
					elif yy == top + rh - 2 or xx == x0 + bw - 2:
						col = Pal.ramp(r, b - 1)
					else:
						col = Pal.ramp(r, b)
						if Px.hash01(px, yy, seed_v) > 0.92:
							col = Pal.ramp(r, b - 1)
					if chipped and xx > x0 + bw - 5 and yy > top + rh - 4 and xx < x0 + bw - 1 and yy < top + rh - 1:
						col = Pal.ramp(r, base - 2)
					# grime toward the floor
					var grime := float(yy - 14) / 18.0
					if grime > 0.0 and Px.bayer(px, yy) < grime * 0.55:
						col = col.lerp(Pal.ramp(r, 0), 0.45)
					c.put(px, yy, col)
			x0 += bw
	# floor contact shadow
	for x in width:
		c.put(x, 31, Pal.ramp(r, 0))
	c.save(path)


static func _top(path: String, size: int, r: Array, seed_v: int) -> void:
	var c := Px.new(size, size)
	for y in size:
		for x in size:
			var n := pnoise(x / 8.0, y / 8.0, size / 8, seed_v)
			var idx := 1 if n > 0.55 else 0
			if Px.hash01(x, y, seed_v) > 0.94:
				idx += 1
			c.put(x, y, Pal.ramp(r, idx))
	c.save(path)


## Short ledge face (8px tall) used for the near/south walls.
static func _ledge(path: String, width: int, r: Array, base: int, seed_v: int) -> void:
	var c := Px.new(width, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var widths := split(width, 10, 20, rng)
	var x0 := 0
	for bw in widths:
		for yy in 8:
			for xx in range(x0, x0 + bw):
				var col: Color
				if yy == 0:
					col = Pal.ramp(r, base + 1)
				elif yy == 7:
					col = Pal.ramp(r, 0)
				elif xx == x0 + bw - 1:
					col = Pal.ramp(r, base - 2)
				elif yy >= 5:
					col = Pal.ramp(r, base - 1)
				else:
					col = Pal.ramp(r, base)
				c.put(xx, yy, col)
		x0 += bw
	c.save(path)


static func _pit(path: String, size: int) -> void:
	var c := Px.new(size, size)
	for y in size:
		for x in size:
			var n := pnoise(x / 8.0, y / 8.0, 8, 61)
			var col := Pal.VOID if n > 0.6 else Pal.INK
			if Px.hash01(x, y, 99) > 0.985:
				col = Pal.SOUL[1]
			c.put(x, y, col)
	c.save(path)
