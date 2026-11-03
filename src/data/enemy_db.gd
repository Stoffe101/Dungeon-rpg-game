## Enemy archetypes. Stats live here; behaviour lives in src/entities/enemies/*.gd.
## `cost` is the encounter budget an enemy consumes.
class_name EnemyDB
extends RefCounted

const ENEMIES := {
	"husk": {
		"voice": "zombie", "voice_pitch": 1.0, "role": "brute",
		"name": "Husk", "script": "res://src/entities/enemies/husk.gd", "sheet": "husk",
		"hp": 42.0, "speed": 2.5, "radius": 0.36, "poise": 22.0, "damage": 12.0,
		"xp": 6, "embers": 3, "cost": 2, "min_depth": 1,
		"lore": "The Undervault's first dead. They still remember how to swing.",
	},
	"skitter": {
		"voice": "skeleton", "voice_pitch": 1.35, "role": "swarm",
		"name": "Skitter", "script": "res://src/entities/enemies/skitter.gd", "sheet": "skitter",
		"hp": 16.0, "speed": 5.4, "radius": 0.28, "poise": 6.0, "damage": 8.0,
		"xp": 3, "embers": 1, "cost": 1, "min_depth": 1, "pack": [2, 4],
		"lore": "Skulls that learned to run on borrowed fingers.",
	},
	"archer": {
		"voice": "skeleton", "voice_pitch": 1.0, "role": "ranged",
		"name": "Hollow Archer", "script": "res://src/entities/enemies/archer.gd", "sheet": "archer",
		"hp": 30.0, "speed": 2.4, "radius": 0.34, "poise": 14.0, "damage": 11.0,
		"xp": 7, "embers": 4, "cost": 3, "min_depth": 1,
		"lore": "Their bowstrings are sinew. Their arrows hum with cold soul-light.",
	},
	"guard": {
		"voice": "skeleton", "voice_pitch": 0.75, "role": "tank",
		"name": "Ossuary Guard", "script": "res://src/entities/enemies/guard.gd", "sheet": "guard",
		"hp": 90.0, "speed": 2.0, "radius": 0.45, "poise": 55.0, "damage": 16.0, "armor": 0.1,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 1,
		"lore": "Sworn to a door that no longer exists. Strike them from behind, or break their guard.",
	},
	"bonecaller": {
		"voice": "skeleton", "voice_pitch": 1.15, "role": "summoner",
		"name": "Bonecaller", "script": "res://src/entities/enemies/bonecaller.gd", "sheet": "bonecaller",
		"hp": 48.0, "speed": 2.2, "radius": 0.36, "poise": 18.0, "damage": 10.0,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 2,
		"lore": "A priest of the hollow choir. Where it sings, the dead stand back up.",
	},
	"bloat": {
		"voice": "bigslime", "voice_pitch": 1.0, "role": "exploder",
		"name": "Grave Bloat", "script": "res://src/entities/enemies/bloat.gd", "sheet": "bloat",
		"hp": 34.0, "speed": 1.9, "radius": 0.42, "poise": 999.0, "damage": 26.0,
		"xp": 6, "embers": 4, "cost": 3, "min_depth": 1,
		"lore": "Swollen with grave-gas. Its end is everyone's problem - including its friends'.",
	},
	"spider": {
		"voice": "bat", "voice_pitch": 0.7, "role": "controller",
		"name": "Grave Spider", "script": "res://src/entities/enemies/spider.gd", "sheet": "spider",
		"hp": 36.0, "speed": 3.4, "radius": 0.34, "poise": 12.0, "damage": 12.0,
		"xp": 8, "embers": 4, "cost": 3, "min_depth": 2,
		"lore": "It wove the Ossuary's shrouds once, when there were still mourners to wear them.",
	},
	"gravemole": {
		"voice": "beast", "voice_pitch": 1.45, "role": "ambush",
		"no_affix": ["phasing"],
		"name": "Gravemole", "script": "res://src/entities/enemies/gravemole.gd", "sheet": "gravemole",
		"hp": 46.0, "speed": 2.6, "radius": 0.4, "poise": 22.0, "damage": 14.0,
		"xp": 8, "embers": 5, "cost": 3, "min_depth": 2,
		"lore": "It digs the graves before anyone needs one. Keep moving, and watch the floor.",
	},
	"lampwight": {
		"voice": "wildfire", "voice_pitch": 1.5, "role": "support",
		"name": "Lampwight", "script": "res://src/entities/enemies/lampwight.gd", "sheet": "lampwight",
		"hp": 30.0, "speed": 2.7, "radius": 0.3, "poise": 10.0, "damage": 8.0,
		"xp": 9, "embers": 5, "cost": 3, "min_depth": 2,
		"lore": "It carries a lamp of soul-light for whoever it decides to keep. Put a wall between them, or put it out.",
	},
	# --- the Rootmire ---
	"sporeling": {
		"voice": "slime", "voice_pitch": 1.3, "role": "swarm",
		"name": "Sporeling", "script": "res://src/entities/enemies/sporeling.gd", "sheet": "sporeling",
		"hp": 24.0, "speed": 3.6, "radius": 0.3, "poise": 8.0, "damage": 9.0,
		"xp": 4, "embers": 2, "cost": 1, "min_depth": 1, "pack": [2, 4],
		"lore": "It wants to share. Mostly what it shares is spores.",
	},
	"thornback": {
		"voice": "beast", "voice_pitch": 1.1, "role": "charger",
		"name": "Thornback", "script": "res://src/entities/enemies/thornback.gd", "sheet": "thornback",
		"hp": 80.0, "speed": 2.2, "radius": 0.5, "poise": 60.0, "damage": 18.0, "armor": 0.35,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 1,
		"lore": "Rolls first, thinks never. Leaves it dizzy and soft-bellied.",
	},
	"moth": {
		"voice": "bat", "voice_pitch": 1.2, "role": "harrier",
		"name": "Lantern Moth", "script": "res://src/entities/enemies/moth.gd", "sheet": "moth",
		"hp": 18.0, "speed": 4.2, "radius": 0.3, "poise": 6.0, "damage": 7.0,
		"xp": 5, "embers": 3, "cost": 2, "min_depth": 1,
		"lore": "Drawn to your flame. It drinks the light out of your lantern.",
	},
	"rootweaver": {
		"voice": "pumpkin", "voice_pitch": 1.0, "role": "controller",
		"name": "Rootweaver", "script": "res://src/entities/enemies/rootweaver.gd", "sheet": "rootweaver",
		"hp": 55.0, "speed": 2.1, "radius": 0.36, "poise": 20.0, "damage": 14.0,
		"xp": 12, "embers": 7, "cost": 5, "min_depth": 1,
		"lore": "It sings to the roots, and the roots answer with thorns.",
	},
	"spore_mortar": {
		"voice": "bigslime", "voice_pitch": 1.3, "role": "artillery",
		"name": "Spore Mortar", "script": "res://src/entities/enemies/spore_mortar.gd", "sheet": "spore_mortar",
		"hp": 52.0, "speed": 0.0, "radius": 0.45, "poise": 40.0, "damage": 16.0, "armor": 0.1,
		"xp": 10, "embers": 6, "cost": 4, "min_depth": 2,
		"lore": "Rooted, patient and loud. Every cough is a seed with somewhere to be.",
	},
	"bramblewright": {
		"voice": "pumpkin", "voice_pitch": 1.25, "role": "terrain",
		"name": "Bramblewright", "script": "res://src/entities/enemies/bramblewright.gd", "sheet": "bramblewright",
		"hp": 50.0, "speed": 2.4, "radius": 0.36, "poise": 18.0, "damage": 13.0,
		"xp": 11, "embers": 6, "cost": 4, "min_depth": 1,
		"lore": "It plants hedges across your path. Brambles burn - remember that.",
	},
	# --- the Sunken Throne ---
	"sentinel": {
		"voice": "orc", "voice_pitch": 0.85, "role": "tank",
		"name": "Gilded Sentinel", "script": "res://src/entities/enemies/guard.gd", "sheet": "sentinel",
		"hp": 120.0, "speed": 2.1, "radius": 0.45, "poise": 70.0, "damage": 20.0, "armor": 0.2,
		"xp": 16, "embers": 9, "cost": 5, "min_depth": 1,
		"lore": "The sun-king's last guard. They still hold the door of a throne room that is under the sea of ash.",
	},
	"hound": {
		"voice": "wolf", "voice_pitch": 1.0, "role": "swarm",
		"name": "Ash Hound", "script": "res://src/entities/enemies/skitter.gd", "sheet": "hound",
		"hp": 24.0, "speed": 6.0, "radius": 0.3, "poise": 8.0, "damage": 11.0,
		"xp": 4, "embers": 2, "cost": 1, "min_depth": 1, "pack": [2, 3],
		"lore": "The King's hunting dogs burned with him. The embers in their ribs never went out.",
	},
	"acolyte": {
		"voice": "wildfire", "voice_pitch": 0.9, "role": "summoner",
		"name": "Eclipse Acolyte", "script": "res://src/entities/enemies/bonecaller.gd", "sheet": "acolyte",
		"hp": 60.0, "speed": 2.3, "radius": 0.36, "poise": 20.0, "damage": 13.0,
		"xp": 14, "embers": 8, "cost": 5, "min_depth": 1, "summon": "hound", "proj": "proj_eclipse",
		"lore": "They pray to the black sun. It answers with hounds.",
	},
	"wraith": {
		"voice": "wildfire", "voice_pitch": 1.2, "role": "ranged",
		"name": "Ash Wraith", "script": "res://src/entities/enemies/archer.gd", "sheet": "wraith",
		"hp": 40.0, "speed": 2.8, "radius": 0.34, "poise": 14.0, "damage": 15.0,
		"xp": 9, "embers": 5, "cost": 3, "min_depth": 1, "proj": "proj_sun", "shot_sfx": "sunlance",
		"lore": "Courtiers who outlived the sun by an hour. They throw the last of its light at anything warm.",
	},
	"duelist": {
		"voice": "orc", "voice_pitch": 1.15, "role": "duelist",
		"name": "Gilded Duelist", "script": "res://src/entities/enemies/duelist.gd", "sheet": "duelist",
		"hp": 85.0, "speed": 3.0, "radius": 0.36, "poise": 40.0, "damage": 17.0, "armor": 0.1,
		"xp": 14, "embers": 8, "cost": 4, "min_depth": 1,
		"lore": "The court's champion still fences for an audience of ash. When its blade glints, do not swing.",
	},
	"sunwatcher": {
		"voice": "wildfire", "voice_pitch": 0.7, "role": "beam",
		"name": "Sunwatcher", "script": "res://src/entities/enemies/sunwatcher.gd", "sheet": "sunwatcher",
		"hp": 48.0, "speed": 2.2, "radius": 0.38, "poise": 16.0, "damage": 18.0,
		"xp": 12, "embers": 7, "cost": 4, "min_depth": 2,
		"lore": "An eye that watched the sun set and never blinked again. It still holds the last of the light.",
	},
	"ashen_king": {
		"voice": "minotaur", "voice_pitch": 0.85, "role": "boss",
		"name": "The Ashen King", "script": "res://src/entities/enemies/ashen_king.gd", "sheet": "ashen_king",
		"hp": 3400.0, "speed": 3.2, "radius": 0.9, "poise": 420.0, "damage": 26.0, "armor": 0.1,
		"xp": 320, "embers": 240, "cost": 99, "min_depth": 99, "boss": true,
		"epithet": "Last of the Sun-Kings", "fall": "The Ashen King Falls",
		"lore": "He ruled the day. When the sun died, he would not kneel to the dark, so he burned instead - and is burning still.",
	},
	"toad": {
		"voice": "bigslime", "voice_pitch": 0.85, "role": "controller",
		"name": "Bog Toad", "script": "res://src/entities/enemies/toad.gd", "sheet": "toad",
		"hp": 70.0, "speed": 0.0, "radius": 0.45, "poise": 30.0, "damage": 15.0, "armor": 0.1,
		"xp": 10, "embers": 6, "cost": 4, "min_depth": 1,
		"lore": "Its tongue is longer than it is. It has never once been in a hurry.",
	},
	"bloom": {
		"voice": "pumpkin", "voice_pitch": 0.7, "role": "boss",
		"name": "The Hollow Bloom", "script": "res://src/entities/enemies/bloom.gd", "sheet": "bloom",
		"hp": 2600.0, "speed": 0.0, "radius": 1.6, "poise": 340.0, "damage": 20.0, "armor": 0.25,
		"xp": 240, "embers": 180, "cost": 99, "min_depth": 99, "boss": true,
		"epithet": "Heart of the Rootmire", "fall": "The Bloom Withers",
		"lore": "Where the sun's last seed fell, something grew that is not a flower.",
	},
	"warden": {
		"voice": "brute", "voice_pitch": 0.8, "role": "boss",
		"name": "The Gloam Warden", "script": "res://src/entities/enemies/warden.gd", "sheet": "warden",
		"hp": 1900.0, "speed": 3.0, "radius": 0.9, "poise": 260.0, "damage": 22.0, "armor": 0.0,
		"xp": 160, "embers": 120, "cost": 99, "min_depth": 99, "boss": true,
		"epithet": "Keeper of the Lightless Heart", "fall": "The Warden Falls",
		"lore": "Keeper of the Ossuary's lightless heart. It swallows every flame it finds.",
	},
}

