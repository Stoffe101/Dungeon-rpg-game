## Builders for modal screens. Each returns a Control ready for UIRoot.open().
class_name Screens
extends RefCounted


static func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(c)
	return cc


static func _title(text: String, col := UIKit.C_GOLD) -> Label:
	var l := UIKit.label(text.to_upper(), 16, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- main menu -------------------------------------------------------------------

static func main_menu(ui: UIRoot) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 260
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := UIKit.vbox(6)
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(40, -60)
	root.add_child(box)
	var title := UIKit.label("KINDLED DEEP", 32, UIKit.C_GOLD, true)
	box.add_child(title)
	box.add_child(UIKit.label("Carry the last fire into the dark.", 8, UIKit.C_TEXT, true))
	box.add_child(UIKit.spacer(14))
	var buttons := UIKit.vbox(5)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(buttons)
	var has_progress := int(Profile.data.stats.get("runs", 0)) > 0 or Profile.level() > 1
	var start := UIKit.button("Continue" if has_progress else "Begin", func() -> void:
		ui.leave_main_menu()
		ui.fade(Game.goto_hub), 110)
	buttons.add_child(start)
	if has_progress:
		buttons.add_child(UIKit.button("New Game", func() -> void:
			ui.confirm("Start over?", "Your current progress will be erased. A backup of the old save is kept.", func() -> void:
				Profile.reset_profile()
				ui.leave_main_menu()
				ui.fade(Game.goto_hub)), 110))
	buttons.add_child(UIKit.button("Co-op Party", func() -> void: ui.open(Screens.coop(ui)), 110))
	buttons.add_child(UIKit.button("Settings", func() -> void: ui.settings(), 110))
	buttons.add_child(UIKit.button("Quit", func() -> void: ui.get_tree().quit(), 110))
	var runs := int(Profile.data.stats.get("runs", 0))
	var ver := UIKit.label("v%s  -  Level %d  -  %d expedition%s" % [ProjectSettings.get_setting("application/config/version"), Profile.level(), runs, "" if runs == 1 else "s"], 8, UIKit.C_DIM, true)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(8, -14)
	ver.offset_top = -14
	root.add_child(ver)
	start.call_deferred("grab_focus")
	return root


# --- Ember Runes ---------------------------------------------------------------------

## Set runes in your spells' sockets, and carve new ones. Each rune shows what
## it would do in the spell you are looking at.
static func runes(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(_title("Ember Runes"))
	var n_sockets := Runes.sockets(Profile.level())
	var intro := "Set a rune in a spell to change how it behaves."
	if n_sockets < 2:
		intro += " A second socket opens at level %d." % Runes.SECOND_SOCKET_LEVEL
	v.add_child(UIKit.para(intro, 260, UIKit.C_DIM))
	var body := UIKit.vbox(3)
	v.add_child(body)
	var picker := UIKit.vbox(2)
	var state := {"ability": "", "socket": -1}
	var rebuild := func(again: Callable) -> void:
		for c in body.get_children():
			c.queue_free()
		for c in picker.get_children():
			c.queue_free()
		for ab in SkillDB.abilities(Profile.skills()):
			var d := GearDB.ability(String(ab))
			var row := UIKit.hbox(4)
			row.add_child(UIKit.icon_rect(String(d.get("icon", "flare"))))
			var nm := UIKit.label(String(d.name), 8, UIKit.C_TEXT)
			nm.custom_minimum_size = Vector2(70, 0)
			row.add_child(nm)
			var set: Array = Profile.runes().socketed.get(ab, [])
			for s in n_sockets:
				var rid := String(set[s]) if s < set.size() else ""
				var b := Button.new()
				b.custom_minimum_size = Vector2(80, 18)
				b.text = String(Runes.get_def(rid).get("name", "")) .trim_prefix("Rune of ") if rid != "" else "- empty -"
				if rid != "":
					b.icon = UIKit.item_icon(String(Runes.get_def(rid).icon))
					b.add_theme_color_override("font_color", Runes.get_def(rid).color)
				var abid: String = ab
				var sock: int = s
				b.pressed.connect(func() -> void:
					state.ability = abid
					state.socket = sock
					Audio.ui("ui_click")
					again.call(again))
				if state.ability == ab and state.socket == s:
					b.modulate = Color(1.2, 1.1, 0.8)
				row.add_child(b)
			body.add_child(row)
		# the picker for the chosen socket
		if state.ability != "":
			var abn: String = state.ability
			picker.add_child(UIKit.label("FOR %s, SOCKET %d" % [String(GearDB.ability(abn).name).to_upper(), int(state.socket) + 1], 8, UIKit.C_GOLD, true))
			for rid in Runes.RUNES:
				var have := Profile.runes_free(rid)
				var cur: Array = Profile.runes().socketed.get(abn, [])
				var here: bool = int(state.socket) < cur.size() and String(cur[state.socket]) == rid
				if have <= 0 and not here:
					continue
				var r: Dictionary = Runes.RUNES[rid]
				var line := UIKit.hbox(3)
				var pick := UIKit.button(String(r.name).trim_prefix("Rune of ") + ("  (x%d)" % have if not here else "  (set)"), func() -> void:
					if Profile.set_rune(abn, int(state.socket), rid):
						Audio.play("clank", -6.0, 1.4)
						if Game.stage and Game.stage.player:
							Game.stage.player.rebuild_stats()
					again.call(again), 96)
				pick.icon = UIKit.item_icon(String(r.icon))
				line.add_child(pick)
				line.add_child(UIKit.para(Runes.describe(rid, abn), 170, r.color))
				picker.add_child(line)
			picker.add_child(UIKit.button("Clear socket", func() -> void:
				Profile.set_rune(abn, int(state.socket), "")
				again.call(again), 90))
		# carving: a sure way to the rune you want
		var owned := UIKit.hbox(3)
		owned.add_child(UIKit.label("CARVE (%s)" % _cost_text(Runes.CARVE), 8, UIKit.C_GOLD, true))
		picker.add_child(owned)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 3)
		for rid in Runes.RUNES:
			var r: Dictionary = Runes.RUNES[rid]
			var cb := Button.new()
			cb.custom_minimum_size = Vector2(50, 18)
			cb.icon = UIKit.item_icon(String(r.icon))
			cb.text = "%d" % int(Profile.runes().owned.get(rid, 0))
			cb.tooltip_text = "%s - %s" % [r.name, r.desc]
			cb.disabled = not Profile.can_pay(Runes.CARVE)
			var id: String = rid
			cb.pressed.connect(func() -> void:
				if Profile.pay(Runes.CARVE):
					Profile.add_rune(id)
					Audio.play("forge", -4.0, 1.2)
				again.call(again))
			grid.add_child(cb)
		picker.add_child(grid)
	v.add_child(picker)
	rebuild.call(rebuild)
	v.add_child(UIKit.button("Close", func() -> void: ui.close_top(), 70))
	return _center(p)


static func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		var nm := "Embers" if k == "embers" else (String(ItemDB.MATERIALS[k].name) if ItemDB.MATERIALS.has(k) else String(k))
		parts.append("%d %s" % [int(cost[k]), nm])
	return ", ".join(PackedStringArray(parts))


# --- co-op party -------------------------------------------------------------------

## Host or join a party of up to four. The host leads the descent from the
## Undervault Gate; everyone keeps their own Kindled, gear and progress.
static func coop(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(_title("Co-op Party"))
	v.add_child(UIKit.para("Up to four Kindled share one expedition. Each keeps their own gear, Hearthtree and rewards; Embers and materials found are shared, gear drops for each of you. The host leads the descent from the Undervault Gate.", 250, UIKit.C_DIM))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.label("Name", 8, UIKit.C_TEXT))
	var name_in := LineEdit.new()
	name_in.text = String(Settings.get_value("player_name", "Kindled"))
	name_in.max_length = 16
	name_in.custom_minimum_size = Vector2(110, 14)
	name_in.text_changed.connect(func(t: String) -> void: Settings.set_value("player_name", t.strip_edges() if t.strip_edges() != "" else "Kindled"))
	row.add_child(name_in)
	v.add_child(row)
	var row2 := UIKit.hbox(4)
	row2.add_child(UIKit.label("Address", 8, UIKit.C_TEXT))
	var addr := LineEdit.new()
	addr.text = String(Settings.get_value("coop_address", "127.0.0.1"))
	addr.custom_minimum_size = Vector2(110, 14)
	addr.text_changed.connect(func(t: String) -> void: Settings.set_value("coop_address", t.strip_edges()))
	row2.add_child(addr)
	v.add_child(row2)
	var status := UIKit.para(Net.i.status if Net.i.status != "" else "Not in a party.", 250, UIKit.C_SOUL)
	v.add_child(status)
	var party := UIKit.vbox(2)
	v.add_child(party)
	var buttons := UIKit.hbox(5)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	var refresh := func() -> void:
		status.text = Net.i.status if Net.i.status != "" else "Not in a party."
		for c in party.get_children():
			c.queue_free()
		if Net.active():
			var seats: Array = Net.i.roster.keys()
			seats.sort_custom(func(a, b): return int(Net.i.roster[a].slot) < int(Net.i.roster[b].slot))
			for pid in seats:
				var r: Dictionary = Net.i.roster[pid]
				var sh: Dictionary = r.get("sheet", {})
				var w := GearDB.weapon(String(sh.get("weapon", "sword")))
				var line := "%s%s   Lv %d   %s" % [String(r.name), "  (host)" if int(pid) == 1 else "", int(sh.get("level", 1)), String(w.get("name", "?"))]
				party.add_child(UIKit.label(line, 8, Net.color_of(int(pid)), true))
		for c in buttons.get_children():
			c.queue_free()
		if not Net.active():
			buttons.add_child(UIKit.button("Host", func() -> void: Net.i.host(), 60))
			buttons.add_child(UIKit.button("Join", func() -> void: Net.i.join(addr.text.strip_edges()), 60))
		else:
			buttons.add_child(UIKit.button("Leave party", func() -> void:
				Net.i.leave()
				Net.i._status("Left the party."), 80))
		buttons.add_child(UIKit.button("Close", func() -> void: ui.close_top(), 60))
	Net.i.roster_changed.connect(refresh)
	Net.i.status_changed.connect(func(_t): refresh.call())
	p.tree_exiting.connect(func() -> void:
		if Net.i.roster_changed.is_connected(refresh):
			Net.i.roster_changed.disconnect(refresh))
	refresh.call()
	v.add_child(UIKit.para("Internet play: the host forwards UDP port %d on their router, or everyone joins the same LAN-style VPN (e.g. ZeroTier, Tailscale). LAN play needs nothing extra." % Net.PORT, 250, UIKit.C_DIM))
	return _center(p)


# --- relic choice ------------------------------------------------------------------

static func relic_choice(ui: UIRoot, ids: Array, on_pick: Callable) -> Control:
	var v := UIKit.vbox(8)
	v.add_child(_title("Choose a Relic"))
	var row := UIKit.hbox(8)
	v.add_child(row)
	var i := 0
	for id in ids:
		i += 1
		var r := RelicDB.relic(id)
		var card := UIKit.panel("CardPanel")
		card.custom_minimum_size = Vector2(118, 136)
		var cv := UIKit.vbox(3)
		card.add_child(cv)
		var cursed: bool = r.get("cursed", false)
		var rc: Color = RelicDB.RARITY_COLOR["cursed" if cursed else r.rarity]
		var ic := UIKit.icon_rect(r.icon, 2)
		cv.add_child(ic)
		var nm := UIKit.label(r.name, 8, rc, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nm)
		var rar := UIKit.label(("Cursed " if cursed else "") + String(r.rarity).capitalize(), 8, rc.darkened(0.25))
		rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(rar)
		cv.add_child(HSeparator.new())
		cv.add_child(UIKit.para(r.desc, 104))
		var tags: Array = r.get("tags", [])
		if not tags.is_empty():
			var tl := UIKit.label(", ".join(tags.map(func(t): return String(SkillDB.BRANCHES.get(t, {}).get("name", t)))), 8, UIKit.C_DIM)
			cv.add_child(tl)
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(fill)
		var key := i
		var pick := UIKit.button("Take" if Settings.using_pad else "[%d] Take" % key, func() -> void:
			ui.close_top()
			on_pick.call(id), 90)
		cv.add_child(pick)
		row.add_child(card)
		if i == 1:
			pick.call_deferred("grab_focus")
	var skip := UIKit.button("Leave them", func() -> void:
		ui.close_top()
		on_pick.call(""), 80)
	var sk := CenterContainer.new()
	sk.add_child(skip)
	v.add_child(sk)
	var wrap := _center(v)
	wrap.set_meta("keys", ids)
	wrap.gui_input.connect(func(_e): pass)
	var keyh := _KeyPicker.new()
	keyh.ids = ids
	keyh.on_pick = func(id: String) -> void:
		ui.close_top()
		on_pick.call(id)
	wrap.add_child(keyh)
	return wrap


class _KeyPicker:
	extends Node
	var ids: Array = []
	var on_pick: Callable
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _unhandled_key_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo:
			var k := (e as InputEventKey).keycode
			var idx := -1
			if k >= KEY_1 and k <= KEY_3:
				idx = k - KEY_1
			if idx >= 0 and idx < ids.size():
				get_viewport().set_input_as_handled()
				on_pick.call(ids[idx])


# --- merchant -------------------------------------------------------------------------

## The Cinder Merchant, for this machine's Kindled on the host (or alone).
static func shop(ui: UIRoot, prop: Prop) -> Control:
	var d := Game.stage as Dungeon
	var ctx := {"stock": Party.shop_stock(d, d.player, prop)}
	ctx.buy = func(i: int) -> void:
		if Party.buy(d, d.player, prop, i):
			Audio.play("buy", 0.0)
		else:
			Audio.ui("deny")
		ctx.rebuild.call()
	return _shop_panel(ui, ctx)


## The Cinder Merchant on a guest's screen: the host keeps the stock and the
## purse, and answers each purchase with the stock as it now stands.
static func shop_view(ui: UIRoot, idx: int, stock: Array) -> Control:
	var ctx := {"stock": stock, "idx": idx}
	ctx.buy = func(i: int) -> void:
		var item: Dictionary = ctx.stock[i]
		if item.get("sold", false) or Game.run == null or Game.run.embers < int(item.price):
			Audio.ui("deny")
			return
		Audio.play("buy", 0.0)
		item["pending"] = true
		Net.ask("buy", [idx, i])
		ctx.rebuild.call()
	var node := _shop_panel(ui, ctx)
	ctx.node = node
	Party._shop_view = ctx
	return node


static func _shop_panel(ui: UIRoot, ctx: Dictionary) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title("The Cinder Merchant"))
	v.add_child(UIKit.para("\"Embers you spend here won't reach your Hearth. Choose well, wanderer.\"", 260, UIKit.C_DIM))
	var have := UIKit.label("", 8, UIKit.C_EMBER, true)
	v.add_child(have)
	var list := UIKit.vbox(3)
	v.add_child(list)
	# lambdas capture by value, so self-reference goes through a shared dict
	ctx.rebuild = func() -> void:
		if not is_instance_valid(list):
			return
		var embers: int = Game.run.embers if Game.run else 0
		have.text = "Carried Embers: %d" % embers
		for c in list.get_children():
			c.queue_free()
		for i in (ctx.stock as Array).size():
			var item: Dictionary = ctx.stock[i]
			var row := UIKit.hbox(6)
			var name := ""
			var desc := ""
			var icon := "relic"
			match item.kind:
				"relic":
					var r := RelicDB.relic(item.id)
					name = r.name
					desc = r.desc
					icon = r.icon
				"flask":
					name = "Hearth Draught"
					desc = "Refill one flask charge."
					icon = "flask"
				"heal":
					name = "Warm Broth"
					desc = "Restore 40% health."
					icon = "heart"
			row.add_child(UIKit.icon_rect(icon, 1))
			var tv := UIKit.vbox(0)
			tv.add_child(UIKit.label(name + ("  (sold)" if item.get("sold", false) else ""), 8, UIKit.C_GOLD if not item.get("sold", false) else UIKit.C_DIM))
			tv.add_child(UIKit.para(desc, 170, UIKit.C_TEXT))
			row.add_child(tv)
			var fill := Control.new()
			fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(fill)
			var b := UIKit.button("%d Embers" % item.price, func() -> void: ctx.buy.call(i), 70)
			b.disabled = item.get("sold", false) or item.get("pending", false) or embers < int(item.price)
			row.add_child(b)
			list.add_child(row)
	ctx.rebuild.call()
	v.add_child(UIKit.button("Leave", func() -> void: ui.close_top(), 70))
	return _center(p)


