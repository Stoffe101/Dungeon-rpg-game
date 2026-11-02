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
var level_lbl: Label
var prompt_lbl: Label
var relic_row: HBoxContainer
var slot_nodes: Array = []
var boss_name: Label
var controls_card: PanelContainer
var tooltip: PanelContainer
var tooltip_lbl: Label
var _relic_count := -1
var _boss: Enemy
var _hp_shown := 1.0
var _hp_lag := 1.0


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
	level_lbl = UIKit.label("", 8, UIKit.C_SOUL, true)
	add_child(level_lbl)
	prompt_lbl = UIKit.label("", 8, UIKit.C_GOLD, true)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_lbl)
	relic_row = UIKit.hbox(2)
	add_child(relic_row)
	for i in 2:
		var slot := _make_slot(i)
		add_child(slot)
		slot_nodes.append(slot)
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
	_relic_count = -1


## First-expedition reminder of the controls (rebinding-aware).
func show_controls() -> void:
	for c in controls_card.get_children():
		c.queue_free()
	var v := UIKit.vbox(1)
	controls_card.add_child(v)
	v.add_child(UIKit.label("CONTROLS", 8, UIKit.C_GOLD, true))
	var rows := [
		["Move", "WASD"],
		["Attack / hold to charge", Settings.describe_action("attack")],
		["Dodge (perfect = slow-mo)", Settings.describe_action("dodge")],
		["Ward: parry & reflect", Settings.describe_action("ward")],
		["Abilities (cost Kindle)", "%s / %s" % [Settings.describe_action("ability_1"), Settings.describe_action("ability_2")]],
		["Flask", Settings.describe_action("flask")],
		["Interact", Settings.describe_action("interact")],
		["Map", Settings.describe_action("map")],
	]
	for r in rows:
		var h := UIKit.hbox(6)
		var k := UIKit.label(r[1], 8, UIKit.C_EMBER)
		k.custom_minimum_size = Vector2(40, 0)
		h.add_child(k)
		h.add_child(UIKit.label(r[0], 8, UIKit.C_TEXT))
		v.add_child(h)
	controls_card.modulate.a = 1.0
	controls_card.visible = true


func toggle_big_map() -> void:
	if not in_dungeon:
		return
	big_map.visible = not big_map.visible


func _make_slot(i: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(26, 26)
	c.size = Vector2(26, 26)
	var frame := TextureRect.new()
	frame.texture = preload("res://assets/ui/ui_slot.png")
	frame.size = Vector2(26, 26)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	c.add_child(frame)
	var ic := UIKit.icon_rect("lock")
	ic.position = Vector2(5, 5)
	ic.name = "Icon"
	c.add_child(ic)
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.65)
	cd.position = Vector2(3, 3)
	cd.size = Vector2(20, 0)
	cd.name = "Cooldown"
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cd)
	var key := UIKit.label("Q" if i == 0 else "E", 8, UIKit.C_GOLD, true)
	key.position = Vector2(-2, 17)
	key.name = "Key"
	c.add_child(key)
	var cost := UIKit.label("", 8, UIKit.C_EMBER, true)
	cost.position = Vector2(15, 17)
	cost.name = "Cost"
	c.add_child(cost)
	return c


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var st: Stage = Game.stage
	var pl: Player = st.player if st else null
	# layout (anchors handle most; keep explicit offsets crisp)
	minimap.position = Vector2(vp.x - minimap.size.x - 8, 8)
	var cur: Control = get_node("Currency")
	cur.position = Vector2(vp.x - 70 - 8, (minimap.size.y + 12) if in_dungeon else 8)
	cur.size.x = 70
	big_map.position = (vp - big_map.size) * 0.5
	var slot_y := vp.y - 40
	for i in slot_nodes.size():
		slot_nodes[i].position = Vector2(vp.x * 0.5 - 30 + i * 34, slot_y)
	prompt_lbl.position = Vector2(vp.x * 0.5 - 100, slot_y - 18)
	prompt_lbl.size.x = 200
	relic_row.position = Vector2(8, vp.y - 26)
	if controls_card.visible:
		controls_card.reset_size()
		controls_card.position = Vector2(8, vp.y - 40 - controls_card.size.y)
	level_lbl.position = Vector2(8, vp.y - 12)
	boss_name.position = Vector2(vp.x * 0.5 - 150, 14)
	boss_name.size.x = 300
	if pl == null:
		queue_redraw()
		return
	embers_lbl.text = str(pl.run.embers if in_dungeon and pl.run else Profile.currency("embers"))
	shards_lbl.text = str((pl.run.sunshards if in_dungeon and pl.run else 0) + Profile.currency("sunshards"))
	if in_dungeon and pl.run:
		depth_lbl.text = "Depth %d  %s" % [pl.run.depth, UIKit.fmt_time(pl.run.elapsed)]
	level_lbl.text = "LV %d" % Profile.level()
	# abilities
	for i in 2:
		var id: String = pl.ability_slots[i] if i < pl.ability_slots.size() else ""
		var slot: Control = slot_nodes[i]
		var ic: TextureRect = slot.get_node("Icon")
		var cd: ColorRect = slot.get_node("Cooldown")
		var cost_l: Label = slot.get_node("Cost")
		var key_l: Label = slot.get_node("Key")
		key_l.text = Settings.describe_action("ability_1" if i == 0 else "ability_2")
		if id == "":
			ic.texture = UIKit.icon("lock")
			ic.modulate = Color(1, 1, 1, 0.25)
			cd.size.y = 0
			cost_l.text = ""
			continue
		var d := GearDB.ability(id)
		ic.texture = UIKit.icon(d.icon)
		var cost: float = d.cost * pl.stats.v("ability_cost")
		cost_l.text = str(int(cost))
		var is_ready: bool = pl.ability_cd[i] <= 0.0
		var afford := pl.kindle >= cost or pl.stats.has("bonfire_soul")
		ic.modulate = Color(1, 1, 1, 1) if is_ready and afford else Color(0.55, 0.5, 0.55, 1)
		cost_l.add_theme_color_override("font_color", UIKit.C_EMBER if afford else UIKit.C_BAD)
		var full: float = float(d.cooldown) * pl.stats.v("cooldown")
		cd.size.y = 20.0 * clampf(pl.ability_cd[i] / maxf(full, 0.01), 0.0, 1.0)
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
	# --- flasks ---
	var fy := ky + 9
	var tex := UIKit.icon("flask")
	for i in int(pl.stats.v("flask_charges")):
		var col := Color(1, 1, 1, 1) if i < pl.flask else Color(0.3, 0.3, 0.35, 0.8)
		draw_texture_rect(tex, Rect2(x0 + i * 13, fy, 12, 12), false, col)
	draw_string(UIKit.FONT_OUTLINE, Vector2(x0 + int(pl.stats.v("flask_charges")) * 13 + 2, fy + 9), Settings.describe_action("flask"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_DIM)
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
