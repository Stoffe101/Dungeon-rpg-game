## Dev (`scenario=<name> role=host|guest`): plays a co-op journey the way a
## person does - real key presses and mouse clicks through Input (the same
## path the keyboard takes: bindings, UI focus, the Kindled's polling), real
## buttons clicked where they are drawn - in separate game processes talking
## over the real network. Checks what each machine actually has on screen
## (layers, replicas, sprites, positions), saves matched captures from every
## machine at once (Net.dev_shot), and logs positions as `[probe]` lines for
## tools/dev/e2e_compare.py. Ends with `[scenario] RESULT <role>: n passed,
## m failed` and quits (exit 1 on a failure). See tools/dev/e2e.sh.
##
## Scenarios:
##   journey  - the whole evening: host and join through the party screen,
##              the shared sanctuary, talking (keys, clicks, mashing, Esc, a
##              request accepted), changing gear, an expedition proposed,
##              declined, withdrawn, proposed again and accepted, depth 1
##              (foes on every screen, a room sealing with a friend outside),
##              the stairs to depths 2 and 3 with everyone walking on their own
##              keys, a Hearthcall home, and a second expedition.
##   talk     - solo: the dialogue checks alone.
class_name Scenario
extends Node

var role := "host"
var scen := ""
var guests := 1               # host: how many guests to wait for
var passed := 0
var failed := 0
var _held := {}               # action -> true while held down
var _probe_t := 0.0
var _t0 := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in Dev.args():
		if a.begins_with("scenario="):
			scen = a.substr(9)
		elif a.begins_with("role="):
			role = a.substr(5)
		elif a.begins_with("guests="):
			guests = int(a.substr(7))
	_t0 = now()
	_run.call_deferred()


func _process(delta: float) -> void:
	_probe_t += delta
	if _probe_t >= 0.25:
		_probe_t = 0.0
		_probe()


func _run() -> void:
	await wait(1.5)
	match scen:
		"journey":
			await journey()
		"talk":
			await talk_checks("solo")
		"stairs":
			await stairs_only()
		"sites":
			await sites()
		"ways":
			await ways()
		"deep":
			await deep()
		"depthworld":
			await depthworld()
		"guardian":
			await guardian()
		"bestiary":
			await bestiary()
		"partyhud":
			await party_hud()
		"facing":
			await facing()
		"landmark":
			await landmark()
		"spells":
			await spells()
		"loot":
			await loot()
		"partystart":
			await party_start()
		"partyesc":
			await _skip_intro()
			Game.ui.party()
			await wait(0.6)
			await click_button("Host")
			await wait(1.5)
			print("[scenario] modals before Esc: ", Game.ui.modals.map(func(m): return [m.get_meta("kind", "?"), m.get_child(0).get_class() if m.get_child_count() > 0 else "-"]))
			tap("pause")
			await wait(0.5)
			print("[scenario] modals after Esc: ", Game.ui.modals.map(func(m): return m.get_meta("kind", "?")))
			expect(Game.ui.modal_of("party") == null, "Esc closes the party screen")
		_:
			fail("no such scenario: %s" % scen)
	release_all()
	print("[scenario] RESULT %s: %d passed, %d failed" % [role, passed, failed])
	await wait(2.0)
	get_tree().quit(0 if failed == 0 else 1)


# --- the journey ------------------------------------------------------------------------

func journey() -> void:
	await until(func() -> bool: return Game.stage is Hub and not (Game.stage as Hub).menu_mode and Game.stage.player != null, 20.0, "in the sanctuary")
	await _skip_intro()
	if role == "host":
		await host_party()
	else:
		await join_party()
	# the shared sanctuary
	var want := guests if role == "host" else 1
	await until(func() -> bool: return hub() != null and hub().sync != null and hub().sync.others.size() >= want, 25.0, "the party's Kindled are in my sanctuary (%d)" % want)
	await wait(1.0)
	if role == "host":
		Net.i.dev_shot("e2e/01_hub_together")
	await wait(1.0)
	await walk_to(Vector2(20.5, 15.5) if role == "host" else Vector2(23.5, 16.0), 0.5, 10.0)
	await wait(0.8)
	if role == "host":
		Net.i.dev_shot("e2e/02_hub_moved")
	await wait(0.6)
	check_others_in_place()
	# what each Kindled wears, as the others see it (then a change, live)
	await gear_checks()
	# talking
	await talk_checks(role)
	# the expedition
	await expedition()
	# below
	await below()


## A fresh profile is greeted by the Keeper first: hear them out (Esc).
func _skip_intro() -> void:
	await wait(1.2)
	if Game.ui.modal_of("dialogue") != null:
		tap("pause")
		await wait(0.4)


func hub() -> Hub:
	return Game.stage as Hub if Game.stage is Hub and not (Game.stage as Hub).menu_mode else null


func host_party() -> void:
	Game.ui.party()
	await wait(0.6)
	expect(Game.ui.modal_of("party") != null, "the party screen opens")
	Capture.save_now("e2e/00_party_start_%s" % _tag())
	await click_button("Host")
	await until(func() -> bool: return Net.is_host(), 10.0, "hosting")
	await wait(0.5)
	Capture.save_now("e2e/00_party_hosting_%s" % _tag())
	await until(func() -> bool: return Net.party_size() >= guests + 1, 40.0, "%d guest(s) joined" % guests)
	await wait(0.6)
	Capture.save_now("e2e/00_party_full_%s" % _tag())
	tap("pause")
	await wait(0.4)
	expect(Game.ui.modal_of("party") == null, "Esc closes the party screen")


func join_party() -> void:
	await wait(1.0 + float(Net.i.get_instance_id() % 5) * 0.1)
	Game.ui.party()
	await wait(0.6)
	await click_button("Enter address")
	await wait(0.3)
	var le := find_control(func(c: Control) -> bool: return c is LineEdit and (c as LineEdit).placeholder_text != "") as LineEdit
	expect(le != null, "the address field is shown")
	if le:
		le.text = "127.0.0.1"
		le.text_changed.emit(le.text)
	Capture.save_now("e2e/00_party_address_%s" % _tag())
	await click_button("Join")
	await until(func() -> bool: return Net.is_client() and Net.i.roster.has(Net.my_id()), 15.0, "joined the party")
	# the sanctuary becomes the host's (a short fade)
	await until(func() -> bool: return hub() != null and not Net.i.camp.is_empty() and hub().camp == Net.i.camp, 10.0, "walking the host's camp")
	await wait(0.8)
	if Game.ui.modal_of("party") == null:
		Game.ui.party()
		await wait(0.5)
	Capture.save_now("e2e/00_party_joined_%s" % _tag())
	tap("pause")
	await wait(0.4)
	expect(Game.ui.modal_of("party") == null, "Esc closes the party screen")


## Every other Kindled stands where its owner says it does (the probe lines
## compare it exactly; here: drawn, and not frozen at its arrival).
func check_others_in_place() -> void:
	var h := hub()
	if h == null or h.sync == null:
		fail("no shared sanctuary")
		return
	for pid in h.sync.others:
		var pl: Player = h.sync.others[pid]
		expect(is_instance_valid(pl) and pl.sprite.visible and pl.visual.visible, "%s is drawn" % Net.name_of(int(pid)))
		var dis: Variant = pl.sprite.get_instance_shader_parameter("dissolve")
		expect(dis == null or float(dis) < 0.2, "%s is solid, not dissolved" % Net.name_of(int(pid)))
		expect(not pl.gear_layers.is_empty() or GearLooks.paperdoll(pl.sheet.get("equipped", {}), pl.sheet.get("shown", {})).is_empty(),
			"%s wears their own armour layers" % Net.name_of(int(pid)))


func gear_checks() -> void:
	var h := hub()
	# everyone's replicas wear what that player's sheet says
	for pid in h.sync.others:
		var pl: Player = h.sync.others[pid]
		var want := GearLooks.paperdoll(pl.sheet.get("equipped", {}), pl.sheet.get("shown", {}))
		var have := {}
		for slot in pl.gear_layers:
			have[slot] = (pl.gear_layers[slot] as PixelSprite).sheet.name
		expect(have == want, "%s's armour as drawn here matches their sheet (%s)" % [Net.name_of(int(pid)), str(want.values())])
	# a guest changes what it shows: a helm hidden, the chest from the wardrobe
	if role == "guest" and Net.my_id() == _first_guest():
		var sh: Dictionary = Profile.inv().get("shown", {})
		sh["head"] = "none"
		Profile.inv()["shown"] = sh
		Profile.mark_changed()
		h.player.refresh_paperdoll()
		print("[scenario] hid my helm")
	await wait(2.0)
	if role == "host":
		var g := _first_guest()
		var gp: Player = h.sync.others.get(g)
		if gp:
			expect(not gp.gear_layers.has("head"), "the guest's hidden helm is gone on my screen too")
			expect(String(gp.sheet.get("shown", {}).get("head", "")) == "none", "the guest's sheet arrived live")
		Net.i.dev_shot("e2e/03_hub_gear_changed")
	await wait(1.0)


func _first_guest() -> int:
	var best := 0
	for pid in Net.i.roster:
		if int(pid) != 1 and (best == 0 or int(Net.i.roster[pid].slot) < int(Net.i.roster[best].slot)):
			best = int(pid)
	return best


# --- talking ------------------------------------------------------------------------------

