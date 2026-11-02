## Persistent progression: levels, currencies, skill tree, forge, sanctuary,
## unlocks, Grudges (nemeses) and statistics.
##
## Saves are versioned JSON written atomically (temp file + rename) with the
## previous good save kept as a .bak. Loading falls back to the backup if the
## main file is missing or corrupt, and old versions are migrated forward.
extends Node

signal changed

const VERSION := 4
const DEFAULT_PATH := "user://profile.json"

var path := DEFAULT_PATH
var data: Dictionary = {}
var dirty := false
var last_load_status := ""


func _ready() -> void:
	var p := OS.get_cmdline_user_args()
	for a in p:
		if a.begins_with("profile="):
			path = "user://" + a.substr(8)
	load_profile()


static func fresh() -> Dictionary:
	return {
		"version": VERSION,
		"created": Time.get_datetime_string_from_system(),
		"playtime": 0.0,
		"level": 1,
		"xp": 0,
		"embers": 0,
		"sunshards": 0,
		"skills": ["hearth"],
		"respecs": 0,
		"weapons": {"sword": {"unlocked": true, "level": 0}, "hammer": {"unlocked": false, "level": 0}, "staff": {"unlocked": false, "level": 0}},
		"equipped": {"weapon": "sword", "slots": ["flare", ""]},
		"sanctuary": {"hearth": 1, "forge": 0, "apothecary": 0, "shrine": 0},
		"unlocks": {},
		"grudges": [],
		"world": {"memory": 0, "warden_kills": 0, "deepest": 0},
		"stats": {"runs": 0, "deaths": 0, "extractions": 0, "victories": 0, "kills": 0, "embers_earned": 0, "best_time": 0.0},
		"seen": {"relics": [], "enemies": []},
		"flags": {"intro_done": false},
		"requests": {},
	}


# --- persistence -----------------------------------------------------------

func load_profile() -> void:
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(path + ".bak")
		if not loaded.is_empty():
			last_load_status = "restored_backup"
			push_warning("Profile: main save unreadable, restored backup")
		else:
			last_load_status = "new" if not FileAccess.file_exists(path) else "corrupt_reset"
	else:
		last_load_status = "ok"
	data = migrate(loaded) if not loaded.is_empty() else fresh()
	changed.emit()


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var txt := FileAccess.get_file_as_string(p)
	if txt.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary and parsed.has("version"):
		return parsed
	return {}


## Writes the profile atomically and keeps the previous save as a backup.
func save_profile() -> bool:
	data.version = VERSION
	var txt := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Profile: cannot write " + tmp)
		return false
	f.store_string(txt)
	f.close()
	# verify what we wrote parses before replacing the real save
	var check: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if not (check is Dictionary):
		push_error("Profile: verification failed, keeping old save")
		return false
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			dir.remove(path.get_file() + ".bak")
		dir.rename(path.get_file(), path.get_file() + ".bak")
	var err := dir.rename(tmp.get_file(), path.get_file())
	dirty = false
	return err == OK


func reset_profile() -> void:
	data = fresh()
	save_profile()
	changed.emit()


## Brings any older save up to the current version without losing progress.
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := int(out.get("version", 1))
	if v < 2:
		# v2: currencies split into embers + sunshards; skills became a list
		if out.has("currency"):
			out["embers"] = int(out.currency)
			out.erase("currency")
		if out.get("skills") is Dictionary:
			out["skills"] = (out.skills as Dictionary).keys()
		v = 2
	if v < 3:
		# v3: sanctuary buildings, grudges, world memory
		if not out.has("sanctuary"):
			out["sanctuary"] = {"hearth": 1, "forge": 0, "apothecary": 0, "shrine": 0}
		if not out.has("grudges"):
			out["grudges"] = []
		v = 3
	if v < 4:
		# v4: resident requests (id -> {state, n}); mastery ranks reuse the skills list
		if not out.has("requests"):
			out["requests"] = {}
		v = 4
	# fill any missing keys from a fresh profile (forward compatible)
	var f := fresh()
	for k in f:
		if not out.has(k):
			out[k] = f[k]
		elif f[k] is Dictionary and out[k] is Dictionary:
			for k2 in f[k]:
				if not out[k].has(k2):
					out[k][k2] = f[k][k2]
	if not (out.skills as Array).has("hearth"):
		out.skills.push_front("hearth")
	out["version"] = VERSION
	return out


