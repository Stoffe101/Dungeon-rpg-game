## Gear and materials. Gear goes in six slots beside the weapon (head, chest,
## hands, feet, ring, charm); every piece is an instance of a base with a
## rarity, a level, a tier and rolled affixes. Materials drop in the Undervault
## and are spent at the blacksmith to craft and temper gear.
##
## Item instance: {uid, base, rarity, level (1-5, tempering), tier (difficulty it
## dropped at), affixes: [[stat, op, v]]}
## Base kinds: plain bases (craftable), set pieces (drop at Tier II+; bonuses at
## 2 and 4 pieces), uniques (learned from blueprints, with special mechanics),
## and boss legendaries.
class_name ItemDB
extends RefCounted

const SLOTS := ["head", "chest", "hands", "feet", "ring", "charm"]
const SLOT_NAMES := {"head": "Head", "chest": "Chest", "hands": "Hands", "feet": "Feet", "ring": "Ring", "charm": "Charm", "weapon": "Weapon"}
const MAX_LEVEL := 5
const MAX_TIER := 8

const RARITY := {
	"common": {"name": "Common", "color": Color(0.82, 0.8, 0.76), "mult": 1.0, "affixes": 0, "value": 1.0},
	"rare": {"name": "Rare", "color": Color(0.45, 0.75, 1.0), "mult": 1.15, "affixes": 1, "value": 1.8},
	"epic": {"name": "Epic", "color": Color(0.82, 0.5, 1.0), "mult": 1.3, "affixes": 2, "value": 3.0},
	"set": {"name": "Set", "color": Color(0.45, 1.0, 0.5), "mult": 1.25, "affixes": 1, "value": 4.0},
	"legendary": {"name": "Legendary", "color": Color(1.0, 0.62, 0.2), "mult": 1.0, "affixes": 0, "value": 5.0},
}

const MATERIALS := {
	"bone_dust": {"name": "Bone Dust", "icon": "bone_dust", "desc": "Ground from the Ossuary's dead. The smith's flux.", "region": "ossuary"},
	"grave_iron": {"name": "Grave Iron", "icon": "grave_iron", "desc": "Black iron from old grave-guards' arms.", "region": "ossuary"},
	"soul_glass": {"name": "Soul Glass", "icon": "soul_glass", "desc": "Cold teal glass that hums. Bonecallers bleed it.", "region": "ossuary"},
	"rootwood": {"name": "Rootwood", "icon": "rootwood", "desc": "Living root from the Rootmire. Burns slow and hot.", "region": "rootmire"},
	"spore_silk": {"name": "Spore Silk", "icon": "spore_silk", "desc": "Light as breath, strong as wire.", "region": "rootmire"},
	"sun_gold": {"name": "Sun Gold", "icon": "sun_gold", "desc": "Gold from the drowned throne, still warm.", "region": "throne"},
	"ember_core": {"name": "Ember Core", "icon": "ember_core", "desc": "A seed of the old sun, found in chests.", "region": ""},
	"warden_sigil": {"name": "Warden Sigil", "icon": "warden_sigil", "desc": "The Gloam Warden's seal. Masterwork catalyst.", "region": "ossuary"},
	"bloom_heart": {"name": "Bloom Heart", "icon": "bloom_heart", "desc": "Still beating. Masterwork catalyst.", "region": "rootmire"},
	"eclipse_shard": {"name": "Eclipse Shard", "icon": "eclipse_shard", "desc": "A sliver of the dead sun's last eclipse. Masterwork catalyst.", "region": "throne"},
}

## Masterwork catalysts guarantee an epic when crafting.
const CATALYSTS := ["warden_sigil", "bloom_heart", "eclipse_shard"]

## Tier sets: wear 2 / 4 pieces for the bonuses. `look` recolours the Kindled.
const SETS := {
	"emberwrought": {"name": "Emberwrought", "color": Color(1.0, 0.62, 0.25), "look": "emberwrought",
		"blurb": "Gold-chased plate from the Hearth's first forge.",
		2: {"mods": [["fire_damage", "add", 0.2], ["burn_chance", "add", 0.1]], "desc": "+20% fire damage, +10% chance to Burn."},
		4: {"flags": {"ember_set4": 1}, "desc": "Every melee hit Burns. Burning enemies take 25% more damage from you."}},
	"rimeguard": {"name": "Rimeguard", "color": Color(0.6, 0.85, 1.0), "look": "rimeguard",
		"blurb": "Frost-silvered mail of the wardens who held the cold gate.",
		2: {"mods": [["armor", "add", 0.1], ["chill_chance", "add", 0.2]], "desc": "+10% armor, +20% chance to Chill."},
		4: {"flags": {"rime_set4": 1}, "desc": "A successful Ward freezes nearby attackers and grants a 30-point barrier. Take 15% less damage from chilled or frozen enemies."}},
	"gloamweave": {"name": "Gloamweave", "color": Color(0.78, 0.5, 1.0), "look": "gloamweave",
		"blurb": "Shadow-spun cloth that drinks the light around it.",
		2: {"mods": [["dodge_charges", "add", 1.0], ["dodge_recharge", "more", -0.15]], "desc": "+1 dodge charge, dodges recharge 15% faster."},
		4: {"flags": {"gloam_set4": 1}, "desc": "For 2s after a dodge your hits are critical and deal 30% more damage. Perfect dodges reset your ability cooldowns."}},
	"verdant": {"name": "Verdant Warden", "color": Color(0.55, 0.95, 0.45), "look": "verdant",
		"blurb": "Living bark and bone, grown rather than made.",
		2: {"mods": [["max_hp", "add", 40.0], ["flask_heal", "add", 0.15]], "desc": "+40 maximum health, flasks heal 15% more."},
		4: {"flags": {"verdant_set4": 1}, "desc": "Kills heal 3% of your health and burst into spores that poison enemies nearby."}},
}

