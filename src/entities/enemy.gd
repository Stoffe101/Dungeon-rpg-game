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
var affix2 := ""   # from Tier IV, elites carry a second affix
var summoned := false   # raised or called by another enemy
var _voice_t := 0.0
var _attack_voice_t := 0.0
var _idle_voice_t := 4.0
var grudge: Dictionary = {}
var state := "spawn"
var state_t := 0.0
var spawn_t := 0.7
var speed := 2.5
var damage := 10.0
var attack_rate := 1.0
var tempo := 1.0             # a party's guardian rests less between attacks (Dungeon._coop_scale):
                             # its cooldowns run faster, its wind-ups (and their telegraphs) do not
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
var _trail_t := 0.0
var _aura_t := 0.0
var _gloom_light: OmniLight3D
const GLOOM_R := 4.0
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
func scale_for(depth: int, memory: int, tier := 1) -> void:
	var m := 1.0 + 0.22 * float(depth - 1) + 0.12 * float(memory)
	max_hp *= m * Difficulty.hp_mult(tier)
	hp = max_hp
	damage *= (1.0 + 0.12 * float(depth - 1) + 0.08 * float(memory)) * Difficulty.damage_mult(tier)
	# higher tiers also stagger less and pay more
	max_poise *= 1.0 + 0.08 * float(tier - 1)
	poise = max_poise
	var rm := Difficulty.reward_mult(tier)
	xp = int(round(xp * rm))
	embers = int(round(embers * rm))


## A creature's voice from its data ("voice": kind, "voice_pitch"): v_<kind>_<event>
## for attack, hurt, die, idle, jump and land. Elites sound bigger.
func voice(event: String, vol := -8.0) -> void:
	var v := String(def.get("voice", ""))
	if v == "" or stage == null:
		return
	var pitch := float(def.get("voice_pitch", 1.0)) * randf_range(0.94, 1.06) * (0.88 if elite else 1.0)
	if def.get("boss", false):
		vol += 4.0
	Audio.play_at("v_%s_%s" % [v, event], pos, vol, pitch, 90)


func has_affix(a: String) -> bool:
	return affix == a or affix2 == a


func make_elite(a: String, second := "") -> void:
	elite = true
	affix = a
	max_hp *= 2.3
	hp = max_hp
	max_poise *= 1.6
	poise = max_poise
	xp *= 3
	embers *= 3
	_apply_affix(a)
	if second != "" and second != a:
		affix2 = second
		_apply_affix(second)


func _apply_affix(a: String) -> void:
	match a:
		"hasted":
			speed *= 1.4
			attack_rate = 1.4
		"warded":
			shield_max = max_hp * 0.45
			shield = shield_max
		"gloom":
			# a light that takes light away: the room darkens around it
			_gloom_light = OmniLight3D.new()
			_gloom_light.light_negative = true
			_gloom_light.light_color = Color(0.9, 0.85, 1.0)
			_gloom_light.light_energy = 0.7
			_gloom_light.omni_range = GLOOM_R + 0.5
			_gloom_light.position = Vector3(0, 0.8, 0)
			# ...but its own violet eyes still show where it is
			var eyes := OmniLight3D.new()
			eyes.light_color = Color(0.65, 0.45, 1.0)
			eyes.light_energy = 1.4
			eyes.omni_range = 2.2
			eyes.position = Vector3(0, 1.4, 0.5)
			_gloom_light.add_child(eyes)
			if visual:
				visual.add_child(_gloom_light)


func make_grudge(g: Dictionary) -> void:
	grudge = g
	if not elite:
		make_elite(String(g.get("affix", "hasted")), String(g.get("affix2", "")))
	var lvl := int(g.get("level", 1))
	max_hp *= 1.0 + 0.3 * lvl
	hp = max_hp
	damage *= 1.0 + 0.12 * lvl
	if (g.get("traits", []) as Array).has("ember_fed"):
		# every 50 Embers it carries makes it hit a little harder
		damage *= 1.0 + minf(0.5, 0.05 * floorf(int(g.get("embers", 0)) / 50.0))
	display_name = String(g.get("name", display_name))
	_grudge_cd = 4.0


