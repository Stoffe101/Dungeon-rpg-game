## What is worn stays on the body: every armour sheet measured against the body's own
## frames, pose by pose, including the death it used to vanish in.
extends TestCase

const HEADS := ["hood", "helm", "circlet", "crown", "cap", "mask"]
const CHESTS := ["robe", "mail", "plate", "cloak", "coat"]
const HANDS := ["gauntlets", "gloves", "wraps", "bracers"]


func _sheet(name: String) -> Array:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % name))
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % name))
	return [img, info]


func _bits(sh: Array, anim: String, frame: int) -> PackedByteArray:
	var img: Image = sh[0]
	var a: Dictionary = sh[1].anims[anim]
	var out := PackedByteArray()
	out.resize(32 * 32)
	for y in 32:
		for x in 32:
			out[y * 32 + x] = 1 if img.get_pixel(frame * 32 + x, int(a.row) * 32 + y).a > 0.5 else 0
	return out


func _count(b: PackedByteArray) -> int:
	var n := 0
	for v in b:
		n += v
	return n


## Pieces of `gear` that touch nothing of `body`: armour hanging in the air.
func _floating(gear: PackedByteArray, body: PackedByteArray) -> int:
	var seen := PackedByteArray()
	seen.resize(gear.size())
	var bad := 0
	for start in gear.size():
		if gear[start] == 0 or seen[start] == 1:
			continue
		var todo: Array[int] = [start]
		seen[start] = 1
		var touches := false
		while not todo.is_empty():
			var i: int = todo.pop_back()
			var x := i % 32
			var y := i / 32
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= 32 or ny >= 32:
						continue
					var n := ny * 32 + nx
					if body[n] == 1:
						touches = true
					if gear[n] == 1 and seen[n] == 0:
						seen[n] = 1
						todo.append(n)
		if not touches:
			bad += 1
	return bad


func _widest(b: PackedByteArray, y0 := 0, y1 := 32) -> int:
	var lo := 32
	var hi := -1
	for y in range(y0, y1):
		for x in 32:
			if b[y * 32 + x] == 1:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return hi - lo + 1


func _union(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := a.duplicate()
	for i in out.size():
		out[i] = out[i] | b[i]
	return out


func test_every_armour_has_the_bodys_animations_frame_for_frame() -> void:
	var body := _sheet("player")
	for base: String in GearLooks.VIS:
		var g := _sheet("gear_" + base)
		for a: String in body[1].anims:
			check(g[1].anims.has(a), "%s has %s" % [base, a])
			eq(int(g[1].anims[a].frames), int(body[1].anims[a].frames), "%s %s frames" % [base, a])
		eq(int(g[1].origin[0]), int(body[1].origin[0]), base + " shares the body's origin")


func test_nothing_worn_floats_and_nothing_worn_vanishes() -> void:
	var body := _sheet("player")
	var bits := {}
	for base: String in GearLooks.VIS:
		var style: String = GearLooks.VIS[base][0]
		var g := _sheet("gear_" + base)
		for a: String in body[1].anims:
			for f in int(body[1].anims[a].frames):
				var key := "%s/%d" % [a, f]
				if not bits.has(key):
					bits[key] = _bits(body, a, f)
				var gb := _bits(g, a, f)
				var n := _count(gb)
				eq(_floating(gb, bits[key]), 0, "%s floats in %s" % [base, key])
				if a == "death" and (style in HANDS or (not style in HEADS and not style in CHESTS)):
					continue       # gloves and boots are under the heap
				check(n >= 2, "%s vanishes in %s (%d pixels)" % [base, key, n])


func test_a_helm_rides_on_the_head_in_every_living_pose() -> void:
	var body := _sheet("player")
	for base: String in GearLooks.VIS:
		if not String(GearLooks.VIS[base][0]) in HEADS:
			continue
		var g := _sheet("gear_" + base)
		for a: String in body[1].anims:
			if a == "death":
				continue
			for f in int(body[1].anims[a].frames):
				var gb := _bits(g, a, f)
				var ys := 0
				var n := 0
				for i in gb.size():
					if gb[i] == 1:
						ys += i / 32
						n += 1
				check(float(ys) / float(n) < 18.0, "%s sits on the head in %s %d" % [base, a, f])


func test_iron_looks_heavy_and_silk_looks_light() -> void:
	var body := _bits(_sheet("player"), "idle_down", 0)
	var plain := _widest(body)
	var plate := _widest(_union(body, _bits(_sheet("gear_emberwrought_plate"), "idle_down", 0)))
	var mail := _widest(_union(body, _bits(_sheet("gear_grave_iron_mail"), "idle_down", 0)))
	var robe := _widest(_union(body, _bits(_sheet("gear_gravecloth_robe"), "idle_down", 0)), 25, 32)
	var robe_shoulders := _widest(_union(body, _bits(_sheet("gear_gravecloth_robe"), "idle_down", 0)), 14, 20)
	var mail_hem := _widest(_union(body, _bits(_sheet("gear_grave_iron_mail"), "idle_down", 0)), 25, 32)
	check(plate >= plain + 4, "plate stands wider than the body (%d against %d)" % [plate, plain])
	check(plate > mail, "plate is wider than mail (%d against %d)" % [plate, mail])
	check(robe > mail_hem, "cloth flares past mail at the hem (%d against %d)" % [robe, mail_hem])
	check(robe > robe_shoulders, "a robe is widest at the feet")
	var slim := _widest(_union(body, _bits(_sheet("gear_sprinter_sandals"), "idle_down", 0)))
	eq(slim, plain, "sandals add nothing to the outline")
	var fist := _widest(_union(body, _bits(_sheet("gear_bone_gauntlets"), "idle_down", 0)), 18, 25)
	var wrap := _widest(_union(body, _bits(_sheet("gear_silk_wraps"), "idle_down", 0)), 18, 25)
	check(fist > wrap, "gauntlets are bigger than wraps (%d against %d)" % [fist, wrap])


func test_a_face_stays_visible_under_everything_that_leaves_it_open() -> void:
	# eyes are the one thing that says "this is you" at game size
	var hood := _sheet("gear_gravecloth_hood")
	var img: Image = hood[0]
	var a: Dictionary = hood[1].anims["idle_down"]
	var c := img.get_pixel(14, int(a.row) * 32 + 12)
	check(c.a > 0.5 and c.r > 0.6, "the hood draws the eyes again")
