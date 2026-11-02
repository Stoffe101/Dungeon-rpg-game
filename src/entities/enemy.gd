## Base enemy: stats from EnemyDB, a tiny state machine, readable telegraphed
## attacks, elite affixes, Grudges (nemeses), drops and a floating health bar.
class_name Enemy
extends Actor

signal died_enemy(e: Enemy)

const TELE_COLOR := Color(1.0, 0.2, 0.35, 0.55)
const TELE_EDGE := Color(1.0, 0.45, 0.5, 1.0)

var id := ""
var def: Dictionary = {}
var elite := false
var affix := ""
var grudge: Dictionary = {}
var state := "spawn"
var state_t := 0.0
var spawn_t := 0.7
var speed := 2.5
var damage := 10.0
var attack_rate := 1.0
var xp := 5
var embers := 2
var room_id := -1
var shield := 0.0
var shield_max := 0.0
var bar: Control
var nameplate: Label
var tele: MeshInstance3D
var aim_dir := Vector2.RIGHT
var _phase_t := 0.0
var _hb_show_t := 0.0
var _strafe_sign := 1.0
var _repath_t := 0.0
var _goal := Vector2.ZERO
## Pixels from the top of the sprite frame down to where the health bar sits.
var bar_offset := 4.0
var _wildfire_t := 0.0


func configure(enemy_id: String) -> Enemy:
	id = enemy_id
	def = EnemyDB.get_def(enemy_id)
	display_name = def.name
	max_hp = def.hp
	hp = max_hp
	speed = def.speed
	radius = def.radius
	max_poise = def.poise
	poise = max_poise
	damage = def.damage
	xp = int(def.xp)
	embers = int(def.embers)
	armor = def.get("armor", 0.0)
	mass = 1.0 + radius * 2.0
	_strafe_sign = 1.0 if randf() > 0.5 else -1.0
	return self


## Scales the enemy for depth and memory (the Undervault adapts).
func scale_for(depth: int, memory: int) -> void:
	var m := 1.0 + 0.22 * float(depth - 1) + 0.12 * float(memory)
	max_hp *= m
	hp = max_hp
	damage *= 1.0 + 0.12 * float(depth - 1) + 0.08 * float(memory)


func make_elite(a: String) -> void:
	elite = true
	affix = a
	max_hp *= 2.3
	hp = max_hp
	max_poise *= 1.6
	poise = max_poise
	xp *= 3
	embers *= 3
	match a:
		"hasted":
			speed *= 1.4
			attack_rate = 1.4
		"warded":
			shield_max = max_hp * 0.45
			shield = shield_max


func make_grudge(g: Dictionary) -> void:
	grudge = g
	if not elite:
		make_elite(String(g.get("affix", "hasted")))
	var lvl := int(g.get("level", 1))
	max_hp *= 1.0 + 0.3 * lvl
	hp = max_hp
	damage *= 1.0 + 0.12 * lvl
	display_name = String(g.get("name", display_name))


func _ready() -> void:
	team = Team.ENEMY
	build_visual(def.sheet, "idle")
	sprite.set_dissolve(1.0)
	if elite or not grudge.is_empty():
		_make_nameplate()
	state = "spawn"
	state_t = 0.0


func hit_color() -> Color:
	return Color(0.88, 0.84, 0.74)


func target() -> Player:
	return stage.player if stage.player and stage.player.alive else null


func set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
		tele = null


func tick(dt: float) -> void:
	if state == "spawn":
		state_t += dt
		var k := clampf(state_t / spawn_t, 0.0, 1.0)
		sprite.set_dissolve(1.0 - k)
		if randf() < 0.5:
			stage.fx.motes(pos, 0.0, Color(0.35, 0.95, 0.85), 1, 2.0, 0.6, radius)
		if k >= 1.0:
			set_state("idle")
		sync_visual()
		return
	if affix == "phasing":
		_phase_t += dt
		var cyc := fmod(_phase_t, 4.5)
		var phased := cyc > 3.4
		targetable = not phased
		sprite.set_tint(Color(1, 1, 1, 0.35 if phased else 1.0))
	super.tick(dt)
	_update_bar(dt)
	_wildfire(dt)


