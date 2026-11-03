## Nine-slice interface textures: carved dark stone with warm iron trim.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")


static func build(dir: String) -> void:
	_frame(dir, "ui_panel", 24, Pal.VOID, Pal.EARTH, true, 0.94)
	_frame(dir, "ui_panel_dark", 16, Pal.INK, Pal.STONE, false, 0.92)
	_frame(dir, "ui_card", 24, Color8(24, 20, 34), Pal.EARTH, true, 1.0)
	_frame(dir, "ui_tooltip", 12, Color8(16, 13, 24), Pal.EARTH, false, 0.97)
	_button(dir, "ui_button", Pal.STONE, 2, Pal.EARTH, 2)
	_button(dir, "ui_button_hover", Pal.STONE, 3, Pal.EMBER, 2)
	_button(dir, "ui_button_pressed", Pal.STONE, 1, Pal.EMBER, 3)
	_button(dir, "ui_button_disabled", Pal.STONE, 1, Pal.STONE, 1)
	_slot(dir)
	_bar(dir)


static func _frame(dir: String, name: String, size: int, fill: Color, trim: Array, studs: bool, alpha: float) -> void:
	var c := Px.new(size, size)
	for y in size:
		for x in size:
			var col := fill
			if Px.hash01(x, y, 3) > 0.9:
				col = fill.lightened(0.06)
			col.a = alpha
			c.put(x, y, col)
	var last := size - 1
	for i in size:
		# outer dark edge
		c.put(i, 0, Pal.INK)
		c.put(i, last, Pal.INK)
		c.put(0, i, Pal.INK)
		c.put(last, i, Pal.INK)
		# warm trim, lit from the top-left
		c.put(i, 1, trim[3])
		c.put(1, i, trim[3])
		c.put(i, last - 1, trim[1])
		c.put(last - 1, i, trim[1])
		c.put(i, 2, trim[2])
		c.put(2, i, trim[2])
		c.put(i, last - 2, trim[1])
		c.put(last - 2, i, trim[1])
		# inner shadow line
		if i > 2 and i < last - 2:
			c.put(i, 3, Pal.INK)
			c.put(3, i, Pal.INK)
	c.put(0, 0, Color(0, 0, 0, 0))
	c.put(last, 0, Color(0, 0, 0, 0))
	c.put(0, last, Color(0, 0, 0, 0))
	c.put(last, last, Color(0, 0, 0, 0))
	if studs:
		for p in [Vector2i(2, 2), Vector2i(last - 2, 2), Vector2i(2, last - 2), Vector2i(last - 2, last - 2)]:
			c.put(p.x, p.y, Pal.GOLD[3])
			c.put(p.x + 1, p.y, Pal.GOLD[1])
			c.put(p.x, p.y + 1, Pal.GOLD[1])
	c.save(dir.path_join(name + ".png"))


static func _button(dir: String, name: String, fill: Array, fi: int, trim: Array, ti: int) -> void:
	var size := 16
	var c := Px.new(size, size)
	var last := size - 1
	for y in size:
		for x in size:
			var col: Color = Pal.ramp(fill, fi) if y < size / 2 else Pal.ramp(fill, fi - 1)
			c.put(x, y, col)
	for i in size:
		c.put(i, 0, Pal.INK)
		c.put(i, last, Pal.INK)
		c.put(0, i, Pal.INK)
		c.put(last, i, Pal.INK)
		c.put(i, 1, Pal.ramp(trim, ti + 1))
		c.put(1, i, Pal.ramp(trim, ti))
		c.put(i, last - 1, Pal.ramp(trim, ti - 1))
		c.put(last - 1, i, Pal.ramp(trim, ti - 1))
	c.put(0, 0, Color(0, 0, 0, 0))
	c.put(last, 0, Color(0, 0, 0, 0))
	c.put(0, last, Color(0, 0, 0, 0))
	c.put(last, last, Color(0, 0, 0, 0))
	c.save(dir.path_join(name + ".png"))


static func _slot(dir: String) -> void:
	var size := 22
	var c := Px.new(size, size)
	var last := size - 1
	for y in size:
		for x in size:
			c.put(x, y, Color(Pal.INK.r, Pal.INK.g, Pal.INK.b, 0.85))
	for i in size:
		for k in 2:
			c.put(i, k, Pal.EARTH[3 - k])
			c.put(k, i, Pal.EARTH[3 - k])
			c.put(i, last - k, Pal.EARTH[1])
			c.put(last - k, i, Pal.EARTH[1])
	for p in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		c.put(p.x, p.y, Pal.GOLD[3])
	c.save(dir.path_join("ui_slot.png"))


static func _bar(dir: String) -> void:
	var c := Px.new(12, 8)
	for y in 8:
		for x in 12:
			var edge := x == 0 or y == 0 or x == 11 or y == 7
			c.put(x, y, Pal.INK if edge else Color(Pal.VOID.r, Pal.VOID.g, Pal.VOID.b, 1.0))
	for x in range(1, 11):
		c.put(x, 1, Pal.EARTH[2])
	c.save(dir.path_join("ui_bar.png"))