const BASES := {
	# ================= plain gear (craftable) =================
	# --- head ---
	"gravecloth_hood": {"name": "Gravecloth Hood", "slot": "head", "icon": "hood", "mods": [["max_hp", "add", 10.0], ["armor", "add", 0.02]],
		"recipe": {"bone_dust": 6, "embers": 40}},
	"grave_iron_helm": {"name": "Grave-Iron Helm", "slot": "head", "icon": "helm", "mods": [["armor", "add", 0.06], ["max_hp", "add", 6.0]],
		"recipe": {"grave_iron": 5, "bone_dust": 3, "embers": 80}},
	"soulglass_circlet": {"name": "Soulglass Circlet", "slot": "head", "icon": "circlet", "mods": [["kindle_max", "add", 12.0], ["ability_damage", "add", 0.06]],
		"recipe": {"soul_glass": 3, "grave_iron": 2, "embers": 120}},
	"rootweave_cowl": {"name": "Rootweave Cowl", "slot": "head", "icon": "cowl", "mods": [["max_hp", "add", 14.0], ["status_duration", "add", 0.08]],
		"recipe": {"rootwood": 6, "spore_silk": 2, "embers": 90}},
	"miners_cap": {"name": "Miner's Lamp Cap", "slot": "head", "icon": "lampcap", "mods": [["kindle_max", "add", 10.0], ["ember_gain", "add", 0.08]],
		"recipe": {"grave_iron": 3, "ember_core": 1, "embers": 70}},
	"plague_mask": {"name": "Plague Mask", "slot": "head", "icon": "plague_mask", "mods": [["status_duration", "add", 0.12], ["burn_damage", "add", 0.15]],
		"recipe": {"bone_dust": 5, "spore_silk": 2, "embers": 90}},
	"horned_helm": {"name": "Horned Helm", "slot": "head", "icon": "horned", "mods": [["melee_damage", "add", 0.07], ["poise_damage", "add", 0.2]],
		"recipe": {"grave_iron": 6, "bone_dust": 4, "embers": 110}},
	"fools_cap": {"name": "Fool's Cap", "slot": "head", "icon": "fools_cap", "mods": [["crit_chance", "add", 0.06], ["armor", "add", -0.03]],
		"recipe": {"spore_silk": 3, "ember_core": 1, "embers": 60}, "desc": "Jingles when you run. Somehow, it helps."},
	# --- chest ---
	"gravecloth_robe": {"name": "Gravecloth Robe", "slot": "chest", "icon": "robe", "mods": [["max_hp", "add", 14.0], ["kindle_gain", "inc", 0.05]],
		"recipe": {"bone_dust": 8, "embers": 50}},
	"grave_iron_mail": {"name": "Grave-Iron Mail", "slot": "chest", "icon": "mail", "mods": [["armor", "add", 0.08], ["max_hp", "add", 10.0]],
		"recipe": {"grave_iron": 8, "bone_dust": 4, "embers": 110}},
	"sporesilk_coat": {"name": "Spore-Silk Coat", "slot": "chest", "icon": "coat", "mods": [["dodge_recharge", "more", -0.06], ["max_hp", "add", 8.0], ["move_speed", "inc", 0.03]],
		"recipe": {"spore_silk": 5, "rootwood": 4, "embers": 120}},
	"tattered_cloak": {"name": "Tattered Cloak", "slot": "chest", "icon": "cloak", "mods": [["move_speed", "inc", 0.06], ["dodge_recharge", "more", -0.05]],
		"recipe": {"bone_dust": 5, "spore_silk": 1, "embers": 60}},
	"pilgrim_vestments": {"name": "Pilgrim's Vestments", "slot": "chest", "icon": "vestments", "mods": [["flask_heal", "add", 0.08], ["max_hp", "add", 10.0]],
		"recipe": {"bone_dust": 6, "ember_core": 1, "embers": 90}},
	"scale_hauberk": {"name": "Scale Hauberk", "slot": "chest", "icon": "scale", "mods": [["armor", "add", 0.07], ["thorns", "add", 6.0]],
		"recipe": {"grave_iron": 6, "rootwood": 3, "embers": 120}},
	# --- hands ---
	"bone_gauntlets": {"name": "Bone Gauntlets", "slot": "hands", "icon": "gauntlets", "mods": [["melee_damage", "add", 0.06], ["poise_damage", "add", 0.15]],
		"recipe": {"bone_dust": 6, "grave_iron": 2, "embers": 60}},
	"ember_gloves": {"name": "Ember Gloves", "slot": "hands", "icon": "gloves", "mods": [["fire_damage", "add", 0.08], ["burn_chance", "add", 0.05]],
		"recipe": {"ember_core": 2, "bone_dust": 4, "embers": 90}},
	"silk_wraps": {"name": "Silk Wraps", "slot": "hands", "icon": "wraps", "mods": [["attack_speed", "add", 0.05], ["crit_chance", "add", 0.02]],
		"recipe": {"spore_silk": 4, "embers": 100}},
	"duelist_gloves": {"name": "Duelist's Gloves", "slot": "hands", "icon": "duelist", "mods": [["crit_mult", "add", 0.25]],
		"recipe": {"spore_silk": 2, "grave_iron": 2, "embers": 110}},
	"mitts_of_haste": {"name": "Mitts of Haste", "slot": "hands", "icon": "haste_mitts", "mods": [["attack_speed", "add", 0.08]],
		"recipe": {"spore_silk": 3, "soul_glass": 1, "embers": 120}},
	"sigil_bracers": {"name": "Sigil Bracers", "slot": "hands", "icon": "bracers", "mods": [["ability_damage", "add", 0.08], ["cooldown", "more", -0.06]],
		"recipe": {"soul_glass": 3, "rootwood": 2, "embers": 120}},
	# --- feet ---
	"soft_boots": {"name": "Soft Boots", "slot": "feet", "icon": "boots", "mods": [["move_speed", "inc", 0.04], ["max_hp", "add", 4.0]],
		"recipe": {"bone_dust": 5, "embers": 40}},
	"iron_greaves": {"name": "Iron Greaves", "slot": "feet", "icon": "greaves", "mods": [["armor", "add", 0.05], ["max_hp", "add", 8.0]],
		"recipe": {"grave_iron": 5, "embers": 80}},
	"gloam_treads": {"name": "Gloam Treads", "slot": "feet", "icon": "treads", "mods": [["dodge_distance", "inc", 0.12], ["dodge_iframes", "add", 0.02]],
		"recipe": {"soul_glass": 2, "spore_silk": 3, "embers": 120}},
	"sprinter_sandals": {"name": "Sprinter's Sandals", "slot": "feet", "icon": "sandals", "mods": [["move_speed", "inc", 0.08]],
		"recipe": {"rootwood": 3, "bone_dust": 2, "embers": 70}},
	"mud_waders": {"name": "Mud Waders", "slot": "feet", "icon": "waders", "mods": [["armor", "add", 0.03], ["max_hp", "add", 12.0]],
		"recipe": {"rootwood": 4, "spore_silk": 1, "embers": 70}},
	"dancer_slippers": {"name": "Dancer's Slippers", "slot": "feet", "icon": "slippers", "mods": [["dodge_iframes", "add", 0.03], ["dodge_recharge", "more", -0.08]],
		"recipe": {"spore_silk": 3, "soul_glass": 1, "embers": 110}},
	# --- ring ---
	"ember_band": {"name": "Ember Band", "slot": "ring", "icon": "band", "mods": [["crit_chance", "add", 0.03], ["fire_damage", "add", 0.04]],
		"recipe": {"ember_core": 2, "grave_iron": 2, "embers": 100}},
	"frost_signet": {"name": "Frost Signet", "slot": "ring", "icon": "signet", "mods": [["frost_damage", "add", 0.08], ["chill_chance", "add", 0.05]],
		"recipe": {"soul_glass": 3, "embers": 100}},
	"wick_loop": {"name": "Wick Loop", "slot": "ring", "icon": "loop", "mods": [["kindle_gain", "inc", 0.1], ["kindle_max", "add", 6.0]],
		"recipe": {"rootwood": 3, "ember_core": 1, "embers": 90}},
	"clover_ring": {"name": "Four-Leaf Ring", "slot": "ring", "icon": "clover_ring", "mods": [["ember_gain", "add", 0.15], ["xp_gain", "add", 0.1]],
		"recipe": {"rootwood": 2, "ember_core": 2, "embers": 100}, "desc": "Lucky. Probably."},
	"thorn_ring": {"name": "Ring of Thorns", "slot": "ring", "icon": "thorn_ring", "mods": [["thorns", "add", 8.0], ["armor", "add", 0.02]],
		"recipe": {"rootwood": 4, "grave_iron": 1, "embers": 90}},
	"focus_band": {"name": "Band of Focus", "slot": "ring", "icon": "focus_band", "mods": [["kindle_gain", "inc", 0.12], ["ability_cost", "more", -0.05]],
		"recipe": {"soul_glass": 2, "ember_core": 1, "embers": 110}},
	# --- charm ---
	"bone_totem": {"name": "Bone Totem", "slot": "charm", "icon": "totem", "mods": [["max_hp", "add", 12.0], ["thorns", "add", 4.0]],
		"recipe": {"bone_dust": 10, "embers": 60}},
	"spore_locket": {"name": "Spore Locket", "slot": "charm", "icon": "locket", "mods": [["flask_heal", "add", 0.05], ["life_on_kill", "add", 1.0]],
		"recipe": {"spore_silk": 3, "rootwood": 3, "embers": 110}},
	"rabbits_foot": {"name": "Rabbit's Foot", "slot": "charm", "icon": "rabbit_foot", "mods": [["crit_chance", "add", 0.04], ["ember_gain", "add", 0.1]],
		"recipe": {"bone_dust": 4, "spore_silk": 2, "embers": 80}, "desc": "Less lucky for the rabbit."},
	"hourglass_pendant": {"name": "Hourglass Pendant", "slot": "charm", "icon": "hourglass_charm", "mods": [["cooldown", "more", -0.1]],
		"recipe": {"soul_glass": 2, "sun_gold": 1, "embers": 130}},
	"warding_idol": {"name": "Warding Idol", "slot": "charm", "icon": "idol", "mods": [["parry_window", "add", 0.03], ["armor", "add", 0.02]],
		"recipe": {"grave_iron": 3, "soul_glass": 2, "embers": 110}},
	"sunburst_brooch": {"name": "Sunburst Brooch", "slot": "charm", "icon": "brooch", "mods": [["damage", "add", 0.06]],
		"recipe": {"sun_gold": 3, "ember_core": 1, "embers": 160}},

	# ================= tier sets (drop at Tier II and up) =================
	"emberwrought_helm": {"name": "Emberwrought Helm", "slot": "head", "icon": "ew_helm", "set": "emberwrought", "mods": [["max_hp", "add", 10.0], ["fire_damage", "add", 0.05]]},
	"emberwrought_plate": {"name": "Emberwrought Plate", "slot": "chest", "icon": "ew_plate", "set": "emberwrought", "mods": [["armor", "add", 0.05], ["max_hp", "add", 16.0]]},
	"emberwrought_gauntlets": {"name": "Emberwrought Gauntlets", "slot": "hands", "icon": "ew_gauntlets", "set": "emberwrought", "mods": [["fire_damage", "add", 0.06], ["melee_damage", "add", 0.04]]},
	"emberwrought_greaves": {"name": "Emberwrought Greaves", "slot": "feet", "icon": "ew_greaves", "set": "emberwrought", "mods": [["move_speed", "inc", 0.03], ["armor", "add", 0.03]]},
	"emberwrought_signet": {"name": "Emberwrought Signet", "slot": "ring", "icon": "ew_signet", "set": "emberwrought", "mods": [["fire_damage", "add", 0.06], ["burn_chance", "add", 0.05]]},
	"rimeguard_helm": {"name": "Rimeguard Visor", "slot": "head", "icon": "rg_helm", "set": "rimeguard", "mods": [["armor", "add", 0.04], ["max_hp", "add", 8.0]]},
	"rimeguard_mail": {"name": "Rimeguard Hauberk", "slot": "chest", "icon": "rg_mail", "set": "rimeguard", "mods": [["armor", "add", 0.07], ["max_hp", "add", 12.0]]},
	"rimeguard_gauntlets": {"name": "Rimeguard Gauntlets", "slot": "hands", "icon": "rg_gauntlets", "set": "rimeguard", "mods": [["frost_damage", "add", 0.08], ["parry_window", "add", 0.02]]},
	"rimeguard_boots": {"name": "Rimeguard Sabatons", "slot": "feet", "icon": "rg_boots", "set": "rimeguard", "mods": [["armor", "add", 0.04], ["chill_power", "add", 0.06]]},
	"rimeguard_band": {"name": "Rimeguard Band", "slot": "ring", "icon": "rg_band", "set": "rimeguard", "mods": [["frost_damage", "add", 0.06], ["max_hp", "add", 8.0]]},
	"gloamweave_hood": {"name": "Gloamweave Hood", "slot": "head", "icon": "gw_hood", "set": "gloamweave", "mods": [["crit_chance", "add", 0.03], ["dodge_distance", "inc", 0.06]]},
	"gloamweave_cloak": {"name": "Gloamweave Cloak", "slot": "chest", "icon": "gw_cloak", "set": "gloamweave", "mods": [["move_speed", "inc", 0.05], ["max_hp", "add", 8.0]]},
	"gloamweave_wraps": {"name": "Gloamweave Wraps", "slot": "hands", "icon": "gw_wraps", "set": "gloamweave", "mods": [["attack_speed", "add", 0.05], ["crit_mult", "add", 0.15]]},
	"gloamweave_treads": {"name": "Gloamweave Treads", "slot": "feet", "icon": "gw_treads", "set": "gloamweave", "mods": [["dodge_iframes", "add", 0.03], ["move_speed", "inc", 0.04]]},
	"gloamweave_locket": {"name": "Gloamweave Locket", "slot": "charm", "icon": "gw_locket", "set": "gloamweave", "mods": [["crit_chance", "add", 0.04]]},
	"verdant_cowl": {"name": "Verdant Cowl", "slot": "head", "icon": "vd_cowl", "set": "verdant", "mods": [["max_hp", "add", 14.0]]},
	"verdant_robe": {"name": "Verdant Bark-Robe", "slot": "chest", "icon": "vd_robe", "set": "verdant", "mods": [["max_hp", "add", 20.0], ["armor", "add", 0.03]]},
	"verdant_gloves": {"name": "Verdant Gloves", "slot": "hands", "icon": "vd_gloves", "set": "verdant", "mods": [["life_on_kill", "add", 2.0], ["melee_damage", "add", 0.04]]},
	"verdant_boots": {"name": "Verdant Boots", "slot": "feet", "icon": "vd_boots", "set": "verdant", "mods": [["max_hp", "add", 10.0], ["move_speed", "inc", 0.03]]},
	"verdant_totem": {"name": "Verdant Totem", "slot": "charm", "icon": "vd_totem", "set": "verdant", "mods": [["flask_heal", "add", 0.06], ["max_hp", "add", 8.0]]},

	# ================= uniques (learned from blueprints) =================
	"gamblers_coin": {"name": "Gambler's Coin", "slot": "charm", "icon": "coin", "unique": true, "flags": {"gamblers_coin": 1},
		"mods": [["ember_gain", "add", 0.35], ["crit_chance", "add", 0.05]],
		"desc": "Critical hits have a 10% chance to spill Embers. Ka-ching.",
		"recipe": {"ember_core": 4, "sun_gold": 2, "warden_sigil": 1, "embers": 300}},
	"seven_league_boots": {"name": "Seven-League Boots", "slot": "feet", "icon": "league_boots", "unique": true, "flags": {"ember_steps": 1},
		"mods": [["move_speed", "inc", 0.25], ["dodge_distance", "inc", 0.4]],
		"desc": "Every step scorches the floor behind you.",
		"recipe": {"rootwood": 6, "ember_core": 3, "bloom_heart": 1, "embers": 300}},
	"squeaky_clogs": {"name": "Squeaky Clogs", "slot": "feet", "icon": "clogs", "unique": true, "flags": {"squeaky": 1},
		"mods": [["move_speed", "inc", 0.12], ["dodge_charges", "add", 1.0]],
		"desc": "Squeak. Squeak. Enemies nearby sometimes stop to wonder what that was.",
		"recipe": {"rootwood": 5, "spore_silk": 3, "warden_sigil": 1, "embers": 200}},
	"heart_of_the_mountain": {"name": "Heart of the Mountain", "slot": "chest", "icon": "mountain_plate", "unique": true,
		"mods": [["max_hp", "add", 60.0], ["armor", "add", 0.15], ["move_speed", "inc", -0.1]],
		"desc": "Immovable. Mostly by choice.",
		"recipe": {"grave_iron": 12, "sun_gold": 3, "warden_sigil": 1, "embers": 350}},
	"spellweaver_circlet": {"name": "Spellweaver's Circlet", "slot": "head", "icon": "spell_circlet", "unique": true,
		"mods": [["ability_damage", "add", 0.35], ["ability_cost", "more", -0.2], ["melee_damage", "add", -0.15]],
		"desc": "Your gifts burn brighter; your blade, a little duller.",
		"recipe": {"soul_glass": 6, "ember_core": 3, "eclipse_shard": 1, "embers": 350}},
	"echoing_gauntlets": {"name": "Echoing Gauntlets", "slot": "hands", "icon": "echo_gauntlets", "unique": true, "flags": {"echo_strike": 1},
		"mods": [["melee_damage", "add", 0.08]],
		"desc": "Every fourth melee hit echoes a moment later for 60% damage.",
		"recipe": {"soul_glass": 5, "grave_iron": 5, "warden_sigil": 1, "embers": 320}},
	"ring_of_the_last_ember": {"name": "Ring of the Last Ember", "slot": "ring", "icon": "last_ember", "unique": true, "flags": {"phoenix": 1},
		"mods": [["max_hp", "add", 10.0]],
		"desc": "Once per expedition, a killing blow rekindles you at half health in a burst of fire.",
		"recipe": {"ember_core": 5, "bloom_heart": 1, "eclipse_shard": 1, "embers": 400}},
	"lantern_of_avarice": {"name": "Lantern of Avarice", "slot": "charm", "icon": "avarice_lantern", "unique": true, "flags": {"avarice": 1},
		"mods": [["ember_gain", "add", 0.6], ["xp_gain", "add", 0.2]],
		"desc": "Materials drop 60% more often. Everything down there has 20% more health.",
		"recipe": {"sun_gold": 4, "ember_core": 2, "warden_sigil": 1, "embers": 300}},
	"stormcaller_signet": {"name": "Stormcaller Signet", "slot": "ring", "icon": "storm_signet", "unique": true, "flags": {"storm_crit": 1},
		"mods": [["crit_chance", "add", 0.04]],
		"desc": "Critical hits call lightning down on a nearby enemy.",
		"recipe": {"soul_glass": 5, "sun_gold": 2, "eclipse_shard": 1, "embers": 350}},
	"vampires_kiss": {"name": "Vampire's Kiss", "slot": "ring", "icon": "vamp_ring", "unique": true, "flags": {"lifesteal": 1},
		"mods": [["melee_damage", "add", 0.05], ["flask_charges", "add", -1.0]],
		"desc": "Melee hits heal you for 4% of the damage dealt. You carry one flask fewer.",
		"recipe": {"bone_dust": 8, "spore_silk": 4, "bloom_heart": 1, "embers": 300}},
	"featherfall_hood": {"name": "Featherfall Hood", "slot": "head", "icon": "feather_hood", "unique": true, "flags": {"featherfall": 1},
		"mods": [["move_speed", "inc", 0.1], ["dodge_distance", "inc", 0.15]],
		"desc": "You float a hand's breadth above the floor. Spike traps can't touch you.",
		"recipe": {"spore_silk": 6, "soul_glass": 2, "bloom_heart": 1, "embers": 260}},
	"berserkers_mantle": {"name": "Berserker's Mantle", "slot": "chest", "icon": "berserk_mantle", "unique": true, "flags": {"berserk": 1},
		"mods": [["melee_damage", "add", 0.1]],
		"desc": "+3% damage for every 10% of your health that is missing.",
		"recipe": {"bone_dust": 8, "grave_iron": 6, "warden_sigil": 1, "embers": 300}},
	"kindle_battery": {"name": "Kindle Battery", "slot": "charm", "icon": "battery", "unique": true, "flags": {"kindle_refund": 1},
		"mods": [["kindle_max", "add", 40.0]],
		"desc": "Kills made with abilities refund 12 Kindle.",
		"recipe": {"soul_glass": 4, "ember_core": 4, "eclipse_shard": 1, "embers": 320}},

	# ================= boss legendaries =================
	"gloamward_lantern": {"name": "Gloamward Lantern", "slot": "charm", "icon": "lantern_charm", "legendary": true, "look": "gloamward",
		"mods": [["kindle_max", "add", 20.0], ["parry_window", "add", 0.04], ["ability_damage", "add", 0.1]],
		"desc": "Taken from the Gloam Warden. The light it holds will not be snuffed.", "salvage": {"warden_sigil": 1}},
	"bloom_crown": {"name": "Crown of the Hollow Bloom", "slot": "head", "icon": "bloom_crown", "legendary": true, "look": "bloom",
		"mods": [["fire_damage", "add", 0.15], ["burn_damage", "add", 0.3], ["max_hp", "add", 10.0]],
		"desc": "Petals that never stop smouldering.", "salvage": {"bloom_heart": 1}},
	"sunfall_mantle": {"name": "Sunfall Mantle", "slot": "chest", "icon": "sunfall_mantle", "legendary": true, "look": "sunfall",
		"mods": [["damage", "add", 0.15], ["ability_cost", "more", -0.15], ["kindle_max", "add", 20.0]],
		"desc": "The Ashen King's mantle, woven from the last light of the sun.", "salvage": {"eclipse_shard": 1}},
}

