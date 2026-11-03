## How the Kindled looks: recolourings of the cloak and scarf, earned by
## wearing tier sets and legendaries and chosen freely in the wardrobe
## (transmogrification). Applied as a palette swap in the sprite shader, so
## every animation frame changes with no extra art.
class_name Looks
extends RefCounted

const Pal = preload("res://src/render/pal.gd")

const LOOKS := {
	"kindled": {"short": "Kindled", "name": "The Kindled", "desc": "Hearth-blue cloak, ember scarf.", "cloak": [], "scarf": []},
	"emberwrought": {"short": "Ember", "name": "Emberwrought", "desc": "Crimson and burnished gold.",
		"cloak": [Color8(40, 10, 16), Color8(72, 18, 24), Color8(112, 30, 30), Color8(158, 54, 40), Color8(206, 110, 60)],
		"scarf": [Color8(122, 82, 26), Color8(186, 134, 40), Color8(255, 216, 110)]},
	"rimeguard": {"short": "Rime", "name": "Rimeguard", "desc": "Frost-silvered steel and ice.",
		"cloak": [Color8(18, 34, 82), Color8(32, 68, 144), Color8(56, 114, 200), Color8(110, 172, 240), Color8(190, 228, 255)],
		"scarf": [Color8(62, 104, 168), Color8(110, 160, 214), Color8(190, 228, 250)]},
	"gloamweave": {"short": "Gloam", "name": "Gloamweave", "desc": "Midnight violet and shadow-silk.",
		"cloak": [Color8(14, 9, 22), Color8(30, 16, 44), Color8(54, 28, 78), Color8(90, 50, 122), Color8(140, 90, 172)],
		"scarf": [Color8(140, 74, 150), Color8(196, 120, 196), Color8(240, 190, 240)]},
	"verdant": {"short": "Verdant", "name": "Verdant Warden", "desc": "Living moss and old bone.",
		"cloak": [Color8(20, 32, 22), Color8(34, 54, 32), Color8(56, 84, 42), Color8(92, 122, 54), Color8(144, 168, 76)],
		"scarf": [Color8(170, 154, 130), Color8(214, 202, 176), Color8(240, 234, 214)]},
	"gloamward": {"short": "Gloamward", "name": "Gloamward", "desc": "The Warden's soul-light, turned.",
		"cloak": [Color8(10, 30, 36), Color8(18, 56, 62), Color8(28, 90, 94), Color8(56, 140, 134), Color8(120, 210, 190)],
		"scarf": [Color8(36, 122, 124), Color8(76, 184, 170), Color8(170, 246, 226)]},
	"bloom": {"short": "Bloom", "name": "Bloomcrowned", "desc": "Petal-red and spore-gold.",
		"cloak": [Color8(46, 12, 28), Color8(90, 22, 46), Color8(140, 40, 70), Color8(196, 80, 104), Color8(240, 150, 150)],
		"scarf": [Color8(94, 124, 56), Color8(146, 170, 78), Color8(214, 226, 140)]},
	"wanderer": {"short": "Wanderer", "name": "Grudge-Wanderer", "desc": "Road-dust and old blood. For those the dungeon forgot.",
		"cloak": [Color8(30, 24, 20), Color8(52, 42, 34), Color8(80, 66, 52), Color8(116, 98, 76), Color8(158, 138, 108)],
		"scarf": [Color8(98, 28, 30), Color8(150, 40, 40), Color8(200, 70, 60)]},
	"undying": {"short": "Undying", "name": "Undying Night", "desc": "Bone-white, and an ember that will not go out.",
		"cloak": [Color8(70, 66, 74), Color8(120, 116, 124), Color8(172, 168, 172), Color8(214, 210, 206), Color8(244, 240, 230)],
		"scarf": [Color8(170, 30, 30), Color8(230, 60, 40), Color8(255, 140, 70)]},
	"sunfall": {"short": "Sunfall", "name": "Sunfall", "desc": "Eclipse-black and the last gold of the sun.",
		"cloak": [Color8(12, 10, 16), Color8(22, 19, 28), Color8(36, 31, 42), Color8(58, 48, 58), Color8(98, 80, 70)],
		"scarf": [Color8(170, 110, 40), Color8(230, 170, 70), Color8(255, 226, 140)]},
}

## Which looks each item grants when obtained.
static func look_of_base(base_id: String) -> String:
	var b := ItemDB.base(base_id)
	if b.has("set"):
		return String(ItemDB.SETS[b.set].look)
	return String(b.get("look", ""))


static func unlocked() -> Array:
	var inv := Profile.inv()
	if not inv.has("looks"):
		inv["looks"] = ["kindled"]
	return inv.looks


static func unlock(id: String) -> bool:
	if id == "" or not LOOKS.has(id) or unlocked().has(id):
		return false
	unlocked().append(id)
	return true


## The look in use: the wardrobe choice, or (when "") whatever the gear says.
static func current() -> String:
	var chosen := String(Profile.inv().get("look", ""))
	if chosen != "" and unlocked().has(chosen):
		return chosen
	return ItemDB.gear_look(Profile.equipped())


static func choose(id: String) -> void:
	Profile.inv()["look"] = id if id == "" or unlocked().has(id) else ""
	Profile.mark_changed()


## Source -> target colours for the palette swap.
static func swaps(id: String) -> Array:
	var l: Dictionary = LOOKS.get(id, LOOKS.kindled)
	var out: Array = []
	var cloak: Array = l.cloak
	for i in cloak.size():
		out.append([Pal.CLOAK[i], cloak[i]])
	var scarf: Array = l.scarf
	for i in scarf.size():
		out.append([Pal.EMBER[i + 1], scarf[i]])
	return out


## Writes a look into any material using the palette-swap uniforms. Sources are
## always matched in sRGB; 3D sprite shaders sample their atlas as source_color
## (linear), so their targets are written linear, menus work in sRGB.
static func apply_to(mat: ShaderMaterial, id: String, linear := false) -> void:
	var sw := swaps(id)
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	for i in 12:
		if i < sw.size():
			var a: Color = sw[i][0]
			var b: Color = sw[i][1]
			if linear:
				b = b.srgb_to_linear()
			from.append(Vector3(a.r, a.g, a.b))
			to.append(Vector3(b.r, b.g, b.b))
		else:
			from.append(Vector3(-1, -1, -1))
			to.append(Vector3.ZERO)
	mat.set_shader_parameter("swap_from", from)
	mat.set_shader_parameter("swap_to", to)
	mat.set_shader_parameter("swap_count", sw.size())


## The player sheet's material carries the current look.
static func apply_player(id: String) -> void:
	var info := SpriteLib.get_sheet("player")
	apply_to(info.material, id, true)


static var _canvas_shader: Shader

## A CanvasItem material with the look, for portraits in menus.
static func canvas_material(id: String) -> ShaderMaterial:
	if _canvas_shader == null:
		_canvas_shader = load("res://assets/shaders/palette_swap.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _canvas_shader
	apply_to(m, id)
	return m
