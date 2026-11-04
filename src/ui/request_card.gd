## The party's open question, at the side of the screen for everyone: an
## expedition someone proposed (Expedition), or - below - a vote for the
## stairs, the Hearthstone, the Trial or a Hearthcall (NetRun votes). It never
## takes the player's hands: no pause, no focus grab, so a fight or a menu goes
## on around it. Answer with the buttons, or Y / N (pad: D-pad up / down) from
## anywhere. Each Kindled's answer shows beside their name as it comes in.
class_name RequestCard
extends PanelContainer

const W := 196

var ui: UIRoot
var mode := ""              # "proposal", "vote" or "" (hidden)
var vote_id := -1
var _title: Label
var _sub: Label
var _what: Label            # the expedition itself: region (and tier, Omens) on its own line
var _rows: VBoxContainer
var _buttons: HBoxContainer
var _foot: Label
var _bar: ColorRect
var _bar_back: ColorRect
var _until := 0.0           # local seconds when the vote (or countdown) runs out
var _span := 1.0
var _counting := false
var _shown_id := -1


static func ensure(u: UIRoot) -> RequestCard:
	for c in u.root.get_children():
		if c is RequestCard:
			return c
	var card := RequestCard.new()
	card.ui = u
	u.root.add_child(card)     # above the modal layer: seen over the satchel too
	return card


func _ready() -> void:
	theme_type_variation = "CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, 0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var v := UIKit.vbox(3)
	add_child(v)
	_title = UIKit.label("", 8, UIKit.C_GOLD, true)
	v.add_child(_title)
	_sub = UIKit.para("", W - 16, UIKit.C_DIM)
	v.add_child(_sub)
	_what = UIKit.para("", W - 16, UIKit.C_TEXT)
	v.add_child(_what)
	var line := ColorRect.new()
	line.color = Color(0.45, 1.0, 0.88, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_rows = UIKit.vbox(1)
	v.add_child(_rows)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.06, 0.05, 0.09)
	_bar_back.custom_minimum_size = Vector2(0, 2)
	v.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = UIKit.C_SOUL
	_bar.size = Vector2(0, 2)
	_bar_back.add_child(_bar)
	_foot = UIKit.label("", 8, UIKit.C_DIM)
	v.add_child(_foot)
	_buttons = UIKit.hbox(6)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_buttons)
	Net.i.proposal_changed.connect(_on_proposal)
	Net.i.roster_changed.connect(func() -> void:
		if mode == "proposal":
			_on_proposal())
	_on_proposal()


func _process(_d: float) -> void:
	if not visible:
		return
	# never taller than what it holds (answers, rows and buttons come and go)
	var want := get_combined_minimum_size()
	if size.y > want.y + 0.5:
		size = Vector2(W, want.y)
	var vp := get_viewport_rect().size
	# under the currency (sanctuary) or the map (below), never over either
	var y := 50.0 if not (Game.stage is Dungeon) else 84.0
	position = Vector2(roundf(vp.x - size.x - 6.0), y)
	var left := _until - HubSync.now_s()
	if _until > 0.0:
		_bar_back.visible = true
		_bar.size = Vector2(roundf(_bar_back.size.x * clampf(left / maxf(_span, 0.01), 0.0, 1.0)), 2)
		if _counting:
			_foot.text = "The party descends in %d..." % maxi(1, ceili(left)) if left > 0.0 else "Into the light..."
	else:
		_bar_back.visible = false


func _unhandled_input(e: InputEvent) -> void:
	if not visible or (e is InputEventKey and (e as InputEventKey).echo):
		return
	if e.is_action_pressed("party_yes"):
		_answer(true)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("party_no"):
		_answer(false)
		get_viewport().set_input_as_handled()


func _answer(yes: bool) -> void:
	match mode:
		"proposal":
			if int(Net.i.proposal.get("by", -1)) == Net.my_id() and not yes:
				Expedition.withdraw()
			elif Expedition.my_answer() != ("yes" if yes else "no"):
				Expedition.reply(yes)
				Audio.ui("ui_click")
		"vote":
			Party.answer(vote_id, yes)
			Audio.ui("ui_click")


func _show() -> void:
	if visible:
		return
	visible = true
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	Audio.ui("ui_open")


func _hide() -> void:
	if not visible:
		return
	mode = ""
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if mode == "":
			visible = false)


