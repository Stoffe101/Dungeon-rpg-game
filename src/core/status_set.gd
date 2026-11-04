## Status effects carried by an actor. Pure logic so it can be unit tested.
##
## Burn   - stacking damage over time (ticks every 0.5s), refreshed on reapply.
## Chill  - builds toward 1.0; slows the target; at 1.0 the target Freezes.
## Frozen - cannot act; takes bonus damage; may Shatter.
## Stagger- poise broken: interrupted and takes bonus damage.
## Exposed- takes bonus damage from all sources.
## Snared - caught in a web: moves at half speed for a moment.
class_name StatusSet
extends RefCounted

const BURN_TICK := 0.5
const BURN_DURATION := 3.0
const CHILL_DECAY := 0.28
const FREEZE_TIME := 1.6
const FROZEN_BONUS := 0.5
const STAGGER_BONUS := 0.25
const EXPOSED_BONUS := 0.3

var burn_stacks := 0
var burn_dps_per_stack := 3.0
var burn_t := 0.0
var burn_tick_t := 0.0
var burn_source: Node = null
var chill := 0.0
var frozen_t := 0.0
var stagger_t := 0.0
var exposed_t := 0.0
var freeze_immune_t := 0.0
var snare_t := 0.0
var root_t := 0.0             # rooted: cannot move (it can still strike)


func apply_burn(stacks: int, dps_per_stack: float, max_stacks: int, src: Node = null) -> void:
	if stacks <= 0:
		return
	burn_stacks = mini(burn_stacks + stacks, maxi(max_stacks, 1))
	burn_dps_per_stack = maxf(burn_dps_per_stack, dps_per_stack)
	burn_t = BURN_DURATION
	burn_source = src


## Returns true if this application froze the target.
func apply_chill(amount: float, freeze_mult := 1.0) -> bool:
	if amount <= 0.0 or frozen_t > 0.0:
		return false
	chill = minf(1.0, chill + amount)
	if chill >= 1.0 and freeze_immune_t <= 0.0:
		chill = 0.0
		frozen_t = FREEZE_TIME * freeze_mult
		return true
	return false


func apply_snare(seconds: float) -> void:
	snare_t = maxf(snare_t, seconds)


func apply_root(seconds: float) -> void:
	root_t = maxf(root_t, seconds)


func is_frozen() -> bool:
	return frozen_t > 0.0


func is_staggered() -> bool:
	return stagger_t > 0.0


func burning() -> bool:
	return burn_stacks > 0


## Movement multiplier from chill/freeze.
func speed_mult() -> float:
	if frozen_t > 0.0 or root_t > 0.0:
		return 0.0
	return (1.0 - chill * 0.5) * (0.5 if snare_t > 0.0 else 1.0)


func can_act() -> bool:
	return frozen_t <= 0.0 and stagger_t <= 0.0


## Bonus multiplier on incoming damage.
func damage_taken_mult(shatter := false) -> float:
	var m := 1.0
	if frozen_t > 0.0:
		m += FROZEN_BONUS * (2.0 if shatter else 1.0)
	if stagger_t > 0.0:
		m += STAGGER_BONUS
	if exposed_t > 0.0:
		m += EXPOSED_BONUS
	return m


## Advances timers. Returns burn damage dealt this step (0 if no tick).
func tick(dt: float) -> float:
	var dmg := 0.0
	if burn_stacks > 0:
		burn_t -= dt
		burn_tick_t += dt
		while burn_tick_t >= BURN_TICK:
			burn_tick_t -= BURN_TICK
			dmg += burn_stacks * burn_dps_per_stack * BURN_TICK
		if burn_t <= 0.0:
			burn_stacks = 0
			burn_tick_t = 0.0
	if frozen_t > 0.0:
		frozen_t -= dt
		if frozen_t <= 0.0:
			freeze_immune_t = 2.0
	elif chill > 0.0:
		chill = maxf(0.0, chill - CHILL_DECAY * dt)
	freeze_immune_t = maxf(0.0, freeze_immune_t - dt)
	stagger_t = maxf(0.0, stagger_t - dt)
	exposed_t = maxf(0.0, exposed_t - dt)
	root_t = maxf(0.0, root_t - dt)
	snare_t = maxf(0.0, snare_t - dt)
	return dmg


func clear() -> void:
	burn_stacks = 0
	burn_t = 0.0
	chill = 0.0
	frozen_t = 0.0
	stagger_t = 0.0
	exposed_t = 0.0
	root_t = 0.0
	snare_t = 0.0