## Affixes rolled onto rare, epic and set pieces (values at level 1, tier 1).
const AFFIXES := [
	["max_hp", "add", 8.0], ["armor", "add", 0.03], ["melee_damage", "add", 0.05], ["fire_damage", "add", 0.06],
	["frost_damage", "add", 0.06], ["crit_chance", "add", 0.02], ["attack_speed", "add", 0.04], ["move_speed", "inc", 0.03],
	["kindle_max", "add", 8.0], ["kindle_gain", "inc", 0.06], ["ability_damage", "add", 0.06], ["dodge_recharge", "more", -0.05],
	["ember_gain", "add", 0.06], ["crit_mult", "add", 0.1], ["thorns", "add", 4.0], ["flask_heal", "add", 0.04],
]

## Bases that drop in each region (sets, uniques and legendaries drop separately).
const REGION_BASES := {
	"ossuary": ["gravecloth_hood", "grave_iron_helm", "soulglass_circlet", "miners_cap", "horned_helm", "gravecloth_robe",
		"grave_iron_mail", "tattered_cloak", "pilgrim_vestments", "bone_gauntlets", "ember_gloves", "duelist_gloves",
		"soft_boots", "iron_greaves", "ember_band", "frost_signet", "focus_band", "bone_totem", "rabbits_foot", "warding_idol"],
	"rootmire": ["rootweave_cowl", "plague_mask", "fools_cap", "sporesilk_coat", "scale_hauberk", "silk_wraps", "mitts_of_haste",
		"sigil_bracers", "gloam_treads", "sprinter_sandals", "mud_waders", "dancer_slippers", "wick_loop", "clover_ring",
		"thorn_ring", "spore_locket", "ember_gloves", "soft_boots"],
	"throne": ["horned_helm", "soulglass_circlet", "fools_cap", "scale_hauberk", "pilgrim_vestments", "duelist_gloves",
		"mitts_of_haste", "sigil_bracers", "dancer_slippers", "sprinter_sandals", "clover_ring", "focus_band",
		"hourglass_pendant", "sunburst_brooch", "warding_idol"],
}