## Wildfire (Pyre notable): burning foes pass their flames to a neighbour.
func _wildfire(dt: float) -> void:
	if not alive or not status.burning():
		_wildfire_t = 0.0
		return
	var pl := stage.player
	if pl == null or not pl.stats.has("wildfire"):
		return
	_wildfire_t += dt
	if _wildfire_t < 1.5:
		return
	_wildfire_t = 0.0
	var best: Actor = null
	var bd := 3.2
	for a in stage.hostiles(Team.PLAYER):
		if a == self or a.status.burning():
			continue
		var d := a.pos.distance_to(pos)
		if d < bd:
			bd = d
			best = a
	if best:
		best.status.apply_burn(1, status.burn_dps_per_stack, int(pl.stats.v("burn_stacks")), pl)
		for i in 6:
			stage.fx.burst(pos.lerp(best.pos, i / 6.0), 0.6, Color(1.0, 0.55, 0.2), 1, 0.6, 0.3, 0.0)


func think(dt: float) -> void:
	state_t += dt
	if not status.can_act():
		vel = Vector2.ZERO
		if tele and is_instance_valid(tele):
			stage.fx.release(tele)
			tele = null
		if state != "stunned":
			state = "stunned"
			state_t = 0.0
		sprite.speed_scale = 0.0
		return
	sprite.speed_scale = attack_rate
	if state == "stunned":
		set_state("idle")
	behave(dt)


## Override per enemy type.
func behave(_dt: float) -> void:
	pass


# --- movement helpers --------------------------------------------------------

func move_toward_point(p: Vector2, spd: float, dt: float) -> void:
	_repath_t -= dt
	if _repath_t <= 0.0:
		_repath_t = 0.25
		_goal = stage.path_step(pos, p)
	var d := _goal - pos
	if d.length() < 0.15:
		_repath_t = 0.0
	vel = d.normalized() * spd if d.length() > 0.05 else Vector2.ZERO
	if vel.length() > 0.1:
		facing = vel.normalized()


func chase(spd: float, dt: float) -> void:
	var t := target()
	if t == null:
		vel = Vector2.ZERO
		return
	move_toward_point(t.pos, spd, dt)


## Keeps a preferred distance band from the player, strafing sideways.
func kite(min_d: float, max_d: float, spd: float, dt: float) -> void:
	var t := target()
	if t == null:
		vel = Vector2.ZERO
		return
	var to := t.pos - pos
	var d := to.length()
	var los := stage.grid.line_clear(pos, t.pos)
	if d > max_d or not los:
		move_toward_point(t.pos, spd, dt)
	elif d < min_d:
		var away := pos - to.normalized() * 2.0
		vel = (away - pos).normalized() * spd
		if stage.grid.box_blocked(pos + vel.normalized() * 0.6, box()):
			vel = to.normalized().orthogonal() * spd * _strafe_sign
	else:
		vel = to.normalized().orthogonal() * spd * 0.6 * _strafe_sign
		if stage.grid.box_blocked(pos + vel.normalized() * 0.6, box()) or randf() < dt * 0.4:
			_strafe_sign *= -1.0
	facing = to.normalized()


func dist_to_player() -> float:
	var t := target()
	return t.pos.distance_to(pos) if t else 999.0


func dir_to_player() -> Vector2:
	var t := target()
	return (t.pos - pos).normalized() if t else facing


# --- attacks --------------------------------------------------------------------

func telegraph(kind: int, center: Vector2, dir: Vector2, size: Vector2, duration: float, params := {}) -> void:
	var p := params.duplicate()
	p["progress"] = 0.0
	tele = stage.fx.shape(kind, center, dir, size, TELE_COLOR, TELE_EDGE, duration + 0.05, p)
	var dur := duration
	var start := stage.elapsed
	var st := stage
	var data: Dictionary = stage.fx._shapes[stage.fx._shapes.size() - 1]
	data.update = func(_t: float, n: MeshInstance3D) -> void:
		var k := clampf((st.elapsed - start) / maxf(dur, 0.01), 0.0, 1.0)
		n.set_instance_shader_parameter("progress", k)


func make_hit(amount: float, from: Vector2, kb := 5.0) -> Hit:
	var h := Hit.make(self, amount, ["melee"])
	h.can_crit = false
	var d := (stage.player.pos - from).normalized() if stage.player else Vector2.RIGHT
	h.knockback = d * kb
	h.from_dir = d
	return h


func strike_circle(center: Vector2, r: float, amount: float, kb := 5.0) -> bool:
	var t := target()
	if t and t.pos.distance_to(center) <= r + t.radius:
		t.take_enemy_hit(make_hit(amount, center, kb), self)
		return true
	return false


