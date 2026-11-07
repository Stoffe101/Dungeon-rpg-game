## Relics: temporary powers found during an expedition.
## Offers are weighted toward the tags of the player's skill-tree branches and
## the relics already held, so builds snowball into a recognisable identity.
class_name RelicDB
extends RefCounted

const RARITY_WEIGHT := {"common": 60.0, "rare": 30.0, "epic": 9.0}
const RARITY_COLOR := {
	"common": Color(0.82, 0.8, 0.74),
	"rare": Color(0.45, 0.78, 1.0),
	"epic": Color(1.0, 0.62, 0.25),
	"cursed": Color(0.85, 0.45, 0.95),
}

const RELICS := [
	# --- found, never offered ---
	{"id": "whetted", "name": "Whetted Edge", "rarity": "rare", "tags": [], "icon": "sword", "found": true,
		"mods": [["weapon_damage", "add", 0.12]], "desc": "+12% weapon damage. A travelling grindstone did this."},
	# --- common ---
	{"id": "tinderbox", "name": "Tinderbox", "rarity": "common", "tags": ["pyre"], "icon": "flame",
		"mods": [["burn_chance", "add", 0.12]], "desc": "+12% chance to Burn on hit."},
	{"id": "whetstone", "name": "Whetstone", "rarity": "common", "tags": ["blade"], "icon": "sword",
		"mods": [["melee_damage", "add", 0.15]], "desc": "+15% melee damage."},
	{"id": "rime_locket", "name": "Rime Locket", "rarity": "common", "tags": ["rime"], "icon": "snow",
		"mods": [["chill_chance", "add", 0.14]], "desc": "+14% chance to Chill on hit."},
	{"id": "runners_wraps", "name": "Runner's Wraps", "rarity": "common", "tags": ["gloam"], "icon": "boot",
		"mods": [["move_speed", "inc", 0.1], ["dodge_recharge", "more", -0.1]], "desc": "+10% movement speed. Dodges recharge 10% faster."},
	{"id": "bone_charm", "name": "Bone Charm", "rarity": "common", "tags": ["bulwark"], "icon": "heart",
		"mods": [["max_hp", "add", 20.0]], "desc": "+20 maximum health."},
	{"id": "wick_trimmer", "name": "Wick Trimmer", "rarity": "common", "tags": ["kindle"], "icon": "wick",
		"mods": [["ability_cost", "more", -0.15]], "desc": "Abilities cost 15% less Kindle."},
	{"id": "knucklebone", "name": "Lucky Knucklebone", "rarity": "common", "tags": ["blade"], "icon": "die",
		"mods": [["crit_chance", "add", 0.06]], "desc": "+6% critical strike chance."},
	{"id": "ember_pouch", "name": "Ember Pouch", "rarity": "common", "tags": [], "icon": "pouch",
		"mods": [["ember_gain", "add", 0.3]], "desc": "+30% Embers found."},
	{"id": "coal_heart", "name": "Coal Heart", "rarity": "common", "tags": ["pyre"], "icon": "coal",
		"mods": [["burn_damage", "add", 0.4]], "desc": "Burn deals +40% damage."},
	{"id": "glass_shard", "name": "Glass Shard", "rarity": "common", "tags": ["blade"], "icon": "shard",
		"mods": [["crit_mult", "add", 0.4]], "desc": "+40% critical strike damage."},
	{"id": "mourning_bell", "name": "Mourning Bell", "rarity": "common", "tags": ["bulwark"], "icon": "bell",
		"mods": [["life_on_kill", "add", 2.0]], "desc": "Heal 2 health whenever an enemy dies."},
	{"id": "soot_feather", "name": "Soot Feather", "rarity": "common", "tags": ["gloam"], "icon": "feather",
		"mods": [["dodge_distance", "inc", 0.25]], "desc": "+25% dodge distance."},
	{"id": "iron_ring", "name": "Iron Ring", "rarity": "common", "tags": ["bulwark"], "icon": "ring",
		"mods": [["armor", "add", 0.08]], "desc": "+8% armor."},
	{"id": "bellows", "name": "Bellows", "rarity": "common", "tags": ["pyre", "kindle"], "icon": "flare", "requires_ability": "flare",
		"flags": {"bellows": 1}, "desc": "Flare's radius is 40% larger and hurls enemies further."},

	# --- rare ---
	{"id": "cinder_crown", "name": "Cinder Crown", "rarity": "rare", "tags": ["pyre"], "icon": "crown",
		"flags": {"cinder_crown": 1}, "desc": "Burning enemies take 20% more damage from all sources."},
	{"id": "heart_of_rime", "name": "Heart of Rime", "rarity": "rare", "tags": ["rime"], "icon": "gem_blue",
		"flags": {"shatter": 1}, "mods": [["frost_damage", "add", 0.15]], "desc": "Grants Shatter. +15% frost damage."},
	{"id": "echo_mask", "name": "Echoing Mask", "rarity": "rare", "tags": ["gloam"], "icon": "mask",
		"flags": {"dodge_afterimage": 1}, "desc": "Dodging leaves an exploding shade. If you already leave shades, they deal double damage."},
	{"id": "mirror_shard", "name": "Mirror Shard", "rarity": "rare", "tags": ["bulwark"], "icon": "mirror",
		"flags": {"mirror_ward": 1}, "mods": [["parry_window", "add", 0.05]], "desc": "Reflected projectiles deal triple damage and pierce. Ward window +0.05s."},
	{"id": "hungry_lantern", "name": "Hungry Lantern", "rarity": "rare", "tags": ["kindle"], "icon": "lantern",
		"mods": [["kindle_gain", "inc", 0.35], ["kindle_max", "add", 25.0]], "desc": "+35% Kindle gained. +25 maximum Kindle."},
	{"id": "forked_ember", "name": "Forked Ember", "rarity": "rare", "tags": ["pyre", "kindle"], "icon": "fork",
		"flags": {"forked_ember": 1}, "desc": "Staff ember bolts fork into two when they strike."},
	{"id": "quake_stone", "name": "Quake Stone", "rarity": "rare", "tags": ["blade", "bulwark"], "icon": "stone",
		"mods": [["poise_damage", "add", 0.5]], "flags": {"quake_stone": 1}, "desc": "+50% poise damage. Staggered enemies take 25% more damage."},
	{"id": "bloodied_bandage", "name": "Bloodied Bandage", "rarity": "rare", "tags": ["blade"], "icon": "bandage",
		"flags": {"desperation": 1}, "desc": "While below 40% health, deal 35% more damage."},
	{"id": "wardens_sigil", "name": "Warden's Sigil", "rarity": "rare", "tags": ["blade"], "icon": "sigil",
		"flags": {"first_strike": 1}, "desc": "Your first hit against each enemy deals 60% more damage."},
	{"id": "hound_collar", "name": "Hound's Collar", "rarity": "rare", "tags": ["kindle"], "icon": "collar", "requires_ability": "wisp",
		"mods": [["summon_damage", "add", 0.6]], "flags": {"long_wisps": 1}, "desc": "Wisps deal +60% damage and linger 50% longer."},
	{"id": "pyre_brand", "name": "Pyre Brand", "rarity": "rare", "tags": ["pyre", "blade"], "icon": "brand",
		"flags": {"pyre_brand": 1}, "desc": "Critical hits apply 3 stacks of Burn."},
	{"id": "splinter_lance", "name": "Splinter Lance", "rarity": "rare", "tags": ["pyre"], "icon": "lance", "requires_ability": "cinder_lance",
		"flags": {"splinter_lance": 1}, "desc": "Cinder Lance throws three spears in a fan."},
	{"id": "glacier_seal", "name": "Glacier Seal", "rarity": "rare", "tags": ["rime"], "icon": "sigil", "requires_ability": "frost_sigil",
		"flags": {"glacier_seal": 1}, "desc": "Frost Sigil pulses two additional times and is 25% larger."},
	{"id": "twin_shade", "name": "Twin Shade", "rarity": "rare", "tags": ["gloam"], "icon": "gloamstep", "requires_ability": "gloamstep",
		"flags": {"twin_shade": 1}, "desc": "Gloamstep costs 40% less and its shade detonates twice."},
	{"id": "frost_spurs", "name": "Frost Spurs", "rarity": "rare", "tags": ["rime", "gloam"], "icon": "boot",
		"flags": {"frost_trail": 1}, "desc": "Dodging leaves a trail of rime that Chills enemies."},

	# --- epic ---
	{"id": "phoenix_feather", "name": "Phoenix Feather", "rarity": "epic", "tags": ["pyre", "bulwark"], "icon": "phoenix",
		"flags": {"phoenix": 1}, "desc": "The first time you would die, rise again at 50% health in an eruption of flame."},
	{"id": "prism_seasons", "name": "Prism of Seasons", "rarity": "epic", "tags": ["pyre", "rime"], "icon": "prism",
		"flags": {"thermal_shock": 1}, "mods": [["burn_chance", "add", 0.08], ["chill_chance", "add", 0.08]],
		"desc": "Grants Thermal Shock. +8% chance to Burn and to Chill."},
	{"id": "sun_shard", "name": "Shard of the Sun", "rarity": "epic", "tags": ["bulwark"], "icon": "sun",
		"mods": [["flask_charges", "add", 1.0], ["flask_heal", "add", 0.1]], "desc": "+1 Flask charge. Flasks heal 10% more.", "refill_flask": true},
	{"id": "hourglass_ash", "name": "Hourglass of Ash", "rarity": "epic", "tags": ["kindle"], "icon": "hourglass",
		"mods": [["cooldown", "more", -0.25], ["ability_cost", "more", -0.15]], "desc": "25% shorter cooldowns. Abilities cost 15% less."},

	# --- cursed: big power with a real cost ---
	{"id": "unlit_candle", "name": "The Unlit Candle", "rarity": "epic", "cursed": true, "tags": [], "icon": "candle",
		"mods": [["damage", "add", 0.5]], "flags": {"dim_lantern": 1}, "desc": "+50% damage. Your lantern's light shrinks to a guttering glow."},
	{"id": "gluttonous_wick", "name": "Gluttonous Wick", "rarity": "rare", "cursed": true, "tags": ["kindle"], "icon": "wick",
		"mods": [["kindle_max", "more", 1.0], ["kindle_gain", "inc", 0.5]], "flags": {"blood_price": 1}, "desc": "Double maximum Kindle and +50% Kindle gained. Each ability costs 4% of your health."},
	{"id": "oathbreaker", "name": "Oathbreaker's Ring", "rarity": "rare", "cursed": true, "tags": ["blade"], "icon": "ring_cursed",
		"mods": [["damage", "add", 0.35]], "flags": {"no_ward": 1}, "desc": "+35% damage. You can no longer Ward."},
	{"id": "glass_heart", "name": "Glass Heart", "rarity": "rare", "cursed": true, "tags": ["blade"], "icon": "gem_red",
		"mods": [["crit_chance", "add", 0.15], ["crit_mult", "add", 0.5], ["damage_taken", "more", 0.3]], "desc": "+15% crit chance and +50% crit damage. You take 30% more damage."},
]