static func base(id: String) -> Dictionary:
	return BASES.get(id, {})


static func is_unique(id: String) -> bool:
	return base(id).get("unique", false)


## Plain craftable bases (uniques need their blueprint; sets and legendaries drop).
static func craftable() -> Array:
	return BASES.keys().filter(func(k): return BASES[k].has("recipe") and not BASES[k].get("unique", false))


static func blueprints() -> Array:
	return BASES.keys().filter(func(k): return BASES[k].get("unique", false))


static func set_pieces(set_id: String) -> Array:
	return BASES.keys().filter(func(k): return BASES[k].get("set", "") == set_id)


## A fresh item. Affixes are rolled from `rng` so drops are reproducible.
static func make_item(base_id: String, rarity: String, level: int, rng: RandomNumberGenerator, tier := 1) -> Dictionary:
	var b := base(base_id)
	if b.get("legendary", false) or b.get("unique", false):
		rarity = "legendary"
	elif b.has("set"):
		rarity = "set"
	var affixes: Array = []
	var pool := AFFIXES.duplicate()
	for i in int(RARITY[rarity].affixes):
		if pool.is_empty():
			break
		var a: Array = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		affixes.append([a[0], a[1], float(a[2]) * rng.randf_range(0.8, 1.2)])
	return {"uid": 0, "base": base_id, "rarity": rarity, "level": clampi(level, 1, MAX_LEVEL), "tier": clampi(tier, 1, MAX_TIER), "affixes": affixes}


