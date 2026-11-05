## Seamless environment textures. 16 texels = 1 world tile.
## Floors and wall tops tile in both axes; wall faces tile horizontally and are
## exactly one wall height (32px = 2 tiles) tall.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const GenStone = preload("res://tools/art/gen_stone.gd")


static func build(out_dir: String) -> void:
	GenStone.build(out_dir)      # floors, wall faces, caps and columns
	_ledge(out_dir.path_join("crypt_ledge.png"), 64, Pal.STONE, 2, 51)
	_ledge(out_dir.path_join("hearth_ledge.png"), 64, Pal.EARTH, 2, 52)
	_ledge(out_dir.path_join("root_ledge.png"), 64, Pal.EARTH, 1, 65)
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
