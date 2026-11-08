## What each thing in the world is made of, in one table: the rule the art follows and
## the audit checks (tests/test_world_depth.gd, `-- showcol`).
##   GROUND  you walk through it: low, thin, no outline, no shadow of its own.
##   SOLID   it stops you: a visible foot filling its tile, an outline, it does not sway.
##   BREAK   it stops you until it is broken, and shows where.
##   USE     it does something (a label and a glow say so).
##   HAZARD  it hurts you: an honest shape, a warning, and its danger is what you see.
##   FIXTURE it is on a wall.
class_name Physical
extends RefCounted

enum Cls {GROUND, SOLID, BREAK, USE, HAZARD, FIXTURE}

const OF := {
	"decal": Cls.GROUND, "scar": Cls.GROUND, "rug": Cls.GROUND, "candles": Cls.GROUND, "ember_pile": Cls.USE,
	"stairs": Cls.USE, "cold_lantern": Cls.USE, "echo": Cls.USE,
	"torch": Cls.FIXTURE, "banner": Cls.FIXTURE,
	"thicket": Cls.SOLID, "tree": Cls.SOLID, "glowcap": Cls.SOLID, "icewall": Cls.SOLID,
	"bramble": Cls.BREAK, "root_node": Cls.BREAK, "strut": Cls.BREAK, "kindle_jar": Cls.BREAK, "boss_brazier": Cls.BREAK,
	"urn": Cls.BREAK,
	"chest": Cls.USE, "relic_altar": Cls.USE, "spring": Cls.USE, "shrine": Cls.USE, "merchant": Cls.USE, "fountain": Cls.USE,
	"hearthstone": Cls.USE, "lore": Cls.USE, "ember_well": Cls.USE, "trial_altar": Cls.USE, "lamp": Cls.USE, "rubble": Cls.USE,
	"lever": Cls.USE, "lock_plate": Cls.USE, "key_altar": Cls.USE, "sconce": Cls.USE, "brazier": Cls.USE,
	"spikes": Cls.HAZARD, "rime_vent": Cls.HAZARD,
}

## Kinds that do not stop you, on purpose. An urn is the one thing here that looks solid
## and is not: it breaks when you walk into it.
const WALK_THROUGH := ["decal", "scar", "rug", "candles", "ember_pile", "stairs", "cold_lantern", "echo", "torch", "banner", "spikes", "rime_vent", "urn"]

## Above this many texels a thing standing on the floor is not ground cover.
const GROUND_MAX_H := 13
## At its foot a solid thing covers at least this much of its 16-texel tile...
const FOOT_MIN := 10
## ...and spreads no wider than this over the tiles beside it.
const FOOT_MAX := 28


## What a drawing really occupies (first frame of `anim`): its height and width and the
## width of its lowest four rows. {"h", "w", "foot"}.
static func art_of(sheet_name: String, anim := "") -> Dictionary:
	var info := SpriteLib.get_sheet(sheet_name)
	var img := info.texture.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var row := 0
	if anim != "" and info.anims.has(anim):
		row = int(info.anims[anim].row)
	var fw := info.frame_size.x
	var fh := info.frame_size.y
	var y0 := row * fh
	var top := fh
	var bottom := -1
	var left := fw
	var right := -1
	for y in fh:
		for x in fw:
			if img.get_pixel(x, y0 + y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
				left = mini(left, x)
				right = maxi(right, x)
	var fl := fw
	var fr := -1
	for y in range(maxi(0, bottom - 3), bottom + 1):
		for x in fw:
			if img.get_pixel(x, y0 + y).a > 0.5:
				fl = mini(fl, x)
				fr = maxi(fr, x)
	return {"h": bottom - top + 1, "w": right - left + 1, "foot": fr - fl + 1}
