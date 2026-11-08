## The Canopy Mother. Plants herself and opens a parasol of gills; any foe under it can only
## be hurt from under it. A bow behind a hedge does nothing: someone has to go in.
extends Enemy

const CANOPY_R := 4.6
const OUTSIDE_TAKES := 0.35

var _ring_t := 0.0
var _spit_cd := 2.0


func _ready() -> void:
	super._ready()
	anchored = true
	mass = 12.0
	bar_offset = 7.0
	stage.canopies.append(self)


func _exit_tree() -> void:
	if stage:
		stage.canopies.erase(self)
	super._exit_tree()


## Does this canopy shelter `who` from a blow struck by someone standing at `from`?
func shelters(who: Vector2, from: Vector2) -> bool:
	return alive and who.distance_to(pos) <= CANOPY_R and from.distance_to(pos) > CANOPY_R


func behave(dt: float) -> void:
	vel = Vector2.ZERO
	_spit_cd -= dt * attack_rate * tempo
	_ring_t -= dt
	if _ring_t <= 0.0:
		# (a warning every machine draws: this ground is hers)
		_ring_t = 1.9
		stage.fx.shape(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(CANOPY_R * 2.0, CANOPY_R * 2.0), Color(0.55, 0.85, 0.35, 0.1), Color(0.75, 1.0, 0.5, 0.75), 1.95, {"progress": 1.0})
	match state:
		"windup":
			if timer(0.7):
				sprite.play("spit")
				var t := target()
				if t:
					var pr := shoot("proj_orb", (t.pos - pos).normalized(), 5.5, damage, 0.28)
					pr.life = 3.0
				Audio.play_at("orb", pos, -4.0, 0.7)
				_spit_cd = 2.8
				set_state("recover")
		"recover":
			if timer(0.5):
				sprite.play("idle")
				set_state("stalk")
		_:
			if state != "stalk":
				set_state("stalk")
			if _spit_cd <= 0.0 and target() and may_strike("ranged"):
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.RECT, pos, aim_dir, Vector2(8.0, 0.7), 0.7 / attack_rate)


func hit_color() -> Color:
	return Color(0.6, 0.8, 0.4)
