## A soul on its way back to the Gloam Warden's cage. It does nothing to you; it is the
## thing you have to decide about. Strike it down and its light is yours.
extends Enemy

const KINDLE_BACK := 10.0

## Seconds it takes to reach the cage, however the Warden moves: the time to decide.
const ARRIVES_IN := 8.0

var warden: Enemy
var _done := false
var _age := 0.0


func _ready() -> void:
	super._ready()
	flying = true
	spawn_t = 0.5
	height = 0.9


func behave(dt: float) -> void:
	sprite.play("idle")
	if warden == null or not is_instance_valid(warden) or not warden.alive:
		die(null)
		return
	var to := warden.pos - pos
	if to.length() < warden.radius + 0.5:
		_done = true
		warden.call("soul_arrived")
		die(null)
		return
	_age += dt
	pos += to.normalized() * minf(to.length() / maxf(0.5, ARRIVES_IN - _age), 12.0) * dt
	bob = sin(stage.elapsed * 5.0 + float(get_instance_id() % 7)) * 0.15


func die(killer: Node) -> void:
	if not alive:
		return
	if not _done and warden != null and is_instance_valid(warden) and warden.alive:
		warden.call("soul_lost")
		if killer is Player:
			(killer as Player).gain_kindle(KINDLE_BACK)
	super.die(killer)


func hit_color() -> Color:
	return Color(0.5, 1.0, 0.92)