static var _by_id: Dictionary = {}


static func relic(id: String) -> Dictionary:
	if _by_id.is_empty():
		for r in RELICS:
			_by_id[r.id] = r
	return _by_id.get(id, {})


## Picks `count` distinct relic offers.
## `held` relic ids are excluded; `branches` (branch -> count of allocated nodes)
## and the held relics' tags bias the draw toward the current build.
static func roll_offer(rng: RandomNumberGenerator, count: int, held: Array, branches: Dictionary, abilities: Array, depth: int, allow_cursed := true) -> Array:
	var pool: Array = []
	var held_tags := {}
	for h in held:
		for t in relic(h).get("tags", []):
			held_tags[t] = int(held_tags.get(t, 0)) + 1
	for r in RELICS:
		if held.has(r.id) or r.get("found", false):
			continue
		var req: String = r.get("requires_ability", "")
		if req != "" and not abilities.has(req):
			continue
		if r.get("cursed", false) and not allow_cursed:
			continue
		var w: float = RARITY_WEIGHT[r.rarity]
		if r.rarity == "epic":
			w *= 1.0 + 0.35 * float(depth - 1)
		var syn := 0.0
		for t in r.tags:
			syn += float(branches.get(t, 0)) * 0.12 + float(held_tags.get(t, 0)) * 0.35
		w *= 1.0 + minf(syn, 2.5)
		if req != "":
			w *= 1.6
		if r.get("cursed", false):
			w *= 0.5
		pool.append([r.id, w])
	var out: Array = []
	for i in count:
		var total := 0.0
		for p in pool:
			total += p[1]
		if total <= 0.0:
			break
		var x := rng.randf() * total
		for j in pool.size():
			x -= pool[j][1]
			if x <= 0.0:
				out.append(pool[j][0])
				pool.remove_at(j)
				break
	return out


static func apply(held: Array, stats: Stats) -> void:
	for id in held:
		var r := relic(id)
		stats.apply_mods(r.get("mods", []))
		stats.apply_flags(r.get("flags", {}))
		if id == "echo_mask" and stats.flag("dodge_afterimage") >= 2:
			stats.add_flag("afterimage_double")
