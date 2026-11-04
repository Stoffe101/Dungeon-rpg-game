## Ashwood Staff: tap to loose ember bolts; hold to gather a fireball that
## bursts on impact.
## Forms (ItemDB "form"):
##   rime (Rimewood Staff) - its bolts are frost shards that shatter into three
##     splinters where they strike; hold for a Frost Lance: a line of cold
##     straight out, freezing the already chilled, frost left along it.
##   branch (Splitbranch Staff) - its bolts fork on the first foe they strike;
##     its fireball bursts and scatters five embers that burst again.
extends Weapon

var _cool := 0.0
var _embers := 0              # the Wand of a Hundred Embers counts every one


func _init() -> void:
	charge_time = 0.7


func max_combo() -> int:
	return 1


func move_mult() -> float:
	if phase == Phase.CHARGE:
		return 0.55
	if phase != Phase.IDLE:
		return 0.8
	return 1.0


func update(dt: float) -> void:
	_cool = maxf(0.0, _cool - dt)
	super.update(dt)
	swing = 0.0


func begin_combo() -> void:
	start_strike(0)


func start_strike(_i: int) -> void:
	if _cool > 0.0:
		buffered = true
		strike = {"recover": _cool}
		_set_phase(Phase.RECOVER, _cool)
		return
	strike = {"windup": 0.02, "active": 0.02, "recover": 0.16}
	aim_dir = player.aim
	_set_phase(Phase.WINDUP, 0.02)
	player.on_attack_start()


func on_active() -> void:
	_cool = 0.18 / speed()
	var spread := deg_to_rad(randf_range(-4.0, 4.0))
	var d0 := aim_dir.rotated(spread)
	var group := {}
	for d: Vector2 in Volley.directions(player, d0, 1, 0.14):
		_bolt(d, group)
	Audio.play("bolt", -4.0, randf_range(0.92, 1.1))
	player.stage.fx.burst(player.pos + d0 * 0.6, 0.6, Color(1.0, 0.75, 0.4), 3, 3.0, 0.15, 0.0, d0, 0.5)
	player.on_weapon_strike(0, false)


## The Hundredth Ember: a great one falls at the cursor and bursts.
func _hundredth() -> void:
	var st := player.stage
	var at := player.pos + (player.aim_point - player.pos).limit_length(8.0)
	var col := Color(1.0, 0.6, 0.22)
	st.fx.number(at, 2.8, "THE HUNDREDTH EMBER", Color(1.0, 0.85, 0.5), true)
	st.fx.shape(Fx.Shape.SIGIL, at, Vector2.RIGHT, Vector2(5.6, 5.6), Color(1.0, 0.5, 0.2, 0.25), Color(1.0, 0.75, 0.4, 1.0), 0.6, {"glow": 1.6})
	var pr := shoot("proj_fireball", at + Vector2(0, -0.1), Vector2.ZERO, 0.0, def.charged * 1.4, ["ranged", "fire"], 0.55)
	pr.height = 6.0
	pr.lob(0.55, 0.0)
	pr.with_light(col, 2.0, 5.0)
	pr.on_end_fn = func(proj: Projectile, p: Vector2) -> void:
		var r := 2.8 * player.stats.v("area")
		st.fx.ring(p, r, col, 0.35, 0.45)
		st.fx.burst(p, 0.4, col, 40, 8.0, 0.55, 3.0)
		st.fx.flash_light(p, 0.8, col, 5.0, 9.0, 0.5)
		st.fx.shake(0.45)
		Audio.play("explode", 2.0, 0.75)
		st.strike_props_circle(p, r, player, true)
		for a in st.in_circle(player.team, p, r):
			var h := Combat.player_hit(player, player.stats, proj.damage, ["ranged", "fire"])
			h.burn = 3
			h.knockback = (a.pos - p).normalized() * 9.0
			h.poise = 45.0
			player.deal_hit(a, h, true)


## One ember bolt of a volley.
func _bolt(d: Vector2, group: Dictionary) -> void:
	if form == "hundred":
		_embers += 2 if player.hearthfire_t > 0.0 and player.stats.has("hearthforged") and _embers % 100 != 99 else 1
		player.form_meter = float(_embers % 100) / 100.0
		if _embers % 100 == 0:
			_hundredth()
	if form == "rime":
		_shard(d, group)
		return
	var pr := Projectile.create(player.stage, "proj_ember", player.pos + d * 0.5, d * 15.0 * player.stats.v("projectile_speed"), player.team)
	pr.source = player
	pr.damage = def.damage[0] * damage_scale()
	pr.tags = ["ranged", "fire"]
	pr.pierce = 1 if tempered() else 0
	pr.radius = 0.22
	pr.life = 0.9
	pr.height = 0.6
	pr.knockback = 1.5
	pr.trail_color = Color(1.0, 0.6, 0.25)
	pr.trail_rate = 30.0
	pr.reflectable = false
	pr.spin = true
	pr.on_hit_fn = func(proj: Projectile, target: Actor, _res) -> void:
		player.gain_kindle(2.5)
		if player.stats.has("forked_ember") and not proj.tags.has("forked"):
			_fork(proj, target)
	pr.with_light(Color(1.0, 0.55, 0.25), 0.7, 2.2)
	Volley.shape(pr, player, group)
	if form == "branch":
		pr.fork = maxi(pr.fork, 1)     # every bolt forks on its first foe


