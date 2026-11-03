## Tiny pixel-art canvas used by the asset generators.
## Shapes are drawn into masks, then painted with a colour ramp and automatic
## light-from-top-left shading so every part gets consistent volume.
extends RefCounted

var w: int
var h: int
var img: Image
## Emission mask: pixels marked here glow in the dark in-game.
var glow: PackedByteArray


func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	glow.resize(w * h)


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func put(x: int, y: int, c: Color) -> void:
	if inside(x, y):
		if c.a >= 0.999:
			img.set_pixel(x, y, c)
			glow[y * w + x] = 0
		elif c.a > 0.0:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


## Puts an emissive pixel (glows in darkness).
func lit(x: int, y: int, c: Color) -> void:
	if inside(x, y):
		img.set_pixel(x, y, c)
		glow[y * w + x] = 1


func fill_lit(m: Mask, c: Color) -> void:
	for y in h:
		for x in w:
			if m.has(x, y):
				lit(x, y, c)


func has_glow() -> bool:
	for g in glow:
		if g != 0:
			return true
	return false


func glow_image() -> Image:
	var e := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	e.fill(Color(0, 0, 0, 1))
	for y in h:
		for x in w:
			if glow[y * w + x] != 0:
				e.set_pixel(x, y, Color(1, 1, 1, 1))
	return e


func get_c(x: int, y: int) -> Color:
	if inside(x, y):
		return img.get_pixel(x, y)
	return Color(0, 0, 0, 0)


func opaque(x: int, y: int) -> bool:
	return get_c(x, y).a > 0.5


func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			put(xx, yy, c)


func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		put(x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var m := mask()
	m.ellipse(cx, cy, rx, ry)
	fill(m, c)


func mask() -> Mask:
	return Mask.new(w, h)


func fill(m: Mask, c: Color) -> void:
	for y in h:
		for x in w:
			if m.has(x, y):
				put(x, y, c)


## Paints a mask with a ramp: base colour, highlight on the top-left rim,
## shadow on the bottom-right rim. `deep` adds a second shadow band.
func paint(m: Mask, r: Array, base: int, deep := false, hi := true) -> void:
	for y in h:
		for x in w:
			if not m.has(x, y):
				continue
			var i := base
			if not m.has(x + 1, y + 1) or not m.has(x, y + 1):
				i = base - 1
			elif hi and (not m.has(x - 1, y - 1) or not m.has(x, y - 1)):
				i = base + 1
			elif deep and (not m.has(x + 2, y + 2) or not m.has(x, y + 2)):
				i = base - 1
			put(x, y, r[clampi(i, 0, r.size() - 1)])


## Adds a 1px outline around all opaque pixels (4-neighbourhood).
func outline(c: Color, diagonal := false) -> void:
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			var hit := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					hit = true
					break
			if not hit and diagonal:
				for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
						hit = true
						break
			if hit:
				img.set_pixel(x, y, c)


## Copies another canvas onto this one.
func blit(src, ox: int, oy: int, flip_h := false) -> void:
	for y in src.h:
		for x in src.w:
			var c: Color = src.img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var tx: int = ox + (src.w - 1 - x if flip_h else x)
			if src.glow[y * src.w + x] != 0:
				lit(tx, oy + y, c)
			else:
				put(tx, oy + y, c)


func blit_image(src: Image, ox: int, oy: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.0:
				put(ox + x, oy + y, c)


func save(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


## Deterministic hash noise in [0,1).
static func hash01(x: int, y: int, s: int = 0) -> float:
	var n := x * 374761393 + y * 668265263 + s * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65536.0


## Smooth value noise in [0,1).
static func vnoise(x: float, y: float, s: int = 0) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := hash01(xi, yi, s)
	var b := hash01(xi + 1, yi, s)
	var c := hash01(xi, yi + 1, s)
	var d := hash01(xi + 1, yi + 1, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Ordered 4x4 Bayer threshold in [0,1).
static func bayer(x: int, y: int) -> float:
	const M := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (M[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


class Mask:
	var w: int
	var h: int
	var bits: PackedByteArray

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		bits.resize(w * h)

	func has(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		return bits[y * w + x] != 0

	func set_bit(x: int, y: int, v := true) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			bits[y * w + x] = 1 if v else 0

	func rect(x: int, y: int, rw: int, rh: int, v := true) -> Mask:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				set_bit(xx, yy, v)
		return self

	func ellipse(cx: float, cy: float, rx: float, ry: float, v := true) -> Mask:
		for y in h:
			for x in w:
				var dx := (x + 0.5 - cx) / maxf(rx, 0.01)
				var dy := (y + 0.5 - cy) / maxf(ry, 0.01)
				if dx * dx + dy * dy <= 1.0:
					set_bit(x, y, v)
		return self

	## Scanline polygon fill.
	func poly(pts: PackedVector2Array, v := true) -> Mask:
		for y in h:
			var sy := y + 0.5
			var xs: Array[float] = []
			for i in pts.size():
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
					xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			var i := 0
			while i + 1 < xs.size():
				for x in range(int(ceil(xs[i] - 0.5)), int(floor(xs[i + 1] - 0.5)) + 1):
					set_bit(x, y, v)
				i += 2
		return self

	func line(x0: int, y0: int, x1: int, y1: int, v := true) -> Mask:
		var dx := absi(x1 - x0)
		var dy := -absi(y1 - y0)
		var sx := 1 if x0 < x1 else -1
		var sy := 1 if y0 < y1 else -1
		var err := dx + dy
		while true:
			set_bit(x0, y0, v)
			if x0 == x1 and y0 == y1:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy
		return self

	func subtract(o: Mask) -> Mask:
		for i in bits.size():
			if o.bits[i] != 0:
				bits[i] = 0
		return self

	func intersect(o: Mask) -> Mask:
		for i in bits.size():
			if o.bits[i] == 0:
				bits[i] = 0
		return self

	func union(o: Mask) -> Mask:
		for i in bits.size():
			if o.bits[i] != 0:
				bits[i] = 1
		return self