## The dialogue checks: F opens one conversation; mashing F turns pages and
## closes it without opening another; no dimmed layer is left; Esc closes;
## a click on someone talks; a request is accepted once.
func talk_checks(tag: String) -> void:
	var h := hub()
	if h == null:
		fail("not in the sanctuary")
		return
	var keeper: Prop = null
	for p in h.props:
		if is_instance_valid(p) and p.kind == "keeper":
			keeper = p
	await walk_to(keeper.pos + Vector2(0.4 if role != "guest" else -0.4, 1.0), 0.35, 12.0)
	await wait(0.3)
	tap("interact")
	await wait(0.5)
	expect(Game.ui.modal_of("dialogue") != null, "[%s] F opens the Keeper's words" % tag)
	expect(Game.ui.layer_count() == 1, "[%s] one layer on screen (got %d)" % [tag, Game.ui.layer_count()])
	Capture.save_now("e2e/04_dialogue_open_%s" % _tag())
	# mashing F: pages turn, no second conversation stacks up
	var most := 0
	for k in 40:
		if Game.ui.modal_of("dialogue") == null:
			break
		tap("interact", 0.03)
		await wait(0.07)
		most = maxi(most, Game.ui.layer_count())
	expect(most <= 1, "[%s] mashing F never stacks a second layer (most %d)" % [tag, most])
	await until(func() -> bool: return Game.ui.modal_of("dialogue") == null, 6.0, "[%s] the conversation ends" % tag)
	await wait(0.6)
	expect(Game.ui.layer_count() == 0, "[%s] nothing left over the world after it closes" % tag)
	Capture.save_now("e2e/05_dialogue_closed_%s" % _tag())
	# Esc closes at once, and the next F talks again
	await wait(0.4)
	# (waits on the result, not a fixed time: four game windows on one PC run
	# each other slow, and the dialogue can open half a second after F)
	tap("interact")
	if not await until(func() -> bool: return Game.ui.modal_of("dialogue") != null, 2.0, "[%s] F talks again" % tag):
		return
	await wait(0.2)
	tap("pause")
	await until(func() -> bool: return Game.ui.modal_of("dialogue") == null and Game.ui.layer_count() == 0, 2.0, "[%s] one Esc closes it" % tag)
	await wait(0.5)
	expect(Game.ui.modal_of("dialogue") == null, "[%s] and it does not reopen" % tag)
	# a click on the Keeper
	await wait(0.4)
	await click_world(keeper.pos + Vector2(0, -0.3))
	# (out of reach - a crowd of Kindled round the Keeper - the click first
	# walks the Kindled over, then talks)
	await until(func() -> bool: return Game.ui.modal_of("dialogue") != null, 3.0, "[%s] a click on the Keeper talks" % tag)
	tap("pause")
	await wait(0.4)
	expect(Game.ui.layer_count() == 0, "[%s] closed again" % tag)
	_clear_screens(tag)
	# a resident with a request: accept it (the conversation's choice)
	var res: Wanderer = null
	for w in h.residents:
		if is_instance_valid(w) and Residents.present(String(w.def.id)) and Residents.request_state(String(w.def.id)) == "" and not (w.def.get("request", {}) as Dictionary).is_empty():
			res = w
	if res == null:
		print("[scenario] no resident with a request to accept here (fine on a used profile)")
		return
	var rid := String(res.def.id)
	var who := String(res.def.name)
	var speaking := func() -> bool:
		var dlg := Game.ui.modal_of("dialogue")
		return dlg != null and String(dlg.get_meta("speaker", "")).begins_with(who)
	for attempt in 4:
		# up to them (they wander), then a click on them - the one under the pointer talks
		var near := res.pos + (res.pos - Game.stage.player.pos).normalized() * -1.0
		await walk_to(Game.stage.random_floor_near(near, 0.4), 0.5, 6.0)
		await click_world(res.pos + Vector2(0, -0.4))
		await wait(0.5)
		if speaking.call():
			break
		_clear_screens(tag)
	expect(speaking.call(), "[%s] %s talks (a click on them)" % [tag, who])
	for k in 14:
		if find_control(func(c: Control) -> bool: return c is Button and (c as Button).text == "Accept" and c.is_visible_in_tree()) != null:
			break
		if not speaking.call():
			break
		tap("interact", 0.03)
		await wait(0.25)
	Capture.save_now("e2e/06_request_offer_%s" % _tag())
	await click_button("Accept")
	await wait(0.6)
	expect(Residents.request_state(rid) == "active", "[%s] the request was accepted (%s)" % [tag, Residents.request_state(rid)])
	expect(Game.ui.layer_count() == 0, "[%s] and the screen is clear" % tag)
	_clear_screens(tag)


## Whatever a failed step left open is closed (and counted), so one miss
## does not take the rest of the run with it.
func _clear_screens(tag: String) -> void:
	if Game.ui.has_modal() and not Game.ui.get_meta("menu", false):
		fail("[%s] a screen was left open (%d layers)" % [tag, Game.ui.layer_count()])
		Game.ui.close_all()


# --- the expedition -----------------------------------------------------------------------

func expedition() -> void:
	var h := hub()
	if role == "host":
		await propose_at_gate()
		await until(func() -> bool: return not Net.i.proposal.is_empty(), 5.0, "my proposal is open")
		# a guest says not now; I withdraw; then propose again
		await until(func() -> bool: return Net.i.proposal.is_empty() or (Net.i.proposal.answers as Dictionary).values().has("no"), 25.0, "a guest answered Not now")
		await wait(1.0)
		Net.i.dev_shot("e2e/08_proposal_declined")
		await wait(1.0)
		tap("party_no")     # the proposer's N withdraws it
		await until(func() -> bool: return Net.i.proposal.is_empty(), 5.0, "withdrawn")
		await wait(2.0)
		await propose_at_gate()
		await until(func() -> bool: return Net.i.proposal.is_empty() or float(Net.i.proposal.get("launch_in", -1.0)) > 0.0, 25.0, "everyone ready: the countdown")
		await wait(0.6)
		Net.i.dev_shot("e2e/09_proposal_countdown")
	else:
		await until(func() -> bool: return not Net.i.proposal.is_empty(), 60.0, "a proposal reached me")
		await wait(1.0)
		var card := RequestCard.ensure(Game.ui)
		expect(card.visible and card.mode == "proposal", "the request card shows it")
		expect(Game.ui.layer_count() == 0 and not Game.ui.blocks_world(), "it does not take my hands")
		if Net.my_id() == _first_guest():
			Net.i.dev_shot("e2e/07_proposal_received")
			await wait(1.0)
			tap("party_no")
			await until(func() -> bool: return Expedition.my_answer() == "no" or Net.i.proposal.is_empty(), 5.0, "N says Not now")
		await until(func() -> bool: return Net.i.proposal.is_empty(), 25.0, "the host withdrew it")
		await until(func() -> bool: return not Net.i.proposal.is_empty(), 25.0, "proposed again")
		await wait(0.8 + 0.3 * (Net.my_id() % 3))
		tap("party_yes")
		await until(func() -> bool: return Expedition.my_answer() == "yes" or Net.i.proposal.is_empty(), 5.0, "Y says Ready")
	await until(func() -> bool: return Game.stage is Dungeon and Game.run != null, 25.0, "the party went down together")
	expect(Game.run != null and Game.run.depth == 1, "depth 1")


func propose_at_gate() -> void:
	var h := hub()
	await walk_to(h.gate_prop.pos + Vector2(0, 1.6), 0.6, 12.0)
	tap("interact")
	await wait(0.6)
	expect(Game.ui.modal_of("") != null or Game.ui.has_modal(), "the gate opens the Descent")
	await click_button("Propose expedition", "Update proposal")
	await wait(0.5)


# --- below --------------------------------------------------------------------------------

func dun() -> Dungeon:
	return Game.stage as Dungeon if Game.stage is Dungeon else null


