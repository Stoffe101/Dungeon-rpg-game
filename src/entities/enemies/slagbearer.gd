## The Slagbearer carries what is left of the court's furnaces on a yoke and pours it where
## you are about to stand. Slag burns anyone, the King's own included: kite it past its
## friends. Struck down, it spills everything at its feet.
extends Enemy

const POOLS := 5
const POOL_R := 1.15
const POOL_LIFE := 7.0
const SLAG_TICK := 7.0

var _pour_cd := 1.5
var _from := Vector2.ZERO


func _ready() -> void:
	super._ready()
	bar_offset = 5.0


func behave(dt: float) -> void:
	_pour_cd -= dt * attack_rate * tempo
	match state:
		"windup":
			vel = Vector2.ZERO
			if timer(0.75):
				sprite.play("pour")
				_pour()
				_pour_cd = 4.2
				set_state("pouring")
		"pouring":
			vel = Vector2.ZERO
			if timer(0.8):
				sprite.play("idle")
				set_state("stalk")
		_:
			if state != "stalk":
				set_state("stalk")
			if target() == null:
				vel = Vector2.ZERO
				return
			var d := dist_to_player()
			if d > 7.0:
				chase(speed, dt)
				sprite.play("walk")
			elif d < 3.5:
				kite(4.0, 7.0, speed, dt)
				sprite.play("walk")
			else:
				vel = Vector2.ZERO
				sprite.play("idle")
			facing = dir_to_player()
			if _pour_cd <= 0.0 and d < 9.0 and may_strike("ranged"):
				aim_dir = dir_to_player()
				facing = aim_dir
				_from = pos
				set_state("windup")
				sprite.play("windup")
				var aim := Vector2(aim_dir)
				for k in POOLS:
					var at: Vector2 = pos + aim * (2.0 + k * 1.7)
					stage.fx.shape(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(POOL_R * 2.0, POOL_R * 2.0), TELE_COLOR, TELE_EDGE, 0.75 / attack_rate, {"progress": 0.2})
					stage.share_danger(at, 0.75 / attack_rate, {"kind": Fx.Shape.DISC, "dir": Vector2.RIGHT, "size": Vector2(POOL_R * 2.0, POOL_R * 2.0)})
				Audio.play_at("steam", pos, -6.0, 0.7)


func _pour() -> void:
	Audio.play_at("explode", pos, -8.0, 1.6)
	for k in POOLS:
		var at: Vector2 = _from + aim_dir * (2.0 + k * 1.7)
		var ti := Vector2i(floori(at.x), floori(at.y))
		if stage.grid.at(ti.x, ti.y) != TileGrid.FLOOR:
			break
		strike_circle(at, POOL_R, damage, 3.0)
		spill(stage, at, POOL_R, POOL_LIFE)


## A pool of slag: it burns both sides.
static func spill(st: Stage, at: Vector2, r: float, life: float) -> void:
	st.fx.burst(at, 0.2, Color(1.0, 0.65, 0.3), 10, 3.5, 0.5, 3.0)
	var hz := Hazard.spawn(st, at, r, life, Team.ENEMY, Color(1.0, 0.5, 0.2), _burn_kindled)
	hz.period = 0.5
	var foes := Hazard.spawn(st, at, r, life, Team.PLAYER, Color(1.0, 0.5, 0.2), _burn_foes, true)
	foes.period = 0.5


static func _burn_kindled(_h: Hazard, a: Actor) -> void:
	if a is Player:
		var h := Hit.make(null, SLAG_TICK, ["dot", "fire"])
		h.can_crit = false
		h.silent = true
		(a as Player).take_enemy_hit(h, null)


static func _burn_foes(_h: Hazard, a: Actor) -> void:
	if a is Enemy and not (a as Enemy).def.get("boss", false) and (a as Enemy).id != "slagbearer":
		var h := Hit.make(null, (a as Enemy).max_hp * 0.07, ["dot", "fire"])
		h.can_crit = false
		h.silent = true
		a.take_hit(h)


func die(killer: Node) -> void:
	if not alive:
		return
	spill(stage, pos, 1.9, 5.0)
	super.die(killer)


func hit_color() -> Color:
	return Color(0.9, 0.55, 0.25)