## Rimewood: a shard of frost that shatters into splinters where it strikes.
func _shard(d: Vector2, group: Dictionary) -> void:
	var pr := shoot("proj_shard", player.pos + d * 0.5, d, 14.0 * player.stats.v("projectile_speed"), def.damage[0] * 1.05, ["ranged", "frost"], 0.9)
	pr.chill = 0.3
	pr.pierce = 1 if tempered() else 0
	pr.radius = 0.22
	pr.height = 0.6
	pr.knockback = 1.2
	pr.trail_color = Color(0.7, 0.9, 1.0)
	pr.trail_rate = 26.0
	pr.with_light(Color(0.6, 0.85, 1.0), 0.6, 2.2)
	pr.on_hit_fn = func(_proj: Projectile, _t: Actor, _res) -> void:
		player.gain_kindle(2.5)
	pr.on_end_fn = func(proj: Projectile, at: Vector2) -> void:
		_shatter(at, proj.vel.normalized(), proj.hit_set)
	Volley.shape(pr, player, group)


func _shatter(at: Vector2, d: Vector2, struck: Dictionary) -> void:
	if d.length() < 0.1:
		d = aim_dir
	player.stage.fx.burst(at, 0.6, Color(0.8, 0.95, 1.0), 8, 3.5, 0.25, 4.0)
	Audio.play_at("shatter_ice", at, -8.0, randf_range(1.0, 1.15))
	for s in [-0.45, 0.0, 0.45]:
		var sp := shoot("proj_splinter", at, d.rotated(s), 12.0, def.damage[0] * 0.38, ["ranged", "frost"], 0.26)
		sp.chill = 0.15
		sp.pierce = 1
		sp.radius = 0.16
		sp.height = 0.6
		sp.trail_color = Color(0.75, 0.92, 1.0)
		sp.trail_rate = 16.0
		for id in struck:
			sp.hit_set[id] = true


## Frost Lance: straight out, as far as the eye goes - the chilled freeze.
func _frost_lance() -> void:
	var from := player.pos + aim_dir * 0.4
	var to := from
	var reach := 7.5 * player.stats.v("area")
	var k := 0.0
	while k < reach:
		var p := from + aim_dir * (k + 0.25)
		if player.stage.grid.blocks_shot(floori(p.x), floori(p.y)):
			break
		to = p
		k += 0.25
	hit_ids.clear()
	var col := Color(0.65, 0.88, 1.0)
	player.stage.fx.shape(Fx.Shape.RECT, from, aim_dir, Vector2(from.distance_to(to), 0.7), Color(0.6, 0.85, 1.0, 0.0), Color(0.85, 0.97, 1.0, 1.0), 0.22, {"progress": 1.0, "glow": 2.0})
	player.stage.fx.burst(to, 0.6, col, 16, 5.0, 0.4, 2.0)
	player.stage.fx.flash_light(from.lerp(to, 0.5), 0.8, col, 3.0, 6.0, 0.3)
	player.stage.fx.shake(0.18)
	Audio.play("frost_lance", -1.0)
	var hits := line_hit(from, to, 0.7, def.charged * 0.9, ["ranged", "frost"], 3.0, 25.0, {"finisher": true, "each": func(a: Actor, h: Hit) -> void:
		h.chill = 1.0 if (a.status.chill > 0.0 or a.status.is_frozen()) else 0.45})
	var src := player
	var st := player.stage
	var steps := int(from.distance_to(to) / 1.4)
	for i in steps + 1:
		var p2: Vector2 = from.lerp(to, float(i) / maxf(1.0, steps))
		var hz := Hazard.spawn(st, p2, 0.75, 3.0, Actor.Team.PLAYER, col, func(_h: Hazard, a: Actor) -> void:
			if a.team != Actor.Team.PLAYER and is_instance_valid(src):
				a.status.apply_chill(0.2), true)
		hz.period = 0.5
		hz.particle_rate = 3.0
	player.on_weapon_strike(hits, true)