static func roll_rarity(rng: RandomNumberGenerator, luck := 0.0) -> String:
	var r := rng.randf() - luck
	if r < 0.12:
		return "epic"
	if r < 0.45:
		return "rare"
	return "common"


## How much an item's tier multiplies its numbers (gear from harder tiers is stronger).
static func tier_mult(tier: int) -> float:
	return 1.0 + 0.4 * float(tier - 1)


## Every modifier the item grants (base scaled by level, tier and rarity, plus affixes).
## Penalties (negative base values on uniques) do not grow with level or tier.
static func mods_of(item: Dictionary) -> Array:
	var b := base(String(item.get("base", "")))
	if b.is_empty():
		return []
	var k := (1.0 + 0.12 * (int(item.get("level", 1)) - 1)) * tier_mult(int(item.get("tier", 1)))
	var rar_k := float(RARITY.get(item.get("rarity", "common"), RARITY.common).mult)
	var out: Array = []
	for m in b.mods:
		var v := float(m[2])
		var integral: bool = m[0] in ["dodge_charges", "flask_charges"]
		if integral or (v < 0.0 and not m[0] in ["dodge_recharge", "cooldown", "ability_cost"]):
			out.append([m[0], m[1], v])
		else:
			out.append([m[0], m[1], v * k * rar_k])
	for a in item.get("affixes", []):
		out.append([a[0], a[1], float(a[2]) * k])
	return out


