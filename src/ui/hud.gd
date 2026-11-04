## In-game heads-up display. Bars and pips are drawn directly for crisp pixels;
## icons and labels are child controls. Layout uses anchors so it holds up at
## 16:9 and 21:9 and any integer UI scale.
class_name HUD
extends Control

var in_dungeon := false
var minimap: Minimap
var big_map: Minimap
var embers_lbl: Label
var shards_lbl: Label
var depth_lbl: Label
var omen_lbl: Label
var level_lbl: Label
var prompt_lbl: Label
var relic_row: HBoxContainer
var slot_nodes: Array = []
var flask_slot: Control
var _flask_seen := -1
var combo_box: VBoxContainer
var combo_lbl: Label
var combo := 0
var _combo_t := 0.0
var boss_name: Label
var controls_card: PanelContainer
var tooltip: PanelContainer
var tooltip_lbl: Label
var _relic_count := -1
var _boss: Enemy
var _hp_shown := 1.0
var _hp_lag := 1.0
var party: PartyFrames     # co-op: every other Kindled (made once Net exists)
var _bar := Rect2()        # the hotbar plate (drawn under the slots)
var _cd_was: Array = [0.0, 0.0, 0.0]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.custom_minimum_size = Vector2(112, 72)
	minimap.size = Vector2(112, 72)
	add_child(minimap)
	big_map = Minimap.new()
	big_map.big = true
	big_map.visible = false
	big_map.set_anchors_preset(Control.PRESET_CENTER)
	big_map.size = Vector2(300, 200)
	add_child(big_map)
	var cur := UIKit.vbox(1)
	cur.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cur.name = "Currency"
	add_child(cur)
	var r1 := UIKit.hbox(2)
	r1.alignment = BoxContainer.ALIGNMENT_END
	r1.add_child(UIKit.icon_rect("ember"))
	embers_lbl = UIKit.label("0", 8, UIKit.C_EMBER, true)
	r1.add_child(embers_lbl)
	cur.add_child(r1)
	var r2 := UIKit.hbox(2)
	r2.alignment = BoxContainer.ALIGNMENT_END
	r2.add_child(UIKit.icon_rect("sunshard"))
	shards_lbl = UIKit.label("0", 8, UIKit.C_GOLD, true)
	r2.add_child(shards_lbl)
	cur.add_child(r2)
	depth_lbl = UIKit.label("", 8, UIKit.C_DIM, true)
	depth_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cur.add_child(depth_lbl)
	omen_lbl = UIKit.label("", 8, Omens.COLOR, true)
	omen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cur.add_child(omen_lbl)
	level_lbl = UIKit.label("", 8, UIKit.C_SOUL, true)
	add_child(level_lbl)
	prompt_lbl = UIKit.label("", 8, UIKit.C_GOLD, true)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_lbl)
	relic_row = UIKit.hbox(2)
	add_child(relic_row)
	for i in 3:
		var slot := _make_slot(i)
		add_child(slot)
		slot_nodes.append(slot)
	flask_slot = _make_slot(3)
	(flask_slot.get_node("Icon") as TextureRect).texture = UIKit.icon("flask")
	add_child(flask_slot)
	boss_name = UIKit.label("", 8, UIKit.C_TEXT, true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.visible = false
	add_child(boss_name)
	tooltip = UIKit.panel()
	tooltip.theme_type_variation = ""
	tooltip.add_theme_stylebox_override("panel", UIKit.theme().get_stylebox("panel", "TooltipPanel"))
	tooltip_lbl = UIKit.para("", 140)
	tooltip.add_child(tooltip_lbl)
	tooltip.visible = false
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tooltip)
	controls_card = UIKit.panel()
	controls_card.visible = false
	controls_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls_card)
	Events.room_cleared.connect(func(_id: int) -> void:
		if controls_card.visible:
			var tw := controls_card.create_tween()
			tw.tween_interval(2.0)
			tw.tween_property(controls_card, "modulate:a", 0.0, 0.8)
			tw.tween_callback(func() -> void: controls_card.visible = false))
	# hit chain counter: consecutive hits without a 2.2 s gap
	combo_box = UIKit.vbox(0)
	combo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	combo_lbl = UIKit.label("", 16, UIKit.C_TEXT, true)
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_box.add_child(combo_lbl)
	var hits_lbl := UIKit.label("HITS", 8, UIKit.C_DIM, true)
	hits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_box.add_child(hits_lbl)
	combo_box.modulate.a = 0.0
	add_child(combo_box)
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.boss_started.connect(func(b: Node) -> void:
		_boss = b as Enemy
		boss_name.text = _boss.display_name.to_upper()
		boss_name.visible = true)
	Events.boss_defeated.connect(func(_b: Node) -> void:
		_boss = null
		boss_name.visible = false)


