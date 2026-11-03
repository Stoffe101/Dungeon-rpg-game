## Active abilities (spend Kindle). Each returns true when it was cast.
## Ember Runes (see Runes) change how each behaves: the generic ones (Arcing,
## Ruin, Kindling, Rime, Gloam) act on every hit in Player.deal_hit; Many, Echoes
## and the Well are written into each spell here.
class_name Abilities
extends RefCounted

## While a spell (or its echo) is being cast: its id, power and where it came from.
static var _ab := ""
static var _power := 1.0


## `power` < 1 for echoes; `at` is where an echo happens (INF: the Kindled).
static func cast(pl: Player, id: String, power := 1.0, at := Vector2.INF, dir := Vector2.ZERO) -> bool:
	_ab = id
	_power = power * Runes.damage_mult(pl, id)
	if pl.stats.has("runebound"):
		_power *= 1.0 + 0.08 * Runes.total(pl)
	var ok := false
	match id:
		"flare":
			ok = _flare(pl, at)
		"cinder_lance":
			ok = _lance(pl, at, dir)
		"frost_sigil":
			ok = _sigil(pl, at)
		"gloamstep":
			ok = _gloamstep(pl, power < 1.0)
		"aegis":
			ok = _aegis(pl, power)
		"wisp":
			ok = _wisp(pl, power)
	_ab = ""
	_power = 1.0
	return ok


## After a cast: the Rune of Echoes schedules the spell again, weaker.
static func echo(pl: Player, id: String, at: Vector2, dir: Vector2, target: Vector2) -> void:
	if not Runes.has(pl, id, "echo"):
		return
	var st := pl.stage
	match id:
		"flare", "cinder_lance":
			st.after(0.6, func() -> void:
				if is_instance_valid(pl) and pl.alive:
					cast(pl, id, 0.6, at, dir))
		"frost_sigil":
			pass    # handled by the sigil's own pulse count
		"gloamstep":
			st.after(2.0, func() -> void:
				if not is_instance_valid(pl) or not pl.alive:
					return
				st.fx.ghost(pl.sprite, pl.global_position + pl.sprite.position, Color(0.55, 0.3, 0.75), 0.4)
				pl.pos = at
				st.fx.burst(at, 0.6, Color(0.7, 0.45, 0.9), 16, 3.0, 0.4, -1.0)
				Audio.play_at("blink", at, -2.0, 1.2))
		"wisp":
			st.after(6.0, func() -> void:
				if is_instance_valid(pl) and pl.alive:
					cast(pl, "wisp", 0.6))
		"aegis":
			pl.aegis_echo = true


static func _hit(pl: Player, base: float, tags: Array) -> Hit:
	var t := tags.duplicate()
	t.append("ability")
	var h := Combat.player_hit(pl, pl.stats, base * _power, t)
	h.set_meta("ab", _ab)
	return h


## The knockback a spell gives: outward, or inward with the Rune of the Well.
static func _push(pl: Player, from: Vector2, a: Actor, force: float) -> Vector2:
	var out := (a.pos - from).normalized()
	if Runes.has(pl, _ab, "gravity"):
		return -out * force * 1.2
	return out * force


static func _flare(pl: Player, at: Vector2) -> bool:
	var d := GearDB.ability("flare")
	var c := pl.pos if at == Vector2.INF else at
	var bellows := pl.stats.has("bellows")
	var r: float = d.radius * (1.4 if bellows else 1.0) * pl.stats.v("area") * Runes.area_mult(pl, "flare")
	_flare_at(pl, c, r, d.damage, bellows)
	if Runes.has(pl, "flare", "split") and at == Vector2.INF:
		# Rune of Many: three more, smaller, around the Kindled
		for k in 3:
			var p := c + Vector2.from_angle(pl.aim.angle() + TAU * k / 3.0) * (r * 0.9)
			var st := pl.stage
			var me := pl
			var rr := r * 0.55
			var dmg: float = d.damage * 0.5
			st.after(0.12 + k * 0.08, func() -> void:
				if is_instance_valid(me):
					var was := _ab
					var wp := _power
					_ab = "flare"
					_power = Runes.damage_mult(me, "flare")
					_flare_at(me, p, rr, dmg, false)
					_ab = was
					_power = wp)
	return true


