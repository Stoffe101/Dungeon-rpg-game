## Grave Bloat: waddles toward you and bursts. The blast hurts everything -
## including other enemies. Kill it among its friends, or knock it into them.
extends Enemy

const BLAST_R := 2.4
var fused := false
var exploded := false


func behave(dt: float) -> void:
	match state:
		"idle":
			set_state("chase")
		"chase":
			chase(speed, dt)
			sprite.play("walk")
			if dist_to_player() < 1.7:
				_fuse(0.9)
		"fuse":
			vel = Vector2.ZERO
			if state_t > 0.0 and randf() < 0.4:
				stage.fx.motes(pos, 0.8, Color(0.75, 0.85, 0.35), 1, 1.0, 0.4, 0.3)
		_:
			set_state("chase")


func _fuse(t: float) -> void:
	if fused:
		return
	fused = true
	set_state("fuse")
	sprite.play("swell")
	Audio.play("bloat", -4.0)
	telegraph(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(BLAST_R * 2, BLAST_R * 2), t)
	var st := stage
	var me: WeakRef = weakref(self)
	st.after(t, func() -> void:
		var b = me.get_ref()
		if b != null and b.alive:
			b._explode())


func die(killer: Node) -> void:
	if not alive:
		return
	if not exploded:
		# killing it doesn't defuse it: the corpse still pops a moment later
		exploded = true
		stage.fx.shape(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(BLAST_R * 2, BLAST_R * 2), TELE_COLOR, TELE_EDGE, 0.5, {"progress": 0.5})
		_blast_later(stage, pos, damage, 0.45)
	super.die(killer)


func _explode() -> void:
	if not alive or exploded:
		return
	exploded = true
	_blast(stage, pos, damage, self)
	hp = 0.0
	super.die(null)


## Static so the delayed callback is not bound to this (soon freed) instance.
static func _blast_later(st: Stage, p: Vector2, dmg: float, delay: float) -> void:
	st.after(delay, func() -> void: _blast(st, p, dmg, null))


static func _blast(st: Stage, p: Vector2, dmg: float, self_ref: Node) -> void:
	st.fx.ring(p, BLAST_R, Color(0.7, 0.85, 0.3), 0.3, 0.35)
	st.fx.burst(p, 0.5, Color(0.6, 0.75, 0.3), 26, 6.0, 0.6, 4.0)
	st.fx.burst(p, 0.5, Color(0.35, 0.4, 0.25), 12, 2.5, 1.0, -1.0)
	st.fx.shake(0.35)
	Audio.play("explode", -2.0, 0.85)
	var pl := st.player
	if pl and pl.alive and pl.pos.distance_to(p) <= BLAST_R + pl.radius:
		var h := Hit.make(self_ref, dmg, ["fire"])
		h.can_crit = false
		h.knockback = (pl.pos - p).normalized() * 8.0
		h.from_dir = (pl.pos - p).normalized()
		pl.take_enemy_hit(h, null)
	for a in st.in_circle(Actor.Team.PLAYER, p, BLAST_R):
		if a == self_ref:
			continue
		var h2 := Hit.make(pl, 30.0, ["fire"])
		h2.can_crit = false
		h2.knockback = (a.pos - p).normalized() * 7.0
		h2.from_dir = (a.pos - p).normalized()
		a.take_hit(h2)


func hit_color() -> Color:
	return Color(0.6, 0.72, 0.35)
