## Owns every on-screen interface layer: HUD, banners, toasts, prompts,
## full-screen fades and the modal screens (menus, choices, skill tree...).
class_name UIRoot
extends CanvasLayer

var root: Control
var hud: HUD
var modal_layer: Control
var banner_box: VBoxContainer
var banner_bg: TextureRect      # a dark band behind it: nothing in the world fights its words
var banner_title: Label
var banner_sub: Label
var toast_box: VBoxContainer
var fader: ColorRect
var vignette: ColorRect
var modals: Array[Control] = []
var _banner_tw: Tween
var _menu_open := false
var closed_frame := -10    # process frame of the last modal close (input debounce)
var _closed_ms := -100000  # when the last modal closed (ms)
var _hurt_k := 0.0         # damage flash on the vignette
var _beat_t := 0.0
var _focus_index := -1     # position of the focused control among the top modal's focusables
var _last_focus: Control
var card_pending := false   # a title card is covering a scene change
var _card: RequestCard     # the party's open question (co-op)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://assets/shaders/vignette.gdshader")
	vignette.material = vm
	root.add_child(vignette)
	hud = HUD.new()
	hud.visible = false
	root.add_child(hud)
	# banner
	banner_bg = TextureRect.new()
	var band := Gradient.new()
	band.set_color(0, Color(0.02, 0.02, 0.04, 0.0))
	band.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
	band.add_point(0.2, Color(0.02, 0.02, 0.04, 0.78))
	band.add_point(0.8, Color(0.02, 0.02, 0.04, 0.78))
	var band_tex := GradientTexture2D.new()
	band_tex.gradient = band
	band_tex.width = 256
	band_tex.height = 1
	banner_bg.texture = band_tex
	banner_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_bg.stretch_mode = TextureRect.STRETCH_SCALE
	banner_bg.anchor_right = 1.0
	banner_bg.offset_top = 50.0
	banner_bg.offset_bottom = 90.0
	banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_bg.modulate.a = 0.0
	root.add_child(banner_bg)
	banner_box = UIKit.vbox(2)
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.position.y = 54
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_title = UIKit.label("", 16, UIKit.C_GOLD, true)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = UIKit.label("", 8, UIKit.C_TEXT, true)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_title)
	banner_box.add_child(banner_sub)
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)
	# (grows upward from above the middle: the controls card sits below it)
	toast_box = UIKit.vbox(2)
	toast_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_box.offset_left = 10.0
	toast_box.offset_top = -36.0
	toast_box.offset_bottom = -36.0
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	root.add_child(NetDiag.new())
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	fader = ColorRect.new()
	fader.color = Color(0.01, 0.01, 0.02, 0.0)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fader)
	Events.banner.connect(banner)
	Events.toast.connect(toast)
	Events.player_damaged.connect(_on_hurt)
	Events.level_up.connect(func(lvl: int) -> void:
		banner("Level %d" % lvl, "TALENT POINT AVAILABLE  -  %s: Hearthtree" % Settings.describe_action("hearthtree"))
		Audio.play("skill_unlock", 0.0, 0.8)
		if Game.stage and Game.stage.player:
			var pl := Game.stage.player
			pl.stage.fx.ring(pl.pos, 2.0, Color(0.45, 1.0, 0.9), 0.5, 0.2)
			pl.stage.fx.motes(pl.pos, 0.3, Color(0.45, 1.0, 0.9), 24, 2.0, 1.0, 0.6))
	Events.relic_gained.connect(func(id: String) -> void:
		var r := RelicDB.relic(id)
		toast("%s - %s" % [r.name, r.desc], RelicDB.RARITY_COLOR["cursed" if r.get("cursed", false) else r.rarity]))
	_make_cursor()
	get_window().size_changed.connect(_make_cursor)
	Settings.device_changed.connect(_on_device_changed)


func _process(delta: float) -> void:
	if _card == null and Net.i:
		_card = RequestCard.ensure(self)
	_layout_banner()
	_keep_focus()
	_low_health(delta)