# --- a Grudge is not an elite with a name: it remembers how you fought ------------

var grudge_ward_t := 0.0     # its red ward is up: your blows land at less than half
var _grudge_cd := 4.0
var _spoor_t := 0.0
var _wound_checked := false
const GRUDGE_RED := Color(1.0, 0.32, 0.25)


## The red brand over a Grudge: it grows with every level. Every machine draws it.
func _brand() -> void:
	var b := PixelSprite.new()
	visual.add_child(b)
	b.setup("grudge_brand", "l%d" % clampi(int(grudge.get("level", 1)), 1, 5))
	b.material_override = null
	var h := float(sprite.sheet.frame_size.y) * Iso.TEXEL * 0.92
	b.position = Vector3(0, h * Iso.SQ2 + 0.1, 0.02)


func _grudge_tick(dt: float) -> void:
	grudge_ward_t = maxf(0.0, grudge_ward_t - dt)
	_spoor_t -= dt
	if _spoor_t <= 0.0:
		_spoor_t = 0.22
		stage.fx.motes(pos, 0.5, GRUDGE_RED, 1, 0.4, 0.9, 0.2)
	if state == "spawn" or not alive:
		return
	# hurt badly and grown enough to know when to run: it flees, once an expedition
	if int(grudge.get("level", 1)) >= 2 and hp < max_hp * 0.3 and stage is Dungeon and not _wound_checked:
		_wound_checked = true
		if (stage as Dungeon).grudge_flees(self):
			return
	_grudge_cd -= dt
	if _grudge_cd > 0.0 or target() == null:
		return
	if String(grudge.get("learned", "ward")) == "closer":
		var t := target()
		var d := t.pos.distance_to(pos)
		if d > 4.0 and d < 16.0:
			_grudge_cd = 6.5
			var at := stage.foe_spot(t.pos + (pos - t.pos).normalized() * 1.3, 0.5, room_id)
			telegraph(Fx.Shape.DISC, at, Vector2.RIGHT, Vector2(2.4, 2.4), 0.8)
			stage.after(0.8, func() -> void:
				if is_instance_valid(self) and alive:
					stage.fx.burst(pos, 0.8, GRUDGE_RED, 16, 3.0, 0.4, 2.0)
					pos = at
					stage.fx.ring(at, 2.2, GRUDGE_RED, 0.3, 0.25)
					Audio.play_at("gate_flare", at, -10.0, 1.6)
					strike_arc(at, Vector2.RIGHT, 1.3, PI, damage * 0.8, 3.0))
		else:
			_grudge_cd = 1.0
	else:
		_grudge_cd = 7.5
		grudge_ward_t = 1.8
		stage.fx.ring(pos, 1.8, GRUDGE_RED, 1.8, 0.2)
		stage.fx.number(pos, 2.4, "WARDED", GRUDGE_RED)
		if sprite:
			sprite.flash(GRUDGE_RED, 0.4)
		Audio.play_at("grudge_ward", pos, -7.0)


func _ready() -> void:
	team = Team.ENEMY
	build_visual(def.sheet, "idle")
	sprite.set_dissolve(1.0)
	if (elite or not grudge.is_empty()) and not def.get("boss", false):
		_make_nameplate()
	if not grudge.is_empty():
		_brand()
	if _gloom_light and _gloom_light.get_parent() == null:
		visual.add_child(_gloom_light)
	state = "spawn"
	state_t = 0.0


func hit_color() -> Color:
	return Color(0.88, 0.84, 0.74)


var _tgt: Player
var _tgt_t := 0.0
var last_player: Player     # who hit it last (on-kill credit, aggro)


