## Ash Seal: a chained obelisk warding a Trial of Ash hall. It does not move or
## strike; while any seal stands, the hall's other foes shrug off most of
## every blow (Dungeon.sealed_foe). Any blow, spell or shot breaks it - an
## Enemy so every build can, and so the room's clear and the network treat it
## like any foe.
extends Enemy


func _ready() -> void:
	super._ready()
	mass = 99.0


func behave(_dt: float) -> void:
	vel = Vector2.ZERO
	push = Vector2.ZERO
	if state != "idle":
		set_state("idle")
	sprite.play("idle")
	# its rune breathes ash
	if fmod(stage.elapsed + float(get_instance_id() % 7) * 0.13, 0.6) < 0.02:
		stage.fx.motes(pos + Vector2(0, -0.1), 1.3, Color(1.0, 0.45, 0.25), 2, 0.5, 1.1, 0.2)


## A seal does not stagger or slide.
func hit_react(_dir: Vector2, _power := 1.0) -> void:
	if sprite:
		sprite.flash(Color(1.0, 0.7, 0.45), 0.12)


func die(killer: Node) -> void:
	if not alive:
		return
	stage.fx.burst(pos, 0.9, Color(1.0, 0.45, 0.25), 26, 4.0, 0.6, 5.0, Vector2.UP, 1.2)
	stage.fx.ring(pos, 2.0, Color(1.0, 0.55, 0.3), 0.4, 0.25)
	Audio.play_at("shatter", pos, -4.0, 0.75)
	var st := stage
	super.die(killer)
	if st is Dungeon:
		(st as Dungeon).on_seal_broken()


func hit_color() -> Color:
	return Color(1.0, 0.55, 0.3)