# --- shrine -----------------------------------------------------------------------------

## The shrine of pacts for this machine's Kindled on the host (or alone).
static func shrine(ui: UIRoot, prop: Prop) -> Control:
	var d := Game.stage as Dungeon
	var pl := d.player
	return _shrine_panel(ui, Party.spent(prop, pl), Party.shrine_curse(d, pl, prop), func(choice: String) -> void:
		Party.shrine_choice(d, pl, prop, choice))


## The shrine on a guest's screen: the host makes the bargain.
static func shrine_view(ui: UIRoot, idx: int, curse_id: String, spent: bool) -> Control:
	return _shrine_panel(ui, spent, curse_id, func(choice: String) -> void:
		Audio.play("pact", 0.0, 1.0 if choice == "blood" else 0.8)
		Net.ask("shrine", [idx, choice]))


static func _shrine_panel(ui: UIRoot, spent: bool, curse_id: String, choose: Callable) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title("Shrine of Pacts", Color(0.8, 0.6, 1.0)))
	if spent:
		v.add_child(UIKit.para("The idol's eyes are dark to you. Your bargain is spent.", 240, UIKit.C_DIM))
		v.add_child(UIKit.button("Leave", func() -> void: ui.close_top(), 70))
		return _center(p)
	v.add_child(UIKit.para("A hollow voice: \"Power is never free. What will you give?\"", 260, UIKit.C_DIM))
	var blood := UIKit.button("Blood Pact: lose 25% of your health, choose a rare relic", func() -> void:
		ui.close_top()
		choose.call("blood"), 250)
	v.add_child(blood)
	if curse_id != "":
		var c := RelicDB.relic(curse_id)
		var txt := "Embrace the Curse: %s (%s) +40 Embers" % [c.name, c.desc]
		var curse := UIKit.button(txt, func() -> void:
			ui.close_top()
			choose.call("curse"), 250)
		curse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		curse.custom_minimum_size = Vector2(250, 26)
		v.add_child(curse)
	v.add_child(UIKit.button("Refuse", func() -> void: ui.close_top(), 70))
	return _center(p)


