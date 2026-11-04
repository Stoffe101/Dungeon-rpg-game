## Emberwright's Tome: a spellcaster's weapon. Hold to read from it: a stream
## of seeking motes of hearth-script flies at the foes before you. Every mote
## that lands hurries your spells (shorter cooldowns). Casting a spell writes
## its element into the next pages: the following motes burn, chill or expose,
## and hit harder. No charged attack - the Tome is about the spells.
extends Weapon

const MOTE_GAP := 0.2         # seconds between motes while reading
const COOLDOWN_PER_HIT := 0.12
## Forms (ItemDB "form"):
##   echo (Codex of Echoes) - reading writes glyphs that circle the Kindled (up
##     to three) and strike whatever they pass; casting a spell with all three
##     written spends them to cast it again, a breath later, at 45%.
##   ash (Grimoire of Ash) - reading breathes fire: a short cone that burns all
##     before it (the inscribed element changes the breath: frost chills,
##     shadow exposes).
const GLYPHS := 3
const GLYPH_LIFE := 8.0
const GLYPH_R := 1.5
const BREATH_EVERY := 0.1
const BREATH_RANGE := 3.4


## Inkbound (Hearthtree): the Grimoire breathes a third further.
func breath_range() -> float:
	return BREATH_RANGE * (1.3 if player and player.stats and player.stats.has("mastery_tome") else 1.0)
var _glyphs: Array = []
var _orbit := 0.0
var _glyph_clear := 0.0
var _breath_t := 0.0
var _breath_n := 0
var _breath_snd := 0.0
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
	if form == "ash":
		_breathe(dt)
	elif form == "echo":
		_orbit_glyphs(dt)
	_gap = maxf(0.0, _gap - dt)
	if held and _gap <= 0.0 and player.alive and form != "ash":
		_gap = MOTE_GAP / speed() * (2.5 if form == "echo" else 1.0)
		if not predicting:
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
	if _gap <= 0.0 and player.alive and form != "ash":
		_gap = MOTE_GAP / speed() * (2.5 if form == "echo" else 1.0)
		if not predicting:
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
	if form == "ash":
		inscribed_n *= 6     # the breath reads many short words
	player.stage.fx.ring(player.pos, 1.0, _element_color(), 0.25, 0.2)
	if form == "echo":
		_echo(ability)


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
	if form == "echo":
		_write_glyph()
		return
	var st := player.stage
	_n += 1
	var d := player.aim.rotated(deg_to_rad(randf_range(-6.0, 6.0)))
	var target := st.nearest_hostile(player.team, player.pos + player.aim * 4.0, 7.0, true)
	var big := masterwork() and _n % 5 == 0
	var element := inscribed if inscribed_n > 0 else ""
	if inscribed_n > 0:
		inscribed_n -= 1
	# one mote, or a few (extra projectiles), each seeking its own foe
	var dirs := Volley.directions(player, d, 1, 0.22)
	var foes: Array = []
	if dirs.size() > 1:
		foes = st.hostiles(player.team).filter(func(a): return a.pos.distance_to(player.pos) < 9.0 and st.grid.line_clear(player.pos, a.pos))
		foes.sort_custom(func(a, b): return a.pos.distance_to(player.pos) < b.pos.distance_to(player.pos))
	var group := {}
	for k in dirs.size():
		var tk: Actor = target if foes.is_empty() else foes[k % foes.size()]
		_one_mote(dirs[k], tk, big, element, group)
	if _n % 2 == 0:
		Audio.play("orb", -12.0, randf_range(1.6, 1.9))
	player.on_weapon_strike(0, false)


func _one_mote(d: Vector2, target: Actor, big: bool, element: String, group: Dictionary) -> void:
	var st := player.stage
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
		var hurry := COOLDOWN_PER_HIT * (2.0 if player.stats.has("hollow_index") else 1.0)
		for i in player.ability_cd.size():
			player.ability_cd[i] = maxf(0.0, player.ability_cd[i] - hurry)
		player.gain_kindle(1.5)
		if big:
			_glyph_burst(proj.pos, proj.damage * 0.6, col)
	Volley.shape(pr, player, group)


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



# --- Codex of Echoes ------------------------------------------------------------------

func _live_glyphs() -> Array:
	_glyphs = _glyphs.filter(func(g): return is_instance_valid(g) and g.life > 0.0)
	return _glyphs


