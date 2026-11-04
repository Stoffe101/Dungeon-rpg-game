## Dev smoke test for menus: opens every screen and presses its buttons so
## script errors in rarely-used flows surface. Run with `-- uismoke profile=smoke.json`.
## Watch the log for SCRIPT ERROR lines; it prints "[smoke] done" at the end.
extends Node

const SKIP := ["Quit", "Quit to Desktop", "New Game", "Main Menu", "Close", "Not yet", "Leave", "Refuse", "No", "Done", "Resume", "Leave them"]

var ui: UIRoot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = Game.ui
	_run.call_deferred()


func _wait(frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame


## Layout: every visible piece of the top screen lies inside the window (at
## this resolution and UI scale), unless it scrolls inside a ScrollContainer.
func _check_fits(label: String) -> void:
	if ui.modals.is_empty():
		return
	var top: Control = ui.modals[ui.modals.size() - 1]
	var vr := get_viewport().get_visible_rect().grow(1.0)
	var bad: Array = []
	_walk_fits(top, vr, bad)
	if bad.is_empty():
		print("[smoke] ok: %s fits %dx%d (ui scale %d)" % [label, int(vr.size.x), int(vr.size.y), Settings.effective_ui_scale()])
	else:
		push_error("[smoke] FAILED: %s runs off the screen at ui scale %d: %s" % [label, Settings.effective_ui_scale(), ", ".join(bad.slice(0, 3))])


func _walk_fits(n: Node, vr: Rect2, bad: Array) -> void:
	for c in n.get_children():
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		var r := (c as Control).get_global_rect()
		if r.size.x > 0.0 and r.size.y > 0.0 and not vr.encloses(r):
			bad.append("%s %s" % [c.name, str(r)])
		if c is ScrollContainer:
			continue     # its contents scroll: they may be longer than the window
		_walk_fits(c, vr, bad)


func _press_all(label: String) -> void:
	if ui.modals.is_empty():
		return
	_check_fits(label)
	var top: Control = ui.modals[ui.modals.size() - 1]
	var buttons: Array = []
	_collect(top, buttons)
	print("[smoke] %s: %d buttons" % [label, buttons.size()])
	for b in buttons:
		if not is_instance_valid(b) or b.disabled or b.text in SKIP or b.text.begins_with("[") or b.text == "Descend" or b.text == "Return to the Sanctuary":
			continue
		b.pressed.emit()
		await _wait(2)


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and not (c is OptionButton) and not (c is CheckBox):
			out.append(c)
		_collect(c, out)


func _close_all() -> void:
	ui.close_all()
	await _wait(2)


func _run() -> void:
	await _wait(10)
	# start from a clean slate so earlier smoke runs cannot change the outcome
	if Profile.path != Profile.DEFAULT_PATH:
		Profile.reset_profile()
	Profile.add_currency("embers", 20000)
	Profile.add_currency("sunshards", 20)
	for i in 6:
		Profile.add_xp(Combat.xp_to_next(Profile.level()))
	# sanctuary
	for id in ["forge", "apothecary", "shrine", "hearth"]:
		ui.sanctuary_build(id)
		await _wait()
		await _press_all("build " + id)
		await _wait(40)
		await _close_all()
	await _wait(40)
	Game.goto_hub()
	await _wait(10)
	ui.forge()
	await _wait()
	for k in 3:
		await _press_all("forge pass %d" % k)
	await _close_all()
	ui.weapon_select()
	await _wait()
	await _press_all("weapon rack")
	await _close_all()
	ui.skill_tree()
	await _wait()
	var tree: SkillTreeUI = ui.modals[0].get_child(0)
	for id in ["b1", "b2", "b3", "p1", "p2", "p3l", "g1", "w1", "k1", "k2", "k3"]:
		tree._try_allocate(id)
	tree._try_refund("k3")
	# a distant node kindles the whole path to it; search and panels work
	while Profile.skill_points_free() < 4:
		Profile.add_xp(Combat.xp_to_next(Profile.level()))
	var before := Profile.skills().size()
	var route := SkillDB.path_to("w3", Profile.skills())
	tree._try_allocate("w3")
	_expect(Profile.skills().has("w3"), "clicking a distant node kindles the path to it")
	_expect(Profile.skills().size() == before + (route.nodes as Array).size(), "exactly the previewed path is kindled (%d nodes)" % (route.nodes as Array).size())
	tree.search_box.text = "burn"
	tree._on_search("burn")
	_expect(tree.matches.size() > 3, "search finds burn nodes")
	# masteries take ranks; the tooltip says so
	while Profile.skill_points_free() < 12:
		Profile.add_xp(Combat.xp_to_next(Profile.level()))
	tree._try_allocate("b_m")
	tree._try_allocate("b_m")
	tree._try_allocate("b_m")
	_expect(SkillDB.rank("b_m", Profile.skills()) == 3, "a mastery is reached by path, then ranked up (rank %d)" % SkillDB.rank("b_m", Profile.skills()))
	tree._set_hovered("b_m")
	await _wait(2)
	var lines: Array = []
	for row in tree.tip_box.get_children():
		if row is Label:
			lines.append((row as Label).text)
	print("[smoke] mastery tooltip: ", " | ".join(lines))
	tree._toggle_bonuses()
	tree._toggle_bonuses()
	tree._focus_branch("rime")
	await _wait(30)
	await _close_all()
	print("[smoke] skills: ", Profile.skills())
	ui.memorial()
	await _wait()
	await _close_all()
	ui.settings()
	await _wait()
	var st: Control = ui.modals[0]
	var tabs: Array = []
	_find_tabs(st, tabs)
	if not tabs.is_empty():
		for t in tabs[0].get_tab_count():
			tabs[0].current_tab = t
			await _wait(2)
	await _close_all()
	ui.dialogue("The Keeper", Keeper.lines())
	await _wait()
	await _close_all()
	ui.descent_prompt()
	await _wait()
	await _close_all()
	# expedition flows
	Game.start_run()
	await _wait(20)
	var d := Game.stage as Dungeon
	var pl := d.player
	var spot := Vector2i(pl.pos) + Vector2i(2, 0)
	var merchant := Prop.make(d, "merchant", spot)
	d.run.embers = 500
	ui.shop(merchant)
	await _wait()
	await _press_all("shop")
	await _close_all()
	var shrine := Prop.make(d, "shrine", spot + Vector2i(0, 2))
	ui.shrine(shrine)
	await _wait()
	var buttons: Array = []
	_collect(ui.modals[0], buttons)
	for b in buttons:
		if is_instance_valid(b) and b.text.begins_with("Blood Pact"):
			b.pressed.emit()
			break
	await _wait(4)
	if not ui.modals.is_empty():
		await _press_all("pact relic choice")
		var picks: Array = []
		_collect(ui.modals[ui.modals.size() - 1], picks)
		for b in picks:
			if is_instance_valid(b) and b.text.begins_with("[1]"):
				b.pressed.emit()
				break
	await _close_all()
	var chest := Prop.make(d, "chest", spot + Vector2i(-3, 0), {"tier": 2})
	chest.interact(pl)
	await _wait(4)
	await _close_all()
	d.request("lore", null)
	await _wait()
	await _close_all()
	var hs := Prop.make(d, "hearthstone", spot + Vector2i(0, -2))
	d.request("hearthstone", hs)
	await _wait()
	await _close_all()
	ui.pause_menu()
	await _wait()
	await _close_all()
	print("[smoke] relics: ", d.run.relics, " hp ", pl.hp, "/", pl.max_hp)
	await _aim_checks(pl)
	await _pad_checks(d, pl)
	Game.descend()
	await _wait(40)
	Game.end_run("extracted")
	await _wait(10)
	await _close_all()
	Game.goto_hub()
	await _wait(10)
	var hub := Game.stage as Hub
	_expect(not hub.residents.is_empty(), "residents live in the sanctuary")
	if not hub.residents.is_empty():
		var w: Wanderer = hub.residents[0]
		# (a title card still covering the last scene change holds the hands;
		# a screen left open - the expedition's summary - is closed here)
		while ui.card_pending:
			await _wait()
		await _close_all()
		hub.player.pos = w.pos + Vector2(0.5, 0.0)
		hub.player.try_interact()
		await _wait(4)
		_expect(ui.has_modal(), "talking to a resident opens a dialogue")
		await _finish_dialogue()
		var rid := String(w.def.id)
		_expect(Residents.request_state(rid) == "active", "%s's request starts after the conversation" % rid)
		var req: Dictionary = w.def.request
		Residents.note(String(req.key), int(req.goal))
		_expect(Residents.request_state(rid) == "complete", "the request completes")
		hub._talk_to(w)
		await _finish_dialogue()
		_expect(Residents.request_state(rid) == "rewarded", "handing it in grants the gift")
	await _gear_checks(hub)
	print("[smoke] respec: ", Profile.respec(), " skills after: ", Profile.skills())
	print("[smoke] done")
	get_tree().quit()


## Advances a dialogue with the confirm button until it closes.
func _finish_dialogue() -> void:
	for i in 16:
		if not ui.has_modal():
			return
		await _pad(JOY_BUTTON_A)
	await _close_all()


## Satchel, smithy and peddler through their screens.
func _gear_checks(hub: Hub) -> void:
	Profile._grant_stockpile(Profile.data)
	if Profile.building("forge") == 0:
		Profile.data.sanctuary.forge = 1
	ui.inventory()
	await _wait()
	var inv: InventoryUI = ui.modals[ui.modals.size() - 1].get_child(0)
	var it: Dictionary = Profile.bag()[0]
	var slot := String(ItemDB.base(String(it.base)).slot)
	inv._equip(int(it.uid))
	await _wait(3)
	_expect(Profile.equipped().get(slot, {}).get("uid", -1) == it.uid, "equipping from the satchel")
	var before := hub.player.max_hp
	await _close_all()
	_expect(hub.player.max_hp >= before, "closing the satchel applies gear stats")
	ui.smithy()
	await _wait()
	var sm: SmithyUI = ui.modals[ui.modals.size() - 1].get_child(0)
	var n := Profile.bag().size()
	sm.selected = "grave_iron_helm"
	sm._craft(false)
	await _wait(2)
	_expect(Profile.bag().size() == n + 1, "the smith forges a piece")
	var crafted: Dictionary = Profile.bag().back()
	sm._craft(true)
	await _wait(2)
	_expect(String(Profile.bag().back().rarity) == "epic", "a masterwork is epic")
	sm.tab = "temper"
	sm.selected = str(int(crafted.uid))
	sm.rebuild()
	await _wait(2)
	var cost := ItemDB.temper_cost(crafted)
	_expect(Profile.can_pay(cost), "tempering is affordable with the stockpile")
	var lvl := int(crafted.level)
	if Profile.pay(cost):
		crafted.level = lvl + 1
	_expect(int(Profile.find_item(int(crafted.uid)).level) == lvl + 1, "tempering raises the level")
	var mats := Profile.material("grave_iron")
	Profile.salvage(int(crafted.uid))
	_expect(Profile.material("grave_iron") > mats, "salvage returns grave iron")
	await _close_all()
	ui.peddler()
	await _wait()
	var pd: PeddlerUI = ui.modals[ui.modals.size() - 1].get_child(0)
	var stock_n := (Profile.data.shop.stock as Array).size()
	_expect(stock_n == PeddlerUI.STOCK_SIZE, "the peddler has wares")
	var embers := Profile.currency("embers")
	pd._buy(0)
	await _wait(2)
	_expect((Profile.data.shop.stock as Array).size() == stock_n - 1 and Profile.currency("embers") < embers, "buying from the peddler")
	var sell_uid := int(Profile.bag().back().uid)
	if String(Profile.bag().back().rarity) not in ["epic", "legendary"]:
		pd._sell(sell_uid)
		await _wait(2)
		_expect(Profile.find_item(sell_uid).is_empty(), "selling to the peddler")
	await _close_all()


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("[smoke] ok: ", what)
	else:
		push_error("[smoke] FAILED: " + what)


func _pad(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(2)
	var r := InputEventJoypadButton.new()
	r.button_index = button
	r.pressed = false
	Input.parse_input_event(r)
	await _wait(2)


func _mouse_to(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.relative = Vector2(20, 0)
	Input.parse_input_event(e)
	Input.warp_mouse(p * get_window().content_scale_factor)
	await _wait(3)


## The Kindled turns to the mouse and swings where it points.
func _aim_checks(pl: Player) -> void:
	var view: PixelView = pl.stage.view
	var me := view.internal_to_screen(view.world_to_internal(pl.global_position))
	await _mouse_to(me + Vector2(-120, 0))
	_expect(pl.aim.x < -0.7, "mouse to the left aims left (%s)" % pl.aim)
	await _mouse_to(me + Vector2(120, 0))
	_expect(pl.aim.x > 0.7, "mouse to the right aims right (%s)" % pl.aim)
	await _mouse_to(me + Vector2(0, -100))
	_expect(pl.aim.y < -0.7, "mouse above aims up (%s)" % pl.aim)
	_expect(pl.facing.y < -0.7, "the Kindled faces the mouse")
	pl.weapon.press()
	pl.weapon.release()
	await _wait(20)
	_expect(pl.weapon.aim_dir.y < -0.7, "the swing goes where the mouse points (%s)" % pl.weapon.aim_dir)


## Drives menus and the world through real (synthetic) gamepad events.
func _pad_checks(d: Dungeon, pl: Player) -> void:
	var spring := Prop.make(d, "spring", Vector2i(pl.pos) + Vector2i(1, 0))
	pl.pos = spring.pos + Vector2(-0.9, 0.0)
	pl.hp = pl.max_hp * 0.5
	# the world ignores presses for 220 ms after a screen closes (so the press
	# that closed it does not act too); at smoke-test frame rates a few frames
	# are far shorter than that, so wait it out like a player would
	while ui.just_closed():
		await _wait(1)
	await _pad(JOY_BUTTON_B)
	_expect(Settings.using_pad, "pad detected")
	_expect(spring.used, "B interacts with a nearby spring")
	ui.pause_menu()
	await _wait()
	var f := get_viewport().gui_get_focus_owner()
	_expect(f != null and ui.modals[ui.modals.size() - 1].is_ancestor_of(f), "pause menu takes pad focus")
	ui.settings()
	await _wait()
	var sui: SettingsUI = ui.modals[ui.modals.size() - 1].get_child(0)
	var before: String = sui.page
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(sui.page != before, "RB switches the settings page (%s -> %s)" % [before, sui.page])
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	f = get_viewport().gui_get_focus_owner()
	_expect(f != null and sui._rows.is_ancestor_of(f), "right moves focus from the rail into the page")
	await _pad(JOY_BUTTON_B)
	_expect(ui.modals.size() == 1, "B closes settings")
	await _pad(JOY_BUTTON_B)
	_expect(ui.modals.is_empty() and not get_tree().paused, "B closes the pause menu and resumes")
	ui.skill_tree()
	await _wait()
	await _pad(JOY_BUTTON_B)
	_expect(ui.modals.is_empty(), "B closes the skill tree")
	ui.pause_menu()
	await _wait()
	var dodges := pl.dodge_t
	await _pad(JOY_BUTTON_A)
	_expect(ui.modals.is_empty(), "A presses the focused Resume button")
	await _wait(2)
	_expect(pl.dodge_t <= dodges, "the A that closed the menu does not also dodge")


func _find_tabs(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is TabContainer:
			out.append(c)
		_find_tabs(c, out)
