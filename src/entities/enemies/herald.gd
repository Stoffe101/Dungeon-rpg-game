## Ash Herald: the court's voice. It keeps its distance and reads a decree on its
## horn: one Kindled is marked, and every foe strikes them harder for as long as
## the mark lasts. It fights for nobody else: fell it and the decree dies with it.
## In a party the marked one has somewhere to run and someone else has a job.
extends Enemy

const DECREE := 5.0
const GOLD := Color(1.0, 0.78, 0.35)

var decree_cd := 3.0
var marked: Player = null
var _mark_left := 0.0
var _mark_fx := 0.0


func behave(dt: float) -> void:
	decree_cd -= dt * attack_rate
	_tend_mark(dt)
	match state:
		"idle":
			set_state("walk")
		"walk":
			kite(6.0, 9.0, speed, dt)
			sprite.play("walk" if vel.length() > 0.3 else "idle")
			var t := target()
			if decree_cd <= 0.0 and t and marked == null and stage.grid.line_clear(pos, t.pos) and may_strike("ranged"):
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.DISC, t.pos, Vector2.RIGHT, Vector2(2.2, 2.2), 1.1 / attack_rate)
				Audio.play_at("gate_flare", pos, -12.0, 1.8)
		"windup":
			vel = Vector2.ZERO
			if timer(1.1):
				_proclaim()
				set_state("recover")
				sprite.play("blow")
		"recover":
			vel = Vector2.ZERO
			if timer(0.7):
				decree_cd = 8.0
				set_state("walk")
		_:
			set_state("walk")


func _proclaim() -> void:
	var t := target()
	if not t is Player:
		return
	marked = t as Player
	marked.marked_t = DECREE
	_mark_left = DECREE
	stage.fx.number(marked.pos, 2.6, "MARKED", GOLD, true)
	stage.fx.ring(marked.pos, 1.8, GOLD, 0.5, 0.25)
	Audio.play_at("boss_arrive", pos, -14.0, 1.7)
	if marked == stage.player:
		Events.toast.emit("Marked: every foe strikes you harder. Fell the Herald.", GOLD)


func _tend_mark(dt: float) -> void:
	if marked == null:
		return
	if not is_instance_valid(marked) or not marked.alive:
		marked = null
		return
	_mark_left -= dt
	if _mark_left <= 0.0:
		marked = null
		return
	_mark_fx -= dt
	if _mark_fx <= 0.0:
		_mark_fx = 0.3
		stage.fx.ring(marked.pos, 0.9, GOLD, 0.3, 0.2)


func die(killer: Node) -> void:
	if not alive:
		return
	if marked and is_instance_valid(marked):
		marked.marked_t = 0.0     # the decree dies with its voice
		marked = null
	super.die(killer)
