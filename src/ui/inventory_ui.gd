## The satchel: the Kindled with their equipment around them, the bag of gear
## gathered so far, materials, and a side panel of character stats that can be
## opened and closed. Click a bag item to equip it (what was worn goes back in
## the bag), click a worn item to take it off, right-click (pad: X) to salvage.
class_name InventoryUI
extends Control

const BAG_COLS := 8
const BAG_SLOTS := 40
const DOLL := {
	"head": Vector2(6, 6), "chest": Vector2(6, 46), "hands": Vector2(6, 86),
	"ring": Vector2(128, 6), "charm": Vector2(128, 46), "feet": Vector2(128, 86),
	"weapon": Vector2(67, 128),
}

var tip: GearUI.FloatTip
var stats_open := true
var wardrobe_open := false
var body: HBoxContainer
var _focus_uid := -1
var _player_tex: AtlasTexture
# the bag itself: body, the flap (closed over the front, thrown back when open)
var _rig: Control
var _bag: PanelContainer
var _contents: Control
var _flap_back: NinePatchRect
var _opened := false
# the satchel as it looks shut: shown while it opens and closes
var _closed: Control
var _closed_flap: TextureRect
var _buckles: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	stats_open = bool(Profile.data.flags.get("satchel_stats", true))
	var info := SpriteLib.get_sheet("player")
	_player_tex = AtlasTexture.new()
	_player_tex.atlas = info.texture
	var a: Dictionary = info.anims["idle_down"]
	_player_tex.region = Rect2(0, float(a.row) * info.frame_size.y, info.frame_size.x, info.frame_size.y)
	rebuild()
	Profile.changed.connect(_on_changed)


func _exit_tree() -> void:
	if Profile.changed.is_connected(_on_changed):
		Profile.changed.disconnect(_on_changed)
	Profile.save_profile()
	if Game.stage and Game.stage.player:
		Game.stage.player.rebuild_stats()


func _on_changed() -> void:
	rebuild.call_deferred()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# the bag: a plain rig (so the flaps can sit outside the leather body) holding
	# the stitched body, with everything inside it in pockets and lining
	_rig = Control.new()
	center.add_child(_rig)
	_flap_back = _nine("res://assets/ui/satchel_flap_inside.png", 10)
	_rig.add_child(_flap_back)
	_bag = UIKit.panel("SatchelBody")
	_rig.add_child(_bag)
	var outer := UIKit.vbox(4)
	_contents = outer
	_bag.add_child(outer)
	# header
	var head := UIKit.hbox(8)
	var em := TextureRect.new()
	em.texture = load("res://assets/ui/satchel_emblem.png")
	em.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	em.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(em)
	head.add_child(UIKit.label("SATCHEL", 16, UIKit.C_GOLD, true))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	head.add_child(UIKit.button("Wardrobe", func() -> void:
		wardrobe_open = not wardrobe_open
		rebuild(), 56))
	head.add_child(UIKit.button("Hide stats" if stats_open else "Show stats", _toggle_stats, 60))
	head.add_child(UIKit.button("Close", func() -> void: Game.ui.close_top(), 44))
	outer.add_child(head)
	body = UIKit.hbox(5)
	outer.add_child(body)
	body.add_child(_doll_panel())
	body.add_child(_wardrobe_panel() if wardrobe_open else _bag_panel())
	if stats_open:
		body.add_child(GearUI.stats_panel(140, "SatchelPocket"))
	var hint := UIKit.label("", 8, Color(0.85, 0.74, 0.6), true)
	hint.text = "A equip / take off   X salvage   B close" if Settings.using_pad else "Click: equip / take off    Right-click: salvage    %s: close" % Settings.describe_action("inventory")
	outer.add_child(hint)
	_fit_rig()
	tip = GearUI.FloatTip.new()
	add_child(tip)
	if not _opened:
		_opened = true
		_animate_open()
	# keep pad focus on the same item across rebuilds
	if _focus_uid >= 0:
		var b := find_child("uid_%d" % _focus_uid, true, false)
		if b:
			(b as Control).grab_focus.call_deferred()