## The Kindled this foe is after: the nearest one, kept for a while so it does
## not flicker between players, and turned on whoever hits it hard.
func target() -> Player:
	if _tgt and is_instance_valid(_tgt) and _tgt.alive and not _tgt.downed and _tgt_t > 0.0:
		return _tgt
	_tgt_t = randf_range(1.0, 1.6)
	var ps: Array = stage.active_players()
	_tgt = stage.nearest_player(pos) if ps.size() <= 1 else _party_target(ps)
	return _tgt


## In a party, foes share themselves out instead of all falling on whoever
## stands nearest (which left the rest of the party free - why bigger
## parties took far less per Kindled): a Kindled already pressed by others
## is less inviting, one standing alone is prey (flankers most of all), and
## ranged and support foes care little for distance, so the back line is
## pressed too. A foe keeps its target unless another is clearly better.
func _party_target(ps: Array) -> Player:
	var role := String(def.get("role", ""))
	var reach := role in ["ranged", "artillery", "beam", "support", "summoner", "controller"]
	var flanker := role in ["harrier", "charger", "swarm", "ambush"]
	var foes := stage.hostiles(Team.PLAYER)
	var best: Player = null
	var bs := INF
	for p: Player in ps:
		var s := pos.distance_to(p.pos) * (0.45 if reach else 1.0)
		var pressed := 0
		for o in foes:
			if o != self and o is Enemy and (o as Enemy)._tgt == p and o.alive:
				pressed += 1
		s += 1.6 * pressed
		var alone := true
		for q: Player in ps:
			if q != p and q.pos.distance_to(p.pos) < 4.0:
				alone = false
				break
		if alone:
			s -= 1.5 if flanker else 0.8
		if p == _tgt:
			s -= 1.5
		if s < bs:
			bs = s
			best = p
	return best if best else stage.nearest_player(pos)


func set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
		tele = null


func tick(dt: float) -> void:
	_tgt_t -= dt
	_voice_t -= dt
	_attack_voice_t -= dt
	_idle_voice_t -= dt
	if _idle_voice_t <= 0.0:
		_idle_voice_t = randf_range(5.0, 11.0)
		if state != "spawn" and alive and stage.nearest_player(pos, 11.0) != null:
			voice("idle", -15.0)
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
	if has_affix("phasing"):
		_phase_t += dt
		var cyc := fmod(_phase_t, 4.5)
		var phased := cyc > 3.4
		targetable = not phased
		sprite.set_tint(Color(1, 1, 1, 0.35 if phased else 1.0))
	super.tick(dt)
	_tell()
	_update_bar(dt)
	_wildfire(dt)
	if elite and alive:
		_affix_tick(dt)


var _seen_hp := -1.0


## Co-op client: the picture of a foe the host simulates. It rises out of the
## dark as it does on the host (it starts fully dissolved: without this a
## guest saw only its shadow), and keeps its health bar, nameplate and a
## phasing foe's fade, which the host's simulation step would otherwise draw.
func replica_present(dt: float) -> void:
	if state == "spawn":
		state_t += dt
		var k := clampf(state_t / maxf(spawn_t, 0.01), 0.0, 1.0)
		sprite.set_dissolve(1.0 - k)
		if k >= 1.0:
			state = "idle"
	if _seen_hp >= 0.0 and hp < _seen_hp - 0.01:
		_hb_show_t = 3.0
	_seen_hp = hp
	if has_affix("phasing"):
		sprite.set_tint(Color(1, 1, 1, 1.0 if targetable else 0.35))
	_tell()
	_update_bar(dt)
	super.replica_present(dt)


## States in which a blow may show its drawn flinch (never over a wind-up or
## an attack: a telegraph must stay readable).
const FLINCH_STATES := ["idle", "chase", "float", "orbit", "wander", "kite", "walk", "hover", "circle", "approach", "stunned", "recover"]
var _flinch_t := 0.0


