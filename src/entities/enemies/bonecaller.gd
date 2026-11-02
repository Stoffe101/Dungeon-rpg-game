## Bonecaller: a floating priest. Raises Husks from the floor and sends slow,
## seeking soul orbs. Fragile - a priority target.
extends Enemy

const MAX_SUMMONS := 4
var raise_cd := 2.5
var orb_cd := 1.5
var summons: Array = []


func _ready() -> void:
	super._ready()
	flying = true
	bar_offset = 6.0


func behave(dt: float) -> void:
	raise_cd -= dt * attack_rate
	orb_cd -= dt * attack_rate
	bob = sin(stage.elapsed * 2.5) * 0.1 + 0.15
	summons = summons.filter(func(s): return is_instance_valid(s) and s.alive)
	match state:
		"idle":
			set_state("float")
		"float":
			kite(5.0, 9.0, speed, dt)
			sprite.play("idle")
			if raise_cd <= 0.0 and summons.size() < MAX_SUMMONS:
				vel = Vector2.ZERO
				set_state("raise")
				sprite.play("cast")
				Audio.play("chant", -6.0)
				for i in 2:
					var p := stage.random_floor_near(pos + Vector2.from_angle(randf() * TAU) * 2.0, 1.5)
					stage.fx.shape(Fx.Shape.SIGIL, p, Vector2.RIGHT, Vector2(1.8, 1.8), Color(0.3, 0.95, 0.8, 0.4), Color(0.5, 1.0, 0.9, 1.0), 0.95, {"glow": 1.4})
					_pending.append(p)
			elif orb_cd <= 0.0 and stage.grid.line_clear(pos, target().pos if target() else pos):
				vel = Vector2.ZERO
				set_state("orb")
				sprite.play("cast")
		"raise":
			vel = Vector2.ZERO
			if timer(0.9):
				for p in _pending:
					var h := preload("res://src/entities/enemies/husk.gd").new()
					h.configure("husk")
					h.summoned = true
					h.max_hp *= 0.6
					h.hp = h.max_hp
					h.xp = 1
					h.embers = 0
					h.pos = p
					h.room_id = room_id
					stage.add_actor(h)
					summons.append(h)
					if stage.has_method("register_enemy"):
						stage.register_enemy(h)
				_pending.clear()
				raise_cd = randf_range(6.0, 7.5)
				set_state("float")
		"orb":
			vel = Vector2.ZERO
			if timer(0.55):
				for k in 3:
					var d := dir_to_player().rotated((k - 1) * 0.5)
					var pr := shoot("proj_orb", d, 4.2, damage, 0.28)
					pr.homing_target = target()
					pr.homing_turn = 1.4
					pr.life = 4.0
					pr.spin = false
				Audio.play("orb", -4.0)
				orb_cd = randf_range(3.0, 4.0)
				set_state("float")
		_:
			set_state("float")


var _pending: Array = []


func hit_color() -> Color:
	return Color(0.6, 0.45, 0.75)
