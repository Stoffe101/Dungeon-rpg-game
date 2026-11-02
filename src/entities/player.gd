## The Kindled. Direct control: move, aim, attack combos, charged attacks,
## dodge (with perfect-dodge reward), Ward (parry / reflect), two Kindle-fuelled
## abilities and a healing flask. Kindle also feeds the lantern: the more you
## have, the further your light reaches.
class_name Player
extends Actor

const DODGE_SPEED := 17.0
const PERFECT_WINDOW := 0.2

var stats: Stats
var run: RunState
var weapon: Weapon
var ability_slots: Array = ["flare", ""]
var ability_cd: Array = [0.0, 0.0]
var kindle := 0.0
var dodge_charges := 2.0
var dodge_t := 0.0
var dodge_len := 0.0
var dodge_dir := Vector2.ZERO
var dodge_age := 9.0
var perfect_done := false
var ward_t := 0.0
var ward_cd := 0.0
var ward_recover := 0.0
var cast_t := 0.0
var hurt_t := 0.0
var flask := 2
var flask_t := 0.0
var barrier := 0.0
var barrier_t := 0.0
var aegis_hp := 0.0
var aegis_t := 0.0
var riposte_t := 0.0
var ambush_t := 0.0
var counter_ready := false
var second_wind_used := false
var phoenix_used := false
var aim := Vector2.RIGHT
var aim_point := Vector2.ZERO
var move_in := Vector2.ZERO
var input_enabled := true
var autopilot := false
var last_attacker_id := ""
var godmode := "godmode" in OS.get_cmdline_user_args()
var lantern: OmniLight3D
var dir_name := "down"
var hit_once := {}
var dead_t := 0.0

var _buf := {"attack": 0.0, "dodge": 0.0, "ward": 0.0, "a1": 0.0, "a2": 0.0, "flask": 0.0}
var _release_pending := false
var _attack_down := false
var _trail_t := 0.0
var _rime_t := 0.0
var _flicker := 0.0
var _aegis_fx: MeshInstance3D
var _pad_aim := false
var _last_foot := -1
var _foot_i := 0


func _ready() -> void:
	team = Team.PLAYER
	radius = 0.32
	mass = 1.0
	display_name = "Kindled"
	build_visual("player", "idle_down")
	var mat := sprite.sheet.material
	if mat.next_pass == null:
		var sil := ShaderMaterial.new()
		sil.shader = preload("res://assets/shaders/silhouette.gdshader")
		sil.set_shader_parameter("atlas", mat.get_shader_parameter("atlas"))
		sil.set_shader_parameter("frame_uv", mat.get_shader_parameter("frame_uv"))
		sil.render_priority = 1
		mat.next_pass = sil
	lantern = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.64, 0.34)
	lantern.light_energy = 2.0
	lantern.omni_range = 8.0
	lantern.omni_attenuation = 0.9
	lantern.shadow_enabled = true
	lantern.shadow_bias = 0.08
	lantern.position = Vector3(0.35, 1.0 * Iso.SQ2, 0.25)
	visual.add_child(lantern)


## Builds stats from the profile (skill tree, forge, sanctuary) and the run's relics.
func setup_from(r: RunState) -> void:
	run = r
	rebuild_stats()
	var wid: String = r.weapon_id
	set_weapon(wid, r.weapon_level)
	ability_slots = r.abilities.duplicate()
	hp = max_hp if r.hp < 0.0 else minf(r.hp, max_hp)
	kindle = r.kindle
	flask = int(stats.v("flask_charges")) if r.flask < 0 else r.flask
	second_wind_used = r.second_wind_used
	phoenix_used = r.phoenix_used
	dodge_charges = stats.v("dodge_charges")


func rebuild_stats() -> void:
	var ratio := hp_ratio() if max_hp > 0.0 and hp > 0.0 else 1.0
	stats = Stats.for_player()
	SkillDB.apply(Profile.skills(), stats)
	Profile.apply_sanctuary(stats)
	if run:
		RelicDB.apply(run.relics, stats)
	var old_max := max_hp
	max_hp = maxf(1.0, roundf(stats.v("max_hp")))
	if old_max > 0.0 and hp > 0.0:
		hp = clampf(roundf(max_hp * ratio), 1.0, max_hp)
	else:
		hp = max_hp
	armor = stats.v("armor")
	damage_taken = stats.v("damage_taken")
	kindle = minf(kindle, stats.v("kindle_max"))
	dodge_charges = minf(dodge_charges, stats.v("dodge_charges"))
	anchored = stats.has("unbreakable")


