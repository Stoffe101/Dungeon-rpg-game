## Persistent progression: levels, currencies, skill tree, forge, sanctuary,
## unlocks, Grudges (nemeses) and statistics.
##
## Saves are versioned JSON written atomically (temp file + rename) with the
## previous good save kept as a .bak. Loading falls back to the backup if the
## main file is missing or corrupt, and old versions are migrated forward.
extends Node

signal changed

const VERSION := 8
## Levels stop at the cap: the Hearthtree costs far more points than a Kindled
## can ever have, so a build is a choice. Experience past the cap becomes Renown.
const MAX_LEVEL := 60
const PAGES := 3
const DEFAULT_PATH := "user://profile.json"
## While gear and crafting are being tested, saves get a stockpile of materials,
## embers and a few pieces of gear (once: on upgrading to v5 or on a new save).
const TEST_STOCKPILE := true

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
		"skill_pages": [["hearth"], ["hearth"], ["hearth"]],
		"skill_page": 0,
		"renown": 0,
		"renown_xp": 0,
		"feats": {},
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
		"inventory": {"bag": [], "equipped": {}, "materials": {}, "next_uid": 1, "known": [], "scrolls": [], "looks": ["kindled"], "look": "", "shown": {}},
		"difficulty": {"unlocked": 2, "selected": 1, "cleared": 0},
		"shop": {"stock": [], "for_run": -1},
		"descent": {"region": "ossuary", "omens": []},
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
	if loaded.is_empty() and TEST_STOCKPILE:
		_grant_stockpile(data)
		_grant_test_v6(data)
		for it in bag():
			Looks.unlock(Looks.look_of_base(String(it.base)))
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
	if v < 5:
		# v5: gear, materials and the peddler's stock
		if not out.has("inventory"):
			out["inventory"] = {"bag": [], "equipped": {}, "materials": {}, "next_uid": 1}
		if not out.has("shop"):
			out["shop"] = {"stock": [], "for_run": -1}
		if TEST_STOCKPILE:
			_grant_stockpile(out)
		v = 5
	if v < 6:
		# v6: blueprints (known / unread scrolls), looks (transmog), difficulty tiers
		var inv6: Dictionary = out.inventory
		for k in ["known", "scrolls"]:
			if not inv6.has(k):
				inv6[k] = []
		if not inv6.has("looks"):
			inv6["looks"] = ["kindled"]
		if not inv6.has("look"):
			inv6["look"] = ""
		if not out.has("difficulty"):
			out["difficulty"] = {"unlocked": 2, "selected": 1, "cleared": 0}
		if TEST_STOCKPILE:
			_grant_test_v6(out)
		# looks already earned by gear the Kindled owns
		var owned: Array = (inv6.bag as Array).duplicate()
		for s in inv6.equipped:
			if inv6.equipped[s] is Dictionary:
				owned.append(inv6.equipped[s])
		for it in owned:
			var lk := Looks.look_of_base(String((it as Dictionary).get("base", "")))
			if lk != "" and not (inv6.looks as Array).has(lk):
				(inv6.looks as Array).append(lk)
		v = 6
	if v < 7:
		# v7: level cap (levels past it become Renown), Hearthtree pages, feats
		var lvl := int(out.get("level", 1))
		if lvl > MAX_LEVEL:
			out["renown"] = lvl - MAX_LEVEL
			out["level"] = MAX_LEVEL
		var total := int(out.get("level", 1)) - 1 + int(out.get("unlocks", {}).get("bonus_points", 0))
		if SkillDB.spent(out.get("skills", ["hearth"])) > total:
			out["skills"] = ["hearth"]
		out["skill_pages"] = [(out.get("skills", ["hearth"]) as Array).duplicate(), ["hearth"], ["hearth"]]
		out["skill_page"] = 0
		if not out.has("feats"):
			out["feats"] = {}
		v = 7
	if v < 8:
		# v8: the Descent remembers the last region and Omens chosen
		if not out.has("descent"):
			out["descent"] = {"region": "ossuary", "omens": []}
		v = 8
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


