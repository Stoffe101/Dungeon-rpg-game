## Bramblewright: sings a wall of brambles up out of the floor across the
## Kindled's path, and lashes with a thorn whip at anyone who comes close.
## Brambles burn - fire clears a wall in a moment - or can be hacked through;
## left alone they wither after a while.
extends Enemy

const WALL_LIFE := 9.0
var grow_cd := 1.5
var whip_cd := 0.0


func behave(dt: float) -> void:
	grow_cd -= dt * attack_rate
	whip_cd -= dt * attack_rate
	match state:
		"idle":
			set_state("stalk")
		"stalk":
			var t := target()
			if t == null:
				vel = Vector2.ZERO
				return
			var d := dist_to_player()
			kite(3.0, 6.5, speed, dt)
			sprite.play("walk" if vel.length() > 0.3 else "idle")
			if whip_cd <= 0.0 and d < 2.6:
				vel = Vector2.ZERO
				aim_dir = dir_to_player()
				facing = aim_dir
				set_state("whip_windup")
				telegraph(Fx.Shape.CONE, pos, aim_dir, Vector2(6.0, 6.0), 0.45 / attack_rate, {"half_angle": deg_to_rad(45.0)})
			elif grow_cd <= 0.0 and d > 2.6 and d < 9.0 and stage.grid.line_clear(pos, t.pos):
				vel = Vector2.ZERO
				set_state("sing")
				sprite.play("cast")
				Audio.play_at("chant", pos, -6.0, 0.8)
				_mark_wall()
		"sing":
			vel = Vector2.ZERO
			if timer(0.7):
				_grow_wall()
				grow_cd = randf_range(6.5, 8.0)
				set_state("stalk")
		"whip_windup":
			vel = Vector2.ZERO
			if timer(0.45):
				sprite.play("whip")
				strike_arc(pos, aim_dir, 3.0, deg_to_rad(45.0), damage, 6.0)
				stage.fx.swipe(pos, aim_dir, 3.0, deg_to_rad(47.0), Color(0.55, 0.8, 0.35, 0.9), 0.12, 0.6)
				Audio.play_at("swing", pos, -2.0, 0.7)
				whip_cd = 1.6
				set_state("recover")
		"recover":
			vel = Vector2.ZERO
			if timer(0.4):
				set_state("stalk")
		_:
			set_state("stalk")


var _wall_tiles: Array[Vector2i] = []


## Where the wall will rise: across the line between the Kindled and the
## Bramblewright, a little in front of the Kindled.
func _mark_wall() -> void:
	_wall_tiles.clear()
	var t := target()
	if t == null:
		return
	var d := (pos - t.pos).normalized()
	var c := t.pos + d * 1.8
	var side := d.orthogonal()
	for k in range(-2, 3):
		var p := c + side * k
		var ti := Vector2i(floori(p.x), floori(p.y))
		if _wall_tiles.has(ti) or stage.grid.at(ti.x, ti.y) != TileGrid.FLOOR:
			continue
		var blocked := false
		for a in stage.actors:
			if a.alive and a.pos.distance_to(Vector2(ti) + Vector2(0.5, 0.5)) < 0.9:
				blocked = true
		if blocked or _near_door(ti):
			continue
		_wall_tiles.append(ti)
		stage.fx.shape(Fx.Shape.SIGIL, Vector2(ti) + Vector2(0.5, 0.5), Vector2.RIGHT, Vector2(1.0, 1.0), Color(0.5, 0.85, 0.35, 0.35), Color(0.6, 0.95, 0.4, 1.0), 0.75, {"glow": 1.3})


func _near_door(ti: Vector2i) -> bool:
	if not (stage is Dungeon):
		return false
	var r: Room = (stage as Dungeon).layout.room(room_id) if room_id >= 0 else null
	if r == null:
		return false
	for dr in r.doors:
		for dt: Vector2i in dr.tiles:
			if absi(dt.x - ti.x) + absi(dt.y - ti.y) < 2:
				return true
	return false


func _grow_wall() -> void:
	var st := stage
	for ti in _wall_tiles:
		# never trap anyone who walked onto the mark meanwhile
		var c := Vector2(ti) + Vector2(0.5, 0.5)
		var blocked := false
		for a in st.actors:
			if a.alive and a.pos.distance_to(c) < 0.8:
				blocked = true
		if blocked or st.grid.at(ti.x, ti.y) != TileGrid.FLOOR:
			continue
		var p := Prop.make(st, "bramble", ti, {"grown": true})
		p.room_id = room_id
		st.fx.burst(c, 0.3, Color(0.4, 0.6, 0.25), 8, 3.0, 0.4, 6.0, Vector2.ZERO, PI, 3.0)
		var pref: WeakRef = weakref(p)
		st.after(WALL_LIFE + randf_range(0.0, 1.5), func() -> void:
			var q = pref.get_ref()
			if q and is_instance_valid(q) and not q.used:
				q.unsolid()
				st.props.erase(q)
				st.fx.burst(q.pos, 0.4, Color(0.35, 0.3, 0.2), 6, 2.0, 0.5, 5.0)
				q.queue_free())
	_wall_tiles.clear()
	Audio.play_at("crumble", pos, -4.0, 0.6)


func hit_color() -> Color:
	return Color(0.55, 0.7, 0.35)
