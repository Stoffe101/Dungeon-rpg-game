## Enemy archetypes. Stats live here; behaviour lives in src/entities/enemies/*.gd.
## `cost` is the encounter budget an enemy consumes.
class_name EnemyDB
extends RefCounted

const ENEMIES := {
	"husk": {
		"name": "Husk", "script": "res://src/entities/enemies/husk.gd", "sheet": "husk",
		"hp": 42.0, "speed": 2.5, "radius": 0.36, "poise": 22.0, "damage": 12.0,
		"xp": 6, "embers": 3, "cost": 2, "min_depth": 1,
		"lore": "The Undervault's first dead. They still remember how to swing.",
	},
	"skitter": {
		"name": "Skitter", "script": "res://src/entities/enemies/skitter.gd", "sheet": "skitter",
		"hp": 16.0, "speed": 5.4, "radius": 0.28, "poise": 6.0, "damage": 8.0,
		"xp": 3, "embers": 1, "cost": 1, "min_depth": 1, "pack": [2, 4],
		"lore": "Skulls that learned to run on borrowed fingers.",
	},
	"archer": {
		"name": "Hollow Archer", "script": "res://src/entities/enemies/archer.gd", "sheet": "archer",
		"hp": 30.0, "speed": 2.4, "radius": 0.34, "poise": 14.0, "damage": 11.0,
		"xp": 7, "embers": 4, "cost": 3, "min_depth": 1,
		"lore": "Their bowstrings are sinew. Their arrows hum with cold soul-light.",
	},
	"guard": {
		"name": "Ossuary Guard", "script": "res://src/entities/enemies/guard.gd", "sheet": "guard",
		"hp": 90.0, "speed": 2.0, "radius": 0.45, "poise": 55.0, "damage": 16.0, "armor": 0.1,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 1,
		"lore": "Sworn to a door that no longer exists. Strike them from behind, or break their guard.",
	},
	"bonecaller": {
		"name": "Bonecaller", "script": "res://src/entities/enemies/bonecaller.gd", "sheet": "bonecaller",
		"hp": 48.0, "speed": 2.2, "radius": 0.36, "poise": 18.0, "damage": 10.0,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 2,
		"lore": "A priest of the hollow choir. Where it sings, the dead stand back up.",
	},
	"bloat": {
		"name": "Grave Bloat", "script": "res://src/entities/enemies/bloat.gd", "sheet": "bloat",
		"hp": 34.0, "speed": 1.9, "radius": 0.42, "poise": 999.0, "damage": 26.0,
		"xp": 6, "embers": 4, "cost": 3, "min_depth": 1,
		"lore": "Swollen with grave-gas. Its end is everyone's problem - including its friends'.",
	},
	# --- the Rootmire ---
	"sporeling": {
		"name": "Sporeling", "script": "res://src/entities/enemies/sporeling.gd", "sheet": "sporeling",
		"hp": 24.0, "speed": 3.6, "radius": 0.3, "poise": 8.0, "damage": 9.0,
		"xp": 4, "embers": 2, "cost": 1, "min_depth": 1, "pack": [2, 4],
		"lore": "It wants to share. Mostly what it shares is spores.",
	},
	"thornback": {
		"name": "Thornback", "script": "res://src/entities/enemies/thornback.gd", "sheet": "thornback",
		"hp": 80.0, "speed": 2.2, "radius": 0.5, "poise": 60.0, "damage": 18.0, "armor": 0.35,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 1,
		"lore": "Rolls first, thinks never. Leaves it dizzy and soft-bellied.",
	},
	"moth": {
		"name": "Lantern Moth", "script": "res://src/entities/enemies/moth.gd", "sheet": "moth",
		"hp": 18.0, "speed": 4.2, "radius": 0.3, "poise": 6.0, "damage": 7.0,
		"xp": 5, "embers": 3, "cost": 2, "min_depth": 1,
		"lore": "Drawn to your flame. It drinks the light out of your lantern.",
	},
	"rootweaver": {
		"name": "Rootweaver", "script": "res://src/entities/enemies/rootweaver.gd", "sheet": "rootweaver",
		"hp": 55.0, "speed": 2.1, "radius": 0.36, "poise": 20.0, "damage": 14.0,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 1,
		"lore": "It sings to the roots, and the roots answer with thorns.",
	},
	"bloom": {
		"name": "The Hollow Bloom", "script": "res://src/entities/enemies/bloom.gd", "sheet": "bloom",
		"hp": 2600.0, "speed": 0.0, "radius": 1.6, "poise": 340.0, "damage": 20.0, "armor": 0.25,
		"xp": 240, "embers": 180, "cost": 99, "min_depth": 99, "boss": true,
		"lore": "Where the sun's last seed fell, something grew that is not a flower.",
	},
	"warden": {
		"name": "The Gloam Warden", "script": "res://src/entities/enemies/warden.gd", "sheet": "warden",
		"hp": 1900.0, "speed": 3.0, "radius": 0.9, "poise": 260.0, "damage": 22.0, "armor": 0.0,
		"xp": 160, "embers": 120, "cost": 99, "min_depth": 99, "boss": true,
		"lore": "Keeper of the Ossuary's lightless heart. It swallows every flame it finds.",
	},
}