func below() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim and Game.ui.card_pending == false, 20.0, "depth 1 under way")
	await wait(1.0)
	expect(dun().players.size() == guests + 1 if role == "host" else dun().players.size() >= 2, "every Kindled is on the floor")
	# the host fights its way in (the bot); the guest stays put at first, so a
	# sealing room has to draw it in
	if role == "host":
		dun().player.add_child(Bot.new())
		await until(func() -> bool: return dun().active_room != null, 60.0, "a fight began")
		await wait(1.6)
		Net.i.dev_shot("e2e/10_fight_starts")
		_check_regroup()
		await wait(2.5)
		Net.i.dev_shot("e2e/11_fight")
	else:
		await until(func() -> bool: return _enemies().size() > 0, 70.0, "foes reached my screen")
		await wait(1.6)
		_check_enemies_drawn()
		await wait(1.0)
		# drawn in by the light: I can move (real keys)
		var p0 := dun().player.pos
		await walk_dir(Vector2(1, 0), 0.6)
		var moved := dun().player.pos.distance_to(p0)
		await walk_dir(Vector2(-1, 0), 0.6)
		expect(moved > 0.3, "I can move after the room drew me in (%.2f tiles)" % moved)
		dun().player.add_child(Bot.new())
	# fight a while, then the stairs (each floor: both walk on their own keys)
	for depth in [2, 3]:
		await wait(8.0)
		_strip_bot()     # (a bot answers votes by itself: the person does it here)
		await wait(2.0)
		# the Forked Descent: the party takes the first way this floor offers
		# (the same two on every machine), and every machine must arrive on it
		var offer: Array = dun().layout.offer.duplicate() if dun() else []
		if role == "host":
			if Net.i.run_sync:
				var sp: Prop = null
				for p in dun().props:
					if is_instance_valid(p) and p.kind == "stairs" and not offer.is_empty() and String(p.data.get("route", "")) == String(offer[0]):
						sp = p
				if sp:
					Net.i.run_sync.start_vote("stairs:" + String(offer[0]), sp.net_idx, dun().player)
				else:
					Net.i.run_sync.start_vote("stairs", -1, dun().player)
		else:
			await until(func() -> bool: return RequestCard.ensure(Game.ui).mode == "vote", 30.0, "the stairs vote reached me")
			await wait(0.6)
			if Net.my_id() == _first_guest():
				Net.i.dev_shot("e2e/12_vote_d%d" % depth)
			await wait(0.4)
			tap("party_yes")
		var want_depth: int = depth
		await until(func() -> bool: return dun() != null and Game.run != null and Game.run.depth == want_depth and not dun().paused_sim and not Game.ui.card_pending, 30.0, "down to depth %d together" % depth)
		if not offer.is_empty() and dun():
			expect(Game.run.route == String(offer[0]) and dun().layout.route == String(offer[0]), "down the way the party chose (%s: run %s, floor %s)" % [offer[0], Game.run.route, dun().layout.route])
			print("[scenario] depth %d via %s: %d rooms" % [depth, dun().layout.route, dun().layout.rooms.size()])
		await walk_check(depth)
		if dun() and role == "host":
			dun().player.add_child(Bot.new())
	# home: a Hearthcall everyone agrees to
	await wait(6.0)
	if role == "host":
		_strip_bot()
		# (what a completed Hearthcall starts in a party)
		if Net.i.run_sync:
			Net.i.run_sync.start_vote("hearthcall", -1, dun().player)
	else:
		await until(func() -> bool: return RequestCard.ensure(Game.ui).mode == "vote", 40.0, "the Hearthcall vote reached me")
		_strip_bot()
		tap("party_yes")
	await until(func() -> bool: return Game.run == null or Game.run.result != "", 40.0, "the party went home")
	await wait(2.5)
	Capture.save_now("e2e/16_summary_%s" % _tag())
	await click_button("Return to the Sanctuary")
	await until(func() -> bool: return hub() != null, 20.0, "back in the sanctuary")
	await until(func() -> bool: return hub().sync != null and hub().sync.others.size() >= (guests if role == "host" else 1), 30.0, "together in the sanctuary again")
	await wait(1.0)
	if role == "host":
		Net.i.dev_shot("e2e/17_home_again")
		await wait(1.0)
		await propose_at_gate()
	else:
		await until(func() -> bool: return not Net.i.proposal.is_empty(), 40.0, "a second proposal")
		await wait(0.5)
		tap("party_yes")
	await until(func() -> bool: return dun() != null and Game.run != null and Game.run.depth == 1 and not dun().paused_sim, 30.0, "a second expedition began")
	await wait(2.0)
	if role == "host":
		Net.i.dev_shot("e2e/18_second_expedition")
	await wait(2.0)


## The party HUD on every screen: in the sanctuary, below in a fight, with a
## Kindled down (then raised), and after a level gained mid-expedition.
func party_hud() -> void:
	await until(func() -> bool: return hub() != null and hub().sync != null and hub().sync.others.size() >= (guests if role == "host" else 1), 40.0, "the party gathered")
	await _skip_intro()
	await wait(1.5)
	if role == "host":
		Net.i.dev_shot("hud/01_sanctuary")
	if not await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending, 60.0, "below together"):
		return
	await wait(1.0)
	var hud: HUD = Game.ui.hud
	expect(hud.party != null and hud.party.visible, "the party cards are on screen")
	expect(hud.party != null and hud.party._cards.size() == Net.party_size() - 1, "one card for every other Kindled")
	dun().player.add_child(Bot.new())
	await until(func() -> bool: return dun().active_room != null or _enemies().size() > 0, 60.0, "a fight")
	await wait(2.0)
	if role == "host":
		Net.i.dev_shot("hud/02_fight")
	await wait(1.0)
	# a Kindled goes down (the host decides), then gets up again
	if role == "host":
		var g := _first_guest()
		for pl in dun().players:
			if pl.peer_id == g and pl.alive:
				pl._go_down()
		await wait(1.2)
		Net.i.dev_shot("hud/03_downed")
		await wait(0.6)
		for pl in dun().players:
			if pl.peer_id == g and pl.downed:
				pl.revive_k = 1.0
		# the host gains a level: everyone's card for the host says so
		Profile.add_xp(Combat.xp_to_next(Profile.level()))
		await wait(2.0)
		Net.i.dev_shot("hud/04_level_up")
	else:
		await wait(4.5)
		var host_lv := int(Net.i.roster.get(1, {}).get("sheet", {}).get("level", 0))
		expect(host_lv >= 2, "the host's new level reached my screen (Lv %d)" % host_lv)
	await wait(2.0)


## WASD turns the Kindled: real key presses with the pointer parked to the
## right, each direction checked on this machine (frames and mirror) and
## captured; stopping keeps the facing; an attack while walking away faces the
## aim; a dodge faces its way. In a party (DEVNET) every machine then walks a
## direction of its own and checks the others are drawn facing theirs - in
## the sanctuary and below.
func facing() -> void:
	# (a party is made by the dev flow's net= switch; Net starts a moment later)
	var party: bool = Array(Dev.args()).any(func(a): return String(a).begins_with("net="))
	if party:
		await until(func() -> bool: return hub() != null and hub().sync != null and hub().sync.others.size() >= (guests if role == "host" else 1), 40.0, "the party gathered")
		await _skip_intro()
		_park_pointer(Vector2(1, 0))
		await _others_face("sanctuary")
		# the dev host proposes the expedition as soon as everyone is in: below
		if not await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending, 60.0, "below together"):
			return
	else:
		await until(func() -> bool: return Game.stage != null and Game.stage.player != null, 20.0, "a Kindled")
		await _skip_intro()
	await wait(1.0)
	var st := Game.stage
	var pl: Player = st.player
	_park_pointer(Vector2(1, 0))
	for k in [[Vector2.UP, "up", false, "w"], [Vector2.DOWN, "down", false, "s"], [Vector2.LEFT, "side", true, "a"], [Vector2.RIGHT, "side", false, "d"],
			[Vector2(-1, -1), "side", true, "wa_after_a"], [Vector2(0, -1), "up", false, "w2"], [Vector2(-1, -1), "up", false, "wa_after_w"]]:
		steer(k[0])
		await wait(0.45)
		expect(pl.sprite.anim == "run_" + String(k[1]) and pl.sprite.flip_h == bool(k[2]),
			"%s walks %s (%s, mirrored %s)" % [k[3], k[1], pl.sprite.anim, pl.sprite.flip_h])
		_shot("facing/%s_%s" % [role, k[3]])
	steer(Vector2.LEFT)
	await wait(0.4)
	steer(Vector2.ZERO)
	await wait(0.6)
	expect(pl.sprite.anim == "idle_side" and pl.sprite.flip_h, "stopping after A keeps facing left with the pointer on the right (%s, %s)" % [pl.sprite.anim, pl.sprite.flip_h])
	_shot("facing/%s_stop_left" % role)
	# fighting faces the aim, even walking away from it
	steer(Vector2.LEFT)
	await wait(0.25)
	tap("attack")
	await wait(0.12)
	expect(pl.look.x > 0.5 and not pl.sprite.flip_h, "attacking while walking left faces the pointer on the right (look %s)" % pl.look)
	_shot("facing/%s_attack_back" % role)
	await wait(0.6)
	steer(Vector2.ZERO)
	await wait(0.3)
	# a dodge faces where it goes
	steer(Vector2.LEFT)
	await wait(0.05)
	tap("dodge")
	await wait(0.06)
	expect(pl.sprite.anim == "dash_side" and pl.sprite.flip_h, "a dodge to the left faces left (%s, %s)" % [pl.sprite.anim, pl.sprite.flip_h])
	steer(Vector2.ZERO)
	await wait(0.6)
	if party:
		await _others_face("below")


## A landmark in a party (dev switch `landmark`: every floor has one): the
## host brings everyone to it (its fight counted as won), the first guest
## walks up and presses F, and every machine checks it answered - its sprite
## woken and, for the Bone Colossus, every room on that machine's own map.
func landmark() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending, 90.0, "below together")
	await wait(1.0)
	_strip_bot()
	var d := dun()
	var lm: Prop = null
	for p in d.props:
		if is_instance_valid(p) and p.kind == "landmark":
			lm = p
	expect(lm != null, "this floor has a landmark")
	if lm == null:
		return
	var lid := String(lm.data.get("id", ""))
	if role == "host":
		var r := d.layout.room_at_point(lm.pos)
		r.cleared = true
		var k := 0
		for pl in d.players:
			pl.pos = d.random_floor_near(lm.pos + Vector2(-2.0 + 2.0 * k, 2.6), 0.4)
			pl.vel = Vector2.ZERO
			k += 1
	var me := Net.my_id() == _first_guest()
	if not await until(func() -> bool: return d.player.pos.distance_to(lm.pos) < 4.0, 20.0, "brought to the landmark"):
		return
	await wait(1.2)
	var m: Dictionary = d.fx._marks.get(lm.get_instance_id(), {})
	expect(not m.is_empty() and (m.name as Label).text == lm.label_name() and lm.label_name() != "", "its name is over it here (%s)" % lm.label_name())
	if me:
		# walk the last step on my own keys, then F
		await walk_to(lm.pos + Vector2(0, 1.4), 0.5, 6.0)
		release_all()
		await wait(0.4)
		var near := d.nearest_interactable(d.player.pos)
		expect(near == lm, "the landmark is what F would use (%s)" % (near.kind if near else "nothing"))
		tap("interact")
	var state: String = {"colossus": "woken", "heartroot": "fed", "sundisc": "lit"}.get(lid, "")
	await until(func() -> bool: return lm.sprite.anim == state, 10.0, "%s answers on this screen" % lm.label_name())
	if lid == "colossus":
		expect(d.remembered(), "every room is on this machine's map")
	if role == "host":
		Net.i.dev_shot("landmark/%s_answered" % lid)
	await wait(2.5)


