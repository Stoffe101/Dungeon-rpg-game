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


func _press_all(label: String) -> void:
	if ui.modals.is_empty():
		return
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
		hub.player.pos = w.pos + Vector2(0.5, 0.0)
		hub.player.try_interact()
		await _wait(4)
		_expect(ui.has_modal(), "talking to a resident opens a dialogue")
		await _close_all()
	print("[smoke] respec: ", Profile.respec(), " skills after: ", Profile.skills())
	print("[smoke] done")
	get_tree().quit()


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


## Drives menus and the world through real (synthetic) gamepad events.
func _pad_checks(d: Dungeon, pl: Player) -> void:
	var spring := Prop.make(d, "spring", Vector2i(pl.pos) + Vector2i(1, 0))
	pl.pos = spring.pos + Vector2(-0.9, 0.0)
	pl.hp = pl.max_hp * 0.5
	await _pad(JOY_BUTTON_B)
	_expect(Settings.using_pad, "pad detected")
	_expect(spring.used, "B interacts with a nearby spring")
	ui.pause_menu()
	await _wait()
	var f := get_viewport().gui_get_focus_owner()
	_expect(f != null and ui.modals[ui.modals.size() - 1].is_ancestor_of(f), "pause menu takes pad focus")
	ui.settings()
	await _wait()
	var tabs: Array = []
	_find_tabs(ui.modals[ui.modals.size() - 1], tabs)
	var before: int = tabs[0].current_tab
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(tabs[0].current_tab == (before + 1) % tabs[0].get_tab_count(), "RB switches the settings tab")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	f = get_viewport().gui_get_focus_owner()
	_expect(f != null and tabs[0].get_current_tab_control().is_ancestor_of(f), "focus moves inside the new tab")
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