## Equipped gear: mods, unique flags, and set bonuses for 2 / 4 pieces.
static func apply_equipped(equipped: Dictionary, stats: Stats) -> void:
	for slot in SLOTS:
		var it: Variant = equipped.get(slot)
		if it is Dictionary and not (it as Dictionary).is_empty():
			stats.apply_mods(mods_of(it))
			stats.apply_flags(base(String(it.base)).get("flags", {}))
	var counts := set_counts(equipped)
	for s in counts:
		for n in [2, 4]:
			if int(counts[s]) >= n:
				var bonus: Dictionary = SETS[s][n]
				stats.apply_mods(bonus.get("mods", []))
				stats.apply_flags(bonus.get("flags", {}))


static func set_counts(equipped: Dictionary) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var it: Variant = equipped.get(slot)
		if it is Dictionary and not (it as Dictionary).is_empty():
			var s := String(base(String(it.base)).get("set", ""))
			if s != "":
				out[s] = int(out.get(s, 0)) + 1
	return out


## The look the gear gives the Kindled: a set worn at 2+ pieces, else a worn
## legendary with a look, else the plain Kindled.
static func gear_look(equipped: Dictionary) -> String:
	var counts := set_counts(equipped)
	var best := ""
	var bn := 1
	for s in counts:
		if int(counts[s]) > bn:
			bn = int(counts[s])
			best = String(SETS[s].look)
	if best != "":
		return best
	for slot in ["chest", "head", "charm"]:
		var it: Variant = equipped.get(slot)
		if it is Dictionary and base(String((it as Dictionary).get("base", ""))).has("look"):
			return String(base(String(it.base)).look)
	return "kindled"


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
	var r := float(RARITY[item.get("rarity", "common")].value)
	return int(round(e * r * (1.0 + 0.3 * (int(item.get("level", 1)) - 1)) * tier_mult(int(item.get("tier", 1))) * 0.5))


