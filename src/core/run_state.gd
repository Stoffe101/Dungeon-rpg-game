## Everything about the current expedition that is temporary.
## What survives a run is decided in Game.end_run() / RunState.settle().
class_name RunState
extends RefCounted

## Fraction of carried Embers kept when the Kindled falls. The rest is carried
## off by whatever killed you (a Grudge) and can be won back next time.
const DEATH_KEEP := 0.5
const VICTORY_BONUS := 0.25

var seed := 0
var region := "ossuary"
var tier := 1               # difficulty tier (see Difficulty)
var depth := 1
var relics: Array = []
var embers := 0
var sunshards := 0
var xp_gained := 0
var kills := 0
var rooms_cleared := 0
var elites_slain := 0
var grudges_settled: Array = []
var elapsed := 0.0
var hp := -1.0
var kindle := 0.0
var flask := -1
var second_wind_used := false
var phoenix_used := false
var weapon_id := "sword"
var weapon_level := 0
var abilities: Array = ["flare", "", ""]
var result := ""            # "", "extracted", "died", "victory"
var killer_id := ""
var rng := RandomNumberGenerator.new()
var seen_rooms := 0
## Materials picked up this expedition, banked at the end (half on a death).
## (Gear, runes and blueprints go into the Satchel when found - see `found` -
## and only a run saved before that change still carries them here.)
var route := ""                # the way this floor was reached (DungeonGen.ROUTES), "" the plain way
var routes: Array = []         # every way taken this expedition, in order
var loot := {"materials": {}, "gear": [], "blueprints": [], "runes": [], "reagents": []}
## Everything of one's own found this expedition: [{kind, what, drop}] (the
## summary's list; each was banked the moment it was taken).
var found: Array = []
## Omens read at the Descent (see Omens).
var omens: Array = []
## The Hollow Below (see Delve): the region changes as the party goes deeper.
var delve := false
## Co-op settlement (each Kindled banks its own run on its own machine):
var run_id := ""              # one id per expedition: a guest settles it once
var kill_counts := {}         # enemy id -> kills by the party (everyone's bestiary and stats)
var bosses: Array = []        # guardians felled with this Kindled in the party
var grudges_won: Array = []   # this Kindled's own Grudges settled on this run (ids)


static func create(seed_v: int, region_id: String, weapon: String, wlevel: int, slots: Array) -> RunState:
	var r := RunState.new()
	r.seed = seed_v
	r.region = region_id
	if region_id == "delve":
		r.delve = true
		r.region = Delve.region_for(1)
	r.weapon_id = weapon
	r.weapon_level = wlevel
	r.abilities = slots.duplicate()
	while r.abilities.size() < 3:
		r.abilities.append("")
	r.rng.seed = seed_v * 7919 + 13
	return r


## Everything a co-op client needs to settle this run on its own machine.
func to_dict() -> Dictionary:
	return {"seed": seed, "region": region, "tier": tier, "depth": depth, "relics": relics.duplicate(),
		"embers": embers, "sunshards": sunshards, "xp_gained": xp_gained, "kills": kills,
		"rooms_cleared": rooms_cleared, "elites_slain": elites_slain, "grudges_settled": grudges_settled.duplicate(),
		"elapsed": elapsed, "weapon_id": weapon_id, "weapon_level": weapon_level, "abilities": abilities.duplicate(),
		"loot": loot.duplicate(true), "found": found.duplicate(true), "omens": omens.duplicate(), "delve": delve, "run_id": run_id,
		"kill_counts": kill_counts.duplicate(), "bosses": bosses.duplicate(), "grudges_won": grudges_won.duplicate(),
		"route": route, "routes": routes.duplicate()}


static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.create(int(d.get("seed", 0)), String(d.get("region", "ossuary")), String(d.get("weapon_id", "sword")), int(d.get("weapon_level", 0)), d.get("abilities", ["flare", ""]))
	r.tier = int(d.get("tier", 1))
	r.depth = int(d.get("depth", 1))
	r.relics = (d.get("relics", []) as Array).duplicate()
	r.embers = int(d.get("embers", 0))
	r.sunshards = int(d.get("sunshards", 0))
	r.xp_gained = int(d.get("xp_gained", 0))
	r.kills = int(d.get("kills", 0))
	r.rooms_cleared = int(d.get("rooms_cleared", 0))
	r.elites_slain = int(d.get("elites_slain", 0))
	r.grudges_settled = (d.get("grudges_settled", []) as Array).duplicate()
	r.elapsed = float(d.get("elapsed", 0.0))
	r.loot = (d.get("loot", r.loot) as Dictionary).duplicate(true)
	r.found = (d.get("found", []) as Array).duplicate(true)
	r.omens = (d.get("omens", []) as Array).duplicate()
	r.delve = bool(d.get("delve", false))
	r.route = String(d.get("route", ""))
	r.routes = (d.get("routes", []) as Array).duplicate()
	r.run_id = String(d.get("run_id", ""))
	r.kill_counts = (d.get("kill_counts", {}) as Dictionary).duplicate()
	r.bosses = (d.get("bosses", []) as Array).duplicate()
	r.grudges_won = (d.get("grudges_won", []) as Array).duplicate()
	return r


func add_relic(id: String) -> void:
	if not relics.has(id):
		relics.append(id)


func has_relic(id: String) -> bool:
	return relics.has(id)


func has_omen(id: String) -> bool:
	return omens.has(id)


## What was found, in the summary's shape: {gear, runes, blueprints, materials}.
func found_summary() -> Dictionary:
	var out := {"materials": (loot.materials as Dictionary).duplicate(), "gear": [], "runes": [], "blueprints": [], "reagents": []}
	for f in found:
		match String(f.get("kind", "")):
			"gear":
				(out.gear as Array).append(f.what)
			"rune":
				(out.runes as Array).append(f.what)
			"blueprint":
				(out.blueprints as Array).append(f.what)
			"reagent":
				(out.reagents as Array).append(f.what)
	for k in ["gear", "runes", "blueprints", "reagents"]:
		(out[k] as Array).append_array(loot.get(k, []))
	return out


func add_material(id: String, n: int) -> void:
	loot.materials[id] = int(loot.materials.get(id, 0)) + n


## What of the loot survives: everything, or half the materials on a death
## (gear found is always kept).
func settle_loot(outcome: String) -> Dictionary:
	var mats := {}
	for k in loot.materials:
		var n := int(loot.materials[k])
		mats[k] = int(floor(n * DEATH_KEEP)) if outcome == "died" else n
	return {"materials": mats, "gear": (loot.gear as Array).duplicate(true), "blueprints": (loot.get("blueprints", []) as Array).duplicate(),
		"runes": (loot.get("runes", []) as Array).duplicate(), "reagents": (loot.get("reagents", []) as Array).duplicate()}


## Works out what the profile keeps from this run. Pure so it can be tested.
## Returns {"embers_kept", "embers_lost", "sunshards", "bonus"}.
func settle(outcome: String) -> Dictionary:
	var out := {"embers_kept": 0, "embers_lost": 0, "sunshards": sunshards, "bonus": 0}
	match outcome:
		"died":
			out.embers_kept = int(floor(embers * DEATH_KEEP))
			out.embers_lost = embers - out.embers_kept
		"victory":
			out.bonus = int(round(embers * VICTORY_BONUS))
			out.embers_kept = embers + out.bonus
		_:
			out.embers_kept = embers
	return out
