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
	if pl.stats.has("wide_wick") and pl.kindle >= pl.kindle_max() * 0.8:
		_power *= 1.2
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
		"knives":
			ok = _knives(pl, at, dir)
		"lantern":
			ok = _lantern(pl, power)
		"rush":
			ok = _rush(pl, power < 1.0)
		"rekindle":
			ok = _rekindle(pl, power, at)
		"beam":
			ok = _beam(pl, power, dir)
		"orb":
			ok = _orb(pl, power, at)
		"rimewall":
			ok = _rimewall(pl, power)
		"hearthfire":
			ok = _hearthfire(pl, power)
	_ab = ""
	_power = 1.0
	if ok:
		_spellblade(pl, id)
	return ok


## Spellblade (keystone): a spell charges the weapon - the next three weapon
## hits carry its element and strike harder (Player._deal_hit spends them).
static func _spellblade(pl: Player, id: String) -> void:
	if not pl.stats.has("spellblade") or _power < 0.99:
		return
	pl.spellblade_n = 3
	pl.spellblade_el = {"frost_sigil": "frost", "gloamstep": "shadow", "knives": "shadow"}.get(id, "fire")
	var col: Color = {"frost": Color(0.6, 0.85, 1.0), "shadow": Color(0.7, 0.45, 0.95)}.get(pl.spellblade_el, Color(1.0, 0.6, 0.3))
	pl.stage.fx.ring(pl.pos, 0.9, col, 0.25, 0.2)
	if pl.weapon and pl.weapon.visual:
		pl.weapon.visual.set_instance_shader_parameter("flash", Color(col.r, col.g, col.b, 0.8))


