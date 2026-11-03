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
		"bestiary":
			await bestiary()
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
	tap("interact")
	await wait(0.4)
	expect(Game.ui.modal_of("dialogue") != null, "[%s] F talks again" % tag)
	tap("pause")
	await wait(0.4)
	expect(Game.ui.modal_of("dialogue") == null and Game.ui.layer_count() == 0, "[%s] one Esc closes it" % tag)
	await wait(0.5)
	expect(Game.ui.modal_of("dialogue") == null, "[%s] and it does not reopen" % tag)
	# a click on the Keeper
	await wait(0.4)
	await click_world(keeper.pos + Vector2(0, -0.3))
	await wait(0.5)
	expect(Game.ui.modal_of("dialogue") != null, "[%s] a click on the Keeper talks" % tag)
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
		if role == "host":
			if Net.i.run_sync:
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
	var b := find_control(func(c: Control) -> bool:
		return c is Button and c.is_visible_in_tree() and not (c as Button).disabled and (c as Button).text.strip_edges() in [text, alt, alt2]) as Button
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