# --- the bag opening and closing --------------------------------------------------

func _nine(path: String, m: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(path)
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m
	n.patch_margin_bottom = m
	n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return n


## Sizes the rig to the bag and lays the flaps around it: the underside of the
## flap thrown back above the bag, the closed flap (with its buckle and the
## hearth emblem) over the front.
func _fit_rig() -> void:
	var ms := _bag.get_combined_minimum_size()
	var lip := 16.0
	_rig.custom_minimum_size = ms + Vector2(0, lip)
	_bag.position = Vector2(0, lip)
	_bag.size = ms
	_flap_back.position = Vector2(10, 0)
	_flap_back.size = Vector2(ms.x - 20, lip + 8)
	_flap_back.pivot_offset = Vector2(_flap_back.size.x / 2.0, lip + 8)
	_rig.pivot_offset = _rig.custom_minimum_size / 2.0


## The shut satchel, centred on screen: body with its shoulder strap, the flap
## (pivoting at its top edge) and the two buckles its straps run into.
func _make_closed() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_closed = Control.new()
	_closed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closed.custom_minimum_size = Vector2(260, 184)
	holder.add_child(_closed)
	var body := _pic("res://assets/ui/satchel_closed.png")
	_closed.add_child(body)
	_closed_flap = _pic("res://assets/ui/satchel_closed_flap.png")
	_closed_flap.position = Vector2(14, 50)
	_closed.add_child(_closed_flap)
	_buckles.clear()
	for bx in [78.0, 182.0]:
		var b := _pic("res://assets/ui/satchel_buckle_big.png")
		b.position = Vector2(bx - 12.0, 152.0)
		_closed.add_child(b)
		_buckles.append(b)
	_closed.pivot_offset = Vector2(130, 92)


func _pic(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _tw() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


## The shut satchel pops up, its straps slip their buckles, the flap swings up,
## and the bag unfolds into the open satchel with its pockets in the light.
func _animate_open() -> void:
	_make_closed()
	_closed.scale = Vector2(0.6, 0.6)
	_closed.modulate.a = 0.0
	_rig.modulate.a = 0.0
	_rig.scale = Vector2(0.9, 0.9)
	_contents.modulate.a = 0.0
	_flap_back.scale = Vector2(1, 0)
	var t := _tw()
	t.tween_property(_closed, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(_closed, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_closed, "scale", Vector2.ONE, 0.06)
	# the straps slip their buckles
	t.tween_property(_closed_flap, "position:y", 46.0, 0.07)
	for b in _buckles:
		t.parallel().tween_property(b, "position:y", 156.0, 0.07)
	# the flap swings up and over
	t.tween_property(_closed_flap, "scale:y", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# the open satchel takes its place
	t.tween_property(_closed, "scale", Vector2(1.5, 1.5), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_closed, "modulate:a", 0.0, 0.16)
	t.parallel().tween_property(_rig, "modulate:a", 1.0, 0.14)
	t.parallel().tween_property(_rig, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_flap_back, "scale:y", 1.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_contents, "modulate:a", 1.0, 0.14)
	t.tween_callback(func() -> void:
		if is_instance_valid(_closed):
			_closed.get_parent().queue_free())


## Called by UIRoot.close_top: the flap falls shut and the bag drops away.
func animate_close(done: Callable) -> void:
	if tip:
		tip.visible = false
	if _rig == null or not is_instance_valid(_rig):
		done.call()
		return
	if _closed == null or not is_instance_valid(_closed):
		_make_closed()
	_closed.modulate.a = 0.0
	_closed.scale = Vector2(1.4, 1.4)
	_closed_flap.scale = Vector2(1, 0)
	_closed_flap.position.y = 46.0
	for b in _buckles:
		b.position.y = 156.0
	var t := _tw()
	# the open satchel folds back into the shut one
	t.tween_property(_contents, "modulate:a", 0.0, 0.06)
	t.parallel().tween_property(_flap_back, "scale:y", 0.0, 0.06)
	t.tween_property(_rig, "modulate:a", 0.0, 0.1)
	t.parallel().tween_property(_rig, "scale", Vector2(0.9, 0.9), 0.1)
	t.parallel().tween_property(_closed, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(_closed, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# flap down, straps into their buckles, and away
	t.tween_property(_closed_flap, "scale:y", 1.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_closed_flap, "position:y", 50.0, 0.05)
	for b in _buckles:
		t.parallel().tween_property(b, "position:y", 152.0, 0.05)
	t.tween_property(_closed, "scale", Vector2(0.7, 0.7), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_closed, "modulate:a", 0.0, 0.1)
	t.tween_callback(done)


func _toggle_stats() -> void:
	stats_open = not stats_open
	Profile.data.flags["satchel_stats"] = stats_open
	rebuild()


# --- the Kindled and what they wear -----------------------------------------------

func _doll_panel() -> PanelContainer:
	var p := UIKit.panel("SatchelPocket")
	var v := UIKit.vbox(2)
	p.add_child(v)
	v.add_child(UIKit.label("THE KINDLED   Lv %d" % Profile.level(), 8, UIKit.C_GOLD, true))
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(158, 170)
	v.add_child(doll)
	# a soft hearth glow behind the figure
	var glow := _Glow.new()
	glow.position = Vector2(79, 74)
	doll.add_child(glow)
	var fig := TextureRect.new()
	fig.texture = _player_tex
	fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fig.stretch_mode = TextureRect.STRETCH_SCALE
	fig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fig.size = Vector2(96, 96)
	fig.position = Vector2(31, 22)
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.material = Looks.canvas_material(Looks.current())
	doll.add_child(fig)
	for t in GearLooks.portrait_layers(Profile.equipped(), Profile.inv().get("shown", {})):
		var layer := TextureRect.new()
		layer.texture = t
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.size = fig.size
		layer.position = fig.position
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		doll.add_child(layer)
	var eq := Profile.equipped()
	for slot in DOLL:
		var b: Button
		if slot == "weapon" and Profile.weapon_item().is_empty():
			b = _weapon_button()     # the plain archetype from the forge
		else:
			var it: Dictionary = eq.get(slot, {}) if eq.get(slot) is Dictionary else {}
			b = GearUI.slot_button(it, 26, _empty_icon(slot))
			if not it.is_empty():
				b.name = "uid_%d" % int(it.uid)
				var u := int(it.uid)
				b.pressed.connect(func() -> void: _unequip(slot, u))
				_tip_on(b, func() -> Control: return _item_tip(it, {}, "Click to take off"))
			else:
				_tip_on(b, func() -> Control: return UIKit.label("%s: empty" % ItemDB.SLOT_NAMES[slot], 8, UIKit.C_DIM))
		b.position = DOLL[slot]
		doll.add_child(b)
		var lbl := UIKit.label(ItemDB.SLOT_NAMES[slot], 8, UIKit.C_DIM)
		lbl.position = DOLL[slot] + (Vector2(0, 26) if slot != "weapon" else Vector2(-4, 26))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		doll.add_child(lbl)
	_materials(v)
	return p


func _empty_icon(slot: String) -> String:
	return {"head": "helm", "chest": "robe", "hands": "gloves", "feet": "boots", "ring": "band", "charm": "totem", "weapon": "wpn_sword"}.get(slot, "bag")


func _weapon_button() -> Button:
	var wid := Profile.equipped_weapon()
	var b := Button.new()
	b.custom_minimum_size = Vector2(26, 26)
	b.focus_mode = Control.FOCUS_ALL
	var tr := UIKit.icon_rect({"sword": "sword", "hammer": "hammer", "staff": "staff"}.get(wid, "sword"))
	tr.position = Vector2(5, 5)
	tr.size = Vector2(16, 16)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tr)
	var def := GearDB.weapon(wid)
	var in_hub := Game.stage is Hub
	b.pressed.connect(func() -> void:
		if in_hub:
			Game.ui.weapon_select())
	_tip_on(b, func() -> Control:
		var v := UIKit.vbox(2)
		v.add_child(UIKit.label("%s   (forge +%d)" % [def.get("name", wid), Profile.weapon_level(wid)], 8, UIKit.C_GOLD, true))
		v.add_child(UIKit.para(String(def.get("desc", "")), 160))
		v.add_child(UIKit.label("Click to change weapon" if in_hub else "Change weapons at the Hearth", 8, UIKit.C_DIM))
		return v)
	return b


# --- the wardrobe (transmogrification) ---------------------------------------------------

func _wardrobe_panel() -> PanelContainer:
	var p := UIKit.panel("SatchelLining")
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label("WARDROBE", 8, UIKit.C_GOLD, true))
	v.add_child(UIKit.para("Wear any look you have earned, whatever your gear. Tier sets (two pieces) and legendaries unlock theirs.", 196, UIKit.C_DIM))
	var chosen := String(Profile.inv().get("look", ""))
	var auto := UIKit.button(("> " if chosen == "" else "") + "Match my gear (%s)" % Looks.LOOKS[ItemDB.gear_look(Profile.equipped())].name, func() -> void: _wear(""), 190)
	v.add_child(auto)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for id in Looks.LOOKS:
		var have := Looks.unlocked().has(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 52)
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = not have
		var fig := TextureRect.new()
		fig.texture = _player_tex
		fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fig.stretch_mode = TextureRect.STRETCH_SCALE
		fig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fig.size = Vector2(32, 32)
		fig.position = Vector2(7, 2)
		fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fig.material = Looks.canvas_material(id)
		fig.modulate = Color(1, 1, 1, 1) if have else Color(0.15, 0.15, 0.2, 0.9)
		b.add_child(fig)
		var nm := UIKit.label(String(Looks.LOOKS[id].short) if have else "???", 8, UIKit.C_GOLD if id == chosen else (UIKit.C_TEXT if have else UIKit.C_DIM))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.size = Vector2(46, 12)
		nm.position = Vector2(0, 36)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
		var look_id: String = id
		b.pressed.connect(func() -> void: _wear(look_id))
		_tip_on(b, func() -> Control:
			var tv := UIKit.vbox(1)
			tv.add_child(UIKit.label(Looks.LOOKS[look_id].name if have else "Not yet earned", 8, UIKit.C_GOLD, true))
			tv.add_child(UIKit.label(String(Looks.LOOKS[look_id].desc), 8, UIKit.C_DIM))
			return tv)
		grid.add_child(b)
	# what each piece looks like, separately from what it is
	v.add_child(UIKit.label("APPEARANCE", 8, UIKit.C_GOLD, true))
	for slot in ["head", "chest", "hands", "feet"]:
		var row := UIKit.hbox(3)
		row.add_child(UIKit.label(String(slot).capitalize(), 8, UIKit.C_DIM))
		var opts := _appearance_options(slot)
		var shown: Dictionary = Profile.inv().get("shown", {})
		var cur := String(shown.get(slot, ""))
		var idx := maxi(0, opts.find(cur))
		var sl: String = slot
		var lbl := UIKit.label(_appearance_name(cur), 8, UIKit.C_TEXT)
		lbl.custom_minimum_size = Vector2(120, 0)
		var step := func(d: int) -> void:
			idx = posmod(idx + d, opts.size())
			var sh: Dictionary = Profile.inv().get("shown", {})
			sh[sl] = opts[idx]
			Profile.inv()["shown"] = sh
			Profile.mark_changed()
			lbl.text = _appearance_name(String(opts[idx]))
			Audio.ui("ui_click")
			if Game.stage and Game.stage.player:
				Game.stage.player.refresh_paperdoll()
		row.add_child(UIKit.button("<", func() -> void: step.call(-1), 14))
		row.add_child(lbl)
		row.add_child(UIKit.button(">", func() -> void: step.call(1), 14))
		v.add_child(row)
	return p


## Equipped (""), hidden ("none"), or the look of any piece the Kindled owns for that slot.
func _appearance_options(slot: String) -> Array:
	var out: Array = ["", "none"]
	var items: Array = (Profile.inv().get("bag", []) as Array).duplicate()
	for s in Profile.equipped():
		if Profile.equipped()[s] is Dictionary:
			items.append(Profile.equipped()[s])
	for it in items:
		var b := String((it as Dictionary).get("base", ""))
		if ItemDB.base(b).get("slot", "") == slot and GearLooks.VIS.has(b) and not out.has(b):
			out.append(b)
	return out


func _appearance_name(id: String) -> String:
	if id == "":
		return "As equipped"
	if id == "none":
		return "Hidden"
	return String(ItemDB.base(id).get("name", id))


func _wear(id: String) -> void:
	Looks.choose(id)
	Looks.apply_player(Looks.current())
	Audio.play("clank", -8.0, 1.3)


# --- the bag ------------------------------------------------------------------------

## What the Kindled has gathered for the smith, kept in the character pocket.
func _materials(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("MATERIALS", 8, UIKit.C_GOLD, true))
	var mg := GridContainer.new()
	mg.columns = 4
	mg.add_theme_constant_override("h_separation", 8)
	for k in ItemDB.MATERIALS:
		var h := UIKit.hbox(2)
		var ic := UIKit.item_icon_rect(ItemDB.MATERIALS[k].icon)
		h.add_child(ic)
		var n := Profile.material(k)
		h.add_child(UIKit.label(str(n), 8, UIKit.C_TEXT if n > 0 else UIKit.C_DIM))
		h.tooltip_text = "%s - %s" % [ItemDB.MATERIALS[k].name, ItemDB.MATERIALS[k].desc]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		mg.add_child(h)
	v.add_child(mg)


func _bag_panel() -> PanelContainer:
	var p := UIKit.panel("SatchelLining")
	var v := UIKit.vbox(3)
	p.add_child(v)
	var bag := Profile.bag()
	v.add_child(UIKit.label("GEAR  %d" % bag.size(), 8, UIKit.C_GOLD, true))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(BAG_COLS * 25 + 8, 5 * 25)
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = BAG_COLS
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	scroll.add_child(grid)
	var eq := Profile.equipped()
	for i in maxi(BAG_SLOTS, bag.size()):
		if i >= bag.size():
			var e := GearUI.slot_button({}, 24)
			e.focus_mode = Control.FOCUS_NONE
			grid.add_child(e)
			continue
		var it: Dictionary = bag[i]
		var b := GearUI.slot_button(it, 24)
		b.name = "uid_%d" % int(it.uid)
		var u := int(it.uid)
		var slot := String(ItemDB.base(String(it.base)).slot)
		var worn: Dictionary = eq.get(slot, {}) if eq.get(slot) is Dictionary else {}
		b.pressed.connect(func() -> void: _equip(u))
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				_salvage(u))
		b.focus_entered.connect(func() -> void: _focus_uid = u)
		_tip_on(b, func() -> Control: return _item_tip(it, worn, "Click to equip   Right-click to salvage"))
		grid.add_child(b)
	# blueprints: unread scrolls to learn, and how many are known
	var known := Profile.known_blueprints().size()
	v.add_child(UIKit.label("BLUEPRINTS  %d/%d known" % [known, ItemDB.blueprints().size()], 8, UIKit.C_GOLD, true))
	var sr := UIKit.hbox(2)
	if Profile.scrolls().is_empty():
		sr.add_child(UIKit.label("Rare finds from elites, chests and bosses.", 8, UIKit.C_DIM))
	for bid in Profile.scrolls():
		var sb := GearUI.slot_button({}, 22, "scroll")
		(sb.get_child(0) as TextureRect).modulate = Color(1, 1, 1, 1)
		var id: String = bid
		sb.pressed.connect(func() -> void: _learn(id))
		_tip_on(sb, func() -> Control:
			var tv := UIKit.vbox(2)
			tv.add_child(UIKit.label("Blueprint: %s" % ItemDB.base(id).name, 8, Color(1.0, 0.75, 0.35), true))
			tv.add_child(UIKit.para(String(ItemDB.base(id).get("desc", "")), 160))
			tv.add_child(UIKit.label("Click to learn - then forge it at the smithy", 8, UIKit.C_GOLD))
			return tv)
		sr.add_child(sb)
	v.add_child(sr)
	return p


func _learn(id: String) -> void:
	if Profile.learn_blueprint(id):
		Audio.play("learn", 0.0)
		Game.ui.toast("Learned: %s - forge it at the smithy" % ItemDB.base(id).name, Color(1.0, 0.75, 0.35))


func _item_tip(it: Dictionary, compare: Dictionary, hint: String) -> Control:
	var v := GearUI.item_info(it, compare)
	v.add_child(UIKit.label("Worth %d Embers to the peddler" % ItemDB.value(it), 8, UIKit.C_DIM))
	v.add_child(UIKit.label(hint if not Settings.using_pad else hint.replace("Click", "A").replace("Right-click", "X"), 8, UIKit.C_GOLD))
	return v


func _tip_on(b: Control, make: Callable) -> void:
	b.mouse_entered.connect(func() -> void: tip.show_content(make.call(), get_global_mouse_position()))
	b.mouse_exited.connect(func() -> void: tip.visible = false)
	b.focus_entered.connect(func() -> void: tip.show_content(make.call(), b.global_position + Vector2(b.size.x, 0)))
	b.focus_exited.connect(func() -> void: tip.visible = false)


func _input(event: InputEvent) -> void:
	# pad: X salvages the focused bag item
	if event.is_action_pressed("ability_1") and Settings.using_pad:
		var f := get_viewport().gui_get_focus_owner()
		if f and String(f.name).begins_with("uid_") and not Profile.find_item(int(String(f.name).substr(4))).is_empty():
			var u := int(String(f.name).substr(4))
			for it in Profile.bag():
				if int(it.uid) == u:
					_salvage(u)
					get_viewport().set_input_as_handled()
					return


# --- actions ---------------------------------------------------------------------

func _equip(uid: int) -> void:
	_focus_uid = uid
	if Profile.equip(uid):
		Audio.play("clank", -4.0, 1.1)


func _unequip(slot: String, uid: int) -> void:
	_focus_uid = uid
	if Profile.unequip(slot):
		Audio.play("clank", -6.0, 0.9)


func _salvage(uid: int) -> void:
	var it := Profile.find_item(uid)
	if it.is_empty():
		return
	var y := ItemDB.salvage_yield(it)
	var parts: Array = []
	for k in y:
		parts.append("%d %s" % [int(y[k]), ItemDB.MATERIALS[k].name])
	Game.ui.confirm("Salvage %s?" % ItemDB.item_name(it), "It breaks down into %s." % ", ".join(parts), func() -> void:
		Profile.salvage(uid)
		Audio.play("forge", -4.0, 1.2))


## The warm halo behind the figure.
class _Glow:
	extends Node2D
	func _draw() -> void:
		for k in 5:
			draw_circle(Vector2.ZERO, 46.0 - k * 8.0, Color(1.0, 0.55, 0.22, 0.04 + 0.02 * k))
