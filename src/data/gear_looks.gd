## How each piece of armour looks on the Kindled: its drawn style, its
## material (a palette ramp) and an accent. tools/art/gen_gear.gd draws one
## overlay sheet per base from this table ("gear_<base>"), on the same poses as
## the body; Player layers them over the body at run time.
class_name GearLooks
extends RefCounted

## base id -> [style, material ramp, accent ramp, variant]
const VIS := {
	# head
	"gravecloth_hood": ["hood", "ASH", "BONE", ""],
	"grave_iron_helm": ["helm", "STEEL", "STEEL", ""],
	"soulglass_circlet": ["circlet", "STEEL", "SOUL", ""],
	"rootweave_cowl": ["hood", "MOSS", "WOOD", "cowl"],
	"miners_cap": ["cap", "WOOD", "GOLD", "miner"],
	"plague_mask": ["mask", "BONE", "SOUL", ""],
	"horned_helm": ["helm", "STEEL", "BONE", "horned"],
	"fools_cap": ["cap", "BLOOD", "GOLD", "fool"],
	"emberwrought_helm": ["helm", "BLOOD", "EMBER", "ember"],
	"rimeguard_helm": ["helm", "FROST", "FROST", "visor"],
	"gloamweave_hood": ["hood", "GLOAM", "GLOAM", "gloam"],
	"verdant_cowl": ["hood", "MOSS", "MOSS", "cowl"],
	"spellweaver_circlet": ["circlet", "GOLD", "GLOAM", "big"],
	"featherfall_hood": ["hood", "BONE", "BONE", "feather"],
	"crown_of_embers": ["crown", "GOLD", "EMBER", ""],
	"bloom_crown": ["crown", "MOSS", "BLOOD", "bloom"],
	# chest
	"gravecloth_robe": ["robe", "ASH", "BONE", ""],
	"grave_iron_mail": ["mail", "STEEL", "EARTH", ""],
	"sporesilk_coat": ["coat", "MOSS", "BONE", ""],
	"tattered_cloak": ["cloak", "EARTH", "STEEL", "tattered"],
	"pilgrim_vestments": ["robe", "BONE", "GOLD", "pilgrim"],
	"scale_hauberk": ["mail", "STEEL", "EARTH", "scale"],
	"emberwrought_plate": ["plate", "BLOOD", "EMBER", "ember"],
	"rimeguard_mail": ["mail", "FROST", "FROST", "rime"],
	"gloamweave_cloak": ["cloak", "GLOAM", "GLOAM", "stars"],
	"verdant_robe": ["robe", "WOOD", "MOSS", "bark"],
	"heart_of_the_mountain": ["plate", "STONE", "EMBER", "mountain"],
	"berserkers_mantle": ["cloak", "BLOOD", "BONE", "fur"],
	"mothwing_cloak": ["cloak", "ASH", "GOLD", "moth"],
	"thornmail": ["mail", "MOSS", "WOOD", "thorn"],
	"sunfall_mantle": ["cloak", "GOLD", "GOLD", "sunfall"],
	"counterpoise": ["mail", "STEEL", "GOLD", "scale"],
	# hands
	"bone_gauntlets": ["gauntlets", "BONE", "BONE", ""],
	"ember_gloves": ["gloves", "EMBER", "EMBER", ""],
	"silk_wraps": ["wraps", "BONE", "MOSS", ""],
	"duelist_gloves": ["gloves", "BLOOD", "GOLD", ""],
	"mitts_of_haste": ["gloves", "GOLD", "GOLD", "haste"],
	"sigil_bracers": ["bracers", "STEEL", "SOUL", ""],
	"emberwrought_gauntlets": ["gauntlets", "BLOOD", "EMBER", "glow"],
	"rimeguard_gauntlets": ["gauntlets", "FROST", "FROST", ""],
	"gloamweave_wraps": ["wraps", "GLOAM", "GLOAM", ""],
	"verdant_gloves": ["gloves", "MOSS", "MOSS", ""],
	"echoing_gauntlets": ["gauntlets", "STEEL", "SOUL", "glow"],
	"firebrand_gauntlets": ["gauntlets", "OBSIDIAN", "EMBER", "glow"],
	"mirrorguard_bracers": ["bracers", "FROST", "BONE", "mirror"],
	# feet
	"soft_boots": ["boots", "EARTH", "EARTH", ""],
	"iron_greaves": ["greaves", "STEEL", "STEEL", ""],
	"gloam_treads": ["treads", "CLOAK", "GLOAM", ""],
	"sprinter_sandals": ["sandals", "WOOD", "GOLD", ""],
	"mud_waders": ["waders", "MOSS", "EARTH", ""],
	"dancer_slippers": ["sandals", "BLOOD", "GOLD", "slipper"],
	"emberwrought_greaves": ["greaves", "BLOOD", "EMBER", ""],
	"rimeguard_boots": ["greaves", "FROST", "FROST", ""],
	"gloamweave_treads": ["treads", "GLOAM", "GLOAM", ""],
	"verdant_boots": ["boots", "MOSS", "WOOD", ""],
	"seven_league_boots": ["boots", "EARTH", "BONE", "winged"],
	"long_way_greaves": ["greaves", "EARTH", "GOLD", ""],
	"squeaky_clogs": ["clogs", "WOOD", "GOLD", ""],
	"sandals_of_still_time": ["sandals", "GOLD", "SOUL", "glow"],
}

## Drawn back to front over the body.
const LAYERS := ["feet", "chest", "hands", "head"]


## The figure's layers for a menu portrait (first frame of the given pose).
static func portrait_layers(equipped: Dictionary, shown: Dictionary, anim := "idle_down") -> Array:
	var out: Array = []
	var doll := paperdoll(equipped, shown)
	for slot in LAYERS:
		if not doll.has(slot):
			continue
		var info := SpriteLib.get_sheet(String(doll[slot]))
		if info == null:
			continue
		var a: Dictionary = info.anims.get(anim, info.anims.values()[0])
		var t := AtlasTexture.new()
		t.atlas = info.texture
		t.region = Rect2(0, float(a.row) * info.frame_size.y, info.frame_size.x, info.frame_size.y)
		out.append(t)
	return out


static func sheet_for(base_id: String) -> String:
	return "gear_" + base_id if VIS.has(base_id) else ""


## Which overlay sheet each slot shows, from equipped items and the wardrobe's
## per-slot choices ({slot: base id to show, or "none" to show nothing}).
static func paperdoll(equipped: Dictionary, shown: Dictionary) -> Dictionary:
	var out := {}
	for slot in LAYERS:
		var pick := String(shown.get(slot, ""))
		if pick == "none":
			continue
		var base := pick
		if base == "":
			var it: Variant = equipped.get(slot)
			if it is Dictionary and not (it as Dictionary).is_empty():
				base = String(it.get("base", ""))
		var sh := sheet_for(base)
		if sh != "":
			out[slot] = sh
	return out