## Elite affixes: a twist on an enemy, never just a bigger health bar.
const AFFIXES := {
	"hasted": {"name": "Hasted", "color": Color(1.0, 0.85, 0.35), "desc": "Moves and attacks faster."},
	"warded": {"name": "Warded", "color": Color(0.45, 0.8, 1.0), "desc": "Shielded by soul-light until the shield is broken."},
	"volatile": {"name": "Volatile", "color": Color(1.0, 0.45, 0.25), "desc": "Erupts in flame when it dies."},
	"vampiric": {"name": "Vampiric", "color": Color(0.9, 0.25, 0.35), "desc": "Heals whenever it wounds you."},
	"phasing": {"name": "Phasing", "color": Color(0.75, 0.5, 0.95), "desc": "Periodically slips out of the world, becoming untouchable."},
}

## Regions: each has its own enemy pool, look and boss. Only the Ossuary is
## playable in the first slice; the others are seeds for expansion.
const REGIONS := {
	"ossuary": {
		"name": "The Hollow Ossuary",
		"theme": "crypt",
		"depths": 2,
		"pool": ["husk", "skitter", "archer", "guard", "bonecaller", "bloat"],
		"boss": "warden",
		"ambient": Color(0.3, 0.33, 0.55),
		"flame": Color(0.35, 0.95, 0.85),
		"music": "crypt",
		"ambience": "amb_crypt",
		"torch": "torch",
		"unlock": {},
		"blurb": "Two depths of bone and soul-light, then the Gloam Warden.",
	},
	"rootmire": {
		"name": "The Rootmire",
		"theme": "root",
		"depths": 2,
		"pool": ["sporeling", "thornback", "moth", "rootweaver", "husk", "archer"],
		"boss": "bloom",
		"ambient": Color(0.3, 0.46, 0.38),
		"flame": Color(0.55, 1.0, 0.45),
		"music": "rootmire",
		"ambience": "amb_root",
		"torch": "torch_bio",
		"unlock": {"warden_kills": 1},
		"blurb": "Fungal caverns among the roots of a dead world-tree. Brambles burn. The Hollow Bloom waits.",
		"memory_bonus": 1,
	},
}


static func region_unlocked(id: String) -> bool:
	var req: Dictionary = REGIONS.get(id, {}).get("unlock", {})
	for k in req:
		if int(Profile.data.world.get(k, 0)) < int(req[k]):
			return false
	return true


static func get_def(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


## Builds a list of enemy ids worth roughly `budget` points for a room.
static func roll_encounter(rng: RandomNumberGenerator, region: String, depth: int, budget: int) -> Array:
	var pool: Array = []
	for id in REGIONS[region].pool:
		var d: Dictionary = ENEMIES[id]
		if int(d.min_depth) <= depth:
			pool.append(id)
	var out: Array = []
	var left := budget
	var guard := 0
	while left > 0 and guard < 40:
		guard += 1
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var d: Dictionary = ENEMIES[id]
		var c := int(d.cost)
		if c > left:
			if left <= 1:
				id = "skitter"
				c = 1
			else:
				continue
		if d.has("pack") and id == "skitter":
			var n := rng.randi_range(int(d.pack[0]), int(d.pack[1]))
			n = mini(n, left)
			for k in n:
				out.append(id)
			left -= n
			continue
		out.append(id)
		left -= c
	return out
