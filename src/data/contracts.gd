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
	{"id": "secret", "title": "Behind the Walls", "line": "Find two hidden rooms.", "key": "secret", "goal": 2, "pay": {"embers": 220, "material": ["soul_glass", 2]}},
	{"id": "hearths", "title": "Somebody's Home", "line": "Light the three hearths of a settlement.", "key": "settlement", "goal": 1, "pay": {"embers": 240, "xp": 140}},
	{"id": "cage", "title": "An Empty Cage", "line": "Strike down every soul of the Warden's Harvest before they reach it.", "key": "cage", "goal": 1, "after": "warden_kills", "pay": {"sunshards": 1, "rune": true}},
	{"id": "choke", "title": "A Mouthful", "line": "Choke the Hollow Bloom as it breathes in.", "key": "choke", "goal": 1, "after": "bloom_kills", "pay": {"sunshards": 1, "material": ["bloom_heart", 1]}},
	{"id": "defy", "title": "The Lantern Holds", "line": "Hold off an Eclipse with a Ward as it lands.", "key": "defy", "goal": 1, "after": "ashen_king_kills", "pay": {"sunshards": 2, "rune": true}},
	# longer errands: one thing leads to the next
	{"id": "c_lamplighter", "title": "The Lamplighter's Round", "line": "Bram wants the old round walked, one more time.", "key": "", "goal": 3,
		"stages": [["settlement", 1, "Light a settlement's hearths: start where people lived."], ["secret", 1, "Find what the lamplighters walled up."], ["lantern", 1, "Relight your own cold lantern: end where you fell."]], "pay": {"embers": 420, "sunshards": 2, "rune": true}},
	{"id": "c_clapper", "title": "The Bellfounder's Clapper", "line": "Teodric swears the old bell's clapper is still down there.", "key": "", "goal": 3,
		"stages": [["chest", 3, "Open three chests for word of it."], ["vault", 1, "Open the barred vault it was kept in."], ["grudge", 1, "Whatever took it holds a Grudge: settle one."]], "pay": {"embers": 420, "sunshards": 2, "rune": true}},
	{"id": "c_tremor", "title": "What Moves Under the Floor", "line": "The Hearth shook. Three nights, the same hour.", "key": "", "goal": 3,
		"stages": [["elite", 2, "Bring down two champions and ask them with your blade."], ["rule", 1, "Win a fight the floor itself has rules for."], ["form", 1, "Fell a guardian in a form you have not learned."]], "pay": {"embers": 480, "material": ["ember_core", 3]}},
	{"id": "c_seedbed", "title": "A Bed for the Seedlings", "line": "Ama wants soil from under a room that was fought over.", "key": "", "goal": 3,
		"stages": [["bramble", 8, "Clear eight thorns: they strangle what grows."], ["room_kill", 2, "Let the room do your work twice: what falls feeds the soil."], ["chest", 2, "Bring back two caches of seed."]], "pay": {"embers": 300, "xp": 260, "material": ["rootwood", 5]}},
	# a technique practised: these go up for whoever has the technique to practise
	{"id": "t_cadence", "title": "In Time", "line": "Land thirty strikes in Cadence.", "key": "cadence", "goal": 30, "tech": "cadence", "pay": {"embers": 220, "xp": 150}},
	{"id": "t_behind", "title": "From the Shadows", "line": "Strike twenty foes from behind.", "key": "behind", "goal": 20, "tech": "behind", "pay": {"embers": 220, "material": ["soul_glass", 2]}},
	{"id": "t_point", "title": "The Sweet Spot", "line": "Strike twenty-five foes with the point of a thrust.", "key": "point", "goal": 25, "tech": "point", "pay": {"embers": 220, "material": ["grave_iron", 3]}},
	{"id": "t_breaker", "title": "Breaking Point", "line": "Break ten foes and shake those beside them.", "key": "breaker", "goal": 10, "tech": "breaker", "pay": {"embers": 220, "material": ["ember_core", 1]}},
	{"id": "t_overcharge", "title": "Overflowing", "line": "Loose eight Overcharged blows.", "key": "overcharge", "goal": 8, "tech": "overcharge", "pay": {"embers": 220, "xp": 150}},
	{"id": "t_focus", "title": "Unbroken", "line": "Gather full Focus five times.", "key": "focus_full", "goal": 5, "tech": "focus", "pay": {"embers": 220, "sunshards": 1}},
	# hunts: once a region's guardian has fallen, it can be tracked down there again
	{"id": "hunt_ossuary", "title": "The Warden's Trail", "line": "Hunt the Gloam Warden through the Ossuary: read its trail, bring down its harbinger, fell it in its rarer form.", "key": "hunt_ossuary", "goal": 1, "hunt": "ossuary", "pay": {"sunshards": 3, "rune": true}},
	{"id": "hunt_rootmire", "title": "The Bloom's Roots", "line": "Hunt the Hollow Bloom through the Rootmire: read its trail, bring down its harbinger, fell it in its rarer form.", "key": "hunt_rootmire", "goal": 1, "hunt": "rootmire", "pay": {"sunshards": 3, "rune": true}},
	{"id": "hunt_throne", "title": "The Eclipse Hunt", "line": "Hunt the Ashen King through the Sunken Throne: read its trail, bring down its harbinger, fell it in its rarer form.", "key": "hunt_throne", "goal": 1, "hunt": "throne", "pay": {"sunshards": 4, "rune": true}},
	# the old hands' notices: up once a guardian has fallen to you, for those who want them
	{"id": "untouched", "title": "Not a Mark on You", "line": "Leave a floor without one blow landing on anybody.", "key": "clean_floor", "goal": 1, "pay": {"sunshards": 2, "xp": 200}, "mastery": true},
	{"id": "dry", "title": "Without Drinking", "line": "Fell a guardian without touching your flask.", "key": "dry_guardian", "goal": 1, "pay": {"sunshards": 3, "rune": true}, "mastery": true},
	{"id": "quick", "title": "Before the Candle Burns Down", "line": "Leave a floor inside two and a half minutes.", "key": "quick_floor", "goal": 1, "pay": {"embers": 320, "material": ["ember_core", 1]}, "mastery": true},
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