static func _flare_at(pl: Player, c: Vector2, r: float, dmg: float, bellows: bool) -> void:
	var st := pl.stage
	var col := Runes.tint(pl, "flare", Color(1.0, 0.65, 0.3))
	st.fx.ring(c, r, col, 0.28, 0.3)
	st.fx.ring(c, r * 0.6, col.lightened(0.4), 0.2, 0.2)
	st.fx.burst(c, 0.5, col, 34, r * 3.0, 0.45, 1.0)
	st.fx.burst(c, 0.5, col.lightened(0.5), 14, r * 2.0, 0.3, 0.0)
	st.fx.flash_light(c, 0.8, col, 5.0, r * 2.4, 0.4)
	st.fx.shake(0.3)
	Audio.play("flare", 0.0)
	st.strike_props_circle(c, r, pl, true)
	for a in st.in_circle(pl.team, c, r):
		var h := _hit(pl, dmg, ["fire"])
		h.burn = 2
		h.knockback = _push(pl, c, a, 12.0 if bellows else 7.0)
		h.from_dir = (a.pos - c).normalized()
		h.poise = 25.0
		pl.deal_hit(a, h)
	if pl.stats.has("flare_ground"):
		var hz := Hazard.spawn(st, c, r * 0.75, 3.0, pl.team, col, func(_hz: Hazard, a: Actor) -> void:
			var h := _hit(pl, 5.0, ["fire", "dot"])
			h.burn = 1
			h.can_crit = false
			h.silent = true
			pl.deal_hit(a, h))
		hz.period = 0.5
		hz.particle_rate = 14.0


static func _lance(pl: Player, at: Vector2, dir0: Vector2) -> bool:
	var d := GearDB.ability("cinder_lance")
	var from := pl.pos if at == Vector2.INF else at
	var aim := pl.aim if dir0 == Vector2.ZERO else dir0
	var dirs: Array = [aim]
	var each := 1.0
	if pl.stats.has("splinter_lance") or Runes.has(pl, "cinder_lance", "split"):
		dirs = [aim.rotated(-0.22), aim, aim.rotated(0.22)]
		each = 1.0 if pl.stats.has("splinter_lance") else 0.7
	var col := Runes.tint(pl, "cinder_lance", Color(1.0, 0.55, 0.2))
	var gravity := Runes.has(pl, "cinder_lance", "gravity")
	var ab := _ab
	var power := _power
	for dir: Vector2 in dirs:
		var pr := Projectile.create(pl.stage, "proj_lance", from + dir * 0.5, dir * 24.0, pl.team)
		pr.source = pl
		pr.damage = d.damage * each
		pr.tags = ["ability", "fire"]
		pr.pierce = 99
		pr.radius = 0.4
		pr.life = d.range / 24.0
		pr.height = 0.6
		pr.burn = 1
		pr.knockback = 3.0
		pr.spin = true
		pr.reflectable = false
		pr.trail_color = col
		pr.trail_rate = 90.0
		pr.with_light(col, 1.4, 3.0)
		pr.make_hit_fn = func(proj: Projectile, t: Actor) -> Hit:
			var was := _ab
			var wp := _power
			_ab = ab
			_power = power
			var h := _hit(pl, proj.damage, ["fire"])
			_ab = was
			_power = wp
			h.burn = 1
			h.knockback = ((pl.pos - t.pos).normalized() * 6.0) if gravity else proj.vel.normalized() * 3.0
			h.from_dir = proj.vel.normalized()
			h.poise = 18.0
			return h
	pl.stage.fx.burst(from + aim * 0.6, 0.6, col, 10, 5.0, 0.25, 0.0, aim, 0.4)
	pl.stage.fx.shake(0.15)
	Audio.play("lance", 0.0)
	return true


