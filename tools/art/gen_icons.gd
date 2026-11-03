## 16x16 icons for abilities, relics, rewards, currencies and branches.
## Writes icons.png + icons.json (atlas) and icons_reward (in-world door icons).
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")

const NAMES := [
	"flame", "snow", "sword", "hammer", "staff", "boot", "heart", "wick", "die", "pouch",
	"coal", "shard", "bell", "feather", "ring", "crown", "gem_blue", "gem_red", "mask", "mirror",
	"lantern", "fork", "stone", "bandage", "sigil", "collar", "brand", "phoenix", "prism", "sun",
	"hourglass", "candle", "ring_cursed", "shield", "flare", "lance", "gloamstep", "aegis", "wisp", "skull",
	"chest", "shrine", "merchant", "stairs", "boss", "relic", "embers", "vigor", "memory", "sunshard",
	"ember", "xp", "flask", "dodge", "kindle", "lock", "eye", "hearth", "star", "key",
	"daggers", "spear", "bow", "tome",
]

const REWARD_KEYS := ["relic", "embers", "vigor", "memory", "sunshard", "chest", "shrine", "merchant", "skull", "stairs", "boss"]


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func build(dir: String) -> void:
	var cols := 10
	var rows := int(ceil(NAMES.size() / float(cols)))
	var atlas := Px.new(cols * 16, rows * 16)
	var meta := {}
	for i in NAMES.size():
		var ic := draw(NAMES[i])
		atlas.blit(ic, (i % cols) * 16, (i / cols) * 16)
		meta[NAMES[i]] = [i % cols, i / cols]
	atlas.save(dir.path_join("icons.png"))
	var f := FileAccess.open(ProjectSettings.globalize_path(dir.path_join("icons.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cell": 16, "icons": meta}, "\t"))
	f.close()
	# door reward icons: icon on a dark disc with a soft rim
	var s := Sheet.new(20, 20, Vector2i(10, 19))
	for k in REWARD_KEYS:
		var c := Px.new(20, 20)
		var disc := c.mask().ellipse(10.0, 10.0, 9.4, 9.4)
		c.fill(disc, Pal.VOID)
		var rim := c.mask().ellipse(10.0, 10.0, 9.4, 9.4)
		rim.subtract(c.mask().ellipse(10.0, 10.0, 8.4, 8.4))
		var rc: Color = Pal.GOLD[3] if k != "skull" and k != "boss" else Pal.BLOOD[3]
		if k == "shrine":
			rc = Pal.GLOAM[4]
		c.fill_lit(rim, rc)
		c.blit(draw(k), 2, 2)
		s.add(k, [c], 1.0)
	s.save(dir, "icons_reward")


