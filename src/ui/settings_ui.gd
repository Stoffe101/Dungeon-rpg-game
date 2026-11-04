## Settings: a rail of categories on the left, that category's rows on the
## right, and a line under them explaining whatever row is pointed at.
##
## Rows are one of three kinds, all usable with mouse, keys and pad: a slider
## (left / right), a stepper for a fixed list ("< Borderless >": click or left /
## right), and an on / off switch. Changes apply at once and are saved;
## "Restore defaults" resets the open category. LB / RB (or Q / E on keys while
## the rail has focus) change category; Esc / B closes.
class_name SettingsUI
extends Control

const W := 372
const PAGES := [
	["audio", "Audio", "bell", "How loud each part of the game is."],
	["display", "Display", "sun", "The window, and how large the world and the interface are drawn."],
	["gameplay", "Gameplay", "sword", "How fights feel in your hands."],
	["access", "Accessibility", "eye", "Calmer camera, softer flashes, fewer particles."],
	["coop", "Co-op", "lantern", "Playing with others: your name, and how much of their light you see."],
	["controls", "Controls", "key", "Every action on keyboard and mouse, and on a gamepad."],
]

var ui: UIRoot
var page := "audio"
var _rail: VBoxContainer
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _desc: Label
var _head: Label
var _rail_buttons := {}