func hit_react(dir: Vector2, power := 1.0) -> void:
	super.hit_react(dir, power)
	if sprite and sprite.has_anim("hurt") and state in FLINCH_STATES and not def.get("boss", false):
		_flinch_t = 0.16


const SHEPHERD_R := 5.0
const SHEPHERD_EVERY := 6.5
var _frenzy := false
var _shep_t := 3.0


## Frenzied: at half health it erupts (once) - faster, and it strikes faster.
func _check_frenzy() -> void:
	if _frenzy or not has_affix("frenzied") or not alive or hp > max_hp * 0.5:
		return
	_frenzy = true
	speed *= 1.4
	attack_rate *= 1.35
	stage.fx.ring(pos, 1.6, Color(1.0, 0.35, 0.3), 0.3, 0.3)
	stage.fx.burst(pos, 0.8, Color(1.0, 0.3, 0.25), 18, 4.0, 0.4, 0.0)
	stage.fx.number(pos, 2.4, "FRENZY", Color(1.0, 0.45, 0.4), true)
	Audio.play_at("frenzy", pos, -2.0)
	voice("attack", -4.0)


## Shepherd: soul-light gathers (a ring warns), then every foe around is shielded.
func _shepherd(dt: float) -> void:
	_shep_t -= dt
	if _shep_t > 0.0:
		return
	_shep_t = SHEPHERD_EVERY
	var col := Color(0.5, 0.95, 0.85)
	var warn := stage.fx.shape(Fx.Shape.DISC, pos, Vector2.RIGHT, Vector2(SHEPHERD_R * 2.0, SHEPHERD_R * 2.0), Color(col.r, col.g, col.b, 0.12), Color(col.r, col.g, col.b, 0.8), 0.9, {"progress": 1.0, "glow": 1.4})
	begin_tell(0.85)
	var me := self
	stage.after(0.85, func() -> void:
		if not is_instance_valid(me) or not me.alive:
			return
		me.stage.fx.ring(me.pos, SHEPHERD_R, col, 0.35, 0.3)
		Audio.play_at("shepherd", me.pos, -3.0)
		for a in me.stage.actors:
			if a is Enemy and a != me and a.alive and a.pos.distance_to(me.pos) <= SHEPHERD_R:
				var e := a as Enemy
				e.shield_max = maxf(e.shield_max, e.max_hp * 0.25)
				e.shield = maxf(e.shield, e.max_hp * 0.25)
				me.stage.fx.motes(e.pos, 0.6, col, 6, 1.0, 0.6, 0.3))


## The affixes that change how a fight plays, every frame.
func _affix_tick(dt: float) -> void:
	if has_affix("shepherd"):
		_shepherd(dt)
	if has_affix("molten") and vel.length() > 0.5:
		_trail_t -= dt
		if _trail_t <= 0.0:
			_trail_t = 0.3
			_molten_patch(stage, pos, damage * 0.2)
	if has_affix("gloom"):
		for pl in stage.players_near(pos, GLOOM_R):
			pl.gloom_t = 0.25
		_aura_t -= dt
		if _aura_t <= 0.0:
			_aura_t = 0.1
			var p := pos + Vector2.from_angle(randf() * TAU) * randf_range(0.4, GLOOM_R * 0.8)
			stage.fx.motes(p, 0.1, Color(0.55, 0.4, 0.85), 1, 0.8, 1.0, 0.2)


## A patch of burning ground; static so it outlives the one who left it.
static func _molten_patch(st: Stage, p: Vector2, dmg: float) -> void:
	var hz := Hazard.spawn(st, p, 0.6, 2.6, Team.ENEMY, Color(1.0, 0.45, 0.12), func(_h: Hazard, a: Actor) -> void:
		if a is Player:
			var h := Hit.make(null, dmg, ["fire", "dot"])
			h.can_crit = false
			h.silent = true
			(a as Player).take_enemy_hit(h, null))
	hz.period = 0.45
	hz.particle_rate = 3.0


