## The blacksmith's bench: craft gear from materials, temper it to higher
## levels, or break pieces down. Crafting rolls a rarity; a boss catalyst
## (Warden Sigil, Bloom Heart) makes a guaranteed epic masterwork.
##
## Built once, in persistent sections (tabs, filters, the list, the detail
## panel, the materials on hand): picking a piece only restyles two list rows
## and redraws the detail - the list keeps its scroll and its focus (it used
## to be rebuilt from scratch on every click, jumping back to the top). The
## list itself is refreshed only when the save changes (a piece forged,
## tempered or broken down), and then keeps its place.
class_name SmithyUI
extends Control

const TABS := [["craft", "Craft"], ["temper", "Temper"], ["salvage", "Salvage"]]
const RARITY_RANK := {"common": 0, "rare": 1, "epic": 2, "set": 3, "legendary": 4}
const RARITY_STEPS := [["", "Any rarity"], ["rare", "Rare and up"], ["epic", "Epic and up"]]
const SLOT_ICONS := {"head": "helm", "chest": "robe", "hands": "gloves", "feet": "boots", "ring": "band", "charm": "totem", "weapon": "wpn_sword"}

var tab := "craft"
var selected := ""            # craft: base id; temper/salvage: item uid as string
var slot_filter := ""         # "" = every slot
var rarity_floor := ""        # temper/salvage: "" | "rare" | "epic"
var only_ready := false       # only what can be forged / tempered right now
var tip: GearUI.FloatTip
var _last_result: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _tabs := {}               # tab key -> Button
var _chips := {}              # slot ("" = all) -> Button
var _ready_btn: Button
var _rarity_btn: Button
var _flavour_lbl: Label
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _dv: VBoxContainer
var _mats: HFlowContainer
var _rows := {}               # selection key -> Button (the list as drawn)
var _active_sb: StyleBoxFlat
var _dirty := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_active_sb = StyleBoxFlat.new()
	_active_sb.bg_color = Color(0.25, 0.16, 0.08)
	_active_sb.border_color = UIKit.C_GOLD
	_active_sb.set_border_width_all(1)
	_build()
	rebuild()
	Profile.changed.connect(_on_profile_changed)


func _exit_tree() -> void:
	if Profile.changed.is_connected(_on_profile_changed):
		Profile.changed.disconnect(_on_profile_changed)
	Profile.save_profile()


func _on_profile_changed() -> void:
	_dirty = true


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_refresh_list()
		_refresh_mats()
		_refresh_detail()


# --- the frame (built once) ------------------------------------------------------------

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(480, 0)
	center.add_child(p)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.item_icon_rect("anvil"))
	head.add_child(UIKit.label("THE SMITHY", 16, UIKit.C_GOLD, true))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	for t in TABS:
		var key: String = t[0]
		var b := UIKit.button(t[1], func() -> void: set_tab(key), 46)
		_tabs[key] = b
		head.add_child(b)
	head.add_child(UIKit.button("Close", func() -> void: Game.ui.close_top(), 40))
	v.add_child(head)
	_flavour_lbl = UIKit.label("", 8, UIKit.C_DIM)
	v.add_child(_flavour_lbl)
	# filters: a chip per slot, the rarity floor, "ready now"
	var fr := UIKit.hbox(2)
	for s in [""] + ItemDB.SLOTS:
		var slot: String = s
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(22 if slot != "" else 26, 18)
		chip.focus_mode = Control.FOCUS_ALL
		chip.tooltip_text = "Every slot" if slot == "" else String(ItemDB.SLOT_NAMES[slot])
		if slot == "":
			chip.text = "All"
		else:
			var ic := UIKit.item_icon_rect(String(SLOT_ICONS[slot]))
			ic.position = Vector2(3, 1)
			ic.size = Vector2(16, 16)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(ic)
		chip.pressed.connect(func() -> void:
			Audio.ui("ui_click")
			slot_filter = slot
			_refresh_chips()
			_refresh_list(true))
		_chips[slot] = chip
		fr.add_child(chip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(gap)
	_rarity_btn = UIKit.button("Any rarity", func() -> void:
		var i := 0
		for k in RARITY_STEPS.size():
			if RARITY_STEPS[k][0] == rarity_floor:
				i = k
		rarity_floor = RARITY_STEPS[(i + 1) % RARITY_STEPS.size()][0]
		_refresh_chips()
		_refresh_list(true), 64)
	fr.add_child(_rarity_btn)
	_ready_btn = UIKit.button("", func() -> void:
		only_ready = not only_ready
		_refresh_chips()
		_refresh_list(true), 70)
	fr.add_child(_ready_btn)
	v.add_child(fr)
	var row := UIKit.hbox(6)
	v.add_child(row)
	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size = Vector2(186, 230)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_list_scroll)
	_list = UIKit.vbox(1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	var detail := UIKit.panel("DarkPanel")
	detail.custom_minimum_size = Vector2(270, 230)
	row.add_child(detail)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(dscroll)
	_dv = UIKit.vbox(3)
	_dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_dv)
	# what is on hand, always in sight
	var foot := UIKit.hbox(4)
	foot.add_child(UIKit.label("ON HAND", 8, UIKit.C_GOLD, true))
	_mats = HFlowContainer.new()
	_mats.add_theme_constant_override("h_separation", 6)
	_mats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_mats)
	v.add_child(foot)
	tip = GearUI.FloatTip.new()
	add_child(tip)


