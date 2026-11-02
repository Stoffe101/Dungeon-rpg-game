## Active abilities (spend Kindle). Each returns true when it was cast.
class_name Abilities
extends RefCounted


static func cast(pl: Player, id: String) -> bool:
	match id:
		"flare":
			return _flare(pl)
		"cinder_lance":
			return _lance(pl)
		"frost_sigil":
			return _sigil(pl)
		"gloamstep":
			return _gloamstep(pl)
		"aegis":
			return _aegis(pl)
		"wisp":
			return _wisp(pl)
	return false


static func _hit(pl: Player, base: float, tags: Array) -> Hit:
	var t := tags.duplicate()
	t.append("ability")
	return Combat.player_hit(pl, pl.stats, base, t)


static func _flare(pl: Player) -> bool:
	var d := GearDB.ability("flare")
	var bellows := pl.stats.has("bellows")
	var r: float = d.radius * (1.4 if bellows else 1.0) * pl.stats.v("area")
	var st := pl.stage
	st.fx.ring(pl.pos, r, Color(1.0, 0.65, 0.3), 0.28, 0.3)
	st.fx.ring(pl.pos, r * 0.6, Color(1.0, 0.9, 0.6), 0.2, 0.2)
	st.fx.burst(pl.pos, 0.5, Color(1.0, 0.6, 0.25), 34, r * 3.0, 0.45, 1.0)
	st.fx.burst(pl.pos, 0.5, Color(1.0, 0.9, 0.55), 14, r * 2.0, 0.3, 0.0)
	st.fx.flash_light(pl.pos, 0.8, Color(1.0, 0.6, 0.3), 5.0, r * 2.4, 0.4)
	st.fx.shake(0.3)
	Audio.play("flare", 0.0)
	for a in st.in_circle(pl.team, pl.pos, r):
		var h := _hit(pl, d.damage, ["fire"])
		h.burn = 2
		h.knockback = (a.pos - pl.pos).normalized() * (12.0 if bellows else 7.0)
		h.from_dir = (a.pos - pl.pos).normalized()
		h.poise = 25.0
		pl.deal_hit(a, h)
	if pl.stats.has("flare_ground"):
		var hz := Hazard.spawn(st, pl.pos, r * 0.75, 3.0, pl.team, Color(1.0, 0.5, 0.2), func(_hz: Hazard, a: Actor) -> void:
			var h := _hit(pl, 5.0, ["fire", "dot"])
			h.burn = 1
			h.can_crit = false
			h.silent = true
			pl.deal_hit(a, h))
		hz.period = 0.5
		hz.particle_rate = 14.0
	return true


static func _lance(pl: Player) -> bool:
	var d := GearDB.ability("cinder_lance")
	var dirs: Array = [pl.aim]
	if pl.stats.has("splinter_lance"):
		dirs = [pl.aim.rotated(-0.22), pl.aim, pl.aim.rotated(0.22)]
	for dir: Vector2 in dirs:
		var pr := Projectile.create(pl.stage, "proj_lance", pl.pos + dir * 0.5, dir * 24.0, pl.team)
		pr.source = pl
		pr.damage = d.damage
		pr.tags = ["ability", "fire"]
		pr.pierce = 99
		pr.radius = 0.4
		pr.life = d.range / 24.0
		pr.height = 0.6
		pr.burn = 1
		pr.knockback = 3.0
		pr.spin = true
		pr.reflectable = false
		pr.trail_color = Color(1.0, 0.55, 0.2)
		pr.trail_rate = 90.0
		pr.with_light(Color(1.0, 0.55, 0.2), 1.4, 3.0)
		pr.make_hit_fn = func(proj: Projectile, _t: Actor) -> Hit:
			var h := _hit(pl, proj.damage, ["fire"])
			h.burn = 1
			h.knockback = proj.vel.normalized() * 3.0
			h.from_dir = proj.vel.normalized()
			h.poise = 18.0
			return h
	pl.stage.fx.burst(pl.pos + pl.aim * 0.6, 0.6, Color(1.0, 0.7, 0.3), 10, 5.0, 0.25, 0.0, pl.aim, 0.4)
	pl.stage.fx.shake(0.15)
	Audio.play("lance", 0.0)
	return true


