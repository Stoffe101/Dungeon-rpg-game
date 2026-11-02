## Gear and materials. Gear goes in six slots beside the weapon (head, chest,
## hands, feet, ring, charm); every piece is an instance of a base with a
## rarity, a level and rolled affixes. Materials drop in the Undervault and are
## spent at the blacksmith to craft and temper gear.
##
## Item instance: {uid, base, rarity: common|rare|epic|legendary, level, affixes: [[stat, op, v]]}
class_name ItemDB
extends RefCounted

const SLOTS := ["head", "chest", "hands", "feet", "ring", "charm"]
const SLOT_NAMES := {"head": "Head", "chest": "Chest", "hands": "Hands", "feet": "Feet", "ring": "Ring", "charm": "Charm", "weapon": "Weapon"}
const MAX_LEVEL := 5

const RARITY := {
	"common": {"name": "Common", "color": Color(0.82, 0.8, 0.76), "mult": 1.0, "affixes": 0, "value": 1.0},
	"rare": {"name": "Rare", "color": Color(0.45, 0.75, 1.0), "mult": 1.15, "affixes": 1, "value": 1.8},
	"epic": {"name": "Epic", "color": Color(0.82, 0.5, 1.0), "mult": 1.3, "affixes": 2, "value": 3.0},
	"legendary": {"name": "Legendary", "color": Color(1.0, 0.7, 0.25), "mult": 1.0, "affixes": 0, "value": 5.0},
}

const MATERIALS := {
	"bone_dust": {"name": "Bone Dust", "icon": "bone_dust", "desc": "Ground from the Ossuary's dead. The smith's flux.", "region": "ossuary"},
	"grave_iron": {"name": "Grave Iron", "icon": "grave_iron", "desc": "Black iron from old grave-guards' arms.", "region": "ossuary"},
	"soul_glass": {"name": "Soul Glass", "icon": "soul_glass", "desc": "Cold teal glass that hums. Bonecallers bleed it.", "region": "ossuary"},
	"rootwood": {"name": "Rootwood", "icon": "rootwood", "desc": "Living root from the Rootmire. Burns slow and hot.", "region": "rootmire"},
	"spore_silk": {"name": "Spore Silk", "icon": "spore_silk", "desc": "Light as breath, strong as wire.", "region": "rootmire"},
	"ember_core": {"name": "Ember Core", "icon": "ember_core", "desc": "A seed of the old sun, found in chests.", "region": ""},
	"warden_sigil": {"name": "Warden Sigil", "icon": "warden_sigil", "desc": "The Gloam Warden's seal. Masterwork catalyst.", "region": "ossuary"},
	"bloom_heart": {"name": "Bloom Heart", "icon": "bloom_heart", "desc": "Still beating. Masterwork catalyst.", "region": "rootmire"},
}

## Masterwork catalysts guarantee an epic when crafting.
const CATALYSTS := ["warden_sigil", "bloom_heart"]