## The new spells and weapon forms in a party (DEVNET=1 with XARGS=build=wall
## or build=pyreblade): the first guest casts on its own keys and every
## machine checks what it sees - a Rimewall's ice (and its pillar tiles), its
## melting; Hearthfire Form's glow on that Kindled; the Emberforge Mallet's
## heat (the host's) on the guest's own gauge.
func spells() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending, 90.0, "below together")
	await wait(1.0)
	_strip_bot()
	var d := dun()
	var me := Net.my_id() == _first_guest()
	var guest: Player = null
	for p in d.players:
		if p.peer_id == _first_guest():
			guest = p
	expect(guest != null, "the first guest's Kindled is here")
	if guest == null:
		return
	var slots: Array = d.player.ability_slots
	_park_pointer(Vector2(1, 0))
	# a floor starts with no Kindle: the host (whose word it is) fills everyone's
	if role == "host":
		for p in d.players:
			p.kindle = p.kindle_max()
	await until(func() -> bool: return d.player.kindle >= 50.0, 6.0, "Kindle to cast with")
	if slots.has("rimewall"):
		if me:
			tap("ability_%d" % (slots.find("rimewall") + 1))
		await until(func() -> bool: return _ice(d).size() >= 3, 6.0, "a guest's Rimewall rises on this screen")
		var walls := _ice(d)
		if not walls.is_empty():
			var t: Vector2i = walls[0].tile
			expect(d.grid.at(t.x, t.y) == TileGrid.PILLAR, "its tiles stop foes and shots here too")
		if role == "host":
			Net.i.dev_shot("spells/rimewall")
		await until(func() -> bool: return _ice(d).is_empty(), 9.0, "and it melts on this screen")
		if not walls.is_empty() and is_instance_valid(d):
			pass
	if slots.has("hearthfire"):
		if role == "host":
			for p in d.players:
				p.kindle = p.kindle_max()
		await wait(0.5)
		if me:
			tap("ability_%d" % (slots.find("hearthfire") + 1))
		await until(func() -> bool: return guest.hearthfire_t > 0.0, 5.0, "the guest is hearth-fire on this screen")
		await wait(0.3)
		expect(guest.sprite.highlight.a > 0.15, "and burns there (glow %.2f)" % guest.sprite.highlight.a)
		if role == "host":
			Net.i.dev_shot("spells/hearthfire")
		# the Mallet's heat (dealt by the host) reaches the guest's own gauge
		if me and d.player.weapon and d.player.weapon.form == "forge":
			var foes: Array = d.hostiles(d.player.team).filter(func(a): return a is Enemy and a.alive)
			if not foes.is_empty():
				var f: Actor = foes[0]
				await walk_to(f.pos + Vector2(-1.2, 0), 0.6, 6.0)
				release_all()
				for k in 4:
					Dev.mouse = get_viewport().get_visible_rect().size * 0.5 + Vector2(120, 0)
					tap("attack")
					await wait(0.7)
				await until(func() -> bool: return d.player.form_meter > 0.05, 4.0, "the host's heat shows on my gauge (%.2f)" % d.player.form_meter)
	await wait(1.0)


## The second playtest's party findings, on real machines (DEVNET=1): the host
## drops one epic find for each Kindled beside them, memories and Embers.
## Every machine checks it draws its own find and nobody else's, walks to it on
## its own keys, has it in its Satchel at once (still below), wears it with a
## real click in the Satchel, and that its save got exactly its run's XP; the
## host checks every Kindled's run got the same XP and Embers, and sees each
## guest wearing what they put on.
func loot() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending, 90.0, "below together")
	await wait(1.0)
	_strip_bot()
	var d := dun()
	var me_id := Net.my_id()
	var xp0 := Profile.total_xp()
	var run_xp0 := Game.run.xp_gained
	var bag0 := Profile.bag().size()
	var runs0 := {}
	if role == "host":
		for p in d.players:
			runs0[p.peer_id] = [p.run.xp_gained, p.run.embers]
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for p in d.players:
			var it := ItemDB.make_item("grave_iron_helm", "epic", 1, rng, 1)
			Pickup.spawn(d, "gear", d.random_floor_near(p.pos + Vector2(5.5, 0.0), 1.0), 1, {"item": it}, p.peer_id)     # (beyond the pickup reach)
	await wait(1.5)
	var mine: Pickup = null
	var others_drawn := 0
	var others_here := 0
	for pk in d.pickups:
		if not is_instance_valid(pk) or pk.kind != "gear":
			continue
		if pk.owner_peer == me_id:
			mine = pk
		else:
			others_here += 1
			if pk.visible or (pk.beam and pk.beam.visible):
				others_drawn += 1
	expect(mine != null and mine.visible, "my own find is on this floor, drawn")
	expect(others_drawn == 0, "no one else's find is drawn here (%d carried for its owner)" % others_here)
	if role != "host":
		expect(others_here == 0, "a guest is not even sent another's find")
	if role == "host":
		Net.i.dev_shot("loot/finds")
	if mine:
		await walk_to(mine.pos, 0.35, 8.0)
	release_all()
	await until(func() -> bool: return Profile.bag().size() > bag0, 6.0, "my find is in my Satchel at once, below")
	var got: Dictionary = Profile.bag().back() if Profile.bag().size() > bag0 else {}
	expect(String(got.get("drop", "")).begins_with(Game.run.run_id + "/"), "it is this expedition's find (%s)" % got.get("drop", ""))
	# wear it below: open the Satchel with the key, click the piece
	tap("inventory")
	await until(func() -> bool: return not Game.ui.modal_layer.find_children("*", "InventoryUI", true, false).is_empty(), 3.0, "the Satchel opens below")
	await wait(0.6)
	if not got.is_empty():
		var b := find_control(func(c: Control) -> bool: return c is Button and String(c.name) == "uid_%d" % int(got.uid))
		expect(b != null, "the find has its place in the bag")
		if b:
			var at := b.get_global_transform_with_canvas() * (b.size * 0.5)
			await click_at(get_viewport().get_final_transform() * at)
			await until(func() -> bool: return int(Profile.equipped().get("head", {}).get("uid", -1)) == int(got.uid), 3.0, "a click wears it, below")
	tap("inventory")
	await wait(1.0)
	# memories for everyone: three orbs and a handful of Embers, taken by the host
	if role == "host":
		for k in 3:
			Pickup.spawn(d, "xp", d.player.pos + Vector2(0.3, 0), 10)
		Pickup.spawn(d, "ember", d.player.pos + Vector2(0.3, 0), 20)
	await wait(2.5)
	expect(Profile.total_xp() - xp0 == Game.run.xp_gained - run_xp0, "my save got exactly my run's XP (%d / %d)" % [Profile.total_xp() - xp0, Game.run.xp_gained - run_xp0])
	if role == "host":
		var gains := {}
		for p in d.players:
			var r0: Array = runs0.get(p.peer_id, [0, 0])
			gains[p.peer_id] = [p.run.xp_gained - int(r0[0]), p.run.embers - int(r0[1])]
		var vals := gains.values()
		var same := true
		for v in vals:
			if v != vals[0]:
				same = false
		expect(same and int(vals[0][0]) > 0, "every Kindled's run got the same XP and Embers %s" % str(gains))
		# each guest is drawn in the helm they put on below
		for p in d.players:
			if p == d.player:
				continue
			await until(func() -> bool: return p.gear_layers.has("head"), 4.0, "the host sees %s wear their find" % Net.name_of(p.peer_id))
		Net.i.dev_shot("loot/worn")
	# every machine's own map, with every Kindled on it
	await wait(1.0)
	Game.ui.hud.toggle_big_map()
	await wait(0.8)
	expect(Game.ui.hud.big_map.visible, "the full map opens below")
	if role == "host":
		Net.i.dev_shot("loot/map")
	await wait(1.2)
	Game.ui.hud.toggle_big_map()
	await wait(1.5)