## Roles: what a creature does in a fight, and the answer to it (bestiary).
const ROLES := {
	"brute": ["Brute", "Walks in and swings. Dodge the swing, punish the recovery."],
	"swarm": ["Swarm", "Fast, fragile, never alone. Sweep them."],
	"ranged": ["Ranged", "Keeps its distance. Close in, or Ward the shot back."],
	"tank": ["Tank", "Guards its front. Get behind it, or break its guard."],
	"summoner": ["Summoner", "Raises help. Kill it first."],
	"exploder": ["Exploder", "Its death is everyone's problem - its friends' too."],
	"controller": ["Controller", "Decides where you can stand."],
	"charger": ["Charger", "Rushes in a line. Sidestep, then punish."],
	"harrier": ["Harrier", "Darts in and out to wear you down."],
	"ambush": ["Ambush", "Strikes from hiding. Watch the floor and keep moving."],
	"support": ["Support", "Strengthens others. Break the link, or kill it first."],
	"artillery": ["Artillery", "Bombards marked ground from afar. Read the marks and close in."],
	"terrain": ["Terrain", "Reshapes the room. Fire and blades clear the way."],
	"duelist": ["Duelist", "Punishes careless swings. Learn its rhythm."],
	"beam": ["Beam", "Sweeps a line of light. Dash through it, or get behind the source."],
	"boss": ["Boss", ""],
}

