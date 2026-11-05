## Dev: how often a signature weapon's moment actually comes (`-- legendlab
## profile=legend.json`, debug builds only; headless is fine). A Kindled holding
## the weapon fights by the game's own rules - swinging at the nearest foe the
## way a player mashing attack would (charging where the weapon is charged) -
## in three kinds of fight: a small group (3 husks, the room ends when they
## fall, then a short walk to the next), a long fight (8 foes kept coming) and
## a boss (one tough foe). Counts each moment and when the first came.
##
## Args: secs=90 forms=thousandth_cut,hundred_embers,sunfall_glaive
class_name LegendLab
extends Node

var secs := 90.0
var bases: Array = ["thousandth_cut", "hundred_embers", "sunfall_glaive"]


func _ready() -> void:
	for a in Dev.args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"secs":
				secs = float(kv[1])
			"forms":
				bases = Array(kv[1].split(","))
	_go.call_deferred()


func _go() -> void:
	print("[legend] %d s per fight" % int(secs))
	var lines: Array = ["# Signature moments per minute (%d s of each fight)" % int(secs), "", "| weapon | fight | moments | per minute | first after |", "|---|---|---|---|---|"]
	for b in bases:
		for fight in ["small", "long", "boss"]:
			var r := await _run(String(b), fight)
			var per := float(r.n) * 60.0 / secs
			print("[legend] %-16s %-6s moments %d  (%.1f a minute)  first after %s" % [b, fight, r.n, per, ("%.1f s" % r.first) if r.first >= 0.0 else "-"])
			lines.append("| %s | %s | %d | %.1f | %s |" % [b, fight, r.n, per, ("%.1f s" % r.first) if r.first >= 0.0 else "-"])
	var f := FileAccess.open("user://legend_lab.md", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	get_tree().quit()


func _run(base: String, fight: String) -> Dictionary:
	seed(77)
	Profile.data = Profile.fresh()
	var it := Profile.add_item(ItemDB.make_item(base, "legendary" if ItemDB.base(base).get("legendary", false) else "rare", 1, RandomNumberGenerator.new(), 1))
	Profile.equip(int(it.uid))
	var g := TileGrid.new(40, 24)
	for y in range(2, 22):
		for x in range(2, 38):
			g.put(x, y, TileGrid.FLOOR)
	g.finalize_walls()
	var st := Stage.new()
	st.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(st)
	st.setup(g, null)
	var pl := Player.new()
	pl.pos = Vector2(20, 12)
	pl.input_enabled = false
	pl.godmode = true
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", Profile.equipped_weapon(), 0, ["", "", ""]))
	var arch := pl.weapon.id
	var charged := arch in ["spear", "hammer", "bow"] or base == "sunfall_glaive"
	var out := {"n": 0, "first": -1.0}
	var form := pl.weapon.form
	var t := 0.0
	var dt := 1.0 / 30.0
	var walk := 0.0
	var hold := 0.0
	var mark := _moments(pl, form)
	while t < secs:
		var foes := st.hostiles(pl.team).filter(func(a): return a is Enemy and a.alive)
		if foes.is_empty() and walk <= 0.0:
			if fight == "small" and t > 0.0:
				walk = 3.0     # to the next room
			_spawn(st, fight, pl)
		walk = maxf(0.0, walk - dt)
		if fight == "long" and foes.size() < 8:
			_spawn_one(st, "husk", pl)
		var near: Actor = null
		var bd := INF
		for f in foes:
			var dd: float = f.pos.distance_to(pl.pos)
			if dd < bd:
				bd = dd
				near = f
		if near:
			var to := near.pos - pl.pos
			pl.aim = to.normalized()
			pl.aim_point = near.pos
			var reach := 1.4 if arch in ["sword", "daggers", "hammer"] else (2.2 if arch == "spear" else 6.0)
			pl.move_in = to.normalized() if to.length() > reach else Vector2.ZERO
			if to.length() <= reach + 0.5:
				if charged:
					# press and hold, then let go (the charged blow), a beat between
					if hold == 0.0:
						pl.press("attack")
					hold += dt
					pl._attack_down = hold > 0.0 and hold < 0.9
					if hold >= 0.9:
						pl._attack_down = false
						pl._release_pending = true
						hold = -0.35
					elif hold < 0.0 and hold + dt >= 0.0:
						hold = 0.0
				elif fmod(t, 0.2) < dt:
					pl.press("attack")
		else:
			pl.move_in = Vector2.ZERO
		st.simulate(dt)
		t += dt
		var now := _moments(pl, form)
		if now > mark:
			out.n += now - mark
			if out.first < 0.0:
				out.first = t
		mark = now
	st.queue_free()
	await get_tree().process_frame
	return out


## How many signature moments so far (read from the weapon/player's own count).
func _moments(pl: Player, form: String) -> int:
	return int(pl.get_meta("legend_moments", 0))


func _spawn(st: Stage, fight: String, pl: Player) -> void:
	match fight:
		"small":
			for k in 3:
				_spawn_one(st, "husk", pl)
		"long":
			for k in 8:
				_spawn_one(st, "husk", pl)
		"boss":
			var e := _spawn_one(st, "guard", pl)
			e.max_hp *= 30.0
			e.hp = e.max_hp


func _spawn_one(st: Stage, id: String, pl: Player) -> Enemy:
	var e: Enemy = load(EnemyDB.get_def(id).script).new()
	e.configure(id)
	e.pos = st.random_floor_near(pl.pos + Vector2.from_angle(randf() * TAU) * 4.0, 1.0)
	e.damage = 0.0
	st.add_actor(e)
	e.spawn_t = 0.0
	return e
