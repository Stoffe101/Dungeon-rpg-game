## Icons for gear and materials: one 16x16 atlas (items.png + items.json),
## same layout as the main icon atlas. Gear icons are archetypes (hood, helm,
## plate, gauntlets, boots, ring...) drawn in each item's own colours, so tier
## sets read as matched suits and uniques stand out.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://src/render/pal.gd")

## name -> [archetype, main ramp, accent ramp, glowing gem?]
const GEAR := {
	"hood": ["hood", "EARTH", "EMBER", false], "helm": ["helm", "STEEL", "STEEL", false], "circlet": ["circlet", "STEEL", "SOUL", true],
	"cowl": ["hood", "MOSS", "WOOD", false], "lampcap": ["lampcap", "WOOD", "EMBER", true], "plague_mask": ["mask", "BONE", "EARTH", false],
	"horned": ["horned", "STEEL", "BONE", false], "fools_cap": ["fools", "BLOOD", "GOLD", false], "bloom_crown": ["crown", "BLOOD", "EMBER", true],
	"robe": ["robe", "EARTH", "GOLD", false], "mail": ["mail", "STEEL", "STEEL", false], "coat": ["coat", "FROST", "GOLD", false],
	"cloak": ["cloak", "CLOAK", "EMBER", false], "vestments": ["robe", "BONE", "GOLD", false], "scale": ["plate", "MOSS", "STEEL", false],
	"gauntlets": ["gauntlets", "BONE", "STEEL", false], "gloves": ["gloves", "BLOOD", "EMBER", true], "wraps": ["wraps", "BONE", "BONE", false],
	"duelist": ["gloves", "EARTH", "GOLD", false], "haste_mitts": ["wraps", "FROST", "SOUL", false], "bracers": ["bracers", "GLOAM", "SOUL", true],
	"boots": ["boots", "WOOD", "WOOD", false], "greaves": ["greaves", "STEEL", "STEEL", false], "treads": ["boots", "GLOAM", "GLOAM", true],
	"sandals": ["sandals", "WOOD", "EARTH", false], "waders": ["boots", "MOSS", "EARTH", false], "slippers": ["sandals", "GLOAM", "GOLD", false],
	"band": ["ring", "GOLD", "EMBER", true], "signet": ["signet", "STEEL", "FROST", true], "loop": ["ring", "WOOD", "EMBER", true],
	"clover_ring": ["ring", "GOLD", "MOSS", true], "thorn_ring": ["thorn_ring", "WOOD", "BLOOD", false], "focus_band": ["signet", "SOUL", "SOUL", true],
	"totem": ["totem", "BONE", "BLOOD", false], "locket": ["locket", "GOLD", "MOSS", true], "rabbit_foot": ["foot", "BONE", "EARTH", false],
	"hourglass_charm": ["hourglass", "GOLD", "SOUL", true], "idol": ["idol", "STONE", "SOUL", true], "brooch": ["brooch", "GOLD", "EMBER", true],
	"lantern_charm": ["lantern", "STEEL", "SOUL", true],
	# --- tier sets: matched suits with a glowing gem ---
	"ew_helm": ["helm", "GOLD", "EMBER", true], "ew_plate": ["plate", "GOLD", "BLOOD", true], "ew_gauntlets": ["gauntlets", "GOLD", "EMBER", true],
	"ew_greaves": ["greaves", "GOLD", "EMBER", true], "ew_signet": ["signet", "GOLD", "EMBER", true],
	"rg_helm": ["helm", "FROST", "STEEL", true], "rg_mail": ["plate", "FROST", "STEEL", true], "rg_gauntlets": ["gauntlets", "FROST", "STEEL", true],
	"rg_boots": ["greaves", "FROST", "STEEL", true], "rg_band": ["ring", "FROST", "SOUL", true],
	"gw_hood": ["hood", "GLOAM", "GLOAM", true], "gw_cloak": ["cloak", "GLOAM", "GLOAM", true], "gw_wraps": ["wraps", "GLOAM", "GLOAM", true],
	"gw_treads": ["boots", "GLOAM", "GLOAM", true], "gw_locket": ["locket", "GLOAM", "GLOAM", true],
	"vd_cowl": ["hood", "MOSS", "BONE", true], "vd_robe": ["robe", "MOSS", "BONE", true], "vd_gloves": ["gloves", "MOSS", "BONE", true],
	"vd_boots": ["boots", "MOSS", "BONE", true], "vd_totem": ["totem", "MOSS", "BONE", true],
	# --- uniques ---
	"coin": ["coin", "GOLD", "GOLD", true], "league_boots": ["boots", "GOLD", "EMBER", true], "clogs": ["clogs", "WOOD", "BLOOD", false],
	"mountain_plate": ["plate", "STONE", "GOLD", true], "spell_circlet": ["circlet", "GLOAM", "GLOAM", true], "echo_gauntlets": ["gauntlets", "SOUL", "SOUL", true],
	"last_ember": ["ring", "EMBER", "EMBER", true], "avarice_lantern": ["lantern", "GOLD", "EMBER", true], "storm_signet": ["signet", "FROST", "SOUL", true],
	"vamp_ring": ["ring", "BLOOD", "BLOOD", true], "feather_hood": ["feather_hood", "BONE", "FROST", false], "berserk_mantle": ["cloak", "BLOOD", "STEEL", true],
	"battery": ["battery", "STEEL", "EMBER", true], "sunfall_mantle": ["cloak", "GOLD", "EMBER", true],
	"ember_crown": ["crown", "GOLD", "EMBER", true], "moth_cloak": ["cloak", "GLOAM", "GOLD", true], "thornmail": ["plate", "WOOD", "MOSS", false],
	"firebrand": ["gauntlets", "EMBER", "GOLD", true], "mirror_bracers": ["bracers", "STEEL", "FROST", true], "still_sandals": ["sandals", "SOUL", "GOLD", true],
	"exec_ring": ["signet", "BLOOD", "STEEL", true], "clover4": ["ring", "MOSS", "GOLD", true], "grudge_locket": ["locket", "BLOOD", "BONE", true],
	"flask_charm": ["battery", "BLOOD", "EMBER", true], "glass_lantern": ["lantern", "FROST", "EMBER", true],
}

