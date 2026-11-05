## Depth variants of each region's floor and wall textures, so the second and
## third depth of a region look like going deeper into one real place:
##   the Ossuary   - the Charnel Galleries (bones in the paving, more cracks),
##                   the Warden's Deep (soul-light inlay in the seams, wet stone);
##   the Rootmire  - the Sporefields (fungus caps, spore bloom),
##                   the Bloom's Heart (red veins of the Bloom through it all);
##   the Throne    - the Court of Ash (ash drifts, scorch),
##                   the Last Sun's Seat (gold inlay, a sun mosaic).
## The first depth keeps the base texture. Writes <theme>_floor_d2/_d3 and
## <theme>_wall_d2/_d3 next to the base ones (job "depths": run after "tiles"
## and "throne"). Every mark wraps, so the textures stay seamless.
extends RefCounted

const Pal = preload("res://src/render/pal.gd")
const GenStone = preload("res://tools/art/gen_stone.gd")


static func build(dir: String) -> void:
	for theme in ["crypt", "root", "throne"]:
		for d in [2, 3]:
			_floor(dir, theme, d)
			_wall(dir, theme, d)


static func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)


static func _px(img: Image, x: int, y: int) -> Color:
	return img.get_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()))


static func _blend(img: Image, x: int, y: int, c: Color, k: float) -> void:
	_put(img, x, y, _px(img, x, y).lerp(c, k))


## A seam is a pixel darker than both its neighbours along one axis (mortar).
static func _seam(img: Image, x: int, y: int) -> bool:
	var v := _px(img, x, y).get_luminance()
	return (v < _px(img, x - 1, y).get_luminance() - 0.04 and v < _px(img, x + 1, y).get_luminance() - 0.04) or \
		(v < _px(img, x, y - 1).get_luminance() - 0.04 and v < _px(img, x, y + 1).get_luminance() - 0.04)


static func _floor(dir: String, theme: String, d: int) -> void:
	var img := _load(dir.path_join(theme + "_floor.png"))
	var w := img.get_width()
	var h := img.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme) + d * 101
	var m: int = maxi(1, w * h / (128 * 128))      # as many marks per tile on bigger floors
	match theme:
		"crypt":
			if d == 2:
				# the Charnel Galleries: bones set in the paving, more cracks, old stains
				for k in 14 * m:
					_bone(img, rng.randi_range(0, w), rng.randi_range(0, h), rng)
				for k in 10 * m:
					_crack(img, rng.randi_range(0, w), rng.randi_range(0, h), rng, Pal.STONE[0])
				for k in 5 * m:
					_stain(img, rng.randi_range(0, w), rng.randi_range(0, h), rng.randf_range(5.0, 10.0), Pal.BLOOD[0], 0.25)
			else:
				# the Warden's Deep: darker, wet, soul-light glowing in the seams
				_darken(img, 0.82)
				_inlay(img, Pal.SOUL[3], 0.6, 5)
				for k in 4 * m:
					_stain(img, rng.randi_range(0, w), rng.randi_range(0, h), rng.randf_range(8.0, 14.0), Pal.FROST[1], 0.35)
				for k in 8 * m:
					_crack(img, rng.randi_range(0, w), rng.randi_range(0, h), rng, Pal.SOUL[1])
		"root":
			if d == 2:
				# the Sporefields: fungus caps and pale spore bloom
				for k in 22 * m:
					_cap(img, rng.randi_range(0, w), rng.randi_range(0, h), rng)
				for k in 6 * m:
					_stain(img, rng.randi_range(0, w), rng.randi_range(0, h), rng.randf_range(6.0, 12.0), Pal.MOSS[3], 0.2)
			else:
				# the Bloom's Heart: red veins of the Bloom run through everything
				_tint(img, Color(1.0, 0.86, 0.88), 0.25)
				for k in 9 * m:
					_vein(img, rng.randi_range(0, w), rng.randi_range(0, h), rng)
				for k in 10 * m:
					var x := rng.randi_range(0, w)
					var y := rng.randi_range(0, h)
					_put(img, x, y, Pal.BLOOD[3])
					_put(img, x + 1, y, Pal.BLOOD[2])
		"throne":
			if d == 2:
				# the Court of Ash: drifts of ash, scorch where the fire walked
				for k in 7 * m:
					_stain(img, rng.randi_range(0, w), rng.randi_range(0, h), rng.randf_range(7.0, 13.0), Pal.STONE[4], 0.3)
				for k in 5 * m:
					_stain(img, rng.randi_range(0, w), rng.randi_range(0, h), rng.randf_range(5.0, 9.0), Color(0.08, 0.06, 0.07), 0.45)
				for k in 40 * m:
					_blend(img, rng.randi_range(0, w), rng.randi_range(0, h), Pal.EMBER[2], 0.6)
			else:
				# the Last Sun's Seat: gold in the seams and a sun in the floor
				_inlay(img, Pal.GOLD[2], 0.45, 9)
				_sun(img, w / 2, h / 2, 13)
	img.save_png(ProjectSettings.globalize_path(dir.path_join("%s_floor_d%d.png" % [theme, d])))