static func _sigil(pl: Player, at: Vector2) -> bool:
	var d := GearDB.ability("frost_sigil")
	var big := pl.stats.has("glacier_seal")
	var r: float = d.radius * (1.25 if big else 1.0) * pl.stats.v("area") * Runes.area_mult(pl, "frost_sigil")
	var target := at
	if target == Vector2.INF:
		target = pl.pos + (pl.aim_point - pl.pos).limit_length(8.0)
		if pl.stage.grid.at(floori(target.x), floori(target.y)) != TileGrid.FLOOR:
			target = pl.pos + pl.aim * 2.0
	var pulses := (5 if big else 3) + (2 if Runes.has(pl, "frost_sigil", "echo") else 0)
	_sigil_at(pl, target, r, pulses, d.damage)
	if Runes.has(pl, "frost_sigil", "split"):
		var mirror := pl.pos - (target - pl.pos)
		if pl.stage.grid.at(floori(mirror.x), floori(mirror.y)) == TileGrid.FLOOR:
			_sigil_at(pl, mirror, r * 0.7, pulses, d.damage * 0.7)
	Audio.play("sigil", 0.0)
	return true


static func _sigil_at(pl: Player, target: Vector2, r: float, pulses: int, dmg: float) -> void:
	var st := pl.stage
	var col := Color(0.6, 0.85, 1.0)
	if Runes.has(pl, "frost_sigil", "gloam"):
		col = Color(0.7, 0.45, 0.95)
	var sig := st.fx.shape(Fx.Shape.SIGIL, target, Vector2.RIGHT, Vector2(r * 2, r * 2), Color(col.r, col.g, col.b, 0.5), col.lightened(0.3), pulses * 0.6 + 0.3, {"glow": 1.6})
	var data_t := [0.0]
	var sig_ref: WeakRef = weakref(sig)
	var gravity := Runes.has(pl, "frost_sigil", "gravity")
	var power := _power
	var hz := Hazard.spawn(st, target, r, pulses * 0.6 + 0.05, pl.team, col, Callable())
	hz.period = 0.6
	hz.particle_rate = 10.0
	hz.on_pulse = func(h: Hazard) -> void:
		data_t[0] += 1.0
		var sn = sig_ref.get_ref()
		if sn != null:
			sn.set_instance_shader_parameter("progress", data_t[0] / pulses)
		st.fx.ring(h.pos, r, col, 0.3, 0.2)
		st.fx.burst(h.pos, 0.2, col.lightened(0.3), 12, 4.0, 0.4, 2.0)
		Audio.play("frost", -3.0, 1.0 + data_t[0] * 0.05)
		_ab = "frost_sigil"
		_power = power
		for a in st.in_circle(pl.team, h.pos, r):
			var hit := _hit(pl, dmg, ["frost"])
			hit.chill = 0.4
			hit.poise = 8.0
			if gravity:
				hit.knockback = (h.pos - a.pos).normalized() * 5.0
			pl.deal_hit(a, hit)
		_ab = ""
		_power = 1.0


static func _gloamstep(pl: Player, is_echo: bool) -> bool:
	var d := GearDB.ability("gloamstep")
	var st := pl.stage
	var from := pl.pos
	var want := pl.pos + (pl.aim_point - pl.pos).limit_length(d.range)
	var dest := from
	var steps := 24
	for i in range(steps, 0, -1):
		var c := from.lerp(want, float(i) / steps)
		if not st.grid.box_blocked(c, pl.box()):
			dest = c
			break
	st.fx.burst(from, 0.6, Color(0.6, 0.35, 0.8), 16, 3.0, 0.4, -1.0)
	st.fx.ghost(pl.sprite, pl.global_position + pl.sprite.position, Color(0.55, 0.3, 0.75), 0.5)
	pl.pos = dest
	pl.invuln_t = maxf(pl.invuln_t, 0.3)
	st.fx.burst(dest, 0.6, Color(0.7, 0.45, 0.9), 16, 3.0, 0.4, -1.0)
	Audio.play("blink", 0.0)
	var twice := pl.stats.has("twin_shade")
	var dmg: float = d.damage * _power
	if Runes.has(pl, "gloamstep", "split"):
		for k in 3:
			shade(pl, from.lerp(dest, k / 3.0), dmg * 0.6, 0.45 + k * 0.1, false)
	else:
		shade(pl, from, dmg, 0.45, twice)
	if Runes.has(pl, "gloamstep", "echo") and not is_echo:
		echo(pl, "gloamstep", from, Vector2.ZERO, from)
	return true