func set_weapon(id: String, level: int) -> void:
	if weapon:
		weapon.free_visual()
	var def := GearDB.weapon(id)
	var scr: GDScript = load(def.script)
	weapon = scr.new()
	weapon.setup(self, id, level)


func kindle_max() -> float:
	return stats.v("kindle_max")


func aim_offset() -> Vector2:
	# lean the camera a little toward where the player is looking
	var d := (aim_point - pos)
	return d.limit_length(6.0) * 0.18


# --- input (real time) ---------------------------------------------------------

func _process(delta: float) -> void:
	for k in _buf:
		_buf[k] = maxf(0.0, _buf[k] - delta)
	if autopilot:
		return
	if not input_enabled or not alive or get_tree().paused:
		move_in = Vector2.ZERO
		if _attack_down:
			_attack_down = false
			_release_pending = true
		return
	move_in = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	# the mouse wins as soon as it is used (Settings sees every input event;
	# this node lives in the world SubViewport, which receives none)
	if not Settings.using_pad:
		_pad_aim = false
	if stick.length() > 0.3:
		_pad_aim = true
		aim = _assisted(stick.normalized())
		aim_point = pos + aim * 4.0
	elif _pad_aim and move_in.length() > 0.3 and not _attack_down:
		aim = move_in.normalized()
		aim_point = pos + aim * 4.0
	if not _pad_aim and stage and stage.view:
		# root-window UI coordinates: get_viewport() here is the world SubViewport,
		# whose mouse position never updates
		var mp := stage.view.get_global_mouse_position()
		aim_point = stage.view.screen_to_plane(mp, 0.6)
		var d := aim_point - pos
		if d.length() > 0.05:
			aim = d.normalized()
	# the press that closed a menu must not also act in the world
	if Game.ui and Engine.get_process_frames() - Game.ui.closed_frame <= 1:
		return
	if Input.is_action_just_pressed("interact"):
		try_interact()
	if Input.is_action_just_pressed("attack"):
		_buf.attack = 0.18
		_attack_down = true
	if _attack_down and not Input.is_action_pressed("attack"):
		_attack_down = false
		_release_pending = true
	if Input.is_action_just_pressed("dodge"):
		_buf.dodge = 0.15
	if Input.is_action_just_pressed("ward"):
		_buf.ward = 0.12
	if Input.is_action_just_pressed("ability_1"):
		_buf.a1 = 0.15
	if Input.is_action_just_pressed("ability_2"):
		_buf.a2 = 0.15
	if Input.is_action_just_pressed("flask"):
		_buf.flask = 0.15


## Uses the nearest interactable prop (chest, merchant, stairs...). Returns it, or null.
func try_interact() -> Prop:
	if stage == null or not alive:
		return null
	var near := stage.nearest_interactable(pos)
	if near:
		near.interact(self)
	return near


## Gamepad aim assist: bend the stick direction toward the enemy closest to it.
func _assisted(dir: Vector2) -> Vector2:
	var k := float(Settings.get_value("aim_assist", 0.5))
	if k <= 0.0 or stage == null:
		return dir
	var cone := deg_to_rad(12.0 + 18.0 * k)
	var best: Actor = null
	var best_ang := cone
	for a in stage.hostiles(team):
		var to := a.pos - pos
		if to.length() > 9.0:
			continue
		var ang := absf(dir.angle_to(to))
		if ang < best_ang and stage.grid.line_clear(pos, a.pos):
			best_ang = ang
			best = a
	if best == null:
		return dir
	return dir.slerp((best.pos - pos).normalized(), clampf(k, 0.0, 1.0) * 0.85)


# --- simulation ------------------------------------------------------------------

func think(dt: float) -> void:
	if not alive:
		return
	_timers(dt)
	if dodge_t > 0.0:
		_update_dodge(dt)
	else:
		_handle_actions(dt)
		if weapon:
			weapon.update(dt)
		var spd := stats.v("move_speed")
		var mult := weapon.move_mult() if weapon else 1.0
		if cast_t > 0.0:
			mult *= 0.55
		if ward_t > 0.0 or ward_recover > 0.0:
			mult *= 0.35
		if flask_t > 0.0:
			mult *= 0.45
		vel = move_in * spd * mult
	facing = aim
	_update_lantern(dt)
	_update_anim()
	_footsteps()
	_update_aegis_fx()


