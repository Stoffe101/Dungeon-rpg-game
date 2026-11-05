## Tollkeeper: keeps to the edge of a fight and tolls its bell. A ring of sound
## goes out from it, and whoever the ring finds in the open reels. You do not run
## from it: you dodge through it, or put a wall between you. The ring you see is
## the ring that hits (Fx.ring's own curve).
extends Enemy

const RING_R := 9.0
const RING_LIFE := 1.5
const BAND := 0.65
const SOUL := Color(0.45, 0.95, 0.85)

var toll_cd := 2.4
var _rings: Array = []     # {at, t, struck: {}}


func behave(dt: float) -> void:
	toll_cd -= dt * attack_rate
	_tend_rings(dt)
	match state:
		"idle":
			set_state("walk")
		"walk":
			kite(4.0, 7.5, speed, dt)
			sprite.play("walk" if vel.length() > 0.3 else "idle")
			if toll_cd <= 0.0 and target() and stage.grid.line_clear(pos, target().pos) and may_strike("ranged"):
				vel = Vector2.ZERO
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(3.0, 3.0), 0.95 / attack_rate)
				Audio.play_at("gate_hum", pos, -12.0, 1.6)
		"windup":
			vel = Vector2.ZERO
			if timer(0.95):
				_toll()
				set_state("recover")
				sprite.play("toll")
		"recover":
			vel = Vector2.ZERO
			if timer(0.8):
				toll_cd = 5.0
				set_state("walk")
		_:
			set_state("walk")


func _toll() -> void:
	_rings.append({"at": pos, "t": 0.0, "struck": {}})
	stage.fx.ring(pos, RING_R, SOUL, RING_LIFE, 0.3)
	stage.fx.flash_light(pos, 1.6, SOUL, 2.5, 6.0, 0.4)
	Audio.play_at("forge", pos, -2.0, 0.42)


## How far a ring has gone after `t` seconds (Fx.ring's curve).
static func ring_radius(t: float) -> float:
	var k := clampf(t / RING_LIFE, 0.0, 1.0)
	return RING_R * lerpf(0.25, 1.0, 1.0 - pow(1.0 - k, 3.0))


func _tend_rings(dt: float) -> void:
	for ring in _rings:
		ring.t += dt
		var r := ring_radius(float(ring.t))
		var at: Vector2 = ring.at
		for p in stage.active_players():
			if ring.struck.has(p.net_id if p.net_id != 0 else p.peer_id):
				continue
			if absf(p.pos.distance_to(at) - r) < BAND and stage.grid.line_clear(at, p.pos):
				ring.struck[p.net_id if p.net_id != 0 else p.peer_id] = true
				var h := _hit_on(p, damage, at, 4.0)
				h.chill = 0.3
				p.take_enemy_hit(h, self)
	_rings = _rings.filter(func(ring): return float(ring.t) < RING_LIFE)
