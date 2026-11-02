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
	buttons.add_child(UIKit.button("Settings", func() -> void: ui.settings(), 110))
	buttons.add_child(UIKit.button("Quit", func() -> void: ui.get_tree().quit(), 110))
	var ver := UIKit.label("v%s  -  Level %d  -  %d runs" % [ProjectSettings.get_setting("application/config/version"), Profile.level(), int(Profile.data.stats.get("runs", 0))], 8, UIKit.C_DIM, true)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(8, -14)
	ver.offset_top = -14
	root.add_child(ver)
	start.call_deferred("grab_focus")
	return root


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
		var pick := UIKit.button("[%d] Take" % key, func() -> void:
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

static func shop(ui: UIRoot, prop: Prop) -> Control:
	var d := Game.stage as Dungeon
	var run := d.run
	if not prop.data.has("stock"):
		var ids := RelicDB.roll_offer(run.rng, 3, run.relics, SkillDB.branch_counts(Profile.skills()), SkillDB.abilities(Profile.skills()), run.depth, false)
		var stock: Array = []
		for id in ids:
			var r := RelicDB.relic(id)
			var price: int = {"common": 45, "rare": 80, "epic": 130}[r.rarity] + 15 * (run.depth - 1)
			stock.append({"kind": "relic", "id": id, "price": price})
		stock.append({"kind": "flask", "price": 35})
		stock.append({"kind": "heal", "price": 25})
		prop.data["stock"] = stock
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title("The Cinder Merchant"))
	v.add_child(UIKit.para("\"Embers you spend here won't reach your Hearth. Choose well, wanderer.\"", 260, UIKit.C_DIM))
	var have := UIKit.label("", 8, UIKit.C_EMBER, true)
	v.add_child(have)
	var list := UIKit.vbox(3)
	v.add_child(list)
	var rebuild: Callable
	rebuild = func() -> void:
		have.text = "Carried Embers: %d" % run.embers
		for c in list.get_children():
			c.queue_free()
		for item in prop.data.stock:
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
			var b := UIKit.button("%d Embers" % item.price, func() -> void:
				if run.embers < int(item.price) or item.get("sold", false):
					Audio.ui("deny")
					return
				run.embers -= int(item.price)
				item["sold"] = true
				Audio.play("buy", 0.0)
				var pl := d.player
				match item.kind:
					"relic":
						Game.grant_relic(item.id)
					"flask":
						pl.flask = mini(pl.flask + 1, int(pl.stats.v("flask_charges")))
					"heal":
						pl.heal(pl.max_hp * 0.4)
				rebuild.call(), 70)
			b.disabled = item.get("sold", false) or run.embers < int(item.price)
			row.add_child(b)
			list.add_child(row)
	rebuild.call()
	v.add_child(UIKit.button("Leave", func() -> void: ui.close_top(), 70))
	return _center(p)


# --- shrine -----------------------------------------------------------------------------

static func shrine(ui: UIRoot, prop: Prop) -> Control:
	var d := Game.stage as Dungeon
	var run := d.run
	var p := UIKit.panel()
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(_title("Shrine of Pacts", Color(0.8, 0.6, 1.0)))
	if prop.used:
		v.add_child(UIKit.para("The idol's eyes are dark. Its bargain is spent.", 240, UIKit.C_DIM))
		v.add_child(UIKit.button("Leave", func() -> void: ui.close_top(), 70))
		return _center(p)
	v.add_child(UIKit.para("A hollow voice: \"Power is never free. What will you give?\"", 260, UIKit.C_DIM))
	var pl := d.player
	var blood := UIKit.button("Blood Pact: lose 25% of your health, choose a rare relic", func() -> void:
		prop.used = true
		pl.hp = maxf(1.0, pl.hp - pl.max_hp * 0.25)
		pl.stage.fx.burst(pl.pos, 1.0, Color(0.8, 0.2, 0.3), 16, 3.0, 0.5, 4.0)
		Audio.play("pact", 0.0)
		ui.close_top()
		var offer := RelicDB.roll_offer(run.rng, 3, run.relics, SkillDB.branch_counts(Profile.skills()), SkillDB.abilities(Profile.skills()), run.depth + 2, false)
		offer = offer.filter(func(id): return RelicDB.relic(id).rarity != "common")
		if offer.is_empty():
			offer = RelicDB.roll_offer(run.rng, 3, run.relics, {}, [], 3, false)
		ui.relic_choice(offer, func(id: String) -> void:
			if id != "":
				Game.grant_relic(id)), 250)
	v.add_child(blood)
	var curses: Array = RelicDB.RELICS.filter(func(r): return r.get("cursed", false) and not run.relics.has(r.id))
	if not curses.is_empty():
		var c: Dictionary = curses[run.rng.randi_range(0, curses.size() - 1)]
		var txt := "Embrace the Curse: %s (%s) +40 Embers" % [c.name, c.desc]
		var curse := UIKit.button(txt, func() -> void:
			prop.used = true
			Game.grant_relic(c.id)
			run.embers += 40
			Audio.play("pact", 0.0, 0.8)
			ui.close_top(), 250)
		curse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		curse.custom_minimum_size = Vector2(250, 26)
		v.add_child(curse)
	v.add_child(UIKit.button("Refuse", func() -> void: ui.close_top(), 70))
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