# --- the blacksmith -----------------------------------------------------------

static func recipe(base_id: String) -> Dictionary:
	return base(base_id).get("recipe", {})


## Crafting rolls a rarity; a catalyst makes it epic. Crafted gear is made at
## the highest difficulty tier the Kindled has unlocked.
static func craft(base_id: String, rng: RandomNumberGenerator, masterwork := false, forge_level := 1, tier := 1) -> Dictionary:
	var rar := "epic" if masterwork else roll_rarity(rng, 0.04 * (forge_level - 1))
	return make_item(base_id, rar, 1, rng, tier)


static func temper_cost(item: Dictionary) -> Dictionary:
	var lvl := int(item.get("level", 1))
	var out := {}
	var rec := recipe(String(item.base))
	for k in rec:
		if k != "embers" and not k in CATALYSTS:
			out[k] = maxi(1, int(ceil(int(rec[k]) * 0.5)))
	var b := base(String(item.base))
	if rec.is_empty():
		# sets and legendaries temper with ember cores (and a legendary's own catalyst)
		out["ember_core"] = 2
		for k in b.get("salvage", {}):
			out[k] = 1
	out["embers"] = 60 * lvl * int(ceil(tier_mult(int(item.get("tier", 1)))))
	return out


## What breaking an item down returns: half its recipe (at least one of the main
## material), or a legendary's catalyst; set pieces return ember cores and sun gold.
static func salvage_yield(item: Dictionary) -> Dictionary:
	var b := base(String(item.get("base", "")))
	if b.has("salvage"):
		return (b.salvage as Dictionary).duplicate()
	var out := {}
	if b.has("set"):
		return {"ember_core": 2, "sun_gold": 1}
	for k in b.get("recipe", {}):
		if k != "embers" and not k in CATALYSTS:
			out[k] = maxi(1, int(floor(int(b.recipe[k]) * 0.5)))
	if item.get("rarity", "common") in ["epic", "legendary"]:
		out["ember_core"] = int(out.get("ember_core", 0)) + 1
	return out


