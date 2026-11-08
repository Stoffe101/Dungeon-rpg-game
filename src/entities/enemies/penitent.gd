## The Penitent. Stone while any lantern is turned on it; the moment nobody is looking its
## way it comes, fast and silent but for the scrape. Every Kindled covers the others' backs.
extends Enemy

const SEEN_CONE := 1.15          # half angle (radians) of what a lantern's beam covers
const REACH := 2.1

var _strike_cd := 0.0
var _scrape_t := 0.0


func _ready() -> void:
	super._ready()
	anchored = true
	bar_offset = 4.0


## Is a lantern on it?
func watched() -> bool:
	for pl: Player in stage.active_players():
		var off := pos - pl.pos
		var d := off.length()
		if d < 1.2:
			continue           # (too close to see properly: it is on you)
		if d <= pl.light_reach() * 2.6 and absf(angle_difference(off.angle(), pl.look.angle())) <= SEEN_CONE:
			return true
	return false


func behave(dt: float) -> void:
	_strike_cd -= dt * attack_rate * tempo
	match state:
		"windup":
			vel = Vector2.ZERO
			if timer(0.3):
				sprite.play("strike")
				strike_arc(pos, aim_dir, REACH + 0.3, deg_to_rad(55.0), damage, 6.0)
				stage.fx.swipe(pos, aim_dir, REACH, deg_to_rad(57.0), Color(0.6, 0.95, 0.9, 0.8), 0.12, 0.5)
				Audio.play_at("swing", pos, -3.0, 0.65)
				_strike_cd = 1.1
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			if timer(0.5):
				set_state("stalk")
		_:
			if state != "stalk":
				set_state("stalk")
			if watched():
				vel = Vector2.ZERO
				sprite.play("stone")
				return
			if target() == null:
				vel = Vector2.ZERO
				return
			chase(speed, dt)
			sprite.play("walk")
			_scrape_t -= dt
			if _scrape_t <= 0.0:
				_scrape_t = 0.34
				Audio.play_at("crumble", pos, -14.0, 1.8)
			if dist_to_player() < REACH and _strike_cd <= 0.0 and may_strike():
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("windup")
				sprite.play("windup")
				telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(REACH * 2.0 + 0.6, REACH * 2.0 + 0.6), 0.3 / attack_rate, {"half_angle": deg_to_rad(55.0)})


func hit_color() -> Color:
	return Color(0.7, 0.72, 0.75)
