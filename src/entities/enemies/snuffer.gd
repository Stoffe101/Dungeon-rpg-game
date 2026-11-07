## Snuffer: it wants your light and nothing else. It lunges on a thin warning line;
## its touch takes a third of the lantern's Kindle, dims the lantern and sends it
## running with the flame in its hands, lit up for anyone to chase. Bring it down
## and the flame comes home with interest. Left alone it swallows the flame, heals
## and comes back quicker, but it can only ever do that twice.
extends Enemy

const STEAL := 0.33
const REACH := 4.6
const CARRY_T := 9.0
const DIM_T := 7.0
const FLAME := Color(1.0, 0.62, 0.3)

var cd := 1.2
var stolen := 0.0
var victim: Player = null
var swallowed := 0
var _carry_left := 0.0
var _trail := 0.0


func behave(dt: float) -> void:
	cd -= dt * attack_rate
	match state:
		"idle":
			set_state("stalk")
		"stalk":
			chase(speed, dt)
			sprite.play("walk" if vel.length() > 0.3 else "idle")
			var t := target()
			if t and cd <= 0.0 and dist_to_player() < REACH - 0.6 and stage.grid.line_clear(pos, t.pos) and may_strike():
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(REACH, 1.0), 0.55 / attack_rate)
				voice("attack")
		"windup":
			vel = Vector2.ZERO
			if timer(0.55):
				set_state("lunge")
				sprite.play("lunge")
				Audio.play_at("ward", pos, -12.0, 1.8)
		"lunge":
			vel = aim_dir * 14.0
			if _touch():
				return
			if timer(0.3):
				vel = Vector2.ZERO
				set_state("spent")
				sprite.play("spent")
		"spent":
			vel = Vector2.ZERO
			if timer(1.1):
				cd = 2.6
				set_state("stalk")
		"flee":
			_run_with_it(dt)
		_:
			set_state("stalk")


## Its touch: a dodge goes through it, a Ward stops it; only a blow that lands
## reaches the flame (`landed_on`).
func _touch() -> bool:
	for p in stage.active_players():
		if p.pos.distance_to(pos) <= 1.0 + p.radius:
			vel = Vector2.ZERO
			set_state("spent")
			sprite.play("spent")
			p.take_enemy_hit(_hit_on(p, damage, pos, 3.0), self)
			return true
	return false


func landed_on(p: Player) -> void:
	if state == "spent" and stolen <= 0.0:
		_steal(p)


func _steal(p: Player) -> void:
	stolen = maxf(1.0, minf(p.kindle, p.kindle_max() * STEAL))
	p.kindle = maxf(0.0, p.kindle - stolen)
	p.snuff(DIM_T)
	victim = p
	_carry_left = CARRY_T
	set_state("flee")
	sprite.play("carry")
	stage.fx.burst(p.pos, 0.9, FLAME, 16, 3.0, 0.5, 3.0)
	stage.fx.number(p.pos, 2.6, "FLAME STOLEN", FLAME, true)
	Audio.play_at("snuff", p.pos, -3.0)
	if p == stage.player:
		Events.toast.emit("It has your flame. Bring it down and it comes back.", FLAME)


func _run_with_it(dt: float) -> void:
	_carry_left -= dt
	var t: Player = victim if is_instance_valid(victim) else target()
	if t:
		var away := (pos - t.pos).normalized()
		move_toward_point(pos + away * 3.0, speed * 1.1, dt)
		if vel.length() < 0.5:
			vel = away.orthogonal() * speed     # cornered: along the wall
	sprite.play("carry")
	_trail -= dt
	if _trail <= 0.0:
		_trail = 0.12
		stage.fx.motes(pos, 0.7, FLAME, 2, 0.8, 0.5, 0.15)
	if _carry_left <= 0.0:
		_swallow()


func _swallow() -> void:
	stolen = 0.0
	victim = null
	swallowed += 1
	hp = minf(max_hp, hp + max_hp * 0.3)
	if swallowed <= 2:
		speed *= 1.12
	cd = 3.5 + 1.5 * swallowed
	stage.fx.ring(pos, 1.2, FLAME, 0.3, 0.2)
	Audio.play_at("ignite", pos, -9.0, 0.7)
	set_state("stalk")


func die(killer: Node) -> void:
	if not alive:
		return
	if stolen > 0.0 and is_instance_valid(victim) and victim.alive:
		# the flame goes home, a little brighter
		victim.kindle = minf(victim.kindle_max(), victim.kindle + stolen * 1.5)
		victim.snuff(0.0)
		victim.heal(victim.max_hp * 0.05)
		stage.fx.ring(victim.pos, 1.6, FLAME, 0.4, 0.25)
		stage.fx.burst(victim.pos, 0.9, FLAME, 18, 3.0, 0.6, 2.0, Vector2.UP, 1.2)
		stage.fx.number(victim.pos, 2.6, "FLAME RETURNED", FLAME, true)
		Audio.play_at("kindle_full", victim.pos, -4.0)
	stolen = 0.0
	super.die(killer)