# --- convenience -------------------------------------------------------------

func skills() -> Array:
	return data.get("skills", ["hearth"])


func level() -> int:
	return int(data.get("level", 1))


func skill_points_total() -> int:
	return level() - 1 + int(data.get("unlocks", {}).get("bonus_points", 0))


func skill_points_free() -> int:
	return skill_points_total() - SkillDB.spent(skills())


func allocate(id: String) -> bool:
	if not SkillDB.can_allocate(id, skills(), skill_points_free()):
		return false
	data.skills.append(id)
	_changed()
	return true


func refund(id: String) -> bool:
	if not SkillDB.can_refund(id, skills()):
		return false
	data.skills.erase(id)
	_changed()
	return true


func respec_cost() -> int:
	return 0 if int(data.get("respecs", 0)) == 0 else 40 + 40 * int(data.respecs)


func respec() -> bool:
	var c := respec_cost()
	if not spend("embers", c):
		return false
	data.skills = ["hearth"]
	data.respecs = int(data.get("respecs", 0)) + 1
	_changed()
	return true


func currency(kind: String) -> int:
	return int(data.get(kind, 0))


func add_currency(kind: String, amount: int) -> void:
	data[kind] = currency(kind) + amount
	if kind == "embers" and amount > 0:
		data.stats.embers_earned = int(data.stats.get("embers_earned", 0)) + amount
	_changed()
	Events.currency_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if currency(k) < int(cost[k]):
			return false
	return true