func _row(pid: int, state: String, note := "") -> void:
	var row := UIKit.hbox(4)
	var pip := ColorRect.new()
	pip.custom_minimum_size = Vector2(4, 4)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.color = Net.color_of(pid)
	row.add_child(pip)
	var who := UIKit.label(Net.name_of(pid) + (" (you)" if pid == Net.my_id() else ""), 8, Net.color_of(pid))
	who.custom_minimum_size = Vector2(80, 0)
	row.add_child(who)
	var txt: String = {"yes": "Ready", "no": "Not now", "": "Deciding"}.get(state, state)
	var col: Color = {"yes": UIKit.C_GOOD, "no": UIKit.C_BAD}.get(state, UIKit.C_DIM)
	row.add_child(UIKit.label(txt + ("  -  " + note if note != "" and state == "" else ""), 8, col))
	_rows.add_child(row)


func _clear() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for c in _buttons.get_children():
		c.queue_free()


func _key(action: String) -> String:
	return Settings.describe_action(action, Settings.using_pad)


# --- an expedition proposal ----------------------------------------------------------

func _on_proposal() -> void:
	var p: Dictionary = Net.i.proposal if Net.i else {}
	if p.is_empty() or not Net.active():
		if mode == "proposal":
			_hide()
		return
	if mode == "vote":
		return
	mode = "proposal"
	var fresh := int(p.id) != _shown_id
	_shown_id = int(p.id)
	_clear()
	var by := int(p.by)
	var mine := by == Net.my_id()
	_title.text = "YOUR EXPEDITION" if mine else "EXPEDITION PROPOSED"
	_sub.text = "You proposed:" if mine else "%s proposes:" % Net.name_of(by)
	_what.visible = true
	_what.text = Expedition.describe(p).replace("  -  ", ",  ")
	var answers: Dictionary = p.answers
	var seats: Array = answers.keys()
	seats.sort_custom(func(a, b): return int(Net.i.roster.get(a, {}).get("slot", 9)) < int(Net.i.roster.get(b, {}).get("slot", 9)))
	for pid in seats:
		_row(int(pid), String(answers[pid]), Net.where_text(int(pid)) if Net.where_text(int(pid)) != "in the sanctuary" else "")
	var launch := float(p.get("launch_in", -1.0))
	_counting = launch > 0.0
	if _counting:
		_span = launch
		_until = HubSync.now_s() + launch
		Audio.play("skill_unlock", -6.0, 1.2)
	else:
		_until = 0.0
		var waiting := 0
		for pid in answers:
			if String(answers[pid]) == "":
				waiting += 1
		_foot.text = ("Waiting for %d" % waiting) if waiting > 0 else ("Someone is not ready yet." if not mine else "")
	var me := Expedition.my_answer()
	if mine:
		_buttons.add_child(UIKit.button("Withdraw  [%s]" % _key("party_no"), func() -> void: Expedition.withdraw(), 90))
	else:
		if me != "yes":
			_buttons.add_child(UIKit.button("Ready  [%s]" % _key("party_yes"), func() -> void: _answer(true), 80))
		if me != "no":
			_buttons.add_child(UIKit.button("Not now  [%s]" % _key("party_no"), func() -> void: _answer(false), 80))
		if Net.is_host():
			_buttons.add_child(UIKit.button("Cancel", func() -> void: Expedition.withdraw(), 50))
	_show()
	set_deferred("size", Vector2(W, 0))     # shrink to what it now holds
	if fresh and not mine:
		Audio.play("gate_hum", -6.0, 1.15)


# --- a vote below ------------------------------------------------------------------------

func show_vote(id: int, title: String, body: String, yes: Array, present: Array, time_left: float) -> void:
	mode = "vote"
	var fresh := vote_id != id
	vote_id = id
	_clear()
	_title.text = title.to_upper()
	_sub.text = body
	_what.visible = false
	for pid in present:
		_row(int(pid), "yes" if yes.has(pid) else "", Net.where_text(int(pid)) if bool(Net.i.roster.get(pid, {}).get("away", false)) else "")
	_counting = false
	if fresh:
		_span = maxf(time_left, 1.0)
		_until = HubSync.now_s() + time_left
	_foot.text = "%d of %d agree" % [yes.size(), present.size()]
	if not yes.has(Net.my_id()):
		_buttons.add_child(UIKit.button("Agree  [%s]" % _key("party_yes"), func() -> void: _answer(true), 80))
		_buttons.add_child(UIKit.button("Not yet  [%s]" % _key("party_no"), func() -> void: _answer(false), 80))
	_show()
	set_deferred("size", Vector2(W, 0))     # shrink to what it now holds


func end_vote(id: int) -> void:
	if mode == "vote" and vote_id == id:
		vote_id = -1
		_hide()
		_on_proposal()
