## Weapons and active abilities.
class_name GearDB
extends RefCounted

## Weapons are mechanically distinct; numbers here tune the behaviour implemented
## in src/combat/weapons/*.gd.
const WEAPONS := {
	"sword": {
		"name": "Hearthblade",
		"desc": "A balanced blade. Three-strike combo; hold to charge a whirling cut.",
		"icon": "sword",
		"sprite": "w_sword",
		"script": "res://src/combat/weapons/sword.gd",
		"unlock": {},
		"damage": [14.0, 14.0, 24.0],
		"charged": 34.0,
	},
	"hammer": {
		"name": "Cinderhammer",
		"desc": "Slow and crushing. Breaks guards and staggers; charge to leap and quake the ground.",
		"icon": "hammer",
		"sprite": "w_hammer",
		"script": "res://src/combat/weapons/hammer.gd",
		"unlock": {"sunshards": 1, "embers": 150},
		"damage": [30.0, 46.0],
		"charged": 64.0,
	},
	"staff": {
		"name": "Ashwood Staff",
		"desc": "Hurls ember bolts from range. Hold to gather a bursting fireball.",
		"icon": "staff",
		"sprite": "w_staff",
		"script": "res://src/combat/weapons/staff.gd",
		"unlock": {"sunshards": 1, "embers": 150},
		"damage": [9.0],
		"charged": 48.0,
	},
	"daggers": {
		"name": "Twin Fangs",
		"desc": "Two quick blades: four fast cuts and +15% crit chance. Charge to Shadowstep through your foes.",
		"icon": "daggers",
		"sprite": "w_daggers",
		"script": "res://src/combat/weapons/daggers.gd",
		"unlock": {"sunshards": 2, "embers": 250, "soul_glass": 6},
		"damage": [8.0, 8.0, 9.0, 16.0],
		"charged": 30.0,
	},
	"spear": {
		"name": "Sunpiercer",
		"desc": "A long glaive. Thrusts skewer a whole line, the third cut sweeps wide. Charge for a Comet Lunge.",
		"icon": "spear",
		"sprite": "w_spear",
		"script": "res://src/combat/weapons/spear.gd",
		"unlock": {"sunshards": 2, "embers": 250, "grave_iron": 8},
		"damage": [15.0, 15.0, 26.0],
		"charged": 46.0,
	},
	"bow": {
		"name": "Hearthbow",
		"desc": "Quick shots from range. Hold to draw; let go as the draw peaks for a Steady Shot that pierces three and always crits. Slow while drawing.",
		"icon": "bow",
		"sprite": "w_bow",
		"script": "res://src/combat/weapons/bow.gd",
		"unlock": {"sunshards": 2, "embers": 250, "rootwood": 6},
		"damage": [11.0],
		"charged": 42.0,
	},
	"tome": {
		"name": "Emberwright's Tome",
		"desc": "A spellcaster's book. Hold to read: seeking motes of script stream at your foes, and every one that lands hurries your spells. Each spell you cast writes its element into the next pages.",
		"icon": "tome",
		"sprite": "w_tome",
		"script": "res://src/combat/weapons/tome.gd",
		"unlock": {"sunshards": 2, "embers": 300, "soul_glass": 8},
		"damage": [6.0],
		"charged": 0.0,
	},
}