## Elite affixes: a twist on an enemy, never just a bigger health bar.
const AFFIXES := {
	"hasted": {"name": "Hasted", "color": Color(1.0, 0.85, 0.35), "desc": "Moves and attacks faster."},
	"warded": {"name": "Warded", "color": Color(0.45, 0.8, 1.0), "desc": "Shielded by soul-light until the shield is broken."},
	"volatile": {"name": "Volatile", "color": Color(1.0, 0.45, 0.25), "desc": "Erupts in flame when it dies."},
	"vampiric": {"name": "Vampiric", "color": Color(0.9, 0.25, 0.35), "desc": "Heals whenever it wounds you."},
	"phasing": {"name": "Phasing", "color": Color(0.75, 0.5, 0.95), "desc": "Periodically slips out of the world, becoming untouchable."},
	"molten": {"name": "Molten", "color": Color(1.0, 0.5, 0.15), "desc": "Leaves a trail of burning ground. Don't chase it - make it come to you."},
	"splitting": {"name": "Splitting", "color": Color(0.6, 0.95, 0.5), "desc": "Splits into two lesser copies when it dies."},
	"gloom": {"name": "Gloom", "color": Color(0.6, 0.45, 0.9), "desc": "Wrapped in darkness: near it your lantern dims and Kindle comes at half the rate."},
}


