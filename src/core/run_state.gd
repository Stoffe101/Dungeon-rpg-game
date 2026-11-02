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
var abilities: Array = ["flare", ""]
var result := ""            # "", "extracted", "died", "victory"
var killer_id := ""
var rng := RandomNumberGenerator.new()
var seen_rooms := 0


static func create(seed_v: int, region_id: String, weapon: String, wlevel: int, slots: Array) -> RunState:
	var r := RunState.new()
	r.seed = seed_v
	r.region = region_id
	r.weapon_id = weapon
	r.weapon_level = wlevel
	r.abilities = slots.duplicate()
	r.rng.seed = seed_v * 7919 + 13
	return r


func add_relic(id: String) -> void:
	if not relics.has(id):
		relics.append(id)


func has_relic(id: String) -> bool:
	return relics.has(id)


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