func set_dungeon(on: bool) -> void:
	in_dungeon = on
	minimap.visible = on
	depth_lbl.visible = on
	omen_lbl.visible = on
	_relic_count = -1


## First-expedition reminder of the controls (rebinding- and device-aware).
func show_controls() -> void:
	refresh_controls()
	controls_card.modulate.a = 1.0
	controls_card.visible = true


func refresh_controls() -> void:
	for c in controls_card.get_children():
		c.queue_free()
	var v := UIKit.vbox(1)
	controls_card.add_child(v)
	v.add_child(UIKit.label("CONTROLS", 8, UIKit.C_GOLD, true))
	var pad := Settings.using_pad
	var rows := [
		["Move", "L-Stick" if pad else "%s%s%s%s" % [Settings.describe_action("move_up"), Settings.describe_action("move_left"), Settings.describe_action("move_down"), Settings.describe_action("move_right")]],
		["Aim", "R-Stick" if pad else "Mouse"],
		["Attack / hold to charge", Settings.describe_action("attack")],
		["Dodge (perfect = slow-mo)", Settings.describe_action("dodge")],
		["Ward: parry & reflect", Settings.describe_action("ward")],
		["Spells (cost Kindle)", "%s / %s / %s" % [Settings.describe_action("ability_1"), Settings.describe_action("ability_2"), Settings.describe_action("ability_3")]],
		["Flask", Settings.describe_action("flask")],
		["Interact", Settings.describe_action("interact")],
		["Satchel (gear)", Settings.describe_action("inventory")],
		["Hearthcall (home)", Settings.describe_action("hearthcall")],
		["Map", Settings.describe_action("map")],
	]
	for r in rows:
		var h := UIKit.hbox(6)
		var k := UIKit.label(r[1], 8, UIKit.C_EMBER)
		k.custom_minimum_size = Vector2(40, 0)
		h.add_child(k)
		h.add_child(UIKit.label(r[0], 8, UIKit.C_TEXT))
		v.add_child(h)


func toggle_big_map() -> void:
	if not in_dungeon:
		return
	big_map.visible = not big_map.visible


## One hotbar slot: frame, icon, the cooldown shade with its seconds, a flash
## when the spell comes back, the key (top left, on the rim) and the Kindle
## cost (inside, bottom right; the flask shows its charges there).
func _make_slot(i: int) -> Control:
	var c := Control.new()
	c.name = "Slot%d" % i
	c.custom_minimum_size = Vector2(26, 26)
	c.size = Vector2(26, 26)
	var frame := TextureRect.new()
	frame.texture = preload("res://assets/ui/ui_slot.png")
	frame.size = Vector2(26, 26)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(frame)
	var ic := UIKit.icon_rect("lock")
	ic.position = Vector2(5, 5)
	ic.name = "Icon"
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ic)
	var cd := ColorRect.new()
	cd.color = Color(0.02, 0.01, 0.05, 0.72)
	cd.position = Vector2(3, 3)
	cd.size = Vector2(20, 0)
	cd.name = "Cooldown"
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cd)
	var fl := ColorRect.new()
	fl.color = Color(1.0, 0.88, 0.55, 0.0)
	fl.position = Vector2(3, 3)
	fl.size = Vector2(20, 20)
	fl.name = "Flash"
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(fl)
	var secs := UIKit.label("", 8, UIKit.C_TEXT, true)
	secs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secs.position = Vector2(0, 7)
	secs.size = Vector2(26, 10)
	secs.name = "Secs"
	c.add_child(secs)
	var key := UIKit.label("", 8, UIKit.C_GOLD, true)
	key.position = Vector2(0, -5)
	key.name = "Key"
	c.add_child(key)
	var cost := UIKit.label("", 8, UIKit.C_EMBER, true)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.position = Vector2(4, 15)
	cost.size = Vector2(21, 10)
	cost.name = "Cost"
	c.add_child(cost)
	return c