func strike_arc(origin: Vector2, dir: Vector2, r: float, half: float, amount: float, kb := 5.0) -> bool:
	var t := target()
	if t == null:
		return false
	var to := t.pos - origin
	if to.length() > r + t.radius:
		return false
	if to.length() > 0.5 and absf(dir.angle_to(to)) > half + 0.15:
		return false
	t.take_enemy_hit(make_hit(amount, origin, kb), self)
	return true


func strike_line(origin: Vector2, dir: Vector2, length: float, width: float, amount: float, kb := 5.0) -> bool:
	var t := target()
	if t == null:
		return false
	var q := Geometry2D.get_closest_point_to_segment(t.pos, origin, origin + dir * length)
	if q.distance_to(t.pos) <= width * 0.5 + t.radius:
		t.take_enemy_hit(make_hit(amount, origin, kb), self)
		return true
	return false


func shoot(sheet: String, dir: Vector2, spd: float, amount: float, rad := 0.22) -> Projectile:
	var pr := Projectile.create(stage, sheet, pos + dir * 0.5, dir * spd, team)
	pr.source = self
	pr.damage = amount
	pr.radius = rad
	pr.height = 0.7
	pr.tags = ["ranged"]
	pr.spin = true
	pr.life = 3.0
	pr.trail_color = Color(0.4, 0.95, 0.85)
	pr.trail_rate = 20.0
	pr.with_light(Color(0.35, 0.95, 0.85), 0.6, 2.0)
	return pr


func timer(len: float) -> bool:
	return state_t >= len / attack_rate


# --- damage / death ---------------------------------------------------------------

func block_mult(h: Hit) -> float:
	if shield > 0.0 and not h.has_tag("dot"):
		var absorbed := minf(shield, h.amount)
		shield -= absorbed
		stage.fx.burst(pos, 0.9, Color(0.45, 0.8, 1.0), 4, 2.5, 0.3, 0.0)
		if shield <= 0.0:
			stage.fx.number(pos, 2.6, "WARD BROKEN", Color(0.5, 0.85, 1.0))
			stage.fx.ring(pos, 1.4, Color(0.5, 0.85, 1.0), 0.3, 0.3)
			on_poise_break(h)
		return clampf(1.0 - absorbed / maxf(h.amount, 0.01), 0.0, 1.0) if h.amount > 0.0 else 1.0
	return 1.0


func on_damaged(hit: Hit, res: Combat.Result) -> void:
	super.on_damaged(hit, res)
	_hb_show_t = 3.0
	if state == "idle" or state == "wander":
		set_state("idle")


func die(killer: Node) -> void:
	if not alive:
		return
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	var pl := stage.player
	var by_player := killer is Player or (killer is Actor and (killer as Actor).team == Team.PLAYER) or hit_by_player
	super.die(killer)
	if bar:
		bar.queue_free()
	if nameplate:
		nameplate.queue_free()
	died_enemy.emit(self)
	Audio.play("enemy_die", -3.0, randf_range(0.9, 1.1))
	stage.fx.burst(pos, 0.6, hit_color(), 12, 4.0, 0.6, 9.0)
	stage.fx.motes(pos, 0.3, Color(0.35, 0.95, 0.85), 6, 1.5, 0.9, 0.3)
	if pl and by_player:
		var st := pl.stats
		if st.v("life_on_kill") > 0.0:
			pl.heal(st.v("life_on_kill"))
		if st.v("kindle_on_kill") > 0.0:
			pl.gain_kindle(st.v("kindle_on_kill") / maxf(st.v("kindle_gain"), 0.01))
		if st.has("combustion") and status.burning():
			_combust(pl)
		if st.has("shatter") and status.is_frozen():
			_shatter(pl)
	if affix == "volatile":
		_volatile_burst()


func _combust(pl: Player) -> void:
	var p := pos
	var stacks := status.burn_stacks
	stage.fx.ring(p, 2.4, Color(1.0, 0.55, 0.2), 0.25, 0.35)
	stage.fx.burst(p, 0.5, Color(1.0, 0.6, 0.2), 22, 6.0, 0.45, 2.0)
	stage.fx.flash_light(p, 0.6, Color(1.0, 0.55, 0.2), 3.0, 5.0, 0.3)
	Audio.play("explode", -3.0, 1.15)
	for a in stage.in_circle(Team.PLAYER, p, 2.4):
		var h := Combat.player_hit(pl, pl.stats, 14.0 + 6.0 * stacks, ["fire"])
		h.burn = maxi(1, stacks - 1)
		h.proc = false
		h.knockback = (a.pos - p).normalized() * 5.0
		pl.deal_hit(a, h)


