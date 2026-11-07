## The Chronicle: what the Undervault remembers. One record per save, three
## kinds of memory, nothing else:
##   sites - each region's Hollow Altar: rekindled, broken or bound by a pact.
##           A site changes every later expedition into that region, and can
##           always be changed again (at the altar, or let rest from the Shrine
##           of Memory): a choice opens things, it never ruins a world.
##   marks - counted deeds (ways taken, objectives won, wonders seen), read by
##           rare content and shown on the Shrine.
##   log   - the last lines of the story, in plain words, for the Shrine.
##
## Ownership in a party: the WORLD a party walks is the host's. Every machine
## builds its floors from the snapshot the host read at the start of the
## expedition (`snapshot`, carried by the run), so a guest's own sites are never
## overwritten and never leak into the host's game. A site chosen on the host's
## floor changes the host's Chronicle; each guest only marks that they saw it.
class_name Chronicle
extends RefCounted

const LOG_MAX := 40

const ALTARS := {
	"ossuary": {"name": "the Bone Vigil", "line": "Keepers once tended a flame here so the dead would sleep."},
	"rootmire": {"name": "the Root Vigil", "line": "The roots grew around this flame and did not put it out."},
	"throne": {"name": "the Sun Vigil", "line": "The court swore on this flame. The flame remembers the oaths."},
}

## What each state does to later expeditions into that region. Each opens
## something and costs something: none is the right answer.
const STATES := {
	"kindled": {"name": "Rekindled", "verb": "Rekindle the Vigil", "color": Color(1.0, 0.72, 0.38),
		"short": "A spring on every floor, and a flask more. The Vigil's order keeps the halls: fewer hidden things.",
		"done": "The Vigil burns again. Its keepers will know the way."},
	"broken": {"name": "Broken", "verb": "Break the seal", "color": Color(0.95, 0.35, 0.3),
		"short": "A Breach opens on every floor: a third way down, rich and deadly. Foes here go unbound.",
		"done": "The seal is broken. Something old has been let out."},
	"pact": {"name": "Pact", "verb": "Accept the Pale Pact", "color": Color(0.72, 0.62, 1.0),
		"short": "A Pale Bowl waits on every floor: blood for rare reagents. It feeds your Grudges too.",
		"done": "The pale flame takes your name. It will ask again."},
}


static func _rec() -> Dictionary:
	var d: Variant = Profile.data.get("chronicle")
	if not (d is Dictionary):
		Profile.data["chronicle"] = fresh()
		d = Profile.data.chronicle
	return d


static func fresh() -> Dictionary:
	return {"sites": {}, "marks": {}, "log": []}


## This save's own state of a region's altar ("" = untouched).
static func site(region: String) -> String:
	return String((_rec().sites as Dictionary).get(region, ""))


## The world's state as a run sees it: the run's snapshot (the host's, in a
## party), so every machine reads the same.
static func site_of(world: Dictionary, region: String) -> String:
	return String((world.get("sites", {}) as Dictionary).get(region, ""))


static func set_site(region: String, state: String, why := "") -> void:
	if state == "":
		(_rec().sites as Dictionary).erase(region)
	else:
		_rec().sites[region] = state
	mark("altar_" + (state if state != "" else "rested"))
	var altar := String(ALTARS.get(region, {}).get("name", "the Vigil"))
	note(why if why != "" else ("%s: %s." % [altar.capitalize(), String(STATES.get(state, {}).get("name", "left to rest"))]))
	Profile.mark_changed()


static func mark(id: String, n := 1) -> void:
	var m: Dictionary = _rec().marks
	m[id] = int(m.get(id, 0)) + n


static func marks(id: String) -> int:
	return int((_rec().marks as Dictionary).get(id, 0))


## One line of the story (the newest last).
static func note(text: String) -> void:
	var l: Array = _rec().log
	if not l.is_empty() and String(l.back()) == text:
		return
	l.append(text)
	while l.size() > LOG_MAX:
		l.pop_front()


## What an expedition's floors read: taken once when it starts, carried by the
## run (and to guests with it), so a floor is the same on every machine and
## after a rejoin, whatever changes meanwhile. `lair`: this Kindled (or party's
## host) has a Grudge grown enough to keep a lair.
static func snapshot() -> Dictionary:
	var lair := false
	for g in Profile.active_grudges():
		if int(g.get("level", 1)) >= 2:
			lair = true
	var felled := {}
	for region in EnemyDB.REGIONS:
		felled[region] = int(Profile.data.world.get("%s_kills" % EnemyDB.REGIONS[region].boss, 0))
	return {"sites": (_rec().sites as Dictionary).duplicate(), "lair": lair, "felled": felled,
		"falls": (_rec().get("falls", {}) as Dictionary).duplicate(true), "rescued": (_rec().get("rescued", []) as Array).duplicate()}


## Someone found alive: they live at this save's Hearth from now on.
static func rescue(id: String) -> void:
	var r := _rec()
	if not r.has("rescued"):
		r["rescued"] = []
	if not (r.rescued as Array).has(id):
		r.rescued.append(id)


static func rescued(id: String) -> bool:
	return (_rec().get("rescued", []) as Array).has(id)


## Where a Kindled last fell in a region: their lantern lies there, cold, until
## somebody relights it.
static func record_fall(region: String, depth: int, by: String) -> void:
	var r := _rec()
	if not r.has("falls"):
		r["falls"] = {}
	r.falls[region] = {"depth": depth, "by": by, "at": int(Time.get_unix_time_from_system())}


static func clear_fall(region: String) -> void:
	var r := _rec()
	if r.has("falls"):
		(r.falls as Dictionary).erase(region)


## Cost of letting an altar rest (the Shrine of Memory): a reversal is always
## there, and never free.
static func rest_cost() -> int:
	return 120