## Adds experience; returns the number of levels gained.
func add_xp(amount: int) -> int:
	var gained := 0
	if level() >= MAX_LEVEL:
		_add_renown_xp(amount)
		_changed()
		return 0
	data.xp = int(data.get("xp", 0)) + amount
	while level() < MAX_LEVEL and int(data.xp) >= Combat.xp_to_next(level()):
		data.xp = int(data.xp) - Combat.xp_to_next(level())
		data.level = level() + 1
		gained += 1
	if level() >= MAX_LEVEL and int(data.xp) > 0:
		_add_renown_xp(int(data.xp))
		data.xp = 0
	if gained > 0:
		Events.level_up.emit(level())
	_changed()
	return gained


func renown() -> int:
	return int(data.get("renown", 0))


## Experience needed for the next Renown rank (the cost of the last level).
static func renown_step() -> int:
	return Combat.xp_to_next(MAX_LEVEL)


## Each Renown rank pays Embers, every fifth a Sunshard: worth playing on for,
## without inflating power.
func _add_renown_xp(amount: int) -> void:
	data["renown_xp"] = int(data.get("renown_xp", 0)) + amount
	while int(data.renown_xp) >= renown_step():
		data.renown_xp = int(data.renown_xp) - renown_step()
		data["renown"] = renown() + 1
		add_currency("embers", 60)
		if renown() % 5 == 0:
			add_currency("sunshards", 1)
		Events.toast.emit("Renown %d  (+60 Embers%s)" % [renown(), ", +1 Sunshard" if renown() % 5 == 0 else ""], Color(1.0, 0.85, 0.5))


## Swaps the Hearthtree to another saved page (in the sanctuary only).
func switch_page(i: int) -> void:
	i = clampi(i, 0, PAGES - 1)
	if not data.has("skill_pages"):
		data["skill_pages"] = [skills().duplicate(), ["hearth"], ["hearth"]]
	var pages: Array = data.skill_pages
	pages[int(data.get("skill_page", 0))] = skills().duplicate()
	data.skills = (pages[i] as Array).duplicate()
	if SkillDB.spent(data.skills) > skill_points_total():
		data.skills = ["hearth"]
	data["skill_page"] = i
	_changed()


func skill_page() -> int:
	return int(data.get("skill_page", 0))


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
	var cost := forge_cost(id)
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
	cost.merge(GearDB.FORGE_MATERIALS[lvl])
	if lvl == 2 or lvl == 6 or lvl == 9:
		cost["sunshards"] = 1 if lvl == 2 else 2
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
	apply_sanctuary_data(data.sanctuary, resident_mods(), stats)


## The sanctuary's gifts from plain data (so another player's sheet works too).
static func apply_sanctuary_data(sanct: Dictionary, res_mods: Array, stats: Stats) -> void:
	var h := int(sanct.get("hearth", 1))
	stats.add_mod("max_hp", "add", 10.0 * float(h - 1))
	var ap := int(sanct.get("apothecary", 0))
	if ap >= 1:
		stats.add_mod("flask_charges", "add", 1.0)
	if ap >= 2:
		stats.add_mod("flask_heal", "add", 0.1)
	if ap >= 3:
		stats.add_mod("flask_charges", "add", 1.0)
	stats.apply_mods(res_mods)


## The stat gifts of the residents whose requests are done.
func resident_mods() -> Array:
	var out: Array = []
	for r in Residents.LIST:
		if Residents.request_state(r.id) == "rewarded":
			out.append_array(r.request.reward)
	return out


## Everything another machine needs to build this Kindled exactly as this one
## would: the same data the local Kindled's stats come from (co-op).
func character_sheet() -> Dictionary:
	return {
		"name": String(Settings.get_value("player_name", "Kindled")),
		"level": level(),
		"skills": skills().duplicate(),
		"equipped": equipped().duplicate(true),
		"sanctuary": (data.sanctuary as Dictionary).duplicate(),
		"resident_mods": resident_mods(),
		"look": Looks.current(),
		"shown": (inv().get("shown", {}) as Dictionary).duplicate(),
		"weapon": equipped_weapon(),
		"weapon_level": weapon_level(equipped_weapon()),
		"slots": slots(),
	}


# --- gear and materials --------------------------------------------------------

## Materials, embers and three starter pieces, for trying crafting and gear.
static func _grant_stockpile(d: Dictionary) -> void:
	var inv: Dictionary = d.inventory
	var mats: Dictionary = inv.materials
	var pile := ItemDB.stockpile()
	for k in pile:
		mats[k] = int(mats.get(k, 0)) + int(pile[k])
	d["embers"] = int(d.get("embers", 0)) + 1500
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for b in [["gravecloth_hood", "common"], ["bone_gauntlets", "rare"], ["soft_boots", "epic"]]:
		var it := ItemDB.make_item(b[0], b[1], 1, rng)
		it.uid = int(inv.get("next_uid", 1))
		inv.next_uid = it.uid + 1
		(inv.bag as Array).append(it)


