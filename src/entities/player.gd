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
var ability_slots: Array = ["flare", "", ""]
var ability_cd: Array = [0.0, 0.0, 0.0]
## The third slot opens at this character level (a third rite for the Kindled).
const THIRD_SLOT_LEVEL := 5
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
var gloam_t := 0.0          # Gloamweave 4pc: empowered window after a dodge
var _echo_n := 0            # Echoing Gauntlets hit counter
var _aura_t := 0.0          # set aura emission
var counter_ready := false
var second_wind_used := false
var phoenix_used := false
var aim := Vector2.RIGHT
## Where the Kindled looks (sprite direction): the way they walk, or the aim
## while fighting and whenever the mouse moves with them standing still.
var look := Vector2.RIGHT
var _fight_look_t := 0.0
var _last_aim := Vector2.RIGHT
var aim_point := Vector2.ZERO
var move_in := Vector2.ZERO
var input_enabled := true
var autopilot := false
## Who drives this Kindled: this machine's devices (LOCAL), a client's input
## over the network (REMOTE, on the host), or nobody - a picture of the host's
## simulation (REPLICA, on a client).
enum Ctrl { LOCAL, REMOTE, REPLICA }
var controller := Ctrl.LOCAL
var peer_id := 1
var downed := false          # co-op: at 0 health, waiting for an ally
var bleed_t := 0.0
var revive_k := 0.0
var aegis_echo := false       # Rune of Echoes: the ward forms once more when it breaks
var still_t := 0.0            # Stillness keystone: how long the Kindled has stood still
var sheet: Dictionary = {}   # co-op: another player's character sheet (empty: this profile)
var predicting := false       # co-op client: this machine's Kindled acts at once; the host's word corrects it (NetRun)
var kindle_cap := -1.0        # co-op client: another Kindled's Kindle maximum, as the host has it
var pred_move := Vector2.ZERO # co-op client: the movement last sent to the host (the prediction uses only that)
var pred_speed := 1.0         # co-op client: the host's slows and chills on this Kindled
var in_seq := 0               # host: the newest input from a remote Kindled's owner
var in_age := 0.0             # host: how long (simulated) that input has been driving it
var lag_grace := 0.0          # host: how long blows on a remote Kindled wait for its owner's late dodge or Ward
var remote_hold := -1.0       # host: how long the owner held attack before letting go, by their own clock
var lag_saves := 0            # host: blows that a late dodge or Ward still caught
var _deferred: Array = []     # host: [due, hit, attacker] waiting out lag_grace
var _settling := false
var _held_until := {}         # co-op client: what the prediction changed itself, kept until the host has heard
var away := false             # co-op host: its owner lost the link; it waits, untouchable, for them
## Press counters for every button: they only go up, so a network packet lost
## in between can never lose a press (the host compares counts).
var presses := {"attack": 0, "dodge": 0, "ward": 0, "a1": 0, "a2": 0, "flask": 0, "home": 0, "interact": 0, "a3": 0}
const BLEED_TIME := 25.0
const REVIVE_TIME := 2.5
var last_attacker_id := ""
var godmode := "godmode" in Dev.args()
var lantern: OmniLight3D
var dir_name := "down"
var remote_look := Vector2.ZERO    # host: the facing a guest's own machine chose (sent with its input)
var _mouse_moved := false          # the pointer itself moved this frame (not the camera under it)
var _last_mp := Vector2(-1, -1)
# the keys always walk the screen's way; the pointer only turns the Kindled's
# face: a deliberate sweep of the mouse (not a twitch, nor the camera sliding
# under a resting pointer) faces the aim for a moment, even mid-walk
var _bled_out := false
var _aim_travel := 0.0
var aim_look_t := 0.0
const AIM_SWEEP := 18.0       # screen px of hand travel that count as aiming
const AIM_HOLD := 0.7         # seconds the face stays on the aim after the hand rests
var hit_once := {}
var dead_t := 0.0

var _buf := {"attack": 0.0, "dodge": 0.0, "ward": 0.0, "a1": 0.0, "a2": 0.0, "flask": 0.0, "home": 0.0, "a3": 0.0}
# build mechanics (the Hearthtree's transformative nodes; see SkillDB)
var shelter_t := 0.0          # in a Hearth Lantern's light: Kindle and less damage
var spellblade_n := 0         # Spellblade: weapon hits charged by the last spell
var spellblade_el := "fire"
var momentum := 0             # Momentum: hits in quick succession (0-8)
var form_meter := 0.0         # the weapon form's gauge, 0..1 (heat, nocked arrows, glyphs; host's for guests)
var channel_t := 0.0          # pouring a Soulfire Beam: slow, no weapon
var hearthfire_t := 0.0       # Hearthfire Form
var hearthfire_power := 1.0
var hearthfire_bonus := 0.0   # Hearthforged: seconds the form has gained from kills
var haste_t := 0.0            # Rekindle's quickening
var marked_t := 0.0           # an Ash Herald's decree: every foe strikes harder
var snuffed_t := 0.0          # a Snuffer took the flame: the lantern burns low
var furnace := 0.0            # Furnace Heart: Kindle spent, banked for the next blow
var answer_ready := false     # Perfect Answer: the next blow is a sure critical
var mirror_t := 0.0           # Mirror of the Deep: until it answers again
var stillwater_t := 0.0       # Stillwater Stone: until its barrier rises again
var last_spell := ""
var _still_for := 0.0
var salt_t := 0.0             # Grave-salt: no affliction takes hold
var tonic_chill_t := 0.0      # Gloamwater: every blow landed chills
var rush_refund := 0.0        # Ember Rush through the burning: part of its cooldown back
var _orb_cast_t := 0.0        # co-op client: a Cinder Orb of its own still drifting (a press bursts it)
var _fire_mote_t := 0.0
var _momentum_t := 0.0
var cuts := 0                 # Thousand Cuts: hits in a row
var retribution := 0.0        # Retribution: damage held for the next Ward
var _bond_t := 0.0
var _calm_t := 0.0            # Last Light: time since the last blow
## Hearthcall: stand still for a few breaths and the Last Hearth pulls you home
## from anywhere below (keeping everything you carry). Any hit, step or swing
## breaks it, and no fire can be heard over a boss.
const HEARTHCALL_TIME := 3.0
var hearthcall_t := -1.0
var gloom_t := 0.0          # inside a Gloom elite's darkness
var aura_cols: Array = []   # one colour per equipped legendary or unique (sets have their 4-piece aura)
var _gear_aura_t := 0.0
var _gloom_k := 0.0
var _hc_shapes: Array = []
var _hc_fx_t := 0.0
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
	if sheet.is_empty():
		_gear_sig = gear_signature()
		if not Profile.changed.is_connected(_on_profile_changed):
			Profile.changed.connect(_on_profile_changed)
	var wid: String = r.weapon_id
	set_weapon(wid, r.weapon_level)
	ability_slots = r.abilities.duplicate()
	while ability_slots.size() < 3:
		ability_slots.append("")
	hp = max_hp if r.hp < 0.0 else minf(r.hp, max_hp)
	kindle = r.kindle
	flask = int(stats.v("flask_charges")) if r.flask < 0 else r.flask
	second_wind_used = r.second_wind_used
	phoenix_used = r.phoenix_used
	dodge_charges = stats.v("dodge_charges")


func rebuild_stats() -> void:
	var ratio := hp_ratio() if max_hp > 0.0 and hp > 0.0 else 1.0
	stats = Stats.for_player()
	var equipped: Dictionary = Profile.equipped()
	if sheet.is_empty():
		SkillDB.apply(Profile.skills(), stats)
		Profile.apply_sanctuary(stats)
		Profile.apply_gear(stats)
	else:
		SkillDB.apply(sheet.get("skills", ["hearth"]), stats)
		Profile.apply_sanctuary_data(sheet.get("sanctuary", {}), sheet.get("resident_mods", []), stats)
		equipped = sheet.get("equipped", {})
		ItemDB.apply_equipped(equipped, stats)
	aura_cols.clear()
	for slot in equipped:
		var it = equipped[slot]
		if not (it is Dictionary):
			continue
		var r := String(it.get("rarity", ""))
		if r == "legendary":
			aura_cols.append(ItemDB.color(it))
		elif ItemDB.is_unique(String(it.get("base", ""))):
			aura_cols.append(Color(1.0, 0.82, 0.45))
		if Evolutions.can_evolve(it) and Evolutions.stage(it) >= 1:
			# grown things burn a little brighter, and another colour once they have chosen
			aura_cols.append(Color(0.55, 1.0, 0.9) if Evolutions.stage(it) >= 2 else Color(1.0, 0.82, 0.45))
	apply_look()
	refresh_paperdoll()
	if run:
		RelicDB.apply(run.relics, stats)
		Omens.apply(run.omens, stats)
		if Chronicle.site_of(run.world, run.region) == "kindled":
			stats.add_mod("flask_charges", "add", 1.0)      # a rekindled Vigil's blessing
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


## The Kindled's look: the shared material for this machine's own Kindled (the
## satchel and wardrobe preview it), a private copy for anyone else's.
func apply_look() -> void:
	if sheet.is_empty():
		Looks.apply_player(Looks.current())
		return
	if sprite == null:
		return
	if not (sprite.material_override is ShaderMaterial):
		sprite.material_override = (sprite.sheet.material as ShaderMaterial).duplicate()
	Looks.apply_to(sprite.material_override, String(sheet.get("look", "")), true)


var gear_layers := {}    # slot -> PixelSprite drawn over the body


## The armour this Kindled wears, drawn over the body (see GearLooks): one layer
## per slot, kept on the body's exact animation frame.
func refresh_paperdoll() -> void:
	if sprite == null or visual == null:
		return
	var eq: Dictionary = Profile.equipped() if sheet.is_empty() else sheet.get("equipped", {})
	var shown: Dictionary = Profile.inv().get("shown", {}) if sheet.is_empty() else sheet.get("shown", {})
	var want := GearLooks.paperdoll(eq, shown)
	for slot in gear_layers.keys():
		var l: PixelSprite = gear_layers[slot]
		if not want.has(slot) or l.sheet.name != String(want[slot]):
			l.queue_free()
			gear_layers.erase(slot)
	for i in GearLooks.LAYERS.size():
		var slot: String = GearLooks.LAYERS[i]
		if not want.has(slot) or gear_layers.has(slot):
			continue
		var l := PixelSprite.new()
		visual.add_child(l)
		l.setup(String(want[slot]), sprite.anim)
		l.playing = false
		l.set_meta("z", 0.004 * (i + 1))
		gear_layers[slot] = l
	_sync_paperdoll()


func _sync_paperdoll() -> void:
	for l: PixelSprite in gear_layers.values():
		if l.anim != sprite.anim and l.has_anim(sprite.anim):
			l.play(sprite.anim, true)
		l.playing = false
		if l.frame_i != sprite.frame_i:
			l.set_frame(sprite.frame_i)
		l.flip_h = sprite.flip_h
		l.visible = sprite.visible
		l.scale = sprite.scale
		l.position = sprite.position + Vector3(0, 0, float(l.get_meta("z", 0.004)))
		for k in ["dissolve", "flash", "tint", "lead"]:
			var v: Variant = sprite.get_instance_shader_parameter(k)
			if v != null:
				l.set_instance_shader_parameter(k, v)


## The weapon item this Kindled wields ({} for a plain archetype); another
## Kindled's comes from their character sheet.
func weapon_item() -> Dictionary:
	var eq: Variant = sheet.get("equipped", {}) if not sheet.is_empty() else Profile.equipped()
	var it: Variant = (eq as Dictionary).get("weapon") if eq is Dictionary else null
	return it if it is Dictionary else {}


func set_weapon(id: String, level: int) -> void:
	if weapon:
		weapon.free_visual()
	var def := GearDB.weapon(id)
	var scr: GDScript = load(def.script)
	weapon = scr.new()
	weapon.predicting = predicting
	weapon.setup(self, id, level)
	_weapon_sig = weapon_sig()


## Co-op: this (other) player's character sheet changed - new armour, a
## wardrobe pick, a hidden slot, another weapon. Drawn at once on every
## machine; the host's copy also takes the new stats - and, below as in the
## sanctuary, the weapon: a find taken up mid-expedition (another variant, or
## another kind of weapon altogether) is what the host swings for them.
func apply_sheet(sh: Dictionary) -> void:
	if sh.is_empty():
		return
	sheet = sh
	rebuild_stats()
	if sh.get("slots") is Array and not (sh.slots as Array).is_empty():
		ability_slots = (sh.slots as Array).duplicate()
		while ability_slots.size() < 3:
			ability_slots.append("")
		if run:
			run.abilities = ability_slots.duplicate()
	var wid := String(sh.get("weapon", ""))
	var wl := int(sh.get("weapon_level", 0))
	if wid != "" and (weapon == null or weapon.id != wid or weapon.level != wl or weapon_sig() != _weapon_sig):
		set_weapon(wid, wl)
		if run and not (stage is Hub):
			run.weapon_id = wid
			run.weapon_level = wl