## A hunt goes up once its guardian has fallen to this save; a technique's notice for
## whoever wields a weapon that knows it (or has learned it on the Hearthtree).
static func _huntable(c: Dictionary) -> bool:
	if c.has("tech"):
		var arch := Profile.equipped_weapon()
		return String(Weapon.TECHNIQUES.get(arch, "")) == String(c.tech) or Profile.skills().has("t_" + String(c.tech))
	if c.has("after") and int(Profile.data.world.get(String(c.after), 0)) <= 0:
		return false       # (a thing you have to have met, first)
	if not c.has("hunt"):
		return true
	var boss: String = EnemyDB.REGIONS[String(c.hunt)].boss
	return int(Profile.data.world.get("%s_kills" % boss, 0)) > 0


## The regions this Kindled carries a hunt for (Chronicle.snapshot: the host's, in a party).
static func hunt_regions() -> Array:
	var out: Array = []
	for t in taken():
		var c := def_of(String(t.id))
		if c.has("hunt") and not finished(t):
			out.append(String(c.hunt))
	return out


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
	var seasoned := int(Profile.data.stats.get("victories", 0)) > 0
	for c in LIST:
		if not carrying(String(c.id)) and not up.has(c.id) and (seasoned or not c.get("mastery", false)) and _huntable(c):
			pool.append(String(c.id))
	# a hunt that can be had is always on the board (one at a time)
	var hunt_up := up.any(func(id): return def_of(String(id)).has("hunt"))
	if not hunt_up and up.size() < OFFERS:
		for id in pool:
			if def_of(String(id)).has("hunt"):
				up.append(id)
				pool.erase(id)
				break
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
		if c.has("stages"):
			# an errand: only the stage it has reached counts
			if int(t.n) >= int(c.goal):
				continue
			var st: Array = c.stages[int(t.n)]
			if String(st[0]) != key:
				continue
			t["s"] = int(t.get("s", 0)) + amount
			if int(t.s) >= int(st[1]):
				t.s = 0
				t.n = int(t.n) + 1
				if int(t.n) >= int(c.goal):
					done.append(String(c.title))
				else:
					done.append("%s: %s" % [c.title, c.stages[int(t.n)][2]])
			continue
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
		if c.has("stages") and not finished(t):
			var st: Array = c.stages[int(t.n)]
			out.append(["%s - %s  %d/%d" % [c.title, st[2], int(t.get("s", 0)), int(st[1])], "active"])
			continue
		out.append(["%s - %s  %d/%d" % [c.title, c.line, int(t.n), int(c.goal)], "complete" if finished(t) else "active"])
	return out