# --- drops ---------------------------------------------------------------------

## Materials an enemy can drop: [[material, chance, min, max], ...]
static func enemy_drops(enemy_id: String, region: String) -> Array:
	var out: Array = []
	match region:
		"rootmire":
			out.append(["rootwood", 0.25, 1, 2])
		"throne":
			out.append(["sun_gold", 0.22, 1, 2])
		_:
			out.append(["bone_dust", 0.28, 1, 2])
	match enemy_id:
		"guard":
			out.append(["grave_iron", 0.4, 1, 2])
		"husk", "skitter", "spider":
			out.append(["grave_iron", 0.06, 1, 1])
		"bonecaller":
			out.append(["soul_glass", 0.4, 1, 1])
		"archer":
			out.append(["soul_glass", 0.08, 1, 1])
		"moth", "sporeling", "toad":
			out.append(["spore_silk", 0.3, 1, 1])
		"thornback", "rootweaver":
			out.append(["spore_silk", 0.15, 1, 1])
			out.append(["rootwood", 0.2, 1, 1])
		"sentinel":
			out.append(["grave_iron", 0.35, 1, 2])
			out.append(["sun_gold", 0.2, 1, 1])
		"wraith", "acolyte":
			out.append(["soul_glass", 0.3, 1, 1])
		"hound":
			out.append(["ember_core", 0.08, 1, 1])
	return out


## A random piece of plain gear for a region, depth and difficulty tier; from
## Tier II up some drops are set pieces instead.
static func random_drop(region: String, depth: int, rng: RandomNumberGenerator, luck := 0.0, tier := 1) -> Dictionary:
	if tier >= 2 and rng.randf() < 0.03 + 0.025 * tier:
		return random_set_piece(rng, depth, tier)
	var pool: Array = REGION_BASES.get(region, REGION_BASES.ossuary)
	var b: String = pool[rng.randi_range(0, pool.size() - 1)]
	return make_item(b, roll_rarity(rng, luck + 0.03 * (tier - 1)), clampi(depth, 1, MAX_LEVEL), rng, tier)


static func random_set_piece(rng: RandomNumberGenerator, depth: int, tier: int) -> Dictionary:
	var sets := SETS.keys()
	var pieces := set_pieces(sets[rng.randi_range(0, sets.size() - 1)])
	return make_item(pieces[rng.randi_range(0, pieces.size() - 1)], "set", clampi(depth, 1, MAX_LEVEL), rng, tier)


## A blueprint the Kindled hasn't learned (or found) yet, or "" when all are known.
static func roll_blueprint(rng: RandomNumberGenerator, have: Array) -> String:
	var unknown := blueprints().filter(func(b): return not have.has(b))
	if unknown.is_empty():
		return ""
	return unknown[rng.randi_range(0, unknown.size() - 1)]


## A test stockpile so crafting can be tried right away (see Profile.TEST_STOCKPILE).
static func stockpile() -> Dictionary:
	var out := {}
	for k in MATERIALS:
		out[k] = 6 if k in CATALYSTS else 60
	return out