static func _wall(dir: String, theme: String, d: int) -> void:
	var img := _load(dir.path_join(theme + "_wall.png"))
	var w := img.get_width()
	var h := img.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme) + d * 211
	match theme:
		"crypt":
			if d == 2:
				# burial niches with skulls in the face
				for k in 3:
					_niche(img, 8 + k * 21 + rng.randi_range(-2, 2), 10 + rng.randi_range(-2, 3))
			else:
				_darken(img, 0.82)
				for k in 4:
					_rune(img, 6 + k * 16, 12 + rng.randi_range(-3, 3), Pal.SOUL[3], k)
		"root":
			if d == 2:
				for k in 9:
					_cap(img, rng.randi_range(0, w), rng.randi_range(h / 2, h), rng)
			else:
				_tint(img, Color(1.0, 0.86, 0.88), 0.2)
				for k in 4:
					_vein(img, rng.randi_range(0, w), rng.randi_range(0, h), rng)
		"throne":
			if d == 2:
				for k in 4:
					_stain(img, rng.randi_range(0, w), rng.randi_range(h / 3, h), rng.randf_range(5.0, 9.0), Color(0.08, 0.06, 0.07), 0.45)
			else:
				for k in 3:
					_rune(img, 10 + k * 22, 9, Pal.GOLD[3], k + 1)
	img.save_png(ProjectSettings.globalize_path(dir.path_join("%s_wall_d%d.png" % [theme, d])))


# --- marks (all wrap) ---------------------------------------------------------

static func Px_hash(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177 & 0x7fffffff
	return float(n % 10000) / 10000.0


static func _darken(img: Image, k: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))


static func _tint(img: Image, t: Color, k: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.lerp(Color(c.r * t.r, c.g * t.g, c.b * t.b, c.a), k * 4.0 if k < 0.25 else 1.0))


static func _stain(img: Image, cx: int, cy: int, r: float, col: Color, k: float) -> void:
	for y in range(-int(r), int(r) + 1):
		for x in range(-int(r), int(r) + 1):
			var dd := Vector2(x, y).length() / r
			if dd < 1.0 and Px_hash(cx + x, cy + y, 3) > dd * 0.8:
				_blend(img, cx + x, cy + y, col, k * (1.0 - dd * 0.6))


static func _crack(img: Image, x: int, y: int, rng: RandomNumberGenerator, col: Color) -> void:
	var dx := 1 if rng.randf() > 0.5 else -1
	for st in rng.randi_range(5, 12):
		x += dx
		if rng.randf() < 0.45:
			y += 1 if rng.randf() > 0.3 else -1
		_put(img, x, y, col)