func _shatter(pl: Player) -> void:
	var p := pos
	stage.fx.burst(p, 0.7, Color(0.75, 0.92, 1.0), 26, 6.0, 0.5, 9.0)
	stage.fx.ring(p, 2.4, Color(0.7, 0.9, 1.0), 0.25, 0.3)
	Audio.play("shatter", -2.0)
	for a in stage.in_circle(Team.PLAYER, p, 2.4):
		var h := Combat.player_hit(pl, pl.stats, 18.0, ["frost"])
		h.chill = 0.6
		h.proc = false
		pl.deal_hit(a, h)


func _volatile_burst() -> void:
	_volatile_later(stage, pos, damage * 1.6)


## Static so the delayed blast survives this enemy being freed.
static func _volatile_later(st: Stage, p: Vector2, dmg: float) -> void:
	st.fx.shape(Fx.Shape.DISC, p, Vector2.RIGHT, Vector2(5, 5), TELE_COLOR, TELE_EDGE, 0.75, {"progress": 0.0})
	st.after(0.7, func() -> void:
		st.fx.ring(p, 2.5, Color(1.0, 0.5, 0.2), 0.3, 0.35)
		st.fx.burst(p, 0.5, Color(1.0, 0.55, 0.2), 24, 6.0, 0.45, 2.0)
		Audio.play("explode", -2.0)
		var pl := st.player
		if pl and pl.alive and pl.pos.distance_to(p) < 2.5 + pl.radius:
			var h := Hit.make(null, dmg, ["fire"])
			h.can_crit = false
			h.knockback = (pl.pos - p).normalized() * 7.0
			pl.take_enemy_hit(h, null))


# --- overlay UI ----------------------------------------------------------------------

func _make_nameplate() -> void:
	if stage.view == null:
		return
	nameplate = Label.new()
	nameplate.add_theme_font_override("font", Fx.FONT_OUTLINE)
	nameplate.add_theme_font_size_override("font_size", 8)
	var col: Color = EnemyDB.AFFIXES.get(affix, {}).get("color", Color(1, 0.8, 0.4))
	if not grudge.is_empty():
		col = Color(1.0, 0.45, 0.35)
		nameplate.text = "%s  Lv%d" % [display_name, int(grudge.get("level", 1))]
	else:
		nameplate.text = "%s %s" % [EnemyDB.AFFIXES[affix].name, display_name]
	nameplate.add_theme_color_override("font_color", col)
	stage.view.overlay.add_child(nameplate)


func _update_bar(dt: float) -> void:
	_hb_show_t -= dt
	if stage.view == null:
		return
	var show: bool = ((_hb_show_t > 0.0 or elite) and alive and hp < max_hp or shield > 0.0 or not grudge.is_empty()) and not def.get("boss", false)
	if show and bar == null:
		bar = _HealthBar.new()
		stage.view.overlay.add_child(bar)
	if bar:
		bar.visible = show
	var feet := stage.view.world_to_internal(global_position)
	var top := feet.y - float(sprite.sheet.origin.y) + bar_offset
	if bar and show:
		var w := 16 if not elite else 24
		bar.position = Vector2(roundf(feet.x - w * 0.5), roundf(top))
		bar.set_values(hp_ratio(), shield / maxf(shield_max, 1.0) if shield_max > 0.0 else 0.0, w)
	if nameplate:
		var sz := nameplate.get_minimum_size()
		nameplate.position = Vector2(roundf(feet.x - sz.x * 0.5), roundf(top - sz.y - 1.0))


class _HealthBar:
	extends Control
	var ratio := 1.0
	var shield_ratio := 0.0
	var w := 16

	func set_values(r: float, s: float, width: int) -> void:
		ratio = r
		shield_ratio = s
		w = width
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-1, -1, w + 2, 4), Color(0.04, 0.03, 0.06))
		draw_rect(Rect2(0, 0, w, 2), Color(0.25, 0.08, 0.1))
		draw_rect(Rect2(0, 0, roundf(w * ratio), 2), Color(0.86, 0.25, 0.28))
		if shield_ratio > 0.0:
			draw_rect(Rect2(0, 0, roundf(w * shield_ratio), 1), Color(0.5, 0.85, 1.0))