func _write_glyph() -> void:
	if _live_glyphs().size() >= GLYPHS:
		return
	var st := player.stage
	var col := _element_color() if inscribed_n > 0 else Color(0.7, 1.0, 0.95)
	var g := Projectile.create(st, "proj_glyph", player.pos, Vector2.ZERO, player.team)
	g.source = player
	g.damage = def.damage[0] * 1.3 * damage_scale()
	g.tags = ["ranged"]
	g.radius = 0.35
	g.life = GLYPH_LIFE
	g.height = 0.8
	g.pierce = 999
	g.phasing = true
	g.knockback = 1.5
	g.reflectable = false
	g.trail_color = col
	g.trail_rate = 14.0
	g.with_light(col, 0.6, 2.2)
	g.on_hit_fn = func(_proj: Projectile, _t: Actor, _res) -> void:
		for i in player.ability_cd.size():
			player.ability_cd[i] = maxf(0.0, player.ability_cd[i] - COOLDOWN_PER_HIT * 0.5)
		player.gain_kindle(1.0)
	_glyphs.append(g)
	st.fx.burst(player.pos, 0.8, col, 6, 2.0, 0.3, 0.0)
	Audio.play("glyph", -6.0, 0.9 + 0.1 * _glyphs.size())
	player.form_meter = float(_glyphs.size()) / GLYPHS


## The written glyphs circle the Kindled and strike what they pass.
func _orbit_glyphs(dt: float) -> void:
	if predicting:
		return
	var gs := _live_glyphs()
	player.form_meter = float(gs.size()) / GLYPHS
	if gs.is_empty():
		return
	_orbit += dt * 3.2
	_glyph_clear -= dt
	var clear := _glyph_clear <= 0.0
	if clear:
		_glyph_clear = 0.45
	for i in gs.size():
		var g: Projectile = gs[i]
		var a := _orbit + TAU * i / gs.size()
		var to := player.pos + Vector2.from_angle(a) * GLYPH_R
		g.vel = (to - g.pos) / maxf(dt, 0.001)
		if clear:
			g.hit_set.clear()


## Casting with every glyph written: they fly out, and the spell answers again.
func _echo(ability: String) -> void:
	var gs := _live_glyphs()
	if gs.size() < GLYPHS or predicting:
		return
	for g in gs:
		var d: Vector2 = (g.pos - player.pos).normalized()
		g.vel = d * 14.0
		g.life = 0.4
		g.pierce = 2
	_glyphs.clear()
	player.form_meter = 0.0
	var pl := player
	var st := player.stage
	st.fx.ring(pl.pos, 2.0, Color(0.7, 1.0, 0.95), 0.3, 0.25)
	st.fx.number(pl.pos, 2.4, "ECHO", Color(0.7, 1.0, 0.95), true)
	Audio.play("echo_cast", -2.0)
	st.after(0.35, func() -> void:
		if is_instance_valid(pl) and pl.alive:
			Abilities.cast(pl, ability, 0.65 if pl.stats.has("mastery_tome") else 0.45))


# --- Grimoire of Ash ------------------------------------------------------------------

## Reading breathes: a short cone of fire (or of whatever was inscribed).
func _breathe(dt: float) -> void:
	_breath_t -= dt
	_breath_snd -= dt
	if not held or not player.alive or _breath_t > 0.0:
		return
	_breath_t = BREATH_EVERY / speed()
	_breath_n += 1
	var d := player.aim
	var element := inscribed if inscribed_n > 0 and inscribed in ["frost", "shadow"] else "fire"
	var col := _element_color() if element != "fire" else Color(1.0, 0.55, 0.22)
	player.cosmetic(func() -> void:
		player.stage.fx.burst(player.pos + d * 0.6, 0.7, col, 5, 9.0, 0.32, 0.0, d, 0.42)
		player.stage.fx.burst(player.pos + d * 0.6, 0.7, Color(1.0, 0.85, 0.5) if element == "fire" else col.lightened(0.3), 2, 7.0, 0.2, 0.0, d, 0.25))
	if _breath_snd <= 0.0:
		_breath_snd = 0.32
		player.cosmetic(func() -> void: Audio.play("breath", -6.0, randf_range(0.92, 1.05)))
	if predicting:
		return
	if inscribed_n > 0:
		inscribed_n -= 1
	hit_ids.clear()
	var tags: Array = ["ranged", element]
	var n := _breath_n
	var touch := func(_a: Actor, h: Hit) -> void:
		h.silent = n % 3 != 0
		if element == "fire":
			h.burn = 1 if n % 3 == 0 else 0
		elif element == "frost":
			h.chill = 0.08
		elif element == "shadow":
			h.expose = 0.6
	var opts := {"each": touch}
	var hits := arc_hit(player.pos, d, breath_range() * player.stats.v("area"), deg_to_rad(26.0), def.damage[0] * 0.42, tags, 0.6, 2.0, opts)
	if hits > 0:
		for i in player.ability_cd.size():
			player.ability_cd[i] = maxf(0.0, player.ability_cd[i] - COOLDOWN_PER_HIT * 0.25)
		player.gain_kindle(0.5 * hits)