## Wildfire (Pyre notable): burning foes pass their flames to a neighbour.
func _wildfire(dt: float) -> void:
	if not alive or not status.burning():
		_wildfire_t = 0.0
		return
	var pl: Player = null
	for p in stage.players:
		if p.alive and p.stats.has("wildfire"):
			pl = p
	if pl == null:
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
	if not grudge.is_empty():
		_grudge_tick(dt)
	behave(dt)
	if _flinch_t > 0.0:
		_flinch_t -= dt
		if state in FLINCH_STATES:
			sprite.play("hurt")     # (sent on in snapshots: every screen shows it)


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
	if _attack_voice_t <= 0.0:
		_attack_voice_t = 0.8
		voice("attack", -7.0)
	var p := params.duplicate()
	p["progress"] = 0.0
	Net.mute += 1
	tele = stage.fx.shape(kind, center, dir, size, TELE_COLOR, TELE_EDGE, duration + 0.05, p)
	Net.mute -= 1
	if Net.recording:
		var tid := Net.i.run_sync.next_proj_id()
		tele.set_meta("tid", tid)
		Net.rec(["tele", tid, kind, center, dir, size, duration, params, net_id])
	begin_tell(duration)
	var dur := duration
	var start := stage.elapsed
	var st := stage
	var data: Dictionary = stage.fx._shapes[stage.fx._shapes.size() - 1]
	data.update = func(_t: float, n: MeshInstance3D) -> void:
		var k := clampf((st.elapsed - start) / maxf(dur, 0.01), 0.0, 1.0)
		n.set_instance_shader_parameter("progress", k)


var _tell_start := -99.0
var _tell_dur := 0.0


## Its body tells the blow coming, not only the ground: it glows ever redder
## through the wind-up and flashes pale as the blow lands - in a crowd, the
## one about to strike stands out. (Co-op guests: NetRun._tele starts it.)
# --- attack tokens ----------------------------------------------------------------
# A crowd takes turns: at most STRIKERS foes wind up a melee blow on one
# Kindled at once (and SHOOTERS a shot), so four claws never close at the same
# instant with no way out. A foe refused a turn keeps closing in and asks
# again; an elite always takes a turn (it still counts, so the rank and file
# wait on it); a guardian has its own patterns and is not counted.

const STRIKERS := 2
const SHOOTERS := 2
const TURN_TIME := 1.1             # how long a turn lasts (a wind-up and its blow)
var _turn_target: Actor = null
var _turn_kind := ""
var _turn_until := -1.0


## May this foe begin an attack of `kind` ("melee" or "ranged") on its target
## now? Takes the turn if so.
func may_strike(kind := "melee") -> bool:
	var t := target()
	if t == null or def.get("boss", false):
		return true
	if not elite:
		var n := 0
		for a in stage.actors:
			if a == self or not (a is Enemy) or not a.alive:
				continue
			var o := a as Enemy
			if o._turn_target == t and o._turn_kind == kind and stage.elapsed < o._turn_until:
				n += 1
		if n >= (STRIKERS if kind == "melee" else SHOOTERS):
			return false
	_turn_target = t
	_turn_kind = kind
	_turn_until = stage.elapsed + TURN_TIME / maxf(0.5, attack_rate)
	return true


func begin_tell(duration: float) -> void:
	_tell_start = stage.elapsed
	_tell_dur = maxf(duration, 0.05)


func _tell() -> void:
	if sprite == null:
		return
	var t := stage.elapsed - _tell_start
	if t < 0.0 or t > _tell_dur + 0.15:
		if sprite.highlight.a > 0.0:
			sprite.highlight.a = 0.0
		return
	var k := clampf(t / _tell_dur, 0.0, 1.0)
	if t > _tell_dur:
		sprite.highlight = Color(1.0, 0.95, 0.85, 0.55 * (1.0 - (t - _tell_dur) / 0.15))
	elif k > 0.82:
		sprite.highlight = Color(1.0, 0.55, 0.5, 0.45 + 0.2 * sin(t * 60.0))
	else:
		sprite.highlight = Color(1.0, 0.25, 0.3, 0.08 + 0.32 * k * k)