## Whether an affix does anything on this creature (a rooted Mortar can't
## leave a trail; a burrower can't phase).
static func affix_ok(id: String, a: String) -> bool:
	var d: Dictionary = ENEMIES.get(id, {})
	if a == "molten" and float(d.get("speed", 1.0)) <= 0.0:
		return false
	return not (d.get("no_affix", []) as Array).has(a)


## A random affix that suits this creature.
static func roll_affix(rng: RandomNumberGenerator, id: String, exclude := "") -> String:
	var pool: Array = AFFIXES.keys().filter(func(k): return k != exclude and affix_ok(id, k))
	return String(pool[rng.randi_range(0, pool.size() - 1)])

## Regions: each has its own enemy pool, look and boss. Only the Ossuary is
## playable in the first slice; the others are seeds for expansion.
const REGIONS := {
	"ossuary": {
		"name": "The Hollow Ossuary",
		"theme": "crypt",
		"depths": 3,
		"pool": ["husk", "skitter", "archer", "guard", "bonecaller", "bloat", "spider", "gravemole", "lampwight"],
		"boss": "warden",
		"ambient": Color(0.3, 0.33, 0.55),
		"flame": Color(0.35, 0.95, 0.85),
		"music": "crypt",
		"ambience": "amb_crypt",
		"torch": "torch",
		"unlock": {},
		"blurb": "Three depths of bone and soul-light, then the Gloam Warden.",
	},
	"rootmire": {
		"name": "The Rootmire",
		"theme": "root",
		"depths": 3,
		"pool": ["sporeling", "thornback", "moth", "rootweaver", "toad", "husk", "archer", "spore_mortar", "bramblewright"],
		"boss": "bloom",
		"ambient": Color(0.3, 0.46, 0.38),
		"flame": Color(0.55, 1.0, 0.45),
		"music": "rootmire",
		"ambience": "amb_root",
		"torch": "torch_bio",
		"unlock": {"warden_kills": 1},
		"blurb": "Fungal caverns among the roots of a dead world-tree. Brambles burn. The Hollow Bloom waits.",
		"sealed": "Sealed. Defeat the Gloam Warden to open the way.",
		"victory": "The Bloom Is Withered",
		"memory_bonus": 1,
	},
	"throne": {
		"name": "The Sunken Throne",
		"theme": "throne",
		"depths": 3,
		"pool": ["sentinel", "hound", "acolyte", "wraith", "duelist", "sunwatcher"],
		"boss": "ashen_king",
		"ambient": Color(0.5, 0.4, 0.38),
		"flame": Color(1.0, 0.72, 0.35),
		"music": "throne",
		"ambience": "amb_throne",
		"torch": "torch_warm",
		"brazier": "brazier_warm",
		"unlock": {"warden_kills": 1, "bloom_kills": 1},
		"blurb": "The capstone. Three depths of the sun-king's drowned court, then the Ashen King. Win here to open harder tiers.",
		"sealed": "Sealed. Fell both the Gloam Warden and the Hollow Bloom.",
		"victory": "The Last Sun-King Is Ash",
		"memory_bonus": 2,
	},
}