const OTHER := ["bone_dust", "grave_iron", "soul_glass", "rootwood", "spore_silk", "sun_gold", "ember_core", "warden_sigil",
	"bloom_heart", "eclipse_shard", "bag", "anvil", "scroll",
	"rune_split", "rune_chain", "rune_echo", "rune_rime", "rune_gloam", "rune_volatile", "rune_siphon", "rune_gravity", "rune_haste", "rune_might"]

## Ember Runes: a worn stone with a glyph burning in the rune's colour.
const RUNE_GLYPHS := {
	"rune_split": ["GOLD", [[8, 12], [8, 8], [8, 8], [5, 4], [8, 8], [11, 4], [8, 8], [8, 4]]],
	"rune_chain": ["FROST", [[5, 4], [9, 7], [6, 9], [11, 12]]],
	"rune_echo": ["SOUL", [[5, 5], [5, 11], [8, 4], [8, 12], [11, 5], [11, 11]]],
	"rune_rime": ["FROST", [[8, 3], [8, 13], [4, 8], [12, 8], [5, 5], [11, 11], [11, 5], [5, 11]]],
	"rune_gloam": ["GLOAM", [[4, 8], [8, 5], [8, 5], [12, 8], [12, 8], [8, 11], [8, 11], [4, 8]]],
	"rune_volatile": ["EMBER", [[8, 3], [8, 13], [3, 8], [13, 8], [5, 5], [11, 11]]],
	"rune_siphon": ["BLOOD", [[8, 3], [5, 9], [5, 9], [8, 12], [8, 12], [11, 9], [11, 9], [8, 3]]],
	"rune_gravity": ["SOUL", [[8, 4], [12, 8], [12, 8], [8, 12], [8, 12], [5, 8], [5, 8], [8, 6]]],
	"rune_haste": ["GOLD", [[4, 5], [8, 8], [8, 8], [4, 11], [8, 5], [12, 8], [12, 8], [8, 11]]],
	"rune_might": ["BLOOD", [[8, 3], [12, 12], [12, 12], [4, 12], [4, 12], [8, 3]]],
}


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func ramp(key: String) -> Array:
	match key:
		"EARTH":
			return Pal.EARTH
		"STEEL":
			return Pal.STEEL
		"GOLD":
			return Pal.GOLD
		"BLOOD":
			return Pal.BLOOD
		"FROST":
			return Pal.FROST
		"GLOAM":
			return Pal.GLOAM
		"MOSS":
			return Pal.MOSS
		"BONE":
			return Pal.BONE
		"SOUL":
			return Pal.SOUL
		"EMBER":
			return Pal.EMBER
		"WOOD":
			return Pal.WOOD
		"STONE":
			return Pal.STONE
		"CLOAK":
			return Pal.CLOAK
	return Pal.STONE