static func _bone(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var horiz := rng.randf() > 0.5
	var n := rng.randi_range(3, 6)
	for k in n:
		var px := x + (k if horiz else 0)
		var py := y + (0 if horiz else k)
		_put(img, px, py, Pal.BONE[3] if k > 0 and k < n - 1 else Pal.BONE[4])
		_put(img, px + (0 if horiz else 1), py + (1 if horiz else 0), Pal.BONE[1])
	# knuckled ends
	_put(img, x - (1 if horiz else 0), y - (0 if horiz else 1), Pal.BONE[4])


static func _cap(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var col: Color = [Pal.BONE[4], Pal.GOLD[3], Pal.BLOOD[3]][rng.randi_range(0, 2)] if rng.randf() < 0.7 else Pal.MOSS[4]
	_put(img, x, y, col)
	_put(img, x + 1, y, col)
	_put(img, x - 1, y, col.darkened(0.25))
	_put(img, x, y + 1, Pal.BONE[2])
	_put(img, x, y - 1, col.lightened(0.25))


static func _vein(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var a := rng.randf() * TAU
	var fx := float(x)
	var fy := float(y)
	for st in rng.randi_range(14, 30):
		a += rng.randf_range(-0.5, 0.5)
		fx += cos(a)
		fy += sin(a)
		_put(img, int(fx), int(fy), Pal.BLOOD[2])
		if st % 3 == 0:
			_put(img, int(fx) + 1, int(fy), Pal.BLOOD[1])


static func _sun(img: Image, cx: int, cy: int, r: int) -> void:
	for k in 16:
		var d := Vector2.from_angle(k * TAU / 16.0)
		for s in range(4, r):
			_blend(img, cx + int(d.x * s), cy + int(d.y * s), Pal.GOLD[3] if k % 2 == 0 else Pal.GOLD[2], 0.55)
	for y in range(-3, 4):
		for x in range(-3, 4):
			if x * x + y * y <= 9:
				_blend(img, cx + x, cy + y, Pal.GOLD[4], 0.7)


static func _niche(img: Image, x: int, y: int) -> void:
	for yy in range(y, y + 10):
		for xx in range(x, x + 9):
			_put(img, xx, yy, Pal.INK if yy > y + 1 else Color(0.06, 0.05, 0.08))
	# a skull resting in it
	for yy in range(y + 4, y + 8):
		for xx in range(x + 2, x + 7):
			if not ((xx == x + 2 or xx == x + 6) and yy == y + 7):
				_put(img, xx, yy, Pal.BONE[3])
	_put(img, x + 3, y + 5, Pal.INK)
	_put(img, x + 5, y + 5, Pal.INK)
	_put(img, x + 4, y + 4, Pal.BONE[4])


## Glowing inlay in the mortar, but only in long patches of each floor: a room
## should have a few bright runs in it, not a grid drawn over everything.
static func _inlay(img: Image, col: Color, k: float, s: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cell := float(w) / 5.0
	var seams: Array[Vector2i] = []
	for y in h:
		for x in w:
			if _seam(img, x, y) and GenStone.pn(x, y, cell, w, s) > 0.6 and Px_hash(x, y, s) > 0.2:
				seams.append(Vector2i(x, y))
	for p in seams:
		_blend(img, p.x, p.y, col, k)


## Carved signs, cut into the stone and lit from within. Not letters: a lantern,
## a tally, a stair, a flame.
const RUNES := [
	[[2, 0], [1, 1], [3, 1], [0, 2], [4, 2], [1, 3], [3, 3], [2, 4]],
	[[0, 0], [2, 0], [4, 0], [0, 1], [2, 1], [4, 1], [0, 2], [2, 2], [4, 2], [2, 4]],
	[[0, 0], [1, 0], [2, 0], [2, 1], [2, 2], [3, 2], [4, 2], [4, 3], [4, 4]],
	[[2, 0], [1, 1], [2, 1], [1, 2], [3, 2], [0, 3], [4, 3], [1, 4], [2, 4], [3, 4]],
]


static func _rune(img: Image, x: int, y: int, col: Color, which := 0) -> void:
	var pts: Array = RUNES[which % RUNES.size()]
	for p in pts:
		_blend(img, x + p[0] + 1, y + p[1] + 1, Pal.INK, 0.7)     # the cut's shadow
	for p in pts:
		_put(img, x + p[0], y + p[1], col)