static func dialogue(ui: UIRoot, speaker: String, lines: Array) -> Control:
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
	var hint := UIKit.label("[click / F] continue", 8, UIKit.C_DIM)
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
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(_title("Paused"))
	var resume := UIKit.button("Resume", func() -> void: ui.close_top(), 140)
	v.add_child(resume)
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
	gp.add_child(_toggle("Hit-stop", "hitstop"))
	gp.add_child(_toggle("Reduce flashes", "reduce_flashes"))
	gp.add_child(_toggle("Damage numbers", "damage_numbers"))
	tabs.add_child(gp)
	var ctl := ScrollContainer.new()
	ctl.name = "Controls"
	ctl.custom_minimum_size = Vector2(280, 170)
	var cv := UIKit.vbox(2)
	ctl.add_child(cv)
	var actions := [["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
		["attack", "Attack"], ["ward", "Ward"], ["dodge", "Dodge"], ["ability_1", "Ability 1"], ["ability_2", "Ability 2"],
		["flask", "Flask"], ["interact", "Interact"], ["map", "Map"]]
	for a in actions:
		var row := UIKit.hbox(6)
		var l := UIKit.label(a[1], 8)
		l.custom_minimum_size = Vector2(80, 0)
		row.add_child(l)
		var b := Button.new()
		b.text = Settings.describe_action(a[0])
		b.custom_minimum_size = Vector2(80, 14)
		var act: String = a[0]
		b.pressed.connect(func() -> void:
			b.text = "press a key..."
			var cap := _Rebind.new()
			cap.action = act
			cap.done = func() -> void: b.text = Settings.describe_action(act)
			b.add_child(cap))
		row.add_child(b)
		cv.add_child(row)
	cv.add_child(UIKit.button("Reset controls", func() -> void:
		Settings.reset_bindings()
		ui.close_top()
		ui.settings(), 100))
	tabs.add_child(ctl)
	v.add_child(UIKit.button("Done", func() -> void: ui.close_top(), 70))
	return _center(p)


class _Rebind:
	extends Node
	var action := ""
	var done: Callable
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(e: InputEvent) -> void:
		if (e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index <= MOUSE_BUTTON_MIDDLE):
			if e is InputEventKey and (e as InputEventKey).keycode == KEY_ESCAPE:
				done.call()
				queue_free()
				get_viewport().set_input_as_handled()
				return
			var ev: InputEvent = e
			if e is InputEventKey:
				ev = InputEventKey.new()
				(ev as InputEventKey).physical_keycode = (e as InputEventKey).physical_keycode
			Settings.rebind(action, 0, ev)
			done.call()
			get_viewport().set_input_as_handled()
			queue_free()


# --- sanctuary ------------------------------------------------------------------------------

static func forge(ui: UIRoot, equip_only: bool) -> Control:
	var p := UIKit.panel()
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(_title("Weapon Rack" if equip_only else "The Ashen Forge"))
	var forge_built := Profile.building("forge") > 0
	if not forge_built:
		v.add_child(UIKit.para("The forge lies cold. Rebuild it to temper and craft weapons.", 260, UIKit.C_DIM))
	var list := UIKit.vbox(4)
	v.add_child(list)
	var rebuild: Callable
	rebuild = func() -> void:
		for c in list.get_children():
			c.queue_free()
		for id in GearDB.WEAPONS:
			var w: Dictionary = GearDB.WEAPONS[id]
			var row := UIKit.hbox(6)
			row.add_child(UIKit.icon_rect(w.icon, 2))
			var tv := UIKit.vbox(0)
			var unlocked: bool = Profile.weapon_unlocked(id)
			var lvl: int = Profile.weapon_level(id)
			var eq: bool = Profile.equipped_weapon() == id
			tv.add_child(UIKit.label("%s%s%s" % [w.name, ("  +%d" % lvl) if lvl > 0 else "", "  (equipped)" if eq else ""], 8, UIKit.C_GOLD if unlocked else UIKit.C_DIM))
			tv.add_child(UIKit.para(w.desc, 170))
			if unlocked and lvl >= 3:
				tv.add_child(UIKit.para(GearDB.FORGE_SIGNATURES[id], 170, UIKit.C_EMBER))
			row.add_child(tv)
			var bv := UIKit.vbox(2)
			if unlocked:
				var e := UIKit.button("Equip", func() -> void:
					Profile.data.equipped.weapon = id
					Profile.save_profile()
					if Game.stage and Game.stage.player:
						Game.stage.player.set_weapon(id, Profile.weapon_level(id))
					rebuild.call(), 60)
				e.disabled = eq
				bv.add_child(e)
				if not equip_only and forge_built:
					var cost := Profile.forge_cost(id)
					if not cost.is_empty():
						var up := UIKit.button("Temper +%d" % (lvl + 1), func() -> void:
							if Profile.upgrade_weapon(id):
								Audio.play("forge", 0.0)
								Profile.save_profile()
								if Game.stage and Game.stage.player and Profile.equipped_weapon() == id:
									Game.stage.player.set_weapon(id, Profile.weapon_level(id))
							rebuild.call(), 60)
						up.disabled = not Profile.can_afford(cost)
						bv.add_child(up)
						bv.add_child(UIKit.cost_row(cost))
			elif not equip_only and forge_built:
				var uc: Dictionary = w.unlock
				var cr := UIKit.button("Craft", func() -> void:
					if Profile.pay(uc):
						Profile.unlock_weapon(id)
						Audio.play("forge", 0.0, 0.8)
						Profile.save_profile()
					rebuild.call(), 60)
				cr.disabled = not Profile.can_afford(uc)
				bv.add_child(cr)
				bv.add_child(UIKit.cost_row(uc))
			else:
				bv.add_child(UIKit.label("Locked", 8, UIKit.C_DIM))
			row.add_child(bv)
			list.add_child(row)
			list.add_child(HSeparator.new())
	rebuild.call()
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
	var reg: Dictionary = EnemyDB.REGIONS.ossuary
	var card := UIKit.panel("DarkPanel")
	var cv := UIKit.vbox(2)
	card.add_child(cv)
	cv.add_child(UIKit.label(reg.name, 8, UIKit.C_SOUL, true))
	var mem := int(Profile.data.world.get("memory", 0))
	cv.add_child(UIKit.para("%d depths, then the Gloam Warden.%s" % [int(reg.depths), ("  The Undervault remembers you (Memory %d): foes are stronger, rewards richer." % mem) if mem > 0 else ""], 240))
	v.add_child(card)
	var locked := UIKit.label("Further regions: sealed (defeat the Warden...)", 8, UIKit.C_DIM)
	v.add_child(locked)
	v.add_child(UIKit.label("LOADOUT", 8, UIKit.C_GOLD, true))
	v.add_child(UIKit.label("Weapon: %s +%d" % [GearDB.weapon(Profile.equipped_weapon()).name, Profile.weapon_level(Profile.equipped_weapon())], 8))
	var avail := SkillDB.abilities(Profile.skills())
	for i in 2:
		var row := UIKit.hbox(4)
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
		v.add_child(row)
	var row2 := UIKit.hbox(8)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := UIKit.button("Descend", func() -> void:
		ui.close_all()
		ui.fade(func() -> void: Game.start_run("ossuary")), 80)
	row2.add_child(go)
	row2.add_child(UIKit.button("Not yet", func() -> void: ui.close_top(), 70))
	v.add_child(row2)
	go.call_deferred("grab_focus")
	return _center(p)


# --- run summary ------------------------------------------------------------------------------

static func summary(ui: UIRoot, s: Dictionary) -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(260, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var titles := {"died": ["Your Light Fails", UIKit.C_BAD], "extracted": ["Returned to the Hearth", UIKit.C_GOLD], "victory": ["The Warden Is Fallen", UIKit.C_SOUL]}
	var t: Array = titles.get(s.outcome, ["Expedition Over", UIKit.C_TEXT])
	v.add_child(_title(t[0], t[1]))
	v.add_child(UIKit.label("Depth %d   Rooms %d   Foes %d   Time %s" % [s.depth, s.rooms, s.kills, UIKit.fmt_time(s.time)], 8, UIKit.C_DIM))
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
	if Profile.skill_points_free() > 0:
		v.add_child(UIKit.label("%d skill point(s) await at the Hearth." % Profile.skill_points_free(), 8, UIKit.C_GOOD))
	var g: Dictionary = s.get("grudge", {})
	if not g.is_empty():
		v.add_child(UIKit.para("%s now carries %d of your Embers. The Undervault will send it after you." % [g.name, int(g.embers)], 240, Color(1.0, 0.55, 0.45)))
	for n in s.get("settled", []):
		v.add_child(UIKit.label("Grudge settled: %s" % n, 8, UIKit.C_GOOD))
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
		ui.fade(Game.goto_hub), 140)
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
