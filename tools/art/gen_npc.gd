## The people of the Last Hearth, drawn on one shared rig so they match the
## Kindled: 32x32 frames, feet at (16, 30), big readable heads, three-tone
## shading and an ink outline. Front view for idle / talk / sit / work, side
## view (facing right; the game mirrors it) for walking.
##
## A character is a spec dictionary:
##   cloth, cloth2 (legs / undershirt), trim (belt, hems), skin, hair, hat: ramps
##   build: slim | normal | broad | hunched      child: bool     elder: bool
##   outfit: tunic | coat | apron | dress | robe | tabard
##   hair_style: short | long | bun | tousled | bald      beard: none | full | braid | mustache
##   head: none | hood | scarf | cap | brim      face: normal | shadow (dark hood, glowing eyes)
##   shawl: ramp or absent     hold: none | staff_lantern | hammer | basket | pole_lantern | axe | lute | sling | toy
##   back: none | pack | logs      blush: bool
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")

const SKIN_DEEP := [Color8(58, 36, 34), Color8(98, 62, 50), Color8(140, 96, 70), Color8(178, 132, 96)]
const HAIR_DARK := [Color8(18, 14, 20), Color8(34, 26, 32), Color8(54, 40, 46), Color8(80, 62, 64)]
const SHOE := [Color8(11, 10, 18), Color8(40, 24, 22), Color8(70, 42, 32), Color8(104, 66, 44)]

# side-view walk: [near leg dx, near lift, far leg dx, far lift, bob, arm swing]
const WALK := [[3, 0, -3, 0, 0, 2], [1, 0, -1, 1, 1, 1], [-1, 0, 1, 2, 0, -1], [-3, 0, 3, 0, 0, -2], [-1, 1, 1, 0, 1, -1], [1, 2, -1, 0, 0, 1]]