## Forge levels: +12% damage per level. +3 Tempers a weapon (its signature),
## +7 makes it a Masterwork (a second one), +10 Ascends it (it burns brighter).
## Higher levels ask for materials from deeper regions too.
const FORGE_MAX := 10
const FORGE_DAMAGE_PER_LEVEL := 0.12
const FORGE_COSTS := [60, 120, 220, 360, 540, 760, 1000, 1300, 1650, 2050]
const FORGE_MATERIALS := [
	{}, {"bone_dust": 4}, {"grave_iron": 4}, {"grave_iron": 6, "soul_glass": 2},
	{"rootwood": 6, "ember_core": 1}, {"spore_silk": 6, "ember_core": 2},
	{"grave_iron": 10, "ember_core": 3}, {"sun_gold": 6, "ember_core": 3},
	{"sun_gold": 10, "soul_glass": 6}, {"sun_gold": 14, "eclipse_shard": 1},
]
const FORGE_SIGNATURES := {
	"sword": "Tempered: the third strike sends out a cutting wave.",
	"hammer": "Tempered: slams release a wider shockwave.",
	"staff": "Tempered: ember bolts pierce one extra enemy.",
	"daggers": "Tempered: the crossing cut strikes with full force.",
	"spear": "Tempered: thrusts slip past shields.",
	"bow": "Tempered: quick shots pierce a foe.",
	"tome": "Tempered: motes pierce a foe.",
}
const FORGE_MASTERWORK := {
	"sword": "Masterwork: the whirling cut leaves a ring of embers that sets foes alight.",
	"hammer": "Masterwork: slams leave the ground cracked and burning.",
	"staff": "Masterwork: the fireball bursts into a ring of ember bolts.",
	"daggers": "Masterwork: the shadow left by Shadowstep cuts again.",
	"spear": "Masterwork: the sweep hurls a piercing lance of sunfire.",
	"bow": "Masterwork: a Steady Shot splits in two at the first foe it meets.",
	"tome": "Masterwork: every fifth mote is a glyph that bursts where it lands.",
}

const ABILITIES := {
	"flare": {
		"name": "Flare", "cost": 30.0, "cooldown": 1.2, "icon": "flare",
		"desc": "Release a burst of hearth-fire around you. Burns and knocks enemies back.",
		"damage": 28.0, "radius": 3.0,
	},
	"cinder_lance": {
		"name": "Cinder Lance", "cost": 25.0, "cooldown": 0.8, "icon": "lance",
		"desc": "Hurl a piercing spear of fire toward the cursor, igniting everything it passes.",
		"damage": 30.0, "range": 11.0,
	},
	"frost_sigil": {
		"name": "Frost Sigil", "cost": 35.0, "cooldown": 4.0, "icon": "sigil",
		"desc": "Inscribe a rune at the cursor that pulses freezing cold three times.",
		"damage": 10.0, "radius": 2.8,
	},
	"gloamstep": {
		"name": "Gloamstep", "cost": 20.0, "cooldown": 2.0, "icon": "gloamstep",
		"desc": "Vanish and reappear at the cursor, leaving a shade that detonates.",
		"damage": 26.0, "range": 6.5,
	},
	"aegis": {
		"name": "Aegis", "cost": 35.0, "cooldown": 9.0, "icon": "aegis",
		"desc": "Surround yourself with a ward that absorbs 40 damage and reflects projectiles for 4s.",
		"absorb": 40.0, "duration": 4.0,
	},
	"wisp": {
		"name": "Wisp Familiar", "cost": 40.0, "cooldown": 12.0, "icon": "wisp",
		"desc": "Summon a hearth-wisp that hunts enemies with ember bolts for 18s.",
		"damage": 7.0, "duration": 18.0,
	},
	"knives": {
		"name": "Gloam Knives", "cost": 10.0, "cooldown": 0.42, "icon": "knives",
		"desc": "Cut five knives from your lantern's shadow and fling them in a fan. Cheap and quick: a caster's blade. Shaped by every projectile modifier you carry.",
		"damage": 7.0, "count": 5, "range": 9.0,
	},
	"lantern": {
		"name": "Hearth Lantern", "cost": 45.0, "cooldown": 16.0, "icon": "lantern",
		"desc": "Plant a lantern at the cursor for 12s. It looses ember bolts at foes, and every Kindled in its light regains Kindle and takes 10% less damage.",
		"damage": 8.0, "duration": 12.0, "radius": 3.5,
	},
	"rush": {
		"name": "Ember Rush", "cost": 22.0, "cooldown": 3.0, "icon": "rush",
		"desc": "Burst toward the cursor as a streak of fire, cutting and burning everything in your path. Counts as a melee strike.",
		"damage": 22.0, "range": 6.0,
	},
	"rekindle": {
		"name": "Rekindle", "cost": 40.0, "cooldown": 24.0, "icon": "rekindle",
		"desc": "Hearth-light floods out around you: you and every ally in it gain a ward of 25% of health and 20 Kindle, and fallen allies in it get back up.",
		"radius": 4.0, "ward": 0.25,
	},
}


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS.sword)


static func ability(id: String) -> Dictionary:
	return ABILITIES.get(id, {})
