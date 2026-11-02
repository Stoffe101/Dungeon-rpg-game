## Shared interface building blocks: the theme (carved stone + warm iron),
## the pixel fonts, icons from the generated atlas, and small widget helpers.
class_name UIKit
extends RefCounted

const FONT := preload("res://assets/fonts/kindled.fnt")
const FONT_OUTLINE := preload("res://assets/fonts/kindled_outline.fnt")
const ICONS := preload("res://assets/sprites/icons.png")

const C_TEXT := Color(0.95, 0.92, 0.86)
const C_DIM := Color(0.62, 0.58, 0.66)
const C_EMBER := Color(1.0, 0.62, 0.28)
const C_GOLD := Color(1.0, 0.85, 0.45)
const C_SOUL := Color(0.45, 0.95, 0.85)
const C_BAD := Color(1.0, 0.4, 0.4)
const C_GOOD := Color(0.55, 1.0, 0.6)

static var _theme: Theme
static var _icon_map: Dictionary = {}
## Gold ring around the focused control; only visible while navigating
## with a pad or keys (mouse users never see it).
static var focus_ring: StyleBoxFlat


static func _focus_box() -> StyleBoxFlat:
	if focus_ring == null:
		focus_ring = StyleBoxFlat.new()
		focus_ring.draw_center = false
		focus_ring.set_border_width_all(1)
		focus_ring.set_expand_margin_all(1)
		focus_ring.border_color = Color(C_GOLD, 0.0)
	return focus_ring


static func show_focus_ring(on: bool) -> void:
	_focus_box().border_color = Color(C_GOLD, 1.0 if on else 0.0)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 8
	var panel := _tex_box("res://assets/ui/ui_panel.png", 6, 8)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var dark := _tex_box("res://assets/ui/ui_panel_dark.png", 4, 5)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", dark)
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _tex_box("res://assets/ui/ui_card.png", 6, 8))
	t.set_stylebox("panel", "TooltipPanel", _tex_box("res://assets/ui/ui_tooltip.png", 4, 5))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_font("font", "TooltipLabel", FONT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var file: String = {"normal": "ui_button", "hover": "ui_button_hover", "pressed": "ui_button_pressed", "disabled": "ui_button_disabled", "focus": "ui_button_hover"}[st]
		var sb: StyleBox = _tex_box("res://assets/ui/%s.png" % file, 4, 6)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		if st == "focus":
			sb = _focus_box()
		t.set_stylebox(st, "Button", sb)
		t.set_stylebox(st, "OptionButton", sb)
	t.set_stylebox("focus", "CheckBox", _focus_box())
	t.set_stylebox("focus", "HSlider", _focus_box())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_GOLD)
	t.set_color("font_pressed_color", "Button", C_EMBER)
	t.set_color("font_disabled_color", "Button", C_DIM)
	t.set_color("font_focus_color", "Button", C_GOLD)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_color", "OptionButton", C_TEXT)
	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_color("font_hover_color", "CheckBox", C_GOLD)
	# sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.04, 0.08)
	track.border_color = Color(0.35, 0.27, 0.22)
	track.set_border_width_all(1)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.48, 0.2)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _solid_tex(6, 10, C_GOLD)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", _solid_tex(6, 10, Color(1, 1, 1)))
	# tabs share the button look; the tab body is a dark inset panel
	t.set_stylebox("panel", "TabContainer", _tex_box("res://assets/ui/ui_panel_dark.png", 4, 6))
	t.set_stylebox("tab_selected", "TabContainer", _tex_box("res://assets/ui/ui_button_hover.png", 4, 6))
	t.set_stylebox("tab_unselected", "TabContainer", _tex_box("res://assets/ui/ui_button.png", 4, 6))
	t.set_stylebox("tab_hovered", "TabContainer", _tex_box("res://assets/ui/ui_button_hover.png", 4, 6))
	t.set_stylebox("tab_disabled", "TabContainer", _tex_box("res://assets/ui/ui_button_disabled.png", 4, 6))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", C_GOLD)
	t.set_color("font_unselected_color", "TabContainer", C_DIM)
	t.set_color("font_hovered_color", "TabContainer", C_TEXT)
	t.set_font("font", "TabContainer", FONT)
	t.set_font_size("font_size", "TabContainer", 8)
	var pop := _tex_box("res://assets/ui/ui_tooltip.png", 4, 4)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_GOLD)
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 4)
	var sep := StyleBoxLine.new()
	sep.color = Color(0.35, 0.27, 0.22)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