var _weapon_sig := ""


## Which weapon item is in hand (its base, uid and make - a tempered blade is
## taken up again): a change means another form, even of the same kind.
func weapon_sig() -> String:
	var it := weapon_item()
	return "%s#%d#%d" % [String(it.get("base", "")), int(it.get("uid", 0)), hash(it)] if not it.is_empty() else ""


var _gear_sig := 0
var _gear_due := false


## This machine's own Kindled follows its save the moment it changes - the
## Satchel, the weapon rack, a loadout, the forge, a tempering, the Hearthtree,
## runes, a building, a resident's gift: every one of them ends here, so no
## screen has its own partial refresh (the weapon used to stay in hand in the
## sanctuary until the camp was rebuilt). Stats, the weapon (kind, form, look),
## the armour drawn over the body. Called on the frame after a change (changes
## come in bursts), or at once with `force`.
func sync_gear(force := false) -> void:
	_gear_due = false
	if not sheet.is_empty() or run == null or not is_inside_tree():
		return
	var s := gear_signature()
	if s == _gear_sig and not force:
		return
	_gear_sig = s
	rebuild_stats()
	take_up_weapon()
	# the spells too (a loadout worn below brings its own)
	ability_slots = Profile.slots()
	run.abilities = ability_slots.duplicate()


## Everything in the save that the Kindled's numbers or hands depend on.
static func gear_signature() -> int:
	return hash([Profile.equipped(), Profile.skills(), Profile.data.get("sanctuary", {}), Profile.runes().get("socketed", {}),
		Profile.data.get("weapons", {}), Profile.level(), Profile.resident_mods(), Profile.inv().get("shown", {}), Looks.current()])


func _on_profile_changed() -> void:
	_gear_due = true


func _exit_tree() -> void:
	if Profile.changed.is_connected(_on_profile_changed):
		Profile.changed.disconnect(_on_profile_changed)


## Below, after the Satchel changed what this Kindled wields: take it up now.
func take_up_weapon() -> void:
	var wid := Profile.equipped_weapon()
	var wl := Profile.weapon_level(wid)
	if weapon and weapon.id == wid and weapon.level == wl and weapon_sig() == _weapon_sig:
		return
	set_weapon(wid, wl)
	if run:
		run.weapon_id = wid
		run.weapon_level = wl


## Hides what the Kindled carries (the blade drawn beside the sprite), for
## when they dissolve into light.
func hide_gear() -> void:
	if weapon and weapon.visual and weapon.visual.visible:
		weapon.visual.visible = false
		stage.fx.burst(pos + look * 0.5, 0.7, Color(1.0, 0.7, 0.35), 8, 1.5, 0.5, -1.0)
	if shadow:
		shadow.visible = false


func kindle_max() -> float:
	if kindle_cap > 0.0 and controller == Ctrl.REPLICA and not predicting:
		return kindle_cap     # another Kindled: the host's figure (its relics included)
	return stats.v("kindle_max")


func aim_offset() -> Vector2:
	# lean the camera a little toward where the player is looking
	var d := (aim_point - pos)
	return d.limit_length(6.0) * 0.18


# --- input (real time) ---------------------------------------------------------

func _process(delta: float) -> void:
	if _gear_due:
		sync_gear()
	for k in _buf:
		_buf[k] = maxf(0.0, _buf[k] - delta)
	if autopilot or controller == Ctrl.REMOTE or downed:
		return
	if controller == Ctrl.REPLICA and peer_id != Net.my_id():
		return
	# a menu or a conversation has the player's hands: in co-op the world goes
	# on (it is never paused), but this Kindled waits - its keys belong to the
	# screen (F advancing a dialogue used to talk to the same resident again,
	# stacking a dimmed screen per press)
	var held := Game.ui != null and Game.ui.blocks_world()
	if not input_enabled or not alive or get_tree().paused or held:
		move_in = Vector2.ZERO
		if _attack_down:
			_attack_down = false
			_release_pending = true
		return
	move_in = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _approach:
		_tend_approach(delta)
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
		var mp := Dev.mouse_at(stage.view)
		# turning toward the pointer is for when the hand moves it: the aim also
		# shifts while the camera settles after a walk, which used to spin a
		# Kindled that had just stopped toward the mouse
		if _last_mp.x >= 0.0 and mp.distance_to(_last_mp) > 1.5:
			_mouse_moved = true
		var hand := mp.distance_to(_last_mp) if _last_mp.x >= 0.0 else 0.0
		_last_mp = mp
		aim_point = stage.view.screen_to_plane(mp, 0.6)
		var d := aim_point - pos
		if d.length() > 0.05:
			aim = d.normalized()
		note_aim(hand, delta)
	# the press that closed a menu must not also act in the world (nor open the
	# same conversation again straight away)
	if Game.ui and (Engine.get_process_frames() - Game.ui.closed_frame <= 1 or Game.ui.just_closed()):
		return
	if Input.is_action_just_pressed("interact"):
		try_interact()
	if Input.is_action_just_pressed("hearthcall"):
		press("home")
	if Input.is_action_just_pressed("ping"):
		Party.ping(stage, self, aim_point)
	# in the sanctuary a click on someone (or something) within reach talks to them
	var clicked: Prop = null
	var walking_over := false
	if Input.is_action_just_pressed("attack") and not _pad_aim and stage is Hub:
		clicked = stage.interactable_at(aim_point, pos)
		if clicked == null:
			walking_over = approach(stage.interactable_at(aim_point, pos, APPROACH_REACH))
	if clicked:
		_use(clicked)
	elif walking_over:
		pass
	elif Input.is_action_just_pressed("attack"):
		press("attack")
		_attack_down = true
	if _attack_down and not Input.is_action_pressed("attack"):
		_attack_down = false
		_release_pending = true
	if Input.is_action_just_pressed("dodge"):
		press("dodge")
	if Input.is_action_just_pressed("ward"):
		press("ward")
	if Input.is_action_just_pressed("ability_1"):
		press("a1")
	if Input.is_action_just_pressed("ability_2"):
		press("a2")
	if Input.is_action_just_pressed("ability_3"):
		press("a3")
	if Input.is_action_just_pressed("flask"):
		press("flask")


## Aiming with the mouse: `hand` is how far the hand moved the pointer this
## frame (screen pixels, never the camera sliding under it). A deliberate sweep
## faces the Kindled toward the aim for AIM_HOLD seconds - walking on the keys'
## way all the while - then the walk's own facing returns. It never changes
## where the Kindled walks: the keys alone decide that.
func note_aim(hand: float, delta: float) -> void:
	# (capped: a long sweep must not keep the face on the aim long after the hand rests)
	_aim_travel = minf(AIM_SWEEP * 1.5, maxf(0.0, _aim_travel - 90.0 * delta) + hand)
	if _aim_travel > AIM_SWEEP:
		aim_look_t = AIM_HOLD
	else:
		aim_look_t = maxf(0.0, aim_look_t - delta)


## A button press: buffered for the simulation and counted for the network.
func press(k: String) -> void:
	presses[k] = int(presses.get(k, 0)) + 1
	match k:
		"attack":
			_buf.attack = 0.18
		"dodge":
			_buf.dodge = 0.15
		"ward":
			_buf.ward = 0.12
		"a1", "a2", "a3", "flask":
			_buf[k] = 0.15
		"home":
			_buf.home = 0.2


## Uses the nearest interactable prop (chest, merchant, stairs...). Returns it, or null.
## A click on someone out of reach: the Kindled walks over and talks. (It used to
## swing a sword at them instead, with no word of why: in a crowd round the Keeper,
## being eased a step aside was enough to make a click do nothing it seemed to mean.)
const APPROACH_REACH := 14.0
var _approach: Prop = null
var _approach_t := 0.0


func approach(p: Prop) -> bool:
	if p == null:
		return false
	_approach = p
	_approach_t = 5.0
	return true


## Keys take over at once; someone unreachable is given up on out loud.
func _tend_approach(delta: float) -> void:
	_approach_t -= delta
	if move_in.length() > 0.1 or not is_instance_valid(_approach) or not _approach.interactable():
		_approach = null
		return
	if stage.interactable_at(_approach.pos, pos) == _approach:
		var p := _approach
		_approach = null
		move_in = Vector2.ZERO
		_use(p)
		return
	if _approach_t <= 0.0:
		_approach = null
		Events.toast.emit("You cannot reach them from here.", Color(0.8, 0.75, 0.7))
		return
	move_in = (stage.path_step(pos, _approach.pos) - pos).normalized()


func try_interact() -> Prop:
	if stage == null or not alive or downed:
		return null
	var near := stage.nearest_interactable(pos)
	if near:
		_use(near)
	return near


func _use(p: Prop) -> void:
	if Game.ui and Game.ui.blocks_world():
		return     # one screen at a time
	presses.interact = int(presses.interact) + 1
	if controller == Ctrl.REPLICA and not (stage is Hub):
		# a client asks the host, which owns every prop below
		Net.ask("interact", [p.net_idx])
	else:
		p.interact(self)


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
	if not alive or controller == Ctrl.REPLICA:
		return
	# sounds and screen shake from here on are this Kindled's (see Net.actor_peer)
	var prev := Net.actor_peer
	Net.actor_peer = peer_id
	Net.actor_pos = pos
	_think(dt)
	Net.actor_peer = prev


func _think(dt: float) -> void:
	if controller == Ctrl.REMOTE:
		in_age += dt
		_settle_deferred(false)
	if downed:
		_bleed(dt)
		return
	_timers(dt)
	if dodge_t > 0.0:
		_update_dodge(dt)
	else:
		_handle_actions(dt)
		if weapon:
			weapon.update(dt)
		vel = move_in * stats.v("move_speed") * _move_mult()
		if hearthcall_t >= 0.0:
			vel = Vector2.ZERO
			_tick_hearthcall(dt)
	if stats.has("stillness"):
		var was := still_t >= 0.6
		still_t = still_t + dt if move_in.length() < 0.1 and dodge_t <= 0.0 else 0.0
		if still_t >= 0.6 and not was:
			stage.fx.ring(pos, 0.9, Color(0.65, 0.88, 1.0), 0.3, 0.15)
		if still_t >= 0.6 and fmod(stage.elapsed, 0.25) < dt:
			stage.fx.motes(pos, 0.2, Color(0.65, 0.88, 1.0), 1, 0.4, 0.8, 0.5)
	_update_look(dt)
	facing = look
	if stats.has("featherfall"):
		bob = 0.12 + 0.03 * sin(stage.elapsed * 3.0)
	_set_aura(dt)
	_update_lantern(dt)
	_update_anim()
	_footsteps()
	_update_aegis_fx()


## How much the Kindled's stance slows its walk (attacking, casting, warding, drinking).
func _move_mult() -> float:
	var mult := weapon.move_mult() if weapon else 1.0
	if cast_t > 0.0:
		mult *= 0.55
	if ward_t > 0.0 or ward_recover > 0.0:
		mult *= 0.35
	if flask_t > 0.0:
		mult *= 0.45
	if channel_t > 0.0 and not stats.has("steady_pour"):
		mult *= 0.45
	if hearthfire_t > 0.0:
		mult *= 1.25
	if haste_t > 0.0:
		mult *= 1.25
	return mult


# --- co-op prediction (a client's own Kindled) -------------------------------------

## Co-op host: its owner lost the link (or is back).
func set_away(on: bool) -> void:
	away = on
	targetable = not on and not downed and alive
	move_in = Vector2.ZERO
	_attack_down = false
	_deferred.clear()
	if sprite:
		sprite.set_tint(Color(1, 1, 1, 0.35 if on else 1.0))


func can_predict() -> bool:
	return predicting and alive and not downed and stats != null


## Keeps what the prediction just changed (a spent dodge, Kindle, a cooldown)
## from being overwritten by host snapshots sent before the host heard of it.
func _hold(k: String) -> void:
	_held_until[k] = Time.get_ticks_msec() + int(Net.rtt_s() * 1000.0) + 200


func held_local(k: String) -> bool:
	return Time.get_ticks_msec() < int(_held_until.get(k, 0))


