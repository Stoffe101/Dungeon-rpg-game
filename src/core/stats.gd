## A bag of numeric stats plus behaviour flags.
##
## value = (base + sum(add)) * (1 + sum(inc)) * product(1 + more)
## Percent-style stats ("fire_damage", "crit_chance", ...) have base 0 and are
## built from "add" modifiers. Flags are integer levels that unlock behaviours
## ("dodge_afterimage": 1). Sources (skill tree, relics, gear) are rebuilt into
## a Stats object whenever they change.
class_name Stats
extends RefCounted

const PLAYER_BASE := {
	"max_hp": 100.0,
	"move_speed": 6.6,
	"armor": 0.0,
	"crit_chance": 0.05,
	"crit_mult": 1.75,
	"attack_speed": 1.0,
	"weapon_damage": 1.0,      # the weapon item's own might (Weapon.damage_scale)
	"dodge_charges": 2.0,
	"dodge_recharge": 1.1,
	"dodge_distance": 3.4,
	"dodge_iframes": 0.24,
	"kindle_max": 100.0,
	"kindle_gain": 1.0,
	"ability_cost": 1.0,
	"cooldown": 1.0,
	"burn_chance": 0.0,
	"burn_damage": 0.0,
	"burn_stacks": 3.0,
	"chill_chance": 0.0,
	"chill_power": 0.0,
	"status_duration": 1.0,
	"parry_window": 0.2,
	"flask_charges": 2.0,
	"flask_heal": 0.35,
	"pickup_radius": 2.6,
	"xp_gain": 1.0,
	"ember_gain": 1.0,
	"knockback": 1.0,
	"poise_damage": 1.0,
	"life_on_kill": 0.0,
	"kindle_on_kill": 0.0,
	"thorns": 0.0,
	"damage": 0.0,
	"melee_damage": 0.0,
	"ranged_damage": 0.0,
	"ability_damage": 0.0,
	"fire_damage": 0.0,
	"frost_damage": 0.0,
	"shadow_damage": 0.0,
	"damage_more": 1.0,
	"damage_taken": 1.0,
	"elite_damage": 0.0,
	"area": 1.0,
	"summon_damage": 0.0,
	"projectile_speed": 1.0,
	"projectiles": 0.0,       # extra shots per volley (Volley)
	"pierce": 0.0,
	"chain": 0.0,
	"fork": 0.0,
	"projectile_damage": 0.0,
	"heal_mult": 1.0,
}

var base: Dictionary = {}
var _add: Dictionary = {}
var _inc: Dictionary = {}
var _more: Dictionary = {}
var flags: Dictionary = {}
var _cache: Dictionary = {}


static func for_player() -> Stats:
	var s := Stats.new()
	s.base = PLAYER_BASE.duplicate()
	return s


func clear_mods() -> void:
	_add.clear()
	_inc.clear()
	_more.clear()
	flags.clear()
	_cache.clear()


## op: "add" (flat), "inc" (additive percent), "more" (multiplicative percent)
func add_mod(stat: String, op: String, value: float) -> void:
	var d: Dictionary
	match op:
		"inc":
			d = _inc
		"more":
			d = _more
		_:
			d = _add
	if op == "more":
		d[stat] = d.get(stat, 1.0) * (1.0 + value)
	else:
		d[stat] = d.get(stat, 0.0) + value
	_cache.erase(stat)


func add_flag(f: String, n: int = 1) -> void:
	flags[f] = int(flags.get(f, 0)) + n


func flag(f: String) -> int:
	return int(flags.get(f, 0))


func has(f: String) -> bool:
	return int(flags.get(f, 0)) > 0


func v(stat: String) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var val: float = (float(base.get(stat, 0.0)) + float(_add.get(stat, 0.0))) * (1.0 + float(_inc.get(stat, 0.0))) * float(_more.get(stat, 1.0))
	_cache[stat] = val
	return val


## Outgoing damage multiplier for a hit carrying the given tags.
func damage_mult(tags: Array) -> float:
	var inc := v("damage")
	for t in tags:
		inc += v(String(t) + "_damage")
	return maxf(0.0, 1.0 + inc) * v("damage_more")


func apply_mods(mods: Array) -> void:
	for m in mods:
		add_mod(String(m[0]), String(m[1]), float(m[2]))


func apply_flags(fl: Dictionary) -> void:
	for k in fl:
		add_flag(String(k), int(fl[k]))
