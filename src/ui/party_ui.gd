## Playing together: hosting, joining and the party itself.
##
## Not in a party: three ways in, side by side - host, join a Steam friend,
## join by address - each saying in a line what it does. In a party: a card
## per seat (the Kindled in their own gear and colour, who hosts, who you are,
## where each one is right now), the expedition being planned, and what you can
## do (invite, plan, leave). Connection details stay folded away until asked
## for. Esc / B steps back a view, then closes.
class_name PartyUI
extends Control

const W := 340

var ui: UIRoot
var view := ""              # "start", "address", "friends", "party"
var _body: VBoxContainer
var _title: Label
var _sub: Label
var _status: Label
var _details := false


func _ready() -> void:
	ui = Game.ui
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(W, 0)
	center.add_child(p)
	var v := UIKit.vbox(5)
	p.add_child(v)
	var head := UIKit.vbox(1)
	_title = UIKit.label("", 16, UIKit.C_GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_title)
	_sub = UIKit.label("", 8, UIKit.C_DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_sub)
	v.add_child(head)
	v.add_child(_rule())
	_body = UIKit.vbox(5)
	v.add_child(_body)
	_status = UIKit.para("", W - 16, UIKit.C_SOUL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	Net.i.roster_changed.connect(_refresh)
	Net.i.status_changed.connect(_on_status)
	Net.i.proposal_changed.connect(_refresh)
	view = "party" if Net.active() else "start"
	_refresh()


func _exit_tree() -> void:
	for s in [Net.i.roster_changed, Net.i.proposal_changed]:
		if s.is_connected(_refresh):
			s.disconnect(_refresh)
	if Net.i.status_changed.is_connected(_on_status):
		Net.i.status_changed.disconnect(_on_status)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if view in ["address", "friends"] and not Net.active():
			_go("start")
		else:
			ui.close_modal(get_parent())


func _go(v: String) -> void:
	view = v
	Audio.ui("ui_click")
	_refresh()


func _on_status(_t: String) -> void:
	if Net.active() and view != "party" and view != "friends":
		view = "party"
	_refresh()


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.45, 0.32, 0.22, 0.8)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _refresh() -> void:
	if not is_inside_tree():
		return
	if Net.active() and view in ["start", "address"]:
		view = "party"
	elif not Net.active() and view == "party":
		view = "start"
	for c in _body.get_children():
		c.queue_free()
	var st := Net.i.status
	_status.text = st
	_status.add_theme_color_override("font_color", UIKit.C_BAD if (st.begins_with("Could not") or st.begins_with("Different") or st.contains("full") or st.contains("already")) else UIKit.C_SOUL)
	match view:
		"start":
			_start()
		"address":
			_address()
		"friends":
			_friends()
		"party":
			_party()
	_focus_first.call_deferred()


func _focus_first() -> void:
	if not is_inside_tree():
		return
	for c in UIRoot.focusables(_body):
		if c is Button or c is LineEdit:
			c.grab_focus()
			return


# --- not in a party: three ways in ----------------------------------------------------