## A party vote: shown to everyone, answered by each on their own screen. The
## world keeps going meanwhile (the screen does not pause it).
static func vote(ui: UIRoot, title: String, body: String, answer: Callable) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title(title))
	v.add_child(UIKit.para(body, 220))
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ok := UIKit.button("Agree", func() -> void:
		ui.close_top()
		answer.call(true), 70)
	row.add_child(ok)
	row.add_child(UIKit.button("Not yet", func() -> void:
		ui.close_top()
		answer.call(false), 70))
	v.add_child(row)
	ok.call_deferred("grab_focus")
	return _center(p)


# --- small dialogs --------------------------------------------------------------------

static func confirm(ui: UIRoot, title: String, body: String, yes: Callable) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title(title))
	v.add_child(UIKit.para(body, 220))
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ok := UIKit.button("Yes", func() -> void:
		ui.close_top()
		yes.call(), 60)
	row.add_child(ok)
	row.add_child(UIKit.button("No", func() -> void: ui.close_top(), 60))
	v.add_child(row)
	ok.call_deferred("grab_focus")
	return _center(p)


static func lore(ui: UIRoot, entry: Array) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title(entry[0], UIKit.C_SOUL))
	v.add_child(UIKit.para(entry[1], 220))
	var b := UIKit.button("Close", func() -> void: ui.close_top(), 60)
	v.add_child(b)
	b.call_deferred("grab_focus")
	return _center(p)


static func dialogue(ui: UIRoot, speaker: String, lines: Array, on_done: Callable = Callable()) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p := UIKit.panel()
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.custom_minimum_size = Vector2(320, 56)
	p.position = Vector2(-160, -90)
	root.add_child(p)
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label(speaker, 8, UIKit.C_GOLD, true))
	var body := UIKit.para("", 300)
	v.add_child(body)
	var hint := UIKit.label("[A] continue" if Settings.using_pad else "[click / %s] continue" % Settings.describe_action("interact", false), 8, UIKit.C_DIM)
	v.add_child(hint)
	var state := {"i": 0, "chars": 0.0}
	var show := func() -> void:
		body.text = lines[state.i]
		body.visible_characters = 0
		state.chars = 0.0
	show.call()
	var typer := _Typer.new()
	typer.body = body
	typer.state = state
	typer.advance = func() -> void:
		if body.visible_characters >= 0 and body.visible_characters < body.text.length():
			body.visible_characters = -1
			return
		state.i += 1
		if state.i >= lines.size():
			ui.close_top()
			if on_done.is_valid():
				on_done.call()
		else:
			show.call()
			Audio.ui("ui_click")
	root.add_child(typer)
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			typer.advance.call())
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


class _Typer:
	extends Node
	var body: Label
	var state: Dictionary
	var advance: Callable
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		if body.visible_characters >= 0:
			state.chars += delta * 55.0
			body.visible_characters = mini(int(state.chars), body.text.length())
			if body.visible_characters >= body.text.length():
				body.visible_characters = -1
	func _unhandled_input(e: InputEvent) -> void:
		if e.is_action_pressed("interact") or e.is_action_pressed("dodge") or e.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			advance.call()


# --- pause / settings -----------------------------------------------------------------------

static func pause(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var row := UIKit.hbox(12)
	p.add_child(row)
	var v := UIKit.vbox(5)
	row.add_child(v)
	# residents' requests: what they asked for and how far along it is
	var journal := Residents.journal()
	if not journal.is_empty():
		var jv := UIKit.vbox(3)
		jv.add_child(UIKit.label("REQUESTS", 8, UIKit.C_GOLD, true))
		for line in journal:
			var col: Color = {"active": UIKit.C_TEXT, "complete": UIKit.C_GOLD, "rewarded": UIKit.C_DIM}[line[1]]
			jv.add_child(UIKit.para(String(line[0]), 170, col))
		row.add_child(jv)
	v.add_child(_title("Paused"))
	var resume := UIKit.button("Resume", func() -> void: ui.close_top(), 140)
	v.add_child(resume)
	v.add_child(UIKit.button("Satchel", func() -> void: ui.inventory(), 140))
	v.add_child(UIKit.button("Feats  %d / %d" % [Feats.earned_count(), Feats.FEATS.size()], func() -> void: ui.open(feats(ui)), 140))
	v.add_child(UIKit.button("Bestiary", func() -> void: ui.open(bestiary(ui)), 140))
	v.add_child(UIKit.button("Settings", func() -> void: ui.settings(), 140))
	if Game.stage is Dungeon:
		v.add_child(UIKit.button("Abandon Expedition", func() -> void:
			ui.confirm("Abandon the expedition?", "You fall where you stand: half your carried Embers are lost.", func() -> void:
				ui.close_all()
				Game.end_run("died")), 140))
	else:
		v.add_child(UIKit.button("Main Menu", func() -> void:
			Profile.save_profile()
			ui.close_all()
			Game.goto_menu(), 140))
	v.add_child(UIKit.button("Quit to Desktop", func() -> void:
		Profile.save_profile()
		ui.get_tree().quit(), 140))
	resume.call_deferred("grab_focus")
	return _center(p)


static func _slider(label: String, key: String, lo: float, hi: float, step: float) -> HBoxContainer:
	var row := UIKit.hbox(6)
	var l := UIKit.label(label, 8)
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key, lo))
	s.custom_minimum_size = Vector2(110, 10)
	var val := UIKit.label("%d%%" % int(s.value * 100.0), 8, UIKit.C_DIM)
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%d%%" % int(x * 100.0)
		Settings.set_value(key, x))
	row.add_child(s)
	row.add_child(val)
	return row


