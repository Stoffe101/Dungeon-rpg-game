## One instance of damage travelling from a source to a target.
class_name Hit
extends RefCounted

var source: Node = null          # Actor that caused the hit (may be freed later)
var amount := 0.0                # already scaled by the attacker's damage stats
var tags: Array = []             # "melee", "ranged", "ability", "fire", "frost", "shadow", "dot", "summon"
var can_crit := true
var crit_chance := 0.0
var crit_mult := 1.5
var forced_crit := false
var knockback := Vector2.ZERO    # plane units/second impulse
var poise := 0.0                 # poise damage
var burn := 0                    # burn stacks to apply
var chill := 0.0                 # chill amount (0..1, 1 = freeze)
var expose := 0.0                # seconds of Exposed
var from_dir := Vector2.ZERO     # direction the hit travels (for shields / reactions)
var unblockable := false
var is_reflected := false
var silent := false              # no hit-stop / number (e.g. tiny DoT ticks)
var proc := true                 # may trigger on-hit effects (prevents infinite chains)


static func make(src: Node, amt: float, tag_list: Array = []) -> Hit:
	var h := Hit.new()
	h.source = src
	h.amount = amt
	h.tags = tag_list
	return h


func has_tag(t: String) -> bool:
	return tags.has(t)