static func build(dir: String) -> void:
	var names: Array = GEAR.keys() + OTHER
	var cols := 10
	var rows := int(ceil(names.size() / float(cols)))
	var atlas := Px.new(cols * 16, rows * 16)
	var meta := {}
	for i in names.size():
		var n: String = names[i]
		var c: Px
		if GEAR.has(n):
			var g: Array = GEAR[n]
			c = gear(String(g[0]), ramp(g[1]), ramp(g[2]), bool(g[3]))
		else:
			c = other(n)
		atlas.blit(c, (i % cols) * 16, (i / cols) * 16)
		meta[n] = [i % cols, i / cols]
	atlas.save(dir.path_join("items.png"))
	var f := FileAccess.open(ProjectSettings.globalize_path(dir.path_join("items.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cell": 16, "icons": meta}, "\t"))
	f.close()


## A gear archetype in a main ramp `r` with accent ramp `a`; `gem` adds a glowing stone.
static func gear(arch: String, r: Array, a: Array, gem: bool) -> Px:
	var c := Px.new(16, 16)
	var gem_at := Vector2i(-1, -1)
	match arch:
		"hood", "feather_hood":
			var m := c.mask().ellipse(8.0, 8.0, 6.0, 6.0)
			m.poly(V([[2, 9], [14, 9], [15, 15], [1, 15]]))
			c.paint(m, r, 2, true)
			c.fill(c.mask().ellipse(8.0, 9.5, 3.4, 3.6), Pal.INK)
			c.put(6, 9, Pal.EMBER[4])
			c.put(10, 9, Pal.EMBER[4])
			c.line(2, 14, 14, 14, a[2])
			if arch == "feather_hood":
				c.line(11, 1, 15, 6, a[4])
				c.line(12, 1, 15, 4, a[3])
			gem_at = Vector2i(8, 3)
		"helm":
			var m := c.mask().ellipse(8.0, 8.0, 6.0, 6.0)
			m.rect(2, 8, 12, 6)
			c.paint(m, r, 3, true)
			c.fill(c.mask().rect(4, 8, 8, 2), Pal.INK)
			c.fill(c.mask().rect(7, 10, 2, 3), Pal.INK)
			c.line(8, 1, 8, 6, a[4])
			c.line(2, 13, 13, 13, a[2])
			gem_at = Vector2i(8, 5)
		"horned":
			var m := c.mask().ellipse(8.0, 9.0, 5.5, 5.5)
			m.rect(3, 9, 10, 5)
			c.paint(m, r, 3, true)
			c.paint(c.mask().poly(V([[3, 6], [0, 1], [5, 5]])).poly(V([[13, 6], [16, 1], [11, 5]])), a, 3)
			c.fill(c.mask().rect(5, 9, 6, 2), Pal.INK)
		"circlet":
			var m := c.mask().ellipse(8.0, 9.0, 6.5, 3.5)
			m.subtract(c.mask().ellipse(8.0, 9.0, 5.0, 2.0))
			c.paint(m, r, 4, true)
			c.fill_lit(c.mask().poly(V([[8, 3], [10, 6], [8, 9], [6, 6]])), a[4])
			c.lit(8, 5, a[5] if a.size() > 5 else Pal.WHITE)
		"crown":
			c.paint(c.mask().poly(V([[2, 13], [2, 6], [5, 9], [8, 3], [11, 9], [14, 6], [14, 13]])), r, 3, true)
			for p in [[4, 8], [8, 5], [12, 8]]:
				c.lit(p[0], p[1], a[4])
			c.fill_lit(c.mask().ellipse(8.0, 11.0, 2.0, 1.5), a[3])
		"mask":
			c.paint(c.mask().ellipse(8.0, 7.0, 5.0, 5.5), r, 3, true)
			c.paint(c.mask().poly(V([[6, 9], [10, 9], [8, 15]])), r, 2, true)
			c.fill(c.mask().ellipse(5.5, 6.0, 1.4, 1.4), Pal.INK)
			c.fill(c.mask().ellipse(10.5, 6.0, 1.4, 1.4), Pal.INK)
			c.lit(5, 6, Pal.EMBER[3])
			c.lit(10, 6, Pal.EMBER[3])
			c.line(3, 3, 13, 3, a[2])
		"lampcap":
			var m := c.mask().ellipse(8.0, 10.0, 6.0, 4.5)
			m.rect(1, 11, 14, 2)
			c.paint(m, r, 3, true)
			c.paint(c.mask().rect(6, 5, 4, 4), Pal.STEEL, 2)
			gem_at = Vector2i(8, 6)
		"fools":
			var m := c.mask().rect(3, 9, 10, 5)
			m.poly(V([[3, 10], [1, 2], [7, 9]])).poly(V([[13, 10], [15, 2], [9, 9]])).poly(V([[6, 9], [8, 1], [10, 9]]))
			c.paint(m, r, 3, true)
			for p in [[1, 2], [8, 1], [15, 2]]:
				c.paint(c.mask().ellipse(p[0] + 0.5, p[1] + 0.5, 1.5, 1.5), a, 4)
		"robe", "coat":
			var m := c.mask().poly(V([[4, 2], [12, 2], [15, 7], [13, 8], [12, 6], [13, 15], [3, 15], [4, 6], [3, 8], [1, 7]]))
			c.paint(m, r, 2, true)
			c.line(8, 3, 8, 14, r[1])
			c.line(5, 8, 11, 8, a[3])
			if arch == "coat":
				for y in [5, 9, 12]:
					c.put(9, y, a[3])
			gem_at = Vector2i(8, 5)
		"cloak":
			var m := c.mask().poly(V([[5, 1], [11, 1], [15, 15], [1, 15]]))
			c.paint(m, r, 2, true)
			c.fill(c.mask().poly(V([[7, 2], [9, 2], [10, 15], [6, 15]])), r[1])
			c.paint(c.mask().rect(4, 1, 8, 2), a, 3)
			gem_at = Vector2i(8, 2)
		"mail":
			var m := c.mask().poly(V([[4, 2], [12, 2], [15, 6], [13, 7], [12, 6], [12, 14], [4, 14], [4, 6], [3, 7], [1, 6]]))
			c.paint(m, r, 3, true)
			for y in range(4, 14, 2):
				for x in range(5, 12, 2):
					c.put(x + (y / 2) % 2, y, r[1])
		"plate":
			var m := c.mask().poly(V([[3, 3], [13, 3], [14, 8], [12, 15], [4, 15], [2, 8]]))
			c.paint(m, r, 3, true)
			c.paint(c.mask().ellipse(2.5, 4.5, 2.5, 2.2).ellipse(13.5, 4.5, 2.5, 2.2), a, 3, true)
			c.line(8, 4, 8, 14, r[1])
			c.line(4, 10, 12, 10, a[2])
			gem_at = Vector2i(8, 7)
		"gauntlets", "gloves", "wraps", "bracers":
			var m := c.mask().rect(4, 7, 8, 7)
			m.rect(4, 3, 2, 5).rect(6, 2, 2, 5).rect(8, 2, 2, 5).rect(10, 3, 2, 5)
			m.poly(V([[12, 9], [15, 7], [15, 9], [12, 12]]))
			c.paint(m, r, 3 if arch != "gloves" else 2, true)
			match arch:
				"gauntlets":
					c.paint(c.mask().rect(3, 12, 10, 3), a, 3)
				"wraps":
					for y in [4, 7, 10, 13]:
						c.line(4, y, 11, y - 1, r[1])
				"bracers":
					c.paint(c.mask().rect(3, 10, 10, 5), a, 2, true)
			gem_at = Vector2i(8, 10)
		"boots", "greaves", "clogs":
			var m := c.mask().rect(5, 2, 5, 9)
			m.poly(V([[5, 10], [10, 10], [15, 12], [15, 15], [4, 15]]))
			if arch == "clogs":
				m = c.mask().rect(5, 6, 6, 5)
				m.poly(V([[4, 10], [11, 10], [15, 12], [15, 15], [3, 15]]))
			c.paint(m, r, 3, true)
			c.line(4, 14, 15, 14, r[0])
			if arch == "greaves":
				c.paint(c.mask().rect(4, 4, 7, 2), a, 4)
			if arch == "clogs":
				c.put(13, 12, a[3])
				c.put(1, 9, Pal.WHITE)
				c.put(2, 8, Pal.WHITE)
			gem_at = Vector2i(7, 6)
		"sandals":
			c.paint(c.mask().poly(V([[3, 12], [14, 12], [15, 15], [2, 15]])), r, 3, true)
			c.line(5, 12, 8, 6, a[3])
			c.line(10, 12, 8, 6, a[3])
			c.line(4, 9, 12, 9, a[2])
		"ring", "signet", "thorn_ring":
			var m := c.mask().ellipse(8.0, 10.0, 5.5, 4.5)
			m.subtract(c.mask().ellipse(8.0, 10.0, 3.5, 2.5))
			c.paint(m, r, 3, true)
			if arch == "signet":
				c.paint(c.mask().rect(5, 3, 6, 4), r, 4)
				gem_at = Vector2i(8, 5)
			elif arch == "thorn_ring":
				for p in [[3, 7], [13, 7], [8, 4], [3, 13], [13, 13]]:
					c.put(p[0], p[1], a[3])
			else:
				gem_at = Vector2i(8, 5)
		"totem":
			c.paint(c.mask().ellipse(8.0, 6.0, 4.0, 4.5), r, 3, true)
			c.fill(c.mask().ellipse(6.5, 6.0, 1.0, 1.2), Pal.INK)
			c.fill(c.mask().ellipse(9.5, 6.0, 1.0, 1.2), Pal.INK)
			c.paint(c.mask().rect(7, 10, 2, 5), Pal.WOOD, 2)
			c.line(4, 12, 12, 12, a[3])
		"locket":
			c.line(4, 1, 8, 6, Pal.GOLD[3])
			c.line(12, 1, 8, 6, Pal.GOLD[3])
			c.paint(c.mask().ellipse(8.0, 10.0, 4.5, 4.5), r, 3, true)
			gem_at = Vector2i(8, 10)
		"lantern":
			c.paint(c.mask().rect(4, 4, 8, 10), r, 2)
			c.fill_lit(c.mask().rect(5, 5, 6, 8), a[3])
			c.fill_lit(c.mask().ellipse(8.0, 9.0, 1.8, 2.6), a[5] if a.size() > 5 else a[4])
			c.line(6, 1, 10, 1, r[3])
			c.line(6, 1, 4, 4, r[3])
			c.line(10, 1, 12, 4, r[3])
		"foot":
			c.paint(c.mask().ellipse(8.0, 9.0, 3.5, 5.5), r, 3, true)
			c.paint(c.mask().rect(6, 2, 4, 3), Pal.GOLD, 3)
			c.line(8, 1, 8, 0, Pal.GOLD[2])
		"hourglass":
			c.paint(c.mask().rect(3, 1, 10, 2).rect(3, 13, 10, 2), r, 3)
			c.fill_lit(c.mask().poly(V([[4, 3], [12, 3], [8, 8]])), a[3])
			c.fill_lit(c.mask().poly(V([[8, 8], [12, 13], [4, 13]])), a[4])
		"idol":
			c.paint(c.mask().poly(V([[5, 15], [5, 6], [8, 2], [11, 6], [11, 15]])), r, 3, true)
			c.fill(c.mask().rect(6, 6, 4, 1), Pal.INK)
			gem_at = Vector2i(8, 9)
		"brooch":
			for k in 8:
				var ang := k * TAU / 8.0
				c.line(8, 8, int(round(8 + cos(ang) * 6)), int(round(8 + sin(ang) * 6)), r[3])
			c.paint(c.mask().ellipse(8.0, 8.0, 3.5, 3.5), r, 3, true)
			gem_at = Vector2i(8, 8)
		"coin":
			c.paint(c.mask().ellipse(8.0, 8.0, 6.0, 6.0), r, 3, true)
			c.paint(c.mask().ellipse(8.0, 8.0, 4.0, 4.0), r, 2)
			c.line(8, 5, 8, 11, r[4])
			c.line(6, 6, 10, 6, r[4])
			c.line(6, 10, 10, 10, r[4])
			c.lit(4, 4, Pal.WHITE)
		"battery":
			c.paint(c.mask().rect(4, 3, 8, 12), r, 2, true)
			c.paint(c.mask().rect(6, 1, 4, 2), r, 4)
			c.fill_lit(c.mask().rect(5, 7, 6, 7), a[3])
			c.fill_lit(c.mask().rect(5, 9, 6, 5), a[4])
	if gem and gem_at.x >= 0:
		c.lit(gem_at.x, gem_at.y, a[4] if a.size() > 4 else a[3])
		c.lit(gem_at.x - 1, gem_at.y, a[3])
	c.outline(Pal.INK)
	return c