func _start() -> void:
	_title.text = "Play Together"
	_sub.text = "Up to four Kindled, one expedition. Everyone keeps their own progress."
	var name_row := UIKit.hbox(6)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_child(UIKit.label("Your name", 8, UIKit.C_DIM))
	var name_in := LineEdit.new()
	name_in.text = String(Settings.get_value("player_name", "Kindled"))
	name_in.max_length = 16
	name_in.custom_minimum_size = Vector2(120, 14)
	name_in.text_changed.connect(func(t: String) -> void:
		Settings.set_value("player_name", t.strip_edges() if t.strip_edges() != "" else "Kindled"))
	name_row.add_child(name_in)
	_body.add_child(name_row)
	var row := UIKit.hbox(5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var steam: SteamLink = Net.i.steam
	row.add_child(_option("flame", "Host a Party", "Open your sanctuary to friends." if steam.online else "Friends on your network (or by address) join you.",
		"Host", func() -> void:
			if steam.online:
				steam.host_lobby(true)
			else:
				Net.i.host()))
	var steam_why := "" if steam.online else ("Steam is not running." if steam.status == "" else "Steam play is off in this build.")
	row.add_child(_option("lantern", "Join a Friend", "Join a Steam friend's party." if steam.online else steam_why,
		"Find friends", func() -> void: _go("friends"), not steam.online))
	row.add_child(_option("key", "Join by Address", "For LAN play, or a host who shared their address.",
		"Enter address", func() -> void: _go("address")))


## One way into a party: an icon, what it is, a line on what it does, a button.
func _option(icon: String, title: String, line: String, act: String, cb: Callable, off := false) -> PanelContainer:
	var card := UIKit.panel("CardPanel")
	card.custom_minimum_size = Vector2(104, 92)
	var v := UIKit.vbox(3)
	card.add_child(v)
	var ic := UIKit.icon_rect(icon, 2)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color(1, 1, 1) if not off else Color(0.5, 0.5, 0.55)
	v.add_child(ic)
	var t := UIKit.label(title, 8, UIKit.C_GOLD if not off else UIKit.C_DIM, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UIKit.para(line, 92, UIKit.C_DIM)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	var b := UIKit.button(act, cb, 84)
	b.disabled = off
	v.add_child(b)
	return card


func _address() -> void:
	_title.text = "Join by Address"
	_sub.text = "The host's party screen shows the address to use."
	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var addr := LineEdit.new()
	addr.text = String(Settings.get_value("coop_address", "127.0.0.1"))
	addr.custom_minimum_size = Vector2(150, 14)
	addr.placeholder_text = "192.168.1.20"
	addr.text_changed.connect(func(t: String) -> void: Settings.set_value("coop_address", t.strip_edges()))
	var go := func() -> void:
		if addr.text.strip_edges() != "":
			Net.i.join(addr.text.strip_edges())
	addr.text_submitted.connect(func(_t: String) -> void: go.call())
	row.add_child(addr)
	row.add_child(UIKit.button("Join", go, 60))
	_body.add_child(row)
	_body.add_child(_hint("Same network: nothing to set up. Over the internet the host forwards UDP port %d (or everyone joins one VPN); Steam needs neither." % Net.PORT))
	_body.add_child(_back_row())


func _friends() -> void:
	var sl: SteamLink = Net.i.steam
	var hosting := Net.is_host() and sl.lobby_id != 0
	_title.text = "Invite Friends" if hosting else "Join a Friend"
	_sub.text = "Steam friends who are online." if not hosting else "An invite reaches them through Steam."
	var friends: Array = sl.friends_online() if sl.online else []
	if hosting and sl.online and bool(sl.steam.call("isOverlayEnabled")):
		var ob := UIKit.button("Open the Steam overlay", func() -> void: sl.invite(), 140)
		_body.add_child(ob)
	var list := UIKit.vbox(2)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W - 16, 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	if friends.is_empty():
		list.add_child(UIKit.para("No friends are online on Steam right now." if sl.online else "Steam is not running.", W - 30, UIKit.C_DIM))
	# friends in a Kindled Deep party first
	friends.sort_custom(func(a, b): return int(a.get("lobby", 0)) != 0 and int(b.get("lobby", 0)) == 0)
	for f in friends.slice(0, 30):
		var row := UIKit.hbox(6)
		var lob := int(f.get("lobby", 0))
		var who := UIKit.label(String(f.name), 8, UIKit.C_GOLD if lob != 0 else UIKit.C_TEXT)
		who.custom_minimum_size = Vector2(150, 0)
		row.add_child(who)
		var note := UIKit.label("in a party" if lob != 0 else ("playing" if f.playing else ""), 8, UIKit.C_SOUL if lob != 0 else UIKit.C_DIM)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
		var fid := int(f.id)
		if hosting:
			var inv := UIKit.button("Invite", func() -> void: pass, 54)
			inv.pressed.connect(func() -> void:
				sl.invite_friend(fid)
				inv.text = "Invited"
				inv.disabled = true)
			row.add_child(inv)
		elif lob != 0 and not Net.active():
			row.add_child(UIKit.button("Join", func() -> void: sl.join_lobby(lob), 54))
		list.add_child(row)
	_body.add_child(_back_row())


func _back_row() -> HBoxContainer:
	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UIKit.button("Back", func() -> void: _go("party" if Net.active() else "start"), 70))
	return row


func _hint(t: String) -> Label:
	var l := UIKit.para(t, W - 30, UIKit.C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- in a party ----------------------------------------------------------------------

func _party() -> void:
	var n := Net.party_size()
	_title.text = "Your Party"
	_sub.text = ("You are hosting  -  %d of %d Kindled" if Net.is_host() else "In %s's party  -  %d of %d Kindled") % (
		[n, Net.MAX_PLAYERS] if Net.is_host() else [Net.name_of(1), n, Net.MAX_PLAYERS])
	var seats := UIKit.hbox(4)
	seats.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(seats)
	var by_slot := {}
	for pid in Net.i.roster:
		by_slot[int(Net.i.roster[pid].get("slot", 0))] = int(pid)
	var sl: SteamLink = Net.i.steam
	for s in Net.MAX_PLAYERS:
		seats.add_child(_seat(int(by_slot[s])) if by_slot.has(s) else _empty_seat(Net.is_host() and sl.lobby_id != 0))
	# the expedition being planned
	var ex := UIKit.panel("DarkPanel")
	var exv := UIKit.vbox(2)
	ex.add_child(exv)
	var p: Dictionary = Net.i.proposal
	var ex_head := UIKit.hbox(4)
	ex_head.add_child(UIKit.icon_rect("stairs"))
	ex_head.add_child(UIKit.label("EXPEDITION", 8, UIKit.C_GOLD, true))
	exv.add_child(ex_head)
	if p.is_empty():
		exv.add_child(UIKit.para("None planned yet. Anyone can propose one at the Undervault Gate; everyone is asked, wherever they are.", W - 30, UIKit.C_DIM))
	else:
		var yes := 0
		for pid in p.answers:
			if String(p.answers[pid]) == "yes":
				yes += 1
		exv.add_child(UIKit.para("%s proposes %s.  %d of %d ready." % [Net.name_of(int(p.by)), Expedition.describe(p), yes, (p.answers as Dictionary).size()], W - 30, UIKit.C_TEXT))
	_body.add_child(ex)
	var row := UIKit.hbox(5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if Game.stage is Hub and not (Game.stage as Hub).menu_mode and Game.run == null:
		row.add_child(UIKit.button("Plan expedition", func() -> void: ui.descent_prompt(), 96))
	if Net.is_host() and sl.lobby_id != 0:
		row.add_child(UIKit.button("Invite friends", func() -> void: _go("friends"), 86))
	row.add_child(UIKit.button("Leave party" if not Net.is_host() else "Close the party", func() -> void:
		var was_host := Net.is_host()
		var bye := func() -> void:
			Net.i.leave()
			Net.i._status("The party is closed." if was_host else "You left the party.")
		if Game.run != null:
			ui.confirm("Leave the expedition?", "What you carry now comes home with you.", bye)
		else:
			bye.call(), 86))
	row.add_child(UIKit.button("Close", func() -> void: ui.close_modal(get_parent()), 56))
	_body.add_child(row)
	var more := UIKit.button(("Hide" if _details else "Show") + " connection details", func() -> void:
		_details = not _details
		_refresh(), 150)
	more.flat = true
	_body.add_child(more)
	if _details:
		_body.add_child(_hint(_connection_text()))


func _connection_text() -> String:
	var steam := Net.i.peer != null and Net.i.peer.get_class() == "SteamMultiplayerPeer"
	var lines: Array = []
	lines.append("Through %s." % ("Steam (Valve's relay)" if steam else "the network (UDP port %d)" % Net.PORT))
	if Net.is_host() and not steam:
		lines.append("Friends on your network join %s." % Net.lan_address())
	if Net.is_client():
		lines.append("Round trip to the host: %d ms." % int(Net.rtt_s() * 1000.0))
	lines.append("Build %s, protocol %d." % [Net.game_version(), Net.PROTOCOL])
	return "  ".join(PackedStringArray(lines))


## One Kindled's seat: who they are, in their own gear and colour, and where they are.
func _seat(pid: int) -> PanelContainer:
	var r: Dictionary = Net.i.roster[pid]
	var sh: Dictionary = r.get("sheet", {})
	var col := Net.color_of(pid)
	var card := UIKit.panel("CardPanel")
	card.custom_minimum_size = Vector2(78, 112)
	var v := UIKit.vbox(1)
	card.add_child(v)
	var tag := "HOST" if pid == 1 else ""
	if pid == Net.my_id():
		tag = (tag + "  YOU").strip_edges()
	var t := UIKit.label(tag, 8, UIKit.C_DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(GearUI.portrait(sh, 56))
	var nm := UIKit.label(String(r.get("name", "Kindled")), 8, col, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	v.add_child(nm)
	var wid := String(sh.get("weapon", "sword"))
	var lv_row := UIKit.hbox(3)
	lv_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lv_row.add_child(UIKit.label("Lv %d" % int(sh.get("level", 1)), 8, UIKit.C_TEXT))
	var wi := TextureRect.new()
	wi.texture = UIKit.icon_small(wid)
	wi.tooltip_text = String(GearDB.weapon(wid).get("name", wid))
	wi.mouse_filter = Control.MOUSE_FILTER_PASS
	lv_row.add_child(wi)
	v.add_child(lv_row)
	var where: String = {"menu": "At the menu", "hub": "In camp", "below": "Below", "summary": "Home soon"}.get(String(r.get("where", "")), "")
	if bool(r.get("away", false)):
		where = "Link lost"
	var wl := UIKit.label(where, 8, UIKit.C_BAD if bool(r.get("away", false)) else UIKit.C_DIM)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl.clip_text = true
	v.add_child(wl)
	var stripe := ColorRect.new()
	stripe.color = col
	stripe.custom_minimum_size = Vector2(0, 2)
	v.add_child(stripe)
	return card


func _empty_seat(can_invite: bool) -> PanelContainer:
	var card := UIKit.panel("DarkPanel")
	card.custom_minimum_size = Vector2(78, 112)
	var v := UIKit.vbox(3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var l := UIKit.label("Open seat", 8, UIKit.C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if can_invite:
		v.add_child(UIKit.button("Invite", func() -> void: _go("friends"), 54))
	return card