## Everything again, keeping the list's place (a tab change resets it on purpose).
func rebuild() -> void:
	_flavour_lbl.text = _flavour()
	_refresh_chips()
	_refresh_list()
	_refresh_detail()
	_refresh_mats()


func set_tab(key: String) -> void:
	if key == tab:
		return
	tab = key
	selected = ""
	_last_result = {}
	rebuild()
	_list_scroll.scroll_vertical = 0


func _refresh_chips() -> void:
	for k in _tabs:
		(_tabs[k] as Button).add_theme_color_override("font_color", UIKit.C_GOLD if k == tab else UIKit.C_TEXT)
		if k == tab:
			(_tabs[k] as Button).add_theme_stylebox_override("normal", _active_sb)
		else:
			(_tabs[k] as Button).remove_theme_stylebox_override("normal")
	for s in _chips:
		var c: Button = _chips[s]
		if s == slot_filter:
			c.add_theme_stylebox_override("normal", _active_sb)
		else:
			c.remove_theme_stylebox_override("normal")
	_rarity_btn.visible = tab != "craft"
	for st in RARITY_STEPS:
		if st[0] == rarity_floor:
			_rarity_btn.text = st[1]
	_ready_btn.text = ("Ready: " if only_ready else "Show: ") + ({"craft": "can forge", "temper": "can temper"}.get(tab, "all") if only_ready else "everything")
	_ready_btn.visible = tab != "salvage"
	_ready_btn.add_theme_color_override("font_color", UIKit.C_EMBER if only_ready else UIKit.C_TEXT)


func _flavour() -> String:
	match tab:
		"temper":
			return '"Heat it, fold it, quench it. Every temper makes it a little more yours."'
		"salvage":
			return '"Nothing is wasted at a forge. Bring me what you do not wear."'
	return '"Bring me iron and bone and I will make you something that will not break."'


# --- the list ---------------------------------------------------------------------------

## Redraws the list's rows (after the save changed, or a filter), keeping the
## scroll position and the focused row.
func _refresh_list(filters_changed := false) -> void:
	var keep := _list_scroll.scroll_vertical
	var focus_key := ""
	var fo := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for k in _rows:
		if _rows[k] == fo:
			focus_key = k
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	match tab:
		"craft":
			_craft_list()
		"temper":
			_item_list(func(it: Dictionary) -> bool: return int(it.level) < ItemDB.MAX_LEVEL, true)
		"salvage":
			_item_list(func(_it: Dictionary) -> bool: return true, false)
	if not _rows.has(selected):
		var was := selected
		selected = _first_row()
		if was != selected and not filters_changed:
			_refresh_detail()
		elif filters_changed:
			_refresh_detail()
	if focus_key != "" and _rows.has(focus_key):
		(_rows[focus_key] as Button).grab_focus.call_deferred()
	# the rows are laid out next frame: put the list back where it was then
	_list_scroll.scroll_vertical = keep
	_restore_scroll.call_deferred(0 if filters_changed else keep)


