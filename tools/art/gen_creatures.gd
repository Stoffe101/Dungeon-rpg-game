## Newer inhabitants of the older regions: the Grave Spider of the Ossuary and
## the Bog Toad of the Rootmire. Facing right.
extends RefCounted

const Px = preload("res://tools/art/px.gd")
const Pal = preload("res://tools/art/pal.gd")
const Sheet = preload("res://tools/art/sheet.gd")


static func build(dir: String) -> void:
	_spider(dir)
	_toad(dir)


# --- Grave Spider: a bone-white spider with a skull on its back ---------------

static func _spider(dir: String) -> void:
	var s := Sheet.new(26, 16, Vector2i(13, 14))
	s.add("idle", [spider_frame({}), spider_frame({"bob": 1})], 3.0)
	var walk: Array = []
	for i in 4:
		walk.append(spider_frame({"walk": i, "bob": i % 2}))
	s.add("walk", walk, 12.0)
	s.add("windup", [spider_frame({"rear": true})], 1.0, false)
	s.add("spit", [spider_frame({"rear": true, "spit": 1}), spider_frame({"spit": 2})], 10.0, false)
	s.add("lunge", [spider_frame({"lunge": true}), spider_frame({"lunge": true, "bob": 1})], 10.0, false)
	s.save(dir, "spider")


static func spider_frame(p: Dictionary) -> Px:
	var c := Px.new(26, 16)
	var b: int = int(p.get("bob", 0))
	var w: int = int(p.get("walk", -1))
	var rear: bool = p.get("rear", false)
	var lunge: bool = p.get("lunge", false)
	var by := 8 + b + (-1 if rear else 0)
	var bx := 11 + (2 if lunge else 0)
	# legs: four pairs arching up to a knee and down to the floor, far side darker
	var feet := [-10, -5, 4, 9]
	var knees := [-7, -3, 2, 6]
	for side: int in [1, 0]:
		var col: Color = Pal.STONE[2] if side == 1 else Pal.BONE[1]
		for i in 4:
			var step := 0
			if w >= 0:
				step = 1 if (i + w + side) % 2 == 0 else -1
			var kx: int = bx + knees[i] + step + side
			var ky := by - 5 - side
			var fx: int = bx + feet[i] + step * 2 + side * 2
			var fy := 14 - (1 if step > 0 else 0)
			if i == 3 and rear:
				kx = bx + 6
				ky = by - 8
				fx = bx + 9 + side
				fy = by - 6
			elif i == 3 and lunge:
				fx = bx + 11
				fy = by + 2
			c.line(bx + (i - 2) * 2, by, kx, ky, col)
			c.line(kx, ky, fx, fy, col)
	# abdomen with the skull marking
	var ab := c.mask().ellipse(bx - 4.5, by - 1.0, 5.5, 4.0)
	c.paint(ab, Pal.BONE, 2, true)
	for q in [Vector2i(-6, -2), Vector2i(-3, -2)]:
		c.put(bx + q.x, by + q.y, Pal.INK)
		c.put(bx + q.x, by + q.y + 1, Pal.BONE[0])
	c.put(bx - 5, by + 1, Pal.BONE[0])
	c.put(bx - 4, by + 1, Pal.BONE[0])
	for x in range(bx - 7, bx - 1):
		c.put(x, by + 2, Pal.BONE[1] if x % 2 == 0 else Pal.BONE[0])
	# head
	var hd := c.mask().ellipse(bx + 3.0, by - 0.5, 3.0, 2.4)
	c.paint(hd, Pal.BONE, 3, true)
	c.lit(bx + 4, by - 1, Pal.SOUL[4])
	c.lit(bx + 5, by - 1, Pal.SOUL[3])
	c.lit(bx + 4, by - 2, Pal.SOUL[3])
	# fangs
	var sp: int = int(p.get("spit", 0))
	c.put(bx + 6, by + 1, Pal.BONE[4])
	c.put(bx + 6, by + 2 + (1 if lunge else 0), Pal.BONE[3])
	if sp == 1:
		c.lit(bx + 7, by, Pal.STEEL[5])
	elif sp == 2:
		c.lit(bx + 8, by - 1, Pal.STEEL[5])
		c.lit(bx + 9, by - 1, Pal.STEEL[4])
	c.outline(Pal.INK)
	return c


# --- Bog Toad: fat, mossy, glowing with spores --------------------------------

static func _toad(dir: String) -> void:
	var s := Sheet.new(26, 22, Vector2i(13, 20))
	s.add("idle", [toad_frame({}), toad_frame({"throat": 1})], 2.5)
	s.add("crouch", [toad_frame({"crouch": true})], 1.0, false)
	s.add("hop", [toad_frame({"hop": 1}), toad_frame({"hop": 2})], 8.0, false)
	s.add("tongue", [toad_frame({"mouth": true}), toad_frame({"mouth": true, "throat": 1})], 10.0, false)
	s.save(dir, "toad")


static func toad_frame(p: Dictionary) -> Px:
	var c := Px.new(26, 22)
	var crouch: bool = p.get("crouch", false)
	var hop: int = int(p.get("hop", 0))
	var mouth: bool = p.get("mouth", false)
	var throat: int = int(p.get("throat", 0))
	var by := 13 + (2 if crouch else 0) - (2 if hop == 1 else 0)
	var stretch := 1.0 if hop == 1 else 0.0
	# back legs
	if hop == 1:
		c.paint(c.mask().ellipse(7.0, by + 5.0, 3.0, 1.6), Pal.MOSS, 1)
		c.line(4, by + 6, 2, by + 8, Pal.MOSS[1])
	else:
		c.paint(c.mask().ellipse(7.5, by + 3.5, 3.6, 3.0), Pal.MOSS, 2, true)
		c.line(5, by + 6, 9, 19, Pal.MOSS[1])
	# body
	var body := c.mask().ellipse(12.0, by, 7.5 + stretch, 5.5 - stretch)
	c.paint(body, Pal.MOSS, 2, true)
	var belly := c.mask().ellipse(14.0, by + 2.5, 5.0, 2.6)
	belly.subtract(c.mask().rect(0, 0, 26, by + 1))
	c.paint(belly, Pal.BONE, 2)
	# glowing spore pustules on the back
	for q in [[9, by - 4], [12, by - 5], [7, by - 2], [14, by - 3]]:
		c.lit(q[0], q[1], Pal.SOUL[4] if (q[0] + throat) % 3 == 0 else Pal.SOUL[3])
	# throat sac
	if throat == 1 or mouth:
		c.paint(c.mask().ellipse(18.0, by + 2.5, 2.4, 2.0), Pal.BLOOD, 3)
	# eyes on top
	for ex: int in [14, 17]:
		c.paint(c.mask().ellipse(ex, by - 4.5, 1.8, 1.6), Pal.MOSS, 3)
		c.lit(ex, by - 5, Pal.GOLD[4])
		c.put(ex + 1, by - 5, Pal.INK)
	# mouth
	if mouth:
		c.paint(c.mask().rect(17, by, 4, 2), [Pal.INK, Pal.BLOOD[1], Pal.BLOOD[2]], 1)
		c.line(20, by + 1, 24, by + 1, Pal.BLOOD[3])
	else:
		c.line(15, by + 1, 20, by, Pal.MOSS[0])
	# front legs
	if hop != 1:
		c.line(16, by + 4, 17, 19, Pal.MOSS[2])
		c.line(18, by + 4, 19, 19, Pal.MOSS[1])
	c.outline(Pal.INK)
	return c