func spend(kind: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if currency(kind) < amount:
		return false
	data[kind] = currency(kind) - amount
	_changed()
	Events.currency_changed.emit()
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		data[k] = currency(k) - int(cost[k])
	_changed()
	Events.currency_changed.emit()
	return true


## Adds experience; returns the number of levels gained.
func add_xp(amount: int) -> int:
	var gained := 0
	data.xp = int(data.get("xp", 0)) + amount
	while int(data.xp) >= Combat.xp_to_next(level()):
		data.xp = int(data.xp) - Combat.xp_to_next(level())
		data.level = level() + 1
		gained += 1
	if gained > 0:
		Events.level_up.emit(level())
	_changed()
	return gained


func weapon_level(id: String) -> int:
	return int(data.weapons.get(id, {}).get("level", 0))


func weapon_unlocked(id: String) -> bool:
	return bool(data.weapons.get(id, {}).get("unlocked", false))


func unlock_weapon(id: String) -> void:
	if not data.weapons.has(id):
		data.weapons[id] = {"unlocked": true, "level": 0}
	data.weapons[id].unlocked = true
	_changed()


func upgrade_weapon(id: String) -> bool:
	var lvl := weapon_level(id)
	if lvl >= GearDB.FORGE_MAX:
		return false
	var cost := {"embers": GearDB.FORGE_COSTS[lvl]}
	if lvl == 2:
		cost["sunshards"] = 1
	if not pay(cost):
		return false
	data.weapons[id].level = lvl + 1
	_changed()
	return true


func forge_cost(id: String) -> Dictionary:
	var lvl := weapon_level(id)
	if lvl >= GearDB.FORGE_MAX:
		return {}
	var cost := {"embers": GearDB.FORGE_COSTS[lvl]}
	if lvl == 2:
		cost["sunshards"] = 1
	return cost


func equipped_weapon() -> String:
	var w: String = data.equipped.get("weapon", "sword")
	return w if weapon_unlocked(w) else "sword"


func slots() -> Array:
	var s: Array = data.equipped.get("slots", ["flare", ""]).duplicate()
	var avail := SkillDB.abilities(skills())
	for i in s.size():
		if s[i] != "" and not avail.has(s[i]):
			s[i] = ""
	if s[0] == "" and s[1] != "flare":
		s[0] = "flare"
	return s


func set_slot(i: int, ability: String) -> void:
	var s: Array = data.equipped.get("slots", ["flare", ""])
	var other := 1 - i
	if s[other] == ability:
		s[other] = s[i]
	s[i] = ability
	data.equipped.slots = s
	_changed()


# --- sanctuary ---------------------------------------------------------------

const SANCTUARY := {
	"hearth": {"name": "The Last Hearth", "max": 4, "costs": [{}, {"embers": 120}, {"embers": 300, "sunshards": 1}, {"embers": 600, "sunshards": 2}],
		"desc": "Feed the Hearth. Each level grants +10 maximum health and lights more of the sanctuary."},
	"forge": {"name": "Ashen Forge", "max": 1, "costs": [{"embers": 80}],
		"desc": "Rebuild the forge to temper weapons and craft new ones."},
	"apothecary": {"name": "Ember Apothecary", "max": 3, "costs": [{"embers": 100}, {"embers": 250}, {"embers": 450, "sunshards": 1}],
		"desc": "Distil hearth-light: +1 flask charge at level 1 and 3, stronger flasks at level 2."},
	"shrine": {"name": "Shrine of Memory", "max": 1, "costs": [{"embers": 150, "sunshards": 1}],
		"desc": "Remember your Grudges. Settling a Grudge returns double its Embers."},
}


func building(id: String) -> int:
	return int(data.sanctuary.get(id, 0))


func building_cost(id: String) -> Dictionary:
	var b: Dictionary = SANCTUARY[id]
	var lvl := building(id)
	if lvl >= int(b.max):
		return {}
	return b.costs[lvl] if id != "hearth" else b.costs[lvl]


func upgrade_building(id: String) -> bool:
	var b: Dictionary = SANCTUARY[id]
	var lvl := building(id)
	if lvl >= int(b.max):
		return false
	var cost: Dictionary = b.costs[lvl]
	if not pay(cost):
		return false
	data.sanctuary[id] = lvl + 1
	_changed()
	return true


## Sanctuary bonuses applied to the player's stats.
func apply_sanctuary(stats: Stats) -> void:
	var h := building("hearth")
	stats.add_mod("max_hp", "add", 10.0 * float(h - 1))
	var ap := building("apothecary")
	if ap >= 1:
		stats.add_mod("flask_charges", "add", 1.0)
	if ap >= 2:
		stats.add_mod("flask_heal", "add", 0.1)
	if ap >= 3:
		stats.add_mod("flask_charges", "add", 1.0)
	Residents.apply_rewards(stats)


# --- grudges -----------------------------------------------------------------

const GRUDGE_NAMES := ["Morrow", "Vesk", "Ilgra", "Thane", "Corvin", "Ossa", "Brenn", "Ysolde", "Grisk", "Maul", "Sorrel", "Hake"]
const GRUDGE_TITLES := ["the Unburied", "Who Remembers", "of the Second Grave", "the Patient", "Lanternbane", "the Hungry", "Twice-Dead", "the Collector"]


## The enemy that killed you becomes a Grudge carrying the Embers you lost.
func record_grudge(enemy_id: String, lost_embers: int, depth: int, rng: RandomNumberGenerator) -> Dictionary:
	if enemy_id == "" or EnemyDB.get_def(enemy_id).get("boss", false):
		return {}
	for g in data.grudges:
		if g.enemy == enemy_id and not g.get("settled", false):
			g.level = int(g.level) + 1
			g.embers = int(g.embers) + lost_embers
			g.depth = depth
			_changed()
			return g
	var g := {
		"id": "g%d" % Time.get_unix_time_from_system(),
		"enemy": enemy_id,
		"name": "%s %s" % [GRUDGE_NAMES[rng.randi_range(0, GRUDGE_NAMES.size() - 1)], GRUDGE_TITLES[rng.randi_range(0, GRUDGE_TITLES.size() - 1)]],
		"affix": EnemyDB.AFFIXES.keys()[rng.randi_range(0, EnemyDB.AFFIXES.size() - 1)],
		"level": 1,
		"embers": lost_embers,
		"depth": depth,
		"settled": false,
	}
	data.grudges.append(g)
	_changed()
	return g


func active_grudges() -> Array:
	return data.grudges.filter(func(g): return not g.get("settled", false))


func settle_grudge(gid: String) -> Dictionary:
	for g in data.grudges:
		if g.id == gid:
			g.settled = true
			_changed()
			return g
	return {}


func note_seen(kind: String, id: String) -> void:
	var arr: Array = data.seen.get(kind, [])
	if not arr.has(id):
		arr.append(id)
		data.seen[kind] = arr


func stat_add(key: String, n: float = 1.0) -> void:
	data.stats[key] = float(data.stats.get(key, 0)) + n


func _changed() -> void:
	dirty = true
	changed.emit()
	Events.profile_changed.emit()