func make_hit(amount: float, from: Vector2, kb := 5.0) -> Hit:
	var h := Hit.make(self, amount, ["melee"])
	h.can_crit = false
	var t := target()
	var d := (t.pos - from).normalized() if t else Vector2.RIGHT
	h.knockback = d * kb
	h.from_dir = d
	return h


## A foe's blow lands on every Kindled inside what its telegraph showed (it
## used to strike only the one it chose: a slam drawn over two players hurt
## one, and standing together looked safer than it was). The ground flashes
## where it lands.
func strike_circle(center: Vector2, r: float, amount: float, kb := 5.0) -> bool:
	_strike_flash(Fx.Shape.DISC, center, Vector2.RIGHT, Vector2(r * 2.0, r * 2.0), {})
	var any := false
	for t in stage.active_players():
		if t.pos.distance_to(center) <= r + t.radius:
			t.take_enemy_hit(_hit_on(t, amount, center, kb), self)
			any = true
	return any


func strike_arc(origin: Vector2, dir: Vector2, r: float, half: float, amount: float, kb := 5.0) -> bool:
	_strike_flash(Fx.Shape.CONE, origin, dir, Vector2(r * 2.0, r * 2.0), {"half_angle": half})
	var any := false
	for t in stage.active_players():
		var to := t.pos - origin
		if to.length() > r + t.radius:
			continue
		if to.length() > 0.5 and absf(dir.angle_to(to)) > half + 0.15:
			continue
		t.take_enemy_hit(_hit_on(t, amount, origin, kb), self)
		any = true
	return any


func strike_line(origin: Vector2, dir: Vector2, length: float, width: float, amount: float, kb := 5.0) -> bool:
	_strike_flash(Fx.Shape.RECT, origin, dir, Vector2(length, width), {})
	var any := false
	for t in stage.active_players():
		var q := Geometry2D.get_closest_point_to_segment(t.pos, origin, origin + dir * length)
		if q.distance_to(t.pos) <= width * 0.5 + t.radius:
			t.take_enemy_hit(_hit_on(t, amount, origin, kb), self)
			any = true
	return any


## The blow on one Kindled: knocked away from where it came from.
func _hit_on(t: Player, amount: float, from: Vector2, kb: float) -> Hit:
	var h := Hit.make(self, amount, ["melee"])
	h.can_crit = false
	var d := (t.pos - from).normalized() if t.pos.distance_to(from) > 0.05 else (t.pos - pos).normalized()
	h.knockback = d * kb
	h.from_dir = d
	return h


## The moment a telegraphed blow lands: its shape flashes pale for a breath.
func _strike_flash(kind: int, at: Vector2, dir: Vector2, size: Vector2, params: Dictionary) -> void:
	var p := params.duplicate()
	p["progress"] = 1.0
	p["glow"] = 1.5
	stage.fx.shape(kind, at, dir, size, Color(1.0, 0.85, 0.8, 0.28), Color(1.0, 0.95, 0.9, 0.9), 0.09, p)


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
	var src: Variant = hit.source
	if src is Player:
		last_player = src
		# a heavy blow from someone else turns it on them
		if _tgt != src and res.amount > max_hp * 0.08:
			_tgt = src
			_tgt_t = 2.5
	_hb_show_t = 3.0
	if elite:
		_check_frenzy()
	if alive and _voice_t <= 0.0 and res.amount > 0.0:
		_voice_t = 0.45
		voice("hurt", -9.0)
	if state == "idle" or state == "wander":
		set_state("idle")