## Splitbranch: the fireball scatters five embers that burst again.
func _cluster(at: Vector2, dmg: float) -> void:
	var st := player.stage
	for k in 5:
		var d := Vector2.from_angle(k * TAU / 5.0 + randf() * 0.4)
		var b := shoot("proj_bomblet", at, d, 4.5, dmg * 0.32 / damage_scale(), ["ranged", "fire"], 0.5)
		b.lob(0.5, 1.0)
		b.radius = 0.2
		b.trail_color = Color(1.0, 0.6, 0.25)
		b.trail_rate = 20.0
		b.on_end_fn = func(proj: Projectile, p: Vector2) -> void:
			var r := 1.25 * player.stats.v("area")
			st.fx.ring(p, r, Color(1.0, 0.6, 0.25), 0.2, 0.25)
			st.fx.burst(p, 0.3, Color(1.0, 0.65, 0.3), 10, 4.0, 0.3, 2.0)
			Audio.play_at("explode", p, -8.0, 1.3)
			for a in st.in_circle(player.team, p, r):
				var h := Combat.player_hit(player, player.stats, proj.damage, ["ranged", "fire"])
				h.burn = 1
				h.knockback = (a.pos - p).normalized() * 4.0
				h.proc = false
				player.deal_hit(a, h)


func _fork(proj: Projectile, target: Actor) -> void:
	for s in [-0.5, 0.5]:
		var d := proj.vel.normalized().rotated(s)
		var f := Projectile.create(player.stage, "proj_ember", proj.pos, d * proj.vel.length(), player.team)
		f.source = player
		f.damage = proj.damage * 0.5
		f.tags = ["ranged", "fire", "forked"]
		f.life = 0.4
		f.spin = true
		f.trail_color = proj.trail_color
		f.trail_rate = 20.0
		f.reflectable = false
		f.hit_set[target.get_instance_id()] = true


func predict_charge() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"recover": 0.3}
	_set_phase(Phase.RECOVER, 0.3 / speed())


func release_charge() -> void:
	charged = false
	aim_dir = player.aim
	strike = {"recover": 0.3}
	_set_phase(Phase.RECOVER, 0.3 / speed())
	if form == "rime":
		_frost_lance()
		return
	var pr := Projectile.create(player.stage, "proj_fireball", player.pos + aim_dir * 0.6, aim_dir * 10.0, player.team)
	pr.source = player
	pr.damage = def.charged * damage_scale()
	pr.tags = ["ranged", "fire"]
	pr.radius = 0.35
	pr.life = 1.4
	pr.height = 0.7
	pr.burn = 2
	pr.trail_color = Color(1.0, 0.55, 0.2)
	pr.trail_rate = 60.0
	pr.reflectable = false
	pr.with_light(Color(1.0, 0.5, 0.2), 1.6, 4.0)
	pr.on_end_fn = func(proj: Projectile, at: Vector2) -> void:
		_explode(at, proj.damage)
	Audio.play("fireball", 0.0)
	player.on_weapon_strike(0, true)


func _explode(at: Vector2, dmg: float) -> void:
	var r := 2.2 * player.stats.v("area")
	player.stage.fx.ring(at, r, Color(1.0, 0.6, 0.25), 0.25, 0.35)
	player.stage.fx.burst(at, 0.4, Color(1.0, 0.65, 0.25), 24, 7.0, 0.45, 3.0)
	player.stage.fx.burst(at, 0.4, Color(0.4, 0.35, 0.35), 10, 3.0, 0.8, -1.0)
	player.stage.fx.flash_light(at, 0.6, Color(1.0, 0.55, 0.25), 4.0, 6.0, 0.35)
	player.stage.fx.shake(0.35)
	Audio.play("explode", 0.0)
	player.stage.strike_props_circle(at, r, player, true)
	for a in player.stage.in_circle(player.team, at, r):
		var h := Combat.player_hit(player, player.stats, dmg, ["ranged", "fire"])
		h.knockback = (a.pos - at).normalized() * 8.0
		h.from_dir = (a.pos - at).normalized()
		h.burn = 2
		h.poise = 30.0
		player.deal_hit(a, h)
	if form == "branch":
		_cluster(at, dmg)
	if masterwork():
		# a ring of ember bolts flies out of the burst
		for k in 8:
			var d := Vector2.RIGHT.rotated(k * TAU / 8.0)
			var pr := Projectile.create(player.stage, "proj_ember", at + d * 0.4, d * 11.0, player.team)
			pr.source = player
			pr.damage = dmg * 0.3
			pr.tags = ["ranged", "fire"]
			pr.life = 0.5
			pr.reflectable = false
