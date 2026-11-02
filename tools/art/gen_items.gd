## Icons for gear and materials: one 16x16 atlas (items.png + items.json),
## same layout as the main icon atlas.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")

const NAMES := [
	"hood", "helm", "circlet", "cowl", "bloom_crown",
	"robe", "mail", "coat",
	"gauntlets", "gloves", "wraps",
	"boots", "greaves", "treads",
	"band", "signet", "loop",
	"totem", "locket", "lantern_charm",
	"bone_dust", "grave_iron", "soul_glass", "rootwood", "spore_silk", "ember_core", "warden_sigil", "bloom_heart",
	"bag", "anvil",
]


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
		atlas.blit(draw(NAMES[i]), (i % cols) * 16, (i / cols) * 16)
		meta[NAMES[i]] = [i % cols, i / cols]
	atlas.save(dir.path_join("items.png"))
	var f := FileAccess.open(ProjectSettings.globalize_path(dir.path_join("items.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cell": 16, "icons": meta}, "\t"))
	f.close()


static func draw(n: String) -> Px:
	var c := Px.new(16, 16)
	match n:
		# --- head ---
		"hood", "cowl":
			var r: Array = Pal.EARTH if n == "hood" else Pal.MOSS
			var m := c.mask().ellipse(8.0, 8.0, 6.0, 6.0)
			m.poly(V([[2, 9], [14, 9], [15, 15], [1, 15]]))
			c.paint(m, r, 2, true)
			c.fill(c.mask().ellipse(8.0, 9.5, 3.4, 3.6), Pal.INK)
			c.put(6, 9, Pal.EMBER[4])
			c.put(10, 9, Pal.EMBER[4])
			if n == "cowl":
				c.line(2, 5, 5, 2, Pal.WOOD[3])
				c.line(14, 5, 11, 2, Pal.WOOD[3])
		"helm":
			var m := c.mask().ellipse(8.0, 8.0, 6.0, 6.0)
			m.rect(2, 8, 12, 6)
			c.paint(m, Pal.STEEL, 3, true)
			c.fill(c.mask().rect(4, 8, 8, 2), Pal.INK)
			c.fill(c.mask().rect(7, 10, 2, 3), Pal.INK)
			c.line(8, 1, 8, 6, Pal.STEEL[5])
		"circlet":
			var m := c.mask().ellipse(8.0, 9.0, 6.5, 3.5)
			m.subtract(c.mask().ellipse(8.0, 9.0, 5.0, 2.0))
			c.paint(m, Pal.STEEL, 4, true)
			c.fill_lit(c.mask().poly(V([[8, 3], [10, 6], [8, 9], [6, 6]])), Pal.SOUL[4])
			c.lit(8, 5, Pal.SOUL[5])
		"bloom_crown":
			c.paint(c.mask().poly(V([[2, 13], [2, 6], [5, 9], [8, 3], [11, 9], [14, 6], [14, 13]])), Pal.BLOOD, 3, true)
			for p in [[4, 8], [8, 5], [12, 8]]:
				c.lit(p[0], p[1], Pal.EMBER[4])
			c.fill_lit(c.mask().ellipse(8.0, 11.0, 2.0, 1.5), Pal.EMBER[3])
		# --- chest ---
		"robe", "coat":
			var r: Array = Pal.EARTH if n == "robe" else Pal.FROST
			var m := c.mask().poly(V([[4, 2], [12, 2], [15, 7], [13, 8], [12, 6], [13, 15], [3, 15], [4, 6], [3, 8], [1, 7]]))
			c.paint(m, r, 2, true)
			c.line(8, 3, 8, 14, r[1])
			c.line(5, 8, 11, 8, Pal.GOLD[3] if n == "robe" else Pal.STEEL[4])
			if n == "coat":
				for y in [5, 9, 12]:
					c.put(9, y, Pal.GOLD[3])
		"mail":
			var m := c.mask().poly(V([[4, 2], [12, 2], [15, 6], [13, 7], [12, 6], [12, 14], [4, 14], [4, 6], [3, 7], [1, 6]]))
			c.paint(m, Pal.STEEL, 3, true)
			for y in range(4, 14, 2):
				for x in range(5, 12, 2):
					c.put(x + (y / 2) % 2, y, Pal.STEEL[1])
		# --- hands ---
		"gauntlets", "gloves", "wraps":
			var r: Array = Pal.BONE if n == "gauntlets" else (Pal.BLOOD if n == "gloves" else Pal.BONE)
			var m := c.mask().rect(4, 7, 8, 7)
			m.rect(4, 3, 2, 5).rect(6, 2, 2, 5).rect(8, 2, 2, 5).rect(10, 3, 2, 5)
			m.poly(V([[12, 9], [15, 7], [15, 9], [12, 12]]))
			c.paint(m, r, 3 if n != "gloves" else 2, true)
			if n == "gauntlets":
				c.paint(c.mask().rect(3, 12, 10, 3), Pal.STEEL, 3)
			elif n == "gloves":
				c.lit(7, 9, Pal.EMBER[4])
				c.lit(8, 10, Pal.EMBER[3])
			else:
				for y in [4, 7, 10, 13]:
					c.line(4, y, 11, y - 1, Pal.BONE[1])
		# --- feet ---
		"boots", "greaves", "treads":
			var r: Array = Pal.WOOD if n == "boots" else (Pal.STEEL if n == "greaves" else Pal.GLOAM)
			var m := c.mask().rect(5, 2, 5, 9)
			m.poly(V([[5, 10], [10, 10], [15, 12], [15, 15], [4, 15]]))
			c.paint(m, r, 3, true)
			c.line(4, 14, 15, 14, r[0])
			if n == "greaves":
				c.paint(c.mask().rect(4, 4, 7, 2), Pal.STEEL, 4)
			elif n == "treads":
				c.lit(7, 6, Pal.GLOAM[5])
				c.line(1, 8, 4, 11, Pal.GLOAM[4])
		# --- rings ---
		"band", "signet", "loop":
			var r: Array = Pal.GOLD if n == "band" else (Pal.STEEL if n == "signet" else Pal.WOOD)
			var m := c.mask().ellipse(8.0, 10.0, 5.5, 4.5)
			m.subtract(c.mask().ellipse(8.0, 10.0, 3.5, 2.5))
			c.paint(m, r, 3, true)
			match n:
				"band":
					c.fill_lit(c.mask().ellipse(8.0, 5.0, 2.0, 2.0), Pal.EMBER[3])
					c.lit(7, 4, Pal.EMBER[5])
				"signet":
					c.paint(c.mask().rect(5, 3, 6, 4), Pal.STEEL, 4)
					c.fill_lit(c.mask().rect(7, 4, 2, 2), Pal.FROST[4])
				"loop":
					c.lit(8, 5, Pal.EMBER[4])
					c.lit(8, 4, Pal.EMBER[5])
					c.line(8, 6, 8, 7, Pal.BONE[3])
		# --- charms ---
		"totem":
			c.paint(c.mask().ellipse(8.0, 6.0, 4.0, 4.5), Pal.BONE, 3, true)
			c.fill(c.mask().ellipse(6.5, 6.0, 1.0, 1.2), Pal.INK)
			c.fill(c.mask().ellipse(9.5, 6.0, 1.0, 1.2), Pal.INK)
			c.paint(c.mask().rect(7, 10, 2, 5), Pal.WOOD, 2)
			c.line(4, 12, 12, 12, Pal.BLOOD[3])
		"locket":
			c.line(4, 1, 8, 6, Pal.GOLD[3])
			c.line(12, 1, 8, 6, Pal.GOLD[3])
			c.paint(c.mask().ellipse(8.0, 10.0, 4.5, 4.5), Pal.GOLD, 3, true)
			c.fill(c.mask().ellipse(8.0, 10.0, 2.5, 2.5), Pal.MOSS[3])
			c.lit(7, 9, Pal.MOSS[5])
		"lantern_charm":
			c.paint(c.mask().rect(4, 4, 8, 10), Pal.STEEL, 2)
			c.fill_lit(c.mask().rect(5, 5, 6, 8), Pal.SOUL[3])
			c.fill_lit(c.mask().ellipse(8.0, 9.0, 1.8, 2.6), Pal.SOUL[5])
			c.line(6, 1, 10, 1, Pal.STEEL[3])
			c.line(6, 1, 4, 4, Pal.STEEL[3])
			c.line(10, 1, 12, 4, Pal.STEEL[3])
		# --- materials ---
		"bone_dust":
			c.paint(c.mask().ellipse(8.0, 11.5, 6.0, 3.5), Pal.BONE, 3, true)
			c.paint(c.mask().ellipse(8.0, 9.0, 3.5, 2.5), Pal.BONE, 3, true)
			for p in [[5, 11], [10, 10], [8, 13], [12, 12]]:
				c.put(p[0], p[1], Pal.BONE[1])
		"grave_iron":
			var m := c.mask().poly(V([[2, 9], [10, 6], [14, 8], [6, 12]]))
			m.poly(V([[2, 9], [6, 12], [6, 14], [2, 11]])).poly(V([[6, 12], [14, 8], [14, 10], [6, 14]]))
			c.paint(m, Pal.STONE, 2, true)
			c.line(3, 9, 10, 7, Pal.STONE[4])
		"soul_glass":
			c.fill_lit(c.mask().poly(V([[8, 1], [12, 6], [10, 15], [6, 15], [4, 6]])), Pal.SOUL[3])
			c.fill_lit(c.mask().poly(V([[8, 2], [10, 6], [8, 13]])), Pal.SOUL[5])
			c.put(6, 5, Pal.WHITE)
		"rootwood":
			c.paint(c.mask().poly(V([[1, 11], [12, 4], [15, 7], [4, 14]])), Pal.WOOD, 2, true)
			c.paint(c.mask().ellipse(13.5, 5.5, 2.0, 2.0), Pal.WOOD, 4)
			c.put(13, 5, Pal.WOOD[1])
			c.line(4, 12, 1, 15, Pal.MOSS[3])
		"spore_silk":
			c.paint(c.mask().ellipse(8.0, 8.0, 5.5, 5.5), Pal.BONE, 4, true)
			for y in range(4, 13, 2):
				c.line(4, y, 12, y + 1, Pal.BONE[2])
			c.lit(11, 3, Pal.MOSS[5])
			c.lit(13, 5, Pal.MOSS[4])
		"ember_core":
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 5.0, 5.0), Pal.EMBER[2])
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 3.2, 3.2), Pal.EMBER[4])
			c.lit(7, 7, Pal.EMBER[5])
			c.lit(8, 7, Pal.WHITE)
		"warden_sigil":
			c.paint(c.mask().ellipse(8.0, 8.0, 6.5, 6.5), Pal.STONE, 2, true)
			c.fill_lit(c.mask().ellipse(8.0, 8.0, 4.0, 4.0), Pal.SOUL[2])
			c.fill(c.mask().ellipse(8.0, 8.0, 2.4, 2.4), Pal.INK)
			c.lit(8, 8, Pal.SOUL[5])
			c.line(8, 1, 8, 3, Pal.SOUL[4])
			c.line(8, 13, 8, 15, Pal.SOUL[4])
		"bloom_heart":
			var m := c.mask().ellipse(5.5, 6.5, 3.5, 3.5)
			m.union(c.mask().ellipse(10.5, 6.5, 3.5, 3.5))
			m.poly(V([[2, 8], [14, 8], [8, 15]]))
			c.paint(m, Pal.BLOOD, 3, true)
			c.lit(5, 5, Pal.BLOOD[4])
			c.line(8, 1, 8, 4, Pal.MOSS[3])
			c.put(9, 2, Pal.MOSS[4])
		# --- misc ---
		"bag":
			c.paint(c.mask().ellipse(8.0, 10.0, 6.0, 5.0), Pal.EARTH, 3, true)
			c.paint(c.mask().rect(5, 3, 6, 3), Pal.EARTH, 2)
			c.line(5, 6, 11, 6, Pal.GOLD[3])
		"anvil":
			c.paint(c.mask().poly(V([[1, 4], [13, 4], [15, 6], [11, 8], [11, 11], [13, 14], [3, 14], [5, 11], [5, 8], [2, 7]])), Pal.STEEL, 2, true)
			c.line(2, 4, 13, 4, Pal.STEEL[4])
			c.lit(9, 2, Pal.EMBER[4])
			c.lit(11, 1, Pal.EMBER[3])
	c.outline(Pal.INK)
	return c