## After a cast: the Rune of Echoes schedules the spell again, weaker.
static func echo(pl: Player, id: String, at: Vector2, dir: Vector2, target: Vector2) -> void:
	if not Runes.has(pl, id, "echo"):
		return
	var st := pl.stage
	match id:
		"flare", "cinder_lance", "beam", "orb":
			st.after(0.6 if id != "beam" else 1.8, func() -> void:
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
		"knives":
			st.after(0.28, func() -> void:
				if is_instance_valid(pl) and pl.alive:
					cast(pl, "knives", 0.6, at, dir))
		"lantern":
			pass    # the lantern flares as it gutters (LanternTotem.flare_out)
		"rush":
			pass    # the trail bursts (in _rush)
		"rekindle":
			st.after(3.0, func() -> void:
				if is_instance_valid(pl) and pl.alive:
					cast(pl, "rekindle", 0.5))


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
		st.strike_props_circle(h.pos, r, pl, false)
		for a in st.in_circle(pl.team, h.pos, r):
			var hit := _hit(pl, dmg, ["frost"])
			hit.chill = 0.4
			hit.poise = 8.0
			if gravity:
				hit.knockback = (h.pos - a.pos).normalized() * 5.0
			pl.deal_hit(a, hit)
		_ab = ""
		_power = 1.0


## Where a blink or a rush of `rng` tiles toward the cursor ends: the farthest
## open spot along the way. Deterministic, so a co-op guest predicts the same
## spot the host will choose (its Kindled moves at once, nothing to correct).
static func dash_dest(pl: Player, rng: float, through_foes := true) -> Vector2:
	var st := pl.stage
	var from := pl.pos
	var want := pl.pos + (pl.aim_point - pl.pos).limit_length(rng)
	var steps := 24
	if not through_foes:
		# a rush stops at walls (it cannot pass through them as a blink can)
		var dest2 := from
		for i in range(1, steps + 1):
			var c2 := from.lerp(want, float(i) / steps)
			if st.grid.box_blocked(c2, pl.box()):
				break
			dest2 = c2
		return dest2
	for i in range(steps, 0, -1):
		var c := from.lerp(want, float(i) / steps)
		if not st.grid.box_blocked(c, pl.box()):
			return c
	return from


static func _gloamstep(pl: Player, is_echo: bool) -> bool:
	var d := GearDB.ability("gloamstep")
	var st := pl.stage
	var from := pl.pos
	var dest := dash_dest(pl, d.range)
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
		st.strike_props_circle(p, 2.0, pl, false)
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


## Gloam Knives: a fan of spectral knives (five, plus the Kindled's extra
## projectiles, three more with the Rune of Many). One knife per foe per throw.
static func _knives(pl: Player, at: Vector2, dir0: Vector2) -> bool:
	var d := GearDB.ability("knives")
	var from := pl.pos if at == Vector2.INF else at
	var aim := pl.aim if dir0 == Vector2.ZERO else dir0
	var base: int = int(d.count) + (3 if Runes.has(pl, "knives", "split") else 0)
	var col := Runes.tint(pl, "knives", Color(0.72, 0.5, 1.0))
	var ab := _ab
	var power := _power
	var back := Runes.has(pl, "knives", "gravity")
	Volley.fire(pl, "proj_knife", from, aim, 22.0 * pl.stats.v("projectile_speed"), base, func(pr: Projectile, _dir: Vector2) -> void:
		pr.damage = float(d.damage)
		pr.tags = ["ability", "shadow"]
		pr.radius = 0.22
		pr.life = float(d.range) / 22.0
		pr.height = 0.7
		pr.knockback = 1.2
		pr.spin = true
		pr.reflectable = false
		pr.returning = back
		pr.trail_color = col
		pr.trail_rate = 26.0
		pr.make_hit_fn = func(proj: Projectile, _t: Actor) -> Hit:
			var was := _ab
			var wp := _power
			_ab = ab
			_power = power
			var h := _hit(pl, proj.damage, ["shadow"])
			_ab = was
			_power = wp
			h.knockback = proj.vel.normalized() * proj.knockback
			h.from_dir = proj.vel.normalized()
			h.poise = 3.0
			return h
		pr.on_hit_fn = func(_proj: Projectile, t: Actor, _res) -> void:
			_knife_lodge(pl, t, power, ab), 0.12)
	pl.stage.fx.burst(from + aim * 0.5, 0.7, col, 6, 3.0, 0.2, 0.0, aim, 0.7)
	Audio.play("knives", -4.0, randf_range(0.95, 1.1))
	return true


## Hearth Lantern: a lantern planted at the cursor (two at 60% with the Rune of
## Many). Lanternwright: two may burn at once, they fire faster and last longer.
static func _lantern(pl: Player, power: float) -> bool:
	var d := GearDB.ability("lantern")
	var st := pl.stage
	var wright := pl.stats.has("lanternwright")
	var target := pl.pos + (pl.aim_point - pl.pos).limit_length(6.0)
	if st.grid.box_blocked(target, 0.3):
		target = st.random_floor_near(pl.pos + pl.aim * 1.5, 1.0)
	var spots: Array = [target]
	var each := 1.0
	if Runes.has(pl, "lantern", "split"):
		var side := pl.aim.orthogonal() * 1.4
		spots = [st.random_floor_near(target + side, 0.4), st.random_floor_near(target - side, 0.4)]
		each = 0.6
	# only so many burn at once: the oldest gutters
	var mine: Array = st.actors.filter(func(a): return a is LanternTotem and (a as LanternTotem).owner_player == pl and a.alive)
	var cap := (2 if wright else 1) * spots.size()
	while mine.size() + spots.size() > cap and not mine.is_empty():
		(mine.pop_front() as LanternTotem).duration = 0.0
	for p: Vector2 in spots:
		var t := LanternTotem.new()
		t.owner_player = pl
		t.pos = p
		t.damage = float(d.damage) * _power * each
		t.duration = float(d.duration) * (1.5 if wright else 1.0) * power
		t.fire_every = 0.3 if wright else 0.6
		t.light_r = float(d.radius) * pl.stats.v("area") * Runes.area_mult(pl, "lantern")
		t.flare_out = Runes.has(pl, "lantern", "echo")
		t.draws_in = Runes.has(pl, "lantern", "gravity")
		st.add_actor(t)
		st.fx.ring(p, 1.2, LanternTotem.LIGHT_COL, 0.3, 0.25)
		st.fx.motes(p, 0.6, LanternTotem.LIGHT_COL, 14, 1.6, 0.8, 0.4)
	Audio.play("lantern", -2.0)
	return true


## Ember Rush: a streak of fire toward the cursor; everything in the path is cut
## (a melee hit: melee builds feed it) and set alight.
static func _rush(pl: Player, is_echo: bool) -> bool:
	var d := GearDB.ability("rush")
	var st := pl.stage
	var from := pl.pos
	var dest := dash_dest(pl, float(d.range) * pl.stats.v("area"), false)
	if dest.distance_to(from) < 0.6:
		return false
	var col := Runes.tint(pl, "rush", Color(1.0, 0.6, 0.28))
	# the trail of afterimages, then the Kindled where the streak ends
	for k in 4:
		st.fx.ghost(pl.sprite, pl.global_position + pl.sprite.position, col, 0.25 + k * 0.08)
	pl.pos = dest
	pl.invuln_t = maxf(pl.invuln_t, 0.25)
	_rush_cut(pl, from, dest, float(d.damage) * _power, col)
	if Runes.has(pl, "rush", "split"):
		var side := (dest - from).normalized().orthogonal() * 1.1
		for s in [-1.0, 1.0]:
			_rush_cut(pl, from + side * s, dest + side * s, float(d.damage) * _power * 0.5, col)
	if Runes.has(pl, "rush", "echo") and not is_echo:
		var ab := _ab
		var power := _power
		st.after(0.5, func() -> void:
			if not is_instance_valid(pl):
				return
			_ab = ab
			_power = power * 0.6
			for k in 5:
				var p := from.lerp(dest, (k + 0.5) / 5.0)
				st.fx.burst(p, 0.3, col, 6, 2.5, 0.35, 2.0)
				st.strike_props_circle(p, 1.0, pl, true)
				for a in st.in_circle(pl.team, p, 1.0):
					var h := _hit(pl, float(d.damage) * 0.35, ["fire"])
					h.burn = 1
					pl.deal_hit(a, h)
			_ab = ""
			_power = 1.0)
	st.fx.burst(dest, 0.5, col, 16, 4.0, 0.35, 1.0)
	st.fx.flash_light(dest, 0.6, col, 2.2, 4.0, 0.25)
	st.fx.shake(0.12)
	Audio.play("ember_rush", -2.0)
	if pl.rush_refund > 0.0:
		st.fx.number(dest, 2.4, "CHAIN", Color(1.0, 0.75, 0.4))
		st.fx.ring(dest, 1.2, Color(1.0, 0.75, 0.4), 0.2, 0.25)
		Audio.play("rush_chain", -4.0)
	return true


static func _rush_cut(pl: Player, from: Vector2, to: Vector2, dmg: float, col: Color) -> void:
	var st := pl.stage
	var dir := (to - from).normalized()
	var gravity := Runes.has(pl, "rush", "gravity")
	for k in 6:
		st.fx.burst(from.lerp(to, k / 5.0), 0.4, col, 3, 2.0, 0.25, 0.0, dir, 0.6)
	st.strike_props_line(from, to, 0.8, pl, true)
	for a in st.in_line(pl.team, from, to, 0.8):
		if a.status.burning():
			pl.rush_refund = 0.6
		var h := _hit(pl, dmg, ["melee", "fire"])
		h.burn = 1
		h.from_dir = dir
		h.poise = 20.0
		h.knockback = (to - a.pos) * 3.0 if gravity else dir * 5.0
		pl.deal_hit(a, h)


## Rekindle: hearth-light floods out; every Kindled in it is warded and fed
## Kindle, the downed get back up. (Rune of the Well: foes are drawn in.)
static func _rekindle(pl: Player, power: float, at: Vector2) -> bool:
	var d := GearDB.ability("rekindle")
	var st := pl.stage
	var c := pl.pos if at == Vector2.INF else at
	var r: float = float(d.radius) * pl.stats.v("area") * Runes.area_mult(pl, "rekindle")
	var col := Color(1.0, 0.85, 0.5)
	st.fx.ring(c, r, col, 0.35, 0.35)
	st.fx.ring(c, r * 0.55, Color(1.0, 0.95, 0.75), 0.25, 0.25)
	st.fx.motes(c, 0.3, col, 30, r * 0.6, 1.2, r * 0.8)
	st.fx.flash_light(c, 1.0, col, 3.5, r * 2.2, 0.5)
	Audio.play("rekindle", -1.0)
	for ally in st.players:
		if not is_instance_valid(ally) or ally.pos.distance_to(c) > r + ally.radius:
			continue
		if ally.downed:
			ally.revive(0.3 * power)
			st.fx.number(ally.pos, 2.4, "REKINDLED", col, true)
		elif ally.alive:
			var ward: float = ally.max_hp * float(d.ward) * power
			ally.barrier = maxf(ally.barrier, ward)
			ally.barrier_t = 5.0
			ally.gain_kindle(20.0 * power)
			# the hearth-light burns off what clings and quickens the step
			ally.status.burn_stacks = 0
			ally.status.chill = 0.0
			ally.status.snare_t = 0.0
			ally.status.root_t = 0.0
			ally.haste_t = maxf(ally.haste_t, 3.0 * power)
			st.fx.ring(ally.pos, 1.0, col, 0.3, 0.2)
			st.fx.motes(ally.pos, 0.2, Color(1.0, 0.95, 0.7), 12, 3.0, 0.9, 0.25)
	if Runes.has(pl, "rekindle", "split") and power >= 0.99:
		var ahead := pl.pos + pl.aim * 2.5
		st.after(0.4, func() -> void:
			if is_instance_valid(pl) and pl.alive:
				_rekindle(pl, 0.5, ahead))
	if Runes.has(pl, "rekindle", "gravity"):
		for a in st.in_circle(pl.team, c, r + 2.0):
			var h := _hit(pl, 6.0, ["fire"])
			h.knockback = (c - a.pos).normalized() * 8.0
			h.poise = 40.0
			pl.deal_hit(a, h)
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



# --- Soulfire Beam ------------------------------------------------------------------

## A beam of the lantern's fire, steered by the Kindled's aim for 1.6s; it
## burns hotter the longer it holds on (Rune of Many: two thinner beams beside
## it; of the Well: it drags what it touches in toward its line).
static func _beam(pl: Player, power: float, dir0: Vector2) -> bool:
	var d := GearDB.ability("beam")
	var st := pl.stage
	var dur: float = float(d.duration) * (1.0 if power >= 0.99 else 0.6)
	var ticks := int(dur / 0.08)
	var ab := _ab
	var pw := _power
	var col := Runes.tint(pl, "beam", Color(1.0, 0.62, 0.25))
	var side := Runes.has(pl, "beam", "split")
	var well := Runes.has(pl, "beam", "gravity")
	if power >= 0.99:
		pl.channel_t = dur
	Audio.play("beam_start", -2.0)
	for k in ticks:
		st.after(0.08 * k, func() -> void:
			if not is_instance_valid(pl) or not pl.alive:
				return
			var aim := pl.aim if dir0 == Vector2.ZERO or power >= 0.99 else dir0
			var ramp := 1.0 + 1.2 * minf(1.0, float(k) / maxf(1.0, ticks - 1) * (1.5 if pl.stats.has("steady_pour") else 1.0))
			_beam_tick(pl, aim, float(d.range) * pl.stats.v("area"), float(d.damage) * ramp, k, col, ab, pw, well)
			if side:
				for s in [-0.24, 0.24]:
					_beam_tick(pl, aim.rotated(s), float(d.range) * 0.8, float(d.damage) * ramp * 0.5, k, col, ab, pw, false)
			if k % 5 == 0:
				Audio.play("beam_hum", -6.0, 0.95 + 0.04 * ramp))
	return true


static func _beam_tick(pl: Player, aim: Vector2, reach: float, dmg: float, k: int, col: Color, ab: String, pw: float, well: bool) -> void:
	var st := pl.stage
	var from := pl.pos + aim * 0.45
	var to := from
	var step := 0.0
	while step < reach:
		var p := from + aim * (step + 0.25)
		if st.grid.blocks_shot(floori(p.x), floori(p.y)):
			break
		to = p
		step += 0.25
	var len := from.distance_to(to)
	# a wide soft glow, and a white-hot core that flickers with the pour
	var flick := 0.85 + 0.15 * sin(st.elapsed * 40.0 + k)
	st.fx.shape(Fx.Shape.RECT, from, aim, Vector2(len, 0.8), Color(col.r, col.g, col.b, 0.22 * flick), Color(col.r, col.g, col.b, 0.5), 0.1, {"progress": 1.0, "glow": 1.6})
	st.fx.shape(Fx.Shape.RECT, from, aim, Vector2(len, 0.24), Color(1.0, 0.92, 0.7, 0.85 * flick), Color(1.0, 0.98, 0.9, 1.0), 0.1, {"progress": 1.0, "glow": 3.0})
	if k % 2 == 0:
		st.fx.burst(to, 0.6, col, 3, 3.0, 0.2, 0.0, -aim, 0.8)
	if k % 4 == 0:
		st.fx.flash_light(from.lerp(to, 0.5), 0.6, col, 1.4, len * 0.7 + 2.0, 0.12)
	st.strike_props_line(from, to, 0.5, pl, true)
	var was := _ab
	var wp := _power
	_ab = ab
	_power = pw
	for a in st.in_line(pl.team, from, to, 0.5):
		var h := _hit(pl, dmg, ["fire"])
		h.burn = 1 if k % 3 == 0 else 0
		h.silent = k % 3 != 0
		h.poise = 3.0
		h.from_dir = aim
		h.knockback = Vector2.ZERO
		if well:
			var t := clampf((a.pos - from).dot(aim), 0.0, len)
			h.knockback = (from + aim * t - a.pos) * 4.0
		pl.deal_hit(a, h)
	_ab = was
	_power = wp


# --- Cinder Orb ---------------------------------------------------------------------

## A slow orb of embers drifting toward the cursor, scorching what it touches;
## cast again to burst it (bigger the longer it drifted). Rune of Many: two
## orbs; of Echoes: the burst comes twice; of the Well: it draws foes in.
static func _orb(pl: Player, power: float, at: Vector2) -> bool:
	var d := GearDB.ability("orb")
	var st := pl.stage
	var from := pl.pos if at == Vector2.INF else at
	var target := pl.aim_point if at == Vector2.INF else at + pl.aim * 5.0
	var dirs: Array = [(target - from).normalized()]
	var each := 1.0
	if Runes.has(pl, "orb", "split"):
		dirs = [dirs[0].rotated(-0.35), dirs[0].rotated(0.35)]
		each = 0.6
	var orbs: Array = []
	for dv: Vector2 in dirs:
		if dv.length() < 0.1:
			dv = pl.aim
		var pr := Projectile.create(st, "proj_cinder_orb", from + dv * 0.6, dv * 4.2, pl.team)
		pr.source = pl
		pr.damage = 4.0 * _power
		pr.tags = ["ability", "fire"]
		pr.burn = 1
		pr.radius = 0.45
		pr.pierce = 999
		pr.life = float(d.life)
		pr.height = 0.8
		pr.knockback = 0.5
		pr.reflectable = false
		pr.trail_color = Color(1.0, 0.55, 0.2)
		pr.trail_rate = 24.0
		pr.with_light(Color(1.0, 0.55, 0.22), 1.4, 3.5)
		pr.set_meta("born", st.elapsed)
		pr.set_meta("power", _power * each * power)
		pr.set_meta("ab", _ab)
		pr.on_end_fn = func(proj: Projectile, p: Vector2) -> void:
			_orb_burst(pl, proj, p)
		orbs.append(pr)
		if Runes.has(pl, "orb", "gravity"):
			_orb_pull(pl, pr)
	pl.set_meta("orbs", orbs)
	Audio.play("orb_throw", -2.0)
	return true


static func _orb_pull(pl: Player, pr: Projectile) -> void:
	var st := pl.stage
	for k in 40:
		st.after(0.1 * k, func() -> void:
			if not is_instance_valid(pr) or pr.life <= 0.0 or not is_instance_valid(pl):
				return
			for a in st.in_circle(pl.team, pr.pos, 3.0):
				if a is Enemy and not (a as Enemy).def.get("boss", false):
					a.push += (pr.pos - a.pos).normalized() * 0.6)


## The Kindled's orbs still drifting (Player._try_ability: a second cast bursts them).
static func live_orbs(pl: Player) -> Array:
	var orbs: Array = pl.get_meta("orbs", [])
	return orbs.filter(func(o): return is_instance_valid(o) and o.life > 0.0)


static func burst_orbs(pl: Player) -> bool:
	var orbs := live_orbs(pl)
	if orbs.is_empty():
		return false
	for o in orbs:
		o.life = 0.0     # ends on its next step: the burst (on_end_fn)
	pl.set_meta("orbs", [])
	return true


static func _orb_burst(pl: Player, proj: Projectile, p: Vector2) -> void:
	if not is_instance_valid(pl) or proj.get_meta("burst", false):
		return
	proj.set_meta("burst", true)
	var st := pl.stage
	var d := GearDB.ability("orb")
	var age := clampf((st.elapsed - float(proj.get_meta("born", st.elapsed))) / 2.5, 0.0, 1.0)
	var k := 1.0 + 1.5 * age
	var r: float = float(d.radius) * (1.0 + 0.5 * age) * pl.stats.v("area")
	var dmg: float = float(d.damage) * k
	var col := Color(1.0, 0.55, 0.22)
	var was := _ab
	var wp := _power
	_ab = String(proj.get_meta("ab", "orb"))
	_power = float(proj.get_meta("power", 1.0))
	st.fx.ring(p, r, col, 0.3, 0.4)
	st.fx.ring(p, r * 0.55, Color(1.0, 0.9, 0.6), 0.22, 0.25)
	st.fx.burst(p, 0.5, col, int(16 + 24 * age), 6.0 + 3.0 * age, 0.45, 2.0)
	st.fx.flash_light(p, 0.8, col, 3.0 + 2.0 * age, r * 2.5, 0.35)
	st.fx.shake(0.15 + 0.25 * age)
	Audio.play_at("orb_burst", p, -1.0 + 3.0 * age, 1.15 - 0.25 * age)
	st.strike_props_circle(p, r, pl, true)
	if pl.stats.has("detonator"):
		for a in st.in_circle(pl.team, p, r):
			if int(a.get_meta("knives_in", 0)) > 0:
				knives_detonate(pl, a)
			if int(a.get_meta("gloam_marks", 0)) > 0:
				tear_marks(pl, a)
		for w in st.props.duplicate():
			if is_instance_valid(w) and w.kind == "icewall" and w.pos.distance_to(p) <= r:
				_rimewall_shatter(pl, [w], float(GearDB.ability("rimewall").damage), "rimewall")
	for a in st.in_circle(pl.team, p, r):
		var h := _hit(pl, dmg, ["fire"])
		h.burn = 1 + int(2.0 * age)
		h.knockback = (a.pos - p).normalized() * (5.0 + 5.0 * age)
		h.from_dir = (a.pos - p).normalized()
		h.poise = 20.0 + 30.0 * age
		pl.deal_hit(a, h)
	_ab = was
	_power = wp
	if Runes.has(pl, "orb", "echo") and not proj.get_meta("echoed", false):
		var ghost := Projectile.new()
		ghost.set_meta("born", float(proj.get_meta("born", st.elapsed)) + 1.2)
		ghost.set_meta("power", float(proj.get_meta("power", 1.0)) * 0.5)
		ghost.set_meta("ab", proj.get_meta("ab", "orb"))
		ghost.set_meta("echoed", true)
		st.after(0.5, func() -> void:
			if is_instance_valid(pl):
				_orb_burst(pl, ghost, p)
			ghost.free())


# --- Rimewall -----------------------------------------------------------------------

## A wall of ice across the Kindled's aim: foes and their shots stop at it;
## melted, it shatters on what stands beside it. Rune of Many: a longer wall;
## of Echoes: it shatters twice; of the Well: foes near are dragged to its face.
static func _rimewall(pl: Player, power: float) -> bool:
	var d := GearDB.ability("rimewall")
	var st := pl.stage
	var c := pl.pos + (pl.aim_point - pl.pos).limit_length(5.0)
	if st.grid.at(floori(c.x), floori(c.y)) != TileGrid.FLOOR:
		c = st.random_floor_near(c, 1.5)
	var across := pl.aim.orthogonal().normalized()
	var n := int(d.length) + (2 if Runes.has(pl, "rimewall", "split") else 0)
	var made := 0
	var segs: Array = []
	var taken := {}
	for k in n:
		var t := Vector2i(floori(c.x + across.x * (k - (n - 1) * 0.5)), floori(c.y + across.y * (k - (n - 1) * 0.5)))
		if taken.has(t) or st.grid.at(t.x, t.y) != TileGrid.FLOOR:
			continue
		# never in a doorway: a seal closing over the ice (or the ice melting
		# under a closed seal) used to leave a hole in the room's gates
		if st.has_method("is_door_tile") and st.is_door_tile(t):
			continue
		var blocked := false
		var cell := Rect2(Vector2(t), Vector2.ONE)
		for a in st.actors:
			if a.alive and cell.grow(a.box() * 0.9).has_point(a.pos):
				blocked = true     # never wall anyone in, nor half into ice
				break
		if blocked:
			continue
		taken[t] = true
		var seg := Prop.make(st, "icewall", t, {"bastion": pl.stats.has("frozen_bastion")})
		segs.append(seg)
		made += 1
	if made == 0:
		return false
	st.fx.burst(c, 0.3, Color(0.75, 0.92, 1.0), 20, 4.0, 0.5, 4.0)
	st.fx.flash_light(c, 0.8, Color(0.6, 0.85, 1.0), 2.5, 6.0, 0.3)
	st.fx.shake(0.15)
	Audio.play("icewall_rise", -1.0)
	if Runes.has(pl, "rimewall", "gravity"):
		for a in st.in_circle(pl.team, c, 3.5):
			if a is Enemy and not (a as Enemy).def.get("boss", false):
				var near := c + across * across.dot(a.pos - c)
				a.push += (near - a.pos).normalized() * 6.0
	var dur: float = float(d.duration) * power
	var dmg: float = float(d.damage) * _power
	var twice := Runes.has(pl, "rimewall", "echo")
	var ab := _ab
	st.after(dur, func() -> void:
		_rimewall_shatter(pl, segs, dmg, ab)
		if twice:
			st.after(0.5, func() -> void: _rimewall_shatter(pl, segs, dmg * 0.6, ab, true)))
	return true


static func _rimewall_shatter(pl: Player, segs: Array, dmg: float, ab: String, ghost := false) -> void:
	if segs.is_empty():
		return
	var st: Stage = null
	var at: Array = []
	for s in segs:
		if is_instance_valid(s):
			st = s.stage
			at.append(s.pos)
			if not ghost:
				s.unsolid()
				st.props.erase(s)
				s.queue_free()
	if st == null or not is_instance_valid(pl):
		return
	var was := _ab
	_ab = ab
	Audio.play_at("icewall_shatter", at[at.size() / 2] if not at.is_empty() else pl.pos, -1.0)
	var hit := {}
	for p: Vector2 in at:
		st.fx.burst(p, 0.8, Color(0.8, 0.95, 1.0), 10, 5.0, 0.4, 6.0)
		for a in st.in_circle(pl.team, p, 1.5):
			if hit.has(a.get_instance_id()):
				continue
			hit[a.get_instance_id()] = true
			var h := _hit(pl, dmg, ["frost"])
			h.chill = 1.0 if pl.stats.has("frozen_bastion") and a.status.chill > 0.0 else 0.5
			h.knockback = (a.pos - p).normalized() * 4.0
			h.poise = 20.0
			pl.deal_hit(a, h)
	_ab = was


# --- Hearthfire Form ----------------------------------------------------------------

## The Kindled becomes hearth-fire for 7s (Player.hearthfire_t: faster, hits
## burst in flame, cold cannot slow it, Kindle flows back); it ends in a nova.
static func _hearthfire(pl: Player, power: float) -> bool:
	var d := GearDB.ability("hearthfire")
	var st := pl.stage
	var dur: float = float(d.duration) * (1.0 if power >= 0.99 else 0.5)
	pl.hearthfire_t = maxf(pl.hearthfire_t, dur)
	pl.hearthfire_power = _power
	pl.hearthfire_bonus = 0.0
	pl.status.chill = 0.0
	pl.status.snare_t = 0.0
	var col := Color(1.0, 0.6, 0.25)
	st.fx.ring(pl.pos, 2.2, col, 0.35, 0.35)
	st.fx.burst(pl.pos, 0.4, col, 30, 5.0, 0.6, -1.0)
	st.fx.flash_light(pl.pos, 1.0, col, 4.0, 7.0, 0.5)
	Audio.play("hearthfire_on", -1.0)
	return true


## When the form ends: a nova of what was left of it.
static func hearthfire_nova(pl: Player) -> void:
	var st := pl.stage
	var d := GearDB.ability("hearthfire")
	var r := 3.0 * pl.stats.v("area")
	var col := Color(1.0, 0.6, 0.25)
	st.fx.ring(pl.pos, r, col, 0.35, 0.4)
	st.fx.burst(pl.pos, 0.4, col, 28, 6.0, 0.45, 2.0)
	st.fx.flash_light(pl.pos, 0.8, col, 3.0, 6.0, 0.4)
	st.fx.shake(0.25)
	Audio.play("hearthfire_end", -1.0)
	var was := _ab
	var wp := _power
	_ab = "hearthfire"
	_power = pl.hearthfire_power
	for a in st.in_circle(pl.team, pl.pos, r):
		var h := _hit(pl, float(d.damage) * 3.0, ["fire"])
		h.burn = 2
		h.knockback = (a.pos - pl.pos).normalized() * 8.0
		h.poise = 30.0
		pl.deal_hit(a, h)
	_ab = was
	_power = wp


## A weapon hit in Hearthfire Form: a burst of flame where it landed.
static func hearthfire_burst(pl: Player, t: Actor) -> void:
	var st := pl.stage
	var d := GearDB.ability("hearthfire")
	st.fx.burst(t.pos, 0.6, Color(1.0, 0.6, 0.25), 8, 3.5, 0.3, 2.0)
	var was := _ab
	var wp := _power
	_ab = "hearthfire"
	_power = pl.hearthfire_power
	for a in st.in_circle(pl.team, t.pos, 1.1):
		var h := _hit(pl, float(d.damage), ["fire"])
		h.burn = 1
		h.proc = false
		h.silent = a != t
		h.knockback = Vector2.ZERO
		pl.deal_hit(a, h)
	_ab = was
	_power = wp



# --- Gloam Knives: lodged blades -------------------------------------------------------

## A knife that strikes stays in the foe; the next melee blow on it (or 2.5s)
## tears the lodged ones open at once.
static func _knife_lodge(pl: Player, t: Actor, power: float, ab: String) -> void:
	if not is_instance_valid(t) or not t.alive or not is_instance_valid(pl):
		return
	var n := mini(12, int(t.get_meta("knives_in", 0)) + 1)
	t.set_meta("knives_in", n)
	t.set_meta("knives_power", power)
	t.set_meta("knives_ab", ab)
	var stamp := pl.stage.elapsed
	t.set_meta("knives_t", stamp)
	if pl.stats.has("shadow_cutlery"):
		t.set_meta("gloam_marks", mini(5, int(t.get_meta("gloam_marks", 0)) + 1))
		t.set_meta("gloam_mark_t", stamp)
	pl.stage.fx.motes(t.pos, 1.2, Color(0.72, 0.5, 1.0), 1, 0.3, 0.8, 0.2)
	var st := pl.stage
	st.after(2.5, func() -> void:
		if is_instance_valid(t) and is_instance_valid(pl) and float(t.get_meta("knives_t", -1.0)) == stamp:
			knives_detonate(pl, t))


static func knives_detonate(pl: Player, t: Actor) -> void:
	var n := int(t.get_meta("knives_in", 0))
	t.set_meta("knives_in", 0)
	t.set_meta("knives_t", -1.0)
	if n <= 0 or not t.alive or not is_instance_valid(pl):
		return
	var d := GearDB.ability("knives")
	var was := _ab
	var wp := _power
	_ab = String(t.get_meta("knives_ab", "knives"))
	_power = float(t.get_meta("knives_power", 1.0)) * Runes.damage_mult(pl, "knives")
	var h := _hit(pl, float(d.damage) * 0.8 * n, ["shadow"])
	h.proc = false
	h.poise = 4.0 * n
	h.from_dir = (t.pos - pl.pos).normalized()
	pl.deal_hit(t, h)
	_ab = was
	_power = wp
	var col := Color(0.72, 0.5, 1.0)
	pl.stage.fx.burst(t.pos, 0.9, col, 6 + 3 * n, 3.0 + 0.4 * n, 0.3, 0.0)
	pl.stage.fx.ring(t.pos, 0.5 + 0.12 * n, col, 0.2, 0.2)
	Audio.play_at("gloam_tear", t.pos, -6.0 + 0.5 * n, 1.3)
	if pl.stats.has("shadow_cutlery"):
		tear_marks(pl, t)


## Gloam marks on a foe (the Gloam Kris, Shadow Cutlery) torn open by a spell.
static func tear_marks(pl: Player, t: Actor) -> void:
	var m := int(t.get_meta("gloam_marks", 0))
	t.set_meta("gloam_marks", 0)
	if m <= 0 or not t.alive:
		return
	var h := Combat.player_hit(pl, pl.stats, 6.0 * m, ["shadow", "ability"])
	h.proc = false
	h.poise = 5.0 * m
	pl.deal_hit(t, h)
	pl.stage.fx.number(t.pos, 2.2, "%d MARKS" % m, Color(0.85, 0.65, 1.0))