func _ready() -> void:
	ui = Game.ui
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(W, 0)
	center.add_child(p)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var title := UIKit.label("SETTINGS", 16, UIKit.C_GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var main := UIKit.hbox(6)
	v.add_child(main)
	_rail = UIKit.vbox(2)
	_rail.custom_minimum_size = Vector2(86, 0)
	main.add_child(_rail)
	for pg in PAGES:
		var b := Button.new()
		b.text = "  " + String(pg[1])
		b.icon = UIKit.icon_small(String(pg[2]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(86, 16)
		b.focus_mode = Control.FOCUS_ALL
		b.toggle_mode = true
		var id: String = pg[0]
		b.pressed.connect(func() -> void: _open_page(id))
		b.mouse_entered.connect(func() -> void: Audio.ui("ui_hover"))
		_rail.add_child(b)
		_rail_buttons[id] = b
	var right := UIKit.panel("DarkPanel")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(W - 100, 0)
	right.clip_contents = true
	main.add_child(right)
	var rv := UIKit.vbox(3)
	right.add_child(rv)
	_head = UIKit.label("", 8, UIKit.C_GOLD, true)
	rv.add_child(_head)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W - 112, 150)
	_scroll.clip_contents = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(_scroll)
	_rows = UIKit.vbox(3)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	var line := ColorRect.new()
	line.color = Color(0.45, 0.32, 0.22, 0.8)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_desc = UIKit.para("", W - 16, UIKit.C_DIM)
	_desc.custom_minimum_size.y = 20
	v.add_child(_desc)
	var foot := UIKit.hbox(8)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_child(UIKit.button("Restore defaults", func() -> void: _defaults(), 100))
	var done := UIKit.button("Done", func() -> void: ui.close_modal(get_parent()), 70)
	foot.add_child(done)
	v.add_child(foot)
	_open_page(page)
	(_rail_buttons[page] as Button).call_deferred("grab_focus")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton and e.pressed and (e.button_index == JOY_BUTTON_LEFT_SHOULDER or e.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		_step_page(-1 if e.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		if get_viewport().gui_get_focus_owner() and get_viewport().gui_get_focus_owner().has_node("Rebind"):
			return    # a rebind in progress takes Esc itself
		get_viewport().set_input_as_handled()
		ui.close_modal(get_parent())


func _step_page(d: int) -> void:
	var ids := PAGES.map(func(pg): return pg[0])
	_open_page(ids[posmod(ids.find(page) + d, ids.size())])
	(_rail_buttons[page] as Button).grab_focus()


func _open_page(id: String) -> void:
	page = id
	for k in _rail_buttons:
		(_rail_buttons[k] as Button).set_pressed_no_signal(k == id)
	for c in _rows.get_children():
		_rows.remove_child(c)     # gone now: focus links must not find the old page's rows
		c.queue_free()
	_scroll.scroll_vertical = 0
	var blurb := ""
	for pg in PAGES:
		if pg[0] == id:
			_head.text = String(pg[1]).to_upper()
			blurb = String(pg[3])
	_desc.text = blurb
	Audio.ui("ui_click")
	match id:
		"audio":
			_slider("Master volume", "master_volume", 0.0, 1.0, 0.05, "Everything you hear.")
			_slider("Music", "music_volume", 0.0, 1.0, 0.05, "The sanctuary's songs and the Undervault's.")
			_slider("Effects", "sfx_volume", 0.0, 1.0, 0.05, "Blows, spells, footsteps and voices.")
			_slider("Ambience", "ambience_volume", 0.0, 1.0, 0.05, "Wind, fire, water and the deep.")
		"display":
			_stepper("Window", "window_mode", ["windowed", "borderless", "fullscreen"], ["Windowed", "Borderless", "Fullscreen"], "Borderless fills the screen and switches away fastest.")
			_stepper("Interface size", "ui_scale", [0, 1, 2, 3, 4, 5, 6], ["Auto", "1x", "2x", "3x", "4x", "5x", "6x"],
				"Menus and the HUD. Auto picks the largest size that fits (now %dx)." % Settings.effective_ui_scale())
			_stepper("World pixel size", "pixel_scale", [0, 2, 3, 4, 5, 6, 8], ["Auto", "2x", "3x", "4x", "5x", "6x", "8x"], "How large the world's pixels are drawn: smaller shows more of the floor.")
			_stepper("Frame cap", "max_fps", [0, 60, 120, 144, 240], ["Unlimited", "60", "120", "144", "240"], "The most frames per second drawn.")
			_switch("V-Sync", "vsync", "Waits for the monitor: no tearing, a little more input delay.")
			_slider("Brightness", "brightness", 0.8, 1.5, 0.05, "How bright the world is drawn. The Undervault is meant to be dark, never unreadable.")
			_switch("Show frame rate", "show_fps", "A frame counter in the corner.")
		"gameplay":
			_stepper("Pointer steering", "steer", ["on", "always", "off"], ["W follows the mouse", "Always", "Off"],
				"On: hold W and move the mouse, and you walk toward the pointer until you let go of W. Always: every key walks relative to the pointer. Off: keys walk the screen's way.")
			_slider("Aim assist (pad)", "aim_assist", 0.0, 1.0, 0.05, "With a pad, aim bends toward the foe nearest your stick.")
			_slider("Rumble (pad)", "rumble", 0.0, 1.0, 0.05, "Pad vibration on hits, dodges and heartbeats.")
			_switch("Hit-stop", "hitstop", "The world holds for a breath when a heavy blow lands (never in co-op).")
			_switch("Damage numbers", "damage_numbers", "Numbers rise from what you hit.")
		"access":
			_slider("Screen shake", "screen_shake", 0.0, 1.5, 0.05, "How hard the camera kicks on impacts.")
			_slider("Effect intensity", "effects_intensity", 0.25, 1.0, 0.05, "Particles and flashes from your own Kindled.")
			_switch("Reduce flashes", "reduce_flashes", "Softens bright flashes and the damage pulse at the screen's edges.")
			_stepper("Object names", "world_names", ["all", "nearest", "off"], ["All nearby", "Only the nearest", "Off"],
				"Names over chests, shrines and finds. Off: what F would use is told at the bottom of the screen instead.")
		"coop":
			_name_row()
			_slider("Allies' effects", "ally_effects", 0.2, 1.0, 0.05, "How strongly other Kindled's particles are drawn on your screen, beside your own.")
			_switch("Network overlay", "net_overlay", "Round trip, loss and how far behind the floor is drawn (also F3).")
		"controls":
			_controls()
	_link_focus.call_deferred()
	_focus_page_first.call_deferred()


## Pad / arrow keys: right from the rail goes into the page, left comes back.
func _link_focus() -> void:
	if not is_inside_tree():
		return
	var rows := UIRoot.focusables(_rows)
	if rows.is_empty():
		return
	for k in _rail_buttons:
		var rb: Button = _rail_buttons[k]
		rb.focus_neighbor_right = rb.get_path_to(rows[0])
	var back: Button = _rail_buttons[page]
	for c in rows:
		c.focus_neighbor_left = c.get_path_to(back)


func _focus_page_first() -> void:
	if not Settings.using_pad:
		return
	(_rail_buttons[page] as Button).grab_focus()


func _defaults() -> void:
	if page == "controls":
		Settings.reset_bindings()
	else:
		for row in _rows.get_children():
			var key := String(row.get_meta("key", ""))
			if key != "" and Settings.DEFAULTS.has(key):
				Settings.set_value(key, Settings.DEFAULTS[key])
	Audio.ui("ui_click")
	_open_page(page)


# --- rows -----------------------------------------------------------------------------

func _row(label: String, key: String, desc: String) -> HBoxContainer:
	var row := UIKit.hbox(6)
	row.set_meta("key", key)
	row.set_meta("desc", desc)
	var l := UIKit.label(label, 8, UIKit.C_TEXT)
	l.custom_minimum_size = Vector2(104, 0)
	row.add_child(l)
	row.mouse_entered.connect(func() -> void: _desc.text = desc)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(row)
	return row


func _hooked(c: Control, desc: String) -> void:
	c.focus_entered.connect(func() -> void: _desc.text = desc)
	c.mouse_entered.connect(func() -> void: _desc.text = desc)


func _slider(label: String, key: String, lo: float, hi: float, step: float, desc: String) -> void:
	var row := _row(label, key, desc)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key, lo))
	s.custom_minimum_size = Vector2(96, 12)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var val := UIKit.label("%d%%" % roundi(s.value * 100.0), 8, UIKit.C_GOLD)
	val.custom_minimum_size = Vector2(30, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d%%" % roundi(x * 100.0)
		Settings.set_value(key, x))
	_hooked(s, desc)
	row.add_child(s)
	row.add_child(val)


## A fixed list, stepped through: click (or right) for the next, left for the previous.
func _stepper(label: String, key: String, options: Array, names: Array, desc: String) -> void:
	var row := _row(label, key, desc)
	var idx := maxi(0, options.find(Settings.get_value(key)))
	var b := Button.new()
	b.custom_minimum_size = Vector2(128, 14)
	b.focus_mode = Control.FOCUS_ALL
	var show := func() -> void: b.text = "<  %s  >" % names[idx]
	show.call()
	var step := func(d: int) -> void:
		idx = posmod(idx + d, options.size())
		show.call()
		Settings.set_value(key, options[idx])
		Audio.ui("ui_click")
	b.pressed.connect(func() -> void: step.call(1))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event()
		elif e.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event()
		elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			step.call(-1)
			b.accept_event())
	_hooked(b, desc)
	row.add_child(b)


## On / off: a press flips it (the word and its colour say which; the
## button keeps its ordinary frame, so only focus is ever outlined).
func _switch(label: String, key: String, desc: String) -> void:
	var row := _row(label, key, desc)
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 14)
	b.focus_mode = Control.FOCUS_ALL
	var paint := func(on: bool) -> void:
		b.text = "On" if on else "Off"
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(k, UIKit.C_GOOD if on else UIKit.C_DIM)
	paint.call(bool(Settings.get_value(key, false)))
	b.pressed.connect(func() -> void:
		var on := not bool(Settings.get_value(key, false))
		Settings.set_value(key, on)
		paint.call(on)
		Audio.ui("ui_click"))
	_hooked(b, desc)
	row.add_child(b)


