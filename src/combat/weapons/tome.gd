## Emberwright's Tome: a spellcaster's weapon. Hold to read from it: a stream
## of seeking motes of hearth-script flies at the foes before you. Every mote
## that lands hurries your spells (shorter cooldowns). Casting a spell writes
## its element into the next pages: the following motes burn, chill or expose,
## and hit harder. No charged attack - the Tome is about the spells.
extends Weapon

const MOTE_GAP := 0.2         # seconds between motes while reading
const COOLDOWN_PER_HIT := 0.12
var _gap := 0.0
var inscribed := ""          # the element written by the last spell
var inscribed_n := 0         # motes left that carry it
var _n := 0


func max_combo() -> int:
	return 1


func can_charge() -> bool:
	return false


func move_mult() -> float:
	return 0.7 if held else 1.0


func update(dt: float) -> void:
	_gap = maxf(0.0, _gap - dt)
	if held and _gap <= 0.0 and player.alive:
		_gap = MOTE_GAP / speed()
		_mote()
	super.update(dt)
	swing = 0.0
	if visual:
		var c := _element_color()
		visual.set_instance_shader_parameter("flash", Color(c.r, c.g, c.b, (0.5 if inscribed_n > 0 else 0.0) + (0.25 if held else 0.0)))


func begin_combo() -> void:
	pass       # reading happens while the button is held (update)


func press() -> void:
	held = true
	hold_t = 0.0
	# a tap reads one word at once; holding keeps reading
	if _gap <= 0.0 and player.alive:
		_gap = MOTE_GAP / speed()
		_mote()


func release() -> void:
	held = false


## Called by the Kindled after casting a spell: the Tome takes its element.
func inscribe(ability: String) -> void:
	var tags: Array = []
	match ability:
		"flare", "cinder_lance":
			tags = ["fire"]
		"frost_sigil":
			tags = ["frost"]
		"gloamstep":
			tags = ["shadow"]
		_:
			tags = []
	var runes := Runes.of(player, ability)
	if runes.has("rime"):
		tags = ["frost"]
	elif runes.has("gloam"):
		tags = ["shadow"]
	inscribed = String(tags[0]) if not tags.is_empty() else "ember"
	inscribed_n = 10 if ascended() else 6
	player.stage.fx.ring(player.pos, 1.0, _element_color(), 0.25, 0.2)


func _element_color() -> Color:
	match inscribed:
		"fire":
			return Color(1.0, 0.55, 0.25)
		"frost":
			return Color(0.6, 0.85, 1.0)
		"shadow":
			return Color(0.7, 0.45, 0.95)
	return Color(1.0, 0.9, 0.7)


func _mote() -> void:
	var st := player.stage
	_n += 1
	var d := player.aim.rotated(deg_to_rad(randf_range(-6.0, 6.0)))
	var target := st.nearest_hostile(player.team, player.pos + player.aim * 4.0, 7.0, true)
	var big := masterwork() and _n % 5 == 0
	var element := inscribed if inscribed_n > 0 else ""
	if inscribed_n > 0:
		inscribed_n -= 1
	var pr := Projectile.create(st, "proj_mote", player.pos + d * 0.5, d * 13.0 * player.stats.v("projectile_speed"), player.team)
	pr.source = player
	pr.damage = def.damage[0] * damage_scale() * (1.4 if element != "" else 1.0) * (2.0 if big else 1.0)
	pr.tags = ["ranged"] + ([element] if element in ["fire", "frost", "shadow"] else [])
	pr.radius = 0.2 if not big else 0.35
	pr.life = 1.0
	pr.height = 0.7
	pr.knockback = 1.0
	pr.reflectable = false
	pr.pierce = 1 if tempered() else 0
	pr.homing_target = target
	pr.homing_turn = 6.0
	var col := _element_color() if element != "" else Color(1.0, 0.9, 0.7)
	pr.trail_color = col
	pr.trail_rate = 28.0
	pr.with_light(col, 0.5 if not big else 1.2, 2.0)
	if pr.sprite:
		pr.sprite.set_tint(col.lightened(0.2))
	pr.make_hit_fn = func(proj: Projectile, _t: Actor) -> Hit:
		var h := Combat.player_hit(player, player.stats, proj.damage, proj.tags.duplicate())
		h.knockback = proj.vel.normalized() * proj.knockback
		h.from_dir = proj.vel.normalized()
		h.poise = 4.0
		match element:
			"fire":
				h.burn = 1
			"frost":
				h.chill = 0.18
			"shadow":
				h.expose = 1.0
		return h
	pr.on_hit_fn = func(proj: Projectile, _t: Actor, _res) -> void:
		# each word that lands hurries the spells
		for i in player.ability_cd.size():
			player.ability_cd[i] = maxf(0.0, player.ability_cd[i] - COOLDOWN_PER_HIT)
		player.gain_kindle(1.5)
		if big:
			_glyph_burst(proj.pos, proj.damage * 0.6, col)
	if _n % 2 == 0:
		Audio.play("orb", -12.0, randf_range(1.6, 1.9))
	player.on_weapon_strike(0, false)


## Masterwork: every fifth mote is a glyph that bursts where it lands.
func _glyph_burst(at: Vector2, dmg: float, col: Color) -> void:
	var st := player.stage
	st.fx.ring(at, 1.6, col, 0.2, 0.25)
	st.fx.burst(at, 0.6, col, 10, 3.5, 0.3, 0.0)
	for a in st.in_circle(player.team, at, 1.6):
		var h := Combat.player_hit(player, player.stats, dmg, ["ranged"])
		h.proc = false
		h.knockback = (a.pos - at).normalized() * 3.0
		player.deal_hit(a, h)
