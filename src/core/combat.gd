## Damage resolution rules. Stateless and deterministic given a random roll.
class_name Combat
extends RefCounted

const MAX_ARMOR := 0.75


class Result:
	var amount := 0.0
	var crit := false
	var blocked := false


## `roll` is a uniform random number in [0,1) used for the crit check.
## `block_mult` < 1 when a shield or guard absorbs part of the hit.
static func resolve(hit: Hit, status: StatusSet, armor: float, damage_taken: float, roll: float, shatter := false, block_mult := 1.0) -> Result:
	var r := Result.new()
	var amt := hit.amount
	if hit.forced_crit or (hit.can_crit and roll < hit.crit_chance):
		r.crit = true
		amt *= hit.crit_mult
	if status != null:
		amt *= status.damage_taken_mult(shatter)
	amt *= 1.0 - clampf(armor, 0.0, MAX_ARMOR)
	amt *= maxf(damage_taken, 0.0)
	if block_mult < 1.0:
		r.blocked = true
		amt *= maxf(block_mult, 0.0)
	if amt > 0.0:
		amt = maxf(1.0, roundf(amt))
	r.amount = amt
	return r


## Builds an outgoing hit using an attacker's stats.
static func player_hit(src: Node, stats: Stats, base: float, tags: Array) -> Hit:
	if stats.has("living_pyre") and not tags.has("fire"):
		tags = tags.duplicate()
		tags.append("fire")
	var h := Hit.make(src, base * stats.damage_mult(tags), tags)
	h.crit_chance = stats.v("crit_chance")
	h.crit_mult = stats.v("crit_mult")
	return h


## Experience required to go from `level` to `level + 1`.
static func xp_to_next(level: int) -> int:
	return int(round(60.0 * pow(float(level), 1.35) + 40.0))