## The title screen in a party (DEVNET=0): everyone starts at the title; the
## host hosts, the guests join by address, then the host alone presses "Begin
## together" - every guest must arrive in the host's sanctuary without
## touching anything, each as their own Kindled.
func party_start() -> void:
	Game.goto_menu()
	await wait(1.5)
	if role == "host":
		Game.ui.party()
		await wait(0.6)
		await click_button("Host")
		await until(func() -> bool: return Net.is_host(), 10.0, "hosting from the title")
		await until(func() -> bool: return Net.party_size() >= guests + 1, 40.0, "%d guest(s) joined at the title" % guests)
		await wait(1.0)
		Capture.save_now("e2e/partystart_title_%s" % _tag())
		await click_button("Begin together")     # (not "Begin": the title screen has its own, under the party screen)
		await until(func() -> bool: return hub() != null and not hub().menu_mode, 10.0, "the host is in camp")
		await until(func() -> bool:
			for pid in Net.i.roster:
				if String(Net.i.roster[pid].get("where", "")) != "hub":
					return false
			return true, 20.0, "every guest arrived in camp")
	else:
		await wait(1.0 + float(Net.i.get_instance_id() % 5) * 0.1)
		Game.ui.party()
		await wait(0.6)
		await click_button("Enter address")
		await wait(0.3)
		var le := find_control(func(c: Control) -> bool: return c is LineEdit and (c as LineEdit).placeholder_text != "") as LineEdit
		if le:
			le.text = "127.0.0.1"
			le.text_changed.emit(le.text)
		await click_button("Join")
		await until(func() -> bool: return Net.is_client() and Net.i.roster.has(Net.my_id()), 15.0, "joined at the title")
		expect(Game.stage is Hub and (Game.stage as Hub).menu_mode, "still at the title until the host begins")
		await until(func() -> bool: return hub() != null and not hub().menu_mode and not Net.i.camp.is_empty() and hub().camp == Net.i.camp, 30.0, "followed into the host's camp without a click")
		expect(Game.ui.modal_of("party") == null, "no party screen left to close")
	await wait(1.0)
	Capture.save_now("e2e/partystart_camp_%s" % _tag())
	await wait(1.0)


func _ice(d: Dungeon) -> Array:
	return d.props.filter(func(p): return is_instance_valid(p) and p.kind == "icewall")


## Every machine walks its own way (host left, guests right) for two seconds;
## half-way, each checks every other Kindled is drawn facing its walk.
func _others_face(where: String) -> void:
	var mine := Vector2.LEFT if role == "host" else Vector2.RIGHT
	steer(mine)
	await wait(1.4)
	for o: Player in Game.stage.players if Game.stage is Dungeon else hub().sync.others.values():
		if not is_instance_valid(o) or o.peer_id == Net.my_id():
			continue
		var theirs_left := o.peer_id == 1     # the host walks left, guests right
		var ok := o.sprite.anim.ends_with("_side") and o.sprite.flip_h == theirs_left
		expect(ok, "%s: %s is drawn walking %s (%s, mirrored %s)" % [where, Net.name_of(o.peer_id), "left" if theirs_left else "right", o.sprite.anim, o.sprite.flip_h])
	if role == "host":
		Net.i.dev_shot("facing/%s_apart" % where)
	await wait(0.8)
	steer(Vector2.ZERO)
	await wait(0.8)


## The pointer held still at one side of the screen centre (the camera follows
## the Kindled, so it stays on that side of it).
func _park_pointer(side: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	Dev.mouse = vp * 0.5 + side * vp.x * 0.3


func _shot(name: String) -> void:
	if Net.active() and Net.i:
		return     # parties take matched shots with Net.dev_shot
	Capture.save_now(name)


## Every foe there is, beside the party: the host raises them a few at a
## time (with elites of every affix, a Grudge and the three guardians), the
## guests check each one is drawn whole on their screen, then the host fells
## them and the guests check they are gone. Matched captures per batch.
const BESTIARY := [
	["husk", "skitter", "archer", "guard", "bonecaller"],
	["bloat", "spider", "gravemole", "lampwight", "sporeling"],
	["thornback", "moth", "rootweaver", "spore_mortar", "bramblewright"],
	["sentinel", "hound", "acolyte", "wraith", "duelist"],
	["sunwatcher", "toad", "husk:hasted", "guard:warded", "archer:volatile"],
	["hound:vampiric", "wraith:phasing", "bloat:molten", "skitter:splitting", "acolyte:gloom"],
	["husk:grudge"],
	["warden"],
	["bloom"],
	["ashen_king"],
]


func bestiary() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending, 60.0, "below together")
	await wait(1.5)
	if role == "host":
		var d := dun()
		for i in BESTIARY.size():
			var made: Array = []
			var row: Array = BESTIARY[i]
			for k in row.size():
				var parts := String(row[k]).split(":")
				var e := d._make_enemy(parts[0])
				if parts.size() > 1 and parts[1] == "grudge":
					e.make_grudge({"name": "Ash-Eater, Who Took Your Light", "level": 2, "embers": 80, "traits": ["ember_fed"], "affix": "hasted"})
				elif parts.size() > 1:
					e.make_elite(parts[1])
				var ring := Vector2.from_angle(TAU * k / maxf(1.0, row.size()) + 0.4) * (3.2 if row.size() > 1 else 3.8)
				e.pos = d.random_floor_near(d.player.pos + ring, 0.8)
				e.room_id = d.current_room.id if d.current_room else -1
				d.add_actor(e)
				d.register_enemy(e)
				made.append(e)
			print("[scenario] batch %d: %s" % [i, ", ".join(PackedStringArray(row))])
			await wait(2.6)
			Net.i.dev_shot("best/%02d_%s" % [i, String(row[0]).replace(":", "_")])
			await wait(0.8)
			for e in made:
				if is_instance_valid(e) and e.alive:
					e.hp = 0.0
					e.die(d.player)
			for a in d.actors.duplicate():
				if a is Enemy and a.alive:
					a.hp = 0.0
					a.die(d.player)
			await wait(1.6)
		print("[scenario] bestiary done")
		Net.i.dev_shot("best/99_cleared")
		await wait(2.0)
	else:
		var first := {}       # net id -> when it reached this screen
		var bad := {}
		var seen_ids := {}
		var t_end := now() + BESTIARY.size() * 5.2 + 12.0
		while now() < t_end and Net.active():
			for e in _enemies():
				if not first.has(e.net_id):
					first[e.net_id] = now()
					seen_ids[e.id] = true
				elif now() - float(first[e.net_id]) > 1.2:
					var dis: Variant = e.sprite.get_instance_shader_parameter("dissolve")
					var drawn: bool = e.sprite.visible and e.visual.visible and (dis == null or float(dis) < 0.3) and e.sprite.sheet.name == String(e.def.sheet)
					if not drawn and not bad.has(e.net_id):
						bad[e.net_id] = e.id
						print("[scenario] not drawn: %s (%d) visible=%s dissolve=%s sheet=%s" % [e.id, e.net_id, e.sprite.visible, str(dis), e.sprite.sheet.name])
			await wait(0.25)
		var all_ids: Array = []
		for row in BESTIARY:
			for x in row:
				all_ids.append(String(x).split(":")[0])
		var missing := all_ids.filter(func(x): return not seen_ids.has(x))
		expect(missing.is_empty(), "every kind of foe reached my screen (missing: %s)" % ", ".join(PackedStringArray(missing)))
		expect(bad.is_empty(), "every foe on my screen was drawn whole (%d of %d not: %s)" % [bad.size(), first.size(), str(bad.values())])
		await wait(2.0)
		expect(_enemies().is_empty(), "felled foes are gone from my screen too (%d left)" % _enemies().size())


## Just the stairs: the dev party (net=host / net=join, coop=2) goes down,
## everyone walks on their own keys at depths 2 and 3.
func stairs_only() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim, 60.0, "depth 1")
	var stay := 2.0
	for a in Dev.args():
		if a.begins_with("stay="):
			stay = float(a.substr(5))     # time on depth 1 (input numbers grow 60 a second)
	await wait(stay)
	for depth in [2, 3]:
		if role == "host":
			await wait(1.0)
			Net.i.run_sync.start_vote("stairs", -1, dun().player)
		else:
			await until(func() -> bool: return RequestCard.ensure(Game.ui).mode == "vote", 30.0, "the stairs vote reached me")
			await wait(0.4)
			tap("party_yes")
		var want_depth: int = depth
		await until(func() -> bool: return dun() != null and Game.run != null and Game.run.depth == want_depth and not Game.ui.card_pending, 30.0, "down to depth %d together" % depth)
		await walk_check(depth)


## Pings and a Hollow Altar answered by the whole party: each machine presses
## its own keys, and every screen must show the same world afterwards.
func sites() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim, 60.0, "depth 1")
	_strip_bot()
	# (the depth's title card holds every hand: a key pressed under it does nothing)
	await until(func() -> bool: return not Game.ui.card_pending and not Game.ui.blocks_world(), 20.0, "the floor is mine to act on")
	await wait(1.0)
	# a ping from my own key, seen by everyone: each Kindled's colour on my map
	# (the others' cards may clear a little before or after mine)
	tap("ping")
	var hues := {}
	for peer in Net.i.roster:
		hues[Net.color_of(int(peer)).to_html()] = true
	var seen := {}
	var t_end := now() + 8.0
	while now() < t_end and seen.size() < hues.size():
		for pg in dun().pings:
			var key: String = (pg.col as Color).to_html()
			if hues.has(key):
				seen[key] = true
		await wait(0.1)
	expect(seen.size() >= hues.size(), "every Kindled's ping reached my map (%d of %d)" % [seen.size(), hues.size()])
	if role == "host":
		Net.i.dev_shot("e2e/sites_ping")
	# the altar waits on the first floor or the second
	if _site("altar") == null:
		if role == "host":
			Net.i.run_sync.start_vote("stairs", -1, dun().player)
		else:
			await until(func() -> bool: return RequestCard.ensure(Game.ui).mode == "vote", 30.0, "the stairs vote reached me")
			await wait(0.4)
			tap("party_yes")
		await until(func() -> bool: return dun() != null and Game.run != null and Game.run.depth == 2 and not Game.ui.card_pending, 30.0, "down to depth 2 together")
		await wait(2.0)
	var offer: Prop = _site("altar")
	expect(offer != null, "a Hollow Altar stands on this floor, on my screen")
	if offer == null:
		return
	var stone: Prop = _site("altar_stone")
	var region: String = dun().layout.region
	if role == "host":
		await wait(1.0)
		dun().player.pos = offer.pos + Vector2(0.0, 1.0)
		await wait(0.5)
		tap("interact")
	else:
		await until(func() -> bool: return RequestCard.ensure(Game.ui).mode == "vote", 30.0, "the altar's question reached me")
		await wait(0.4)
		if role == "guest":
			Net.i.dev_shot("e2e/sites_vote")
		tap("party_yes")
	var want := String(offer.data.choice)
	await until(func() -> bool: return String(stone.sprite.anim) == want, 20.0, "the altar shows the answer on my screen")
	if role == "host":
		expect(Chronicle.site(region) == want, "the host's Chronicle remembers it")
		Net.i.dev_shot("e2e/sites_answered")
	else:
		expect(Chronicle.site(region) == "", "a guest's own altar is untouched")
		expect(Chronicle.marks("witnessed_altar_" + want) == 1, "a guest's Chronicle records what they saw")
	await until(func() -> bool:
		for p in dun().props:
			if is_instance_valid(p) and p.kind == "site" and String(p.data.get("event", "")) == "altar" and not p.used:
				return false
		return true, 10.0, "the other answers are spent on my screen")
	await wait(1.0)