## For testing the v6 features: three blueprint scrolls to learn, a set piece
## of each tier set (two Emberwrought, enough to see a set bonus and its look)
## and more catalysts.
static func _grant_test_v6(d: Dictionary) -> void:
	var inv6: Dictionary = d.inventory
	var rng := RandomNumberGenerator.new()
	rng.seed = 6006
	for b in ["gamblers_coin", "seven_league_boots", "squeaky_clogs"]:
		if not (inv6.scrolls as Array).has(b) and not (inv6.known as Array).has(b):
			(inv6.scrolls as Array).append(b)
	for b in ["emberwrought_helm", "emberwrought_plate", "rimeguard_mail", "gloamweave_cloak", "verdant_robe"]:
		var it := ItemDB.make_item(b, "set", 1, rng, 2)
		it.uid = int(inv6.get("next_uid", 1))
		inv6.next_uid = it.uid + 1
		(inv6.bag as Array).append(it)
	var mats: Dictionary = inv6.materials
	for k in ["sun_gold", "eclipse_shard", "warden_sigil", "bloom_heart"]:
		mats[k] = int(mats.get(k, 0)) + (40 if k == "sun_gold" else 6)


## Blueprints the Kindled has learned (their uniques can be forged).
func known_blueprints() -> Array:
	return inv().get("known", [])


## Blueprint scrolls carried home but not yet read.
func scrolls() -> Array:
	if not inv().has("scrolls"):
		inv()["scrolls"] = []
	return inv().scrolls


func learn_blueprint(id: String) -> bool:
	if not scrolls().has(id):
		return false
	scrolls().erase(id)
	if not inv().has("known"):
		inv()["known"] = []
	if not (inv().known as Array).has(id):
		(inv().known as Array).append(id)
	_changed()
	return true


func inv() -> Dictionary:
	if not data.has("inventory"):
		data["inventory"] = {"bag": [], "equipped": {}, "materials": {}, "next_uid": 1}
	return data.inventory


func bag() -> Array:
	return inv().bag


func equipped() -> Dictionary:
	return inv().equipped


func material(id: String) -> int:
	return int(inv().materials.get(id, 0))


func add_material(id: String, n: int) -> void:
	inv().materials[id] = maxi(0, material(id) + n)
	_changed()


## Can pay a cost made of materials and/or currencies ({"grave_iron": 3, "embers": 80}).
func can_pay(cost: Dictionary) -> bool:
	for k in cost:
		var have := material(k) if ItemDB.MATERIALS.has(k) else currency(k)
		if have < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for k in cost:
		if ItemDB.MATERIALS.has(k):
			inv().materials[k] = material(k) - int(cost[k])
		else:
			data[k] = currency(k) - int(cost[k])
	_changed()
	Events.currency_changed.emit()
	return true


func add_item(item: Dictionary) -> Dictionary:
	Looks.unlock(Looks.look_of_base(String(item.get("base", ""))))
	var it := item.duplicate(true)
	it.uid = int(inv().get("next_uid", 1))
	inv().next_uid = it.uid + 1
	bag().append(it)
	_changed()
	return it


func find_item(uid: int) -> Dictionary:
	for it in bag():
		if int(it.uid) == uid:
			return it
	for s in equipped():
		var e: Variant = equipped()[s]
		if e is Dictionary and int((e as Dictionary).get("uid", -1)) == uid:
			return e
	return {}


func remove_item(uid: int) -> Dictionary:
	for i in bag().size():
		if int(bag()[i].uid) == uid:
			var it: Dictionary = bag()[i]
			bag().remove_at(i)
			_changed()
			return it
	return {}


## Equips a bag item into its slot; whatever was there goes back in the bag.
func equip(uid: int) -> bool:
	var it := remove_item(uid)
	if it.is_empty():
		return false
	var slot := String(ItemDB.base(String(it.base)).get("slot", ""))
	var old: Variant = equipped().get(slot)
	if old is Dictionary and not (old as Dictionary).is_empty():
		bag().append(old)
	equipped()[slot] = it
	_changed()
	return true