func _restore_scroll(v: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_list_scroll):
		_list_scroll.scroll_vertical = v


func _first_row() -> String:
	for c in _list.get_children():
		for k in _rows:
			if _rows[k] == c and not (c as Button).disabled:
				return k
	return ""


## A piece picked: two rows restyled and the detail redrawn - nothing else moves.
func select(key: String) -> void:
	if key == selected and _last_result.is_empty():
		return
	if _rows.has(selected):
		(_rows[selected] as Button).remove_theme_stylebox_override("normal")
	selected = key
	_last_result = {}
	if _rows.has(key):
		(_rows[key] as Button).add_theme_stylebox_override("normal", _active_sb)
	_refresh_detail()


func _craft_list() -> void:
	var by_slot := {}
	for b in ItemDB.craftable():
		var s := String(ItemDB.BASES[b].slot)
		if slot_filter != "" and s != slot_filter:
			continue
		if not by_slot.has(s):
			by_slot[s] = []
		by_slot[s].append(b)
	for s in ItemDB.SLOTS:
		if not by_slot.has(s):
			continue
		var rows: Array = []
		for b in by_slot[s]:
			var ok := Profile.can_pay(ItemDB.recipe(b))
			if only_ready and not ok:
				continue
			rows.append([b, ok])
		if rows.is_empty():
			continue
		_list.add_child(UIKit.label(String(ItemDB.SLOT_NAMES[s]).to_upper(), 8, UIKit.C_GOLD, true))
		for r in rows:
			var base: Dictionary = ItemDB.BASES[r[0]]
			_add_row(String(r[0]), String(base.icon), String(base.name), UIKit.C_TEXT if r[1] else UIKit.C_DIM, bool(r[1]))
	# uniques from learned blueprints; unknown ones are only hinted at
	var bps: Array = ItemDB.blueprints().filter(func(b): return slot_filter == "" or String(ItemDB.BASES[b].slot) == slot_filter)
	if bps.is_empty():
		return
	_list.add_child(UIKit.label("BLUEPRINTS  -  UNIQUE", 8, Color(1.0, 0.75, 0.35), true))
	for b in bps:
		var base: Dictionary = ItemDB.BASES[b]
		if Profile.known_blueprints().has(b):
			var ok := Profile.can_pay(ItemDB.recipe(b))
			if only_ready and not ok:
				continue
			_add_row(String(b), String(base.icon), String(base.name), Color(1.0, 0.7, 0.3) if ok else Color(0.6, 0.45, 0.3), ok, true)
		elif not only_ready:
			var lb := _list_button("scroll", "??? (%s)" % ItemDB.SLOT_NAMES[base.slot], Color(0.4, 0.38, 0.42))
			lb.disabled = true
			lb.tooltip_text = "Find this blueprint in the Undervault to learn it."
			_list.add_child(lb)


func _all_items(include_worn: bool) -> Array:
	var out: Array = []
	if include_worn:
		for s in ItemDB.SLOTS:
			var e: Variant = Profile.equipped().get(s)
			if e is Dictionary and not (e as Dictionary).is_empty():
				out.append(e)
	out.append_array(Profile.bag())
	return out


