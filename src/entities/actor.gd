## Base for everything that fights: player, enemies, summons.
## Simulation state lives on the 2D plane (pos/vel in tiles); the node's 3D
## transform is only presentation, synced every frame.
class_name Actor
extends Node3D

enum Team { PLAYER, ENEMY, NEUTRAL }

const SHADOW_TEX := preload("res://assets/sprites/shadow.png")

static var _shadow_mat: StandardMaterial3D

var stage: Stage
var team := Team.ENEMY
var display_name := ""
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var push := Vector2.ZERO
var height := 0.0
var radius := 0.35
var mass := 1.0
var flying := false
var anchored := false
var ghost := false
var targetable := true
var alive := true

var hp := 10.0
var max_hp := 10.0
var armor := 0.0
var damage_taken := 1.0
var poise := 0.0
var max_poise := 0.0
var poise_regen_wait := 0.0
var invuln_t := 0.0
var status := StatusSet.new()
var facing := Vector2.RIGHT
var hit_by_player := false
var last_hit_from := Vector2.ZERO

var visual: Node3D
var sprite: PixelSprite
var shadow: MeshInstance3D
var shadow_scale := 1.0
var bob := 0.0


func _ready() -> void:
	if visual == null:
		build_visual("")


func build_visual(sheet: String, anim := "") -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if sheet != "":
		sprite = PixelSprite.new()
		visual.add_child(sprite)
		sprite.setup(sheet, anim)
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	var sw := maxf(radius * 2.2, 0.6) * shadow_scale
	q.size = Vector2(sw, sw * 0.55 * Iso.SQ2)
	q.orientation = PlaneMesh.FACE_Y
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_shadow_mat.alpha_scissor_threshold = 0.5
		_shadow_mat.albedo_texture = SHADOW_TEX
		_shadow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_shadow_mat.albedo_color = Color(0, 0, 0, 1)
	q.material = _shadow_mat
	shadow.mesh = q
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0, 0.01, 0)
	add_child(shadow)
	sync_visual()


func box() -> float:
	return radius * 0.8


func is_dead() -> bool:
	return not alive


func hp_ratio() -> float:
	return hp / maxf(max_hp, 1.0)


## Main simulation step. Subclasses override think() for behaviour.
func tick(dt: float) -> void:
	var burn := status.tick(dt)
	if burn > 0.0 and alive:
		var h := Hit.make(status.burn_source, burn, ["fire", "dot"])
		h.can_crit = false
		h.silent = true
		h.proc = false
		take_hit(h)
		if not alive:
			return
	if invuln_t > 0.0:
		invuln_t -= dt
	if poise_regen_wait > 0.0:
		poise_regen_wait -= dt
	elif poise < max_poise:
		poise = minf(max_poise, poise + max_poise * 0.35 * dt)
	think(dt)
	_move(dt)
	sync_visual()


func think(_dt: float) -> void:
	pass


func _move(dt: float) -> void:
	var spd := status.speed_mult()
	if vel != Vector2.ZERO and spd > 0.0:
		pos = stage.grid.move_box(pos, box(), vel * spd * dt, flying)
	if push.length_squared() > 0.0001:
		var cross := flying or (team == Team.ENEMY and mass < 5.0)
		pos = stage.grid.move_box(pos, box(), push * dt, cross)
		push *= exp(-9.0 * dt)
		if cross and not flying and stage.grid.at(floori(pos.x), floori(pos.y)) == TileGrid.PIT:
			_fall_into_pit()
	else:
		push = Vector2.ZERO


func _fall_into_pit() -> void:
	if not alive:
		return
	stage.fx.number(pos, 1.5, "PLUNGED!", Color(0.7, 0.9, 1.0))
	stage.fx.burst(pos, 0.0, Color(0.3, 0.9, 0.85), 10, 3.0, 0.6, 2.0)
	var h := Hit.make(null, hp + 9999.0, ["fall"])
	h.can_crit = false
	h.silent = true
	hp = 0.0
	die(stage.player)


func sync_visual() -> void:
	if visual == null:
		return
	# snap to the texel grid so sprites never shimmer
	var sx := roundf(pos.x * Iso.PPU) / Iso.PPU
	var sy := roundf(pos.y * Iso.PPU) / Iso.PPU
	var sh := roundf((height + bob) * Iso.PPU) / Iso.PPU
	position = Iso.to_world(Vector2(sx, sy), 0.0)
	visual.position = Vector3(0, sh * Iso.SQ2, 0)
	if sprite:
		sprite.flip_h = facing.x < -0.05 if absf(facing.x) > 0.05 else sprite.flip_h


