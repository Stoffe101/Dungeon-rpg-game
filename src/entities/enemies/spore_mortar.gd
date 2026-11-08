## Spore Mortar: a rooted bulb that coughs spore bombs high into the air; each
## lands where its mark glows and leaves a choking cloud. It cannot move -
## close the distance, or keep the marks in sight and step out of them.
extends Enemy

const BLAST_R := 1.35
var cooldown := 2.2


func _ready() -> void:
	super._ready()
	anchored = true


func behave(dt: float) -> void:
	vel = Vector2.ZERO
	cooldown -= dt * attack_rate
	match state:
		"idle":
			sprite.play("idle")
			var t := target()
			if t and cooldown <= 0.0 and dist_to_player() < 14.0 and may_strike("ranged"):
				set_state("charge")
				sprite.play("charge")
				Audio.play_at("bloat", pos, -8.0, 1.4)
		"charge":
			if timer(0.55):
				sprite.play("fire")
				_volley()
				cooldown = randf_range(2.6, 3.4)
				set_state("recover")
		"recover":
			if timer(0.5):
				set_state("idle")
		_:
			set_state("idle")


func _volley() -> void:
	var t := target()
	if t == null:
		return
	var n := 3 if elite else 2
	var lead := t.vel * 0.7
	for k in n:
		var at := stage.random_floor_near(t.pos + lead + Vector2.from_angle(randf() * TAU) * (0.0 if k == 0 else 1.8), 0.3)
		var flight := 1.05 + k * 0.12
		stage.fx.shape(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(BLAST_R * 2.0, BLAST_R * 2.0), TELE_COLOR, TELE_EDGE, flight + 0.05, {"progress": 0.0})
		var pr := Projectile.create(stage, "proj_spore", pos + Vector2(0, -0.3), (at - pos) / flight, team)
		pr.source = self
		pr.damage = 0.0
		pr.lob(flight, 3.2)
		pr.reflectable = false
		var me: WeakRef = weakref(self)
		var st := stage
		var dmg := damage
		pr.on_end_fn = func(_p: Projectile, land: Vector2) -> void:
			_burst(st, land, dmg, me)
	Audio.play_at("orb", pos, -2.0, 0.6)
	voice("attack", -8.0)


static func _burst(st: Stage, at: Vector2, dmg: float, me: WeakRef) -> void:
	for pl in st.players_near(at, BLAST_R):
		var h := Hit.make(me.get_ref() as Node, dmg, ["ranged"])
		h.can_crit = false
		h.knockback = (pl.pos - at).normalized() * 4.0
		h.from_dir = (pl.pos - at).normalized()
		pl.take_enemy_hit(h, me.get_ref())
	st.fx.burst(at, 0.2, Color(0.55, 0.8, 0.35), 18, 4.5, 0.5, 3.0)
	st.fx.ring(at, BLAST_R, Color(0.6, 0.95, 0.4), 0.25, 0.25)
	st.fx.splat(at, Color(0.22, 0.3, 0.14), 10.0, 1.0)
	Audio.play_at("explode", at, -8.0, 1.5)
	var hz := Hazard.spawn(st, at, 1.1, 2.6, Actor.Team.ENEMY, Color(0.5, 0.75, 0.3), func(_h: Hazard, a: Actor) -> void:
		if a is Player:
			var dh := Hit.make(null, 3.0, ["dot", "spore"])
			dh.can_crit = false
			(a as Player).take_enemy_hit(dh, null))
	hz.period = 0.5
	hz.particle_rate = 10.0


func hit_color() -> Color:
	return Color(0.55, 0.75, 0.4)