## Co-op client: this machine's Kindled moves, turns, dodges, wards and swings
## the moment its owner asks, the way think() would on the host; NetRun pulls it
## toward the host's word, and the host deals every blow.
func _predict(dt: float) -> void:
	_react = move_toward(_react, 0.0, dt * 6.0)
	move_in = pred_move
	for i in ability_cd.size():
		ability_cd[i] = maxf(0.0, ability_cd[i] - dt)
	ward_cd = maxf(0.0, ward_cd - dt)
	ward_recover = maxf(0.0, ward_recover - dt)
	shelter_t = maxf(0.0, shelter_t - dt)
	# (Momentum, Last Light and Hearthbond run on the host; Momentum comes back
	# in the snapshot so the swings predicted here keep its pace)
	channel_t = maxf(0.0, channel_t - dt)
	hearthfire_t = maxf(0.0, hearthfire_t - dt)
	haste_t = maxf(0.0, haste_t - dt)
	_orb_cast_t = maxf(0.0, _orb_cast_t - dt)
	cast_t = maxf(0.0, cast_t - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	flask_t = maxf(0.0, flask_t - dt)
	dodge_age += dt
	if ward_t > 0.0:
		ward_t -= dt
		if ward_t <= 0.0:
			ward_recover = 0.28
			ward_cd = 0.35 * (1.5 if stats.has("bastion") else 1.0)
	var maxc := stats.v("dodge_charges")
	if dodge_charges < maxc:
		dodge_charges = minf(maxc, dodge_charges + dt / maxf(0.2, stats.v("dodge_recharge")))
	if dodge_t > 0.0:
		dodge_t -= dt
		vel = dodge_dir * DODGE_SPEED
		_trail_t += dt
		if _trail_t >= 0.035:
			_trail_t = 0.0
			stage.fx.ghost(sprite, global_position + sprite.position + visual.position, Color(1.0, 0.6, 0.3), 0.18)
		if dodge_t <= 0.0:
			dodge_t = 0.0
			vel = Vector2.ZERO
		if weapon:
			weapon.update_visual(dt)
	else:
		_handle_actions(dt)
		if weapon:
			weapon.update(dt)
		vel = move_in * stats.v("move_speed") * _move_mult()
		if hearthcall_t >= 0.0:
			vel = Vector2.ZERO
	# Actor._move, with the host's slows standing in for this machine's statuses
	if vel != Vector2.ZERO and pred_speed > 0.0:
		pos = stage.grid.move_box(pos, box(), vel * pred_speed * dt, flying)
	if push.length_squared() > 0.0001:
		pos = stage.grid.move_box(pos, box(), push * dt, flying)
		push *= exp(-9.0 * dt)
	else:
		push = Vector2.ZERO
	draw_off = draw_off * exp(-dt * 12.0) if draw_off.length() > 0.005 else Vector2.ZERO
	_update_look(dt)
	facing = look
	_update_lantern(dt)
	_update_anim()
	_footsteps()
	sync_visual()


func _predict_dodge() -> void:
	var d := move_in if move_in.length() > 0.2 else aim
	dodge_dir = d.normalized()
	dodge_len = stats.v("dodge_distance") / DODGE_SPEED
	dodge_t = dodge_len
	dodge_age = 0.0
	perfect_done = false
	dodge_charges -= 1.0
	_hold("dodge")
	if weapon:
		weapon.cancel()
	ward_t = 0.0
	cast_t = 0.0
	Audio.play("dodge", -2.0, randf_range(0.95, 1.05))
	stage.fx.burst(pos, 0.1, Color(0.55, 0.52, 0.5), 10, 2.6, 0.4, 3.0, -dodge_dir, 0.8)
	stage.fx.kick(dodge_dir, 1.0)


## Effects of this Kindled's own action that its owner has already shown itself
## (prediction): the host sends them to everyone else only.
func cosmetic(fn: Callable) -> void:
	var was := Net.skip_peer
	if controller == Ctrl.REMOTE:
		Net.skip_peer = peer_id
	fn.call()
	Net.skip_peer = was


# --- co-op lag compensation (host) ----------------------------------------------------

## A remote Kindled's owner sees each blow coming a round trip late. Blows that
## would land wait `lag_grace` for a dodge or Ward already on its way; one that
## arrives in time turns the blow (a perfect dodge, a Ward) as it would have
## on the owner's screen.
func _settle_deferred(now_all: bool) -> void:
	if _deferred.is_empty():
		return
	var due: Array = []
	for d in _deferred:
		if now_all or stage.elapsed >= float(d[0]):
			due.append(d)
	for d in due:
		_deferred.erase(d)
		var att: Variant = d[2]
		if att is Object and not is_instance_valid(att):
			att = null
		var before := hp
		_settling = true
		take_enemy_hit(d[1], att)
		_settling = false
		if now_all and hp >= before:
			lag_saves += 1


var _moth_t := 1.0


func _timers(dt: float) -> void:
	if stats.has("moth_swarm") and stage is Dungeon:
		_moth(dt)
	for i in ability_cd.size():
		ability_cd[i] = maxf(0.0, ability_cd[i] - dt)
	ward_cd = maxf(0.0, ward_cd - dt)
	ward_recover = maxf(0.0, ward_recover - dt)
	riposte_t = maxf(0.0, riposte_t - dt)
	ambush_t = maxf(0.0, ambush_t - dt)
	shelter_t = maxf(0.0, shelter_t - dt)
	if momentum > 0:
		_momentum_t -= dt
		if _momentum_t <= 0.0:
			momentum = 0
			cuts = 0
	if blade_charge > 0.0:
		_blade_idle += dt
		if _blade_idle > 4.0:
			blade_charge = maxf(0.0, blade_charge - dt * 2.0)
			_blade_cued = blade_charge >= THOUSANDTH * 0.8
			_legend_glow(blade_charge / THOUSANDTH)
	# Last Light: unhurt for a breath, the lantern's flame comes back quickly
	_calm_t += dt
	if stats.has("last_light") and _calm_t > 2.0 and kindle < stats.v("kindle_max"):
		kindle = minf(stats.v("kindle_max"), kindle + 6.0 * dt)
	# Hearthbond: every Kindled near you (you too) is fed a little Kindle
	if stats.has("hearthbond") and stage is Dungeon:
		_bond_t -= dt
		if _bond_t <= 0.0:
			_bond_t = 0.5
			for ally in stage.players_near(pos, 5.0):
				ally.gain_kindle(1.0)
	gloam_t = maxf(0.0, gloam_t - dt)
	channel_t = maxf(0.0, channel_t - dt)
	haste_t = maxf(0.0, haste_t - dt)
	tonic_chill_t = maxf(0.0, tonic_chill_t - dt)
	mirror_t = maxf(0.0, mirror_t - dt)
	marked_t = maxf(0.0, marked_t - dt)
	stillwater_t = maxf(0.0, stillwater_t - dt)
	if ward_t > 0.0 and stats.has("hearth_anchor"):
		gain_kindle(8.0 * dt / maxf(stats.v("kindle_gain"), 0.01))
	if stats.has("stillwater") and stillwater_t <= 0.0 and stage is Dungeon and (stage as Dungeon).fight_on():
		_still_for = _still_for + dt if move_in.length() < 0.1 and dodge_t <= 0.0 else 0.0
		if _still_for >= 1.0:
			_still_for = 0.0
			stillwater_t = 8.0
			barrier = maxf(barrier, roundf(max_hp * 0.15))
			barrier_t = maxf(barrier_t, 6.0)
			stage.fx.ring(pos, 1.5, Color(0.6, 0.85, 1.0), 0.5, 0.3)
	if run and run.has_omen("bleeding_lantern") and stage is Dungeon and (stage as Dungeon).fight_on():
		kindle = maxf(0.0, kindle - 1.5 * dt)
	if salt_t > 0.0:
		# Grave-salt: no burning, chill or other affliction takes hold
		salt_t -= dt
		status.clear()
	if hearthfire_t > 0.0:
		# hearth-fire: cold cannot hold it, and the lantern feeds
		hearthfire_t -= dt
		status.chill = 0.0
		status.snare_t = 0.0
		gain_kindle(6.0 * dt)
		if hearthfire_t <= 0.0:
			hearthfire_t = 0.0
			Abilities.hearthfire_nova(self)
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
			ward_cd = 0.35 * (1.5 if stats.has("bastion") else 1.0)
	var maxc := stats.v("dodge_charges")
	if dodge_charges < maxc:
		dodge_charges = minf(maxc, dodge_charges + dt / maxf(0.2, stats.v("dodge_recharge")))


func _handle_actions(_dt: float) -> void:
	if _buf.home > 0.0:
		_buf.home = 0.0
		if predicting:
			return     # the host decides the Hearthcall
		if hearthcall_t >= 0.0:
			break_hearthcall()
		else:
			start_hearthcall()
		return
	if hearthcall_t >= 0.0:
		if predicting:
			return
		# anything else the Kindled does breaks the call
		if _buf.attack > 0.0 or _buf.dodge > 0.0 or _buf.ward > 0.0 or _buf.a1 > 0.0 or _buf.a2 > 0.0 or _buf.a3 > 0.0 or _buf.flask > 0.0 or move_in.length() > 0.5:
			break_hearthcall()
		else:
			return
	var leaping: bool = weapon is Weapon and weapon.has_method("is_busy") and weapon.get("leaping") == true
	if _buf.dodge > 0.0 and dodge_charges >= 1.0 and not leaping:
		_buf.dodge = 0.0
		_start_dodge()
		return
	if _buf.ward > 0.0 and ward_cd <= 0.0 and ward_recover <= 0.0 and not leaping and not stats.has("no_ward"):
		_buf.ward = 0.0
		_start_ward()
		return
	for i in 3:
		var key: String = "a%d" % (i + 1)
		if _buf[key] > 0.0 and not leaping:
			_buf[key] = 0.0
			_try_ability(i)
	if _buf.flask > 0.0 and flask_t <= 0.0:
		_buf.flask = 0.0
		_drink()
	if weapon == null or ward_t > 0.0 or flask_t > 0.0 or channel_t > 0.0:
		return
	if _buf.attack > 0.0 and cast_t <= 0.0:
		_buf.attack = 0.0
		weapon.press()
		if not _attack_down:
			_release_pending = true
	if _release_pending and not (_buf.attack > 0.0):
		_release_pending = false
		if remote_hold >= 0.0:
			weapon.sync_hold(remote_hold)
			remote_hold = -1.0
		weapon.release()


## Ashwalker's Cinder: burning ground where the dodge began, and along it.
func _ash_trail() -> void:
	var from := pos
	for k in 3:
		stage.after(k * 0.08, func() -> void:
			if not is_inside_tree():
				return
			var h := Hazard.spawn(stage, pos if k > 0 else from, 0.9, 2.4, team, Color(1.0, 0.5, 0.2), func(_h: Hazard, a: Actor) -> void:
				if a is Enemy and is_instance_valid(self):
					var hit := Hit.make(self, 3.0 + stats.v("fire_damage") * 4.0, ["dot", "fire"])
					hit.can_crit = false
					hit.silent = true
					hit.burn = 1
					deal_hit(a, hit))
			h.period = 0.5)


func _start_dodge() -> void:
	if stats.has("ash_cinder") and not predicting:
		_ash_trail()
	if predicting:
		_predict_dodge()
		return
	if stats.has("shadowdancer"):
		Abilities.shade(self, pos, 14.0 * stats.damage_mult(["shadow"]), 0.4)
	var d := move_in if move_in.length() > 0.2 else aim
	dodge_dir = d.normalized()
	var dist := stats.v("dodge_distance")
	dodge_len = dist / DODGE_SPEED
	dodge_t = dodge_len
	dodge_age = 0.0
	perfect_done = false
	invuln_t = maxf(invuln_t, stats.v("dodge_iframes"))
	dodge_charges -= 1.0
	if stats.has("turncloak"):
		# the Turncloak Ring: those you slip past keep looking back where you were
		var end := pos + dodge_dir * dist
		for a in stage.hostiles(team):
			if a is Enemy and not (a as Enemy).def.get("boss", false):
				var q := Geometry2D.get_closest_point_to_segment(a.pos, pos, end)
				if q.distance_to(a.pos) < 1.4:
					(a as Enemy).turn_away(-dodge_dir, 1.2)
	if weapon:
		weapon.cancel()
	ward_t = 0.0
	cast_t = 0.0
	if stats.has("gloam_set4"):
		gloam_t = 2.0 + dodge_len
	cosmetic(func() -> void:
		Audio.play("dodge", -2.0, randf_range(0.95, 1.05))
		stage.fx.burst(pos, 0.1, Color(0.55, 0.52, 0.5), 10, 2.6, 0.4, 3.0, -dodge_dir, 0.8)
		stage.fx.kick(dodge_dir, 1.0))
	if stats.has("dodge_afterimage"):
		Abilities.shade(self, pos, 30.0 * (2.0 if stats.has("afterimage_double") else 1.0), 0.6)
	_settle_deferred(true)


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
	cosmetic(func() -> void:
		Audio.play("ward", -3.0)
		stage.fx.shape(Fx.Shape.RING, pos, Vector2.RIGHT, Vector2(2.4, 2.4), Color(1.0, 0.85, 0.5, 0.6), Color(1.0, 0.95, 0.75, 1.0), ward_t, {"inner": 0.82, "glow": 1.4}))
	_settle_deferred(true)


func is_warding() -> bool:
	return ward_t > 0.0


## The third spell slot opens at THIRD_SLOT_LEVEL (another Kindled: their sheet's level).
func slot_open(slot: int) -> bool:
	if slot < 2:
		return true
	var lvl := Profile.level() if sheet.is_empty() else int(sheet.get("level", 1))
	return lvl >= THIRD_SLOT_LEVEL


func _try_ability(slot: int) -> void:
	var id: String = ability_slots[slot] if slot < ability_slots.size() else ""
	if id == "orb" and cast_t <= 0.0:
		# a second cast bursts the Cinder Orb still drifting (no cost, no wait)
		if predicting and _orb_cast_t > 0.0:
			_orb_cast_t = 0.0
			cast_t = 0.15
			_hold("a%d" % slot)
			return
		if not predicting and Abilities.burst_orbs(self):
			cast_t = 0.15
			return
	if id == "" or slot >= ability_cd.size() or ability_cd[slot] > 0.0 or cast_t > 0.0 or not slot_open(slot):
		return
	var d := GearDB.ability(id)
	if d.is_empty():
		return
	var cost: float = d.cost * stats.v("ability_cost") * Runes.cost_mult(self, id)
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
	if predicting:
		# the host casts it; here the Kindled takes the stance and pays at once
		kindle = maxf(0.0, kindle - cost)
		ability_cd[slot] = float(d.cooldown) * stats.v("cooldown") * Runes.cooldown_mult(self, id)
		cast_t = 0.2
		_hold("kindle")
		_hold("a%d" % slot)
		# the spells that change how the Kindled moves, predicted at once
		match id:
			"beam":
				channel_t = float(d.duration)
			"hearthfire":
				hearthfire_t = float(d.duration)
			"orb":
				_orb_cast_t = float(d.life)
		# a blink or a rush moves the Kindled at once (the host picks the same spot)
		if id == "gloamstep" or id == "rush":
			var rng: float = float(d.range) * (stats.v("area") if id == "rush" else 1.0)
			var to := Abilities.dash_dest(self, rng, id == "gloamstep")
			if to.distance_to(pos) >= 0.6:
				stage.fx.ghost(sprite, global_position + sprite.position, Color(1.0, 0.6, 0.3) if id == "rush" else Color(0.55, 0.3, 0.75), 0.3)
				pos = to
				invuln_t = maxf(invuln_t, 0.25)
		return
	var cast_at := pos
	var cast_dir := aim
	if not Abilities.cast(self, id):
		return
	last_spell = id
	if stats.has("furnace_heart"):
		furnace = minf(60.0, furnace + cost)
	if id != "gloamstep":
		Abilities.echo(self, id, cast_at, cast_dir, aim_point)
	if weapon and weapon.has_method("inscribe"):
		weapon.inscribe(id)
	if pay_hp > 0.0:
		hp -= pay_hp
		kindle = 0.0
		stage.fx.number(pos, 2.2, "-%d" % int(pay_hp), Color(1.0, 0.4, 0.3))
	else:
		kindle -= cost
	if stats.has("blood_price"):
		hp = maxf(1.0, hp - max_hp * 0.04)
	ability_cd[slot] = float(d.cooldown) * stats.v("cooldown") * Runes.cooldown_mult(self, id)
	if id == "rush" and rush_refund > 0.0:
		# through the burning: the next Rush comes sooner
		ability_cd[slot] *= 1.0 - rush_refund
		rush_refund = 0.0
	cast_t = 0.2


func _deny() -> void:
	cosmetic(func() -> void:
		Audio.play("deny", -6.0)
		stage.fx.number(pos, 2.2, "no kindle", Color(0.7, 0.7, 0.75)))


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
	if predicting:
		_hold("flask")     # the host heals (and pours the tincture)
	else:
		_pour()
	var tcol: Color = Tinctures.get_def(String(tincture().get("id", "hearthbalm"))).color
	cosmetic(func() -> void:
		Audio.play("flask", 0.0)
		# hearth-fire rises through you, in the colour of what the flask is steeped with
		stage.fx.motes(pos, 0.4, tcol, 18, 1.6, 0.8, 0.4)
		stage.fx.motes(pos, 0.1, Color(0.6, 1.0, 0.6), 10, 2.2, 0.7, 0.3)
		stage.fx.ring(pos, 1.3, tcol, 0.35, 0.2)
		stage.fx.flash_light(pos, 1.0, tcol, 2.0, 4.0, 0.4))
	if sprite and controller != Ctrl.REMOTE:
		sprite.flash(Color(1.0, 0.85, 0.55), 0.25)
		Settings.rumble(0.25, 0.0, 0.15)


## What this Kindled's flask is steeped with ({id, rank}; another Kindled's
## comes from their sheet - the host pours a guest's draught).
func tincture() -> Dictionary:
	if not sheet.is_empty():
		var t: Variant = sheet.get("tincture", {})
		return t if t is Dictionary else {}
	return Profile.tincture()


## The drink itself (host side): the heal, and the tincture's work.
func _pour() -> void:
	var base := max_hp * stats.v("flask_heal") * stats.v("heal_mult")
	var tc := tincture()
	var id := String(tc.get("id", ""))
	var rk := int(tc.get("rank", 0))
	if id == "" or rk <= 0 or not Tinctures.TINCTURES.has(id):
		heal(base)
		return
	var mult := Tinctures.at(id, "heal", rk)
	if id == "last_ember" and hp_ratio() < 0.34:
		mult = Tinctures.at(id, "low", rk)
	heal(base * mult)
	match id:
		"kindleroot":
			kindle = stats.v("kindle_max")
		"wardmilk":
			barrier = maxf(barrier, roundf(max_hp * Tinctures.at(id, "barrier", rk)))
			barrier_t = maxf(barrier_t, 5.0)
		"sunwater":
			haste_t = maxf(haste_t, Tinctures.at(id, "haste", rk))
			dodge_charges = stats.v("dodge_charges")
		"salt":
			status.clear()
			salt_t = Tinctures.at(id, "ward", rk)
		"gloamwater":
			tonic_chill_t = Tinctures.at(id, "chill", rk)


func _deny_flask() -> void:
	cosmetic(func() -> void:
		Audio.play("deny", -6.0)
		stage.fx.number(pos, 2.2, "flask empty", Color(0.7, 0.7, 0.75)))


func gain_kindle(amount: float) -> void:
	var mx := stats.v("kindle_max")
	var before := kindle
	if gloom_t > 0.0 and amount > 0.0:
		amount *= 0.5
	kindle = minf(mx, kindle + amount * stats.v("kindle_gain"))
	if before < mx and kindle >= mx:
		stage.fx.ring(pos, 1.2, Color(1.0, 0.8, 0.35), 0.3, 0.2)
		Audio.play("kindle_full", -6.0)


# --- weapon callbacks --------------------------------------------------------------

func on_attack_start() -> void:
	cast_t = 0.0


func on_weapon_charged() -> void:
	cosmetic(func() -> void:
		Audio.play("charged", -4.0)
		stage.fx.ring(pos, 1.0, Color(1.0, 0.85, 0.45), 0.2, 0.25))


func on_weapon_strike(_hits: int, _finisher: bool) -> void:
	if _hits > 0 and weapon and weapon.form == "thousandth":
		_gather_blade(2.0 if hearthfire_t > 0.0 and stats.has("hearthforged") else 1.0)
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
	if finisher and weapon and weapon.technique() != "focus" and weapon.has_technique("focus") and h.proc:
		weapon.add_focus()     # the tree's Focus: a charged blow that lands is a true shot
	var prev := Net.actor_peer
	Net.actor_peer = peer_id
	Net.actor_pos = pos
	var res := _deal_hit(t, h, finisher)
	Net.actor_peer = prev
	return res


## What a blow is counted under in the run analysis.
func _hit_name(h: Hit, ab: String) -> String:
	if ab != "":
		return String(GearDB.ability(ab).get("name", ab.capitalize()))
	if h.has_tag("dot"):
		return "Burn and poison"
	return String(GearDB.weapon(weapon.id if weapon else "").get("name", "Weapon"))


## Who to blame, in a word a player would use.
func _blow_name(attacker: Node, h: Hit) -> String:
	var src: Node = attacker if attacker != null else h.source
	if src is Enemy and is_instance_valid(src):
		return (src as Enemy).display_name
	return "Burning" if h.has_tag("fire") else ("The room" if h.has_tag("hazard") else "The Undervault")


## How far the lantern's light reaches, in tiles (The Lantern's Edge strikes inside it).
func light_reach() -> float:
	return (lantern.omni_range if lantern else 10.0) * 0.5


## The lantern burns low for a while (every machine sees its own Kindled's).
func snuff(seconds: float) -> void:
	snuffed_t = seconds
	if controller == Ctrl.REMOTE:
		Net.rec(["own", peer_id, ["snuff", seconds]])


## Dragged somewhere by force: over a push, so the walls still have a say and the
## guest's own prediction takes the same path as the host's.
func hauled(to: Vector2) -> void:
	push = (to - pos) * 9.0
	if controller == Ctrl.REMOTE:
		Net.rec(["own", peer_id, ["haul", to]])


var _pulsing := false


## A fight with a rule of its own (DeepEvents.RULES) answers the blows in it.
func _room_rule(t: Actor, res: Combat.Result, dot: bool) -> void:
	match (stage as Dungeon).rule_here():
		"unlit":
			if not t.alive:
				gain_kindle(kindle_max() * 0.2)
		"one_pulse":
			if dot or _pulsing:
				return
			_pulsing = true
			for a in stage.hostiles(Actor.Team.PLAYER):
				if a != t and a is Enemy and a.alive and (stage as Dungeon).room_enemies.has(a):
					var e := Hit.make(self, res.amount * 0.3, ["ability"])
					e.can_crit = false
					e.proc = false
					e.silent = true
					e.poise = 0.0
					deal_hit(a, e)
					stage.fx.burst(a.pos, 0.7, Color(1.0, 0.45, 0.42), 3, 2.0, 0.3, 4.0)
			_pulsing = false


func _deal_hit(t: Actor, h: Hit, finisher: bool) -> Combat.Result:
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
	if stage is Dungeon and (stage as Dungeon).sealed_foe(t):
		mult *= 0.5      # a Trial of Ash hall's seals ward its foes
	if t is Enemy and (t as Enemy).grudge_ward_t > 0.0:
		mult *= 0.4      # a Grudge's red ward: step back and wait it out
	if stats.has("berserk"):
		mult *= 1.0 + 0.03 * floorf((1.0 - hp_ratio()) * 10.0)
	if stats.has("ember_crown") and run:
		mult *= 1.0 + minf(0.4, 0.02 * floorf(run.embers / 50.0))
	if stats.has("grudgebearer"):
		mult *= 1.0 + minf(0.2, 0.04 * Profile.active_grudges().size())
	if stats.has("glass_lantern") and t.pos.distance_to(pos) < 4.0:
		mult *= 1.35
	if stats.has("lantern_edge") and t.pos.distance_to(pos) <= light_reach():
		mult *= 1.0 + 0.25 * clampf(kindle / maxf(1.0, kindle_max()), 0.0, 1.0)
	if stats.has("vanguard") and t.status.is_staggered():
		mult *= 1.35
	if stats.has("stillness") and still_t >= 0.6:
		mult *= 1.4
		h.chill = maxf(h.chill, 0.2)
	if direct and tonic_chill_t > 0.0:
		h.chill = maxf(h.chill, 0.3)     # Gloamwater
	if direct and not h.has_tag("ability"):
		if furnace > 0.0:
			mult *= 1.0 + furnace / 100.0      # Furnace Heart: what was spent, struck
			furnace = 0.0
		if answer_ready:
			answer_ready = false               # Perfect Answer
			h.forced_crit = true
			h.poise = maxf(h.poise, 40.0)
		if stats.has("shadowfrost") and t.status.chill > 0.0:
			mult *= 1.3
	# one Kindled freezes, another shatters: a bonus for a party, never a need
	if direct and t.status.is_frozen() and t.has_meta("frozen_by") and int(t.get_meta("frozen_by")) != peer_id:
		mult *= 1.5
		t.remove_meta("frozen_by")
		cosmetic(func() -> void:
			stage.fx.number(t.pos, 2.4, "SHATTER", Color(0.7, 0.9, 1.0), true)
			stage.fx.burst(t.pos, 0.8, Color(0.75, 0.92, 1.0), 16, 4.0, 0.4, 3.0))
	if stats.has("ashbringer") and float(t.get_meta("ashen_until", -1.0)) > stage.elapsed:
		mult *= 1.25
	if direct and stats.has("headsman") and t.hp_ratio() < 0.25:
		h.forced_crit = true
	if stats.has("ember_set4") and t.status.burning():
		mult *= 1.25
	if direct and stats.has("gloam_set4") and gloam_t > 0.0:
		h.forced_crit = true
		mult *= 1.3
	if direct and stats.has("thousand_cuts"):
		mult *= 0.7
	if direct and spellblade_n > 0 and not h.has_tag("ability"):
		# Spellblade: the spell's element rides this hit
		spellblade_n -= 1
		mult *= 1.4
		if not h.tags.has(spellblade_el):
			h.tags.append(spellblade_el)
		match spellblade_el:
			"fire":
				h.burn = maxi(h.burn, 1)
			"frost":
				h.chill = maxf(h.chill, 0.3)
			"shadow":
				h.expose = maxf(h.expose, 1.5)
		var sc: Color = {"frost": Color(0.6, 0.85, 1.0), "shadow": Color(0.7, 0.45, 0.95)}.get(spellblade_el, Color(1.0, 0.6, 0.3))
		stage.fx.burst(t.pos, 0.7, sc, 6, 3.0, 0.25, 0.0, h.from_dir, 0.6)
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
		if stats.has("ember_set4") and h.has_tag("melee"):
			h.burn = maxi(h.burn, 1)
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
	var ab := String(h.get_meta("ab", ""))
	var runes: Array = Runes.of(self, ab) if ab != "" else []
	if runes.has("rime"):
		# the spell turned to frost: it chills rather than burns
		for k in ["fire", "shadow"]:
			h.tags.erase(k)
		if not h.tags.has("frost"):
			h.tags.append("frost")
		h.burn = 0
		h.chill = maxf(h.chill, 0.35)
		if t.status.is_frozen():
			h.amount *= 1.5
	elif runes.has("gloam"):
		for k in ["fire", "frost"]:
			h.tags.erase(k)
		if not h.tags.has("shadow"):
			h.tags.append("shadow")
		h.burn = 0
		h.chill = 0.0
		h.expose = maxf(h.expose, 2.0)
	var was_chilled := t.status.chill > 0.0 or t.status.is_frozen()
	var was_burning := t.status.burning()
	var res := t.take_hit(h)
	if res.amount <= 0.0:
		return res
	if run:
		run.note_dealt(_hit_name(h, ab), res.amount)
	if stage is Dungeon:
		_room_rule(t, res, dot)
	if not runes.is_empty() and h.proc:
		_rune_on_hit(t, h, res, runes)
	if stats.has("ashbringer") and h.has_tag("ability") and h.has_tag("fire") and float(t.get_meta("ash_cd", -1.0)) < stage.elapsed:
		t.set_meta("ash_cd", stage.elapsed + 0.8)
		_ash_ground(t.pos)
	Events.damage_dealt.emit(t, res.amount, res.crit)
	if res.crit and stats.has("pyre_brand") and t.alive:
		t.status.apply_burn(3, 3.0 * (1.0 + stats.v("burn_damage")), int(stats.v("burn_stacks")), self)
	if h.proc and direct and not stats.has("lantern_edge"):
		var g := 4.0 if h.has_tag("melee") else 1.2
		if stats.has("ember_edge") and h.has_tag("melee"):
			g *= 1.5
		gain_kindle(g)
	if res.crit and h.proc and stats.has("crit_chain"):
		_crit_chain(t, res.amount * 0.5)
	if direct and h.proc and (stats.has("momentum") or stats.has("thousand_cuts")):
		_flow(t, finisher)
	if direct and h.proc and hearthfire_t > 0.0 and not h.has_tag("ability"):
		Abilities.hearthfire_burst(self, t)
	if h.has_tag("melee") and not dot and int(t.get_meta("knives_in", 0)) > 0:
		Abilities.knives_detonate(self, t)
	if res.crit and direct and h.proc and stats.has("crit_knives"):
		spectral_knife(t)     # Gloamfang
	_unique_on_hit(t, h, res, direct)
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
		if res.crit or finisher:
			stage.fx.flash_light(t.pos, 0.9, flash_col, 1.8, 3.2, 0.14)
		if h.has_tag("melee"):
			stage.fx.kick(h.from_dir, 2.5 if res.crit or finisher else 1.2)
			if weapon:
				weapon.hit_flash()
		# each weapon lands with its own sound; a crit rings over it
		Audio.play(_impact_sound(h), -4.0 if not res.crit else -2.0, randf_range(0.93, 1.07))
		if res.crit:
			stage.fx.burst(t.pos, 0.8, Color(1.0, 0.9, 0.5), 6, 5.0, 0.2, 0.0, h.from_dir, 0.5)
			stage.hitstop(0.06)
			Settings.rumble(0.35, 0.25, 0.08)
			Audio.play("crit", -5.0, randf_range(0.95, 1.05))
		else:
			Settings.rumble(0.18, 0.0, 0.05)
		if t.alive and h.has_tag("melee") and weapon and weapon.form == "thousandth" and t is Enemy and ((t as Enemy).elite or (t as Enemy).def.get("boss", false)):
			_gather_blade(1.0)     # a guardian's or an elite's hide feeds it twice over
		if not t.alive and h.has_tag("melee") and weapon and weapon.form == "thousandth":
			_gather_blade(1.0)     # a foe felled feeds the Thousandth Cut
		if not t.alive and h.has_tag("melee"):
			# killing blows land a beat harder (a hammer's hardest of all)
			stage.hitstop(0.075 if (t is Enemy and (t as Enemy).elite) else 0.05)
			if weapon and weapon.id == "hammer":
				stage.fx.burst(t.pos, 0.3, Color(0.7, 0.66, 0.6), 10, 5.0, 0.5, 9.0, h.from_dir, 1.0, 2.5)
				stage.fx.shake(0.18)
			stage.fx.kick(h.from_dir, 2.0)
	return res


## What a hit sounds like: a blade slices, a hammer crunches, a point punches
## in, an arrow thunks, a spell or bolt pops.
func _impact_sound(h: Hit) -> String:
	if h.has_tag("melee") and weapon and not h.has_tag("ability"):
		match weapon.id:
			"hammer":
				return "hit_blunt"
			"spear":
				return "hit_pierce"
			"sword", "daggers":
				return "hit_slash"
	if h.has_tag("ranged") and weapon and weapon.id == "bow" and not h.has_tag("ability"):
		return "hit_arrow"
	if h.has_tag("ranged") or h.has_tag("ability"):
		return "hit_magic"
	return "hit"


## Momentum and Thousand Cuts: weapon hits in quick succession build up.
## Momentum: +4% attack speed per hit (up to 8); at 8, a finisher sends a
## cutting wave. Thousand Cuts: every third hit in a row looses a spectral blade
## at another foe.
func _flow(t: Actor, finisher: bool) -> void:
	momentum = mini(8, momentum + 1)
	_momentum_t = 1.5
	cuts += 1
	if stats.has("thousand_cuts") and cuts % 3 == 0:
		spectral_knife(t)
	if stats.has("momentum") and momentum >= 8 and finisher and weapon:
		stage.fx.ring(pos, 1.0, Color(1.0, 0.85, 0.45), 0.25, 0.2)
		_combo_wave_at(aim)


## The Thousandth Cut gathers with every swing that lands (not every foe one
## sweep touches) and every foe it fells, and keeps what it gathered between
## fights - it only fades after four seconds without a blow. Measured with
## `-- legendlab` (src/dev/legend_lab.gd): as "thirty blows in a row" it came
## after 48 s in small fights and 18 times a minute in a crowd.
const THOUSANDTH := 70
var blade_charge := 0.0
var _blade_idle := 0.0
var _blade_cued := false


func _gather_blade(n: float) -> void:
	blade_charge += n
	_blade_idle = 0.0
	if blade_charge >= THOUSANDTH:
		blade_charge = 0.0
		_blade_cued = false
		_thousandth_cut()
	elif blade_charge >= THOUSANDTH * 0.8 and not _blade_cued:
		# nearly there: the blade hums (heard and seen by its wielder)
		_blade_cued = true
		Audio.play("glyph", -8.0, 1.4)
	_legend_glow(blade_charge / THOUSANDTH)


## A signature weapon brightens as its moment gathers (the HUD gauge says it
## too, but the eye is on the blade).
func _legend_glow(k: float) -> void:
	form_meter = k
	if weapon and weapon.visual:
		weapon.visual.set_instance_shader_parameter("glow_mult", weapon._base_glow * (1.0 + 1.6 * clampf(k, 0.0, 1.0)))


## The Thousandth Cut (the unique blade): the thirtieth blow in a row is eight
## phantom cuts, one after another, through everything around the Kindled.
func _thousandth_cut() -> void:
	set_meta("legend_moments", int(get_meta("legend_moments", 0)) + 1)
	var col := Color(0.85, 0.65, 1.0)
	stage.fx.number(pos, 2.8, "THE THOUSANDTH CUT", col, true)
	stage.fx.flash_light(pos, 1.0, col, 3.0, 6.0, 0.4)
	Audio.play("riposte", 0.0, 0.8)
	for k in 8:
		var a := k * TAU / 8.0 + randf() * 0.3
		stage.after(0.05 * k, func() -> void:
			if not alive:
				return
			var d := Vector2.from_angle(a)
			stage.fx.swipe(pos, d, 3.0, deg_to_rad(50.0), Color(col.r, col.g, col.b, 0.9), 0.08, 0.45, k % 2 == 0)
			Audio.play("swing", -6.0, 1.3 + 0.03 * k)
			for f in stage.in_arc(team, pos, d, 3.0, deg_to_rad(28.0)):
				var h := Combat.player_hit(self, stats, 14.0, ["melee", "shadow"])
				h.proc = false
				h.from_dir = d
				h.knockback = d * 3.0
				h.poise = 10.0
				deal_hit(f, h))


## A spectral knife at another foe near `t` (or `t` itself): Thousand Cuts,
## Gloamfang. It cannot set off more knives.
func spectral_knife(t: Actor) -> void:
	var other: Actor = null
	var bd := 7.0
	for a in stage.hostiles(team):
		if a != t and a.targetable and a.pos.distance_to(pos) < bd and stage.grid.line_clear(pos, a.pos):
			bd = a.pos.distance_to(pos)
			other = a
	var to := other if other else t
	if to == null or not is_instance_valid(to):
		return
	var dmg: float = (6.0 + 0.35 * (float(weapon.def.damage[0]) if weapon else 10.0)) * (weapon.damage_scale() if weapon else 1.0)
	var me := self
	Volley.fire(self, "proj_knife", pos, (to.pos - pos).normalized(), 24.0, 1, func(pr: Projectile, _d: Vector2) -> void:
		pr.damage = dmg
		pr.tags = ["melee", "shadow"]
		pr.life = 0.4
		pr.height = 0.7
		pr.spin = true
		pr.reflectable = false
		pr.trail_color = Color(0.72, 0.5, 1.0)
		pr.trail_rate = 24.0
		pr.make_hit_fn = func(proj: Projectile, _x: Actor) -> Hit:
			var hh := Combat.player_hit(me, me.stats, proj.damage, proj.tags.duplicate())
			hh.proc = false
			hh.from_dir = proj.vel.normalized()
			return hh)


## A cutting wave of embers along `dir` (Momentum at its peak).
func _combo_wave_at(dir: Vector2) -> void:
	var pr := Projectile.create(stage, "proj_wave", pos + dir * 0.6, dir * 13.0, team)
	pr.source = self
	pr.damage = 0.6 * (weapon.def.damage[0] if weapon else 12.0) * (weapon.damage_scale() if weapon else 1.0)
	pr.tags = ["melee", "ranged"]
	pr.pierce = 3
	pr.radius = 0.45
	pr.life = 0.45
	pr.spin = true
	pr.knockback = 4.0
	pr.trail_color = Color(1.0, 0.8, 0.45)
	pr.trail_rate = 40.0
	pr.reflectable = false


## Attack speed from Momentum (Weapon.speed reads it).
func flow_speed() -> float:
	return 1.0 + 0.04 * momentum if stats.has("momentum") else 1.0


## Effects from unique gear when a hit lands.
func _unique_on_hit(t: Actor, h: Hit, res: Combat.Result, direct: bool) -> void:
	if stats.has("lifesteal") and direct and h.has_tag("melee") and alive:
		hp = minf(max_hp, hp + res.amount * 0.04)
	if res.crit and h.proc and stats.has("gamblers_coin") and randf() < 0.1:
		for i in 4:
			Pickup.spawn(stage, "ember", t.pos, 2)
		stage.fx.number(t.pos, 2.8, "KA-CHING!", Color(1.0, 0.85, 0.3), true)
		Audio.play("pickup_ember", 0.0, 1.6)
	if res.crit and h.proc and direct and stats.has("storm_crit"):
		_call_lightning(t, res.amount)
	if direct and h.proc and h.has_tag("melee") and stats.has("echo_strike"):
		_echo_n += 1
		if _echo_n % 4 == 0:
			Player._echo_later(stage, weakref(self), weakref(t), h.amount * 0.6, h.from_dir)


## A delayed second strike (static so it never captures a freed player or target).
static func _echo_later(st: Stage, pref: WeakRef, tref: WeakRef, amount: float, dir: Vector2) -> void:
	st.after(0.14, func() -> void:
		var pl: Player = pref.get_ref()
		var tg: Actor = tref.get_ref()
		if pl == null or tg == null or not is_instance_valid(tg) or not tg.alive:
			return
		var e := Combat.player_hit(pl, pl.stats, amount, ["melee"])
		e.proc = false
		e.from_dir = dir
		e.knockback = dir * 2.0
		st.fx.ghost(pl.sprite, pl.global_position + pl.sprite.position + pl.visual.position, Color(0.45, 0.95, 0.9), 0.2)
		st.fx.impact(tg.pos, 0.8, Color(0.5, 1.0, 0.95), false, dir)
		Audio.play("swing", -6.0, 1.4)
		pl.deal_hit(tg, e))


## Stormcaller Signet: lightning on a nearby enemy (not the one just hit if others are near).
## Ashbringer: a patch of burning ground; foes in it are marked to take more.
func _ash_ground(at: Vector2) -> void:
	var me := self
	var hz := Hazard.spawn(stage, at, 1.2, 3.0, team, Color(1.0, 0.45, 0.15), func(_hz: Hazard, a: Actor) -> void:
		a.set_meta("ashen_until", me.stage.elapsed + 0.6)
		var dh := Combat.player_hit(me, me.stats, 3.0, ["fire", "dot"])
		dh.can_crit = false
		dh.silent = true
		dh.proc = false
		me.deal_hit(a, dh))
	hz.period = 0.4
	hz.particle_rate = 8.0


## Runes that act on each spell hit: Arcing, Ruin and Kindling.
func _rune_on_hit(t: Actor, h: Hit, res: Combat.Result, runes: Array) -> void:
	if runes.has("siphon"):
		gain_kindle(4.0 / maxf(stats.v("kindle_gain"), 0.01))
		heal(max_hp * 0.01)
	if runes.has("chain"):
		var done := [t]
		var from := t
		for k in 2:
			var best: Actor = null
			var bd := 4.0
			for a in stage.hostiles(team):
				if done.has(a):
					continue
				var dd := a.pos.distance_to(from.pos)
				if dd < bd:
					bd = dd
					best = a
			if best == null:
				break
			done.append(best)
			var col := Color(0.6, 0.9, 1.0)
			var seg := best.pos - from.pos
			stage.fx.shape(Fx.Shape.RECT, from.pos, seg.normalized(), Vector2(seg.length(), 0.18), Color(col.r, col.g, col.b, 0.6), col.lightened(0.4), 0.14, {"progress": 1.0, "glow": 2.0})
			stage.fx.burst(best.pos, 0.6, col, 6, 3.0, 0.2, 0.0)
			var ch := Combat.player_hit(self, stats, 1.0, h.tags.duplicate())
			ch.amount = res.amount * 0.5
			ch.proc = false
			ch.can_crit = false
			ch.from_dir = seg.normalized()
			deal_hit(best, ch)
			from = best
		Audio.play_at("bolt", t.pos, -6.0, 1.4, 80)
	if runes.has("volatile") and not t.alive:
		var p := t.pos
		var dmg := t.max_hp * 0.4
		stage.fx.ring(p, 2.2, Color(1.0, 0.5, 0.25), 0.25, 0.3)
		stage.fx.burst(p, 0.5, Color(1.0, 0.55, 0.25), 18, 5.0, 0.4, 2.0)
		Audio.play_at("explode", p, -4.0, 1.2)
		stage.strike_props_circle(p, 2.2, self, true)
		for a in stage.in_circle(team, p, 2.2):
			var vh := Combat.player_hit(self, stats, 1.0, ["fire", "ability"])
			vh.amount = dmg
			vh.proc = false
			vh.knockback = (a.pos - p).normalized() * 6.0
			deal_hit(a, vh)


func _call_lightning(from: Actor, amount: float) -> void:
	var best: Actor = null
	var bd := 5.0
	for a in stage.hostiles(team):
		var d := a.pos.distance_to(from.pos)
		if a != from and d < bd:
			bd = d
			best = a
	if best == null:
		best = from
	for i in 6:
		stage.fx.burst(best.pos, 0.3 + i * 0.45, Color(0.7, 0.85, 1.0), 2, 1.5, 0.15, 0.0)
	stage.fx.impact(best.pos, 0.6, Color(0.6, 0.85, 1.0), true)
	stage.fx.flash_light(best.pos, 2.0, Color(0.6, 0.8, 1.0), 4.0, 5.0, 0.18)
	stage.fx.ring(best.pos, 1.2, Color(0.7, 0.9, 1.0), 0.2, 0.2)
	Audio.play("crit", -2.0, 0.6)
	var e := Combat.player_hit(self, stats, 18.0 + amount * 0.3, ["frost"])
	e.can_crit = false
	e.proc = false
	e.from_dir = (best.pos - pos).normalized()
	deal_hit(best, e)


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
	stage.strike_props_circle(t.pos, 2.2, self, false)
	for a in stage.in_circle(team, t.pos, 2.2):
		var h := Combat.player_hit(self, stats, 32.0, ["fire", "frost"])
		h.proc = false
		h.knockback = (a.pos - t.pos).normalized() * 4.0
		h.from_dir = (a.pos - t.pos).normalized()
		deal_hit(a, h)


# --- taking damage ---------------------------------------------------------------------

## All enemy damage to the player passes through here (dodge, ward, aegis, barrier).
func take_enemy_hit(h: Hit, attacker: Node) -> Combat.Result:
	var prev := Net.actor_peer
	Net.actor_peer = peer_id
	Net.actor_pos = pos
	var res := _take_enemy_hit(h, attacker)
	Net.actor_peer = prev
	return res


func _take_enemy_hit(h: Hit, attacker: Node) -> Combat.Result:
	var empty := Combat.Result.new()
	if not alive or godmode or away:
		return empty
	if dodge_t > 0.0 or (invuln_t > 0.0 and dodge_age < stats.v("dodge_iframes") + 0.02):
		if dodge_age <= PERFECT_WINDOW and not perfect_done and not h.has_tag("dot"):
			_perfect_dodge()
		return empty
	if invuln_t > 0.0:
		return empty
	if controller == Ctrl.REMOTE and lag_grace > 0.0 and not _settling and not h.has_tag("dot") and ward_t <= 0.0:
		_deferred.append([stage.elapsed + lag_grace, h, attacker])
		return empty
	if hearthcall_t >= 0.0:
		break_hearthcall("The call is broken!")
	if ward_t > 0.0 and not h.has_tag("dot") and not h.unblockable:
		_on_ward(attacker, false)
		return empty
	# a stance weapon (the Sabre's En Garde, the Partisan's line) takes it
	if weapon and not h.has_tag("dot") and weapon.guard_hit(h, attacker):
		return empty
	if not h.has_tag("dot") and not h.unblockable and stage.players.size() > 1:
		for ally in stage.players_near(pos, 4.0):
			if ally != self and ally.ward_t > 0.0 and ally.stats.has("bastion"):
				ally._on_ward(attacker, false)
				stage.fx.ring(pos, 1.2, Color(1.0, 0.85, 0.45), 0.25, 0.25)
				return empty
	if stats.has("hearthguard") and kindle >= stats.v("kindle_max") - 0.01:
		h.amount *= 0.85
	if shelter_t > 0.0:
		h.amount *= 0.9
	if marked_t > 0.0:
		h.amount *= 1.25     # an Ash Herald's decree
	_calm_t = 0.0
	if stats.has("last_light") and kindle > 0.0 and not h.has_tag("dot"):
		# Last Light: the lantern's flame takes the blow before you do
		var soak := minf(kindle, h.amount)
		kindle -= soak
		h.amount -= soak
		stage.fx.burst(pos, 0.9, Color(1.0, 0.8, 0.4), 5, 2.5, 0.25, 0.0)
		if h.amount <= 0.0:
			return empty
	if stats.has("rime_set4") and attacker is Actor and is_instance_valid(attacker) and ((attacker as Actor).status.chill > 0.0 or (attacker as Actor).status.is_frozen()):
		h.amount *= 0.85
	if aegis_t > 0.0 and aegis_hp > 0.0:
		var ab := minf(aegis_hp, h.amount)
		aegis_hp -= ab
		h.amount -= ab
		stage.fx.burst(pos, 0.8, Color(1.0, 0.85, 0.45), 6, 3.0, 0.3, 0.0)
		if aegis_hp <= 0.0:
			aegis_t = 0.0
			stage.fx.ring(pos, 1.5, Color(1.0, 0.8, 0.4), 0.25, 0.3)
			_aegis_broken()
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
		if run:
			run.note_blow(stage.elapsed, _blow_name(attacker, h), res.amount)
		if weapon:
			weapon.on_hurt()
		hurt_t = 0.25
		invuln_t = maxf(invuln_t, 0.5)
		if attacker is Enemy and is_instance_valid(attacker):
			(attacker as Enemy).landed_on(self)
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
			if attacker is Enemy and (attacker as Enemy).has_affix("vampiric"):
				at.heal(res.amount * 1.5)
		if stats.has("hearthguard"):
			gain_kindle(10.0 / maxf(stats.v("kindle_gain"), 0.01))
		if stats.has("bramble_burst"):
			_bramble_burst(res.amount)
		if stats.has("retribution"):
			retribution = minf(max_hp, retribution + res.amount)
		# Hearthbond: friends who carry it feel the blow, and their flame answers
		for ally in stage.players_near(pos, 5.0):
			if ally != self and ally.stats.has("hearthbond"):
				ally.gain_kindle(4.0)
	return res


## Retribution: every blow taken since the last Ward bursts out of this one,
## doubled.
func _retribute() -> void:
	var dmg := retribution * 2.0
	retribution = 0.0
	stage.fx.ring(pos, 3.0, Color(1.0, 0.9, 0.6), 0.3, 0.3)
	stage.fx.burst(pos, 0.8, Color(1.0, 0.85, 0.5), 20, 5.0, 0.4, 1.0)
	stage.fx.shake(0.3)
	Audio.play("aegis", -2.0, 0.7)
	stage.strike_props_circle(pos, 3.0, self, false)
	for a in stage.in_circle(team, pos, 3.0):
		var h := Combat.player_hit(self, stats, dmg, ["melee"])
		h.knockback = (a.pos - pos).normalized() * 9.0
		h.poise = 60.0
		h.proc = false
		deal_hit(a, h)


## Thornmail: thorns burst out at everything within reach.
## Runes on the Aegis: the Well pulls foes in as it breaks; Echoes re-form it once.
func _aegis_broken() -> void:
	if Runes.has(self, "aegis", "gravity"):
		stage.fx.ring(pos, 3.5, Color(0.5, 0.95, 0.9), 0.35, 0.3)
		for a in stage.in_circle(team, pos, 3.5):
			var h := Combat.player_hit(self, stats, 8.0, ["ability"])
			h.knockback = (pos - a.pos).normalized() * 9.0
			h.poise = 40.0
			deal_hit(a, h)
	if aegis_echo:
		aegis_echo = false
		var me := self
		stage.after(0.3, func() -> void:
			if is_instance_valid(me) and me.alive:
				me.aegis_hp = GearDB.ability("aegis").absorb * 0.5
				me.aegis_t = 3.0
				me.stage.fx.ring(me.pos, 1.4, Color(0.45, 1.0, 0.85), 0.3, 0.3)
				Audio.play_at("aegis", me.pos, -4.0, 1.2))


func _bramble_burst(taken: float) -> void:
	stage.fx.burst(pos, 0.6, Color(0.5, 0.75, 0.3), 16, 5.0, 0.3, 3.0)
	stage.fx.ring(pos, 2.6, Color(0.55, 0.8, 0.35), 0.2, 0.2)
	stage.strike_props_circle(pos, 2.6, self, false)
	for a in stage.in_circle(team, pos, 2.6):
		var th := Hit.make(self, taken * 2.0, ["melee"])
		th.can_crit = false
		th.proc = false
		th.knockback = (a.pos - pos).normalized() * 4.0
		deal_hit(a, th)


## Mothwing Cloak: an ember moth flies from the lantern to the nearest foe.
func _moth(dt: float) -> void:
	_moth_t -= dt
	if _moth_t > 0.0:
		return
	_moth_t = 2.0
	var best: Actor = null
	var bd := 8.0
	for a in stage.hostiles(team):
		var d := a.pos.distance_to(pos)
		if d < bd and a.targetable:
			bd = d
			best = a
	if best == null:
		return
	var d0 := (best.pos - pos).normalized()
	var pr := Projectile.create(stage, "proj_ember", pos + d0 * 0.4, d0.rotated(randf_range(-0.8, 0.8)) * 7.0, team)
	pr.source = self
	pr.damage = 6.0 * (1.0 + stats.v("fire_damage")) * stats.v("damage_more")
	pr.tags = ["ability", "fire"]
	pr.homing_target = best
	pr.homing_turn = 4.0
	pr.life = 2.5
	pr.burn = 1
	pr.reflectable = false
	Audio.play("wisp", -14.0, 1.6)


func _perfect_dodge() -> void:
	perfect_done = true
	if weapon:
		weapon.on_evade()
	stage.slow_motion(0.3, 0.35)
	Settings.rumble(0.6, 0.0, 0.12)
	stage.fx.ring(pos, 1.8, Color(1.0, 0.9, 0.6), 0.3, 0.15)
	stage.fx.number(pos, 2.4, "PERFECT", Color(1.0, 0.9, 0.55))
	Audio.play("perfect", -2.0)
	gain_kindle(15.0 / maxf(stats.v("kindle_gain"), 0.01))
	if stats.has("perfect_refund"):
		dodge_charges = minf(stats.v("dodge_charges"), dodge_charges + 1.0)
		gain_kindle(25.0)
	if stats.has("hourglass"):
		stage.slow_motion(0.2, 0.9)
		dodge_charges = minf(stats.v("dodge_charges"), dodge_charges + 1.0)
		stage.fx.ring(pos, 3.2, Color(0.55, 0.9, 1.0), 0.6, 0.12)
	if stats.has("gloam_set4"):
		ability_cd = [0.0, 0.0, 0.0]
		stage.fx.number(pos, 2.0, "COOLDOWNS RESET", Color(0.8, 0.55, 1.0))
	if stats.has("counterstep"):
		counter_ready = true
	if stats.has("perfect_answer"):
		answer_ready = true
	Events.perfect_dodge.emit()


func _on_ward(attacker: Node, projectile: bool) -> void:
	if stats.has("perfect_answer"):
		answer_ready = true
	if stats.has("deep_mirror") and mirror_t <= 0.0 and last_spell != "" and not predicting:
		mirror_t = 6.0
		Abilities.cast(self, last_spell, 0.8)
		stage.fx.number(pos, 2.4, "ANSWERED", Color(0.55, 0.9, 1.0))
	if weapon:
		weapon.on_evade()
	if stats.has("retribution") and retribution > 1.0:
		_retribute()
	ward_t = 0.0
	ward_cd = 0.1
	ward_recover = 0.0
	stage.hitstop(0.1)
	stage.fx.ring(pos, 1.6, Color(1.0, 0.85, 0.45), 0.25, 0.3)
	stage.fx.burst(pos + aim * 0.5, 0.8, Color(1.0, 0.9, 0.6), 14, 6.0, 0.3, 4.0)
	stage.fx.flash_light(pos, 1.0, Color(1.0, 0.8, 0.45), 3.0, 4.0, 0.2)
	stage.fx.number(pos, 2.4, "WARD", Color(1.0, 0.9, 0.55))
	if stats.has("counterweight") and weapon:
		# the blow you turned becomes the one you strike
		weapon.cancel()
		if weapon.has_method("inscribe"):
			for k in 5:
				stage.after(k * 0.06, func() -> void:
					if alive and weapon and weapon.has_method("_mote"):
						weapon._mote())
		else:
			weapon.aim_dir = aim
			weapon.charged = true
			weapon.release_charge()
	if stats.has("bastion"):
		ward_cd = 0.6
		stage.fx.ring(pos, 3.0, Color(1.0, 0.85, 0.45), 0.3, 0.3)
		for a in stage.in_circle(team, pos, 3.0):
			var bh := Combat.player_hit(self, stats, 12.0, ["melee"])
			bh.knockback = (a.pos - pos).normalized() * 9.0
			bh.poise = 35.0
			bh.proc = false
			deal_hit(a, bh)
	if stats.has("mirror_ward") and not projectile and attacker is Enemy and is_instance_valid(attacker) and (attacker as Enemy).alive:
		var en := attacker as Enemy
		var mh := Hit.make(self, en.damage * 3.0, ["melee"])
		mh.can_crit = false
		mh.knockback = (en.pos - pos).normalized() * 6.0
		deal_hit(en, mh)
		stage.fx.number(en.pos, 2.2, "MIRRORED", Color(0.7, 0.9, 1.0))
	stage.fx.shake(0.2)
	Audio.play("parry", 0.0)
	gain_kindle(15.0 / maxf(stats.v("kindle_gain"), 0.01))
	if stats.has("riposte"):
		riposte_t = 2.0
	if stats.has("ward_barrier"):
		barrier = 20.0
		barrier_t = 4.0
	if stats.has("rime_set4"):
		barrier = maxf(barrier, 30.0)
		barrier_t = 4.0
		stage.fx.ring(pos, 2.4, Color(0.7, 0.9, 1.0), 0.3, 0.3)
		for a in stage.in_circle(team, pos, 2.6):
			if a.status.apply_chill(2.5):
				a.on_frozen()
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
	if stage.players.size() > 1 and not downed and not _bled_out:
		_go_down()
		return
	_deferred.clear()
	alive = false
	downed = false
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


# --- co-op: downed and revived -------------------------------------------------

static var _ring_tex: ImageTexture

## Co-op: a ring of the seat's colour on the floor under this Kindled, so four
## of them in one fight can always be told apart (and each finds their own).
## Co-op: a ring in the seat's colour under this Kindled. Your own is
## brighter, doubled and breathing, so you can find yourself in a crowd.
func set_seat(col: Color, mine := false) -> void:
	if has_node("SeatRing"):
		return     # a seat is worn once
	if _ring_tex == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		for y in 24:
			for x in 24:
				var d := Vector2(x + 0.5 - 12.0, y + 0.5 - 12.0).length()
				if d > 9.0 and d < 11.5:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 10.6 else 0.55))
		_ring_tex = ImageTexture.create_from_image(img)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1 * 0.55 * Iso.SQ2)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = _ring_tex
	mat.albedo_color = Color(col.r, col.g, col.b, 0.75 if not mine else 1.0)
	mi.name = "SeatRing"
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.02, 0)
	add_child(mi)
	if mine:
		q.size *= 1.15
		# a second, inner ring of warm light that breathes
		var inner := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = q.size * 0.72
		q2.orientation = PlaneMesh.FACE_Y
		inner.mesh = q2
		var m2 := mat.duplicate() as StandardMaterial3D
		m2.albedo_color = Color(1.0, 0.85, 0.55, 0.8)
		inner.material_override = m2
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inner.position = Vector3(0, 0.025, 0)
		add_child(inner)
		var tw := inner.create_tween().set_loops()
		tw.tween_property(m2, "albedo_color:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m2, "albedo_color:a", 0.8, 0.9).set_trans(Tween.TRANS_SINE)


## Co-op client: the picture of a Kindled the host simulates.
func replica_present(dt: float) -> void:
	if can_predict():
		_predict(dt)
		return
	super.replica_present(dt)
	_update_lantern(dt)
	if weapon and alive and not downed:
		weapon.update_visual(dt)
	if downed and fmod(stage.elapsed, 0.5) < dt:
		stage.fx.motes(pos, 0.2, Color(1.0, 0.55, 0.4), 1, 0.8, 0.8, 0.2)


## Co-op client: the host brought this one back.
func revive_replica() -> void:
	alive = true
	downed = false
	sprite.visible = true
	sprite.set_dissolve(0.0)
	if weapon == null or weapon.visual == null:
		set_weapon(run.weapon_id if run else "sword", run.weapon_level if run else 0)


## At 0 health with friends about, the Kindled falls but its light holds for a
## while: an ally who stands beside it long enough brings it back.
func _go_down() -> void:
	_deferred.clear()
	downed = true
	hp = 0.0
	bleed_t = BLEED_TIME
	revive_k = 0.0
	targetable = false
	vel = Vector2.ZERO
	move_in = Vector2.ZERO
	if weapon:
		weapon.cancel()
	if hearthcall_t >= 0.0:
		break_hearthcall()
	sprite.play("death", true)
	stage.fx.burst(pos, 0.5, Color(1.0, 0.6, 0.3), 20, 2.5, 0.9, -0.5)
	stage.fx.number(pos, 2.6, "DOWN", Color(1.0, 0.55, 0.45), true)
	Audio.play_at("player_death", pos, -4.0, 1.1)
	stage.notify_death(self, null)


func _bleed(dt: float) -> void:
	vel = Vector2.ZERO
	var helper := false
	for pl in stage.active_players():
		if pl != self and pl.pos.distance_to(pos) < 1.6:
			helper = true
	if helper:
		revive_k += dt / REVIVE_TIME
		if fmod(revive_k * 10.0, 1.0) < dt * 4.0:
			stage.fx.motes(pos, 0.3, Color(1.0, 0.8, 0.45), 2, 1.4, 0.7, 0.4)
		if revive_k >= 1.0:
			revive(0.4)
			return
	else:
		revive_k = maxf(0.0, revive_k - dt * 0.5)
		bleed_t -= dt
	sync_visual()
	if bleed_t <= 0.0:
		downed = false
		hp = 0.0
		alive = true      # die() expects the living
		_bled_out = true  # ...and must not lay them down again (it looped)
		die(null)
		_bled_out = false


## Back on their feet (from downed, or from a spectator at a room's end).
func revive(frac: float) -> void:
	downed = false
	alive = true
	targetable = true
	hp = maxf(1.0, max_hp * frac)
	revive_k = 0.0
	invuln_t = 1.5
	if weapon == null or weapon.visual == null:
		set_weapon(run.weapon_id if run else "sword", run.weapon_level if run else 0)
	sprite.visible = true
	sprite.set_dissolve(0.0)
	sprite.play("idle_" + dir_name, true)
	stage.fx.ring(pos, 1.6, Color(1.0, 0.8, 0.45), 0.4, 0.25)
	stage.fx.motes(pos, 0.2, Color(1.0, 0.75, 0.4), 16, 1.8, 1.0, 0.4)
	stage.fx.number(pos, 2.6, "REKINDLED", Color(1.0, 0.8, 0.5), true)
	Audio.play_at("hearth_feed", pos, -4.0)


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
	if stats.has("glass_lantern"):
		rng *= 1.4
		en *= 1.15
	if stats.has("lantern_edge"):
		rng *= 1.3
	if stage is Dungeon and (stage as Dungeon).rule_here() == "unlit":
		rng *= 0.5
		en *= 0.75
	if snuffed_t > 0.0:
		snuffed_t -= dt
		rng *= 0.5
		en *= 0.55
	if stage is Dungeon and String(Delve.band((stage as Dungeon).layout.depth).get("id", "")) == "thin":
		rng *= 0.8
	gloom_t -= dt
	# a faint drift of light in the colour of each great thing worn
	if not aura_cols.is_empty() and hearthcall_t < 0.0:
		_gear_aura_t -= dt
		if _gear_aura_t <= 0.0:
			_gear_aura_t = 0.42 / aura_cols.size()
			var ac: Color = aura_cols[randi() % aura_cols.size()]
			stage.fx.motes(pos + Vector2.from_angle(randf() * TAU) * randf_range(0.25, 0.5), randf_range(0.1, 0.9), ac, 1, 0.5, 0.9, 0.05)
	_gloom_k = move_toward(_gloom_k, 1.0 if gloom_t > 0.0 else 0.0, dt * 2.5)
	if _gloom_k > 0.0:
		rng *= lerpf(1.0, 0.65, _gloom_k)
		en *= lerpf(1.0, 0.75, _gloom_k)
	if hearthcall_t >= 0.0:
		# the lantern swells as the Hearth answers
		var hk := clampf(hearthcall_t / HEARTHCALL_TIME, 0.0, 1.0)
		en *= 1.0 + 2.2 * hk * hk
		rng *= 1.0 + 0.35 * hk
	lantern.omni_range = rng
	lantern.light_energy = en
	var side := 1.0 if look.x >= 0.0 else -1.0
	lantern.position = Vector3(0.3 * side, (1.05 + bob) * Iso.SQ2, 0.3)


## A full (4-piece) tier set wreathes the Kindled in its element.
func _set_aura(dt: float) -> void:
	var col := Color.TRANSPARENT
	var rise := 1.2
	if stats.has("ember_set4"):
		col = Color(1.0, 0.6, 0.25)
	elif stats.has("rime_set4"):
		col = Color(0.7, 0.9, 1.0)
		rise = 0.5
	elif stats.has("gloam_set4"):
		col = Color(0.75, 0.45, 1.0)
	elif stats.has("verdant_set4"):
		col = Color(0.55, 1.0, 0.45)
		rise = 0.8
	if col.a <= 0.0:
		return
	_aura_t += dt
	if _aura_t > 0.09:
		_aura_t = 0.0
		stage.fx.motes(pos + Vector2(randf_range(-0.35, 0.35), randf_range(-0.1, 0.2)), 0.2, col, 1, rise, 0.9, 0.15)


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
		if stats.has("ember_steps"):
			stage.fx.splat(pos + Vector2(randf_range(-0.1, 0.1), 0.1), Color(0.2, 0.09, 0.05), 3.5, 0.45)
			stage.fx.burst(pos, 0.05, Color(1.0, 0.6, 0.25), 3, 1.0, 0.35, -1.0)
		if stats.has("squeaky"):
			Audio.play("squeak", -8.0, randf_range(0.9, 1.15))
			if randf() < 0.12:
				var e := stage.nearest_hostile(team, pos, 5.0, false)
				if e and e is Enemy and not (e as Enemy).def.get("boss", false):
					e.status.stagger_t = maxf(e.status.stagger_t, 0.8)
					stage.fx.number(e.pos, 2.2, "?", Color(1.0, 0.95, 0.6), true)
		# a little dust kicked up behind the foot
		var dust := Color(0.32, 0.36, 0.26) if moss else Color(0.45, 0.42, 0.42)
		stage.fx.burst(pos + Vector2(0, 0.15), 0.05, dust, 2, 0.8, 0.3, -0.6, -vel.normalized() if vel.length() > 0.1 else Vector2.ZERO, 0.9, 0.6)
		_foot_i += 1 + (randi() % 2)
	_last_foot = f


# --- Hearthcall ------------------------------------------------------------------

## Why the Hearth can't be called right now ("" when it can).
func hearthcall_blocked() -> String:
	if not (stage is Dungeon):
		return "You are already home"
	var d := stage as Dungeon
	if d.run == null or d.run.result != "":
		return "No"
	if d.boss and is_instance_valid(d.boss) and d.boss.alive:
		return "The Hearth can't hear you over this"
	return ""


func start_hearthcall() -> void:
	var why := hearthcall_blocked()
	if why != "":
		stage.fx.number(pos, 2.4, why, Color(1.0, 0.6, 0.5))
		Audio.play("deny", -4.0)
		return
	hearthcall_t = 0.0
	_hc_fx_t = 0.0
	move_in = Vector2.ZERO     # the Kindled plants its feet (walking on breaks the call)
	if weapon:
		weapon.cancel()
	cast_t = 0.0
	Audio.play("hearthcall", -2.0)
	stage.fx.number(pos, 2.6, "HEARTHCALL", Color(1.0, 0.8, 0.45), true)
	_hc_shapes.clear()
	_hc_shapes.append(stage.fx.shape(Fx.Shape.SIGIL, pos, Vector2.RIGHT, Vector2(3.6, 3.6), Color(1.0, 0.7, 0.3, 0.35), Color(1.0, 0.86, 0.5, 1.0), HEARTHCALL_TIME + 0.1, {"glow": 1.8}))
	# a ring of hearth-light closing on the Kindled: when it reaches them, they go
	var ring := stage.fx.shape(Fx.Shape.RING, pos, Vector2.RIGHT, Vector2(5.2, 5.2), Color(1.0, 0.75, 0.35, 0.6), Color(1.0, 0.92, 0.65, 1.0), HEARTHCALL_TIME + 0.1, {"inner": 0.88, "glow": 2.0})
	_hc_shapes.append(ring)
	var data: Dictionary = stage.fx._shapes[stage.fx._shapes.size() - 1]
	var origin := ring.transform.origin
	data.update = func(t: float, n: MeshInstance3D) -> void:
		var rr := lerpf(2.6, 0.45, clampf(t / HEARTHCALL_TIME, 0.0, 1.0))
		n.transform = Transform3D(Basis(Vector3(rr * 2.0, 0, 0), Vector3.UP, Vector3(0, 0, rr * 2.0 * Iso.SQ2)), origin)
		n.set_instance_shader_parameter("px_size", rr * 2.0 * Iso.PPU)


func _tick_hearthcall(dt: float) -> void:
	hearthcall_t += dt
	var k := clampf(hearthcall_t / HEARTHCALL_TIME, 0.0, 1.0)
	_hc_fx_t -= dt
	while _hc_fx_t <= 0.0:
		_hc_fx_t += lerpf(0.06, 0.02, k)
		# embers drawn in from the dark, sparks rising off the lantern
		var from := pos + Vector2.from_angle(randf() * TAU) * lerpf(2.8, 1.2, k)
		stage.fx.burst(from, 0.2 + k * 0.6, Color(1.0, 0.68, 0.3), 1, 3.0 + 3.0 * k, 0.45, -1.0, (pos - from).normalized(), 0.12, 0.8)
		stage.fx.motes(pos, 0.5 + k * 1.4, Color(1.0, 0.86, 0.55), 1, 2.0 + 3.0 * k, 0.9, 0.5)
	if k >= 1.0:
		_complete_hearthcall()


func _complete_hearthcall() -> void:
	hearthcall_t = -1.0
	if Net.active() and Net.party_size() > 1 and Net.i.run_sync:
		# the whole party goes home, or nobody does
		Net.i.run_sync.start_vote("hearthcall", -1, self)
		return
	input_enabled = false
	invuln_t = 5.0
	Audio.play("hearthcall_go", 0.0)
	stage.fx.flash_light(pos, 2.0, Color(1.0, 0.78, 0.45), 9.0, 14.0, 1.0)
	for i in 3:
		stage.fx.burst(pos, 0.4 + i * 0.9, Color(1.0, 0.8, 0.45), 26, 6.0, 0.9, -4.0, Vector2.ZERO, PI, 7.0)
	stage.fx.ring(pos, 3.0, Color(1.0, 0.85, 0.5), 0.45, 0.3)
	stage.fx.shake(0.3)
	var tw := create_tween()
	tw.tween_method(sprite.set_dissolve, 0.0, 1.0, 0.6)
	if weapon and is_instance_valid(weapon.visual):
		weapon.visual.visible = false
	Events.toast.emit("The Last Hearth answers.", Color(1.0, 0.8, 0.45))
	stage.after(0.8, func() -> void:
		if Game.run and Game.run.result == "":
			Game.end_run("extracted"))


func break_hearthcall(why := "") -> void:
	if hearthcall_t < 0.0:
		return
	hearthcall_t = -1.0
	for s in _hc_shapes:
		if is_instance_valid(s):
			stage.fx.release(s)
	_hc_shapes.clear()
	Audio.play("hearthcall_break", -4.0)
	stage.fx.burst(pos, 0.8, Color(0.6, 0.5, 0.45), 12, 2.5, 0.5, 3.0)
	if why != "":
		stage.fx.number(pos, 2.4, why, Color(1.0, 0.55, 0.45))


func _update_look(dt: float) -> void:
	_fight_look_t = maxf(0.0, _fight_look_t - dt)
	var busy: bool = weapon != null and weapon.has_method("is_busy") and weapon.is_busy()
	if _attack_down or busy or cast_t > 0.0 or ward_t > 0.0 or _buf.attack > 0.0:
		_fight_look_t = 0.45
	# priority: a dodge > fighting (attack, charge, cast, Ward: toward the aim)
	# > walking (toward the walk) > a pointer the hand moved > the last facing
	if _fight_look_t > 0.0 or _pad_aim or aim_look_t > 0.0:
		# the pad's aim already follows the left stick when the right one rests;
		# a hand aiming the mouse faces the aim even while walking another way
		look = aim
	elif move_in.length() > 0.2:
		look = move_in.normalized()
	elif _mouse_moved:
		look = aim
	if dodge_t > 0.0 and dodge_dir.length() > 0.1:
		look = dodge_dir
	if controller == Ctrl.REMOTE and remote_look.length() > 0.1:
		# a guest's Kindled faces where its owner's machine has it facing, so
		# every screen draws the same Kindled the same way
		look = remote_look
	_mouse_moved = false
	_last_aim = aim


func _update_anim() -> void:
	if not alive:
		return
	var ad := look
	# three drawn directions; a diagonal keeps the one already shown (a little
	# hysteresis), so W+D after W stays "up" and after D stays "side"
	var side_now := dir_name == "side"
	var side := absf(ad.x) > absf(ad.y) * (0.7 if side_now else 1.15)
	if side:
		dir_name = "side"
	elif ad.y < 0.0:
		dir_name = "up"
	else:
		dir_name = "down"
	var a := "idle_"
	if hearthcall_t >= 0.0:
		# the ritual faces the camera, lantern raised
		dir_name = "down"
		ad = Vector2.DOWN
	if dodge_t > 0.0:
		a = "dash_"
	elif hurt_t > 0.0:
		a = "hurt_"
	elif cast_t > 0.0 or ward_t > 0.0 or flask_t > 0.0 or hearthcall_t >= 0.0:
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


## How the spells of the moment show on the Kindled (every machine draws its
## own, from the timers or the host's flags - never sent on): Hearthfire Form
## burns around it, a Soulfire Beam lights its lantern, Rekindle's haste glows.
func _spell_look() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if controller == Ctrl.REPLICA and peer_id != Net.my_id():
		# another Kindled on a guest's screen runs no clock of its own: its
		# spells fade unless the next snapshot keeps them (NetRun._spell_bits)
		var dt := get_process_delta_time()
		hearthfire_t = maxf(0.0, hearthfire_t - dt)
		channel_t = maxf(0.0, channel_t - dt)
		haste_t = maxf(0.0, haste_t - dt)
	if hearthfire_t > 0.0:
		sprite.highlight = Color(1.0, 0.55, 0.2, 0.32 + 0.12 * sin(t * 14.0))
	elif channel_t > 0.0:
		sprite.highlight = Color(1.0, 0.7, 0.35, 0.18)
	elif haste_t > 0.0:
		sprite.highlight = Color(1.0, 0.9, 0.6, 0.1 + 0.05 * sin(t * 10.0))
	elif sprite.highlight.a > 0.0:
		sprite.highlight.a = 0.0
	if hearthfire_t > 0.0 and stage:
		_fire_mote_t -= get_process_delta_time()
		if _fire_mote_t <= 0.0:
			_fire_mote_t = 0.05
			Net.mute += 1
			stage.fx.motes(pos + Vector2(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2)), 0.5, Color(1.0, 0.6, 0.22), 1, 1.6, 0.5, 0.15)
			Net.mute -= 1


func sync_visual() -> void:
	super.sync_visual()
	if sprite and alive:
		# the side frames mirror toward where the Kindled looks (its walk, or
		# its aim while fighting) - from the animation playing, so a replica
		# drawn from a snapshot mirrors exactly as its owner's does. (This used
		# the bare aim: a Kindled walking left faced a mouse on the right.)
		var side := sprite.anim.ends_with("_side")
		if side and absf(look.x) > 0.05:
			sprite.flip_h = look.x < 0.0
		elif not side:
			sprite.flip_h = false
		_spell_look()
	if not gear_layers.is_empty():
		_sync_paperdoll()


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