## What the Shifting Undervault adds, in a party (run with XARGS="plan=wing warp=lock"): the floor is
## the same on every machine; a guest takes the key and opens the vault with real
## key presses, every map and every wall agrees; then a Snuffer and a Gravehook
## work on the guest's own Kindled, whose prediction must go along with them.
func ways() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim, 60.0, "depth 1")
	_strip_bot()
	await wait(2.0)
	var lay: DungeonGen.Layout = dun().layout
	expect(lay.plan == "wing" and not lay.locks.is_empty(), "a barred wing on my floor")
	if lay.locks.is_empty():
		return
	var key_room: Room = lay.room(lay.key_room)
	var bars: Array = lay.locks[0].tiles
	var plate: Prop = null
	for p in dun().props:
		if is_instance_valid(p) and p.kind == "lock_plate":
			plate = p
	expect(plate != null, "the plate beside the bars is on my screen")
	var t0: Vector2i = bars[0]
	expect(dun().grid.at(t0.x, t0.y) == TileGrid.GATE, "barred on my machine")
	if role == "host":
		# the floor's fights are not what this tests (a layout change once sealed the
		# guests into one on the way to the plate): every fight is won before it starts
		for r in lay.rooms:
			if r.type in [Room.Type.COMBAT, Room.Type.ELITE]:
				r.cleared = true
		for a in dun().actors.duplicate():
			if a is Enemy and a.alive:
				a.die(null)
		await wait(1.0)
		# the key's room is far: its altar is set down beside the guest (its fight is not
		# what this tests; carrying the key and the bars are)
		var g0: Player = _guest_kindled()
		if g0:
			Prop.make(dun(), "key_altar", Vector2i(dun().foe_spot(g0.pos + Vector2(2.5, 0.0), 0.6)), {})
	await until(func() -> bool: return _prop_kind("key_altar") != null, 20.0, "the key's altar reached me")
	var altar: Prop = _prop_kind("key_altar")
	if role == "guest":
		# barred first: without the key it does not move (walked to, never teleported:
		# the host only believes where a guest really walked)
		expect(await walk_to(plate.pos + Vector2(0.0, 1.0), 0.6, 12.0), "I walked to the plate")
		tap("interact")
		await wait(0.8)
		expect(not dun().layout.locks[0].open, "without the key the plate does nothing")
		expect(await walk_to(altar.pos + Vector2(0.0, 1.0), 0.6, 12.0), "I walked to the key")
		tap("interact")
	await until(func() -> bool: return dun().has_key, 20.0, "the party carries the key on my screen")
	expect(Minimap.known_rooms(dun()).has(lay.vault_room), "my map shows where it fits")
	expect(String(dun().objective.get("text", "")).contains("KEY"), "my HUD says what to do with it")
	if role == "guest":
		Net.i.dev_shot("e2e/ways_key")
		expect(await walk_to(plate.pos + Vector2(0.0, 1.0), 0.6, 12.0), "I walked back to the plate")
		tap("interact")
	await until(func() -> bool: return dun().layout.locks[0].open, 20.0, "the vault opened on my screen")
	expect(dun().grid.at(t0.x, t0.y) == TileGrid.FLOOR, "the way is floor on my machine")
	expect(not dun().astar.is_point_solid(t0), "and walkable")
	expect(not dun().has_key, "the key is spent on my machine")
	if role == "guest":
		var v: Vector2 = lay.room(lay.vault_room).center()
		expect(await walk_to(dun().player.pos.lerp(v, 0.5), 1.0, 8.0), "I can walk toward it through the open bars")
		Net.i.dev_shot("e2e/ways_open")
	await wait(1.0)
	# the rooms' own devices
	if role == "host":
		var c: Vector2 = dun().foe_spot(dun().player.pos + Vector2(3.0, 0.0), 0.6)
		var st := Prop.make(dun(), "strut", Vector2i(c), {"scenario": true})
		await wait(0.5)
		st.on_struck(dun().player)
	await until(func() -> bool:
		var s: Prop = _newest("strut")
		return s != null and String(s.sprite.anim) == "down", 15.0, "a felled column lies down on my screen")
	# a Snuffer on the guest's own lantern
	var mine := dun().player
	var before: float = mine.kindle
	if role == "host":
		# every guest's own lantern, at once
		var thieves: Array = []
		for g in _guests():
			g.kindle = g.kindle_max()
			thieves.append([_spawn_near("snuffer", g), g])
		await wait(1.0)
		for pair in thieves:
			pair[0].state = "spent"
			pair[0].landed_on(pair[1])
		await wait(2.0)
		Net.i.dev_shot("e2e/ways_snuffed")
		for pair in thieves:
			pair[0].hp = 0.0
			pair[0].die(dun().player)
	else:
		await wait(0.2)
		mine.kindle = mine.kindle_max()
		await until(func() -> bool: return mine.snuffed_t > 0.0, 15.0, "my lantern burns low")
		await until(func() -> bool: return mine.snuffed_t <= 0.0, 15.0, "and burns as it did once the thief falls")
	# a Gravehook's chain on the guest's own feet
	if role == "host":
		await wait(1.0)
		var hooks: Array = []
		for g2 in _guests():
			hooks.append([_spawn_near("gravehook", g2, 6.0), g2])
		await wait(1.0)
		for pair in hooks:
			pair[0].aim_dir = (pair[1].pos - pair[0].pos).normalized()
			pair[0].state = "thrown"
			pair[0].landed_on(pair[1])
		await wait(2.0)
		for pair in hooks:
			pair[0].hp = 0.0
			pair[0].die(dun().player)
	else:
		var from: Vector2 = mine.pos
		var moved := 0.0
		var end := now() + 8.0
		while now() < end:
			moved = maxf(moved, mine.pos.distance_to(from))
			await wait(0.05)
		expect(moved > 2.0, "the chain dragged my own Kindled (%.1f tiles)" % moved)
	await wait(1.0)


func _prop_kind(kind: String) -> Prop:
	for p in dun().props:
		if is_instance_valid(p) and p.kind == kind:
			return p
	return null


## The deepening pass in a party (run with HXARGS=hunt=ossuary GXARGS="wear=gloamfang evolve=storm"):
## the host's hunt reaches every floor the same way; a guest reads a sign of the trail
## with a real key press and the host counts it; a guest's grown weapon is a grown weapon
## on the host too (its path's power is the host's to apply).
func deep() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim, 60.0, "depth 1")
	_strip_bot()
	await wait(2.0)
	expect(dun().hunted(), "this floor is the hunt's, on my machine")
	var signs: Array = []
	for p in dun().props:
		if is_instance_valid(p) and p.kind == "site" and String(p.data.get("event", "")) == "spoor":
			signs.append(p)
	expect(signs.size() == 2, "two signs of its trail on my floor (%d)" % signs.size())
	if signs.is_empty():
		return
	if role == "host":
		# the floor's own signs lie in rooms that seal for their fights: one more is set
		# down beside the guest (the reading, by the guest's own key, is what is tested)
		await wait(1.0)
		var g0: Player = _guest_kindled()
		if g0:
			var at := Vector2i(dun().foe_spot(g0.pos + Vector2(2.0, 0.0), 0.6))
			var pd := {"kind": "site", "tile": at, "event": "spoor"}
			var extra := DeepEvents.site_data(pd, dun().layout.region, dun().run.world)
			extra["event"] = "spoor"
			Prop.make(dun(), "site", at, extra)
	if role == "guest":
		await until(func() -> bool:
			var s := _newest("site")
			return s != null and String(s.data.get("event", "")) == "spoor" and s.pos.distance_to(dun().player.pos) < 5.0, 20.0, "a sign was set down beside me")
		var near := _newest("site")
		expect(await walk_to(near.pos + Vector2(0.0, 1.0), 0.6, 12.0), "I walked to the sign")
		tap("interact")
		await until(func() -> bool: return not near.interactable(), 15.0, "the sign is read on my screen")
		Net.i.dev_shot("e2e/deep_sign")
	else:
		await until(func() -> bool: return dun().run.hunt_signs >= 1, 40.0, "the host counted the guest's sign")
		var g: Player = _guest_kindled()
		expect(g != null and g.stats.has("storm_crit"), "the guest's grown weapon has its path's power on the host")
		expect(g != null and g.stats.has("crit_knives"), "and its own")
	await wait(1.5)