static func other(n: String) -> Px:
	var c := Px.new(16, 16)
	if RUNE_GLYPHS.has(n):
		var g: Array = RUNE_GLYPHS[n]
		var stone := c.mask().ellipse(8.0, 8.5, 6.5, 7.0)
		c.paint(stone, Pal.STONE, 2, true)
		var col: Array = ramp(String(g[0]))
		var pts: Array = g[1]
		var i := 0
		while i + 1 < pts.size():
			var a: Array = pts[i]
			var b: Array = pts[i + 1]
			var m := c.mask().line(a[0], a[1], b[0], b[1])
			c.fill_lit(m, col[4])
			i += 2
		c.lit(8, 8, col[col.size() - 1])
		c.outline(Pal.INK)
		return c
	match n:
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
		"sun_gold":
			var m := c.mask().poly(V([[2, 9], [10, 6], [14, 8], [6, 12]]))
			m.poly(V([[2, 9], [6, 12], [6, 14], [2, 11]])).poly(V([[6, 12], [14, 8], [14, 10], [6, 14]]))
			c.paint(m, Pal.GOLD, 3, true)
			c.lit(9, 7, Pal.WHITE)
			c.lit(4, 9, Pal.GOLD[4])
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
		"eclipse_shard":
			c.fill(c.mask().ellipse(8.0, 8.0, 6.0, 6.0), Pal.INK)
			var rim := c.mask().ellipse(8.0, 8.0, 6.5, 6.5)
			rim.subtract(c.mask().ellipse(9.0, 7.0, 5.5, 5.5))
			c.fill_lit(rim, Pal.EMBER[4])
			c.lit(3, 11, Pal.WHITE)
		"bag":
			c.paint(c.mask().ellipse(8.0, 10.0, 6.0, 5.0), Pal.EARTH, 3, true)
			c.paint(c.mask().rect(5, 3, 6, 3), Pal.EARTH, 2)
			c.line(5, 6, 11, 6, Pal.GOLD[3])
		"anvil":
			c.paint(c.mask().poly(V([[1, 4], [13, 4], [15, 6], [11, 8], [11, 11], [13, 14], [3, 14], [5, 11], [5, 8], [2, 7]])), Pal.STEEL, 2, true)
			c.line(2, 4, 13, 4, Pal.STEEL[4])
			c.lit(9, 2, Pal.EMBER[4])
			c.lit(11, 1, Pal.EMBER[3])
		"scroll":
			c.paint(c.mask().rect(3, 3, 10, 10), Pal.BONE, 3, true)
			c.paint(c.mask().rect(2, 2, 12, 2).rect(2, 12, 12, 2), Pal.WOOD, 3)
			for y in [6, 8, 10]:
				c.line(5, y, 11, y, Pal.SOUL[2])
			c.lit(11, 5, Pal.GOLD[4])
	c.outline(Pal.INK)
	return c
