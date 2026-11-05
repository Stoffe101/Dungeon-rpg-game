## Lurecap: stands among the Rootmire's lit mushrooms and looks like one, but for
## a pale eye under its great cap. Step close and it unfolds and bites; hit it first
## and it has lost its chance. When the rest of a room's foes are down it gives up
## the pretence and comes for you, so no fight ends on a hunt for a mushroom.
extends Enemy

const WAKE := 2.8
const REACH := 1.6
const HALF := 1.0

var hidden := true
var _placed := false
var bite_cd := 0.0


func _ready() -> void:
	super._ready()
	spawn_t = 0.01     # (it was always here)


func behave(dt: float) -> void:
	bite_cd -= dt * attack_rate
	if not _placed:
		_placed = true
		_stand_among_the_caps()
	match state:
		"idle":
			vel = Vector2.ZERO
			if not hidden:
				set_state("hunt")
			elif _spotted():
				_unfold()
			else:
				sprite.play("idle")
		"unfold":
			vel = Vector2.ZERO
			if timer(0.45):
				_bite()
		"hunt":
			chase(speed, dt)
			sprite.play("walk")
			if dist_to_player() < REACH and bite_cd <= 0.0 and target() and may_strike():
				_unfold(0.5)
		"bitten":
			vel = Vector2.ZERO
			if timer(0.7):
				set_state("hunt")
		_:
			set_state("hunt" if not hidden else "idle")


func _spotted() -> bool:
	if dist_to_player() < WAKE or hp < max_hp:
		return true
	# the last of a room's foes stops pretending
	if stage is Dungeon:
		for e in (stage as Dungeon).room_enemies:
			if is_instance_valid(e) and e.alive and e.id != id:
				return false
		return (stage as Dungeon).active_room != null
	return false


func _unfold(warn := 0.45) -> void:
	hidden = false
	vel = Vector2.ZERO
	aim_dir = dir_to_player()
	facing = aim_dir
	set_state("unfold")
	state_t = 0.45 - warn
	sprite.play("rise")
	telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(REACH * 2.0, REACH * 2.0), warn / attack_rate, {"half_angle": HALF})
	Audio.play_at("crumble", pos, -8.0, 1.3)


func _bite() -> void:
	set_state("bitten")
	sprite.play("bite")
	bite_cd = 1.6
	push += aim_dir * 5.0
	strike_arc(pos, aim_dir, REACH, HALF, damage, 4.0)
	stage.fx.swipe(pos, aim_dir, REACH, HALF, Color(0.55, 0.9, 0.5, 0.8), 0.08, 0.5)
	Audio.play_at("claw", pos, -6.0, 1.2)


## It takes its place beside a real glowcap if the room has one.
func _stand_among_the_caps() -> void:
	var best: Prop = null
	var bd := 9.0
	for p in stage.props:
		if is_instance_valid(p) and p.kind == "glowcap":
			var d: float = p.pos.distance_to(pos)
			if d < bd and p.room_id == room_id:
				bd = d
				best = p
	if best:
		pos = stage.foe_spot(best.pos + Vector2(0.9, 0.4), 0.4, room_id)