const BASES := {
	# --- head ---
	"gravecloth_hood": {"name": "Gravecloth Hood", "slot": "head", "icon": "hood", "mods": [["max_hp", "add", 10.0], ["armor", "add", 0.02]],
		"recipe": {"bone_dust": 6, "embers": 40}},
	"grave_iron_helm": {"name": "Grave-Iron Helm", "slot": "head", "icon": "helm", "mods": [["armor", "add", 0.06], ["max_hp", "add", 6.0]],
		"recipe": {"grave_iron": 5, "bone_dust": 3, "embers": 80}},
	"soulglass_circlet": {"name": "Soulglass Circlet", "slot": "head", "icon": "circlet", "mods": [["kindle_max", "add", 12.0], ["ability_damage", "add", 0.06]],
		"recipe": {"soul_glass": 3, "grave_iron": 2, "embers": 120}},
	"rootweave_cowl": {"name": "Rootweave Cowl", "slot": "head", "icon": "cowl", "mods": [["max_hp", "add", 14.0], ["status_duration", "add", 0.08]],
		"recipe": {"rootwood": 6, "spore_silk": 2, "embers": 90}},
	# --- chest ---
	"gravecloth_robe": {"name": "Gravecloth Robe", "slot": "chest", "icon": "robe", "mods": [["max_hp", "add", 14.0], ["kindle_gain", "inc", 0.05]],
		"recipe": {"bone_dust": 8, "embers": 50}},
	"grave_iron_mail": {"name": "Grave-Iron Mail", "slot": "chest", "icon": "mail", "mods": [["armor", "add", 0.08], ["max_hp", "add", 10.0]],
		"recipe": {"grave_iron": 8, "bone_dust": 4, "embers": 110}},
	"sporesilk_coat": {"name": "Spore-Silk Coat", "slot": "chest", "icon": "coat", "mods": [["dodge_recharge", "more", -0.06], ["max_hp", "add", 8.0], ["move_speed", "inc", 0.03]],
		"recipe": {"spore_silk": 5, "rootwood": 4, "embers": 120}},
	# --- hands ---
	"bone_gauntlets": {"name": "Bone Gauntlets", "slot": "hands", "icon": "gauntlets", "mods": [["melee_damage", "add", 0.06], ["poise_damage", "add", 0.15]],
		"recipe": {"bone_dust": 6, "grave_iron": 2, "embers": 60}},
	"ember_gloves": {"name": "Ember Gloves", "slot": "hands", "icon": "gloves", "mods": [["fire_damage", "add", 0.08], ["burn_chance", "add", 0.05]],
		"recipe": {"ember_core": 2, "bone_dust": 4, "embers": 90}},
	"silk_wraps": {"name": "Silk Wraps", "slot": "hands", "icon": "wraps", "mods": [["attack_speed", "add", 0.05], ["crit_chance", "add", 0.02]],
		"recipe": {"spore_silk": 4, "embers": 100}},
	# --- feet ---
	"soft_boots": {"name": "Soft Boots", "slot": "feet", "icon": "boots", "mods": [["move_speed", "inc", 0.04], ["max_hp", "add", 4.0]],
		"recipe": {"bone_dust": 5, "embers": 40}},
	"iron_greaves": {"name": "Iron Greaves", "slot": "feet", "icon": "greaves", "mods": [["armor", "add", 0.05], ["max_hp", "add", 8.0]],
		"recipe": {"grave_iron": 5, "embers": 80}},
	"gloam_treads": {"name": "Gloam Treads", "slot": "feet", "icon": "treads", "mods": [["dodge_distance", "inc", 0.12], ["dodge_iframes", "add", 0.02]],
		"recipe": {"soul_glass": 2, "spore_silk": 3, "embers": 120}},
	# --- ring ---
	"ember_band": {"name": "Ember Band", "slot": "ring", "icon": "band", "mods": [["crit_chance", "add", 0.03], ["fire_damage", "add", 0.04]],
		"recipe": {"ember_core": 2, "grave_iron": 2, "embers": 100}},
	"frost_signet": {"name": "Frost Signet", "slot": "ring", "icon": "signet", "mods": [["frost_damage", "add", 0.08], ["chill_chance", "add", 0.05]],
		"recipe": {"soul_glass": 3, "embers": 100}},
	"wick_loop": {"name": "Wick Loop", "slot": "ring", "icon": "loop", "mods": [["kindle_gain", "inc", 0.1], ["kindle_max", "add", 6.0]],
		"recipe": {"rootwood": 3, "ember_core": 1, "embers": 90}},
	# --- charm ---
	"bone_totem": {"name": "Bone Totem", "slot": "charm", "icon": "totem", "mods": [["max_hp", "add", 12.0], ["thorns", "add", 4.0]],
		"recipe": {"bone_dust": 10, "embers": 60}},
	"spore_locket": {"name": "Spore Locket", "slot": "charm", "icon": "locket", "mods": [["flask_heal", "add", 0.05], ["life_on_kill", "add", 1.0]],
		"recipe": {"spore_silk": 3, "rootwood": 3, "embers": 110}},
	# --- legendary (boss drops, cannot be crafted) ---
	"gloamward_lantern": {"name": "Gloamward Lantern", "slot": "charm", "icon": "lantern_charm", "legendary": true,
		"mods": [["kindle_max", "add", 20.0], ["parry_window", "add", 0.04], ["ability_damage", "add", 0.1]],
		"desc": "Taken from the Gloam Warden. The light it holds will not be snuffed.", "salvage": {"warden_sigil": 1}},
	"bloom_crown": {"name": "Crown of the Hollow Bloom", "slot": "head", "icon": "bloom_crown", "legendary": true,
		"mods": [["fire_damage", "add", 0.15], ["burn_damage", "add", 0.3], ["max_hp", "add", 10.0]],
		"desc": "Petals that never stop smouldering.", "salvage": {"bloom_heart": 1}},
}

