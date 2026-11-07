## The noticeboard: what the survivors would like done down there. Three notices are
## up at a time and a Kindled may carry two. They never expire and nothing is lost by
## ignoring them: they suggest a way to play the next expedition and pay for it.
## Taken notices are kept in Profile.data.contracts; progress is counted through
## Dungeon.note_request like a resident's request, for every Kindled on their own
## machine, and paid when the expedition comes home.
class_name Contracts
extends RefCounted

const CARRY := 2
const OFFERS := 3

## `key` is what Dungeon.note_request counts. `pay`: embers, sunshards, xp, material
## ([id, n]), rune (true).
const LIST := [
	{"id": "vault", "title": "The Sealed Rooms", "line": "Open a barred vault.", "key": "vault", "goal": 1, "pay": {"embers": 240, "rune": true}},
	{"id": "rule", "title": "Strange Weather", "line": "Win a fight that keeps a rule of its own.", "key": "rule", "goal": 1, "pay": {"embers": 180, "xp": 120}},
	{"id": "elites", "title": "A Verse or Two", "line": "Bring down three champions.", "key": "elite", "goal": 3, "pay": {"embers": 200, "material": ["ember_core", 1]}},
	{"id": "room_kills", "title": "Let the Room Do It", "line": "Fell four foes with a falling column, a jar or a vent.", "key": "room_kill", "goal": 4, "pay": {"embers": 160, "xp": 140}},
	{"id": "flame", "title": "Stolen Light", "line": "Bring down a Snuffer that has your flame.", "key": "flame_back", "goal": 1, "pay": {"embers": 180, "material": ["soul_glass", 2]}},
	{"id": "form", "title": "The Rarer Thing", "line": "Fell a guardian in a form you have not learned.", "key": "form", "goal": 1, "pay": {"sunshards": 2, "rune": true}},
	{"id": "grudge", "title": "Old Scores", "line": "Settle a Grudge.", "key": "grudge", "goal": 1, "pay": {"embers": 260, "xp": 100}},
	{"id": "chests", "title": "Seed Money", "line": "Open six chests.", "key": "chest", "goal": 6, "pay": {"embers": 150, "material": ["bone_dust", 4]}},
	{"id": "brambles", "title": "Clear the Path", "line": "Cut or burn fifteen brambles.", "key": "bramble", "goal": 15, "pay": {"embers": 140, "material": ["rootwood", 3]}},
	{"id": "wards", "title": "Late, Not Early", "line": "Turn aside ten blows with a clean Ward.", "key": "ward", "goal": 10, "pay": {"embers": 150, "xp": 110}},
	{"id": "lantern", "title": "What You Dropped", "line": "Relight your own cold lantern.", "key": "lantern", "goal": 1, "pay": {"embers": 200, "sunshards": 1}},
	{"id": "shard", "title": "Warm Stones", "line": "Bring home two Sunshards.", "key": "sunshard", "goal": 2, "pay": {"embers": 220, "material": ["sun_gold", 1]}},
]


static func _rec() -> Dictionary:
	if not Profile.data.has("contracts"):
		Profile.data["contracts"] = {"offer": [], "taken": [], "done": 0}
	return Profile.data.contracts


static func def_of(id: String) -> Dictionary:
	for c in LIST:
		if String(c.id) == id:
			return c
	return {}


static func taken() -> Array:
	return _rec().taken


static func carrying(id: String) -> bool:
	for t in taken():
		if String(t.id) == id:
			return true
	return false


## What is on the board: filled up from those neither posted nor carried, in an order
## that depends on how many have been finished, so it changes as you work through it.
static func offers() -> Array:
	var r := _rec()
	var up: Array = (r.offer as Array).filter(func(id): return not def_of(String(id)).is_empty() and not carrying(String(id)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["board", int(r.done), int(Profile.data.stats.get("runs", 0)) / 2])
	var pool: Array = []
	for c in LIST:
		if not carrying(String(c.id)) and not up.has(c.id):
			pool.append(String(c.id))
	while up.size() < OFFERS and not pool.is_empty():
		up.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	r.offer = up
	return up


## Takes a notice off the board. False: hands full, or not on the board.
static func take(id: String) -> bool:
	if taken().size() >= CARRY or not offers().has(id) or carrying(id):
		return false
	taken().append({"id": id, "n": 0})
	(_rec().offer as Array).erase(id)
	return true


## Puts a notice back, its progress forgotten. Nothing else is lost.
static func drop(id: String) -> void:
	_rec().taken = taken().filter(func(t): return String(t.id) != id)


## Something happened down there. Returns the titles of those just finished.
static func note(key: String, amount := 1) -> Array:
	var done: Array = []
	for t in taken():
		var c := def_of(String(t.id))
		if String(c.get("key", "")) != key or int(t.n) >= int(c.goal):
			continue
		t.n = mini(int(t.n) + amount, int(c.goal))
		if int(t.n) >= int(c.goal):
			done.append(String(c.title))
	return done


static func finished(t: Dictionary) -> bool:
	return int(t.n) >= int(def_of(String(t.id)).get("goal", 1))


## Pays out whatever is finished (Game.end_run, on any way home). Lines for the summary.
static func settle() -> Array:
	var said: Array = []
	var keep: Array = []
	for t in taken():
		if not finished(t):
			keep.append(t)
			continue
		var c := def_of(String(t.id))
		_pay(c.pay)
		_rec().done = int(_rec().done) + 1
		Chronicle.mark("contracts")
		said.append("%s: %s" % [String(c.title), pay_text(c.pay)])
	_rec().taken = keep
	return said


static func _pay(p: Dictionary) -> void:
	if p.has("embers"):
		Profile.add_currency("embers", int(p.embers))
	if p.has("sunshards"):
		Profile.add_currency("sunshards", int(p.sunshards))
	if p.has("xp"):
		Profile.add_xp(int(p.xp), "contract")
	if p.has("material"):
		Profile.add_material(String(p.material[0]), int(p.material[1]))
	if p.get("rune", false):
		var ids: Array = Runes.RUNES.keys()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["contract", int(_rec().done), Profile.level()])
		Profile.add_rune(String(ids[rng.randi_range(0, ids.size() - 1)]))


static func pay_text(p: Dictionary) -> String:
	var bits: Array = []
	if p.has("embers"):
		bits.append("%d Embers" % int(p.embers))
	if p.has("sunshards"):
		bits.append("%d Sunshards" % int(p.sunshards))
	if p.has("xp"):
		bits.append("%d Memories" % int(p.xp))
	if p.has("material"):
		bits.append("%d %s" % [int(p.material[1]), String(ItemDB.MATERIALS.get(p.material[0], {}).get("name", p.material[0]))])
	if p.get("rune", false):
		bits.append("a rune")
	return ", ".join(PackedStringArray(bits))


## One line each, for the pause menu's journal.
static func journal() -> Array:
	var out: Array = []
	for t in taken():
		var c := def_of(String(t.id))
		out.append(["%s - %s  %d/%d" % [c.title, c.line, int(t.n), int(c.goal)], "complete" if finished(t) else "active"])
	return out
