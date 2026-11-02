## Owns every on-screen interface layer: HUD, banners, toasts, prompts,
## full-screen fades and the modal screens (menus, choices, skill tree...).
class_name UIRoot
extends CanvasLayer

var root: Control
var hud: HUD
var modal_layer: Control
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var toast_box: VBoxContainer
var fader: ColorRect
var vignette: ColorRect
var modals: Array[Control] = []
var _banner_tw: Tween
var _menu_open := false


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
	toast_box = UIKit.vbox(2)
	toast_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	toast_box.position = Vector2(10, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
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
		banner("Level %d" % lvl, "A skill point awaits at the Hearth")
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


func _process(_delta: float) -> void:
	_layout_banner()


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
		if hud.visible and Game.stage is Dungeon and not has_modal() and not "autopilot" in OS.get_cmdline_user_args():
			pause_menu()


# --- feedback --------------------------------------------------------------------

func banner(title: String, sub := "") -> void:
	banner_title.text = title.to_upper()
	banner_sub.text = sub
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween()
	banner_box.modulate.a = 0.0
	_banner_tw.tween_property(banner_box, "modulate:a", 1.0, 0.4)
	_banner_tw.tween_interval(2.6)
	_banner_tw.tween_property(banner_box, "modulate:a", 0.0, 0.8)


func toast(text: String, col := UIKit.C_TEXT) -> void:
	if text == "":
		return
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
	var m := vignette.material as ShaderMaterial
	var k := clampf(amount / 30.0, 0.3, 1.0) * (0.5 if Settings.get_value("reduce_flashes", false) else 1.0)
	m.set_shader_parameter("hurt", k)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("hurt", v), k, 0.0, 0.5)


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


## Opens a modal screen. Pauses the game while it is open (unless told not to).
func open(screen: Control, pause := true) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.set_meta("pause", pause)
	modals.append(dim)
	if pause:
		get_tree().paused = true
	Audio.ui("ui_open")
	return dim


func close_top() -> void:
	if modals.is_empty():
		return
	var m: Control = modals.pop_back()
	m.queue_free()
	Audio.ui("ui_close")
	if modals.is_empty() and not _menu_open:
		get_tree().paused = false


func close_all() -> void:
	for m in modals:
		m.queue_free()
	modals.clear()
	if not _menu_open:
		get_tree().paused = false


func has_modal() -> bool:
	return not modals.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if has_modal():
			var top := modals[modals.size() - 1]
			if not top.get_meta("sticky", false):
				close_top()
		elif hud.visible and Game.stage and not _menu_open:
			pause_menu()
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


func dialogue(speaker: String, lines: Array, on_done: Callable = Callable()) -> void:
	open(Screens.dialogue(self, speaker, lines, on_done))


func pause_menu() -> void:
	open(Screens.pause(self))


func settings() -> void:
	open(Screens.settings(self))


func skill_tree() -> void:
	open(SkillTreeUI.new())


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