## The world of depth in a party: a spike trap shows the same state on every machine at
## the same moment and bites a guest who really walked onto it; a solid thorn stops a guest
## and is gone for everyone once cut.
func depthworld() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim and not Game.ui.card_pending and not Game.ui.blocks_world(), 60.0, "depth 1")
	_strip_bot()
	await wait(1.0)
	if role == "host":
		var g0: Player = _guest_kindled()
		var at: Vector2i = Vector2i(dun().foe_spot(g0.pos + Vector2(2.5, 0.0), 0.6))
		Prop.make(dun(), "spikes", at, {})
		Prop.make(dun(), "bramble", at + Vector2i(-1, 2), {})
	await until(func() -> bool: return _prop_kind("spikes") != null and _prop_kind("bramble") != null, 20.0, "the trap and the thorn reached me")
	var trap: Prop = _newest("spikes")
	var thorn: Prop = _newest("bramble")
	expect(trap != null and trap.teeth != null, "a trap with its teeth on my screen")
	# one clock: what each machine thinks the host's time is (they share this PC's clock)
	var mine := dun().hazard_time() - Time.get_unix_time_from_system()
	var path := "user://e2e_clock_%s.txt" % _tag()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(str(mine))
	f.close()
	await wait(1.5)
	if role == "guest":
		var host_off := FileAccess.get_file_as_string("user://e2e_clock_host.txt")
		if host_off != "":
			var diff := absf(float(host_off) - mine)
			expect(diff < 0.35, "my trap clock agrees with the host's (%.0f ms apart)" % (diff * 1000.0))
	if _tag() == "guest1":
		# a solid thorn really stops me
		var target: Vector2 = thorn.pos
		await walk_to(target + Vector2(0.0, 1.05), 0.5, 10.0)
		var t_end := now() + 1.2
		while now() < t_end:
			steer(Vector2.UP)
			await wait(0.05)
		steer(Vector2.ZERO)
		expect(dun().player.pos.y > target.y + 0.35, "the thorn stopped me at its foot (%.2f past it)" % (dun().player.pos.y - target.y))
		# I step onto the plate and stand there through its cycle
		await walk_to(trap.pos, 0.3, 12.0)
		var hp0: float = dun().player.hp
		await wait(Prop.SPIKE_CYCLE + 0.8)
		expect(dun().player.hp < hp0, "the teeth bit me on the plate (%d -> %d)" % [int(hp0), int(dun().player.hp)])
		# cut the thorn
		await walk_to(thorn.pos + Vector2(0.0, 1.1), 0.5, 12.0)
		for k in 7:
			if not is_instance_valid(thorn) or thorn.used:
				break
			Dev.mouse = get_viewport().get_visible_rect().size * 0.5 + Vector2(0, -120)
			tap("attack")
			await wait(0.55)
	await until(func() -> bool: return not is_instance_valid(thorn) or thorn.used or dun().grid.at(thorn.tile.x, thorn.tile.y) == TileGrid.FLOOR, 30.0, "the thorn is cut on my machine")
	expect(not is_instance_valid(thorn) or dun().grid.at(thorn.tile.x, thorn.tile.y) == TileGrid.FLOOR, "its tile is open on my machine")
	await wait(1.5)
	Net.i.dev_shot("e2e/depthworld")


## The most recently made prop of a kind (the floor may have its own already).
func _newest(kind: String) -> Prop:
	var best: Prop = null
	for p in dun().props:
		if is_instance_valid(p) and p.kind == kind and (best == null or p.net_idx > best.net_idx):
			best = p
	return best


func _guests() -> Array:
	return dun().players.filter(func(pl): return pl != dun().player)


func _guest_kindled() -> Player:
	for pl in dun().players:
		if pl != dun().player:
			return pl
	return null


func _spawn_near(id: String, p: Player, dist := 3.0) -> Enemy:
	var e: Enemy = dun()._make_enemy(id)
	e.pos = dun().foe_spot(p.pos + Vector2(dist, 0.0), 0.5)
	dun().add_actor(e)
	dun().register_enemy(e)
	e.spawn_t = 0.01
	return e


## A party's guardian: the stairs to depth 3, its arrival, the fight turning and
## its fall, on every machine; its spoils land after the fall, for everyone.
func guardian() -> void:
	await until(func() -> bool: return dun() != null and not dun().paused_sim, 60.0, "depth 1")
	_strip_bot()
	for depth in [2, 3]:
		if role == "host":
			await wait(1.0)
			Net.i.run_sync.start_vote("stairs", -1, dun().player)
		else:
			await until(func() -> bool: return RequestCard.ensure(Game.ui).mode == "vote", 30.0, "the stairs vote reached me")
			await wait(0.4)
			tap("party_yes")
		var want: int = depth
		await until(func() -> bool: return dun() != null and Game.run != null and Game.run.depth == want and not Game.ui.card_pending, 30.0, "down to depth %d" % depth)
		_strip_bot()
	await wait(1.5)
	var boss_room: Room = dun().layout.room(dun().layout.exit_id)
	if role == "host":
		dun().player.godmode = true
		dun().player.pos = dun().random_floor_near(boss_room.center() + Vector2(0, 3), 1.0)
	if not await until(func() -> bool: return dun().boss != null and is_instance_valid(dun().boss), 20.0, "the guardian arrived on my screen"):
		return
	var b: Enemy = dun().boss
	# every machine watches for itself from here, each on its own clock: a lagged
	# guest must not be judged by when it happened to look
	var began := now()
	var turned := false
	var did_turn := false
	var did_fall := false
	var t_fell := -1.0
	var t_hoard := -1.0
	var home := false
	while now() < began + 30.0 and not (turned and t_hoard > 0.0 and home):
		if role == "host" and not did_turn and now() > began + 3.5:
			did_turn = true
			b.phase_moment("The Fight Turns", "scenario", Color(0.7, 0.5, 0.95))
			expect(b.aura.a > 0.0, "the guardian sheds its light from now on")
			Net.i.dev_shot("e2e/guardian_turn")
		if role == "host" and did_turn and not did_fall and now() > began + 6.5:
			did_fall = true
			b.hp = 0.0
			b.die(dun().player)
		if not turned and String(Game.ui.banner_title.text) == "THE FIGHT TURNS":
			turned = true
		if t_fell < 0.0 and (not is_instance_valid(b) or String(b.sprite.anim) == "death"):
			t_fell = now()
			if role == "host":
				Net.i.dev_shot("e2e/guardian_fall")
		if t_hoard < 0.0 and not dun().pickups.filter(func(p): return is_instance_valid(p) and p.kind == "sunshard").is_empty():
			t_hoard = now()
		home = not dun().props.filter(func(p): return is_instance_valid(p) and p.kind == "hearthstone" and p.data.get("victory", false)).is_empty()
		await wait(0.03)
	expect(turned, "the turn reached my screen")
	expect(t_fell > 0.0, "it fell on my screen")
	expect(t_hoard > 0.0, "its hoard landed on my screen")
	expect(home, "the way home stands on my screen")
	print("[scenario] the hoard came %.2f s after the fall" % (t_hoard - t_fell))
	expect(t_hoard - t_fell > 1.5, "the fall had the floor to itself (%.2f s)" % (t_hoard - t_fell))
	if role == "host":
		Net.i.dev_shot("e2e/guardian_spoils")
	await wait(1.0)


func _site(ev: String) -> Prop:
	if dun() == null:
		return null
	for p in dun().props:
		if is_instance_valid(p) and p.kind == "site" and String(p.data.get("event", "")) == ev:
			return p
	return null


func _strip_bot() -> void:
	if dun() and dun().player:
		for c in dun().player.get_children():
			if c is Bot:
				c.queue_free()
		dun().player.autopilot = false
		dun().player.move_in = Vector2.ZERO


## On each new floor: I walk a square on my own keys; the others watch my
## Kindled move on their screens (each machine checks the others).
func walk_check(depth: int) -> void:
	await wait(1.5)
	var others := {}
	for pl in dun().players:
		if pl != dun().player:
			others[pl.peer_id] = [pl.pos, 0.0]
	var t_end := now() + 7.0
	var dirs := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var k := 0
	var me0 := dun().player.pos
	var me_far := 0.0
	while now() < t_end:
		await walk_dir(dirs[k % 4] * (1 if role == "host" else -1), 0.7)
		k += 1
		me_far = maxf(me_far, dun().player.pos.distance_to(me0))
		for pl in dun().players:
			if others.has(pl.peer_id):
				var e: Array = others[pl.peer_id]
				e[1] = maxf(float(e[1]), pl.pos.distance_to(e[0]))
	expect(me_far > 1.0, "depth %d: my own Kindled moves on my keys (%.1f tiles)" % [depth, me_far])
	for pid in others:
		expect(float(others[pid][1]) > 1.0, "depth %d: %s moves on my screen (%.1f tiles)" % [depth, Net.name_of(int(pid)), float(others[pid][1])])
	if role == "host":
		Net.i.dev_shot("e2e/13_depth%d_moving" % depth)
	await wait(1.0)