func unequip(slot: String) -> bool:
	var old: Variant = equipped().get(slot)
	if not (old is Dictionary) or (old as Dictionary).is_empty():
		return false
	equipped().erase(slot)
	bag().append(old)
	_changed()
	return true


## Breaks a bag item down into materials.
func salvage(uid: int) -> Dictionary:
	var it := remove_item(uid)
	if it.is_empty():
		return {}
	var y := ItemDB.salvage_yield(it)
	for k in y:
		inv().materials[k] = material(k) + int(y[k])
	_changed()
	return y


func apply_gear(stats: Stats) -> void:
	ItemDB.apply_equipped(equipped(), stats)


# --- grudges -----------------------------------------------------------------

const GRUDGE_NAMES := ["Morrow", "Vesk", "Ilgra", "Thane", "Corvin", "Ossa", "Brenn", "Ysolde", "Grisk", "Maul", "Sorrel", "Hake"]
const GRUDGE_TITLES := ["the Unburied", "Who Remembers", "of the Second Grave", "the Patient", "Lanternbane", "the Hungry", "Twice-Dead", "the Collector"]


## The enemy that killed you becomes a Grudge carrying the Embers you lost.
func record_grudge(enemy_id: String, lost_embers: int, depth: int, rng: RandomNumberGenerator) -> Dictionary:
	if enemy_id == "" or EnemyDB.get_def(enemy_id).get("boss", false):
		return {}
	for g in data.grudges:
		if g.enemy == enemy_id and not g.get("settled", false):
			g.level = mini(GRUDGE_MAX_LEVEL, int(g.level) + 1)
			g.embers = int(g.embers) + lost_embers
			g.depth = depth
			g["runs"] = 0
			_grudge_traits(g, rng)
			_changed()
			return g
	var g := {
		"id": "g%d" % Time.get_unix_time_from_system(),
		"enemy": enemy_id,
		"name": "%s %s" % [GRUDGE_NAMES[rng.randi_range(0, GRUDGE_NAMES.size() - 1)], GRUDGE_TITLES[rng.randi_range(0, GRUDGE_TITLES.size() - 1)]],
		"affix": EnemyDB.roll_affix(rng, enemy_id),
		"level": 1,
		"embers": lost_embers,
		"depth": depth,
		"settled": false,
	}
	data.grudges.append(g)
	_changed()
	return g


const GRUDGE_MAX_LEVEL := 5
## What a Grudge learns as it grows: a second affix, kin that follow it, and
## at the last a hunger fed by the Embers it carries.
const GRUDGE_TRAITS := {2: "twinned", 3: "escorted", 4: "ember_fed"}
const GRUDGE_TRAIT_TEXT := {"twinned": "a second affix", "escorted": "kin at its side", "ember_fed": "fed on your Embers"}


func _grudge_traits(g: Dictionary, rng: RandomNumberGenerator) -> void:
	var traits: Array = g.get("traits", [])
	for lv in GRUDGE_TRAITS:
		var t: String = GRUDGE_TRAITS[lv]
		if int(g.level) >= int(lv) and not traits.has(t):
			traits.append(t)
			if t == "twinned":
				g["affix2"] = EnemyDB.roll_affix(rng, String(g.enemy), String(g.get("affix", "")))
	g["traits"] = traits


## Grudges left alone grow in the dark: every third expedition that does not
## settle one, it gains a level and its hoard grows. Returns the names that grew.
func age_grudges(rng: RandomNumberGenerator) -> Array:
	var grew: Array = []
	for g in active_grudges():
		g["runs"] = int(g.get("runs", 0)) + 1
		if int(g.runs) % 3 == 0 and int(g.level) < GRUDGE_MAX_LEVEL:
			g.level = int(g.level) + 1
			g.embers = int(round(int(g.embers) * 1.15))
			_grudge_traits(g, rng)
			grew.append(String(g.name))
	if not grew.is_empty():
		_changed()
	return grew


func active_grudges() -> Array:
	return data.grudges.filter(func(g): return not g.get("settled", false))


func settle_grudge(gid: String) -> Dictionary:
	for g in data.grudges:
		if g.id == gid:
			g.settled = true
			stat_add("grudges_settled")
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


## For edits made directly to profile data (e.g. tempering an item in place).
func mark_changed() -> void:
	_changed()


func _changed() -> void:
	dirty = true
	changed.emit()
	Events.profile_changed.emit()