func _timers(dt: float) -> void:
	for i in 2:
		ability_cd[i] = maxf(0.0, ability_cd[i] - dt)
	ward_cd = maxf(0.0, ward_cd - dt)
	ward_recover = maxf(0.0, ward_recover - dt)
	riposte_t = maxf(0.0, riposte_t - dt)
	ambush_t = maxf(0.0, ambush_t - dt)
	cast_t = maxf(0.0, cast_t - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	dodge_age += dt
	if flask_t > 0.0:
		flask_t -= dt
	if barrier_t > 0.0:
		barrier_t -= dt
		if barrier_t <= 0.0:
			barrier = 0.0
	if aegis_t > 0.0:
		aegis_t -= dt
		if aegis_t <= 0.0:
			aegis_hp = 0.0
	if ward_t > 0.0:
		ward_t -= dt
		if ward_t <= 0.0:
			ward_recover = 0.28
			ward_cd = 0.35
	var maxc := stats.v("dodge_charges")
	if dodge_charges < maxc:
		dodge_charges = minf(maxc, dodge_charges + dt / maxf(0.2, stats.v("dodge_recharge")))


func _handle_actions(_dt: float) -> void:
	var leaping: bool = weapon is Weapon and weapon.has_method("is_busy") and weapon.get("leaping") == true
	if _buf.dodge > 0.0 and dodge_charges >= 1.0 and not leaping:
		_buf.dodge = 0.0
		_start_dodge()
		return
	if _buf.ward > 0.0 and ward_cd <= 0.0 and ward_recover <= 0.0 and not leaping and not stats.has("no_ward"):
		_buf.ward = 0.0
		_start_ward()
		return
	for i in 2:
		var key: String = "a1" if i == 0 else "a2"
		if _buf[key] > 0.0 and not leaping:
			_buf[key] = 0.0
			_try_ability(i)
	if _buf.flask > 0.0 and flask_t <= 0.0:
		_buf.flask = 0.0
		_drink()
	if weapon == null or ward_t > 0.0 or flask_t > 0.0:
		return
	if _buf.attack > 0.0 and cast_t <= 0.0:
		_buf.attack = 0.0
		weapon.press()
		if not _attack_down:
			_release_pending = true
	if _release_pending and not (_buf.attack > 0.0):
		_release_pending = false
		weapon.release()


func _start_dodge() -> void:
	var d := move_in if move_in.length() > 0.2 else aim
	dodge_dir = d.normalized()
	var dist := stats.v("dodge_distance")
	dodge_len = dist / DODGE_SPEED
	dodge_t = dodge_len
	dodge_age = 0.0
	perfect_done = false
	invuln_t = maxf(invuln_t, stats.v("dodge_iframes"))
	dodge_charges -= 1.0
	if weapon:
		weapon.cancel()
	ward_t = 0.0
	cast_t = 0.0
	Audio.play("dodge", -2.0, randf_range(0.95, 1.05))
	stage.fx.burst(pos, 0.1, Color(0.55, 0.52, 0.5), 6, 2.0, 0.35, 4.0, -dodge_dir, 0.8)
	if stats.has("dodge_afterimage"):
		Abilities.shade(self, pos, 30.0 * (2.0 if stats.has("afterimage_double") else 1.0), 0.6)


func _update_dodge(dt: float) -> void:
	dodge_t -= dt
	vel = dodge_dir * DODGE_SPEED
	_trail_t += dt
	if _trail_t >= 0.035:
		_trail_t = 0.0
		stage.fx.ghost(sprite, global_position + sprite.position + visual.position, Color(1.0, 0.6, 0.3), 0.18)
	if stats.has("frost_trail"):
		_rime_t += dt
		if _rime_t >= 0.06:
			_rime_t = 0.0
			var hz := Hazard.spawn(stage, pos, 0.7, 2.5, team, Color(0.6, 0.85, 1.0), func(_h: Hazard, a: Actor) -> void:
				var h := Combat.player_hit(self, stats, 3.0, ["frost", "dot"])
				h.chill = 0.3
				h.can_crit = false
				h.silent = true
				deal_hit(a, h))
			hz.period = 0.35
			hz.particle_rate = 3.0
	if dodge_t <= 0.0:
		dodge_t = 0.0
		vel = Vector2.ZERO
		if stats.has("ambush"):
			ambush_t = 1.2


func _start_ward() -> void:
	ward_t = stats.v("parry_window")
	if weapon:
		weapon.cancel()
	Audio.play("ward", -3.0)
	stage.fx.shape(Fx.Shape.RING, pos, Vector2.RIGHT, Vector2(2.4, 2.4), Color(1.0, 0.85, 0.5, 0.6), Color(1.0, 0.95, 0.75, 1.0), ward_t, {"inner": 0.82, "glow": 1.4})


func is_warding() -> bool:
	return ward_t > 0.0


func _try_ability(slot: int) -> void:
	var id: String = ability_slots[slot] if slot < ability_slots.size() else ""
	if id == "" or ability_cd[slot] > 0.0 or cast_t > 0.0:
		return
	var d := GearDB.ability(id)
	if d.is_empty():
		return
	var cost: float = d.cost * stats.v("ability_cost")
	if id == "gloamstep" and stats.has("twin_shade"):
		cost *= 0.6
	var pay_hp := 0.0
	if kindle < cost:
		if stats.has("bonfire_soul"):
			pay_hp = (cost - kindle) * 0.5
			if hp <= pay_hp + 1.0:
				_deny()
				return
		else:
			_deny()
			return
	if weapon:
		weapon.cancel()
	if not Abilities.cast(self, id):
		return
	if pay_hp > 0.0:
		hp -= pay_hp
		kindle = 0.0
		stage.fx.number(pos, 2.2, "-%d" % int(pay_hp), Color(1.0, 0.4, 0.3))
	else:
		kindle -= cost
	if stats.has("blood_price"):
		hp = maxf(1.0, hp - max_hp * 0.04)
	ability_cd[slot] = float(d.cooldown) * stats.v("cooldown")
	cast_t = 0.2


func _deny() -> void:
	Audio.play("deny", -6.0)
	stage.fx.number(pos, 2.2, "no kindle", Color(0.7, 0.7, 0.75))


func _drink() -> void:
	if flask <= 0:
		_deny_flask()
		return
	if hp >= max_hp:
		return
	flask -= 1
	flask_t = 0.45
	if weapon:
		weapon.cancel()
	var amount := max_hp * stats.v("flask_heal") * stats.v("heal_mult")
	heal(amount)
	Audio.play("flask", 0.0)
	# hearth-fire rises through you: motes, a warm ring, a soft flash of light
	stage.fx.motes(pos, 0.4, Color(1.0, 0.75, 0.4), 18, 1.6, 0.8, 0.4)
	stage.fx.motes(pos, 0.1, Color(0.6, 1.0, 0.6), 10, 2.2, 0.7, 0.3)
	stage.fx.ring(pos, 1.3, Color(1.0, 0.8, 0.45), 0.35, 0.2)
	stage.fx.flash_light(pos, 1.0, Color(1.0, 0.75, 0.45), 2.0, 4.0, 0.4)
	if sprite:
		sprite.flash(Color(1.0, 0.85, 0.55), 0.25)
	Settings.rumble(0.25, 0.0, 0.15)


func _deny_flask() -> void:
	Audio.play("deny", -6.0)
	stage.fx.number(pos, 2.2, "flask empty", Color(0.7, 0.7, 0.75))


func gain_kindle(amount: float) -> void:
	var mx := stats.v("kindle_max")
	var before := kindle
	kindle = minf(mx, kindle + amount * stats.v("kindle_gain"))
	if before < mx and kindle >= mx:
		stage.fx.ring(pos, 1.2, Color(1.0, 0.8, 0.35), 0.3, 0.2)
		Audio.play("kindle_full", -6.0)


# --- weapon callbacks --------------------------------------------------------------

func on_attack_start() -> void:
	cast_t = 0.0


func on_weapon_charged() -> void:
	Audio.play("charged", -4.0)
	stage.fx.ring(pos, 1.0, Color(1.0, 0.85, 0.45), 0.2, 0.25)


func on_weapon_strike(_hits: int, _finisher: bool) -> void:
	if stats.has("overflow") and kindle >= stats.v("kindle_max") - 0.01:
		for i in 2:
			var d := aim.rotated(randf_range(-0.6, 0.6))
			var pr := Projectile.create(stage, "proj_ember", pos + d * 0.4, d * 12.0, team)
			pr.source = self
			pr.damage = 8.0
			pr.tags = ["ability", "fire"]
			pr.homing_target = stage.nearest_hostile(team, pos, 9.0, true)
			pr.homing_turn = 8.0
			pr.spin = true
			pr.reflectable = false
			pr.trail_color = Color(1.0, 0.8, 0.4)
			pr.trail_rate = 30.0
			pr.life = 1.2


# --- dealing damage ------------------------------------------------------------------

## Every hit the player (or their summons/projectiles) lands goes through here so
## skill-tree and relic interactions apply consistently.
func deal_hit(t: Actor, h: Hit, finisher := false) -> Combat.Result:
	if t == null or not t.alive:
		return Combat.Result.new()
	var dot := h.has_tag("dot")
	var direct := (h.has_tag("melee") or h.has_tag("ranged")) and not dot
	var mult := 1.0
	if stats.has("executioner") and t.hp_ratio() < 0.3:
		mult *= 1.6
	if stats.has("desperation") and hp_ratio() < 0.4:
		mult *= 1.35
	if stats.has("first_strike") and not hit_once.has(t.get_instance_id()):
		hit_once[t.get_instance_id()] = true
		mult *= 1.6
	if stats.has("cinder_crown") and t.status.burning():
		mult *= 1.2
	if stats.has("quake_stone") and t.status.is_staggered():
		mult *= 1.25
	if stats.has("winters_heart") and t.status.chill <= 0.0 and not t.status.is_frozen():
		mult *= 0.75
	if t is Enemy and (t as Enemy).elite:
		mult *= 1.0 + stats.v("elite_damage")
	h.amount *= mult
	if direct and ambush_t > 0.0:
		h.forced_crit = true
	if direct and riposte_t > 0.0:
		h.forced_crit = true
		h.amount *= 1.6
		riposte_t = 0.0
	if finisher and stats.has("perfect_form") and h.has_tag("melee"):
		h.forced_crit = true
	if h.proc and not dot:
		var bc := stats.v("burn_chance")
		if stats.has("searing_edge") and h.has_tag("melee"):
			bc += 0.2
		if bc > 0.0 and randf() < bc:
			h.burn += 1
		if not stats.has("living_pyre"):
			var cc := stats.v("chill_chance")
			if stats.has("winters_heart"):
				cc = 1.0
			if cc > 0.0 and randf() < cc:
				h.chill += 0.3 + stats.v("chill_power")
			if h.has_tag("frost"):
				h.chill += stats.v("chill_power")
		if counter_ready:
			h.poise += 999.0
			counter_ready = false
	if stats.has("living_pyre"):
		h.chill = 0.0
	var was_chilled := t.status.chill > 0.0 or t.status.is_frozen()
	var was_burning := t.status.burning()
	var res := t.take_hit(h)
	if res.amount <= 0.0:
		return res
	Events.damage_dealt.emit(t, res.amount, res.crit)
	if res.crit and stats.has("pyre_brand") and t.alive:
		t.status.apply_burn(3, 3.0 * (1.0 + stats.v("burn_damage")), int(stats.v("burn_stacks")), self)
	if h.proc and direct:
		var g := 4.0 if h.has_tag("melee") else 1.2
		if stats.has("ember_edge") and h.has_tag("melee"):
			g *= 1.5
		gain_kindle(g)
	if res.crit and h.proc and stats.has("crit_chain"):
		_crit_chain(t, res.amount * 0.5)
	if h.proc and stats.has("thermal_shock"):
		if (h.has_tag("fire") and was_chilled) or (h.has_tag("frost") and was_burning):
			_thermal_shock(t)
	if not dot and not h.silent:
		var col: Color = t.hit_color() if t.has_method("hit_color") else Color(0.9, 0.9, 0.85)
		stage.fx.burst(t.pos, 0.6, col, 5 if not res.crit else 10, 4.0, 0.3, 8.0, h.from_dir, 0.7)
		# a starburst where it landed, tinted by what landed, and a nudge of the camera
		var flash_col := Color(1.0, 0.92, 0.75)
		if res.crit:
			flash_col = Color(1.0, 0.82, 0.35)
		elif h.has_tag("fire"):
			flash_col = Color(1.0, 0.6, 0.3)
		elif h.has_tag("frost"):
			flash_col = Color(0.65, 0.88, 1.0)
		stage.fx.impact(t.pos, 0.75, flash_col, res.crit or finisher, h.from_dir)
		if h.has_tag("melee"):
			stage.fx.kick(h.from_dir, 2.5 if res.crit or finisher else 1.2)
			if weapon:
				weapon.hit_flash()
		if res.crit:
			stage.fx.burst(t.pos, 0.8, Color(1.0, 0.9, 0.5), 6, 5.0, 0.2, 0.0, h.from_dir, 0.5)
			stage.hitstop(0.06)
			Settings.rumble(0.35, 0.25, 0.08)
			Audio.play("crit", -3.0, randf_range(0.95, 1.05))
		else:
			Settings.rumble(0.18, 0.0, 0.05)
			Audio.play("hit", -4.0, randf_range(0.9, 1.1))
		if not t.alive and h.has_tag("melee"):
			# killing blows land a beat harder
			stage.hitstop(0.075 if (t is Enemy and (t as Enemy).elite) else 0.05)
			stage.fx.kick(h.from_dir, 2.0)
	return res


func _crit_chain(from: Actor, dmg: float) -> void:
	var best: Actor = null
	var bd := 4.5
	for a in stage.hostiles(team):
		if a == from:
			continue
		var d := a.pos.distance_to(from.pos)
		if d < bd:
			bd = d
			best = a
	if best == null:
		return
	var steps := 8
	for i in steps:
		var p := from.pos.lerp(best.pos, float(i) / steps)
		stage.fx.burst(p, 0.8, Color(1.0, 0.75, 0.35), 1, 0.5, 0.25, 0.0)
	var h := Hit.make(self, dmg, ["fire"])
	h.can_crit = false
	h.proc = false
	h.from_dir = (best.pos - from.pos).normalized()
	deal_hit(best, h)


func _thermal_shock(t: Actor) -> void:
	t.status.chill = 0.0
	stage.fx.ring(t.pos, 2.2, Color(0.9, 0.95, 1.0), 0.3, 0.3)
	stage.fx.burst(t.pos, 0.6, Color(0.9, 0.95, 1.0), 20, 4.0, 0.6, -1.5)
	Audio.play("steam", -2.0)
	for a in stage.in_circle(team, t.pos, 2.2):
		var h := Combat.player_hit(self, stats, 32.0, ["fire", "frost"])
		h.proc = false
		h.knockback = (a.pos - t.pos).normalized() * 4.0
		h.from_dir = (a.pos - t.pos).normalized()
		deal_hit(a, h)


# --- taking damage ---------------------------------------------------------------------

## All enemy damage to the player passes through here (dodge, ward, aegis, barrier).
func take_enemy_hit(h: Hit, attacker: Node) -> Combat.Result:
	var empty := Combat.Result.new()
	if not alive or godmode:
		return empty
	if dodge_t > 0.0 or (invuln_t > 0.0 and dodge_age < stats.v("dodge_iframes") + 0.02):
		if dodge_age <= PERFECT_WINDOW and not perfect_done and not h.has_tag("dot"):
			_perfect_dodge()
		return empty
	if invuln_t > 0.0:
		return empty
	if ward_t > 0.0 and not h.has_tag("dot") and not h.unblockable:
		_on_ward(attacker, false)
		return empty
	if stats.has("hearthguard") and kindle >= stats.v("kindle_max") - 0.01:
		h.amount *= 0.85
	if aegis_t > 0.0 and aegis_hp > 0.0:
		var ab := minf(aegis_hp, h.amount)
		aegis_hp -= ab
		h.amount -= ab
		stage.fx.burst(pos, 0.8, Color(1.0, 0.85, 0.45), 6, 3.0, 0.3, 0.0)
		if aegis_hp <= 0.0:
			aegis_t = 0.0
			stage.fx.ring(pos, 1.5, Color(1.0, 0.8, 0.4), 0.25, 0.3)
	if barrier > 0.0 and h.amount > 0.0:
		var ab2 := minf(barrier, h.amount)
		barrier -= ab2
		h.amount -= ab2
	if h.amount <= 0.0:
		return empty
	h.can_crit = false
	if attacker is Enemy and is_instance_valid(attacker):
		last_attacker_id = (attacker as Enemy).id
	elif h.source is Enemy and is_instance_valid(h.source):
		last_attacker_id = (h.source as Enemy).id
	var res := take_hit(h)
	if res.amount > 0.0:
		hurt_t = 0.25
		invuln_t = maxf(invuln_t, 0.5)
		stage.hitstop(0.07)
		stage.fx.shake(0.4)
		stage.fx.kick(h.from_dir, 3.0)
		stage.fx.burst(pos, 0.7, Color(0.85, 0.2, 0.25), 8, 4.0, 0.35, 8.0, h.from_dir, 0.8)
		Audio.play("hurt", 0.0)
		Events.player_damaged.emit(res.amount)
		if weapon and weapon.phase == Weapon.Phase.CHARGE:
			weapon.cancel()
		if attacker is Actor and is_instance_valid(attacker) and (attacker as Actor).alive:
			var at := attacker as Actor
			if stats.v("thorns") > 0.0 and at.pos.distance_to(pos) < 3.0:
				var th := Hit.make(self, stats.v("thorns"), ["melee"])
				th.can_crit = false
				th.proc = false
				deal_hit(at, th)
			if stats.has("hoarfrost"):
				at.status.apply_chill(0.5)
			if attacker is Enemy and (attacker as Enemy).affix == "vampiric":
				at.heal(res.amount * 1.5)
		if stats.has("hearthguard"):
			gain_kindle(10.0 / maxf(stats.v("kindle_gain"), 0.01))
	return res


func _perfect_dodge() -> void:
	perfect_done = true
	stage.slow_motion(0.3, 0.35)
	Settings.rumble(0.6, 0.0, 0.12)
	stage.fx.ring(pos, 1.8, Color(1.0, 0.9, 0.6), 0.3, 0.15)
	stage.fx.number(pos, 2.4, "PERFECT", Color(1.0, 0.9, 0.55))
	Audio.play("perfect", -2.0)
	gain_kindle(15.0 / maxf(stats.v("kindle_gain"), 0.01))
	if stats.has("perfect_refund"):
		dodge_charges = minf(stats.v("dodge_charges"), dodge_charges + 1.0)
		gain_kindle(25.0)
	if stats.has("counterstep"):
		counter_ready = true
	Events.perfect_dodge.emit()


func _on_ward(attacker: Node, projectile: bool) -> void:
	ward_t = 0.0
	ward_cd = 0.1
	ward_recover = 0.0
	stage.hitstop(0.1)
	stage.fx.ring(pos, 1.6, Color(1.0, 0.85, 0.45), 0.25, 0.3)
	stage.fx.burst(pos + aim * 0.5, 0.8, Color(1.0, 0.9, 0.6), 14, 6.0, 0.3, 4.0)
	stage.fx.flash_light(pos, 1.0, Color(1.0, 0.8, 0.45), 3.0, 4.0, 0.2)
	stage.fx.number(pos, 2.4, "WARD", Color(1.0, 0.9, 0.55))
	stage.fx.shake(0.2)
	Audio.play("parry", 0.0)
	gain_kindle(15.0 / maxf(stats.v("kindle_gain"), 0.01))
	if stats.has("riposte"):
		riposte_t = 2.0
	if stats.has("ward_barrier"):
		barrier = 20.0
		barrier_t = 4.0
	if stats.has("counterstep"):
		counter_ready = true
	if not projectile and attacker is Actor and is_instance_valid(attacker):
		var at := attacker as Actor
		if at.alive and at.pos.distance_to(pos) < 4.0:
			at.on_poise_break(null)
			at.push += (at.pos - pos).normalized() * 6.0
			if stats.has("glacial_ward"):
				at.status.apply_chill(1.0)
	Events.parry_success.emit()


## Called by enemy projectiles touching the player.
func try_reflect(p: Projectile) -> bool:
	if ward_t > 0.0:
		var mirror := stats.has("mirror_ward")
		p.reflect(self, 3.0 if mirror else 1.5, 2 if mirror else 0)
		if stats.has("glacial_ward"):
			p.chill = 0.5
		_on_ward(null, true)
		return true
	if aegis_t > 0.0:
		p.reflect(self, 1.5, 0)
		Audio.play("parry", -6.0, 1.2)
		return true
	return false


func die(killer: Node) -> void:
	if not alive:
		return
	if stats.has("second_wind") and not second_wind_used:
		second_wind_used = true
		hp = 1.0
		invuln_t = 2.0
		stage.fx.number(pos, 2.6, "SECOND WIND", Color(1.0, 0.9, 0.6), true)
		stage.fx.ring(pos, 2.0, Color(1.0, 0.85, 0.5), 0.4, 0.2)
		stage.slow_motion(0.35, 0.5)
		Audio.play("perfect", 0.0, 0.8)
		return
	if stats.has("phoenix") and not phoenix_used:
		phoenix_used = true
		hp = max_hp * 0.5
		invuln_t = 2.0
		stage.fx.number(pos, 2.6, "REKINDLED", Color(1.0, 0.7, 0.3), true)
		stage.fx.flash_light(pos, 1.0, Color(1.0, 0.6, 0.25), 6.0, 9.0, 0.6)
		stage.fx.ring(pos, 4.0, Color(1.0, 0.6, 0.25), 0.4, 0.3)
		stage.fx.burst(pos, 0.5, Color(1.0, 0.65, 0.25), 40, 8.0, 0.6, 1.0)
		for a in stage.in_circle(team, pos, 4.0):
			var h := Combat.player_hit(self, stats, 60.0, ["fire"])
			h.burn = 3
			h.knockback = (a.pos - pos).normalized() * 12.0
			deal_hit(a, h)
		Audio.play("explode", 2.0)
		return
	alive = false
	vel = Vector2.ZERO
	if weapon:
		weapon.cancel()
		weapon.free_visual()
	sprite.play("death", true)
	stage.slow_motion(0.25, 1.2)
	stage.fx.burst(pos, 0.5, Color(1.0, 0.6, 0.3), 30, 3.0, 1.2, -0.5)
	Audio.play("player_death", 0.0)
	Events.player_died.emit()
	stage.notify_death(self, killer)


# --- presentation --------------------------------------------------------------

func _update_lantern(dt: float) -> void:
	_flicker += dt
	var k := kindle / maxf(1.0, stats.v("kindle_max"))
	var fl := 0.94 + 0.06 * sin(_flicker * 17.0) * sin(_flicker * 7.3)
	var rng := lerpf(10.0, 13.5, k)
	var en := lerpf(1.6, 2.4, k) * fl
	if stats.has("dim_lantern"):
		rng *= 0.55
		en *= 0.8
	lantern.omni_range = rng
	lantern.light_energy = en
	var side := 1.0 if aim.x >= 0.0 else -1.0
	lantern.position = Vector3(0.3 * side, (1.05 + bob) * Iso.SQ2, 0.3)


## A footstep each time a foot lands in the run cycle (frames 0 and 3 of 6),
## so the sound always matches the feet. Moss in the Rootmire, stone elsewhere.
func _footsteps() -> void:
	if sprite == null or not sprite.anim.begins_with("run_"):
		_last_foot = -1
		return
	var f := sprite.frame_i
	if f != _last_foot and (f == 0 or f == 3):
		var moss := stage is Dungeon and (stage as Dungeon).layout.region == "rootmire"
		var n := 3 if moss else 4
		Audio.play("step_%s_%d" % ["moss" if moss else "stone", _foot_i % n], -11.0, randf_range(0.94, 1.06))
		_foot_i += 1 + (randi() % 2)
	_last_foot = f


func _update_anim() -> void:
	if not alive:
		return
	var ad := aim
	if absf(ad.x) > absf(ad.y) * 0.85:
		dir_name = "side"
	elif ad.y < 0.0:
		dir_name = "up"
	else:
		dir_name = "down"
	var a := "idle_"
	if dodge_t > 0.0:
		a = "dash_"
	elif hurt_t > 0.0:
		a = "hurt_"
	elif cast_t > 0.0 or ward_t > 0.0 or flask_t > 0.0:
		a = "cast_"
	elif vel.length() > 0.4:
		a = "run_"
	sprite.play(a + dir_name)
	sprite.flip_h = dir_name == "side" and ad.x < 0.0
	if a == "run_":
		sprite.speed_scale = clampf(vel.length() / 6.0, 0.6, 1.4)
	else:
		sprite.speed_scale = 1.0
	if invuln_t > 0.0 and dodge_t <= 0.0 and hurt_t <= 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0:
		sprite.set_tint(Color(1, 1, 1, 0.55))
	else:
		sprite.set_tint(Color(1, 1, 1, 1))


func sync_visual() -> void:
	super.sync_visual()
	if sprite and alive:
		sprite.flip_h = dir_name == "side" and aim.x < 0.0


func _update_aegis_fx() -> void:
	if aegis_t > 0.0:
		if _aegis_fx == null or not is_instance_valid(_aegis_fx):
			_aegis_fx = stage.fx.shape(Fx.Shape.SIGIL, pos, Vector2.RIGHT, Vector2(2.6, 2.6), Color(1.0, 0.85, 0.45, 0.4), Color(1.0, 0.92, 0.6, 1.0), -1.0, {"glow": 1.5})
		var t := _aegis_fx.transform
		t.origin = Iso.to_world(pos, 0.0) + Vector3(0, 0.02, 0)
		_aegis_fx.transform = t
		_aegis_fx.set_instance_shader_parameter("progress", stage.elapsed * 0.3)
	elif _aegis_fx != null and is_instance_valid(_aegis_fx):
		_aegis_fx.queue_free()
		_aegis_fx = null


## Persists run-relevant state (between depths).
func store_to(r: RunState) -> void:
	r.hp = hp
	r.kindle = kindle
	r.flask = flask
	r.second_wind_used = second_wind_used
	r.phoenix_used = phoenix_used
