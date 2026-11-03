## Shared widgets for gear screens: item slots, item details (with comparison),
## material costs, the character stat sheet, and a floating tooltip.
class_name GearUI
extends RefCounted


## A square button showing an item (or an empty slot's icon, dimmed).
static var _body_tex: AtlasTexture


## A Kindled's portrait from their character sheet (their look, armour and
## wardrobe choices), `size` UI pixels square: the party screen's seats.
static func portrait(sheet: Dictionary, size := 56) -> Control:
	if _body_tex == null:
		var info := SpriteLib.get_sheet("player")
		var a: Dictionary = info.anims.get("idle_down", info.anims.values()[0])
		_body_tex = AtlasTexture.new()
		_body_tex.atlas = info.texture
		_body_tex.region = Rect2(0, float(a.row) * info.frame_size.y, info.frame_size.x, info.frame_size.y)
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := String(sheet.get("look", ""))
	var layers: Array = [_body_tex]
	layers.append_array(GearLooks.portrait_layers(sheet.get("equipped", {}), sheet.get("shown", {})))
	for k in layers.size():
		var t := TextureRect.new()
		t.texture = layers[k]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.size = Vector2(size, size)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if k == 0:
			t.material = Looks.canvas_material(look if look != "" else "kindled")
		box.add_child(t)
	return box


static func slot_button(item: Dictionary, size := 24, empty_icon := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_ALL
	var has_item := not item.is_empty()
	var col := ItemDB.color(item) if has_item else Color(0.3, 0.27, 0.33)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.07) if not has_item else Color(col.r * 0.12, col.g * 0.12, col.b * 0.12 + 0.04)
	sb.border_color = col.darkened(0.2) if has_item else Color(0.22, 0.2, 0.26)
	sb.set_border_width_all(1)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.border_color = col.lightened(0.3) if has_item else Color(0.5, 0.45, 0.4)
	sbh.bg_color = sb.bg_color.lightened(0.08)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("disabled", sb)
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = UIKit.item_icon(ItemDB.icon(item)) if has_item else (UIKit.item_icon(empty_icon) if empty_icon != "" else null)
	tr.modulate = Color(1, 1, 1, 1) if has_item else Color(0.35, 0.33, 0.4, 0.5)
	tr.size = Vector2(16, 16)
	tr.position = Vector2((size - 16) / 2, (size - 16) / 2)
	b.add_child(tr)
	if has_item and int(item.get("level", 1)) > 1:
		var l := UIKit.label("+%d" % (int(item.level) - 1), 8, UIKit.C_GOLD, true)
		l.position = Vector2(size - 11, size - 11)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	return b


## Name, kind, stats, comparison against what is equipped in the same slot.
static func item_info(item: Dictionary, compare: Dictionary = {}, width := 160) -> VBoxContainer:
	var v := UIKit.vbox(2)
	var b := ItemDB.base(String(item.base))
	var col := ItemDB.color(item)
	var head := UIKit.hbox(4)
	head.add_child(UIKit.item_icon_rect(ItemDB.icon(item)))
	head.add_child(UIKit.label(ItemDB.item_name(item), 8, col, true))
	v.add_child(head)
	var kind := "Unique" if b.get("unique", false) else String(ItemDB.RARITY[item.rarity].name)
	v.add_child(UIKit.label("%s %s   Level %d/%d   Tier %s" % [kind, ItemDB.SLOT_NAMES[b.slot], int(item.level), ItemDB.MAX_LEVEL, Difficulty.roman(int(item.get("tier", 1)))], 8, UIKit.C_DIM))
	var mods := ItemDB.mods_of(item)
	var nb := (b.mods as Array).size()
	var might := ItemDB.tier_might(item)
	for i in mods.size():
		if might > 0.0 and i == mods.size() - 1:
			var tt := int(item.get("tier", 1))
			v.add_child(UIKit.label("  Tier %s might: +%d%% damage" % [Difficulty.roman(tt), int(round(might * 100.0))], 8, Difficulty.tier_color(tt)))
			continue
		var txt := UIKit.describe_mod(mods[i])
		v.add_child(UIKit.para(("  " if i < nb else "+ ") + txt, width, UIKit.C_TEXT if i < nb else Color(0.6, 0.85, 1.0)))
	if b.has("desc"):
		v.add_child(UIKit.para(String(b.desc), width, Color(1.0, 0.8, 0.5)))
	if b.has("set"):
		v.add_child(set_info(String(b.set), width))
	if not compare.is_empty() and int(compare.get("uid", -1)) != int(item.get("uid", -2)):
		var delta := _delta(mods, ItemDB.mods_of(compare))
		if not delta.is_empty():
			v.add_child(UIKit.label("Compared to %s:" % ItemDB.item_name(compare), 8, UIKit.C_DIM))
			for d in delta:
				v.add_child(UIKit.label("  " + UIKit.describe_mod(d), 8, UIKit.C_GOOD if _better(d) else UIKit.C_BAD))
	return v


## A tier set's name, how many pieces are worn, and its bonuses (lit when active).
static func set_info(set_id: String, width := 160) -> VBoxContainer:
	var s: Dictionary = ItemDB.SETS[set_id]
	var worn := int(ItemDB.set_counts(Profile.equipped()).get(set_id, 0))
	var v := UIKit.vbox(1)
	v.add_child(UIKit.label("%s set  (%d/5 worn)" % [s.name, worn], 8, s.color, true))
	for n in [2, 4]:
		var on: bool = worn >= int(n)
		v.add_child(UIKit.para("(%d) %s" % [n, s[n].desc], width, s.color if on else UIKit.C_DIM))
	return v


