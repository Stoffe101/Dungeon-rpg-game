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
}

## Forge levels: damage bonus per level; level 3 grants the weapon's signature upgrade.
const FORGE_MAX := 5
const FORGE_DAMAGE_PER_LEVEL := 0.12
const FORGE_COSTS := [60, 120, 220, 360, 540]
const FORGE_SIGNATURES := {
	"sword": "Tempered: the third strike sends out a cutting wave.",
	"hammer": "Tempered: slams release a wider shockwave.",
	"staff": "Tempered: ember bolts pierce one extra enemy.",
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
}


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS.sword)


static func ability(id: String) -> Dictionary:
	return ABILITIES.get(id, {})