func _item_list(keep: Callable, include_worn: bool) -> void:
	var worn_uids := {}
	for s in ItemDB.SLOTS:
		var e: Variant = Profile.equipped().get(s)
		if e is Dictionary and not (e as Dictionary).is_empty():
			worn_uids[int(e.uid)] = true
	var floor_rank := int(RARITY_RANK.get(rarity_floor, 0))
	var items: Array = []
	for it in _all_items(include_worn):
		if not keep.call(it):
			continue
		if slot_filter != "" and String(ItemDB.base(String(it.base)).get("slot", "")) != slot_filter:
			continue
		if int(RARITY_RANK.get(String(it.rarity), 0)) < floor_rank:
			continue
		var ready := tab == "temper" and Profile.can_pay(ItemDB.temper_cost(it))
		if only_ready and tab == "temper" and not ready:
			continue
		items.append([it, ready])
	# what you wear first, then the finest, then the most tempered
	items.sort_custom(func(a, b) -> bool:
		var wa := worn_uids.has(int(a[0].uid))
		var wb := worn_uids.has(int(b[0].uid))
		if wa != wb:
			return wa
		var ra := int(RARITY_RANK.get(String(a[0].rarity), 0))
		var rb := int(RARITY_RANK.get(String(b[0].rarity), 0))
		if ra != rb:
			return ra > rb
		if int(a[0].level) != int(b[0].level):
			return int(a[0].level) > int(b[0].level)
		return int(a[0].uid) < int(b[0].uid))
	for e in items:
		var it: Dictionary = e[0]
		var label := ItemDB.item_name(it) + ("  +%d" % int(it.level) if int(it.level) > 1 else "") + ("  (worn)" if worn_uids.has(int(it.uid)) else "")
		_add_row(str(int(it.uid)), ItemDB.icon(it), label, ItemDB.color(it), bool(e[1]))
	if items.is_empty():
		_list.add_child(UIKit.para("Nothing to work on here." if tab == "temper" else "No gear here to break down.", 170, UIKit.C_DIM))


func _add_row(key: String, icon_name: String, text: String, col: Color, ready: bool, unique := false) -> void:
	var b := _list_button(icon_name, text, col)
	if key == selected:
		b.add_theme_stylebox_override("normal", _active_sb)
	if ready:
		# can be forged / tempered right now: an ember in the corner
		var pip := ColorRect.new()
		pip.color = UIKit.C_EMBER if not unique else Color(1.0, 0.8, 0.4)
		pip.size = Vector2(3, 3)
		pip.position = Vector2(170, 7)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pip)
	b.pressed.connect(func() -> void: select(key))
	# a pad or the keys walking the list inspect as they go
	b.focus_entered.connect(func() -> void:
		if Settings.using_pad or UIKit.focus_ring_shown():
			select(key))
	_rows[key] = b
	_list.add_child(b)


# --- the detail panel ----------------------------------------------------------------------

func _refresh_detail() -> void:
	for c in _dv.get_children():
		_dv.remove_child(c)
		c.queue_free()
	match tab:
		"craft":
			_craft_detail(_dv)
		"temper":
			_temper_detail(_dv)
		"salvage":
			_salvage_detail(_dv)


func _refresh_mats() -> void:
	for c in _mats.get_children():
		_mats.remove_child(c)
		c.queue_free()
	for k in ["embers", "sunshards"]:
		var h := UIKit.hbox(1)
		h.add_child(UIKit.icon_rect("ember" if k == "embers" else "sunshard"))
		h.add_child(UIKit.label(str(Profile.currency(k)), 8, UIKit.C_TEXT))
		h.tooltip_text = "Embers" if k == "embers" else "Sunshards"
		_mats.add_child(h)
	for m in ItemDB.MATERIALS:
		var n := Profile.material(m)
		if n <= 0:
			continue
		var h := UIKit.hbox(1)
		h.add_child(UIKit.item_icon_rect(String(ItemDB.MATERIALS[m].icon)))
		h.add_child(UIKit.label(str(n), 8, UIKit.C_TEXT))
		h.tooltip_text = String(ItemDB.MATERIALS[m].name)
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		_mats.add_child(h)