## Keys as short as the slot corner allows ("Space" -> "Spc").
static func short_key(s: String) -> String:
	var m := {"Space": "Spc", "Shift": "Sft", "Ctrl": "Ctl", "Alt": "Alt", "Tab": "Tab", "D-Left": "D<", "D-Right": "D>",
		"D-Up": "D^", "D-Down": "Dv", "Menu": "Mnu", "View": "Vw", "Escape": "Esc", "Enter": "Ent"}
	if m.has(s):
		return m[s]
	return s if s.length() <= 3 else s.substr(0, 3)


func _update_spell_slot(pl: Player, i: int) -> void:
	var id: String = pl.ability_slots[i] if i < pl.ability_slots.size() else ""
	var slot: Control = slot_nodes[i]
	var ic: TextureRect = slot.get_node("Icon")
	var cd: ColorRect = slot.get_node("Cooldown")
	var cost_l: Label = slot.get_node("Cost")
	var key_l: Label = slot.get_node("Key")
	var secs: Label = slot.get_node("Secs")
	key_l.text = short_key(Settings.describe_action("ability_%d" % (i + 1)))
	if not pl.slot_open(i):
		ic.texture = UIKit.icon("lock")
		ic.modulate = Color(1, 1, 1, 0.4)
		cd.size.y = 0
		secs.text = ""
		key_l.text = ""
		cost_l.text = "Lv%d" % Player.THIRD_SLOT_LEVEL
		cost_l.add_theme_color_override("font_color", UIKit.C_DIM)
		slot.tooltip_text = "A third spell slot opens at level %d." % Player.THIRD_SLOT_LEVEL
		return
	if id == "":
		ic.texture = UIKit.icon("lock")
		ic.modulate = Color(1, 1, 1, 0.12)
		cd.size.y = 0
		secs.text = ""
		cost_l.text = ""
		slot.tooltip_text = "No spell in this slot. Pick one in the Descent loadout; the Hearthtree teaches more."
		return
	var d := GearDB.ability(id)
	ic.texture = UIKit.icon(d.icon)
	var cost: float = d.cost * pl.stats.v("ability_cost")
	cost_l.text = str(int(round(cost)))
	var left: float = pl.ability_cd[i] if i < pl.ability_cd.size() else 0.0
	var is_ready := left <= 0.0
	var afford := pl.kindle >= cost or pl.stats.has("bonfire_soul")
	ic.modulate = Color(1, 1, 1, 1) if is_ready and afford else Color(0.5, 0.46, 0.52, 1)
	cost_l.add_theme_color_override("font_color", UIKit.C_EMBER if afford else UIKit.C_BAD)
	var full: float = float(d.cooldown) * pl.stats.v("cooldown")
	cd.size.y = roundf(20.0 * clampf(left / maxf(full, 0.01), 0.0, 1.0))
	# seconds only for real waits (a knife flurry's half-second would flicker)
	if left > 0.0 and full >= 1.5:
		secs.text = "%d" % ceili(left) if left >= 1.0 else "%.1f" % left
	else:
		secs.text = ""
	if float(_cd_was[i]) > 0.0 and is_ready and full >= 1.5:
		_ready_flash(slot)
	_cd_was[i] = left
	slot.tooltip_text = "%s  -  %d Kindle, %s s cooldown\n%s" % [d.name, int(round(cost)), str(snappedf(full, 0.1)), d.desc]


## A spell back off cooldown: a short warm flash and a pop.
func _ready_flash(slot: Control) -> void:
	var fl: ColorRect = slot.get_node("Flash")
	fl.color.a = 0.7
	slot.create_tween().tween_property(fl, "color:a", 0.0, 0.3)
	slot.pivot_offset = Vector2(13, 13)
	var tw := slot.create_tween()
	tw.tween_property(slot, "scale", Vector2(1.15, 1.15), 0.05)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.12)