static func _toggle(label: String, key: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = bool(Settings.get_value(key, false))
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	return c


static func _choice(label: String, key: String, options: Array, names: Array) -> HBoxContainer:
	var row := UIKit.hbox(6)
	var l := UIKit.label(label, 8)
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	for i in options.size():
		ob.add_item(names[i], i)
		if options[i] == Settings.get_value(key):
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void: Settings.set_value(key, options[i]))
	row.add_child(ob)
	return row


static func settings(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(300, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(_title("Settings"))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(290, 190)
	v.add_child(tabs)
	var audio := UIKit.vbox(4)
	audio.name = "Audio"
	audio.add_child(_slider("Master", "master_volume", 0.0, 1.0, 0.05))
	audio.add_child(_slider("Music", "music_volume", 0.0, 1.0, 0.05))
	audio.add_child(_slider("Effects", "sfx_volume", 0.0, 1.0, 0.05))
	audio.add_child(_slider("Ambience", "ambience_volume", 0.0, 1.0, 0.05))
	tabs.add_child(audio)
	var disp := UIKit.vbox(4)
	disp.name = "Display"
	disp.add_child(_choice("Window", "window_mode", ["windowed", "borderless", "fullscreen"], ["Windowed", "Borderless", "Fullscreen"]))
	disp.add_child(_choice("UI scale", "ui_scale", [0, 1, 2, 3, 4, 5, 6], ["Auto", "1x", "2x", "3x", "4x", "5x", "6x"]))
	disp.add_child(_choice("Pixel size", "pixel_scale", [0, 2, 3, 4, 5, 6, 8], ["Auto", "2x", "3x", "4x", "5x", "6x", "8x"]))
	disp.add_child(_choice("Frame cap", "max_fps", [0, 60, 120, 144, 240], ["Unlimited", "60", "120", "144", "240"]))
	disp.add_child(_toggle("V-Sync", "vsync"))
	disp.add_child(_toggle("Show FPS", "show_fps"))
	tabs.add_child(disp)
	var gp := UIKit.vbox(4)
	gp.name = "Gameplay"
	gp.add_child(_slider("Screen shake", "screen_shake", 0.0, 1.5, 0.05))
	gp.add_child(_slider("Effects", "effects_intensity", 0.25, 1.0, 0.05))
	gp.add_child(_slider("Aim assist (pad)", "aim_assist", 0.0, 1.0, 0.05))
	gp.add_child(_slider("Rumble (pad)", "rumble", 0.0, 1.0, 0.05))
	gp.add_child(_toggle("Hit-stop", "hitstop"))
	gp.add_child(_toggle("Reduce flashes", "reduce_flashes"))
	gp.add_child(_toggle("Damage numbers", "damage_numbers"))
	tabs.add_child(gp)
	var ctl := ScrollContainer.new()
	ctl.name = "Controls"
	ctl.custom_minimum_size = Vector2(280, 170)
	var cv := UIKit.vbox(2)
	ctl.add_child(cv)
	var head := UIKit.hbox(6)
	for h in [["Action", 74], ["Keyboard", 84], ["Gamepad", 84]]:
		var hl := UIKit.label(h[0], 8, UIKit.C_GOLD)
		hl.custom_minimum_size = Vector2(h[1], 0)
		head.add_child(hl)
	cv.add_child(head)
	var actions := [["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
		["attack", "Attack"], ["ward", "Ward"], ["dodge", "Dodge"], ["ability_1", "Ability 1"], ["ability_2", "Ability 2"],
		["flask", "Flask"], ["interact", "Interact"], ["map", "Map"], ["inventory", "Satchel"], ["hearthcall", "Hearthcall (go home)"]]
	for a in actions:
		var row := UIKit.hbox(6)
		var l := UIKit.label(a[1], 8)
		l.custom_minimum_size = Vector2(74, 0)
		row.add_child(l)
		row.add_child(_bind_button(a[0], false))
		var pb := _bind_button(a[0], true)
		pb.disabled = String(a[0]).begins_with("move_")   # movement stays on the left stick
		row.add_child(pb)
		cv.add_child(row)
	cv.add_child(UIKit.button("Reset controls", func() -> void:
		Settings.reset_bindings()
		ui.close_top()
		ui.settings(), 100))
	tabs.add_child(ctl)
	v.add_child(UIKit.button("Done", func() -> void: ui.close_top(), 70))
	return _center(p)


static func _bind_button(act: String, pad: bool) -> Button:
	var b := Button.new()
	b.text = Settings.describe_action(act, pad)
	b.custom_minimum_size = Vector2(84, 14)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		if b.has_node("Rebind"):
			return
		b.text = "press a button..." if pad else "press a key..."
		var cap := _Rebind.new()
		cap.name = "Rebind"
		cap.action = act
		cap.pad = pad
		cap.done = func() -> void: b.text = Settings.describe_action(act, pad)
		b.add_child(cap))
	return b


## Captures the next key/mouse button (or pad button/trigger) for an action.
## Esc or Menu cancels.
class _Rebind:
	extends Node
	var action := ""
	var pad := false
	var done: Callable
	var _frames := 0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_d: float) -> void:
		_frames += 1
	func _input(e: InputEvent) -> void:
		if _frames < 2:
			return   # the press that started the capture
		var cancel: bool = (e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_ESCAPE) 			or (e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_START)
		var ev: InputEvent = null
		if pad:
			if e is InputEventJoypadButton and e.pressed:
				ev = Settings._joy_button((e as InputEventJoypadButton).button_index)
			elif e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.6 					and (e as InputEventJoypadMotion).axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
				ev = Settings._joy_axis((e as InputEventJoypadMotion).axis, 1.0)
		elif e is InputEventKey and e.pressed:
			ev = Settings._key((e as InputEventKey).physical_keycode)
		elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index <= MOUSE_BUTTON_MIDDLE:
			ev = Settings._mouse((e as InputEventMouseButton).button_index)
		if not cancel and ev == null:
			return
		if not cancel:
			Settings.rebind(action, ev)
		get_viewport().set_input_as_handled()
		done.call()
		queue_free()


# --- sanctuary ------------------------------------------------------------------------------

static func forge(ui: UIRoot, equip_only: bool) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(_title("Weapon Rack" if equip_only else "The Ashen Forge"))
	var forge_built := Profile.building("forge") > 0
	if not forge_built:
		v.add_child(UIKit.para("The forge lies cold. Rebuild it in the sanctuary to temper and craft weapons.", 300, UIKit.C_DIM))
	# the rack on the left, the chosen weapon on the anvil to the right
	var cols := UIKit.hbox(8)
	v.add_child(cols)
	var list := UIKit.vbox(2)
	list.custom_minimum_size = Vector2(112, 0)
	cols.add_child(list)
	var detail := UIKit.vbox(3)
	detail.custom_minimum_size = Vector2(210, 196)
	cols.add_child(detail)
	# lambdas capture by value, so self-reference goes through a shared dict
	var ctx := {"sel": Profile.equipped_weapon()}
	ctx.rebuild = func() -> void:
		for c in list.get_children():
			c.queue_free()
		for c in detail.get_children():
			c.queue_free()
		for wid in GearDB.WEAPONS:
			var w0: Dictionary = GearDB.WEAPONS[wid]
			var lv0: int = Profile.weapon_level(wid)
			var b := Button.new()
			b.toggle_mode = true
			b.button_pressed = wid == ctx.sel
			b.custom_minimum_size = Vector2(112, 20)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "      %s%s" % [w0.name, ("  +%d" % lv0) if lv0 > 0 else ""]
			b.modulate = Color(1, 1, 1) if Profile.weapon_unlocked(wid) else Color(0.6, 0.56, 0.62)
			var ic := UIKit.icon_rect(w0.icon)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.position = Vector2(4, 2)
			b.add_child(ic)
			var pick: String = wid
			b.pressed.connect(func() -> void:
				ctx.sel = pick
				Audio.ui("ui_click")
				ctx.rebuild.call())
			list.add_child(b)
		var id: String = ctx.sel
		var w: Dictionary = GearDB.WEAPONS[id]
		var unlocked: bool = Profile.weapon_unlocked(id)
		var lvl: int = Profile.weapon_level(id)
		var eq: bool = Profile.equipped_weapon() == id
		var head := UIKit.hbox(6)
		head.add_child(UIKit.icon_rect(w.icon, 3))
		var hv := UIKit.vbox(0)
		hv.add_child(UIKit.label(String(w.name), 16, UIKit.C_GOLD if unlocked else UIKit.C_DIM, true))
		var rank := "Not yet forged" if not unlocked else ("+%d / +%d%s%s" % [lvl, GearDB.FORGE_MAX, "   equipped" if eq else "", "   ASCENDED" if lvl >= GearDB.FORGE_MAX else ""])
		hv.add_child(UIKit.label(rank, 8, Color(1.0, 0.85, 0.5) if lvl >= GearDB.FORGE_MAX else UIKit.C_DIM))
		head.add_child(hv)
		detail.add_child(head)
		detail.add_child(UIKit.para(String(w.desc), 210))
		if unlocked:
			detail.add_child(UIKit.label("Damage +%d%%" % int(round(lvl * GearDB.FORGE_DAMAGE_PER_LEVEL * 100.0)), 8, UIKit.C_TEXT))
		detail.add_child(UIKit.para(String(GearDB.FORGE_SIGNATURES[id]) + ("" if lvl >= 3 else "  (at +3)"), 210, UIKit.C_EMBER if unlocked and lvl >= 3 else UIKit.C_DIM))
		detail.add_child(UIKit.para(String(GearDB.FORGE_MASTERWORK[id]) + ("" if lvl >= 7 else "  (at +7)"), 210, Color(1.0, 0.8, 0.45) if unlocked and lvl >= 7 else UIKit.C_DIM))
		var row := UIKit.hbox(6)
		detail.add_child(row)
		if unlocked:
			var e := UIKit.button("Equip", func() -> void:
				Profile.data.equipped.weapon = id
				Profile.save_profile()
				if Game.stage and Game.stage.player:
					Game.stage.player.set_weapon(id, Profile.weapon_level(id))
				ctx.rebuild.call(), 60)
			e.disabled = eq
			row.add_child(e)
			if not equip_only and forge_built:
				var cost := Profile.forge_cost(id)
				if not cost.is_empty():
					var up := UIKit.button("Temper to +%d" % (lvl + 1), func() -> void:
						if Profile.upgrade_weapon(id):
							Audio.play("forge", 0.0)
							Profile.save_profile()
							if Game.stage and Game.stage.player and Profile.equipped_weapon() == id:
								Game.stage.player.set_weapon(id, Profile.weapon_level(id))
						ctx.rebuild.call(), 84)
					up.disabled = not Profile.can_pay(cost)
					row.add_child(up)
					detail.add_child(UIKit.cost_row(cost))
		elif not equip_only and forge_built:
			var uc: Dictionary = w.unlock
			var cr := UIKit.button("Forge it", func() -> void:
				if Profile.pay(uc):
					Profile.unlock_weapon(id)
					Audio.play("forge", 0.0, 0.8)
					Profile.save_profile()
				ctx.rebuild.call(), 70)
			cr.disabled = not Profile.can_pay(uc)
			row.add_child(cr)
			detail.add_child(UIKit.cost_row(uc))
		else:
			row.add_child(UIKit.label("Forge it at the Ashen Forge.", 8, UIKit.C_DIM))
	ctx.rebuild.call()
	v.add_child(UIKit.button("Close", func() -> void: ui.close_top(), 70))
	return _center(p)


static func sanctuary_build(ui: UIRoot, id: String) -> Control:
	var b: Dictionary = Profile.SANCTUARY[id]
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title(b.name))
	v.add_child(UIKit.para(b.desc, 220))
	var lvl := Profile.building(id)
	v.add_child(UIKit.label("Level %d / %d" % [lvl, int(b.max)], 8, UIKit.C_DIM))
	var cost := Profile.building_cost(id)
	if cost.is_empty():
		v.add_child(UIKit.label("Fully restored.", 8, UIKit.C_GOOD))
	else:
		v.add_child(UIKit.cost_row(cost))
		var btn := UIKit.button("Build" if lvl == 0 else "Improve", func() -> void:
			if Profile.upgrade_building(id):
				Audio.play("build", 0.0)
				Profile.save_profile()
				ui.close_top()
				ui.fade(Game.goto_hub), 80)
		btn.disabled = not Profile.can_afford(cost)
		v.add_child(btn)
	v.add_child(UIKit.button("Close", func() -> void: ui.close_top(), 70))
	return _center(p)