static func draw(n: String) -> Px:
	var c := Px.new(16, 16)
	match n:
		"flame", "pyre":
			_flame(c, 8.0, 14.0, 5.0, 12.0, Pal.EMBER)
		"snow", "rime":
			for a in 3:
				var ang := a * PI / 3.0
				var d := Vector2(cos(ang), sin(ang)) * 6.0
				c.line(int(8 - d.x), int(8 - d.y), int(8 + d.x), int(8 + d.y), Pal.FROST[4])
			c.put(8, 8, Pal.WHITE)
			c.put(8, 2, Pal.FROST[5])
			c.put(8, 14, Pal.FROST[5])
		"sword", "blade":
			var m := c.mask().poly(V([[3, 13], [11, 3], [13, 3], [13, 5], [5, 14]]))
			c.paint(m, Pal.STEEL, 4)
			c.line(2, 10, 6, 14, Pal.GOLD[3])
			c.line(1, 15, 3, 13, Pal.WOOD[3])
		"hammer":
			c.line(3, 14, 10, 7, Pal.WOOD[3])
			c.line(4, 14, 11, 7, Pal.WOOD[2])
			c.paint(c.mask().poly(V([[7, 4], [11, 1], [15, 5], [11, 9]])), Pal.STEEL, 3, true)
			c.lit(11, 5, Pal.EMBER[3])
		"daggers":
			for k in 2:
				var ox := 4 * k
				c.paint(c.mask().poly(V([[2 + ox, 12], [8 + ox, 4], [10 + ox, 2], [9 + ox, 6], [4 + ox, 13]])), Pal.STEEL, 4)
				c.line(1 + ox, 13, 3 + ox, 11, Pal.GOLD[3])
				c.line(0 + ox, 15, 2 + ox, 13, Pal.EARTH[3])
			c.lit(9, 5, Pal.GLOAM[4])
		"spear":
			c.line(1, 15, 11, 5, Pal.WOOD[3])
			c.line(2, 15, 12, 5, Pal.WOOD[2])
			c.paint(c.mask().poly(V([[10, 6], [12, 1], [15, 0], [14, 3], [9, 7]])), Pal.STEEL, 4)
			c.lit(13, 2, Pal.EMBER[4])
			c.line(9, 7, 10, 8, Pal.GOLD[3])
		"bow":
			var lb := c.mask().line(4, 1, 9, 4).line(9, 4, 11, 8).line(11, 8, 9, 12).line(9, 12, 4, 15)
			lb.line(5, 1, 10, 4).line(5, 15, 10, 12)
			c.paint(lb, Pal.WOOD, 3)
			for y in range(1, 16):
				c.lit(4, y, Pal.EMBER[3] if y % 2 else Pal.EMBER[2])
			c.line(4, 8, 13, 8, Pal.STEEL[3])
			c.put(14, 8, Pal.STEEL[4])
		"tome":
			c.paint(c.mask().poly(V([[1, 4], [8, 5], [15, 4], [15, 13], [8, 14], [1, 13]])), Pal.BLOOD, 2, true)
			c.paint(c.mask().poly(V([[2, 4], [8, 5], [8, 13], [2, 12]])), Pal.BONE, 3)
			c.paint(c.mask().poly(V([[8, 5], [14, 4], [14, 12], [8, 13]])), Pal.BONE, 4)
			c.lit(11, 7, Pal.EMBER[5])
			c.lit(10, 8, Pal.EMBER[4])
			c.lit(12, 9, Pal.EMBER[4])
			c.line(3, 7, 6, 7, Pal.EARTH[2])
			c.line(3, 9, 6, 9, Pal.EARTH[2])
		"staff":
			c.line(3, 14, 11, 6, Pal.WOOD[3])
			c.line(4, 14, 12, 6, Pal.WOOD[2])
			c.fill_lit(c.mask().ellipse(12.5, 4.5, 2.6, 2.6), Pal.EMBER[3])
			c.lit(12, 4, Pal.EMBER[5])
		"boot", "dodge", "gloam":
			c.paint(c.mask().poly(V([[5, 2], [10, 2], [10, 10], [14, 11], [14, 14], [4, 14], [5, 8]])), Pal.EARTH, 3, true)
			c.line(1, 9, 3, 9, Pal.GLOAM[4])
			c.line(0, 12, 3, 12, Pal.GLOAM[3])
		"heart", "vigor":
			var m := c.mask().ellipse(5.5, 6.0, 3.4, 3.4)
			m.union(c.mask().ellipse(10.5, 6.0, 3.4, 3.4))
			m.poly(V([[2.3, 7], [13.7, 7], [8, 14]]))
			c.paint(m, Pal.BLOOD, 3, true)
			c.put(5, 5, Pal.WHITE)
		"wick", "kindle":
			c.paint(c.mask().rect(6, 7, 4, 8), Pal.BONE, 3, true)
			_flame(c, 8.0, 7.0, 2.4, 6.0, Pal.EMBER)
		"die":
			c.paint(c.mask().rect(3, 3, 10, 10), Pal.BONE, 3, true)
			for p in [Vector2i(5, 5), Vector2i(10, 10), Vector2i(8, 8), Vector2i(10, 5), Vector2i(5, 10)]:
				c.put(p.x, p.y, Pal.INK)
		"pouch":
			c.paint(c.mask().ellipse(8.0, 10.0, 5.0, 4.5), Pal.EARTH, 3, true)
			c.paint(c.mask().rect(6, 3, 4, 3), Pal.EARTH, 2)
			c.lit(8, 9, Pal.EMBER[4])
		"coal":
			c.paint(c.mask().poly(V([[3, 10], [6, 4], [11, 3], [14, 8], [11, 13], [5, 13]])), Pal.STONE, 1, true)
			for p in [Vector2i(7, 7), Vector2i(9, 9), Vector2i(6, 10), Vector2i(10, 6)]:
				c.lit(p.x, p.y, Pal.EMBER[3])
		"shard":
			c.paint(c.mask().poly(V([[8, 1], [12, 8], [8, 15], [5, 8]])), Pal.FROST, 4, true)
			c.put(8, 5, Pal.WHITE)
		"bell":
			c.paint(c.mask().ellipse(8.0, 7.0, 4.5, 5.0).rect(3, 7, 10, 5), Pal.GOLD, 2, true)
			c.paint(c.mask().rect(2, 12, 12, 1), Pal.GOLD, 3)
			c.put(8, 14, Pal.GOLD[4])
		"feather":
			c.paint(c.mask().poly(V([[3, 14], [12, 2], [14, 4], [5, 14]])), Pal.STONE, 1, true)
			c.line(3, 14, 13, 3, Pal.STONE[3])
		"ring":
			var m := c.mask().ellipse(8.0, 9.0, 5.0, 5.0)
			m.subtract(c.mask().ellipse(8.0, 9.0, 3.0, 3.0))
			c.paint(m, Pal.STEEL, 3, true)
			c.put(8, 4, Pal.SOUL[4])
		"ring_cursed":
			var m := c.mask().ellipse(8.0, 9.0, 5.0, 5.0)
			m.subtract(c.mask().ellipse(8.0, 9.0, 3.0, 3.0))
			c.paint(m, Pal.GLOAM, 3, true)
			c.lit(8, 4, Pal.GLOAM[5])
		"crown":
			c.paint(c.mask().poly(V([[2, 13], [2, 5], [5, 9], [8, 3], [11, 9], [14, 5], [14, 13]])), Pal.GOLD, 3, true)
			c.lit(8, 6, Pal.EMBER[4])
		"gem_blue", "gem_red", "prism":
			var r: Array = Pal.FROST if n == "gem_blue" else (Pal.BLOOD if n == "gem_red" else Pal.GLOAM)
			c.paint(c.mask().poly(V([[4, 5], [8, 2], [12, 5], [8, 14]])), r, 3, true)
			c.put(7, 4, Pal.WHITE)
			if n == "prism":
				c.line(9, 6, 12, 12, Pal.EMBER[3])
				c.line(7, 6, 4, 12, Pal.FROST[4])
		"mask":
			c.paint(c.mask().ellipse(8.0, 8.0, 5.5, 6.5), Pal.BONE, 3, true)
			c.fill(c.mask().ellipse(6.0, 7.0, 1.2, 1.2), Pal.INK)
			c.fill(c.mask().ellipse(10.0, 7.0, 1.2, 1.2), Pal.INK)
			c.line(6, 11, 10, 11, Pal.INK)
			c.line(12, 4, 15, 2, Pal.GLOAM[4])
		"mirror":
			c.paint(c.mask().ellipse(8.0, 7.0, 4.5, 5.5), Pal.GOLD, 2, true)
			c.fill_lit(c.mask().ellipse(8.0, 7.0, 3.0, 4.0), Pal.FROST[4])
			c.put(7, 5, Pal.WHITE)
			c.paint(c.mask().rect(7, 12, 2, 3), Pal.WOOD, 3)
		"lantern", "hearth":
			c.paint(c.mask().rect(4, 4, 8, 10), Pal.STEEL, 1, true)
			c.fill_lit(c.mask().rect(5, 6, 6, 6), Pal.EMBER[3])
			c.lit(8, 8, Pal.EMBER[5])
			c.line(7, 1, 9, 1, Pal.STEEL[3])
			c.put(6, 2, Pal.STEEL[3])
			c.put(10, 2, Pal.STEEL[3])
		"fork":
			c.line(8, 14, 8, 8, Pal.EMBER[3])
			c.line(8, 8, 4, 2, Pal.EMBER[4])
			c.line(8, 8, 12, 2, Pal.EMBER[4])
			c.lit(4, 2, Pal.EMBER[5])
			c.lit(12, 2, Pal.EMBER[5])
		"stone":
			c.paint(c.mask().poly(V([[2, 12], [4, 5], [10, 3], [14, 8], [12, 14]])), Pal.STONE, 3, true)
			c.line(5, 8, 10, 11, Pal.STONE[1])
		"bandage":
			c.paint(c.mask().poly(V([[2, 10], [10, 2], [14, 6], [6, 14]])), Pal.BONE, 3, true)
			c.fill(c.mask().ellipse(8.0, 8.0, 2.0, 2.0), Pal.BLOOD[2])
		"sigil":
			var m := c.mask().ellipse(8.0, 8.0, 6.5, 6.5)
			m.subtract(c.mask().ellipse(8.0, 8.0, 5.5, 5.5))
			c.fill_lit(m, Pal.FROST[3])
			c.lit(8, 4, Pal.FROST[5])
			c.line(5, 10, 8, 4, Pal.FROST[4])
			c.line(11, 10, 8, 4, Pal.FROST[4])
			c.line(5, 10, 11, 10, Pal.FROST[4])
		"collar":
			var m := c.mask().ellipse(8.0, 8.0, 5.5, 4.0)
			m.subtract(c.mask().ellipse(8.0, 7.5, 4.0, 2.6))
			c.paint(m, Pal.EARTH, 3, true)
			c.lit(8, 12, Pal.EMBER[4])
		"brand":
			c.line(3, 14, 10, 7, Pal.STEEL[3])
			c.fill_lit(c.mask().ellipse(11.0, 5.0, 3.0, 3.0), Pal.EMBER[3])
			c.lit(11, 5, Pal.EMBER[5])
		"phoenix":
			c.fill_lit(c.mask().poly(V([[8, 3], [15, 6], [10, 9], [12, 14], [8, 11], [4, 14], [6, 9], [1, 6]])), Pal.EMBER[3])
			c.lit(8, 6, Pal.EMBER[5])
		"sun", "sunshard":
			for a in 8:
				var d := Vector2.from_angle(a * PI / 4.0)
				c.line(8, 8, int(8 + d.x * 7), int(8 + d.y * 7), Pal.GOLD[3])
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 3.6, 3.6), Pal.GOLD[4])
			c.lit(7, 7, Pal.WHITE)
		"hourglass":
			c.paint(c.mask().rect(3, 1, 10, 2), Pal.WOOD, 3)
			c.paint(c.mask().rect(3, 13, 10, 2), Pal.WOOD, 3)
			c.paint(c.mask().poly(V([[4, 3], [12, 3], [8, 8], [12, 13], [4, 13], [8, 8]])), Pal.FROST, 4)
			c.lit(8, 11, Pal.EMBER[4])
			c.lit(7, 12, Pal.EMBER[3])
			c.lit(9, 12, Pal.EMBER[3])
		"candle":
			c.paint(c.mask().rect(6, 6, 4, 9), Pal.STONE, 1, true)
			c.put(8, 4, Pal.INK)
			c.put(8, 5, Pal.STONE[3])
			c.line(10, 2, 13, 0, Pal.GLOAM[4])
		"shield", "bulwark", "aegis":
			c.paint(c.mask().poly(V([[3, 2], [13, 2], [13, 8], [8, 14], [3, 8]])), Pal.STEEL, 3, true)
			c.line(8, 3, 8, 12, Pal.GOLD[3])
			if n == "aegis":
				c.lit(8, 7, Pal.WHITE)
				c.lit(7, 7, Pal.GOLD[4])
				c.lit(9, 7, Pal.GOLD[4])
		"flare":
			for a in 8:
				var d := Vector2.from_angle(a * PI / 4.0 + 0.3)
				c.lit(int(8 + d.x * 6), int(8 + d.y * 6), Pal.EMBER[3])
				c.lit(int(8 + d.x * 4), int(8 + d.y * 4), Pal.EMBER[4])
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 2.6, 2.6), Pal.EMBER[5])
		"lance":
			c.fill_lit(c.mask().poly(V([[1, 14], [11, 4], [15, 1], [12, 5], [2, 15]])), Pal.EMBER[3])
			c.line(4, 12, 12, 4, Pal.EMBER[5])
		"gloamstep":
			for k in 3:
				c.paint(c.mask().ellipse(4.0 + k * 4.0, 8.0, 2.0, 4.0), Pal.GLOAM, 2 + k)
			c.lit(13, 7, Pal.GLOAM[5])
		"wisp":
			c.fill_lit(c.mask().ellipse(8.0, 7.0, 4.0, 4.0), Pal.EMBER[3])
			c.fill_lit(c.mask().ellipse(8.0, 6.5, 2.0, 2.0), Pal.EMBER[5])
			c.lit(7, 12, Pal.EMBER[2])
			c.lit(9, 13, Pal.EMBER[1])
			c.put(7, 6, Pal.INK)
			c.put(9, 6, Pal.INK)
		"skull", "boss":
			var r2: Array = Pal.BONE
			c.paint(c.mask().ellipse(8.0, 7.0, 5.5, 5.0), r2, 3, true)
			c.paint(c.mask().rect(5, 10, 6, 4), r2, 2)
			c.fill(c.mask().ellipse(6.0, 7.0, 1.4, 1.6), Pal.INK)
			c.fill(c.mask().ellipse(10.0, 7.0, 1.4, 1.6), Pal.INK)
			c.lit(6, 7, Pal.BLOOD[3] if n == "boss" else Pal.SOUL[4])
			c.lit(10, 7, Pal.BLOOD[3] if n == "boss" else Pal.SOUL[4])
			c.put(6, 12, Pal.INK)
			c.put(8, 12, Pal.INK)
			c.put(10, 12, Pal.INK)
			if n == "boss":
				c.paint(c.mask().poly(V([[2, 4], [1, 0], [4, 3]])), Pal.BONE, 3)
				c.paint(c.mask().poly(V([[14, 4], [15, 0], [12, 3]])), Pal.BONE, 3)
		"chest":
			c.paint(c.mask().rect(2, 7, 12, 7), Pal.WOOD, 2, true)
			c.paint(c.mask().rect(2, 4, 12, 4), Pal.WOOD, 3, true)
			c.paint(c.mask().rect(7, 6, 2, 3), Pal.GOLD, 3)
		"shrine":
			c.paint(c.mask().rect(5, 5, 6, 9), Pal.STONE, 3, true)
			c.paint(c.mask().ellipse(8.0, 4.0, 3.0, 3.0), Pal.STONE, 3)
			c.lit(7, 4, Pal.GLOAM[5])
			c.lit(9, 4, Pal.GLOAM[5])
		"merchant":
			c.paint(c.mask().ellipse(8.0, 9.0, 5.0, 5.0), Pal.GOLD, 3, true)
			c.line(8, 5, 8, 13, Pal.GOLD[1])
			c.line(6, 7, 10, 7, Pal.GOLD[1])
			c.line(6, 11, 10, 11, Pal.GOLD[1])
		"stairs":
			for k in 4:
				c.rect(2 + k * 3, 3 + k * 3, 12 - k * 3, 3, Pal.ramp(Pal.STONE, 4 - k))
			c.lit(13, 13, Pal.SOUL[4])
		"relic":
			c.paint(c.mask().poly(V([[8, 1], [13, 8], [8, 15], [3, 8]])), Pal.GOLD, 3, true)
			c.lit(8, 6, Pal.WHITE)
			c.lit(7, 7, Pal.GOLD[4])
		"embers", "ember":
			for p in [Vector2(5, 9), Vector2(10, 7), Vector2(8, 12)]:
				c.fill_lit(c.mask().poly(V([[p.x, p.y - 3], [p.x + 2.5, p.y], [p.x, p.y + 3], [p.x - 2.5, p.y]])), Pal.EMBER[3])
				c.lit(int(p.x), int(p.y) - 1, Pal.EMBER[5])
		"memory", "xp":
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 5.0, 5.0), Pal.SOUL[2])
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 3.0, 3.0), Pal.SOUL[4])
			c.lit(7, 7, Pal.SOUL[5])
		"flask":
			c.paint(c.mask().ellipse(8.0, 10.0, 5.0, 4.5), Pal.STEEL, 3, true)
			c.fill_lit(c.mask().ellipse(8.0, 10.5, 3.6, 3.0), Pal.EMBER[3])
			c.paint(c.mask().rect(6, 2, 4, 5), Pal.STEEL, 3)
			c.lit(7, 10, Pal.EMBER[5])
		"lock":
			var m := c.mask().ellipse(8.0, 6.0, 4.0, 4.0)
			m.subtract(c.mask().ellipse(8.0, 6.0, 2.0, 2.0))
			c.paint(m, Pal.STEEL, 3)
			c.paint(c.mask().rect(3, 7, 10, 7), Pal.STEEL, 2, true)
			c.put(8, 10, Pal.INK)
		"eye":
			c.paint(c.mask().ellipse(8.0, 8.0, 6.5, 3.5), Pal.BONE, 3, true)
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 2.4, 2.4), Pal.GLOAM[4])
			c.put(8, 8, Pal.INK)
		"star":
			c.fill_lit(c.mask().poly(V([[8, 1], [10, 6], [15, 6], [11, 9], [13, 15], [8, 11], [3, 15], [5, 9], [1, 6], [6, 6]])), Pal.GOLD[3])
			c.lit(8, 7, Pal.WHITE)
		"key":
			c.paint(c.mask().ellipse(5.0, 5.0, 3.0, 3.0), Pal.GOLD, 3)
			c.line(6, 6, 13, 13, Pal.GOLD[3])
			c.line(11, 13, 12, 12, Pal.GOLD[3])
			c.put(5, 5, Pal.INK)
		_:
			c.paint(c.mask().ellipse(8.0, 8.0, 5.0, 5.0), Pal.STONE, 3)
	c.outline(Pal.INK)
	return c


static func _flame(c: Px, cx: float, base_y: float, w: float, h: float, r: Array) -> void:
	var outer := c.mask().ellipse(cx, base_y - h * 0.38, w, h * 0.42)
	outer.poly(V([[cx - w * 0.7, base_y - h * 0.45], [cx + 0.5, base_y - h], [cx + w * 0.7, base_y - h * 0.45]]))
	c.fill_lit(outer, r[2])
	c.fill_lit(c.mask().ellipse(cx, base_y - h * 0.32, w * 0.65, h * 0.3), r[3])
	c.fill_lit(c.mask().ellipse(cx, base_y - h * 0.25, w * 0.32, h * 0.16), r[5])