static func V(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func specs() -> Dictionary:
	return {
		"keeper": {"build": "hunched", "elder": true, "outfit": "robe", "cloth": Pal.CLOAK, "trim": Pal.GOLD, "shawl": Pal.EMBER,
			"head": "hood", "hat": Pal.BLOOD, "skin": Pal.SKIN, "hair": Pal.BONE, "hold": "staff_lantern"},
		"smith": {"build": "broad", "outfit": "apron", "cloth": Pal.BLOOD, "cloth2": Pal.EARTH, "trim": Pal.WOOD, "skin": Pal.SKIN,
			"hair": Pal.EMBER, "hair_style": "bald", "beard": "braid", "hold": "hammer", "bare_arms": true},
		"merchant": {"build": "hunched", "outfit": "coat", "cloth": Pal.EARTH, "cloth2": Pal.WOOD, "trim": Pal.GOLD, "skin": Pal.SKIN,
			"head": "hood", "hat": Pal.EARTH, "face": "shadow", "back": "pack", "hold": "lantern"},
		"resident_ama": {"outfit": "dress", "cloth": Pal.MOSS, "trim": Pal.EARTH, "skin": SKIN_DEEP, "hair": HAIR_DARK,
			"hair_style": "long", "head": "scarf", "hat": Pal.GOLD, "apron": Pal.BONE, "hold": "basket"},
		"resident_teodric": {"build": "broad", "elder": true, "outfit": "tabard", "cloth": Pal.STEEL, "cloth2": Pal.STONE, "trim": Pal.BLOOD,
			"skin": Pal.SKIN, "hair": Pal.BONE, "hair_style": "short", "beard": "mustache", "hold": "sling"},
		"resident_wren": {"child": true, "outfit": "tunic", "cloth": Pal.GLOAM, "cloth2": Pal.EARTH, "trim": Pal.GOLD, "skin": Pal.SKIN,
			"hair": Pal.WOOD, "hair_style": "tousled", "scarf": Pal.EMBER, "blush": true, "hold": "toy"},
		"resident_bram": {"build": "slim", "outfit": "coat", "cloth": Pal.FROST, "cloth2": Pal.STONE, "trim": Pal.GOLD, "skin": Pal.SKIN,
			"hair": Pal.EARTH, "hair_style": "short", "head": "brim", "hat": Pal.STONE, "hold": "pole_lantern"},
		"resident_hollis": {"build": "broad", "outfit": "tunic", "cloth": Pal.BLOOD, "cloth2": Pal.EARTH, "trim": Pal.WOOD, "skin": Pal.SKIN,
			"hair": Pal.EMBER, "hair_style": "short", "beard": "full", "head": "cap", "hat": Pal.STONE, "hold": "axe", "back": "logs", "plaid": true},
		"resident_sefa": {"build": "slim", "outfit": "dress", "cloth": Pal.BLOOD, "trim": Pal.GOLD, "skin": SKIN_DEEP, "hair": Pal.STONE,
			"hair_style": "bun", "blush": true, "hold": "lute"},
	}


static func build(dir: String) -> void:
	var all := specs()
	for name in all:
		var sp: Dictionary = all[name]
		var s := Sheet.new(32, 32, Vector2i(16, 30))
		if name == "smith":
			s.add("idle", _frames(sp, "work", 6), 7.0)
		else:
			s.add("idle", _frames(sp, "idle", 8), 5.0)
		s.add("talk", _frames(sp, "talk", 4), 6.0)
		s.add("walk", _frames(sp, "walk", 6), 9.0)
		s.add("sit", _frames(sp, "sit", 6), 4.0)
		s.save(dir, String(name))


static func _frames(sp: Dictionary, anim: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		var p := {"f": i}
		match anim:
			"idle":
				p.bob = [0, 0, 0, 1, 1, 1, 1, 0][i]
				p.blink = i == 5
			"talk":
				p.talk = 1 + i % 2
				p.bob = i % 2
			"walk":
				var w: Array = WALK[i]
				p.view = "side"
				p.step = w
				p.bob = w[4]
				p.arm = w[5]
			"sit":
				p.sit = true
				p.bob = [0, 0, 1, 1, 1, 0][i]
				p.blink = i == 3
			"work":
				p.work = i
				p.bob = [0, 0, 0, 1, 1, 0][i]
		out.append(frame(sp, p))
	return out


static func frame(sp: Dictionary, p: Dictionary) -> Px:
	var c := Px.new(32, 32)
	var side: bool = p.get("view", "front") == "side"
	var child: bool = sp.get("child", false)
	var sit: bool = p.get("sit", false)
	var f: int = p.get("f", 0)
	var build: String = sp.get("build", "normal")
	var hunch := 1 if build == "hunched" else 0
	var hw := 5
	match build:
		"slim":
			hw = 4
		"broad":
			hw = 6
	if child:
		hw = 4
	var bob: int = p.get("bob", 0) + (4 if sit else 0)
	var rx := 4.3 if child else 4.6
	var ry := 4.5 if child else 5.0
	var cx := 16.0 + (0.5 if side else 0.0) + (1.0 if side and hunch > 0 else 0.0)
	var cy := (15.0 if child else 10.5) + bob + hunch
	var ty := (19 if child else 15) + bob + hunch
	var outfit: String = sp.get("outfit", "tunic")
	var long_skirt := outfit in ["robe", "dress"]
	var hem := (26 if child else 25) + (2 if sit else 0)
	var bottom := 28 if long_skirt else hem
	var cloth: Array = sp.cloth
	var cloth2: Array = sp.get("cloth2", Pal.EARTH)
	var trim: Array = sp.get("trim", Pal.EARTH)
	var skin: Array = sp.get("skin", Pal.SKIN)
	var work: int = p.get("work", -1)
	var talk: int = p.get("talk", 0)
	var sw := hw - 1   # half width seen from the side

	# --- behind the body: back items, far arm ----------------------------------------
	_back_item(c, sp, side, ty, hw)
	if side:
		var swing: int = p.get("arm", 0)
		var far := c.mask().line(15, ty + 1, 15 - swing, ty + 7).line(16, ty + 1, 16 - swing, ty + 7)
		c.paint(far, cloth, 1, false, false)

	# --- legs and shoes ----------------------------------------------------------------
	if sit:
		c.paint(c.mask().rect(12, 27, 3, 2).rect(17, 27, 3, 2), cloth2, 2)
		c.paint(c.mask().rect(11, 29, 4, 1).rect(17, 29, 4, 1), SHOE, 2)
	elif side:
		var st: Array = p.get("step", [0, 0, 0, 0])
		var ly := hem + 1
		var bx: int = 15 + int(st[2])
		var ax: int = 15 + int(st[0])
		c.paint(c.mask().rect(bx, ly - int(st[3]), 2, 29 - ly), cloth2, 1, false, false)
		c.paint(c.mask().rect(bx, 29 - int(st[3]), 3, 1), SHOE, 1)
		c.paint(c.mask().rect(ax, ly - int(st[1]), 2, 29 - ly), cloth2, 2)
		c.paint(c.mask().rect(ax, 29 - int(st[1]), 3, 1), SHOE, 2)
	else:
		var ly := hem + 1
		c.paint(c.mask().rect(13, ly, 2, 29 - ly).rect(17, ly, 2, 29 - ly), cloth2, 2)
		c.paint(c.mask().rect(12, 29, 3, 1).rect(17, 29, 3, 1), SHOE, 2)

	# --- torso / outfit -----------------------------------------------------------------
	var body := c.mask()
	if side:
		body.poly(V([[16 - sw, ty], [15 + sw, ty], [16 + sw, ty + 3], [16 + sw + (1 if long_skirt else 0), bottom + 1], [16 - sw - (2 if long_skirt else 1), bottom + 1], [16 - sw - 1, ty + 3]]))
	else:
		var fl := 2 if long_skirt else 1
		body.poly(V([[17 - hw, ty], [15 + hw, ty], [16 + hw, ty + 2], [16 + hw + fl, bottom + 1], [16 - hw - fl, bottom + 1], [16 - hw, ty + 2]]))
	c.paint(body, cloth, 2, true)
	var waist := ty + (5 if child else 6)
	if sp.get("plaid", false):
		for y in range(ty + 1, bottom + 1):
			for x in range(4, 28):
				if body.has(x, y) and ((x + 1) % 4 == 0 or y % 4 == 0):
					c.put(x, y, cloth[1])
	if long_skirt:
		# folds in the skirt and a trimmed hem
		for x in [14, 18] if not side else [15]:
			for y in range(waist + 2, bottom + 1):
				if body.has(x, y):
					c.put(x, y, cloth[1])
		_band(c, body, bottom, trim, 3)
	match outfit:
		"apron":
			var ap := c.mask().poly(V([[13, ty + 3], [19, ty + 3], [20, bottom + 1], [12, bottom + 1]])) if not side else c.mask().rect(16 + sw - 2, ty + 3, 3, bottom - ty - 2)
			c.paint(ap, trim, 2, false, false)
			if not side:
				c.line(13, ty + 3, 12, ty, trim[1])
				c.line(19, ty + 3, 20, ty, trim[1])
				c.put(16, waist + 2, Pal.STEEL[3])   # a tool loop
		"coat":
			if not side:
				for y in range(ty + 1, bottom + 1):
					c.put(16, y, cloth[0])
				for y in [ty + 3, ty + 6, ty + 9]:
					if y <= bottom:
						c.put(17, y, trim[3])
			_band(c, body, waist, trim, 1)
		"tabard":
			if not side:
				var tb := c.mask().rect(14, ty + 1, 5, bottom - ty + 1)
				c.paint(tb, trim, 2, false, false)
				c.put(16, ty + 4, Pal.GOLD[3])
				# pauldrons
				c.paint(c.mask().ellipse(16.0 - hw + 0.5, ty + 1.5, 2.4, 2.0).ellipse(16.0 + hw + 0.5, ty + 1.5, 2.4, 2.0), Pal.STEEL, 3)
			else:
				c.paint(c.mask().rect(16 + sw - 2, ty + 1, 3, bottom - ty), trim, 2, false, false)
				c.paint(c.mask().ellipse(16.5, ty + 1.5, 2.6, 2.0), Pal.STEEL, 3)
			_band(c, body, waist, Pal.WOOD, 1)
		"tunic":
			_band(c, body, waist, trim, 2)
			if not side:
				c.put(16, ty + 1, cloth[0])
				c.put(16, ty + 2, cloth[0])
		"robe":
			_band(c, body, waist, trim, 2)
		"dress":
			_band(c, body, waist, trim, 2)
	if sp.has("apron") and not side:
		var ap2 := c.mask().poly(V([[13, waist + 1], [19, waist + 1], [20, bottom - 1], [12, bottom - 1]]))
		c.paint(ap2, sp.apron, 2, false, false)
	if sp.has("shawl"):
		var sh := c.mask()
		if side:
			sh.poly(V([[16 - sw - 1, ty - 1], [16 + sw, ty - 1], [16 + sw, ty + 3], [16 - sw - 2, ty + 5]]))
		else:
			sh.poly(V([[16 - hw - 1, ty - 1], [16 + hw + 1, ty - 1], [16 + hw, ty + 2], [16, ty + 4], [16 - hw, ty + 2]]))
		c.paint(sh, sp.shawl, 2, true)
	if sp.has("scarf"):
		var sc := c.mask().rect(16 - hw, ty - 1, hw * 2 + 1, 2) if not side else c.mask().rect(16 - sw, ty - 1, sw * 2, 2)
		if not side:
			sc.rect(16 + hw - 2, ty + 1, 2, 4)
		else:
			sc.rect(16 - sw - 3, ty, 3, 2)
		c.paint(sc, sp.scarf, 2)

	if sp.get("back", "none") == "logs" and not side:
		c.line(16 - hw + 1, ty, 16 + hw - 1, ty + 7, Pal.WOOD[1])
		c.line(16 - hw + 2, ty, 16 + hw, ty + 7, Pal.WOOD[2])

	# --- arms, hands, held item -------------------------------------------------------------
	var hand_r := Vector2i(16 + hw + 1, ty + 8)    # screen-right hand (front view)
	var hand_l := Vector2i(16 - hw - 2, ty + 8)
	var sleeve: Array = skin if sp.get("bare_arms", false) else cloth
	var hold: String = sp.get("hold", "none")
	if side:
		var swing: int = p.get("arm", 0)
		var hand := Vector2i(16 + swing, ty + 8)
		if hold in ["staff_lantern", "pole_lantern", "lantern", "basket", "hammer", "toy"]:
			hand = Vector2i(17 + sw - 1, ty + 7)
		var arm := c.mask().line(16, ty + 1, hand.x, hand.y - 1).line(17, ty + 1, hand.x + 1, hand.y - 1)
		c.paint(arm, sleeve, 2, false, true)
		c.paint(c.mask().rect(hand.x, hand.y, 2, 2), skin, 2)
		_held_side(c, sp, hold, hand, ty, f)
	else:
		var gesture := talk > 0 and hold in ["none", "basket", "lantern", "toy", "sling", "hammer", "axe", "pole_lantern", "staff_lantern"]
		# screen-left arm: the talking hand
		if hold == "sling":
			c.paint(c.mask().rect(16 - hw, ty + 4, hw + 1, 2), sleeve, 2)
			c.paint(c.mask().poly(V([[16 - hw - 1, ty + 3], [17, ty + 3], [16, ty + 7]])), Pal.BONE, 3, false, false)
		elif gesture:
			var up := 3 if talk == 1 else 5
			c.paint(c.mask().rect(hand_l.x, ty + 1, 2, 7 - up).rect(hand_l.x - 1, ty + 8 - up - 2, 2, 3), sleeve, 2)
			c.paint(c.mask().rect(hand_l.x - 2, ty + 8 - up - 3, 2, 2), skin, 2)
		elif hold == "lute":
			c.paint(c.mask().line(hand_l.x + 1, ty + 1, 13, ty + 6).line(hand_l.x + 2, ty + 1, 14, ty + 6), sleeve, 2)
		elif sit:
			c.paint(c.mask().rect(hand_l.x + 1, ty + 1, 2, 6), sleeve, 2)
			c.paint(c.mask().rect(hand_l.x + 2, ty + 7, 2, 2), skin, 2)
		else:
			c.paint(c.mask().rect(hand_l.x, ty + 1, 2, 7), sleeve, 2)
			c.paint(c.mask().rect(hand_l.x, hand_l.y, 2, 2), skin, 2)
		# screen-right arm: holds the item
		if work >= 0 and hold == "hammer":
			hand_r = _work_hand(work, ty, hw)
			c.paint(c.mask().line(16 + hw, ty + 1, hand_r.x, hand_r.y).line(16 + hw + 1, ty + 1, hand_r.x + 1, hand_r.y), sleeve, 2)
		elif hold == "lute":
			hand_r = Vector2i(19, ty + 6)
			c.paint(c.mask().line(16 + hw + 1, ty + 1, 19, ty + 5).line(16 + hw, ty + 1, 18, ty + 5), sleeve, 2)
		elif hold == "axe":
			hand_r = Vector2i(16 + hw + 1, ty + 4)
			c.paint(c.mask().rect(16 + hw, ty + 1, 2, 4), sleeve, 2)
		elif sit:
			hand_r = Vector2i(16 + hw - 1, ty + 7)
			c.paint(c.mask().rect(16 + hw - 1, ty + 1, 2, 6), sleeve, 2)
		else:
			c.paint(c.mask().rect(hand_r.x, ty + 1, 2, 7), sleeve, 2)
		c.paint(c.mask().rect(hand_r.x, hand_r.y, 2, 2), skin, 2)
		_held_front(c, sp, hold, hand_r, ty, hw, f, work, talk)

	# --- head --------------------------------------------------------------------------------
	_head(c, sp, side, cx, cy, rx, ry, ty, p)
	c.outline(Pal.INK)
	_after_outline(c, sp, hold, hand_r, ty, hw, work, side)
	return c


## A one-pixel horizontal band clipped to the body (belts, hems).
static func _band(c: Px, body: Px.Mask, y: int, r: Array, i: int) -> void:
	for x in 32:
		if body.has(x, y):
			c.put(x, y, r[clampi(i, 0, r.size() - 1)])


static func _work_hand(work: int, ty: int, hw: int) -> Vector2i:
	# the smith's hammer: raise (0-2), strike (3), recover (4-5)
	match work:
		0:
			return Vector2i(16 + hw + 1, ty + 6)
		1:
			return Vector2i(16 + hw + 2, ty + 1)
		2:
			return Vector2i(16 + hw + 1, ty - 3)
		3:
			return Vector2i(16 + hw + 3, ty + 8)
		4:
			return Vector2i(16 + hw + 2, ty + 7)
	return Vector2i(16 + hw + 1, ty + 7)


static func _back_item(c: Px, sp: Dictionary, side: bool, ty: int, hw: int) -> void:
	match sp.get("back", "none"):
		"pack":
			var pk := c.mask().rect(16 - hw - 1, ty - 6, hw * 2 + 3, 12) if not side else c.mask().rect(16 - hw - 4, ty - 6, 8, 13)
			c.paint(pk, Pal.WOOD, 2, true)
			var ox := 16 - hw if not side else 16 - hw - 3
			var wares: Array = [Pal.BLOOD, Pal.GOLD, Pal.SOUL, Pal.MOSS]
			for k in 4:
				c.paint(c.mask().rect(ox + k * 3, ty - 9 + (k % 2), 3, 4), wares[k], 3)
			c.line(ox, ty - 2, ox + (hw * 2 if not side else 6), ty - 2, Pal.EARTH[1])
		"logs":
			if side:
				for k in 3:
					c.paint(c.mask().rect(16 - hw - 3, ty - 1 + k * 3, 6, 3), Pal.WOOD, 3 - k % 2)
					c.put(16 - hw - 3, ty + k * 3, Pal.WOOD[4])
			# seen from the front only the carrying strap shows (drawn over the torso)


static func _held_front(c: Px, sp: Dictionary, hold: String, h: Vector2i, ty: int, hw: int, f: int, work: int, talk: int) -> void:
	match hold:
		"staff_lantern":
			var top := ty - 12
			c.paint(c.mask().rect(h.x + 2, top, 1, 30 - top), Pal.WOOD, 3, false, false)
			c.put(h.x + 2, top - 1, Pal.WOOD[4])
			c.put(h.x + 3, top, Pal.STEEL[2])
			c.put(h.x + 4, top + 1, Pal.STEEL[2])
			_lamp(c, h.x + 3, top + 2, 4 + f % 2)
		"pole_lantern":
			var tip := Vector2i(h.x + 5, 3 + (f % 4) / 3)
			c.line(h.x, h.y + 1, tip.x, tip.y, Pal.WOOD[2])
			c.line(h.x + 1, h.y + 1, tip.x + 1, tip.y, Pal.WOOD[3])
			c.put(tip.x + 2, tip.y, Pal.STEEL[3])
			_lamp(c, tip.x + 2, tip.y + 1, 4 + f % 2)
		"lantern":
			c.line(h.x + 1, h.y + 1, h.x + 2, h.y + 3, Pal.STEEL[2])
			_lamp(c, h.x + 1, h.y + 3, 4 + f % 2)
		"hammer":
			var hd := h
			if work == 2:
				c.paint(c.mask().rect(hd.x, hd.y - 5, 1, 6), Pal.WOOD, 2, false, false)
				c.paint(c.mask().rect(hd.x - 2, hd.y - 8, 5, 3), Pal.STEEL, 3)
			elif work == 3:
				c.paint(c.mask().rect(hd.x + 1, hd.y - 1, 5, 1), Pal.WOOD, 2, false, false)
				c.paint(c.mask().rect(hd.x + 5, hd.y - 2, 3, 4), Pal.STEEL, 3)
			else:
				c.paint(c.mask().rect(hd.x, hd.y - 4, 1, 6), Pal.WOOD, 2, false, false)
				c.paint(c.mask().rect(hd.x - 1, hd.y - 6, 4, 3), Pal.STEEL, 3)
		"basket":
			var bk := c.mask().ellipse(h.x + 1.5, h.y + 3.0, 3.2, 2.4)
			bk.rect(h.x - 1, h.y + 1, 6, 2)
			c.paint(bk, Pal.WOOD, 3, true)
			c.line(h.x - 1, h.y + 1, h.x + 4, h.y + 1, Pal.WOOD[1])
			c.put(h.x, h.y, Pal.MOSS[4])
			c.put(h.x + 2, h.y - 1, Pal.MOSS[3])
			c.put(h.x + 3, h.y, Pal.MOSS[4])
		"axe":
			c.line(h.x, h.y + 2, h.x - 2, ty - 7, Pal.WOOD[2])
			c.line(h.x + 1, h.y + 2, h.x - 1, ty - 7, Pal.WOOD[3])
			var ah := c.mask().poly(V([[h.x - 2, ty - 9], [h.x + 3, ty - 10], [h.x + 4, ty - 6], [h.x - 1, ty - 6]]))
			c.paint(ah, Pal.STEEL, 3)
			c.put(h.x + 4, ty - 8, Pal.STEEL[5])
		"lute":
			var lb := c.mask().ellipse(14.0, ty + 7.0, 3.4, 2.8)
			c.paint(lb, Pal.WOOD, 3, true)
			c.put(14, ty + 7, Pal.INK)
			c.line(16, ty + 6, 16 + hw + 2, ty - 1, Pal.WOOD[1])
			c.put(16 + hw + 2, ty - 2, Pal.WOOD[3])
			c.put(16 + hw + 3, ty - 2, Pal.WOOD[3])
			if talk > 0:
				c.put(15 + (talk % 2), ty + 6, Pal.BONE[4])
		"toy":
			c.line(h.x + 1, h.y, h.x + 4, h.y - 6, Pal.WOOD[3])
			c.line(h.x, h.y - 1, h.x + 2, h.y - 1, Pal.WOOD[1])
		"sling":
			# a sheathed sword at the hip
			c.paint(c.mask().rect(16 + hw - 2, ty + 7, 1, 7), Pal.STEEL, 2, false, false)
			c.put(16 + hw - 3, ty + 7, Pal.GOLD[2])
			c.put(16 + hw - 1, ty + 7, Pal.GOLD[2])


static func _held_side(c: Px, sp: Dictionary, hold: String, h: Vector2i, ty: int, f: int) -> void:
	match hold:
		"staff_lantern":
			var top := ty - 12
			c.paint(c.mask().rect(h.x + 1, top, 1, 30 - top), Pal.WOOD, 3, false, false)
			c.put(h.x + 2, top, Pal.STEEL[2])
			_lamp(c, h.x + 2, top + 1, 4 + f % 2)
		"pole_lantern":
			c.line(h.x, h.y + 1, h.x + 6, 3, Pal.WOOD[2])
			_lamp(c, h.x + 7, 4, 4 + f % 2)
		"lantern":
			_lamp(c, h.x + 1, h.y + 2, 4 + f % 2)
		"hammer":
			c.paint(c.mask().rect(h.x + 1, h.y - 3, 1, 6), Pal.WOOD, 2, false, false)
			c.paint(c.mask().rect(h.x, h.y - 5, 3, 3), Pal.STEEL, 3)
		"basket":
			c.paint(c.mask().ellipse(h.x + 1.5, h.y + 3.0, 3.0, 2.2), Pal.WOOD, 3, true)
			c.put(h.x + 1, h.y, Pal.MOSS[4])
		"axe":
			c.line(h.x, h.y, h.x - 6, ty - 5, Pal.WOOD[2])
			c.paint(c.mask().poly(V([[h.x - 9, ty - 8], [h.x - 5, ty - 8], [h.x - 5, ty - 4], [h.x - 8, ty - 5]])), Pal.STEEL, 3)
		"lute":
			c.paint(c.mask().ellipse(11.0, ty + 4.0, 2.6, 3.4), Pal.WOOD, 3, true)
			c.line(12, ty + 1, 15, ty - 4, Pal.WOOD[1])
		"toy":
			c.line(h.x + 1, h.y, h.x + 4, h.y - 5, Pal.WOOD[3])


## A small hanging lamp whose flame is emissive.
static func _lamp(c: Px, x: int, y: int, glow: int) -> void:
	c.put(x, y, Pal.STEEL[1])
	c.put(x + 1, y, Pal.STEEL[3])
	c.put(x - 1, y + 1, Pal.STEEL[1])
	c.put(x + 2, y + 1, Pal.STEEL[1])
	for yy in range(y + 1, y + 4):
		c.lit(x, yy, Pal.ramp(Pal.EMBER, glow))
		c.lit(x + 1, yy, Pal.ramp(Pal.EMBER, glow + (1 if yy == y + 2 else 0)))
	c.put(x - 1, y + 4, Pal.STEEL[0])
	c.put(x, y + 4, Pal.STEEL[2])
	c.put(x + 1, y + 4, Pal.STEEL[2])
	c.put(x + 2, y + 4, Pal.STEEL[0])


static func _head(c: Px, sp: Dictionary, side: bool, cx: float, cy: float, rx: float, ry: float, ty: int, p: Dictionary) -> void:
	var skin: Array = sp.get("skin", Pal.SKIN)
	var hair: Array = sp.get("hair", Pal.EARTH)
	var hat: Array = sp.get("hat", Pal.EARTH)
	var head_kind: String = sp.get("head", "none")
	var style: String = sp.get("hair_style", "short")
	var blink: bool = p.get("blink", false)
	var talk: int = p.get("talk", 0)
	var elder: bool = sp.get("elder", false)
	var shadow: bool = sp.get("face", "normal") == "shadow"
	var icx := int(floor(cx))
	var icy := int(floor(cy))
	# neck
	c.paint(c.mask().rect(icx - 1, icy + 3, 2 + (1 if side else 0), ty - icy - 2), skin, 1, false, false)
	var head := c.mask().ellipse(cx, cy, rx, ry)
	if side:
		head.set_bit(int(cx + rx), icy + 2)   # nose
	c.paint(head, skin, 2)
	# hair (under any headwear)
	if head_kind != "hood":
		var hm := c.mask()
		if style != "bald":
			hm.ellipse(cx - (0.6 if side else 0.0), cy - 1.0, rx + 0.6, ry + 0.1)
			for y in 32:
				for x in 32:
					if not hm.has(x, y):
						continue
					var dx := x + 0.5 - cx
					if side:
						if y > icy - 2 and dx > -1.5:
							hm.set_bit(x, y, false)
					elif y > icy - 2 and absf(dx) < rx - 1.0:
						hm.set_bit(x, y, false)
			match style:
				"long":
					if side:
						hm.rect(int(cx - rx) - 1, icy - 1, 3, ty + 5 - icy)
					else:
						hm.rect(int(cx - rx) - 1, icy - 1, 2, ty + 5 - icy).rect(int(cx + rx) - 1, icy - 1, 2, ty + 5 - icy)
				"bun":
					hm.ellipse(cx - (1.5 if side else 0.0), cy - ry - 0.6, 2.2, 2.0)
				"tousled":
					for k in 5:
						hm.set_bit(icx - 3 + k * 2 - (1 if side else 0), int(cy - ry) - (k % 2))
		c.paint(hm, hair, 2)
		if style == "bald":
			c.put(icx - 2, int(cy - ry) + 2, skin[3])
			c.put(icx - 1, int(cy - ry) + 1, skin[3])
	# beard
	var beard: String = sp.get("beard", "none")
	if beard != "none":
		var bm := c.mask()
		match beard:
			"full", "braid":
				if side:
					bm.ellipse(cx + 1.2, cy + 2.8, rx - 1.2, 2.6)
				else:
					bm.ellipse(cx, cy + 3.0, rx - 0.4, 2.6)
				for y in 32:
					for x in 32:
						if bm.has(x, y) and y < icy + 2 and absf(x + 0.5 - cx) < 2.0 and not side:
							bm.set_bit(x, y, false)
				if beard == "braid":
					bm.rect(icx - 1, icy + 5, 2, 5)
			"mustache":
				if side:
					bm.rect(icx + 2, icy + 2, 3, 1)
				else:
					bm.rect(icx - 2, icy + 2, 4, 1)
					bm.set_bit(icx - 3, icy + 3)
					bm.set_bit(icx + 2, icy + 3)
		c.paint(bm, hair, 2)
		if beard == "braid":
			c.put(icx - 1, icy + 7, Pal.GOLD[3])
			c.put(icx, icy + 7, Pal.GOLD[3])
	# headwear
	match head_kind:
		"hood":
			var hood := c.mask()
			if side:
				hood.ellipse(cx - 0.6, cy - 0.4, rx + 1.4, ry + 1.2)
				hood.poly(V([[cx - 2, cy + 2], [cx - rx - 3, cy + 6], [cx - 1, cy + 6]]))
			else:
				hood.ellipse(cx, cy - 0.4, rx + 1.4, ry + 1.2)
			var face := c.mask()
			if side:
				face.ellipse(cx + 2.0, cy + 1.2, 2.6, ry - 1.4)
			else:
				face.ellipse(cx, cy + 1.2, rx - 0.8, ry - 1.3)
			hood.subtract(face)
			c.paint(hood, hat, 2, true)
			if shadow:
				c.fill(face, Pal.INK)
		"scarf":
			var sc := c.mask()
			sc.ellipse(cx - (0.4 if side else 0.0), cy - 1.2, rx + 0.9, ry + 0.2)
			for y in 32:
				for x in 32:
					if sc.has(x, y) and y > icy - 2 and (side and x + 0.5 > cx - 1.0 or not side and absf(x + 0.5 - cx) < rx - 0.6):
						sc.set_bit(x, y, false)
			if side:
				sc.rect(int(cx - rx) - 2, icy, 2, 4)
			else:
				sc.ellipse(cx + rx + 0.4, cy + 1.5, 1.4, 1.3)
				sc.rect(int(cx + rx), icy + 2, 2, 4)
			c.paint(sc, hat, 2, true)
			c.line(int(cx - rx) + 1, icy - 2, int(cx + rx) - 1, icy - 2, hat[1])
		"cap":
			var cap := c.mask().ellipse(cx - (0.4 if side else 0.0), cy - 2.2, rx + 0.4, 2.8)
			for y in 32:
				for x in 32:
					if cap.has(x, y) and y > icy - 2:
						cap.set_bit(x, y, false)
			if side:
				cap.rect(icx, icy - 2, int(rx) + 3, 1)
			else:
				cap.rect(icx - int(rx), icy - 2, int(rx) * 2 + 1, 1)
			c.paint(cap, hat, 3, true)
		"brim":
			var hb := c.mask().rect(icx - 3, int(cy - ry) - 3, 7 if not side else 6, 4)
			hb.rect(icx - int(rx) - 3, int(cy - ry) + 1, int(rx) * 2 + 7, 2)
			c.paint(hb, hat, 3, true)
			_band_rect(c, icx - 3, int(cy - ry), 7 if not side else 6, Pal.GOLD[2])
	# face
	if shadow:
		var ey := icy + 1
		c.lit(icx - 2 + (3 if side else 0), ey, Pal.GOLD[4])
		if not side:
			c.lit(icx + 1, ey, Pal.GOLD[4])
		return
	var ey2 := icy + 1
	var eyes: Array = [icx + 2] if side else [icx - 2, icx + 1]
	for e in eyes:
		if blink:
			c.put(e, ey2 + 1, skin[0])
		else:
			c.put(e, ey2, Pal.INK)
			c.put(e, ey2 + 1, Pal.INK)
		if elder:
			c.put(e, ey2 - 1, Pal.BONE[4])
			c.put(e + (1 if side else 0), ey2 + 2, skin[1])
		else:
			c.put(e, ey2 - 1, hair[1] if head_kind != "hood" else skin[1])
	if sp.get("blush", false) and not side:
		c.put(icx - 3, ey2 + 2, skin[3].lerp(Pal.BLOOD[4], 0.5))
		c.put(icx + 2, ey2 + 2, skin[3].lerp(Pal.BLOOD[4], 0.5))
	var mouth_y := ey2 + 3
	if sp.get("beard", "none") in ["full", "braid"] and talk == 0:
		return
	if side:
		c.put(icx + 3, mouth_y, Pal.BLOOD[1] if talk == 2 else skin[0])
	elif talk == 2:
		c.put(icx - 1, mouth_y, Pal.INK)
		c.put(icx, mouth_y, Pal.INK)
		c.put(icx - 1, mouth_y + 1, Pal.BLOOD[2])
	else:
		c.put(icx - 1, mouth_y, skin[0])
		c.put(icx, mouth_y, skin[0])


static func _band_rect(c: Px, x: int, y: int, w: int, col: Color) -> void:
	for k in w:
		if c.opaque(x + k, y):
			c.put(x + k, y, col)


## Emissive bits drawn after the outline so they glow past it (forge sparks).
static func _after_outline(c: Px, sp: Dictionary, hold: String, h: Vector2i, ty: int, hw: int, work: int, side: bool) -> void:
	if hold == "hammer" and work == 3 and not side:
		for k in 5:
			var sx := h.x + 6 + (k * 3) % 5 - 1
			var sy := h.y + 1 - (k * 2) % 5
			c.lit(sx, sy, Pal.EMBER[3 + k % 3])
