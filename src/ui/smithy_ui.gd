## The blacksmith's bench: craft gear from materials, temper it to higher
## levels, or break pieces down. Crafting rolls a rarity; a boss catalyst
## (Warden Sigil, Bloom Heart) makes a guaranteed epic masterwork.
class_name SmithyUI
extends Control

var tab := "craft"
var selected := ""            # craft: base id; temper/salvage: item uid as string
var tip: GearUI.FloatTip
var _last_result: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	rebuild()


func _exit_tree() -> void:
	Profile.save_profile()
	if Game.stage and Game.stage.player:
		Game.stage.player.rebuild_stats()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(430, 0)
	center.add_child(p)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.item_icon_rect("anvil"))
	head.add_child(UIKit.label("THE SMITHY", 16, UIKit.C_GOLD, true))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	for t in [["craft", "Craft"], ["temper", "Temper"], ["salvage", "Salvage"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func() -> void:
			tab = key
			selected = ""
			_last_result = {}
			rebuild(), 46)
		if tab == key:
			b.add_theme_color_override("font_color", UIKit.C_GOLD)
		head.add_child(b)
	head.add_child(UIKit.button("Close", func() -> void: Game.ui.close_top(), 40))
	v.add_child(head)
	v.add_child(UIKit.label(_flavour(), 8, UIKit.C_DIM))
	var row := UIKit.hbox(6)
	v.add_child(row)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(170, 200)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(list_scroll)
	var list := UIKit.vbox(1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	var detail := UIKit.panel("DarkPanel")
	detail.custom_minimum_size = Vector2(240, 200)
	row.add_child(detail)
	var dv := UIKit.vbox(3)
	detail.add_child(dv)
	match tab:
		"craft":
			_craft_list(list)
			_craft_detail(dv)
		"temper":
			_item_list(list, func(it: Dictionary) -> bool: return int(it.level) < ItemDB.MAX_LEVEL, true)
			_temper_detail(dv)
		"salvage":
			_item_list(list, func(_it: Dictionary) -> bool: return true, false)
			_salvage_detail(dv)
	tip = GearUI.FloatTip.new()
	add_child(tip)


func _flavour() -> String:
	match tab:
		"temper":
			return '"Heat it, fold it, quench it. Every temper makes it a little more yours."'
		"salvage":
			return '"Nothing is wasted at a forge. Bring me what you do not wear."'
	return '"Bring me iron and bone and I will make you something that will not break."'


# --- craft --------------------------------------------------------------------------

func _craft_list(list: VBoxContainer) -> void:
	var by_slot := {}
	for b in ItemDB.craftable():
		var s := String(ItemDB.BASES[b].slot)
		if not by_slot.has(s):
			by_slot[s] = []
		by_slot[s].append(b)
	var first := ""
	for s in ItemDB.SLOTS:
		if not by_slot.has(s):
			continue
		list.add_child(UIKit.label(String(ItemDB.SLOT_NAMES[s]).to_upper(), 8, UIKit.C_GOLD, true))
		for b in by_slot[s]:
			var base: Dictionary = ItemDB.BASES[b]
			var ok := Profile.can_pay(ItemDB.recipe(b))
			var btn := _list_button(base.icon, String(base.name), UIKit.C_TEXT if ok else UIKit.C_DIM, b == selected)
			var bid: String = b
			btn.pressed.connect(func() -> void:
				selected = bid
				_last_result = {}
				rebuild())
			list.add_child(btn)
			if first == "":
				first = b
	# uniques from learned blueprints; unknown ones are only hinted at
	list.add_child(UIKit.label("BLUEPRINTS", 8, Color(1.0, 0.75, 0.35), true))
	for b in ItemDB.blueprints():
		var base: Dictionary = ItemDB.BASES[b]
		if Profile.known_blueprints().has(b):
			var ok := Profile.can_pay(ItemDB.recipe(b))
			var btn := _list_button(base.icon, String(base.name), Color(1.0, 0.7, 0.3) if ok else Color(0.6, 0.45, 0.3), b == selected)
			var bid: String = b
			btn.pressed.connect(func() -> void:
				selected = bid
				_last_result = {}
				rebuild())
			list.add_child(btn)
		else:
			var lb := _list_button("scroll", "??? (%s)" % ItemDB.SLOT_NAMES[base.slot], Color(0.4, 0.38, 0.42), false)
			lb.disabled = true
			lb.tooltip_text = "Find this blueprint in the Undervault to learn it."
			list.add_child(lb)
	if selected == "":
		selected = first


func _craft_detail(dv: VBoxContainer) -> void:
	if not _last_result.is_empty():
		dv.add_child(UIKit.label("FORGED", 8, UIKit.C_GOLD, true))
		dv.add_child(GearUI.item_info(_last_result, _worn_in(String(ItemDB.base(String(_last_result.base)).slot)), 220))
		dv.add_child(UIKit.label("It's in your satchel.", 8, UIKit.C_DIM))
		dv.add_child(UIKit.button("Forge another", func() -> void:
			_last_result = {}
			rebuild(), 90))
		return
	if selected == "":
		return
	var base := ItemDB.base(selected)
	var unique := ItemDB.is_unique(selected)
	var preview := ItemDB.make_item(selected, "common", 1, RandomNumberGenerator.new(), Difficulty.craft_tier())
	dv.add_child(GearUI.item_info(preview, {}, 220))
	if unique:
		dv.add_child(UIKit.label("A unique, forged from its blueprint.", 8, Color(1.0, 0.75, 0.35)))
	else:
		dv.add_child(UIKit.label("Rarity: Common 55%   Rare 33%   Epic 12%", 8, UIKit.C_DIM))
	dv.add_child(UIKit.label("Forged at Tier %s (the highest you have conquered)" % Difficulty.roman(Difficulty.craft_tier()), 8, UIKit.C_DIM))
	dv.add_child(UIKit.label("COST", 8, UIKit.C_GOLD, true))
	var cost := ItemDB.recipe(selected)
	dv.add_child(GearUI.cost_row(cost))
	var forge := UIKit.button("Forge", func() -> void: _craft(false), 70)
	forge.disabled = not Profile.can_pay(cost)
	var row := UIKit.hbox(4)
	row.add_child(forge)
	var cat := _catalyst()
	var mw := UIKit.button("Masterwork (Epic)", func() -> void: _craft(true), 100)
	mw.disabled = cat == "" or not Profile.can_pay(cost) or unique
	mw.visible = not unique
	mw.tooltip_text = "Spend 1 %s for a guaranteed Epic." % (ItemDB.MATERIALS[cat].name if cat != "" else "Warden Sigil or Bloom Heart")
	row.add_child(mw)
	dv.add_child(row)
	if base.slot != "":
		var worn := _worn_in(String(base.slot))
		if not worn.is_empty():
			dv.add_child(UIKit.label("Wearing: %s" % ItemDB.item_name(worn), 8, ItemDB.color(worn)))


func _catalyst() -> String:
	for c in ItemDB.CATALYSTS:
		if Profile.material(c) > 0:
			return c
	return ""


func _craft(masterwork: bool) -> void:
	var cost := ItemDB.recipe(selected).duplicate()
	var cat := _catalyst() if masterwork else ""
	if masterwork:
		if cat == "":
			return
		cost[cat] = 1
	if not Profile.pay(cost):
		Audio.ui("deny")
		return
	var it := Profile.add_item(ItemDB.craft(selected, _rng, masterwork, Profile.building("forge"), Difficulty.craft_tier()))
	_last_result = it
	Audio.play("forge", 0.0)
	Audio.play("relic", -6.0 if it.rarity == "common" else 0.0)
	Game.ui.toast("Forged: %s %s" % [ItemDB.RARITY[it.rarity].name, ItemDB.item_name(it)], ItemDB.color(it))
	if Game.stage is Hub:
		(Game.stage as Hub).workshop_flare(it.rarity != "common")
	rebuild()


# --- temper and salvage ---------------------------------------------------------------

func _all_items(include_worn: bool) -> Array:
	var out: Array = []
	if include_worn:
		for s in ItemDB.SLOTS:
			var e: Variant = Profile.equipped().get(s)
			if e is Dictionary and not (e as Dictionary).is_empty():
				out.append(e)
	out.append_array(Profile.bag())
	return out


func _item_list(list: VBoxContainer, keep: Callable, include_worn: bool) -> void:
	var first := ""
	var worn_uids := {}
	for s in ItemDB.SLOTS:
		var e: Variant = Profile.equipped().get(s)
		if e is Dictionary and not (e as Dictionary).is_empty():
			worn_uids[int(e.uid)] = true
	for it in _all_items(include_worn):
		if not keep.call(it):
			continue
		var u := str(int(it.uid))
		var label := ItemDB.item_name(it) + ("  (worn)" if worn_uids.has(int(it.uid)) else "")
		var btn := _list_button(ItemDB.icon(it), label, ItemDB.color(it), u == selected)
		btn.pressed.connect(func() -> void:
			selected = u
			rebuild())
		list.add_child(btn)
		if first == "":
			first = u
	if first == "":
		list.add_child(UIKit.para("Nothing to work on." if tab == "temper" else "Your satchel holds no gear to break down.", 160, UIKit.C_DIM))
	if selected == "" or Profile.find_item(int(selected)).is_empty():
		selected = first


func _temper_detail(dv: VBoxContainer) -> void:
	if selected == "":
		return
	var it := Profile.find_item(int(selected))
	if it.is_empty():
		return
	var next := it.duplicate(true)
	next.level = int(it.level) + 1
	dv.add_child(GearUI.item_info(next, it, 220))
	dv.add_child(UIKit.label("COST", 8, UIKit.C_GOLD, true))
	var cost := ItemDB.temper_cost(it)
	dv.add_child(GearUI.cost_row(cost))
	var b := UIKit.button("Temper to level %d" % int(next.level), func() -> void:
		if Profile.pay(cost):
			it.level = int(it.level) + 1
			Profile.mark_changed()
			Audio.play("forge", 0.0, 1.1)
			Game.ui.toast("Tempered: %s" % ItemDB.item_name(it), ItemDB.color(it))
			if Game.stage is Hub:
				(Game.stage as Hub).workshop_flare(false)
			rebuild(), 110)
	b.disabled = not Profile.can_pay(cost)
	dv.add_child(b)


func _salvage_detail(dv: VBoxContainer) -> void:
	if selected == "":
		return
	var it := Profile.find_item(int(selected))
	if it.is_empty():
		return
	dv.add_child(GearUI.item_info(it, {}, 220))
	dv.add_child(UIKit.label("BREAKS DOWN INTO", 8, UIKit.C_GOLD, true))
	var y := ItemDB.salvage_yield(it)
	var row := HFlowContainer.new()
	for k in y:
		var h := UIKit.hbox(1)
		h.add_child(UIKit.item_icon_rect(ItemDB.MATERIALS[k].icon))
		h.add_child(UIKit.label("+%d %s" % [int(y[k]), ItemDB.MATERIALS[k].name], 8, UIKit.C_GOOD))
		row.add_child(h)
	dv.add_child(row)
	var uid := int(selected)
	dv.add_child(UIKit.button("Salvage", func() -> void:
		var go := func() -> void:
			Profile.salvage(uid)
			Audio.play("forge", -2.0, 1.25)
			selected = ""
			rebuild()
		if it.rarity in ["epic", "legendary"]:
			Game.ui.confirm("Break down %s?" % ItemDB.item_name(it), "It is %s. This cannot be undone." % ItemDB.RARITY[it.rarity].name.to_lower(), go)
		else:
			go.call(), 70))


# --- helpers -----------------------------------------------------------------------

func _worn_in(slot: String) -> Dictionary:
	var e: Variant = Profile.equipped().get(slot)
	return e if e is Dictionary else {}


func _list_button(icon_name: String, text: String, col: Color, active: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(158, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "     " + text
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.focus_mode = Control.FOCUS_ALL
	if active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.16, 0.08)
		sb.border_color = UIKit.C_GOLD
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
	var ic := UIKit.item_icon_rect(icon_name)
	ic.position = Vector2(3, 1)
	ic.size = Vector2(16, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b