func _craft_detail(dv: VBoxContainer) -> void:
	if not _last_result.is_empty():
		dv.add_child(UIKit.label("FORGED", 8, UIKit.C_GOLD, true))
		dv.add_child(GearUI.item_info(_last_result, _worn_in(String(ItemDB.base(String(_last_result.base)).slot)), 250))
		dv.add_child(UIKit.label("It's in your satchel.", 8, UIKit.C_DIM))
		dv.add_child(UIKit.button("Forge another", func() -> void:
			_last_result = {}
			_refresh_detail(), 90))
		return
	if selected == "":
		dv.add_child(UIKit.para("Pick a piece on the left to see what it takes.", 250, UIKit.C_DIM))
		return
	var base := ItemDB.base(selected)
	var unique := ItemDB.is_unique(selected)
	var preview := ItemDB.make_item(selected, "common", 1, RandomNumberGenerator.new(), Difficulty.craft_tier())
	# compared with what is worn in that slot
	dv.add_child(GearUI.item_info(preview, _worn_in(String(base.get("slot", ""))), 250))
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
	var it := Profile.add_item(ItemDB.craft(selected, _rng, masterwork, Profile.facility("forge"), Difficulty.craft_tier()))
	_last_result = it
	Audio.play("forge", 0.0)
	Audio.play("relic", -6.0 if it.rarity == "common" else 0.0)
	Game.ui.toast("Forged: %s %s" % [ItemDB.RARITY[it.rarity].name, ItemDB.item_name(it)], ItemDB.color(it))
	if Game.stage is Hub:
		(Game.stage as Hub).workshop_flare(it.rarity != "common")
	_refresh_detail()


func _temper_detail(dv: VBoxContainer) -> void:
	if selected == "":
		dv.add_child(UIKit.para("Pick a piece on the left to temper it.", 250, UIKit.C_DIM))
		return
	var it := Profile.find_item(int(selected))
	if it.is_empty():
		return
	var next := it.duplicate(true)
	next.level = int(it.level) + 1
	dv.add_child(UIKit.label("LEVEL %d  ->  %d" % [int(it.level), int(next.level)], 8, UIKit.C_GOLD, true))
	dv.add_child(GearUI.item_info(next, it, 250))
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
				(Game.stage as Hub).workshop_flare(false), 110)
	b.disabled = not Profile.can_pay(cost)
	dv.add_child(b)


func _salvage_detail(dv: VBoxContainer) -> void:
	if selected == "":
		dv.add_child(UIKit.para("Pick a piece on the left to break it down.", 250, UIKit.C_DIM))
		return
	var it := Profile.find_item(int(selected))
	if it.is_empty():
		return
	dv.add_child(GearUI.item_info(it, {}, 250))
	dv.add_child(UIKit.label("BREAKS DOWN INTO", 8, UIKit.C_GOLD, true))
	var y := ItemDB.salvage_yield(it)
	var row := HFlowContainer.new()
	for k in y:
		var h := UIKit.hbox(1)
		h.add_child(UIKit.item_icon_rect(ItemDB.MATERIALS[k].icon))
		h.add_child(UIKit.label("+%d %s" % [int(y[k]), ItemDB.MATERIALS[k].name], 8, UIKit.C_GOOD))
		row.add_child(h)
	dv.add_child(row)
	var used := Profile.loadouts_using(int(selected))
	if not used.is_empty():
		dv.add_child(UIKit.para("Part of loadout %s." % ", ".join(used), 250, Color(1.0, 0.7, 0.45)))
	var uid := int(selected)
	dv.add_child(UIKit.button("Salvage", func() -> void:
		var go := func() -> void:
			Profile.salvage(uid)
			Audio.play("forge", -2.0, 1.25)
			selected = ""
		if it.rarity in ["epic", "legendary", "set"] or not used.is_empty():
			Game.ui.confirm("Break down %s?" % ItemDB.item_name(it), "It is %s.%s This cannot be undone." % [ItemDB.RARITY[it.rarity].name.to_lower(),
				(" It is part of loadout %s." % ", ".join(used)) if not used.is_empty() else ""], go)
		else:
			go.call(), 70))


# --- helpers -----------------------------------------------------------------------

func _worn_in(slot: String) -> Dictionary:
	var e: Variant = Profile.equipped().get(slot)
	return e if e is Dictionary else {}


func _list_button(icon_name: String, text: String, col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(176, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "     " + text
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.add_theme_color_override("font_focus_color", col.lightened(0.2))
	b.focus_mode = Control.FOCUS_ALL
	var ic := UIKit.item_icon_rect(icon_name)
	ic.position = Vector2(3, 1)
	ic.size = Vector2(16, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b