## Affixes rolled onto rare and epic pieces (values at level 1).
const AFFIXES := [
	["max_hp", "add", 8.0], ["armor", "add", 0.03], ["melee_damage", "add", 0.05], ["fire_damage", "add", 0.06],
	["frost_damage", "add", 0.06], ["crit_chance", "add", 0.02], ["attack_speed", "add", 0.04], ["move_speed", "inc", 0.03],
	["kindle_max", "add", 8.0], ["kindle_gain", "inc", 0.06], ["ability_damage", "add", 0.06], ["dodge_recharge", "more", -0.05],
]

## Bases that drop in each region (legendaries come only from bosses).
const REGION_BASES := {
	"ossuary": ["gravecloth_hood", "grave_iron_helm", "soulglass_circlet", "gravecloth_robe", "grave_iron_mail", "bone_gauntlets",
		"ember_gloves", "soft_boots", "iron_greaves", "ember_band", "frost_signet", "bone_totem"],
	"rootmire": ["rootweave_cowl", "sporesilk_coat", "silk_wraps", "gloam_treads", "wick_loop", "spore_locket", "ember_gloves", "soft_boots"],
}


static func base(id: String) -> Dictionary:
	return BASES.get(id, {})


static func craftable() -> Array:
	return BASES.keys().filter(func(k): return not BASES[k].get("legendary", false))