## Its health bar and nameplate live in the view's overlay, not under the foe:
## they go with it however it goes (a co-op guest's foes never run die()).
func _clear_overlay() -> void:
	if bar and is_instance_valid(bar):
		bar.queue_free()
	bar = null
	if nameplate and is_instance_valid(nameplate):
		nameplate.queue_free()
	nameplate = null


func _exit_tree() -> void:
	_clear_overlay()


func replica_die() -> void:
	_clear_overlay()
	super.replica_die()


func die(killer: Node) -> void:
	if not alive:
		return
	if tele and is_instance_valid(tele):
		stage.fx.release(tele)
	# on-kill effects belong to whoever landed it (co-op: not always this machine's Kindled)
	var pl: Player = killer as Player if killer is Player else (last_player if is_instance_valid(last_player) else stage.player)
	var by_player := killer is Player or (killer is Actor and (killer as Actor).team == Team.PLAYER) or hit_by_player
	super.die(killer)
	if bar:
		bar.queue_free()
	if nameplate:
		nameplate.queue_free()
	died_enemy.emit(self)
	Audio.play("enemy_die", -3.0, randf_range(0.9, 1.1))
	voice("die", -6.0)
	stage.fx.burst(pos, 0.6, hit_color(), 12, 4.0, 0.6, 9.0, last_hit_from, 1.4)
	# what's left on the floor: a splat in the enemy's colour, or scorch if it burned
	var mark := hit_color().darkened(0.45) if not status.burning() else Color(0.16, 0.12, 0.11)
	stage.fx.splat(pos + last_hit_from * 0.35, mark, 26.0, 1.0 + radius * 0.6)
	stage.fx.motes(pos, 0.3, Color(0.35, 0.95, 0.85), 6, 1.5, 0.9, 0.3)
	if elite:
		# champions go out with a crack of soul-light
		stage.fx.ring(pos, 1.8, Color(0.55, 1.0, 0.9), 0.35, 0.3)
		stage.fx.flash_light(pos, 1.0, Color(0.5, 1.0, 0.9), 3.0, 5.0, 0.35)
		stage.fx.burst(pos, 0.8, Color(0.6, 1.0, 0.92), 18, 6.0, 0.7, 4.0)
		stage.fx.shake(0.3)
	if pl and by_player:
		var st := pl.stats
		if pl.hearthfire_t > 0.0 and st.has("hearthforged") and pl.hearthfire_bonus < 5.0:
			# Hearthforged: every foe felled feeds the form a second
			pl.hearthfire_t += 1.0
			pl.hearthfire_bonus += 1.0
		if st.v("life_on_kill") > 0.0:
			pl.heal(st.v("life_on_kill"))
		if st.v("kindle_on_kill") > 0.0:
			pl.gain_kindle(st.v("kindle_on_kill") / maxf(st.v("kindle_gain"), 0.01))
		if st.has("combustion") and status.burning():
			_combust(pl)
		if st.has("kindle_refund") and last_hit_tags.has("ability"):
			pl.gain_kindle(12.0 / maxf(st.v("kindle_gain"), 0.01))
		if st.has("verdant_set4"):
			_spore_burst(pl)
		if st.has("shatter") and status.is_frozen():
			_shatter(pl)
	if has_affix("volatile"):
		_volatile_burst()
	if has_affix("splitting") and not summoned and not def.get("boss", false):
		_split()