func _on_damage_dealt(_t: Node, _amount: float, crit: bool) -> void:
	combo += 1
	_combo_t = 2.2
	if combo < 3:
		return
	combo_lbl.text = str(combo)
	var col := UIKit.C_TEXT
	if combo >= 50:
		col = Color(1.0, 0.45, 0.3)
	elif combo >= 25:
		col = UIKit.C_EMBER
	elif combo >= 10:
		col = UIKit.C_GOLD
	combo_lbl.add_theme_color_override("font_color", col)
	combo_box.modulate.a = 1.0
	combo_box.pivot_offset = combo_box.size * Vector2(1.0, 0.5)
	var tw := combo_box.create_tween()
	var pop := 1.35 if crit or combo % 10 == 0 else 1.18
	tw.tween_property(combo_box, "scale", Vector2(pop, pop), 0.04)
	tw.tween_property(combo_box, "scale", Vector2.ONE, 0.12)


## The flask slot: charges left, the drink in progress, empty, or a pulse
## when health is low and a flask is ready.
func _update_flask_slot(pl: Player) -> void:
	var ic: TextureRect = flask_slot.get_node("Icon")
	var cd: ColorRect = flask_slot.get_node("Cooldown")
	var cnt: Label = flask_slot.get_node("Cost")
	var key_l: Label = flask_slot.get_node("Key")
	key_l.text = short_key(Settings.describe_action("flask"))
	var mx := int(pl.stats.v("flask_charges"))
	cnt.text = "%d" % pl.flask
	cnt.add_theme_color_override("font_color", UIKit.C_TEXT if pl.flask > 0 else UIKit.C_BAD)
	cd.size.y = 20.0 * clampf(pl.flask_t / 0.45, 0.0, 1.0)
	var low := pl.hp_ratio() < 0.35 and pl.flask > 0 and pl.alive
	if pl.flask <= 0:
		ic.modulate = Color(0.4, 0.38, 0.42, 0.8)
	elif low:
		var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0)
		ic.modulate = Color(1.0, 0.75 + 0.25 * p, 0.75 + 0.25 * p).lerp(Color(1.6, 1.3, 1.1), p * 0.5)
	else:
		ic.modulate = Color(1, 1, 1, 1)
	flask_slot.tooltip_text = "Flask: %d/%d charges, heals %d%% of your health" % [pl.flask, mx, int(pl.stats.v("flask_heal") * 100.0)]
	if _flask_seen != -1 and pl.flask < _flask_seen:
		# a quick pop when a charge is drunk
		flask_slot.pivot_offset = Vector2(13, 13)
		var tw := flask_slot.create_tween()
		tw.tween_property(flask_slot, "scale", Vector2(1.25, 1.25), 0.06)
		tw.tween_property(flask_slot, "scale", Vector2.ONE, 0.14)
	_flask_seen = pl.flask


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var st: Stage = Game.stage
	var pl: Player = st.player if st else null
	# layout (anchors handle most; keep explicit offsets crisp)
	minimap.position = Vector2(vp.x - minimap.size.x - 8, 8)
	var cur: Control = get_node("Currency")
	# as wide as its longest line (the run clock, the Omens), right-aligned
	var cw := maxf(70.0, cur.get_combined_minimum_size().x)
	cur.size.x = cw
	cur.position = Vector2(vp.x - cw - 8, (minimap.size.y + 12) if in_dungeon else 8)
	big_map.position = (vp - big_map.size) * 0.5
	# hotbar: three spells, a hearth notch, the flask, on one plate
	var slot_y := vp.y - 38
	var bx := roundf(vp.x * 0.5 - 62)
	for i in slot_nodes.size():
		slot_nodes[i].position = Vector2(bx + i * 30, slot_y)
	flask_slot.position = Vector2(bx + 98, slot_y)
	_bar = Rect2(bx - 5, slot_y - 6, 134, 36)
	prompt_lbl.position = Vector2(vp.x * 0.5 - 100, slot_y - 22)
	prompt_lbl.size.x = 200
	relic_row.position = Vector2(8, vp.y - 26)
	if controls_card.visible:
		controls_card.reset_size()
		controls_card.position = Vector2(8, vp.y - 40 - controls_card.size.y)
	level_lbl.position = Vector2(8, vp.y - 12)
	boss_name.position = Vector2(vp.x * 0.5 - 150, 14)
	boss_name.size.x = 300
	if party == null and Net.i:
		party = PartyFrames.new()
		party.name = "Party"
		add_child(party)
	if party:
		party.position = Vector2(8, 32)
	if pl == null:
		queue_redraw()
		return
	embers_lbl.text = str(pl.run.embers if in_dungeon and pl.run else Profile.currency("embers"))
	shards_lbl.text = str((pl.run.sunshards if in_dungeon and pl.run else 0) + Profile.currency("sunshards"))
	if in_dungeon and pl.run:
		depth_lbl.text = "Tier %s  %s  %s" % [Difficulty.roman(pl.run.tier), Delve.depth_short(pl.run.region, pl.run.depth, pl.run.delve), UIKit.fmt_time(pl.run.elapsed)]
		var guardian := Delve.is_boss_depth(pl.run.depth) if pl.run.delve else pl.run.depth >= int(EnemyDB.REGIONS.get(pl.run.region, {}).get("depths", 3))
		depth_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5) if guardian else UIKit.C_DIM)
		omen_lbl.text = Omens.names(pl.run.omens)
	level_lbl.text = "LV %d" % Profile.level() if Profile.level() < Profile.MAX_LEVEL else "LV %d  Renown %d" % [Profile.level(), Profile.renown()]
	# spells
	for i in slot_nodes.size():
		_update_spell_slot(pl, i)
	_update_flask_slot(pl)
	# combo counter fades out once the chain breaks
	combo_box.position = Vector2(vp.x - 70, vp.y * 0.5 - 20)
	combo_box.size.x = 62
	if _combo_t > 0.0:
		_combo_t -= get_process_delta_time()
		if _combo_t <= 0.0:
			combo = 0
			combo_box.create_tween().tween_property(combo_box, "modulate:a", 0.0, 0.3)
	# interaction prompt
	var near := st.nearest_interactable(pl.pos) if pl.alive else null
	if near and not Game.ui.has_modal():
		prompt_lbl.text = "[%s] %s" % [Settings.describe_action("interact"), near.prompt()]
	else:
		prompt_lbl.text = ""
	# relics
	if pl.run and _relic_count != pl.run.relics.size():
		_relic_count = pl.run.relics.size()
		for c in relic_row.get_children():
			c.queue_free()
		for rid in pl.run.relics:
			var r := RelicDB.relic(rid)
			var ir := UIKit.icon_rect(r.get("icon", "relic"))
			var txt := "%s\n%s" % [r.name, r.desc]
			ir.mouse_entered.connect(func() -> void: _show_tip(txt, ir))
			ir.mouse_exited.connect(func() -> void: tooltip.visible = false)
			ir.mouse_filter = Control.MOUSE_FILTER_STOP
			relic_row.add_child(ir)
	# low health pulse
	var vm: ShaderMaterial = Game.ui.vignette.material
	vm.set_shader_parameter("low", 0.5 if pl.alive and pl.hp_ratio() < 0.3 else 0.0)
	queue_redraw()