static func _sigil(pl: Player) -> bool:
	var d := GearDB.ability("frost_sigil")
	var big := pl.stats.has("glacier_seal")
	var r: float = d.radius * (1.25 if big else 1.0) * pl.stats.v("area")
	var target := pl.pos + (pl.aim_point - pl.pos).limit_length(8.0)
	if pl.stage.grid.at(floori(target.x), floori(target.y)) != TileGrid.FLOOR:
		target = pl.pos + pl.aim * 2.0
	var pulses := 5 if big else 3
	var st := pl.stage
	var sig := st.fx.shape(Fx.Shape.SIGIL, target, Vector2.RIGHT, Vector2(r * 2, r * 2), Color(0.5, 0.8, 1.0, 0.5), Color(0.75, 0.92, 1.0, 1.0), pulses * 0.6 + 0.3, {"glow": 1.6})
	var data_t := [0.0]
	var sig_ref: WeakRef = weakref(sig)
	var hz := Hazard.spawn(st, target, r, pulses * 0.6 + 0.05, pl.team, Color(0.6, 0.85, 1.0), Callable())
	hz.period = 0.6
	hz.particle_rate = 10.0
	hz.on_pulse = func(h: Hazard) -> void:
		data_t[0] += 1.0
		var sn = sig_ref.get_ref()
		if sn != null:
			sn.set_instance_shader_parameter("progress", data_t[0] / pulses)
		st.fx.ring(h.pos, r, Color(0.6, 0.85, 1.0), 0.3, 0.2)
		st.fx.burst(h.pos, 0.2, Color(0.75, 0.92, 1.0), 12, 4.0, 0.4, 2.0)
		Audio.play("frost", -3.0, 1.0 + data_t[0] * 0.05)
		for a in st.in_circle(pl.team, h.pos, r):
			var hit := _hit(pl, d.damage, ["frost"])
			hit.chill = 0.4
			hit.poise = 8.0
			pl.deal_hit(a, hit)
	Audio.play("sigil", 0.0)
	return true


static func _gloamstep(pl: Player) -> bool:
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
	shade(pl, from, d.damage, 0.45, twice)
	return true


## A shadow afterimage that detonates after `delay`.
static func shade(pl: Player, p: Vector2, dmg: float, delay: float, twice := false) -> void:
	var st := pl.stage
	var mark := st.fx.shape(Fx.Shape.DISC, p, Vector2.RIGHT, Vector2(4.0, 4.0), Color(0.55, 0.3, 0.75, 0.15), Color(0.75, 0.5, 0.95, 0.55), delay + 0.05, {"glow": 1.1})
	var mark_t := [0.0]
	st.after(delay * 0.5, func() -> void:
		if is_instance_valid(mark):
			mark.set_instance_shader_parameter("progress", 0.6))
	var boom := func() -> void:
		if not is_instance_valid(pl) or not is_instance_valid(st):
			return
		st.fx.ring(p, 2.0, Color(0.7, 0.45, 0.95), 0.25, 0.3)
		st.fx.burst(p, 0.5, Color(0.65, 0.4, 0.9), 18, 5.0, 0.4, 1.0)
		st.fx.flash_light(p, 0.6, Color(0.6, 0.35, 0.9), 2.5, 4.0, 0.25)
		Audio.play("shade", -2.0)
		for a in st.in_circle(pl.team, p, 2.0):
			var h := _hit(pl, dmg, ["shadow"])
			h.knockback = (a.pos - p).normalized() * 5.0
			h.from_dir = (a.pos - p).normalized()
			h.poise = 15.0
			pl.deal_hit(a, h)
	mark_t[0] = 0.0
	st.after(delay, boom)
	if twice:
		st.after(delay + 0.35, boom)


static func _aegis(pl: Player) -> bool:
	var d := GearDB.ability("aegis")
	pl.aegis_hp = d.absorb
	pl.aegis_t = d.duration
	pl.stage.fx.ring(pl.pos, 1.4, Color(1.0, 0.85, 0.45), 0.3, 0.3)
	pl.stage.fx.burst(pl.pos, 0.8, Color(1.0, 0.85, 0.5), 16, 3.0, 0.4, 0.0)
	Audio.play("aegis", 0.0)
	return true


static func _wisp(pl: Player) -> bool:
	var d := GearDB.ability("wisp")
	var n := 2 if pl.stats.has("twin_wisps") else 1
	var dur: float = d.duration * (1.5 if pl.stats.has("long_wisps") else 1.0)
	for i in n:
		var w := Wisp.new()
		w.owner_player = pl
		w.duration = dur
		w.damage = d.damage * (1.3 if pl.stats.has("twin_wisps") else 1.0)
		w.orbit_phase = float(i) * PI
		w.pos = pl.pos + Vector2.from_angle(w.orbit_phase) * 1.2
		pl.stage.add_actor(w)
	pl.stage.fx.burst(pl.pos, 1.0, Color(1.0, 0.85, 0.45), 20, 3.0, 0.6, -1.0)
	Audio.play("wisp", 0.0)
	return true
