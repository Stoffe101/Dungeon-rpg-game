## Difficulty tiers, chosen at the Descent. Higher tiers make everything
## below tougher (health, damage, more elites, elites with two affixes) and
## richer (better rarities, stronger item tiers, more materials, set pieces and
## blueprints). Tiers I-II are open from the start; completing the capstone
## dungeon (the Sunken Throne) at your highest tier opens the next two.
class_name Difficulty
extends RefCounted

const MAX_TIER := 8
const START_UNLOCKED := 2

const TIERS := [
	{"name": "Kindling", "color": Color(0.85, 0.82, 0.75)},
	{"name": "Smoulder", "color": Color(1.0, 0.8, 0.45)},
	{"name": "Blaze", "color": Color(1.0, 0.62, 0.3)},
	{"name": "Inferno", "color": Color(1.0, 0.42, 0.25)},
	{"name": "Ashfall", "color": Color(0.85, 0.7, 0.65)},
	{"name": "Eclipse", "color": Color(0.8, 0.5, 1.0)},
	{"name": "Sunless", "color": Color(0.55, 0.6, 1.0)},
	{"name": "Undying Night", "color": Color(1.0, 0.3, 0.4)},
]


static func tier_name(t: int) -> String:
	return String(TIERS[clampi(t, 1, MAX_TIER) - 1].name)


static func tier_color(t: int) -> Color:
	return TIERS[clampi(t, 1, MAX_TIER) - 1].color


static func roman(t: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(t, 1, 10) - 1]


# --- what a tier does ---------------------------------------------------------

static func hp_mult(t: int) -> float:
	return pow(1.3, t - 1)


static func damage_mult(t: int) -> float:
	return pow(1.21, t - 1)


## Extra chance that a regular encounter brings an elite.
static func elite_chance(t: int) -> float:
	return 0.04 * (t - 1)


## From Tier IV, elites carry two affixes.
static func double_affix(t: int) -> bool:
	return t >= 4


static func loot_luck(t: int) -> float:
	return 0.03 * (t - 1)


static func reward_mult(t: int) -> float:
	return 1.0 + 0.25 * (t - 1)


static func material_mult(t: int) -> float:
	return 1.0 + 0.2 * (t - 1)


static func describe(t: int) -> Array:
	var out: Array = [
		"Enemies: %d%% health, %d%% damage" % [int(round(hp_mult(t) * 100.0)), int(round(damage_mult(t) * 100.0))],
		"Embers and Memories: %d%%" % int(round(reward_mult(t) * 100.0)),
		"Gear drops at Tier %s (x%.1f stats)" % [roman(t), ItemDB.tier_mult(t)],
	]
	if t >= 2:
		out.append("Set pieces can drop")
	if t >= 4:
		out.append("Elites carry two affixes")
	if elite_chance(t) > 0.0:
		out.append("More elites (+%d%%)" % int(round(elite_chance(t) * 100.0)))
	return out


# --- progress ------------------------------------------------------------------

static func _d() -> Dictionary:
	if not Profile.data.has("difficulty"):
		Profile.data["difficulty"] = {"unlocked": START_UNLOCKED, "selected": 1, "cleared": 0}
	return Profile.data.difficulty


static func unlocked() -> int:
	return clampi(int(_d().get("unlocked", START_UNLOCKED)), 1, MAX_TIER)


static func selected() -> int:
	return clampi(int(_d().get("selected", 1)), 1, unlocked())


static func select(t: int) -> void:
	_d()["selected"] = clampi(t, 1, unlocked())


## The highest tier the Kindled has won a region at (crafting happens at this tier).
static func best_won() -> int:
	return maxi(1, int(_d().get("cleared", 0)))


static func craft_tier() -> int:
	return best_won()


## A victory at tier t. The capstone opens the next two tiers when won at (or
## near) the top of what is unlocked. Returns the tiers newly unlocked.
static func on_victory(region: String, t: int) -> Array:
	var d := _d()
	d["cleared"] = maxi(int(d.get("cleared", 0)), t)
	var opened: Array = []
	if region == "throne" and t >= unlocked() - 1:
		var to := mini(MAX_TIER, maxi(unlocked(), t + 2))
		for k in range(unlocked() + 1, to + 1):
			opened.append(k)
		d["unlocked"] = to
	return opened


# --- how strong the Kindled is ---------------------------------------------------

## A single number for the Kindled's strength (tree, sanctuary and gear), 100 at
## the start of the game. Used to recommend a tier.
static func power() -> int:
	var st := Stats.for_player()
	SkillDB.apply(Profile.skills(), st)
	Profile.apply_sanctuary(st)
	Profile.apply_gear(st)
	var crit := clampf(st.v("crit_chance"), 0.0, 1.0)
	var offense := (1.0 + st.v("melee_damage") + st.v("damage") + 0.5 * (st.v("fire_damage") + st.v("frost_damage") + st.v("ability_damage")))
	offense *= (1.0 + crit * (st.v("crit_mult") - 1.0)) * st.v("attack_speed") * st.v("damage_more")
	var defense := st.v("max_hp") / maxf(0.2, 1.0 - clampf(st.v("armor"), 0.0, 0.75))
	var base_off := 1.0 + 0.05 * 0.75
	return int(round(100.0 * sqrt((offense / base_off) * (defense / 100.0))))


## The tier whose enemies roughly match the Kindled's power (never above unlocked).
static func recommended() -> int:
	return clampi(recommended_for(power()), 1, unlocked())


static func recommended_for(p: int) -> int:
	var ratio := float(p) / 100.0
	return clampi(1 + int(floor(log(maxf(ratio, 1.0)) / log(1.28))), 1, MAX_TIER)
