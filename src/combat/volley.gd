## How a Kindled's shots fly. Every bow shot, staff bolt, tome mote, Gloam
## Knife, Cinder Lance and lantern bolt goes out through here, so one set of
## projectile modifiers - from the Hearthtree, gear, relics and runes - shapes
## all of them the same way:
##
## - `projectiles`: more shots in a fan. A foe is struck by only one shot of a
##   volley (no shotgunning): more projectiles cover more ground, they do not
##   multiply single-target damage.
## - `pierce`: passes through that many more foes.
## - `chain`: after a hit, leaps to the nearest foe it has not struck.
## - `fork`: on its first hit, splits into two shots at half damage.
## - `proj_return` (flag): flies back to the Kindled, striking again on the way.
## - Ember Hail (keystone): two more projectiles, each a quarter weaker.
class_name Volley
extends RefCounted

const SPREAD := 0.13       # radians between neighbours in a fan


## The directions of one volley: `base` shots (the weapon's or spell's own)
## plus the Kindled's extra projectiles, fanned around `dir`.
static func directions(pl: Player, dir: Vector2, base := 1, spread := SPREAD) -> Array:
	var n := base + extra(pl)
	var out: Array = []
	for k in n:
		out.append(dir.rotated((float(k) - (n - 1) * 0.5) * spread))
	return out


static func extra(pl: Player) -> int:
	if pl == null or pl.stats == null:
		return 0
	return maxi(0, int(round(pl.stats.v("projectiles"))))


## Gives one player projectile the Kindled's modifiers. `group` is shared by
## every shot of the same volley (one strike per foe per volley).
static func shape(pr: Projectile, pl: Player, group: Dictionary) -> void:
	if pl == null or pl.stats == null:
		return
	var st := pl.stats
	pr.pierce += int(round(st.v("pierce")))
	pr.chain += int(round(st.v("chain")))
	pr.fork += int(round(st.v("fork")))
	pr.returning = pr.returning or st.has("proj_return")
	if group.is_empty():
		group[0] = true     # marks the volley (no actor has instance id 0)
	pr.group = group
	if not pr.tags.has("projectile"):
		pr.tags.append("projectile")
	if st.has("ember_hail"):
		pr.damage *= 0.75
	if st.has("seeking") and pr.homing_target == null and pl.stage:
		# Wand of a Hundred Embers: it bends toward the nearest foe ahead
		pr.homing_target = pl.stage.nearest_hostile(pl.team, pr.pos + pr.vel.normalized() * 3.0, 9.0, true)
		pr.homing_turn = 5.0


## One shot of a volley, configured by the caller's `setup` (sheet, speed,
## damage, tags...) and then shaped. Returns the projectiles made.
static func fire(pl: Player, sheet: String, from: Vector2, dir: Vector2, speed: float, base: int, setup: Callable, spread := SPREAD) -> Array:
	var group := {}
	var out: Array = []
	for d: Vector2 in directions(pl, dir, base, spread):
		var pr := Projectile.create(pl.stage, sheet, from + d * 0.5, d * speed, pl.team)
		pr.source = pl
		setup.call(pr, d)
		shape(pr, pl, group)
		out.append(pr)
	return out