## A fresh item. Affixes are rolled from `rng` so drops are reproducible.
static func make_item(base_id: String, rarity: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var b := base(base_id)
	if b.get("legendary", false):
		rarity = "legendary"
	var affixes: Array = []
	var pool := AFFIXES.duplicate()
	for i in int(RARITY[rarity].affixes):
		if pool.is_empty():
			break
		var a: Array = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		affixes.append([a[0], a[1], float(a[2]) * rng.randf_range(0.8, 1.2)])
	return {"uid": 0, "base": base_id, "rarity": rarity, "level": clampi(level, 1, MAX_LEVEL), "affixes": affixes}


static func roll_rarity(rng: RandomNumberGenerator, luck := 0.0) -> String:
	var r := rng.randf() - luck
	if r < 0.12:
		return "epic"
	if r < 0.45:
		return "rare"
	return "common"


## Every modifier the item grants (base scaled by level and rarity, plus affixes).
static func mods_of(item: Dictionary) -> Array:
	var b := base(String(item.get("base", "")))
	if b.is_empty():
		return []
	var lvl_k := 1.0 + 0.12 * (int(item.get("level", 1)) - 1)
	var rar_k := float(RARITY.get(item.get("rarity", "common"), RARITY.common).mult)
	var out: Array = []
	for m in b.mods:
		out.append([m[0], m[1], float(m[2]) * lvl_k * rar_k])
	for a in item.get("affixes", []):
		out.append([a[0], a[1], float(a[2]) * lvl_k])
	return out


static func apply_equipped(equipped: Dictionary, stats: Stats) -> void:
	for slot in SLOTS:
		var it: Variant = equipped.get(slot)
		if it is Dictionary and not (it as Dictionary).is_empty():
			stats.apply_mods(mods_of(it))


static func item_name(item: Dictionary) -> String:
	var n := String(base(String(item.get("base", ""))).get("name", "?"))
	var lvl := int(item.get("level", 1))
	return n if lvl <= 1 else "%s +%d" % [n, lvl - 1]


static func color(item: Dictionary) -> Color:
	return RARITY.get(item.get("rarity", "common"), RARITY.common).color


static func icon(item: Dictionary) -> String:
	return String(base(String(item.get("base", ""))).get("icon", "bag"))


## Embers the peddler pays (and charges twice that).
static func value(item: Dictionary) -> int:
	var b := base(String(item.get("base", "")))
	var e := float(b.get("recipe", {}).get("embers", 150))
	return int(round(e * float(RARITY[item.get("rarity", "common")].value) * (1.0 + 0.3 * (int(item.get("level", 1)) - 1)) * 0.5))


# --- the blacksmith -----------------------------------------------------------

static func recipe(base_id: String) -> Dictionary:
	return base(base_id).get("recipe", {})


## Crafting rolls a rarity; a catalyst (Warden Sigil or Bloom Heart) makes it epic.
static func craft(base_id: String, rng: RandomNumberGenerator, masterwork := false, forge_level := 1) -> Dictionary:
	var rar := "epic" if masterwork else roll_rarity(rng, 0.04 * (forge_level - 1))
	return make_item(base_id, rar, 1, rng)


static func temper_cost(item: Dictionary) -> Dictionary:
	var lvl := int(item.get("level", 1))
	var out := {}
	var rec := recipe(String(item.base))
	for k in rec:
		if k != "embers":
			out[k] = maxi(1, int(ceil(int(rec[k]) * 0.5)))
	if rec.is_empty():
		# legendaries temper with their own catalyst
		for k in base(String(item.base)).get("salvage", {}):
			out[k] = 1
	out["embers"] = 60 * lvl
	return out


## What breaking an item down returns: half its recipe (at least one of the main
## material), or a legendary's catalyst.
static func salvage_yield(item: Dictionary) -> Dictionary:
	var b := base(String(item.get("base", "")))
	if b.has("salvage"):
		return (b.salvage as Dictionary).duplicate()
	var out := {}
	for k in b.get("recipe", {}):
		if k != "embers":
			out[k] = maxi(1, int(floor(int(b.recipe[k]) * 0.5)))
	if item.get("rarity", "common") == "epic":
		out["ember_core"] = int(out.get("ember_core", 0)) + 1
	return out


# --- drops ---------------------------------------------------------------------

## Materials an enemy can drop: [[material, chance, min, max], ...]
static func enemy_drops(enemy_id: String, region: String) -> Array:
	var out: Array = []
	if region == "rootmire":
		out.append(["rootwood", 0.25, 1, 2])
	else:
		out.append(["bone_dust", 0.28, 1, 2])
	match enemy_id:
		"guard":
			out.append(["grave_iron", 0.4, 1, 2])
		"husk", "skitter":
			out.append(["grave_iron", 0.05, 1, 1])
		"bonecaller":
			out.append(["soul_glass", 0.4, 1, 1])
		"archer":
			out.append(["soul_glass", 0.08, 1, 1])
		"moth", "sporeling":
			out.append(["spore_silk", 0.3, 1, 1])
		"thornback", "rootweaver":
			out.append(["spore_silk", 0.15, 1, 1])
			out.append(["rootwood", 0.2, 1, 1])
	return out


## A random piece of gear for a region and depth.
static func random_drop(region: String, depth: int, rng: RandomNumberGenerator, luck := 0.0) -> Dictionary:
	var pool: Array = REGION_BASES.get(region, REGION_BASES.ossuary)
	var b: String = pool[rng.randi_range(0, pool.size() - 1)]
	return make_item(b, roll_rarity(rng, luck), clampi(depth, 1, MAX_LEVEL), rng)


## A test stockpile so crafting can be tried right away (see Profile.TEST_STOCKPILE).
static func stockpile() -> Dictionary:
	var out := {}
	for k in MATERIALS:
		out[k] = 6 if k in CATALYSTS else 60
	return out