func _enemies() -> Array:
	var out: Array = []
	if dun():
		for a in dun().actors:
			if is_instance_valid(a) and a is Enemy and a.alive:
				out.append(a)
	return out


## Every foe on this (guest's) screen is drawn: its sprite solid (not left
## dissolved, the "only shadows" bug), visible, the right sheet.
func _check_enemies_drawn() -> void:
	var es := _enemies()
	var ok := 0
	for e in es:
		var dis: Variant = e.sprite.get_instance_shader_parameter("dissolve")
		if e.sprite.visible and e.visual.visible and (dis == null or float(dis) < 0.3) and e.sprite.sheet.name == String(e.def.sheet):
			ok += 1
		else:
			print("[scenario] foe %s (%s) not drawn: visible=%s dissolve=%s" % [e.id, e.net_id, e.sprite.visible, str(dis)])
	expect(not es.is_empty() and ok == es.size(), "every foe on my screen is drawn (%d of %d)" % [ok, es.size()])
	Capture.save_now("e2e/10b_foes_%s" % _tag())


## Host: anyone the sealing room drew in stands on open floor, free to move.
func _check_regroup() -> void:
	var d := dun()
	var r := d.active_room
	for pl in d.players:
		var t := Vector2i(floori(pl.pos.x), floori(pl.pos.y))
		expect(r.contains_tile(t), "%s is inside the sealed room" % Net.name_of(pl.peer_id))
		expect(not d.grid.box_blocked(pl.pos, pl.box()), "%s stands clear of walls and props" % Net.name_of(pl.peer_id))
		var open := 0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if d.grid.at(t.x + dx, t.y + dy) == TileGrid.FLOOR:
					open += 1
		expect(open >= 6, "%s has room to move (%d open tiles around)" % [Net.name_of(pl.peer_id), open])


# --- input, the way a person gives it -------------------------------------------------------

func _event_for(action: String) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			return e
	return null


func _send(action: String, down: bool) -> void:
	var src := _event_for(action)
	if src == null:
		fail("no key for %s" % action)
		return
	var e: InputEvent = src.duplicate()
	if e is InputEventKey:
		var k := e as InputEventKey
		k.keycode = k.physical_keycode
		k.pressed = down
		k.device = 0
	elif e is InputEventMouseButton:
		var m := e as InputEventMouseButton
		m.pressed = down
		m.device = 0
		m.position = get_viewport().get_mouse_position()
		m.global_position = m.position
	Input.parse_input_event(e)


func tap(action: String, hold := 0.06) -> void:
	_send(action, true)
	get_tree().create_timer(hold, true, false, true).timeout.connect(func() -> void: _send(action, false))


func hold(action: String, on: bool) -> void:
	if bool(_held.get(action, false)) == on:
		return
	_held[action] = on
	_send(action, on)


func release_all() -> void:
	for a in _held.keys():
		hold(a, false)


func steer(d: Vector2) -> void:
	var n := d.normalized() if d.length() > 0.01 else Vector2.ZERO
	hold("move_right", n.x > 0.38)
	hold("move_left", n.x < -0.38)
	hold("move_down", n.y > 0.38)
	hold("move_up", n.y < -0.38)


func walk_dir(d: Vector2, secs: float) -> void:
	steer(d)
	await wait(secs)
	steer(Vector2.ZERO)


func walk_to(target: Vector2, tol := 0.5, timeout := 10.0) -> bool:
	var st := Game.stage
	var t_end := now() + timeout
	var path: Array = []
	var last := Vector2.INF
	var still := 0.0
	var side := 0.0
	var flip := 1.0
	while st and st.player and is_instance_valid(st.player) and st.player.pos.distance_to(target) > tol:
		if now() > t_end:
			steer(Vector2.ZERO)
			print("[scenario] could not reach %s (at %s)" % [target, st.player.pos])
			return false
		var me := st.player.pos
		# the way there, tile by tile (tile centres keep the Kindled's box off corners)
		if path.is_empty():
			var a := Vector2i(floori(me.x), floori(me.y))
			var b := Vector2i(floori(target.x), floori(target.y))
			for t in st.astar.get_id_path(a, b, true):
				path.append(Vector2(t) + Vector2(0.5, 0.5))
			if not path.is_empty():
				path.pop_front()
			path.append(target)
		while path.size() > 1 and me.distance_to(path[0]) < 0.3:
			path.pop_front()
		var d: Vector2 = path[0] - me
		if side > 0.0:
			side -= get_process_delta_time()
			d = d.orthogonal() * flip
		steer(d)
		await get_tree().process_frame
		if Game.stage != st:
			break
		still = still + get_process_delta_time() if st.player.pos.distance_to(last) < 0.004 else 0.0
		last = st.player.pos
		if still > 0.35:
			# caught (as a person sometimes is): a step aside, then the way afresh
			still = 0.0
			side = 0.25
			flip = -flip
			path.clear()
	steer(Vector2.ZERO)
	return true


## Clicks a button the way the mouse does: the pointer moves over it, presses, lets go.
func click_button(text: String, alt := "", alt2 := "") -> void:
	# (only the names given: an unused "" must not match a button with no text,
	# such as a spell card)
	var names := [text, alt, alt2].filter(func(t): return String(t) != "")
	var b := find_control(func(c: Control) -> bool:
		return c is Button and c.is_visible_in_tree() and not (c as Button).disabled and (c as Button).text.strip_edges() != "" and (c as Button).text.strip_edges() in names) as Button
	if b == null:
		b = find_control(func(c: Control) -> bool:
			return c is Button and c.is_visible_in_tree() and not (c as Button).disabled and (c as Button).text.strip_edges().begins_with(text)) as Button
	if b == null:
		fail("no button '%s' on screen" % text)
		return
	# a button made this frame has no place on screen until the layout runs
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(b):
		fail("button '%s' went away" % text)
		return
	var at := b.get_global_transform_with_canvas() * (b.size * 0.5)
	var hits := {"n": 0}
	var cb := func() -> void: hits.n += 1
	b.pressed.connect(cb)
	await click_at(get_viewport().get_final_transform() * at)
	if is_instance_valid(b):
		b.pressed.disconnect(cb)
	if hits.n == 0:
		print("[scenario] click on '%s' at %s (rect %s, window %s) did not press it" % [text, at, b.get_global_rect() if is_instance_valid(b) else "?", get_viewport().get_final_transform() * at])


func click_at(win: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = win
	mv.global_position = win
	Input.parse_input_event(mv)
	await get_tree().process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = win
		e.global_position = win
		Input.parse_input_event(e)
		await get_tree().process_frame


func click_world(p: Vector2) -> void:
	var v := Game.view
	var canvas := v.internal_to_screen(v.world_to_internal(Iso.to_world(p, 0.0)))
	Dev.mouse = canvas     # where the Kindled sees the pointer
	await get_tree().process_frame
	await click_at(get_viewport().get_final_transform() * canvas)
	await get_tree().process_frame
	Dev.mouse = Vector2(-1, -1)


func click_screen_center() -> void:
	await click_at(Vector2(get_window().size) * Vector2(0.5, 0.6))


func find_control(pred: Callable, n: Node = null) -> Control:
	if n == null:
		n = Game.ui
	for c in n.get_children():
		if c is Control and pred.call(c):
			return c
		var f := find_control(pred, c)
		if f:
			return f
	return null


# --- waiting, checking, logging -------------------------------------------------------------

func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func until(cond: Callable, timeout: float, what: String) -> bool:
	var t_end := now() + timeout
	while not cond.call():
		if now() > t_end:
			fail("timed out: " + what)
			return false
		await get_tree().process_frame
	ok(what)
	return true


func expect(c: bool, what: String) -> void:
	if c:
		ok(what)
	else:
		fail(what)


func ok(what: String) -> void:
	passed += 1
	print("[scenario] ok    %s" % what)


func fail(what: String) -> void:
	failed += 1
	print("[scenario] FAIL  %s" % what)


func _tag() -> String:
	for a in Dev.args():
		if a.begins_with("name="):
			return a.substr(5).to_lower()
	return role


## Where everything is on this machine, four times a second, with the wall
## clock (tools/dev/e2e_compare.py lines machines up by it).
func _probe() -> void:
	var st := Game.stage
	if st == null or st.player == null:
		return
	var others := {}
	for pl in st.players:
		if is_instance_valid(pl) and pl != st.player:
			others[Net.name_of(pl.peer_id)] = [snappedf(pl.pos.x, 0.01), snappedf(pl.pos.y, 0.01), pl.sprite.anim if pl.sprite else ""]
	var line := {"t": int(Time.get_unix_time_from_system() * 1000.0), "who": _tag(), "stage": "hub" if st is Hub else "dungeon",
		"fl": Net.i.run_sync.floor_id if Net.i and Net.i.run_sync else 0, "me": [snappedf(st.player.pos.x, 0.01), snappedf(st.player.pos.y, 0.01)],
		"block": Game.ui.blocks_world() if Game.ui else false, "card": Game.ui.card_pending if Game.ui else false,
		"pred": st.player.can_predict(), "in": [snappedf(st.player.move_in.x, 0.01), snappedf(st.player.move_in.y, 0.01)],
		"held": _held.keys().filter(func(k): return _held[k]), "inen": st.player.input_enabled, "paused": get_tree().paused,
		"others": others, "foes": _enemies().size(), "layers": Game.ui.layer_count() if Game.ui else 0}
	print("[probe] ", JSON.stringify(line))
