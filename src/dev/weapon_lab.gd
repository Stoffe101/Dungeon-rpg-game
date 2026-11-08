## Dev: every weapon side by side (`-- weaponlab`, debug builds, headless is fine).
## A Kindled with the weapon (no gear, no tree, the same skill for every weapon: it
## presses attack, holds charged moves, keeps its distance with ranged ones) fights by
## the game's own rules in three fights:
##   duel  - one tough Guard (shield, poise, real blows): damage dealt and taken a minute
##   pack  - waves of five Husks at once: foes felled a minute, damage taken a minute
##   swarm - Skitters that keep coming: foes felled a minute
## Health is raised so nobody dies and the fight keeps going: what is measured is how
## much it hurts, not whether it ends. Not a verdict on fun, a map of where each weapon sits.
##
## Args: secs=60 bases=hearthblade,gravecleaver,...  (default: every weapon base)
class_name WeaponLab
extends Node

var secs := 60.0
var bases: Array = []


func _ready() -> void:
	for a in Dev.args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"secs":
				secs = float(kv[1])
			"bases":
				bases = Array(kv[1].split(","))
	if bases.is_empty():
		for k in ItemDB.BASES:
			var b: Dictionary = ItemDB.BASES[k]
			if String(b.get("slot", "")) == "weapon":
				bases.append(k)
	_go.call_deferred()


func _go() -> void:
	var lines: Array = ["# Weapon lab (%d s a fight, the same simple player for all)" % int(secs), "",
		"| weapon | arch | form | brute dealt/min | brute taken/min | shield dealt/min | pack kills/min | pack taken/min | swarm kills/min |", "|---|---|---|---|---|---|---|---|---|"]
	for b in bases:
		var brute := await _run(String(b), "brute")
		var duel := await _run(String(b), "duel")
		var pack := await _run(String(b), "pack")
		var swarm := await _run(String(b), "swarm")
		var row := "| %s | %s | %s | %d | %d | %d | %.1f | %d | %.1f |" % [b, duel.arch, duel.form if duel.form != "" else "-",
			int(brute.dealt * 60.0 / secs), int(brute.taken * 60.0 / secs), int(duel.dealt * 60.0 / secs), pack.kills * 60.0 / secs, int(pack.taken * 60.0 / secs), swarm.kills * 60.0 / secs]
		print("[weapons] " + row)
		lines.append(row)
	var f := FileAccess.open("user://weapon_lab.md", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	print("[weapons] done")
	get_tree().quit()


func _run(base: String, fight: String) -> Dictionary:
	seed(91)
	Profile.data = Profile.fresh()
	var rare := "legendary" if ItemDB.base(base).get("legendary", false) or ItemDB.base(base).get("unique", false) else "rare"
	var it := Profile.add_item(ItemDB.make_item(base, rare, 1, RandomNumberGenerator.new(), 1))
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
	st.add_actor(pl)
	st.player = pl
	pl.setup_from(RunState.create(1, "ossuary", Profile.equipped_weapon(), 0, ["", "", ""]))
	pl.max_hp = 100000.0
	pl.hp = pl.max_hp
	var arch := pl.weapon.id
	var ranged := arch in ["staff", "bow", "tome"]
	var charged := arch in ["spear", "hammer", "bow", "staff"]
	var reads := arch == "tome"     # the tome is held: reading is the attack
	var out := {"dealt": 0.0, "taken": 0.0, "kills": 0, "arch": arch, "form": pl.weapon.form}
	var t := 0.0
	var dt := 1.0 / 30.0
	var hold := 0.0
	var on_hit := func(_t: Node, amount: float, _crit: bool) -> void: out.dealt += amount
	Events.damage_dealt.connect(on_hit)
	var hp_was := pl.hp
	_spawn(st, fight, pl)
	while t < secs:
		var foes := st.hostiles(pl.team).filter(func(a): return a is Enemy and a.alive)
		if fight == "pack" and foes.is_empty():
			_spawn(st, fight, pl)
		if fight == "swarm" and foes.size() < 6:
			_spawn_one(st, "skitter", pl)
		var near: Actor = null
		var bd := INF
		for e in foes:
			var dd: float = e.pos.distance_to(pl.pos)
			if dd < bd:
				bd = dd
				near = e
		if near:
			var to := near.pos - pl.pos
			pl.aim = to.normalized()
			pl.aim_point = near.pos
			var reach := 1.3 if arch in ["sword", "daggers", "hammer"] else (2.4 if arch == "spear" else 6.0)
			if pl.weapon.form == "ash":
				reach = 2.8
			if to.length() > reach:
				pl.move_in = to.normalized()
			elif ranged and reach > 4.0 and to.length() < 3.0:
				pl.move_in = -to.normalized()
			else:
				pl.move_in = Vector2.ZERO
			if reads:
				if not pl._attack_down:
					pl.press("attack")
				pl._attack_down = to.length() <= reach + 0.6
			elif to.length() <= reach + 0.6:
				if charged and fmod(t, 3.0) < 1.4:
					if hold == 0.0:
						pl.press("attack")
					hold += dt
					pl._attack_down = hold < 0.9
					if hold >= 0.9:
						pl._attack_down = false
						pl._release_pending = true
						hold = -0.35
					elif hold < 0.0 and hold + dt >= 0.0:
						hold = 0.0
				elif fmod(t, 0.2) < dt:
					pl.press("attack")
					pl._release_pending = true
		else:
			pl.move_in = Vector2.ZERO
		var alive_before := foes.size()
		st.simulate(dt)
		out.taken += maxf(0.0, hp_was - pl.hp)
		pl.hp = pl.max_hp
		hp_was = pl.hp
		var alive_after := st.hostiles(pl.team).filter(func(a): return a is Enemy and a.alive).size()
		if alive_after < alive_before:
			out.kills += alive_before - alive_after
		t += dt
	Events.damage_dealt.disconnect(on_hit)
	st.queue_free()
	await get_tree().process_frame
	return out


func _spawn(st: Stage, fight: String, pl: Player) -> void:
	match fight:
		"brute":
			var b := _spawn_one(st, "husk", pl)
			b.max_hp *= 60.0
			b.hp = b.max_hp
			b.poise *= 4.0
		"duel":
			var e := _spawn_one(st, "guard", pl)
			e.max_hp *= 40.0
			e.hp = e.max_hp
		"pack":
			for k in 5:
				_spawn_one(st, "husk", pl)
		"swarm":
			for k in 6:
				_spawn_one(st, "skitter", pl)


func _spawn_one(st: Stage, id: String, pl: Player) -> Enemy:
	var e: Enemy = load(EnemyDB.get_def(id).script).new()
	e.configure(id)
	e.pos = st.random_floor_near(pl.pos + Vector2.from_angle(randf() * TAU) * 5.0, 1.0)
	st.add_actor(e)
	e.spawn_t = 0.0
	return e