## Per stat, what `a` gives over `b` ([[stat, op, delta]], zero deltas dropped).
static func _delta(a: Array, b: Array) -> Array:
	var sums := {}
	var order: Array = []
	for m in a:
		var k := "%s|%s" % [m[0], m[1]]
		if not sums.has(k):
			order.append(k)
		sums[k] = float(sums.get(k, 0.0)) + float(m[2])
	for m in b:
		var k := "%s|%s" % [m[0], m[1]]
		if not sums.has(k):
			order.append(k)
		sums[k] = float(sums.get(k, 0.0)) - float(m[2])
	var out: Array = []
	for k in order:
		if absf(float(sums[k])) > 0.0005:
			var p := String(k).split("|")
			out.append([p[0], p[1], float(sums[k])])
	return out


static func _better(d: Array) -> bool:
	# lower is better for recharge-style stats
	if d[0] in ["dodge_recharge", "cooldown", "ability_cost", "damage_taken"]:
		return float(d[2]) < 0.0
	return float(d[2]) > 0.0


## Material / ember costs as icons with have/need counts.
static func cost_row(cost: Dictionary) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	for k in cost:
		var have := Profile.material(k) if ItemDB.MATERIALS.has(k) else Profile.currency(k)
		var need := int(cost[k])
		var h := UIKit.hbox(1)
		if ItemDB.MATERIALS.has(k):
			h.add_child(UIKit.item_icon_rect(ItemDB.MATERIALS[k].icon))
			h.tooltip_text = String(ItemDB.MATERIALS[k].name)
		else:
			h.add_child(UIKit.icon_rect("ember" if k == "embers" else "sunshard"))
		h.add_child(UIKit.label("%d/%d" % [have, need], 8, UIKit.C_GOOD if have >= need else UIKit.C_BAD))
		row.add_child(h)
	return row


## The Kindled's numbers right now: tree, sanctuary, gear and (during a run) relics.
static func stat_lines() -> Array:
	var st := Stats.for_player()
	SkillDB.apply(Profile.skills(), st)
	Profile.apply_sanctuary(st)
	Profile.apply_gear(st)
	if Game.run and Game.stage is Dungeon:
		RelicDB.apply(Game.run.relics, st)
	var pct := func(v: float) -> String: return "%+d%%" % int(round(v * 100.0))
	return [
		["Max health", str(int(round(st.v("max_hp"))))],
		["Armor", "%d%%" % int(round(st.v("armor") * 100.0))],
		["All damage", pct.call(st.v("damage"))],
		["Melee damage", pct.call(st.v("melee_damage"))],
		["Fire damage", pct.call(st.v("fire_damage"))],
		["Frost damage", pct.call(st.v("frost_damage"))],
		["Ability damage", pct.call(st.v("ability_damage"))],
		["Crit chance", "%d%%" % int(round(st.v("crit_chance") * 100.0))],
		["Crit damage", "%d%%" % int(round(st.v("crit_mult") * 100.0))],
		["Attack speed", "%d%%" % int(round(st.v("attack_speed") * 100.0))],
		["Move speed", "%.1f" % st.v("move_speed")],
		["Dodges", "%d  (%.1fs)" % [int(st.v("dodge_charges")), st.v("dodge_recharge")]],
		["Ward window", "%.2fs" % st.v("parry_window")],
		["Max Kindle", str(int(st.v("kindle_max")))],
		["Kindle gain", "%d%%" % int(round(st.v("kindle_gain") * 100.0))],
		["Flasks", "%d  (heal %d%%)" % [int(st.v("flask_charges")), int(round(st.v("flask_heal") * 100.0))]],
		["Burn chance", "%d%%" % int(round(st.v("burn_chance") * 100.0))],
		["Embers found", "%d%%" % int(round(st.v("ember_gain") * 100.0))],
		["Memories", "%d%%" % int(round(st.v("xp_gain") * 100.0))],
	]


static func stats_panel(width := 140, variation := "DarkPanel") -> PanelContainer:
	var p := UIKit.panel(variation)
	var v := UIKit.vbox(1)
	p.add_child(v)
	v.add_child(UIKit.label("CHARACTER", 8, UIKit.C_GOLD, true))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 0)
	for line in stat_lines():
		var l := UIKit.label(line[0], 8, UIKit.C_DIM)
		l.custom_minimum_size = Vector2(width * 0.55, 0)
		g.add_child(l)
		g.add_child(UIKit.label(line[1], 8, UIKit.C_TEXT))
	v.add_child(g)
	return p


## A tooltip that follows the mouse or a focused control.
class FloatTip:
	extends PanelContainer
	var box: VBoxContainer

	func _init() -> void:
		add_theme_stylebox_override("panel", UIKit.theme().get_stylebox("panel", "TooltipPanel"))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		z_index = 10

	func show_content(content: Control, at: Vector2) -> void:
		for c in get_children():
			c.queue_free()
		add_child(content)
		visible = true
		reset_size()
		place.call_deferred(at)

	func place(at: Vector2) -> void:
		var vp := get_viewport_rect().size
		var p := at + Vector2(12, 8)
		if p.x + size.x > vp.x - 4:
			p.x = at.x - size.x - 12
		if p.y + size.y > vp.y - 4:
			p.y = vp.y - size.y - 4
		global_position = p.round()