## A shadow afterimage that detonates after `delay`.
static func shade(pl: Player, p: Vector2, dmg: float, delay: float, twice := false) -> void:
	var st := pl.stage
	var mark := st.fx.shape(Fx.Shape.DISC, p, Vector2.RIGHT, Vector2(4.0, 4.0), Color(0.55, 0.3, 0.75, 0.15), Color(0.75, 0.5, 0.95, 0.55), delay + 0.05, {"glow": 1.1})
	st.after(delay * 0.5, func() -> void:
		if is_instance_valid(mark):
			mark.set_instance_shader_parameter("progress", 0.6))
	var gravity := Runes.has(pl, "gloamstep", "gravity")
	var boom := func() -> void:
		if not is_instance_valid(pl) or not is_instance_valid(st):
			return
		st.fx.ring(p, 2.0, Color(0.7, 0.45, 0.95), 0.25, 0.3)
		st.fx.burst(p, 0.5, Color(0.65, 0.4, 0.9), 18, 5.0, 0.4, 1.0)
		st.fx.flash_light(p, 0.6, Color(0.6, 0.35, 0.9), 2.5, 4.0, 0.25)
		Audio.play("shade", -2.0)
		_ab = "gloamstep"
		for a in st.in_circle(pl.team, p, 2.0 * (1.4 if gravity else 1.0)):
			var h := _hit(pl, dmg, ["shadow"])
			h.knockback = (p - a.pos).normalized() * 6.0 if gravity else (a.pos - p).normalized() * 5.0
			h.from_dir = (a.pos - p).normalized()
			h.poise = 15.0
			pl.deal_hit(a, h)
		_ab = ""
	st.after(delay, boom)
	if twice:
		st.after(delay + 0.35, boom)


static func _aegis(pl: Player, power: float) -> bool:
	var d := GearDB.ability("aegis")
	var absorb: float = d.absorb * power
	if Runes.has(pl, "aegis", "split"):
		var allies := pl.stage.players_near(pl.pos, 5.0).filter(func(a): return a != pl)
		if allies.is_empty():
			absorb *= 1.3
		for a: Player in allies:
			a.aegis_hp = maxf(a.aegis_hp, absorb * 0.5)
			a.aegis_t = d.duration
			pl.stage.fx.ring(a.pos, 1.2, Color(1.0, 0.85, 0.45), 0.3, 0.25)
	pl.aegis_hp = absorb
	pl.aegis_t = d.duration
	pl.stage.fx.ring(pl.pos, 1.4, Color(1.0, 0.85, 0.45), 0.3, 0.3)
	pl.stage.fx.burst(pl.pos, 0.8, Color(1.0, 0.85, 0.5), 16, 3.0, 0.4, 0.0)
	Audio.play("aegis", 0.0)
	return true


static func _wisp(pl: Player, power: float) -> bool:
	var d := GearDB.ability("wisp")
	var split := Runes.has(pl, "wisp", "split")
	var n := 2 if pl.stats.has("twin_wisps") or split else 1
	var dur: float = d.duration * (1.5 if pl.stats.has("long_wisps") else 1.0)
	for i in n:
		var w := Wisp.new()
		w.owner_player = pl
		w.duration = dur
		w.damage = d.damage * (1.3 if pl.stats.has("twin_wisps") else 1.0) * (0.6 if split else 1.0) * _power
		w.orbit_phase = float(i) * PI
		w.pos = pl.pos + Vector2.from_angle(w.orbit_phase) * 1.2
		pl.stage.add_actor(w)
	pl.stage.fx.burst(pl.pos, 1.0, Color(1.0, 0.85, 0.45), 20, 3.0, 0.6, -1.0)
	Audio.play("wisp", 0.0)
	return true