func _name_row() -> void:
	var desc := "What the party sees above your Kindled and on its seat."
	var row := _row("Your name", "", desc)
	var name_in := LineEdit.new()
	name_in.text = String(Settings.get_value("player_name", "Kindled"))
	name_in.max_length = 16
	name_in.custom_minimum_size = Vector2(128, 14)
	name_in.text_changed.connect(func(t: String) -> void:
		Settings.set_value("player_name", t.strip_edges() if t.strip_edges() != "" else "Kindled"))
	_hooked(name_in, desc)
	row.add_child(name_in)


func _controls() -> void:
	var head := UIKit.hbox(6)
	for h in [["Action", 88], ["Keys / mouse", 72], ["Gamepad", 72]]:
		var hl := UIKit.label(h[0], 8, UIKit.C_GOLD)
		hl.custom_minimum_size = Vector2(h[1], 0)
		if h[0] != "Action":
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(hl)
	_rows.add_child(head)
	var groups := [
		["MOVE", [["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"], ["dodge", "Dodge"]]],
		["FIGHT", [["attack", "Attack"], ["ward", "Ward"], ["ability_1", "Spell 1"], ["ability_2", "Spell 2"], ["ability_3", "Spell 3"], ["flask", "Flask"]]],
		["EXPLORE", [["interact", "Interact / talk"], ["map", "Map"], ["inventory", "Satchel"], ["hearthcall", "Hearthcall (go home)"]]],
		["PARTY", [["party_yes", "Ready / agree"], ["party_no", "Not now"]]],
	]
	for g in groups:
		var gl := UIKit.label(String(g[0]), 8, UIKit.C_DIM)
		_rows.add_child(gl)
		for a in g[1]:
			var row := UIKit.hbox(6)
			var l := UIKit.label(a[1], 8)
			l.custom_minimum_size = Vector2(88, 0)
			l.clip_text = true
			row.add_child(l)
			var kb := Screens._bind_button(a[0], false)
			kb.custom_minimum_size = Vector2(72, 14)
			row.add_child(kb)
			var pb := Screens._bind_button(a[0], true)
			pb.custom_minimum_size = Vector2(72, 14)
			pb.disabled = String(a[0]).begins_with("move_")   # movement stays on the left stick
			row.add_child(pb)
			_hooked(kb, "Click, then press the new key or mouse button (Esc cancels).")
			_hooked(pb, "Select, then press the new pad button (Start cancels).")
			_rows.add_child(row)
