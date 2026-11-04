## Feats: long goals that outlast any single build. Each one is earned once and
## pays out something: Embers, Sunshards, a wardrobe look, and for the great
## ones a skill point beyond the level cap (the only way past it).
class_name Feats
extends RefCounted

const FEATS := {
	"first_light": {"name": "First Light", "desc": "Come home from an expedition alive.", "goal": 1, "reward": {"embers": 100}},
	"warden": {"name": "Wardenfall", "desc": "Defeat the Gloam Warden.", "goal": 1, "reward": {"points": 1}},
	"bloom": {"name": "Uprooted", "desc": "Defeat the Hollow Bloom.", "goal": 1, "reward": {"points": 1}},
	"king": {"name": "Sunset", "desc": "Defeat the Ashen King.", "goal": 1, "reward": {"points": 1}},
	"inferno": {"name": "Inferno Walker", "desc": "Conquer the Sunken Throne on Tier IV or higher.", "goal": 4, "reward": {"points": 1}},
	"undying": {"name": "Undying Night", "desc": "Conquer the Sunken Throne on Tier VIII.", "goal": 8, "reward": {"points": 1, "look": "undying"}},
	"veteran": {"name": "Veteran", "desc": "Win ten expeditions.", "goal": 10, "reward": {"sunshards": 2}},
	"kills_100": {"name": "A Hundred Fallen", "desc": "Slay 100 foes.", "goal": 100, "reward": {"embers": 150}},
	"kills_1000": {"name": "A Thousand Fallen", "desc": "Slay 1,000 foes.", "goal": 1000, "reward": {"sunshards": 2}},
	"kills_10000": {"name": "Legion's End", "desc": "Slay 10,000 foes.", "goal": 10000, "reward": {"points": 1}},
	"elites": {"name": "Elite Hunter", "desc": "Slay 50 elites.", "goal": 50, "reward": {"sunshards": 2}},
	"grudges": {"name": "The Dungeon Forgets", "desc": "Settle 5 Grudges.", "goal": 5, "reward": {"sunshards": 2, "look": "wanderer"}},
	"masterwork": {"name": "Smith's Pride", "desc": "Forge a weapon to +7.", "goal": 7, "reward": {"embers": 300}},
	"ascended": {"name": "Ascension", "desc": "Forge a weapon to +10.", "goal": 10, "reward": {"points": 1}},
	"arsenal": {"name": "Arsenal", "desc": "Forge every weapon.", "goal": 5, "reward": {"sunshards": 3}},
	"scholar": {"name": "Scholar", "desc": "Learn 6 blueprints.", "goal": 6, "reward": {"sunshards": 2}},
	"archivist": {"name": "Archivist", "desc": "Learn every blueprint.", "goal": 13, "reward": {"points": 1}},
	"matched": {"name": "Matched", "desc": "Wear four pieces of one tier set.", "goal": 4, "reward": {"sunshards": 1}},
	"fashion": {"name": "Fashion of the Deep", "desc": "Unlock 6 looks in the wardrobe.", "goal": 6, "reward": {"embers": 300}},
	"wonders": {"name": "Wonders of the Deep", "desc": "Find the great landmark of every region.", "goal": 3, "reward": {"sunshards": 2}},
	"restored": {"name": "Hearth Restored", "desc": "Fully restore every sanctuary building.", "goal": 1, "reward": {"points": 1}},
	"cap": {"name": "Kindled Paragon", "desc": "Reach the level cap.", "goal": 60, "reward": {"sunshards": 3}},
	"renowned": {"name": "Renowned", "desc": "Reach Renown 10 (experience past the level cap).", "goal": 10, "reward": {"embers": 1000}},
}


static func earned(id: String) -> bool:
	return bool(Profile.data.get("feats", {}).get(id, false))


static func earned_count() -> int:
	var n := 0
	for id in FEATS:
		if earned(id):
			n += 1
	return n


## How far along a feat is, in the units of its goal.
static func progress(id: String) -> int:
	var d := Profile.data
	var st: Dictionary = d.get("stats", {})
	var w: Dictionary = d.get("world", {})
	match id:
		"first_light":
			return int(st.get("extractions", 0)) + int(st.get("victories", 0))
		"warden":
			return int(w.get("warden_kills", 0))
		"bloom":
			return int(w.get("bloom_kills", 0))
		"king":
			return int(w.get("ashen_king_kills", 0))
		"inferno", "undying":
			return int(d.get("difficulty", {}).get("throne_best", 0))
		"veteran":
			return int(st.get("victories", 0))
		"kills_100", "kills_1000", "kills_10000":
			return int(st.get("kills", 0))
		"elites":
			return int(st.get("elites", 0))
		"grudges":
			return int(st.get("grudges_settled", 0))
		"masterwork", "ascended":
			var best := 0
			for wid in d.get("weapons", {}):
				best = maxi(best, int(d.weapons[wid].get("level", 0)))
			return best
		"arsenal":
			var n := 0
			for wid in GearDB.WEAPONS:
				if bool(d.get("weapons", {}).get(wid, {}).get("unlocked", false)):
					n += 1
			return n
		"scholar", "archivist":
			return Profile.known_blueprints().size()
		"matched":
			var best2 := 0
			for s in ItemDB.set_counts(Profile.equipped()).values():
				best2 = maxi(best2, int(s))
			return best2
		"fashion":
			return Looks.unlocked().size()
		"wonders":
			return (d.get("seen", {}).get("landmarks", []) as Array).size()
		"restored":
			for b in Profile.SANCTUARY:
				if Profile.building(b) < int(Profile.SANCTUARY[b].max):
					return 0
			return 1
		"cap":
			return Profile.level()
		"renowned":
			return Profile.renown()
	return 0


static func goal(id: String) -> int:
	match id:
		"archivist":
			return ItemDB.blueprints().size()
		"arsenal":
			return GearDB.WEAPONS.size()
	return int(FEATS[id].goal)


## Grants every feat that has just been reached; returns their ids.
static func check() -> Array:
	if not Profile.data.has("feats"):
		Profile.data["feats"] = {}
	var out: Array = []
	for id in FEATS:
		if earned(id) or progress(id) < goal(id):
			continue
		Profile.data.feats[id] = true
		_grant(FEATS[id].reward)
		out.append(id)
	return out


static func _grant(r: Dictionary) -> void:
	if r.has("points"):
		var u: Dictionary = Profile.data.unlocks
		u["bonus_points"] = int(u.get("bonus_points", 0)) + int(r.points)
	if r.has("embers"):
		Profile.add_currency("embers", int(r.embers))
	if r.has("sunshards"):
		Profile.add_currency("sunshards", int(r.sunshards))
	if r.has("look"):
		Looks.unlock(String(r.look))


static func describe_reward(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("points"):
		parts.append("+%d skill point" % int(r.points))
	if r.has("embers"):
		parts.append("%d Embers" % int(r.embers))
	if r.has("sunshards"):
		parts.append("%d Sunshard%s" % [int(r.sunshards), "" if int(r.sunshards) == 1 else "s"])
	if r.has("look"):
		parts.append("look: %s" % Looks.LOOKS[r.look].name)
	return ", ".join(PackedStringArray(parts))