static func _tex_box(path: String, margin: int, content: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content
	sb.content_margin_bottom = content
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


static func _solid_tex(w: int, h: int, c: Color) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	for x in w:
		img.set_pixel(x, 0, Color(0.04, 0.04, 0.06))
		img.set_pixel(x, h - 1, Color(0.04, 0.04, 0.06))
	for y in h:
		img.set_pixel(0, y, Color(0.04, 0.04, 0.06))
		img.set_pixel(w - 1, y, Color(0.04, 0.04, 0.06))
	return ImageTexture.create_from_image(img)


# --- icons ---------------------------------------------------------------------

static func icon(name: String) -> AtlasTexture:
	if _icon_map.is_empty():
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/icons.json"))
		if meta is Dictionary:
			_icon_map = meta.icons
	var at := AtlasTexture.new()
	at.atlas = ICONS
	var cell: Array = _icon_map.get(name, _icon_map.get("star", [0, 0]))
	at.region = Rect2(float(cell[0]) * 16.0, float(cell[1]) * 16.0, 16, 16)
	return at


static var _item_map: Dictionary = {}
static var _items_tex: Texture2D


## Gear and material icons (16px, items atlas).
static func item_icon(name: String) -> AtlasTexture:
	if _item_map.is_empty():
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/items.json"))
		if meta is Dictionary:
			_item_map = meta.icons
		_items_tex = load("res://assets/sprites/items.png")
	var at := AtlasTexture.new()
	at.atlas = _items_tex
	var cell: Array = _item_map.get(name, _item_map.get("bag", [0, 0]))
	at.region = Rect2(float(cell[0]) * 16.0, float(cell[1]) * 16.0, 16, 16)
	return at


static var _icons_small: ImageTexture


## An 8px version of an icon (averaged down from the 16px atlas) for tight spots.
static func icon_small(name: String) -> AtlasTexture:
	icon(name)   # loads the atlas map
	if _icons_small == null:
		var img := ICONS.get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		_icons_small = ImageTexture.create_from_image(img)
	var at := AtlasTexture.new()
	at.atlas = _icons_small
	var cell: Array = _icon_map.get(name, _icon_map.get("star", [0, 0]))
	at.region = Rect2(float(cell[0]) * 8.0, float(cell[1]) * 8.0, 8, 8)
	return at


static func item_icon_rect(name: String, scale := 1) -> TextureRect:
	var tr := icon_rect("star", scale)
	tr.texture = item_icon(name)
	return tr


static func icon_rect(name: String, scale := 1) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon(name)
	tr.custom_minimum_size = Vector2(16, 16) * scale
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_PASS
	return tr


# --- widgets -------------------------------------------------------------------

static func label(text: String, size := 8, col := C_TEXT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_font_override("font", FONT_OUTLINE)
	return l


static func para(text: String, width := 160, col := C_TEXT) -> Label:
	var l := label(text, 8, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func button(text: String, cb: Callable, min_w := 60) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 16)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Audio.ui("ui_click")
		cb.call())
	b.mouse_entered.connect(func() -> void: Audio.ui("ui_hover"))
	b.focus_mode = Control.FOCUS_ALL
	return b


static func panel(variation := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func vbox(sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 4) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func cost_row(cost: Dictionary, have_check := true) -> HBoxContainer:
	var row := hbox(2)
	for k in cost:
		var ok: bool = not have_check or Profile.currency(k) >= int(cost[k])
		row.add_child(icon_rect("ember" if k == "embers" else "sunshard"))
		row.add_child(label(str(cost[k]), 8, C_TEXT if ok else C_BAD))
	return row


static func fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


## Human-readable text for a stat modifier.
static func describe_mod(m: Array) -> String:
	var stat: String = m[0]
	var op: String = m[1]
	var v: float = m[2]
	var pct := "%+d%%" % int(round(v * 100.0))
	var names := {
		"melee_damage": "melee damage", "fire_damage": "fire damage", "frost_damage": "frost damage", "ability_damage": "ability damage",
		"damage": "damage", "crit_chance": "critical strike chance", "crit_mult": "critical strike damage", "attack_speed": "attack speed",
		"poise_damage": "poise damage (stagger)", "burn_chance": "chance to Burn on hit", "burn_damage": "Burn damage", "chill_chance": "chance to Chill on hit",
		"chill_power": "Chill strength", "status_duration": "status duration", "move_speed": "movement speed", "dodge_distance": "dodge distance",
		"armor": "armor", "parry_window": "Ward window", "kindle_gain": "Kindle gained", "summon_damage": "wisp damage", "ember_gain": "Embers found",
		"flask_heal": "flask healing", "kindle_max": "maximum Kindle", "max_hp": "maximum health",
		"xp_gain": "Memories gained", "heal_mult": "healing received",
	}
	match stat:
		"max_hp":
			return "%+d maximum health" % int(v) if op == "add" else "%s maximum health" % pct
		"kindle_max":
			return "%+d maximum Kindle" % int(v) if op == "add" else "%s maximum Kindle" % pct
		"dodge_charges":
			return "%+d dodge charge" % int(v)
		"flask_charges":
			return "%+d flask charge" % int(v)
		"burn_stacks":
			return "Burn stacks %+d more times" % int(v)
		"thorns":
			return "Attackers take %d damage" % int(v)
		"life_on_kill":
			return "Heal %d on kill" % int(v)
		"kindle_on_kill":
			return "+%d Kindle on kill" % int(v)
		"parry_window":
			return "Ward window %+.2fs" % v
		"dodge_iframes":
			return "Dodge invulnerability %+.2fs" % v if op == "add" else "%s dodge invulnerability" % pct
		"dodge_recharge":
			return "Dodges recharge %d%% faster" % int(round(-v * 100.0))
		"ability_cost":
			return "Abilities cost %d%% less" % int(round(-v * 100.0))
		"cooldown":
			return "%d%% shorter cooldowns" % int(round(-v * 100.0))
		"damage_taken":
			return "Take %s damage" % pct
	var n: String = names.get(stat, stat.replace("_", " "))
	if op == "more":
		return "%s %s (multiplicative)" % [pct, n]
	return "%s %s" % [pct, n]
