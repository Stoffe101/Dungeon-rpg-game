## The peddler's stall in the sanctuary: a stock of gear that changes after
## every expedition, bought with Embers; and a buyer for whatever you won't wear.
class_name PeddlerUI
extends Control

const STOCK_SIZE := 6

var tab := "buy"
var tip: GearUI.FloatTip


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	PeddlerUI.restock_if_needed()
	rebuild()


func _exit_tree() -> void:
	Profile.save_profile()


## New wares after each expedition (keyed on the run counter).
static func restock_if_needed() -> void:
	var shop: Dictionary = Profile.data.get("shop", {})
	var runs := int(Profile.data.stats.get("runs", 0))
	if int(shop.get("for_run", -1)) == runs and not (shop.get("stock", []) as Array).is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151 + runs * 97 + int(Profile.data.get("created", "").hash() % 1000)
	var region := "rootmire" if EnemyDB.region_unlocked("rootmire") and rng.randf() < 0.5 else "ossuary"
	var lvl := clampi(1 + int(Profile.data.world.get("memory", 0)), 1, ItemDB.MAX_LEVEL)
	var stock: Array = []
	for i in STOCK_SIZE:
		var it := ItemDB.random_drop(region if i % 2 == 0 else "ossuary", lvl, rng, 0.08)
		it.uid = -(i + 1)
		stock.append(it)
	Profile.data["shop"] = {"stock": stock, "for_run": runs}


static func price(it: Dictionary) -> int:
	return ItemDB.value(it) * 2


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(380, 0)
	center.add_child(p)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.icon_rect("merchant"))
	head.add_child(UIKit.label("THE PEDDLER", 16, UIKit.C_GOLD, true))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	head.add_child(UIKit.icon_rect("ember"))
	head.add_child(UIKit.label(str(Profile.currency("embers")), 8, UIKit.C_EMBER, true))
	for t in [["buy", "Buy"], ["sell", "Sell"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func() -> void:
			tab = key
			rebuild(), 40)
		if tab == key:
			b.add_theme_color_override("font_color", UIKit.C_GOLD)
		head.add_child(b)
	head.add_child(UIKit.button("Close", func() -> void: Game.ui.close_top(), 40))
	v.add_child(head)
	v.add_child(UIKit.label('"Found it, fair and square. Mostly. New wares after every descent."' if tab == "buy" else '"I will take it off your hands. Do not ask what for."', 8, UIKit.C_DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(370, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := UIKit.vbox(2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	tip = GearUI.FloatTip.new()
	if tab == "buy":
		var stock: Array = Profile.data.shop.stock
		if stock.is_empty():
			list.add_child(UIKit.label("Sold out. Come back after your next descent.", 8, UIKit.C_DIM))
		for i in stock.size():
			list.add_child(_row(stock[i], price(stock[i]), "Buy", _buy.bind(i)))
	else:
		if Profile.bag().is_empty():
			list.add_child(UIKit.label("Your satchel holds no gear to sell (worn pieces stay on).", 8, UIKit.C_DIM))
		for it in Profile.bag():
			list.add_child(_row(it, ItemDB.value(it), "Sell", _sell.bind(int(it.uid))))
	add_child(tip)


func _row(it: Dictionary, cost: int, verb: String, action: Callable) -> Control:
	var h := UIKit.hbox(6)
	var slot := GearUI.slot_button(it, 24)
	slot.focus_mode = Control.FOCUS_NONE
	h.add_child(slot)
	var info := UIKit.vbox(0)
	info.custom_minimum_size = Vector2(220, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(ItemDB.item_name(it), 8, ItemDB.color(it), true))
	var mods := ItemDB.mods_of(it)
	var parts: Array = []
	for m in mods.slice(0, 2):
		parts.append(UIKit.describe_mod(m))
	info.add_child(UIKit.label(", ".join(parts) + ("  +%d more" % (mods.size() - 2) if mods.size() > 2 else ""), 8, UIKit.C_DIM))
	h.add_child(info)
	var b := UIKit.button("%s %d" % [verb, cost], action, 64)
	if verb == "Buy":
		b.disabled = Profile.currency("embers") < cost
	h.add_child(b)
	var slot_name := String(ItemDB.base(String(it.base)).slot)
	var worn: Variant = Profile.equipped().get(slot_name)
	var show := func(at: Vector2) -> void: tip.show_content(GearUI.item_info(it, worn if worn is Dictionary else {}), at)
	slot.mouse_entered.connect(func() -> void: show.call(get_global_mouse_position()))
	slot.mouse_exited.connect(func() -> void: tip.visible = false)
	b.focus_entered.connect(func() -> void: show.call(b.global_position + Vector2(b.size.x, 0)))
	b.focus_exited.connect(func() -> void: tip.visible = false)
	return h


func _buy(i: int) -> void:
	var stock: Array = Profile.data.shop.stock
	if i >= stock.size():
		return
	var it: Dictionary = stock[i]
	if not Profile.spend("embers", price(it)):
		Audio.ui("deny")
		return
	stock.remove_at(i)
	Profile.add_item(it)
	Audio.play("buy", 0.0)
	Game.ui.toast("Bought: %s" % ItemDB.item_name(it), ItemDB.color(it))
	rebuild()


func _sell(uid: int) -> void:
	var it := Profile.find_item(uid)
	if it.is_empty():
		return
	var go := func() -> void:
		Profile.remove_item(uid)
		Profile.add_currency("embers", ItemDB.value(it))
		Audio.play("buy", 0.0, 0.85)
		rebuild()
	var used := Profile.loadouts_using(uid)
	if it.rarity in ["epic", "legendary"] or not used.is_empty():
		Game.ui.confirm("Sell %s?" % ItemDB.item_name(it), "For %d Embers.%s" % [ItemDB.value(it), (" It is part of loadout %s." % ", ".join(used)) if not used.is_empty() else ""], go)
	else:
		go.call()