static func memorial(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(_title("Shrine of Memory", Color(0.8, 0.6, 1.0)))
	v.add_child(UIKit.label("GRUDGES", 8, UIKit.C_BAD, true))
	var gs: Array = Profile.data.grudges
	if gs.is_empty():
		v.add_child(UIKit.para("Nothing in the Undervault holds a grudge against you. Yet.", 240, UIKit.C_DIM))
	for g in gs:
		var t := "%s  (%s, Lv%d)  -  %s" % [g.name, EnemyDB.get_def(g.enemy).get("name", g.enemy), int(g.level), "settled" if g.get("settled", false) else "carries %d Embers" % int(g.embers)]
		v.add_child(UIKit.label(t, 8, UIKit.C_DIM if g.get("settled", false) else UIKit.C_TEXT))
		var traits: Array = g.get("traits", [])
		if not g.get("settled", false) and not traits.is_empty():
			v.add_child(UIKit.label("    has grown: " + ", ".join(PackedStringArray(traits.map(func(x): return String(Profile.GRUDGE_TRAIT_TEXT.get(x, x))))), 8, Color(1.0, 0.55, 0.45)))
	if not Profile.active_grudges().is_empty():
		v.add_child(UIKit.para("Unsettled Grudges grow in the dark: every third expedition, stronger, and their hoard with them.", 240, UIKit.C_DIM))
	v.add_child(HSeparator.new())
	var st: Dictionary = Profile.data.stats
	v.add_child(UIKit.label("Expeditions %d   Deaths %d   Returns %d   Victories %d" % [int(st.get("runs", 0)), int(st.get("deaths", 0)), int(st.get("extractions", 0)), int(st.get("victories", 0))], 8))
	v.add_child(UIKit.label("Foes slain %d   Embers gathered %d   Warden felled %d" % [int(st.get("kills", 0)), int(st.get("embers_earned", 0)), int(Profile.data.world.get("warden_kills", 0))], 8))
	v.add_child(UIKit.label("Undervault Memory: %d" % int(Profile.data.world.get("memory", 0)), 8, UIKit.C_SOUL))
	v.add_child(UIKit.button("Close", func() -> void: ui.close_top(), 70))
	return _center(p)


static func descent(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(_title("The Descent"))
	var mem := int(Profile.data.world.get("memory", 0))
	var last := String(Profile.data.descent.get("region", "ossuary"))
	var ctx := {"region": last if (EnemyDB.REGIONS.has(last) and EnemyDB.region_unlocked(last)) or (last == "delve" and Delve.unlocked()) else "ossuary"}
	# one row of region tabs, the chosen (or sealed) region described below
	var cards: Array = []
	var tabs := UIKit.hbox(3)
	v.add_child(tabs)
	var about := UIKit.para("", 250, UIKit.C_TEXT)
	about.custom_minimum_size = Vector2(250, 26)
	v.add_child(about)
	var describe := func(rid: String) -> void:
		if rid == "delve":
			about.text = (Delve.BLURB + ("  Deepest so far: %d." % Delve.best() if Delve.best() > 0 else "")) if Delve.unlocked() else Delve.SEALED
			about.add_theme_color_override("font_color", UIKit.C_SOUL if Delve.unlocked() else UIKit.C_DIM)
			return
		var reg: Dictionary = EnemyDB.REGIONS[rid]
		var open := EnemyDB.region_unlocked(rid)
		about.text = String(reg.blurb) if open else String(reg.get("sealed", "Sealed."))
		about.add_theme_color_override("font_color", UIKit.C_TEXT if open else UIKit.C_DIM)
	for rid in EnemyDB.REGIONS:
		var reg: Dictionary = EnemyDB.REGIONS[rid]
		var open := EnemyDB.region_unlocked(rid)
		var card := Button.new()
		card.toggle_mode = true
		card.button_pressed = rid == ctx.region
		card.custom_minimum_size = Vector2(80, 16)
		card.text = String(reg.name).trim_prefix("The ")
		card.modulate = Color(1, 1, 1) if open else Color(0.55, 0.52, 0.6)
		var region_id: String = rid
		card.pressed.connect(func() -> void:
			if EnemyDB.region_unlocked(region_id):
				ctx.region = region_id
				Profile.data.descent.region = region_id
				Profile.mark_changed()
			for c in cards:
				c.button_pressed = c == card if EnemyDB.region_unlocked(region_id) else c.get_meta("rid") == ctx.region
			describe.call(region_id)
			Audio.ui("ui_click"))
		card.focus_entered.connect(func() -> void: describe.call(region_id))
		card.mouse_entered.connect(func() -> void: describe.call(region_id))
		card.mouse_exited.connect(func() -> void: describe.call(ctx.region))
		card.set_meta("rid", rid)
		cards.append(card)
		tabs.add_child(card)
	# the endless descent, once the Ashen King has fallen
	var deep := Button.new()
	deep.toggle_mode = true
	deep.custom_minimum_size = Vector2(80, 16)
	deep.text = "Hollow Below"
	deep.modulate = Color(0.75, 1.0, 0.95) if Delve.unlocked() else Color(0.45, 0.45, 0.5)
	deep.button_pressed = ctx.region == "delve"
	deep.set_meta("rid", "delve")
	deep.pressed.connect(func() -> void:
		if Delve.unlocked():
			ctx.region = "delve"
			Profile.data.descent.region = "delve"
		for c in cards:
			c.button_pressed = c == deep if Delve.unlocked() else c.get_meta("rid") == ctx.region
		describe.call("delve")
		Audio.ui("ui_click"))
	deep.mouse_entered.connect(func() -> void: describe.call("delve"))
	deep.mouse_exited.connect(func() -> void: describe.call(ctx.region))
	cards.append(deep)
	tabs.add_child(deep)
	describe.call(ctx.region)
	if mem > 0:
		v.add_child(UIKit.para("The Undervault remembers you (Memory %d): foes are stronger, rewards richer." % mem, 250, UIKit.C_SOUL))
	v.add_child(_tier_picker())
	if Omens.any_unlocked():
		v.add_child(_omen_picker())
	v.add_child(UIKit.label("LOADOUT", 8, UIKit.C_GOLD, true))
	v.add_child(UIKit.label("Weapon: %s +%d" % [GearDB.weapon(Profile.equipped_weapon()).name, Profile.weapon_level(Profile.equipped_weapon())], 8))
	var avail := SkillDB.abilities(Profile.skills())
	var row := UIKit.hbox(4)
	v.add_child(row)
	for i in 2:
		row.add_child(UIKit.label("%s:" % Settings.describe_action("ability_1" if i == 0 else "ability_2"), 8, UIKit.C_DIM))
		var ob := OptionButton.new()
		var cur: String = Profile.slots()[i]
		var opts := [""] + avail
		for k in opts.size():
			ob.add_item("(none)" if opts[k] == "" else String(GearDB.ability(opts[k]).name), k)
			if opts[k] == cur:
				ob.select(k)
		var slot := i
		ob.item_selected.connect(func(k: int) -> void:
			Profile.set_slot(slot, opts[k])
			if Game.stage and Game.stage.player:
				Game.stage.player.ability_slots = Profile.slots())
		row.add_child(ob)
	var row2 := UIKit.hbox(8)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := UIKit.button("Descend" if not Net.active() else "Descend together", func() -> void:
		ui.close_all()
		Game.begin_descent(ctx.region), 80)
	if Net.is_client():
		go.disabled = true
		go.text = "%s leads the way" % Net.name_of(1)
	row2.add_child(go)
	row2.add_child(UIKit.button("Runes", func() -> void: ui.open(Screens.runes(ui)), 50))
	row2.add_child(UIKit.button("Party (%d)" % Net.party_size() if Net.active() else "Co-op", func() -> void: ui.open(Screens.coop(ui)), 60))
	row2.add_child(UIKit.button("Not yet", func() -> void: ui.close_top(), 70))
	v.add_child(row2)
	go.call_deferred("grab_focus")
	return _center(p)


## Omens: toggle the signs to read on this expedition. What each costs is shown
## on hover/focus; the sum of the rewards underneath. Remembered between runs.
static func _omen_picker() -> VBoxContainer:
	var v := UIKit.vbox(1)
	var chosen: Array = Profile.data.descent.omens
	var head := UIKit.hbox(4)
	head.add_child(UIKit.label("OMENS", 8, Omens.COLOR, true))
	var total := UIKit.label("", 8, UIKit.C_DIM)
	head.add_child(total)
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
	v.add_child(grid)
	var about := UIKit.para("", 250, UIKit.C_DIM)
	about.custom_minimum_size = Vector2(250, 18)
	v.add_child(about)
	var sum := func() -> void:
		var live := chosen.filter(func(o): return Omens.unlocked(String(o)))
		var e := Omens.bonus(live, "embers")
		var x := Omens.bonus(live, "xp")
		total.text = "none read" if live.is_empty() else "+%d%% Embers  +%d%% XP" % [int(round(e * 100.0)), int(round(x * 100.0))]
		total.add_theme_color_override("font_color", UIKit.C_DIM if live.is_empty() else UIKit.C_GOLD)
	var tell := func(id: String) -> void:
		var d := Omens.get_def(id)
		if not Omens.unlocked(id):
			about.text = Omens.what_unlocks(id)
			return
		var pay: Array = []
		if float(d.embers) > 0.0:
			pay.append("+%d%% Embers" % int(round(float(d.embers) * 100.0)))
		if float(d.xp) > 0.0:
			pay.append("+%d%% XP" % int(round(float(d.xp) * 100.0)))
		about.text = "%s  %s" % [String(d.cost), ("Pays " + ", ".join(PackedStringArray(pay)) + ".") if not pay.is_empty() else ""]
	for id in Omens.OMENS:
		var oid: String = id
		var open := Omens.unlocked(oid)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(82, 14)
		b.text = String(Omens.OMENS[oid].name) if open else "? ? ?"
		b.button_pressed = open and chosen.has(oid)
		b.disabled = not open
		b.modulate = Color(1, 1, 1) if open else Color(0.55, 0.52, 0.6)
		b.add_theme_font_size_override("font_size", 8)
		b.toggled.connect(func(on: bool) -> void:
			if on and not chosen.has(oid):
				chosen.append(oid)
			elif not on:
				chosen.erase(oid)
			Profile.mark_changed()
			Audio.ui("ui_click")
			tell.call(oid)
			sum.call())
		b.focus_entered.connect(func() -> void: tell.call(oid))
		b.mouse_entered.connect(func() -> void: tell.call(oid))
		grid.add_child(b)
	about.text = "Optional signs: each makes the expedition harder in one way, and pays for it."
	sum.call()
	return v


## Difficulty: step through the unlocked tiers and see what each one does.
static func _tier_picker() -> VBoxContainer:
	var v := UIKit.vbox(1)
	var head := UIKit.hbox(4)
	head.add_child(UIKit.label("DIFFICULTY", 8, UIKit.C_GOLD, true))
	var rec := Difficulty.recommended()
	head.add_child(UIKit.label("Power %d   Suggested: Tier %s" % [Difficulty.power(), Difficulty.roman(rec)], 8, UIKit.C_DIM))
	v.add_child(head)
	var row := UIKit.hbox(4)
	var name_l := UIKit.label("", 8, UIKit.C_TEXT, true)
	name_l.custom_minimum_size = Vector2(150, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := UIKit.vbox(0)
	var refresh := func() -> void:
		var t := Difficulty.selected()
		name_l.text = "Tier %s  %s" % [Difficulty.roman(t), Difficulty.tier_name(t)]
		name_l.add_theme_color_override("font_color", Difficulty.tier_color(t))
		for c in info.get_children():
			c.queue_free()
		info.add_child(UIKit.para(". ".join(PackedStringArray(Difficulty.describe(t))) + ".", 250, UIKit.C_DIM))
		if t == Difficulty.unlocked() and t < Difficulty.MAX_TIER:
			info.add_child(UIKit.para("Conquer the Sunken Throne at Tier %s or higher to go deeper." % Difficulty.roman(maxi(1, Difficulty.unlocked() - 1)), 250, Color(1.0, 0.7, 0.4)))
	var step := func(d: int) -> void:
		Difficulty.select(Difficulty.selected() + d)
		Profile.mark_changed()
		Audio.ui("ui_click")
		refresh.call()
	row.add_child(UIKit.button("<", func() -> void: step.call(-1), 18))
	row.add_child(name_l)
	row.add_child(UIKit.button(">", func() -> void: step.call(1), 18))
	v.add_child(row)
	v.add_child(info)
	refresh.call()
	return v


# --- bestiary --------------------------------------------------------------------------------------

## The first idle frame of a creature's sheet, for portraits.
static func creature_tex(id: String) -> AtlasTexture:
	var info := SpriteLib.get_sheet(String(EnemyDB.get_def(id).sheet))
	var anims: Dictionary = info.anims
	var a: Dictionary = anims.get("idle", anims.values()[0])
	var t := AtlasTexture.new()
	t.atlas = info.texture
	t.region = Rect2(0, float(a.row) * info.frame_size.y, info.frame_size.x, info.frame_size.y)
	return t


static func _region_of(id: String) -> String:
	for rid in EnemyDB.REGIONS:
		var r: Dictionary = EnemyDB.REGIONS[rid]
		if (r.pool as Array).has(id) or String(r.boss) == id:
			return String(r.name)
	return ""


## Every creature of the Undervault: a silhouette until met, then its portrait,
## where it lives, how many have fallen to you, and what is known of it.
static func bestiary(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(_title("Bestiary"))
	var seen: Array = Profile.data.get("seen", {}).get("enemies", [])
	var order: Array = []
	for rid in EnemyDB.REGIONS:
		for id in EnemyDB.REGIONS[rid].pool:
			if not order.has(id) and EnemyDB.ENEMIES.has(id):
				order.append(id)
		if not order.has(EnemyDB.REGIONS[rid].boss):
			order.append(EnemyDB.REGIONS[rid].boss)
	v.add_child(UIKit.label("%d of %d creatures met." % [order.filter(func(i): return seen.has(i)).size(), order.size()], 8, UIKit.C_DIM))
	var row := UIKit.hbox(8)
	v.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	row.add_child(grid)
	var detail := UIKit.vbox(3)
	detail.custom_minimum_size = Vector2(170, 200)
	row.add_child(detail)
	var show := func(id: String) -> void:
		for c in detail.get_children():
			c.queue_free()
		var d := EnemyDB.get_def(id)
		var met := seen.has(id)
		var big := TextureRect.new()
		big.texture = creature_tex(id)
		big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		big.custom_minimum_size = Vector2(170, 72)
		big.modulate = Color(1, 1, 1) if met else Color(0, 0, 0, 0.85)
		detail.add_child(big)
		detail.add_child(UIKit.label(String(d.name) if met else "???", 16, UIKit.C_GOLD if met else UIKit.C_DIM, true))
		var role: Array = EnemyDB.ROLES.get(String(d.get("role", "")), ["", ""])
		detail.add_child(UIKit.label(_region_of(id) + "   " + (String(role[0]).to_upper() if met else ""), 8, UIKit.C_DIM))
		if met:
			detail.add_child(UIKit.label("Slain: %d" % int(Profile.data.stats.get("k_" + id, 0)), 8, UIKit.C_TEXT))
			detail.add_child(UIKit.para(String(d.get("lore", "")), 170, Color(0.85, 0.8, 0.7)))
			if String(role[1]) != "":
				detail.add_child(UIKit.para(String(role[1]), 170, UIKit.C_DIM))
		else:
			detail.add_child(UIKit.para("Not yet met. Go deeper.", 170, UIKit.C_DIM))
	for id in order:
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.focus_mode = Control.FOCUS_ALL
		var tr := TextureRect.new()
		tr.texture = creature_tex(String(id))
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(34, 34)
		tr.position = Vector2(2, 2)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(1, 1, 1) if seen.has(id) else Color(0, 0, 0, 0.8)
		b.add_child(tr)
		var pick: String = id
		b.pressed.connect(func() -> void:
			Audio.ui("ui_click")
			show.call(pick))
		b.focus_entered.connect(func() -> void: show.call(pick))
		b.mouse_entered.connect(func() -> void: show.call(pick))
		grid.add_child(b)
	var met_ids: Array = order.filter(func(i): return seen.has(i))
	show.call(String(met_ids[0] if not met_ids.is_empty() else order[0]))
	var close := UIKit.button("Close", func() -> void: ui.close_top(), 70)
	v.add_child(close)
	close.call_deferred("grab_focus")
	return _center(p)


# --- feats ---------------------------------------------------------------------------------------

## Long goals: progress toward each, and what it pays.
static func feats(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(_title("Feats"))
	v.add_child(UIKit.label("%d of %d earned.  Skill points from feats: %d.  Level cap %d, Renown %d." % [Feats.earned_count(), Feats.FEATS.size(), int(Profile.data.unlocks.get("bonus_points", 0)), Profile.MAX_LEVEL, Profile.renown()], 8, UIKit.C_DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(330, 220)
	v.add_child(scroll)
	var list := UIKit.vbox(3)
	scroll.add_child(list)
	for id in Feats.FEATS:
		var f: Dictionary = Feats.FEATS[id]
		var done := Feats.earned(id)
		var row := UIKit.hbox(6)
		row.add_child(UIKit.icon_rect("star" if done else "lock"))
		var tv := UIKit.vbox(0)
		var goal := Feats.goal(id)
		var prog := mini(Feats.progress(id), goal)
		var name_col := UIKit.C_GOLD if done else UIKit.C_TEXT
		tv.add_child(UIKit.label("%s%s" % [f.name, "" if done or goal <= 1 else "   %d / %d" % [prog, goal]], 8, name_col, done))
		tv.add_child(UIKit.para("%s  Reward: %s" % [f.desc, Feats.describe_reward(f.reward)], 290, UIKit.C_DIM if done else UIKit.C_TEXT))
		row.add_child(tv)
		list.add_child(row)
	var close := UIKit.button("Close", func() -> void: ui.close_top(), 70)
	v.add_child(close)
	close.call_deferred("grab_focus")
	return _center(p)


# --- run summary ------------------------------------------------------------------------------

static func summary(ui: UIRoot, s: Dictionary) -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(260, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var titles := {"died": ["Your Light Fails", UIKit.C_BAD], "extracted": ["Returned to the Hearth", UIKit.C_GOLD], "victory": ["The Warden Is Fallen", UIKit.C_SOUL]}
	var t: Array = titles.get(s.outcome, ["Expedition Over", UIKit.C_TEXT])
	if s.outcome == "victory":
		t = [String(EnemyDB.REGIONS.get(s.get("region", "ossuary"), {}).get("victory", t[0])), t[1]]
	v.add_child(_title(t[0], t[1]))
	v.add_child(UIKit.label("Depth %d   Rooms %d   Foes %d   Time %s   Tier %s" % [s.depth, s.rooms, s.kills, UIKit.fmt_time(s.time), Difficulty.roman(int(s.get("tier", 1)))], 8, UIKit.C_DIM))
	for fid in s.get("feats", []):
		v.add_child(UIKit.label("Feat earned: %s  -  %s" % [Feats.FEATS[fid].name, Feats.describe_reward(Feats.FEATS[fid].reward)], 8, Color(1.0, 0.85, 0.45), true))
	for nt in s.get("tiers", []):
		v.add_child(UIKit.label("New difficulty unlocked: Tier %s, %s" % [Difficulty.roman(int(nt)), Difficulty.tier_name(int(nt))], 8, Difficulty.tier_color(int(nt)), true))
	v.add_child(HSeparator.new())
	var er := UIKit.hbox(4)
	er.add_child(UIKit.icon_rect("ember"))
	er.add_child(UIKit.label("Embers brought home: %d" % int(s.embers_kept), 8, UIKit.C_EMBER))
	v.add_child(er)
	if int(s.bonus) > 0:
		v.add_child(UIKit.label("  includes a victory bonus of %d" % int(s.bonus), 8, UIKit.C_GOOD))
	if int(s.embers_lost) > 0:
		v.add_child(UIKit.label("Embers lost in the dark: %d" % int(s.embers_lost), 8, UIKit.C_BAD))
	if int(s.sunshards) > 0:
		var sr := UIKit.hbox(4)
		sr.add_child(UIKit.icon_rect("sunshard"))
		sr.add_child(UIKit.label("Sunshards: %d" % int(s.sunshards), 8, UIKit.C_GOLD))
		v.add_child(sr)
	v.add_child(UIKit.label("Memories (XP) gathered: %d   Level %d" % [int(s.xp), Profile.level()], 8, UIKit.C_SOUL))
	if bool(s.get("delve", false)):
		var best := int(s.get("delve_best", 0))
		v.add_child(UIKit.label("The Hollow Below: depth %d%s" % [int(s.depth), ("   - a new deepest!" if int(s.depth) > best else "   (deepest %d)" % best)], 8, UIKit.C_SOUL, true))
	if not (s.get("omens", []) as Array).is_empty():
		v.add_child(UIKit.label("Omens read: %s   (+%d Embers, +%d XP)" % [Omens.names(s.omens), int(s.get("omen_embers", 0)), int(s.get("omen_xp", 0))], 8, Omens.COLOR))
	if Profile.skill_points_free() > 0:
		v.add_child(UIKit.label("%d skill point(s) await at the Hearth." % Profile.skill_points_free(), 8, UIKit.C_GOOD))
	var g: Dictionary = s.get("grudge", {})
	if not g.is_empty():
		v.add_child(UIKit.para("%s now carries %d of your Embers. The Undervault will send it after you." % [g.name, int(g.embers)], 240, Color(1.0, 0.55, 0.45)))
	for n in s.get("settled", []):
		v.add_child(UIKit.label("Grudge settled: %s" % n, 8, UIKit.C_GOOD))
	for n in s.get("grudges_grew", []):
		v.add_child(UIKit.label("%s grew stronger in the dark." % n, 8, Color(1.0, 0.55, 0.45)))
	if String(s.get("unlocked", "")) != "":
		v.add_child(UIKit.label("Unlocked: %s" % s.unlocked, 8, UIKit.C_GOLD))
	var rl: Array = s.get("relics", [])
	if not rl.is_empty():
		var rr := HFlowContainer.new()
		rr.custom_minimum_size = Vector2(240, 0)
		for id in rl:
			var ic := UIKit.icon_rect(RelicDB.relic(id).get("icon", "relic"))
			ic.tooltip_text = RelicDB.relic(id).get("name", id)
			rr.add_child(ic)
		v.add_child(rr)
	var b := UIKit.button("Return to the Sanctuary", func() -> void:
		ui.close_all()
		ui.title_card("The Sanctuary", "The Hearth still burns.", Game.goto_hub), 140)
	var cc := CenterContainer.new()
	cc.add_child(b)
	v.add_child(cc)
	b.call_deferred("grab_focus")
	return _center(p)


# --- developer tools ------------------------------------------------------------------------------

static func debug(ui: UIRoot) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(_title("Debug", UIKit.C_SOUL))
	v.add_child(UIKit.button("+500 Embers, +3 Sunshards", func() -> void:
		Profile.add_currency("embers", 500)
		Profile.add_currency("sunshards", 3), 160))
	v.add_child(UIKit.button("+5 Levels", func() -> void:
		for i in 5:
			Profile.add_xp(Combat.xp_to_next(Profile.level())), 160))
	v.add_child(UIKit.button("Random relic", func() -> void:
		if Game.run:
			var ids := RelicDB.roll_offer(Game.run.rng, 1, Game.run.relics, {}, SkillDB.abilities(Profile.skills()), 3)
			if not ids.is_empty():
				Game.grant_relic(ids[0]), 160))
	v.add_child(UIKit.button("Heal / full Kindle", func() -> void:
		var pl := Game.stage.player if Game.stage else null
		if pl:
			pl.hp = pl.max_hp
			pl.kindle = pl.kindle_max(), 160))
	v.add_child(UIKit.button("Kill room enemies", func() -> void:
		if Game.stage:
			for a in Game.stage.actors.duplicate():
				if a is Enemy and a.alive:
					a.take_hit(Hit.make(Game.stage.player, 99999.0, ["debug"])), 160))
	v.add_child(UIKit.button("Skip to next depth", func() -> void:
		ui.close_all()
		if Game.run:
			Game.descend(), 160))
	v.add_child(UIKit.button("Unlock all weapons + forge", func() -> void:
		Profile.data.sanctuary.forge = 1
		for w in GearDB.WEAPONS:
			Profile.unlock_weapon(w), 160))
	v.add_child(UIKit.button("Close", func() -> void: ui.close_top(), 70))
	return _center(p)