## Applies a hit. Returns the resolved result (amount 0 if ignored).
func take_hit(hit: Hit) -> Combat.Result:
	var res := Combat.Result.new()
	if not alive or (invuln_t > 0.0 and not hit.has_tag("dot")):
		return res
	var block := block_mult(hit)
	var shatter := false
	if hit.source is Player:
		shatter = (hit.source as Player).stats.has("shatter")
	res = Combat.resolve(hit, status, armor, damage_taken * extra_damage_taken(hit), randf(), shatter, block)
	if res.amount <= 0.0:
		return res
	hp -= res.amount
	last_hit_from = hit.from_dir
	if hit.source is Player or (hit.source is Actor and (hit.source as Actor).team == Team.PLAYER):
		hit_by_player = true
	on_damaged(hit, res)
	if hit.knockback != Vector2.ZERO and not anchored:
		push += hit.knockback / maxf(mass, 0.1) * (0.3 if res.blocked else 1.0)
	if hit.poise > 0.0 and max_poise > 0.0:
		poise -= hit.poise * (0.4 if res.blocked else 1.0)
		poise_regen_wait = 1.6
		if poise <= 0.0:
			poise = max_poise
			on_poise_break(hit)
	if hit.burn > 0:
		var dps := 3.0
		var max_st := 3
		if hit.source is Player:
			var st: Stats = (hit.source as Player).stats
			dps = 3.0 * (1.0 + st.v("burn_damage")) * st.v("damage_more")
			max_st = int(st.v("burn_stacks"))
		status.apply_burn(hit.burn, dps, max_st, hit.source)
	if hit.chill > 0.0:
		if status.apply_chill(hit.chill):
			on_frozen()
	if hit.expose > 0.0:
		status.exposed_t = maxf(status.exposed_t, hit.expose)
	if hp <= 0.0:
		hp = 0.0
		die(hit.source)
	return res


## Fraction of damage that gets through (1 = all). Shields override this.
func block_mult(_hit: Hit) -> float:
	return 1.0


func extra_damage_taken(_hit: Hit) -> float:
	return 1.0


func on_damaged(hit: Hit, res: Combat.Result) -> void:
	if sprite and not hit.silent:
		sprite.flash(Color(1, 1, 1), 0.09)
	elif sprite and hit.has_tag("fire"):
		sprite.flash(Color(1.0, 0.5, 0.2), 0.06)
	if stage and stage.fx and not (hit.silent and res.amount < 1.0):
		var col := Color(1, 1, 1)
		if res.crit:
			col = Color(1.0, 0.85, 0.3)
		elif hit.has_tag("dot"):
			col = Color(1.0, 0.55, 0.25)
		elif hit.has_tag("frost"):
			col = Color(0.6, 0.85, 1.0)
		if team == Team.PLAYER:
			col = Color(1.0, 0.35, 0.35)
		var txt := str(int(res.amount))
		if res.crit:
			txt += "!"
		if res.blocked:
			col = col.darkened(0.35)
		stage.fx.number(pos, 1.9 + randf() * 0.3, txt, col, res.crit)


func on_poise_break(_hit: Hit) -> void:
	status.stagger_t = 1.0
	if stage:
		stage.fx.number(pos, 2.4, "STAGGER", Color(1.0, 0.9, 0.5))
		stage.fx.ring(pos, 1.2, Color(1.0, 0.85, 0.4), 0.25, 0.3)


func on_frozen() -> void:
	if stage:
		stage.fx.number(pos, 2.4, "FROZEN", Color(0.65, 0.9, 1.0))
		stage.fx.burst(pos, 0.8, Color(0.75, 0.92, 1.0), 12, 3.0, 0.5, 4.0)


func heal(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp > before and stage:
		stage.fx.number(pos, 2.0, "+%d" % int(hp - before), Color(0.5, 1.0, 0.55))


func die(_killer: Node) -> void:
	if not alive:
		return
	alive = false
	vel = Vector2.ZERO
	if stage:
		stage.remove_actor(self)
		stage.notify_death(self, _killer)
	_death_effect()


func _death_effect() -> void:
	if sprite == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_method(sprite.set_dissolve, 0.0, 1.05, 0.45)
	tw.tween_callback(queue_free)
	if shadow:
		shadow.visible = false


func face_towards(p: Vector2) -> void:
	var d := p - pos
	if d.length_squared() > 0.0001:
		facing = d.normalized()
