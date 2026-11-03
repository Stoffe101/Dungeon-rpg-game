## The Kindled Deep master palette.
## Every generated sprite, tile and UI element draws from these ramps so the
## whole game reads as one coherent piece of pixel art. Ramps run dark -> light.
extends RefCounted

const INK := Color8(11, 10, 18)          # outlines, deepest shadow
const VOID := Color8(20, 17, 30)

# Cool crypt stone
const STONE := [Color8(26, 24, 38), Color8(40, 39, 56), Color8(58, 60, 79), Color8(82, 88, 108), Color8(116, 124, 142), Color8(160, 168, 182)]
# Warm stone / earth
const EARTH := [Color8(38, 28, 30), Color8(60, 44, 42), Color8(88, 66, 58), Color8(120, 94, 78), Color8(156, 128, 102), Color8(196, 170, 136)]
# Bone / parchment
const BONE := [Color8(74, 62, 58), Color8(122, 106, 92), Color8(170, 154, 130), Color8(214, 202, 176), Color8(240, 234, 214)]
# Ember / fire
const EMBER := [Color8(74, 22, 24), Color8(140, 38, 30), Color8(204, 74, 38), Color8(240, 130, 52), Color8(255, 192, 88), Color8(255, 238, 170)]
# Spectral teal (souls, the Undervault's cold light)
const SOUL := [Color8(14, 40, 48), Color8(22, 76, 84), Color8(36, 122, 124), Color8(76, 184, 170), Color8(150, 236, 214), Color8(220, 255, 244)]
# Frost
const FROST := [Color8(22, 34, 66), Color8(36, 62, 112), Color8(62, 104, 168), Color8(110, 160, 214), Color8(176, 214, 240), Color8(234, 248, 255)]
# Gloam (shadow / curse purple)
const GLOAM := [Color8(30, 18, 44), Color8(56, 30, 76), Color8(92, 48, 112), Color8(140, 74, 150), Color8(196, 120, 196), Color8(236, 186, 236)]
# Moss / rot
const MOSS := [Color8(22, 34, 26), Color8(36, 56, 34), Color8(58, 86, 44), Color8(94, 124, 56), Color8(146, 170, 78), Color8(198, 214, 120)]
# Blood
const BLOOD := [Color8(54, 12, 26), Color8(98, 20, 38), Color8(156, 34, 50), Color8(214, 70, 76), Color8(246, 132, 120)]
# Gold
const GOLD := [Color8(70, 44, 18), Color8(122, 82, 26), Color8(186, 134, 40), Color8(232, 190, 70), Color8(255, 232, 140)]
# Steel
const STEEL := [Color8(30, 32, 44), Color8(54, 58, 74), Color8(88, 96, 116), Color8(132, 142, 160), Color8(184, 194, 206), Color8(232, 238, 244)]
# Player cloak (deep hearth-blue)
const CLOAK := [Color8(18, 22, 40), Color8(28, 38, 66), Color8(42, 60, 96), Color8(62, 88, 128), Color8(94, 124, 162)]
# Obsidian marble (the Sunken Throne)
const OBSIDIAN := [Color8(14, 11, 20), Color8(26, 21, 34), Color8(42, 35, 52), Color8(62, 54, 74), Color8(90, 80, 100), Color8(128, 118, 136)]
# Ash
const ASH := [Color8(34, 30, 34), Color8(58, 53, 56), Color8(90, 84, 84), Color8(130, 122, 118), Color8(176, 168, 158), Color8(222, 214, 200)]
# Wood
const WOOD := [Color8(40, 24, 22), Color8(70, 42, 32), Color8(104, 66, 44), Color8(140, 96, 60), Color8(178, 132, 86)]
# Skin / pale face under hood
const SKIN := [Color8(92, 60, 58), Color8(150, 104, 90), Color8(206, 160, 136), Color8(236, 204, 178)]

const WHITE := Color8(248, 244, 236)
const CLEAR := Color(0, 0, 0, 0)


static func ramp(r: Array, i: int) -> Color:
	return r[clampi(i, 0, r.size() - 1)]
