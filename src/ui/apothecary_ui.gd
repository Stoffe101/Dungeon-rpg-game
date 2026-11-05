## The Ember Apothecary: steep the flask with a tincture (it stays steeped
## between expeditions), see what each one does at its rank, which reagents
## you have found and where the rest are found, and improve the Apothecary
## itself. Built once in persistent sections, like the Smithy.
class_name ApothecaryUI
extends Control

var selected := ""
var _rows := {}
var _list: VBoxContainer
var _dv: VBoxContainer
var _head_lbl: Label
var _flask_lbl: Label
var _build_box: HBoxContainer
var _active_sb: StyleBoxFlat
var _dirty := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_active_sb = StyleBoxFlat.new()
	_active_sb.bg_color = Color(0.22, 0.1, 0.12)
	_active_sb.border_color = Color(1.0, 0.55, 0.6)
	_active_sb.set_border_width_all(1)
	selected = String(Profile.tincture().get("id", ""))
	if selected == "":
		selected = "hearthbalm"
	_build()
	refresh()
	Profile.changed.connect(_on_changed)


func _exit_tree() -> void:
	if Profile.changed.is_connected(_on_changed):
		Profile.changed.disconnect(_on_changed)
	Profile.save_profile()


func _on_changed() -> void:
	_dirty = true


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(470, 0)
	center.add_child(p)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.item_icon_rect("ember_core"))
	head.add_child(UIKit.label("THE EMBER APOTHECARY", 16, Color(1.0, 0.6, 0.62), true))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	_head_lbl = UIKit.label("", 8, UIKit.C_DIM)
	head.add_child(_head_lbl)
	head.add_child(UIKit.button("Close", func() -> void: Game.ui.close_top(), 40))
	v.add_child(head)
	v.add_child(UIKit.label('"One flask, steeped well, is worth three drunk in a hurry."', 8, UIKit.C_DIM))
	var row := UIKit.hbox(6)
	v.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(176, 210)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = UIKit.vbox(1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var detail := UIKit.panel("DarkPanel")
	detail.custom_minimum_size = Vector2(270, 210)
	row.add_child(detail)
	_dv = UIKit.vbox(3)
	detail.add_child(_dv)
	_flask_lbl = UIKit.label("", 8, UIKit.C_TEXT)
	v.add_child(_flask_lbl)
	_build_box = UIKit.hbox(6)
	v.add_child(_build_box)


func refresh() -> void:
	var lvl := Profile.facility("apothecary")
	_head_lbl.text = "Level %d / %d" % [lvl, int(Profile.SANCTUARY.apothecary.max)]
	_refresh_list()
	_refresh_detail()
	var tc := Profile.tincture()
	var cur := String(tc.get("id", ""))
	var pl: Player = Game.stage.player if Game.stage else null
	var charges := int(pl.stats.v("flask_charges")) if pl else 0
	var heal := int(round(pl.stats.v("flask_heal") * 100.0)) if pl else 0
	_flask_lbl.text = "Your flask: %s   -   %d charge%s, each heals %d%% of your health before the tincture" % [
		("%s (rank %s)" % [Tinctures.get_def(cur).name, _roman(int(tc.rank))]) if cur != "" else "plain",
		charges, "" if charges == 1 else "s", heal]
	_refresh_build()


func _refresh_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var cur := String(Profile.tincture().get("id", ""))
	_list.add_child(UIKit.label("TINCTURES", 8, Color(1.0, 0.6, 0.62), true))
	for id in Tinctures.TINCTURES:
		var tid: String = id
		var d := Tinctures.get_def(tid)
		var known := Profile.tincture_known(tid)
		var b := Button.new()
		b.custom_minimum_size = Vector2(168, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.focus_mode = Control.FOCUS_ALL
		var rk := Profile.tincture_rank(tid)
		var hint := String(Tinctures.reagent(String(d.reagent)).get("where", ""))
		b.text = "  " + (String(d.name) + ("  " + _roman(rk) if rk > 0 else "") if known else "???  (%s)" % hint) + ("   <" if tid == cur else "")
		b.add_theme_color_override("font_color", (d.color as Color) if known else Color(0.42, 0.4, 0.46))
		if tid == selected:
			b.add_theme_stylebox_override("normal", _active_sb)
		b.pressed.connect(func() -> void: _select(tid))
		b.focus_entered.connect(func() -> void:
			if Settings.using_pad or UIKit.focus_ring_shown():
				_select(tid))
		_rows[tid] = b
		_list.add_child(b)
	_list.add_child(UIKit.label("REAGENTS FOUND", 8, Color(1.0, 0.6, 0.62), true))
	for rid in Tinctures.REAGENTS:
		var rg: Dictionary = Tinctures.REAGENTS[rid]
		var n := Profile.reagent_count(rid)
		var l := UIKit.label("  %s  x%d" % [rg.name, n] if n > 0 else "  ???  (%s)" % rg.where, 8, (rg.color as Color) if n > 0 else UIKit.C_DIM)
		l.tooltip_text = String(rg.desc) if n > 0 else "Found among %s." % rg.where
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		_list.add_child(l)


func _select(id: String) -> void:
	if id == selected:
		return
	if _rows.has(selected):
		(_rows[selected] as Button).remove_theme_stylebox_override("normal")
	selected = id
	if _rows.has(id):
		(_rows[id] as Button).add_theme_stylebox_override("normal", _active_sb)
	_refresh_detail()


func _refresh_detail() -> void:
	for c in _dv.get_children():
		_dv.remove_child(c)
		c.queue_free()
	var d := Tinctures.get_def(selected)
	var known := Profile.tincture_known(selected)
	var rk := Profile.tincture_rank(selected)
	var col: Color = d.color
	if not known:
		var rg := Tinctures.reagent(String(d.reagent))
		_dv.add_child(UIKit.label("AN UNKNOWN TINCTURE", 8, UIKit.C_DIM, true))
		_dv.add_child(UIKit.para("Its reagent has not been found yet. Look among %s." % rg.get("where", "the Undervault"), 250, UIKit.C_DIM))
		return
	_dv.add_child(UIKit.label(String(d.name).to_upper(), 8, col, true))
	_dv.add_child(_pips(rk, col))
	if rk <= 0:
		_dv.add_child(UIKit.para(Tinctures.describe(selected, 1), 250, UIKit.C_DIM))
		_dv.add_child(UIKit.para("The Apothecary must be rebuilt before anything can be steeped.", 250, UIKit.C_BAD))
		return
	_dv.add_child(UIKit.para(Tinctures.describe(selected, rk), 250, UIKit.C_TEXT))
	var cap := 2 if Profile.facility("apothecary") < 3 else Tinctures.MAX_RANK
	var reag := String(d.reagent)
	if rk < Tinctures.MAX_RANK:
		_dv.add_child(UIKit.label("NEXT RANK", 8, UIKit.C_GOLD, true))
		_dv.add_child(UIKit.para(Tinctures.describe(selected, rk + 1), 250, UIKit.C_DIM))
		if reag == "":
			_dv.add_child(UIKit.para("Distilled further as the Apothecary is improved.", 250, UIKit.C_DIM))
		elif rk >= cap:
			_dv.add_child(UIKit.para("Rank III needs the Apothecary fully restored.", 250, UIKit.C_DIM))
		else:
			_dv.add_child(UIKit.para("Find another %s (%s)." % [Tinctures.reagent(reag).get("name", "?"), Tinctures.reagent(reag).get("where", "")], 250, UIKit.C_DIM))
	var cur := String(Profile.tincture().get("id", ""))
	var b := UIKit.button("Steeped" if cur == selected else "Steep the flask", func() -> void:
		if Profile.steep(selected):
			Audio.play("flask", 0.0, 1.1)
			Game.ui.toast("Your flask is steeped with %s." % d.name, col)
			Profile.save_profile()
			if Game.stage is Hub:
				var h := Game.stage as Hub
				h.fx.motes(h.player.pos, 0.4, col, 16, 1.5, 0.8, 0.4), 110)
	b.disabled = cur == selected
	_dv.add_child(b)


func _refresh_build() -> void:
	for c in _build_box.get_children():
		_build_box.remove_child(c)
		c.queue_free()
	if not (Game.stage is Hub) or not (Game.stage as Hub).own_camp():
		return
	var lvl := Profile.building("apothecary")
	var levels := ["", "an alembic and a counter of bottles", "a cauldron and a shelf of reagents: stronger draughts", "an ember alembic: tinctures distil to rank III"]
	if lvl >= int(Profile.SANCTUARY.apothecary.max):
		_build_box.add_child(UIKit.label("Fully restored.", 8, UIKit.C_GOOD))
		return
	var cost := Profile.building_cost("apothecary")
	_build_box.add_child(UIKit.para("Improve: %s" % levels[mini(lvl + 1, levels.size() - 1)], 200, UIKit.C_DIM))
	_build_box.add_child(GearUI.cost_row(cost))
	var b := UIKit.button("Improve", func() -> void:
		if Profile.upgrade_building("apothecary"):
			Profile.save_profile()
			if Game.stage is Hub:
				(Game.stage as Hub).refresh_camp(), 60)
	b.disabled = not Profile.can_afford(cost)
	_build_box.add_child(b)


func _pips(rk: int, col: Color) -> Control:
	var h := UIKit.hbox(2)
	for i in Tinctures.MAX_RANK:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(10, 4)
		r.color = col if i < rk else Color(0.2, 0.18, 0.24)
		h.add_child(r)
	h.add_child(UIKit.label("  rank %s" % _roman(rk), 8, UIKit.C_DIM))
	return h


static func _roman(n: int) -> String:
	return ["-", "I", "II", "III"][clampi(n, 0, 3)]