# --- gamepad / keyboard navigation -------------------------------------------------

func _on_device_changed(pad: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if pad else Input.MOUSE_MODE_VISIBLE
	UIKit.show_focus_ring(pad)
	if hud.controls_card.visible:
		hud.refresh_controls()


## Menus stay navigable with a pad: if focus is lost (screen opened or rebuilt),
## it returns to the same slot, or the first control.
func _keep_focus() -> void:
	if modals.is_empty():
		return
	var top: Control = modals[modals.size() - 1]
	if top.get_meta("own_nav", false):
		return
	var f := get_viewport().gui_get_focus_owner()
	if f and top.is_ancestor_of(f) and f.is_visible_in_tree():
		if f != _last_focus:
			_last_focus = f
			_focus_index = focusables(top).find(f)
		return
	if Settings.using_pad:
		_focus_first(top)


func _focus_first(top: Control) -> void:
	var list := focusables(top)
	if list.is_empty():
		return
	var c: Control = list[clampi(_focus_index, 0, list.size() - 1)]
	c.grab_focus()
	_last_focus = c


## Visible, enabled controls that accept keyboard/pad focus, in tree order.
static func focusables(n: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is TabContainer:
			var cur := (c as TabContainer).get_current_tab_control()
			if cur:
				out.append_array(focusables(cur))
			continue
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
			out.append(c)
		out.append_array(focusables(c))
	return out


func _first_tabs(n: Node) -> TabContainer:
	for c in n.get_children():
		if c is TabContainer and (c as TabContainer).is_visible_in_tree():
			return c
		var t := _first_tabs(c)
		if t:
			return t
	return null


func _switch_tab(top: Control, dir: int) -> bool:
	var tabs := _first_tabs(top)
	if tabs == null or tabs.get_tab_count() < 2:
		return false
	tabs.current_tab = posmod(tabs.current_tab + dir, tabs.get_tab_count())
	Audio.ui("ui_click")
	_focus_index = 0
	var list := focusables(tabs.get_current_tab_control())
	if not list.is_empty():
		list[0].grab_focus()
		_last_focus = list[0]
	return true


func _layout_banner() -> void:
	var vp := root.get_viewport_rect().size
	banner_box.size.x = vp.x
	banner_box.position.x = 0
	toast_box.position.y = vp.y * 0.45


## A pixel crosshair, scaled with the UI so it stays crisp and visible.
func _make_cursor() -> void:
	var s := Settings.effective_ui_scale()
	var base := Image.create_empty(11, 11, false, Image.FORMAT_RGBA8)
	var ink := Color(0.04, 0.03, 0.06)
	var hot := Color(1.0, 0.8, 0.45)
	for i in 11:
		for j in 11:
			var on := (i == 5 and (j < 4 or j > 6)) or (j == 5 and (i < 4 or i > 6))
			if on:
				base.set_pixel(i, j, hot)
	base.set_pixel(5, 5, hot)
	# outline
	var out := base.duplicate() as Image
	for i in 11:
		for j in 11:
			if base.get_pixel(i, j).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(i, j) + d
				if q.x >= 0 and q.y >= 0 and q.x < 11 and q.y < 11 and base.get_pixel(q.x, q.y).a > 0.0:
					out.set_pixel(i, j, ink)
	out.resize(11 * s, 11 * s, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(out), Input.CURSOR_ARROW, Vector2(5 * s + s / 2, 5 * s + s / 2))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# alone, tabbing out pauses; in a party nothing pauses, so no menu
		# appears to hold this player's hands while the fight goes on
		if hud.visible and Game.stage is Dungeon and not has_modal() and not Net.active() and not "autopilot" in Dev.args() and not _dev_capture():
			pause_menu()


## A dev capture or scripted run must not pause when the window loses focus
## (someone else is using the desktop).
static func _dev_capture() -> bool:
	for a in Dev.args():
		if a.begins_with("capture=") or a.begins_with("scenario=") or a == "uismoke" or a.begins_with("frames="):
			return true
	return false


# --- feedback --------------------------------------------------------------------

func banner(title: String, sub := "") -> void:
	banner_title.text = title.to_upper()
	banner_sub.text = sub
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_alpha(0.0)
	_banner_tw.tween_method(_banner_alpha, 0.0, 1.0, 0.4)
	_banner_tw.tween_interval(2.6)
	_banner_tw.tween_method(_banner_alpha, 1.0, 0.0, 0.8)


func _banner_alpha(a: float) -> void:
	banner_box.modulate.a = a
	banner_bg.modulate.a = a


func toast(text: String, col := UIKit.C_TEXT) -> void:
	if text == "":
		return
	for c in toast_box.get_children():
		if c is Label and (c as Label).text == text:
			return     # (it is still on screen)
	var l := UIKit.label(text, 8, col, true)
	toast_box.add_child(l)
	var tw := l.create_tween()
	l.modulate.a = 0.0
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while toast_box.get_child_count() > 5:
		toast_box.get_child(0).free()


func _on_hurt(amount: float) -> void:
	var k := clampf(amount / 30.0, 0.3, 1.0) * (0.5 if Settings.get_value("reduce_flashes", false) else 1.0)
	_hurt_k = k
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _hurt_k = v, k, 0.0, 0.5)


## Low health: the edges pulse red in time with a heartbeat.
func _low_health(delta: float) -> void:
	var m := vignette.material as ShaderMaterial
	var low := 0.0
	var pl: Player = Game.stage.player if Game.stage and hud.visible else null
	if pl and is_instance_valid(pl) and pl.alive and pl.hp_ratio() < 0.3 and not get_tree().paused:
		var danger := 1.0 - pl.hp_ratio() / 0.3
		var period := lerpf(1.0, 0.7, danger)
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = period
			Audio.play("heartbeat", lerpf(-12.0, -5.0, danger))
			Settings.rumble(0.0, 0.25 + 0.25 * danger, 0.08)
		var ph := 1.0 - _beat_t / period
		low = (0.18 + 0.22 * danger) * maxf(0.0, 1.0 - ph * 3.0) * (0.5 if Settings.get_value("reduce_flashes", false) else 1.0)
	else:
		_beat_t = 0.0
	m.set_shader_parameter("hurt", maxf(_hurt_k, low))


## A title card on black: covers a scene change (the walk down the stair, the
## road home) and names where the Kindled arrives. `mid` runs behind it.
func title_card(title: String, sub: String, mid: Callable, extra := "") -> void:
	card_pending = true
	var box := UIKit.vbox(3)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UIKit.label(title.to_upper(), 16, UIKit.C_GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var line := ColorRect.new()
	line.color = Color(0.45, 1.0, 0.88, 0.85)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	var s := UIKit.label(sub, 8, UIKit.C_TEXT, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	if extra != "":
		var e := UIKit.label(extra, 8, Omens.COLOR, true)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(e)
	box.modulate.a = 0.0
	root.add_child(box)
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.45)
	tw.tween_callback(mid)
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(line, "custom_minimum_size:x", 140.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.05)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: card_pending = false)
	tw.tween_property(fader, "color:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


func fade(mid: Callable, t := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, t)
	tw.tween_callback(mid)
	tw.tween_interval(0.1)
	tw.tween_property(fader, "color:a", 0.0, t)


# --- HUD / screens ---------------------------------------------------------------

func show_hud(in_dungeon: bool) -> void:
	close_all()
	hud.visible = true
	hud.set_dungeon(in_dungeon)
	_menu_open = false


func hide_hud() -> void:
	hud.visible = false


## Opens a modal screen. Pauses the game while it is open (unless told not to,
## or in co-op, where the shared world never stops). `dim` is how much of the
## world it darkens behind it (a conversation keeps the scene in view).
func open(screen: Control, pause := true, sound := "ui_open", dim_alpha := 0.55) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.set_meta("pause", pause)
	modals.append(dim)
	_focus_index = -1
	_last_focus = null
	if pause:
		if not Net.active():   # a shared world never stops for one player's menu
			get_tree().paused = true
	Audio.ui(sound)
	return dim


func close_top() -> void:
	if modals.is_empty():
		return
	# a screen may animate its own closing first (the satchel buckles shut)
	var top: Control = modals[modals.size() - 1]
	if top.get_child_count() > 0 and top.get_child(0).has_method("animate_close") and not top.get_meta("closing", false):
		top.set_meta("closing", true)
		top.get_child(0).animate_close(_close_now)
		return
	_close_now()


func _close_now() -> void:
	if modals.is_empty():
		return
	closed_frame = Engine.get_process_frames()
	_closed_ms = Time.get_ticks_msec()
	_focus_index = -1
	_last_focus = null
	var m: Control = modals.pop_back()
	m.queue_free()
	Audio.ui(String(m.get_meta("close_sound", "ui_close")))
	if modals.is_empty() and not _menu_open:
		get_tree().paused = false


## Closes one particular screen, wherever it is in the stack (a vote that ended).
func close_modal(dim: Control) -> void:
	if not modals.has(dim):
		return
	if modals.back() == dim:
		close_top()
		return
	modals.erase(dim)
	dim.queue_free()


func close_all() -> void:
	closed_frame = Engine.get_process_frames()
	_closed_ms = Time.get_ticks_msec()
	for m in modals:
		m.queue_free()
	modals.clear()
	if not _menu_open:
		get_tree().paused = false


func has_modal() -> bool:
	return not modals.is_empty()


## A screen has the player's attention: their Kindled takes no world input
## (move, attack, interact) until it closes, whether or not the world is paused.
func blocks_world() -> bool:
	return not modals.is_empty() or card_pending


## A screen closed a moment ago (the key that closed it, held or pressed
## twice, must not open the same thing again).
func just_closed() -> bool:
	return Time.get_ticks_msec() - _closed_ms < 220


## The open screen of a kind ("dialogue", "coop"...), or null.
func modal_of(kind: String) -> Control:
	for m in modals:
		if is_instance_valid(m) and m.get_meta("kind", "") == kind:
			return m
	return null


## Every full-screen layer UIRoot holds right now (the network overlay and the
## uismoke checks read it: a dimmed layer left behind is a bug).
func layer_count() -> int:
	var n := 0
	for c in modal_layer.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


func _input(event: InputEvent) -> void:
	# keyboard navigation shows the focus ring too; the mouse hides it
	if event is InputEventKey and event.pressed and (event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right") or event.is_action("ui_focus_next")):
		UIKit.show_focus_ring(true)
	elif event is InputEventMouseButton and event.pressed:
		UIKit.show_focus_ring(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if has_modal():
			var top := modals[modals.size() - 1]
			if not top.get_meta("sticky", false):
				close_top()
		elif hud.visible and Game.stage and not _menu_open:
			pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and hud.visible and Game.stage:
		# the satchel opens and closes on the same key
		if has_modal():
			var top := modals[modals.size() - 1]
			if top.get_child_count() > 0 and top.get_child(0) is InventoryUI:
				close_top()
		elif not _menu_open:
			inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hearthtree") and hud.visible and Game.stage and not _menu_open:
		# the Hearthtree opens and closes on its own key, at home or below
		if has_modal():
			var top := modals[modals.size() - 1]
			if top.get_child_count() > 0 and top.get_child(0) is SkillTreeUI:
				close_top()
		else:
			skill_tree()
		get_viewport().set_input_as_handled()
	elif has_modal() and event.is_action_pressed("ui_cancel"):
		var top := modals[modals.size() - 1]
		if not top.get_meta("sticky", false) and not top.get_meta("no_cancel", false):
			close_top()
		get_viewport().set_input_as_handled()
	elif has_modal() and event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		if _switch_tab(modals[modals.size() - 1], -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1):
			get_viewport().set_input_as_handled()
	elif has_modal() and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		# nothing had focus yet: the first navigation press selects a control
		var top := modals[modals.size() - 1]
		if not top.get_meta("own_nav", false):
			_focus_first(top)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and hud.visible and not has_modal():
		hud.toggle_big_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_menu") and OS.has_feature("editor"):
		debug_menu()
		get_viewport().set_input_as_handled()


# Screens live in screens.gd to keep this file about layering.
func show_main_menu() -> void:
	close_all()
	hud.visible = false
	_menu_open = true
	var s := Screens.main_menu(self)
	modal_layer.add_child(s)
	modals.append(s)
	s.set_meta("sticky", true)


func leave_main_menu() -> void:
	_menu_open = false
	close_all()


func relic_choice(ids: Array, on_pick: Callable) -> void:
	open(Screens.relic_choice(self, ids, on_pick))


func shop(prop: Prop) -> void:
	open(Screens.shop(self, prop))


func shrine(prop: Prop) -> void:
	open(Screens.shrine(self, prop))


func confirm(title: String, body: String, yes: Callable) -> void:
	open(Screens.confirm(self, title, body, yes))


func lore(entry: Array) -> void:
	open(Screens.lore(self, entry))


## A conversation (one at a time: a second request while one is open is
## ignored). `on_done` runs exactly once when it closes, however it closes;
## `choices` ([[label, Callable], ...]) end it with a decision, the last one
## being what backing out (Esc / B) means.
func dialogue(speaker: String, lines: Array, on_done: Callable = Callable(), choices: Array = []) -> void:
	if modal_of("dialogue") != null or lines.is_empty():
		return
	var dim := open(Screens.dialogue(self, speaker, lines, on_done, choices), true, "ui_open", 0.0)
	dim.set_meta("kind", "dialogue")
	dim.set_meta("speaker", speaker)
	dim.set_meta("no_cancel", true)    # the conversation handles Esc / B itself


## The co-op party screen (hosting, joining, the party). One at a time.
func party() -> void:
	if modal_of("party") != null:
		return
	var dim := open(PartyUI.new())
	dim.set_meta("kind", "party")
	dim.set_meta("no_cancel", true)    # it steps back through its own views


func pause_menu() -> void:
	open(Screens.pause(self))


func settings() -> void:
	if modal_of("settings") != null:
		return
	var dim := open(Screens.settings(self))
	dim.set_meta("kind", "settings")
	dim.set_meta("no_cancel", true)    # it handles Esc / B (a rebind in progress keeps it)


func wardrobe() -> void:
	var inv := InventoryUI.new()
	inv.wardrobe_open = true
	var dim := open(inv, true, "satchel_open")
	dim.set_meta("close_sound", "satchel_close")


func inventory() -> void:
	var dim := open(InventoryUI.new(), true, "satchel_open")
	dim.set_meta("close_sound", "satchel_close")


func smithy() -> void:
	open(SmithyUI.new())


func peddler() -> void:
	open(PeddlerUI.new())


func apothecary() -> void:
	open(ApothecaryUI.new())


func skill_tree() -> void:
	open(SkillTreeUI.new()).set_meta("own_nav", true)


func forge() -> void:
	open(Screens.forge(self, false))


func weapon_select() -> void:
	open(Screens.forge(self, true))


func sanctuary_build(id: String) -> void:
	open(Screens.sanctuary_build(self, id))


func memorial() -> void:
	open(Screens.memorial(self))


func descent_prompt() -> void:
	open(Screens.descent(self))


func show_summary(summary: Dictionary) -> void:
	close_all()
	hud.visible = false
	var s := open(Screens.summary(self, summary))
	s.set_meta("sticky", true)


func debug_menu() -> void:
	open(Screens.debug(self))