static func region_unlocked(id: String) -> bool:
	var req: Dictionary = REGIONS.get(id, {}).get("unlock", {})
	for k in req:
		if int(Profile.data.world.get(k, 0)) < int(req[k]):
			return false
	return true


## The region's one-point creature (packs come in this size), skitters by default.
static func _filler(region: String) -> String:
	for id in REGIONS[region].pool:
		if int(ENEMIES[id].cost) == 1:
			return id
	return "skitter"


static func get_def(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


## Squads: every fight is built around a pairing of roles, so it has a shape -
## a wall with shooters behind it, a guarded caster, a pack with a bomb in it -
## rather than a random heap. Slots are filled in order; the rest of the budget
## is spent freely. A squad is only used where its region has the roles.
const SQUADS := {
	"line": [["tank", "brute", "duelist", "charger"], ["ranged", "artillery", "beam"]],
	"pack": [["swarm"], ["swarm", "harrier"], ["exploder", "ranged", "harrier"]],
	"ward": [["support"], ["tank", "brute", "duelist", "charger"]],
	"court": [["summoner"], ["brute", "tank", "duelist", "swarm"]],
	"snare": [["controller", "terrain"], ["ranged", "artillery", "beam", "harrier"]],
	"ambush": [["ambush"], ["ranged", "swarm", "exploder"]],
}
## How many of a role one fight may hold: two Lampwights shielding each other,
## or three Mortars, are not puzzles, just walls.
const ROLE_CAP := {"support": 1, "summoner": 1, "terrain": 1, "artillery": 2, "beam": 2, "ambush": 2}


## Builds a list of enemy ids worth roughly `budget` points for a room.
static func roll_encounter(rng: RandomNumberGenerator, region: String, depth: int, budget: int) -> Array:
	var pool: Array = []
	for id in REGIONS[region].pool:
		var d: Dictionary = ENEMIES[id]
		if int(d.min_depth) <= depth:
			pool.append(id)
	var out: Array = []
	var left := budget
	# the squad that shapes this fight
	var fits: Array = []
	for sq in SQUADS:
		var ok := true
		for slot in SQUADS[sq]:
			if pool.filter(func(i): return (slot as Array).has(ENEMIES[i].get("role", ""))).is_empty():
				ok = false
		if ok:
			fits.append(sq)
	if not fits.is_empty():
		fits.sort()   # dictionary order is stable, but be explicit for determinism
		var sq: String = fits[rng.randi_range(0, fits.size() - 1)]
		for slot in SQUADS[sq]:
			var cands: Array = pool.filter(func(i): return (slot as Array).has(ENEMIES[i].get("role", "")) and _fits(i, out, left))
			if cands.is_empty():
				continue
			left -= _add(rng, String(cands[rng.randi_range(0, cands.size() - 1)]), out, left)
	var guard := 0
	while left > 0 and guard < 40:
		guard += 1
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not _fits(id, out, left):
			if left <= 1:
				id = _filler(region)
			else:
				continue
		left -= _add(rng, id, out, left)
	return out


static func _fits(id: String, out: Array, left: int) -> bool:
	if int(ENEMIES[id].cost) > left:
		return false
	var role := String(ENEMIES[id].get("role", ""))
	if ROLE_CAP.has(role):
		var n := out.filter(func(o): return ENEMIES[o].get("role", "") == role).size()
		if n >= int(ROLE_CAP[role]):
			return false
	return true


## Adds one creature (or a pack of it) and returns the budget it used.
static func _add(rng: RandomNumberGenerator, id: String, out: Array, left: int) -> int:
	var d: Dictionary = ENEMIES[id]
	if d.has("pack"):
		var n := mini(rng.randi_range(int(d.pack[0]), int(d.pack[1])), left)
		for k in n:
			out.append(id)
		return n
	out.append(id)
	return int(d.cost)