func _show_tip(text: String, at: Control) -> void:
	tooltip_lbl.text = text
	tooltip.visible = true
	tooltip.reset_size()
	tooltip.position = at.global_position + Vector2(0, -tooltip.size.y - 4)


func _draw() -> void:
	var st: Stage = Game.stage
	if st == null or st.player == null:
		return
	var pl := st.player
	# --- the hotbar plate (the slots draw over it) ---
	if _bar.size.x > 0.0:
		draw_rect(_bar.grow(1), Color(0.03, 0.02, 0.05, 0.92))
		draw_rect(_bar, Color(0.1, 0.075, 0.1, 0.88))
		draw_rect(Rect2(_bar.position, Vector2(_bar.size.x, 1)), Color(0.45, 0.34, 0.25))
		draw_rect(Rect2(_bar.position.x, _bar.end.y - 1, _bar.size.x, 1), Color(0.2, 0.15, 0.13))
		# the hearth notch between the spells and the flask
		var nx := _bar.position.x + 5 + 3 * 30 + 1
		var ny := _bar.position.y + 17
		draw_rect(Rect2(nx, _bar.position.y + 4, 1, 26), Color(0.26, 0.19, 0.16))
		var glow := 0.6 + 0.4 * (pl.kindle / maxf(1.0, pl.kindle_max()))
		draw_colored_polygon(PackedVector2Array([Vector2(nx + 0.5, ny - 3), Vector2(nx + 3.5, ny), Vector2(nx + 0.5, ny + 3), Vector2(nx - 2.5, ny)]), Color(0.03, 0.02, 0.05))
		draw_colored_polygon(PackedVector2Array([Vector2(nx + 0.5, ny - 2), Vector2(nx + 2.5, ny), Vector2(nx + 0.5, ny + 2), Vector2(nx - 1.5, ny)]), Color(1.0, 0.6, 0.25) * glow)
	var x0 := 8.0
	var y0 := 8.0
	# --- health ---
	var w := 120.0
	var r := pl.hp_ratio()
	_hp_shown = r
	_hp_lag = maxf(_hp_shown, move_toward(_hp_lag, _hp_shown, get_process_delta_time() * 0.6))
	_frame(Rect2(x0, y0, w + 2, 10))
	draw_rect(Rect2(x0 + 1, y0 + 1, w, 8), Color(0.18, 0.05, 0.08))
	draw_rect(Rect2(x0 + 1, y0 + 1, roundf(w * _hp_lag), 8), Color(0.95, 0.85, 0.6))
	draw_rect(Rect2(x0 + 1, y0 + 1, roundf(w * r), 8), Color(0.8, 0.2, 0.25))
	draw_rect(Rect2(x0 + 1, y0 + 1, roundf(w * r), 2), Color(0.95, 0.45, 0.42))
	if pl.barrier > 0.0 or pl.aegis_hp > 0.0:
		var sh := (pl.barrier + pl.aegis_hp) / pl.max_hp
		draw_rect(Rect2(x0 + 1, y0 + 7, roundf(w * minf(sh, 1.0)), 2), Color(1.0, 0.85, 0.45))
	for k in range(1, int(pl.max_hp / 25.0) + 1):
		var sx := x0 + 1 + roundf(w * (k * 25.0 / pl.max_hp))
		if sx < x0 + w:
			draw_rect(Rect2(sx, y0 + 1, 1, 8), Color(0, 0, 0, 0.45))
	draw_string(UIKit.FONT_OUTLINE, Vector2(x0 + 4, y0 + 8), "%d/%d" % [int(ceil(pl.hp)), int(pl.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_TEXT)
	# --- kindle ---
	var ky := y0 + 12
	var kr := pl.kindle / maxf(1.0, pl.kindle_max())
	_frame(Rect2(x0, ky, w * 0.8 + 2, 6))
	draw_rect(Rect2(x0 + 1, ky + 1, w * 0.8, 4), Color(0.16, 0.08, 0.04))
	var kc := Color(1.0, 0.6, 0.25) if kr < 0.999 else Color(1.0, 0.85, 0.45)
	draw_rect(Rect2(x0 + 1, ky + 1, roundf(w * 0.8 * kr), 4), kc)
	draw_rect(Rect2(x0 + 1, ky + 1, roundf(w * 0.8 * kr), 1), Color(1.0, 0.9, 0.6))
	# --- dodge pips ---
	var maxc := int(pl.stats.v("dodge_charges"))
	for i in maxc:
		var px := x0 + w * 0.8 + 6 + i * 7
		var filled := pl.dodge_charges >= i + 1
		var partial := clampf(pl.dodge_charges - i, 0.0, 1.0)
		_diamond(Vector2(px + 2, ky + 3), filled, partial)
	_draw_guardian_pull(pl, get_viewport_rect().size)
	# (flasks have their own slot beside the abilities)
	# (the party has its own cards: PartyFrames)
	# --- xp bar along the bottom ---
	var vp := get_viewport_rect().size
	var need := Combat.xp_to_next(Profile.level())
	var xr := float(Profile.data.get("xp", 0)) / float(need)
	draw_rect(Rect2(0, vp.y - 2, vp.x, 2), Color(0.04, 0.05, 0.08))
	draw_rect(Rect2(0, vp.y - 2, roundf(vp.x * xr), 2), Color(0.35, 0.9, 0.8))
	# --- boss bar ---
	if _boss and is_instance_valid(_boss) and _boss.alive:
		var bw := 240.0
		var bx := roundf(vp.x * 0.5 - bw * 0.5)
		_frame(Rect2(bx - 1, 24, bw + 2, 8))
		draw_rect(Rect2(bx, 25, bw, 6), Color(0.12, 0.05, 0.1))
		draw_rect(Rect2(bx, 25, roundf(bw * _boss.hp_ratio()), 6), Color(0.55, 0.3, 0.75))
		draw_rect(Rect2(bx, 25, roundf(bw * _boss.hp_ratio()), 1), Color(0.8, 0.6, 0.95))
		draw_rect(Rect2(bx + roundf(bw * 0.55), 25, 1, 6), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(bx + roundf(bw * 0.2), 25, 1, 6), Color(1, 1, 1, 0.5))
		var pr := 1.0 - _boss.poise / maxf(_boss.max_poise, 1.0)
		draw_rect(Rect2(bx, 32, roundf(bw * pr), 1), Color(1.0, 0.85, 0.45))


## On a guardian's floor, until its room is found: an ember at the edge of
## the screen leans toward the way in (dim at first, brighter once most of
## the floor is explored). Every machine draws its own from the same layout.
func _draw_guardian_pull(pl: Player, vp: Vector2) -> void:
	var d := Game.stage as Dungeon
	if d == null or d.layout == null or not d.layout.boss_depth or Game.view == null or not pl.alive:
		return
	var br := d.layout.room(d.layout.exit_id)
	if br == null or br.visited:
		return
	var target := br.center()
	for dd in br.doors:
		if not dd.secret:
			var c := Vector2.ZERO
			for t: Vector2i in dd.tiles:
				c += Vector2(t) + Vector2(0.5, 0.5)
			target = c / (dd.tiles as Array).size()
			break
	var v: PixelView = Game.view
	var sp := v.internal_to_screen(v.world_to_internal(Iso.to_world(target, 0.0)))
	var me := v.internal_to_screen(v.world_to_internal(Iso.to_world(pl.pos, 0.8)))
	var inner := Rect2(Vector2(26, 46), vp - Vector2(52, 96))
	if inner.has_point(sp):
		return     # the way in is on screen already
	var dir := (sp - me).normalized()
	if dir == Vector2.ZERO:
		return
	# where the line from the Kindled toward it leaves the inner frame
	var tmax := 1e9
	for k in 2:
		if absf(dir[k]) > 0.0001:
			var edge: float = inner.end[k] if dir[k] > 0.0 else inner.position[k]
			tmax = minf(tmax, (edge - me[k]) / dir[k])
	var at := (me + dir * maxf(0.0, tmax)).round()
	var seen := 0
	for r in d.layout.rooms:
		if r.visited:
			seen += 1
	var strong := float(seen) / maxf(1.0, d.layout.rooms.size()) > 0.6
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 260.0)
	var col := Color(1.0, 0.45, 0.35, (0.55 if strong else 0.3) + 0.25 * pulse)
	var side := dir.orthogonal()
	var tip := at + dir * 6.0
	draw_colored_polygon(PackedVector2Array([tip + dir, at - dir * 4.0 + side * 5.0, at - dir * 1.0, at - dir * 4.0 - side * 5.0]), Color(0.03, 0.02, 0.05, col.a))
	draw_colored_polygon(PackedVector2Array([tip, at - dir * 3.0 + side * 4.0, at - dir * 0.5, at - dir * 3.0 - side * 4.0]), col)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.85, 0.6, col.a))


func _frame(r: Rect2) -> void:
	draw_rect(r.grow(1), Color(0.03, 0.02, 0.05))
	draw_rect(r, Color(0.36, 0.27, 0.21))


func _diamond(c: Vector2, filled: bool, partial: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)])
	draw_colored_polygon(pts, Color(0.03, 0.02, 0.05))
	var inner := PackedVector2Array([c + Vector2(0, -2), c + Vector2(2, 0), c + Vector2(0, 2), c + Vector2(-2, 0)])
	if filled:
		draw_colored_polygon(inner, Color(0.75, 0.6, 1.0))
	elif partial > 0.0:
		draw_colored_polygon(inner, Color(0.3, 0.25, 0.4))
	else:
		draw_colored_polygon(inner, Color(0.12, 0.1, 0.16))