## Splitting: two lesser copies climb out of the remains.
func _split() -> void:
	var st := stage
	var at := pos
	var kind := id
	var hp_each := max_hp * 0.2
	var dmg := damage * 0.75
	var room := room_id
	var side := last_hit_from.orthogonal() if last_hit_from != Vector2.ZERO else Vector2.UP
	st.fx.burst(at, 0.6, Color(0.6, 0.95, 0.5), 16, 4.0, 0.5, 6.0)
	st.fx.number(at, 2.4, "SPLIT", Color(0.6, 0.95, 0.5))
	if st.has_method("hold_clear"):
		st.hold_clear(0.4)
	st.after(0.15, func() -> void:
		for k in 2:
			var e: Enemy = load(EnemyDB.get_def(kind).script).new()
			e.configure(kind)
			e.summoned = true
			e.max_hp = hp_each
			e.hp = hp_each
			e.damage = dmg
			e.xp = 2
			e.embers = 1
			e.spawn_t = 0.3
			e.pos = st.foe_spot(at + side * (0.7 if k == 0 else -0.7), 0.4)
			e.room_id = room
			st.add_actor(e)
			if e.visual:
				e.visual.scale = Vector3.ONE * 0.8
			if st.has_method("register_enemy"):
				st.register_enemy(e))


## Verdant Warden 4pc: a kill heals and bursts into poisoning spores.
func _spore_burst(pl: Player) -> void:
	pl.hp = minf(pl.max_hp, pl.hp + pl.max_hp * 0.03)
	stage.fx.burst(pos, 0.5, Color(0.55, 0.95, 0.45), 14, 3.0, 0.7, -1.0)
	stage.fx.ring(pos, 2.0, Color(0.55, 0.95, 0.45), 0.35, 0.2)
	for a in stage.in_circle(pl.team, pos, 2.0):
		var h := Combat.player_hit(pl, pl.stats, 14.0, ["dot"])
		h.can_crit = false
		h.proc = false
		pl.deal_hit(a, h)


func _combust(pl: Player) -> void:
	var p := pos
	var stacks := status.burn_stacks
	stage.fx.ring(p, 2.4, Color(1.0, 0.55, 0.2), 0.25, 0.35)
	stage.fx.burst(p, 0.5, Color(1.0, 0.6, 0.2), 22, 6.0, 0.45, 2.0)
	stage.fx.flash_light(p, 0.6, Color(1.0, 0.55, 0.2), 3.0, 5.0, 0.3)
	Audio.play("explode", -3.0, 1.15)
	stage.strike_props_circle(p, 2.4, pl, true)
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
		for pl in st.players_near(p, 2.5):
			var h := Hit.make(null, dmg, ["fire"])
			h.can_crit = false
			h.knockback = (pl.pos - p).normalized() * 7.0
			pl.take_enemy_hit(h, null))


# --- overlay UI ----------------------------------------------------------------------

## A room's named foe: its own title over it, and a head taller. Every machine
## does this (the host in Dungeon._champion, a guest from the replica's record).
func crown(title: String) -> void:
	display_name = title
	set_meta("champion", title)
	if visual:
		visual.scale = Vector3.ONE * 1.25
	if nameplate == null:
		_make_nameplate()
	if nameplate:
		nameplate.text = title
		nameplate.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))


func _make_nameplate() -> void:
	if stage.view == null:
		return
	nameplate = Label.new()
	nameplate.add_theme_font_override("font", Fx.FONT_OUTLINE)
	nameplate.add_theme_font_size_override("font_size", 8)
	var col: Color = EnemyDB.AFFIXES.get(affix, {}).get("color", Color(1, 0.8, 0.4))
	if not grudge.is_empty():
		col = Color(1.0, 0.45, 0.35)
		var owner := int(grudge.get("owner", 0))
		var whose := ("  (%s's)" % Net.name_of(owner)) if owner != 0 and Net.active() and Net.party_size() > 1 else ""
		var marks := int(grudge.get("scars", 0))
		nameplate.text = "%s  Lv%d%s%s" % [display_name, int(grudge.get("level", 1)), ("  scarred x%d" % marks) if marks > 0 else "", whose]
	else:
		nameplate.text = "%s %s" % [EnemyDB.AFFIXES[affix].name, display_name]
		if affix2 != "":
			nameplate.text = "%s %s %s" % [EnemyDB.AFFIXES[affix].name, EnemyDB.AFFIXES[affix2].name, display_name]
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
